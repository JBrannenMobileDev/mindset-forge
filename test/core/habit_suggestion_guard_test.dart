import 'package:flutter_test/flutter_test.dart';
import 'package:mindsetforge/core/utils/habit_suggestion_guard.dart';
import 'package:mindsetforge/models/habit.dart';
import 'package:mindsetforge/models/user_profile.dart';

void main() {
  group('HabitSuggestionGuard.duplicatesBuiltInRoutine', () {
    test('flags identity statement reading', () {
      expect(
        HabitSuggestionGuard.duplicatesBuiltInRoutine({
          'name': 'Read your identity statement each morning',
          'trigger': 'After I wake up',
        }),
        isTrue,
      );
    });

    test('allows unrelated behavioral habits', () {
      expect(
        HabitSuggestionGuard.duplicatesBuiltInRoutine({
          'name': 'Take a 10-minute walk',
          'trigger': 'After lunch',
        }),
        isFalse,
      );
    });

    test('flags journal habits', () {
      expect(
        HabitSuggestionGuard.duplicatesBuiltInRoutine({
          'name': 'Write in my journal',
          'trigger': 'Before bed',
        }),
        isTrue,
      );
    });
  });

  group('HabitSuggestionGuard.duplicatesExistingHabit', () {
    test('flags matching active habit names', () {
      final profile = UserProfile.create(
        uid: 'u1',
        email: 'a@b.com',
        displayName: 'Alex',
      ).copyWith(
        habits: [
          Habit(
            id: 'h1',
            name: 'Meditate for 5 minutes',
            createdAt: DateTime(2026, 1, 1),
          ),
        ],
      );

      expect(
        HabitSuggestionGuard.duplicatesExistingHabit(
          {'name': 'Meditate for 5 minutes', 'trigger': 'After coffee'},
          profile,
        ),
        isTrue,
      );
      expect(
        HabitSuggestionGuard.duplicatesExistingHabit(
          {'name': 'Stretch for 2 minutes', 'trigger': 'After coffee'},
          profile,
        ),
        isFalse,
      );
    });
  });

  group('HabitSuggestionGuard.filterValid', () {
    test('removes built-in duplicates and keeps valid suggestions', () {
      final profile = UserProfile.create(
        uid: 'u1',
        email: 'a@b.com',
        displayName: 'Alex',
      );

      final filtered = HabitSuggestionGuard.filterValid(
        [
          {
            'name': 'Read identity statement aloud',
            'trigger': 'Each morning',
          },
          {
            'name': 'Review one financial goal',
            'trigger': 'After dinner',
          },
        ],
        profile,
      );

      expect(filtered.length, 1);
      expect(filtered.first['name'], 'Review one financial goal');
    });
  });
}
