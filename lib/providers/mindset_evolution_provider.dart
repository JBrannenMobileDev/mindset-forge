import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../core/services/analytics_service.dart';
import '../models/mindset_item_progress.dart';
import '../models/user_profile.dart';
import 'auth_provider.dart';
import 'claude_provider.dart';

/// Whether the evolution excavation flow is busy.
final mindsetEvolutionBusyProvider =
    StateNotifierProvider<MindsetEvolutionNotifier, bool>((ref) {
  return MindsetEvolutionNotifier(ref);
});

class MindsetEvolutionNotifier extends StateNotifier<bool> {
  MindsetEvolutionNotifier(this._ref) : super(false);

  final Ref _ref;
  static const _uuid = Uuid();

  Future<Map<String, List<String>>> runExcavation(UserProfile profile) async {
    state = true;
    try {
      _ref.read(analyticsServiceProvider).trackEvolutionOpened();
      return await _ref
          .read(claudeServiceProvider)
          .excavateDeeperMindset(profile);
    } catch (e) {
      debugPrint('MindsetEvolutionNotifier.runExcavation failed: $e');
      return {'beliefs': <String>[], 'fears': <String>[]};
    } finally {
      state = false;
    }
  }

  Future<void> saveSelections({
    required UserProfile profile,
    required List<String> beliefs,
    required List<String> fears,
  }) async {
    final uid = _ref.read(authStateProvider).valueOrNull?.uid;
    if (uid == null || state) return;

    state = true;
    final now = DateTime.now().toIso8601String();
    final nextGen = _nextGeneration(profile);

    final newBeliefProgress = beliefs
        .map(
          (text) => MindsetItemProgress(
            id: _uuid.v4(),
            text: text,
            kind: 'belief',
            addedAt: now,
            generation: nextGen,
          ),
        )
        .toList();
    final newFearProgress = fears
        .map(
          (text) => MindsetItemProgress(
            id: _uuid.v4(),
            text: text,
            kind: 'fear',
            addedAt: now,
            generation: nextGen,
          ),
        )
        .toList();

    final updatedBeliefs = [...profile.limitingBeliefs, ...beliefs];
    final updatedFears = [...profile.fearsDrift, ...fears];

    try {
      await _ref.read(firestoreServiceProvider).updateUserField(uid, {
        'limitingBeliefs': updatedBeliefs,
        'fearsDrift': updatedFears,
        'beliefProgress': [
          ...profile.beliefProgress.map((e) => e.toJson()),
          ...newBeliefProgress.map((e) => e.toJson()),
        ],
        'fearProgress': [
          ...profile.fearProgress.map((e) => e.toJson()),
          ...newFearProgress.map((e) => e.toJson()),
        ],
        'lastExcavationAt': now,
        'blueprintEvolutionReady': false,
      });
      _ref.read(analyticsServiceProvider).trackEvolutionCompleted(
            beliefCount: beliefs.length,
            fearCount: fears.length,
            generation: nextGen,
          );
    } catch (e) {
      debugPrint('MindsetEvolutionNotifier.saveSelections failed: $e');
      rethrow;
    } finally {
      state = false;
    }
  }

  Future<void> dismiss() async {
    final uid = _ref.read(authStateProvider).valueOrNull?.uid;
    if (uid == null || state) return;

    state = true;
    try {
      await _ref.read(firestoreServiceProvider).updateUserField(uid, {
        'blueprintEvolutionReady': false,
      });
    } catch (e) {
      debugPrint('MindsetEvolutionNotifier.dismiss failed: $e');
    } finally {
      state = false;
    }
  }

  int _nextGeneration(UserProfile profile) {
    final gens = [
      ...profile.beliefProgress.map((e) => e.generation),
      ...profile.fearProgress.map((e) => e.generation),
    ];
    if (gens.isEmpty) return 2;
    return gens.reduce((a, b) => a > b ? a : b) + 1;
  }
}
