import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/action_step.dart';
import '../models/goal.dart';
import '../models/user_profile.dart';
import 'auth_provider.dart';

class GoalsNotifier extends StateNotifier<List<Goal>> {
  final Ref _ref;

  GoalsNotifier(this._ref) : super([]);

  void _loadFromProfile(UserProfile? profile) {
    if (profile != null) state = profile.goals;
  }

  Future<void> addGoal(Goal goal) async {
    final uid = _ref.read(authStateProvider).valueOrNull?.uid;
    if (uid == null) return;

    final updated = [...state, goal];
    state = updated;
    await _ref.read(firestoreServiceProvider).updateUserField(uid, {
      'goals': updated.map((g) => g.toJson()).toList(),
    });
  }

  Future<void> updateGoal(Goal goal) async {
    final uid = _ref.read(authStateProvider).valueOrNull?.uid;
    if (uid == null) return;

    final updated = state.map((g) => g.id == goal.id ? goal : g).toList();
    state = updated;
    await _ref.read(firestoreServiceProvider).updateUserField(uid, {
      'goals': updated.map((g) => g.toJson()).toList(),
    });
  }

  Future<void> deleteGoal(String goalId) async {
    final uid = _ref.read(authStateProvider).valueOrNull?.uid;
    if (uid == null) return;

    final updated = state.where((g) => g.id != goalId).toList();
    state = updated;
    await _ref.read(firestoreServiceProvider).updateUserField(uid, {
      'goals': updated.map((g) => g.toJson()).toList(),
    });
  }

  /// Toggle a single action step's completion and recompute the goal's
  /// progress from the proportion of completed steps.
  Future<void> toggleActionStep(String goalId, String stepId) async {
    final goal = state.firstWhere(
      (g) => g.id == goalId,
      orElse: () => throw StateError('Goal $goalId not found'),
    );

    final steps = goal.actionSteps.map((s) {
      if (s.id != stepId) return s;
      final nowDone = !s.isCompleted;
      return ActionStep(
        id: s.id,
        description: s.description,
        isCompleted: nowDone,
        completedAt: nowDone ? DateTime.now() : null,
      );
    }).toList();

    final progress = steps.isEmpty
        ? goal.progressPercent
        : steps.where((s) => s.isCompleted).length / steps.length * 100;

    await updateGoal(goal.copyWith(
      actionSteps: steps,
      progressPercent: progress,
    ));
  }

  /// Manually sets a goal's progress (0-100). Used by the detail-screen slider
  /// for goals without action steps. Clamps to valid range.
  Future<void> setProgress(String goalId, double percent) async {
    final goal = state.firstWhere((g) => g.id == goalId);
    await updateGoal(goal.copyWith(progressPercent: percent.clamp(0.0, 100.0)));
  }

  Future<void> completeGoal(String goalId) async {
    final goal = state.firstWhere((g) => g.id == goalId);
    await updateGoal(goal.copyWith(
      status: 'completed',
      progressPercent: 100.0,
      completedAt: DateTime.now(),
    ));
  }

  List<Goal> get longTermGoals =>
      state.where((g) => g.isLongTerm && g.status == 'active').toList();

  List<Goal> get shortTermGoals =>
      state.where((g) => !g.isLongTerm && g.status == 'active').toList();
}

final goalsProvider = StateNotifierProvider<GoalsNotifier, List<Goal>>(
  (ref) {
    final notifier = GoalsNotifier(ref);
    ref.listen(currentUserProfileProvider, (_, next) {
      next.whenData((profile) => notifier._loadFromProfile(profile));
    });
    ref.read(currentUserProfileProvider).whenData(
          (profile) => notifier._loadFromProfile(profile),
        );
    return notifier;
  },
);
