import 'action_step.dart';

/// Valid timeframe values for [Goal.goalType].
const String kGoalTypeShortTerm = 'short_term';
const String kGoalTypeMediumTerm = 'medium_term';
const String kGoalTypeLongTerm = 'long_term';
const String kGoalTypeLifeGoal = 'life_goal';

class Goal {
  final String id;
  final String title;
  final String category;

  /// Timeframe horizon: short_term | medium_term | long_term | life_goal.
  /// Independent of [parentGoalId] (which expresses the milestone hierarchy).
  final String goalType;
  final String description;
  final String? parentGoalId;
  final DateTime targetDate;

  /// Deprecated: visualization now lives exclusively in the Future Self
  /// Practice. Kept only for backward-compatible deserialization; never set
  /// by any creation flow.
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
    this.goalType = kGoalTypeLongTerm,
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

  /// Whether this goal sits on a long enough horizon to benefit from an AI
  /// milestone breakdown at creation time.
  bool get isLongHorizon =>
      goalType == kGoalTypeLongTerm || goalType == kGoalTypeLifeGoal;

  Goal copyWith({
    String? id,
    String? title,
    String? category,
    String? goalType,
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
      goalType: goalType ?? this.goalType,
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
      // Back-compat: older goals have no goalType. Infer from the hierarchy —
      // sub-goals are short-term milestones, top-level goals are long-term.
      goalType: json['goalType'] as String? ??
          (json['parentGoalId'] != null ? kGoalTypeShortTerm : kGoalTypeLongTerm),
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
        'goalType': goalType,
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
