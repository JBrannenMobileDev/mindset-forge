import 'action_step.dart';

class Goal {
  final String id;
  final String title;
  final String category;
  final String description;
  final String? parentGoalId;
  final DateTime targetDate;
  final String visualizationText;
  final String identityBecomes;
  final double progressPercent;
  final List<ActionStep> actionSteps;
  final String status;
  final DateTime? completedAt;
  final DateTime createdAt;

  const Goal({
    required this.id,
    required this.title,
    required this.category,
    this.description = '',
    this.parentGoalId,
    required this.targetDate,
    this.visualizationText = '',
    this.identityBecomes = '',
    this.progressPercent = 0.0,
    this.actionSteps = const [],
    this.status = 'active',
    this.completedAt,
    required this.createdAt,
  });

  bool get isLongTerm => parentGoalId == null;
  bool get isCompleted => status == 'completed';

  Goal copyWith({
    String? id,
    String? title,
    String? category,
    String? description,
    String? parentGoalId,
    DateTime? targetDate,
    String? visualizationText,
    String? identityBecomes,
    double? progressPercent,
    List<ActionStep>? actionSteps,
    String? status,
    DateTime? completedAt,
    DateTime? createdAt,
  }) {
    return Goal(
      id: id ?? this.id,
      title: title ?? this.title,
      category: category ?? this.category,
      description: description ?? this.description,
      parentGoalId: parentGoalId ?? this.parentGoalId,
      targetDate: targetDate ?? this.targetDate,
      visualizationText: visualizationText ?? this.visualizationText,
      identityBecomes: identityBecomes ?? this.identityBecomes,
      progressPercent: progressPercent ?? this.progressPercent,
      actionSteps: actionSteps ?? this.actionSteps,
      status: status ?? this.status,
      completedAt: completedAt ?? this.completedAt,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  factory Goal.fromJson(Map<String, dynamic> json) {
    return Goal(
      id: json['id'] as String? ?? '',
      title: json['title'] as String? ?? '',
      category: json['category'] as String? ?? 'personal',
      description: json['description'] as String? ?? '',
      parentGoalId: json['parentGoalId'] as String?,
      targetDate: DateTime.tryParse(json['targetDate'] as String? ?? '') ??
          DateTime.now().add(const Duration(days: 90)),
      visualizationText: json['visualizationText'] as String? ?? '',
      identityBecomes: json['identityBecomes'] as String? ?? '',
      progressPercent: (json['progressPercent'] as num?)?.toDouble() ?? 0.0,
      actionSteps: (json['actionSteps'] as List<dynamic>?)
              ?.map((e) => ActionStep.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      status: json['status'] as String? ?? 'active',
      completedAt: json['completedAt'] != null
          ? DateTime.tryParse(json['completedAt'] as String)
          : null,
      createdAt: DateTime.tryParse(json['createdAt'] as String? ?? '') ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'category': category,
        'description': description,
        'parentGoalId': parentGoalId,
        'targetDate': targetDate.toIso8601String(),
        'visualizationText': visualizationText,
        'identityBecomes': identityBecomes,
        'progressPercent': progressPercent,
        'actionSteps': actionSteps.map((s) => s.toJson()).toList(),
        'status': status,
        'completedAt': completedAt?.toIso8601String(),
        'createdAt': createdAt.toIso8601String(),
      };
}
