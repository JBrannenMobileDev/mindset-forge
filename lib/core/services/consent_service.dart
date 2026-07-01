import 'package:shared_preferences/shared_preferences.dart';

/// Persists the user's cookie/analytics consent choice for the web app.
///
/// On web, non-essential analytics (Mixpanel) must not load until the user
/// accepts. This stores that decision and keeps a synchronous in-memory copy so
/// startup gating can read it without awaiting. Call [load] once at app start.
///
/// Mobile builds are not gated here (analytics run as before), so this is only
/// consulted on web.
class ConsentService {
  ConsentService._();

  static const _key = 'analytics_consent_v1';

  // null = undecided, true = granted, false = denied.
  static bool? _granted;

  /// Whether the user has made an explicit choice yet.
  static bool get decided => _granted != null;

  /// Whether analytics consent has been granted.
  static bool get granted => _granted == true;

  static Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    _granted = prefs.getBool(_key);
  }

  static Future<void> set(bool value) async {
    _granted = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_key, value);
  }
}
