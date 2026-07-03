import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/blueprint_snapshot.dart';
import '../models/mindset_blueprint.dart';
import '../models/user_profile.dart';
import 'analytics_provider.dart';
import 'auth_provider.dart';

/// Persists Blueprint snapshot actions.
class BlueprintNotifier extends StateNotifier<bool> {
  BlueprintNotifier(this._ref) : super(false);

  final Ref _ref;

  /// Saves a new trait snapshot. Rotates the prior snapshot into history and
  /// never mutates [UserProfile.originalMindsetBaseline].
  Future<bool> saveSnapshot(
    UserProfile profile,
    MindsetBlueprint blueprint,
  ) async {
    final uid = _ref.read(authStateProvider).valueOrNull?.uid;
    if (uid == null || state) return false;

    state = true;
    try {
      final now = DateTime.now().toIso8601String();
      final history = _rotateHistory(
        profile: profile,
        priorCreatedAt: profile.mindsetBlueprintSnapshotAt,
      );

      await _ref.read(firestoreServiceProvider).updateUserField(uid, {
        'mindsetBlueprint': blueprint.toJson(),
        'mindsetBlueprintSnapshotAt': now,
        'blueprintSnapshotHistory':
            history.map((e) => e.toJson()).toList(),
      });

      final baseline = profile.originalMindsetBaseline;
      final deltaMagnitude =
          (blueprint.average - baseline.average).abs();
      _ref.read(analyticsServiceProvider).trackBlueprintSnapshotCreated(
            deltaMagnitude: deltaMagnitude,
          );
      return true;
    } catch (e) {
      debugPrint('BlueprintNotifier.saveSnapshot failed: $e');
      return false;
    } finally {
      state = false;
    }
  }

  static List<BlueprintSnapshot> _rotateHistory({
    required UserProfile profile,
    required String? priorCreatedAt,
  }) {
    if (!profile.blueprintCompleted || priorCreatedAt == null) {
      return profile.blueprintSnapshotHistory;
    }

    final archived = BlueprintSnapshot(
      blueprint: profile.mindsetBlueprint,
      createdAt: priorCreatedAt,
      source: 'self_assessment',
    );

    return [archived, ...profile.blueprintSnapshotHistory]
        .take(BlueprintSnapshot.historyMax)
        .toList();
  }
}

final blueprintSavingProvider =
    StateNotifierProvider<BlueprintNotifier, bool>((ref) {
  return BlueprintNotifier(ref);
});
