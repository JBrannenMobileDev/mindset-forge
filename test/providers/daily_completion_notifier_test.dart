import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mindsetforge/core/utils/app_date_utils.dart';
import 'package:mindsetforge/models/daily_completion.dart';
import 'package:mindsetforge/providers/auth_provider.dart';
import 'package:mindsetforge/providers/daily_completion_provider.dart';

import '../mocks/mock_firestore_service.dart';

// ── Helpers ───────────────────────────────────────────────────────────────────

/// Creates a container where auth returns null (persist is a no-op) so tests
/// can focus purely on the state mutation logic of [DailyCompletionNotifier].
ProviderContainer _makeContainer() {
  final mockFirestore = MockFirestoreService();
  return ProviderContainer(
    overrides: [
      firestoreServiceProvider.overrideWithValue(mockFirestore),
      // Null user → _persist no-ops; lets tests focus on state logic.
      authStateProvider.overrideWith((ref) => Stream.value(null)),
    ],
  );
}

// ── Tests ────────────────────────────────────────────────────────────────────

void main() {
  group('DailyCompletionNotifier', () {
    // ── toggle — required fields ──────────────────────────────────────────────

    group('toggle — state mutations', () {
      test('habitsCompleted: true sets field on state', () async {
        final container = _makeContainer();
        addTearDown(container.dispose);

        await container
            .read(dailyCompletionProvider.notifier)
            .toggle('habitsCompleted', true);

        expect(
            container.read(dailyCompletionProvider).habitsCompleted, isTrue);
      });

      test('habitsCompleted: false clears field on state', () async {
        final container = _makeContainer();
        addTearDown(container.dispose);

        final notifier = container.read(dailyCompletionProvider.notifier);
        await notifier.toggle('habitsCompleted', true);
        await notifier.toggle('habitsCompleted', false);

        expect(
            container.read(dailyCompletionProvider).habitsCompleted, isFalse);
      });

      // All 11 valid field names toggle their respective boolean correctly
      final fields = {
        'habitsCompleted': (DailyCompletion c) => c.habitsCompleted,
        'dayPlanned': (DailyCompletion c) => c.dayPlanned,
        'priorityActionsCompleted': (DailyCompletion c) =>
            c.priorityActionsCompleted,
        'affirmationsMorning': (DailyCompletion c) => c.affirmationsMorning,
        'affirmationsEvening': (DailyCompletion c) => c.affirmationsEvening,
        'futureSelfCompleted': (DailyCompletion c) => c.futureSelfCompleted,
        'journalCompleted': (DailyCompletion c) => c.journalCompleted,
        'chatCompleted': (DailyCompletion c) => c.chatCompleted,
        'identityRead': (DailyCompletion c) => c.identityRead,
        'gratitudeLogged': (DailyCompletion c) => c.gratitudeLogged,
        'evidenceLogged': (DailyCompletion c) => c.evidenceLogged,
      };

      for (final entry in fields.entries) {
        test('toggles ${entry.key} correctly', () async {
          final container = _makeContainer();
          addTearDown(container.dispose);

          final notifier = container.read(dailyCompletionProvider.notifier);
          await notifier.toggle(entry.key, true);
          expect(entry.value(container.read(dailyCompletionProvider)), isTrue);

          await notifier.toggle(entry.key, false);
          expect(entry.value(container.read(dailyCompletionProvider)), isFalse);
        });
      }
    });

    // ── completionTimes tracking ──────────────────────────────────────────────

    group('completionTimes', () {
      test('toggle(field, true) sets completionTimes entry', () async {
        final container = _makeContainer();
        addTearDown(container.dispose);

        await container
            .read(dailyCompletionProvider.notifier)
            .toggle('journalCompleted', true);

        final times =
            container.read(dailyCompletionProvider).completionTimes;
        expect(times.containsKey('journalCompleted'), isTrue);
        // Value should be a parseable ISO8601 string
        expect(
            DateTime.tryParse(times['journalCompleted']!), isNotNull);
      });

      test('toggle(field, false) removes completionTimes entry', () async {
        final container = _makeContainer();
        addTearDown(container.dispose);

        final notifier = container.read(dailyCompletionProvider.notifier);
        await notifier.toggle('journalCompleted', true);
        expect(container
            .read(dailyCompletionProvider)
            .completionTimes
            .containsKey('journalCompleted'), isTrue);

        await notifier.toggle('journalCompleted', false);
        expect(container
            .read(dailyCompletionProvider)
            .completionTimes
            .containsKey('journalCompleted'), isFalse);
      });
    });

    // ── unknown field ─────────────────────────────────────────────────────────

    test('toggle with unknown field leaves state unchanged', () async {
      final container = _makeContainer();
      addTearDown(container.dispose);

      final before = container.read(dailyCompletionProvider);
      await container
          .read(dailyCompletionProvider.notifier)
          .toggle('unknownField', true);
      final after = container.read(dailyCompletionProvider);

      // Core booleans must not have changed
      expect(after.habitsCompleted, before.habitsCompleted);
      expect(after.dayPlanned, before.dayPlanned);
      expect(after.affirmationsMorning, before.affirmationsMorning);
    });

    // ── initial state ─────────────────────────────────────────────────────────

    test('initial state is a DailyCompletion for today with all false', () {
      final container = _makeContainer();
      addTearDown(container.dispose);

      final state = container.read(dailyCompletionProvider);

      // The notifier keys on the 4 AM–4 AM "active day" so progress survives
      // the midnight–4 AM grace window instead of resetting at midnight.
      expect(state.date, AppDateUtils.todayStringWithGracePeriod());
      expect(state.completedCount, 0);
      expect(state.isPerfectDay, isFalse);
    });

    // ── multiple toggles compound ─────────────────────────────────────────────

    test('completing multiple fields increments completedCount', () async {
      final container = _makeContainer();
      addTearDown(container.dispose);

      final notifier = container.read(dailyCompletionProvider.notifier);
      await notifier.toggle('habitsCompleted', true);
      await notifier.toggle('dayPlanned', true);
      await notifier.toggle('affirmationsMorning', true);

      expect(container.read(dailyCompletionProvider).completedCount, 3);
    });

    test('completing all 8 required fields makes isPerfectDay true', () async {
      final container = _makeContainer();
      addTearDown(container.dispose);

      final notifier = container.read(dailyCompletionProvider.notifier);
      await notifier.toggle('habitsCompleted', true);
      await notifier.toggle('dayPlanned', true);
      await notifier.toggle('affirmationsMorning', true);
      await notifier.toggle('affirmationsEvening', true);
      await notifier.toggle('futureSelfCompleted', true);
      await notifier.toggle('journalCompleted', true);
      await notifier.toggle('chatCompleted', true);
      await notifier.toggle('identityRead', true);

      expect(container.read(dailyCompletionProvider).isPerfectDay, isTrue);
    });
  });
}
