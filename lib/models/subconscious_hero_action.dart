import '../core/constants/app_strings.dart';
import 'daily_completion.dart';
import 'user_profile.dart';

/// Which subconscious practice the Mindset hub hero should surface.
enum SubconsciousHeroKind { morning, evening, futureSelf, onTrack }

/// Resolved "do this now" action for the Mindset hub's practice hero.
class SubconsciousHeroAction {
  final SubconsciousHeroKind kind;

  /// Win field for session launches (`affirmationsMorning`, etc.).
  final String field;

  /// Uppercase eyebrow (e.g. `TODAY'S PRACTICE`, `MORNING SESSION`).
  final String sessionLabel;

  final String title;
  final String subtitle;

  /// Primary CTA label; null for the calm on-track state.
  final String? buttonLabel;

  const SubconsciousHeroAction({
    required this.kind,
    required this.field,
    required this.sessionLabel,
    required this.title,
    required this.subtitle,
    this.buttonLabel,
  });

  bool get isOnTrack => kind == SubconsciousHeroKind.onTrack;

  bool get isSessionOnly =>
      field == 'affirmationsMorning' || field == 'affirmationsEvening';
}

String _sessionPeriodFor(DateTime d) {
  final hour = d.hour;
  if (hour >= 4 && hour < 12) return 'morning';
  if (hour >= 12 && hour < 17) return 'transition';
  return 'evening';
}

/// Resolves the single subconscious practice hero for [profile] / [completion].
///
/// Priority: catch up morning affirmations → future self → evening affirmations
/// (evening window only) → calm on-track state when today's practices are done.
SubconsciousHeroAction resolveSubconsciousHeroAction(
  UserProfile profile,
  DailyCompletion completion, {
  DateTime? now,
}) {
  final at = now ?? DateTime.now();
  final period = _sessionPeriodFor(at);

  final morningDone = completion.affirmationsMorning;
  final eveningDone = completion.affirmationsEvening;
  final futureSelfDone = completion.futureSelfCompleted;

  if (!morningDone) {
    return const SubconsciousHeroAction(
      kind: SubconsciousHeroKind.morning,
      field: 'affirmationsMorning',
      sessionLabel: AppStrings.mindsetPracticeHeroLabel,
      title: AppStrings.mindsetPracticeHeroMorningTitle,
      subtitle: AppStrings.mindsetPracticeHeroMorningSubtitle,
      buttonLabel: AppStrings.mindsetPracticeHeroMorningButton,
    );
  }

  if (!futureSelfDone) {
    return const SubconsciousHeroAction(
      kind: SubconsciousHeroKind.futureSelf,
      field: 'futureSelfCompleted',
      sessionLabel: AppStrings.mindsetPracticeHeroLabel,
      title: AppStrings.mindsetPracticeHeroFutureSelfTitle,
      subtitle: AppStrings.mindsetPracticeHeroFutureSelfSubtitle,
      buttonLabel: AppStrings.mindsetPracticeHeroFutureSelfButton,
    );
  }

  if (!eveningDone && period == 'evening') {
    return const SubconsciousHeroAction(
      kind: SubconsciousHeroKind.evening,
      field: 'affirmationsEvening',
      sessionLabel: AppStrings.mindsetPracticeHeroLabel,
      title: AppStrings.mindsetPracticeHeroEveningTitle,
      subtitle: AppStrings.mindsetPracticeHeroEveningSubtitle,
      buttonLabel: AppStrings.mindsetPracticeHeroEveningButton,
    );
  }

  return const SubconsciousHeroAction(
    kind: SubconsciousHeroKind.onTrack,
    field: 'onTrack',
    sessionLabel: AppStrings.mindsetPracticeHeroLabel,
    title: AppStrings.mindsetPracticeOnTrackTitle,
    subtitle: AppStrings.mindsetPracticeOnTrackSubtitle,
  );
}
