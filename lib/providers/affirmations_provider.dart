import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/utils/app_date_utils.dart';
import '../models/affirmation.dart';
import '../models/user_profile.dart';
import 'auth_provider.dart';
import 'daily_completion_provider.dart';

class AffirmationsNotifier extends StateNotifier<List<Affirmation>> {
  final Ref _ref;

  AffirmationsNotifier(this._ref) : super([]);

  void _loadFromProfile(UserProfile? profile) {
    if (profile != null) state = profile.affirmations;
  }

  Future<void> _persist(List<Affirmation> items) async {
    final uid = _ref.read(authStateProvider).valueOrNull?.uid;
    if (uid == null) return;
    await _ref.read(firestoreServiceProvider).updateUserField(uid, {
      'affirmations': items.map((a) => a.toJson()).toList(),
    });
  }

  Future<void> addAffirmation(Affirmation affirmation) async {
    final updated = [...state, affirmation];
    state = updated;
    await _persist(updated);
  }

  Future<void> toggleActive(String id) async {
    final updated = state.map((a) {
      if (a.id == id) return a.copyWith(isActive: !a.isActive);
      return a;
    }).toList();
    state = updated;
    await _persist(updated);
  }

  Future<void> deleteAffirmation(String id) async {
    final updated = state.where((a) => a.id != id).toList();
    state = updated;
    await _persist(updated);
  }

  /// Records a session completion for today (with grace period).
  /// Upserts the `affirmation_completions` entry and updates daily completion flags.
  Future<void> recordSessionCompletion(String sessionType) async {
    final uid = _ref.read(authStateProvider).valueOrNull?.uid;
    if (uid == null) return;

    final today = AppDateUtils.todayStringWithGracePeriod();
    final profile = _ref.read(currentUserProfileProvider).valueOrNull;
    if (profile == null) return;

    final completions = [...profile.affirmationCompletions];
    final existingIdx = completions.indexWhere((c) => c.date == today);
    final now = DateTime.now();

    late final AffirmationCompletion updated;
    if (existingIdx >= 0) {
      final existing = completions[existingIdx];
      updated = existing.copyWith(
        morningCompleted:
            sessionType == 'morning' ? true : existing.morningCompleted,
        eveningCompleted:
            sessionType == 'evening' ? true : existing.eveningCompleted,
        morningTime: sessionType == 'morning' ? now : existing.morningTime,
        eveningTime: sessionType == 'evening' ? now : existing.eveningTime,
      );
      completions[existingIdx] = updated;
    } else {
      updated = AffirmationCompletion(
        date: today,
        morningCompleted: sessionType == 'morning',
        eveningCompleted: sessionType == 'evening',
        morningTime: sessionType == 'morning' ? now : null,
        eveningTime: sessionType == 'evening' ? now : null,
      );
      completions.add(updated);
    }

    await _ref.read(firestoreServiceProvider).updateUserField(uid, {
      'affirmationCompletions': completions.map((c) => c.toJson()).toList(),
    });

    // Update the per-session daily completion flag (for DailyWinsTracker)
    final field =
        sessionType == 'morning' ? 'affirmationsMorning' : 'affirmationsEvening';
    await _ref.read(dailyCompletionProvider.notifier).toggle(field, true);
  }

  List<Affirmation> get activeAffirmations =>
      state.where((a) => a.isActive).toList();
}

final affirmationsProvider =
    StateNotifierProvider<AffirmationsNotifier, List<Affirmation>>(
  (ref) {
    final notifier = AffirmationsNotifier(ref);
    ref.listen(currentUserProfileProvider, (_, next) {
      next.whenData((profile) => notifier._loadFromProfile(profile));
    });
    ref.read(currentUserProfileProvider).whenData(
          (profile) => notifier._loadFromProfile(profile),
        );
    return notifier;
  },
);
