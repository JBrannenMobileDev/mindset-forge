import 'mindset_blueprint.dart';
import 'goal.dart';
import 'habit.dart';
import 'affirmation.dart';
import 'daily_completion.dart';
import 'manifestation_alignment.dart';
import 'future_self_setup.dart';
import 'future_self_practice.dart';
import 'belief_pattern.dart';
import 'deep_dive.dart';
import 'evidence_entry.dart';
import 'gratitude_entry.dart';
import 'identity_read_log.dart';
import 'encouragement_message.dart';
import 'accountability_relationship.dart';
import 'journal_summary.dart';

class UserProfile {
  final String uid;
  final String email;
  final String displayName;
  final String userType;
  final String subscriptionStatus;
  final int onboardingStep;
  final MindsetBlueprint mindsetBlueprint;
  final MindsetBlueprint originalMindsetBaseline;
  final String identityStatement;
  final List<IdentityReadLog> identityReadLog;
  final List<Goal> goals;
  final List<Habit> habits;
  final List<Affirmation> affirmations;
  final List<AffirmationCompletion> affirmationCompletions;
  final List<EvidenceEntry> evidenceLog;
  final List<GratitudeEntry> gratitudeLog;
  final List<DailyCompletion> dailyCompletions;
  final List<String> limitingBeliefs;
  final FutureSelfPractice? futureSelfPractice;
  final FutureSelfSetup? futureSelfSetup;
  final ManifestationAlignment manifestationAlignment;
  final List<BeliefPattern> beliefPatternHistory;
  final DeepDive deepDive;
  final List<String> fearsDrift;
  final double mentalToughnessScore;
  final String mindsetBlueprintSummary;
  final Map<String, String> dailyWisdom;
  final List<String> priorityActions;
  final String priorityActionsDate;
  final String dailyFocusAction;
  final String dailyFocusActionDate;
  final bool dailyFocusActionCompleted;
  final String journalPreference; // 'morning' | 'evening' | 'both'
  final List<JournalSummary> recentJournalSummaries;
  final List<AccountabilityRelationship> accountabilityRelationships;
  final List<EncouragementMessage> encouragementMessages;
  final List<String> partnerUids;
  final String? fcmToken;
  final DateTime? lastActiveAt;
  final DateTime createdAt;

  const UserProfile({
    required this.uid,
    required this.email,
    required this.displayName,
    this.userType = 'user',
    this.subscriptionStatus = 'free',
    this.onboardingStep = 0,
    required this.mindsetBlueprint,
    required this.originalMindsetBaseline,
    this.identityStatement = '',
    this.identityReadLog = const [],
    this.goals = const [],
    this.habits = const [],
    this.affirmations = const [],
    this.affirmationCompletions = const [],
    this.evidenceLog = const [],
    this.gratitudeLog = const [],
    this.dailyCompletions = const [],
    this.limitingBeliefs = const [],
    this.futureSelfPractice,
    this.futureSelfSetup,
    required this.manifestationAlignment,
    this.beliefPatternHistory = const [],
    required this.deepDive,
    this.fearsDrift = const [],
    this.mentalToughnessScore = 50.0,
    this.mindsetBlueprintSummary = '',
    this.dailyWisdom = const {},
    this.priorityActions = const [],
    this.priorityActionsDate = '',
    this.dailyFocusAction = '',
    this.dailyFocusActionDate = '',
    this.dailyFocusActionCompleted = false,
    this.journalPreference = 'both',
    this.recentJournalSummaries = const [],
    this.accountabilityRelationships = const [],
    this.encouragementMessages = const [],
    this.partnerUids = const [],
    this.fcmToken,
    this.lastActiveAt,
    required this.createdAt,
  });

  String get firstName =>
      displayName.isNotEmpty ? displayName.split(' ').first : 'there';

  DailyCompletion get todayCompletion {
    final now = DateTime.now();
    final todayStr =
        '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
    return dailyCompletions.firstWhere(
      (c) => c.date == todayStr,
      orElse: DailyCompletion.forToday,
    );
  }

  int get currentStreak {
    if (dailyCompletions.isEmpty) return 0;
    final sorted = [...dailyCompletions]
      ..sort((a, b) => b.date.compareTo(a.date));

    int streak = 0;
    DateTime checkDate = DateTime.now();

    for (final completion in sorted) {
      final parts = completion.date.split('-');
      final date = DateTime(
        int.parse(parts[0]),
        int.parse(parts[1]),
        int.parse(parts[2]),
      );
      final checkDateOnly =
          DateTime(checkDate.year, checkDate.month, checkDate.day);

      if (date == checkDateOnly || date == checkDateOnly.subtract(const Duration(days: 1))) {
        if (completion.completedCount >= 5) {
          streak++;
          checkDate = date.subtract(const Duration(days: 1));
        } else {
          break;
        }
      } else {
        break;
      }
    }
    return streak;
  }

  int get perfectDayCount =>
      dailyCompletions.where((c) => c.isPerfectDay).length;

  UserProfile copyWith({
    String? uid,
    String? email,
    String? displayName,
    String? userType,
    String? subscriptionStatus,
    int? onboardingStep,
    MindsetBlueprint? mindsetBlueprint,
    MindsetBlueprint? originalMindsetBaseline,
    String? identityStatement,
    List<IdentityReadLog>? identityReadLog,
    List<Goal>? goals,
    List<Habit>? habits,
    List<Affirmation>? affirmations,
    List<AffirmationCompletion>? affirmationCompletions,
    List<EvidenceEntry>? evidenceLog,
    List<GratitudeEntry>? gratitudeLog,
    List<DailyCompletion>? dailyCompletions,
    List<String>? limitingBeliefs,
    FutureSelfPractice? futureSelfPractice,
    FutureSelfSetup? futureSelfSetup,
    ManifestationAlignment? manifestationAlignment,
    List<BeliefPattern>? beliefPatternHistory,
    DeepDive? deepDive,
    List<String>? fearsDrift,
    double? mentalToughnessScore,
    String? mindsetBlueprintSummary,
    Map<String, String>? dailyWisdom,
    List<String>? priorityActions,
    String? priorityActionsDate,
    String? dailyFocusAction,
    String? dailyFocusActionDate,
    bool? dailyFocusActionCompleted,
    String? journalPreference,
    List<JournalSummary>? recentJournalSummaries,
    List<AccountabilityRelationship>? accountabilityRelationships,
    List<EncouragementMessage>? encouragementMessages,
    List<String>? partnerUids,
    String? fcmToken,
    DateTime? lastActiveAt,
    DateTime? createdAt,
  }) {
    return UserProfile(
      uid: uid ?? this.uid,
      email: email ?? this.email,
      displayName: displayName ?? this.displayName,
      userType: userType ?? this.userType,
      subscriptionStatus: subscriptionStatus ?? this.subscriptionStatus,
      onboardingStep: onboardingStep ?? this.onboardingStep,
      mindsetBlueprint: mindsetBlueprint ?? this.mindsetBlueprint,
      originalMindsetBaseline:
          originalMindsetBaseline ?? this.originalMindsetBaseline,
      identityStatement: identityStatement ?? this.identityStatement,
      identityReadLog: identityReadLog ?? this.identityReadLog,
      goals: goals ?? this.goals,
      habits: habits ?? this.habits,
      affirmations: affirmations ?? this.affirmations,
      affirmationCompletions:
          affirmationCompletions ?? this.affirmationCompletions,
      evidenceLog: evidenceLog ?? this.evidenceLog,
      gratitudeLog: gratitudeLog ?? this.gratitudeLog,
      dailyCompletions: dailyCompletions ?? this.dailyCompletions,
      limitingBeliefs: limitingBeliefs ?? this.limitingBeliefs,
      futureSelfPractice: futureSelfPractice ?? this.futureSelfPractice,
      futureSelfSetup: futureSelfSetup ?? this.futureSelfSetup,
      manifestationAlignment:
          manifestationAlignment ?? this.manifestationAlignment,
      beliefPatternHistory: beliefPatternHistory ?? this.beliefPatternHistory,
      deepDive: deepDive ?? this.deepDive,
      fearsDrift: fearsDrift ?? this.fearsDrift,
      mentalToughnessScore: mentalToughnessScore ?? this.mentalToughnessScore,
      mindsetBlueprintSummary: mindsetBlueprintSummary ?? this.mindsetBlueprintSummary,
      dailyWisdom: dailyWisdom ?? this.dailyWisdom,
      priorityActions: priorityActions ?? this.priorityActions,
      priorityActionsDate: priorityActionsDate ?? this.priorityActionsDate,
      dailyFocusAction: dailyFocusAction ?? this.dailyFocusAction,
      dailyFocusActionDate: dailyFocusActionDate ?? this.dailyFocusActionDate,
      dailyFocusActionCompleted: dailyFocusActionCompleted ?? this.dailyFocusActionCompleted,
      journalPreference: journalPreference ?? this.journalPreference,
      recentJournalSummaries: recentJournalSummaries ?? this.recentJournalSummaries,
      accountabilityRelationships: accountabilityRelationships ?? this.accountabilityRelationships,
      encouragementMessages: encouragementMessages ?? this.encouragementMessages,
      partnerUids: partnerUids ?? this.partnerUids,
      fcmToken: fcmToken ?? this.fcmToken,
      lastActiveAt: lastActiveAt ?? this.lastActiveAt,
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
      manifestationAlignment: ManifestationAlignment.initial(),
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
      identityReadLog: (json['identityReadLog'] as List<dynamic>?)
              ?.map((e) =>
                  IdentityReadLog.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      goals: (json['goals'] as List<dynamic>?)
              ?.map((e) => Goal.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
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
      futureSelfPractice: json['futureSelfPractice'] != null
          ? FutureSelfPractice.fromJson(
              json['futureSelfPractice'] as Map<String, dynamic>)
          : null,
      futureSelfSetup: json['futureSelfSetup'] != null
          ? FutureSelfSetup.fromJson(
              json['futureSelfSetup'] as Map<String, dynamic>)
          : null,
      manifestationAlignment: json['manifestationAlignment'] != null
          ? ManifestationAlignment.fromJson(
              json['manifestationAlignment'] as Map<String, dynamic>)
          : ManifestationAlignment.initial(),
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
      mindsetBlueprintSummary: json['mindsetBlueprintSummary'] as String? ?? '',
      dailyWisdom:
          Map<String, String>.from(json['dailyWisdom'] as Map? ?? {}),
      priorityActions:
          List<String>.from(json['priorityActions'] as List<dynamic>? ?? []),
      priorityActionsDate: json['priorityActionsDate'] as String? ?? '',
      dailyFocusAction: json['dailyFocusAction'] as String? ?? '',
      dailyFocusActionDate: json['dailyFocusActionDate'] as String? ?? '',
      dailyFocusActionCompleted: json['dailyFocusActionCompleted'] as bool? ?? false,
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
      fcmToken: json['fcmToken'] as String?,
      lastActiveAt: json['lastActiveAt'] != null
          ? DateTime.tryParse(json['lastActiveAt'] as String)
          : null,
      createdAt: DateTime.tryParse(json['createdAt'] as String? ?? '') ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() => {
        'uid': uid,
        'email': email,
        'displayName': displayName,
        'userType': userType,
        'subscriptionStatus': subscriptionStatus,
        'onboardingStep': onboardingStep,
        'mindsetBlueprint': mindsetBlueprint.toJson(),
        'originalMindsetBaseline': originalMindsetBaseline.toJson(),
        'identityStatement': identityStatement,
        'identityReadLog': identityReadLog.map((e) => e.toJson()).toList(),
        'goals': goals.map((g) => g.toJson()).toList(),
        'habits': habits.map((h) => h.toJson()).toList(),
        'affirmations': affirmations.map((a) => a.toJson()).toList(),
        'affirmationCompletions':
            affirmationCompletions.map((a) => a.toJson()).toList(),
        'evidenceLog': evidenceLog.map((e) => e.toJson()).toList(),
        'gratitudeLog': gratitudeLog.map((g) => g.toJson()).toList(),
        'dailyCompletions':
            dailyCompletions.map((d) => d.toJson()).toList(),
        'limitingBeliefs': limitingBeliefs,
        'futureSelfPractice': futureSelfPractice?.toJson(),
        'futureSelfSetup': futureSelfSetup?.toJson(),
        'manifestationAlignment': manifestationAlignment.toJson(),
        'beliefPatternHistory':
            beliefPatternHistory.map((b) => b.toJson()).toList(),
        'deepDive': deepDive.toJson(),
        'fearsDrift': fearsDrift,
        'mentalToughnessScore': mentalToughnessScore,
        'mindsetBlueprintSummary': mindsetBlueprintSummary,
        'dailyWisdom': dailyWisdom,
        'priorityActions': priorityActions,
        'priorityActionsDate': priorityActionsDate,
        'dailyFocusAction': dailyFocusAction,
        'dailyFocusActionDate': dailyFocusActionDate,
        'dailyFocusActionCompleted': dailyFocusActionCompleted,
        'journalPreference': journalPreference,
        'recentJournalSummaries':
            recentJournalSummaries.map((s) => s.toJson()).toList(),
        'accountabilityRelationships':
            accountabilityRelationships.map((r) => r.toJson()).toList(),
        'encouragementMessages':
            encouragementMessages.map((m) => m.toJson()).toList(),
        'partnerUids': partnerUids,
        'fcmToken': fcmToken,
        'lastActiveAt': lastActiveAt?.toIso8601String(),
        'createdAt': createdAt.toIso8601String(),
      };
}
