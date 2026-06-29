import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/services/analytics_service.dart';
import '../core/utils/app_date_utils.dart';
import '../models/daily_completion.dart';
import 'auth_provider.dart';

class DailyCompletionNotifier extends StateNotifier<DailyCompletion> {
  final Ref _ref;

  DailyCompletionNotifier(this._ref)
      : super(DailyCompletion(date: AppDateUtils.todayStringWithGracePeriod()));

  void _initFromProfile() {
    final profile = _ref.read(currentUserProfileProvider).valueOrNull;
    if (profile != null) {
      // Use the 4 AM–4 AM "active day" so the checklist keeps the prior day's
      // progress during the midnight–4 AM grace window instead of resetting.
      final today = AppDateUtils.todayStringWithGracePeriod();
      state = profile.dailyCompletions.firstWhere(
        (c) => c.date == today,
        orElse: () => DailyCompletion(date: today),
      );
    }
  }

  Future<void> toggle(String field, bool value) async {
    final wasComplete = _fieldValue(field);
    final times = Map<String, String>.from(state.completionTimes);
    if (value) {
      times[field] = DateTime.now().toIso8601String();
    } else {
      times.remove(field);
    }
    final updated = _applyField(field, value).copyWith(completionTimes: times);
    state = updated;
    await _persist(updated);

    // Only fire when flipping to true for the first time.
    if (value && !wasComplete) {
      final analytics = _ref.read(analyticsServiceProvider);
      analytics.trackDailyWinCompleted(field);
      if (field == 'gratitudeLogged') analytics.trackGratitudeLogged();
      if (field == 'evidenceLogged') analytics.trackEvidenceLogged();
      _checkPerfectDay(updated, analytics);
      _checkStreakMilestone(analytics);
    }
  }

  bool _fieldValue(String field) {
    return switch (field) {
      'habitsCompleted' => state.habitsCompleted,
      'dayPlanned' => state.dayPlanned,
      'priorityActionsCompleted' => state.priorityActionsCompleted,
      'affirmationsMorning' => state.affirmationsMorning,
      'affirmationsEvening' => state.affirmationsEvening,
      'futureSelfCompleted' => state.futureSelfCompleted,
      'journalCompleted' => state.journalCompleted,
      'chatCompleted' => state.chatCompleted,
      'identityRead' => state.identityRead,
      'gratitudeLogged' => state.gratitudeLogged,
      'evidenceLogged' => state.evidenceLogged,
      _ => false,
    };
  }

  void _checkPerfectDay(DailyCompletion updated, AnalyticsService analytics) {
    if (!updated.isPerfectDay) return;
    // Only fire once per day — if it was already a perfect day before this
    // toggle, we already fired.
    final wasAlreadyPerfect = state.isPerfectDay;
    if (wasAlreadyPerfect) return;
    final profile = _ref.read(currentUserProfileProvider).valueOrNull;
    analytics.trackPerfectDayAchieved(profile?.currentStreak ?? 0);
  }

  static const _streakMilestones = {3, 7, 14, 30};

  void _checkStreakMilestone(AnalyticsService analytics) {
    final profile = _ref.read(currentUserProfileProvider).valueOrNull;
    if (profile == null) return;
    final streak = profile.currentStreak;
    if (_streakMilestones.contains(streak)) {
      analytics.trackStreakMilestoneReached(streak);
    }
  }

  DailyCompletion _applyField(String field, bool value) {
    switch (field) {
      case 'habitsCompleted':
        return state.copyWith(habitsCompleted: value);
      case 'dayPlanned':
        return state.copyWith(dayPlanned: value);
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
