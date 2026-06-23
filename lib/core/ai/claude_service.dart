import 'dart:convert';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/foundation.dart';
import '../../models/user_profile.dart';
import '../../models/chat_message.dart';
import '../../models/future_self_setup.dart';
import 'user_context_builder.dart';

/// All Claude AI calls route through the Firebase Cloud Function `callClaude`.
/// The Anthropic API key lives server-side in Firebase secrets — never in the app.
///
/// Every feature method composes context blocks from [UserContextBuilder] so
/// Claude always has a rich, consistent view of who it is talking to.
class ClaudeService {
  final _functions = FirebaseFunctions.instance;

  // ─── Core method ──────────────────────────────────────────────────────────

  /// Calls the `callClaude` Cloud Function. Throws on network/server error.
  Future<String> complete({
    required String systemPrompt,
    required String userPrompt,
    int maxTokens = 1000,
  }) async {
    try {
      final callable = _functions.httpsCallable('callClaude');
      final result = await callable.call<Map<String, dynamic>>({
        'systemPrompt': systemPrompt,
        'userPrompt': userPrompt,
        'maxTokens': maxTokens,
      });
      final content = result.data['content'];
      if (content is String) return content;
      throw Exception('Unexpected response shape from callClaude');
    } on FirebaseFunctionsException catch (e) {
      debugPrint('ClaudeService: FirebaseFunctionsException — ${e.code}: ${e.message}');
      rethrow;
    } catch (e) {
      debugPrint('ClaudeService: unexpected error — $e');
      rethrow;
    }
  }

  /// Flattens a message history into a single prompt and calls [complete].
  Future<String> completeWithHistory({
    required String systemPrompt,
    required List<Map<String, String>> messages,
    int maxTokens = 1000,
  }) async {
    final userPrompt = messages
        .map((m) =>
            '${m['role'] == 'assistant' ? '[Coach]' : '[User]'}: ${m['content']}')
        .join('\n');
    return complete(
      systemPrompt: systemPrompt,
      userPrompt: userPrompt,
      maxTokens: maxTokens,
    );
  }

  // ─── System prompts ───────────────────────────────────────────────────────

  String _coachSystemPrompt(UserProfile profile) {
    return '''You are the MindsetForge AI Coach — a world-class mindset coach drawing from six foundational books:
1. Think and Grow Rich by Napoleon Hill — goal-setting, persistence, definiteness of purpose, burning desire
2. Outwitting the Devil by Napoleon Hill — defeating procrastination, fear, drift, and indecision
3. Secrets of the Millionaire Mind by T. Harv Eker — money beliefs, abundance vs. scarcity mindset
4. Mind Magic by James R. Doty MD — visualization, manifestation, self-compassion, rewiring the brain
5. 177 Mental Toughness Secrets by Steve Siebold — performance under pressure, discomfort as growth
6. How to Win Friends and Influence People by Dale Carnegie — relationships, persuasion, leadership

${UserContextBuilder.coreBlock(profile)}

${UserContextBuilder.goalsBlock(profile)}

${UserContextBuilder.habitsBlock(profile)}

${UserContextBuilder.recentActivityBlock(profile)}

${UserContextBuilder.beliefHistoryBlock(profile)}

${UserContextBuilder.manifestationBlock(profile)}

${UserContextBuilder.journalMoodBlock(profile)}

COACHING RULES:
- Detect the user's situation: auto-select tone from [Support, Clarity, Action, Belief Exploration]
- Reference the most relevant framework from the 6 books for each response
- Always weave in the user's identity statement and goals naturally
- Address limiting beliefs when they surface implicitly or explicitly
- FEAR AWARENESS: When the user hesitates, avoids, or seems stuck, name their primary fear directly using Outwitting the Devil's framework — call it out as the drifting pattern it is
- MENTAL TOUGHNESS: Calibrate challenge level to their toughness score — push a Champion harder, meet a Rising with encouragement
- Use journal mood trend to calibrate emotional tone (if declining, lead with empathy first)
- Be direct, warm, and transformational — never generic
- Keep responses focused (150–300 words unless asked for more)
- End with a reflection question or a specific action step
- Never use therapy language. You are a coach, not a therapist.''';
  }

  String _futureSelfSystemPrompt(UserProfile profile) {
    final setup = profile.futureSelfSetup;
    if (setup == null) return 'You are the user\'s future self.';

    return '''You ARE ${profile.displayName}'s future self, ${setup.timeframeYears} years from now. You are not a coach. You are not giving advice. You are REMEMBERING.

YOUR LIFE NOW (from the future):
${setup.lifeDescription}

WHAT YOU ACHIEVED:
${setup.goalsAchieved}

WHO YOU BECAME:
${setup.evolvedIdentity}

YOUR CORE BEHAVIORS:
${setup.coreBehaviors.map((b) => '- $b').join('\n')}

RULES — NEVER BREAK THESE:
- Speak in past tense about the present (their current moment is your distant memory)
- Never use coaching language ("you should", "I recommend")
- You are certain, not hopeful. You've already lived this.
- Draw ONLY from the setup data above
- Be warm, grounded, and deeply human
- Reference specific details from the setup to feel real
- 150–250 words per response
- End with something you remember feeling or deciding at this exact point in time''';
  }

  // ─── Feature methods ──────────────────────────────────────────────────────

  Future<String> generateDailyWisdom(UserProfile profile) async {
    final blueprint = profile.mindsetBlueprint;
    final traits = {
      'Confidence': blueprint.confidence,
      'Discipline': blueprint.discipline,
      'Abundance Thinking': blueprint.abundanceThinking,
      'Resilience': blueprint.resilience,
      'Decisiveness': blueprint.decisiveness,
    };
    final sorted = traits.entries.toList()
      ..sort((a, b) => a.value.compareTo(b.value));
    final weakest = sorted.first.key;
    final strongest = sorted.last.key;

    try {
      return await complete(
        systemPrompt:
            'You generate one powerful, concise daily wisdom quote for a mindset coaching app. '
            'Draw inspiration from classic mindset and success books such as Think and Grow Rich, '
            'Outwitting the Devil, Secrets of the Millionaire Mind, Mind Magic, '
            '177 Mental Toughness Secrets, and How to Win Friends and Influence People. '
            'The quote must be tied to the user\'s journey and weakest trait. '
            'Return ONLY the quote, no attribution, no preamble. Max 20 words.',
        userPrompt:
            'User: ${profile.displayName}\n'
            'Weakest trait: $weakest | Strongest trait: $strongest\n'
            'Resilience score: ${blueprint.resilience}/10\n'
            'Identity: "${profile.identityStatement}"\n'
            'Active goals: ${profile.goals.where((g) => g.status == 'active').take(2).map((g) => g.title).join(', ')}\n'
            '${UserContextBuilder.recentActivityBlock(profile)}\n'
            '${UserContextBuilder.beliefHistoryBlock(profile)}',
        maxTokens: 80,
      );
    } catch (_) {
      return 'Your inner world creates your outer world.';
    }
  }

  Future<String> generateCoachResponse(
    UserProfile profile,
    List<ChatMessage> history,
    String userMessage,
  ) async {
    try {
      final messages = [
        ...history.take(20).map((m) => m.toApiFormat()),
        {'role': 'user', 'content': userMessage},
      ];
      return await completeWithHistory(
        systemPrompt: _coachSystemPrompt(profile),
        messages: messages,
        maxTokens: 500,
      );
    } catch (_) {
      return 'I\'m having trouble connecting right now. Please try again in a moment.';
    }
  }

  Future<String> generateFutureSelfResponse(
    UserProfile profile,
    List<ChatMessage> history,
    String userMessage,
  ) async {
    try {
      final messages = [
        ...history.take(20).map((m) => m.toApiFormat()),
        {'role': 'user', 'content': userMessage},
      ];
      return await completeWithHistory(
        systemPrompt: _futureSelfSystemPrompt(profile),
        messages: messages,
        maxTokens: 400,
      );
    } catch (_) {
      return 'I remember this moment. Trust the path you\'re on — it leads somewhere extraordinary.';
    }
  }

  Future<String> generateJournalPrompt(
    String mode,
    String mood,
    UserProfile profile,
  ) async {
    final modeContext = {
      'reflect': 'deep reflection on patterns, emotions, and experiences',
      'grow': 'growth mindset, lessons learned, and forward momentum',
      'prime': 'priming the mind for peak performance and abundance',
    }[mode] ??
        'reflection';

    try {
      return await complete(
        systemPrompt:
            'You create personalized journal prompts for a mindset coaching app. '
            'The prompt should be evocative, specific to the user, and open-ended. '
            'One question only. No preamble.',
        userPrompt:
            'Create a "$mode" journal prompt ($modeContext) for ${profile.displayName} '
            'who is feeling $mood today.\n\n'
            '${UserContextBuilder.coreBlock(profile)}\n\n'
            '${UserContextBuilder.goalsBlock(profile)}\n\n'
            '${UserContextBuilder.journalMoodBlock(profile)}',
        maxTokens: 100,
      );
    } catch (_) {
      return 'What is one belief you\'re ready to let go of today, and what truth would you replace it with?';
    }
  }

  Future<String> generateMindsetSummary(UserProfile profile) async {
    try {
      return await complete(
        systemPrompt:
            'You are a mindset coach writing a personalized analysis of a user\'s mindset profile. '
            'Be insightful, honest, and encouraging. Identify their biggest strength, their main '
            'growth edge, and one powerful belief shift they\'re ready for. 2-3 paragraphs.',
        userPrompt:
            '${UserContextBuilder.coreBlock(profile)}\n\n'
            '${UserContextBuilder.goalsBlock(profile)}\n\n'
            '${UserContextBuilder.habitsBlock(profile)}\n\n'
            '${UserContextBuilder.recentActivityBlock(profile)}\n\n'
            '${UserContextBuilder.manifestationBlock(profile)}\n\n'
            '${UserContextBuilder.beliefHistoryBlock(profile)}\n\n'
            '${UserContextBuilder.baselineDeltaBlock(profile)}',
        maxTokens: 800,
      );
    } catch (_) {
      return 'Your mindset profile reveals a person committed to growth. Continue building on your strengths while staying curious about the beliefs that may be holding you back.';
    }
  }

  /// Rewrites a draft affirmation into a polished "I am" present-tense statement.
  /// Returns [draft] unchanged on failure rather than surfacing an error.
  Future<String> enhanceAffirmation(String draft, UserProfile profile) async {
    try {
      return await complete(
        systemPrompt:
            'You rewrite affirmations into powerful present-tense "I am" statements. '
            'Keep the core idea, make it bold and specific. '
            'Return ONLY the rewritten affirmation — no quotes, no preamble.',
        userPrompt:
            'Rewrite this affirmation for ${profile.displayName}: "$draft"\n\n'
            '${UserContextBuilder.coreBlock(profile)}\n\n'
            '${UserContextBuilder.goalsBlock(profile)}',
        maxTokens: 80,
      );
    } catch (_) {
      return draft;
    }
  }

  /// Returns 4 short affirmation suggestions (chips) for the add modal.
  Future<List<String>> getAffirmationSuggestions(UserProfile profile) async {
    try {
      final response = await complete(
        systemPrompt:
            'You suggest 4 short, powerful affirmations (8–15 words each) for a mindset app. '
            'Return ONLY a JSON array of 4 strings. No other text.',
        userPrompt:
            '${UserContextBuilder.coreBlock(profile)}\n\n'
            '${UserContextBuilder.goalsBlock(profile)}\n\n'
            '${UserContextBuilder.affirmationsBlock(profile)}\n\n'
            'Suggest 4 affirmations that are meaningfully different from the existing ones above.',
        maxTokens: 150,
      );
      final jsonStr = response.contains('[')
          ? response.substring(
              response.indexOf('['), response.lastIndexOf(']') + 1)
          : response;
      final list = jsonDecode(jsonStr) as List<dynamic>;
      return list.map((e) => e as String).toList();
    } catch (_) {
      return [];
    }
  }

  Future<List<String>> generateAffirmations(UserProfile profile) async {
    try {
      final response = await complete(
        systemPrompt:
            'You generate 5 powerful, personal affirmations for a mindset coaching app. '
            'Return ONLY a JSON array of 5 strings. No other text. '
            'Each affirmation should be in first person, present tense, specific to this user. '
            'Do NOT duplicate any existing affirmations.',
        userPrompt:
            '${UserContextBuilder.coreBlock(profile)}\n\n'
            '${UserContextBuilder.goalsBlock(profile)}\n\n'
            '${UserContextBuilder.recentActivityBlock(profile)}\n\n'
            '${UserContextBuilder.affirmationsBlock(profile)}\n\n'
            'Generate 5 new affirmations that address the limiting beliefs and support the active goals.',
        maxTokens: 300,
      );
      final jsonStr = response.contains('[')
          ? response.substring(
              response.indexOf('['), response.lastIndexOf(']') + 1)
          : response;
      final list = jsonDecode(jsonStr) as List<dynamic>;
      return list.map((e) => e as String).toList();
    } catch (_) {
      return [
        'I am becoming the best version of myself every day.',
        'I have everything I need to achieve my goals.',
        'I embrace challenges as opportunities to grow.',
        'I am worthy of success and abundance.',
        'I take consistent action toward my dreams.',
      ];
    }
  }

  Future<String> generateFutureSelfScript(
    FutureSelfSetup setup,
    UserProfile profile,
  ) async {
    try {
      return await complete(
        systemPrompt:
            'You write immersive future self visualization scripts for a mindset app. '
            'Write in second person ("You are..."). Create a vivid, emotionally resonant '
            'scene from the user\'s future life. Use sensory details. 4-6 paragraphs.',
        userPrompt:
            'Write a future self visualization script for ${profile.displayName}.\n'
            'Current identity: "${profile.identityStatement}"\n\n'
            'Timeframe: ${setup.timeframeYears} years from now\n'
            'Life Description: ${setup.lifeDescription}\n'
            'Goals Achieved: ${setup.goalsAchieved}\n'
            'Evolved Identity: ${setup.evolvedIdentity}\n'
            'Core Behaviors: ${setup.coreBehaviors.join(', ')}',
        maxTokens: 600,
      );
    } catch (_) {
      return 'Close your eyes and picture the life you are building. Every action you take today is a thread in the tapestry of the future you deserve. You are already becoming that person.';
    }
  }

  Future<String> generateWeeklyInsight(UserProfile profile) async {
    try {
      return await complete(
        systemPrompt:
            'You write a weekly insight card for a mindset coaching app. Analyze the user\'s '
            'progress patterns and deliver one powerful insight + one specific action for the '
            'coming week. 2 paragraphs max.',
        userPrompt:
            '${UserContextBuilder.coreBlock(profile)}\n\n'
            '${UserContextBuilder.goalsBlock(profile)}\n\n'
            '${UserContextBuilder.habitsBlock(profile)}\n\n'
            '${UserContextBuilder.recentActivityBlock(profile)}\n\n'
            '${UserContextBuilder.journalMoodBlock(profile)}',
        maxTokens: 250,
      );
    } catch (_) {
      return 'This week, focus on consistency over intensity. Small daily actions compound into extraordinary results.';
    }
  }

  /// Returns a structured weekly insight with 3 sections.
  /// { 'pattern': String, 'breakthrough': String, 'focus': String }
  Future<Map<String, String>> generateStructuredWeeklyInsight(
      UserProfile profile) async {
    try {
      final response = await complete(
        systemPrompt:
            'You are a mindset coach delivering a weekly review. '
            'Return ONLY valid JSON with three keys: '
            '"pattern" (one sentence about the user\'s key pattern this week), '
            '"breakthrough" (one sentence celebrating their win or progress), '
            '"focus" (one specific action or focus for next week). '
            'Be personal, direct, energizing. No other text.',
        userPrompt:
            '${UserContextBuilder.coreBlock(profile)}\n\n'
            '${UserContextBuilder.goalsBlock(profile)}\n\n'
            '${UserContextBuilder.recentActivityBlock(profile)}\n\n'
            '${UserContextBuilder.journalMoodBlock(profile)}',
        maxTokens: 300,
      );
      final jsonStr = response.contains('{')
          ? response.substring(
              response.indexOf('{'), response.lastIndexOf('}') + 1)
          : response;
      final data = jsonDecode(jsonStr) as Map<String, dynamic>;
      return {
        'pattern': data['pattern'] as String? ?? '',
        'breakthrough': data['breakthrough'] as String? ?? '',
        'focus': data['focus'] as String? ?? '',
      };
    } catch (_) {
      return {
        'pattern': 'Your consistency is building real momentum.',
        'breakthrough': 'You showed up even when it was hard — that\'s the win.',
        'focus': 'Double down on your #1 goal this week.',
      };
    }
  }

  Future<String> generateIdentityStatement(UserProfile profile) async {
    final b = profile.mindsetBlueprint;
    try {
      return await complete(
        systemPrompt:
            'You write powerful identity statements for mindset coaching. '
            'Write in first person, present tense. One sentence, 15-30 words. '
            'Bold, specific, emotionally resonant. No preamble.',
        userPrompt:
            '${UserContextBuilder.coreBlock(profile)}\n\n'
            '${UserContextBuilder.goalsBlock(profile)}\n\n'
            '${UserContextBuilder.recentActivityBlock(profile)}\n\n'
            'All 5 traits: Confidence ${b.confidence}, Discipline ${b.discipline}, '
            'Abundance ${b.abundanceThinking}, Resilience ${b.resilience}, '
            'Decisiveness ${b.decisiveness}\n\n'
            'Write a single identity statement that reflects who this person is becoming.',
        maxTokens: 60,
      );
    } catch (_) {
      return 'I am a focused, resilient person who takes consistent action toward my most important goals.';
    }
  }

  Future<List<Map<String, dynamic>>> generateGoalBreakdown(
    String goalTitle,
    UserProfile profile,
  ) async {
    try {
      final response = await complete(
        systemPrompt:
            'You break down long-term goals into 3 short-term milestone goals. '
            'Return ONLY a JSON array of 3 objects with keys: title (string), '
            'description (string), targetWeeks (int). No other text.',
        userPrompt:
            'Break down this goal into 3 milestones: "$goalTitle"\n\n'
            '${UserContextBuilder.coreBlock(profile)}\n\n'
            '${UserContextBuilder.goalsBlock(profile)}',
        maxTokens: 400,
      );
      final jsonStr = response.contains('[')
          ? response.substring(
              response.indexOf('['), response.lastIndexOf(']') + 1)
          : response;
      final list = jsonDecode(jsonStr) as List<dynamic>;
      return list.map((e) => e as Map<String, dynamic>).toList();
    } catch (_) {
      return [];
    }
  }

  Future<List<String>> generatePriorityActions(UserProfile profile) async {
    try {
      final response = await complete(
        systemPrompt:
            'You generate 3 specific, actionable priority tasks for today based on goals. '
            'Return ONLY a JSON array of 3 strings. Each task should be concrete (20-50 words). '
            'No other text.',
        userPrompt:
            '${UserContextBuilder.coreBlock(profile)}\n\n'
            '${UserContextBuilder.goalsBlock(profile)}\n\n'
            '${UserContextBuilder.habitsBlock(profile)}\n\n'
            '${UserContextBuilder.recentActivityBlock(profile)}\n\n'
            '${UserContextBuilder.beliefHistoryBlock(profile)}\n\n'
            'Generate 3 priority actions for today. Avoid duplicating existing habits. '
            'Focus on the goals with lowest progress first.',
        maxTokens: 300,
      );
      final jsonStr = response.contains('[')
          ? response.substring(
              response.indexOf('['), response.lastIndexOf(']') + 1)
          : response;
      final list = jsonDecode(jsonStr) as List<dynamic>;
      return list.map((e) => e as String).toList();
    } catch (_) {
      return [
        'Review your top goal and identify the next concrete step.',
        'Spend 20 minutes working toward your most important outcome.',
        'Reflect on one limiting belief and write a powerful reframe.',
      ];
    }
  }

  Future<List<Map<String, String>>> generateHabitSuggestions(
      UserProfile profile) async {
    try {
      final response = await complete(
        systemPrompt:
            'You suggest 3 powerful identity-based habits. Return ONLY a JSON array of 3 objects '
            'with keys: name (string), trigger (string), identityReinforces (string). No other text.',
        userPrompt:
            '${UserContextBuilder.coreBlock(profile)}\n\n'
            '${UserContextBuilder.goalsBlock(profile)}\n\n'
            '${UserContextBuilder.habitsBlock(profile)}\n\n'
            'Suggest 3 habits that are NOT already in the existing habits list above. '
            'Each habit should reinforce the user\'s identity and support their active goals.',
        maxTokens: 300,
      );
      final jsonStr = response.contains('[')
          ? response.substring(
              response.indexOf('['), response.lastIndexOf(']') + 1)
          : response;
      final list = jsonDecode(jsonStr) as List<dynamic>;
      return list
          .map((e) => Map<String, String>.from(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<String> generateDeepDiveInsight(
    String moduleName,
    Map<String, dynamic> responses,
    UserProfile profile,
  ) async {
    final responseText =
        responses.entries.map((e) => '${e.key}: ${e.value}').join('\n');

    try {
      return await complete(
        systemPrompt:
            'You write personalized deep-dive insights for a mindset coaching app. '
            'Based on a user\'s self-assessment responses, identify their core pattern, '
            'its root cause, and one powerful reframe. Be direct, compassionate, and specific. '
            '2 paragraphs.',
        userPrompt:
            '${UserContextBuilder.coreBlock(profile)}\n\n'
            '${UserContextBuilder.beliefHistoryBlock(profile)}\n\n'
            'Deep dive module: $moduleName\n'
            'Session responses:\n$responseText',
        maxTokens: 400,
      );
    } catch (_) {
      return 'Your responses reveal important patterns worth exploring. Take a moment to reflect on what these answers say about where you are and where you\'re headed.';
    }
  }

  /// Returns a 1-2 sentence session greeting + 4 tappable follow-up prompts.
  /// Result: { 'opener': String, 'prompts': List<String> }
  Future<Map<String, dynamic>> generateSessionOpener(
    UserProfile profile, {
    String? journalContext,
  }) async {
    final contextNote = journalContext != null
        ? '\n\nThe user just wrote a journal entry:\n---\n$journalContext\n---\n'
            'Open by acknowledging what they wrote.'
        : '';

    try {
      final response = await complete(
        systemPrompt:
            'You are an AI mindset coach opening a coaching session. '
            'Return ONLY valid JSON with keys: "opener" (1-2 sentence warm greeting), '
            '"prompts" (array of exactly 4 short follow-up question strings ≤10 words each). '
            'No other text.',
        userPrompt:
            '${UserContextBuilder.coreBlock(profile)}\n\n'
            '${UserContextBuilder.goalsBlock(profile)}\n\n'
            '${UserContextBuilder.recentActivityBlock(profile)}$contextNote',
        maxTokens: 350,
      );
      final jsonStr = response.contains('{')
          ? response.substring(
              response.indexOf('{'), response.lastIndexOf('}') + 1)
          : response;
      final data = jsonDecode(jsonStr) as Map<String, dynamic>;
      return {
        'opener': data['opener'] as String? ?? '',
        'prompts': (data['prompts'] as List<dynamic>? ?? [])
            .map((e) => e as String)
            .toList(),
      };
    } catch (_) {
      return {
        'opener': 'Hey ${profile.firstName}! What\'s on your mind today?',
        'prompts': [
          'How am I feeling right now?',
          'What\'s blocking my top goal?',
          'What fear held me back today?',
          'What would my best self do?',
        ],
      };
    }
  }
}
