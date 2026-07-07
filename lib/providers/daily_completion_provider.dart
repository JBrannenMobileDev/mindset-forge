import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/services/analytics_service.dart';
import '../core/utils/app_date_utils.dart';
import '../models/daily_completion.dart';
import 'auth_provider.dart';

class DailyCompletionNotifier extends StateNotifier<DailyCompletion> {
  final Ref _ref;

  DailyCompletionNotifier(this._ref)
      : super(DailyCompletion(date: AppDateUtils.todayStringWithGracePeriod()));

  @override
  bool updateShouldNotify(DailyCompletion old, DailyCompletion current) =>
      old != current;

  void _initFromProfile() {
    final profile = _ref.read(currentUserProfileProvider).valueOrNull;
    if (profile != null) {
      // Use the 4 AM–4 AM "active day" so the checklist keeps the prior day's
      // progress during the midnight–4 AM grace window instead of resetting.
      final today = AppDateUtils.todayStringWithGracePeriod();
      final fromProfile = profile.dailyCompletions.firstWhere(
        (c) => c.date == today,
        orElse: () => DailyCompletion(date: today),
      );
      // Ignore stale/out-of-order Firestore snapshots that would regress today's
      // progress — a lost-update race on the dailyCompletions array can briefly
      // look less complete than what we've already applied locally.
      if (fromProfile.date == state.date &&
          fromProfile.completedCount < state.completedCount) {
        return;
      }
      state = fromProfile;
    }
  }

  /// Optimistically applies a daily win toggle and fires analytics. Returns the
  /// updated [DailyCompletion], or null if the field was already [value].
  DailyCompletion? applyFieldUpdate(String field, bool value) {
    final previous = state;
    final wasComplete = _fieldValue(field);
    if (value == wasComplete) return null;

    final times = Map<String, String>.from(state.completionTimes);
    if (value) {
      times[field] = DateTime.now().toIso8601String();
    } else {
      times.remove(field);
    }
    final updated = _applyField(field, value).copyWith(completionTimes: times);
    state = updated;

    if (value && !wasComplete) {
      _trackCompletionAnalytics(field, previous, updated);
    }
    return updated;
  }

  /// Merges [completion] into a profile's daily completions list for persistence.
  static List<DailyCompletion> mergeIntoProfileList(
    List<DailyCompletion> profileCompletions,
    DailyCompletion completion,
  ) {
    final completions = [...profileCompletions];
    final idx = completions.indexWhere((c) => c.date == completion.date);
    if (idx >= 0) {
      completions[idx] = completion;
    } else {
      completions.add(completion);
    }
    return completions;
  }

  Future<void> toggle(String field, bool value) async {
    final updated = applyFieldUpdate(field, value);
    if (updated == null) return;
    await _persist(updated);
  }

  void _trackCompletionAnalytics(
    String field,
    DailyCompletion previous,
    DailyCompletion updated,
  ) {
    final analytics = _ref.read(analyticsServiceProvider);
    analytics.trackDailyWinCompleted(field);
    if (field == 'gratitudeLogged') analytics.trackGratitudeLogged();
    if (field == 'evidenceLogged') analytics.trackEvidenceLogged();
    _checkPerfectDay(previous, updated, analytics);
    _checkStreakMilestone(analytics);
  }

  bool _fieldValue(String field) {
    return switch (field) {
      'habitsCompleted' => state.habitsCompleted,
      'dayPlanned' => state.dayPlanned,
      'focusCompleted' => state.focusCompleted,
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

  void _checkPerfectDay(
    DailyCompletion previous,
    DailyCompletion updated,
    AnalyticsService analytics,
  ) {
    if (!updated.isPerfectDay) return;
    if (previous.isPerfectDay) return;
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
      case 'focusCompleted':
        return state.copyWith(focusCompleted: value);
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

    final completions =
        mergeIntoProfileList(profile.dailyCompletions, completion);

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
