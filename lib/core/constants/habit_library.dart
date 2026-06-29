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
  'Sleep',
  'Finance',
  'Productivity',
  'Mindfulness',
];

/// Curated habits keyed by area. ~9 per area.
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
    (
      name: 'Eat one piece of fruit',
      trigger: 'After breakfast',
      identity: 'I am someone who fuels myself well',
    ),
    (
      name: 'Take the stairs',
      trigger: 'When I reach the stairs',
      identity: 'I am an active, energized person',
    ),
    (
      name: 'Fill my water bottle',
      trigger: 'Before I start work',
      identity: 'I am someone who stays hydrated',
    ),
    (
      name: 'Do a 60-second plank',
      trigger: 'After my evening shower',
      identity: 'I am someone who builds strength daily',
    ),
  ],
  'Focus': [
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
    (
      name: 'Silence non-essential notifications',
      trigger: 'When I start work',
      identity: 'I am someone who protects my attention',
    ),
    (
      name: 'Close all extra browser tabs',
      trigger: 'When I begin a task',
      identity: 'I am someone who works with intention',
    ),
    (
      name: 'Set a timer before I start',
      trigger: 'When I sit down to work',
      identity: 'I am someone who works with intention',
    ),
    (
      name: 'Single-task for the next 10 minutes',
      trigger: 'When I catch myself multitasking',
      identity: 'I am someone who does deep, focused work',
    ),
    (
      name: 'Take a 5-minute break away from screens',
      trigger: 'After a focus block',
      identity: 'I am someone who protects my energy',
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
      name: 'Step outside for fresh air',
      trigger: 'After lunch',
      identity: 'I am someone who makes space to reset',
    ),
    (
      name: 'Do a 1-minute body scan',
      trigger: 'When I feel stressed',
      identity: 'I am in tune with how I feel',
    ),
    (
      name: 'Unclench my jaw and drop my shoulders',
      trigger: 'When I notice tension',
      identity: 'I am calm and grounded',
    ),
    (
      name: 'Brew a cup of tea slowly',
      trigger: 'In the late afternoon',
      identity: 'I am someone who makes space to reset',
    ),
    (
      name: 'Put on calming music',
      trigger: 'When I start to feel rushed',
      identity: 'I am calm and grounded',
    ),
    (
      name: 'Exhale twice as long as I inhale',
      trigger: 'When I feel anxious',
      identity: 'I am in tune with how I feel',
    ),
    (
      name: 'Sit quietly for one minute',
      trigger: 'Before I open my inbox',
      identity: 'I am someone who starts the day centered',
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
      name: 'Watch one short tutorial',
      trigger: 'After dinner',
      identity: 'I am someone who grows every day',
    ),
    (
      name: 'Learn one new word',
      trigger: 'With my morning coffee',
      identity: 'I am a lifelong learner',
    ),
    (
      name: 'Write down a question I am curious about',
      trigger: 'When something sparks my interest',
      identity: 'I am someone who grows every day',
    ),
    (
      name: 'Review my notes from yesterday',
      trigger: 'When I sit down at my desk',
      identity: 'I am someone who reflects and improves',
    ),
    (
      name: 'Read an article in my field',
      trigger: 'During lunch',
      identity: 'I am someone who invests in my craft',
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
    (
      name: 'Get up with my first alarm',
      trigger: 'When my alarm goes off',
      identity: 'I am someone who does what I say I will do',
    ),
    (
      name: 'Wash my dishes right after eating',
      trigger: 'After a meal',
      identity: 'I am someone who keeps my environment in order',
    ),
    (
      name: 'Do one rep of a habit I am avoiding',
      trigger: 'When I feel resistance',
      identity: 'I am someone who does what I say I will do',
    ),
    (
      name: 'Put my keys in the same place',
      trigger: 'When I walk in the door',
      identity: 'I am prepared and intentional',
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
      name: 'Text a friend I have not spoken to lately',
      trigger: 'After dinner',
      identity: 'I am someone who nurtures my relationships',
    ),
    (
      name: 'Really listen without interrupting',
      trigger: 'During my next conversation',
      identity: 'I am someone who genuinely cares',
    ),
    (
      name: 'Thank someone specifically',
      trigger: 'When someone helps me',
      identity: 'I am someone who lifts others up',
    ),
    (
      name: 'Make eye contact when I greet someone',
      trigger: 'When I say hello',
      identity: 'I am fully present with the people I love',
    ),
    (
      name: 'Call a family member',
      trigger: 'On my way home',
      identity: 'I am someone who nurtures my relationships',
    ),
  ],
  'Sleep': [
    (
      name: 'Put my phone on the charger across the room',
      trigger: 'Before I get into bed',
      identity: 'I am someone who protects my rest',
    ),
    (
      name: 'Dim the lights an hour before bed',
      trigger: 'After dinner',
      identity: 'I am someone who winds down with intention',
    ),
    (
      name: 'Get sunlight within 30 minutes of waking',
      trigger: 'After I wake up',
      identity: 'I am someone who honors my natural rhythm',
    ),
    (
      name: 'Set a consistent bedtime alarm',
      trigger: 'After dinner',
      identity: 'I am someone who protects my rest',
    ),
    (
      name: 'Stop screens 30 minutes before bed',
      trigger: 'When my wind-down alarm goes off',
      identity: 'I am someone who winds down with intention',
    ),
    (
      name: 'Write tomorrow\'s worries on paper',
      trigger: 'Before bed',
      identity: 'I am someone who rests with a clear mind',
    ),
    (
      name: 'Read a few pages instead of scrolling',
      trigger: 'When I get into bed',
      identity: 'I am someone who winds down with intention',
    ),
    (
      name: 'Keep my bedroom cool and dark',
      trigger: 'Before I get into bed',
      identity: 'I am someone who protects my rest',
    ),
    (
      name: 'Avoid caffeine after 2pm',
      trigger: 'In the early afternoon',
      identity: 'I am someone who honors my natural rhythm',
    ),
  ],
  'Finance': [
    (
      name: 'Move 5 dollars to savings',
      trigger: 'After I get paid for anything',
      identity: 'I am someone who builds wealth slowly',
    ),
    (
      name: 'Check my account balance',
      trigger: 'With my morning coffee',
      identity: 'I am someone who stays aware of my money',
    ),
    (
      name: 'Cancel one unused subscription',
      trigger: 'When I spot it on my statement',
      identity: 'I am intentional with my money',
    ),
    (
      name: 'Log one purchase in my budget',
      trigger: 'After I buy something',
      identity: 'I am someone who stays aware of my money',
    ),
    (
      name: 'Wait 24 hours before a non-essential buy',
      trigger: 'When I want to buy something',
      identity: 'I am intentional with my money',
    ),
    (
      name: 'Pack lunch instead of buying',
      trigger: 'The night before',
      identity: 'I am someone who builds wealth slowly',
    ),
    (
      name: 'Read one page about money',
      trigger: 'Before bed',
      identity: 'I am someone who learns to grow my wealth',
    ),
    (
      name: 'Round up and save the change',
      trigger: 'After a purchase',
      identity: 'I am someone who builds wealth slowly',
    ),
    (
      name: 'Review one bill for savings',
      trigger: 'On a weekend morning',
      identity: 'I am intentional with my money',
    ),
  ],
  'Productivity': [
    (
      name: 'Write tomorrow\'s top 3 before logging off',
      trigger: 'Before I close my laptop',
      identity: 'I am organized and prepared',
    ),
    (
      name: 'Process my inbox for 5 minutes',
      trigger: 'After lunch',
      identity: 'I am someone who stays on top of things',
    ),
    (
      name: 'Time-block my calendar',
      trigger: 'When I sit down at my desk',
      identity: 'I am organized and prepared',
    ),
    (
      name: 'Do a 2-minute task right away',
      trigger: 'When a quick task appears',
      identity: 'I am someone who follows through',
    ),
    (
      name: 'Write down every open loop',
      trigger: 'When I feel scattered',
      identity: 'I am someone who stays on top of things',
    ),
    (
      name: 'Set one clear outcome for the day',
      trigger: 'After my morning coffee',
      identity: 'I am someone who works with purpose',
    ),
    (
      name: 'Close my day with a 5-minute review',
      trigger: 'Before I log off',
      identity: 'I am someone who reflects and improves',
    ),
    (
      name: 'Batch similar tasks together',
      trigger: 'When I plan my morning',
      identity: 'I am someone who works with purpose',
    ),
    (
      name: 'Clear my downloads folder',
      trigger: 'Before I shut down',
      identity: 'I am someone who keeps my systems tidy',
    ),
  ],
  'Mindfulness': [
    (
      name: 'Take 3 mindful bites at the start of a meal',
      trigger: 'When I begin eating',
      identity: 'I am fully present in my life',
    ),
    (
      name: 'Notice 5 things I can see',
      trigger: 'When I feel overwhelmed',
      identity: 'I am someone who returns to the present',
    ),
    (
      name: 'Feel my feet on the floor',
      trigger: 'When I stand up',
      identity: 'I am grounded in the present moment',
    ),
    (
      name: 'Take one conscious breath',
      trigger: 'When I unlock my phone',
      identity: 'I am someone who returns to the present',
    ),
    (
      name: 'Notice the temperature of the water',
      trigger: 'When I wash my hands',
      identity: 'I am fully present in my life',
    ),
    (
      name: 'Pause before I respond',
      trigger: 'During a conversation',
      identity: 'I am someone who acts with awareness',
    ),
    (
      name: 'Watch my breath for one minute',
      trigger: 'When I wait in line',
      identity: 'I am someone who returns to the present',
    ),
    (
      name: 'Name how I am feeling right now',
      trigger: 'When I notice a strong emotion',
      identity: 'I am in tune with how I feel',
    ),
    (
      name: 'Walk slowly and notice each step',
      trigger: 'On a short walk',
      identity: 'I am grounded in the present moment',
    ),
  ],
};
