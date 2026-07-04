import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/services/analytics_service.dart';
import '../models/habit.dart';
import '../models/user_profile.dart';
import 'auth_provider.dart';
import 'daily_completion_provider.dart';

class HabitsNotifier extends StateNotifier<List<Habit>> {
  final Ref _ref;

  HabitsNotifier(this._ref) : super([]);

  void _loadFromProfile(UserProfile? profile) {
    if (profile != null) {
      state = profile.habits;
      _syncDailyCompletion();
    }
  }

  void _syncDailyCompletion() {
    final active = state.where((h) => h.state == 'active').toList();
    final allDone = active.isEmpty || active.every((h) => h.isCompletedToday);
    final current = _ref.read(dailyCompletionProvider).habitsCompleted;
    if (allDone != current) {
      _ref.read(dailyCompletionProvider.notifier).toggle('habitsCompleted', allDone);
    }
  }

  Future<void> _persist(List<Habit> habits) async {
    final uid = _ref.read(authStateProvider).valueOrNull?.uid;
    if (uid == null) return;
    try {
      await _ref.read(firestoreServiceProvider).updateUserField(uid, {
        'habits': habits.map((h) => h.toJson()).toList(),
      });
    } catch (e) {
      debugPrint('HabitsNotifier._persist failed: $e');
      rethrow;
    }
  }

  Future<void> addHabit(Habit habit) async {
    final previous = state;
    final updated = [...state, habit];
    state = updated;
    _syncDailyCompletion();
    try {
      await _persist(updated);
    } catch (_) {
      state = previous;
      _syncDailyCompletion();
    }
  }

  Future<void> updateHabit(Habit habit) async {
    final previous = state;
    final updated = state.map((h) => h.id == habit.id ? habit : h).toList();
    state = updated;
    _syncDailyCompletion();
    try {
      await _persist(updated);
    } catch (_) {
      state = previous;
      _syncDailyCompletion();
    }
  }

  Future<void> deleteHabit(String habitId) async {
    final previous = state;
    final updated = state.where((h) => h.id != habitId).toList();
    state = updated;
    _syncDailyCompletion();
    try {
      await _persist(updated);
    } catch (_) {
      state = previous;
      _syncDailyCompletion();
    }
  }

  Future<void> completeHabit(String habitId) async {
    final now = DateTime.now();
    final habit = state.firstWhere((h) => h.id == habitId);
    if (habit.isCompletedToday) return;

    final updated = habit.copyWith(
      lastCompletedDate: now,
      completionHistory: [...habit.completionHistory, now],
    );
    await updateHabit(updated);

    // Count how many active habits are done after this check-in.
    final active = state.where((h) => h.state == 'active').toList();
    final checkedCount = active.where((h) => h.isCompletedToday).length;
    _ref.read(analyticsServiceProvider).trackHabitCheckedIn(
          habitsChecked: checkedCount,
          habitsTotal: active.length,
          allComplete: checkedCount == active.length,
        );
  }

  Future<void> toggleState(String habitId, String newState) async {
    final habit = state.firstWhere((h) => h.id == habitId);
    await updateHabit(habit.copyWith(state: newState));
  }

  /// Reorders the active habits list (drag-and-drop on the Habits tab).
  /// Paused habits keep their existing relative order and are simply
  /// appended after the reordered active ones, matching the active-first
  /// section layout the UI renders.
  Future<void> reorderActive(int oldIndex, int newIndex) async {
    final active = activeHabits;
    final paused = pausedHabits;
    if (oldIndex < 0 ||
        oldIndex >= active.length ||
        newIndex < 0 ||
        newIndex > active.length) {
      return;
    }

    final reordered = List<Habit>.from(active);
    final item = reordered.removeAt(oldIndex);
    reordered.insert(newIndex.clamp(0, reordered.length), item);

    final previous = state;
    final updated = [...reordered, ...paused];
    state = updated;
    try {
      await _persist(updated);
    } catch (e) {
      debugPrint('HabitsNotifier.reorderActive failed: $e');
      state = previous;
    }
  }

  List<Habit> get activeHabits =>
      state.where((h) => h.state == 'active').toList();

  List<Habit> get pausedHabits =>
      state.where((h) => h.state != 'active').toList();
}

final habitsProvider = StateNotifierProvider<HabitsNotifier, List<Habit>>(
  (ref) {
    final notifier = HabitsNotifier(ref);
    ref.listen(currentUserProfileProvider, (_, next) {
      next.whenData((profile) => notifier._loadFromProfile(profile));
    });
    ref.read(currentUserProfileProvider).whenData(
          (profile) => notifier._loadFromProfile(profile),
        );
    return notifier;
  },
);
