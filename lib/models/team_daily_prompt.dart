/// A coach-assigned journal prompt for a single day, mirroring
/// `teams/{teamId}/schedule/{YYYY-MM-DD}`. Read-only from the app: every write
/// happens server-side through the coach portal's callables.
class TeamDailyPrompt {
  /// The scheduled day in `YYYY-MM-DD` form (also the document id).
  final String date;

  /// Id of the prompt in the team's prompt bank.
  final String promptId;
  final String promptText;

  /// Uid of the coach or analyst who assigned it.
  final String assignedBy;

  /// ISO-8601 timestamp of the assignment.
  final String assignedAt;

  const TeamDailyPrompt({
    required this.date,
    this.promptId = '',
    this.promptText = '',
    this.assignedBy = '',
    this.assignedAt = '',
  });

  TeamDailyPrompt copyWith({
    String? date,
    String? promptId,
    String? promptText,
    String? assignedBy,
    String? assignedAt,
  }) {
    return TeamDailyPrompt(
      date: date ?? this.date,
      promptId: promptId ?? this.promptId,
      promptText: promptText ?? this.promptText,
      assignedBy: assignedBy ?? this.assignedBy,
      assignedAt: assignedAt ?? this.assignedAt,
    );
  }

  factory TeamDailyPrompt.fromJson(Map<String, dynamic> json) {
    return TeamDailyPrompt(
      date: json['date'] as String? ?? '',
      promptId: json['promptId'] as String? ?? '',
      promptText: json['promptText'] as String? ?? '',
      assignedBy: json['assignedBy'] as String? ?? '',
      assignedAt: json['assignedAt'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
        'date': date,
        'promptId': promptId,
        'promptText': promptText,
        'assignedBy': assignedBy,
        'assignedAt': assignedAt,
      };

  /// A schedule doc is only usable once it carries prompt text, so a partially
  /// written or unassigned day never replaces the AI prompt.
  bool get isUsable => promptText.trim().isNotEmpty;
}
