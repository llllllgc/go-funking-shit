import 'package:lalema/domain/record_transfer.dart';
import 'package:lalema/domain/record_details.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lalema/application/bowel_log_controller.dart';
import 'package:lalema/data/bowel_record_repository.dart';
import 'package:lalema/domain/bowel_record.dart';

void main() {
  final now = DateTime(2026, 9, 16, 12);

  test('creates, updates, and deletes factual records', () async {
    final repository = _MemoryRepository(now);
    final controller = BowelLogController(repository, now: () => now);
    await controller.initialize();

    expect(controller.todayRecordCount, 0);
    expect(await controller.saveType(4), isTrue);
    expect(controller.todayRecordCount, 1);
    expect(controller.latestTodayRecord?.bristolType, 4);
    expect(controller.feedbackMessage, '已记录');

    final recordId = controller.latestTodayRecord!.recordId;
    expect(await controller.saveType(7, editRecordId: recordId), isTrue);
    expect(controller.latestTodayRecord?.bristolType, 7);
    expect(controller.feedbackMessage, '已修改');

    await controller.deleteRecord(recordId);
    expect(controller.todayRecordCount, 0);
    expect(controller.feedbackMessage, '已删除');
  });

  test('delete remains successful when a follow-up read fails', () async {
    final repository = _MemoryRepository(now);
    final controller = BowelLogController(repository, now: () => now);
    await controller.initialize();
    expect(await controller.saveType(4), isTrue);
    final recordId = controller.records.single.recordId;

    repository.failReads = true;
    final deleted = await controller.deleteRecord(recordId);

    expect(deleted?.recordId, recordId);
    expect(controller.records, isEmpty);
    expect(controller.feedbackMessage, '已删除');
    expect(controller.errorMessage, isNull);
  });

  test(
    'deleted records can be restored with their original identity',
    () async {
      final repository = _MemoryRepository(now);
      final controller = BowelLogController(repository, now: () => now);
      await controller.initialize();
      final occurredAt = now.subtract(const Duration(hours: 2));
      await controller.saveType(3, recordedAt: occurredAt);
      final deleted = controller.records.single;

      await controller.deleteRecord(deleted.recordId);
      expect(controller.records, isEmpty);
      expect(await controller.restoreRecord(deleted.recordId), isTrue);
      expect(controller.records.single.recordId, deleted.recordId);
      expect(controller.records.single.recordedAt, occurredAt);
      expect(controller.feedbackMessage, '已恢复');
    },
  );

  test('builds seven consecutive day summaries', () async {
    final repository = _MemoryRepository(now)
      ..records.addAll(<BowelRecord>[
        _record('today-1', 4, now),
        _record('today-2', 5, now.subtract(const Duration(hours: 1))),
        _record('yesterday', 3, now.subtract(const Duration(days: 1))),
        _record('old', 2, now.subtract(const Duration(days: 8))),
      ]);
    final controller = BowelLogController(repository, now: () => now);
    await controller.initialize();

    final days = controller.lastSevenDays;
    expect(days, hasLength(7));
    expect(days.last.recordCount, 2);
    expect(days[5].recordCount, 1);
    expect(days.fold<int>(0, (sum, day) => sum + day.recordCount), 3);
  });

  test('failed initialization blocks writes and can be retried', () async {
    final repository = _MemoryRepository(now)..failReads = true;
    final controller = BowelLogController(repository, now: () => now);
    await controller.initialize();
    expect(controller.hasLoaded, isFalse);
    expect(await controller.saveType(4), isFalse);
    expect(repository.records, isEmpty);
    repository.failReads = false;
    await controller.initialize();
    expect(controller.hasLoaded, isTrue);
    expect(controller.errorMessage, isNull);
    expect(await controller.saveType(4), isTrue);
  });

  test(
    'daily windows use calendar boundaries across daylight saving',
    () async {
      // Pacific/Auckland changes to daylight time on 2026-09-27. CI also
      // runs this test with that TZ instead of assuming every day is 24 hours.
      final clock = DateTime(2026, 9, 29, 0, 30);
      final repository = _MemoryRepository(clock)
        ..records.addAll([
          _record('first', 2, DateTime(2026, 9, 23, 0)),
          _record('before', 3, DateTime(2026, 9, 22, 23, 59)),
          _record('transition', 4, DateTime(2026, 9, 27, 3, 30)),
          _record('current', 5, clock),
        ]);
      final controller = BowelLogController(repository, now: () => clock);
      await controller.initialize();
      final days = controller.lastSevenDays;
      expect(days.map((day) => day.date.day), [23, 24, 25, 26, 27, 28, 29]);
      expect(days.map((day) => day.recordCount), [1, 0, 0, 0, 1, 0, 1]);
    },
  );

  test('builds a thirty day window ending on the current day', () async {
    final repository = _MemoryRepository(now)
      ..records.add(_record('today', 4, now))
      ..records.add(
        _record('month-start', 5, now.subtract(const Duration(days: 29))),
      )
      ..records.add(
        _record('outside-window', 6, now.subtract(const Duration(days: 30))),
      );
    final controller = BowelLogController(repository, now: () => now);
    await controller.initialize();

    final days = controller.lastThirtyDays;
    expect(days, hasLength(30));
    expect(days.first.date, DateTime(2026, 8, 18));
    expect(days.first.recordCount, 1);
    expect(days.last.recordCount, 1);
    expect(days.fold<int>(0, (sum, day) => sum + day.recordCount), 2);
  });
}

BowelRecord _record(String id, int type, DateTime time) => BowelRecord(
  recordId: id,
  bristolType: type,
  recordedAt: time,
  updatedAt: time,
);

class _MemoryRepository implements BowelRecordRepository {
  _MemoryRepository(this.now);

  final DateTime now;
  final List<BowelRecord> records = <BowelRecord>[];
  bool failReads = false;
  int _nextId = 0;

  @override
  Future<BowelRecord> create(
    int bristolType, {
    DateTime? recordedAt,
    RecordDetails details = const RecordDetails(),
  }) async {
    final record = _record(
      'record-${_nextId++}',
      bristolType,
      recordedAt ?? now,
    );
    records.add(record);
    return record;
  }

  @override
  Future<ImportPlan> importRecords(List<BowelRecord> records) =>
      throw UnimplementedError();

  @override
  Future<int> deleteAll() => throw UnimplementedError();

  @override
  Future<void> delete(String recordId) async {
    records.removeWhere((record) => record.recordId == recordId);
  }

  @override
  Future<List<BowelRecord>> loadAll() async {
    if (failReads) throw StateError('Read failed');
    return List<BowelRecord>.of(records);
  }

  @override
  Future<void> updateType(
    String recordId,
    int bristolType, {
    DateTime? recordedAt,
    RecordDetails? details,
  }) async {
    final index = records.indexWhere((record) => record.recordId == recordId);
    final old = records[index];
    records[index] = BowelRecord(
      recordId: old.recordId,
      bristolType: bristolType,
      recordedAt: recordedAt ?? old.recordedAt,
      updatedAt: now,
    );
  }

  @override
  Future<void> restore(BowelRecord record) async {
    if (records.any((item) => item.recordId == record.recordId)) {
      throw StateError('Record already exists');
    }
    records.add(record);
  }
}
