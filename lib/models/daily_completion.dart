class DailyCompletion {
  final String date;

  // ── Required items (count toward streak) ─────────────────────────────────
  final bool habitsCompleted;

  /// Day has been planned (priorities chosen / focus committed). Drives the
  /// "Plan Day" morning win — distinct from actually completing the actions.
  final bool dayPlanned;

  /// Today's priority actions have actually been completed (the doing).
  /// Tracked for scoring; does NOT count toward the streak on its own.
  final bool priorityActionsCompleted;
  final bool affirmationsMorning;
  final bool affirmationsEvening;
  final bool futureSelfCompleted;
  final bool journalCompleted;
  final bool chatCompleted;
  final bool identityRead;

  // ── Bonus items (tracked but do NOT count toward streak) ─────────────────
  final bool gratitudeLogged;
  final bool evidenceLogged;

  /// ISO8601 completion timestamps keyed by completion field name.
  /// Lets the coach reason about *when* routine items are typically done.
  final Map<String, String> completionTimes;

  const DailyCompletion({
    required this.date,
    this.habitsCompleted = false,
    this.dayPlanned = false,
    this.priorityActionsCompleted = false,
    this.affirmationsMorning = false,
    this.affirmationsEvening = false,
    this.futureSelfCompleted = false,
    this.journalCompleted = false,
    this.chatCompleted = false,
    this.identityRead = false,
    this.gratitudeLogged = false,
    this.evidenceLogged = false,
    this.completionTimes = const {},
  });

  /// Perfect day = all 8 required items done.
  bool get isPerfectDay =>
      habitsCompleted &&
      dayPlanned &&
      affirmationsMorning &&
      affirmationsEvening &&
      futureSelfCompleted &&
      journalCompleted &&
      chatCompleted &&
      identityRead;

  /// Only counts required items — bonus items are excluded.
  int get completedCount {
    return [
      habitsCompleted,
      dayPlanned,
      affirmationsMorning,
      affirmationsEvening,
      futureSelfCompleted,
      journalCompleted,
      chatCompleted,
      identityRead,
    ].where((v) => v).length;
  }

  static const int totalCount = 8;

  double get completionPercent => completedCount / totalCount;

  DailyCompletion copyWith({
    String? date,
    bool? habitsCompleted,
    bool? dayPlanned,
    bool? priorityActionsCompleted,
    bool? affirmationsMorning,
    bool? affirmationsEvening,
    bool? futureSelfCompleted,
    bool? journalCompleted,
    bool? chatCompleted,
    bool? identityRead,
    bool? gratitudeLogged,
    bool? evidenceLogged,
    Map<String, String>? completionTimes,
  }) {
    return DailyCompletion(
      date: date ?? this.date,
      habitsCompleted: habitsCompleted ?? this.habitsCompleted,
      dayPlanned: dayPlanned ?? this.dayPlanned,
      priorityActionsCompleted:
          priorityActionsCompleted ?? this.priorityActionsCompleted,
      affirmationsMorning: affirmationsMorning ?? this.affirmationsMorning,
      affirmationsEvening: affirmationsEvening ?? this.affirmationsEvening,
      futureSelfCompleted: futureSelfCompleted ?? this.futureSelfCompleted,
      journalCompleted: journalCompleted ?? this.journalCompleted,
      chatCompleted: chatCompleted ?? this.chatCompleted,
      identityRead: identityRead ?? this.identityRead,
      gratitudeLogged: gratitudeLogged ?? this.gratitudeLogged,
      evidenceLogged: evidenceLogged ?? this.evidenceLogged,
      completionTimes: completionTimes ?? this.completionTimes,
    );
  }

  factory DailyCompletion.forToday() {
    final now = DateTime.now();
    return DailyCompletion(
      date:
          '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}',
    );
  }

  factory DailyCompletion.fromJson(Map<String, dynamic> json) {
    return DailyCompletion(
      date: json['date'] as String? ?? '',
      habitsCompleted: json['habitsCompleted'] as bool? ?? false,
      // Legacy docs only had `priorityActionsCompleted` and used it as the
      // "Plan Day" win — fall back to it so historical streaks stay intact.
      dayPlanned: json['dayPlanned'] as bool? ??
          json['priorityActionsCompleted'] as bool? ??
          false,
      priorityActionsCompleted:
          json['priorityActionsCompleted'] as bool? ?? false,
      affirmationsMorning: json['affirmationsMorning'] as bool? ?? false,
      affirmationsEvening: json['affirmationsEvening'] as bool? ?? false,
      futureSelfCompleted: json['futureSelfCompleted'] as bool? ?? false,
      journalCompleted: json['journalCompleted'] as bool? ?? false,
      chatCompleted: json['chatCompleted'] as bool? ?? false,
      identityRead: json['identityRead'] as bool? ?? false,
      gratitudeLogged: json['gratitudeLogged'] as bool? ?? false,
      evidenceLogged: json['evidenceLogged'] as bool? ?? false,
      completionTimes:
          Map<String, String>.from(json['completionTimes'] as Map? ?? {}),
    );
  }

  Map<String, dynamic> toJson() => {
        'date': date,
        'habitsCompleted': habitsCompleted,
        'dayPlanned': dayPlanned,
        'priorityActionsCompleted': priorityActionsCompleted,
        'affirmationsMorning': affirmationsMorning,
        'affirmationsEvening': affirmationsEvening,
        'futureSelfCompleted': futureSelfCompleted,
        'journalCompleted': journalCompleted,
        'chatCompleted': chatCompleted,
        'identityRead': identityRead,
        'gratitudeLogged': gratitudeLogged,
        'evidenceLogged': evidenceLogged,
        'completionTimes': completionTimes,
      };
}
