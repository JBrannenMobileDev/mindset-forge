import 'package:intl/intl.dart';

abstract final class AppDateUtils {
  static String todayString() {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }

  /// Midnight–4 AM counts as the previous day (grace period for late-night sessions).
  static String todayStringWithGracePeriod() {
    final now = DateTime.now();
    final adjusted =
        now.hour < 4 ? now.subtract(const Duration(days: 1)) : now;
    return '${adjusted.year}-${adjusted.month.toString().padLeft(2, '0')}-${adjusted.day.toString().padLeft(2, '0')}';
  }

  static String formatDate(DateTime date) =>
      DateFormat('MMM d, yyyy').format(date);

  static String formatDateShort(DateTime date) =>
      DateFormat('MMM d').format(date);

  static String formatMonthYear(DateTime date) =>
      DateFormat('MMMM yyyy').format(date);

  static String formatWeekdayLong(DateTime date) =>
      DateFormat('EEEE, MMMM d').format(date); // e.g. "Tuesday, June 23"

  static String formatTime(DateTime date) =>
      DateFormat('h:mm a').format(date);

  static String formatRelative(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inHours < 1) return '${diff.inMinutes}m ago';
    if (diff.inDays < 1) return '${diff.inHours}h ago';
    if (diff.inDays == 1) return 'Yesterday';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return formatDate(date);
  }

  /// Greeting aligned to the same 4 AM–4 AM day model as [sessionPeriod]: the
  /// midnight–4 AM grace window reads as evening (continuation of the prior
  /// day's evening) rather than morning.
  static String greetingForTime() {
    final hour = DateTime.now().hour;
    if (hour >= 4 && hour < 12) return 'Good morning';
    if (hour >= 12 && hour < 17) return 'Good afternoon';
    return 'Good evening'; // 17–23 and 0–3 (grace window)
  }

  /// Returns the current daily session period:
  /// - 'morning'    → 4 AM – 11:59 AM
  /// - 'transition' → 12 PM – 4:59 PM (both sections visible)
  /// - 'evening'    → 5 PM – 3:59 AM (includes grace period hours)
  static String sessionPeriod() {
    final hour = DateTime.now().hour;
    if (hour >= 4 && hour < 12) return 'morning';
    if (hour >= 12 && hour < 17) return 'transition';
    return 'evening'; // 17–23 and 0–3
  }

  static bool isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  static List<DateTime> lastNDays(int n) {
    final today = DateTime.now();
    return List.generate(n, (i) => today.subtract(Duration(days: n - 1 - i)));
  }

  static String weekdayShort(DateTime date) =>
      DateFormat('EEE').format(date);
}
