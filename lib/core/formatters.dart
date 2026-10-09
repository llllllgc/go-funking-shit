const weekdayLabels = <String>['一', '二', '三', '四', '五', '六', '日'];

String _formatDateWithOptionalYear(DateTime date, DateTime referenceDate) {
  final year = date.year == referenceDate.year ? '' : '${date.year}年';
  return '$year${date.month}月${date.day}日 周${weekdayLabels[date.weekday - 1]}';
}

String formatFullDate(DateTime date, {DateTime? referenceDate}) =>
    _formatDateWithOptionalYear(date, referenceDate ?? DateTime.now());

String formatHistoryDate(DateTime date, {DateTime? referenceDate}) =>
    _formatDateWithOptionalYear(date, referenceDate ?? DateTime.now());

String formatTime(DateTime date) =>
    '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';

String formatDeleteDate(DateTime date, {DateTime? referenceDate}) {
  final year = date.year == (referenceDate ?? DateTime.now()).year
      ? ''
      : '${date.year}年';
  return '$year${date.month}月${date.day}日 ${formatTime(date)}';
}

DateTime dateOnly(DateTime date) => DateTime(date.year, date.month, date.day);

bool isSameDate(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;
