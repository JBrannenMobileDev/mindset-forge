class Affirmation {
  final String id;
  final String text;
  final String source;
  final String category;
  final bool isActive;
  final DateTime createdAt;

  const Affirmation({
    required this.id,
    required this.text,
    this.source = 'custom',
    this.category = 'general',
    this.isActive = true,
    required this.createdAt,
  });

  Affirmation copyWith({
    String? id,
    String? text,
    String? source,
    String? category,
    bool? isActive,
    DateTime? createdAt,
  }) {
    return Affirmation(
      id: id ?? this.id,
      text: text ?? this.text,
      source: source ?? this.source,
      category: category ?? this.category,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  factory Affirmation.fromJson(Map<String, dynamic> json) {
    return Affirmation(
      id: json['id'] as String? ?? '',
      text: json['text'] as String? ?? '',
      source: json['source'] as String? ?? 'custom',
      category: json['category'] as String? ?? 'general',
      isActive: json['isActive'] as bool? ?? true,
      createdAt: DateTime.tryParse(json['createdAt'] as String? ?? '') ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'text': text,
        'source': source,
        'category': category,
        'isActive': isActive,
        'createdAt': createdAt.toIso8601String(),
      };
}

/// Per-date session record (mirrors web app schema).
class AffirmationCompletion {
  final String date; // YYYY-MM-DD (with grace period applied)
  final bool morningCompleted;
  final bool eveningCompleted;
  final DateTime? morningTime;
  final DateTime? eveningTime;

  const AffirmationCompletion({
    required this.date,
    this.morningCompleted = false,
    this.eveningCompleted = false,
    this.morningTime,
    this.eveningTime,
  });

  bool get bothCompleted => morningCompleted && eveningCompleted;

  AffirmationCompletion copyWith({
    String? date,
    bool? morningCompleted,
    bool? eveningCompleted,
    DateTime? morningTime,
    DateTime? eveningTime,
  }) {
    return AffirmationCompletion(
      date: date ?? this.date,
      morningCompleted: morningCompleted ?? this.morningCompleted,
      eveningCompleted: eveningCompleted ?? this.eveningCompleted,
      morningTime: morningTime ?? this.morningTime,
      eveningTime: eveningTime ?? this.eveningTime,
    );
  }

  factory AffirmationCompletion.fromJson(Map<String, dynamic> json) {
    return AffirmationCompletion(
      date: json['date'] as String? ?? '',
      morningCompleted:
          (json['morningCompleted'] ?? json['morning_completed']) as bool? ??
              false,
      eveningCompleted:
          (json['eveningCompleted'] ?? json['evening_completed']) as bool? ??
              false,
      morningTime: json['morningTime'] != null
          ? DateTime.tryParse(json['morningTime'] as String)
          : null,
      eveningTime: json['eveningTime'] != null
          ? DateTime.tryParse(json['eveningTime'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() => {
        'date': date,
        'morningCompleted': morningCompleted,
        'eveningCompleted': eveningCompleted,
        'morningTime': morningTime?.toIso8601String(),
        'eveningTime': eveningTime?.toIso8601String(),
      };
}
