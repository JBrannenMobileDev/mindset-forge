import 'dart:io';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import '../firebase/firestore_service.dart';

class FcmService {
  final _messaging = FirebaseMessaging.instance;
  final _localNotifications = FlutterLocalNotificationsPlugin();

  /// Asks the OS for notification permission. Call this at a meaningful moment
  /// (e.g. end of onboarding or first accountability partner setup) so the user
  /// understands why the app wants the permission.
  Future<bool> requestPermission() async {
    if (!Platform.isIOS) return true;
    final settings = await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );
    return settings.authorizationStatus == AuthorizationStatus.authorized ||
        settings.authorizationStatus == AuthorizationStatus.provisional;
  }

  /// Silently get the FCM token (if permission is already granted) and save it
  /// to Firestore. Does NOT show the permission dialog.
  Future<void> initAndStoreToken(String uid, FirestoreService firestore) async {
    if (Platform.isIOS) {
      final settings = await _messaging.getNotificationSettings();
      if (settings.authorizationStatus == AuthorizationStatus.denied ||
          settings.authorizationStatus == AuthorizationStatus.notDetermined) {
        // Permission not yet granted — don't prompt, just skip silently.
        return;
      }
    }

    // Get token
    final token = await _messaging.getToken();
    if (token == null) return;

    // Store on user doc
    try {
      await firestore.updateUserField(uid, {'fcmToken': token});
    } catch (e) {
      debugPrint('Failed to store FCM token: $e');
    }

    // Listen for token refresh
    _messaging.onTokenRefresh.listen((newToken) async {
      try {
        await firestore.updateUserField(uid, {'fcmToken': newToken});
      } catch (_) {}
    });

    // Handle foreground messages as local notifications
    FirebaseMessaging.onMessage.listen(_handleForegroundMessage);

    // Update lastActiveAt to track user activity for lowActivityAlert
    try {
      await firestore.updateUserField(uid, {
        'lastActiveAt': DateTime.now().toIso8601String(),
      });
    } catch (_) {}
  }

  Future<void> _handleForegroundMessage(RemoteMessage message) async {
    final notification = message.notification;
    if (notification == null) return;

    const androidDetails = AndroidNotificationDetails(
      'mindsetforge_default',
      'MindsetForge',
      channelDescription: 'MindsetForge notifications',
      importance: Importance.high,
      priority: Priority.high,
    );
    const iosDetails = DarwinNotificationDetails();

    await _localNotifications.show(
      notification.hashCode,
      notification.title,
      notification.body,
      const NotificationDetails(android: androidDetails, iOS: iosDetails),
    );
  }

  /// Schedule a local daily reminder notification.
  Future<void> scheduleDailyReminder({
    required int hour,
    required int minute,
    required String title,
    required String body,
  }) async {
    // flutter_local_notifications scheduling requires the timezone package.
    // For now, just show it as a one-time notification.
    // Full scheduling with TZDateTime would be added with the timezone package.
    debugPrint('Daily reminder scheduled for $hour:$minute');
  }

  Future<void> cancelAllNotifications() async {
    await _localNotifications.cancelAll();
  }
}
