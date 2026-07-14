import * as admin from 'firebase-admin';
import Anthropic from '@anthropic-ai/sdk';
import { onSchedule } from 'firebase-functions/v2/scheduler';
import { onDocumentWritten } from 'firebase-functions/v2/firestore';
import { onCall, HttpsError } from 'firebase-functions/v2/https';
import { defineSecret } from 'firebase-functions/params';
import {
  BLOG_AUTHOR_SYSTEM,
  BLOG_DRAFT_PROBABILITY,
  BLOG_GENERATION_MODEL,
  BLOG_MIN_DAYS_BETWEEN_DRAFTS,
  BLOG_TOPIC_SEEDS,
  GITHUB_BLOG_DISPATCH_EVENT,
  GITHUB_BLOG_REPO,
} from './blog_config';

const anthropicKey = defineSecret('ANTHROPIC_API_KEY');
const githubDispatchToken = defineSecret('GITHUB_DISPATCH_TOKEN');

const db = admin.firestore();

export type BlogPostStatus =
  | 'draft'
  | 'in_review'
  | 'approved'
  | 'published'
  | 'archived';

export type BlogFaqItem = { q: string; a: string };

export type BlogPostDoc = {
  slug: string;
  title: string;
  metaDescription: string;
  tldr: string;
  bodyMarkdown: string;
  tags: string[];
  targetKeywords: string[];
  faq: BlogFaqItem[];
  heroImagePrompt?: string;
  status: BlogPostStatus;
  seedNotes?: string;
  editedByHuman: boolean;
  generatedByModel: string;
  createdAt: string;
  scheduledFor?: string;
  publishedAt?: string;
  updatedAt: string;
};

type GeneratedBlogPayload = {
  title: string;
  metaDescription: string;
  tldr: string;
  bodyMarkdown: string;
  tags: string[];
  targetKeywords: string[];
  faq: BlogFaqItem[];
  heroImagePrompt?: string;
};

function slugify(title: string): string {
  return title
    .toLowerCase()
    .replace(/[^a-z0-9\s-]/g, '')
    .trim()
    .replace(/\s+/g, '-')
    .replace(/-+/g, '-')
    .slice(0, 80)
    .replace(/-$/, '');
}

function extractJsonObject(text: string): string {
  const start = text.indexOf('{');
  const end = text.lastIndexOf('}');
  if (start === -1 || end === -1 || end <= start) return text.trim();
  return text.slice(start, end + 1);
}

function parseGeneratedBlog(text: string): GeneratedBlogPayload | null {
  try {
    const data = JSON.parse(extractJsonObject(text)) as Record<string, unknown>;
    const title = typeof data.title === 'string' ? data.title.trim() : '';
    const metaDescription =
      typeof data.metaDescription === 'string' ? data.metaDescription.trim() : '';
    const tldr = typeof data.tldr === 'string' ? data.tldr.trim() : '';
    const bodyMarkdown =
      typeof data.bodyMarkdown === 'string' ? data.bodyMarkdown.trim() : '';
    if (!title || !metaDescription || !tldr || !bodyMarkdown) return null;

    const tags = Array.isArray(data.tags)
      ? data.tags.filter((t): t is string => typeof t === 'string').slice(0, 8)
      : [];
    const targetKeywords = Array.isArray(data.targetKeywords)
      ? data.targetKeywords
          .filter((t): t is string => typeof t === 'string')
          .slice(0, 10)
      : [];
    const faq = Array.isArray(data.faq)
      ? data.faq
          .map((item) => {
            if (!item || typeof item !== 'object') return null;
            const row = item as Record<string, unknown>;
            const q = typeof row.q === 'string' ? row.q.trim() : '';
            const a = typeof row.a === 'string' ? row.a.trim() : '';
            if (!q || !a) return null;
            return { q, a };
          })
          .filter((item): item is BlogFaqItem => item !== null)
          .slice(0, 6)
      : [];
    const heroImagePrompt =
      typeof data.heroImagePrompt === 'string'
        ? data.heroImagePrompt.trim()
        : undefined;

    return {
      title,
      metaDescription,
      tldr,
      bodyMarkdown,
      tags,
      targetKeywords,
      faq,
      heroImagePrompt,
    };
  } catch {
    return null;
  }
}

async function callBlogAnthropic(
  systemPrompt: string,
  userPrompt: string,
  maxTokens: number,
  apiKey: string,
): Promise<string> {
  const client = new Anthropic({ apiKey });
  const message = await client.messages.create({
    model: BLOG_GENERATION_MODEL,
    max_tokens: maxTokens,
    system: systemPrompt,
    messages: [{ role: 'user', content: userPrompt }],
  });
  const block = message.content[0];
  if (block.type !== 'text') {
    throw new Error('Unexpected response type from Claude');
  }
  return block.text
    .replace(/\s*—\s*/g, ', ')
    .replace(/\s*--\s*/g, ', ');
}

async function assertBlogAdmin(uid: string | undefined): Promise<void> {
  if (!uid) {
    throw new HttpsError('unauthenticated', 'Must be signed in.');
  }
  const configSnap = await db.doc('app_config/blog').get();
  const adminUids = (configSnap.data()?.adminUids ?? []) as string[];
  if (!adminUids.includes(uid)) {
    throw new HttpsError('permission-denied', 'Not a blog admin.');
  }
}

async function listExistingBlogTitles(): Promise<string[]> {
  const snap = await db.collection('blog_posts').select('title').get();
  return snap.docs
    .map((doc) => doc.data().title as string | undefined)
    .filter((title): title is string => typeof title === 'string');
}

async function uniqueSlugForTitle(title: string): Promise<string> {
  const base = slugify(title) || `post-${Date.now()}`;
  let candidate = base;
  let suffix = 2;
  while (true) {
    const existing = await db.collection('blog_posts').doc(candidate).get();
    if (!existing.exists) return candidate;
    candidate = `${base}-${suffix}`;
    suffix += 1;
  }
}

async function daysSinceLastDraft(): Promise<number | null> {
  const snap = await db
    .collection('blog_posts')
    .orderBy('createdAt', 'desc')
    .limit(1)
    .get();
  if (snap.empty) return null;
  const createdAt = snap.docs[0].data().createdAt as string | undefined;
  if (!createdAt) return null;
  const createdMs = Date.parse(createdAt);
  if (Number.isNaN(createdMs)) return null;
  return (Date.now() - createdMs) / (1000 * 60 * 60 * 24);
}

function pickTopicSeed(existingTitles: string[]): (typeof BLOG_TOPIC_SEEDS)[number] {
  const lowerTitles = existingTitles.map((t) => t.toLowerCase());
  const unused = BLOG_TOPIC_SEEDS.filter(
    (seed) =>
      !lowerTitles.some(
        (title) =>
          title.includes(seed.theme.toLowerCase()) ||
          seed.keywords.some((kw) => title.includes(kw.toLowerCase())),
      ),
  );
  const pool = unused.length > 0 ? unused : BLOG_TOPIC_SEEDS;
  return pool[Math.floor(Math.random() * pool.length)];
}

async function generateBlogDraftInternal(
  apiKey: string,
  seedNotes?: string,
): Promise<BlogPostDoc> {
  const existingTitles = await listExistingBlogTitles();
  const topic = pickTopicSeed(existingTitles);

  const ideaPrompt =
    `Pick ONE blog post topic for MindsetForge that would help with SEO and AI search visibility.\n`
    + `Theme: ${topic.theme}\n`
    + `Angle: ${topic.angle}\n`
    + `Target keywords: ${topic.keywords.join(', ')}\n`
    + `Avoid overlapping with these existing titles:\n`
    + `${existingTitles.slice(0, 30).map((t) => `- ${t}`).join('\n') || '(none yet)'}\n`
    + `Return ONLY valid JSON: { "workingTitle": string, "hook": string, "outline": string[] }`;

  const ideaResponse = await callBlogAnthropic(
    BLOG_AUTHOR_SYSTEM,
    ideaPrompt,
    600,
    apiKey,
  );

  let workingTitle = topic.theme;
  let hook = topic.angle;
  let outline: string[] = [];
  try {
    const idea = JSON.parse(extractJsonObject(ideaResponse)) as Record<
      string,
      unknown
    >;
    if (typeof idea.workingTitle === 'string') workingTitle = idea.workingTitle;
    if (typeof idea.hook === 'string') hook = idea.hook;
    if (Array.isArray(idea.outline)) {
      outline = idea.outline.filter((x): x is string => typeof x === 'string');
    }
  } catch {
    // Fall back to seed topic if idea JSON fails.
  }

  const seedBlock = seedNotes?.trim()
    ? `\nREAL EXPERIENCE TO WEAVE IN (priority, use specifically):\n${seedNotes.trim()}\n`
    : '';

  const draftPrompt =
    `Write a complete blog post for mindsetforge.app/blog.\n`
    + `Working title: ${workingTitle}\n`
    + `Hook: ${hook}\n`
    + `Outline:\n${outline.map((item) => `- ${item}`).join('\n')}\n`
    + `Target keywords (use naturally): ${topic.keywords.join(', ')}\n`
    + seedBlock
    + `\nRequirements:\n`
    + `- 900–1400 words in bodyMarkdown\n`
    + `- Include a TL;DR (2–3 sentences)\n`
    + `- Use markdown H2 headings phrased as questions where possible\n`
    + `- Include 3–5 FAQ items relevant to the post\n`
    + `- metaDescription under 160 characters\n`
    + `- Mention MindsetForge once, naturally, near the end (not salesy)\n`
    + `- Share at least one personal story or concrete example from Jonathan's life when possible\n`
    + `\nReturn ONLY valid JSON with keys:\n`
    + `title, metaDescription, tldr, bodyMarkdown, tags (string[]), targetKeywords (string[]), faq ([{q,a}]), heroImagePrompt (string)`;

  const draftResponse = await callBlogAnthropic(
    BLOG_AUTHOR_SYSTEM,
    draftPrompt,
    4000,
    apiKey,
  );
  const parsed = parseGeneratedBlog(draftResponse);
  if (!parsed) {
    throw new Error('Failed to parse generated blog JSON');
  }

  const slug = await uniqueSlugForTitle(parsed.title);
  const now = new Date().toISOString();
  return {
    slug,
    title: parsed.title,
    metaDescription: parsed.metaDescription,
    tldr: parsed.tldr,
    bodyMarkdown: parsed.bodyMarkdown,
    tags: parsed.tags.length > 0 ? parsed.tags : topic.keywords.slice(0, 4),
    targetKeywords:
      parsed.targetKeywords.length > 0
        ? parsed.targetKeywords
        : topic.keywords,
    faq: parsed.faq,
    heroImagePrompt: parsed.heroImagePrompt,
    status: 'draft',
    seedNotes: seedNotes?.trim() || undefined,
    editedByHuman: false,
    generatedByModel: BLOG_GENERATION_MODEL,
    createdAt: now,
    updatedAt: now,
  };
}

async function saveBlogDraft(post: BlogPostDoc): Promise<void> {
  await db.collection('blog_posts').doc(post.slug).set(post, { merge: false });
}

async function dispatchBlogPublish(slug: string, token: string): Promise<void> {
  const response = await fetch(
    `https://api.github.com/repos/${GITHUB_BLOG_REPO}/dispatches`,
    {
      method: 'POST',
      headers: {
        Authorization: `Bearer ${token}`,
        Accept: 'application/vnd.github+json',
        'Content-Type': 'application/json',
        'X-GitHub-Api-Version': '2022-11-28',
      },
      body: JSON.stringify({
        event_type: GITHUB_BLOG_DISPATCH_EVENT,
        client_payload: { slug, triggeredAt: new Date().toISOString() },
      }),
    },
  );
  if (!response.ok) {
    const body = await response.text();
    throw new Error(
      `GitHub dispatch failed (${response.status}): ${body.slice(0, 300)}`,
    );
  }
}

/** Daily job: probabilistically create a new draft (~1–2/week). */
export const generateBlogDraft = onSchedule(
  {
    schedule: '0 14 * * *',
    timeZone: 'America/Los_Angeles',
    secrets: [anthropicKey],
    timeoutSeconds: 540,
  },
  async () => {
    if (Math.random() > BLOG_DRAFT_PROBABILITY) {
      console.log('generateBlogDraft: skipped by probability gate');
      return;
    }

    const daysSince = await daysSinceLastDraft();
    if (
      daysSince !== null &&
      daysSince < BLOG_MIN_DAYS_BETWEEN_DRAFTS
    ) {
      console.log(
        `generateBlogDraft: skipped, last draft ${daysSince.toFixed(1)} days ago`,
      );
      return;
    }

    const pendingSnap = await db
      .collection('blog_posts')
      .where('status', 'in', ['draft', 'in_review', 'approved'])
      .limit(5)
      .get();
    if (pendingSnap.size >= 3) {
      console.log('generateBlogDraft: skipped, pending queue already full');
      return;
    }

    try {
      const apiKey = anthropicKey.value().trim();
      const post = await generateBlogDraftInternal(apiKey);
      await saveBlogDraft(post);
      console.log(`generateBlogDraft: created draft "${post.slug}"`);
    } catch (err) {
      console.error('generateBlogDraft failed:', err);
    }
  },
);

/** Admin callable: manually generate a draft, optionally with seed notes. */
export const createBlogDraft = onCall(
  { secrets: [anthropicKey], invoker: 'public' },
  async (request) => {
    await assertBlogAdmin(request.auth?.uid);

    const { seedNotes } = (request.data ?? {}) as { seedNotes?: string };
    if (seedNotes !== undefined && typeof seedNotes !== 'string') {
      throw new HttpsError('invalid-argument', 'seedNotes must be a string.');
    }

    try {
      const apiKey = anthropicKey.value().trim();
      const post = await generateBlogDraftInternal(apiKey, seedNotes);
      await saveBlogDraft(post);
      return { slug: post.slug, title: post.title };
    } catch (err) {
      console.error('createBlogDraft failed:', err);
      throw new HttpsError('internal', 'Failed to generate blog draft.');
    }
  },
);

/** Admin callable: re-run generation for an existing draft slug. */
export const regenerateBlogDraft = onCall(
  { secrets: [anthropicKey], invoker: 'public' },
  async (request) => {
    await assertBlogAdmin(request.auth?.uid);

    const { slug, seedNotes } = (request.data ?? {}) as {
      slug?: string;
      seedNotes?: string;
    };
    if (!slug || typeof slug !== 'string') {
      throw new HttpsError('invalid-argument', 'slug is required.');
    }

    const existing = await db.collection('blog_posts').doc(slug).get();
    if (!existing.exists) {
      throw new HttpsError('not-found', 'Post not found.');
    }
    const data = existing.data() as BlogPostDoc;
    if (data.status === 'published') {
      throw new HttpsError(
        'failed-precondition',
        'Cannot regenerate a published post.',
      );
    }

    const notes = seedNotes ?? data.seedNotes;
    try {
      const apiKey = anthropicKey.value().trim();
      const generated = await generateBlogDraftInternal(apiKey, notes);
      const now = new Date().toISOString();
      const updated: BlogPostDoc = {
        ...generated,
        slug,
        status: data.status === 'archived' ? 'draft' : data.status,
        seedNotes: notes?.trim() || undefined,
        editedByHuman: false,
        createdAt: data.createdAt,
        updatedAt: now,
      };
      await db.collection('blog_posts').doc(slug).set(updated, { merge: false });
      return { slug, title: updated.title };
    } catch (err) {
      console.error('regenerateBlogDraft failed:', err);
      throw new HttpsError('internal', 'Failed to regenerate blog draft.');
    }
  },
);

/** Admin callable: trigger marketing site rebuild after publish. */
export const triggerBlogDeploy = onCall(
  { secrets: [githubDispatchToken], invoker: 'public' },
  async (request) => {
    await assertBlogAdmin(request.auth?.uid);
    const { slug } = (request.data ?? {}) as { slug?: string };
    try {
      await dispatchBlogPublish(slug ?? 'manual', githubDispatchToken.value().trim());
      return { ok: true };
    } catch (err) {
      console.error('triggerBlogDeploy failed:', err);
      throw new HttpsError('internal', 'Failed to trigger blog deploy.');
    }
  },
);

/** Firestore trigger: kick off GitHub deploy when a post is published. */
export const onBlogPostPublished = onDocumentWritten(
  {
    document: 'blog_posts/{slug}',
    secrets: [githubDispatchToken],
  },
  async (event) => {
    const before = event.data?.before.data() as BlogPostDoc | undefined;
    const after = event.data?.after.data() as BlogPostDoc | undefined;
    if (!after || after.status !== 'published') return;
    if (before?.status === 'published') return;

    const token = githubDispatchToken.value().trim();
    if (!token) {
      console.error('onBlogPostPublished: GITHUB_DISPATCH_TOKEN missing');
      return;
    }

    try {
      await dispatchBlogPublish(after.slug, token);
      console.log(`onBlogPostPublished: dispatched deploy for ${after.slug}`);
    } catch (err) {
      console.error('onBlogPostPublished failed:', err);
    }
  },
);
