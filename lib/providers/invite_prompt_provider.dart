import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/constants/app_strings.dart';
import '../core/widgets/invite_partner_sheet.dart';
import '../features/accountability/invite_share.dart';
import '../models/user_profile.dart';
import 'accountability_provider.dart';
import 'auth_provider.dart';

/// High-intent moments at which we may ask the user to invite a partner.
enum InviteTrigger {
  onboarding,
  perfectDay,
  streak3,
  streak7,
  streak30,
  streak60,
  streak100,
}

/// Coordinates accountability-partner invite prompts: decides eligibility,
/// shows the reusable sheet, and records "don't nag" state on the profile.
class InvitePromptController {
  final Ref _ref;
  InvitePromptController(this._ref);

  static const Duration _snoozeDuration = Duration(days: 3);

  String _key(InviteTrigger t) {
    switch (t) {
      case InviteTrigger.onboarding:
        return 'onboarding';
      case InviteTrigger.perfectDay:
        return 'perfect_day';
      case InviteTrigger.streak3:
        return 'streak_3';
      case InviteTrigger.streak7:
        return 'streak_7';
      case InviteTrigger.streak30:
        return 'streak_30';
      case InviteTrigger.streak60:
        return 'streak_60';
      case InviteTrigger.streak100:
        return 'streak_100';
    }
  }

  int? _streakDays(InviteTrigger t) {
    switch (t) {
      case InviteTrigger.streak3:
        return 3;
      case InviteTrigger.streak7:
        return 7;
      case InviteTrigger.streak30:
        return 30;
      case InviteTrigger.streak60:
        return 60;
      case InviteTrigger.streak100:
        return 100;
      default:
        return null;
    }
  }

  String _title(InviteTrigger t) {
    switch (t) {
      case InviteTrigger.onboarding:
        return AppStrings.invitePromptOnboardingTitle;
      case InviteTrigger.perfectDay:
        return AppStrings.invitePromptPerfectDayTitle;
      case InviteTrigger.streak3:
      case InviteTrigger.streak7:
      case InviteTrigger.streak30:
      case InviteTrigger.streak60:
      case InviteTrigger.streak100:
        return AppStrings.invitePromptStreakTitle(_streakDays(t)!);
    }
  }

  String _body(InviteTrigger t) {
    switch (t) {
      case InviteTrigger.onboarding:
        return AppStrings.invitePromptOnboardingBody;
      case InviteTrigger.perfectDay:
        return AppStrings.invitePromptPerfectDayBody;
      case InviteTrigger.streak3:
      case InviteTrigger.streak7:
      case InviteTrigger.streak30:
      case InviteTrigger.streak60:
      case InviteTrigger.streak100:
        return AppStrings.invitePromptStreakBody(_streakDays(t)!);
    }
  }

  /// Whether [trigger] is currently eligible to show for [profile].
  bool shouldShow(UserProfile profile, InviteTrigger trigger) {
    // Partner accounts can invite too — the loop propagates through them. They
    // only reach streak/perfect-day triggers after onboarding + building a
    // streak, so the same eligibility rules below apply uniformly.
    //
    // No "already has a partner" cap: each milestone fires at most once (via
    // invitePromptsShown), so engaged users are re-nudged to invite additional
    // partners as they hit higher streaks, without spamming.
    //
    // Onboarding trigger fires exactly at completion; the others require it done.
    if (trigger != InviteTrigger.onboarding && !profile.hasCompletedOnboarding) {
      return false;
    }
    if (profile.invitePromptsDismissed) return false;

    if (profile.invitePromptsShown.contains(_key(trigger))) return false;

    final snooze = profile.invitePromptSnoozedUntil;
    if (snooze != null && DateTime.now().isBefore(snooze)) return false;

    return true;
  }

  /// Shows the invite prompt for [trigger] if eligible, recording the outcome.
  Future<void> maybeShow(
    BuildContext context,
    InviteTrigger trigger,
  ) async {
    final profile = _ref.read(currentUserProfileProvider).valueOrNull;
    if (profile == null || !shouldShow(profile, trigger)) return;

    // Record up-front so it never re-triggers, even if the user backgrounds.
    await _recordShown(profile, trigger);
    if (!context.mounted) return;

    final result = await showInvitePartnerSheet(
      context,
      title: _title(trigger),
      body: _body(trigger),
    );

    switch (result) {
      case InvitePromptResult.invited:
        if (context.mounted) {
          await shareInvite(context, _ref.read(accountabilityProvider.notifier));
        }
        break;
      case InvitePromptResult.notNow:
        await _snooze();
        break;
      case InvitePromptResult.dismissed:
        await _dismiss();
        break;
      case InvitePromptResult.none:
        break;
    }
  }

  Future<void> _recordShown(UserProfile profile, InviteTrigger trigger) async {
    final uid = _ref.read(authStateProvider).valueOrNull?.uid;
    if (uid == null) return;
    final updated = [...profile.invitePromptsShown, _key(trigger)];
    await _ref.read(firestoreServiceProvider).updateUserField(uid, {
      'invitePromptsShown': updated,
    });
  }

  Future<void> _snooze() async {
    final uid = _ref.read(authStateProvider).valueOrNull?.uid;
    if (uid == null) return;
    await _ref.read(firestoreServiceProvider).updateUserField(uid, {
      'invitePromptSnoozedUntil':
          DateTime.now().add(_snoozeDuration).toIso8601String(),
    });
  }

  Future<void> _dismiss() async {
    final uid = _ref.read(authStateProvider).valueOrNull?.uid;
    if (uid == null) return;
    await _ref.read(firestoreServiceProvider).updateUserField(uid, {
      'invitePromptsDismissed': true,
    });
  }
}

final invitePromptProvider = Provider<InvitePromptController>(
  (ref) => InvitePromptController(ref),
);
