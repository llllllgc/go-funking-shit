import 'package:flutter_test/flutter_test.dart';
import 'package:lalema/core/formatters.dart';

void main() {
  final reference = DateTime(2026, 9, 22);

  test('date formatters include the year for records from another year', () {
    expect(
      formatFullDate(DateTime(2025, 9, 18), referenceDate: reference),
      '2025年9月18日 周四',
    );
    expect(
      formatHistoryDate(DateTime(2025, 9, 18), referenceDate: reference),
      '2025年9月18日 周四',
    );
    expect(
      formatDeleteDate(
        DateTime(2025, 9, 18, 7, 5),
        referenceDate: reference,
      ),
      '2025年9月18日 07:05',
    );
  });

  test('date formatters keep the compact form for the current year', () {
    final date = DateTime(2026, 9, 18, 7, 5);
    expect(formatFullDate(date, referenceDate: reference), '9月18日 周五');
    expect(formatHistoryDate(date, referenceDate: reference), '9月18日 周五');
    expect(formatDeleteDate(date, referenceDate: reference), '9月18日 07:05');
  });
}
