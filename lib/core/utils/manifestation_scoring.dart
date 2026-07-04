import 'dart:math' as math;

import '../../models/user_profile.dart';
import '../../models/manifestation_alignment.dart';
import '../../models/goal.dart';

/// Computes manifestation alignment scores from real activity, replacing the
/// old manual self-rating. Pure and synchronous: depends only on the profile.
///
/// Mirrors the base44 pipeline (Subconscious, Thoughts, Actions, Results) but
/// uses an effective window of `min(windowDays, daysSinceSignup + 1)` so new
/// users are scored fairly against the days they have actually had the app,
/// rather than being penalized for days they could not have acted on.
abstract final class ManifestationScoring {
  static const int defaultWindowDays = 10;

  /// A day earns full Action credit once at least this fraction of active
  /// habits is completed; below the bar the day earns its exact fraction.
  static const double habitDayThreshold = 0.7;

  // How long a completed goal keeps full Results credit, scaled by goal length
  // so a big long-horizon win is honored far longer than a quick one. Beyond
  // the window the completion ages out of the average, so old wins can't mask a
  // neglected current list. Life goals never expire.
  static const int shortTermCreditDays = 30;
  static const int mediumTermCreditDays = 90;
  static const int longTermCreditDays = 180;

  /// Days a completed goal keeps full Results credit; null = never expires.
  static int? _completedGoalCreditDays(String goalType) => switch (goalType) {
        kGoalTypeShortTerm => shortTermCreditDays,
        kGoalTypeMediumTerm => mediumTermCreditDays,
        kGoalTypeLongTerm => longTermCreditDays,
        kGoalTypeLifeGoal => null,
        _ => longTermCreditDays,
      };

  /// Days since the account was created (0 on the signup day).
  static int daysSinceSignup(UserProfile p) {
    final created = DateTime(p.createdAt.year, p.createdAt.month, p.createdAt.day);
    final today = _graceAnchor();
    final diff = today.difference(created).inDays;
    return diff < 0 ? 0 : diff;
  }

  /// The current "active day" at midnight precision. Midnight–4 AM counts as
  /// the previous day so scoring keys match where daily wins are saved
  /// (`AppDateUtils.todayStringWithGracePeriod()`).
  static DateTime _graceAnchor() {
    final now = DateTime.now();
    final adjusted = now.hour < 4 ? now.subtract(const Duration(days: 1)) : now;
    return DateTime(adjusted.year, adjusted.month, adjusted.day);
  }

  /// True while the user is still inside the initial ramp-up window, during
  /// which scores reflect limited history.
  static bool isRampingUp(UserProfile p, {int windowDays = defaultWindowDays}) =>
      daysSinceSignup(p) < windowDays - 1;

  /// The number of days actually used as the scoring denominator basis.
  static int effectiveWindow(UserProfile p,
      {int windowDays = defaultWindowDays}) {
    final available = daysSinceSignup(p) + 1;
    return available < 1
        ? 1
        : (available > windowDays ? windowDays : available);
  }

  static ManifestationAlignment calculate(
    UserProfile p, {
    int windowDays = defaultWindowDays,
  }) {
    final window = effectiveWindow(p, windowDays: windowDays);
    final dates = _recentDateStrings(window);
    final todayKey = dates.isEmpty ? null : dates.first;

    // Index daily completions by date for O(1) lookup.
    final byDate = {for (final c in p.dailyCompletions) c.date: c};

    int affirmationDays = 0;
    int visualizationDays = 0;
    int journalDays = 0;
    int chatDays = 0;
    int priorityDays = 0;

    // Today's contribution, tracked separately so an in-progress day can only
    // lift a dimension's score, never drag it down (see [_graced] below).
    int todayAffirm = 0;
    int todayVis = 0;
    int todayJournal = 0;
    int todayChat = 0;
    int todayPriority = 0;

    for (final date in dates) {
      final c = byDate[date];
      if (c == null) continue;
      final isToday = date == todayKey;
      if (c.affirmationsMorning && c.affirmationsEvening) {
        affirmationDays++;
        if (isToday) todayAffirm++;
      }
      if (c.futureSelfCompleted) {
        visualizationDays++;
        if (isToday) todayVis++;
      }
      if (c.journalCompleted) {
        journalDays++;
        if (isToday) todayJournal++;
      }
      if (c.chatCompleted) {
        chatDays++;
        if (isToday) todayChat++;
      }
      if (c.priorityActionsCompleted) {
        priorityDays++;
        if (isToday) todayPriority++;
      }
    }

    // Habits: capped-proportional credit per day. A day earns the exact
    // fraction of active habits completed, capped to a full point once the
    // [habitDayThreshold] (70%) bar is met. This keeps partial days fair
    // (e.g. 2/3 = 0.67) without giving full credit away below the bar.
    //
    // 'weekly' habits are satisfied for every day of their calendar week
    // (Monday-start) once completed once that week, rather than needing a
    // completion on the exact day — matching their cadence instead of
    // silently expecting daily check-ins. See
    // [Habit.hasCompletionInPeriodContaining].
    final activeHabits = p.habits.where((h) => h.state == 'active').toList();
    double habitCredit = 0;
    double todayHabitCredit = 0;
    if (activeHabits.isNotEmpty) {
      for (final date in dates) {
        final parts = date.split('-');
        final y = int.parse(parts[0]);
        final m = int.parse(parts[1]);
        final d = int.parse(parts[2]);
        final dayDate = DateTime(y, m, d);
        final completed = activeHabits
            .where((h) => h.hasCompletionInPeriodContaining(dayDate))
            .length;
        final fraction = completed / activeHabits.length;
        final dayCredit = fraction >= habitDayThreshold ? 1.0 : fraction;
        habitCredit += dayCredit;
        if (date == todayKey) todayHabitCredit += dayCredit;
      }
    }

    double pct(num count, int denom) =>
        denom <= 0 ? 0 : (count / denom * 100).clamp(0, 100).toDouble();

    // Grace: score each window dimension both including and excluding today,
    // then take the max. While today is still in progress it can only raise
    // the score, never lower it, so scores don't sag every morning before the
    // user has had a chance to finish.
    final fullDenom = window * 2; // includes today
    final pastDenom = (window - 1) * 2; // excludes today
    double graced(num full, num todayPart) {
      final including = pct(full, fullDenom);
      if (pastDenom <= 0) return including; // first day: no baseline yet
      final excluding = pct(full - todayPart, pastDenom);
      return math.max(excluding, including);
    }

    final subconscious =
        graced(affirmationDays + visualizationDays, todayAffirm + todayVis);
    final thought = graced(journalDays + chatDays, todayJournal + todayChat);
    final action = graced(habitCredit + priorityDays, todayHabitCredit + todayPriority);

    // Results: active goals contribute their current progress; completed goals
    // contribute a full 100 while within their goal-length credit window. This
    // means finishing a goal never lowers the score (it swaps partial progress
    // for a held 100), yet stale wins age out so the score reflects what the
    // user is actually producing now.
    final anchor = _graceAnchor();
    final contributions = <double>[];
    for (final g in p.goals) {
      if (g.status == 'active') {
        // Derived from the milestone checklist when present, so Results tracks
        // real completion rather than a self-reported slider.
        contributions.add(g.derivedProgress);
      } else if (g.status == 'completed') {
        final creditDays = _completedGoalCreditDays(g.goalType);
        final completedAt = g.completedAt;
        // Permanent (life goal), or legacy completions with no date, always
        // count; otherwise credit lasts for the goal-length window.
        final withinWindow = creditDays == null ||
            completedAt == null ||
            anchor
                    .difference(DateTime(
                        completedAt.year, completedAt.month, completedAt.day))
                    .inDays <=
                creditDays;
        if (withinWindow) contributions.add(100.0);
      }
    }
    final results = contributions.isEmpty
        ? 0.0
        : (contributions.reduce((a, b) => a + b) / contributions.length)
            .clamp(0, 100)
            .toDouble();

    return ManifestationAlignment(
      subconscious: subconscious,
      thought: thought,
      action: action,
      results: results,
      recordedAt: DateTime.now(),
    );
  }

  /// The most recent [count] date strings (yyyy-MM-dd), today first. Anchored
  /// to the 4 AM grace period so keys match saved daily-win records.
  static List<String> _recentDateStrings(int count) {
    final base = _graceAnchor();
    return List.generate(count, (i) {
      final d = base.subtract(Duration(days: i));
      return '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
    });
  }
}
