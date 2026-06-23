class ManifestationAlignment {
  final double subconscious;
  final double thought;
  final double action;
  final double results;
  final DateTime recordedAt;

  const ManifestationAlignment({
    this.subconscious = 50.0,
    this.thought = 50.0,
    this.action = 50.0,
    this.results = 50.0,
    required this.recordedAt,
  });

  double get overall =>
      (subconscious * 0.35) + (thought * 0.25) + (action * 0.25) + (results * 0.15);

  String get masteryLevel {
    final score = overall;
    if (score < 20) return 'Awakening';
    if (score < 40) return 'Shifting';
    if (score < 60) return 'Building';
    if (score < 80) return 'Manifesting';
    return 'Mastery';
  }

  ManifestationAlignment copyWith({
    double? subconscious,
    double? thought,
    double? action,
    double? results,
    DateTime? recordedAt,
  }) {
    return ManifestationAlignment(
      subconscious: subconscious ?? this.subconscious,
      thought: thought ?? this.thought,
      action: action ?? this.action,
      results: results ?? this.results,
      recordedAt: recordedAt ?? this.recordedAt,
    );
  }

  factory ManifestationAlignment.initial() {
    return ManifestationAlignment(recordedAt: DateTime.now());
  }

  factory ManifestationAlignment.fromJson(Map<String, dynamic> json) {
    return ManifestationAlignment(
      subconscious: (json['subconscious'] as num?)?.toDouble() ?? 50.0,
      thought: (json['thought'] as num?)?.toDouble() ?? 50.0,
      action: (json['action'] as num?)?.toDouble() ?? 50.0,
      results: (json['results'] as num?)?.toDouble() ?? 50.0,
      recordedAt: json['recordedAt'] != null
          ? DateTime.parse(json['recordedAt'] as String)
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() => {
        'subconscious': subconscious,
        'thought': thought,
        'action': action,
        'results': results,
        'recordedAt': recordedAt.toIso8601String(),
      };
}
