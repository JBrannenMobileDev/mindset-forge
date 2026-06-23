class ActionStep {
  final String id;
  final String description;
  final bool isCompleted;
  final DateTime? completedAt;

  const ActionStep({
    required this.id,
    required this.description,
    this.isCompleted = false,
    this.completedAt,
  });

  ActionStep copyWith({
    String? id,
    String? description,
    bool? isCompleted,
    DateTime? completedAt,
  }) {
    return ActionStep(
      id: id ?? this.id,
      description: description ?? this.description,
      isCompleted: isCompleted ?? this.isCompleted,
      completedAt: completedAt ?? this.completedAt,
    );
  }

  factory ActionStep.fromJson(Map<String, dynamic> json) {
    return ActionStep(
      id: json['id'] as String? ?? '',
      description: json['description'] as String? ?? '',
      isCompleted: json['isCompleted'] as bool? ?? false,
      completedAt: json['completedAt'] != null
          ? DateTime.tryParse(json['completedAt'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'description': description,
        'isCompleted': isCompleted,
        'completedAt': completedAt?.toIso8601String(),
      };
}
