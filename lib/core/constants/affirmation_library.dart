/// Curated, pre-written affirmations grouped by category.
///
/// Pure Dart — no Flutter/Firebase imports. This is the shared content source
/// reused by the onboarding starter deck, the in-app browsable library, and the
/// first-run picker. Every entry is a present-tense "I am" identity statement so
/// the whole experience stays consistent with the AI-generated affirmations.
library;

/// The eight affirmation categories surfaced in the UI. Keep in sync with the
/// `_categories` list in the affirmations tab.
const List<String> kAffirmationCategories = [
  'general',
  'confidence',
  'discipline',
  'abundance',
  'resilience',
  'decisiveness',
  'health',
  'relationships',
];

/// Curated affirmations keyed by category. ~24 per category.
const Map<String, List<String>> kAffirmationLibrary = {
  'general': [
    'I am becoming the best version of myself every day.',
    'I am exactly where I need to be to grow.',
    'I am in control of how I respond to my life.',
    'I am proud of how far I have come.',
    'I am capable of creating the life I want.',
    'I am grounded, focused, and moving forward.',
    'I am worthy of the goals I am working toward.',
    'I am committed to showing up for myself today.',
    'I am growing a little stronger every single day.',
    'I am the kind of person who keeps my promises to myself.',
    'I am open to learning from everything that happens to me.',
    'I am turning my intentions into action.',
    'I am at peace with my past and excited for my future.',
    'I am exactly the person I need to be today.',
    'I am making progress, even when it is hard to see.',
    'I am choosing my response to every moment.',
    'I am building momentum with every small win.',
    'I am becoming who I was always meant to be.',
    'I am full of potential waiting to be expressed.',
    'I am grateful for the chance to begin again each day.',
    'I am someone who takes ownership of my life.',
    'I am aligned with the future I am creating.',
    'I am letting go of who I was to become who I am.',
    'I am enough, and I am still growing.',
  ],
  'confidence': [
    'I am confident and capable of achieving my goals.',
    'I am worthy of success and respect.',
    'I am enough exactly as I am right now.',
    'I am secure in who I am becoming.',
    'I am bold and I trust my own decisions.',
    'I am calm and self-assured under pressure.',
    'I am someone who speaks up for what I believe.',
    'I am proud to take up space in any room.',
    'I am at ease being seen and heard.',
    'I am worthy of every good thing coming to me.',
    'I am brave enough to be a beginner.',
    'I am grounded in my own self-worth.',
    'I am not defined by other people\'s opinions.',
    'I am becoming more confident every day.',
    'I am comfortable in my own skin.',
    'I am capable of figuring anything out.',
    'I am deserving of the success I am building.',
    'I am a powerful force in my own life.',
    'I am free to express who I truly am.',
    'I am sure of my value, no matter the outcome.',
    'I am someone who believes in my own abilities.',
    'I am unafraid to ask for what I want.',
    'I am proud of the person I am becoming.',
    'I am steady and confident under any spotlight.',
  ],
  'discipline': [
    'I am disciplined and I follow through on my commitments.',
    'I am someone who does what I say I will do.',
    'I am consistent, even when motivation fades.',
    'I am building unshakable habits one day at a time.',
    'I am in command of my time and my attention.',
    'I am willing to do the hard things first.',
    'I am the kind of person who finishes what I start.',
    'I am stronger than my excuses.',
    'I am in control of my habits and my routines.',
    'I am someone who shows up whether or not I feel like it.',
    'I am focused on my goals over my comfort.',
    'I am disciplined in the small moments that matter.',
    'I am building a life through daily action.',
    'I am the master of my own schedule.',
    'I am willing to be uncomfortable in order to grow.',
    'I am someone who chooses long-term wins.',
    'I am steady and consistent in my efforts.',
    'I am turning discipline into freedom.',
    'I am reliable, especially to myself.',
    'I am stronger than any distraction.',
    'I am committed to my goals over my moods.',
    'I am someone who follows through no matter what.',
    'I am building discipline one decision at a time.',
    'I am the kind of person who keeps going.',
  ],
  'abundance': [
    'I am open to abundance in all areas of my life.',
    'I am worthy of wealth and opportunity.',
    'I am surrounded by possibility everywhere I look.',
    'I am grateful for everything I already have.',
    'I am a magnet for opportunities that serve my growth.',
    'I am generous because I trust there is always enough.',
    'I am creating value that returns to me freely.',
    'I am building a life of freedom and prosperity.',
    'I am aligned with abundance in every form.',
    'I am worthy of receiving more than enough.',
    'I am attracting opportunities that match my growth.',
    'I am thankful for the wealth already in my life.',
    'I am open to receiving good things with ease.',
    'I am someone money flows to and through.',
    'I am surrounded by limitless opportunity.',
    'I am creating value the world rewards.',
    'I am abundant in time, energy, and resources.',
    'I am building wealth with patience and intention.',
    'I am deserving of a rich and full life.',
    'I am a confident steward of growing prosperity.',
    'I am open to success arriving in unexpected ways.',
    'I am grateful, and gratitude brings me more.',
    'I am living a life of expanding possibility.',
    'I am worthy of effortless, lasting prosperity.',
  ],
  'resilience': [
    'I am resilient and I rise stronger from every setback.',
    'I am able to handle whatever comes my way.',
    'I am calm in the face of challenge.',
    'I am growing through what I am going through.',
    'I am someone who keeps going when things get hard.',
    'I am at peace with what I cannot control.',
    'I am learning and adapting every single day.',
    'I am steady, no matter the storm around me.',
    'I am stronger than any obstacle in my path.',
    'I am able to begin again as many times as it takes.',
    'I am grounded even when life feels uncertain.',
    'I am resilient, and setbacks only sharpen me.',
    'I am capable of carrying hard things with grace.',
    'I am someone who always finds a way forward.',
    'I am calm, even in the middle of chaos.',
    'I am learning something valuable from this challenge.',
    'I am bending without breaking.',
    'I am building strength through every difficulty.',
    'I am the calm within my own storm.',
    'I am someone who recovers and keeps moving.',
    'I am at peace with the things I cannot change.',
    'I am tougher than the moments that test me.',
    'I am rooted, steady, and unshaken.',
    'I am someone who turns pain into growth.',
  ],
  'decisiveness': [
    'I am decisive and I trust my own judgment.',
    'I am clear about what matters most to me.',
    'I am willing to act before I feel ready.',
    'I am someone who makes choices and moves forward.',
    'I am free of the need for everyone to approve.',
    'I am confident in the decisions I make.',
    'I am quick to act on what I know is right.',
    'I am the author of my own direction.',
    'I am clear and certain about my next step.',
    'I am someone who trusts my own instincts.',
    'I am willing to choose and let go of the rest.',
    'I am at peace with making imperfect decisions.',
    'I am decisive and I move with purpose.',
    'I am free from the trap of overthinking.',
    'I am the one who decides where I am going.',
    'I am confident in my ability to choose well.',
    'I am someone who commits and follows through.',
    'I am ready to act on what I know is true.',
    'I am clear-headed when it is time to decide.',
    'I am led by my values, not my fears.',
    'I am someone who chooses progress over perfection.',
    'I am decisive, even with incomplete information.',
    'I am the final authority on my own life.',
    'I am quick to decide and steady to act.',
  ],
  'health': [
    'I am strong, healthy, and full of energy.',
    'I am kind to my body and it serves me well.',
    'I am committed to taking care of myself.',
    'I am at home in my body.',
    'I am someone who prioritizes rest and recovery.',
    'I am building strength with every choice I make.',
    'I am calm, present, and in tune with my needs.',
    'I am worthy of feeling good in my own skin.',
    'I am nourishing my body with every choice.',
    'I am grateful for all that my body does for me.',
    'I am someone who moves my body with joy.',
    'I am building lasting health one habit at a time.',
    'I am gentle and patient with my body.',
    'I am full of vitality and energy.',
    'I am someone who listens to what my body needs.',
    'I am committed to my long-term wellbeing.',
    'I am at peace in my body, just as it is.',
    'I am someone who rests without guilt.',
    'I am choosing foods that fuel my best self.',
    'I am stronger and healthier every day.',
    'I am deserving of deep, restful sleep.',
    'I am caring for my mind as much as my body.',
    'I am building a body I am proud to live in.',
    'I am someone who treats my health as a priority.',
  ],
  'relationships': [
    'I am worthy of deep and meaningful connection.',
    'I am present and attentive with the people I love.',
    'I am someone who gives and receives love freely.',
    'I am surrounded by people who support my growth.',
    'I am honest and open in my relationships.',
    'I am building relationships rooted in trust.',
    'I am the kind of person others can rely on.',
    'I am at ease being my authentic self with others.',
    'I am someone who listens to truly understand.',
    'I am worthy of love exactly as I am.',
    'I am building deeper connections every day.',
    'I am open to giving and receiving care.',
    'I am a safe and supportive presence for others.',
    'I am attracting people who value who I am.',
    'I am patient and kind in my relationships.',
    'I am someone who communicates with honesty.',
    'I am present with the people who matter most.',
    'I am worthy of relationships that nourish me.',
    'I am letting go of connections that drain me.',
    'I am someone who forgives and moves forward.',
    'I am grateful for the people who support me.',
    'I am building a circle rooted in mutual respect.',
    'I am loving and worthy of love.',
    'I am someone people feel comfortable being real with.',
  ],
};

/// Maps an arbitrary category or quality keyword (e.g. a goal's category or an
/// identity quality) onto one of the eight affirmation categories. Falls back to
/// `general` when there is no sensible match.
String mapToAffirmationCategory(String raw) {
  final key = raw.trim().toLowerCase();
  if (key.isEmpty) return 'general';

  // Direct match against a known category.
  if (kAffirmationCategories.contains(key)) return key;

  const keywordMap = <String, String>{
    'career': 'confidence',
    'business': 'abundance',
    'work': 'discipline',
    'finance': 'abundance',
    'financial': 'abundance',
    'money': 'abundance',
    'wealth': 'abundance',
    'fitness': 'health',
    'wellness': 'health',
    'body': 'health',
    'mind': 'resilience',
    'mental': 'resilience',
    'family': 'relationships',
    'love': 'relationships',
    'social': 'relationships',
    'personal': 'general',
    'growth': 'general',
    'productivity': 'discipline',
    'focus': 'discipline',
    'confident': 'confidence',
    'disciplined': 'discipline',
    'resilient': 'resilience',
    'decisive': 'decisiveness',
    'abundant': 'abundance',
    'healthy': 'health',
  };

  for (final entry in keywordMap.entries) {
    if (key.contains(entry.key)) return entry.value;
  }
  return 'general';
}

/// Builds a deduped starter set of affirmations.
///
/// Pulls round-robin from [focusCategories] (mapped onto known categories),
/// then tops up from `general` and `confidence` so the result always reaches
/// [count] when possible. [exclude] is matched case-insensitively against the
/// affirmation text so we never re-suggest something the user already has.
///
/// Returns a list of `(text, category)` records.
List<({String text, String category})> affirmationStarterSet({
  List<String> focusCategories = const [],
  int count = 5,
  Set<String> exclude = const {},
}) {
  final excludeLower = exclude.map((e) => e.trim().toLowerCase()).toSet();
  final used = <String>{};
  final result = <({String text, String category})>[];

  // Ordered, deduped list of categories to draw from.
  final ordered = <String>[];
  for (final raw in focusCategories) {
    final mapped = mapToAffirmationCategory(raw);
    if (!ordered.contains(mapped)) ordered.add(mapped);
  }
  for (final fallback in ['general', 'confidence', 'discipline']) {
    if (!ordered.contains(fallback)) ordered.add(fallback);
  }

  // Round-robin across categories so the deck feels balanced.
  final cursors = {for (final c in ordered) c: 0};
  var madeProgress = true;
  while (result.length < count && madeProgress) {
    madeProgress = false;
    for (final category in ordered) {
      if (result.length >= count) break;
      final pool = kAffirmationLibrary[category] ?? const [];
      final cursor = cursors[category]!;
      if (cursor >= pool.length) continue;
      cursors[category] = cursor + 1;
      madeProgress = true;
      final text = pool[cursor];
      final lower = text.toLowerCase();
      if (used.contains(lower) || excludeLower.contains(lower)) continue;
      used.add(lower);
      result.add((text: text, category: category));
    }
  }

  return result;
}
