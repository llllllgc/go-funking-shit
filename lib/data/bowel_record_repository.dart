import '../domain/record_details.dart';
import '../domain/bowel_record.dart';

abstract interface class BowelRecordRepository {
  Future<List<BowelRecord>> loadAll();

  Future<BowelRecord> create(
    int bristolType, {
    DateTime? recordedAt,
    RecordDetails details = const RecordDetails(),
  });

  Future<void> updateType(
    String recordId,
    int bristolType, {
    DateTime? recordedAt,
    RecordDetails? details,
  });

  Future<void> delete(String recordId);

  /// Restores a previously deleted record using its original identity and
  /// timestamps. Implementations should fail if the id is already present.
  ///
  /// Keeping this operation at the repository boundary lets the UI offer a
  /// short-lived undo action without creating a new record or losing its
  /// original occurrence time.
  Future<void> restore(BowelRecord record);
}
