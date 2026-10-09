import '../core/formatters.dart';
import 'bowel_record.dart';
import 'bristol_type.dart';

/// All matching is local. Date windows use natural days, including both
/// selected endpoints, instead of assuming every day lasts 24 hours.
class HistoryFilter {
  const HistoryFilter({
    this.search = '',
    this.days = 0,
    this.bristolType,
    this.onlyWithDiscomfort = false,
    this.from,
    this.through,
  });

  final String search;
  final int days;
  final int? bristolType;
  final bool onlyWithDiscomfort;
  final DateTime? from;
  final DateTime? through;
  bool get isActive =>
      search.trim().isNotEmpty ||
      days != 0 ||
      bristolType != null ||
      onlyWithDiscomfort ||
      from != null ||
      through != null;
  int get extraCount =>
      (bristolType == null ? 0 : 1) + (onlyWithDiscomfort ? 1 : 0);

  HistoryFilter copyWith({
    String? search,
    int? days,
    int? bristolType,
    bool clearType = false,
    bool? onlyWithDiscomfort,
    DateTime? from,
    DateTime? through,
    bool clearDates = false,
  }) => HistoryFilter(
    search: search ?? this.search,
    days: days ?? this.days,
    bristolType: clearType ? null : bristolType ?? this.bristolType,
    onlyWithDiscomfort: onlyWithDiscomfort ?? this.onlyWithDiscomfort,
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
        .where((value) => value.isNotEmpty)
        .toList();
    return records
        .where((record) {
          if (start != null && record.recordedAt.isBefore(start)) return false;
          if (end != null && !record.recordedAt.isBefore(end)) return false;
          if (bristolType != null && record.bristolType != bristolType) {
            return false;
          }
          if (onlyWithDiscomfort && record.details.discomfortMask == 0) {
            return false;
          }
          if (terms.isEmpty) return true;
          final type = bristolTypeFor(record.bristolType);
          final text =
              '${record.details.note} ${type?.code ?? ''} ${record.bristolType}型 ${type?.label ?? ''} ${record.details.discomforts.map((value) => value.label).join(' ')}'
                  .toLowerCase();
          return terms.every(text.contains);
        })
        .toList(growable: false);
  }

  @override
  bool operator ==(Object other) =>
      other is HistoryFilter &&
      other.search == search &&
      other.days == days &&
      other.bristolType == bristolType &&
      other.onlyWithDiscomfort == onlyWithDiscomfort &&
      other.from == from &&
      other.through == through;
  @override
  int get hashCode =>
      Object.hash(search, days, bristolType, onlyWithDiscomfort, from, through);
}
