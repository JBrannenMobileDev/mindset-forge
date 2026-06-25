import 'dart:io';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';

import 'core/constants/app_colors.dart';
import 'core/constants/app_text_styles.dart';
import 'core/router/app_router.dart';
import 'core/services/deep_link_service.dart';
import 'core/services/pending_invite_store.dart';
import 'core/theme/app_theme.dart';
import 'features/auth/widgets/splash_view.dart';
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
  final binding = WidgetsFlutterBinding.ensureInitialized();
  // Hold the native splash on screen until the first Flutter frame paints so
  // there is no gap between the OS launch screen and our SplashView.
  FlutterNativeSplash.preserve(widgetsBinding: binding);

  // Catch all Flutter framework errors
  FlutterError.onError = (details) {
    FlutterError.presentError(details);
    debugPrint('Flutter error: ${details.exceptionAsString()}');
  };

  // Register FCM background handler before Firebase init
  if (!kIsWeb) {
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
  }

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
    // Remove the native splash once the first Flutter frame (our SplashView)
    // has painted. The native and in-app visuals match, so removal is seamless.
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => FlutterNativeSplash.remove(),
    );
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

    // Load any pending partner invite stashed before sign-in.
    await PendingInviteStore.load();

    // Configure RevenueCat
    await _initRevenueCat();

    // Configure local notifications
    await _initLocalNotifications();

    SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle.light);
    if (!kIsWeb) {
      SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    }

    if (mounted) setState(() => _ready = true);
  }

  Future<void> _initRevenueCat() async {
    if (kIsWeb) return; // RevenueCat doesn't support web
    final apiKey = Platform.isIOS ? _revenueCatApiKeyIos : _revenueCatApiKeyAndroid;
    // Always configure the SDK so that Purchases.shared is never nil.
    // Skipping configuration causes a native Swift fatalError if PricingScreen
    // calls getOfferings() before the SDK is configured — not catchable in Dart.
    // With an invalid/placeholder key the configure() call itself succeeds; any
    // subsequent network calls (getOfferings) will throw a catchable Dart error.
    try {
      await Purchases.setLogLevel(LogLevel.error);
      await Purchases.configure(PurchasesConfiguration(apiKey));
    } catch (e) {
      debugPrint('RevenueCat init error: $e');
    }
  }

  Future<void> _initLocalNotifications() async {
    if (kIsWeb) return; // flutter_local_notifications doesn't support web
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
        debugShowCheckedModeBanner: false,
        theme: AppTheme.dark,
        home: Scaffold(
          backgroundColor: AppColors.background,
          body: Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline_rounded,
                      color: AppColors.error, size: 48),
                  const SizedBox(height: 16),
                  Text(
                    'Something went wrong',
                    style: AppTextStyles.headlineSmall,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _error!,
                    style: AppTextStyles.bodySmall
                        .copyWith(color: AppColors.textSecondary),
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
      return MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: AppTheme.dark,
        home: const SplashView(),
      );
    }

    return const ProviderScope(child: MindsetForgeApp());
  }
}

class MindsetForgeApp extends ConsumerStatefulWidget {
  const MindsetForgeApp({super.key});

  @override
  ConsumerState<MindsetForgeApp> createState() => _MindsetForgeAppState();
}

class _MindsetForgeAppState extends ConsumerState<MindsetForgeApp> {
  DeepLinkService? _deepLinkService;

  @override
  void initState() {
    super.initState();
    // Start listening for partner-invite deep links (cold + warm start).
    if (!kIsWeb) {
      _deepLinkService = DeepLinkService(ref.read(routerProvider));
      _deepLinkService!.init();
    }
  }

  @override
  Widget build(BuildContext context) {
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
