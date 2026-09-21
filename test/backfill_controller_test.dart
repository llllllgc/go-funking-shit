import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:lalema/application/bowel_log_controller.dart';

import 'support/memory_repository.dart';

void main() {
  final now = DateTime(2026, 9, 19, 14, 32);
  late MemoryRepository repository;
  late BowelLogController controller;

  setUp(() async {
    repository = MemoryRepository(now);
    controller = BowelLogController(repository, now: () => now);
    await controller.initialize();
  });

  tearDown(() => controller.dispose());

  test('backfill belongs to the requested day after reopening', () async {
    final yesterday = DateTime(2026, 9, 18, 8, 30);
    expect(await controller.saveType(4, recordedAt: yesterday), isTrue);
    expect(controller.todayRecordCount, 0);
    expect(controller.lastSevenDays[5].recordCount, 1);
    expect(controller.records.single.recordedAt, yesterday);
    expect(controller.records.single.updatedAt, now);

    final reopened = BowelLogController(repository, now: () => now);
    await reopened.initialize();
    expect(reopened.recordsForDate(yesterday).single.recordedAt, yesterday);
    expect(reopened.todayRecordCount, 0);
    reopened.dispose();
  });

  test(
    'cross-month edit updates both dates without duplicating the record',
    () async {
      await controller.saveType(4);
      final id = controller.records.single.recordId;
      final olderDate = DateTime(2026, 8, 31, 23, 59);
      expect(
        await controller.saveType(3, editRecordId: id, recordedAt: olderDate),
        isTrue,
      );
      expect(controller.records, hasLength(1));
      expect(controller.todayRecordCount, 0);
      expect(
        controller.lastSevenDays.every((day) => day.recordCount == 0),
        isTrue,
      );
      expect(controller.recordsForDate(olderDate).single.bristolType, 3);
      final reopened = BowelLogController(repository, now: () => now);
      await reopened.initialize();
      expect(reopened.records.single.recordId, id);
      expect(reopened.records.single.recordedAt, olderDate);
      reopened.dispose();
    },
  );

  test('future times and unsupported old dates never reach storage', () async {
    expect(
      await controller.saveType(
        4,
        recordedAt: now.add(const Duration(minutes: 1)),
      ),
      isFalse,
    );
    expect(
      await controller.saveType(4, recordedAt: DateTime(1899, 12, 31)),
      isFalse,
    );
    expect(repository.createCalls, 0);
    expect(controller.errorMessage, '请选择已经发生的日期和时间');
  });

  test('duplicate save is ignored while the first write is pending', () async {
    repository.writeGate = Completer<void>();
    final pending = controller.saveType(
      4,
      recordedAt: DateTime(2026, 9, 18, 9),
    );
    expect(controller.isWorking, isTrue);
    expect(
      await controller.saveType(4, recordedAt: DateTime(2026, 9, 18, 9)),
      isFalse,
    );
    repository.writeGate!.complete();
    expect(await pending, isTrue);
    expect(repository.createCalls, 1);
    expect(controller.records, hasLength(1));
  });

  test('write failure can be retried without changing existing data', () async {
    await controller.saveType(4);
    repository.failWrites = true;
    expect(
      await controller.saveType(3, recordedAt: DateTime(2026, 9, 18, 8)),
      isFalse,
    );
    expect(controller.records, hasLength(1));
    expect(controller.todayRecordCount, 1);
    expect(controller.isWorking, isFalse);
    repository.failWrites = false;
    expect(
      await controller.saveType(3, recordedAt: DateTime(2026, 9, 18, 8)),
      isTrue,
    );
    expect(controller.records, hasLength(2));
  });

  test(
    'successful writes remain successful if subsequent reads are unavailable',
    () async {
      repository.failReads = true;
      expect(
        await controller.saveType(4, recordedAt: DateTime(2026, 9, 18, 8)),
        isTrue,
      );
      expect(controller.errorMessage, isNull);
      expect(controller.records, hasLength(1));
      expect(repository.createCalls, 1);
    },
  );

  test('day refresh and sorting use actual occurrence times', () async {
    var clock = now;
    final changing = BowelLogController(repository, now: () => clock);
    await changing.initialize();
    await changing.saveType(4);
    await changing.saveType(2, recordedAt: DateTime(2026, 9, 18, 10));
    expect(changing.records.first.recordedAt, now);
    clock = DateTime(2026, 9, 20, 0, 1);
    changing.refreshDate();
    expect(changing.todayRecordCount, 0);
    expect(changing.lastSevenDays[5].recordCount, 1);
    changing.dispose();
  });
}
