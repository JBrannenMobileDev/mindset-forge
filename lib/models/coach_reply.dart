import 'dart:convert';

import '../core/constants/app_strings.dart';

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

  /// Builds a reply directly from the structured object returned by the
  /// `coach_reply` tool call (see `callClaudeConversation`). Anthropic's
  /// constrained decoding guarantees this already matches the schema, so no
  /// string parsing or salvage logic is needed on this path.
  factory CoachReply.fromJson(Map<String, dynamic> json) {
    final text = (json['response'] as String?)?.trim() ?? '';
    return CoachReply(
      response: text.isNotEmpty ? text : AppStrings.coachErrorRetry,
      mode: _parseMode(json['mode'] as String?),
      framework: json['framework'] as String? ?? '',
      safety: _parseSafety(json['safety'] as String?),
      memory: json['memory_updates'] is Map<String, dynamic>
          ? CoachMemoryUpdate.fromJson(json['memory_updates'] as Map<String, dynamic>)
          : const CoachMemoryUpdate(),
    );
  }

  /// Defensive fallback parser for raw text output. The primary coach path
  /// now uses [CoachReply.fromJson] on the schema-guaranteed `coach_reply`
  /// tool call, but this remains for any path that still hands back raw text
  /// (e.g. an unexpected non-tool response) — it can misbehave (prepend
  /// prose, wrap the object in a ```json fence, or get truncated mid-object
  /// when it hits the token cap).
  ///
  /// The parse is defensive in three tiers so raw/broken JSON can NEVER reach
  /// the chat bubble:
  ///   1. Strict decode of the outermost `{...}`.
  ///   2. Salvage the `"response"` string field directly (survives truncation,
  ///      since `response` is the first key in the contract).
  ///   3. Strip any code fences / JSON object and show the remaining prose,
  ///      falling back to a generic retry line if nothing readable is left.
  factory CoachReply.parse(String raw) {
    // Tier 1 — strict decode.
    final data = _tryDecodeObject(raw);
    if (data != null) {
      final text = (data['response'] as String?)?.trim();
      if (text != null && text.isNotEmpty) {
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
      }
    }

    // Tier 2 — salvage the response field from malformed/truncated JSON.
    final salvaged = _extractStringField(raw, 'response');
    if (salvaged != null && salvaged.trim().isNotEmpty) {
      return CoachReply(
        response: salvaged.trim(),
        mode: _parseMode(_extractStringField(raw, 'mode')),
        framework: _extractStringField(raw, 'framework') ?? '',
        safety: _parseSafety(_extractStringField(raw, 'safety')),
      );
    }

    // Tier 3 — strip fences/JSON and show whatever prose remains.
    final cleaned = _stripJsonAndFences(raw).trim();
    return CoachReply.plain(
        cleaned.isNotEmpty ? cleaned : AppStrings.coachErrorRetry);
  }

  /// Decodes the outermost `{...}` object, or returns null if that fails.
  static Map<String, dynamic>? _tryDecodeObject(String raw) {
    final start = raw.indexOf('{');
    final end = raw.lastIndexOf('}');
    if (start == -1 || end <= start) return null;
    try {
      final decoded = jsonDecode(raw.substring(start, end + 1));
      return decoded is Map<String, dynamic> ? decoded : null;
    } catch (_) {
      return null;
    }
  }

  /// Extracts the JSON string value for [key] from possibly-malformed or
  /// truncated output. Walks the characters after `"key"\s*:\s*"`, honoring
  /// `\"` escapes, and stops at the first unescaped `"` (or end-of-string if
  /// the model was cut off). The collected literal is JSON-unescaped so `\n`,
  /// `\"`, etc. render correctly. Returns null when the key isn't present.
  static String? _extractStringField(String raw, String key) {
    final match = RegExp('"${RegExp.escape(key)}"\\s*:\\s*"').firstMatch(raw);
    if (match == null) return null;

    final buf = StringBuffer();
    var i = match.end;
    var closed = false;
    while (i < raw.length) {
      final c = raw[i];
      if (c == r'\') {
        if (i + 1 >= raw.length) break; // dangling escape (truncated)
        buf.write(c);
        buf.write(raw[i + 1]);
        i += 2;
        continue;
      }
      if (c == '"') {
        closed = true;
        break;
      }
      buf.write(c);
      i++;
    }

    var literal = buf.toString();
    if (!closed && literal.endsWith(r'\')) {
      // Drop a lone trailing backslash left by truncation so decode succeeds.
      literal = literal.substring(0, literal.length - 1);
    }
    if (literal.isEmpty && !closed) return null;
    try {
      return jsonDecode('"$literal"') as String;
    } catch (_) {
      // Best-effort manual unescape if the literal still isn't valid JSON.
      return literal
          .replaceAll(r'\n', '\n')
          .replaceAll(r'\t', '\t')
          .replaceAll(r'\"', '"')
          .replaceAll(r'\\', r'\');
    }
  }

  /// Removes ```code fences``` and any `{...}` JSON object from [raw], leaving
  /// only human-readable prose. Used as the last-resort fallback so a stray
  /// JSON blob is never shown verbatim.
  static String _stripJsonAndFences(String raw) {
    var text = raw.replaceAll(RegExp(r'```[a-zA-Z]*'), '').replaceAll('```', '');
    final start = text.indexOf('{');
    final end = text.lastIndexOf('}');
    if (start != -1 && end > start) {
      text = text.substring(0, start) + text.substring(end + 1);
    } else if (start != -1) {
      // Unclosed object (truncated) — drop everything from the opening brace.
      text = text.substring(0, start);
    }
    return text;
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
