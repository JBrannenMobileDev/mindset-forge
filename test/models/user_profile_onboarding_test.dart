import 'package:mindsetforge/models/user_profile.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('hasCompletedOnboarding', () {
    UserProfile profile({
      int onboardingStep = 0,
      String mindsetBlueprintSummary = '',
    }) {
      return UserProfile.create(
        uid: 'u1',
        email: 'a@b.com',
        displayName: 'Test',
      ).copyWith(
        onboardingStep: onboardingStep,
        mindsetBlueprintSummary: mindsetBlueprintSummary,
      );
    }

    test('new user with step 0 is incomplete', () {
      expect(profile().hasCompletedOnboarding, isFalse);
    });

    test('legacy completed user with step 5 and summary is complete', () {
      expect(
        profile(onboardingStep: 5, mindsetBlueprintSummary: 'summary').hasCompletedOnboarding,
        isTrue,
      );
    });

    test('new user mid-flow on step 5 without summary is incomplete', () {
      expect(profile(onboardingStep: 5).hasCompletedOnboarding, isFalse);
    });

    test('new user mid-flow on step 6 without summary is incomplete', () {
      expect(profile(onboardingStep: 6).hasCompletedOnboarding, isFalse);
    });

    test('new user finishing with step 7 is complete', () {
      expect(profile(onboardingStep: 7).hasCompletedOnboarding, isTrue);
    });
  });
}
