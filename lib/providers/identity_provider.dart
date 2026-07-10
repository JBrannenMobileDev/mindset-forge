import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/user_profile.dart';
import 'auth_provider.dart';

/// Manages the user's identity statement.
///
/// Keeps a local optimistic copy of the statement and writes changes through
/// [FirestoreService] — widgets never access Firestore directly for this field.
class IdentityNotifier extends StateNotifier<String> {
  final Ref _ref;

  IdentityNotifier(this._ref) : super('');

  void _loadFromProfile(UserProfile? profile) {
    if (profile == null) {
      state = '';
      return;
    }
    state = profile.identityStatement;
  }

  /// Saves [text] to Firestore. Optimistically updates local state; rolls back
  /// and rethrows on failure so the calling widget can surface an error.
  Future<void> updateStatement(String text) async {
    final uid = _ref.read(authStateProvider).valueOrNull?.uid;
    if (uid == null) return;
    final previous = state;
    state = text;
    try {
      await _ref.read(firestoreServiceProvider).updateUserField(uid, {
        'identityStatement': text,
      });
    } catch (e) {
      state = previous;
      debugPrint('IdentityNotifier.updateStatement failed: $e');
      rethrow;
    }
  }
}

final identityProvider = StateNotifierProvider<IdentityNotifier, String>((ref) {
  final notifier = IdentityNotifier(ref);
  ref.listen(currentUserProfileProvider, (_, next) {
    next.whenData((profile) => notifier._loadFromProfile(profile));
  });
  ref.read(currentUserProfileProvider).whenData(
    (profile) => notifier._loadFromProfile(profile),
  );
  return notifier;
});
