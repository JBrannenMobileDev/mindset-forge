import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/utils/identity_evolution.dart';
import '../models/identity_version.dart';
import '../models/user_profile.dart';
import 'auth_provider.dart';
import '../core/services/analytics_service.dart';
import 'claude_provider.dart';

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

  UserProfile? get _profile =>
      _ref.read(currentUserProfileProvider).valueOrNull;

  /// Calls Claude to propose an evolved statement without persisting.
  Future<IdentityEvolutionProposal> proposeEvolution() async {
    final profile = _profile;
    if (profile == null) {
      return const IdentityEvolutionProposal(statement: '', rationale: '');
    }
    return _ref.read(claudeServiceProvider).generateIdentityStatement(profile);
  }

  /// Accepts a new statement: archives the current one, persists the evolution.
  Future<void> acceptEvolution(
    String statement, {
    String source = 'evolved',
    String rationale = '',
  }) async {
    final uid = _ref.read(authStateProvider).valueOrNull?.uid;
    final profile = _profile;
    if (uid == null || profile == null) return;

    final trimmed = statement.trim();
    if (trimmed.isEmpty) return;

    final now = DateTime.now().toIso8601String();
    final previous = profile.identityStatement.trim();
    var history = profile.identityHistory;
    if (previous.isNotEmpty) {
      final lastInHistory =
          history.isNotEmpty ? history.last.statement.trim() : null;
      if (lastInHistory != previous) {
        history = IdentityEvolution.appendHistory(
          history,
          IdentityVersion(
            statement: previous,
            createdAt: profile.lastIdentityEvolvedAt ?? now,
            source: 'evolved',
            rationale: rationale,
          ),
        );
      }
    }

    final previousState = state;
    state = trimmed;

    try {
      await _ref.read(firestoreServiceProvider).updateUserField(uid, {
        'identityStatement': trimmed,
        'identityHistory': history.map((e) => e.toJson()).toList(),
        'lastIdentityEvolvedAt': now,
        'identityEvolveNudgeDismissedAt': null,
      });
      _ref.read(analyticsServiceProvider).trackIdentityEvolved(source: source);
    } catch (e) {
      state = previousState;
      debugPrint('IdentityNotifier.acceptEvolution failed: $e');
      rethrow;
    }
  }

  /// Dismisses the evolve nudge until the next milestone.
  Future<void> dismissEvolveNudge() async {
    final uid = _ref.read(authStateProvider).valueOrNull?.uid;
    if (uid == null) return;

    try {
      await _ref.read(firestoreServiceProvider).updateUserField(uid, {
        'identityEvolveNudgeDismissedAt': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      debugPrint('IdentityNotifier.dismissEvolveNudge failed: $e');
    }
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
