import 'package:shared_preferences/shared_preferences.dart';

/// Persists whether the daily perfect-day celebration (confetti) has already
/// fired for a given day, so it plays exactly once per calendar day — not again
/// on rebuild, and not again on app relaunch.
///
/// Only the most recently celebrated date string is stored, so the flag
/// self-cleans day to day: a new perfect day simply overwrites the previous
/// value.
class PerfectDayCelebrationStore {
  PerfectDayCelebrationStore._();

  static const _key = 'celebrated_perfect_day_v1';

  /// Synchronous cache so a remounted widget can read "already celebrated"
  /// before the async SharedPreferences round-trip completes.
  static String? _memoryDate;

  static Future<bool> hasCelebrated(String date) async {
    if (_memoryDate == date) return true;
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getString(_key);
    if (stored == date) {
      _memoryDate = date;
      return true;
    }
    return false;
  }

  static Future<void> markCelebrated(String date) async {
    _memoryDate = date;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, date);
  }
}
