import 'package:flutter_riverpod/flutter_riverpod.dart';
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
  return profile?.manifestationAlignment.overall ?? 50.0;
});
