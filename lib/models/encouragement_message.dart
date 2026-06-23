class EncouragementMessage {
  final String id;
  final String fromUid;
  final String fromName;
  final String message;
  final String sentAt;
  final bool read;

  const EncouragementMessage({
    required this.id,
    required this.fromUid,
    required this.fromName,
    required this.message,
    required this.sentAt,
    this.read = false,
  });

  EncouragementMessage copyWith({
    String? id,
    String? fromUid,
    String? fromName,
    String? message,
    String? sentAt,
    bool? read,
  }) {
    return EncouragementMessage(
      id: id ?? this.id,
      fromUid: fromUid ?? this.fromUid,
      fromName: fromName ?? this.fromName,
      message: message ?? this.message,
      sentAt: sentAt ?? this.sentAt,
      read: read ?? this.read,
    );
  }

  factory EncouragementMessage.fromJson(Map<String, dynamic> json) {
    return EncouragementMessage(
      id: json['id'] as String? ?? '',
      fromUid: json['fromUid'] as String? ?? '',
      fromName: json['fromName'] as String? ?? 'Partner',
      message: json['message'] as String? ?? '',
      sentAt: json['sentAt'] as String? ?? DateTime.now().toIso8601String(),
      read: json['read'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'fromUid': fromUid,
        'fromName': fromName,
        'message': message,
        'sentAt': sentAt,
        'read': read,
      };
}
