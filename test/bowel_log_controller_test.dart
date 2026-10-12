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
    expect(controller.feedbackMessage, '已记录 · 12:00');

    final recordId = controller.latestTodayRecord!.recordId;
    expect(await controller.saveType(7, editRecordId: recordId), isTrue);
    expect(controller.latestTodayRecord?.bristolType, 7);
    expect(controller.feedbackMessage, '已修改 · 12:00');

    await controller.deleteRecord(recordId);
    expect(controller.todayRecordCount, 0);
    expect(controller.feedbackMessage, '已删除');
  });

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
  int _nextId = 0;

  @override
  Future<BowelRecord> create(int bristolType, {DateTime? recordedAt}) async {
    final record = _record(
      'record-${_nextId++}',
      bristolType,
      recordedAt ?? now,
    );
    records.add(record);
    return record;
  }

  @override
  Future<void> delete(String recordId) async {
    records.removeWhere((record) => record.recordId == recordId);
  }

  @override
  Future<void> restore(BowelRecord record) async {
    records.add(record);
  }

  @override
  Future<List<BowelRecord>> loadAll() async => List<BowelRecord>.of(records);

  @override
  Future<void> updateType(
    String recordId,
    int bristolType, {
    DateTime? recordedAt,
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
}
