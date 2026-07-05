import '../../models/user_profile.dart';
import '../../models/deep_dive.dart';
import '../../models/goal.dart';
import '../utils/manifestation_scoring.dart';

/// Builds structured, reusable context blocks from a [UserProfile].
///
/// Each block returns a formatted string ready to embed directly into a Claude
/// system or user prompt. Methods are composable — call only the blocks a given
/// feature needs rather than sending the full profile on every request.
///
/// All methods are pure/synchronous — no async or Firestore reads required.
abstract final class UserContextBuilder {
  // ─── Core block ───────────────────────────────────────────────────────────

  /// Name, identity, blueprint scores (when self-assessed), limiting beliefs,
  /// fears, mental toughness score, and AI blueprint summary.
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

    final toughnessScore = p.mentalToughnessScore.round();
    final toughnessLabel = toughnessScore <= 33
        ? 'Still Building'
        : toughnessScore <= 66
            ? 'Rising'
            : 'Champion';

    final summaryLine = p.mindsetBlueprintSummary.isNotEmpty
        ? '\nMindset Blueprint Summary: "${p.mindsetBlueprintSummary}"'
        : '';

    final situationLine = p.identitySituation.isNotEmpty
        ? '\nCurrent Situation: ${p.identitySituation}'
        : '';
    final qualitiesLine = p.identityQualities.isNotEmpty
        ? '\nQualities They Aspire To: ${p.identityQualities.join(', ')}'
        : '';

    final blueprintLine = p.blueprintCompleted
        ? '''Mindset Blueprint Scores (1–10):
  Confidence: ${b.confidence.toStringAsFixed(1)}
  Discipline: ${b.discipline.toStringAsFixed(1)}
  Abundance Thinking: ${b.abundanceThinking.toStringAsFixed(1)}
  Resilience: ${b.resilience.toStringAsFixed(1)}
  Decisiveness: ${b.decisiveness.toStringAsFixed(1)}
  Overall Average: ${b.average.toStringAsFixed(1)}'''
        : 'Mindset Blueprint: Not yet self-assessed — do not reference specific '
            'trait scores or imply they rated themselves; they have not done '
            'this assessment yet.';

    return '''USER CONTEXT:
Name: ${p.displayName}
Identity Statement: "${p.identityStatement}"$situationLine$qualitiesLine
$blueprintLine
Limiting Beliefs: $beliefs
Fears to Outwit (Outwitting the Devil): $fearLine
Mental Toughness Score: ${p.mentalToughnessScore.toStringAsFixed(0)}/100 ($toughnessLabel)$summaryLine''';
  }

  // ─── Goals block ──────────────────────────────────────────────────────────

  /// Rich active-goal context: title, category, timeframe, derived progress,
  /// time left, the identity the goal builds toward, why it matters, and the
  /// goal's milestone checklist (done/total with each milestone's state).
  /// Completed goals are excluded; instead a short "Recent wins" line surfaces
  /// the most recently completed goals so the coach can celebrate them.
  static String goalsBlock(UserProfile p) {
    final active = p.goals.where((g) => g.status == 'active').toList();
    final recentWins = _recentWinsLine(p);

    if (active.isEmpty) {
      return recentWins.isEmpty
          ? 'Active Goals: None set yet.'
          : 'Active Goals: None set yet.\n$recentWins';
    }

    final body = active.take(6).map(_goalLines).join('\n');
    return 'Active Goals (${active.length}):\n$body'
        '${recentWins.isEmpty ? '' : '\n$recentWins'}';
  }

  /// Renders one goal plus its milestone checklist.
  static String _goalLines(Goal g) {
    final buffer = StringBuffer();
    buffer.write(
      '  • ${g.title} (${g.category}, ${_goalTypeLabel(g.goalType)}) — '
      '${g.derivedProgress.toStringAsFixed(0)}% complete — ${_timeLeft(g.targetDate)}',
    );
    if (g.identityBecomes.isNotEmpty) {
      buffer.write('\n    becomes: ${g.identityBecomes}');
    }
    if (g.description.isNotEmpty) {
      buffer.write('\n    why: ${_truncate(g.description, 120)}');
    }
    if (g.hasSteps) {
      buffer.write(
          '\n    milestones (${g.completedStepCount}/${g.actionSteps.length} done):');
      for (final s in g.actionSteps.take(6)) {
        buffer.write('\n      ${s.isCompleted ? '[x]' : '[ ]'} ${s.label}');
      }
    }
    return buffer.toString();
  }

  /// One compact line listing the 1-2 most recently completed goals within the
  /// last ~60 days. Empty string if none qualify.
  static String _recentWinsLine(UserProfile p) {
    final cutoff = DateTime.now().subtract(const Duration(days: 60));
    final wins = p.goals
        .where((g) =>
            g.status == 'completed' &&
            g.completedAt != null &&
            g.completedAt!.isAfter(cutoff))
        .toList()
      ..sort((a, b) => b.completedAt!.compareTo(a.completedAt!));
    if (wins.isEmpty) return '';
    final titles = wins.take(2).map((g) => g.title).join(', ');
    return 'Recent wins (completed): $titles';
  }

  static String _goalTypeLabel(String goalType) {
    switch (goalType) {
      case 'short_term':
        return 'short-term';
      case 'medium_term':
        return 'medium-term';
      case 'life_goal':
        return 'life goal';
      case 'long_term':
      default:
        return 'long-term';
    }
  }

  /// Human-readable time remaining until a target date.
  static String _timeLeft(DateTime target) {
    final now = DateTime.now();
    final days = target.difference(now).inDays;
    if (days < 0) return 'overdue';
    if (days == 0) return 'due today';
    if (days <= 14) return '$days days left';
    if (days < 60) return '~${(days / 7).round()} weeks left';
    if (days < 365) return '~${(days / 30).round()} months left';
    final years = days / 365;
    return years < 1.5 ? '~1 year left' : '~${years.round()} years left';
  }

  static String _truncate(String text, int max) {
    final clean = text.replaceAll('\n', ' ').trim();
    if (clean.length <= max) return clean;
    return '${clean.substring(0, max).trimRight()}…';
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

  // ─── Future Self block ────────────────────────────────────────────────────

  /// The future self the user has defined: the identity they are becoming,
  /// their normalized future day, and the traits that define them. Use to
  /// ground suggestions (e.g. habits) in who the user is becoming. Returns an
  /// empty string when no Future Self practice has been set up.
  static String futureSelfBlock(UserProfile p) {
    final setup = p.futureSelfSetup;
    if (setup == null) return '';

    final parts = <String>[];
    if (setup.identityAnchor.trim().isNotEmpty) {
      parts.add(
          'Who they are becoming: someone who ${setup.identityAnchor.trim()}');
    }
    if (setup.dailySnapshot.trim().isNotEmpty) {
      parts.add('Their typical future day: ${setup.dailySnapshot.trim()}');
    }
    if (setup.amplifiers.isNotEmpty) {
      parts.add('Defining traits: ${setup.amplifiers.join(', ')}');
    }
    if (parts.isEmpty) return '';

    return 'FUTURE SELF (who they are becoming):\n${parts.join('\n')}';
  }

  // ─── Recent activity block ────────────────────────────────────────────────

  /// Last 3 gratitude entries, last 3 evidence wins, streak, and perfect days.
  static String recentActivityBlock(UserProfile p) {
    final parts = <String>[];

    parts.add(
      'Consistency: ${p.currentStreak} day streak | ${p.perfectDayCount} perfect days total',
    );

    if (p.gratitudeLog.isNotEmpty) {
      final items = p.gratitudeLog.reversed
          .take(3)
          .map((e) => '  • ${e.content}')
          .join('\n');
      parts.add('Recent Gratitude:\n$items');
    }

    if (p.evidenceLog.isNotEmpty) {
      final items = p.evidenceLog.reversed
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
  /// Scores are COMPUTED from real activity (not self-rated). Includes a
  /// ramp-up note while the user is still in their first 10 days so the coach
  /// does not misread low early scores as a problem.
  static String manifestationBlock(UserProfile p) {
    final m = ManifestationScoring.calculate(p);
    final buffer = StringBuffer()
      ..writeln('Manifestation Alignment (computed from real activity):')
      ..writeln('  Subconscious: ${m.subconscious.toStringAsFixed(0)}/100 '
          '(fed by morning + evening affirmations and future-self visualization)')
      ..writeln('  Thought: ${m.thought.toStringAsFixed(0)}/100 '
          '(fed by journaling and coaching conversations)')
      ..writeln('  Action: ${m.action.toStringAsFixed(0)}/100 '
          '(fed by habits and priority actions)')
      ..writeln('  Results: ${m.results.toStringAsFixed(0)}/100 '
          '(average progress across active goals)')
      ..write('  Overall: ${m.overall.toStringAsFixed(0)}/100 (${m.masteryLevel})');

    if (ManifestationScoring.isRampingUp(p)) {
      final day = ManifestationScoring.daysSinceSignup(p) + 1;
      buffer.write(
        '\n\nRAMP-UP NOTE: This user is on day $day of their first 10 days. '
        'The scores above are based on very little history and will look low '
        'no matter how engaged they are. Do NOT interpret low early scores as '
        'a lack of effort, and do NOT point out that their scores are low. '
        'Focus on encouragement and building the habit, not on the numbers.',
      );
    }

    return buffer.toString();
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

  // ─── Deep Dive block ──────────────────────────────────────────────────────

  /// The user's psychological self-portrait from the Deep Dive modules:
  /// core wound, core desire, self-sabotage patterns, and per-module insights.
  /// This is the most intimate context the coach has — use it to understand the
  /// "why" beneath surface behavior. Returns empty string if nothing completed.
  static String deepDiveBlock(UserProfile p) {
    final d = p.deepDive;
    final parts = <String>[];

    if (d.coreWound.isNotEmpty) parts.add('Core Wound: "${d.coreWound}"');
    if (d.coreDesire.isNotEmpty) parts.add('Core Desire: "${d.coreDesire}"');
    if (d.selfSabotagePatterns.isNotEmpty) {
      parts.add(
        'Self-Sabotage Patterns: ${d.selfSabotagePatterns.join('; ')}',
      );
    }
    if (d.aiSummary.isNotEmpty) parts.add('Deep Dive Summary: "${d.aiSummary}"');

    const moduleLabels = {
      'mindset_patterns': 'Mindset Patterns',
      'motivation_style': 'Motivation Style',
      'fear_inventory': 'Fear Inventory',
      'identity_assessment': 'Identity Assessment',
      'social_influence': 'Social Influence',
    };
    final insights = <String>[];
    for (final id in kDeepDiveModuleIds) {
      final insight = d.moduleInsight(id);
      if (insight != null && insight.isNotEmpty) {
        insights.add('  • ${moduleLabels[id]}: "$insight"');
      }
    }
    if (insights.isNotEmpty) {
      parts.add('Deep Dive Insights:\n${insights.join('\n')}');
    }

    if (parts.isEmpty) return '';
    return 'PSYCHOLOGICAL DEEP DIVE (handle with care — this is the user\'s '
        'inner world):\n${parts.join('\n')}';
  }

  // ─── Coach memory block ───────────────────────────────────────────────────

  /// Persistent cross-session coaching memory: long-term summary, last session,
  /// open commitments, recurring patterns, and key moments.
  /// Lets the coach pick up exactly where it left off. Empty string if no memory.
  static String coachMemoryBlock(UserProfile p) {
    final m = p.coachMemory;
    if (m.isEmpty) return '';

    final parts = <String>[];
    if (m.longTermSummary.isNotEmpty) {
      parts.add('What you know about them: ${m.longTermSummary}');
    }
    if (m.lastSessionSummary.isNotEmpty) {
      final when = m.lastSessionAt != null
          ? ' (${_daysAgoLabel(m.lastSessionAt!)})'
          : '';
      parts.add('Last session$when: ${m.lastSessionSummary}');
    }
    final open = m.openCommitments.where((c) => !c.fulfilled).toList();
    if (open.isNotEmpty) {
      final lines = open.take(5).map((c) => '  • ${c.text}').join('\n');
      parts.add('Open commitments they made:\n$lines');
    }
    if (m.recurringPatterns.isNotEmpty) {
      parts.add(
        'Recurring patterns you\'ve noticed: ${m.recurringPatterns.take(5).join('; ')}',
      );
    }
    if (m.keyMoments.isNotEmpty) {
      final lines = m.keyMoments.take(3).map((k) => '  • $k').join('\n');
      parts.add('Key moments worth remembering:\n$lines');
    }

    return 'COACHING MEMORY (you remember this from before — reference it '
        'naturally, do not recite it like a file):\n${parts.join('\n')}';
  }

  // ─── Behavioral / accountability block ────────────────────────────────────

  /// A recent wins/losses snapshot the coach can hold accountable against:
  /// streak, habit momentum, stalled habits, and stalled goals.
  static String behavioralBlock(UserProfile p) {
    final parts = <String>[];
    final now = DateTime.now();

    parts.add(
      'Current streak: ${p.currentStreak} days | Perfect days: ${p.perfectDayCount}',
    );

    final active = p.habits.where((h) => h.state == 'active').toList();
    if (active.isNotEmpty) {
      final onTrack = active.where((h) => h.isCompletedToday).length;
      parts.add(
        'Habits done today: $onTrack of ${active.length}',
      );

      final stalled = active.where((h) {
        final last = h.lastCompletedDate;
        if (last == null) return true;
        return now.difference(last).inDays >= 3;
      }).map((h) => h.name).toList();
      if (stalled.isNotEmpty) {
        parts.add(
          'Stalled habits (3+ days untouched): ${stalled.take(4).join(', ')}',
        );
      }
    }

    final stalledGoals = p.goals
        .where((g) => g.status == 'active' && g.progressPercent < 100)
        .where((g) => now.difference(g.createdAt).inDays >= 14 && g.progressPercent < 25)
        .map((g) => g.title)
        .toList();
    if (stalledGoals.isNotEmpty) {
      parts.add(
        'Goals losing momentum (older, low progress): ${stalledGoals.take(3).join(', ')}',
      );
    }

    return 'RECENT BEHAVIOR (use like a coach who remembers, not a database):\n'
        '${parts.join('\n')}';
  }

  // ─── Routine timing block ─────────────────────────────────────────────────

  /// Typical completion times for the timing-sensitive subconscious-layer
  /// routines over the last 14 days. Factual only: the coach decides whether
  /// the timing fits the most-programmable windows. Empty string if no data.
  static String routineTimingBlock(UserProfile p) {
    const tracked = <String, String>{
      'affirmationsMorning': 'Morning affirmations',
      'affirmationsEvening': 'Evening affirmations',
      'futureSelfCompleted': 'Future self visualization',
      'identityRead': 'Identity statement reading',
    };

    final recent = [...p.dailyCompletions]
      ..sort((a, b) => b.date.compareTo(a.date));
    final window = recent.take(14).toList();

    final lines = <String>[];
    for (final entry in tracked.entries) {
      final times = <DateTime>[];
      for (final c in window) {
        final iso = c.completionTimes[entry.key];
        if (iso == null) continue;
        final dt = DateTime.tryParse(iso);
        if (dt != null) times.add(dt.toLocal());
      }
      if (times.length < 2) continue;
      final avgMinutes = times
              .map((t) => t.hour * 60 + t.minute)
              .reduce((a, b) => a + b) ~/
          times.length;
      lines.add(
        '  ${entry.value}: usually around ${_formatClock(avgMinutes)} '
        '(${times.length} of last ${window.length} days)',
      );
    }

    if (lines.isEmpty) return '';
    return 'ROUTINE TIMING (when they typically do key practices):\n'
        '${lines.join('\n')}';
  }

  static String _formatClock(int minutesSinceMidnight) {
    final h24 = (minutesSinceMidnight ~/ 60) % 24;
    final m = minutesSinceMidnight % 60;
    final period = h24 < 12 ? 'AM' : 'PM';
    final h12 = h24 % 12 == 0 ? 12 : h24 % 12;
    final mm = m.toString().padLeft(2, '0');
    return '$h12:$mm $period';
  }

  static String _daysAgoLabel(DateTime when) {
    final days = DateTime.now().difference(when).inDays;
    if (days <= 0) return 'today';
    if (days == 1) return 'yesterday';
    if (days < 7) return '$days days ago';
    if (days < 14) return 'last week';
    return '${(days / 7).floor()} weeks ago';
  }
}
