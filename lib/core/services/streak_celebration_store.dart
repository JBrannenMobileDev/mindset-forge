import 'package:shared_preferences/shared_preferences.dart';

/// Persists whether the one-time full-week streak celebration (confetti + badge
/// pop) has already fired for each tier, so it plays exactly once per milestone
/// — not again the next day and not again on app relaunch.
///
/// Each flag is re-armed (reset to false) by the caller when the corresponding
/// streak drops below a week, so a fresh run of seven days celebrates again.
class StreakCelebrationStore {
  StreakCelebrationStore._();

  static const _perfectKey = 'celebrated_perfect_week_v1';
  static const _flawlessKey = 'celebrated_flawless_week_v1';

  static Future<bool> perfectCelebrated() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_perfectKey) ?? false;
  }

  static Future<void> setPerfectCelebrated(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_perfectKey, value);
  }

  static Future<bool> flawlessCelebrated() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_flawlessKey) ?? false;
  }

  static Future<void> setFlawlessCelebrated(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_flawlessKey, value);
  }
}
