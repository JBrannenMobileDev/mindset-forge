import 'package:shared_preferences/shared_preferences.dart';

/// Persists a pending accountability-partner invite id across the sign-up /
/// sign-in flow. When an unauthenticated user opens an invite link, the router
/// stashes the invite here, sends them to auth, then resumes the accept flow
/// once they have an account.
///
/// Keeps a synchronous in-memory copy so the GoRouter redirect (which cannot
/// await) can read it immediately. Call [load] once at app start.
class PendingInviteStore {
  PendingInviteStore._();

  static const _key = 'pending_partner_invite';
  static String? _inviteId;

  static String? get inviteId => _inviteId;
  static bool get hasPending => _inviteId != null && _inviteId!.isNotEmpty;

  static Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    _inviteId = prefs.getString(_key);
  }

  static Future<void> set(String id) async {
    if (id.isEmpty) return;
    _inviteId = id;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, id);
  }

  static Future<void> clear() async {
    _inviteId = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
  }
}
