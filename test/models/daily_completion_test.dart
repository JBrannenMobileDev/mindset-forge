import 'package:flutter_test/flutter_test.dart';
import 'package:mindsetforge/models/daily_completion.dart';

void main() {
  group('DailyCompletion', () {
    // ── isPerfectDay ──────────────────────────────────────────────────────────

    group('isPerfectDay', () {
      test('true when all 8 required items are done', () {
        const completion = DailyCompletion(
          date: '2026-01-15',
          habitsCompleted: true,
          dayPlanned: true,
          affirmationsMorning: true,
          affirmationsEvening: true,
          futureSelfCompleted: true,
          journalCompleted: true,
          chatCompleted: true,
          identityRead: true,
        );
        expect(completion.isPerfectDay, isTrue);
      });

      test('false when one required item is missing', () {
        const completion = DailyCompletion(
          date: '2026-01-15',
          habitsCompleted: true,
          dayPlanned: true,
          affirmationsMorning: true,
          affirmationsEvening: true,
          futureSelfCompleted: true,
          journalCompleted: false, // missing
          chatCompleted: true,
          identityRead: true,
        );
        expect(completion.isPerfectDay, isFalse);
      });

      test('bonus items do not affect isPerfectDay', () {
        // All 8 required true + both bonus false → still perfect
        const completion = DailyCompletion(
          date: '2026-01-15',
          habitsCompleted: true,
          dayPlanned: true,
          affirmationsMorning: true,
          affirmationsEvening: true,
          futureSelfCompleted: true,
          journalCompleted: true,
          chatCompleted: true,
          identityRead: true,
          gratitudeLogged: false,
          evidenceLogged: false,
        );
        expect(completion.isPerfectDay, isTrue);
      });

      test('false for default (all-false) completion', () {
        const completion = DailyCompletion(date: '2026-01-15');
        expect(completion.isPerfectDay, isFalse);
      });
    });

    // ── completedCount ────────────────────────────────────────────────────────

    group('completedCount', () {
      test('0 when nothing is done', () {
        const completion = DailyCompletion(date: '2026-01-15');
        expect(completion.completedCount, 0);
      });

      test('counts only required items', () {
        const completion = DailyCompletion(
          date: '2026-01-15',
          habitsCompleted: true,
          dayPlanned: true,
          // 2 required done, bonus items also true
          gratitudeLogged: true,
          evidenceLogged: true,
        );
        expect(completion.completedCount, 2);
      });

      test('8 when all required are done', () {
        const completion = DailyCompletion(
          date: '2026-01-15',
          habitsCompleted: true,
          dayPlanned: true,
          affirmationsMorning: true,
          affirmationsEvening: true,
          futureSelfCompleted: true,
          journalCompleted: true,
          chatCompleted: true,
          identityRead: true,
        );
        expect(completion.completedCount, DailyCompletion.totalCount);
      });
    });

    // ── completionPercent ─────────────────────────────────────────────────────

    group('completionPercent', () {
      test('0.0 when nothing done', () {
        const completion = DailyCompletion(date: '2026-01-15');
        expect(completion.completionPercent, 0.0);
      });

      test('0.5 when 4 of 8 done', () {
        const completion = DailyCompletion(
          date: '2026-01-15',
          habitsCompleted: true,
          dayPlanned: true,
          affirmationsMorning: true,
          affirmationsEvening: true,
        );
        expect(completion.completionPercent, 0.5);
      });

      test('1.0 when all 8 done', () {
        const completion = DailyCompletion(
          date: '2026-01-15',
          habitsCompleted: true,
          dayPlanned: true,
          affirmationsMorning: true,
          affirmationsEvening: true,
          futureSelfCompleted: true,
          journalCompleted: true,
          chatCompleted: true,
          identityRead: true,
        );
        expect(completion.completionPercent, 1.0);
      });
    });

    // ── totalCount constant ───────────────────────────────────────────────────

    test('totalCount is 8', () {
      expect(DailyCompletion.totalCount, 8);
    });

    // ── fromJson ──────────────────────────────────────────────────────────────

    group('fromJson', () {
      test('all fields default to false when missing', () {
        final completion = DailyCompletion.fromJson({'date': '2026-01-15'});
        expect(completion.habitsCompleted, isFalse);
        expect(completion.dayPlanned, isFalse);
        expect(completion.affirmationsMorning, isFalse);
        expect(completion.affirmationsEvening, isFalse);
        expect(completion.futureSelfCompleted, isFalse);
        expect(completion.journalCompleted, isFalse);
        expect(completion.chatCompleted, isFalse);
        expect(completion.identityRead, isFalse);
        expect(completion.gratitudeLogged, isFalse);
        expect(completion.evidenceLogged, isFalse);
      });

      test('legacy: dayPlanned falls back to priorityActionsCompleted', () {
        final json = {
          'date': '2026-01-15',
          'priorityActionsCompleted': true,
          // no dayPlanned key
        };
        final completion = DailyCompletion.fromJson(json);
        expect(completion.dayPlanned, isTrue);
        expect(completion.priorityActionsCompleted, isTrue);
      });

      test('dayPlanned takes precedence over priorityActionsCompleted fallback', () {
        final json = {
          'date': '2026-01-15',
          'dayPlanned': false,
          'priorityActionsCompleted': true,
        };
        final completion = DailyCompletion.fromJson(json);
        expect(completion.dayPlanned, isFalse);
      });

      test('completionTimes round-trips correctly', () {
        final json = {
          'date': '2026-01-15',
          'completionTimes': {'habitsCompleted': '2026-01-15T08:00:00.000Z'},
        };
        final completion = DailyCompletion.fromJson(json);
        expect(completion.completionTimes['habitsCompleted'], isNotNull);
      });

      test('round-trip preserves all fields', () {
        const original = DailyCompletion(
          date: '2026-01-15',
          habitsCompleted: true,
          dayPlanned: true,
          priorityActionsCompleted: true,
          affirmationsMorning: true,
          affirmationsEvening: false,
          futureSelfCompleted: true,
          journalCompleted: false,
          chatCompleted: true,
          identityRead: true,
          gratitudeLogged: true,
          evidenceLogged: false,
          completionTimes: {'habitsCompleted': '2026-01-15T08:00:00.000Z'},
        );

        final restored = DailyCompletion.fromJson(original.toJson());

        expect(restored.date, original.date);
        expect(restored.habitsCompleted, original.habitsCompleted);
        expect(restored.dayPlanned, original.dayPlanned);
        expect(restored.affirmationsMorning, original.affirmationsMorning);
        expect(restored.affirmationsEvening, original.affirmationsEvening);
        expect(restored.futureSelfCompleted, original.futureSelfCompleted);
        expect(restored.journalCompleted, original.journalCompleted);
        expect(restored.chatCompleted, original.chatCompleted);
        expect(restored.identityRead, original.identityRead);
        expect(restored.gratitudeLogged, original.gratitudeLogged);
        expect(restored.evidenceLogged, original.evidenceLogged);
        expect(restored.completionTimes, original.completionTimes);
      });
    });

    // ── forToday ──────────────────────────────────────────────────────────────

    test('forToday creates completion with today\'s date string', () {
      final now = DateTime.now();
      final expected =
          '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
      final completion = DailyCompletion.forToday();
      expect(completion.date, expected);
      expect(completion.completedCount, 0);
    });

    // ── copyWith ──────────────────────────────────────────────────────────────

    test('copyWith changes only specified fields', () {
      const original = DailyCompletion(date: '2026-01-15', habitsCompleted: false);
      final updated = original.copyWith(habitsCompleted: true);
      expect(updated.habitsCompleted, isTrue);
      expect(updated.date, original.date);
    });
  });
}
