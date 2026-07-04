import 'mindset_blueprint.dart';

/// A point-in-time Blueprint self-assessment archived on [UserProfile].
class BlueprintSnapshot {
  static const int historyMax = 12;

  final MindsetBlueprint blueprint;
  final String createdAt;
  final String source;

  /// One-line explanation per trait key (e.g. `discipline`) for automatic updates.
  final Map<String, String> rationale;

  const BlueprintSnapshot({
    required this.blueprint,
    required this.createdAt,
    this.source = 'self_assessment',
    this.rationale = const {},
  });

  BlueprintSnapshot copyWith({
    MindsetBlueprint? blueprint,
    String? createdAt,
    String? source,
    Map<String, String>? rationale,
  }) {
    return BlueprintSnapshot(
      blueprint: blueprint ?? this.blueprint,
      createdAt: createdAt ?? this.createdAt,
      source: source ?? this.source,
      rationale: rationale ?? this.rationale,
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
      rationale: Map<String, String>.from(
        json['rationale'] as Map? ?? {},
      ),
    );
  }

  Map<String, dynamic> toJson() => {
        'blueprint': blueprint.toJson(),
        'createdAt': createdAt,
        'source': source,
        if (rationale.isNotEmpty) 'rationale': rationale,
      };
}
