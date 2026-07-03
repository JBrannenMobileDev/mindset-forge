/// Structured weekly coaching review persisted on [UserProfile].
class WeeklyInsight {
  static const int historyMax = 12;

  final String pattern;
  final String breakthrough;
  final String focus;
  final String generatedAt;
  final String? viewedAt;

  /// yyyy-MM-dd for the Sunday this report covers (week ending date).
  final String weekEnding;

  const WeeklyInsight({
    required this.pattern,
    required this.breakthrough,
    required this.focus,
    required this.generatedAt,
    this.viewedAt,
    required this.weekEnding,
  });

  bool get isUnread => viewedAt == null;

  bool get hasContent =>
      pattern.isNotEmpty || breakthrough.isNotEmpty || focus.isNotEmpty;

  WeeklyInsight copyWith({
    String? pattern,
    String? breakthrough,
    String? focus,
    String? generatedAt,
    String? viewedAt,
    String? weekEnding,
  }) {
    return WeeklyInsight(
      pattern: pattern ?? this.pattern,
      breakthrough: breakthrough ?? this.breakthrough,
      focus: focus ?? this.focus,
      generatedAt: generatedAt ?? this.generatedAt,
      viewedAt: viewedAt ?? this.viewedAt,
      weekEnding: weekEnding ?? this.weekEnding,
    );
  }

  /// Returns null for legacy prose-only docs (`{ text: "..." }`).
  static WeeklyInsight? tryFromJson(Map<String, dynamic>? json) {
    if (json == null) return null;
    if (json['pattern'] == null &&
        json['breakthrough'] == null &&
        json['focus'] == null) {
      return null;
    }
    return WeeklyInsight.fromJson(json);
  }

  factory WeeklyInsight.fromJson(Map<String, dynamic> json) {
    return WeeklyInsight(
      pattern: json['pattern'] as String? ?? '',
      breakthrough: json['breakthrough'] as String? ?? '',
      focus: json['focus'] as String? ?? '',
      generatedAt: json['generatedAt'] as String? ?? '',
      viewedAt: json['viewedAt'] as String?,
      weekEnding: json['weekEnding'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
        'pattern': pattern,
        'breakthrough': breakthrough,
        'focus': focus,
        'generatedAt': generatedAt,
        if (viewedAt != null) 'viewedAt': viewedAt,
        'weekEnding': weekEnding,
      };

  factory WeeklyInsight.fromSections({
    required Map<String, String> sections,
    required String weekEnding,
    String? viewedAt,
  }) {
    return WeeklyInsight(
      pattern: sections['pattern'] ?? '',
      breakthrough: sections['breakthrough'] ?? '',
      focus: sections['focus'] ?? '',
      generatedAt: DateTime.now().toIso8601String(),
      viewedAt: viewedAt,
      weekEnding: weekEnding,
    );
  }
}
