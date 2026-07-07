/// Built-in daily rituals tracked natively by the app (via [DailyCompletion]).
///
/// Pure Dart — no Flutter/Firebase imports. Aligned with the morning/evening
/// win lists in `hero_action.dart`. AI habit suggestions must not duplicate
/// these; users already get credit for them through the dashboard daily wins.
library;

/// A native app routine with human-readable copy and keyword hints for dedup.
typedef BuiltInRoutine = ({
  String label,
  String description,
  List<String> excludeKeywords,
});

const List<BuiltInRoutine> kBuiltInAppRoutines = [
  (
    label: 'Identity statement reading',
    description: 'Dashboard Identity card — read who you\'re becoming',
    excludeKeywords: [
      'identity statement',
      'read identity',
      'read who you',
      'who you\'re becoming',
    ],
  ),
  (
    label: 'Morning affirmations',
    description: 'Start Day affirmation session',
    excludeKeywords: ['morning affirmation', 'start day', 'affirmation session'],
  ),
  (
    label: 'Evening affirmations',
    description: 'End Day affirmation session',
    excludeKeywords: ['evening affirmation', 'end day'],
  ),
  (
    label: 'Affirmations (general)',
    description: 'Any affirmation repetition practice',
    excludeKeywords: ['affirmation', 'affirmations', 'repeat affirmation'],
  ),
  (
    label: 'Future Self visualization',
    description: 'Future Self practice session',
    excludeKeywords: [
      'future self',
      'future-self',
      'visualization',
      'visualize',
      'visualise',
    ],
  ),
  (
    label: 'Journal entry',
    description: 'Smart journaling in the Journal tab',
    excludeKeywords: ['journal', 'journaling', 'journal entry', 'write in journal'],
  ),
  (
    label: 'Coach chat check-in',
    description: 'Chat with your AI coach',
    excludeKeywords: [
      'coach chat',
      'chat with coach',
      'talk to coach',
      'check in with coach',
    ],
  ),
  (
    label: 'Plan Day',
    description: 'Select daily focus and priorities',
    excludeKeywords: ['plan day', 'plan my day', 'daily priorities', 'select focus'],
  ),
  (
    label: 'Today\'s focus action',
    description: 'Complete the #1 focus action for the day',
    excludeKeywords: ['focus action', '#1 focus', 'top priority action', 'daily focus'],
  ),
  (
    label: 'Gratitude log',
    description: 'Log something you\'re grateful for',
    excludeKeywords: ['gratitude', 'grateful for', 'thankful for'],
  ),
  (
    label: 'Evidence log',
    description: 'Log evidence of acting like your future self',
    excludeKeywords: ['evidence log', 'evidence of growth', 'log evidence'],
  ),
];
