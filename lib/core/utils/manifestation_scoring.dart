import '../../models/user_profile.dart';
import '../../models/manifestation_alignment.dart';

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

  /// Days since the account was created (0 on the signup day).
  static int daysSinceSignup(UserProfile p) {
    final created = DateTime(p.createdAt.year, p.createdAt.month, p.createdAt.day);
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final diff = today.difference(created).inDays;
    return diff < 0 ? 0 : diff;
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

    // Index daily completions by date for O(1) lookup.
    final byDate = {for (final c in p.dailyCompletions) c.date: c};

    int affirmationDays = 0;
    int visualizationDays = 0;
    int journalDays = 0;
    int chatDays = 0;
    int priorityDays = 0;

    for (final date in dates) {
      final c = byDate[date];
      if (c == null) continue;
      if (c.affirmationsMorning && c.affirmationsEvening) affirmationDays++;
      if (c.futureSelfCompleted) visualizationDays++;
      if (c.journalCompleted) journalDays++;
      if (c.chatCompleted) chatDays++;
      if (c.priorityActionsCompleted) priorityDays++;
    }

    // Habits: capped-proportional credit per day. A day earns the exact
    // fraction of active habits completed, capped to a full point once the
    // [habitDayThreshold] (70%) bar is met. This keeps partial days fair
    // (e.g. 2/3 = 0.67) without giving full credit away below the bar.
    final activeHabits = p.habits.where((h) => h.state == 'active').toList();
    double habitCredit = 0;
    if (activeHabits.isNotEmpty) {
      for (final date in dates) {
        final parts = date.split('-');
        final y = int.parse(parts[0]);
        final m = int.parse(parts[1]);
        final d = int.parse(parts[2]);
        final completed = activeHabits.where((h) {
          return h.completionHistory.any(
            (t) => t.year == y && t.month == m && t.day == d,
          );
        }).length;
        final fraction = completed / activeHabits.length;
        habitCredit += fraction >= habitDayThreshold ? 1.0 : fraction;
      }
    }

    final twoW = window * 2;
    double pct(num count, int denom) =>
        denom <= 0 ? 0 : (count / denom * 100).clamp(0, 100).toDouble();

    final subconscious = pct(affirmationDays + visualizationDays, twoW);
    final thought = pct(journalDays + chatDays, twoW);
    final action = pct(habitCredit + priorityDays, twoW);

    final activeGoals =
        p.goals.where((g) => g.status == 'active').toList();
    final results = activeGoals.isEmpty
        ? 0.0
        : (activeGoals
                    .map((g) => g.progressPercent)
                    .reduce((a, b) => a + b) /
                activeGoals.length)
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

  /// The most recent [count] date strings (yyyy-MM-dd), today first.
  static List<String> _recentDateStrings(int count) {
    final now = DateTime.now();
    return List.generate(count, (i) {
      final d = now.subtract(Duration(days: i));
      return '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
    });
  }
}
