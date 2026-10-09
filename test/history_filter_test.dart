import 'package:flutter_test/flutter_test.dart';
import 'package:lalema/domain/bowel_record.dart';
import 'package:lalema/domain/history_filter.dart';
import 'package:lalema/domain/record_details.dart';

void main() {
  final today = DateTime(2026, 10, 9);
  BowelRecord record(
    String id,
    DateTime date, {
    int type = 4,
    String note = '',
    int discomfort = 0,
  }) => BowelRecord(
    recordId: id,
    bristolType: type,
    recordedAt: date,
    updatedAt: date,
    details: RecordDetails(note: note, discomfortMask: discomfort),
  );
  final records = [
    record(
      'today',
      DateTime(2026, 10, 9, 12),
      note: '喝了 Latte 咖啡',
      discomfort: 2,
    ),
    record(
      'week-first',
      DateTime(2026, 10, 3),
      type: 2,
      note: '咖啡后',
      discomfort: 8,
    ),
    record('before-week', DateTime(2026, 10, 2, 23, 59), type: 2),
    record('month-first', DateTime(2026, 9, 10), type: 6, note: '.* [abc]'),
    record('before-month', DateTime(2026, 9, 9, 23, 59), type: 7),
  ];

  test('rolling ranges include the first and current natural day', () {
    expect(
      const HistoryFilter(
        days: 7,
      ).apply(records, today: today).map((r) => r.recordId),
      ['today', 'week-first'],
    );
    expect(
      const HistoryFilter(
        days: 30,
      ).apply(records, today: today).map((r) => r.recordId),
      ['today', 'week-first', 'before-week', 'month-first'],
    );
  });

  test('text search is literal, case-insensitive and matches all terms', () {
    expect(
      const HistoryFilter(
        search: '  LATTE\n腹胀  ',
      ).apply(records, today: today).single.recordId,
      'today',
    );
    expect(
      const HistoryFilter(
        search: '咖啡 费力',
      ).apply(records, today: today).single.recordId,
      'week-first',
    );
    expect(
      const HistoryFilter(search: '2型').apply(records, today: today).length,
      2,
    );
    expect(
      const HistoryFilter(
        search: '.*',
      ).apply(records, today: today).single.recordId,
      'month-first',
    );
    expect(
      const HistoryFilter(search: '咖啡 水样').apply(records, today: today),
      isEmpty,
    );
  });

  test(
    'date type and discomfort criteria combine rather than replace each other',
    () {
      expect(
        const HistoryFilter(
          days: 7,
          bristolType: 2,
          onlyWithDiscomfort: true,
        ).apply(records, today: today).single.recordId,
        'week-first',
      );
      expect(
        HistoryFilter(
          from: DateTime(2026, 10, 2),
          through: DateTime(2026, 10, 3),
        ).apply(records, today: today).map((r) => r.recordId),
        ['week-first', 'before-week'],
      );
      expect(const HistoryFilter().apply(records, today: today).length, 5);
      expect(const HistoryFilter(search: '   ').isActive, isFalse);
    },
  );

  test('custom ranges handle leap days and DST using calendar boundaries', () {
    final records = [
      record('leap', DateTime(2024, 2, 29, 23, 59)),
      record('next', DateTime(2024, 3, 1)),
      record('dst-first', DateTime(2026, 9, 23)),
      record('dst-last', DateTime(2026, 9, 29, 23, 59)),
      record('outside', DateTime(2026, 9, 30)),
    ];
    expect(
      HistoryFilter(
        from: DateTime(2024, 2, 29),
        through: DateTime(2024, 2, 29),
      ).apply(records, today: today).single.recordId,
      'leap',
    );
    expect(
      const HistoryFilter(
        days: 7,
      ).apply(records, today: DateTime(2026, 9, 29)).map((r) => r.recordId),
      ['dst-first', 'dst-last'],
    );
  });
}
