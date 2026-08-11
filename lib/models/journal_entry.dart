class JournalEntry {
  final String id;
  final String uid;
  final String mode;
  final String mood;
  final String prompt;
  final String content;
  final List<String> limitingBeliefsShifted;
  final List<String> fearsOutwitted;

  /// Id of the coach-assigned team prompt this entry was written from, so team
  /// summaries can attribute it. Null for every self-directed entry.
  final String? teamPromptId;
  final DateTime createdAt;

  const JournalEntry({
    required this.id,
    required this.uid,
    required this.mode,
    required this.mood,
    this.prompt = '',
    required this.content,
    this.limitingBeliefsShifted = const [],
    this.fearsOutwitted = const [],
    this.teamPromptId,
    required this.createdAt,
  });

  JournalEntry copyWith({
    String? id,
    String? uid,
    String? mode,
    String? mood,
    String? prompt,
    String? content,
    List<String>? limitingBeliefsShifted,
    List<String>? fearsOutwitted,
    String? teamPromptId,
    DateTime? createdAt,
  }) {
    return JournalEntry(
      id: id ?? this.id,
      uid: uid ?? this.uid,
      mode: mode ?? this.mode,
      mood: mood ?? this.mood,
      prompt: prompt ?? this.prompt,
      content: content ?? this.content,
      limitingBeliefsShifted: limitingBeliefsShifted ?? this.limitingBeliefsShifted,
      fearsOutwitted: fearsOutwitted ?? this.fearsOutwitted,
      teamPromptId: teamPromptId ?? this.teamPromptId,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  factory JournalEntry.fromJson(Map<String, dynamic> json) {
    return JournalEntry(
      id: json['id'] as String? ?? '',
      uid: json['uid'] as String? ?? '',
      mode: json['mode'] as String? ?? 'reflect',
      mood: json['mood'] as String? ?? 'neutral',
      prompt: json['prompt'] as String? ?? '',
      content: json['content'] as String? ?? '',
      limitingBeliefsShifted: List<String>.from(
        json['limitingBeliefsShifted'] as List<dynamic>? ?? [],
      ),
      fearsOutwitted: List<String>.from(
        json['fearsOutwitted'] as List<dynamic>? ?? [],
      ),
      teamPromptId: json['teamPromptId'] as String?,
      createdAt: DateTime.tryParse(json['createdAt'] as String? ?? '') ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'uid': uid,
        'mode': mode,
        'mood': mood,
        'prompt': prompt,
        'content': content,
        'limitingBeliefsShifted': limitingBeliefsShifted,
        'fearsOutwitted': fearsOutwitted,
        if (teamPromptId != null) 'teamPromptId': teamPromptId,
        'createdAt': createdAt.toIso8601String(),
      };
}
