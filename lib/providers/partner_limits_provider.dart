import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/user_profile.dart';
import '../core/widgets/partner_upgrade_sheet.dart';
import 'auth_provider.dart';

/// Limited app features a free "partner" account can sample before upgrading.
enum PartnerFeature { chat, journal, goal, habit, affirmation }

/// Usage limits for free partner accounts *after* their gifted premium window
/// lapses. Principle: meter what costs us money (AI coaching), cap the daily
/// ritual features enough to create loss aversion without killing the habit.
/// Chat and journal reset weekly; goals, habits, and affirmations are lifetime
/// totals (first-N by createdAt stay active, extras are locked in the UI).
class PartnerLimits {
  PartnerLimits._();

  static const int chatMessagesPerWeek = 5;
  static const int journalEntriesPerWeek = 3;
  static const int goalsTotal = 1;
  static const int habitsActive = 2;
  static const int affirmationsActive = 3;

  static bool isCountBased(PartnerFeature f) =>
      f == PartnerFeature.goal ||
      f == PartnerFeature.habit ||
      f == PartnerFeature.affirmation;

  static int limitFor(PartnerFeature f) {
    switch (f) {
      case PartnerFeature.chat:
        return chatMessagesPerWeek;
      case PartnerFeature.journal:
        return journalEntriesPerWeek;
      case PartnerFeature.goal:
        return goalsTotal;
      case PartnerFeature.habit:
        return habitsActive;
      case PartnerFeature.affirmation:
        return affirmationsActive;
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
      case PartnerFeature.habit:
        return 'habit tracking';
      case PartnerFeature.affirmation:
        return 'affirmations';
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

  String? _usageKey(PartnerFeature f) {
    switch (f) {
      case PartnerFeature.chat:
        return 'chatMessages';
      case PartnerFeature.journal:
        return 'journalEntries';
      default:
        return null;
    }
  }

  /// Whether lock/usage rules apply to this profile (post-window partner only).
  bool _isLimitedPartner(UserProfile profile) =>
      profile.isPartnerAccount &&
      !profile.hasGiftedPremium &&
      !profile.hasActiveSubscription;

  /// How many uses the partner has consumed this week for [f], or total count
  /// for count-based features.
  int used(UserProfile profile, PartnerFeature f) {
    switch (f) {
      case PartnerFeature.goal:
        return profile.goals.length;
      case PartnerFeature.habit:
        return profile.habits.length;
      case PartnerFeature.affirmation:
        return profile.affirmations.length;
      case PartnerFeature.chat:
      case PartnerFeature.journal:
        final usage = profile.partnerUsage;
        if (usage['weekStart'] != _currentWeekStart()) return 0;
        final key = _usageKey(f);
        return (usage[key] as num?)?.toInt() ?? 0;
    }
  }

  int remaining(UserProfile profile, PartnerFeature f) {
    final limit = PartnerLimits.limitFor(f);
    return (limit - used(profile, f)).clamp(0, 1 << 30);
  }

  bool canUse(UserProfile profile, PartnerFeature f) =>
      used(profile, f) < PartnerLimits.limitFor(f);

  /// Ids of items beyond the cap for a post-window partner (first-N by
  /// [createdAt] stay active). Empty for gifted, subscribed, or non-partner
  /// accounts.
  Set<String> lockedIds(UserProfile profile, PartnerFeature f) {
    if (!_isLimitedPartner(profile)) return const {};

    final limit = PartnerLimits.limitFor(f);
    final items = _itemsForFeature(profile, f);
    if (items.length <= limit) return const {};

    final sorted = List<_LockableItem>.from(items)
      ..sort((a, b) {
        final cmp = a.createdAt.compareTo(b.createdAt);
        if (cmp != 0) return cmp;
        return a.id.compareTo(b.id);
      });

    return sorted.skip(limit).map((e) => e.id).toSet();
  }

  bool isLocked(UserProfile profile, PartnerFeature f, String id) =>
      lockedIds(profile, f).contains(id);

  List<_LockableItem> _itemsForFeature(UserProfile profile, PartnerFeature f) {
    switch (f) {
      case PartnerFeature.goal:
        return profile.goals
            .map((g) => _LockableItem(id: g.id, createdAt: g.createdAt))
            .toList();
      case PartnerFeature.habit:
        return profile.habits
            .map((h) => _LockableItem(id: h.id, createdAt: h.createdAt))
            .toList();
      case PartnerFeature.affirmation:
        return profile.affirmations
            .map((a) => _LockableItem(id: a.id, createdAt: a.createdAt))
            .toList();
      default:
        return const [];
    }
  }

  /// Attempts to perform a limited action. Returns true if allowed (and records
  /// the usage for chat/journal). For non-partner accounts, always returns true.
  /// When blocked, shows the upgrade sheet.
  Future<bool> tryConsume(
    BuildContext context,
    PartnerFeature f,
  ) async {
    final profile = _ref.read(currentUserProfileProvider).valueOrNull;
    if (profile == null || !profile.isPartnerAccount) return true;

    // During the gifted premium window the partner has full, unlimited access —
    // no onboarding gate, no usage caps. This is the habit-building runway.
    if (profile.hasGiftedPremium) return true;

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

    // Count-based features (goals, habits, affirmations) use list length as
    // the counter — no separate partnerUsage field. Only chat/journal increment.
    if (!PartnerLimits.isCountBased(f)) {
      await _increment(profile, f);
    }
    return true;
  }

  /// Shows the upgrade sheet when a locked item is tapped.
  void showLockedUpgrade(BuildContext context, PartnerFeature f) {
    final profile = _ref.read(currentUserProfileProvider).valueOrNull;
    showPartnerUpgradeSheet(
      context,
      featureName: PartnerLimits.label(f),
      partnerName: profile?.supportingPersonName,
    );
  }

  Future<void> _increment(UserProfile profile, PartnerFeature f) async {
    final uid = _ref.read(authStateProvider).valueOrNull?.uid;
    if (uid == null) return;

    final key = _usageKey(f);
    if (key == null) return;

    final week = _currentWeekStart();
    final current = profile.partnerUsage['weekStart'] == week
        ? Map<String, dynamic>.from(profile.partnerUsage)
        : <String, dynamic>{'weekStart': week, 'chatMessages': 0, 'journalEntries': 0};

    current[key] = ((current[key] as num?)?.toInt() ?? 0) + 1;
    current['weekStart'] = week;

    await _ref.read(firestoreServiceProvider).updateUserField(uid, {
      'partnerUsage': current,
    });
  }
}

class _LockableItem {
  final String id;
  final DateTime createdAt;
  const _LockableItem({required this.id, required this.createdAt});
}

final partnerLimitsProvider = Provider<PartnerLimitsController>(
  (ref) => PartnerLimitsController(ref),
);
