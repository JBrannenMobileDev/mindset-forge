/// A commitment the user made to themselves during a coaching session.
class CoachCommitment {
  final String id;
  final String text;
  final DateTime createdAt;
  final bool fulfilled;

  const CoachCommitment({
    required this.id,
    required this.text,
    required this.createdAt,
    this.fulfilled = false,
  });

  CoachCommitment copyWith({
    String? id,
    String? text,
    DateTime? createdAt,
    bool? fulfilled,
  }) {
    return CoachCommitment(
      id: id ?? this.id,
      text: text ?? this.text,
      createdAt: createdAt ?? this.createdAt,
      fulfilled: fulfilled ?? this.fulfilled,
    );
  }

  factory CoachCommitment.fromJson(Map<String, dynamic> json) {
    return CoachCommitment(
      id: json['id'] as String? ?? '',
      text: json['text'] as String? ?? '',
      createdAt:
          DateTime.tryParse(json['createdAt'] as String? ?? '') ?? DateTime.now(),
      fulfilled: json['fulfilled'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'text': text,
        'createdAt': createdAt.toIso8601String(),
        'fulfilled': fulfilled,
      };
}

/// Persistent cross-session memory for the AI coach.
///
/// Lets the coach feel continuous: it remembers the last session, recurring
/// patterns, and open commitments, so every new conversation starts already
/// knowing the user. Updated from the structured `memory_updates` the coach
/// returns after each exchange.
class CoachMemory {
  /// A rolling, AI-maintained summary of who the user is and where they are.
  final String longTermSummary;

  /// One- or two-sentence recap of the most recent coaching session.
  final String lastSessionSummary;

  /// When the last session occurred.
  final DateTime? lastSessionAt;

  /// Things the user committed to doing.
  final List<CoachCommitment> openCommitments;

  /// Recurring patterns the coach has noticed (short, specific phrases).
  final List<String> recurringPatterns;

  /// Breakthrough or emotionally significant moments worth remembering.
  final List<String> keyMoments;

  const CoachMemory({
    this.longTermSummary = '',
    this.lastSessionSummary = '',
    this.lastSessionAt,
    this.openCommitments = const [],
    this.recurringPatterns = const [],
    this.keyMoments = const [],
  });

  bool get isEmpty =>
      longTermSummary.isEmpty &&
      lastSessionSummary.isEmpty &&
      openCommitments.isEmpty &&
      recurringPatterns.isEmpty &&
      keyMoments.isEmpty;

  CoachMemory copyWith({
    String? longTermSummary,
    String? lastSessionSummary,
    DateTime? lastSessionAt,
    List<CoachCommitment>? openCommitments,
    List<String>? recurringPatterns,
    List<String>? keyMoments,
  }) {
    return CoachMemory(
      longTermSummary: longTermSummary ?? this.longTermSummary,
      lastSessionSummary: lastSessionSummary ?? this.lastSessionSummary,
      lastSessionAt: lastSessionAt ?? this.lastSessionAt,
      openCommitments: openCommitments ?? this.openCommitments,
      recurringPatterns: recurringPatterns ?? this.recurringPatterns,
      keyMoments: keyMoments ?? this.keyMoments,
    );
  }

  factory CoachMemory.empty() => const CoachMemory();

  factory CoachMemory.fromJson(Map<String, dynamic> json) {
    return CoachMemory(
      longTermSummary: json['longTermSummary'] as String? ?? '',
      lastSessionSummary: json['lastSessionSummary'] as String? ?? '',
      lastSessionAt: json['lastSessionAt'] != null
          ? DateTime.tryParse(json['lastSessionAt'] as String)
          : null,
      openCommitments: (json['openCommitments'] as List<dynamic>?)
              ?.map((e) => CoachCommitment.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      recurringPatterns:
          List<String>.from(json['recurringPatterns'] as List<dynamic>? ?? []),
      keyMoments: List<String>.from(json['keyMoments'] as List<dynamic>? ?? []),
    );
  }

  Map<String, dynamic> toJson() => {
        'longTermSummary': longTermSummary,
        'lastSessionSummary': lastSessionSummary,
        'lastSessionAt': lastSessionAt?.toIso8601String(),
        'openCommitments': openCommitments.map((c) => c.toJson()).toList(),
        'recurringPatterns': recurringPatterns,
        'keyMoments': keyMoments,
      };
}
