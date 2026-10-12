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

  test(
    'undo and recovery preserve identity, timestamps and persisted data',
    () async {
      final yesterday = now.subtract(const Duration(days: 1));
      await controller.saveType(1, recordedAt: yesterday);
      final original = controller.records.single;
      expect(controller.feedback!.recordId, original.recordId);
      expect(controller.feedback!.action, RecordFeedbackAction.undo);

      repository.failReads = true;
      await controller.undo(original.recordId);
      expect(controller.errorMessage, isNull);
      expect(controller.records, isEmpty);
      expect(controller.feedback!.action, RecordFeedbackAction.restore);
      await controller.restoreDeletedRecord(original.recordId);
      expect(controller.records.single.toMap(), original.toMap());
      expect(controller.todayRecordCount, 0);
      expect(controller.lastSevenDays[5].recordCount, 1);

      repository.failReads = false;
      final reopened = BowelLogController(repository, now: () => now);
      await reopened.initialize();
      expect(reopened.records.single.toMap(), original.toMap());
      reopened.dispose();
    },
  );

  test('failed deletion keeps the original record', () async {
    await controller.saveType(4);
    final original = controller.records.single;
    repository.failWrites = true;
    await controller.deleteRecord(original.recordId);
    expect(controller.records.single.toMap(), original.toMap());
    expect(repository.records, hasLength(1));
    expect(controller.errorMessage, '没有删除成功，请再试一次');
    expect(controller.feedback, isNull);
  });

  test('failed recovery can be retried without duplicating a record', () async {
    await controller.saveType(4);
    final original = controller.records.single;
    await controller.deleteRecord(original.recordId);
    repository.failWrites = true;
    await controller.restoreDeletedRecord(original.recordId);
    expect(controller.records, isEmpty);
    expect(controller.errorMessage, '没有恢复成功，请再试一次');
    expect(controller.feedback!.action, RecordFeedbackAction.restore);
    repository.failWrites = false;
    await controller.restoreDeletedRecord(original.recordId);
    await controller.restoreDeletedRecord(original.recordId);
    expect(repository.records.single.toMap(), original.toMap());
    expect(controller.records, hasLength(1));
  });

  test('dismissed recovery cannot restore an expired deletion', () async {
    await controller.saveType(4);
    final id = controller.records.single.recordId;
    await controller.deleteRecord(id);
    controller.dismissFeedback(controller.feedback!);
    await controller.restoreDeletedRecord(id);
    expect(controller.records, isEmpty);
    expect(repository.records, isEmpty);
  });

  test('an old prompt closing does not discard a newer recovery', () async {
    await controller.saveType(4);
    final first = controller.records.single.recordId;
    await controller.saveType(1);
    final second = controller.feedback!.recordId!;
    await controller.deleteRecord(first);
    final oldFeedback = controller.feedback!;
    await controller.deleteRecord(second);
    controller.dismissFeedback(oldFeedback);
    await controller.restoreDeletedRecord(first);
    expect(controller.records, isEmpty);
    await controller.restoreDeletedRecord(second);
    expect(controller.records.single.recordId, second);
  });

  test('repeated recovery while storage is busy writes only once', () async {
    await controller.saveType(4);
    final original = controller.records.single;
    await controller.undo(original.recordId);
    repository.writeGate = Completer<void>();
    final pending = controller.restoreDeletedRecord(original.recordId);
    await controller.restoreDeletedRecord(original.recordId);
    repository.writeGate!.complete();
    await pending;
    expect(repository.records.single.toMap(), original.toMap());
  });
}
