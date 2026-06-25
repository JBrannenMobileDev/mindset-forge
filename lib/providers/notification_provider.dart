import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/services/notification_service.dart';
import '../core/services/notification_scheduler.dart';
import '../models/notification_prefs.dart';
import '../models/user_profile.dart';
import 'auth_provider.dart';

final notificationServiceProvider = Provider<NotificationService>((_) {
  return NotificationService();
});

final notificationSchedulerProvider = Provider<NotificationScheduler>((ref) {
  return NotificationScheduler(ref.read(notificationServiceProvider));
});

/// Auto-initializes notifications when a user is authenticated: stores the FCM
/// token, captures timezone/activity, and wires the open-analytics logger.
final notificationInitProvider = FutureProvider<void>((ref) async {
  final user = await ref.watch(authStateProvider.future);
  if (user == null) return;

  final service = ref.read(notificationServiceProvider);
  final firestore = ref.read(firestoreServiceProvider);

  // Record notification opens for the metrics pipeline (best-effort).
  NotificationService.openLogger = (category) async {
    try {
      await FirebaseFunctions.instance
          .httpsCallable('logNotificationEvent')
          .call({'category': category, 'action': 'open'});
    } catch (_) {}
  };

  await service.initAndStoreToken(user.uid, firestore);
});

/// Mutable notification preferences, synced to the user's profile and used to
/// (re)schedule local reminders on every change.
class NotificationPrefsNotifier extends StateNotifier<NotificationPrefs> {
  final Ref _ref;

  NotificationPrefsNotifier(this._ref) : super(const NotificationPrefs());

  void _loadFromProfile(UserProfile? profile) {
    if (profile != null) state = profile.notificationPrefs;
  }

  /// Persists [prefs] (optimistically) and reschedules local reminders.
  Future<void> update(NotificationPrefs prefs) async {
    state = prefs;
    final uid = _ref.read(authStateProvider).valueOrNull?.uid;
    if (uid == null) return;

    try {
      await _ref.read(firestoreServiceProvider).updateUserField(uid, {
        'notificationPrefs': prefs.toJson(),
      });
    } catch (e) {
      debugPrint('NotificationPrefsNotifier.update persist failed: $e');
    }

    final profile = _ref.read(currentUserProfileProvider).valueOrNull;
    if (profile != null) {
      await _ref
          .read(notificationSchedulerProvider)
          .rescheduleAll(profile.copyWith(notificationPrefs: prefs));
    }
  }
}

final notificationPrefsProvider =
    StateNotifierProvider<NotificationPrefsNotifier, NotificationPrefs>((ref) {
  final notifier = NotificationPrefsNotifier(ref);
  ref.listen(currentUserProfileProvider, (_, next) {
    next.whenData((profile) => notifier._loadFromProfile(profile));
  });
  ref.read(currentUserProfileProvider).whenData(
        (profile) => notifier._loadFromProfile(profile),
      );
  return notifier;
});
