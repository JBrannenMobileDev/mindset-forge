class MindsetBlueprint {
  final double confidence;
  final double discipline;
  final double abundanceThinking;
  final double resilience;
  final double decisiveness;

  const MindsetBlueprint({
    this.confidence = 5.0,
    this.discipline = 5.0,
    this.abundanceThinking = 5.0,
    this.resilience = 5.0,
    this.decisiveness = 5.0,
  });

  double get average =>
      (confidence + discipline + abundanceThinking + resilience + decisiveness) / 5;

  MindsetBlueprint copyWith({
    double? confidence,
    double? discipline,
    double? abundanceThinking,
    double? resilience,
    double? decisiveness,
  }) {
    return MindsetBlueprint(
      confidence: confidence ?? this.confidence,
      discipline: discipline ?? this.discipline,
      abundanceThinking: abundanceThinking ?? this.abundanceThinking,
      resilience: resilience ?? this.resilience,
      decisiveness: decisiveness ?? this.decisiveness,
    );
  }

  factory MindsetBlueprint.fromJson(Map<String, dynamic> json) {
    return MindsetBlueprint(
      confidence: (json['confidence'] as num?)?.toDouble() ?? 5.0,
      discipline: (json['discipline'] as num?)?.toDouble() ?? 5.0,
      abundanceThinking: (json['abundanceThinking'] as num?)?.toDouble() ?? 5.0,
      resilience: (json['resilience'] as num?)?.toDouble() ?? 5.0,
      decisiveness: (json['decisiveness'] as num?)?.toDouble() ?? 5.0,
    );
  }

  Map<String, dynamic> toJson() => {
        'confidence': confidence,
        'discipline': discipline,
        'abundanceThinking': abundanceThinking,
        'resilience': resilience,
        'decisiveness': decisiveness,
      };
}
