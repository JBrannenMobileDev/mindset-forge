class DailyCompletion {
  final String date;

  // ── Required items (count toward streak) ─────────────────────────────────
  final bool habitsCompleted;
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

  const DailyCompletion({
    required this.date,
    this.habitsCompleted = false,
    this.priorityActionsCompleted = false,
    this.affirmationsMorning = false,
    this.affirmationsEvening = false,
    this.futureSelfCompleted = false,
    this.journalCompleted = false,
    this.chatCompleted = false,
    this.identityRead = false,
    this.gratitudeLogged = false,
    this.evidenceLogged = false,
  });

  /// Perfect day = all 8 required items done.
  bool get isPerfectDay =>
      habitsCompleted &&
      priorityActionsCompleted &&
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
      priorityActionsCompleted,
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
    bool? priorityActionsCompleted,
    bool? affirmationsMorning,
    bool? affirmationsEvening,
    bool? futureSelfCompleted,
    bool? journalCompleted,
    bool? chatCompleted,
    bool? identityRead,
    bool? gratitudeLogged,
    bool? evidenceLogged,
  }) {
    return DailyCompletion(
      date: date ?? this.date,
      habitsCompleted: habitsCompleted ?? this.habitsCompleted,
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
    );
  }

  Map<String, dynamic> toJson() => {
        'date': date,
        'habitsCompleted': habitsCompleted,
        'priorityActionsCompleted': priorityActionsCompleted,
        'affirmationsMorning': affirmationsMorning,
        'affirmationsEvening': affirmationsEvening,
        'futureSelfCompleted': futureSelfCompleted,
        'journalCompleted': journalCompleted,
        'chatCompleted': chatCompleted,
        'identityRead': identityRead,
        'gratitudeLogged': gratitudeLogged,
        'evidenceLogged': evidenceLogged,
      };
}
