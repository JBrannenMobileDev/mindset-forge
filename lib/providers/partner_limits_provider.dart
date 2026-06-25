import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/user_profile.dart';
import '../core/widgets/partner_upgrade_sheet.dart';
import 'auth_provider.dart';

/// Limited app features a free "partner" account can sample before upgrading.
enum PartnerFeature { chat, journal, goal }

/// Weekly usage limits for free partner accounts (mirrors the conversion model
/// of the reference app). Goals are capped as a lifetime total, the others reset
/// every week.
class PartnerLimits {
  PartnerLimits._();

  static const int chatMessagesPerWeek = 3;
  static const int journalEntriesPerWeek = 1;
  static const int goalsTotal = 1;

  static int limitFor(PartnerFeature f) {
    switch (f) {
      case PartnerFeature.chat:
        return chatMessagesPerWeek;
      case PartnerFeature.journal:
        return journalEntriesPerWeek;
      case PartnerFeature.goal:
        return goalsTotal;
    }
  }

  static String label(PartnerFeature f) {
    switch (f) {
      case PartnerFeature.chat:
        return 'AI coaching';
      case PartnerFeature.journal:
        return 'journaling';
      case PartnerFeature.goal:
        return 'goal tracking';
    }
  }
}

/// Controller that checks and consumes partner usage. Non-partner accounts are
/// always allowed and never consume anything.
class PartnerLimitsController {
  final Ref _ref;
  PartnerLimitsController(this._ref);

  static String _currentWeekStart() {
    final now = DateTime.now();
    final monday = now.subtract(Duration(days: now.weekday - 1));
    return '${monday.year}-${monday.month.toString().padLeft(2, '0')}-${monday.day.toString().padLeft(2, '0')}';
  }

  String _usageKey(PartnerFeature f) =>
      f == PartnerFeature.journal ? 'journalEntries' : 'chatMessages';

  /// How many uses the partner has consumed this week for [f].
  int used(UserProfile profile, PartnerFeature f) {
    if (f == PartnerFeature.goal) return profile.goals.length;
    final usage = profile.partnerUsage;
    if (usage['weekStart'] != _currentWeekStart()) return 0;
    return (usage[_usageKey(f)] as num?)?.toInt() ?? 0;
  }

  int remaining(UserProfile profile, PartnerFeature f) =>
      (PartnerLimits.limitFor(f) - used(profile, f)).clamp(0, 1 << 30);

  bool canUse(UserProfile profile, PartnerFeature f) =>
      used(profile, f) < PartnerLimits.limitFor(f);

  /// Attempts to perform a limited action. Returns true if allowed (and records
  /// the usage for chat/journal). For non-partner accounts, always returns true.
  /// When blocked, shows the upgrade sheet.
  Future<bool> tryConsume(
    BuildContext context,
    PartnerFeature f,
  ) async {
    final profile = _ref.read(currentUserProfileProvider).valueOrNull;
    if (profile == null || !profile.isPartnerAccount) return true;

    // Partners must set up their own journey (real onboarding) before personal
    // features have the identity/goal context they need to work well.
    if (!profile.hasCompletedOnboarding) {
      showPartnerSetupSheet(
        context,
        featureName: PartnerLimits.label(f),
        partnerName: profile.supportingPersonName,
      );
      return false;
    }

    if (!canUse(profile, f)) {
      showPartnerUpgradeSheet(
        context,
        featureName: PartnerLimits.label(f),
        partnerName: profile.supportingPersonName,
      );
      return false;
    }

    // Goals don't need a separate counter — the goal list length is the count.
    if (f != PartnerFeature.goal) {
      await _increment(profile, f);
    }
    return true;
  }

  Future<void> _increment(UserProfile profile, PartnerFeature f) async {
    final uid = _ref.read(authStateProvider).valueOrNull?.uid;
    if (uid == null) return;

    final week = _currentWeekStart();
    final current = profile.partnerUsage['weekStart'] == week
        ? Map<String, dynamic>.from(profile.partnerUsage)
        : <String, dynamic>{'weekStart': week, 'chatMessages': 0, 'journalEntries': 0};

    final key = _usageKey(f);
    current[key] = ((current[key] as num?)?.toInt() ?? 0) + 1;
    current['weekStart'] = week;

    await _ref.read(firestoreServiceProvider).updateUserField(uid, {
      'partnerUsage': current,
    });
  }
}

final partnerLimitsProvider = Provider<PartnerLimitsController>(
  (ref) => PartnerLimitsController(ref),
);
