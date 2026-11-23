/// 极简日期/时长格式化工具，避免引入 intl 额外依赖。
class AppDate {
  const AppDate._();

  static const List<String> _weekdayLabels = <String>[
    '一',
    '二',
    '三',
    '四',
    '五',
    '六',
    '日',
  ];

  static String two(int value) => value.toString().padLeft(2, '0');

  static bool isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  static String dateKey(DateTime date) =>
      '${date.year}-${two(date.month)}-${two(date.day)}';

  static String timeLabel(DateTime date) =>
      '${two(date.hour)}:${two(date.minute)}';

  static String monthDayLabel(DateTime date) => '${date.month}月${date.day}日';

  static String fullDateLabel(DateTime date) =>
      '${date.year}年${date.month}月${date.day}日';

  static String weekdayLabel(DateTime date) =>
      '周${_weekdayLabels[date.weekday - 1]}';

  static String monthDayWithWeekday(DateTime date) =>
      '${monthDayLabel(date)} · ${weekdayLabel(date)}';

  /// 今天 / 明天 / 昨天 / 11月23日 这样的轻量表达。
  static String friendlyDay(DateTime date, {DateTime? now}) {
    final today = now ?? DateTime.now();
    if (isSameDay(date, today)) return '今天';
    if (isSameDay(date, today.add(const Duration(days: 1)))) return '明天';
    if (isSameDay(date, today.subtract(const Duration(days: 1)))) return '昨天';
    return monthDayLabel(date);
  }

  /// 45m / 1h / 1h30m
  static String durationLabel(int? minutes) {
    if (minutes == null || minutes <= 0) return '';
    if (minutes < 60) return '${minutes}m';
    final int hours = minutes ~/ 60;
    final int rest = minutes % 60;
    return rest == 0 ? '${hours}h' : '${hours}h${rest}m';
  }

  static String timeRangeLabel(DateTime start, DateTime end) =>
      '${timeLabel(start)} - ${timeLabel(end)}';

  static DateTime startOfDay(DateTime date) =>
      DateTime(date.year, date.month, date.day);

  static DateTime endOfDay(DateTime date) =>
      DateTime(date.year, date.month, date.day, 23, 59, 59);

  /// 本周一 00:00
  static DateTime startOfWeek(DateTime date) {
    final day = startOfDay(date);
    return day.subtract(Duration(days: day.weekday - 1));
  }

  static DateTime startOfMonth(DateTime date) => DateTime(date.year, date.month);

  static DateTime startOfYear(DateTime date) => DateTime(date.year);
}