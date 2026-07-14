/** Topic seeds for blog draft generation. Expand over time or move to Firestore. */
export const BLOG_TOPIC_SEEDS: Array<{
  theme: string;
  keywords: string[];
  angle: string;
}> = [
  {
    theme: 'Shiny object syndrome and founder focus',
    keywords: ['shiny object syndrome', 'founder focus', 'startup discipline'],
    angle: 'How chasing excitement instead of compounding work kills side projects',
  },
  {
    theme: 'Limiting beliefs in career transitions',
    keywords: ['limiting beliefs', 'career change mindset', 'identity shift'],
    angle: 'The stories we tell ourselves when we outgrow an old version of ourselves',
  },
  {
    theme: 'Definite Major Purpose',
    keywords: ['definite major purpose', 'goal clarity', 'Think and Grow Rich'],
    angle: 'Why vague goals feel motivating for a week and then fizzle',
  },
  {
    theme: 'Drift and procrastination',
    keywords: ['procrastination', 'decision fatigue', 'Outwitting the Devil'],
    angle: 'What drift looks like when you are busy but not moving',
  },
  {
    theme: 'Money mindset and self-worth',
    keywords: ['money mindset', 'wealth beliefs', 'financial self-worth'],
    angle: 'Inherited money scripts that show up even when income grows',
  },
  {
    theme: 'Mental toughness on hard days',
    keywords: ['mental toughness', 'discipline', 'motivation vs commitment'],
    angle: 'Acting when you do not feel like it without burning out',
  },
  {
    theme: 'Visualization without white-knuckling',
    keywords: ['visualization', 'anxiety and goals', 'non-attachment'],
    angle: 'Holding a goal without gripping so hard you cannot breathe',
  },
  {
    theme: 'Identity-based habit change',
    keywords: ['identity change', 'habit formation', 'becoming someone new'],
    angle: 'Why behavior hacks fail when the identity story stays the same',
  },
  {
    theme: 'Morning routines that actually stick',
    keywords: ['morning routine', 'daily practice', 'consistency'],
    angle: 'Designing a routine around who you are becoming, not who you were',
  },
  {
    theme: 'AI coaching vs generic chatbots',
    keywords: ['AI life coach', 'mindset coaching app', 'personalized coaching'],
    angle: 'What changes when a coach remembers your patterns and history',
  },
  {
    theme: 'Evidence logging and self-trust',
    keywords: ['self-trust', 'evidence journal', 'identity proof'],
    angle: 'Collecting proof that you are already becoming the person you want to be',
  },
  {
    theme: 'Relationship mindset and influence',
    keywords: ['communication mindset', 'conflict resolution', 'influence'],
    angle: 'How mindset work shows up in hard conversations at home and work',
  },
];

export const BLOG_AUTHOR_SYSTEM = `You are Jonathan Brannen, founder of MindsetForge, writing a blog post in your own voice.

BACKGROUND (use naturally, do not recite as a resume):
- 12 years in mobile development, solo founder of MindsetForge and DandyLight
- Based in Temecula, California
- Repeated a pattern for years: great idea, build it, market it, no growth, lose interest, chase the next idea
- Turning point after using MindsetForge for a year: his AI coach helped him see he only gave attention to what felt exciting and drifted when projects hit friction
- Now sticks to the plan even when it is not exciting
- Coaches his sons' Little League team, races go-karts semi-pro, gym most mornings, oil paints when he has time
- MindsetForge is grounded in six books: Think and Grow Rich, Outwitting the Devil, Secrets of the Millionaire Mind, Mind Magic (James Doty), 177 Mental Toughness Secrets of the World Class, How to Win Friends and Influence People

VOICE:
- Honest practitioner, not a guru. Still doing the work.
- First person when sharing experience. Concrete examples over abstract advice.
- Short paragraphs. Clear headings. No corporate fluff.
- Never claim to have it all figured out.

STYLE RULES (non-negotiable):
- Never use "--" or em dash. Use a comma, period, or new sentence instead.
- Never use "..." to trail off. End every thought completely.
- Write like a real human founder, not an AI content farm.`;

export const BLOG_GENERATION_MODEL = 'claude-sonnet-4-5';

/** Roughly 1–2 drafts per week when the daily job runs. */
export const BLOG_DRAFT_PROBABILITY = 0.22;

/** Skip auto-generation if a draft was created within this many days. */
export const BLOG_MIN_DAYS_BETWEEN_DRAFTS = 4;

export const GITHUB_BLOG_REPO = 'JBrannenMobileDev/mindsetforge-web';

export const GITHUB_BLOG_DISPATCH_EVENT = 'blog-publish';
