import '../core/formatters.dart';
import 'bowel_record.dart';
import 'bristol_type.dart';

/// Filters saved records locally. Date ranges use natural calendar days.
class HistoryFilter {
  const HistoryFilter({
    this.search = '',
    this.days = 0,
    this.bristolType,
    this.from,
    this.through,
  });

  final String search;
  final int days;
  final int? bristolType;
  final DateTime? from;
  final DateTime? through;

  bool get isActive =>
      search.trim().isNotEmpty ||
      days != 0 ||
      bristolType != null ||
      from != null;

  HistoryFilter copyWith({
    String? search,
    int? days,
    int? bristolType,
    bool clearType = false,
    DateTime? from,
    DateTime? through,
    bool clearDates = false,
  }) => HistoryFilter(
    search: search ?? this.search,
    days: days ?? this.days,
    bristolType: clearType ? null : bristolType ?? this.bristolType,
    from: clearDates ? null : from ?? this.from,
    through: clearDates ? null : through ?? this.through,
  );

  List<BowelRecord> apply(
    List<BowelRecord> records, {
    required DateTime today,
  }) {
    final start = from != null
        ? dateOnly(from!)
        : days > 0
        ? DateTime(today.year, today.month, today.day - days + 1)
        : null;
    final last = through ?? (days > 0 ? today : null);
    final end = last == null
        ? null
        : DateTime(last.year, last.month, last.day + 1);
    final terms = search
        .trim()
        .toLowerCase()
        .split(RegExp(r'\s+'))
        .where((term) => term.isNotEmpty);

    return records
        .where((record) {
          if (start != null && record.recordedAt.isBefore(start)) return false;
          if (end != null && !record.recordedAt.isBefore(end)) return false;
          if (bristolType != null && record.bristolType != bristolType) {
            return false;
          }
          if (terms.isEmpty) return true;
          final type = bristolTypeFor(record.bristolType);
          final text =
              '${type?.code ?? ''} ${type?.code ?? ''}型 ${type?.label ?? ''}'
                  .toLowerCase();
          return terms.every(text.contains);
        })
        .toList(growable: false);
  }
}
