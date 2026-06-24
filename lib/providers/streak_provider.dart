import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/utils/manifestation_scoring.dart';
import 'auth_provider.dart';

final streakProvider = Provider<int>((ref) {
  final profile = ref.watch(currentUserProfileProvider).valueOrNull;
  return profile?.currentStreak ?? 0;
});

final perfectDayCountProvider = Provider<int>((ref) {
  final profile = ref.watch(currentUserProfileProvider).valueOrNull;
  return profile?.perfectDayCount ?? 0;
});

final alignmentScoreProvider = Provider<double>((ref) {
  final profile = ref.watch(currentUserProfileProvider).valueOrNull;
  return profile != null ? ManifestationScoring.calculate(profile).overall : 50.0;
});
