import 'package:flutter/foundation.dart';

import '../core/formatters.dart';
import '../data/bowel_record_repository.dart';
import '../domain/bowel_record.dart';

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
  bool _isWorking = false;
  String? _feedbackMessage;
  String? _errorMessage;

  List<BowelRecord> get records => List<BowelRecord>.unmodifiable(_records);
  DateTime get currentDate => _currentDate;
  DateTime get now => _now();
  bool get isLoading => _isLoading;
  bool get isWorking => _isWorking;
  String? get feedbackMessage => _feedbackMessage;
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

  Future<void> initialize() async {
    _currentDate = dateOnly(_now());
    try {
      await _reload();
    } catch (_) {
      _errorMessage = '没有读取成功，请重新打开应用';
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
    if (_isWorking || (_feedbackMessage == null && _errorMessage == null)) {
      return;
    }
    _feedbackMessage = null;
    _errorMessage = null;
    notifyListeners();
  }

  Future<bool> saveType(
    int bristolType, {
    String? editRecordId,
    DateTime? recordedAt,
  }) async {
    if (_isWorking || bristolType < 1 || bristolType > 7) return false;
    final actionTime = _now();
    if (recordedAt != null &&
        (recordedAt.isAfter(actionTime) ||
            recordedAt.isBefore(DateTime(1900)))) {
      _feedbackMessage = null;
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
      _feedbackMessage = editRecordId != null
          ? '已修改'
          : recordedAt == null
          ? '已记录'
          : '已补记到 ${recordedAt.month}月${recordedAt.day}日';
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
    if (_isWorking || recordId.trim().isEmpty) return;
    _beginAction();
    try {
      await _repository.delete(recordId);
      await _reload();
      _feedbackMessage = successMessage;
    } catch (_) {
      _errorMessage = failureMessage;
    } finally {
      _endAction();
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
    _feedbackMessage = null;
    _errorMessage = null;
    notifyListeners();
  }

  void _endAction() {
    _isWorking = false;
    notifyListeners();
  }
}
