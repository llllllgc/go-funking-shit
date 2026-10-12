import 'package:flutter_test/flutter_test.dart';
import 'package:lalema/domain/bowel_record.dart';
import 'package:lalema/domain/history_filter.dart';

void main() {
  final today = DateTime(2026, 10, 12);
  BowelRecord record(String id, int type, DateTime at) => BowelRecord(
    recordId: id,
    bristolType: type,
    recordedAt: at,
    updatedAt: at,
  );
  final records = [
    record('recent-soft', 4, DateTime(2026, 10, 12, 23, 59)),
    record('week-edge', 1, DateTime(2026, 10, 6)),
    record('older', 4, DateTime(2026, 10, 5, 23, 59)),
  ];

  test('calendar-day windows include both selected endpoints', () {
    expect(
      const HistoryFilter(
        days: 7,
      ).apply(records, today: today).map((e) => e.recordId),
      ['recent-soft', 'week-edge'],
    );
    expect(
      HistoryFilter(
        from: DateTime(2026, 10, 5),
        through: DateTime(2026, 10, 6),
      ).apply(records, today: today).map((e) => e.recordId),
      ['week-edge', 'older'],
    );
  });

  test('search uses displayed code and label while filtering stored type', () {
    expect(
      const HistoryFilter(
        search: '01 光滑柔软',
      ).apply(records, today: today).map((e) => e.recordId),
      ['recent-soft', 'older'],
    );
    expect(
      const HistoryFilter(
        search: '04 颗粒偏硬',
        bristolType: 1,
      ).apply(records, today: today).map((e) => e.recordId),
      ['week-edge'],
    );
  });
}
