import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/services/analytics_service.dart';
import '../models/action_step.dart';
import '../models/goal.dart';
import '../models/user_profile.dart';
import 'auth_provider.dart';

class GoalsNotifier extends StateNotifier<List<Goal>> {
  final Ref _ref;

  /// Guards the one-shot child-goal → checklist migration so the profile-stream
  /// re-trigger its persist causes doesn't kick off a second migration.
  bool _migrating = false;

  GoalsNotifier(this._ref) : super([]);

  void _loadFromProfile(UserProfile? profile) {
    if (profile == null) {
      state = [];
      return;
    }
    final goals = profile.goals;
    if (!_migrating && _needsMigration(goals)) {
      _migrateChildGoals(goals);
      return;
    }
    state = goals;
  }

  /// True when any goal is a child (has a [parentGoalId]) whose parent is still
  /// present — i.e. legacy hierarchy that should be folded into a checklist.
  bool _needsMigration(List<Goal> goals) {
    final ids = goals.map((g) => g.id).toSet();
    return goals
        .any((g) => g.parentGoalId != null && ids.contains(g.parentGoalId));
  }

  /// One-time migration: fold each child goal into its parent's milestone
  /// checklist, then drop the children. Orphan children (parent no longer
  /// present) are kept as standalone goals so no data is lost. Persists once,
  /// guarded by [_migrating].
  Future<void> _migrateChildGoals(List<Goal> goals) async {
    _migrating = true;

    final byId = {for (final g in goals) g.id: g};
    final childrenByParent = <String, List<Goal>>{};
    for (final g in goals) {
      final pid = g.parentGoalId;
      if (pid != null && byId.containsKey(pid)) {
        childrenByParent.putIfAbsent(pid, () => []).add(g);
      }
    }

    final migrated = <Goal>[];
    for (final g in goals) {
      final pid = g.parentGoalId;
      // Real child — folded into its parent's steps below; skip here.
      if (pid != null && byId.containsKey(pid)) continue;

      final kids = childrenByParent[g.id];
      if (kids == null || kids.isEmpty) {
        // Top-level goal with no children, or an orphan — keep as-is.
        migrated.add(g);
        continue;
      }

      kids.sort((a, b) => a.createdAt.compareTo(b.createdAt));
      final steps = <ActionStep>[...g.actionSteps];
      var order = steps.length;
      for (final k in kids) {
        steps.add(ActionStep(
          id: k.id,
          title: k.title,
          description: k.description,
          order: order++,
          targetDate: k.targetDate,
          isCompleted: k.status == 'completed',
          completedAt: k.completedAt,
        ));
      }
      migrated.add(_withRecomputedProgress(g, steps));
    }

    state = migrated;
    try {
      await _persist(migrated);
    } catch (e) {
      debugPrint('GoalsNotifier._migrateChildGoals failed: $e');
    } finally {
      _migrating = false;
    }
  }

  Future<void> _persist(List<Goal> goals) async {
    final uid = _ref.read(authStateProvider).valueOrNull?.uid;
    if (uid == null) return;
    try {
      await _ref.read(firestoreServiceProvider).updateUserField(uid, {
        'goals': goals.map((g) => g.toJson()).toList(),
      });
    } catch (e) {
      debugPrint('GoalsNotifier._persist failed: $e');
      rethrow;
    }
  }

  /// Returns [goal] with its steps replaced and [progressPercent] recomputed
  /// from the checklist (100 × completed / total). Leaves progress untouched
  /// when there are no steps.
  Goal _withRecomputedProgress(Goal goal, List<ActionStep> steps) {
    final progress = steps.isEmpty
        ? goal.progressPercent
        : steps.where((s) => s.isCompleted).length / steps.length * 100;
    return goal.copyWith(actionSteps: steps, progressPercent: progress);
  }

  Future<void> addGoal(Goal goal, {bool usedAiBreakdown = false}) async {
    final previous = state;
    final updated = [...state, goal];
    state = updated;
    try {
      await _persist(updated);
      _ref
          .read(analyticsServiceProvider)
          .trackGoalCreated(usedAiBreakdown: usedAiBreakdown);
    } catch (_) {
      state = previous;
    }
  }

  Future<void> updateGoal(Goal goal) async {
    final previous = state;
    final updated = state.map((g) => g.id == goal.id ? goal : g).toList();
    state = updated;
    try {
      await _persist(updated);
    } catch (_) {
      state = previous;
    }
  }

  Future<void> deleteGoal(String goalId) async {
    final previous = state;
    final updated = state.where((g) => g.id != goalId).toList();
    state = updated;
    try {
      await _persist(updated);
    } catch (_) {
      state = previous;
    }
  }

  Goal _requireGoal(String goalId) => state.firstWhere(
        (g) => g.id == goalId,
        orElse: () => throw StateError('Goal $goalId not found'),
      );

  /// Append a new milestone to a goal's checklist and recompute progress.
  Future<void> addStep(String goalId, ActionStep step) async {
    final goal = _requireGoal(goalId);
    final steps = [
      ...goal.actionSteps,
      step.copyWith(order: goal.actionSteps.length),
    ];
    await updateGoal(_withRecomputedProgress(goal, steps));
  }

  /// Replace an existing milestone (matched by id) in place.
  Future<void> editStep(String goalId, ActionStep step) async {
    final goal = _requireGoal(goalId);
    final steps =
        goal.actionSteps.map((s) => s.id == step.id ? step : s).toList();
    await updateGoal(_withRecomputedProgress(goal, steps));
  }

  /// Remove a milestone and re-normalize the remaining order indices.
  Future<void> removeStep(String goalId, String stepId) async {
    final goal = _requireGoal(goalId);
    final remaining = goal.actionSteps.where((s) => s.id != stepId).toList();
    final steps = [
      for (var i = 0; i < remaining.length; i++) remaining[i].copyWith(order: i),
    ];
    await updateGoal(_withRecomputedProgress(goal, steps));
  }

  /// Reorder the checklist. Indices refer to the goal's ordered step list.
  Future<void> reorderSteps(String goalId, int oldIndex, int newIndex) async {
    final goal = _requireGoal(goalId);
    final list = [...goal.actionSteps];
    if (oldIndex < 0 || oldIndex >= list.length) return;
    if (newIndex > oldIndex) newIndex--;
    final item = list.removeAt(oldIndex);
    list.insert(newIndex.clamp(0, list.length), item);
    final steps = [
      for (var i = 0; i < list.length; i++) list[i].copyWith(order: i),
    ];
    await updateGoal(goal.copyWith(actionSteps: steps));
  }

  /// Toggle a single milestone's completion and recompute the goal's progress
  /// from the proportion of completed steps.
  Future<void> toggleActionStep(String goalId, String stepId) async {
    final goal = _requireGoal(goalId);

    final steps = goal.actionSteps.map((s) {
      if (s.id != stepId) return s;
      final nowDone = !s.isCompleted;
      return s.copyWith(
        isCompleted: nowDone,
        completedAt: nowDone ? DateTime.now() : null,
      );
    }).toList();

    await updateGoal(_withRecomputedProgress(goal, steps));
  }

  /// Manually sets a goal's progress (0-100). Used by the detail-screen slider
  /// for goals without a milestone checklist. Clamps to valid range.
  Future<void> setProgress(String goalId, double percent) async {
    final goal = _requireGoal(goalId);
    await updateGoal(goal.copyWith(progressPercent: percent.clamp(0.0, 100.0)));
  }

  Future<void> completeGoal(String goalId) async {
    final goal = _requireGoal(goalId);
    await updateGoal(goal.copyWith(
      status: 'completed',
      progressPercent: 100.0,
      completedAt: DateTime.now(),
    ));
    _ref.read(analyticsServiceProvider).trackGoalCompleted();
  }

  /// Designate a goal as the user's North Star (their #1 focus). Persisted on
  /// the profile's `primaryGoalId`; state refreshes from the profile stream.
  Future<void> setPrimaryGoal(String goalId) async {
    final uid = _ref.read(authStateProvider).valueOrNull?.uid;
    if (uid == null) return;
    try {
      await _ref.read(firestoreServiceProvider).updateUserField(uid, {
        'primaryGoalId': goalId,
      });
    } catch (e) {
      debugPrint('GoalsNotifier.setPrimaryGoal failed: $e');
    }
  }

  List<Goal> get activeGoals =>
      state.where((g) => g.status == 'active').toList();

  List<Goal> get completedGoals =>
      state.where((g) => g.status == 'completed').toList();
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
