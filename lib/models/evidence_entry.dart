class EvidenceEntry {
  final String id;
  final String content;
  final DateTime createdAt;

  const EvidenceEntry({
    required this.id,
    required this.content,
    required this.createdAt,
  });

  EvidenceEntry copyWith({
    String? id,
    String? content,
    DateTime? createdAt,
  }) {
    return EvidenceEntry(
      id: id ?? this.id,
      content: content ?? this.content,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  factory EvidenceEntry.fromJson(Map<String, dynamic> json) {
    return EvidenceEntry(
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
