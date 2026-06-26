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

/// Curated affirmations keyed by category. ~8-12 per category.
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
