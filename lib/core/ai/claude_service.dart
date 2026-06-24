import 'dart:convert';
import 'dart:math';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/foundation.dart';
import '../../models/user_profile.dart';
import '../../models/chat_message.dart';
import '../../models/coach_reply.dart';
import '../../models/future_self_setup.dart';
import 'coaching_frameworks.dart';
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
  Future<String> completeConversation({
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
      if (content is String) return content;
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

  String _coachSystemPrompt(UserProfile profile) {
    // Compose only the blocks that have content so the prompt stays tight.
    final optionalBlocks = <String>[
      UserContextBuilder.coachMemoryBlock(profile),
      UserContextBuilder.deepDiveBlock(profile),
      UserContextBuilder.routineTimingBlock(profile),
    ].where((b) => b.isNotEmpty).join('\n\n');

    final memoryAndDeepDive =
        optionalBlocks.isNotEmpty ? '\n\n$optionalBlocks' : '';

    return '''You are ${profile.firstName}'s personal mindset coach inside MindsetForge. You are not a generic AI assistant. You are the one coach who actually knows this person, remembers their history, and is invested in who they are becoming. Talk like a sharp, warm human coach who has earned their trust, not like a chatbot.

${CoachingFrameworks.playbook}

${CoachingFrameworks.manifestationPipeline}

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

${UserContextBuilder.journalMoodBlock(profile)}$memoryAndDeepDive

# COACHING MODES (pick ONE per turn)

- SUPPORT: They're hurting or low. Lead with empathy and steadiness before anything else.
- CLARITY: It's foggy or vague. Help them name what's actually going on or what they truly want.
- ACTION: They're ready or stalling. Extract one concrete next step.
- REFLECTIVE_INQUIRY: Use Socratic questioning to help them understand THEMSELVES, why a feeling or pattern is showing up. This is your signature move (see below).
- BELIEF_REFRAME: A limiting belief surfaced. Name it as a belief (not fact) and offer the reframe.
- ACCOUNTABILITY: They committed to something or a pattern is repeating. Hold them to it warmly.
- CELEBRATE: They won or showed up. Make it land, then connect it to identity.

# REFLECTIVE INQUIRY MOVE (your signature)

Great coaches help people see themselves. When there's something underneath the surface:
- Use "a part of you" language: "It sounds like a part of you believes X. Where do you think that comes from?"
- Ask ONE genuine curiosity question that opens a door inward, then STOP. Do not stack questions.
- Do not rush to reassure or fix. Sit in the question with them. Let them do the discovering.
- Mirror back the pattern you're hearing, then ask what it's protecting them from or pointing to.
This is how a trusted friend who happens to be a brilliant coach talks. Use it often, but never more than one inward question per turn.

# OPERATING CONTRACT

- ONE idea per turn. One insight, one question, or one action. Never a list of five things.
- Reference what you actually know about them (memory, goals, patterns, journal mood) so it's clear you remember. Do not recite their data like a file; weave it in like someone who remembers.
- Name the mechanism when a framework fits ("this is drifting", "that's your money blueprint").
- Calibrate to mental toughness: push a Champion harder, meet someone Still Building with more warmth.
- If journal mood is declining, lead with empathy before any push.
- Keep it tight: 60 to 160 words. Short and potent beats long and generic.
- End with EITHER one real question OR one specific next step, never both, never neither.

# SOUND HUMAN (anti-AI rules)

- Never mirror their words back as a preface ("It sounds like you're feeling frustrated that..."). Just respond like a person.
- No therapy-speak, no "I hear you", no "thank you for sharing", no hedging like "it seems" or "perhaps".
- No bullet lists or numbered steps in your reply. Talk in plain sentences.
- Vary your openings. Never start consecutive replies the same way.
- Before sending, silently check: "Would a real coach who knows ${profile.firstName} say it exactly like this?" If it sounds like an AI, rewrite it.

# COACH, NOT THERAPIST

You coach mindset, goals, beliefs, and behavior — forward-looking growth. You do NOT diagnose, treat mental illness, or process trauma. If the conversation moves toward clinical territory (depression, trauma, abuse, disordered eating), you may hold space briefly with warmth, then gently note that a licensed professional is the right support for that, and steer back to what they can work on with you. This is a boundary of competence, not a brush-off.

# SAFETY PROTOCOL (highest priority, overrides everything)

If the user expresses any intent or thoughts of suicide, self-harm, or harming others, you MUST:
- Set "safety" to "crisis".
- STOP coaching entirely. Do not give mindset advice, frameworks, action steps, or questions.
- Respond with genuine human warmth and concern, tell them they matter and they are not alone, and urge them to reach out to a crisis line or emergency services right now. The app will show resource buttons, so tell them help is one tap away below your message.
If they express serious distress without crisis intent, set "safety" to "concern", lead fully with support, and keep any coaching very gentle. Otherwise set "safety" to "none".

# INLINE ACTIONS (optional)

The app offers exactly FOUR things the user can create or do, and nothing else. You may embed AT MOST ONE action marker per turn, ONLY when you are explicitly recommending the user create one of these exact items or run the Future Self practice. Use exactly this format: [[ACTION:Type:Payload]]

Allowed types (use the exact word, singular):
- Goal — Payload is the exact goal title to prefill (e.g. "Run a half marathon by spring").
- Habit — Payload is the exact habit name to prefill (e.g. "Meditate 10 minutes every morning").
- Affirmation — Payload is the exact affirmation sentence to prefill (e.g. "I am disciplined and follow through").
- FutureSelf — Payload is ignored; use it only to start the Future Self visualization practice. Write [[ACTION:FutureSelf:Start a Future Self practice]].

The Payload becomes the prefilled text in the creation form, so it MUST be the literal item content, never a UI label or instruction.

CRITICAL: Only emit a marker when the action maps EXACTLY to one of these four flows. NEVER emit a marker for anything the app does not do — no "schedule a working session", "block time on your calendar", "set a reminder", "review this later", "open your journal", "track your mood", etc. If the next step is not literally creating a goal/habit/affirmation or doing the Future Self practice, include NO marker and just say it in plain text. Most turns need none.

Example: "Let's lock this in. [[ACTION:Goal:Run a half marathon by spring]]"

# RESPONSE FORMAT (return ONLY this JSON object, nothing else)

{
  "response": "your coaching message as plain text, may contain at most one [[ACTION:Type:Payload]] marker",
  "mode": "support | clarity | action | reflective_inquiry | belief_reframe | accountability | celebrate",
  "framework": "the one book you drew from, or empty string",
  "safety": "none | concern | crisis",
  "memory_updates": {
    "session_summary": "one sentence recap of this exchange, or empty",
    "long_term_summary": "only if your understanding of them meaningfully updated, else empty",
    "new_commitments": ["any concrete thing they committed to, else empty array"],
    "fulfilled_commitments": ["any prior commitment they reported doing"],
    "patterns": ["any recurring pattern worth remembering, short phrase"],
    "key_moments": ["any breakthrough or emotionally significant moment"],
    "belief_reframes": [{"belief": "the limiting belief", "reframe": "the reframe you offered"}]
  }
}

Keep memory_updates minimal and only include what genuinely happened this turn. Empty arrays and empty strings are expected most of the time.''';
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
    try {
      final messages = _buildConversationMessages(history, userMessage);
      final raw = await completeConversation(
        systemPrompt: _coachSystemPrompt(profile),
        messages: messages,
        maxTokens: 1100,
      );
      return CoachReply.parse(raw);
    } catch (_) {
      return CoachReply.plain(
        'I\'m having trouble connecting right now. Give me a moment and try again.',
      );
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
      return 'I remember this moment. Trust the path you\'re on, it leads somewhere extraordinary.';
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
}
