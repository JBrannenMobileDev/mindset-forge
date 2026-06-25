/// A single day's Future Self practice completion. Stored as a history list on
/// the profile so the player can show "completed today" and a streak/history,
/// mirroring base44's `future_self_completions`.
class FutureSelfCompletion {
  /// Local date string, yyyy-MM-dd.
  final String date;
  final bool completed;
  final int durationSeconds;
  final DateTime? completionTime;

  const FutureSelfCompletion({
    required this.date,
    this.completed = false,
    this.durationSeconds = 0,
    this.completionTime,
  });

  FutureSelfCompletion copyWith({
    String? date,
    bool? completed,
    int? durationSeconds,
    DateTime? completionTime,
  }) {
    return FutureSelfCompletion(
      date: date ?? this.date,
      completed: completed ?? this.completed,
      durationSeconds: durationSeconds ?? this.durationSeconds,
      completionTime: completionTime ?? this.completionTime,
    );
  }

  factory FutureSelfCompletion.fromJson(Map<String, dynamic> json) {
    return FutureSelfCompletion(
      date: json['date'] as String? ?? '',
      completed: json['completed'] as bool? ?? false,
      durationSeconds: (json['durationSeconds'] as num?)?.toInt() ?? 0,
      completionTime: json['completionTime'] != null
          ? DateTime.tryParse(json['completionTime'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() => {
        'date': date,
        'completed': completed,
        'durationSeconds': durationSeconds,
        'completionTime': completionTime?.toIso8601String(),
      };
}
