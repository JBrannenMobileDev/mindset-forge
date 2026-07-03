import 'mindset_blueprint.dart';

/// A point-in-time Blueprint self-assessment archived on [UserProfile].
class BlueprintSnapshot {
  static const int historyMax = 12;

  final MindsetBlueprint blueprint;
  final String createdAt;
  final String source;

  const BlueprintSnapshot({
    required this.blueprint,
    required this.createdAt,
    this.source = 'self_assessment',
  });

  BlueprintSnapshot copyWith({
    MindsetBlueprint? blueprint,
    String? createdAt,
    String? source,
  }) {
    return BlueprintSnapshot(
      blueprint: blueprint ?? this.blueprint,
      createdAt: createdAt ?? this.createdAt,
      source: source ?? this.source,
    );
  }

  factory BlueprintSnapshot.fromJson(Map<String, dynamic> json) {
    return BlueprintSnapshot(
      blueprint: json['blueprint'] != null
          ? MindsetBlueprint.fromJson(
              json['blueprint'] as Map<String, dynamic>,
            )
          : const MindsetBlueprint(),
      createdAt: json['createdAt'] as String? ?? '',
      source: json['source'] as String? ?? 'self_assessment',
    );
  }

  Map<String, dynamic> toJson() => {
        'blueprint': blueprint.toJson(),
        'createdAt': createdAt,
        'source': source,
      };
}
