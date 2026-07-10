import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/firebase/firestore_service.dart';
import '../models/user_profile.dart';

final firestoreServiceProvider = Provider<FirestoreService>(
  (_) => FirestoreService(),
);

final authStateProvider = StreamProvider<User?>(
  (ref) => FirebaseAuth.instance.authStateChanges(),
);

final currentUserProfileProvider = StreamProvider<UserProfile?>(
  (ref) {
    final authAsync = ref.watch(authStateProvider);
    return authAsync.when(
      data: (user) {
        if (user == null) return Stream.value(null);
        return ref.watch(firestoreServiceProvider).streamUserProfile(user.uid);
      },
      loading: () => Stream.value(null),
      error: (_, __) => Stream.value(null),
    );
  },
);

/// One-time silent migration: existing blueprint users get a fresh calibration
/// window anchored to rollout day.
Future<void> migrateBlueprintCalibrationStart(
  FirestoreService firestore,
  UserProfile profile,
  String uid,
) async {
  if (!profile.blueprintCompleted) return;
  if (profile.blueprintCalibrationStartedAt != null &&
      profile.blueprintCalibrationStartedAt!.isNotEmpty) {
    return;
  }
  try {
    await firestore.updateUserField(uid, {
      'blueprintCalibrationStartedAt': DateTime.now().toIso8601String(),
    });
  } catch (e) {
    debugPrint('migrateBlueprintCalibrationStart failed: $e');
  }
}

/// One-time silent migration: legacy completed users stored [onboardingStep] 5
/// under the old 5-step flow. Bump to 7 (current total step count) so
/// Firestore matches the new schema and [UserProfile.hasCompletedOnboarding]
/// continues to read them as complete. These users already completed
/// onboarding under the account-creation-time Terms/Privacy agreement, so
/// they are not retroactively routed through the new AI consent step.
Future<void> migrateLegacyOnboardingStep(
  FirestoreService firestore,
  UserProfile profile,
  String uid,
) async {
  if (profile.onboardingStep != 5) return;
  if (profile.mindsetBlueprintSummary.isEmpty) return;
  try {
    await firestore.updateUserField(uid, {'onboardingStep': 7});
  } catch (e) {
    debugPrint('migrateLegacyOnboardingStep failed: $e');
  }
}
