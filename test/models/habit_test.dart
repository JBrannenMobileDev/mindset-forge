import 'package:flutter_test/flutter_test.dart';
import 'package:mindsetforge/models/habit.dart';

void main() {
  group('Habit', () {
    final createdAt = DateTime(2025, 1, 1);

    // ── activeDay (4 AM–4 AM grace window) ───────────────────────────────────

    group('activeDay', () {
      test('midnight–4 AM maps to the previous calendar day', () {
        expect(Habit.activeDay(DateTime(2026, 6, 28, 0, 30)),
            DateTime(2026, 6, 27));
        expect(Habit.activeDay(DateTime(2026, 6, 28, 3, 59)),
            DateTime(2026, 6, 27));
      });

      test('4 AM onward maps to the same calendar day', () {
        expect(Habit.activeDay(DateTime(2026, 6, 28, 4, 0)),
            DateTime(2026, 6, 28));
        expect(Habit.activeDay(DateTime(2026, 6, 28, 23, 0)),
            DateTime(2026, 6, 28));
      });

      test('an 11 PM completion and a 12:30 AM "now" share one active day', () {
        // Late-night session: checked at 11 PM, viewed at 12:30 AM next calendar
        // day — both belong to the same 4 AM–4 AM active day, so the habit must
        // still read as completed instead of resetting at midnight.
        expect(Habit.activeDay(DateTime(2026, 6, 27, 23, 0)),
            Habit.activeDay(DateTime(2026, 6, 28, 0, 30)));
      });

      test('a 4:30 AM "now" rolls over to the new active day', () {
        expect(Habit.activeDay(DateTime(2026, 6, 27, 23, 0)),
            isNot(Habit.activeDay(DateTime(2026, 6, 28, 4, 30))));
      });
    });

    // ── isCompletedToday ─────────────────────────────────────────────────────

    group('isCompletedToday', () {
      test('true when lastCompletedDate is today', () {
        final now = DateTime.now();
        final habit = Habit(
          id: '1',
          name: 'Meditate',
          lastCompletedDate: DateTime(now.year, now.month, now.day, 8, 0),
          createdAt: createdAt,
        );
        expect(habit.isCompletedToday, isTrue);
      });

      test('false when lastCompletedDate is yesterday', () {
        final yesterday = DateTime.now().subtract(const Duration(days: 1));
        final habit = Habit(
          id: '1',
          name: 'Meditate',
          lastCompletedDate: DateTime(yesterday.year, yesterday.month, yesterday.day),
          createdAt: createdAt,
        );
        expect(habit.isCompletedToday, isFalse);
      });

      test('false when lastCompletedDate is null', () {
        final habit = Habit(id: '1', name: 'Meditate', createdAt: createdAt);
        expect(habit.isCompletedToday, isFalse);
      });
    });

    // ── currentStreak ────────────────────────────────────────────────────────

    group('currentStreak', () {
      test('returns 0 for empty history', () {
        final habit = Habit(id: '1', name: 'H', createdAt: createdAt);
        expect(habit.currentStreak, 0);
      });

      test('counts consecutive days including today', () {
        final today = DateTime.now();
        final yesterday = today.subtract(const Duration(days: 1));
        final twoDaysAgo = today.subtract(const Duration(days: 2));

        final habit = Habit(
          id: '1',
          name: 'H',
          completionHistory: [
            DateTime(twoDaysAgo.year, twoDaysAgo.month, twoDaysAgo.day, 9),
            DateTime(yesterday.year, yesterday.month, yesterday.day, 9),
            DateTime(today.year, today.month, today.day, 9),
          ],
          createdAt: createdAt,
        );
        expect(habit.currentStreak, 3);
      });

      test('streak resets at a 2-day gap', () {
        // The algorithm allows a 1-day grace gap but breaks on a 2-day gap.
        // today + yesterday = 2 days; four-days-ago creates a 2-day gap from yesterday.
        final today = DateTime.now();
        final yesterday = today.subtract(const Duration(days: 1));
        final fourDaysAgo = today.subtract(const Duration(days: 4));

        final habit = Habit(
          id: '1',
          name: 'H',
          completionHistory: [
            DateTime(fourDaysAgo.year, fourDaysAgo.month, fourDaysAgo.day),
            DateTime(yesterday.year, yesterday.month, yesterday.day),
            DateTime(today.year, today.month, today.day),
          ],
          createdAt: createdAt,
        );
        // today + yesterday = 2; four-days-ago is more than 1-day gap from yesterday
        expect(habit.currentStreak, 2);
      });

      test('streak of 1 when only completed today', () {
        final today = DateTime.now();
        final habit = Habit(
          id: '1',
          name: 'H',
          completionHistory: [DateTime(today.year, today.month, today.day)],
          createdAt: createdAt,
        );
        expect(habit.currentStreak, 1);
      });

      test('multiple completions on same day count as one streak day', () {
        final today = DateTime.now();
        final yesterday = today.subtract(const Duration(days: 1));
        final habit = Habit(
          id: '1',
          name: 'H',
          completionHistory: [
            DateTime(yesterday.year, yesterday.month, yesterday.day, 8),
            DateTime(yesterday.year, yesterday.month, yesterday.day, 20),
            DateTime(today.year, today.month, today.day, 9),
          ],
          createdAt: createdAt,
        );
        expect(habit.currentStreak, 2);
      });
    });

    // ── fromJson / toJson ────────────────────────────────────────────────────

    group('fromJson', () {
      test('round-trip preserves all fields', () {
        final now = DateTime.now();
        final original = Habit(
          id: 'h1',
          name: 'Meditate',
          trigger: 'After coffee',
          frequency: 'daily',
          identityReinforces: 'I am calm',
          state: 'active',
          lastCompletedDate: now,
          completionHistory: [now.subtract(const Duration(days: 1)), now],
          createdAt: createdAt,
          reminderEnabled: true,
          reminderMinutes: 7 * 60 + 30,
        );

        final restored = Habit.fromJson(original.toJson());

        expect(restored.id, original.id);
        expect(restored.name, original.name);
        expect(restored.trigger, original.trigger);
        expect(restored.frequency, original.frequency);
        expect(restored.identityReinforces, original.identityReinforces);
        expect(restored.state, original.state);
        expect(restored.completionHistory.length, 2);
        expect(restored.lastCompletedDate?.day, original.lastCompletedDate?.day);
        expect(restored.reminderEnabled, isTrue);
        expect(restored.reminderMinutes, 7 * 60 + 30);
      });

      test('invalid completion history entries are filtered out', () {
        final json = {
          'id': '1',
          'name': 'H',
          'completionHistory': ['2026-01-10T00:00:00.000', 'bad-date', '2026-01-11T00:00:00.000'],
          'createdAt': createdAt.toIso8601String(),
        };
        final habit = Habit.fromJson(json);
        expect(habit.completionHistory.length, 2);
      });

      test('missing fields get safe defaults', () {
        final habit = Habit.fromJson({'id': '1', 'name': 'H'});
        expect(habit.trigger, '');
        expect(habit.frequency, 'daily');
        expect(habit.state, 'active');
        expect(habit.lastCompletedDate, isNull);
        expect(habit.completionHistory, isEmpty);
        expect(habit.reminderEnabled, isFalse);
        expect(habit.reminderMinutes, Habit.defaultReminderMinutes);
      });
    });

    // ── weekly frequency (cadence-aware completion/streak) ──────────────────

    group('weekly frequency', () {
      // A safe mid-day hour so constructed dates round-trip through the 4 AM
      // grace period unchanged (real completions always carry a genuine
      // wall-clock hour; only synthetic hour-0 test dates would get
      // reinterpreted as the prior day by `activeDay`).
      DateTime atNoon(DateTime d) => DateTime(d.year, d.month, d.day, 12);

      test('isCompletedToday is true once completed anywhere in the current week', () {
        final now = DateTime.now();
        final weekStart = atNoon(Habit.activeWeekStart(now));
        final habit = Habit(
          id: '1',
          name: 'Weekly review',
          frequency: 'weekly',
          lastCompletedDate: weekStart,
          createdAt: createdAt,
        );
        expect(habit.isCompletedToday, isTrue);
      });

      test('isCompletedToday is false once the last completion was in a prior week', () {
        final now = DateTime.now();
        final lastWeek =
            atNoon(Habit.activeWeekStart(now).subtract(const Duration(days: 7)));
        final habit = Habit(
          id: '1',
          name: 'Weekly review',
          frequency: 'weekly',
          lastCompletedDate: lastWeek,
          createdAt: createdAt,
        );
        expect(habit.isCompletedToday, isFalse);
      });

      test('currentStreak counts consecutive weeks, not consecutive days', () {
        final now = DateTime.now();
        final thisWeek = atNoon(Habit.activeWeekStart(now));
        final lastWeek = thisWeek.subtract(const Duration(days: 7));
        final twoWeeksAgo = thisWeek.subtract(const Duration(days: 14));

        final habit = Habit(
          id: '1',
          name: 'Weekly review',
          frequency: 'weekly',
          completionHistory: [twoWeeksAgo, lastWeek, thisWeek],
          createdAt: createdAt,
        );
        expect(habit.currentStreak, 3);
      });

      test('currentStreak breaks on a skipped week', () {
        final now = DateTime.now();
        final thisWeek = atNoon(Habit.activeWeekStart(now));
        final threeWeeksAgo = thisWeek.subtract(const Duration(days: 21));

        final habit = Habit(
          id: '1',
          name: 'Weekly review',
          frequency: 'weekly',
          completionHistory: [threeWeeksAgo, thisWeek],
          createdAt: createdAt,
        );
        expect(habit.currentStreak, 1);
      });

      test('multiple completions within the same week count as one streak week', () {
        final now = DateTime.now();
        final thisWeek = atNoon(Habit.activeWeekStart(now));
        final habit = Habit(
          id: '1',
          name: 'Weekly review',
          frequency: 'weekly',
          completionHistory: [
            thisWeek,
            thisWeek.add(const Duration(days: 2)),
          ],
          createdAt: createdAt,
        );
        expect(habit.currentStreak, 1);
      });
    });
  });
}
