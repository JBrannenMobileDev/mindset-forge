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

  int get currentStreak {
    if (completionHistory.isEmpty) return 0;

    final sorted = [...completionHistory]
      ..sort((a, b) => b.compareTo(a));

    final today = DateTime.now();
    final todayDate = DateTime(today.year, today.month, today.day);

    int streak = 0;
    DateTime checkDate = todayDate;

    for (final completion in sorted) {
      final completionDate = DateTime(
        completion.year,
        completion.month,
        completion.day,
      );

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
    final now = DateTime.now();
    final last = lastCompletedDate!;
    return last.year == now.year && last.month == now.month && last.day == now.day;
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
