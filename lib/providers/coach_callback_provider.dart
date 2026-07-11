import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/services/analytics_service.dart';
import '../models/coach_callback.dart';
import 'auth_provider.dart';

/// Pending proactive coach callback derived from the profile stream.
final pendingCoachCallbackProvider = Provider<CoachCallback?>((ref) {
  final profile = ref.watch(currentUserProfileProvider).valueOrNull;
  if (profile == null || !profile.hasPendingCallback) return null;
  return profile.pendingCallback;
});

/// Persists coach callback seen/clear actions.
class CoachCallbackNotifier extends StateNotifier<bool> {
  CoachCallbackNotifier(this._ref) : super(false);

  final Ref _ref;

  Future<void> markSeen(CoachCallback callback) async {
    final uid = _ref.read(authStateProvider).valueOrNull?.uid;
    if (uid == null || state) return;

    state = true;
    try {
      final seenAt = DateTime.now().toIso8601String();
      await _ref.read(firestoreServiceProvider).updateUserField(uid, {
        'pendingCallback.seenAt': seenAt,
      });
      _ref.read(analyticsServiceProvider).trackCallbackSeen(
            valence: callback.valence,
            triggerType: callback.triggerType,
          );
    } catch (e) {
      debugPrint('CoachCallbackNotifier.markSeen failed: $e');
    } finally {
      state = false;
    }
  }

  Future<void> clearPending() async {
    final uid = _ref.read(authStateProvider).valueOrNull?.uid;
    if (uid == null || state) return;

    state = true;
    try {
      await _ref.read(firestoreServiceProvider).updateUserField(uid, {
        'pendingCallback': null,
      });
    } catch (e) {
      debugPrint('CoachCallbackNotifier.clearPending failed: $e');
    } finally {
      state = false;
    }
  }

  Future<void> markResponded(CoachCallback callback) async {
    final uid = _ref.read(authStateProvider).valueOrNull?.uid;
    if (uid == null) return;

    try {
      await _ref.read(firestoreServiceProvider).updateUserField(uid, {
        'pendingCallback.respondedAt': DateTime.now().toIso8601String(),
      });
      _ref.read(analyticsServiceProvider).trackCallbackResponded(
            valence: callback.valence,
            triggerType: callback.triggerType,
          );
    } catch (e) {
      debugPrint('CoachCallbackNotifier.markResponded failed: $e');
    }
  }
}

final coachCallbackBusyProvider =
    StateNotifierProvider<CoachCallbackNotifier, bool>((ref) {
  return CoachCallbackNotifier(ref);
});
