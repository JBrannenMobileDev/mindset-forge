import 'package:shared_preferences/shared_preferences.dart';

/// Persists whether the dashboard Getting Started checklist is expanded on
/// mobile. Defaults to collapsed so the Today hero stays above the fold.
class GettingStartedExpandStore {
  GettingStartedExpandStore._();

  static const _key = 'getting_started_expanded_v1';

  static bool? _memory;

  static Future<bool> isExpanded() async {
    if (_memory != null) return _memory!;
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getBool(_key) ?? false;
    _memory = stored;
    return stored;
  }

  static Future<void> setExpanded(bool value) async {
    _memory = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_key, value);
  }
}
