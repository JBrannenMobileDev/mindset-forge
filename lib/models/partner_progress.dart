/// Privacy-curated snapshot of a primary user's progress, returned by the
/// `getPartnerProgress` Cloud Function for their accountability partner.
///
/// This intentionally contains ONLY shareable fields. Private data (journal,
/// chat, beliefs, fears, coach memory) is never included.
class PartnerProgress {
  final String displayName;
  final String identityStatement;
  final int currentStreak;
  final int perfectDayCount;
  final int todayCompletedCount;
  final int todayTotalCount;
  final int todayCompletionPercent;
  final List<PartnerGoal> activeGoals;
  final List<PartnerActivityDay> weeklyActivity;
  final String? todayEvidence;

  const PartnerProgress({
    required this.displayName,
    this.identityStatement = '',
    this.currentStreak = 0,
    this.perfectDayCount = 0,
    this.todayCompletedCount = 0,
    this.todayTotalCount = 8,
    this.todayCompletionPercent = 0,
    this.activeGoals = const [],
    this.weeklyActivity = const [],
    this.todayEvidence,
  });

  String get firstName =>
      displayName.isNotEmpty ? displayName.split(' ').first : 'Your partner';

  factory PartnerProgress.fromJson(Map<String, dynamic> json) {
    return PartnerProgress(
      displayName: json['displayName'] as String? ?? 'Your partner',
      identityStatement: json['identityStatement'] as String? ?? '',
      currentStreak: (json['currentStreak'] as num?)?.toInt() ?? 0,
      perfectDayCount: (json['perfectDayCount'] as num?)?.toInt() ?? 0,
      todayCompletedCount: (json['todayCompletedCount'] as num?)?.toInt() ?? 0,
      todayTotalCount: (json['todayTotalCount'] as num?)?.toInt() ?? 8,
      todayCompletionPercent:
          (json['todayCompletionPercent'] as num?)?.toInt() ?? 0,
      activeGoals: (json['activeGoals'] as List<dynamic>?)
              ?.map((e) => PartnerGoal.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      weeklyActivity: (json['weeklyActivity'] as List<dynamic>?)
              ?.map((e) =>
                  PartnerActivityDay.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      todayEvidence: json['todayEvidence'] as String?,
    );
  }
}

class PartnerGoal {
  final String id;
  final String title;
  final String category;
  final double progressPercent;

  const PartnerGoal({
    required this.id,
    required this.title,
    this.category = '',
    this.progressPercent = 0,
  });

  factory PartnerGoal.fromJson(Map<String, dynamic> json) {
    return PartnerGoal(
      id: json['id'] as String? ?? '',
      title: json['title'] as String? ?? '',
      category: json['category'] as String? ?? '',
      progressPercent: (json['progressPercent'] as num?)?.toDouble() ?? 0,
    );
  }
}

class PartnerActivityDay {
  final String date;
  final int completedCount;
  final bool countsForStreak;
  final bool isPerfect;

  const PartnerActivityDay({
    required this.date,
    this.completedCount = 0,
    this.countsForStreak = false,
    this.isPerfect = false,
  });

  factory PartnerActivityDay.fromJson(Map<String, dynamic> json) {
    final count = (json['completedCount'] as num?)?.toInt() ?? 0;
    return PartnerActivityDay(
      date: json['date'] as String? ?? '',
      completedCount: count,
      // Fall back to the client thresholds so a pre-deploy payload (without
      // these flags) still renders the chain correctly.
      countsForStreak: json['countsForStreak'] as bool? ?? (count >= 5),
      isPerfect: json['isPerfect'] as bool? ?? (count >= 9),
    );
  }
}
