/// A point-in-time snapshot of the user's identity statement.
class IdentityVersion {
  static const int historyMax = 12;

  final String statement;
  final String createdAt;
  final String source;
  final String rationale;

  const IdentityVersion({
    required this.statement,
    required this.createdAt,
    this.source = 'onboarding',
    this.rationale = '',
  });

  IdentityVersion copyWith({
    String? statement,
    String? createdAt,
    String? source,
    String? rationale,
  }) {
    return IdentityVersion(
      statement: statement ?? this.statement,
      createdAt: createdAt ?? this.createdAt,
      source: source ?? this.source,
      rationale: rationale ?? this.rationale,
    );
  }

  factory IdentityVersion.fromJson(Map<String, dynamic> json) {
    return IdentityVersion(
      statement: json['statement'] as String? ?? '',
      createdAt: json['createdAt'] as String? ?? '',
      source: json['source'] as String? ?? 'onboarding',
      rationale: json['rationale'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
        'statement': statement,
        'createdAt': createdAt,
        'source': source,
        if (rationale.isNotEmpty) 'rationale': rationale,
      };
}
