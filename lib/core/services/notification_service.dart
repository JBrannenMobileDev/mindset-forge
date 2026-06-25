import 'dart:io';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:go_router/go_router.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;
import '../firebase/firestore_service.dart';

/// Android channel ids — one per notification category so users can tune each
/// independently from system settings. Categories double as analytics buckets.
abstract final class NotifChannel {
  static const routine = 'mindshift_routine';
  static const streak = 'mindshift_streak';
  static const partner = 'mindshift_partner';
  static const lifecycle = 'mindshift_lifecycle';
}

/// Single point of contact with the OS notification layer: FCM tokens,
/// foreground display, permission, tap routing, and local scheduling.
///
/// Higher-level "what to schedule / what to say" logic lives in
/// [NotificationScheduler]; this class only delivers.
///
/// State is static so the (cheap) instances created by the Riverpod provider
/// all share one initialized [FlutterLocalNotificationsPlugin] — avoiding the
/// previous bug where a second, uninitialized plugin silently dropped
/// foreground notifications.
class NotificationService {
  static final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  static final FirebaseMessaging _messaging = FirebaseMessaging.instance;

  static GoRouter? _router;
  static bool _pluginReady = false;
  static bool _tzReady = false;

  /// Optional hook the provider wires up to record notification opens for the
  /// metrics pipeline. Receives the notification category.
  static Future<void> Function(String category)? openLogger;

  // ── One-time init ─────────────────────────────────────────────────────────

  /// Initializes the local-notifications plugin, timezone database, Android
  /// channels, and the tap handler. Idempotent; safe to call from `main`.
  Future<void> initPlugin() async {
    if (kIsWeb || _pluginReady) return;
    await _ensureTimezone();

    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );
    await _plugin.initialize(
      const InitializationSettings(android: androidSettings, iOS: iosSettings),
      onDidReceiveNotificationResponse: (resp) =>
          _routeFromPayload(resp.payload),
    );
    await _createAndroidChannels();
    _pluginReady = true;
  }

  Future<void> _ensureTimezone() async {
    if (_tzReady) return;
    tzdata.initializeTimeZones();
    try {
      final info = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(info.identifier));
    } catch (e) {
      debugPrint('NotificationService: timezone init failed ($e); using UTC');
    }
    _tzReady = true;
  }

  Future<void> _createAndroidChannels() async {
    final android = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    if (android == null) return;
    const channels = [
      AndroidNotificationChannel(
        NotifChannel.routine,
        'Daily reminders',
        description: 'Morning and evening practice nudges',
        importance: Importance.high,
      ),
      AndroidNotificationChannel(
        NotifChannel.streak,
        'Streak protection',
        description: 'Last-chance reminders to keep your streak alive',
        importance: Importance.high,
      ),
      AndroidNotificationChannel(
        NotifChannel.partner,
        'Accountability partner',
        description: 'Encouragement and partner check-ins',
        importance: Importance.high,
      ),
      AndroidNotificationChannel(
        NotifChannel.lifecycle,
        'Comeback nudges',
        description: 'Gentle reminders when you have been away',
        importance: Importance.defaultImportance,
      ),
    ];
    for (final c in channels) {
      await android.createNotificationChannel(c);
    }
  }

  // ── Permission ────────────────────────────────────────────────────────────

  /// Requests OS notification permission. Handles iOS (via FCM) and Android 13+
  /// (`POST_NOTIFICATIONS`, via the local-notifications plugin).
  Future<bool> requestPermission() async {
    if (kIsWeb) return false;
    if (Platform.isIOS) {
      final settings = await _messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );
      return settings.authorizationStatus == AuthorizationStatus.authorized ||
          settings.authorizationStatus == AuthorizationStatus.provisional;
    }
    if (Platform.isAndroid) {
      final android = _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      final granted = await android?.requestNotificationsPermission();
      return granted ?? true;
    }
    return true;
  }

  /// Whether the user has already granted notification permission. Used to drive
  /// the soft-ask fallback in settings.
  Future<bool> hasPermission() async {
    if (kIsWeb) return false;
    if (Platform.isIOS) {
      final settings = await _messaging.getNotificationSettings();
      return settings.authorizationStatus == AuthorizationStatus.authorized ||
          settings.authorizationStatus == AuthorizationStatus.provisional;
    }
    if (Platform.isAndroid) {
      final android = _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      return await android?.areNotificationsEnabled() ?? true;
    }
    return false;
  }

  // ── FCM token + activity ──────────────────────────────────────────────────

  /// Silently fetches and persists the FCM token (if permission is granted),
  /// wires the foreground handler, and records the device timezone. Does NOT
  /// prompt for permission.
  Future<void> initAndStoreToken(String uid, FirestoreService firestore) async {
    if (kIsWeb) return;

    // Capture timezone + activity regardless of push permission so server-side
    // scheduling and re-engagement stay accurate even for push-declined users.
    await markActive(uid, firestore);

    if (Platform.isIOS) {
      final settings = await _messaging.getNotificationSettings();
      if (settings.authorizationStatus == AuthorizationStatus.denied ||
          settings.authorizationStatus == AuthorizationStatus.notDetermined) {
        return;
      }
    }

    final token = await _messaging.getToken();
    if (token == null) return;
    try {
      await firestore.updateUserField(uid, {'fcmToken': token});
    } catch (e) {
      debugPrint('NotificationService: failed to store FCM token: $e');
    }

    _messaging.onTokenRefresh.listen((newToken) async {
      try {
        await firestore.updateUserField(uid, {'fcmToken': newToken});
      } catch (_) {}
    });

    FirebaseMessaging.onMessage.listen(_handleForegroundMessage);
  }

  /// Records that the user is active right now: refreshes `lastActiveAt`,
  /// captures the current timezone, and resets the lifecycle re-engagement tier
  /// so comeback nudges start fresh next time they lapse.
  Future<void> markActive(String uid, FirestoreService firestore) async {
    if (kIsWeb) return;
    String? tzName;
    try {
      tzName = (await FlutterTimezone.getLocalTimezone()).identifier;
    } catch (_) {}
    try {
      await firestore.updateUserField(uid, {
        'lastActiveAt': DateTime.now().toIso8601String(),
        'lifecycleTier': 0,
        if (tzName != null && tzName.isNotEmpty) 'timezone': tzName,
      });
    } catch (_) {}
  }

  /// Clears the FCM token on this device so a logged-out user no longer receives
  /// pushes (important on shared devices).
  Future<void> clearToken(String uid, FirestoreService firestore) async {
    if (kIsWeb) return;
    try {
      await firestore.updateUserField(uid, {'fcmToken': null});
      await _messaging.deleteToken();
    } catch (e) {
      debugPrint('NotificationService: failed to clear FCM token: $e');
    }
  }

  // ── Tap routing ───────────────────────────────────────────────────────────

  /// Stores the router and wires FCM open handlers. Call once the router exists.
  void attachRouter(GoRouter router) {
    _router = router;
    if (kIsWeb) return;
    FirebaseMessaging.onMessageOpenedApp.listen(_routeFromMessage);
    _messaging.getInitialMessage().then((m) {
      if (m != null) _routeFromMessage(m);
    });
  }

  void _routeFromMessage(RemoteMessage message) {
    final data = message.data;
    final route = (data['route'] as String?) ?? _routeForType(data);
    final category = (data['category'] as String?) ??
        _categoryForType(data['type'] as String?);
    _go(route, category);
  }

  /// Local-notification payloads are encoded as "category|route".
  void _routeFromPayload(String? payload) {
    if (payload == null || payload.isEmpty) return;
    final parts = payload.split('|');
    final category = parts.length > 1 ? parts.first : 'routine';
    final route = parts.length > 1 ? parts.sublist(1).join('|') : payload;
    _go(route, category);
  }

  void _go(String route, String category) {
    try {
      openLogger?.call(category);
    } catch (_) {}
    final router = _router;
    if (router == null) return;
    try {
      router.push(route);
    } catch (e) {
      debugPrint('NotificationService: routing to "$route" failed: $e');
    }
  }

  String _routeForType(Map<String, dynamic> data) {
    switch (data['type'] as String?) {
      case 'encouragement':
        return '/notifications';
      case 'partner_slip':
      case 'partner_celebration':
      case 'partner_digest':
        final uid = data['primaryUid'] as String?;
        return (uid != null && uid.isNotEmpty)
            ? '/partner-view/$uid'
            : '/dashboard';
      default:
        return '/dashboard';
    }
  }

  String _categoryForType(String? type) {
    switch (type) {
      case 'encouragement':
      case 'partner_slip':
      case 'partner_celebration':
      case 'partner_digest':
        return 'partner';
      case 'low_activity_alert':
        return 'lifecycle';
      default:
        return 'routine';
    }
  }

  // ── Foreground display ────────────────────────────────────────────────────

  Future<void> _handleForegroundMessage(RemoteMessage message) async {
    final notification = message.notification;
    if (notification == null) return;
    final channelId = _channelForCategory(
      (message.data['category'] as String?) ??
          _categoryForType(message.data['type'] as String?),
    );
    final route = (message.data['route'] as String?) ?? _routeForType(message.data);
    final category = (message.data['category'] as String?) ??
        _categoryForType(message.data['type'] as String?);
    await _plugin.show(
      notification.hashCode,
      notification.title,
      notification.body,
      NotificationDetails(
        android: AndroidNotificationDetails(
          channelId,
          channelId,
          importance: Importance.high,
          priority: Priority.high,
        ),
        iOS: const DarwinNotificationDetails(),
      ),
      payload: '$category|$route',
    );
  }

  String _channelForCategory(String category) {
    switch (category) {
      case 'streak':
        return NotifChannel.streak;
      case 'partner':
        return NotifChannel.partner;
      case 'lifecycle':
        return NotifChannel.lifecycle;
      default:
        return NotifChannel.routine;
    }
  }

  // ── Local scheduling primitives ───────────────────────────────────────────

  /// Schedules a one-shot local notification at [when] (device-local wall time).
  /// No-ops if the time is in the past. [category] selects the Android channel
  /// and is encoded into the payload for tap routing + analytics.
  Future<void> scheduleAt({
    required int id,
    required DateTime when,
    required String title,
    required String body,
    required String category,
    required String route,
  }) async {
    if (kIsWeb || !_pluginReady) return;
    final tzWhen = tz.TZDateTime.from(when, tz.local);
    if (!tzWhen.isAfter(tz.TZDateTime.now(tz.local))) return;
    final channelId = _channelForCategory(category);
    await _plugin.zonedSchedule(
      id,
      title,
      body,
      tzWhen,
      NotificationDetails(
        android: AndroidNotificationDetails(
          channelId,
          channelId,
          importance: Importance.high,
          priority: Priority.high,
        ),
        iOS: const DarwinNotificationDetails(),
      ),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      payload: '$category|$route',
    );
  }

  Future<void> cancel(int id) async {
    if (kIsWeb) return;
    await _plugin.cancel(id);
  }

  Future<void> cancelAll() async {
    if (kIsWeb) return;
    await _plugin.cancelAll();
  }
}
