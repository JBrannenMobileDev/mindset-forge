class FutureSelfSetup {
  final int timeframeYears;
  final String lifeDescription;
  final String goalsAchieved;
  final String evolvedIdentity;
  final List<String> coreBehaviors;
  final String? generatedScript;
  final DateTime createdAt;

  const FutureSelfSetup({
    required this.timeframeYears,
    required this.lifeDescription,
    required this.goalsAchieved,
    required this.evolvedIdentity,
    required this.coreBehaviors,
    this.generatedScript,
    required this.createdAt,
  });

  FutureSelfSetup copyWith({
    int? timeframeYears,
    String? lifeDescription,
    String? goalsAchieved,
    String? evolvedIdentity,
    List<String>? coreBehaviors,
    String? generatedScript,
    DateTime? createdAt,
  }) {
    return FutureSelfSetup(
      timeframeYears: timeframeYears ?? this.timeframeYears,
      lifeDescription: lifeDescription ?? this.lifeDescription,
      goalsAchieved: goalsAchieved ?? this.goalsAchieved,
      evolvedIdentity: evolvedIdentity ?? this.evolvedIdentity,
      coreBehaviors: coreBehaviors ?? this.coreBehaviors,
      generatedScript: generatedScript ?? this.generatedScript,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  factory FutureSelfSetup.fromJson(Map<String, dynamic> json) {
    return FutureSelfSetup(
      timeframeYears: (json['timeframeYears'] as num?)?.toInt() ?? 5,
      lifeDescription: json['lifeDescription'] as String? ?? '',
      goalsAchieved: json['goalsAchieved'] as String? ?? '',
      evolvedIdentity: json['evolvedIdentity'] as String? ?? '',
      coreBehaviors:
          List<String>.from(json['coreBehaviors'] as List<dynamic>? ?? []),
      generatedScript: json['generatedScript'] as String?,
      createdAt: DateTime.tryParse(json['createdAt'] as String? ?? '') ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() => {
        'timeframeYears': timeframeYears,
        'lifeDescription': lifeDescription,
        'goalsAchieved': goalsAchieved,
        'evolvedIdentity': evolvedIdentity,
        'coreBehaviors': coreBehaviors,
        'generatedScript': generatedScript,
        'createdAt': createdAt.toIso8601String(),
      };
}

