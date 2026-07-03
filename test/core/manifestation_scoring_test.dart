import 'package:flutter_test/flutter_test.dart';
import 'package:mindsetforge/core/utils/manifestation_scoring.dart';
import 'package:mindsetforge/models/daily_completion.dart';
import 'package:mindsetforge/models/goal.dart';
import 'package:mindsetforge/models/habit.dart';
import 'package:mindsetforge/models/user_profile.dart';

void main() {
  group('ManifestationScoring grace (today can only help, never hurt)', () {
    // Match the scoring module's 4 AM grace anchor so test date keys line up
    // with the "today" the calculator uses regardless of wall-clock time.
    DateTime graceAnchor() {
      final now = DateTime.now();
      final a = now.hour < 4 ? now.subtract(const Duration(days: 1)) : now;
      return DateTime(a.year, a.month, a.day);
    }

    final anchor = graceAnchor();
    DateTime ago(int days) => anchor.subtract(Duration(days: days));
    String dateKey(DateTime d) =>
        '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

    // Profile with a fixed creation date so the full 10-day window is active
    // (ramp-up cleared). Signup 30 days back guarantees window == 10.
    UserProfile profileWith(
      List<DailyCompletion> completions, {
      List<Habit> habits = const [],
    }) {
      return UserProfile.create(
        uid: 'u1',
        email: 'a@b.com',
        displayName: 'Test',
      ).copyWith(
        dailyCompletions: completions,
        habits: habits,
        createdAt: ago(30),
      );
    }

    // Nine past days (yesterday..9 days ago) that each earn one subconscious
    // point via a completed morning+evening affirmation. Today is left empty.
    List<DailyCompletion> steadyAffirmationPast() => [
          for (var i = 1; i <= 9; i++)
            DailyCompletion(
              date: dateKey(ago(i)),
              affirmationsMorning: true,
              affirmationsEvening: true,
            ),
        ];

    test('empty today does not drop a dimension below its baseline', () {
      // Baseline = 9 affirmation points over the excluding-today denominator
      // (18) = 50%. Including an empty today would dilute to 45%; grace keeps 50.
      final profile = profileWith(steadyAffirmationPast());
      final subconscious =
          ManifestationScoring.calculate(profile).subconscious;
      expect(subconscious, closeTo(50.0, 0.001));
    });

    test('completing today lifts the score above the baseline', () {
      final withToday = [
        ...steadyAffirmationPast(),
        DailyCompletion(
          date: dateKey(ago(0)),
          affirmationsMorning: true,
          affirmationsEvening: true,
          futureSelfCompleted: true,
        ),
      ];
      final subconscious =
          ManifestationScoring.calculate(profileWith(withToday)).subconscious;
      // 11 points / 20 = 55%, which beats the 50% baseline.
      expect(subconscious, greaterThan(50.0));
      expect(subconscious, closeTo(55.0, 0.001));
    });

    test('a partial today never reads below the baseline', () {
      // Only one of the two subconscious sub-items done today.
      final partialAffirmation = [
        ...steadyAffirmationPast(),
        DailyCompletion(
          date: dateKey(ago(0)),
          affirmationsMorning: true,
          affirmationsEvening: true,
        ),
      ];
      final partialVisualization = [
        ...steadyAffirmationPast(),
        DailyCompletion(
          date: dateKey(ago(0)),
          futureSelfCompleted: true,
        ),
      ];
      expect(
        ManifestationScoring.calculate(profileWith(partialAffirmation))
            .subconscious,
        greaterThanOrEqualTo(50.0),
      );
      expect(
        ManifestationScoring.calculate(profileWith(partialVisualization))
            .subconscious,
        greaterThanOrEqualTo(50.0),
      );
    });

    test('touching one dimension today leaves the others at their baseline',
        () {
      // Past: affirmations every day (subconscious baseline) and a priority
      // action on 5 of 9 days (a modest action baseline). One active habit,
      // never completed in the past.
      final habit = Habit(
        id: 'h1',
        name: 'Read',
        createdAt: ago(30),
      );
      final past = [
        for (var i = 1; i <= 9; i++)
          DailyCompletion(
            date: dateKey(ago(i)),
            affirmationsMorning: true,
            affirmationsEvening: true,
            priorityActionsCompleted: i <= 5,
          ),
      ];

      final emptyToday = profileWith(past, habits: [habit]);
      final baseline = ManifestationScoring.calculate(emptyToday);

      // Now the user completes only an Action item today (a priority action and
      // the habit) — nothing in the subconscious/thought dimensions.
      final actionHabit = habit.copyWith(completionHistory: [ago(0)]);
      final actedToday = profileWith(
        [
          ...past,
          DailyCompletion(
            date: dateKey(ago(0)),
            priorityActionsCompleted: true,
          ),
        ],
        habits: [actionHabit],
      );
      final acted = ManifestationScoring.calculate(actedToday);

      // Action rises; the untouched dimensions are unchanged.
      expect(acted.action, greaterThan(baseline.action));
      expect(acted.subconscious, closeTo(baseline.subconscious, 0.001));
      expect(acted.thought, closeTo(baseline.thought, 0.001));
    });

    test('overall score does not dip in the morning', () {
      final baseline = ManifestationScoring.calculate(
        profileWith(steadyAffirmationPast()),
      ).overall;
      // Same history, but now today exists as an all-false record (as it would
      // right after the day rolls over). Overall must not drop.
      final withEmptyToday = ManifestationScoring.calculate(
        profileWith([
          ...steadyAffirmationPast(),
          DailyCompletion(date: dateKey(ago(0))),
        ]),
      ).overall;
      expect(withEmptyToday, closeTo(baseline, 0.001));
    });

    test('brand-new user (day 1) has no baseline and builds up from today', () {
      // Signup today => window == 1 => pastDenom <= 0 => include-today path.
      final freshEmpty = UserProfile.create(
        uid: 'u2',
        email: 'c@d.com',
        displayName: 'Fresh',
      ).copyWith(
        createdAt: anchor,
        dailyCompletions: [DailyCompletion(date: dateKey(ago(0)))],
      );
      expect(
        ManifestationScoring.calculate(freshEmpty).subconscious,
        0.0,
      );

      final freshActed = UserProfile.create(
        uid: 'u2',
        email: 'c@d.com',
        displayName: 'Fresh',
      ).copyWith(
        createdAt: anchor,
        dailyCompletions: [
          DailyCompletion(
            date: dateKey(ago(0)),
            affirmationsMorning: true,
            affirmationsEvening: true,
            futureSelfCompleted: true,
          ),
        ],
      );
      // window == 1 => denom 2, both sub-items done => 100%.
      expect(
        ManifestationScoring.calculate(freshActed).subconscious,
        closeTo(100.0, 0.001),
      );
    });
  });

  group('ManifestationScoring Results (recency-aware)', () {
    // Match the scoring module's grace anchor (midnight, with the 4 AM rule) so
    // completedAt day-diffs in tests line up with the calculator.
    DateTime graceAnchor() {
      final now = DateTime.now();
      final a = now.hour < 4 ? now.subtract(const Duration(days: 1)) : now;
      return DateTime(a.year, a.month, a.day);
    }

    final anchor = graceAnchor();
    DateTime ago(int days) => anchor.subtract(Duration(days: days));

    var seq = 0;
    Goal goal({
      required String goalType,
      required String status,
      double progress = 0.0,
      DateTime? completedAt,
    }) {
      seq++;
      return Goal(
        id: 'g$seq',
        title: 'Goal $seq',
        category: 'personal',
        goalType: goalType,
        targetDate: anchor.add(const Duration(days: 90)),
        progressPercent: progress,
        status: status,
        completedAt: completedAt,
        createdAt: ago(200),
      );
    }

    UserProfile profileWithGoals(List<Goal> goals) {
      return UserProfile.create(
        uid: 'u1',
        email: 'a@b.com',
        displayName: 'Test',
      ).copyWith(goals: goals, createdAt: ago(200));
    }

    double results(List<Goal> goals) =>
        ManifestationScoring.calculate(profileWithGoals(goals)).results;

    test('active-only goals average their progress', () {
      expect(
        results([
          goal(goalType: kGoalTypeShortTerm, status: 'active', progress: 40),
          goal(goalType: kGoalTypeShortTerm, status: 'active', progress: 60),
        ]),
        closeTo(50.0, 0.001),
      );
    });

    test('completing a goal does not lower Results and never crashes to 0', () {
      final active = [
        goal(goalType: kGoalTypeShortTerm, status: 'active', progress: 80),
      ];
      final completed = [
        goal(
          goalType: kGoalTypeShortTerm,
          status: 'completed',
          progress: 100,
          completedAt: anchor,
        ),
      ];
      expect(results(active), closeTo(80.0, 0.001));
      // Single-goal completion holds at 100 rather than dropping to 0.
      expect(results(completed), closeTo(100.0, 0.001));
      expect(results(completed), greaterThanOrEqualTo(results(active)));
    });

    test('a short-term win ages out after its 30-day window', () {
      // Completed 45 days ago (aged out) alongside one active goal at 20 => the
      // stale win is excluded, so only the active goal counts.
      expect(
        results([
          goal(
            goalType: kGoalTypeShortTerm,
            status: 'completed',
            progress: 100,
            completedAt: ago(45),
          ),
          goal(goalType: kGoalTypeShortTerm, status: 'active', progress: 20),
        ]),
        closeTo(20.0, 0.001),
      );
    });

    test('a long-term win is credited far longer than a short one', () {
      // 100 days ago: still inside the 180-day long-term window.
      expect(
        results([
          goal(
            goalType: kGoalTypeLongTerm,
            status: 'completed',
            progress: 100,
            completedAt: ago(100),
          ),
        ]),
        closeTo(100.0, 0.001),
      );
      // 200 days ago: past the window => aged out => empty pool => 0.
      expect(
        results([
          goal(
            goalType: kGoalTypeLongTerm,
            status: 'completed',
            progress: 100,
            completedAt: ago(200),
          ),
        ]),
        closeTo(0.0, 0.001),
      );
    });

    test('a completed life goal is credited permanently', () {
      expect(
        results([
          goal(
            goalType: kGoalTypeLifeGoal,
            status: 'completed',
            progress: 100,
            completedAt: ago(400),
          ),
        ]),
        closeTo(100.0, 0.001),
      );
    });

    test('old wins cannot mask a neglected current list', () {
      // Several short-term wins from 60 days ago (all aged out) plus two fresh
      // active goals barely started => Results reflects the low active average.
      expect(
        results([
          for (var i = 0; i < 4; i++)
            goal(
              goalType: kGoalTypeShortTerm,
              status: 'completed',
              progress: 100,
              completedAt: ago(60),
            ),
          goal(goalType: kGoalTypeLongTerm, status: 'active', progress: 10),
          goal(goalType: kGoalTypeLongTerm, status: 'active', progress: 10),
        ]),
        closeTo(10.0, 0.001),
      );
    });
  });
}
