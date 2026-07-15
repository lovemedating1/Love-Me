/// Relative-time helpers for chat / conversation timestamps.
class RelativeTime {
  RelativeTime._();

  /// Short form: "now", "5m", "3h", "2d", or a date.
  static String short(DateTime t, {DateTime? now}) {
    final ref = now ?? DateTime.now();
    final d = ref.difference(t);
    if (d.inMinutes < 1) return 'now';
    if (d.inMinutes < 60) return '${d.inMinutes}m';
    if (d.inHours < 24) return '${d.inHours}h';
    if (d.inDays < 7) return '${d.inDays}d';
    return '${t.day}/${t.month}';
  }

  /// Clock time HH:mm for chat bubbles.
  static String clock(DateTime t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

  static const _weekdays = [
    'Monday',
    'Tuesday',
    'Wednesday',
    'Thursday',
    'Friday',
    'Saturday',
    'Sunday',
  ];
  static const _months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];

  /// Chat date-separator label: "Friday, Jul 3, 2026".
  static String dayLabel(DateTime t) =>
      '${_weekdays[t.weekday - 1]}, ${_months[t.month - 1]} ${t.day}, ${t.year}';

  static bool isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  /// Absolute short date, e.g. "6/19/2026" — used where the old app shows a
  /// fixed date instead of a relative one (Notifications list).
  static String absolute(DateTime t) => '${t.month}/${t.day}/${t.year}';
}
