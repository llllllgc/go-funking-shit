import '../domain/record_transfer.dart';
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

  /// Atomically inserts missing identities; duplicates and conflicts keep local data.
  Future<ImportPlan> importRecords(List<BowelRecord> records);

  /// Deletes only the application log. Exported files are outside this boundary.
  Future<int> deleteAll();

  /// Restores a previously deleted record using its original identity and
  /// timestamps. Implementations should fail if the id is already present.
  ///
  /// Keeping this operation at the repository boundary lets the UI offer a
  /// short-lived undo action without creating a new record or losing its
  /// original occurrence time.
  Future<void> restore(BowelRecord record);
}
