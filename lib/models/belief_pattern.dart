class BeliefPattern {
  final String id;
  final String belief;
  final String reframe;
  final DateTime identifiedAt;

  const BeliefPattern({
    required this.id,
    required this.belief,
    required this.reframe,
    required this.identifiedAt,
  });

  BeliefPattern copyWith({
    String? id,
    String? belief,
    String? reframe,
    DateTime? identifiedAt,
  }) {
    return BeliefPattern(
      id: id ?? this.id,
      belief: belief ?? this.belief,
      reframe: reframe ?? this.reframe,
      identifiedAt: identifiedAt ?? this.identifiedAt,
    );
  }

  factory BeliefPattern.fromJson(Map<String, dynamic> json) {
    return BeliefPattern(
      id: json['id'] as String? ?? '',
      belief: json['belief'] as String? ?? '',
      reframe: json['reframe'] as String? ?? '',
      identifiedAt:
          DateTime.tryParse(json['identifiedAt'] as String? ?? '') ??
              DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'belief': belief,
        'reframe': reframe,
        'identifiedAt': identifiedAt.toIso8601String(),
      };
}
