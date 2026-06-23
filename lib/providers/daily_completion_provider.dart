import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/daily_completion.dart';
import '../core/utils/app_date_utils.dart';
import 'auth_provider.dart';

class DailyCompletionNotifier extends StateNotifier<DailyCompletion> {
  final Ref _ref;

  DailyCompletionNotifier(this._ref)
      : super(DailyCompletion.forToday());

  void _initFromProfile() {
    final profile = _ref.read(currentUserProfileProvider).valueOrNull;
    if (profile != null) {
      final today = AppDateUtils.todayString();
      state = profile.dailyCompletions.firstWhere(
        (c) => c.date == today,
        orElse: DailyCompletion.forToday,
      );
    }
  }

  Future<void> toggle(String field, bool value) async {
    final updated = _applyField(field, value);
    state = updated;
    await _persist(updated);
  }

  DailyCompletion _applyField(String field, bool value) {
    switch (field) {
      case 'habitsCompleted':
        return state.copyWith(habitsCompleted: value);
      case 'priorityActionsCompleted':
        return state.copyWith(priorityActionsCompleted: value);
      case 'affirmationsMorning':
        return state.copyWith(affirmationsMorning: value);
      case 'affirmationsEvening':
        return state.copyWith(affirmationsEvening: value);
      case 'futureSelfCompleted':
        return state.copyWith(futureSelfCompleted: value);
      case 'journalCompleted':
        return state.copyWith(journalCompleted: value);
      case 'chatCompleted':
        return state.copyWith(chatCompleted: value);
      case 'identityRead':
        return state.copyWith(identityRead: value);
      case 'gratitudeLogged':
        return state.copyWith(gratitudeLogged: value);
      case 'evidenceLogged':
        return state.copyWith(evidenceLogged: value);
      default:
        return state;
    }
  }

  Future<void> _persist(DailyCompletion completion) async {
    final uid = _ref.read(authStateProvider).valueOrNull?.uid;
    if (uid == null) return;
    final profile = _ref.read(currentUserProfileProvider).valueOrNull;
    if (profile == null) return;

    // Build updated list from the in-memory profile — avoids a Firestore
    // round-trip read and the stale-cache race condition it creates.
    final completions = [...profile.dailyCompletions];
    final idx = completions.indexWhere((c) => c.date == completion.date);
    if (idx >= 0) {
      completions[idx] = completion;
    } else {
      completions.add(completion);
    }

    await _ref.read(firestoreServiceProvider).updateUserField(uid, {
      'dailyCompletions': completions.map((c) => c.toJson()).toList(),
    });
  }

  void refresh() => _initFromProfile();
}

final dailyCompletionProvider =
    StateNotifierProvider<DailyCompletionNotifier, DailyCompletion>(
  (ref) {
    final notifier = DailyCompletionNotifier(ref);
    // Eager init: if the profile is already loaded when this provider is first
    // accessed, ref.listen won't fire for the current value, so we seed it now.
    ref.read(currentUserProfileProvider).whenData((_) => notifier.refresh());
    // React to all future profile updates (e.g. after a Firestore write).
    ref.listen(currentUserProfileProvider, (_, next) {
      next.whenData((_) => notifier.refresh());
    });
    return notifier;
  },
);
