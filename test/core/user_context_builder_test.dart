import 'package:flutter_test/flutter_test.dart';
import 'package:mindsetforge/core/ai/user_context_builder.dart';
import 'package:mindsetforge/models/mindset_blueprint.dart';
import 'package:mindsetforge/models/user_profile.dart';

void main() {
  group('UserContextBuilder.coreBlock', () {
    UserProfile profile({bool blueprintCompleted = false}) {
      return UserProfile.create(
        uid: 'u1',
        email: 'a@b.com',
        displayName: 'Alex',
      ).copyWith(
        blueprintCompleted: blueprintCompleted,
        mindsetBlueprint: const MindsetBlueprint(
          confidence: 5,
          discipline: 5,
          abundanceThinking: 5,
          resilience: 5,
          decisiveness: 5,
        ),
        identitySituation: 'Starting a new career',
        identityQualities: const ['focused', 'resilient'],
        limitingBeliefs: const ["I'm not good enough"],
      );
    }

    test('omits numeric blueprint scores when blueprint is not completed', () {
      final block = UserContextBuilder.coreBlock(profile());

      expect(block, contains('Not yet self-assessed'));
      expect(block, isNot(contains('Mindset Blueprint Scores (1–10)')));
      expect(block, isNot(contains('Confidence: 5.0')));
      expect(block, isNot(contains('Overall Average: 5.0')));
    });

    test('includes numeric blueprint scores when blueprint is completed', () {
      final block = UserContextBuilder.coreBlock(
        profile(blueprintCompleted: true).copyWith(
          mindsetBlueprint: const MindsetBlueprint(
            confidence: 7,
            discipline: 6,
            abundanceThinking: 8,
            resilience: 5,
            decisiveness: 9,
          ),
        ),
      );

      expect(block, contains('Mindset Blueprint Scores (1–10)'));
      expect(block, contains('Confidence: 7.0'));
      expect(block, contains('Discipline: 6.0'));
      expect(block, contains('Overall Average: 7.0'));
      expect(block, isNot(contains('Not yet self-assessed')));
    });

    test('onboarding reveal context uses fallback for default blueprint', () {
      // Mirrors StepAiSummary._buildTempProfile() during onboarding:
      // blueprintCompleted stays false and MindsetBlueprint() defaults to 5.0.
      final onboardingProfile = UserProfile.create(
        uid: 'u1',
        email: 'a@b.com',
        displayName: 'Alex',
      ).copyWith(
        identitySituation: 'Career transition',
        identityQualities: const ['disciplined'],
        limitingBeliefs: const ['Success is not for me'],
      );

      final block = UserContextBuilder.coreBlock(onboardingProfile);

      expect(onboardingProfile.blueprintCompleted, isFalse);
      expect(block, contains('Not yet self-assessed'));
      expect(block, isNot(contains('Confidence: 5.0')));
    });
  });
}
