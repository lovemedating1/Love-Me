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
}
