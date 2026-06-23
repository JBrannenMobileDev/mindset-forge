import '../../models/user_profile.dart';

/// Builds structured, reusable context blocks from a [UserProfile].
///
/// Each block returns a formatted string ready to embed directly into a Claude
/// system or user prompt. Methods are composable — call only the blocks a given
/// feature needs rather than sending the full profile on every request.
///
/// All methods are pure/synchronous — no async or Firestore reads required.
abstract final class UserContextBuilder {
  // ─── Core block ───────────────────────────────────────────────────────────

  /// Name, identity, all 5 blueprint scores, limiting beliefs, fears, mental
  /// toughness score, and AI blueprint summary.
  /// Include in every AI call as the minimum baseline context.
  static String coreBlock(UserProfile p) {
    final b = p.mindsetBlueprint;
    final beliefs = p.limitingBeliefs.isNotEmpty
        ? p.limitingBeliefs.join('; ')
        : 'None identified yet';

    final fearLine = p.fearsDrift.isNotEmpty
        ? p.fearsDrift.asMap().entries.map((e) {
            final label = e.key == 0 ? 'Primary' : 'Secondary';
            return '$label: ${e.value}';
          }).join(' | ')
        : 'Not yet assessed';

    final toughnessLabel = p.mentalToughnessScore <= 33
        ? 'Still Building'
        : p.mentalToughnessScore <= 66
            ? 'Rising'
            : 'Champion';

    final summaryLine = p.mindsetBlueprintSummary.isNotEmpty
        ? '\nMindset Blueprint Summary: "${p.mindsetBlueprintSummary}"'
        : '';

    return '''USER CONTEXT:
Name: ${p.displayName}
Identity Statement: "${p.identityStatement}"
Mindset Blueprint Scores (1–10):
  Confidence: ${b.confidence.toStringAsFixed(1)}
  Discipline: ${b.discipline.toStringAsFixed(1)}
  Abundance Thinking: ${b.abundanceThinking.toStringAsFixed(1)}
  Resilience: ${b.resilience.toStringAsFixed(1)}
  Decisiveness: ${b.decisiveness.toStringAsFixed(1)}
  Overall Average: ${b.average.toStringAsFixed(1)}
Limiting Beliefs: $beliefs
Fears to Outwit (Outwitting the Devil): $fearLine
Mental Toughness Score: ${p.mentalToughnessScore.toStringAsFixed(0)}/100 ($toughnessLabel)$summaryLine''';
  }

  // ─── Goals block ──────────────────────────────────────────────────────────

  /// Active goals with title, category, progress, and first action step.
  static String goalsBlock(UserProfile p) {
    final active = p.goals.where((g) => g.status == 'active').toList();
    if (active.isEmpty) return 'Active Goals: None set yet.';

    final lines = active.take(5).map((g) {
      final step = g.actionSteps.isNotEmpty
          ? '\n    Next action: ${g.actionSteps.first.description}'
          : '';
      return '  • ${g.title} (${g.category}) — ${g.progressPercent.toStringAsFixed(0)}% complete$step';
    }).join('\n');

    final completed = p.goals.where((g) => g.status == 'completed').length;
    return 'Active Goals (${active.length}):\n$lines'
        '${completed > 0 ? '\nCompleted Goals: $completed' : ''}';
  }

  // ─── Habits block ─────────────────────────────────────────────────────────

  /// Existing active habits with name and current streak.
  /// Always include when generating habit suggestions to prevent duplicates.
  static String habitsBlock(UserProfile p) {
    final active = p.habits.where((h) => h.state == 'active').toList();
    if (active.isEmpty) return 'Current Habits: None yet.';

    final lines = active.map((h) {
      final streak = h.currentStreak;
      final streakLabel = streak > 0 ? ' — $streak day streak' : '';
      return '  • ${h.name}$streakLabel';
    }).join('\n');

    return 'Current Habits (${active.length}):\n$lines';
  }

  // ─── Recent activity block ────────────────────────────────────────────────

  /// Last 3 gratitude entries, last 3 evidence wins, streak, and perfect days.
  static String recentActivityBlock(UserProfile p) {
    final parts = <String>[];

    parts.add(
      'Consistency: ${p.currentStreak} day streak | ${p.perfectDayCount} perfect days total',
    );

    if (p.gratitudeLog.isNotEmpty) {
      final items = p.gratitudeLog
          .take(3)
          .map((e) => '  • ${e.content}')
          .join('\n');
      parts.add('Recent Gratitude:\n$items');
    }

    if (p.evidenceLog.isNotEmpty) {
      final items = p.evidenceLog
          .take(3)
          .map((e) => '  • ${e.content}')
          .join('\n');
      parts.add('Recent Evidence of Growth:\n$items');
    }

    return parts.join('\n');
  }

  // ─── Belief history block ─────────────────────────────────────────────────

  /// Last 5 identified belief→reframe pairs from the coaching history.
  static String beliefHistoryBlock(UserProfile p) {
    if (p.beliefPatternHistory.isEmpty) {
      return 'Belief Pattern History: None recorded yet.';
    }

    final recent = p.beliefPatternHistory.reversed.take(5);
    final lines = recent.map((bp) {
      return '  • Belief: "${bp.belief}"\n    Reframe: "${bp.reframe}"';
    }).join('\n');

    return 'Belief Pattern History (most recent):\n$lines';
  }

  // ─── Manifestation block ──────────────────────────────────────────────────

  /// All 4 manifestation alignment scores, overall, and mastery level.
  static String manifestationBlock(UserProfile p) {
    final m = p.manifestationAlignment;
    return '''Manifestation Alignment:
  Subconscious: ${m.subconscious.toStringAsFixed(0)}/100
  Thought: ${m.thought.toStringAsFixed(0)}/100
  Action: ${m.action.toStringAsFixed(0)}/100
  Results: ${m.results.toStringAsFixed(0)}/100
  Overall: ${m.overall.toStringAsFixed(0)}/100 (${m.masteryLevel})''';
  }

  // ─── Affirmations block ───────────────────────────────────────────────────

  /// Existing affirmation texts so Claude avoids generating duplicates.
  static String affirmationsBlock(UserProfile p) {
    final active = p.affirmations.where((a) => a.isActive).toList();
    if (active.isEmpty) return 'Existing Affirmations: None yet.';

    final lines = active.map((a) => '  • ${a.text}').join('\n');
    return 'Existing Affirmations (${active.length}) — do not duplicate:\n$lines';
  }

  // ─── Journal mood block ───────────────────────────────────────────────────

  /// Last 14 journal summaries with mood trend analysis.
  /// Derived from the [UserProfile.recentJournalSummaries] cache — no extra
  /// Firestore read needed.
  static String journalMoodBlock(UserProfile p) {
    final entries = p.recentJournalSummaries;
    if (entries.isEmpty) return 'Journal History: No entries recorded yet.';

    // Compute 7-day and 14-day averages
    final scores = entries.map((e) => e.moodScore).toList();
    final avg14 = scores.reduce((a, b) => a + b) / scores.length;
    final recent7 = scores.take(7).toList();
    final avg7 = recent7.reduce((a, b) => a + b) / recent7.length;

    // Trend: compare first half vs second half of recent7
    String trend = 'stable';
    if (recent7.length >= 4) {
      final firstHalf =
          recent7.sublist(recent7.length ~/ 2).reduce((a, b) => a + b) /
              (recent7.length - recent7.length ~/ 2);
      final secondHalf =
          recent7.sublist(0, recent7.length ~/ 2).reduce((a, b) => a + b) /
              (recent7.length ~/ 2);
      if (firstHalf - secondHalf > 1) trend = 'improving';
      if (secondHalf - firstHalf > 1) trend = 'declining';
    }

    final entryLines = entries.take(14).map((e) {
      return '  ${e.date} | ${e.mood} (${e.moodScore}/10) | ${e.mode}'
          '${e.snippet.isNotEmpty ? ' | "${e.snippet}"' : ''}';
    }).join('\n');

    return '''Journal Mood History:
  7-day avg mood: ${avg7.toStringAsFixed(1)}/10 (trend: $trend)
  14-day avg mood: ${avg14.toStringAsFixed(1)}/10
  Recent entries (newest first):
$entryLines''';
  }

  // ─── Baseline comparison block ────────────────────────────────────────────

  /// Compares current blueprint scores against the original onboarding baseline.
  /// Useful for mindset summary and identity regeneration.
  static String baselineDeltaBlock(UserProfile p) {
    final cur = p.mindsetBlueprint;
    final base = p.originalMindsetBaseline;

    String delta(String trait, double current, double baseline) {
      final diff = current - baseline;
      final sign = diff >= 0 ? '+' : '';
      return '  $trait: ${current.toStringAsFixed(1)} ($sign${diff.toStringAsFixed(1)} since baseline)';
    }

    return '''Growth Since Baseline:
${delta('Confidence', cur.confidence, base.confidence)}
${delta('Discipline', cur.discipline, base.discipline)}
${delta('Abundance Thinking', cur.abundanceThinking, base.abundanceThinking)}
${delta('Resilience', cur.resilience, base.resilience)}
${delta('Decisiveness', cur.decisiveness, base.decisiveness)}''';
  }
}
