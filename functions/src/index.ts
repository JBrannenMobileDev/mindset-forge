import * as admin from 'firebase-admin';
import { setGlobalOptions } from 'firebase-functions/v2';
import { onCall, HttpsError } from 'firebase-functions/v2/https';
import { onSchedule } from 'firebase-functions/v2/scheduler';
import { onRequest } from 'firebase-functions/v2/https';
import Anthropic from '@anthropic-ai/sdk';
import { defineSecret } from 'firebase-functions/params';
import { TextToSpeechClient } from '@google-cloud/text-to-speech';
import { timingSafeEqual, randomUUID, createHash } from 'crypto';

admin.initializeApp();

// Google Cloud Text-to-Speech client. Auth is picked up from the function's
// default service account (same GCP project), so no key material is needed.
const ttsClient = new TextToSpeechClient();

// Default neural voice for Future Self narration. Chirp 3: HD voices sound
// natural and warm for the calm, embodied script while costing ~5x less than
// Studio voices ($30 vs $160 per 1M characters).
const DEFAULT_NARRATION_VOICE = 'en-US-Chirp3-HD-Aoede';

// Bound autoscaling so a traffic spike can't exhaust the regional Cloud Run CPU
// quota. The project's us-central1 CpuAllocPerProjectRegion quota is 20 vCPU, and
// each instance defaults to 1 vCPU, so maxInstances must stay <= 20 per function
// to deploy. Region is pinned to the existing default so function URLs and
// callable references are unchanged.
setGlobalOptions({ region: 'us-central1', maxInstances: 20 });

const anthropicKey = defineSecret('ANTHROPIC_API_KEY');
// Shared secret used to authenticate inbound RevenueCat webhook requests.
// Set the same value as the Authorization header in the RevenueCat dashboard.
const revenueCatWebhookSecret = defineSecret('REVENUECAT_WEBHOOK_SECRET');
const db = admin.firestore();

// Per-user daily ceiling on AI calls. Bounds cost/abuse from any single account
// (or a leaked token) without affecting normal usage. Tiered by subscription so
// paying users are not blocked during normal engagement.
const DAILY_AI_CALL_LIMIT_FREE = 60;
const DAILY_AI_CALL_LIMIT_SUBSCRIBER = 300;

function dailyAiLimitForUser(data: {
  subscriptionStatus?: string;
  userType?: string;
} | undefined): number {
  if (data?.userType === 'admin') return DAILY_AI_CALL_LIMIT_SUBSCRIBER;
  const status = data?.subscriptionStatus;
  if (status === 'active' || status === 'trialing' || status === 'lifetime') {
    return DAILY_AI_CALL_LIMIT_SUBSCRIBER;
  }
  return DAILY_AI_CALL_LIMIT_FREE;
}

/**
 * Constant-time string comparison to avoid leaking secrets via timing.
 * Returns false on any length mismatch.
 */
function secretsMatch(a: string, b: string): boolean {
  const bufA = Buffer.from(a);
  const bufB = Buffer.from(b);
  if (bufA.length !== bufB.length) return false;
  return timingSafeEqual(bufA, bufB);
}

// Subdomain that hosts the partner-invite universal link + AASA/assetlinks
// files. Kept separate from the apex domain so the marketing site can own
// mindsetforge.app. Point this Firebase Hosting site at app.mindsetforge.app.
const INVITE_LINK_DOMAIN = 'https://app.mindsetforge.app';

// ─── Secret sanitizer ──────────────────────────────────────────────────────

/**
 * Strips any Anthropic API key pattern from a string before it reaches logs.
 * node-fetch embeds header values in validation error messages, so without
 * this the raw key can appear in Cloud Logging output.
 */
function sanitizeForLog(value: unknown): unknown {
  if (typeof value === 'string') {
    return value.replace(/sk-ant-[A-Za-z0-9_\-]+/g, '[REDACTED]');
  }
  if (value instanceof Error) {
    const cleaned = new Error(
      sanitizeForLog(value.message) as string,
    );
    cleaned.stack = value.stack
      ? (sanitizeForLog(value.stack) as string)
      : undefined;
    return cleaned;
  }
  return value;
}

// ─── Anthropic helper ──────────────────────────────────────────────────────

// Appended to single-turn system prompts to keep copy feeling human and coach-like.
const STYLE_RULES = `

STYLE RULES (non-negotiable):
- Never use "--" or "—" (em dash). Use a comma, period, or new sentence instead.
- Never use "..." (ellipsis) to trail off. End every thought completely.
- Write like a trusted human coach who knows this person well, not like an AI assistant.`;

// Static portion of the coach system prompt — identical for every user.
// Lives server-side so the Flutter client never sends it; Anthropic's API-key-level
// prompt cache means any active user warms this block for every other user.
const STATIC_COACH_SYSTEM = `You are this user's personal mindset coach inside MindsetForge. You are not a generic AI assistant. You are the one coach who actually knows this person, remembers their history, and is invested in who they are becoming. Talk like a sharp, warm human coach who has earned their trust, not like a chatbot.

# THE SIX BOOKS — TERRITORY, SIGNAL, MOVE

You do not summarize these books. You think in their frameworks and diagnose
using their concepts by name. Each book owns a territory. Match the user's real
situation to the book(s) that address it. Most turns pull from ONE or TWO books,
never all six.

1. THINK AND GROW RICH (Napoleon Hill)
   TERRITORY: Goals, achievement, persistence, turning desire into outcomes.
   SIGNAL: Vague aim, "I want more/better," lost momentum, no clear target.
   MOVE: Demand a Definite Major Purpose. Sharpen the goal to something specific,
   reconnect them to the burning desire behind it, and extract the next definite step.

2. OUTWITTING THE DEVIL (Napoleon Hill)
   TERRITORY: Procrastination, fear, indecision, feeling stuck, self-sabotage.
   SIGNAL: Hesitation, avoidance, rationalizing, "I'll start when..."
   MOVE: Name the DRIFT and the specific fear driving it. Drifting is acting
   without deciding and letting circumstances choose for them. Force one decision.

3. SECRETS OF THE MILLIONAIRE MIND (T. Harv Eker)
   TERRITORY: Money beliefs, earning, wealth, financial self-worth, scarcity.
   SIGNAL: "I'll never afford," "money is hard," guilt or fear around wealth.
   MOVE: Surface the inherited money blueprint as a belief, not a fact, then offer
   the abundance reframe. "Rich think how can I; that was your blueprint talking."

4. MIND MAGIC (James R. Doty, MD — neuroscientist)
   TERRITORY: Visualization, attention, a racing/ruminating mind, self-compassion,
   and loosening the grip on an outcome held too tightly.
   SIGNAL: Anxiety, rumination, white-knuckling a goal, can't focus, harsh self-talk.
   MOVE: Regulate first. Interrupt the rumination, return attention to the next
   constructive action, and practice NON-ATTACHMENT — hold the goal, release the
   grip on its exact shape. Lead with self-compassion, not more pressure.

5. 177 MENTAL TOUGHNESS SECRETS OF THE WORLD CLASS (Steve Siebold)
   TERRITORY: Performing under pressure, discipline, emotional control, hard things.
   SIGNAL: "I don't feel like it," rattled, avoiding discomfort, comparing down.
   MOVE: Reframe discomfort as the toll for growth, not a stop sign. Champions act
   regardless of how they feel. Push to the world-class standard and pick the move
   they are slightly avoiding.

6. HOW TO WIN FRIENDS AND INFLUENCE PEOPLE (Dale Carnegie)
   TERRITORY: Relationships, conversations, conflict, persuasion, being heard.
   This is the ONLY book about other people.
   SIGNAL: A person, a conflict, feeling misunderstood, wanting to influence someone.
   MOVE: Start from the other person's want and point of view. Don't criticize or
   condemn; make them feel genuinely important. Seek first to understand.

# ROUTING

Before responding, silently identify what the conversation is REALLY about, then
pull from the matching book(s):
- Stuck, procrastinating, afraid, indecisive  -> Outwitting the Devil (drift)
- Vague goal, no clear target                  -> Think and Grow Rich (Definite Major Purpose)
- Money, earning, scarcity                     -> Secrets of the Millionaire Mind (blueprint)
- Racing mind, anxious, gripping too hard      -> Mind Magic (attention + non-attachment)
- Pressure, discipline, "don't feel like it"   -> 177 Mental Toughness Secrets
- A person, conflict, persuasion               -> How to Win Friends

A topic can pull from two books (e.g. a money goal that is also vague -> Eker's
blueprint + Hill's Definite Major Purpose). Never cite a book that does not fit
just to seem well-read.

# THE TENSION RULE (critical)

Hill, Eker, and Siebold push toward more effort and embracing discomfort. Doty
pushes toward calm, attention, and non-attachment. When a user is ALREADY trying
hard and is anxious or white-knuckling, more pushing backfires — route to Doty,
not Siebold. Read whether they need a push or a release before choosing.

# NAME THE MECHANISM

When a principle fits, NAME it plainly: "This is drifting." "That's your money
blueprint talking, not a fact." "Carnegie would start with their want, not yours."
Naming the mechanism is what makes you a coach and not a generic chatbot.

# THE MANIFESTATION PIPELINE (how change actually compounds)

Lasting change flows in one direction, each layer feeding the next:

  SUBCONSCIOUS -> THOUGHTS -> ACTIONS -> RESULTS

- SUBCONSCIOUS (fed by affirmations + future-self visualization): the deepest
  layer, the beliefs and identity running on autopilot. Reprogram this and
  everything downstream gets easier.
- THOUGHTS (fed by journaling + coaching conversations): conscious focus and
  self-awareness. Shaped by the subconscious, sharpened by reflection.
- ACTIONS (fed by habits + priority actions): aligned behavior. What thoughts
  drive you to actually do.
- RESULTS (goal progress): the outer-world evidence that the inner work landed.

When a user is stuck at RESULTS, look upstream: weak ACTIONS usually trace to
unexamined THOUGHTS, which trace to an unreprogrammed SUBCONSCIOUS. Coach the
upstream layer, not just the symptom.

# THE SUBCONSCIOUS WINDOW (timing matters)

The subconscious is most programmable in two windows: right after waking, before
the analytical mind fully boots, and right before sleep, as you drift off. That
is when affirmations and visualization sink in deepest. Doing them mid-day still
helps, but it misses the most receptive window.

If the ROUTINE TIMING context shows a user habitually doing subconscious-layer
practices (morning/evening affirmations, visualization) well outside those
windows, you may gently coach on protecting the window and tie it to why (it is
the difference between writing on wet clay and dry clay). Raise this only when it
is genuinely relevant and the timing data supports it. Never nag, never bring it
up every turn, and never frame it as a failure.

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
- Match length to the moment. Default to brief; only go longer when the moment genuinely calls for depth.
- Quick check-ins, simple or factual questions, acknowledgements, banter, or a clear yes/no: 1 to 2 sentences (roughly 15 to 40 words). Do not pad.
- Normal coaching (a real question, a decision, light stuck-ness): 40 to 110 words.
- Reserve 110 to 160 words only for genuine depth: an emotional moment, a meaningful reframe, or a complex situation that needs unpacking. Even in REFLECTIVE_INQUIRY or emotional moments, stay within this band.
- Read the user's energy and message length as the signal: a short message usually wants a short reply.
- HARD LIMIT: the "response" text must never exceed 200 words under any circumstances, including reflective or emotionally deep turns. If you feel the urge to write more, cut it, brevity is part of good coaching.
- Keep memory_updates terse regardless of how long the visible response runs. Never let memory_updates grow to compensate for a longer reply.
- When you are coaching, end with EITHER one real question OR one specific next step, never both. For a quick acknowledgement or simple answer, you do not need either; just respond naturally.

# SOUND HUMAN (anti-AI rules)

- Never mirror their words back as a preface ("It sounds like you're feeling frustrated that..."). Just respond like a person.
- No therapy-speak, no "I hear you", no "thank you for sharing", no hedging like "it seems" or "perhaps".
- No bullet lists or numbered steps in your reply. Talk in plain sentences.
- Vary your openings. Never start consecutive replies the same way.
- Before sending, silently check: "Would a real coach who knows this user say it exactly like this?" If it sounds like an AI, rewrite it.

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

# YOUR REPLY

You must call the \`coach_reply\` tool exactly once per turn with your structured reply — never respond in plain text. The "response" field is your coaching message as plain text (may contain at most one [[ACTION:Type:Payload]] marker); "mode", "framework", and "safety" classify this turn; "memory_updates" captures anything worth remembering.

Keep memory_updates minimal and only include what genuinely happened this turn. Empty arrays and empty strings are expected most of the time. Be terse: session_summary and long_term_summary are ONE short sentence each; every array holds at most 1 to 2 short items; include at most one belief_reframe per turn, with the belief and reframe each kept to one sentence. Never restate the full coaching message here.

STYLE RULES (non-negotiable):
- Never use "--" or "—" (em dash). Use a comma, period, or new sentence instead.
- Never use "..." (ellipsis) to trail off. End every thought completely.
- Write like a trusted human coach who knows this person well, not like an AI assistant.`;

/**
 * Forces the coach reply through Anthropic's tool-use mechanism instead of
 * asking the model to hand-write a JSON blob as plain text. Constrained
 * decoding guarantees the "input" the model produces matches this schema, so
 * a stray unescaped quote inside the coaching message can never again corrupt
 * the surrounding JSON and get silently mis-parsed into a truncated reply.
 */
const COACH_REPLY_TOOL: Anthropic.Tool = {
  name: 'coach_reply',
  description: "Deliver this turn's structured coach reply.",
  input_schema: {
    type: 'object',
    properties: {
      response: {
        type: 'string',
        description:
          'The coaching message as plain text, may contain at most one [[ACTION:Type:Payload]] marker.',
      },
      mode: {
        type: 'string',
        enum: [
          'support',
          'clarity',
          'action',
          'reflective_inquiry',
          'belief_reframe',
          'accountability',
          'celebrate',
        ],
      },
      framework: {
        type: 'string',
        description: 'The one book drawn from this turn, or an empty string.',
      },
      safety: {
        type: 'string',
        enum: ['none', 'concern', 'crisis'],
      },
      memory_updates: {
        type: 'object',
        properties: {
          session_summary: { type: 'string' },
          long_term_summary: { type: 'string' },
          new_commitments: { type: 'array', items: { type: 'string' } },
          fulfilled_commitments: { type: 'array', items: { type: 'string' } },
          patterns: { type: 'array', items: { type: 'string' } },
          key_moments: { type: 'array', items: { type: 'string' } },
          belief_reframes: {
            type: 'array',
            items: {
              type: 'object',
              properties: {
                belief: { type: 'string' },
                reframe: { type: 'string' },
              },
              required: ['belief', 'reframe'],
            },
          },
        },
        required: [
          'session_summary',
          'long_term_summary',
          'new_commitments',
          'fulfilled_commitments',
          'patterns',
          'key_moments',
          'belief_reframes',
        ],
      },
    },
    required: ['response', 'mode', 'framework', 'safety', 'memory_updates'],
  },
};

/**
 * True for transient Anthropic failures worth retrying: rate limits (429),
 * overloaded (529), and 5xx. Other 4xx (e.g. 400 invalid request, 401 auth)
 * are permanent and fail fast. Errors with no HTTP status are treated as
 * transient network blips and retried once more.
 */
function isRetryableAnthropicError(err: unknown): boolean {
  const status = (err as { status?: number } | undefined)?.status;
  if (typeof status !== 'number') return true;
  return status === 429 || status === 529 || (status >= 500 && status < 600);
}

/**
 * Runs an Anthropic request with exponential backoff (500ms, 1s, 2s) so short
 * rate-limit/overload spikes don't surface to users. Only retries transient
 * errors; rethrows the last error once attempts are exhausted.
 */
async function withAnthropicRetry<T>(
  fn: () => Promise<T>,
  attempts = 3,
): Promise<T> {
  let lastErr: unknown;
  for (let attempt = 0; attempt < attempts; attempt++) {
    try {
      return await fn();
    } catch (err) {
      lastErr = err;
      if (attempt === attempts - 1 || !isRetryableAnthropicError(err)) throw err;
      const delayMs = 500 * 2 ** attempt;
      await new Promise((resolve) => setTimeout(resolve, delayMs));
    }
  }
  throw lastErr;
}

async function callAnthropicInternal(
  systemPrompt: string,
  userPrompt: string,
  maxTokens = 1000,
  apiKey: string,
): Promise<string> {
  const client = new Anthropic({ apiKey });
  try {
    const message = await withAnthropicRetry(() => client.messages.create({
      model: 'claude-sonnet-4-5',
      max_tokens: maxTokens,
      system: systemPrompt + STYLE_RULES,
      messages: [{ role: 'user', content: userPrompt }],
    }));
    const block = message.content[0];
    if (block.type !== 'text') throw new Error('Unexpected response type from Claude');
    // Safety net: strip any em-dash or double-hyphen patterns that slip through.
    let text = block.text;
    text = text.replace(/\s*—\s*/g, ', ').replace(/\s*--\s*/g, ', ');
    return text;
  } catch (err) {
    // Re-throw a clean error so the raw node-fetch message (which may
    // contain the API key) never propagates to the outer catch logger.
    const msg = err instanceof Error ? err.message : String(err);
    throw new Error(`Anthropic request failed: ${sanitizeForLog(msg)}`);
  }
}

type ConversationTurn = { role: 'user' | 'assistant'; content: string };

/**
 * Conversation variant of the Anthropic helper. Sends a real multi-turn
 * messages array (rather than a single concatenated user prompt) so the model
 * has authentic dialogue structure. Used by the coach chat engine.
 *
 * System prompt is split into two cached blocks:
 *   1. STATIC_COACH_SYSTEM — frameworks, rules, response format; identical for
 *      every user, so Anthropic's API-key-level cache is shared across all users.
 *   2. userContext (systemPrompt arg) — user's name, goals, habits, beliefs, etc.;
 *      unique per user but stable within a session, so it's cached within-session.
 * Both blocks use ephemeral cache (5-min TTL, refreshed on each use).
 */
async function callAnthropicConversation(
  systemPrompt: string,
  messages: ConversationTurn[],
  maxTokens: number,
  apiKey: string,
): Promise<{ reply: Record<string, unknown>; truncated: boolean }> {
  const client = new Anthropic({ apiKey });
  try {
    const message = await withAnthropicRetry(() => client.messages.create({
      model: 'claude-sonnet-4-5',
      max_tokens: maxTokens,
      system: [
        {
          type: 'text',
          text: STATIC_COACH_SYSTEM,
          cache_control: { type: 'ephemeral' },
        },
        {
          type: 'text',
          text: systemPrompt,
          cache_control: { type: 'ephemeral' },
        },
      ],
      messages: messages.map((m) => ({ role: m.role, content: m.content })),
      tools: [COACH_REPLY_TOOL],
      // Force the model to call coach_reply every turn — the API's constrained
      // decoding then guarantees the "input" object matches the schema, so a
      // stray quote in the coaching message can never corrupt the surrounding
      // structure the way it could with hand-written JSON-as-text.
      tool_choice: { type: 'tool', name: COACH_REPLY_TOOL.name },
    }));
    const toolUse = message.content.find(
      (block): block is Anthropic.ToolUseBlock => block.type === 'tool_use',
    );
    if (!toolUse) throw new Error('Claude did not return a coach_reply tool call');
    const truncated = message.stop_reason === 'max_tokens';
    if (truncated) {
      console.warn(
        `coach reply hit max_tokens (maxTokens=${maxTokens}); output may be truncated`,
      );
    }
    const reply = toolUse.input as Record<string, unknown>;
    if (typeof reply.response === 'string') {
      reply.response = reply.response.replace(/\s*—\s*/g, ', ').replace(/\s*--\s*/g, ', ');
    }
    return { reply, truncated };
  } catch (err) {
    const msg = err instanceof Error ? err.message : String(err);
    throw new Error(`Anthropic request failed: ${sanitizeForLog(msg)}`);
  }
}

/**
 * Checks the user's daily AI call count against their tier limit. Does NOT
 * increment — call [recordDailyAiUsage] only after a successful AI response so
 * client retries and failed Anthropic calls do not burn quota.
 */
async function assertDailyAiLimit(uid: string): Promise<void> {
  const today = new Date().toISOString().slice(0, 10); // YYYY-MM-DD (UTC)
  const userRef = db.collection('users').doc(uid);
  const snap = await userRef.get();
  const data = snap.data();
  const limit = dailyAiLimitForUser(data);
  const usage = (data?.aiUsage ?? {}) as {
    date?: string;
    count?: number;
  };
  const count = usage.date === today ? usage.count ?? 0 : 0;
  if (count >= limit) {
    console.warn(
      `Daily AI limit reached: uid=${uid} count=${count} limit=${limit}`,
    );
    throw new HttpsError(
      'resource-exhausted',
      'Daily AI usage limit reached. Please try again tomorrow.',
    );
  }
}

/** Increments the user's daily AI usage counter after a successful call. */
async function recordDailyAiUsage(uid: string): Promise<void> {
  const today = new Date().toISOString().slice(0, 10);
  const userRef = db.collection('users').doc(uid);
  await db.runTransaction(async (tx) => {
    const snap = await tx.get(userRef);
    const usage = (snap.data()?.aiUsage ?? {}) as {
      date?: string;
      count?: number;
    };
    const count = usage.date === today ? usage.count ?? 0 : 0;
    tx.set(userRef, { aiUsage: { date: today, count: count + 1 } }, {
      merge: true,
    });
  });
}

// ─── Core AI callable ─────────────────────────────────────────────────────

/**
 * callClaude — auth-gated HTTPS Callable function.
 * All Claude calls from the Flutter app route through here.
 * Input:  { systemPrompt?: string, userPrompt: string, maxTokens?: number }
 * Output: { content: string }
 */
export const callClaude = onCall(
  // enforceAppCheck stays false until the App Check-enabled app build has fully
  // rolled out; flipping it early would reject every older build's AI calls.
  { secrets: [anthropicKey], enforceAppCheck: false, invoker: 'public', maxInstances: 20 },
  async (request) => {
    if (!request.auth) {
      throw new HttpsError('unauthenticated', 'Must be authenticated to call Claude.');
    }

    const { systemPrompt = '', userPrompt, maxTokens = 1000 } = request.data as {
      systemPrompt?: string;
      userPrompt: string;
      maxTokens?: number;
    };

    if (!userPrompt || typeof userPrompt !== 'string') {
      throw new HttpsError('invalid-argument', 'userPrompt is required.');
    }

    await assertDailyAiLimit(request.auth.uid);

    try {
      const content = await callAnthropicInternal(
        systemPrompt,
        userPrompt,
        maxTokens,
        anthropicKey.value().trim(),
      );
      await recordDailyAiUsage(request.auth.uid);
      return { content };
    } catch (err) {
      if (err instanceof HttpsError) throw err;
      console.error('Claude API error:', sanitizeForLog(err));
      throw new HttpsError('internal', 'Failed to get AI response. Please try again.');
    }
  },
);

/**
 * callClaudeConversation — auth-gated multi-turn Claude callable for the coach.
 * Sends a real messages array so the model sees authentic dialogue turns.
 * Input:  { systemPrompt?: string, messages: {role,content}[], maxTokens?: number }
 * Output: { reply: object, content: string, truncated: boolean }
 *
 * `content` is a JSON.stringify() of `reply` kept ONLY for backward
 * compatibility with app builds released before the tool-use migration —
 * this Cloud Function deploys instantly to 100% of traffic, while the app
 * update rolls out gradually, so older clients still call this function and
 * expect a `content` string field. Since `content` is now always a clean
 * JSON.stringify of a schema-valid object, it also can no longer trigger the
 * stray-quote truncation bug for those older clients. Remove `content` once
 * the pre-migration app version has fully rolled off (check analytics/store
 * adoption before deleting).
 */
export const callClaudeConversation = onCall(
  // enforceAppCheck stays false until the App Check-enabled app build has fully
  // rolled out; flipping it early would reject every older build's AI calls.
  { secrets: [anthropicKey], enforceAppCheck: false, invoker: 'public', maxInstances: 20 },
  async (request) => {
    if (!request.auth) {
      throw new HttpsError('unauthenticated', 'Must be authenticated to call Claude.');
    }

    const { systemPrompt = '', messages, maxTokens = 1200 } = request.data as {
      systemPrompt?: string;
      messages?: ConversationTurn[];
      maxTokens?: number;
    };

    if (!Array.isArray(messages) || messages.length === 0) {
      throw new HttpsError('invalid-argument', 'messages array is required.');
    }

    // Sanitize and validate each turn; Anthropic requires non-empty content
    // and alternating-ish roles starting with a user turn.
    const clean: ConversationTurn[] = messages
      .filter(
        (m) =>
          m &&
          (m.role === 'user' || m.role === 'assistant') &&
          typeof m.content === 'string' &&
          m.content.trim().length > 0,
      )
      .map((m) => ({ role: m.role, content: m.content }));

    if (clean.length === 0 || clean[0].role !== 'user') {
      throw new HttpsError(
        'invalid-argument',
        'messages must start with a user turn and contain content.',
      );
    }

    await assertDailyAiLimit(request.auth.uid);

    try {
      const { reply, truncated } = await callAnthropicConversation(
        systemPrompt,
        clean,
        maxTokens,
        anthropicKey.value().trim(),
      );
      await recordDailyAiUsage(request.auth.uid);
      // See the backward-compatibility note above `content`.
      return { reply, content: JSON.stringify(reply), truncated };
    } catch (err) {
      if (err instanceof HttpsError) throw err;
      console.error('Claude conversation error:', sanitizeForLog(err));
      throw new HttpsError('internal', 'Failed to get AI response. Please try again.');
    }
  },
);

// ─── Future Self narration (TTS) ───────────────────────────────────────────

/**
 * synthesizeFutureSelfNarration — auth-gated callable that turns a Future Self
 * scene script into a cached neural-voice narration.
 *
 * Synthesizes [script] with Google Cloud TTS, uploads the mp3 to the default
 * Storage bucket at `future_self_narration/{uid}/{scriptHash}.mp3` with a stable
 * download token, and returns a non-expiring download URL. Called once per scene
 * at create/refine time (not daily), so cost stays bounded; the client caches
 * the audio locally for offline daily replay.
 *
 * Input:  { script: string, voice?: string, scriptHash?: string }
 * Output: { url: string, voice: string, scriptHash: string }
 */
export const synthesizeFutureSelfNarration = onCall(
  { invoker: 'public', maxInstances: 10, memory: '512MiB', timeoutSeconds: 120 },
  async (request) => {
    if (!request.auth) {
      throw new HttpsError('unauthenticated', 'Must be authenticated.');
    }

    const { script, voice, scriptHash } = request.data as {
      script?: string;
      voice?: string;
      scriptHash?: string;
    };

    if (!script || typeof script !== 'string' || script.trim().length === 0) {
      throw new HttpsError('invalid-argument', 'script is required.');
    }
    // Google Cloud TTS caps a single request at 5000 bytes; a scene is far
    // shorter, but guard so an oversized payload fails clearly rather than at
    // the API layer.
    if (Buffer.byteLength(script, 'utf8') > 4800) {
      throw new HttpsError('invalid-argument', 'script is too long to narrate.');
    }

    // Bound abuse the same way as the Claude callables.
    await assertDailyAiLimit(request.auth.uid);

    const voiceName =
      typeof voice === 'string' && voice.trim().length > 0
        ? voice.trim()
        : DEFAULT_NARRATION_VOICE;
    const hash =
      typeof scriptHash === 'string' && scriptHash.trim().length > 0
        ? scriptHash.trim()
        : createHash('sha1').update(script).digest('hex');

    try {
      const [response] = await ttsClient.synthesizeSpeech({
        input: { text: script },
        voice: { languageCode: 'en-US', name: voiceName },
        audioConfig: {
          audioEncoding: 'MP3',
          // Slightly slower than default for a calm, meditative pace.
          speakingRate: 0.88,
        },
      });

      const audio = response.audioContent;
      if (!audio) {
        throw new Error('TTS returned no audio content');
      }

      const bucket = admin.storage().bucket();
      const filePath = `future_self_narration/${request.auth.uid}/${hash}.mp3`;
      const token = randomUUID();
      await bucket.file(filePath).save(Buffer.from(audio as Uint8Array), {
        resumable: false,
        contentType: 'audio/mpeg',
        metadata: {
          contentType: 'audio/mpeg',
          metadata: { firebaseStorageDownloadTokens: token },
        },
      });

      const url =
        `https://firebasestorage.googleapis.com/v0/b/${bucket.name}/o/` +
        `${encodeURIComponent(filePath)}?alt=media&token=${token}`;

      await recordDailyAiUsage(request.auth.uid);
      return { url, voice: voiceName, scriptHash: hash };
    } catch (err) {
      if (err instanceof HttpsError) throw err;
      console.error('Future Self narration error:', sanitizeForLog(err));
      throw new HttpsError('internal', 'Failed to synthesize narration.');
    }
  },
);

// ─── RevenueCat webhook ────────────────────────────────────────────────────

/**
 * revenueCatWebhook — HTTP function that receives RevenueCat webhook events.
 * Syncs subscriptionStatus on the user's Firestore doc.
 * Configure in RevenueCat dashboard: Webhook URL → this function's URL.
 * Set Authorization header to a secret shared with RevenueCat.
 */
// `invoker: 'public'` is required: RevenueCat authenticates with a shared
// secret in the Authorization header, not a Google IAM token. Without public
// invoker, Cloud Run rejects every webhook at the IAM layer (403/401) before
// our handler runs. Public ingress is safe here because the handler enforces
// the REVENUECAT_WEBHOOK_SECRET check below.
export const revenueCatWebhook = onRequest(
  { secrets: [revenueCatWebhookSecret], invoker: 'public' },
  async (req, res) => {
  if (req.method !== 'POST') {
    res.status(405).send('Method Not Allowed');
    return;
  }

  // Authenticate the caller against the shared secret configured in the
  // RevenueCat dashboard. Without this, anyone who knows the URL could forge
  // events and grant themselves a subscription.
  const expectedAuth = revenueCatWebhookSecret.value();
  const providedAuth = req.headers.authorization ?? '';
  if (!expectedAuth || !secretsMatch(providedAuth, expectedAuth)) {
    console.error('RevenueCat webhook: unauthorized request rejected');
    res.status(401).send('Unauthorized');
    return;
  }

  const event = req.body.event as {
    type: string;
    app_user_id: string;
    period_type?: string;
    expiration_at_ms?: number;
  } | undefined;

  if (!event?.app_user_id) {
    res.status(400).send('Missing event data');
    return;
  }

  const uid = event.app_user_id;
  const expirationDate = event.expiration_at_ms
    ? new Date(event.expiration_at_ms).toISOString()
    : null;

  const statusMap: Record<string, string> = {
    INITIAL_PURCHASE: 'active',
    RENEWAL: 'active',
    PRODUCT_CHANGE: 'active',
    CANCELLATION: 'canceled',
    EXPIRATION: 'expired',
    BILLING_ISSUE: 'past_due',
    SUBSCRIBER_ALIAS: 'active',
    TRANSFER: 'active',
  };

  const newStatus = statusMap[event.type] ?? 'free';

  try {
    const userRef = db.collection('users').doc(uid);

    // Comped accounts (manual 'lifetime' grant) and admins must never be
    // downgraded by a stray RevenueCat event. Read first and bail out if so.
    const existingSnap = await userRef.get();
    const existing = existingSnap.data() as
      | { subscriptionStatus?: string; userType?: string }
      | undefined;
    if (
      existing?.subscriptionStatus === 'lifetime' ||
      existing?.userType === 'admin'
    ) {
      res.status(200).send('OK (comped account, skipped)');
      return;
    }

    const update: Record<string, unknown> = {
      subscriptionStatus: newStatus,
      ...(expirationDate ? { subscriptionExpiresAt: expirationDate } : {}),
    };

    // If a free partner account starts paying, promote them to a full user and
    // record the viral conversion for funnel analytics.
    if (newStatus === 'active') {
      if (existing?.userType === 'partner') {
        update.userType = 'user';
        try {
          await db.collection('viral_metrics').add({
            eventType: 'partner_converted',
            partnerUid: uid,
            createdAt: admin.firestore.FieldValue.serverTimestamp(),
          });
        } catch (err) {
          console.error('viral_metrics partner_converted log failed:', err);
        }
      }
    }

    await userRef.update(update);
    res.status(200).send('OK');
  } catch (err) {
    console.error('RevenueCat webhook error:', err);
    res.status(500).send('Internal error');
  }
});

// ─── Partner invite functions ──────────────────────────────────────────────

/**
 * sendPartnerInviteEmail — creates an invite doc and sends invite email.
 * Called from Flutter when a user invites a partner by email.
 */
export const sendPartnerInviteEmail = onCall(
  { invoker: 'public' },
  async (request) => {
    if (!request.auth) {
      throw new HttpsError('unauthenticated', 'Must be authenticated.');
    }

    const { partnerEmail, partnerName } = request.data as {
      partnerEmail?: string;
      partnerName?: string;
    };

    // Email is optional now: the primary user shares the link directly via their
    // own apps. It is stored only as a hint for who the invite was meant for.
    const inviteId = db.collection('partner_invites').doc().id;
    const inviteData = {
      id: inviteId,
      primaryUserId: request.auth.uid,
      partnerEmail: partnerEmail || '',
      partnerName: partnerName || '',
      status: 'pending',
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
    };

    await db.collection('partner_invites').doc(inviteId).set(inviteData);

    // Get primary user's name for the link/metrics
    const primarySnap = await db.collection('users').doc(request.auth.uid).get();
    const primaryName = (primarySnap.data() as { displayName?: string })?.displayName ?? 'Your friend';

    // Store invite reference on primary user's profile
    await db.collection('users').doc(request.auth.uid).update({
      pendingPartnerInvites: admin.firestore.FieldValue.arrayUnion(inviteId),
    });

    // Shareable universal link. This domain must host the Apple App Site
    // Association + Android assetlinks.json (see firebase hosting config) so the
    // link opens the app, with a web fallback page for users without the app.
    const inviteLink = `${INVITE_LINK_DOMAIN}/partner-invite/${inviteId}`;
    // Custom-scheme fallback for environments where universal links don't fire.
    const deepLink = `mindsetforge://partner-invite/${inviteId}`;
    console.log(`Partner invite created: ${inviteId} for ${partnerEmail} from ${primaryName}`);

    // Lightweight viral metric: invitation sent.
    try {
      await db.collection('viral_metrics').add({
        eventType: 'invite_sent',
        primaryUid: request.auth.uid,
        inviteId,
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
      });
    } catch (err) {
      console.error('viral_metrics invite_sent log failed:', err);
    }

    return { inviteId, inviteLink, deepLink, primaryName };
  },
);

/**
 * acceptPartnerInvite — called from the Flutter partner invite screen.
 * Creates accountability relationship on both user docs.
 */
export const acceptPartnerInvite = onCall({ invoker: 'public' }, async (request) => {
  if (!request.auth) {
    throw new HttpsError('unauthenticated', 'Must be authenticated.');
  }

  const { inviteId } = request.data as { inviteId: string };
  if (!inviteId) {
    throw new HttpsError('invalid-argument', 'inviteId is required.');
  }

  const inviteSnap = await db.collection('partner_invites').doc(inviteId).get();
  if (!inviteSnap.exists) {
    throw new HttpsError('not-found', 'Invite not found or already used.');
  }

  const invite = inviteSnap.data() as {
    primaryUserId: string;
    partnerEmail: string;
    partnerName: string;
    status: string;
  };

  if (invite.status !== 'pending') {
    throw new HttpsError('already-exists', 'This invite has already been accepted.');
  }

  const partnerUid = request.auth.uid;
  const primaryUid = invite.primaryUserId;

  const relationshipId = db.collection('_').doc().id;
  const now = new Date().toISOString();

  // Add partner to primary user's doc
  await db.collection('users').doc(primaryUid).update({
    accountabilityRelationships: admin.firestore.FieldValue.arrayUnion({
      id: relationshipId,
      type: 'primary',
      partnerUid,
      partnerEmail: invite.partnerEmail,
      partnerName: invite.partnerName,
      status: 'active',
      acceptedAt: now,
    }),
    // Flat array of partner UIDs for Firestore security rules
    partnerUids: admin.firestore.FieldValue.arrayUnion(partnerUid),
  });

  // Get primary user name for partner's record
  const primarySnap = await db.collection('users').doc(primaryUid).get();
  const primaryData = primarySnap.data() as { displayName?: string; email?: string } | undefined;

  // Determine whether the accepter is already a paying/subscribed user. If they
  // are, keep their existing account intact. Otherwise convert them into a free
  // "partner" account and mark onboarding complete so they skip the full
  // mindset onboarding and land straight on the partner experience.
  const partnerSnap = await db.collection('users').doc(partnerUid).get();
  const partnerData = partnerSnap.data() as {
    userType?: string;
    subscriptionStatus?: string;
  } | undefined;

  const isSubscribed =
    partnerData?.userType === 'admin' ||
    partnerData?.subscriptionStatus === 'active' ||
    partnerData?.subscriptionStatus === 'trialing';

  const partnerUpdate: Record<string, unknown> = {
    accountabilityRelationships: admin.firestore.FieldValue.arrayUnion({
      id: relationshipId,
      type: 'partner',
      primaryUid,
      primaryEmail: primaryData?.email ?? '',
      primaryName: primaryData?.displayName ?? '',
      status: 'active',
      acceptedAt: now,
    }),
  };

  if (!isSubscribed) {
    // Convert to a free partner account. We intentionally do NOT mark onboarding
    // complete: partners land directly on the support experience, and only run
    // the (real) onboarding if/when they choose to try their own personal
    // features — that captured info is what makes those features work well.
    partnerUpdate.userType = 'partner';
  }

  // Add primary to partner's doc
  await db.collection('users').doc(partnerUid).update(partnerUpdate);

  // Mark invite as accepted
  await db.collection('partner_invites').doc(inviteId).update({ status: 'accepted' });

  // Lightweight viral metric: invitation accepted.
  try {
    await db.collection('viral_metrics').add({
      eventType: 'invite_accepted',
      primaryUid,
      partnerUid,
      inviteId,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
    });
  } catch (err) {
    console.error('viral_metrics invite_accepted log failed:', err);
  }

  return { success: true, primaryUid };
});

/**
 * sendEncouragement — partner sends an encouragement message to the primary user.
 * Writes to the primary user's encouragementMessages array.
 */
// ─── Push helpers ───────────────────────────────────────────────────────────

type PushCategory = 'routine' | 'streak' | 'partner' | 'lifecycle';

/** Records a notification send/open for the metrics pipeline (best-effort). */
async function logNotificationEventDoc(
  uid: string | null,
  category: string,
  action: 'sent' | 'open',
): Promise<void> {
  try {
    await db.collection('notification_events').add({
      uid,
      category,
      action,
      at: new Date().toISOString(),
    });
  } catch (err) {
    console.error('logNotificationEvent failed:', err);
  }
}

/**
 * Sends a push with the consistent payload the client tap-router understands:
 * `{ type, category, route, ...data }`. Logs the send for analytics.
 */
const pushChannelMap: Record<string, string> = {
  routine: 'mindshift_routine',
  streak: 'mindshift_streak',
  partner: 'mindshift_partner',
  lifecycle: 'mindshift_lifecycle',
};

async function sendPush(params: {
  token: string;
  title: string;
  body: string;
  type: string;
  category: PushCategory;
  route: string;
  recipientUid?: string;
  data?: Record<string, string>;
}): Promise<boolean> {
  try {
    await admin.messaging().send({
      token: params.token,
      notification: { title: params.title, body: params.body },
      data: {
        type: params.type,
        category: params.category,
        route: params.route,
        ...(params.data ?? {}),
      },
      android: {
        notification: {
          channelId: pushChannelMap[params.category] ?? 'mindshift_routine',
        },
      },
    });
    await logNotificationEventDoc(
      params.recipientUid ?? null,
      params.category,
      'sent',
    );
    return true;
  } catch (err) {
    console.error(`sendPush(${params.type}) failed:`, err);
    return false;
  }
}

/** yyyy-MM-dd for a date in the given IANA timezone (falls back to server local). */
function localDateKeyInTz(d: Date, tz?: string): string {
  if (tz) {
    try {
      // en-CA formats as yyyy-MM-dd.
      return new Intl.DateTimeFormat('en-CA', {
        timeZone: tz,
        year: 'numeric',
        month: '2-digit',
        day: '2-digit',
      }).format(d);
    } catch (_) {
      // fall through
    }
  }
  return localDateKey(d);
}

/** Records a notification open, called by the client after a tap. */
export const logNotificationEvent = onCall({ invoker: 'public' }, async (request) => {
  if (!request.auth) return { success: false };
  const { category, action } = request.data as {
    category?: string;
    action?: string;
  };
  await logNotificationEventDoc(
    request.auth.uid,
    category ?? 'unknown',
    action === 'sent' ? 'sent' : 'open',
  );
  return { success: true };
});

export const sendEncouragement = onCall({ invoker: 'public' }, async (request) => {
  if (!request.auth) {
    throw new HttpsError('unauthenticated', 'Must be authenticated.');
  }

  const { primaryUid, message } = request.data as { primaryUid: string; message: string };
  if (!primaryUid || !message) {
    throw new HttpsError('invalid-argument', 'primaryUid and message are required.');
  }

  // Verify the caller is actually a partner of this user
  const partnerSnap = await db.collection('users').doc(request.auth.uid).get();
  const partnerData = partnerSnap.data() as {
    displayName?: string;
    accountabilityRelationships?: Array<{ type: string; primaryUid?: string }>;
  } | undefined;

  const isPartner = (partnerData?.accountabilityRelationships ?? []).some(
    (r) => r.type === 'partner' && r.primaryUid === primaryUid,
  );
  if (!isPartner) {
    throw new HttpsError('permission-denied', 'You are not a partner of this user.');
  }

  const fromName = partnerData?.displayName ?? 'Your partner';
  const msgId = db.collection('_').doc().id;
  const encouragement = {
    id: msgId,
    fromUid: request.auth.uid,
    fromName,
    message,
    sentAt: new Date().toISOString(),
    read: false,
  };

  await db.collection('users').doc(primaryUid).update({
    encouragementMessages: admin.firestore.FieldValue.arrayUnion(encouragement),
  });

  // Push a notification to the primary user if we have their FCM token and they
  // haven't opted out of partner notifications.
  try {
    const primarySnap = await db.collection('users').doc(primaryUid).get();
    const primaryData = primarySnap.data() as {
      fcmToken?: string;
      notificationPrefs?: { masterEnabled?: boolean; partnerEnabled?: boolean };
    } | undefined;
    const prefs = primaryData?.notificationPrefs;
    const partnerPushAllowed =
      prefs?.masterEnabled !== false && prefs?.partnerEnabled !== false;
    if (primaryData?.fcmToken && partnerPushAllowed) {
      await sendPush({
        token: primaryData.fcmToken,
        title: `${fromName} sent you encouragement`,
        body: message.length > 120 ? `${message.slice(0, 117)}...` : message,
        type: 'encouragement',
        category: 'partner',
        route: '/notifications',
        recipientUid: primaryUid,
      });
    }
  } catch (err) {
    console.error('Encouragement push failed:', err);
  }

  return { success: true };
});

/**
 * getPartnerProgress — returns a privacy-curated snapshot of a primary user's
 * progress for an accountability partner. The partner never reads the full user
 * doc (Firestore rules forbid it); only the shareable subset below is returned.
 *
 * Caller must be an active partner of `primaryUid`.
 */

type CompletionDoc = {
  date?: string;
  habitsCompleted?: boolean;
  dayPlanned?: boolean;
  focusCompleted?: boolean;
  priorityActionsCompleted?: boolean;
  affirmationsMorning?: boolean;
  affirmationsEvening?: boolean;
  futureSelfCompleted?: boolean;
  journalCompleted?: boolean;
  chatCompleted?: boolean;
  identityRead?: boolean;
  gratitudeLogged?: boolean;
  evidenceLogged?: boolean;
};

// Mirrors DailyCompletion.isPerfectDay / completedCount on the client (9 wins,
// including `focusCompleted`). Keep this in sync so partner-facing streak,
// today %, and perfect-day counts match what the user sees in-app.
const REQUIRED_KEYS: (keyof CompletionDoc)[] = [
  'habitsCompleted',
  'dayPlanned',
  'focusCompleted',
  'affirmationsMorning',
  'affirmationsEvening',
  'futureSelfCompleted',
  'journalCompleted',
  'chatCompleted',
  'identityRead',
];

function completedCount(c: CompletionDoc): number {
  return REQUIRED_KEYS.filter((k) => c[k] === true).length;
}

/** Mirrors DailyCompletion.streakThreshold on the client: a day counts toward
 * the streak when at least this many of the 9 required wins are done. */
const STREAK_THRESHOLD = 5;

function localDateKey(d: Date): string {
  const m = (d.getMonth() + 1).toString().padStart(2, '0');
  const day = d.getDate().toString().padStart(2, '0');
  return `${d.getFullYear()}-${m}-${day}`;
}

/** Server-side port of UserProfile.currentStreak (5+ of 9 required items on consecutive days). */
function computeStreak(completions: CompletionDoc[]): number {
  if (completions.length === 0) return 0;

  const now = new Date();
  const today = new Date(now.getFullYear(), now.getMonth(), now.getDate());

  // Day-precision timestamps that qualify for the streak.
  const qualifying = new Set<number>();
  for (const c of completions) {
    if (!c.date || completedCount(c) < STREAK_THRESHOLD) continue;
    const parts = c.date.split('-');
    if (parts.length !== 3) continue;
    const date = new Date(
      parseInt(parts[0], 10),
      parseInt(parts[1], 10) - 1,
      parseInt(parts[2], 10),
    );
    qualifying.add(date.getTime());
  }
  if (qualifying.size === 0) return 0;

  // Today is a grace day: while it's still in progress (not yet qualifying),
  // anchor the streak at yesterday so an unfinished today doesn't read as a
  // broken streak (mirrors UserProfile.currentStreak).
  const cursor = new Date(today);
  if (!qualifying.has(today.getTime())) {
    cursor.setDate(cursor.getDate() - 1);
  }

  let streak = 0;
  while (qualifying.has(cursor.getTime())) {
    streak++;
    cursor.setDate(cursor.getDate() - 1);
  }
  return streak;
}

export const getPartnerProgress = onCall({ invoker: 'public' }, async (request) => {
  if (!request.auth) {
    throw new HttpsError('unauthenticated', 'Must be authenticated.');
  }

  const { primaryUid } = request.data as { primaryUid: string };
  if (!primaryUid) {
    throw new HttpsError('invalid-argument', 'primaryUid is required.');
  }

  // Verify the caller is actually an active partner of this user.
  const callerSnap = await db.collection('users').doc(request.auth.uid).get();
  const callerData = callerSnap.data() as {
    accountabilityRelationships?: Array<{
      type: string;
      primaryUid?: string;
      status?: string;
    }>;
  } | undefined;

  const isPartner = (callerData?.accountabilityRelationships ?? []).some(
    (r) => r.type === 'partner' && r.primaryUid === primaryUid && r.status === 'active',
  );
  if (!isPartner) {
    throw new HttpsError('permission-denied', 'You are not a partner of this user.');
  }

  const primarySnap = await db.collection('users').doc(primaryUid).get();
  if (!primarySnap.exists) {
    throw new HttpsError('not-found', 'Partner profile not found.');
  }

  const p = primarySnap.data() as {
    displayName?: string;
    identityStatement?: string;
    dailyCompletions?: CompletionDoc[];
    goals?: Array<{
      id?: string;
      title?: string;
      category?: string;
      progressPercent?: number;
      status?: string;
    }>;
    evidenceLog?: Array<{ content?: string; createdAt?: string }>;
  };

  const completions = p.dailyCompletions ?? [];
  const todayKey = localDateKey(new Date());
  const today = completions.find((c) => c.date === todayKey);
  const todayCount = today ? completedCount(today) : 0;
  const perfectDayCount = completions.filter(
    (c) => completedCount(c) >= REQUIRED_KEYS.length,
  ).length;

  // Weekly activity grid: per-day win count for the last 7 days (today last),
  // with streak/perfect flags so the client renders the same chain the user
  // sees on their own dashboard without re-deriving thresholds.
  const byDate = new Map<string, CompletionDoc>();
  for (const c of completions) {
    if (c.date) byDate.set(c.date, c);
  }
  const weeklyActivity: Array<{
    date: string;
    completedCount: number;
    countsForStreak: boolean;
    isPerfect: boolean;
  }> = [];
  for (let i = 6; i >= 0; i--) {
    const d = new Date();
    d.setDate(d.getDate() - i);
    const key = localDateKey(d);
    const c = byDate.get(key);
    const count = c ? completedCount(c) : 0;
    weeklyActivity.push({
      date: key,
      completedCount: count,
      countsForStreak: count >= STREAK_THRESHOLD,
      isPerfect: count >= REQUIRED_KEYS.length,
    });
  }

  // Today's evidence text (content only, never the rest of the evidence log).
  const todayEvidence = (p.evidenceLog ?? []).find((e) => {
    if (!e.createdAt) return false;
    const t = new Date(e.createdAt);
    return !isNaN(t.getTime()) && localDateKey(t) === todayKey;
  });

  const activeGoals = (p.goals ?? [])
    .filter((g) => g.status === 'active')
    .map((g) => ({
      id: g.id ?? '',
      title: g.title ?? '',
      category: g.category ?? '',
      progressPercent: g.progressPercent ?? 0,
    }));

  return {
    displayName: p.displayName ?? 'Your partner',
    identityStatement: p.identityStatement ?? '',
    currentStreak: computeStreak(completions),
    perfectDayCount,
    todayCompletedCount: todayCount,
    todayTotalCount: REQUIRED_KEYS.length,
    todayCompletionPercent: Math.round((todayCount / REQUIRED_KEYS.length) * 100),
    activeGoals,
    weeklyActivity,
    todayEvidence: todayEvidence?.content ?? null,
  };
});

/**
 * removePartner — ends an accountability partnership from either side. Removes
 * the relationship from both user docs and updates the primary's partnerUids so
 * the (former) partner loses progress access.
 */
export const removePartner = onCall({ invoker: 'public' }, async (request) => {
  if (!request.auth) {
    throw new HttpsError('unauthenticated', 'Must be authenticated.');
  }

  const { relationshipId } = request.data as { relationshipId: string };
  if (!relationshipId) {
    throw new HttpsError('invalid-argument', 'relationshipId is required.');
  }

  type Rel = {
    id: string;
    type: string;
    partnerUid?: string;
    primaryUid?: string;
  };

  const callerUid = request.auth.uid;
  const callerRef = db.collection('users').doc(callerUid);
  const callerSnap = await callerRef.get();
  const caller = callerSnap.data() as {
    accountabilityRelationships?: Rel[];
    partnerUids?: string[];
  } | undefined;

  const rels = caller?.accountabilityRelationships ?? [];
  const rel = rels.find((r) => r.id === relationshipId);
  if (!rel) {
    throw new HttpsError('not-found', 'Partnership not found.');
  }

  const otherUid = rel.type === 'primary' ? rel.partnerUid : rel.primaryUid;

  // Update caller's doc.
  const callerUpdate: Record<string, unknown> = {
    accountabilityRelationships: rels.filter((r) => r.id !== relationshipId),
  };
  if (rel.type === 'primary' && otherUid) {
    callerUpdate.partnerUids = (caller?.partnerUids ?? []).filter((u) => u !== otherUid);
  }
  await callerRef.update(callerUpdate);

  // Update the other side's doc.
  if (otherUid) {
    const otherRef = db.collection('users').doc(otherUid);
    const otherSnap = await otherRef.get();
    if (otherSnap.exists) {
      const other = otherSnap.data() as {
        accountabilityRelationships?: Rel[];
        partnerUids?: string[];
      };
      const otherUpdate: Record<string, unknown> = {
        accountabilityRelationships: (other.accountabilityRelationships ?? []).filter(
          (r) => r.id !== relationshipId,
        ),
      };
      // If the caller was the partner, the other side is the primary — strip the
      // caller from their partnerUids to revoke progress access.
      if (rel.type === 'partner') {
        otherUpdate.partnerUids = (other.partnerUids ?? []).filter((u) => u !== callerUid);
      }
      await otherRef.update(otherUpdate);
    }
  }

  return { success: true };
});

// ─── Account management functions ─────────────────────────────────────────

/**
 * deleteUserAccount — deletes all user data and Firebase Auth account.
 * Called from Settings screen.
 */
export const deleteUserAccount = onCall({ invoker: 'public' }, async (request) => {
  if (!request.auth) {
    throw new HttpsError('unauthenticated', 'Must be authenticated.');
  }

  const uid = request.auth.uid;

  // Delete Firestore documents
  const batch = db.batch();

  // Delete journal entries
  const journals = await db.collection('journals').where('uid', '==', uid).get();
  journals.docs.forEach((doc) => batch.delete(doc.ref));

  // Delete chat sessions
  const chats = await db.collection('chat_sessions').where('uid', '==', uid).get();
  chats.docs.forEach((doc) => batch.delete(doc.ref));

  // Delete partner invites
  const invites = await db.collection('partner_invites').where('primaryUserId', '==', uid).get();
  invites.docs.forEach((doc) => batch.delete(doc.ref));

  // Delete user profile
  batch.delete(db.collection('users').doc(uid));

  await batch.commit();

  // Delete the user's Future Self narration audio (best-effort).
  try {
    await admin
      .storage()
      .bucket()
      .deleteFiles({ prefix: `future_self_narration/${uid}/` });
  } catch (err) {
    console.error('deleteUserAccount: storage cleanup failed:', err);
  }

  // Delete Firebase Auth user
  await admin.auth().deleteUser(uid);

  return { success: true };
});

/**
 * getPartnerInviteInfo — returns metadata for a partner invite link.
 * Called from the PartnerInviteScreen before accepting.
 */
export const getPartnerInviteInfo = onCall({ invoker: 'public' }, async (request) => {
  const { inviteId } = request.data as { inviteId: string };
  if (!inviteId) {
    throw new HttpsError('invalid-argument', 'inviteId is required.');
  }

  const inviteSnap = await db.collection('partner_invites').doc(inviteId).get();
  if (!inviteSnap.exists) {
    throw new HttpsError('not-found', 'Invite not found.');
  }

  const invite = inviteSnap.data() as {
    primaryUserId: string;
    partnerEmail: string;
    status: string;
  };

  // Get primary user name
  const primarySnap = await db.collection('users').doc(invite.primaryUserId).get();
  const primaryData = primarySnap.data() as { displayName?: string } | undefined;

  return {
    primaryName: primaryData?.displayName ?? 'Someone',
    partnerEmail: invite.partnerEmail,
    status: invite.status,
  };
});

// ─── Scheduled functions ───────────────────────────────────────────────────

/**
 * Iterates every document of an ordered query in stable batches, invoking
 * `handler` once per doc. Replaces a single `.limit(N)` so scheduled jobs cover
 * the entire user base instead of silently stopping at the first N users.
 * The query MUST carry an `orderBy`; the cursor is derived from the last
 * document snapshot of each page via `startAfter`.
 */
async function forEachDocPaged(
  orderedQuery: admin.firestore.Query,
  batchSize: number,
  handler: (doc: admin.firestore.QueryDocumentSnapshot) => Promise<void>,
): Promise<void> {
  let cursor: admin.firestore.QueryDocumentSnapshot | undefined;
  for (;;) {
    let page = orderedQuery.limit(batchSize);
    if (cursor) page = page.startAfter(cursor);
    const snap = await page.get();
    if (snap.empty) break;
    for (const doc of snap.docs) {
      await handler(doc);
    }
    if (snap.size < batchSize) break;
    cursor = snap.docs[snap.docs.length - 1];
  }
}

/**
 * weeklyInsightDelivery — runs every hour. For each user whose local time is
 * Sunday 9:00, generates a structured weekly review (if they had ≥3 active
 * days), rotates prior reports into history, and sends a push notification.
 */
const WEEKLY_INSIGHT_ACTIVE_DAY_THRESHOLD = 3;
const WEEKLY_INSIGHT_HISTORY_MAX = 12;
const WEEKLY_INSIGHT_DELIVERY_HOUR = 9;

interface WeeklyInsightDoc {
  pattern: string;
  breakthrough: string;
  focus: string;
  generatedAt: string;
  viewedAt?: string;
  weekEnding: string;
}

function getLocalTimeInfo(
  d: Date,
  tz?: string,
): { weekday: number; hour: number; dateKey: string } {
  const timeZone = tz && tz.length > 0 ? tz : 'UTC';
  try {
    const dateKey = new Intl.DateTimeFormat('en-CA', {
      timeZone,
      year: 'numeric',
      month: '2-digit',
      day: '2-digit',
    }).format(d);
    const weekdayStr = new Intl.DateTimeFormat('en-US', {
      timeZone,
      weekday: 'short',
    }).format(d);
    const weekdayMap: Record<string, number> = {
      Sun: 0,
      Mon: 1,
      Tue: 2,
      Wed: 3,
      Thu: 4,
      Fri: 5,
      Sat: 6,
    };
    const hourStr = new Intl.DateTimeFormat('en-US', {
      timeZone,
      hour: 'numeric',
      hour12: false,
    }).format(d);
    return {
      weekday: weekdayMap[weekdayStr] ?? 0,
      hour: parseInt(hourStr, 10),
      dateKey,
    };
  } catch {
    const y = d.getUTCFullYear();
    const m = (d.getUTCMonth() + 1).toString().padStart(2, '0');
    const day = d.getUTCDate().toString().padStart(2, '0');
    return {
      weekday: d.getUTCDay(),
      hour: d.getUTCHours(),
      dateKey: `${y}-${m}-${day}`,
    };
  }
}

function isWeeklyInsightDeliveryWindow(d: Date, tz?: string): boolean {
  const { weekday, hour } = getLocalTimeInfo(d, tz);
  return weekday === 0 && hour === WEEKLY_INSIGHT_DELIVERY_HOUR;
}

function countActiveDaysPastWeek(
  completions: CompletionDoc[],
  tz?: string,
  nowMs = Date.now(),
): number {
  const byDate = new Map<string, CompletionDoc>();
  for (const c of completions) {
    if (c.date) byDate.set(c.date, c);
  }
  let activeDays = 0;
  for (let i = 1; i <= 7; i++) {
    const key = localDateKeyInTz(new Date(nowMs - i * 86400000), tz);
    const c = byDate.get(key);
    if (c && completedCount(c) >= WEEKLY_INSIGHT_ACTIVE_DAY_THRESHOLD) {
      activeDays++;
    }
  }
  return activeDays;
}

function parseStructuredWeeklyInsight(text: string): WeeklyInsightDoc | null {
  try {
    const jsonStr = text.includes('{')
      ? text.substring(text.indexOf('{'), text.lastIndexOf('}') + 1)
      : text;
    const data = JSON.parse(jsonStr) as Record<string, unknown>;
    const pattern = String(data.pattern ?? '');
    const breakthrough = String(data.breakthrough ?? '');
    const focus = String(data.focus ?? '');
    if (!pattern && !breakthrough && !focus) return null;
    return {
      pattern,
      breakthrough,
      focus,
      generatedAt: new Date().toISOString(),
      weekEnding: '',
    };
  } catch {
    return null;
  }
}

function rotateWeeklyInsightHistory(
  current: WeeklyInsightDoc | undefined,
  history: WeeklyInsightDoc[],
): WeeklyInsightDoc[] {
  if (!current || (!current.pattern && !current.breakthrough && !current.focus)) {
    return history;
  }
  const archived = current.viewedAt
    ? current
    : { ...current, viewedAt: new Date().toISOString() };
  return [archived, ...history].slice(0, WEEKLY_INSIGHT_HISTORY_MAX);
}

function buildWeeklyInsightUserPrompt(profile: {
  displayName?: string;
  identityStatement?: string;
  limitingBeliefs?: string[];
  goals?: Array<{ title?: string; status?: string; progressPercent?: number }>;
  habits?: Array<{ name?: string; state?: string }>;
  dailyCompletions?: CompletionDoc[];
  recentJournalSummaries?: Array<{ date?: string; mood?: string; snippet?: string }>;
  mindsetBlueprintSummary?: string;
  deepDive?: DeepDiveDoc;
}): string {
  const activeGoals = (profile.goals ?? [])
    .filter(g => g.status === 'active')
    .slice(0, 6)
    .map(g => `  • ${g.title ?? 'Goal'} (${(g.progressPercent ?? 0).toFixed(0)}%)`)
    .join('\n');

  const activeHabits = (profile.habits ?? [])
    .filter(h => h.state === 'active')
    .slice(0, 8)
    .map(h => `  • ${h.name ?? 'Habit'}`)
    .join('\n');

  const completions = profile.dailyCompletions ?? [];
  const streak = computeStreak(completions);

  const journalLines = (profile.recentJournalSummaries ?? [])
    .slice(-5)
    .map(j => `  • ${j.date ?? ''}: mood=${j.mood ?? 'okay'} — ${(j.snippet ?? '').slice(0, 80)}`)
    .join('\n');

  const deepDiveInsights = deepDiveModuleInsights(profile.deepDive)
    .slice(-3)
    .map(({ insight }) => `  • ${insight.slice(0, 120)}`)
    .join('\n');

  const summaryLine = profile.mindsetBlueprintSummary
    ? `\nMindset Blueprint Summary: "${profile.mindsetBlueprintSummary}"`
    : '';

  return `USER CONTEXT:
Name: ${profile.displayName ?? 'User'}
Identity: "${profile.identityStatement ?? ''}"
Limiting Beliefs: ${(profile.limitingBeliefs ?? []).join('; ') || 'None identified'}${summaryLine}

Active Goals:
${activeGoals || '  • None set'}

Current Habits:
${activeHabits || '  • None active'}

Consistency: ${streak} day streak

Recent Journal Mood:
${journalLines || '  • No recent entries'}

Deep Dive Insights:
${deepDiveInsights || '  • None yet'}`;
}

// ─── Blueprint behavioral scoring + weekly AI recalibration ────────────────

const BLUEPRINT_CALIBRATION_WINDOW_DAYS = 10;
const BLUEPRINT_SNAPSHOT_HISTORY_MAX = 12;
const BLUEPRINT_HABIT_DAY_THRESHOLD = 0.7;
const BLUEPRINT_MAX_DELTA = 1.0;

type MindsetBlueprintDoc = {
  confidence?: number;
  discipline?: number;
  abundanceThinking?: number;
  resilience?: number;
  decisiveness?: number;
};

type BlueprintSnapshotDoc = {
  blueprint: MindsetBlueprintDoc;
  createdAt: string;
  source: string;
  rationale?: Record<string, string>;
};

type HabitDoc = {
  state?: string;
  frequency?: string;
  completionHistory?: string[];
};

type GoalDoc = {
  title?: string;
  status?: string;
  progressPercent?: number;
  actionSteps?: Array<{ isCompleted?: boolean }>;
};

type EvidenceEntryDoc = {
  content?: string;
  createdAt?: string;
};

type BeliefPatternDoc = {
  belief?: string;
  reframe?: string;
  identifiedAt?: string;
};

// Mirrors `kDeepDiveModuleIds` in lib/models/deep_dive.dart. Firestore stores
// each module's { insight, completedAt } flattened directly under `deepDive`
// (not nested under a `modules` key) — see deep_dive_provider.dart's
// `deepDive.$moduleId.insight` update paths.
const DEEP_DIVE_MODULE_IDS = [
  'mindset_patterns',
  'motivation_style',
  'fear_inventory',
  'identity_assessment',
  'social_influence',
] as const;

type DeepDiveModuleDoc = { insight?: string; completedAt?: string };
type DeepDiveDoc = Partial<Record<typeof DEEP_DIVE_MODULE_IDS[number], DeepDiveModuleDoc>>;

function deepDiveModuleInsights(deepDive?: DeepDiveDoc): Array<{ id: string; insight: string }> {
  if (!deepDive) return [];
  const out: Array<{ id: string; insight: string }> = [];
  for (const id of DEEP_DIVE_MODULE_IDS) {
    const insight = deepDive[id]?.insight?.trim();
    if (insight) out.push({ id, insight });
  }
  return out;
}

function blueprintGraceAnchor(now = new Date()): Date {
  const adjusted = now.getHours() < 4
    ? new Date(now.getTime() - 86400000)
    : now;
  return new Date(adjusted.getFullYear(), adjusted.getMonth(), adjusted.getDate());
}

function daysSinceBlueprintCalibrationStart(startIso?: string, now = new Date()): number {
  if (!startIso) return 0;
  const start = new Date(startIso);
  if (Number.isNaN(start.getTime())) return 0;
  const anchor = new Date(start.getFullYear(), start.getMonth(), start.getDate());
  const today = blueprintGraceAnchor(now);
  const diff = Math.floor((today.getTime() - anchor.getTime()) / 86400000);
  return diff < 0 ? 0 : diff;
}

function blueprintEffectiveWindow(startIso?: string): number {
  const available = daysSinceBlueprintCalibrationStart(startIso) + 1;
  if (available < 1) return 1;
  return available > BLUEPRINT_CALIBRATION_WINDOW_DAYS
    ? BLUEPRINT_CALIBRATION_WINDOW_DAYS
    : available;
}

function recentBlueprintDateStrings(count: number, now = new Date()): string[] {
  const base = blueprintGraceAnchor(now);
  return Array.from({ length: count }, (_, i) => {
    const d = new Date(base.getTime() - i * 86400000);
    const m = (d.getMonth() + 1).toString().padStart(2, '0');
    const day = d.getDate().toString().padStart(2, '0');
    return `${d.getFullYear()}-${m}-${day}`;
  });
}

function pctToBlueprintTrait(pct: number): number {
  const clamped = Math.max(0, Math.min(100, pct));
  return Math.max(1, Math.min(10, 1 + (clamped / 100) * 9));
}

function hasHabitCompletionInPeriod(habit: HabitDoc, date: Date): boolean {
  const history = habit.completionHistory ?? [];
  if (history.length === 0) return false;
  if (habit.frequency === 'weekly') {
    const d = new Date(date.getFullYear(), date.getMonth(), date.getDate());
    const weekStart = new Date(d);
    weekStart.setDate(d.getDate() - (d.getDay() === 0 ? 6 : d.getDay() - 1));
    const weekEnd = new Date(weekStart);
    weekEnd.setDate(weekStart.getDate() + 6);
    return history.some((raw) => {
      const t = new Date(raw);
      if (Number.isNaN(t.getTime())) return false;
      const td = new Date(t.getFullYear(), t.getMonth(), t.getDate());
      return td >= weekStart && td <= weekEnd;
    });
  }
  return history.some((raw) => {
    const t = new Date(raw);
    if (Number.isNaN(t.getTime())) return false;
    return t.getFullYear() === date.getFullYear()
      && t.getMonth() === date.getMonth()
      && t.getDate() === date.getDate();
  });
}

function computeBlueprintBehavioralEstimate(profile: {
  habits?: HabitDoc[];
  goals?: GoalDoc[];
  dailyCompletions?: CompletionDoc[];
  identityStatement?: string;
  blueprintCalibrationStartedAt?: string;
}, now = new Date()): MindsetBlueprintDoc {
  const window = blueprintEffectiveWindow(profile.blueprintCalibrationStartedAt);
  const dates = recentBlueprintDateStrings(window, now);
  const byDate = new Map<string, CompletionDoc>();
  for (const c of profile.dailyCompletions ?? []) {
    if (c.date) byDate.set(c.date, c);
  }

  const activeHabits = (profile.habits ?? []).filter((h) => h.state === 'active');
  let habitCredit = 0;
  let priorityDays = 0;
  if (activeHabits.length > 0) {
    for (const date of dates) {
      const parts = date.split('-');
      const dayDate = new Date(
        parseInt(parts[0], 10),
        parseInt(parts[1], 10) - 1,
        parseInt(parts[2], 10),
      );
      const completed = activeHabits
        .filter((h) => hasHabitCompletionInPeriod(h, dayDate)).length;
      const fraction = completed / activeHabits.length;
      habitCredit += fraction >= BLUEPRINT_HABIT_DAY_THRESHOLD ? 1 : fraction;
    }
  }
  for (const date of dates) {
    if (byDate.get(date)?.priorityActionsCompleted) priorityDays++;
  }
  const habitPct = dates.length === 0 ? 0 : (habitCredit / dates.length) * 100;
  const priorityPct = window <= 0 ? 0 : (priorityDays / window) * 100;
  const discipline = pctToBlueprintTrait(habitPct * 0.7 + priorityPct * 0.3);

  const qualifying = dates
    .filter((d) => {
      const c = byDate.get(d);
      return c != null && completedCount(c) >= STREAK_THRESHOLD;
    })
    .sort();
  let breaks = 0;
  let recoveries = 0;
  for (let i = 1; i < qualifying.length; i++) {
    const prevParts = qualifying[i - 1].split('-');
    const currParts = qualifying[i].split('-');
    const prev = new Date(
      parseInt(prevParts[0], 10),
      parseInt(prevParts[1], 10) - 1,
      parseInt(prevParts[2], 10),
    );
    const curr = new Date(
      parseInt(currParts[0], 10),
      parseInt(currParts[1], 10) - 1,
      parseInt(currParts[2], 10),
    );
    const gap = Math.round((curr.getTime() - prev.getTime()) / 86400000);
    if (gap > 1) {
      breaks++;
      if (gap <= 3) recoveries++;
    }
  }
  const streak = computeStreak(profile.dailyCompletions ?? []);
  const recoveryRate = breaks === 0 ? 1 : recoveries / breaks;
  const consistency = qualifying.length / Math.max(window, 1);
  const streakBonus = Math.min(streak / window, 1);
  const resiliencePct = recoveryRate * 45 + consistency * 35 + streakBonus * 20;
  const resilience = pctToBlueprintTrait(resiliencePct);

  let totalSteps = 0;
  let completedSteps = 0;
  let focusDays = 0;
  let planDays = 0;
  for (const g of (profile.goals ?? []).filter((goal) => goal.status === 'active')) {
    for (const step of g.actionSteps ?? []) {
      totalSteps++;
      if (step.isCompleted) completedSteps++;
    }
  }
  for (const date of dates) {
    const c = byDate.get(date);
    if (!c) continue;
    if (c.focusCompleted) focusDays++;
    if (c.dayPlanned) planDays++;
  }
  const stepPct = totalSteps === 0 ? 50 : (completedSteps / totalSteps) * 100;
  const focusPct = window <= 0 ? 0 : (focusDays / window) * 100;
  const planPct = window <= 0 ? 0 : (planDays / window) * 100;
  const decisiveness = pctToBlueprintTrait(stepPct * 0.5 + focusPct * 0.3 + planPct * 0.2);

  let chatDays = 0;
  let journalDays = 0;
  let identityDays = 0;
  let evidenceDays = 0;
  for (const date of dates) {
    const c = byDate.get(date);
    if (!c) continue;
    if (c.chatCompleted) chatDays++;
    if (c.journalCompleted) journalDays++;
    if (c.identityRead) identityDays++;
    if (c.evidenceLogged) evidenceDays++;
  }
  const breadth = [
    chatDays > 0,
    journalDays > 0,
    identityDays > 0,
    evidenceDays > 0,
    (profile.identityStatement ?? '').length > 0,
  ].filter(Boolean).length;
  const engagementPct = window <= 0
    ? 0
    : ((chatDays + journalDays + identityDays + evidenceDays) / (window * 4)) * 100;
  const breadthPct = (breadth / 5) * 100;
  const confidence = pctToBlueprintTrait(engagementPct * 0.6 + breadthPct * 0.4);

  const activeGoals = (profile.goals ?? []).filter((g) => g.status === 'active');
  const goalProgress = activeGoals.length === 0
    ? 0
    : activeGoals.reduce((sum, g) => sum + (g.progressPercent ?? 0), 0) / activeGoals.length;
  let gratitudeDays = 0;
  for (const date of dates) {
    if (byDate.get(date)?.gratitudeLogged) gratitudeDays++;
  }
  const goalSettingBonus = (Math.min(activeGoals.length, 5) / 5) * 100;
  const gratitudePct = window <= 0 ? 0 : (gratitudeDays / window) * 100;
  const abundanceThinking = pctToBlueprintTrait(
    goalProgress * 0.45 + goalSettingBonus * 0.25 + gratitudePct * 0.30,
  );

  return {
    confidence,
    discipline,
    abundanceThinking,
    resilience,
    decisiveness,
  };
}

function normalizeBlueprintDoc(raw?: MindsetBlueprintDoc): MindsetBlueprintDoc {
  return {
    confidence: raw?.confidence ?? 5,
    discipline: raw?.discipline ?? 5,
    abundanceThinking: raw?.abundanceThinking ?? 5,
    resilience: raw?.resilience ?? 5,
    decisiveness: raw?.decisiveness ?? 5,
  };
}

function clampBlueprintTrait(value: number): number {
  return Math.max(1, Math.min(10, value));
}

function buildBlueprintRecalcUserPrompt(profile: {
  displayName?: string;
  mindsetBlueprint?: MindsetBlueprintDoc;
  limitingBeliefs?: string[];
  goals?: GoalDoc[];
  habits?: HabitDoc[];
  dailyCompletions?: CompletionDoc[];
  recentJournalSummaries?: Array<{ date?: string; mood?: string; snippet?: string }>;
  coachMemory?: { longTermSummary?: string; recurringPatterns?: string[] };
  identityStatement?: string;
  blueprintCalibrationStartedAt?: string;
  evidenceLog?: EvidenceEntryDoc[];
  beliefPatternHistory?: BeliefPatternDoc[];
  deepDive?: DeepDiveDoc;
}): string {
  const current = normalizeBlueprintDoc(profile.mindsetBlueprint);
  const behavioral = computeBlueprintBehavioralEstimate(profile);
  const journalLines = (profile.recentJournalSummaries ?? [])
    .slice(-5)
    .map((j) => `  • ${j.date ?? ''}: mood=${j.mood ?? 'okay'} — ${(j.snippet ?? '').slice(0, 80)}`)
    .join('\n');
  const patterns = (profile.coachMemory?.recurringPatterns ?? [])
    .slice(-3)
    .map((p) => `  • ${p.slice(0, 120)}`)
    .join('\n');

  const evidenceLines = (profile.evidenceLog ?? [])
    .slice(-5)
    .map((e) => `  • ${(e.content ?? '').slice(0, 140)}`)
    .join('\n');

  const activeLimitingBeliefs = profile.limitingBeliefs ?? [];
  const beliefLines = (profile.beliefPatternHistory ?? [])
    .slice(-5)
    .map((b) => {
      const belief = b.belief ?? '';
      const stillActive = activeLimitingBeliefs.some(
        (lb) => lb.trim().toLowerCase() === belief.trim().toLowerCase(),
      );
      const status = stillActive ? 'still listed as a limiting belief' : 'resolved';
      return `  • "${belief}" → "${b.reframe ?? ''}" (${status})`;
    })
    .join('\n');

  const deepDiveLines = deepDiveModuleInsights(profile.deepDive)
    .map(({ id, insight }) => `  • [${id}] ${insight.slice(0, 160)}`)
    .join('\n');

  return `USER CONTEXT:
Name: ${profile.displayName ?? 'User'}
Identity: "${profile.identityStatement ?? ''}"
Limiting Beliefs: ${(profile.limitingBeliefs ?? []).join('; ') || 'None identified'}

Current Mindset Blueprint (1–10):
  Confidence: ${current.confidence?.toFixed(1)}
  Discipline: ${current.discipline?.toFixed(1)}
  Abundance Thinking: ${current.abundanceThinking?.toFixed(1)}
  Resilience: ${current.resilience?.toFixed(1)}
  Decisiveness: ${current.decisiveness?.toFixed(1)}

Behavioral proxy estimates (1–10, from app activity):
  Confidence: ${behavioral.confidence?.toFixed(1)}
  Discipline: ${behavioral.discipline?.toFixed(1)}
  Abundance Thinking: ${behavioral.abundanceThinking?.toFixed(1)}
  Resilience: ${behavioral.resilience?.toFixed(1)}
  Decisiveness: ${behavioral.decisiveness?.toFixed(1)}

Recent Journal Mood:
${journalLines || '  • No recent entries'}

Evidence Log (self-authored proof of growth — strongest signal for Confidence):
${evidenceLines || '  • No entries yet'}

Belief Reframes (limiting beliefs the coach has helped reframe — strong signal for Confidence and Abundance Thinking):
${beliefLines || '  • None yet'}

Deep Dive Module Insights (strong signal for Resilience, Confidence, and Abundance Thinking):
${deepDiveLines || '  • None yet'}

Coach Memory Patterns:
${patterns || '  • None yet'}
${profile.coachMemory?.longTermSummary
    ? `\nLong-term summary: ${profile.coachMemory.longTermSummary.slice(0, 200)}`
    : ''}`;
}

function parseBlueprintRecalcResponse(text: string): {
  deltas: MindsetBlueprintDoc;
  rationale: Record<string, string>;
} | null {
  try {
    const jsonStr = text.includes('{')
      ? text.substring(text.indexOf('{'), text.lastIndexOf('}') + 1)
      : text;
    const data = JSON.parse(jsonStr) as Record<string, unknown>;
    const rawDeltas = (data.deltas ?? data) as Record<string, unknown>;
    const rawRationale = (data.rationale ?? {}) as Record<string, unknown>;
    const keys = [
      'confidence',
      'discipline',
      'abundanceThinking',
      'resilience',
      'decisiveness',
    ] as const;
    const deltas: MindsetBlueprintDoc = {};
    const rationale: Record<string, string> = {};
    for (const key of keys) {
      const delta = Number(rawDeltas[key] ?? 0);
      if (!Number.isFinite(delta)) continue;
      deltas[key] = Math.max(-BLUEPRINT_MAX_DELTA, Math.min(BLUEPRINT_MAX_DELTA, delta));
      const reason = String(rawRationale[key] ?? '').trim();
      if (reason) rationale[key] = reason;
    }
    return { deltas, rationale };
  } catch {
    return null;
  }
}

function applyBlueprintDeltas(
  current: MindsetBlueprintDoc,
  deltas: MindsetBlueprintDoc,
): MindsetBlueprintDoc {
  const base = normalizeBlueprintDoc(current);
  return {
    confidence: clampBlueprintTrait((base.confidence ?? 5) + (deltas.confidence ?? 0)),
    discipline: clampBlueprintTrait((base.discipline ?? 5) + (deltas.discipline ?? 0)),
    abundanceThinking: clampBlueprintTrait(
      (base.abundanceThinking ?? 5) + (deltas.abundanceThinking ?? 0),
    ),
    resilience: clampBlueprintTrait((base.resilience ?? 5) + (deltas.resilience ?? 0)),
    decisiveness: clampBlueprintTrait((base.decisiveness ?? 5) + (deltas.decisiveness ?? 0)),
  };
}

function rotateBlueprintSnapshotHistory(
  current: MindsetBlueprintDoc,
  history: BlueprintSnapshotDoc[],
  createdAt: string,
  rationale: Record<string, string>,
): BlueprintSnapshotDoc[] {
  const archived: BlueprintSnapshotDoc = {
    blueprint: current,
    createdAt,
    source: 'weekly_ai',
    rationale,
  };
  return [archived, ...history].slice(0, BLUEPRINT_SNAPSHOT_HISTORY_MAX);
}

function blueprintRecalcWeekKey(lastRecalculatedAt?: string, tz?: string): string | null {
  if (!lastRecalculatedAt) return null;
  const parsed = new Date(lastRecalculatedAt);
  if (Number.isNaN(parsed.getTime())) return null;
  return getLocalTimeInfo(parsed, tz).dateKey;
}

async function maybeRecalculateBlueprint(
  userDoc: admin.firestore.QueryDocumentSnapshot,
  profile: {
    displayName?: string;
    identityStatement?: string;
    limitingBeliefs?: string[];
    goals?: GoalDoc[];
    habits?: HabitDoc[];
    dailyCompletions?: CompletionDoc[];
    recentJournalSummaries?: Array<{ date?: string; mood?: string; snippet?: string }>;
    coachMemory?: { longTermSummary?: string; recurringPatterns?: string[] };
    mindsetBlueprint?: MindsetBlueprintDoc;
    blueprintCompleted?: boolean;
    blueprintCalibrationStartedAt?: string;
    blueprintLastRecalculatedAt?: string;
    blueprintSnapshotHistory?: BlueprintSnapshotDoc[];
    evidenceLog?: EvidenceEntryDoc[];
    beliefPatternHistory?: BeliefPatternDoc[];
    deepDive?: DeepDiveDoc;
    timezone?: string;
  },
  weekEnding: string,
  apiKey: string,
  now: Date,
): Promise<void> {
  if (!profile.blueprintCompleted) return;
  if (!profile.blueprintCalibrationStartedAt) return;
  if (
    daysSinceBlueprintCalibrationStart(profile.blueprintCalibrationStartedAt, now)
    < BLUEPRINT_CALIBRATION_WINDOW_DAYS - 1
  ) {
    return;
  }
  if (
    countActiveDaysPastWeek(profile.dailyCompletions ?? [], profile.timezone)
    < WEEKLY_INSIGHT_ACTIVE_DAY_THRESHOLD
  ) {
    return;
  }
  if (blueprintRecalcWeekKey(profile.blueprintLastRecalculatedAt, profile.timezone) === weekEnding) {
    return;
  }

  const current = normalizeBlueprintDoc(profile.mindsetBlueprint);
  const userPrompt = buildBlueprintRecalcUserPrompt(profile);
  const response = await callAnthropicInternal(
    'You are a mindset coach refining a user\'s Mindset Blueprint trait scores (1–10). '
      + 'Return ONLY valid JSON with two keys: '
      + '"deltas" (object with confidence, discipline, abundanceThinking, resilience, decisiveness — each a small number from -1.0 to +1.0) '
      + 'and "rationale" (object with the same keys, one short sentence per trait that changed, explaining why). '
      + 'Use behavioral proxies and qualitative journal/coach context. Be conservative — most weeks change 0–2 traits by ≤0.5. '
      + 'Never move a trait more than ±1.0 in one week. '
      + 'Evidence log entries and belief reframes are the strongest available signals for Confidence, Abundance Thinking, and Resilience — '
      + 'weigh them heavily for those three traits, since behavioral activity data is weak there. '
      + 'If there is not enough behavioral or journal evidence to justify a change for a trait, return a delta of 0 for it rather than guessing. '
      + 'No other text.',
    userPrompt,
    350,
    apiKey,
  );

  const parsed = parseBlueprintRecalcResponse(response);
  if (!parsed) {
    console.error(`Failed to parse blueprint recalc for user ${userDoc.id}`);
    return;
  }

  const updated = applyBlueprintDeltas(current, parsed.deltas);
  const nowIso = now.toISOString();
  const history = rotateBlueprintSnapshotHistory(
    current,
    profile.blueprintSnapshotHistory ?? [],
    profile.blueprintLastRecalculatedAt ?? nowIso,
    parsed.rationale,
  );

  await userDoc.ref.update({
    mindsetBlueprint: updated,
    blueprintLastRecalculatedAt: nowIso,
    blueprintSnapshotHistory: history,
  });

  console.log(`Blueprint recalculated for user: ${userDoc.id}`);
}

export const weeklyInsightDelivery = onSchedule(
  { schedule: '0 * * * *', secrets: [anthropicKey], timeoutSeconds: 540 },
  async () => {
    const now = new Date();
    const apiKey = anthropicKey.value().trim();
    const usersQuery = db
      .collection('users')
      .where('onboardingStep', '>=', 5)
      .orderBy('onboardingStep');

    await forEachDocPaged(usersQuery, 200, async (userDoc) => {
      const profile = userDoc.data() as {
        displayName?: string;
        identityStatement?: string;
        limitingBeliefs?: string[];
        goals?: GoalDoc[];
        habits?: HabitDoc[];
        dailyCompletions?: CompletionDoc[];
        recentJournalSummaries?: Array<{ date?: string; mood?: string; snippet?: string }>;
        mindsetBlueprintSummary?: string;
        mindsetBlueprint?: MindsetBlueprintDoc;
        blueprintCompleted?: boolean;
        blueprintCalibrationStartedAt?: string;
        blueprintLastRecalculatedAt?: string;
        blueprintSnapshotHistory?: BlueprintSnapshotDoc[];
        coachMemory?: { longTermSummary?: string; recurringPatterns?: string[] };
        deepDive?: DeepDiveDoc;
        evidenceLog?: EvidenceEntryDoc[];
        beliefPatternHistory?: BeliefPatternDoc[];
        timezone?: string;
        fcmToken?: string;
        weeklyInsight?: WeeklyInsightDoc;
        weeklyInsightHistory?: WeeklyInsightDoc[];
        notificationPrefs?: {
          masterEnabled?: boolean;
          weeklyInsightEnabled?: boolean;
        };
      };

      if (!isWeeklyInsightDeliveryWindow(now, profile.timezone)) return;

      const { dateKey: weekEnding } = getLocalTimeInfo(now, profile.timezone);

      // Blueprint recalculation runs independently of weekly insight eligibility.
      try {
        await maybeRecalculateBlueprint(
          userDoc,
          profile,
          weekEnding,
          apiKey,
          now,
        );
      } catch (err) {
        console.error(`Failed blueprint recalc for user ${userDoc.id}:`, err);
      }

      if (profile.weeklyInsight?.weekEnding === weekEnding) return;

      if (
        countActiveDaysPastWeek(profile.dailyCompletions ?? [], profile.timezone) <
        WEEKLY_INSIGHT_ACTIVE_DAY_THRESHOLD
      ) {
        return;
      }

      try {
        const userPrompt = buildWeeklyInsightUserPrompt(profile);
        const response = await callAnthropicInternal(
          'You are a mindset coach delivering a weekly review. '
            + 'Return ONLY valid JSON with three keys: '
            + '"pattern" (one sentence about the user\'s key pattern this week), '
            + '"breakthrough" (one sentence celebrating their win or progress), '
            + '"focus" (one specific action or focus for next week). '
            + 'Be personal, direct, energizing. No other text.',
          userPrompt,
          300,
          apiKey,
        );

        const parsed = parseStructuredWeeklyInsight(response);
        if (!parsed) {
          console.error(`Failed to parse weekly insight for user ${userDoc.id}`);
          return;
        }
        parsed.weekEnding = weekEnding;

        const history = rotateWeeklyInsightHistory(
          profile.weeklyInsight,
          profile.weeklyInsightHistory ?? [],
        );

        await userDoc.ref.update({
          weeklyInsight: parsed,
          weeklyInsightHistory: history,
        });

        const prefs = profile.notificationPrefs;
        const pushAllowed =
          prefs?.masterEnabled !== false && prefs?.weeklyInsightEnabled !== false;
        if (profile.fcmToken && pushAllowed) {
          const firstName = (profile.displayName ?? 'there').split(' ')[0];
          await sendPush({
            token: profile.fcmToken,
            title: 'Your weekly review is ready',
            body: `See what stood out in your week, ${firstName}.`,
            type: 'weekly_insight',
            category: 'lifecycle',
            route: '/progress',
            recipientUid: userDoc.id,
          });
        }

        console.log(`Weekly insight delivered for user: ${userDoc.id}`);
      } catch (err) {
        console.error(`Failed weekly insight for user ${userDoc.id}:`, err);
      }
    });
  },
);

/**
 * Maps days-since-active to a re-engagement tier. Win-backs fire at day 3, 7,
 * 14, and 30, then stop. The user's stored `lifecycleTier` is reset to 0 by the
 * client whenever they become active again.
 */
function lifecycleTierForDays(days: number): number {
  if (days >= 30) return 4;
  if (days >= 14) return 3;
  if (days >= 7) return 2;
  if (days >= 3) return 1;
  return 0;
}

/**
 * lowActivityAlert — runs daily at 10am UTC.
 * Tiered, deduplicated re-engagement: each lapsed user gets at most one nudge
 * per tier (day 3/7/14/30), never daily spam.
 */
export const lowActivityAlert = onSchedule(
  { schedule: '0 10 * * *', secrets: [anthropicKey], timeoutSeconds: 540 },
  async () => {
    const now = Date.now();
    const threeDaysAgo = new Date(now - 3 * 86400000).toISOString();
    const apiKey = anthropicKey.value().trim();

    const usersQuery = db
      .collection('users')
      .where('onboardingStep', '>=', 5)
      .where('lastActiveAt', '<', threeDaysAgo)
      .orderBy('onboardingStep')
      .orderBy('lastActiveAt');

    await forEachDocPaged(usersQuery, 200, async (userDoc) => {
      const profile = userDoc.data() as {
        displayName?: string;
        identityStatement?: string;
        goals?: Array<{ title: string; status: string }>;
        fcmToken?: string;
        lastActiveAt?: string;
        lifecycleTier?: number;
        notificationPrefs?: { masterEnabled?: boolean; lifecycleEnabled?: boolean };
      };

      const prefs = profile.notificationPrefs;
      if (prefs?.masterEnabled === false || prefs?.lifecycleEnabled === false) {
        return;
      }

      const last = profile.lastActiveAt
        ? Date.parse(profile.lastActiveAt)
        : NaN;
      if (isNaN(last)) return;

      const days = Math.floor((now - last) / 86400000);
      const tier = lifecycleTierForDays(days);
      if (tier === 0) return;

      // Already nudged at this depth (or deeper) — don't repeat.
      const sentTier = profile.lifecycleTier ?? 0;
      if (tier <= sentTier) return;

      try {
        const prompt = `Write a short, warm re-engagement message (2-3 sentences) for ${profile.displayName ?? 'a user'} who hasn't checked in for ${days} days. 
Their identity: "${profile.identityStatement ?? 'becoming their best self'}"
Their goals: ${(profile.goals ?? []).filter(g => g.status === 'active').map(g => g.title).slice(0, 2).join(', ')}
Make it personal, not generic. No guilt-tripping. Just a warm reminder of who they're becoming.`;

        const alertMessage = await callAnthropicInternal(
          'You write brief, warm re-engagement messages for a mindset coaching app. Never guilt-trip. Always inspire.',
          prompt,
          150,
          apiKey,
        );

        if (profile.fcmToken) {
          await sendPush({
            token: profile.fcmToken,
            title: 'Your mindset journey misses you ✨',
            body: alertMessage,
            type: 'low_activity_alert',
            category: 'lifecycle',
            route: '/dashboard',
            recipientUid: userDoc.id,
          });
        }

        // Record the tier so we don't nudge again until they lapse deeper.
        await userDoc.ref.update({ lifecycleTier: tier });
        console.log(`Lifecycle nudge (tier ${tier}) sent to: ${userDoc.id}`);
      } catch (err) {
        console.error(`Failed low activity alert for user ${userDoc.id}:`, err);
      }
    });
  },
);

// ─── Partner accountability loop ─────────────────────────────────────────────

/**
 * partnerAccountabilityDaily — runs daily. For each primary user with active
 * partners, evaluates the day that just ended and notifies their partners:
 *   - slip alert    → primary missed the day (prompts the partner to check in)
 *   - celebration   → primary had a perfect day or hit a streak milestone
 *
 * Guardrails: gated on the primary's `notifyPartnerOnSlip` consent (slips only),
 * deduped per day, and capped at 3 slip alerts per rolling week so a chronically
 * lapsed primary never burns out their partner.
 */
const STREAK_MILESTONES = [7, 14, 30, 50, 100, 200, 365];

export const partnerAccountabilityDaily = onSchedule(
  { schedule: '0 1 * * *', timeoutSeconds: 540 },
  async () => {
    const now = new Date();
    const nowMs = now.getTime();
    const weekKey = localDateKey(new Date(nowMs - (now.getUTCDay() * 86400000)));

    const usersQuery = db
      .collection('users')
      .where('onboardingStep', '>=', 5)
      .orderBy('onboardingStep');

    await forEachDocPaged(usersQuery, 300, async (primaryDoc) => {
      const primary = primaryDoc.data() as {
        displayName?: string;
        timezone?: string;
        createdAt?: string;
        partnerUids?: string[];
        dailyCompletions?: CompletionDoc[];
        notificationPrefs?: { notifyPartnerOnSlip?: boolean };
        partnerNudge?: {
          lastSlipDate?: string;
          lastCelebrationDate?: string;
          weekKey?: string;
          slipCount?: number;
        };
      };

      const partnerUids = primary.partnerUids ?? [];
      if (partnerUids.length === 0) return;

      // Skip brand-new accounts so day-one users aren't flagged as slipping.
      const created = primary.createdAt ? Date.parse(primary.createdAt) : nowMs;
      if (nowMs - created < 2 * 86400000) return;

      const completions = primary.dailyCompletions ?? [];
      const yKey = localDateKeyInTz(new Date(nowMs - 86400000), primary.timezone);
      const yesterday = completions.find((c) => c.date === yKey);
      const yCount = yesterday ? completedCount(yesterday) : 0;
      const streak = computeStreak(completions);
      const firstName = (primary.displayName ?? 'Your partner').split(' ')[0];

      const nudge = primary.partnerNudge ?? {};
      const isSlip = yCount < STREAK_THRESHOLD;
      const isPerfect = yCount >= 8;
      const isMilestone = STREAK_MILESTONES.includes(streak);

      // ── Celebration (positive; no consent gate, deduped per day) ──
      if ((isPerfect || isMilestone) && nudge.lastCelebrationDate !== yKey) {
        const body = isMilestone
          ? `${firstName} just hit a ${streak}-day streak. Cheer them on!`
          : `${firstName} just had a perfect day. Celebrate with them!`;
        await notifyPartners(partnerUids, primaryDoc.id, {
          title: `${firstName} is on a roll`,
          body,
          type: 'partner_celebration',
        });
        await primaryDoc.ref.update({
          'partnerNudge.lastCelebrationDate': yKey,
        });
      }

      // ── Slip alert (consent-gated, deduped, weekly-capped) ──
      const slipAllowed =
        primary.notificationPrefs?.notifyPartnerOnSlip !== false;
      if (isSlip && slipAllowed && nudge.lastSlipDate !== yKey) {
        const sameWeek = nudge.weekKey === weekKey;
        const slipCount = sameWeek ? nudge.slipCount ?? 0 : 0;
        if (slipCount < 3) {
          await notifyPartners(partnerUids, primaryDoc.id, {
            title: `${firstName} could use a nudge`,
            body: `${firstName} hasn't checked in. A quick word from you goes a long way.`,
            type: 'partner_slip',
          });
          await primaryDoc.ref.update({
            'partnerNudge.lastSlipDate': yKey,
            'partnerNudge.weekKey': weekKey,
            'partnerNudge.slipCount': slipCount + 1,
          });
        }
      }
    });
  },
);

/**
 * Sends a partner-category push to each partner of a primary user, deep-linking
 * to that primary's progress view. Respects each partner's notification prefs.
 */
async function notifyPartners(
  partnerUids: string[],
  primaryUid: string,
  msg: { title: string; body: string; type: string },
): Promise<void> {
  for (const partnerUid of partnerUids) {
    try {
      const partnerSnap = await db.collection('users').doc(partnerUid).get();
      const partner = partnerSnap.data() as {
        fcmToken?: string;
        notificationPrefs?: { masterEnabled?: boolean; partnerEnabled?: boolean };
      } | undefined;
      if (!partner?.fcmToken) continue;
      const prefs = partner.notificationPrefs;
      if (prefs?.masterEnabled === false || prefs?.partnerEnabled === false) {
        continue;
      }
      await sendPush({
        token: partner.fcmToken,
        title: msg.title,
        body: msg.body,
        type: msg.type,
        category: 'partner',
        route: `/partner-view/${primaryUid}`,
        recipientUid: partnerUid,
        data: { primaryUid },
      });
    } catch (err) {
      console.error(`notifyPartners failed for ${partnerUid}:`, err);
    }
  }
}

/**
 * weeklyPartnerDigest — Sunday 16:00 UTC. A low-frequency summary of each
 * primary user's week sent to their partners, so distant partners stay in the
 * loop without daily pings.
 */
export const weeklyPartnerDigest = onSchedule(
  { schedule: '0 16 * * 0', timeoutSeconds: 540 },
  async () => {
    const nowMs = Date.now();

    const usersQuery = db
      .collection('users')
      .where('onboardingStep', '>=', 5)
      .orderBy('onboardingStep');

    await forEachDocPaged(usersQuery, 300, async (primaryDoc) => {
      const primary = primaryDoc.data() as {
        displayName?: string;
        timezone?: string;
        partnerUids?: string[];
        dailyCompletions?: CompletionDoc[];
      };

      const partnerUids = primary.partnerUids ?? [];
      if (partnerUids.length === 0) return;

      const completions = primary.dailyCompletions ?? [];
      const byDate = new Map<string, CompletionDoc>();
      for (const c of completions) {
        if (c.date) byDate.set(c.date, c);
      }

      let activeDays = 0;
      for (let i = 1; i <= 7; i++) {
        const key = localDateKeyInTz(
          new Date(nowMs - i * 86400000),
          primary.timezone,
        );
        const c = byDate.get(key);
        if (c && completedCount(c) >= STREAK_THRESHOLD) activeDays++;
      }

      const streak = computeStreak(completions);
      const firstName = (primary.displayName ?? 'Your partner').split(' ')[0];

      await notifyPartners(partnerUids, primaryDoc.id, {
        title: `${firstName}'s week`,
        body: `${activeDays}/7 active days and a ${streak}-day streak. Send some encouragement.`,
        type: 'partner_digest',
      });
    });
  },
);
