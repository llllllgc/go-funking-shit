import 'bowel_record.dart';

bool sameRecord(BowelRecord a, BowelRecord b) =>
    a.recordId == b.recordId &&
    a.bristolType == b.bristolType &&
    a.recordedAt.millisecondsSinceEpoch ==
        b.recordedAt.millisecondsSinceEpoch &&
    a.updatedAt.millisecondsSinceEpoch == b.updatedAt.millisecondsSinceEpoch &&
    a.details.note == b.details.note &&
    a.details.discomfortMask == b.details.discomfortMask;

/// The same plan is used for the preview and recomputed inside the database
/// transaction. Existing identities are never overwritten, even on conflict.
class ImportPlan {
  ImportPlan({
    required List<BowelRecord> additions,
    required this.duplicates,
    required this.conflicts,
  }) : additions = List.unmodifiable(additions);

  final List<BowelRecord> additions;
  final int duplicates;
  final int conflicts;
  int get total => additions.length + duplicates + conflicts;

  factory ImportPlan.compare(
    List<BowelRecord> local,
    List<BowelRecord> incoming,
  ) {
    final byId = {for (final record in local) record.recordId: record};
    final additions = <BowelRecord>[];
    var duplicates = 0;
    var conflicts = 0;
    for (final record in incoming) {
      final old = byId[record.recordId];
      if (old == null) {
        additions.add(record);
        byId[record.recordId] = record;
      } else if (sameRecord(old, record)) {
        duplicates++;
      } else {
        conflicts++;
      }
    }
    return ImportPlan(
      additions: additions,
      duplicates: duplicates,
      conflicts: conflicts,
    );
  }
}
