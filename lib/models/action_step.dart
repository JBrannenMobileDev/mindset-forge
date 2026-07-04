/// A single milestone in a goal's checklist. Completing steps is the honest,
/// discrete way a goal's progress advances — no self-reported slider.
///
/// Carries the payload the AI goal breakdown produces (title, description, why
/// it matters, a target date) so an AI-generated milestone and a hand-typed one
/// are the same shape.
class ActionStep {
  final String id;

  /// Primary label for the milestone. Legacy steps persisted only
  /// [description]; [label] falls back to it so nothing renders blank.
  final String title;

  /// Optional supporting detail (one sentence on what to do).
  final String description;

  /// Optional one-liner on why this milestone matters.
  final String whyImportant;

  /// Sort position within the goal's checklist (ascending).
  final int order;

  /// Optional soft due date for the milestone.
  final DateTime? targetDate;

  final bool isCompleted;
  final DateTime? completedAt;

  const ActionStep({
    required this.id,
    this.title = '',
    this.description = '',
    this.whyImportant = '',
    this.order = 0,
    this.targetDate,
    this.isCompleted = false,
    this.completedAt,
  });

  /// The text to show for this milestone, tolerating legacy steps that only
  /// stored [description].
  String get label => title.isNotEmpty ? title : description;

  ActionStep copyWith({
    String? id,
    String? title,
    String? description,
    String? whyImportant,
    int? order,
    DateTime? targetDate,
    bool? isCompleted,
    DateTime? completedAt,
  }) {
    return ActionStep(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      whyImportant: whyImportant ?? this.whyImportant,
      order: order ?? this.order,
      targetDate: targetDate ?? this.targetDate,
      isCompleted: isCompleted ?? this.isCompleted,
      completedAt: completedAt ?? this.completedAt,
    );
  }

  factory ActionStep.fromJson(Map<String, dynamic> json) {
    return ActionStep(
      id: json['id'] as String? ?? '',
      title: json['title'] as String? ?? '',
      description: json['description'] as String? ?? '',
      whyImportant: json['whyImportant'] as String? ?? '',
      order: (json['order'] as num?)?.toInt() ?? 0,
      targetDate: json['targetDate'] != null
          ? DateTime.tryParse(json['targetDate'] as String)
          : null,
      isCompleted: json['isCompleted'] as bool? ?? false,
      completedAt: json['completedAt'] != null
          ? DateTime.tryParse(json['completedAt'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'description': description,
        'whyImportant': whyImportant,
        'order': order,
        'targetDate': targetDate?.toIso8601String(),
        'isCompleted': isCompleted,
        'completedAt': completedAt?.toIso8601String(),
      };
}
