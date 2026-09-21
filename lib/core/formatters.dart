const weekdayLabels = <String>['一', '二', '三', '四', '五', '六', '日'];

String formatFullDate(DateTime date) =>
    '${date.month}月${date.day}日 周${weekdayLabels[date.weekday - 1]}';

String formatHistoryDate(DateTime date) =>
    '${date.month}月${date.day}日 周${weekdayLabels[date.weekday - 1]}';

String formatTime(DateTime date) =>
    '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';

String formatDeleteDate(DateTime date) =>
    '${date.month}月${date.day}日 ${formatTime(date)}';

DateTime dateOnly(DateTime date) => DateTime(date.year, date.month, date.day);

bool isSameDate(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;
