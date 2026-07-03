import '../core/constants/app_strings.dart';
import 'daily_completion.dart';
import 'hero_action.dart';
import 'user_profile.dart';

/// Slim, denormalized snapshot of the dashboard hero ("right now" action),
/// shared with the iOS Home/Lock Screen widget (via App Group) and the Apple
/// Watch (via WatchConnectivity).
///
/// Pure data + pure derivation so the native side stays dumb and so the
/// state-resolution logic can be unit-tested without Flutter bindings. The
/// next-action fields come from the shared [resolveHeroAction] so the widget
/// and the in-app `TodayHeroCard` can never drift apart.
class WidgetPayload {
  /// Back-compatible status: `set_focus`, `focus_open`, `on_track`, or the new
  /// `morning` / `evening` routine states.
  final String state;

  /// The user's #1 focus text for today (empty when none set).
  final String focusText;
  final String focusDate; // yyyy-MM-dd
  final bool focusCompleted;
  final bool hasFocusToday;

  /// One of: `morning`, `transition`, `evening`.
  final String sessionPeriod;

  // ── Resolved next-action (mirrors the dashboard hero) ──────────────────────

  /// Win field (`journalCompleted`, `dayPlanned`, ...) or a synthetic id
  /// (`focus` / `setFocus` / `onTrack`). Drives the deep-link target.
  final String actionField;

  /// Uppercase eyebrow label (e.g. `MORNING SESSION`, `TODAY'S FOCUS`).
  final String sessionLabel;

  /// Prominent line shown on the widget (focus text, routine step, or prompt).
  final String headline;

  /// Secondary line under the headline (may be empty).
  final String subline;

  /// Accent bucket the native side maps to a colour:
  /// `morning` | `evening` | `focus` | `set_focus` | `done`.
  final String accentKind;

  /// True only when the action can be completed from the widget (Today's
  /// Focus). Everything else deep-links into the app.
  final bool canCompleteInWidget;

  /// Deep link fired when the widget is tapped.
  final String deepLink;

  final int streak;
  final int completedCount;
  final int totalCount;

  /// Last 7 days of streak qualification (oldest → newest, index 6 = today).
  /// `weekStreak[6]` reflects today's live qualification (5+ of 9 wins).
  final List<bool> weekStreak;

  /// Per-day 9/9 perfect flag aligned to [weekStreak] (index 6 = today).
  /// `perfect` always implies the day also qualifies; the native side renders
  /// these cells with the perfect-day treatment (gradient + star).
  final List<bool> weekPerfect;

  /// Single-char weekday letters aligned to [weekStreak] (e.g. M T W T F S S).
  final List<String> weekLabels;

  /// Nudge line shown beneath the 7-day chain in the focus-complete state.
  final String weekCaption;

  final String displayName;
  final String firstName;
  final String updatedAt; // ISO8601

  const WidgetPayload({
    required this.state,
    required this.focusText,
    required this.focusDate,
    required this.focusCompleted,
    required this.hasFocusToday,
    required this.sessionPeriod,
    required this.actionField,
    required this.sessionLabel,
    required this.headline,
    required this.subline,
    required this.accentKind,
    required this.canCompleteInWidget,
    required this.deepLink,
    required this.streak,
    required this.completedCount,
    required this.totalCount,
    required this.weekStreak,
    required this.weekPerfect,
    required this.weekLabels,
    required this.weekCaption,
    required this.displayName,
    required this.firstName,
    required this.updatedAt,
  });

  /// Empty/sign-in placeholder rendered when no profile is available.
  factory WidgetPayload.empty({DateTime? now}) {
    final at = now ?? DateTime.now();
    return WidgetPayload(
      state: 'set_focus',
      focusText: '',
      focusDate: '',
      focusCompleted: false,
      hasFocusToday: false,
      sessionPeriod: _sessionPeriodFor(at),
      actionField: 'setFocus',
      sessionLabel: AppStrings.heroFocusSessionLabel,
      headline: AppStrings.heroSetFocusLabel,
      subline: AppStrings.heroSetFocusSubtitle,
      accentKind: 'set_focus',
      canCompleteInWidget: false,
      deepLink: 'mindsetforge://focus',
      streak: 0,
      completedCount: 0,
      totalCount: DailyCompletion.totalCount,
      weekStreak: List<bool>.filled(7, false),
      weekPerfect: List<bool>.filled(7, false),
      weekLabels: _weekLabels(at),
      weekCaption: '',
      displayName: '',
      firstName: 'there',
      updatedAt: at.toIso8601String(),
    );
  }

  /// Derives the payload from the live profile and today's completion record.
  /// [now] is injectable for deterministic tests.
  factory WidgetPayload.fromProfile(
    UserProfile profile, {
    DailyCompletion? completion,
    DateTime? now,
  }) {
    final at = now ?? DateTime.now();
    final todayStr = _activeDayString(at);
    final dc = completion ?? _todayCompletion(profile, todayStr);

    final hasFocusToday = profile.dailyFocusAction.isNotEmpty &&
        profile.dailyFocusActionDate == todayStr;
    final focusComplete = profile.isDailyFocusComplete;

    final action = resolveHeroAction(profile, dc, now: at);

    // The widget leads with the actual focus text for the focus state; every
    // other state shows the resolver's title as the headline.
    final isFocusKind = action.kind == HeroActionKind.focus;
    final headline = isFocusKind ? action.subtitle : action.title;
    final subline = isFocusKind ? '' : action.subtitle;

    final weekStreak = _weekStreak(profile, dc, at);
    final weekPerfect = _weekPerfect(profile, dc, at);
    final weekCaption = dc.countsForStreak
        ? AppStrings.widgetStreakSafe
        : '${dc.completedCount}/${DailyCompletion.totalCount} today — '
            '${AppStrings.widgetStreakFinish}';

    return WidgetPayload(
      state: action.legacyState,
      focusText: hasFocusToday ? profile.dailyFocusAction : '',
      focusDate: profile.dailyFocusActionDate,
      focusCompleted: focusComplete,
      hasFocusToday: hasFocusToday,
      sessionPeriod: _sessionPeriodFor(at),
      actionField: action.field,
      sessionLabel: action.sessionLabel,
      headline: headline,
      subline: subline,
      accentKind: action.accentKind,
      canCompleteInWidget: action.actionable,
      deepLink: action.deepLink,
      streak: profile.currentStreak,
      completedCount: dc.completedCount,
      totalCount: DailyCompletion.totalCount,
      weekStreak: weekStreak,
      weekPerfect: weekPerfect,
      weekLabels: _weekLabels(at),
      weekCaption: weekCaption,
      displayName: profile.displayName,
      firstName: profile.firstName,
      updatedAt: at.toIso8601String(),
    );
  }

  static DailyCompletion _todayCompletion(UserProfile profile, String today) {
    return profile.dailyCompletions.firstWhere(
      (c) => c.date == today,
      orElse: () => DailyCompletion(date: today),
    );
  }

  static String _dateString(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  /// The grace-aware active day as a date (midnight–4 AM counts as prior day).
  static DateTime _activeDay(DateTime d) {
    final base = DateTime(d.year, d.month, d.day);
    return d.hour < 4 ? base.subtract(const Duration(days: 1)) : base;
  }

  /// The last 7 active days, oldest → newest (index 6 = today).
  static List<DateTime> _last7Days(DateTime at) {
    final today = _activeDay(at);
    return List.generate(7, (i) => today.subtract(Duration(days: 6 - i)));
  }

  /// Per-day streak qualification for the last 7 days. Today (index 6) uses the
  /// live completion record; prior days look up history. Mirrors the dashboard
  /// `_StreakStrip` so the widget and app never disagree.
  static List<bool> _weekStreak(
    UserProfile profile,
    DailyCompletion today,
    DateTime at,
  ) {
    final days = _last7Days(at);
    final todayKey = _dateString(days.last);
    return days.map((d) {
      final key = _dateString(d);
      if (key == todayKey) return today.countsForStreak;
      final c = profile.dailyCompletions.firstWhere(
        (x) => x.date == key,
        orElse: () => DailyCompletion(date: key),
      );
      return c.countsForStreak;
    }).toList();
  }

  /// Per-day 9/9 perfect status for the last 7 days. Today (index 6) uses the
  /// live completion record; prior days look up history. Mirrors the dashboard
  /// `_StreakStrip` perfect-day branch so the widget and app never disagree.
  static List<bool> _weekPerfect(
    UserProfile profile,
    DailyCompletion today,
    DateTime at,
  ) {
    final days = _last7Days(at);
    final todayKey = _dateString(days.last);
    return days.map((d) {
      final key = _dateString(d);
      if (key == todayKey) return today.isPerfectDay;
      final c = profile.dailyCompletions.firstWhere(
        (x) => x.date == key,
        orElse: () => DailyCompletion(date: key),
      );
      return c.isPerfectDay;
    }).toList();
  }

  /// Single-char weekday letters aligned to [_last7Days]. Locale-independent
  /// (DateTime.weekday: 1 = Mon … 7 = Sun) so it stays in sync with native.
  static List<String> _weekLabels(DateTime at) {
    const letters = ['M', 'T', 'W', 'T', 'F', 'S', 'S']; // Mon → Sun
    return _last7Days(at).map((d) => letters[d.weekday - 1]).toList();
  }

  /// The "active day" key (4 AM–4 AM): midnight–4 AM counts as the prior day so
  /// the widget's completion count and focus check don't reset at midnight
  /// while the session period is still evening. Mirrors
  /// `AppDateUtils.todayStringWithGracePeriod`.
  static String _activeDayString(DateTime d) =>
      _dateString(d.hour < 4 ? d.subtract(const Duration(days: 1)) : d);

  /// Matches `AppDateUtils.sessionPeriod`: morning 4–11, transition 12–16,
  /// evening otherwise (17–23 and 0–3).
  static String _sessionPeriodFor(DateTime d) {
    final hour = d.hour;
    if (hour >= 4 && hour < 12) return 'morning';
    if (hour >= 12 && hour < 17) return 'transition';
    return 'evening';
  }

  /// Convenience for the "complete" states (no CTA, success accent).
  bool get isDone => accentKind == 'done';

  Map<String, dynamic> toJson() => {
        'state': state,
        'focusText': focusText,
        'focusDate': focusDate,
        'focusCompleted': focusCompleted,
        'hasFocusToday': hasFocusToday,
        'sessionPeriod': sessionPeriod,
        'actionField': actionField,
        'sessionLabel': sessionLabel,
        'headline': headline,
        'subline': subline,
        'accentKind': accentKind,
        'canCompleteInWidget': canCompleteInWidget,
        'deepLink': deepLink,
        'streak': streak,
        'completedCount': completedCount,
        'totalCount': totalCount,
        'weekStreak': weekStreak,
        'weekPerfect': weekPerfect,
        'weekLabels': weekLabels,
        'weekCaption': weekCaption,
        'displayName': displayName,
        'firstName': firstName,
        'updatedAt': updatedAt,
      };

  factory WidgetPayload.fromJson(Map<String, dynamic> json) => WidgetPayload(
        state: json['state'] as String? ?? 'set_focus',
        focusText: json['focusText'] as String? ?? '',
        focusDate: json['focusDate'] as String? ?? '',
        focusCompleted: json['focusCompleted'] as bool? ?? false,
        hasFocusToday: json['hasFocusToday'] as bool? ?? false,
        sessionPeriod: json['sessionPeriod'] as String? ?? 'morning',
        actionField: json['actionField'] as String? ?? 'setFocus',
        sessionLabel: json['sessionLabel'] as String? ?? '',
        headline: json['headline'] as String? ?? '',
        subline: json['subline'] as String? ?? '',
        accentKind: json['accentKind'] as String? ?? 'set_focus',
        canCompleteInWidget: json['canCompleteInWidget'] as bool? ?? false,
        deepLink: json['deepLink'] as String? ?? 'mindsetforge://focus',
        streak: (json['streak'] as num?)?.toInt() ?? 0,
        completedCount: (json['completedCount'] as num?)?.toInt() ?? 0,
        totalCount:
            (json['totalCount'] as num?)?.toInt() ?? DailyCompletion.totalCount,
        weekStreak: (json['weekStreak'] as List?)
                ?.map((e) => e as bool? ?? false)
                .toList() ??
            const [],
        weekPerfect: (json['weekPerfect'] as List?)
                ?.map((e) => e as bool? ?? false)
                .toList() ??
            const [],
        weekLabels: (json['weekLabels'] as List?)
                ?.map((e) => e as String? ?? '')
                .toList() ??
            const [],
        weekCaption: json['weekCaption'] as String? ?? '',
        displayName: json['displayName'] as String? ?? '',
        firstName: json['firstName'] as String? ?? 'there',
        updatedAt: json['updatedAt'] as String? ?? '',
      );
}
