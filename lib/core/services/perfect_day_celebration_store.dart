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

  static Future<bool> hasCelebrated(String date) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_key) == date;
  }

  static Future<void> markCelebrated(String date) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, date);
  }
}
