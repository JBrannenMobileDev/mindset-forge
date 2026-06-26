import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/services/analytics_service.dart';
import '../core/utils/app_date_utils.dart';
import '../models/future_self_setup.dart';
import '../models/future_self_completion.dart';
import '../models/user_profile.dart';
import 'auth_provider.dart';
import 'daily_completion_provider.dart';

/// Owns the Future Self practice setup and completion history. The setup is the
/// visualization half of the Subconscious (Foundation) layer; completions feed
/// `visualizationDays` in manifestation scoring via the `futureSelfCompleted`
/// daily flag.
class FutureSelfNotifier extends StateNotifier<FutureSelfSetup?> {
  final Ref _ref;

  FutureSelfNotifier(this._ref) : super(null);

  void _loadFromProfile(UserProfile? profile) {
    state = profile?.futureSelfSetup;
  }

  /// Saves (creates or refines) the practice setup, including its script.
  Future<void> saveSetup(FutureSelfSetup setup) async {
    state = setup;
    final uid = _ref.read(authStateProvider).valueOrNull?.uid;
    if (uid == null) return;
    await _ref.read(firestoreServiceProvider).updateUserField(uid, {
      'futureSelfSetup': setup.toJson(),
    });
  }

  /// Persists a generated script onto the existing setup (used when the script
  /// is generated lazily on first open).
  Future<void> attachScript(String script) async {
    final current = state;
    if (current == null) return;
    await saveSetup(current.copyWith(generatedScript: script));
  }

  /// Marks the one-time "how to practice" primer as seen so it is not shown
  /// again before future sessions.
  Future<void> markHowToSeen() async {
    final current = state;
    if (current == null || current.hasSeenHowTo) return;
    await saveSetup(current.copyWith(hasSeenHowTo: true));
  }

  /// Records today's completion in the history list AND flips the daily-win
  /// flag so the Subconscious alignment score reflects the session.
  Future<void> recordCompletion(int durationSeconds) async {
    final uid = _ref.read(authStateProvider).valueOrNull?.uid;
    if (uid == null) return;
    final profile = _ref.read(currentUserProfileProvider).valueOrNull;
    if (profile == null) return;

    final today = AppDateUtils.todayStringWithGracePeriod();
    final completions = [...profile.futureSelfCompletions];
    final entry = FutureSelfCompletion(
      date: today,
      completed: true,
      durationSeconds: durationSeconds,
      completionTime: DateTime.now(),
    );
    final idx = completions.indexWhere((c) => c.date == today);
    if (idx >= 0) {
      completions[idx] = entry;
    } else {
      completions.add(entry);
    }

    await _ref.read(firestoreServiceProvider).updateUserField(uid, {
      'futureSelfCompletions': completions.map((c) => c.toJson()).toList(),
    });

    await _ref
        .read(dailyCompletionProvider.notifier)
        .toggle('futureSelfCompleted', true);

    _ref
        .read(analyticsServiceProvider)
        .trackFutureSelfSessionCompleted(durationSeconds);
  }
}

final futureSelfProvider =
    StateNotifierProvider<FutureSelfNotifier, FutureSelfSetup?>((ref) {
  final notifier = FutureSelfNotifier(ref);
  ref.listen(currentUserProfileProvider, (_, next) {
    next.whenData((profile) => notifier._loadFromProfile(profile));
  });
  ref.read(currentUserProfileProvider).whenData(
        (profile) => notifier._loadFromProfile(profile),
      );
  return notifier;
});

/// Whether the Future Self practice has been completed today (grace-period
/// aware), derived from the profile completion history.
final futureSelfCompletedTodayProvider = Provider<bool>((ref) {
  final profile = ref.watch(currentUserProfileProvider).valueOrNull;
  if (profile == null) return false;
  final today = AppDateUtils.todayStringWithGracePeriod();
  return profile.futureSelfCompletions
      .any((c) => c.date == today && c.completed);
});
