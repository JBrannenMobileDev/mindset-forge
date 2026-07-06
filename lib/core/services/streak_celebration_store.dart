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

  /// Synchronous cache so a remounted widget can read the flag before the async
  /// SharedPreferences round-trip completes.
  static bool? _memoryFlawless;

  static Future<bool> flawlessCelebrated() async {
    if (_memoryFlawless != null) return _memoryFlawless!;
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getBool(_flawlessKey) ?? false;
    _memoryFlawless = stored;
    return stored;
  }

  static Future<void> setFlawlessCelebrated(bool value) async {
    _memoryFlawless = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_flawlessKey, value);
  }
}
