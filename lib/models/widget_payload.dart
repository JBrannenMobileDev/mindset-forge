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
    final focusComplete = profile.dailyFocusActionCompleted;

    final action = resolveHeroAction(profile, dc, now: at);

    // The widget leads with the actual focus text for the focus state; every
    // other state shows the resolver's title as the headline.
    final isFocusKind = action.kind == HeroActionKind.focus;
    final headline = isFocusKind ? action.subtitle : action.title;
    final subline = isFocusKind ? '' : action.subtitle;

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
        displayName: json['displayName'] as String? ?? '',
        firstName: json['firstName'] as String? ?? 'there',
        updatedAt: json['updatedAt'] as String? ?? '',
      );
}
