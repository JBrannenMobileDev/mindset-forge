import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/services/analytics_service.dart';
import '../core/utils/app_date_utils.dart';
import 'auth_provider.dart';
import 'claude_provider.dart';
import 'daily_completion_provider.dart';

/// Immutable view of today's priority actions, derived from the user profile.
@immutable
class PriorityActionsState {
  /// Today's planned actions (empty when the user hasn't planned today).
  final List<String> actions;

  /// The committed #1 focus action for today, if any.
  final String focusAction;

  /// Action texts that have been checked off today.
  final Set<String> completed;

  /// True while an AI re-plan is in flight.
  final bool isGenerating;

  const PriorityActionsState({
    this.actions = const [],
    this.focusAction = '',
    this.completed = const {},
    this.isGenerating = false,
  });

  bool get isPlanned => actions.isNotEmpty;

  PriorityActionsState copyWith({
    List<String>? actions,
    String? focusAction,
    Set<String>? completed,
    bool? isGenerating,
  }) {
    return PriorityActionsState(
      actions: actions ?? this.actions,
      focusAction: focusAction ?? this.focusAction,
      completed: completed ?? this.completed,
      isGenerating: isGenerating ?? this.isGenerating,
    );
  }
}

/// Owns today's priority actions and their completion state, persisting to the
/// same `UserProfile` fields the dashboard Plan Day flow writes so the Today
/// tab and the daily-wins tracker stay in sync.
class PriorityActionsNotifier extends StateNotifier<PriorityActionsState> {
  final Ref _ref;

  PriorityActionsNotifier(this._ref) : super(const PriorityActionsState());

  void _initFromProfile() {
    final profile = _ref.read(currentUserProfileProvider).valueOrNull;
    if (profile == null) return;
    final today = AppDateUtils.todayStringWithGracePeriod();

    if (profile.priorityActionsDate == today &&
        profile.priorityActions.isNotEmpty) {
      final focus = profile.dailyFocusActionDate == today
          ? profile.dailyFocusAction
          : '';
      final completed = profile.completedPriorityActions.toSet();
      // The Focus banner marks the focus done via dailyFocusActionCompleted
      // only; reconcile that into the completed set so the tab agrees.
      if (focus.isNotEmpty && profile.dailyFocusActionCompleted) {
        completed.add(focus);
      }
      state = state.copyWith(
        actions: profile.priorityActions,
        focusAction: focus,
        completed: completed,
      );
    } else {
      // Not planned for today — reset to an empty (but not generating) state.
      state = PriorityActionsState(isGenerating: state.isGenerating);
    }
  }

  /// Derives the daily-win flags from the current state and persists them:
  /// - `dayPlanned` = a #1 focus has been picked (the morning commitment).
  /// - `focusCompleted` = that #1 focus is complete — the decisive action that
  ///   counts toward the streak / perfect day.
  /// - `priorityActionsCompleted` = at least one planned action is done; a
  ///   scoring-only signal for the Action dimension (not the streak).
  Future<void> _syncDailyWins() async {
    final hasFocus = state.focusAction.isNotEmpty;
    final focusDone = hasFocus && state.completed.contains(state.focusAction);
    final anyActionDone = state.actions.any(state.completed.contains);
    final dc = _ref.read(dailyCompletionProvider.notifier);
    await dc.toggle('dayPlanned', hasFocus);
    await dc.toggle('focusCompleted', focusDone);
    await dc.toggle('priorityActionsCompleted', anyActionDone);
  }

  /// Toggle a single action's completion. This is the *doing*. Keeps
  /// `dailyFocusActionCompleted` (drives the Today's Focus hero) aligned; the
  /// win flags follow the #1 focus via [_syncDailyWins].
  Future<void> toggleComplete(String action) async {
    final uid = _ref.read(authStateProvider).valueOrNull?.uid;
    if (uid == null) return;

    final completed = Set<String>.from(state.completed);
    if (completed.contains(action)) {
      completed.remove(action);
    } else {
      completed.add(action);
    }
    // Optimistic update.
    state = state.copyWith(completed: completed);

    final focusDone =
        state.focusAction.isNotEmpty && completed.contains(state.focusAction);

    try {
      await _ref.read(firestoreServiceProvider).updateUserField(uid, {
        'completedPriorityActions': completed.toList(),
        'dailyFocusActionCompleted': focusDone,
      });
      await _syncDailyWins();
    } catch (e) {
      debugPrint('PriorityActionsNotifier.toggleComplete failed: $e');
    }
  }

  /// Add a new priority action to today's list. Never auto-assigns the #1
  /// focus — the user must pick it explicitly via [setFocus].
  Future<void> addAction(String text) async {
    final uid = _ref.read(authStateProvider).valueOrNull?.uid;
    if (uid == null) return;

    final trimmed = text.trim();
    if (trimmed.isEmpty || state.actions.contains(trimmed)) return;

    final today = AppDateUtils.todayStringWithGracePeriod();
    final actions = [...state.actions, trimmed];

    state = state.copyWith(actions: actions);

    try {
      await _ref.read(firestoreServiceProvider).updateUserField(uid, {
        'priorityActions': actions,
        'priorityActionsDate': today,
      });
      // "Plan Day" stays unchecked until the user picks a #1 focus.
      await _syncDailyWins();
    } catch (e) {
      debugPrint('PriorityActionsNotifier.addAction failed: $e');
    }
  }

  /// Remove a priority action. Clears the #1 focus when the removed action was
  /// it — the user must pick a new focus rather than have one auto-assigned.
  Future<void> removeAction(String text) async {
    final uid = _ref.read(authStateProvider).valueOrNull?.uid;
    if (uid == null) return;

    final actions = state.actions.where((a) => a != text).toList();
    final completed = Set<String>.from(state.completed)..remove(text);
    final focusCleared = state.focusAction == text;
    final focus = focusCleared ? '' : state.focusAction;
    final focusDone = focus.isNotEmpty && completed.contains(focus);

    state = state.copyWith(
      actions: actions,
      completed: completed,
      focusAction: focus,
    );

    final today = AppDateUtils.todayStringWithGracePeriod();
    try {
      await _ref.read(firestoreServiceProvider).updateUserField(uid, {
        'priorityActions': actions,
        'priorityActionsDate': today,
        'completedPriorityActions': completed.toList(),
        'dailyFocusAction': focus,
        'dailyFocusActionDate': today,
        'dailyFocusActionCompleted': focusDone,
      });
      // Win flags follow the #1 focus (cleared above if it was removed).
      await _syncDailyWins();
    } catch (e) {
      debugPrint('PriorityActionsNotifier.removeAction failed: $e');
    }
  }

  /// Set the committed #1 focus action for today.
  Future<void> setFocus(String text) async {
    final uid = _ref.read(authStateProvider).valueOrNull?.uid;
    if (uid == null) return;
    if (!state.actions.contains(text)) return;

    state = state.copyWith(focusAction: text);

    final today = AppDateUtils.todayStringWithGracePeriod();
    try {
      await _ref.read(firestoreServiceProvider).updateUserField(uid, {
        'dailyFocusAction': text,
        'dailyFocusActionDate': today,
        'dailyFocusActionCompleted': state.completed.contains(text),
      });
      // Explicit pick — this is what satisfies the "Plan Day" win.
      await _syncDailyWins();
      _ref.read(analyticsServiceProvider).trackPriorityActionsSet(
            actionCount: state.actions.length,
            usedAi: false,
          );
    } catch (e) {
      debugPrint('PriorityActionsNotifier.setFocus failed: $e');
    }
  }

  /// Regenerate today's actions via the coach (used by the empty-state
  /// "Generate ideas" action). Leaves the #1 focus empty for the user to pick.
  Future<void> regenerate() async {
    final uid = _ref.read(authStateProvider).valueOrNull?.uid;
    final profile = _ref.read(currentUserProfileProvider).valueOrNull;
    if (uid == null || profile == null) return;

    state = state.copyWith(isGenerating: true);
    try {
      final actions =
          await _ref.read(claudeServiceProvider).generatePriorityActions(profile);
      final today = AppDateUtils.todayStringWithGracePeriod();
      await _ref.read(firestoreServiceProvider).updateUserField(uid, {
        'priorityActions': actions,
        'priorityActionsDate': today,
        'completedPriorityActions': <String>[],
        'dailyFocusAction': '',
        'dailyFocusActionDate': today,
        'dailyFocusActionCompleted': false,
      });
      // No focus picked yet, so no win is satisfied by generating.
      final dc = _ref.read(dailyCompletionProvider.notifier);
      await dc.toggle('dayPlanned', false);
      await dc.toggle('focusCompleted', false);
      await dc.toggle('priorityActionsCompleted', false);
      _ref.read(analyticsServiceProvider).trackAiFeatureUsed('priority_actions');
      // State refreshes from the profile stream.
    } catch (e) {
      debugPrint('PriorityActionsNotifier.regenerate failed: $e');
      rethrow;
    } finally {
      if (mounted) state = state.copyWith(isGenerating: false);
    }
  }

  void refresh() => _initFromProfile();
}

final priorityActionsProvider =
    StateNotifierProvider<PriorityActionsNotifier, PriorityActionsState>(
  (ref) {
    final notifier = PriorityActionsNotifier(ref);
    ref.read(currentUserProfileProvider).whenData((_) => notifier.refresh());
    ref.listen(currentUserProfileProvider, (_, next) {
      next.whenData((_) => notifier.refresh());
    });
    return notifier;
  },
);
