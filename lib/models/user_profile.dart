import 'mindset_blueprint.dart';
import 'goal.dart';
import 'habit.dart';
import 'affirmation.dart';
import 'daily_completion.dart';
import 'future_self_setup.dart';
import 'future_self_completion.dart';
import 'belief_pattern.dart';
import 'deep_dive.dart';
import 'evidence_entry.dart';
import 'gratitude_entry.dart';
import 'identity_read_log.dart';
import 'encouragement_message.dart';
import 'accountability_relationship.dart';
import 'journal_summary.dart';
import 'coach_memory.dart';
import 'notification_prefs.dart';
import 'weekly_insight.dart';
import 'blueprint_snapshot.dart';

class UserProfile {
  final String uid;
  final String email;
  final String displayName;
  final String userType;
  final String subscriptionStatus;
  final DateTime? subscriptionExpiresAt;
  final int onboardingStep;
  final MindsetBlueprint mindsetBlueprint;
  final MindsetBlueprint originalMindsetBaseline;
  final String identityStatement;
  final String identitySituation;
  final List<String> identityQualities;
  final List<IdentityReadLog> identityReadLog;
  final List<Goal> goals;

  /// Id of the goal the user marked as their #1 focus during onboarding. Empty
  /// when unset; downstream code falls back to the first active goal.
  final String primaryGoalId;
  final List<Habit> habits;
  final List<Affirmation> affirmations;
  final List<AffirmationCompletion> affirmationCompletions;
  final List<EvidenceEntry> evidenceLog;
  final List<GratitudeEntry> gratitudeLog;
  final List<DailyCompletion> dailyCompletions;
  final List<String> limitingBeliefs;
  final FutureSelfSetup? futureSelfSetup;
  final List<FutureSelfCompletion> futureSelfCompletions;
  final List<BeliefPattern> beliefPatternHistory;
  final DeepDive deepDive;
  final List<String> fearsDrift;
  final double mentalToughnessScore;
  /// Whether the user has finished the deferred, in-app mindset blueprint setup
  /// (trait sliders, mental toughness, fear quiz) after the lightweight onboarding.
  final bool blueprintCompleted;
  final String mindsetBlueprintSummary;
  final String? mindsetBlueprintSnapshotAt;
  final List<BlueprintSnapshot> blueprintSnapshotHistory;

  /// ISO timestamp when the 10-day behavioral calibration window began.
  final String? blueprintCalibrationStartedAt;

  /// ISO timestamp of the last automatic weekly AI blueprint recalculation.
  final String? blueprintLastRecalculatedAt;
  final Map<String, String> dailyWisdom;
  final List<String> priorityActions;
  final String priorityActionsDate;
  final String dailyFocusAction;
  final String dailyFocusActionDate;
  final List<String> completedPriorityActions;
  final String journalPreference; // 'morning' | 'evening' | 'both'
  final List<JournalSummary> recentJournalSummaries;
  final List<AccountabilityRelationship> accountabilityRelationships;
  final List<EncouragementMessage> encouragementMessages;
  final List<String> partnerUids;

  /// Weekly usage counters for free "partner" accounts (limited app access).
  /// Shape: { 'weekStart': 'yyyy-MM-dd', 'chatMessages': int, 'journalEntries': int }.
  final Map<String, dynamic> partnerUsage;

  /// Keys of accountability-partner invite prompts already shown (e.g.
  /// 'onboarding', 'perfect_day', 'streak_7') so each fires at most once.
  final List<String> invitePromptsShown;

  /// While set and in the future, suppresses invite prompts ("Not now" snooze).
  final DateTime? invitePromptSnoozedUntil;

  /// True once the user opts out of all invite prompts ("Don't ask again").
  final bool invitePromptsDismissed;

  /// True once the user has seen the home screen widget education prompt, so we
  /// stop nudging them in the Getting Started checklist and post-onboarding.
  final bool widgetPromptSeen;

  /// True once the user dismisses the affirmations intro/education card, so the
  /// "new to affirmations?" primer stops appearing on the Affirmations screen.
  final bool affirmationsIntroDismissed;
  final CoachMemory coachMemory;
  final DateTime? coachDisclaimerAcceptedAt;

  /// ISO timestamp when the user explicitly consented to their profile,
  /// journal, and chat data being sent to our third-party AI provider
  /// (Anthropic) to generate personalized coaching. Set once during
  /// onboarding, before any AI call is made.
  final DateTime? aiConsentAcceptedAt;
  final String? fcmToken;
  final DateTime? lastActiveAt;

  /// IANA timezone name of the user's device (e.g. 'America/Denver'). Captured
  /// on launch so server-side scheduled pushes can resolve the user's local
  /// time. Empty until first captured.
  final String timezone;

  /// User-controllable notification preferences (categories, reminder times,
  /// quiet hours, partner-slip consent).
  final NotificationPrefs notificationPrefs;

  /// Current structured weekly coaching review (generated Sunday cron or manual refresh).
  final WeeklyInsight? weeklyInsight;

  /// Prior weekly reviews, newest first (max 12).
  final List<WeeklyInsight> weeklyInsightHistory;

  final DateTime createdAt;

  const UserProfile({
    required this.uid,
    required this.email,
    required this.displayName,
    this.userType = 'user',
    this.subscriptionStatus = 'free',
    this.subscriptionExpiresAt,
    this.onboardingStep = 0,
    required this.mindsetBlueprint,
    required this.originalMindsetBaseline,
    this.identityStatement = '',
    this.identitySituation = '',
    this.identityQualities = const [],
    this.identityReadLog = const [],
    this.goals = const [],
    this.primaryGoalId = '',
    this.habits = const [],
    this.affirmations = const [],
    this.affirmationCompletions = const [],
    this.evidenceLog = const [],
    this.gratitudeLog = const [],
    this.dailyCompletions = const [],
    this.limitingBeliefs = const [],
    this.futureSelfSetup,
    this.futureSelfCompletions = const [],
    this.beliefPatternHistory = const [],
    required this.deepDive,
    this.fearsDrift = const [],
    this.mentalToughnessScore = 50.0,
    this.blueprintCompleted = false,
    this.mindsetBlueprintSummary = '',
    this.mindsetBlueprintSnapshotAt,
    this.blueprintSnapshotHistory = const [],
    this.blueprintCalibrationStartedAt,
    this.blueprintLastRecalculatedAt,
    this.dailyWisdom = const {},
    this.priorityActions = const [],
    this.priorityActionsDate = '',
    this.dailyFocusAction = '',
    this.dailyFocusActionDate = '',
    this.completedPriorityActions = const [],
    this.journalPreference = 'both',
    this.recentJournalSummaries = const [],
    this.accountabilityRelationships = const [],
    this.encouragementMessages = const [],
    this.partnerUids = const [],
    this.partnerUsage = const {},
    this.invitePromptsShown = const [],
    this.invitePromptSnoozedUntil,
    this.invitePromptsDismissed = false,
    this.widgetPromptSeen = false,
    this.affirmationsIntroDismissed = false,
    this.coachMemory = const CoachMemory(),
    this.coachDisclaimerAcceptedAt,
    this.aiConsentAcceptedAt,
    this.fcmToken,
    this.lastActiveAt,
    this.timezone = '',
    this.notificationPrefs = const NotificationPrefs(),
    this.weeklyInsight,
    this.weeklyInsightHistory = const [],
    required this.createdAt,
  });

  /// Whether the user has acknowledged the one-time coach disclaimer.
  bool get hasAcceptedCoachDisclaimer => coachDisclaimerAcceptedAt != null;

  /// Whether the user has explicitly consented to sending their data to our
  /// third-party AI provider (Anthropic) for personalized coaching.
  bool get hasAcceptedAiConsent => aiConsentAcceptedAt != null;

  /// True when a weekly review exists and the user has not opened it yet.
  bool get hasUnreadWeeklyInsight =>
      weeklyInsight != null && weeklyInsight!.isUnread;

  /// The #1 focus is complete iff it appears in the authoritative completed
  /// list. Single source of truth so the dashboard and Priorities tab can
  /// never disagree. Callers gate on "today" via [dailyFocusActionDate].
  bool get isDailyFocusComplete =>
      dailyFocusAction.isNotEmpty &&
      completedPriorityActions.contains(dailyFocusAction);

  /// A free "partner" account: limited app access, joined via an accountability
  /// partner invite, funneled toward starting their own subscription.
  bool get isPartnerAccount => userType == 'partner';

  /// A comped account: free, permanent full access granted manually (family,
  /// friends, partner coaches). Set `subscriptionStatus: 'lifetime'` on the
  /// user doc in Firestore to grant it.
  bool get isComped => subscriptionStatus == 'lifetime';

  /// True when the user has full, paid access (paying subscriber or in trial).
  // 'canceled' means auto-renew was turned off, not that access has ended —
  // the user keeps access until the period expires (status flips to 'expired'
  // via the webhook at that point). 'lifetime' is a manual comp grant that
  // never expires.
  bool get hasActiveSubscription =>
      subscriptionStatus == 'active' ||
      subscriptionStatus == 'trialing' ||
      subscriptionStatus == 'canceled' ||
      subscriptionStatus == 'lifetime';

  /// For a partner account, the name of the primary user they are supporting
  /// (used for social proof in upgrade prompts). Null if not applicable.
  String? get supportingPersonName {
    for (final r in accountabilityRelationships) {
      if (r.type == 'partner' && (r.primaryName ?? '').isNotEmpty) {
        return r.primaryName;
      }
    }
    return null;
  }

  /// Onboarding has 7 steps (0–6): Welcome, Goals Select, Goals Focus,
  /// Identity, AI Consent, Blocker, AI Analysis. It is only complete once
  /// [onboardingStep] reaches the total set on the final step. Deferred
  /// mindset data (blueprint, toughness, fears) is collected in-app afterwards
  /// and tracked separately via [blueprintCompleted].
  ///
  /// Legacy 5-step onboarding (pre-consent-step) stored completion as
  /// [onboardingStep] == 5 with a populated [mindsetBlueprintSummary]. The
  /// current flow also saves step index 6 mid-flow on the AI summary screen,
  /// but those users lack a summary until they finish.
  bool get hasCompletedOnboarding {
    if (onboardingStep >= 7) return true;
    if (onboardingStep == 5 && mindsetBlueprintSummary.isNotEmpty) return true;
    return false;
  }

  String get firstName =>
      displayName.isNotEmpty ? displayName.split(' ').first : 'there';

  DailyCompletion get todayCompletion {
    // Use the 4 AM–4 AM "active day" so late-night (midnight–4 AM) progress
    // stays attached to the prior day rather than resetting at midnight.
    final now = DateTime.now();
    final adjusted = now.hour < 4 ? now.subtract(const Duration(days: 1)) : now;
    final todayStr =
        '${adjusted.year}-${adjusted.month.toString().padLeft(2, '0')}-${adjusted.day.toString().padLeft(2, '0')}';
    return dailyCompletions.firstWhere(
      (c) => c.date == todayStr,
      orElse: () => DailyCompletion(date: todayStr),
    );
  }

  int get currentStreak {
    if (dailyCompletions.isEmpty) return 0;

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    // Day-precision dates that qualify for the streak (5+ of 8 required wins).
    final qualifying = <DateTime>{};
    for (final c in dailyCompletions) {
      if (!c.countsForStreak) continue;
      final parts = c.date.split('-');
      if (parts.length != 3) continue;
      qualifying.add(
        DateTime(int.parse(parts[0]), int.parse(parts[1]), int.parse(parts[2])),
      );
    }
    if (qualifying.isEmpty) return 0;

    // Today is a grace day: while it's still in progress (not yet qualifying),
    // anchor the streak at yesterday so an unfinished today doesn't read as a
    // broken streak. If the day ends without qualifying, today becomes
    // "yesterday" tomorrow and the streak resets then.
    DateTime cursor = qualifying.contains(today)
        ? today
        : today.subtract(const Duration(days: 1));

    int streak = 0;
    while (qualifying.contains(cursor)) {
      streak++;
      cursor = cursor.subtract(const Duration(days: 1));
    }
    return streak;
  }

  int get perfectDayCount =>
      dailyCompletions.where((c) => c.isPerfectDay).length;

  /// Consecutive run of perfect (9/9) days ending today, using the same
  /// midnight–4 AM grace rule as [currentStreak]: an in-progress today does not
  /// break the run — it anchors at yesterday until the day ends.
  int get perfectStreak {
    if (dailyCompletions.isEmpty) return 0;

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    final perfect = <DateTime>{};
    for (final c in dailyCompletions) {
      if (!c.isPerfectDay) continue;
      final parts = c.date.split('-');
      if (parts.length != 3) continue;
      perfect.add(
        DateTime(int.parse(parts[0]), int.parse(parts[1]), int.parse(parts[2])),
      );
    }
    if (perfect.isEmpty) return 0;

    DateTime cursor = perfect.contains(today)
        ? today
        : today.subtract(const Duration(days: 1));

    int streak = 0;
    while (perfect.contains(cursor)) {
      streak++;
      cursor = cursor.subtract(const Duration(days: 1));
    }
    return streak;
  }

  UserProfile copyWith({
    String? uid,
    String? email,
    String? displayName,
    String? userType,
    String? subscriptionStatus,
    DateTime? subscriptionExpiresAt,
    int? onboardingStep,
    MindsetBlueprint? mindsetBlueprint,
    MindsetBlueprint? originalMindsetBaseline,
    String? identityStatement,
    String? identitySituation,
    List<String>? identityQualities,
    List<IdentityReadLog>? identityReadLog,
    List<Goal>? goals,
    String? primaryGoalId,
    List<Habit>? habits,
    List<Affirmation>? affirmations,
    List<AffirmationCompletion>? affirmationCompletions,
    List<EvidenceEntry>? evidenceLog,
    List<GratitudeEntry>? gratitudeLog,
    List<DailyCompletion>? dailyCompletions,
    List<String>? limitingBeliefs,
    FutureSelfSetup? futureSelfSetup,
    List<FutureSelfCompletion>? futureSelfCompletions,
    List<BeliefPattern>? beliefPatternHistory,
    DeepDive? deepDive,
    List<String>? fearsDrift,
    double? mentalToughnessScore,
    bool? blueprintCompleted,
    String? mindsetBlueprintSummary,
    String? mindsetBlueprintSnapshotAt,
    List<BlueprintSnapshot>? blueprintSnapshotHistory,
    String? blueprintCalibrationStartedAt,
    String? blueprintLastRecalculatedAt,
    Map<String, String>? dailyWisdom,
    List<String>? priorityActions,
    String? priorityActionsDate,
    String? dailyFocusAction,
    String? dailyFocusActionDate,
    List<String>? completedPriorityActions,
    String? journalPreference,
    List<JournalSummary>? recentJournalSummaries,
    List<AccountabilityRelationship>? accountabilityRelationships,
    List<EncouragementMessage>? encouragementMessages,
    List<String>? partnerUids,
    Map<String, dynamic>? partnerUsage,
    List<String>? invitePromptsShown,
    DateTime? invitePromptSnoozedUntil,
    bool? invitePromptsDismissed,
    bool? widgetPromptSeen,
    bool? affirmationsIntroDismissed,
    CoachMemory? coachMemory,
    DateTime? coachDisclaimerAcceptedAt,
    DateTime? aiConsentAcceptedAt,
    String? fcmToken,
    DateTime? lastActiveAt,
    String? timezone,
    NotificationPrefs? notificationPrefs,
    WeeklyInsight? weeklyInsight,
    List<WeeklyInsight>? weeklyInsightHistory,
    DateTime? createdAt,
  }) {
    return UserProfile(
      uid: uid ?? this.uid,
      email: email ?? this.email,
      displayName: displayName ?? this.displayName,
      userType: userType ?? this.userType,
      subscriptionStatus: subscriptionStatus ?? this.subscriptionStatus,
      subscriptionExpiresAt:
          subscriptionExpiresAt ?? this.subscriptionExpiresAt,
      onboardingStep: onboardingStep ?? this.onboardingStep,
      mindsetBlueprint: mindsetBlueprint ?? this.mindsetBlueprint,
      originalMindsetBaseline:
          originalMindsetBaseline ?? this.originalMindsetBaseline,
      identityStatement: identityStatement ?? this.identityStatement,
      identitySituation: identitySituation ?? this.identitySituation,
      identityQualities: identityQualities ?? this.identityQualities,
      identityReadLog: identityReadLog ?? this.identityReadLog,
      goals: goals ?? this.goals,
      primaryGoalId: primaryGoalId ?? this.primaryGoalId,
      habits: habits ?? this.habits,
      affirmations: affirmations ?? this.affirmations,
      affirmationCompletions:
          affirmationCompletions ?? this.affirmationCompletions,
      evidenceLog: evidenceLog ?? this.evidenceLog,
      gratitudeLog: gratitudeLog ?? this.gratitudeLog,
      dailyCompletions: dailyCompletions ?? this.dailyCompletions,
      limitingBeliefs: limitingBeliefs ?? this.limitingBeliefs,
      futureSelfSetup: futureSelfSetup ?? this.futureSelfSetup,
      futureSelfCompletions:
          futureSelfCompletions ?? this.futureSelfCompletions,
      beliefPatternHistory: beliefPatternHistory ?? this.beliefPatternHistory,
      deepDive: deepDive ?? this.deepDive,
      fearsDrift: fearsDrift ?? this.fearsDrift,
      mentalToughnessScore: mentalToughnessScore ?? this.mentalToughnessScore,
      blueprintCompleted: blueprintCompleted ?? this.blueprintCompleted,
      mindsetBlueprintSummary: mindsetBlueprintSummary ?? this.mindsetBlueprintSummary,
      mindsetBlueprintSnapshotAt:
          mindsetBlueprintSnapshotAt ?? this.mindsetBlueprintSnapshotAt,
      blueprintSnapshotHistory:
          blueprintSnapshotHistory ?? this.blueprintSnapshotHistory,
      blueprintCalibrationStartedAt:
          blueprintCalibrationStartedAt ?? this.blueprintCalibrationStartedAt,
      blueprintLastRecalculatedAt:
          blueprintLastRecalculatedAt ?? this.blueprintLastRecalculatedAt,
      dailyWisdom: dailyWisdom ?? this.dailyWisdom,
      priorityActions: priorityActions ?? this.priorityActions,
      priorityActionsDate: priorityActionsDate ?? this.priorityActionsDate,
      dailyFocusAction: dailyFocusAction ?? this.dailyFocusAction,
      dailyFocusActionDate: dailyFocusActionDate ?? this.dailyFocusActionDate,
      completedPriorityActions: completedPriorityActions ?? this.completedPriorityActions,
      journalPreference: journalPreference ?? this.journalPreference,
      recentJournalSummaries: recentJournalSummaries ?? this.recentJournalSummaries,
      accountabilityRelationships: accountabilityRelationships ?? this.accountabilityRelationships,
      encouragementMessages: encouragementMessages ?? this.encouragementMessages,
      partnerUids: partnerUids ?? this.partnerUids,
      partnerUsage: partnerUsage ?? this.partnerUsage,
      invitePromptsShown: invitePromptsShown ?? this.invitePromptsShown,
      invitePromptSnoozedUntil:
          invitePromptSnoozedUntil ?? this.invitePromptSnoozedUntil,
      invitePromptsDismissed:
          invitePromptsDismissed ?? this.invitePromptsDismissed,
      widgetPromptSeen: widgetPromptSeen ?? this.widgetPromptSeen,
      affirmationsIntroDismissed:
          affirmationsIntroDismissed ?? this.affirmationsIntroDismissed,
      coachMemory: coachMemory ?? this.coachMemory,
      coachDisclaimerAcceptedAt:
          coachDisclaimerAcceptedAt ?? this.coachDisclaimerAcceptedAt,
      aiConsentAcceptedAt: aiConsentAcceptedAt ?? this.aiConsentAcceptedAt,
      fcmToken: fcmToken ?? this.fcmToken,
      lastActiveAt: lastActiveAt ?? this.lastActiveAt,
      timezone: timezone ?? this.timezone,
      notificationPrefs: notificationPrefs ?? this.notificationPrefs,
      weeklyInsight: weeklyInsight ?? this.weeklyInsight,
      weeklyInsightHistory: weeklyInsightHistory ?? this.weeklyInsightHistory,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  factory UserProfile.create({
    required String uid,
    required String email,
    required String displayName,
  }) {
    return UserProfile(
      uid: uid,
      email: email,
      displayName: displayName,
      mindsetBlueprint: const MindsetBlueprint(),
      originalMindsetBaseline: const MindsetBlueprint(),
      deepDive: DeepDive.initial(),
      createdAt: DateTime.now(),
    );
  }

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    return UserProfile(
      uid: json['uid'] as String? ?? '',
      email: json['email'] as String? ?? '',
      displayName: json['displayName'] as String? ?? '',
      userType: json['userType'] as String? ?? 'user',
      subscriptionStatus: json['subscriptionStatus'] as String? ?? 'free',
      subscriptionExpiresAt:
          DateTime.tryParse(json['subscriptionExpiresAt'] as String? ?? ''),
      onboardingStep: (json['onboardingStep'] as num?)?.toInt() ?? 0,
      mindsetBlueprint: json['mindsetBlueprint'] != null
          ? MindsetBlueprint.fromJson(
              json['mindsetBlueprint'] as Map<String, dynamic>)
          : const MindsetBlueprint(),
      originalMindsetBaseline: json['originalMindsetBaseline'] != null
          ? MindsetBlueprint.fromJson(
              json['originalMindsetBaseline'] as Map<String, dynamic>)
          : const MindsetBlueprint(),
      identityStatement: json['identityStatement'] as String? ?? '',
      identitySituation: json['identitySituation'] as String? ?? '',
      identityQualities:
          List<String>.from(json['identityQualities'] as List<dynamic>? ?? []),
      identityReadLog: (json['identityReadLog'] as List<dynamic>?)
              ?.map((e) =>
                  IdentityReadLog.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      goals: (json['goals'] as List<dynamic>?)
              ?.map((e) => Goal.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      primaryGoalId: json['primaryGoalId'] as String? ?? '',
      habits: (json['habits'] as List<dynamic>?)
              ?.map((e) => Habit.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      affirmations: (json['affirmations'] as List<dynamic>?)
              ?.map((e) => Affirmation.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      affirmationCompletions:
          (json['affirmationCompletions'] as List<dynamic>?)
                  ?.map((e) => AffirmationCompletion.fromJson(
                      e as Map<String, dynamic>))
                  .toList() ??
              [],
      evidenceLog: (json['evidenceLog'] as List<dynamic>?)
              ?.map((e) => EvidenceEntry.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      gratitudeLog: (json['gratitudeLog'] as List<dynamic>?)
              ?.map((e) => GratitudeEntry.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      dailyCompletions: (json['dailyCompletions'] as List<dynamic>?)
              ?.map((e) =>
                  DailyCompletion.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      limitingBeliefs:
          List<String>.from(json['limitingBeliefs'] as List<dynamic>? ?? []),
      futureSelfSetup: json['futureSelfSetup'] != null
          ? FutureSelfSetup.fromJson(
              json['futureSelfSetup'] as Map<String, dynamic>)
          : null,
      futureSelfCompletions: (json['futureSelfCompletions'] as List<dynamic>?)
              ?.map((e) =>
                  FutureSelfCompletion.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      beliefPatternHistory:
          (json['beliefPatternHistory'] as List<dynamic>?)
                  ?.map((e) =>
                      BeliefPattern.fromJson(e as Map<String, dynamic>))
                  .toList() ??
              [],
      deepDive: json['deepDive'] != null
          ? DeepDive.fromJson(json['deepDive'] as Map<String, dynamic>)
          : DeepDive.initial(),
      fearsDrift: List<String>.from(json['fearsDrift'] as List<dynamic>? ?? []),
      mentalToughnessScore: (json['mentalToughnessScore'] as num?)?.toDouble() ?? 50.0,
      blueprintCompleted: json['blueprintCompleted'] as bool? ?? false,
      mindsetBlueprintSummary: json['mindsetBlueprintSummary'] as String? ?? '',
      mindsetBlueprintSnapshotAt:
          json['mindsetBlueprintSnapshotAt'] as String?,
      blueprintSnapshotHistory:
          (json['blueprintSnapshotHistory'] as List<dynamic>?)
                  ?.map((e) =>
                      BlueprintSnapshot.fromJson(e as Map<String, dynamic>))
                  .toList() ??
              [],
      blueprintCalibrationStartedAt:
          json['blueprintCalibrationStartedAt'] as String?,
      blueprintLastRecalculatedAt:
          json['blueprintLastRecalculatedAt'] as String?,
      dailyWisdom:
          Map<String, String>.from(json['dailyWisdom'] as Map? ?? {}),
      priorityActions:
          List<String>.from(json['priorityActions'] as List<dynamic>? ?? []),
      priorityActionsDate: json['priorityActionsDate'] as String? ?? '',
      dailyFocusAction: json['dailyFocusAction'] as String? ?? '',
      dailyFocusActionDate: json['dailyFocusActionDate'] as String? ?? '',
      completedPriorityActions: List<String>.from(
          json['completedPriorityActions'] as List<dynamic>? ?? []),
      journalPreference: json['journalPreference'] as String? ?? 'both',
      recentJournalSummaries:
          (json['recentJournalSummaries'] as List<dynamic>?)
                  ?.map((e) => JournalSummary.fromJson(e as Map<String, dynamic>))
                  .toList() ??
              [],
      accountabilityRelationships:
          (json['accountabilityRelationships'] as List<dynamic>?)
                  ?.map((e) => AccountabilityRelationship.fromJson(e as Map<String, dynamic>))
                  .toList() ??
              [],
      encouragementMessages:
          (json['encouragementMessages'] as List<dynamic>?)
                  ?.map((e) => EncouragementMessage.fromJson(e as Map<String, dynamic>))
                  .toList() ??
              [],
      partnerUids: List<String>.from(json['partnerUids'] as List<dynamic>? ?? []),
      partnerUsage:
          Map<String, dynamic>.from(json['partnerUsage'] as Map? ?? {}),
      invitePromptsShown:
          List<String>.from(json['invitePromptsShown'] as List<dynamic>? ?? []),
      invitePromptSnoozedUntil: json['invitePromptSnoozedUntil'] != null
          ? DateTime.tryParse(json['invitePromptSnoozedUntil'] as String)
          : null,
      invitePromptsDismissed:
          json['invitePromptsDismissed'] as bool? ?? false,
      widgetPromptSeen: json['widgetPromptSeen'] as bool? ?? false,
      affirmationsIntroDismissed:
          json['affirmationsIntroDismissed'] as bool? ?? false,
      coachMemory: json['coachMemory'] != null
          ? CoachMemory.fromJson(json['coachMemory'] as Map<String, dynamic>)
          : const CoachMemory(),
      coachDisclaimerAcceptedAt: json['coachDisclaimerAcceptedAt'] != null
          ? DateTime.tryParse(json['coachDisclaimerAcceptedAt'] as String)
          : null,
      aiConsentAcceptedAt: json['aiConsentAcceptedAt'] != null
          ? DateTime.tryParse(json['aiConsentAcceptedAt'] as String)
          : null,
      fcmToken: json['fcmToken'] as String?,
      lastActiveAt: json['lastActiveAt'] != null
          ? DateTime.tryParse(json['lastActiveAt'] as String)
          : null,
      timezone: json['timezone'] as String? ?? '',
      notificationPrefs: json['notificationPrefs'] != null
          ? NotificationPrefs.fromJson(
              json['notificationPrefs'] as Map<String, dynamic>)
          : const NotificationPrefs(),
      weeklyInsight: WeeklyInsight.tryFromJson(
        json['weeklyInsight'] as Map<String, dynamic>?,
      ),
      weeklyInsightHistory: (json['weeklyInsightHistory'] as List<dynamic>?)
              ?.map((e) => WeeklyInsight.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      createdAt: DateTime.tryParse(json['createdAt'] as String? ?? '') ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() => {
        'uid': uid,
        'email': email,
        'displayName': displayName,
        'userType': userType,
        'subscriptionStatus': subscriptionStatus,
        'subscriptionExpiresAt': subscriptionExpiresAt?.toIso8601String(),
        'onboardingStep': onboardingStep,
        'mindsetBlueprint': mindsetBlueprint.toJson(),
        'originalMindsetBaseline': originalMindsetBaseline.toJson(),
        'identityStatement': identityStatement,
        'identitySituation': identitySituation,
        'identityQualities': identityQualities,
        'identityReadLog': identityReadLog.map((e) => e.toJson()).toList(),
        'goals': goals.map((g) => g.toJson()).toList(),
        'primaryGoalId': primaryGoalId,
        'habits': habits.map((h) => h.toJson()).toList(),
        'affirmations': affirmations.map((a) => a.toJson()).toList(),
        'affirmationCompletions':
            affirmationCompletions.map((a) => a.toJson()).toList(),
        'evidenceLog': evidenceLog.map((e) => e.toJson()).toList(),
        'gratitudeLog': gratitudeLog.map((g) => g.toJson()).toList(),
        'dailyCompletions':
            dailyCompletions.map((d) => d.toJson()).toList(),
        'limitingBeliefs': limitingBeliefs,
        'futureSelfSetup': futureSelfSetup?.toJson(),
        'futureSelfCompletions':
            futureSelfCompletions.map((c) => c.toJson()).toList(),
        'beliefPatternHistory':
            beliefPatternHistory.map((b) => b.toJson()).toList(),
        'deepDive': deepDive.toJson(),
        'fearsDrift': fearsDrift,
        'mentalToughnessScore': mentalToughnessScore,
        'blueprintCompleted': blueprintCompleted,
        'mindsetBlueprintSummary': mindsetBlueprintSummary,
        if (mindsetBlueprintSnapshotAt != null)
          'mindsetBlueprintSnapshotAt': mindsetBlueprintSnapshotAt,
        'blueprintSnapshotHistory':
            blueprintSnapshotHistory.map((e) => e.toJson()).toList(),
        if (blueprintCalibrationStartedAt != null)
          'blueprintCalibrationStartedAt': blueprintCalibrationStartedAt,
        if (blueprintLastRecalculatedAt != null)
          'blueprintLastRecalculatedAt': blueprintLastRecalculatedAt,
        'dailyWisdom': dailyWisdom,
        'priorityActions': priorityActions,
        'priorityActionsDate': priorityActionsDate,
        'dailyFocusAction': dailyFocusAction,
        'dailyFocusActionDate': dailyFocusActionDate,
        'completedPriorityActions': completedPriorityActions,
        'journalPreference': journalPreference,
        'recentJournalSummaries':
            recentJournalSummaries.map((s) => s.toJson()).toList(),
        'accountabilityRelationships':
            accountabilityRelationships.map((r) => r.toJson()).toList(),
        'encouragementMessages':
            encouragementMessages.map((m) => m.toJson()).toList(),
        'partnerUids': partnerUids,
        'partnerUsage': partnerUsage,
        'invitePromptsShown': invitePromptsShown,
        'invitePromptSnoozedUntil': invitePromptSnoozedUntil?.toIso8601String(),
        'invitePromptsDismissed': invitePromptsDismissed,
        'widgetPromptSeen': widgetPromptSeen,
        'affirmationsIntroDismissed': affirmationsIntroDismissed,
        'coachMemory': coachMemory.toJson(),
        'coachDisclaimerAcceptedAt': coachDisclaimerAcceptedAt?.toIso8601String(),
        'aiConsentAcceptedAt': aiConsentAcceptedAt?.toIso8601String(),
        'fcmToken': fcmToken,
        'lastActiveAt': lastActiveAt?.toIso8601String(),
        'timezone': timezone,
        'notificationPrefs': notificationPrefs.toJson(),
        if (weeklyInsight != null) 'weeklyInsight': weeklyInsight!.toJson(),
        'weeklyInsightHistory':
            weeklyInsightHistory.map((e) => e.toJson()).toList(),
        'createdAt': createdAt.toIso8601String(),
      };
}
