import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mixpanel_flutter/mixpanel_flutter.dart';
import '../../models/user_profile.dart';

/// Single point of all Mixpanel calls. No widget or notifier touches the
/// Mixpanel SDK directly.
///
/// The underlying [_mp] instance is static so all provider instances share one
/// initialized SDK client. Call [AnalyticsService.init] once in [main] before
/// [ProviderScope] is mounted.
class AnalyticsService {
  static Mixpanel? _mp;

  // ─── Initialisation ─────────────────────────────────────────────────────────

  static Future<void> init(String token) async {
    if (kIsWeb) return;
    try {
      _mp = await Mixpanel.init(token, trackAutomaticEvents: false);
      if (kDebugMode) _mp?.setLoggingEnabled(true);
      final platform = Platform.isIOS ? 'ios' : 'android';
      _mp?.registerSuperProperties({'platform': platform});
    } catch (e) {
      debugPrint('AnalyticsService.init failed: $e');
    }
  }

  // ─── Identity ───────────────────────────────────────────────────────────────

  void identify(String uid, UserProfile profile) {
    if (_mp == null) return;
    try {
      _mp!.identify(uid);
      final plan = profile.hasActiveSubscription ? 'premium' : 'free';
      _mp!.registerSuperProperties({
        'plan': plan,
        'onboarding_completed': profile.hasCompletedOnboarding,
      });
      final people = _mp!.getPeople();
      people.set('\$email', profile.email);
      people.set('\$created', profile.createdAt.toIso8601String());
      people.set('plan', plan);
      people.set(
          'goals_count', profile.goals.where((g) => g.status == 'active').length);
      people.set('active_habits_count',
          profile.habits.where((h) => h.state == 'active').length);
      people.set('has_partner',
          profile.accountabilityRelationships.any((r) => r.status == 'active'));
      people.set('current_streak', profile.currentStreak);
      people.set('perfect_days_total', profile.perfectDayCount);
      people.set('blueprint_completed', profile.blueprintCompleted);
    } catch (e) {
      debugPrint('AnalyticsService.identify failed: $e');
    }
  }

  void reset() {
    try {
      _mp?.reset();
    } catch (e) {
      debugPrint('AnalyticsService.reset failed: $e');
    }
  }

  // ─── Auth ───────────────────────────────────────────────────────────────────

  void trackSignUp() => _track('sign_up', {'method': 'email'});
  void trackLogIn() => _track('log_in', {'method': 'email'});
  void trackLogOut() => _track('log_out');

  // ─── Onboarding ─────────────────────────────────────────────────────────────

  static const _stepNames = [
    'welcome',
    'goals',
    'identity',
    'blocker',
    'ai_summary',
  ];

  void trackOnboardingStepCompleted(int stepIndex) {
    final name =
        stepIndex < _stepNames.length ? _stepNames[stepIndex] : 'unknown';
    _track('onboarding_step_completed', {
      'step': stepIndex + 1,
      'step_name': name,
    });
  }

  void trackOnboardingCompleted({
    required int goalsCount,
    required bool hasIdentityStatement,
  }) {
    _track('onboarding_completed', {
      'goals_count': goalsCount,
      'has_identity_statement': hasIdentityStatement,
    });
  }

  // ─── Monetisation ───────────────────────────────────────────────────────────

  void trackPaywallViewed({required String source}) =>
      _track('paywall_viewed', {'source': source});

  void trackSubscriptionStarted({
    required String plan,
    required double priceUsd,
  }) =>
      _track('subscription_started', {'plan': plan, 'price_usd': priceUsd});

  void trackSubscriptionRestored() => _track('subscription_restored');

  // ─── Daily Loop & Retention ─────────────────────────────────────────────────

  void trackDailyWinCompleted(String winType) =>
      _track('daily_win_completed', {'win_type': winType});

  void trackPerfectDayAchieved(int streakDays) =>
      _track('perfect_day_achieved', {'streak_days': streakDays});

  void trackStreakMilestoneReached(int days) =>
      _track('streak_milestone_reached', {'days': days});

  // ─── Feature Engagement ─────────────────────────────────────────────────────

  void trackAffirmationSessionCompleted({
    required String sessionType,
    required int affirmationCount,
  }) =>
      _track('affirmation_session_completed', {
        'session_type': sessionType,
        'affirmation_count': affirmationCount,
      });

  void trackJournalEntrySaved({
    required String mode,
    required int wordCount,
    required bool hasTags,
  }) =>
      _track('journal_entry_saved', {
        'mode': mode,
        'word_count': wordCount,
        'has_tags': hasTags,
      });

  void trackCoachMessageSent({
    required String mode,
    required int sessionLength,
  }) =>
      _track('coach_message_sent', {
        'mode': mode,
        'session_length': sessionLength,
      });

  void trackHabitCheckedIn({
    required int habitsChecked,
    required int habitsTotal,
    required bool allComplete,
  }) =>
      _track('habit_checked_in', {
        'habits_checked': habitsChecked,
        'habits_total': habitsTotal,
        'all_complete': allComplete,
      });

  void trackGoalCreated({required bool usedAiBreakdown}) =>
      _track('goal_created', {'used_ai_breakdown': usedAiBreakdown});

  void trackGoalCompleted() => _track('goal_completed');

  void trackFutureSelfSessionCompleted(int durationSeconds) =>
      _track('future_self_session_completed', {
        'duration_seconds': durationSeconds,
      });

  void trackBlueprintCompleted() => _track('blueprint_completed');

  void trackDeepDiveModuleCompleted(String module) =>
      _track('deep_dive_module_completed', {'module': module});

  void trackPriorityActionsSet({
    required int actionCount,
    required bool usedAi,
  }) =>
      _track('priority_actions_set', {
        'action_count': actionCount,
        'used_ai': usedAi,
      });

  void trackGratitudeLogged() => _track('gratitude_logged');
  void trackEvidenceLogged() => _track('evidence_logged');

  // ─── Virality ───────────────────────────────────────────────────────────────

  void trackPartnerInviteSent() => _track('partner_invite_sent');
  void trackPartnerInviteAccepted() => _track('partner_invite_accepted');
  void trackEncouragementSent() => _track('encouragement_sent');

  // ─── AI Usage ───────────────────────────────────────────────────────────────

  void trackAiFeatureUsed(String feature) =>
      _track('ai_feature_used', {'feature': feature});

  // ─── Internal ───────────────────────────────────────────────────────────────

  void _track(String event, [Map<String, dynamic>? properties]) {
    if (_mp == null) return;
    try {
      _mp!.track(event, properties: properties);
    } catch (e) {
      debugPrint('AnalyticsService.track($event) failed: $e');
    }
  }
}

final analyticsServiceProvider =
    Provider<AnalyticsService>((_) => AnalyticsService());
