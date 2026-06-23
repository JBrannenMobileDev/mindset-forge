class GratitudeEntry {
  final String id;
  final String content;
  final DateTime createdAt;

  const GratitudeEntry({
    required this.id,
    required this.content,
    required this.createdAt,
  });

  GratitudeEntry copyWith({
    String? id,
    String? content,
    DateTime? createdAt,
  }) {
    return GratitudeEntry(
      id: id ?? this.id,
      content: content ?? this.content,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  factory GratitudeEntry.fromJson(Map<String, dynamic> json) {
    return GratitudeEntry(
      id: json['id'] as String? ?? '',
      content: json['content'] as String? ?? '',
      createdAt: DateTime.tryParse(json['createdAt'] as String? ?? '') ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'content': content,
        'createdAt': createdAt.toIso8601String(),
      };
}
