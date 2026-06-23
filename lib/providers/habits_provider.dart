import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/habit.dart';
import '../models/user_profile.dart';
import 'auth_provider.dart';

class HabitsNotifier extends StateNotifier<List<Habit>> {
  final Ref _ref;

  HabitsNotifier(this._ref) : super([]);

  void _loadFromProfile(UserProfile? profile) {
    if (profile != null) state = profile.habits;
  }

  Future<void> _persist(List<Habit> habits) async {
    final uid = _ref.read(authStateProvider).valueOrNull?.uid;
    if (uid == null) return;
    await _ref.read(firestoreServiceProvider).updateUserField(uid, {
      'habits': habits.map((h) => h.toJson()).toList(),
    });
  }

  Future<void> addHabit(Habit habit) async {
    final updated = [...state, habit];
    state = updated;
    await _persist(updated);
  }

  Future<void> updateHabit(Habit habit) async {
    final updated = state.map((h) => h.id == habit.id ? habit : h).toList();
    state = updated;
    await _persist(updated);
  }

  Future<void> deleteHabit(String habitId) async {
    final updated = state.where((h) => h.id != habitId).toList();
    state = updated;
    await _persist(updated);
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
  }

  Future<void> toggleState(String habitId, String newState) async {
    final habit = state.firstWhere((h) => h.id == habitId);
    await updateHabit(habit.copyWith(state: newState));
  }

  List<Habit> get activeHabits =>
      state.where((h) => h.state == 'active').toList();
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
