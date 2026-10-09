import '../domain/record_transfer.dart';
import '../domain/record_details.dart';
import 'dart:async';

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
  BowelLogController(
    this._repository, {
    DateTime Function()? now,
    this.onDispose,
    bool Function()? canWrite,
  }) : _now = now ?? DateTime.now,
       _canWrite = canWrite ?? _alwaysAllow;

  static bool _alwaysAllow() => true;
  final bool Function() _canWrite;
  final BowelRecordRepository _repository;
  final DateTime Function() _now;
  final Future<void> Function()? onDispose;
  bool _disposed = false;
  bool _hasLoaded = false;
  bool get hasLoaded => _hasLoaded;

  List<BowelRecord> _records = const <BowelRecord>[];
  DateTime _currentDate = dateOnly(DateTime.now());
  bool _isLoading = true;
  bool _isWorking = false;
  String? _feedbackMessage;
  String? _errorMessage;
  DateTime? _lastSavedAt;
  DateTime? get lastSavedAt => _lastSavedAt;
  final Map<String, BowelRecord> _deletedRecords = <String, BowelRecord>{};

  /// Immutable snapshots retain identity until a successful data change.
  List<BowelRecord> get records => _records;
  DateTime get currentDate => _currentDate;
  DateTime get now => _now();
  bool get isLoading => _isLoading;
  bool get isWorking => _isWorking;
  String? get feedbackMessage => _feedbackMessage;
  String? get errorMessage => _errorMessage;

  /// Returns a deleted record while its undo action is still available.
  ///
  /// The controller keeps the complete record in memory so a restore can
  /// preserve its original id, occurrence time, and update timestamp.
  BowelRecord? deletedRecord(String recordId) => _deletedRecords[recordId];

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
    return summariesForDays(7);
  }

  List<LogDaySummary> get lastThirtyDays {
    return summariesForDays(30);
  }

  /// Returns one summary per calendar day, oldest first, ending on the
  /// controller's current day. Keeping this in the controller means the
  /// home screen and future trend views use the same date boundary.
  List<LogDaySummary> summariesForDays(int dayCount) {
    final totalDays = dayCount < 1 ? 1 : dayCount;
    return List<LogDaySummary>.generate(totalDays, (index) {
      final date = DateTime(
        _currentDate.year,
        _currentDate.month,
        _currentDate.day - totalDays + 1 + index,
      );
      final recordCount = _records
          .where((record) => isSameDate(record.recordedAt, date))
          .length;
      return LogDaySummary(date: date, recordCount: recordCount);
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
    if (_isWorking) return;
    _currentDate = dateOnly(_now());
    _isLoading = true;
    _errorMessage = null;
    try {
      await _reload();
      _hasLoaded = true;
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
    RecordDetails? details,
  }) async {
    if (_isWorking ||
        _isLoading ||
        !_hasLoaded ||
        bristolType < 1 ||
        bristolType > 7) {
      return false;
    }
    if (!_checkWriteAccess()) return false;
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
          details: (details ?? const RecordDetails()).validated(),
        );
      } else {
        final old = record(editRecordId);
        if (old == null) throw StateError('Record no longer exists');
        await _repository.updateType(
          editRecordId,
          bristolType,
          recordedAt: recordedAt,
          details: details?.validated(),
        );
        saved = BowelRecord(
          recordId: old.recordId,
          bristolType: bristolType,
          recordedAt: recordedAt ?? old.recordedAt,
          updatedAt: actionTime,
          details: (details ?? old.details).validated(),
        );
      }
      _lastSavedAt = saved.recordedAt;
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

  Future<void> undo(String recordId) async {
    // This is the existing quick action on the home screen: remove the
    // latest record. A separate restoreRecord method handles undoing a
    // deletion from a snackbar or other transient UI affordance.
    await _delete(
      recordId,
      successMessage: '已撤销',
      failureMessage: '没有撤销成功，请再试一次',
    );
  }

  Future<BowelRecord?> deleteRecord(String recordId) =>
      _delete(recordId, successMessage: '已删除', failureMessage: '没有删除成功，请再试一次');

  /// Restores a record deleted through [deleteRecord] or [undo].
  ///
  /// Returning a bool lets transient UI actions quietly disappear when the
  /// short undo window has expired or a restore has already been attempted.
  Future<bool> restoreRecord(String recordId) async {
    if (_isWorking || _isLoading || !_hasLoaded || recordId.trim().isEmpty) {
      return false;
    }
    if (!_checkWriteAccess()) return false;
    final deleted = _deletedRecords[recordId];
    if (deleted == null) return false;
    _beginAction();
    try {
      await _repository.restore(deleted);
      _deletedRecords.remove(recordId);
      _records = <BowelRecord>[..._records, deleted];
      _sortRecords();
      _feedbackMessage = '已恢复';
      return true;
    } catch (_) {
      _errorMessage = '没有恢复成功，请再试一次';
      return false;
    } finally {
      _endAction();
    }
  }

  Future<BowelRecord?> _delete(
    String recordId, {
    required String successMessage,
    required String failureMessage,
  }) async {
    if (_isWorking || _isLoading || !_hasLoaded || recordId.trim().isEmpty) {
      return null;
    }
    if (!_checkWriteAccess()) return null;
    final deleted = record(recordId);
    if (deleted == null) {
      _errorMessage = failureMessage;
      notifyListeners();
      return null;
    }
    _beginAction();
    try {
      await _repository.delete(recordId);
      // The delete has already been committed when repository.delete
      // resolves. Updating the in-memory snapshot directly avoids turning a
      // successful deletion into a misleading failure if a follow-up read is
      // temporarily unavailable.
      _records = List<BowelRecord>.unmodifiable(
        _records.where((record) => record.recordId != recordId),
      );
      _deletedRecords[recordId] = deleted;
      _feedbackMessage = successMessage;
      return deleted;
    } catch (_) {
      _errorMessage = failureMessage;
      return null;
    } finally {
      _endAction();
    }
  }

  Future<ImportPlan?> importRecords(List<BowelRecord> records) async {
    if (_isWorking || _isLoading || !_hasLoaded) return null;
    if (!_checkWriteAccess()) return null;
    _beginAction();
    try {
      final result = await _repository.importRecords(records);
      // The transaction has already committed. Do not turn a subsequent read
      // failure into a misleading import error and invite duplicate retries.
      _records = [..._records, ...result.additions];
      _sortRecords();
      _deletedRecords.clear();
      _currentDate = dateOnly(_now());
      _feedbackMessage = '已导入 ${result.additions.length} 条记录';
      return result;
    } catch (_) {
      _errorMessage = '没有导入成功，已有记录未更改，请再试一次';
      return null;
    } finally {
      _endAction();
    }
  }

  Future<bool> clearAllRecords() async {
    if (_isWorking || _isLoading || !_hasLoaded) return false;
    if (!_checkWriteAccess()) return false;
    _beginAction();
    try {
      await _repository.deleteAll();
      _records = const [];
      _lastSavedAt = null;
      _deletedRecords.clear();
      _feedbackMessage = '本机记录已清空';
      return true;
    } catch (_) {
      _errorMessage = '没有清空成功，请再试一次';
      return false;
    } finally {
      _endAction();
    }
  }

  bool _checkWriteAccess() {
    if (_disposed) return false;
    if (_canWrite()) return true;
    _feedbackMessage = null;
    _errorMessage = '应用已锁定或离开前台，请返回后重试。';
    notifyListeners();
    return false;
  }

  @override
  void notifyListeners() {
    if (!_disposed) super.notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _lastSavedAt = null;
    _deletedRecords.clear();
    if (onDispose != null) unawaited(onDispose!());
    super.dispose();
  }

  Future<void> _reload() async {
    final loaded = await _repository.loadAll();
    _records = List<BowelRecord>.of(loaded);
    _sortRecords();
  }

  void _sortRecords() {
    final sorted = List<BowelRecord>.of(_records)
      ..sort((a, b) {
        final byTime = b.recordedAt.compareTo(a.recordedAt);
        return byTime != 0 ? byTime : b.recordId.compareTo(a.recordId);
      });
    _records = List<BowelRecord>.unmodifiable(sorted);
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
