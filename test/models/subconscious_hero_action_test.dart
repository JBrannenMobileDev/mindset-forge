import 'package:flutter_test/flutter_test.dart';
import 'package:mindsetforge/models/daily_completion.dart';
import 'package:mindsetforge/models/subconscious_hero_action.dart';
import 'package:mindsetforge/models/user_profile.dart';

void main() {
  group('resolveSubconsciousHeroAction', () {
    UserProfile profile() => UserProfile.create(
          uid: 'u1',
          email: 'a@b.com',
          displayName: 'Test',
        );

    DailyCompletion completion({
      bool morning = false,
      bool evening = false,
      bool futureSelf = false,
    }) {
      return DailyCompletion(
        date: '2026-07-03',
        affirmationsMorning: morning,
        affirmationsEvening: evening,
        futureSelfCompleted: futureSelf,
      );
    }

    test('morning affirmations take priority when incomplete', () {
      final action = resolveSubconsciousHeroAction(
        profile(),
        completion(),
        now: DateTime(2026, 7, 3, 8),
      );

      expect(action.kind, SubconsciousHeroKind.morning);
      expect(action.field, 'affirmationsMorning');
      expect(action.buttonLabel, isNotNull);
    });

    test('future self is next after morning affirmations are done', () {
      final action = resolveSubconsciousHeroAction(
        profile(),
        completion(morning: true),
        now: DateTime(2026, 7, 3, 8),
      );

      expect(action.kind, SubconsciousHeroKind.futureSelf);
      expect(action.field, 'futureSelfCompleted');
    });

    test('evening affirmations surface in the evening window', () {
      final action = resolveSubconsciousHeroAction(
        profile(),
        completion(morning: true, futureSelf: true),
        now: DateTime(2026, 7, 3, 20),
      );

      expect(action.kind, SubconsciousHeroKind.evening);
      expect(action.field, 'affirmationsEvening');
    });

    test('transition period is on-track when morning and future self are done',
        () {
      final action = resolveSubconsciousHeroAction(
        profile(),
        completion(morning: true, futureSelf: true),
        now: DateTime(2026, 7, 3, 14),
      );

      expect(action.kind, SubconsciousHeroKind.onTrack);
      expect(action.buttonLabel, isNull);
    });

    test('all practices complete in evening window is on-track', () {
      final action = resolveSubconsciousHeroAction(
        profile(),
        completion(morning: true, evening: true, futureSelf: true),
        now: DateTime(2026, 7, 3, 21),
      );

      expect(action.kind, SubconsciousHeroKind.onTrack);
    });

    test('morning catch-up still surfaces in the evening window', () {
      final action = resolveSubconsciousHeroAction(
        profile(),
        completion(futureSelf: true),
        now: DateTime(2026, 7, 3, 20),
      );

      expect(action.kind, SubconsciousHeroKind.morning);
    });
  });
}
