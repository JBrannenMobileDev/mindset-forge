/// Curated, pre-written habits grouped by life area.
///
/// Pure-Dart — no Flutter/Firebase imports. This is the shared content source
/// for the browsable habit library and the cold-start empty state. Every entry
/// is intentionally tiny (2-minute rule), anchored to a concrete cue (habit
/// stacking), and tied to an identity, so users start from a complete, proven
/// example instead of a blank field.
library;

/// A single curated habit: a tiny routine, a concrete cue, and the identity it
/// reinforces.
typedef HabitTemplate = ({String name, String trigger, String identity});

/// Browse areas, ordered for display.
const List<String> kHabitLibraryAreas = [
  'Health',
  'Focus',
  'Calm',
  'Growth',
  'Discipline',
  'Relationships',
];

/// Curated habits keyed by area. ~5-6 per area.
const Map<String, List<HabitTemplate>> kHabitLibrary = {
  'Health': [
    (
      name: 'Drink a glass of water',
      trigger: 'After I wake up',
      identity: 'I am someone who takes care of my body',
    ),
    (
      name: 'Take a 10-minute walk',
      trigger: 'After lunch',
      identity: 'I am an active, energized person',
    ),
    (
      name: 'Do 5 push-ups',
      trigger: 'After I brush my teeth in the morning',
      identity: 'I am someone who builds strength daily',
    ),
    (
      name: 'Stretch for 2 minutes',
      trigger: 'Before I get into bed',
      identity: 'I am kind to my body',
    ),
    (
      name: 'Pack a healthy snack',
      trigger: 'After I make my morning coffee',
      identity: 'I am someone who fuels myself well',
    ),
  ],
  'Focus': [
    (
      name: 'Write my top priority for the day',
      trigger: 'When I sit down at my desk',
      identity: 'I am someone who works with intention',
    ),
    (
      name: 'Put my phone in another room',
      trigger: 'When I start deep work',
      identity: 'I am someone who protects my attention',
    ),
    (
      name: 'Plan tomorrow in 3 bullet points',
      trigger: 'Before I close my laptop',
      identity: 'I am organized and prepared',
    ),
    (
      name: 'Work in one 25-minute focus block',
      trigger: 'After my morning coffee',
      identity: 'I am someone who does deep, focused work',
    ),
    (
      name: 'Clear my desk',
      trigger: 'Before I start working',
      identity: 'I am someone who creates a calm workspace',
    ),
  ],
  'Calm': [
    (
      name: 'Take 5 slow breaths',
      trigger: 'After I wake up',
      identity: 'I am calm and grounded',
    ),
    (
      name: 'Meditate for 2 minutes',
      trigger: 'After I sit down in the morning',
      identity: 'I am someone who starts the day centered',
    ),
    (
      name: 'Write one thing I am grateful for',
      trigger: 'Before bed',
      identity: 'I am someone who notices the good',
    ),
    (
      name: 'Step outside for fresh air',
      trigger: 'After lunch',
      identity: 'I am someone who makes space to reset',
    ),
    (
      name: 'Do a 1-minute body scan',
      trigger: 'When I feel stressed',
      identity: 'I am in tune with how I feel',
    ),
  ],
  'Growth': [
    (
      name: 'Read one page',
      trigger: 'After I get into bed',
      identity: 'I am a lifelong learner',
    ),
    (
      name: 'Listen to 5 minutes of a podcast',
      trigger: 'During my commute',
      identity: 'I am someone who grows every day',
    ),
    (
      name: 'Write down one thing I learned',
      trigger: 'Before I close my laptop',
      identity: 'I am someone who reflects and improves',
    ),
    (
      name: 'Practice a skill for 10 minutes',
      trigger: 'After dinner',
      identity: 'I am someone who invests in my craft',
    ),
    (
      name: 'Review my goals',
      trigger: 'After my morning coffee',
      identity: 'I am focused on what matters most',
    ),
  ],
  'Discipline': [
    (
      name: 'Make my bed',
      trigger: 'After I get up',
      identity: 'I am someone who starts the day with a win',
    ),
    (
      name: 'Do the hardest task first',
      trigger: 'When I start work',
      identity: 'I am someone who does what I say I will do',
    ),
    (
      name: 'Lay out tomorrow\'s clothes',
      trigger: 'Before bed',
      identity: 'I am prepared and intentional',
    ),
    (
      name: 'Tidy one small space',
      trigger: 'After dinner',
      identity: 'I am someone who keeps my environment in order',
    ),
    (
      name: 'Track my spending for the day',
      trigger: 'Before I get into bed',
      identity: 'I am responsible with my money',
    ),
  ],
  'Relationships': [
    (
      name: 'Send one thoughtful message',
      trigger: 'After my morning coffee',
      identity: 'I am someone who nurtures my relationships',
    ),
    (
      name: 'Give a genuine compliment',
      trigger: 'When I talk to someone today',
      identity: 'I am someone who lifts others up',
    ),
    (
      name: 'Put my phone away at dinner',
      trigger: 'When I sit down to eat with others',
      identity: 'I am fully present with the people I love',
    ),
    (
      name: 'Ask someone how they are doing',
      trigger: 'When I greet a colleague',
      identity: 'I am someone who genuinely cares',
    ),
    (
      name: 'Reflect on someone I appreciate',
      trigger: 'Before bed',
      identity: 'I am grateful for the people in my life',
    ),
  ],
};
