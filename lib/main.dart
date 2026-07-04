import 'dart:async';
import 'dart:io';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:home_widget/home_widget.dart';
import 'package:just_audio_background/just_audio_background.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';

import 'core/constants/app_colors.dart';
import 'core/constants/app_text_styles.dart';
import 'core/firebase/firestore_service.dart';
import 'core/router/app_router.dart';
import 'core/services/analytics_service.dart';
import 'core/services/consent_service.dart';
import 'core/services/deep_link_service.dart';
import 'core/services/notification_service.dart';
import 'core/services/pending_invite_store.dart';
import 'core/services/widget_sync_service.dart';
import 'core/theme/app_theme.dart';
import 'core/utils/boot_log.dart';
import 'core/widgets/cookie_consent_banner.dart';
import 'features/auth/widgets/splash_view.dart';
import 'firebase_options.dart';
import 'providers/auth_provider.dart';
import 'providers/notification_provider.dart';
import 'providers/widget_sync_provider.dart';

// RevenueCat API keys (public SDK keys — safe to ship in the client).
const _revenueCatApiKeyIos = 'appl_dKUUgDcXtEccZBfJkLEoToRdSri';
const _revenueCatApiKeyAndroid = 'goog_nERDlnjwKvZeslXynNPyZMfzBee';

// App Check reCAPTCHA v3 site key for the web app (public — safe to ship).
const _recaptchaV3SiteKey = '6Ld6Tz4tAAAAAKc7HFs4rXeFvReyPzuDku47yNjH';

/// Handle background FCM messages
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
}

void main() async {
  runZonedGuarded(
    () async {
      final binding = WidgetsFlutterBinding.ensureInitialized();
      bootLog('binding ready');

      // Set up the background audio service so the Future Self practice's
      // binaural beats keep playing when the screen locks or the app is
      // backgrounded (foreground media service on Android, audio session on
      // iOS). Guarded so a failure here can never trap the boot on the splash.
      try {
        await JustAudioBackground.init(
          androidNotificationChannelId: 'com.mindsetforge.audio',
          androidNotificationChannelName: 'Future Self Practice',
          androidNotificationOngoing: true,
          androidStopForegroundOnPause: true,
        );
        bootLog('JustAudioBackground.init done');
      } catch (e) {
        bootLog('JustAudioBackground.init FAILED: $e');
      }
      // Hold the native splash on screen until the first Flutter frame paints so
      // there is no gap between the OS launch screen and our SplashView.
      FlutterNativeSplash.preserve(widgetsBinding: binding);
      bootLog('native splash preserved');

      // Firebase MUST be initialized before any Firebase service is touched
      // (Crashlytics error handler, FCM background handler below). Accessing a
      // Firebase plugin before initializeApp can throw/hang before runApp, which
      // leaves the native splash up forever. _InitApp guards a second call.
      try {
        await Firebase.initializeApp(
          options: DefaultFirebaseOptions.currentPlatform,
        );
        bootLog('Firebase.initializeApp (main) done');
      } catch (e) {
        bootLog('Firebase.initializeApp (main) FAILED: $e');
      }

      // App Check attests that requests originate from a genuine app build
      // (App Attest on iOS, Play Integrity on Android, reCAPTCHA v3 on web).
      // Activated here so new builds start sending tokens now; server-side
      // enforcement (enforceAppCheck) stays OFF until every user is on a build
      // that ships this, so older builds keep working in the meantime. Wrapped
      // so an attestation failure can never block boot while enforcement is off.
      try {
        await FirebaseAppCheck.instance.activate(
          webProvider: ReCaptchaV3Provider(_recaptchaV3SiteKey),
          appleProvider: kDebugMode
              ? AppleProvider.debug
              : AppleProvider.appAttestWithDeviceCheckFallback,
          androidProvider: kDebugMode
              ? AndroidProvider.debug
              : AndroidProvider.playIntegrity,
        );
        bootLog('app check activated');
      } catch (e) {
        bootLog('FirebaseAppCheck.activate FAILED: $e');
      }

      // Route all Flutter framework errors to Crashlytics.
      FlutterError.onError =
          FirebaseCrashlytics.instance.recordFlutterFatalError;
      bootLog('crashlytics handler set');

      // Register FCM background handler before Firebase init
      if (!kIsWeb) {
        FirebaseMessaging.onBackgroundMessage(
          _firebaseMessagingBackgroundHandler,
        );
        bootLog('fcm background handler set');
      }

      // Wire the home-screen widget: register the background callback that the
      // "Mark done" action invokes (iOS App Intent / Android broadcast). The App
      // Group binding is iOS-only; Android stores widget data in SharedPreferences.
      if (!kIsWeb && (Platform.isIOS || Platform.isAndroid)) {
        bootLog('home_widget setup start');
        if (Platform.isIOS) {
          await HomeWidget.setAppGroupId(WidgetSyncService.appGroupId);
        }
        await HomeWidget.registerInteractivityCallback(
          widgetInteractiveCallback,
        );
        bootLog('home_widget setup done');
      }

      bootLog('calling runApp');
      runApp(const _InitApp());
    },
    (error, stack) =>
        FirebaseCrashlytics.instance.recordError(error, stack, fatal: true),
  );
}

class _InitApp extends StatefulWidget {
  const _InitApp();

  @override
  State<_InitApp> createState() => _InitAppState();
}

class _InitAppState extends State<_InitApp> {
  bool _ready = false;
  String? _error;

  // Last subscription status pushed to Firestore from a RevenueCat customer-info
  // update this session — used to skip redundant writes when the listener fires
  // repeatedly (e.g. on every app foreground) with an unchanged entitlement.
  String? _lastSyncedSubStatus;

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
    bootLog('_init start — Firebase.initializeApp');
    try {
      // Already initialized in main() before runApp; only initialize here if
      // that didn't happen (e.g. web) to avoid a duplicate-app throw.
      if (Firebase.apps.isEmpty) {
        await Firebase.initializeApp(
          options: DefaultFirebaseOptions.currentPlatform,
        );
      }
      bootLog('Firebase.initializeApp done');
    } catch (e) {
      bootLog('Firebase.initializeApp FAILED: $e');
      setState(() => _error = 'Firebase init failed:\n$e');
      return;
    }

    // Catch errors outside the Flutter framework (native plugins, isolates)
    // and forward them to Crashlytics now that Firebase is initialized.
    PlatformDispatcher.instance.onError = (error, stack) {
      FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
      return true;
    };

    // Tag crash reports with the signed-in user so crashes can be grouped by
    // account in the Firebase console. Cleared to anonymous on sign-out.
    if (!kIsWeb) {
      FirebaseAuth.instance.authStateChanges().listen((user) {
        FirebaseCrashlytics.instance.setUserIdentifier(user?.uid ?? '');
      });
    }

    // None of the steps below are required to render the app. Each is guarded
    // and time-boxed so a slow network or a throwing plugin can never trap the
    // user on the splash screen — we always proceed to the router, which gates
    // on auth itself. Failures are logged (and forwarded to Crashlytics) so the
    // offending step is identifiable instead of silently hanging.
    await _guardStartupStep('pendingInvite', PendingInviteStore.load);
    await _guardStartupStep('consent', ConsentService.load);
    await _guardStartupStep('revenueCat', _initRevenueCat);
    await _guardStartupStep('localNotifications', _initLocalNotifications);
    await _guardStartupStep('analytics', _initAnalytics);

    SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle.light);
    if (!kIsWeb) {
      SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    }

    bootLog('all startup steps done — setting ready');
    if (mounted) setState(() => _ready = true);
  }

  /// Runs a non-critical startup step with a hard timeout and error guard so the
  /// app never gets stuck on the splash because one initializer hung or threw.
  Future<void> _guardStartupStep(
    String label,
    Future<void> Function() step,
  ) async {
    bootLog('step "$label" start');
    try {
      await step().timeout(const Duration(seconds: 8));
      bootLog('step "$label" done');
    } catch (e, stack) {
      debugPrint('Startup step "$label" failed (continuing): $e');
      FirebaseCrashlytics.instance.recordError(
        e,
        stack,
        reason: 'startup step "$label" failed',
        fatal: false,
      );
    }
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
      _syncRevenueCatIdentity();
      // Reconcile Firestore whenever RevenueCat's view of the customer changes
      // (purchase, restore, renewal, app foreground). This self-heals stale
      // subscription state if a webhook event was missed or delayed.
      Purchases.addCustomerInfoUpdateListener(_syncEntitlementToFirestore);
    } catch (e) {
      debugPrint('RevenueCat init error: $e');
    }
  }

  /// Mirrors the live `premium` entitlement onto the user's Firestore
  /// `subscriptionStatus`. Only heals upward (grants access) — cancellations and
  /// expirations remain authoritative through the webhook, so a transient read
  /// here never downgrades a user.
  Future<void> _syncEntitlementToFirestore(CustomerInfo info) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    final entitlement = info.entitlements.all['premium'];
    if (entitlement == null || !entitlement.isActive) return;
    final status = _statusForEntitlement(entitlement);
    if (status == _lastSyncedSubStatus) return;
    try {
      await FirestoreService().updateUserField(uid, {
        'subscriptionStatus': status,
      });
      _lastSyncedSubStatus = status;
    } catch (e) {
      debugPrint('RevenueCat entitlement sync failed: $e');
    }
  }

  /// Maps an active `premium` entitlement to a Firestore subscription status.
  /// `willRenew == false` on an active entitlement means the user cancelled but
  /// still has access until expiry, so it maps to 'canceled' (not 'active') to
  /// stay consistent with the webhook and avoid masking the ending state.
  static String _statusForEntitlement(EntitlementInfo entitlement) {
    if (entitlement.periodType == PeriodType.trial) return 'trialing';
    if (!entitlement.willRenew) return 'canceled';
    return 'active';
  }

  /// Keep the RevenueCat app user ID in sync with the Firebase UID so that
  /// server-side webhook events (renewals, cancellations, expirations) map to
  /// the correct `users/{uid}` document. Without this, RevenueCat uses an
  /// anonymous ID and the webhook cannot resolve the user. Fires immediately
  /// for an already-signed-in user on cold start and on every auth change.
  void _syncRevenueCatIdentity() {
    FirebaseAuth.instance.authStateChanges().listen((user) async {
      try {
        if (user != null) {
          await Purchases.logIn(user.uid);
        } else {
          await Purchases.logOut();
        }
      } catch (e) {
        // logOut throws if the current user is already anonymous — harmless.
        debugPrint('RevenueCat identity sync error: $e');
      }
    });
  }

  Future<void> _initLocalNotifications() async {
    if (kIsWeb) return; // flutter_local_notifications doesn't support web
    await NotificationService().initPlugin();
  }

  /// On web, analytics (Mixpanel) are non-essential cookies and must wait for
  /// the user's consent — the cookie banner initializes them on accept. On
  /// mobile, analytics run at startup as before.
  Future<void> _initAnalytics() async {
    if (kIsWeb && !ConsentService.granted) return;
    await AnalyticsService.init();
  }

  @override
  Widget build(BuildContext context) {
    bootLog('_InitApp.build ready=$_ready error=${_error != null}');
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

class _MindsetForgeAppState extends ConsumerState<MindsetForgeApp>
    with WidgetsBindingObserver {
  DeepLinkService? _deepLinkService;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    if (!kIsWeb) {
      final router = ref.read(routerProvider);
      // Start listening for partner-invite deep links (cold + warm start).
      _deepLinkService = DeepLinkService(router);
      _deepLinkService!.init();
      // Route notification taps (FCM open + cold-start launch) via the router.
      ref.read(notificationServiceProvider).attachRouter(router);
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _deepLinkService?.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _deepLinkService?.onLifecycleStateChanged(state);
    if (state == AppLifecycleState.resumed) {
      _onResume();
    }
  }

  /// On every foreground resume: re-check widget deep links, refresh activity
  /// tracking, and re-evaluate local reminders against today's live completion
  /// state (suppressing finished items).
  Future<void> _onResume() async {
    if (kIsWeb) return;
    await _deepLinkService?.handleLinksOnResume();
    final uid = ref.read(authStateProvider).valueOrNull?.uid;
    final profile = ref.read(currentUserProfileProvider).valueOrNull;
    if (uid == null) return;
    await ref
        .read(notificationServiceProvider)
        .markActive(uid, ref.read(firestoreServiceProvider));
    if (profile != null) {
      await ref.read(notificationSchedulerProvider).rescheduleAll(profile);
    }
  }

  @override
  Widget build(BuildContext context) {
    final router = ref.watch(routerProvider);
    // Eagerly activate notification initialization whenever a user is signed in.
    ref.watch(notificationInitProvider);
    // Keep the iOS widget + Apple Watch payload in sync with profile/completion
    // changes, and handle watch glance actions.
    ref.watch(widgetSyncInitProvider);
    // Reschedule local reminders whenever the profile changes (login, completion
    // updates, preference edits all flow through the profile stream).
    ref.listen(currentUserProfileProvider, (_, next) {
      next.whenData((profile) {
        if (profile != null && !kIsWeb) {
          ref.read(notificationSchedulerProvider).rescheduleAll(profile);
        }
        // Keep Mixpanel user profile in sync on every profile emission.
        if (profile != null) {
          final uid = ref.read(authStateProvider).valueOrNull?.uid;
          if (uid != null) {
            ref.read(analyticsServiceProvider).identify(uid, profile);
            migrateLegacyOnboardingStep(
              ref.read(firestoreServiceProvider),
              profile,
              uid,
            );
            migrateBlueprintCalibrationStart(
              ref.read(firestoreServiceProvider),
              profile,
              uid,
            );
          }
        }
      });
    });

    return MaterialApp.router(
      title: 'MindsetForge',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.dark,
      darkTheme: AppTheme.dark,
      themeMode: ThemeMode.dark,
      routerConfig: router,
      // Overlay the web cookie-consent banner above all routes. Renders nothing
      // on mobile or once the user has chosen.
      builder: (context, child) => Stack(
        children: [
          if (child != null) child,
          const CookieConsentBanner(),
        ],
      ),
    );
  }
}
