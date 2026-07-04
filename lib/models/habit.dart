class Habit {
  final String id;
  final String name;
  final String trigger;
  final String frequency;
  final String identityReinforces;
  final String state;
  final DateTime? lastCompletedDate;
  final List<DateTime> completionHistory;
  final DateTime createdAt;

  /// Opt-in cue-based reminder: off by default so existing/new habits never
  /// silently start notifying. [reminderMinutes] is minutes since local
  /// midnight, only meaningful while [reminderEnabled] is true.
  final bool reminderEnabled;
  final int reminderMinutes;

  static const int defaultReminderMinutes = 8 * 60; // 08:00

  const Habit({
    required this.id,
    required this.name,
    this.trigger = '',
    this.frequency = 'daily',
    this.identityReinforces = '',
    this.state = 'active',
    this.lastCompletedDate,
    this.completionHistory = const [],
    required this.createdAt,
    this.reminderEnabled = false,
    this.reminderMinutes = defaultReminderMinutes,
  });

  /// Active day (4 AM–4 AM): midnight–4 AM counts as the prior day, matching
  /// `AppDateUtils.todayStringWithGracePeriod()` so late-night progress and
  /// streaks don't reset at midnight while the session period is still evening.
  static DateTime activeDay(DateTime d) {
    final a = d.hour < 4 ? d.subtract(const Duration(days: 1)) : d;
    return DateTime(a.year, a.month, a.day);
  }

  /// The Monday of the calendar week containing [d]'s active day. 'weekly'
  /// habits are satisfied once per week rather than on a specific day, so
  /// streaks and "done for now" key off this instead of [activeDay].
  static DateTime activeWeekStart(DateTime d) {
    final day = activeDay(d);
    return day.subtract(Duration(days: day.weekday - 1));
  }

  /// The cadence period [d] falls into: a specific day for 'daily' habits,
  /// the Monday of its week for 'weekly' habits. Streaks and "completed for
  /// now" are both computed in terms of this period so a weekly habit only
  /// needs one completion per week, not one per day.
  DateTime _periodOf(DateTime d) =>
      frequency == 'weekly' ? activeWeekStart(d) : activeDay(d);

  /// The gap between consecutive cadence periods: one day for 'daily', one
  /// week for 'weekly'.
  Duration get _periodSpan =>
      frequency == 'weekly' ? const Duration(days: 7) : const Duration(days: 1);

  int get currentStreak {
    if (completionHistory.isEmpty) return 0;

    final sorted = [...completionHistory]
      ..sort((a, b) => b.compareTo(a));

    int streak = 0;
    DateTime checkPeriod = _periodOf(DateTime.now());

    for (final completion in sorted) {
      final period = _periodOf(completion);

      if (period == checkPeriod ||
          period == checkPeriod.subtract(_periodSpan)) {
        streak++;
        checkPeriod = period.subtract(_periodSpan);
      } else {
        break;
      }
    }

    return streak;
  }

  /// True once this habit has been completed for its current cadence period
  /// — today for 'daily' habits, this week for 'weekly' habits.
  bool get isCompletedToday {
    if (lastCompletedDate == null) return false;
    return _periodOf(lastCompletedDate!) == _periodOf(DateTime.now());
  }

  /// Whether [date]'s cadence period (that calendar day for 'daily', that
  /// calendar week — Monday-start — for 'weekly') contains at least one raw
  /// completion. Deliberately calendar-day based (no 4 AM grace shift) so it
  /// matches simple day-key comparisons, e.g. the Alignment Score's per-day
  /// credit and the history heatmap, both of which key dates the same way.
  bool hasCompletionInPeriodContaining(DateTime date) {
    if (frequency == 'weekly') {
      final d = DateTime(date.year, date.month, date.day);
      final weekStart = d.subtract(Duration(days: d.weekday - 1));
      final weekEnd = weekStart.add(const Duration(days: 6));
      return completionHistory.any((t) {
        final td = DateTime(t.year, t.month, t.day);
        return !td.isBefore(weekStart) && !td.isAfter(weekEnd);
      });
    }
    return completionHistory.any(
      (t) => t.year == date.year && t.month == date.month && t.day == date.day,
    );
  }

  Habit copyWith({
    String? id,
    String? name,
    String? trigger,
    String? frequency,
    String? identityReinforces,
    String? state,
    DateTime? lastCompletedDate,
    List<DateTime>? completionHistory,
    DateTime? createdAt,
    bool? reminderEnabled,
    int? reminderMinutes,
  }) {
    return Habit(
      id: id ?? this.id,
      name: name ?? this.name,
      trigger: trigger ?? this.trigger,
      frequency: frequency ?? this.frequency,
      identityReinforces: identityReinforces ?? this.identityReinforces,
      state: state ?? this.state,
      lastCompletedDate: lastCompletedDate ?? this.lastCompletedDate,
      completionHistory: completionHistory ?? this.completionHistory,
      createdAt: createdAt ?? this.createdAt,
      reminderEnabled: reminderEnabled ?? this.reminderEnabled,
      reminderMinutes: reminderMinutes ?? this.reminderMinutes,
    );
  }

  factory Habit.fromJson(Map<String, dynamic> json) {
    return Habit(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      trigger: json['trigger'] as String? ?? '',
      frequency: json['frequency'] as String? ?? 'daily',
      identityReinforces: json['identityReinforces'] as String? ?? '',
      state: json['state'] as String? ?? 'active',
      lastCompletedDate: json['lastCompletedDate'] != null
          ? DateTime.tryParse(json['lastCompletedDate'] as String)
          : null,
      completionHistory: (json['completionHistory'] as List<dynamic>?)
              ?.map((e) => DateTime.tryParse(e as String? ?? ''))
              .whereType<DateTime>()
              .toList() ??
          [],
      createdAt: DateTime.tryParse(json['createdAt'] as String? ?? '') ?? DateTime.now(),
      reminderEnabled: json['reminderEnabled'] as bool? ?? false,
      reminderMinutes:
          (json['reminderMinutes'] as num?)?.toInt() ?? defaultReminderMinutes,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'trigger': trigger,
        'frequency': frequency,
        'identityReinforces': identityReinforces,
        'state': state,
        'lastCompletedDate': lastCompletedDate?.toIso8601String(),
        'completionHistory':
            completionHistory.map((d) => d.toIso8601String()).toList(),
        'createdAt': createdAt.toIso8601String(),
        'reminderEnabled': reminderEnabled,
        'reminderMinutes': reminderMinutes,
      };
}
