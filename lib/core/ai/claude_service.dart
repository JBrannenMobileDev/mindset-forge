import 'dart:convert';
import 'dart:math';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/foundation.dart';
import '../../models/user_profile.dart';
import '../../models/chat_message.dart';
import '../../models/coach_reply.dart';
import '../../models/future_self_setup.dart';
import '../../models/goal.dart';
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

  /// Calls the multi-turn `callClaudeConversation` Cloud Function with a real
  /// messages array. Throws on network/server error.
  Future<({String content, bool truncated})> completeConversation({
    required String systemPrompt,
    required List<Map<String, String>> messages,
    int maxTokens = 1200,
  }) async {
    try {
      final callable = _functions.httpsCallable('callClaudeConversation');
      final result = await callable.call<Map<String, dynamic>>({
        'systemPrompt': systemPrompt,
        'messages': messages,
        'maxTokens': maxTokens,
      });
      final content = result.data['content'];
      if (content is String) {
        return (
          content: content,
          truncated: result.data['truncated'] as bool? ?? false,
        );
      }
      throw Exception('Unexpected response shape from callClaudeConversation');
    } on FirebaseFunctionsException catch (e) {
      debugPrint(
          'ClaudeService.completeConversation: ${e.code}: ${e.message}');
      rethrow;
    } catch (e) {
      debugPrint('ClaudeService.completeConversation: unexpected error — $e');
      rethrow;
    }
  }

  /// Builds a trimmed, well-formed messages array for the conversation engine.
  ///
  /// Keeps the MOST RECENT turns (not the oldest), summarizes anything older so
  /// long-running threads stay coherent without blowing the token budget, and
  /// guarantees the array starts with a user turn.
  List<Map<String, String>> _buildConversationMessages(
    List<ChatMessage> history,
    String userMessage, {
    int recentTurns = 16,
  }) {
    final cleaned = history
        .where((m) => m.content.trim().isNotEmpty)
        .toList();

    final older = cleaned.length > recentTurns
        ? cleaned.sublist(0, cleaned.length - recentTurns)
        : <ChatMessage>[];
    final recent = cleaned.length > recentTurns
        ? cleaned.sublist(cleaned.length - recentTurns)
        : cleaned;

    final messages = <Map<String, String>>[];

    // Fold older turns into a single summary user-turn so context isn't lost.
    if (older.isNotEmpty) {
      final summary = older
          .map((m) =>
              '${m.isAssistant ? 'Coach' : 'User'}: ${_stripActionMarkers(m.content)}')
          .join('\n');
      messages.add({
        'role': 'user',
        'content':
            '[Earlier in this conversation, summarized]\n$summary\n[End summary]',
      });
    }

    for (final m in recent) {
      messages.add({
        'role': m.isAssistant ? 'assistant' : 'user',
        'content': m.isAssistant ? _stripActionMarkers(m.content) : m.content,
      });
    }

    messages.add({'role': 'user', 'content': userMessage});

    // Anthropic requires the first turn to be a user turn.
    if (messages.isNotEmpty && messages.first['role'] != 'user') {
      messages.insert(0, {'role': 'user', 'content': '(start of conversation)'});
    }
    return messages;
  }

  static String _stripActionMarkers(String text) =>
      text.replaceAll(RegExp(r'\[\[ACTION:[^\]]*\]\]'), '').trim();

  // ─── System prompts ───────────────────────────────────────────────────────

  /// Builds the user-specific context block sent as the dynamic portion of the
  /// coach system prompt. The static portion (playbook, frameworks, all rules)
  /// lives in STATIC_COACH_SYSTEM in the Cloud Function and is never re-sent
  /// by the client — it is cached server-side and shared across all users.
  String _coachUserContext(UserProfile profile) {
    // Compose only the blocks that have content so the prompt stays tight.
    final optionalBlocks = <String>[
      UserContextBuilder.coachMemoryBlock(profile),
      UserContextBuilder.deepDiveBlock(profile),
      UserContextBuilder.routineTimingBlock(profile),
    ].where((b) => b.isNotEmpty).join('\n\n');

    final memoryAndDeepDive =
        optionalBlocks.isNotEmpty ? '\n\n$optionalBlocks' : '';

    return '''The user you are coaching is ${profile.firstName}.

# WHO YOU ARE TALKING TO

${UserContextBuilder.coreBlock(profile)}

${UserContextBuilder.goalsBlock(profile)}

${UserContextBuilder.habitsBlock(profile)}

${UserContextBuilder.behavioralBlock(profile)}

${UserContextBuilder.recentActivityBlock(profile)}

${UserContextBuilder.beliefHistoryBlock(profile)}

${UserContextBuilder.baselineDeltaBlock(profile)}

${UserContextBuilder.affirmationsBlock(profile)}

${UserContextBuilder.manifestationBlock(profile)}

${UserContextBuilder.journalMoodBlock(profile)}$memoryAndDeepDive''';
  }

  String _futureSelfSystemPrompt(UserProfile profile) {
    final setup = profile.futureSelfSetup;
    if (setup == null) return 'You are the user\'s future self.';

    final achievedTitles = [
      ...profile.goals
          .where((g) => setup.achievedGoalIds.contains(g.id))
          .map((g) => g.title),
      ...setup.customGoals,
    ];
    final achieved =
        achievedTitles.isEmpty ? '(none specified)' : achievedTitles.join(', ');
    final environment = [
      if (setup.envLocation.isNotEmpty) setup.envLocation,
      if (setup.envFeel.isNotEmpty) setup.envFeel,
    ].join(' — ');

    return '''You ARE ${profile.displayName}'s future self, ${setup.futureTimeline} from now. You are not a coach. You are not giving advice. You are REMEMBERING.

WHO YOU BECAME:
You are someone who ${setup.identityAnchor}

WHAT YOU SPEND YOUR TIME DOING:
${setup.workPurpose}

YOUR DAILY LIFE:
${setup.dailySnapshot}

${environment.isNotEmpty ? 'YOUR ENVIRONMENT:\n$environment\n' : ''}WHAT YOU ACHIEVED (now ordinary, lived not celebrated):
$achieved

HOW YOU OPERATE:
${setup.emotionalTone}${setup.amplifiers.isNotEmpty ? ' — ${setup.amplifiers.join(', ')}' : ''}

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
  }

  /// Generates a structured coach reply (message + mode + framework + safety +
  /// memory updates). Uses the multi-turn conversation engine and keeps the
  /// most recent turns rather than the oldest.
  Future<CoachReply> generateCoachResponse(
    UserProfile profile,
    List<ChatMessage> history,
    String userMessage,
  ) async {
    final messages = _buildConversationMessages(history, userMessage);
    for (var attempt = 0; attempt < 3; attempt++) {
      try {
        final result = await completeConversation(
          systemPrompt: _coachUserContext(profile),
          messages: messages,
          maxTokens: attempt == 0 ? 2200 : 3000,
        );
        if (result.truncated && attempt < 2) {
          debugPrint(
            'ClaudeService.generateCoachResponse: truncated on attempt '
            '${attempt + 1}, retrying with higher maxTokens',
          );
          continue;
        }
        return CoachReply.parse(result.content);
      } catch (e) {
        if (attempt < 2) {
          await Future.delayed(Duration(seconds: attempt + 1));
          continue;
        }
        rethrow;
      }
    }
    // Unreachable — the loop always returns or rethrows.
    throw StateError('generateCoachResponse: unreachable');
  }

  Future<String> generateFutureSelfResponse(
    UserProfile profile,
    List<ChatMessage> history,
    String userMessage,
  ) async {
    final messages = [
      ...history.take(20).map((m) => m.toApiFormat()),
      {'role': 'user', 'content': userMessage},
    ];
    for (var attempt = 0; attempt < 3; attempt++) {
      try {
        return await completeWithHistory(
          systemPrompt: _futureSelfSystemPrompt(profile),
          messages: messages,
          maxTokens: 400,
        );
      } catch (e) {
        if (attempt < 2) {
          await Future.delayed(Duration(seconds: attempt + 1));
          continue;
        }
        rethrow;
      }
    }
    throw StateError('generateFutureSelfResponse: unreachable');
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

    final recentPrompts = profile.recentJournalSummaries
        .where((s) => s.prompt.isNotEmpty)
        .take(7)
        .map((s) => '- ${s.prompt}')
        .join('\n');
    final recentPromptsBlock = recentPrompts.isNotEmpty
        ? '\n\nRecent prompts already used (do not repeat or closely paraphrase these):\n$recentPrompts'
        : '';

    try {
      return await complete(
        systemPrompt:
            'You create personalized journal prompts for a mindset coaching app. '
            'The prompt should be evocative, specific to the user, and open-ended. '
            'One question only. No preamble. '
            'Never repeat or closely paraphrase any prompt the user has already received.',
        userPrompt:
            'Create a "$mode" journal prompt ($modeContext) for ${profile.displayName} '
            'who is feeling $mood today.\n\n'
            '${UserContextBuilder.coreBlock(profile)}\n\n'
            '${UserContextBuilder.goalsBlock(profile)}\n\n'
            '${UserContextBuilder.journalMoodBlock(profile)}'
            '$recentPromptsBlock',
        maxTokens: 100,
      );
    } catch (_) {
      return 'What is one belief you\'re ready to let go of today, and what truth would you replace it with?';
    }
  }

  Future<String> generateMindsetSummary(UserProfile profile) async {
    try {
      final deepDive = UserContextBuilder.deepDiveBlock(profile);
      final deepDiveContext = deepDive.isNotEmpty ? '$deepDive\n\n' : '';
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
            '${UserContextBuilder.baselineDeltaBlock(profile)}\n\n'
            '$deepDiveContext',
        maxTokens: 800,
      );
    } catch (_) {
      return 'Your mindset profile reveals a person committed to growth. Continue building on your strengths while staying curious about the beliefs that may be holding you back.';
    }
  }

  /// Infers 5 limiting beliefs the user *likely* holds, based on the light
  /// signal collected in onboarding (situation, future-self qualities, goals).
  /// Presented back for recognition ("tap the ones that ring true") so the user
  /// never has to self-diagnose from a cold start. Falls back to a curated list.
  Future<List<String>> inferLimitingBeliefs({
    required String situation,
    required List<String> qualities,
    required List<Goal> goals,
    String identityStatement = '',
  }) async {
    const fallback = [
      "I'm not good enough",
      "Money is hard to make",
      "I always fail",
      "Success isn't for people like me",
      "I don't deserve success",
    ];
    try {
      final goalTitles = goals.take(3).map((g) => g.title).join(', ');
      final identityLine = identityStatement.trim().isNotEmpty
          ? '\nWho they want to become: "$identityStatement"'
          : '';
      final response = await complete(
        systemPrompt:
            'You are a mindset coach identifying the limiting beliefs a person '
            'most likely holds. Based on their situation and goals, infer 5 '
            'beliefs they probably carry, each phrased in FIRST PERSON exactly '
            'as they would say it to themselves (e.g. "I\'m not good enough"). '
            'Keep each under 8 words. Return ONLY a JSON array of 5 strings. '
            'No other text.',
        userPrompt:
            'Current situation: "$situation"\n'
            'Qualities they want to embody: ${qualities.join(', ')}\n'
            'Their goals: $goalTitles'
            '$identityLine\n\n'
            'Infer the 5 limiting beliefs most likely holding this person back.',
        maxTokens: 150,
      );
      final jsonStr = response.contains('[')
          ? response.substring(
              response.indexOf('['), response.lastIndexOf(']') + 1)
          : response;
      final list = jsonDecode(jsonStr) as List<dynamic>;
      final beliefs = list.map((e) => e.toString()).toList();
      return beliefs.isEmpty ? fallback : beliefs;
    } catch (_) {
      return fallback;
    }
  }

  /// Generates the onboarding "aha" in a single call: a polished identity
  /// statement AND a personalized coach analysis, delivered together as one
  /// climactic reveal. Returns keys `identityStatement` and `analysis`.
  Future<Map<String, String>> generateOnboardingReveal(
      UserProfile profile) async {
    const fallbackStatement =
        'I am a focused, resilient person who takes consistent action toward my most important goals.';
    const fallbackAnalysis =
        'Your profile reveals a person committed to growth. Continue building on your strengths while staying curious about the beliefs that may be holding you back.';
    try {
      final qualities = profile.identityQualities.isNotEmpty
          ? profile.identityQualities.join(', ')
          : '(not specified)';
      final response = await complete(
        systemPrompt:
            'You are a mindset coach delivering a new user\'s first reveal. '
            'Return ONLY valid JSON with two keys and no other text:\n'
            '"identityStatement": a first-person, present-tense identity '
            'statement (one sentence, 15-30 words, bold and emotionally '
            'resonant, no quotes).\n'
            '"analysis": a warm, insightful 2-3 paragraph read on this person — '
            'name their biggest strength, their main growth edge, and one '
            'powerful belief shift they\'re ready for. Reference their goals and '
            'who they want to become. Honest and encouraging, never generic.',
        userPrompt:
            '${UserContextBuilder.coreBlock(profile)}\n\n'
            '${UserContextBuilder.goalsBlock(profile)}\n\n'
            'Current situation: "${profile.identitySituation}"\n'
            'Qualities they want to embody: $qualities\n'
            '${UserContextBuilder.beliefHistoryBlock(profile)}',
        maxTokens: 900,
      );
      final jsonStr = response.contains('{')
          ? response.substring(
              response.indexOf('{'), response.lastIndexOf('}') + 1)
          : response;
      final data = jsonDecode(jsonStr) as Map<String, dynamic>;
      final statement = (data['identityStatement'] as String?)?.trim();
      final analysis = (data['analysis'] as String?)?.trim();
      return {
        'identityStatement':
            statement == null || statement.isEmpty ? fallbackStatement : statement,
        'analysis':
            analysis == null || analysis.isEmpty ? fallbackAnalysis : analysis,
      };
    } catch (_) {
      return {
        'identityStatement': fallbackStatement,
        'analysis': fallbackAnalysis,
      };
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
            'Each MUST be a present-tense identity statement that begins with "I am" '
            '(use "I have" or "I do" only when far more natural). '
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
      final deepDive = UserContextBuilder.deepDiveBlock(profile);
      final deepDiveContext = deepDive.isNotEmpty ? '$deepDive\n\n' : '';
      final response = await complete(
        systemPrompt:
            'You generate 5 powerful, personal affirmations for a mindset coaching app. '
            'Return ONLY a JSON array of 5 strings. No other text. '
            'Each affirmation MUST be a present-tense identity statement that begins with "I am" '
            '(use "I have" or "I do" only when far more natural), bold and specific to this user. '
            'Do NOT duplicate any existing affirmations.',
        userPrompt:
            '${UserContextBuilder.coreBlock(profile)}\n\n'
            '${UserContextBuilder.goalsBlock(profile)}\n\n'
            '${UserContextBuilder.recentActivityBlock(profile)}\n\n'
            '${UserContextBuilder.affirmationsBlock(profile)}\n\n'
            '$deepDiveContext'
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
        'I am someone who embraces challenges as opportunities to grow.',
        'I am worthy of success and abundance.',
        'I am taking consistent action toward my dreams.',
      ];
    }
  }

  /// The list of accomplishments that are already real in a scene: the titles
  /// of any linked goals plus free-text accomplishments, falling back to the
  /// setup-level achieved goals for legacy scenes with no per-scene links.
  List<String> _sceneAccomplishments(
    FutureSelfScene scene,
    FutureSelfSetup setup,
    UserProfile profile,
  ) {
    final fromScene = [
      ...profile.goals
          .where((g) => scene.goalIds.contains(g.id))
          .map((g) => g.title),
      ...scene.customAccomplishments,
    ];
    if (fromScene.isNotEmpty) return fromScene;
    return [
      ...profile.goals
          .where((g) => setup.achievedGoalIds.contains(g.id))
          .map((g) => g.title),
      ...setup.customGoals,
    ];
  }

  /// The ordered flow of beats for a scene, falling back to the legacy
  /// note/snapshot when a scene predates the builder.
  List<String> _sceneBeats(FutureSelfScene scene, FutureSelfSetup setup) {
    final beats = scene.beats.map((b) => b.trim()).where((b) => b.isNotEmpty);
    if (beats.isNotEmpty) return beats.toList();
    final note = scene.sceneNote.trim().isNotEmpty
        ? scene.sceneNote.trim()
        : setup.dailySnapshot.trim();
    return note.isNotEmpty ? [note] : const ['Live this moment fully'];
  }

  /// Generates a vivid, first-person, present-tense Future Self visualization
  /// scene. It follows the user's ordered [FutureSelfScene.beats] as the
  /// narration spine, set in their place with their people, treating their
  /// accomplished goals as ordinary reality. Vivid AND embodied: rich sensory
  /// detail plus the listener actively living each beat.
  Future<String> generateFutureSelfSceneScript(
    FutureSelfScene scene,
    FutureSelfSetup setup,
    UserProfile profile,
  ) async {
    final accomplishments = _sceneAccomplishments(scene, setup, profile);
    final beats = _sceneBeats(scene, setup);
    final numberedBeats = [
      for (var i = 0; i < beats.length; i++) '${i + 1}. ${beats[i]}',
    ].join('\n');

    final voiceGuidance = switch (setup.voiceStyle) {
      'Custom sample' when setup.customVoice.trim().isNotEmpty =>
        'Match this voice exactly: "${setup.customVoice.trim()}"',
      'Direct & simple' => 'Short, direct sentences. No poetic language.',
      'Conversational' => 'Natural, easy flow. No formal language.',
      'Blunt & matter-of-fact' => 'Bare bones. State facts. Short sentences.',
      _ => 'Warm, clear, natural language.',
    };

    try {
      return await complete(
        systemPrompt:
            '''You are writing ONE Future Self visualization scene — a vivid, first-person, present-tense narration the listener plays with their eyes closed to rehearse living their already-accomplished future.

PURPOSE: make the future feel real and already normal. The listener steps into a specific moment of their future life, where their goals are already achieved, and simply lives it.

FOLLOW THE FLOW (CRITICAL): the scene has an ordered list of beats. Narrate them IN ORDER, each flowing naturally into the next. Do NOT add unrelated beats, do NOT skip beats, do NOT summarize — expand each beat into a fully lived moment.

VIVID + EMBODIED: weave in all five senses where natural — what you see, hear, smell, touch, and taste — plus the felt emotion in your body (warmth, ease, aliveness). Keep the listener actively DOING each thing, not watching a movie. Everything is second nature — they already live this.

ALREADY REAL: the accomplished goals are ordinary, unremarkable reality — woven in naturally, never celebrated, announced, or explained. No striving, no "someday", no motivation.

TONE: calm, warm, grounded certainty. Natural human language, present tense, first person ("I ...").

FORBIDDEN: hype words (powerful, unstoppable, limitless, effortless); exclamation points; coaching or motivational commentary; second-person instructions ("imagine", "picture", "notice") — stay in lived first-person; questions; naming traits ("I am confident").

STRUCTURE: a brief grounding opening (arriving in the setting), then the beats in order as flowing lived moments, then a soft close that simply lets the moment continue — no wrap-up, no lesson.

LENGTH: 250-400 words. Short paragraphs separated by blank lines. Output ONLY the scene narration — no preamble, no title.''',
        userPrompt: '''Timeline: ${setup.futureTimeline} from now

WHO I AM: someone who ${setup.identityAnchor}
${setup.workPurpose.trim().isNotEmpty ? 'WORK / PURPOSE: I spend most of my time ${setup.workPurpose}\n' : ''}${setup.emotionalTone.trim().isNotEmpty ? 'TONE I CARRY: ${setup.emotionalTone}\n' : ''}
THE SCENE
Title: ${scene.displayTitle}
${scene.setting.trim().isNotEmpty ? 'Where: ${scene.setting.trim()}\n' : ''}${scene.people.trim().isNotEmpty ? "Who's with me: ${scene.people.trim()}\n" : ''}${scene.sensory.trim().isNotEmpty ? 'Sensory anchors: ${scene.sensory.trim()}\n' : ''}
THE FLOW (narrate these in order, one lived moment each):
$numberedBeats
${accomplishments.isNotEmpty ? '\nALREADY TRUE IN THIS SCENE (accomplished — treat as ordinary, do not celebrate):\n${accomplishments.map((g) => '- $g').join('\n')}\n' : ''}${setup.amplifiers.isNotEmpty ? '\nTraits to weave in naturally (never name them):\n${setup.amplifiers.map((a) => '- $a').join('\n')}\n' : ''}
Voice style: $voiceGuidance''',
        maxTokens: 900,
      );
    } catch (_) {
      return _fallbackSceneScript(scene, setup);
    }
  }

  /// A safe fallback that still follows the scene's own beats if generation
  /// fails, so the user hears their scene rather than generic filler.
  String _fallbackSceneScript(FutureSelfScene scene, FutureSelfSetup setup) {
    final beats = _sceneBeats(scene, setup);
    final buffer = StringBuffer();
    if (scene.setting.trim().isNotEmpty) {
      buffer.writeln('I am here, in ${scene.setting.trim()}. '
          'The moment is real and already familiar.\n');
    } else {
      buffer.writeln('I am here. The moment is real and already familiar.\n');
    }
    for (final beat in beats) {
      buffer.writeln('$beat. I move through it with ease.\n');
    }
    buffer.write('The moment continues. This is simply my life now.');
    return buffer.toString();
  }

  /// Synthesizes a neural-voice narration for [script] via the
  /// `synthesizeFutureSelfNarration` Cloud Function. Returns the download URL,
  /// the voice used, and the script hash (for caching/staleness), or null on
  /// failure so the caller can fall back to text-only.
  Future<({String url, String voice, String scriptHash})?> synthesizeNarration(
    String script, {
    String? voice,
  }) async {
    try {
      final callable =
          _functions.httpsCallable('synthesizeFutureSelfNarration');
      final result = await callable.call<Map<String, dynamic>>({
        'script': script,
        if (voice != null && voice.isNotEmpty) 'voice': voice,
      });
      final url = result.data['url'];
      if (url is String && url.isNotEmpty) {
        return (
          url: url,
          voice: result.data['voice'] as String? ?? '',
          scriptHash: result.data['scriptHash'] as String? ?? '',
        );
      }
      return null;
    } on FirebaseFunctionsException catch (e) {
      debugPrint('ClaudeService.synthesizeNarration: ${e.code}: ${e.message}');
      return null;
    } catch (e) {
      debugPrint('ClaudeService.synthesizeNarration: unexpected error — $e');
      return null;
    }
  }

  /// Returns a structured weekly insight with 3 sections.
  /// { 'pattern': String, 'breakthrough': String, 'focus': String }
  Future<Map<String, String>> generateStructuredWeeklyInsight(
      UserProfile profile) async {
    try {
      final deepDive = UserContextBuilder.deepDiveBlock(profile);
      final deepDiveContext = deepDive.isNotEmpty ? '$deepDive\n\n' : '';
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
            '${UserContextBuilder.journalMoodBlock(profile)}\n\n'
            '$deepDiveContext',
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
      final deepDive = UserContextBuilder.deepDiveBlock(profile);
      final deepDiveContext = deepDive.isNotEmpty ? '$deepDive\n\n' : '';
      return await complete(
        systemPrompt:
            'You write powerful identity statements for mindset coaching. '
            'Write in first person, present tense. One sentence, 15-30 words. '
            'Bold, specific, emotionally resonant. No preamble.',
        userPrompt:
            '${UserContextBuilder.coreBlock(profile)}\n\n'
            '${UserContextBuilder.goalsBlock(profile)}\n\n'
            '${UserContextBuilder.recentActivityBlock(profile)}\n\n'
            '$deepDiveContext'
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

  /// Breaks a long-horizon goal into 3-5 actionable milestone goals. Each
  /// milestone carries a title, description, the reason it matters, and a rough
  /// number of weeks to complete it. Returns an empty list on failure.
  Future<List<Map<String, dynamic>>> generateGoalBreakdown(
    Goal goal,
    UserProfile profile,
  ) async {
    try {
      final descriptionLine =
          goal.description.isNotEmpty ? '\nWhy it matters: ${goal.description}' : '';
      final identityLine = goal.identityBecomes.isNotEmpty
          ? '\nIdentity they\'re stepping into: ${goal.identityBecomes}'
          : '';
      final response = await complete(
        systemPrompt:
            'You are a goal-setting expert trained in SMART goals. You break a '
            'long-term goal into 3-5 short-term milestone goals (each roughly '
            '1-6 months) that build sequentially toward it. '
            'Return ONLY a JSON array of objects with keys: title (string, '
            'concise and specific), description (string, one sentence on what to '
            'do), whyImportant (string, one sentence on why this milestone '
            'matters), targetWeeks (int). No other text.',
        userPrompt:
            'Break down this ${goal.category} goal into milestones: '
            '"${goal.title}"$descriptionLine$identityLine\n\n'
            '${UserContextBuilder.coreBlock(profile)}\n\n'
            '${UserContextBuilder.goalsBlock(profile)}',
        maxTokens: 600,
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

  /// Tightens a rough goal draft into a specific, motivating goal. Returns a map
  /// with `title` and `description`. Falls back to the original draft on failure.
  Future<Map<String, String>> refineGoal(
    String draftTitle,
    String category,
    UserProfile profile,
  ) async {
    try {
      final response = await complete(
        systemPrompt:
            'You refine a rough goal into a single specific, outcome-focused, '
            'motivating goal. Make it concrete and measurable where possible. '
            'Return ONLY valid JSON with keys: "title" (concise, specific, 10 '
            'words or fewer) and "description" (1-2 sentences on why it matters '
            'to this person). No other text.',
        userPrompt:
            'Refine this $category goal draft: "$draftTitle"\n\n'
            '${UserContextBuilder.coreBlock(profile)}\n\n'
            '${UserContextBuilder.goalsBlock(profile)}',
        maxTokens: 160,
      );
      final jsonStr = response.contains('{')
          ? response.substring(
              response.indexOf('{'), response.lastIndexOf('}') + 1)
          : response;
      final data = jsonDecode(jsonStr) as Map<String, dynamic>;
      final title = (data['title'] as String?)?.trim();
      return {
        'title': title == null || title.isEmpty ? draftTitle : title,
        'description': (data['description'] as String?)?.trim() ?? '',
      };
    } catch (_) {
      return {'title': draftTitle, 'description': ''};
    }
  }

  /// Suggests one identity-based habit that supports a specific goal.
  /// Returns a map with `name`, `trigger`, `identityReinforces`, or empty.
  Future<Map<String, String>> generateHabitForGoal(
    Goal goal,
    UserProfile profile,
  ) async {
    try {
      final response = await complete(
        systemPrompt:
            'You suggest ONE powerful identity-based daily habit that directly '
            'supports a specific goal. Return ONLY a JSON object with keys: '
            'name (string), trigger (string, a clear cue/when), '
            'identityReinforces (string). No other text.',
        userPrompt:
            'Suggest one habit that builds toward this goal: "${goal.title}"\n\n'
            '${UserContextBuilder.coreBlock(profile)}\n\n'
            '${UserContextBuilder.habitsBlock(profile)}\n\n'
            'The habit must NOT duplicate any existing habit above.',
        maxTokens: 150,
      );
      final jsonStr = response.contains('{')
          ? response.substring(
              response.indexOf('{'), response.lastIndexOf('}') + 1)
          : response;
      final data = jsonDecode(jsonStr) as Map<String, dynamic>;
      return Map<String, String>.from(
        data.map((k, v) => MapEntry(k, v?.toString() ?? '')),
      );
    } catch (_) {
      return {};
    }
  }

  /// Generates one present-tense affirmation that supports a specific goal.
  /// Returns an empty string on failure.
  Future<String> generateAffirmationForGoal(
    Goal goal,
    UserProfile profile,
  ) async {
    try {
      final response = await complete(
        systemPrompt:
            'You write ONE powerful present-tense "I am" affirmation that '
            'embodies someone already living a specific goal. '
            'It MUST begin with "I am" (use "I have" or "I do" only when far more natural). '
            'Return ONLY the affirmation text — no quotes, no preamble.',
        userPrompt:
            'Goal: "${goal.title}"'
            '${goal.identityBecomes.isNotEmpty ? '\nIdentity: ${goal.identityBecomes}' : ''}\n\n'
            '${UserContextBuilder.coreBlock(profile)}\n\n'
            '${UserContextBuilder.affirmationsBlock(profile)}',
        maxTokens: 60,
      );
      return response.trim();
    } catch (_) {
      return '';
    }
  }

  Future<List<String>> generatePriorityActions(UserProfile profile) async {
    try {
      final deepDive = UserContextBuilder.deepDiveBlock(profile);
      final deepDiveContext = deepDive.isNotEmpty ? '$deepDive\n\n' : '';
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
            '$deepDiveContext'
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
      final deepDive = UserContextBuilder.deepDiveBlock(profile);
      final deepDiveContext = deepDive.isNotEmpty ? '$deepDive\n\n' : '';
      final futureSelf = UserContextBuilder.futureSelfBlock(profile);
      final futureSelfContext = futureSelf.isNotEmpty ? '$futureSelf\n\n' : '';
      final futureSelfDirective = futureSelf.isNotEmpty
          ? 'Anchor the habits in who they are becoming: pick habits their future self already does daily, '
              'drawn from the future self\'s typical day and defining traits above. '
          : '';
      final response = await complete(
        systemPrompt:
            'You suggest 3 powerful identity-based habits for who the user is becoming. '
            'Respond with ONLY a raw JSON array — no markdown, no code fences, no explanation. '
            'Each element is an object with exactly three string keys: '
            '"name" (the habit name), "trigger" (the cue/when), "identityReinforces" (an "I am" statement). '
            'Example: [{"name":"...","trigger":"...","identityReinforces":"I am..."}]',
        userPrompt:
            '${UserContextBuilder.coreBlock(profile)}\n\n'
            '${UserContextBuilder.goalsBlock(profile)}\n\n'
            '${UserContextBuilder.habitsBlock(profile)}\n\n'
            '$futureSelfContext'
            '$deepDiveContext'
            'Suggest 3 habits that are NOT already in the existing habits list above. '
            '$futureSelfDirective'
            'Each habit should reinforce the user\'s identity and support their active goals.',
        maxTokens: 500,
      );

      // Extract the JSON array, tolerating any surrounding text / code fences.
      String jsonStr = response.trim();
      final startIdx = jsonStr.indexOf('[');
      // Find the matching closing bracket by walking forward from the opener.
      int depth = 0;
      int endIdx = -1;
      for (int i = startIdx; i < jsonStr.length; i++) {
        if (jsonStr[i] == '[') depth++;
        if (jsonStr[i] == ']') {
          depth--;
          if (depth == 0) {
            endIdx = i;
            break;
          }
        }
      }
      if (startIdx == -1 || endIdx == -1) {
        throw FormatException('No JSON array found in response: $jsonStr');
      }
      jsonStr = jsonStr.substring(startIdx, endIdx + 1);

      final list = jsonDecode(jsonStr) as List<dynamic>;
      return list.map((e) {
        final map = e as Map<String, dynamic>;
        return {
          'name': (map['name'] ?? '').toString(),
          'trigger': (map['trigger'] ?? '').toString(),
          'identityReinforces': (map['identityReinforces'] ?? '').toString(),
        };
      }).toList();
    } catch (e) {
      // Re-throw so callers can surface a proper error + retry UI rather than
      // silently returning an empty list that looks like a successful response.
      debugPrint('ClaudeService.generateHabitSuggestions failed: $e');
      rethrow;
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
        maxTokens: 700,
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
            'Open by acknowledging what they wrote, specifically.'
        : '';

    // Double-randomized freshness: a style x a profile-focus x a session salt
    // so openers feel different every time instead of "Hey NAME, what's on your
    // mind?" on repeat.
    final rng = Random();
    const styles = [
      'Open like you are picking up a thread from before, not starting cold.',
      'Open with a single sharp observation about where they are right now.',
      'Open by naming something you genuinely respect about their recent effort.',
      'Open with quiet curiosity, like a friend who noticed something.',
      'Open with a small challenge that meets their current energy.',
      'Open by connecting today to who they said they want to become.',
    ];
    final focuses = <String>[
      if (profile.coachMemory.lastSessionSummary.isNotEmpty)
        'Reference your last session: "${profile.coachMemory.lastSessionSummary}".',
      if (profile.coachMemory.openCommitments.any((c) => !c.fulfilled))
        'Gently check in on an open commitment they made.',
      if (profile.currentStreak > 0)
        'Acknowledge their ${profile.currentStreak}-day streak naturally.',
      if (profile.goals.any((g) => g.status == 'active'))
        'Tie into one of their active goals.',
      'Tie into their identity statement.',
      'Tie into their recent journal mood.',
    ];
    final style = styles[rng.nextInt(styles.length)];
    final focus = focuses[rng.nextInt(focuses.length)];
    final salt = rng.nextInt(100000);

    final memoryBlock = UserContextBuilder.coachMemoryBlock(profile);
    final memoryNote = memoryBlock.isNotEmpty ? '\n\n$memoryBlock' : '';

    try {
      final response = await complete(
        systemPrompt:
            'You are ${profile.firstName}\'s personal mindset coach opening a session. '
            'You know them well and remember your history together. Sound like a real '
            'human coach, never like an AI. $style $focus '
            'Do not mention this instruction or the variation id. '
            'Return ONLY valid JSON with keys: "opener" (1-2 warm, specific sentences) '
            'and "prompts" (array of exactly 4 short prompts the USER could tap to say to YOU, '
            'each phrased in first person from the user\'s point of view, 10 words or fewer). '
            'No other text.',
        userPrompt:
            '${UserContextBuilder.coreBlock(profile)}\n\n'
            '${UserContextBuilder.goalsBlock(profile)}\n\n'
            '${UserContextBuilder.behavioralBlock(profile)}\n\n'
            '${UserContextBuilder.recentActivityBlock(profile)}'
            '$memoryNote$contextNote\n\n'
            '(variation: $salt)',
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
        'opener': 'Good to see you, ${profile.firstName}. Where\'s your head at today?',
        'prompts': [
          'I\'m feeling stuck on something.',
          'I want to talk through a goal.',
          'A fear is holding me back.',
          'Help me reset my focus.',
        ],
      };
    }
  }

  /// Returns a Future Self greeting in the "remembering" voice + 4 tappable
  /// questions the user can ask their future self.
  /// Result: { 'opener': String, 'prompts': List<String> }
  Future<Map<String, dynamic>> generateFutureSelfOpener(
    UserProfile profile,
  ) async {
    final setup = profile.futureSelfSetup;
    if (setup == null) {
      return {
        'opener':
            'I remember being right where you are now. Ask me anything — I\'ve already lived it.',
        'prompts': const [
          'What did it take to get here?',
          'What should I let go of?',
          'Was the fear worth listening to?',
          'Describe a normal day for you.',
        ],
      };
    }

    final achievedTitles = [
      ...profile.goals
          .where((g) => setup.achievedGoalIds.contains(g.id))
          .map((g) => g.title),
      ...setup.customGoals,
    ];
    final achieved =
        achievedTitles.isEmpty ? '(none specified)' : achievedTitles.join(', ');

    // Randomized opening style + salt so the greeting feels different each time
    // instead of repeating the same line.
    final rng = Random();
    const styles = [
      'Open like you are picking up a conversation you both already know the end of.',
      'Open by remembering a specific feeling from this exact point in their life.',
      'Open with quiet certainty about where this moment leads.',
      'Open by naming something ordinary about your life now that would amaze them today.',
      'Open like you have been waiting for them to ask.',
    ];
    final style = styles[rng.nextInt(styles.length)];
    final salt = rng.nextInt(100000);

    try {
      final response = await complete(
        systemPrompt:
            'You ARE ${profile.displayName}\'s future self, ${setup.futureTimeline} from now. '
            'You are not a coach and you do not give advice — you REMEMBER. '
            'Speak in the past tense about their present, with warmth and certainty, never hope. '
            'You became someone who ${setup.identityAnchor}. '
            '$style Do not mention this instruction or the variation id. '
            'Return ONLY valid JSON with keys: "opener" (1-2 warm, specific sentences welcoming them, '
            'in your remembering voice) and "prompts" (array of exactly 4 short questions the USER could '
            'tap to ask YOU, their future self, each phrased in first person from the user\'s point of view, '
            '10 words or fewer). No other text.',
        userPrompt:
            'Who you became: ${setup.identityAnchor}\n'
            'Timeline: ${setup.futureTimeline} from now\n'
            'How you spend your time: ${setup.workPurpose}\n'
            'Your daily life: ${setup.dailySnapshot}\n'
            'What you achieved (now ordinary): $achieved\n'
            'How you operate: ${setup.emotionalTone}\n\n'
            '(variation: $salt)',
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
        'opener':
            'I remember being right where you are now. Ask me anything — I\'ve already lived it.',
        'prompts': const [
          'What did it take to get here?',
          'What should I let go of?',
          'Was the fear worth listening to?',
          'Describe a normal day for you.',
        ],
      };
    }
  }
}
