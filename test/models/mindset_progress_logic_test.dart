import 'package:flutter_test/flutter_test.dart';
import 'package:mindsetforge/core/utils/mindset_progress_logic.dart';
import 'package:mindsetforge/models/mindset_item_progress.dart';
import 'package:mindsetforge/models/user_profile.dart';
import 'package:mindsetforge/models/deep_dive.dart';
import 'package:mindsetforge/models/mindset_blueprint.dart';

UserProfile _profile({
  List<MindsetItemProgress> beliefProgress = const [],
  List<MindsetItemProgress> fearProgress = const [],
  bool blueprintEvolutionReady = false,
  String? lastExcavationAt,
}) {
  return UserProfile(
    uid: 'u1',
    email: 'a@b.com',
    displayName: 'Test User',
    mindsetBlueprint: const MindsetBlueprint(),
    originalMindsetBaseline: const MindsetBlueprint(),
    deepDive: DeepDive.initial(),
    beliefProgress: beliefProgress,
    fearProgress: fearProgress,
    blueprintEvolutionReady: blueprintEvolutionReady,
    lastExcavationAt: lastExcavationAt,
    blueprintCompleted: true,
    createdAt: DateTime(2026, 1, 1),
  );
}

void main() {
  final now = DateTime(2026, 2, 1);
  const thresholds = MindsetProgressThresholds();

  group('canPromoteToOvercome', () {
    test('single journal tag does not promote belief to overcome', () {
      final item = MindsetItemProgress(
        id: '1',
        text: 'I am not enough',
        kind: 'belief',
        status: 'softening',
        addedAt: now.subtract(const Duration(days: 20)).toIso8601String(),
        journalSignalDays: 1,
        coachCorroborated: false,
      );

      expect(
        canPromoteToOvercome(
          item: item,
          thresholds: thresholds,
          now: now,
        ),
        isFalse,
      );
    });

    test('belief promotes only with journal days and coach corroboration', () {
      final item = MindsetItemProgress(
        id: '1',
        text: 'I am not enough',
        kind: 'belief',
        status: 'softening',
        addedAt: now.subtract(const Duration(days: 20)).toIso8601String(),
        journalSignalDays: 2,
        coachCorroborated: true,
      );

      expect(
        canPromoteToOvercome(
          item: item,
          thresholds: thresholds,
          now: now,
        ),
        isTrue,
      );
    });

    test('fear requires higher distinct-day threshold', () {
      final youngFear = MindsetItemProgress(
        id: '2',
        text: 'Fear of Failure',
        kind: 'fear',
        status: 'softening',
        addedAt: now.subtract(const Duration(days: 20)).toIso8601String(),
        journalSignalDays: 2,
      );

      final readyFear = youngFear.copyWith(journalSignalDays: 3);

      expect(
        canPromoteToOvercome(
          item: youngFear,
          thresholds: thresholds,
          now: now,
        ),
        isFalse,
      );
      expect(
        canPromoteToOvercome(
          item: readyFear,
          thresholds: thresholds,
          now: now,
        ),
        isTrue,
      );
    });
  });

  group('UserProfile getters', () {
    test('overcomeBeliefs and hasBlueprintEvolutionReady', () {
      final profile = _profile(
        blueprintEvolutionReady: true,
        beliefProgress: const [
          MindsetItemProgress(
            id: '1',
            text: 'Old belief',
            kind: 'belief',
            status: 'overcome',
            addedAt: '2026-01-01',
          ),
        ],
      );

      expect(profile.overcomeBeliefs.length, 1);
      expect(profile.overcomeBeliefs.first.text, 'Old belief');
      expect(profile.hasBlueprintEvolutionReady, isTrue);
    });
  });

  group('isBlueprintEvolutionReady', () {
    test('requires minimum overcome count and share', () {
      final notReady = _profile(
        beliefProgress: const [
          MindsetItemProgress(
            id: '1',
            text: 'A',
            kind: 'belief',
            status: 'overcome',
            addedAt: '2026-01-01',
          ),
          MindsetItemProgress(
            id: '2',
            text: 'B',
            kind: 'belief',
            status: 'active',
            addedAt: '2026-01-01',
          ),
          MindsetItemProgress(
            id: '3',
            text: 'C',
            kind: 'belief',
            status: 'active',
            addedAt: '2026-01-01',
          ),
        ],
      );

      expect(
        isBlueprintEvolutionReady(
          beliefProgress: notReady.beliefProgress,
          fearProgress: notReady.fearProgress,
          blueprintCompleted: true,
          alreadyReady: false,
          lastExcavationAt: null,
          activeDaysPastWeek: 4,
          now: now,
        ),
        isFalse,
      );
    });

    test('respects excavation cooldown', () {
      final items = List.generate(
        3,
        (i) => MindsetItemProgress(
          id: '$i',
          text: 'Belief $i',
          kind: 'belief',
          status: i < 2 ? 'overcome' : 'active',
          addedAt: '2026-01-01',
        ),
      );

      expect(
        isBlueprintEvolutionReady(
          beliefProgress: items,
          fearProgress: const [],
          blueprintCompleted: true,
          alreadyReady: false,
          lastExcavationAt: now.subtract(const Duration(days: 5)).toIso8601String(),
          activeDaysPastWeek: 4,
          now: now,
        ),
        isFalse,
      );
    });
  });
}
