import 'package:shared_preferences/shared_preferences.dart';

/// Persists whether the one-time flawless-week streak celebration (confetti +
/// badge pop) has already fired, so it plays exactly once per milestone — not
/// again the next day and not again on app relaunch.
///
/// Re-armed (reset to false) by the caller when the streak drops below a
/// week, so a fresh run of seven flawless days celebrates again.
class StreakCelebrationStore {
  StreakCelebrationStore._();

  static const _flawlessKey = 'celebrated_flawless_week_v1';

  static Future<bool> flawlessCelebrated() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_flawlessKey) ?? false;
  }

  static Future<void> setFlawlessCelebrated(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_flawlessKey, value);
  }
}
