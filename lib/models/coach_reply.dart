import 'dart:convert';

/// A belief→reframe pair the coach surfaced during a turn.
class CoachBeliefReframe {
  final String belief;
  final String reframe;

  const CoachBeliefReframe({required this.belief, required this.reframe});

  factory CoachBeliefReframe.fromJson(Map<String, dynamic> json) =>
      CoachBeliefReframe(
        belief: json['belief'] as String? ?? '',
        reframe: json['reframe'] as String? ?? '',
      );
}

/// Structured memory the coach asks the app to persist after a turn.
class CoachMemoryUpdate {
  final String sessionSummary;
  final String longTermSummary;
  final List<String> newCommitments;
  final List<String> fulfilledCommitments;
  final List<String> patterns;
  final List<String> keyMoments;
  final List<CoachBeliefReframe> beliefReframes;

  const CoachMemoryUpdate({
    this.sessionSummary = '',
    this.longTermSummary = '',
    this.newCommitments = const [],
    this.fulfilledCommitments = const [],
    this.patterns = const [],
    this.keyMoments = const [],
    this.beliefReframes = const [],
  });

  bool get isEmpty =>
      sessionSummary.isEmpty &&
      longTermSummary.isEmpty &&
      newCommitments.isEmpty &&
      fulfilledCommitments.isEmpty &&
      patterns.isEmpty &&
      keyMoments.isEmpty &&
      beliefReframes.isEmpty;

  factory CoachMemoryUpdate.fromJson(Map<String, dynamic> json) {
    List<String> strList(dynamic v) =>
        (v as List<dynamic>?)?.map((e) => e.toString()).toList() ?? const [];

    return CoachMemoryUpdate(
      sessionSummary: json['session_summary'] as String? ?? '',
      longTermSummary: json['long_term_summary'] as String? ?? '',
      newCommitments: strList(json['new_commitments']),
      fulfilledCommitments: strList(json['fulfilled_commitments']),
      patterns: strList(json['patterns']),
      keyMoments: strList(json['key_moments']),
      beliefReframes: (json['belief_reframes'] as List<dynamic>?)
              ?.whereType<Map<String, dynamic>>()
              .map(CoachBeliefReframe.fromJson)
              .where((r) => r.belief.isNotEmpty && r.reframe.isNotEmpty)
              .toList() ??
          const [],
    );
  }
}

/// Safety classification the coach assigns to the user's latest message.
enum CoachSafety { none, concern, crisis }

/// The coach's coaching mode for a turn — drives the subtle UI cue.
enum CoachMode {
  support,
  clarity,
  action,
  reflectiveInquiry,
  beliefReframe,
  accountability,
  celebrate,
  unknown,
}

/// A fully parsed structured coach response.
class CoachReply {
  /// The human-facing message (may still contain `[[ACTION:...]]` markers).
  final String response;
  final CoachMode mode;
  final String framework;
  final CoachSafety safety;
  final CoachMemoryUpdate memory;

  const CoachReply({
    required this.response,
    this.mode = CoachMode.unknown,
    this.framework = '',
    this.safety = CoachSafety.none,
    this.memory = const CoachMemoryUpdate(),
  });

  /// Plain-text fallback when no structured JSON could be parsed.
  factory CoachReply.plain(String text) => CoachReply(response: text);

  /// Parses the raw model output. The model is instructed to return a single
  /// JSON object; we extract the outermost `{...}` and decode it. Any failure
  /// falls back to treating the entire string as the response text.
  factory CoachReply.parse(String raw) {
    try {
      final start = raw.indexOf('{');
      final end = raw.lastIndexOf('}');
      if (start == -1 || end <= start) return CoachReply.plain(raw.trim());

      final jsonStr = raw.substring(start, end + 1);
      final data = jsonDecode(jsonStr) as Map<String, dynamic>;

      final text = (data['response'] as String?)?.trim();
      if (text == null || text.isEmpty) return CoachReply.plain(raw.trim());

      return CoachReply(
        response: text,
        mode: _parseMode(data['mode'] as String?),
        framework: data['framework'] as String? ?? '',
        safety: _parseSafety(data['safety'] as String?),
        memory: data['memory_updates'] is Map<String, dynamic>
            ? CoachMemoryUpdate.fromJson(
                data['memory_updates'] as Map<String, dynamic>)
            : const CoachMemoryUpdate(),
      );
    } catch (_) {
      return CoachReply.plain(raw.trim());
    }
  }

  static CoachMode _parseMode(String? raw) {
    switch (raw?.toLowerCase().trim()) {
      case 'support':
        return CoachMode.support;
      case 'clarity':
        return CoachMode.clarity;
      case 'action':
        return CoachMode.action;
      case 'reflective_inquiry':
      case 'reflective inquiry':
        return CoachMode.reflectiveInquiry;
      case 'belief_reframe':
      case 'belief reframe':
        return CoachMode.beliefReframe;
      case 'accountability':
        return CoachMode.accountability;
      case 'celebrate':
        return CoachMode.celebrate;
      default:
        return CoachMode.unknown;
    }
  }

  static CoachSafety _parseSafety(String? raw) {
    switch (raw?.toLowerCase().trim()) {
      case 'crisis':
        return CoachSafety.crisis;
      case 'concern':
        return CoachSafety.concern;
      default:
        return CoachSafety.none;
    }
  }

  /// Short label for the subtle coaching-mode cue on coach bubbles.
  String? get modeLabel {
    switch (mode) {
      case CoachMode.support:
        return 'Support';
      case CoachMode.clarity:
        return 'Clarity';
      case CoachMode.action:
        return 'Action';
      case CoachMode.reflectiveInquiry:
        return 'Reflecting';
      case CoachMode.beliefReframe:
        return 'Reframe';
      case CoachMode.accountability:
        return 'Accountability';
      case CoachMode.celebrate:
        return 'Celebrate';
      case CoachMode.unknown:
        return null;
    }
  }
}
