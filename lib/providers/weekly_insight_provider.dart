import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/utils/app_date_utils.dart';
import '../models/user_profile.dart';
import '../models/weekly_insight.dart';
import 'auth_provider.dart';
import 'claude_provider.dart';

/// Persists weekly insight actions (mark viewed, manual refresh).
class WeeklyInsightNotifier extends StateNotifier<bool> {
  WeeklyInsightNotifier(this._ref) : super(false);

  final Ref _ref;

  Future<void> markViewedIfNeeded(WeeklyInsight? insight) async {
    if (insight == null || !insight.isUnread) return;
    final uid = _ref.read(authStateProvider).valueOrNull?.uid;
    if (uid == null) return;

    try {
      await _ref.read(firestoreServiceProvider).updateUserField(uid, {
        'weeklyInsight.viewedAt': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      debugPrint('WeeklyInsightNotifier.markViewedIfNeeded failed: $e');
    }
  }

  /// Manual refresh — rate-limited to once per local calendar day.
  Future<bool> refresh(UserProfile profile) async {
    final uid = _ref.read(authStateProvider).valueOrNull?.uid;
    if (uid == null || state) return false;

    final current = profile.weeklyInsight;
    if (current != null) {
      final generated = DateTime.tryParse(current.generatedAt);
      if (generated != null &&
          AppDateUtils.isSameDay(generated, DateTime.now())) {
        return false;
      }
    }

    state = true;
    try {
      final sections = await _ref
          .read(claudeServiceProvider)
          .generateStructuredWeeklyInsight(profile);
      final weekEnding = _currentWeekEndingDateKey();
      final insight = WeeklyInsight.fromSections(
        sections: sections,
        weekEnding: weekEnding,
      );

      final history = _rotateHistory(
        current: profile.weeklyInsight,
        history: profile.weeklyInsightHistory,
      );

      await _ref.read(firestoreServiceProvider).updateUserField(uid, {
        'weeklyInsight': insight.toJson(),
        'weeklyInsightHistory': history.map((e) => e.toJson()).toList(),
      });
      return true;
    } catch (e) {
      debugPrint('WeeklyInsightNotifier.refresh failed: $e');
      return false;
    } finally {
      state = false;
    }
  }

  static String _currentWeekEndingDateKey() {
    final now = DateTime.now();
    // Sunday = 7 in Dart weekday (Mon=1 … Sun=7).
    final daysUntilSunday = DateTime.sunday - now.weekday;
    final sunday = now.add(Duration(days: daysUntilSunday));
    return _dateKey(sunday);
  }

  static List<WeeklyInsight> _rotateHistory({
    required WeeklyInsight? current,
    required List<WeeklyInsight> history,
  }) {
    if (current == null || !current.hasContent) return history;
    final archived = current.viewedAt != null
        ? current
        : current.copyWith(viewedAt: DateTime.now().toIso8601String());
    return [archived, ...history].take(WeeklyInsight.historyMax).toList();
  }

  static String _dateKey(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
}

final weeklyInsightRefreshingProvider =
    StateNotifierProvider<WeeklyInsightNotifier, bool>((ref) {
  return WeeklyInsightNotifier(ref);
});
