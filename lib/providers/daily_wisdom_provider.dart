import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/utils/app_date_utils.dart';
import '../models/user_profile.dart';
import 'auth_provider.dart';
import 'claude_provider.dart';

/// State for the daily wisdom feature.
class DailyWisdomState {
  final String? wisdom;
  final bool isLoading;

  const DailyWisdomState({
    this.wisdom,
    this.isLoading = false,
  });

  DailyWisdomState copyWith({String? wisdom, bool? isLoading}) {
    return DailyWisdomState(
      wisdom: wisdom ?? this.wisdom,
      isLoading: isLoading ?? this.isLoading,
    );
  }
}

// ─── Notifier ─────────────────────────────────────────────────────────────────

/// Single source of truth for the daily wisdom quote.
///
/// Both [DashboardHeader] and [DailyWisdomCard] watch this provider.
/// Only one Claude call is made per day regardless of how many widgets observe.
class DailyWisdomNotifier extends StateNotifier<DailyWisdomState> {
  final Ref _ref;
  bool _generateCalled = false;

  DailyWisdomNotifier(this._ref) : super(const DailyWisdomState());

  static const _fallback =
      'Your inner world creates your outer world.';

  /// Call once when the profile is available. Idempotent — subsequent calls
  /// are no-ops if generation is already in progress or complete for today.
  Future<void> loadForProfile(UserProfile profile) async {
    // Partner accounts have no onboarding data to personalize an AI quote from,
    // so skip the Claude call and serve a static quote. Returning without
    // setting state would leave the header stuck on its loading shimmer.
    if (profile.userType == 'partner') {
      state = state.copyWith(wisdom: _fallback, isLoading: false);
      return;
    }

    final today = AppDateUtils.todayString();
    final cached = profile.dailyWisdom[today];

    // Serve cache immediately — but not if the cached value is the fallback
    // string, which means a prior Claude failure was incorrectly persisted.
    if (cached != null && cached.isNotEmpty && cached != _fallback) {
      state = state.copyWith(wisdom: cached);
      return;
    }

    // Prevent duplicate generation when multiple widgets call this.
    if (_generateCalled) return;
    _generateCalled = true;

    state = state.copyWith(isLoading: true);

    try {
      final wisdom = await _ref
          .read(claudeServiceProvider)
          .generateDailyWisdom(profile);

      state = const DailyWisdomState().copyWith(wisdom: wisdom, isLoading: false);

      // Persist to Firestore so tomorrow's cold start is instant.
      final uid = _ref.read(authStateProvider).valueOrNull?.uid;
      if (uid != null) {
        final newMap = Map<String, String>.from(profile.dailyWisdom)
          ..[today] = wisdom;
        await _ref.read(firestoreServiceProvider).updateUserField(uid, {
          'dailyWisdom': newMap,
        });
      }
    } catch (e) {
      _generateCalled = false;
      debugPrint('DailyWisdomNotifier: generation failed — $e');
      state = const DailyWisdomState().copyWith(wisdom: _fallback, isLoading: false);
    }
  }
}

// ─── Provider ─────────────────────────────────────────────────────────────────

final dailyWisdomProvider =
    StateNotifierProvider<DailyWisdomNotifier, DailyWisdomState>((ref) {
  return DailyWisdomNotifier(ref);
});
