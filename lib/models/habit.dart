import 'date_range.dart';

class Habit {
  final String id;
  final String name;
  final String trigger;
  final String frequency;
  final String identityReinforces;
  final String state;
  final DateTime? lastCompletedDate;
  final List<DateTime> completionHistory;
  final List<DateRange> pausedDates;
  final DateTime createdAt;

  const Habit({
    required this.id,
    required this.name,
    this.trigger = '',
    this.frequency = 'daily',
    this.identityReinforces = '',
    this.state = 'active',
    this.lastCompletedDate,
    this.completionHistory = const [],
    this.pausedDates = const [],
    required this.createdAt,
  });

  /// Active day (4 AM–4 AM): midnight–4 AM counts as the prior day, matching
  /// `AppDateUtils.todayStringWithGracePeriod()` so late-night progress and
  /// streaks don't reset at midnight while the session period is still evening.
  static DateTime activeDay(DateTime d) {
    final a = d.hour < 4 ? d.subtract(const Duration(days: 1)) : d;
    return DateTime(a.year, a.month, a.day);
  }

  int get currentStreak {
    if (completionHistory.isEmpty) return 0;

    final sorted = [...completionHistory]
      ..sort((a, b) => b.compareTo(a));

    int streak = 0;
    DateTime checkDate = activeDay(DateTime.now());

    for (final completion in sorted) {
      final completionDate = activeDay(completion);

      if (completionDate == checkDate ||
          completionDate == checkDate.subtract(const Duration(days: 1))) {
        streak++;
        checkDate = completionDate.subtract(const Duration(days: 1));
      } else {
        break;
      }
    }

    return streak;
  }

  bool get isCompletedToday {
    if (lastCompletedDate == null) return false;
    return activeDay(lastCompletedDate!) == activeDay(DateTime.now());
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
    List<DateRange>? pausedDates,
    DateTime? createdAt,
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
      pausedDates: pausedDates ?? this.pausedDates,
      createdAt: createdAt ?? this.createdAt,
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
      pausedDates: (json['pausedDates'] as List<dynamic>?)
              ?.map((e) => DateRange.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      createdAt: DateTime.tryParse(json['createdAt'] as String? ?? '') ?? DateTime.now(),
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
        'pausedDates': pausedDates.map((r) => r.toJson()).toList(),
        'createdAt': createdAt.toIso8601String(),
      };
}
