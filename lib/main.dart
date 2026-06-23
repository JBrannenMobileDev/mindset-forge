import 'dart:io';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';
import 'firebase_options.dart';
import 'providers/fcm_provider.dart';

// RevenueCat API keys — replace with your actual keys from the RevenueCat dashboard
const _revenueCatApiKeyIos = 'appl_REPLACE_WITH_IOS_KEY';
const _revenueCatApiKeyAndroid = 'goog_REPLACE_WITH_ANDROID_KEY';

final _localNotifications = FlutterLocalNotificationsPlugin();

/// Handle background FCM messages
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Catch all Flutter framework errors
  FlutterError.onError = (details) {
    FlutterError.presentError(details);
    debugPrint('Flutter error: ${details.exceptionAsString()}');
  };

  // Register FCM background handler before Firebase init
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

  runApp(const _InitApp());
}

class _InitApp extends StatefulWidget {
  const _InitApp();

  @override
  State<_InitApp> createState() => _InitAppState();
}

class _InitAppState extends State<_InitApp> {
  bool _ready = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    try {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
    } catch (e) {
      setState(() => _error = 'Firebase init failed:\n$e');
      return;
    }

    // Configure RevenueCat
    await _initRevenueCat();

    // Configure local notifications
    await _initLocalNotifications();

    SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle.light);
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);

    if (mounted) setState(() => _ready = true);
  }

  Future<void> _initRevenueCat() async {
    final apiKey = Platform.isIOS ? _revenueCatApiKeyIos : _revenueCatApiKeyAndroid;
    // Skip init if keys haven't been replaced yet — avoids iOS watchdog kills.
    if (apiKey.startsWith('appl_REPLACE') || apiKey.startsWith('goog_REPLACE')) {
      debugPrint('RevenueCat: placeholder key detected, skipping init.');
      return;
    }
    try {
      await Purchases.setLogLevel(LogLevel.error);
      await Purchases.configure(PurchasesConfiguration(apiKey));
    } catch (e) {
      debugPrint('RevenueCat init error: $e');
    }
  }

  Future<void> _initLocalNotifications() async {
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );
    await _localNotifications.initialize(
      const InitializationSettings(android: androidSettings, iOS: iosSettings),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_error != null) {
      return MaterialApp(
        home: Scaffold(
          backgroundColor: const Color(0xFF0A0A0F),
          body: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, color: Colors.red, size: 48),
                  const SizedBox(height: 16),
                  Text(
                    _error!,
                    style: const TextStyle(color: Colors.white70, fontSize: 13),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    if (!_ready) {
      return const MaterialApp(
        home: Scaffold(
          backgroundColor: Color(0xFF0A0A0F),
          body: Center(
            child: CircularProgressIndicator(color: Color(0xFF7B61FF)),
          ),
        ),
      );
    }

    return const ProviderScope(child: MindsetForgeApp());
  }
}

class MindsetForgeApp extends ConsumerWidget {
  const MindsetForgeApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);
    // Eagerly activate FCM initialization whenever a user is signed in
    ref.watch(fcmInitProvider);

    return MaterialApp.router(
      title: 'MindsetForge',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.dark,
      darkTheme: AppTheme.dark,
      themeMode: ThemeMode.dark,
      routerConfig: router,
    );
  }
}
