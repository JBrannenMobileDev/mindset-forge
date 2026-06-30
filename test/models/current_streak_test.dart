import 'package:flutter_test/flutter_test.dart';
import 'package:mindsetforge/models/daily_completion.dart';
import 'package:mindsetforge/models/user_profile.dart';

void main() {
  group('UserProfile.currentStreak', () {
    String dateKey(DateTime d) =>
        '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

    // A completion for [day] with [wins] of the 9 required items set true.
    DailyCompletion day(DateTime date, int wins) {
      final flags = List<bool>.generate(9, (i) => i < wins);
      return DailyCompletion(
        date: dateKey(date),
        habitsCompleted: flags[0],
        dayPlanned: flags[1],
        focusCompleted: flags[2],
        affirmationsMorning: flags[3],
        affirmationsEvening: flags[4],
        futureSelfCompleted: flags[5],
        journalCompleted: flags[6],
        chatCompleted: flags[7],
        identityRead: flags[8],
      );
    }

    UserProfile profileWith(List<DailyCompletion> completions) {
      return UserProfile.create(
        uid: 'u1',
        email: 'a@b.com',
        displayName: 'Test',
      ).copyWith(dailyCompletions: completions);
    }

    final today = DateTime.now();
    DateTime ago(int days) => today.subtract(Duration(days: days));

    test('0 when there are no completions', () {
      expect(profileWith([]).currentStreak, 0);
    });

    test('an incomplete today keeps the streak earned through yesterday', () {
      // 4 qualifying days through yesterday, today started but only 2/8 wins.
      final profile = profileWith([
        day(ago(4), 5),
        day(ago(3), 6),
        day(ago(2), 5),
        day(ago(1), 7),
        day(ago(0), 2), // today, not yet qualifying
      ]);
      expect(profile.currentStreak, 4);
    });

    test('a qualifying today is included in the streak', () {
      final profile = profileWith([
        day(ago(2), 5),
        day(ago(1), 6),
        day(ago(0), 5), // today qualifies
      ]);
      expect(profile.currentStreak, 3);
    });

    test('counts a yesterday-anchored streak when no today record exists', () {
      final profile = profileWith([
        day(ago(3), 5),
        day(ago(2), 6),
        day(ago(1), 5),
        // no record for today yet
      ]);
      expect(profile.currentStreak, 3);
    });

    test('a sub-threshold yesterday breaks the streak (resets to 0)', () {
      // Yesterday is over and didn't qualify, so the streak is broken.
      final profile = profileWith([
        day(ago(3), 5),
        day(ago(2), 6),
        day(ago(1), 4), // yesterday failed
      ]);
      expect(profile.currentStreak, 0);
    });

    test('a calendar gap before today breaks the streak', () {
      // Today incomplete (skipped), then a gap on day-1 means nothing anchors
      // back to yesterday.
      final profile = profileWith([
        day(ago(3), 5),
        day(ago(2), 5),
        // gap on ago(1)
        day(ago(0), 2), // today, not yet qualifying
      ]);
      expect(profile.currentStreak, 0);
    });
  });
}
