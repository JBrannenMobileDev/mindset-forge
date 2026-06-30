import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/services/widget_sync_service.dart';
import 'auth_provider.dart';
import 'daily_completion_provider.dart';

/// Activating this provider wires up widget/watch data export:
///   - rebuilds + pushes the payload whenever the profile or today's
///     completion changes (covers focus set, focus complete, win toggles,
///     and new-day rollover via the profile stream)
///   - handles "Mark focus done" commands relayed from the watch glance app,
///     routing them through the same notifier path the in-app hero uses
///
/// `ref.watch` it once high in the widget tree (see `MindsetForgeApp.build`).
final widgetSyncInitProvider = Provider<void>((ref) {
  final service = ref.watch(widgetSyncServiceProvider);

  // Relay watch glance actions into the existing focus-complete logic.
  ref.read(watchBridgeProvider).setCommandHandler((command) async {
    if (command == 'completeFocus') {
      await _completeFocusFromWatch(ref);
    }
  });

  // Initial push + react to every profile emission (login, completion edits,
  // preference changes, day rollover all flow through the profile stream).
  ref.listen(
    currentUserProfileProvider,
    (_, __) => service.sync(),
    fireImmediately: true,
  );
  // Optimistic in-session completion toggles update the daily completion
  // notifier before the profile stream round-trips — sync on those too.
  ref.listen(dailyCompletionProvider, (_, __) => service.sync());
});

/// Mirrors `TodayHeroCard._completeFocus` but driven from the watch.
Future<void> _completeFocusFromWatch(Ref ref) async {
  try {
    final uid = ref.read(authStateProvider).valueOrNull?.uid;
    if (uid != null) {
      await ref.read(firestoreServiceProvider).updateUserField(uid, {
        'dailyFocusActionCompleted': true,
      });
    }
    final dc = ref.read(dailyCompletionProvider.notifier);
    await dc.toggle('focusCompleted', true);
    await dc.toggle('priorityActionsCompleted', true);
    // The profile/completion listeners above will re-sync the watch + widget.
  } catch (e) {
    debugPrint('widgetSync: completeFocus from watch failed: $e');
  }
}
