/// Lightweight journal entry summary cached on UserProfile for AI context.
/// Keeps the last 14 entries so Claude always knows the user's mood history
/// without requiring an extra Firestore fetch.
class JournalSummary {
  final String date; // YYYY-MM-DD
  final String mood; // 'amazing' | 'good' | 'okay' | 'struggling' | 'low'
  final String mode; // 'reflect' | 'grow' | 'prime'
  final String snippet; // first 100 chars of journal content
  final String prompt; // AI-generated prompt question for this entry
  final List<String> limitingBeliefsShifted;
  final List<String> fearsOutwitted;

  const JournalSummary({
    required this.date,
    required this.mood,
    required this.mode,
    required this.snippet,
    this.prompt = '',
    this.limitingBeliefsShifted = const [],
    this.fearsOutwitted = const [],
  });

  static const _moodScores = {
    'amazing': 10,
    'good': 8,
    'okay': 6,
    'struggling': 3,
    'low': 1,
  };

  /// Numeric mood value (1–10) derived from the mood label.
  int get moodScore => _moodScores[mood] ?? 5;

  JournalSummary copyWith({
    String? date,
    String? mood,
    String? mode,
    String? snippet,
    String? prompt,
    List<String>? limitingBeliefsShifted,
    List<String>? fearsOutwitted,
  }) {
    return JournalSummary(
      date: date ?? this.date,
      mood: mood ?? this.mood,
      mode: mode ?? this.mode,
      snippet: snippet ?? this.snippet,
      prompt: prompt ?? this.prompt,
      limitingBeliefsShifted:
          limitingBeliefsShifted ?? this.limitingBeliefsShifted,
      fearsOutwitted: fearsOutwitted ?? this.fearsOutwitted,
    );
  }

  factory JournalSummary.fromJson(Map<String, dynamic> json) {
    return JournalSummary(
      date: json['date'] as String? ?? '',
      mood: json['mood'] as String? ?? 'okay',
      mode: json['mode'] as String? ?? 'reflect',
      snippet: json['snippet'] as String? ?? '',
      prompt: json['prompt'] as String? ?? '',
      limitingBeliefsShifted: List<String>.from(
        json['limitingBeliefsShifted'] as List<dynamic>? ?? [],
      ),
      fearsOutwitted: List<String>.from(
        json['fearsOutwitted'] as List<dynamic>? ?? [],
      ),
    );
  }

  Map<String, dynamic> toJson() => {
        'date': date,
        'mood': mood,
        'mode': mode,
        'snippet': snippet,
        'prompt': prompt,
        'limitingBeliefsShifted': limitingBeliefsShifted,
        'fearsOutwitted': fearsOutwitted,
      };
}
