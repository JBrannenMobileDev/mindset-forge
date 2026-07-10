import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../features/future_self/widgets/future_self_scene_editor.dart';

/// Persists an in-progress add-scene draft locally so dismissing the sheet or
/// closing the app does not lose the user's work. Cleared on successful create.
class SceneDraftStore {
  SceneDraftStore._();

  static String _key(String uid) => 'future_self_add_scene_draft_$uid';

  static Future<void> save(String uid, SceneDraft draft) async {
    if (uid.isEmpty) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key(uid), jsonEncode(draft.toJson()));
  }

  static Future<SceneDraft?> load(String uid) async {
    if (uid.isEmpty) return null;
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key(uid));
    if (raw == null || raw.isEmpty) return null;
    try {
      return SceneDraft.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }

  static Future<void> clear(String uid) async {
    if (uid.isEmpty) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key(uid));
  }
}
