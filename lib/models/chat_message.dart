class ChatMessage {
  final String id;
  final String role;
  final String content;
  final DateTime timestamp;
  final int? feedback;

  /// Coaching mode label for assistant messages (e.g. 'Reframe'). Null for
  /// user messages or when the coach did not classify a mode.
  final String? mode;

  /// Safety classification for assistant messages: 'none' | 'concern' | 'crisis'.
  final String? safety;

  const ChatMessage({
    required this.id,
    required this.role,
    required this.content,
    required this.timestamp,
    this.feedback,
    this.mode,
    this.safety,
  });

  bool get isUser => role == 'user';
  bool get isAssistant => role == 'assistant';
  bool get isCrisis => safety == 'crisis';

  ChatMessage copyWith({
    String? id,
    String? role,
    String? content,
    DateTime? timestamp,
    int? feedback,
    String? mode,
    String? safety,
  }) {
    return ChatMessage(
      id: id ?? this.id,
      role: role ?? this.role,
      content: content ?? this.content,
      timestamp: timestamp ?? this.timestamp,
      feedback: feedback ?? this.feedback,
      mode: mode ?? this.mode,
      safety: safety ?? this.safety,
    );
  }

  Map<String, String> toApiFormat() => {
        'role': role,
        'content': content,
      };

  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    return ChatMessage(
      id: json['id'] as String? ?? '',
      role: json['role'] as String? ?? 'user',
      content: json['content'] as String? ?? '',
      timestamp: DateTime.tryParse(json['timestamp'] as String? ?? '') ?? DateTime.now(),
      feedback: (json['feedback'] as num?)?.toInt(),
      mode: json['mode'] as String?,
      safety: json['safety'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'role': role,
        'content': content,
        'timestamp': timestamp.toIso8601String(),
        'feedback': feedback,
        'mode': mode,
        'safety': safety,
      };
}
