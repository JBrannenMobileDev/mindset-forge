import 'chat_message.dart';

class ChatSession {
  final String id;
  final String uid;
  final String mode;
  final String topic;
  final List<ChatMessage> messages;
  final DateTime createdAt;
  final DateTime updatedAt;

  const ChatSession({
    required this.id,
    required this.uid,
    required this.mode,
    this.topic = 'New Session',
    this.messages = const [],
    required this.createdAt,
    required this.updatedAt,
  });

  String get lastMessagePreview {
    if (messages.isEmpty) return 'No messages yet';
    return messages.last.content.length > 60
        ? '${messages.last.content.substring(0, 60)}...'
        : messages.last.content;
  }

  ChatSession copyWith({
    String? id,
    String? uid,
    String? mode,
    String? topic,
    List<ChatMessage>? messages,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return ChatSession(
      id: id ?? this.id,
      uid: uid ?? this.uid,
      mode: mode ?? this.mode,
      topic: topic ?? this.topic,
      messages: messages ?? this.messages,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  factory ChatSession.fromJson(Map<String, dynamic> json) {
    final createdAtStr = json['createdAt'] as String? ?? '';
    return ChatSession(
      id: json['id'] as String? ?? '',
      uid: json['uid'] as String? ?? '',
      mode: json['mode'] as String? ?? 'coach',
      topic: json['topic'] as String? ?? 'Session',
      messages: (json['messages'] as List<dynamic>?)
              ?.map((e) => ChatMessage.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      createdAt: DateTime.tryParse(createdAtStr) ?? DateTime.now(),
      updatedAt: DateTime.tryParse(
            json['updatedAt'] as String? ?? createdAtStr,
          ) ??
          DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'uid': uid,
        'mode': mode,
        'topic': topic,
        'messages': messages.map((m) => m.toJson()).toList(),
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
      };
}
