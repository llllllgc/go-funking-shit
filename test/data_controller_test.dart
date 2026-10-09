import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:lalema/application/bowel_log_controller.dart';
import 'package:lalema/domain/bowel_record.dart';
import 'package:lalema/domain/record_details.dart';

import 'support/memory_repository.dart';

void main() {
  final now = DateTime(2026, 10, 9, 12);
  BowelRecord incoming() => BowelRecord(
    recordId: 'imported',
    bristolType: 3,
    recordedAt: now,
    updatedAt: now,
    details: const RecordDetails(note: '导入完整细节', discomfortMask: 8),
  );

  test('record snapshots are immutable and detached after writes', () async {
    final repository = MemoryRepository(now);
    final controller = BowelLogController(repository, now: () => now);
    await controller.initialize();
    await controller.saveType(4);
    final original = controller.records;
    expect(() => original.clear(), throwsUnsupportedError);
    controller.clearFeedback();
    expect(identical(original, controller.records), isTrue);
    repository.failWrites = true;
    expect(await controller.saveType(5), isFalse);
    expect(identical(original, controller.records), isTrue);
    repository.failWrites = false;
    await controller.saveType(5);
    expect(original, hasLength(1));
    expect(controller.records, hasLength(2));
    await controller.deleteRecord(controller.records.first.recordId);
    expect(() => controller.records.add(incoming()), throwsUnsupportedError);
  });

  test(
    'committed import does not depend on a successful follow-up read',
    () async {
      final repository = MemoryRepository(now);
      final controller = BowelLogController(repository, now: () => now);
      await controller.initialize();
      repository.failReads = true;
      final result = await controller.importRecords([incoming()]);
      expect(result!.additions, hasLength(1));
      expect(controller.records.single.toMap(), incoming().toMap());
      expect(controller.errorMessage, isNull);
      expect((await controller.importRecords([incoming()]))!.duplicates, 1);
      expect(controller.records, hasLength(1));
    },
  );

  test('failed import and clear preserve data and permit retry', () async {
    final repository = MemoryRepository(now);
    final controller = BowelLogController(repository, now: () => now);
    await controller.initialize();
    await controller.saveType(4);
    final original = controller.records.single.toMap();
    repository.failWrites = true;
    expect(await controller.importRecords([incoming()]), isNull);
    expect(await controller.clearAllRecords(), isFalse);
    expect(controller.records.single.toMap(), original);
    expect(repository.records.single.toMap(), original);
    repository.failWrites = false;
    expect(
      (await controller.importRecords([incoming()]))!.additions,
      hasLength(1),
    );
    expect(await controller.clearAllRecords(), isTrue);
    expect(repository.records, isEmpty);
  });

  test(
    'import excludes concurrent writes and clear invalidates old undo entries',
    () async {
      final repository = MemoryRepository(now);
      final controller = BowelLogController(repository, now: () => now);
      await controller.initialize();
      await controller.saveType(4);
      final old = controller.records.single;
      await controller.deleteRecord(old.recordId);
      repository.writeGate = Completer<void>();
      final importing = controller.importRecords([incoming()]);
      expect(controller.isWorking, isTrue);
      expect(await controller.importRecords([incoming()]), isNull);
      expect(await controller.saveType(4), isFalse);
      expect(await controller.clearAllRecords(), isFalse);
      repository.writeGate!.complete();
      await importing;
      expect(await controller.clearAllRecords(), isTrue);
      expect(await controller.restoreRecord(old.recordId), isFalse);
      expect(controller.records, isEmpty);
    },
  );
}
