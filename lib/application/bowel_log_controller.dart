import 'package:flutter/foundation.dart';

import '../core/formatters.dart';
import '../data/bowel_record_repository.dart';
import '../domain/bowel_record.dart';

enum RecordFeedbackAction { undo, restore }

class RecordFeedback {
  const RecordFeedback(this.message, {this.action, this.recordId});

  final String message;
  final RecordFeedbackAction? action;
  final String? recordId;
}

class LogDaySummary {
  const LogDaySummary({required this.date, required this.recordCount});

  final DateTime date;
  final int recordCount;

  bool get hasRecord => recordCount > 0;
}

class BowelLogController extends ChangeNotifier {
  BowelLogController(this._repository, {DateTime Function()? now})
    : _now = now ?? DateTime.now;

  final BowelRecordRepository _repository;
  final DateTime Function() _now;

  List<BowelRecord> _records = const <BowelRecord>[];
  DateTime _currentDate = dateOnly(DateTime.now());
  bool _isLoading = true;
  bool _hasLoaded = false;
  bool _isWorking = false;
  RecordFeedback? _feedback;
  BowelRecord? _deletedRecord;
  RecordFeedback? _recoveryFeedback;
  String? _errorMessage;

  List<BowelRecord> get records => List<BowelRecord>.unmodifiable(_records);
  DateTime get currentDate => _currentDate;
  DateTime get now => _now();
  bool get isLoading => _isLoading;
  bool get hasLoaded => _hasLoaded;
  bool get isWorking => _isWorking;
  RecordFeedback? get feedback => _feedback;
  String? get feedbackMessage => _feedback?.message;
  String? get errorMessage => _errorMessage;

  List<BowelRecord> get todayRecords => _records
      .where((record) => isSameDate(record.recordedAt, _currentDate))
      .toList(growable: false);

  BowelRecord? get latestTodayRecord =>
      todayRecords.isEmpty ? null : todayRecords.first;

  int get todayRecordCount => todayRecords.length;

  List<BowelRecord> recordsForDate(DateTime date) => _records
      .where((record) => isSameDate(record.recordedAt, date))
      .toList(growable: false);

  List<LogDaySummary> get lastSevenDays {
    return List<LogDaySummary>.generate(7, (index) {
      final date = DateTime(
        _currentDate.year,
        _currentDate.month,
        _currentDate.day - 6 + index,
      );
      final count = _records
          .where((record) => isSameDate(record.recordedAt, date))
          .length;
      return LogDaySummary(date: date, recordCount: count);
    });
  }

  BowelRecord? record(String? recordId) {
    if (recordId == null) return null;
    for (final record in _records) {
      if (record.recordId == recordId) return record;
    }
    return null;
  }

  Future<bool> initialize() async {
    if (_isWorking) return _hasLoaded;
    _currentDate = dateOnly(_now());
    _isLoading = true;
    _errorMessage = null;
    try {
      await _reload();
      _hasLoaded = true;
      return true;
    } catch (_) {
      _hasLoaded = false;
      _errorMessage = '没有读取成功，请重试';
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void refreshDate() {
    final next = dateOnly(_now());
    if (next == _currentDate) return;
    _currentDate = next;
    notifyListeners();
  }

  void clearFeedback() {
    if (_isWorking || (_feedback == null && _errorMessage == null)) {
      return;
    }
    _feedback = null;
    _errorMessage = null;
    notifyListeners();
  }

  Future<bool> saveType(
    int bristolType, {
    String? editRecordId,
    DateTime? recordedAt,
  }) async {
    if (_isWorking ||
        _isLoading ||
        !_hasLoaded ||
        bristolType < 1 ||
        bristolType > 7) {
      return false;
    }
    final actionTime = _now();
    if (recordedAt != null &&
        (recordedAt.isAfter(actionTime) ||
            recordedAt.isBefore(DateTime(1900)))) {
      _feedback = null;
      _errorMessage = '请选择已经发生的日期和时间';
      notifyListeners();
      return false;
    }
    _beginAction();
    try {
      BowelRecord saved;
      if (editRecordId == null) {
        saved = await _repository.create(
          bristolType,
          recordedAt: recordedAt ?? actionTime,
        );
      } else {
        final old = record(editRecordId);
        if (old == null) throw StateError('Record no longer exists');
        await _repository.updateType(
          editRecordId,
          bristolType,
          recordedAt: recordedAt,
        );
        saved = BowelRecord(
          recordId: old.recordId,
          bristolType: bristolType,
          recordedAt: recordedAt ?? old.recordedAt,
          updatedAt: actionTime,
        );
      }
      // Once the write succeeds, update locally. A failed follow-up read must
      // never invite a retry that creates a duplicate record.
      _records = [
        ..._records.where((record) => record.recordId != saved.recordId),
        saved,
      ];
      _sortRecords();
      _currentDate = dateOnly(_now());
      _deletedRecord = null;
      _recoveryFeedback = null;
      _feedback = RecordFeedback(
        editRecordId != null
            ? '已修改 · ${formatTime(saved.recordedAt)}'
            : recordedAt == null
            ? '已记录 · ${formatTime(saved.recordedAt)}'
            : '已补记 · ${recordedAt.month}月${recordedAt.day}日 ${formatTime(saved.recordedAt)}',
        action: editRecordId == null ? RecordFeedbackAction.undo : null,
        recordId: saved.recordId,
      );
      return true;
    } catch (_) {
      _errorMessage = '没有保存成功，请再试一次';
      return false;
    } finally {
      _endAction();
    }
  }

  Future<void> undo(String recordId) =>
      _delete(recordId, successMessage: '已撤销', failureMessage: '没有撤销成功，请再试一次');

  Future<void> deleteRecord(String recordId) =>
      _delete(recordId, successMessage: '已删除', failureMessage: '没有删除成功，请再试一次');

  Future<void> _delete(
    String recordId, {
    required String successMessage,
    required String failureMessage,
  }) async {
    if (_isWorking || _isLoading || !_hasLoaded || recordId.trim().isEmpty) {
      return;
    }
    final deleted = record(recordId);
    if (deleted == null) return;
    _beginAction();
    try {
      await _repository.delete(recordId);
      _records = _records
          .where((record) => record.recordId != recordId)
          .toList(growable: false);
      _deletedRecord = deleted;
      _feedback = RecordFeedback(
        successMessage,
        action: RecordFeedbackAction.restore,
        recordId: recordId,
      );
      _recoveryFeedback = _feedback;
    } catch (_) {
      _errorMessage = failureMessage;
    } finally {
      _endAction();
    }
  }

  Future<void> restoreDeletedRecord(String recordId) async {
    final deleted = _deletedRecord;
    if (_isWorking ||
        _isLoading ||
        !_hasLoaded ||
        deleted == null ||
        deleted.recordId != recordId) {
      return;
    }
    _beginAction();
    try {
      await _repository.restore(deleted);
      _records = [..._records, deleted];
      _sortRecords();
      _deletedRecord = null;
      _recoveryFeedback = null;
      _currentDate = dateOnly(_now());
      _feedback = RecordFeedback('已恢复 · ${formatTime(deleted.recordedAt)}');
    } catch (_) {
      _errorMessage = '没有恢复成功，请再试一次';
      _feedback = RecordFeedback(
        _errorMessage!,
        action: RecordFeedbackAction.restore,
        recordId: recordId,
      );
      _recoveryFeedback = _feedback;
    } finally {
      _endAction();
    }
  }

  void dismissFeedback(RecordFeedback feedback) {
    if (identical(_recoveryFeedback, feedback)) {
      _deletedRecord = null;
      _recoveryFeedback = null;
    }
    if (identical(_feedback, feedback)) {
      _feedback = null;
      notifyListeners();
    }
  }

  Future<void> _reload() async {
    final loaded = await _repository.loadAll();
    _records = List<BowelRecord>.of(loaded);
    _sortRecords();
  }

  void _sortRecords() {
    _records.sort((a, b) {
      final byTime = b.recordedAt.compareTo(a.recordedAt);
      return byTime != 0 ? byTime : b.recordId.compareTo(a.recordId);
    });
  }

  void _beginAction() {
    _isWorking = true;
    _feedback = null;
    _errorMessage = null;
    notifyListeners();
  }

  void _endAction() {
    _isWorking = false;
    notifyListeners();
  }
}
