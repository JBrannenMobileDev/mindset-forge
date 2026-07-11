/// Point-in-time Manifestation Alignment Score archived on [UserProfile].
class AlignmentSnapshot {
  static const int historyMax = 12;

  final double overall;
  final double subconscious;
  final double thought;
  final double action;
  final double results;

  /// yyyy-MM-dd local date when the snapshot was taken.
  final String date;

  const AlignmentSnapshot({
    required this.overall,
    required this.subconscious,
    required this.thought,
    required this.action,
    required this.results,
    required this.date,
  });

  AlignmentSnapshot copyWith({
    double? overall,
    double? subconscious,
    double? thought,
    double? action,
    double? results,
    String? date,
  }) {
    return AlignmentSnapshot(
      overall: overall ?? this.overall,
      subconscious: subconscious ?? this.subconscious,
      thought: thought ?? this.thought,
      action: action ?? this.action,
      results: results ?? this.results,
      date: date ?? this.date,
    );
  }

  factory AlignmentSnapshot.fromJson(Map<String, dynamic> json) {
    return AlignmentSnapshot(
      overall: (json['overall'] as num?)?.toDouble() ?? 0,
      subconscious: (json['subconscious'] as num?)?.toDouble() ?? 0,
      thought: (json['thought'] as num?)?.toDouble() ?? 0,
      action: (json['action'] as num?)?.toDouble() ?? 0,
      results: (json['results'] as num?)?.toDouble() ?? 0,
      date: json['date'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
        'overall': overall,
        'subconscious': subconscious,
        'thought': thought,
        'action': action,
        'results': results,
        'date': date,
      };
}
