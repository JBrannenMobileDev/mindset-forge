class DailyCompletion {
  final String date;

  // ── Required items (count toward streak) ─────────────────────────────────
  final bool habitsCompleted;

  /// Day has been planned (priorities chosen / focus committed). Drives the
  /// "Plan Day" morning win — distinct from actually completing the actions.
  final bool dayPlanned;

  /// The user-picked #1 focus action has been completed (the doing). This is
  /// the one decisive action that drives change, so it counts toward the
  /// streak / perfect day.
  final bool focusCompleted;

  /// At least one of today's planned priority actions has been completed.
  /// Scoring-only signal for the Action alignment dimension; does NOT count
  /// toward the streak on its own.
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
    this.focusCompleted = false,
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

  /// Perfect day = all 9 required items done.
  bool get isPerfectDay =>
      habitsCompleted &&
      dayPlanned &&
      focusCompleted &&
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
      focusCompleted,
      affirmationsMorning,
      affirmationsEvening,
      futureSelfCompleted,
      journalCompleted,
      chatCompleted,
      identityRead,
    ].where((v) => v).length;
  }

  static const int totalCount = 9;

  /// A day extends the streak when at least [streakThreshold] of the 9
  /// required wins are done.
  static const int streakThreshold = 5;

  double get completionPercent => completedCount / totalCount;

  /// Whether this day counts toward the current/best streak.
  bool get countsForStreak => completedCount >= streakThreshold;

  DailyCompletion copyWith({
    String? date,
    bool? habitsCompleted,
    bool? dayPlanned,
    bool? focusCompleted,
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
      focusCompleted: focusCompleted ?? this.focusCompleted,
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
      focusCompleted: json['focusCompleted'] as bool? ?? false,
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
        'focusCompleted': focusCompleted,
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

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DailyCompletion &&
          date == other.date &&
          habitsCompleted == other.habitsCompleted &&
          dayPlanned == other.dayPlanned &&
          focusCompleted == other.focusCompleted &&
          priorityActionsCompleted == other.priorityActionsCompleted &&
          affirmationsMorning == other.affirmationsMorning &&
          affirmationsEvening == other.affirmationsEvening &&
          futureSelfCompleted == other.futureSelfCompleted &&
          journalCompleted == other.journalCompleted &&
          chatCompleted == other.chatCompleted &&
          identityRead == other.identityRead &&
          gratitudeLogged == other.gratitudeLogged &&
          evidenceLogged == other.evidenceLogged &&
          _mapEquals(completionTimes, other.completionTimes);

  @override
  int get hashCode => Object.hash(
        date,
        habitsCompleted,
        dayPlanned,
        focusCompleted,
        priorityActionsCompleted,
        affirmationsMorning,
        affirmationsEvening,
        futureSelfCompleted,
        journalCompleted,
        chatCompleted,
        identityRead,
        gratitudeLogged,
        evidenceLogged,
        Object.hashAll(completionTimes.entries
            .map((e) => Object.hash(e.key, e.value))),
      );

  static bool _mapEquals(Map<String, String> a, Map<String, String> b) {
    if (a.length != b.length) return false;
    for (final key in a.keys) {
      if (a[key] != b[key]) return false;
    }
    return true;
  }
}
