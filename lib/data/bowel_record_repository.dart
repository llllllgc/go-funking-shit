import '../domain/bowel_record.dart';

abstract interface class BowelRecordRepository {
  Future<List<BowelRecord>> loadAll();

  Future<BowelRecord> create(int bristolType, {DateTime? recordedAt});

  Future<void> updateType(
    String recordId,
    int bristolType, {
    DateTime? recordedAt,
  });

  Future<void> delete(String recordId);

  /// Reinstates a deleted record with its original identity and timestamps.
  Future<void> restore(BowelRecord record);
}
