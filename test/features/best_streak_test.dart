import 'package:flutter_test/flutter_test.dart';
import 'package:mindsetforge/models/daily_completion.dart';
import 'package:mindsetforge/features/dashboard/widgets/daily_wins_shared.dart';

void main() {
  group('bestStreak', () {
    // Builds a completion for [date] with [wins] of the 8 required items set.
    DailyCompletion day(String date, int wins) {
      final flags = List<bool>.generate(8, (i) => i < wins);
      return DailyCompletion(
        date: date,
        habitsCompleted: flags[0],
        dayPlanned: flags[1],
        affirmationsMorning: flags[2],
        affirmationsEvening: flags[3],
        futureSelfCompleted: flags[4],
        journalCompleted: flags[5],
        chatCompleted: flags[6],
        identityRead: flags[7],
      );
    }

    test('0 for no completions', () {
      expect(bestStreak([]), 0);
    });

    test('ignores days below the streak threshold', () {
      // Three consecutive days, each with only 4/8 wins → no qualifying day.
      final completions = [
        day('2026-01-15', 4),
        day('2026-01-16', 4),
        day('2026-01-17', 4),
      ];
      expect(bestStreak(completions), 0);
    });

    test('counts consecutive days at or above the threshold', () {
      final completions = [
        day('2026-01-15', 5),
        day('2026-01-16', 6),
        day('2026-01-17', 8),
      ];
      expect(bestStreak(completions), 3);
    });

    test('sub-threshold day breaks the run', () {
      // 2 qualifying, 1 sub-threshold (resets), then 3 qualifying → best is 3.
      final completions = [
        day('2026-01-15', 5),
        day('2026-01-16', 5),
        day('2026-01-17', 4), // breaks
        day('2026-01-18', 6),
        day('2026-01-19', 7),
        day('2026-01-20', 8),
      ];
      expect(bestStreak(completions), 3);
    });

    test('calendar gap breaks the run even when both days qualify', () {
      final completions = [
        day('2026-01-15', 5),
        day('2026-01-16', 5),
        // gap on the 17th
        day('2026-01-18', 5),
      ];
      expect(bestStreak(completions), 2);
    });
  });
}
