import 'package:lalema/data/record_archive.dart';
import 'package:lalema/domain/record_transfer.dart';
import 'package:lalema/domain/record_details.dart';
import 'dart:async';

import 'package:lalema/data/bowel_record_repository.dart';
import 'package:lalema/domain/bowel_record.dart';

class MemoryRepository implements BowelRecordRepository {
  MemoryRepository(this.now);

  final DateTime now;
  final List<BowelRecord> records = [];
  bool failWrites = false;
  bool failReads = false;
  Completer<void>? writeGate;
  int createCalls = 0;
  int restoreCalls = 0;
  int _nextId = 0;

  @override
  Future<List<BowelRecord>> loadAll() async {
    if (failReads) throw StateError('Read failed');
    return List.unmodifiable(records);
  }

  @override
  Future<BowelRecord> create(
    int bristolType, {
    DateTime? recordedAt,
    RecordDetails details = const RecordDetails(),
  }) async {
    createCalls++;
    if (writeGate != null) await writeGate!.future;
    if (failWrites) throw StateError('Write failed');
    final record = BowelRecord(
      recordId: 'new-${_nextId++}',
      bristolType: bristolType,
      recordedAt: recordedAt ?? now,
      updatedAt: now,
      details: details.validated(),
    );
    records.add(record);
    return record;
  }

  @override
  Future<void> updateType(
    String recordId,
    int bristolType, {
    DateTime? recordedAt,
    RecordDetails? details,
  }) async {
    if (failWrites) throw StateError('Write failed');
    final index = records.indexWhere((record) => record.recordId == recordId);
    if (index < 0) throw StateError('Missing record');
    final old = records[index];
    records[index] = BowelRecord(
      recordId: recordId,
      bristolType: bristolType,
      recordedAt: recordedAt ?? old.recordedAt,
      updatedAt: now,
      details: (details ?? old.details).validated(),
    );
  }

  @override
  Future<ImportPlan> importRecords(List<BowelRecord> incoming) async {
    if (writeGate != null) await writeGate!.future;
    if (failWrites) throw StateError('Write failed');
    RecordArchiveCodec.validateRecords(incoming, now: now);
    final plan = ImportPlan.compare(records, incoming);
    records.addAll(plan.additions);
    return plan;
  }

  @override
  Future<int> deleteAll() async {
    if (failWrites) throw StateError('Write failed');
    final count = records.length;
    records.clear();
    return count;
  }

  @override
  Future<void> delete(String recordId) async {
    if (writeGate != null) await writeGate!.future;
    if (failWrites) throw StateError('Write failed');
    records.removeWhere((record) => record.recordId == recordId);
  }

  @override
  Future<void> restore(BowelRecord record) async {
    restoreCalls++;
    if (writeGate != null) await writeGate!.future;
    if (failWrites) throw StateError('Write failed');
    if (records.any((item) => item.recordId == record.recordId)) {
      throw StateError('Record already exists');
    }
    records.add(record);
  }
}
