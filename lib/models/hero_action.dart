import '../core/constants/app_strings.dart';
import 'daily_completion.dart';
import 'user_profile.dart';

/// The single, time-aware "right now" action surfaced by both the dashboard
/// hero (`TodayHeroCard`) and the home-screen widget / watch (`WidgetPayload`).
///
/// This resolver is the one source of truth for that decision so the in-app
/// hero and the widget can never drift apart. It is pure Dart (no Flutter /
/// Firebase imports) so the logic stays unit-testable.

/// Plain, icon-free descriptor of a daily-win checklist item. Mirrors the
/// `WinItem` list in `daily_wins_shared.dart` (which carries Flutter `IconData`)
/// but stays in the model layer.
class _WinItem {
  final String field;
  final String label;
  final String subtitle;
  final bool isBonus;
  final bool sessionOnly;

  const _WinItem(
    this.field,
    this.label,
    this.subtitle, {
    this.isBonus = false,
    this.sessionOnly = false,
  });
}

const _morningWins = [
  _WinItem('identityRead', 'Identity', 'Read who you\'re becoming'),
  _WinItem('affirmationsMorning', 'Affirmations', 'Start Day', sessionOnly: true),
  _WinItem('futureSelfCompleted', 'Future Self', 'Practice'),
  _WinItem('journalCompleted', 'Journal', 'Prime Mind'),
  _WinItem('dayPlanned', 'Plan Day', 'Select Focus'),
  _WinItem('gratitudeLogged', 'Gratitude', 'Something you\'re grateful for',
      isBonus: true),
];

const _eveningWins = [
  _WinItem('affirmationsEvening', 'Affirmations', 'End Day', sessionOnly: true),
  _WinItem('chatCompleted', 'Coach Chat', 'Check In'),
  _WinItem('evidenceLogged', 'Evidence Log', 'Act like your future self',
      isBonus: true),
];

bool _completionField(DailyCompletion c, String field) {
  return switch (field) {
    'habitsCompleted' => c.habitsCompleted,
    'dayPlanned' => c.dayPlanned,
    'priorityActionsCompleted' => c.priorityActionsCompleted,
    'affirmationsMorning' => c.affirmationsMorning,
    'affirmationsEvening' => c.affirmationsEvening,
    'futureSelfCompleted' => c.futureSelfCompleted,
    'journalCompleted' => c.journalCompleted,
    'chatCompleted' => c.chatCompleted,
    'identityRead' => c.identityRead,
    'gratitudeLogged' => c.gratitudeLogged,
    'evidenceLogged' => c.evidenceLogged,
    _ => false,
  };
}

_WinItem? _firstIncomplete(DailyCompletion c, List<_WinItem> items) {
  for (final w in items) {
    if (!_completionField(c, w.field)) return w;
  }
  return null;
}

/// Which arc of the day the resolved action belongs to. Drives the accent
/// colour and copy on the native side.
enum HeroActionKind { morning, evening, focus, setFocus, onTrack }

/// The resolved hero action — a value object both the dashboard and widget map
/// onto their own visuals.
class HeroAction {
  final HeroActionKind kind;

  /// Win field (`journalCompleted`, `dayPlanned`, ...) for routine steps, or a
  /// synthetic id (`focus` / `setFocus` / `onTrack`) otherwise.
  final String field;

  /// Uppercase session/eyebrow label (e.g. `MORNING SESSION`, `TODAY'S FOCUS`).
  final String sessionLabel;

  /// Card title (dashboard-facing copy: routine step name, "Today's #1 Focus",
  /// "Set Your Focus", or the calm on-track line).
  final String title;

  /// Secondary line under the title (routine hint, the focus text, or prompt).
  final String subtitle;

  /// True only when the action can be completed from the widget itself
  /// (Today's Focus). Everything else deep-links into the app.
  final bool actionable;

  const HeroAction({
    required this.kind,
    required this.field,
    required this.sessionLabel,
    required this.title,
    required this.subtitle,
    required this.actionable,
  });

  bool get isFocus =>
      kind == HeroActionKind.focus || kind == HeroActionKind.setFocus;

  /// True for the affirmation steps, which open a session rather than toggle.
  bool get isSessionOnly =>
      field == 'affirmationsMorning' || field == 'affirmationsEvening';

  /// Native accent bucket: `morning` | `evening` | `focus` | `set_focus` | `done`.
  String get accentKind => switch (kind) {
        HeroActionKind.morning => 'morning',
        HeroActionKind.evening => 'evening',
        HeroActionKind.focus => 'focus',
        HeroActionKind.setFocus => 'set_focus',
        HeroActionKind.onTrack => 'done',
      };

  /// Back-compatible `state` string consumed by older native code paths.
  String get legacyState => switch (kind) {
        HeroActionKind.morning => 'morning',
        HeroActionKind.evening => 'evening',
        HeroActionKind.focus => 'focus_open',
        HeroActionKind.setFocus => 'set_focus',
        HeroActionKind.onTrack => 'on_track',
      };

  /// Deep link fired when the widget (or a non-interactive action) is tapped.
  /// Focus / set-focus keep the existing `focus` host (opens Plan Day when no
  /// focus is set); routine steps carry their field; on-track just opens.
  String get deepLink => switch (kind) {
        HeroActionKind.focus ||
        HeroActionKind.setFocus =>
          'mindsetforge://focus',
        HeroActionKind.morning ||
        HeroActionKind.evening =>
          'mindsetforge://action/$field',
        HeroActionKind.onTrack => 'mindsetforge://dashboard',
      };
}

String _dateString(DateTime d) =>
    '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

/// The "active day" key (4 AM–4 AM): midnight–4 AM counts as the prior day so
/// the focus-set check doesn't flip to false at midnight while the session
/// period is still evening. Mirrors `AppDateUtils.todayStringWithGracePeriod`.
String _activeDayString(DateTime d) =>
    _dateString(d.hour < 4 ? d.subtract(const Duration(days: 1)) : d);

/// Matches `AppDateUtils.sessionPeriod`: morning 4–11, transition 12–16,
/// evening otherwise (17–23 and 0–3).
String _sessionPeriodFor(DateTime d) {
  final hour = d.hour;
  if (hour >= 4 && hour < 12) return 'morning';
  if (hour >= 12 && hour < 17) return 'transition';
  return 'evening';
}

/// Resolves the single hero action for [profile] / [completion] at [now].
///
/// Mirrors `TodayHeroCard._resolveHero` exactly (including the journal-
/// preference placement and the morning → evening → focus → set-focus → on-
/// track branch order) so the widget and the in-app hero stay in lockstep.
HeroAction resolveHeroAction(
  UserProfile profile,
  DailyCompletion completion, {
  DateTime? now,
}) {
  final at = now ?? DateTime.now();
  final todayStr = _activeDayString(at);
  final period = _sessionPeriodFor(at);

  final hasFocusToday = profile.dailyFocusAction.isNotEmpty &&
      profile.dailyFocusActionDate == todayStr;
  final focusComplete = profile.dailyFocusActionCompleted;

  // ── Journal placement based on user preference ──────────────────────────
  final journalPref = profile.journalPreference;
  const journalItem = _WinItem('journalCompleted', 'Journal', 'Prime Mind');
  final morningWithJournal = journalPref == 'morning' || journalPref == 'both';
  final eveningWithJournal = journalPref == 'evening' || journalPref == 'both';

  final planDayItem = _WinItem(
    'dayPlanned',
    'Plan Day',
    hasFocusToday ? 'Focus Set' : 'Select Focus',
  );

  final effectiveMorning = [
    ..._morningWins.where(
        (w) => w.field != 'journalCompleted' && w.field != 'dayPlanned'),
    planDayItem,
    if (morningWithJournal) journalItem,
  ];
  final effectiveEvening = [
    if (eveningWithJournal) journalItem,
    ..._eveningWins,
  ];

  final morningRequired = effectiveMorning.where((w) => !w.isBonus).toList();
  final eveningRequired = effectiveEvening.where((w) => !w.isBonus).toList();

  final morningDone =
      morningRequired.every((w) => _completionField(completion, w.field));
  final eveningDone =
      eveningRequired.every((w) => _completionField(completion, w.field));

  // Morning phase, routine unfinished → next morning item.
  if (period == 'morning' && !morningDone) {
    final item = _firstIncomplete(completion, morningRequired)!;
    return HeroAction(
      kind: HeroActionKind.morning,
      field: item.field,
      sessionLabel: AppStrings.morningSessionHero,
      title: item.label,
      subtitle: item.subtitle,
      actionable: false,
    );
  }

  // Evening phase, routine unfinished → next evening item.
  if (period == 'evening' && !eveningDone) {
    final item = _firstIncomplete(completion, eveningRequired)!;
    return HeroAction(
      kind: HeroActionKind.evening,
      field: item.field,
      sessionLabel: AppStrings.eveningSessionHero,
      title: item.label,
      subtitle: item.subtitle,
      actionable: false,
    );
  }

  // Otherwise the day belongs to Today's Focus.
  if (hasFocusToday && !focusComplete) {
    return HeroAction(
      kind: HeroActionKind.focus,
      field: 'focus',
      sessionLabel: AppStrings.heroFocusSessionLabel,
      title: AppStrings.focusCardTitle,
      subtitle: profile.dailyFocusAction,
      actionable: true,
    );
  }

  if (!hasFocusToday) {
    return const HeroAction(
      kind: HeroActionKind.setFocus,
      field: 'setFocus',
      sessionLabel: AppStrings.heroFocusSessionLabel,
      title: AppStrings.heroSetFocusLabel,
      subtitle: AppStrings.heroSetFocusSubtitle,
      actionable: false,
    );
  }

  // Focus complete → calm "on track" / evening wrap-up state.
  final calmTitle = (period == 'evening' && eveningDone)
      ? AppStrings.eveningRoutineComplete
      : AppStrings.heroOnTrackLabel;
  return HeroAction(
    kind: HeroActionKind.onTrack,
    field: 'onTrack',
    sessionLabel: AppStrings.heroFocusSessionLabel,
    title: calmTitle,
    subtitle: AppStrings.heroOnTrackSubtitle,
    actionable: false,
  );
}
