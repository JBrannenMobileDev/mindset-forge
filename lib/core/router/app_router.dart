import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../features/auth/splash_screen.dart';
import '../../features/auth/welcome_screen.dart';
import '../../features/auth/login_screen.dart';
import '../../features/auth/signup_screen.dart';
import '../../features/auth/download_app_screen.dart';
import '../../features/onboarding/onboarding_screen.dart';
import '../../features/pricing/pricing_screen.dart';
import '../../features/dashboard/dashboard_screen.dart';
import '../../features/coach_chat/chat_screen.dart';
import '../../features/goals_habits/actions_screen.dart';
import '../../features/goals_habits/goal_detail_screen.dart';
import '../../features/goals_habits/habit_detail_screen.dart';
import '../../features/journal/journal_screen.dart';
import '../../features/journal/new_journal_entry_screen.dart';
import '../../features/journal/journal_entry_detail_screen.dart';
import '../../features/mindset/mindset_screen.dart';
import '../../features/mindset/blueprint_screen.dart';
import '../../features/mindset/affirmations_screen.dart';
import '../../features/mindset/blueprint_setup_screen.dart';
import '../../features/future_self/future_self_screen.dart';
import '../../features/progress/progress_screen.dart';
import '../../features/settings/settings_screen.dart';
import '../../features/settings/notification_settings_screen.dart';
import '../../features/notifications/notifications_screen.dart';
import '../../features/accountability/accountability_screen.dart';
import '../../features/accountability/partner_invite_screen.dart';
import '../../features/accountability/partner_dashboard_screen.dart';
import '../../features/deep_dive/deep_dive_screen.dart';
import '../../features/legal/legal_screen.dart';
import '../constants/app_strings.dart';
import '../constants/legal_content.dart';
import '../../providers/auth_provider.dart';
import '../services/pending_invite_store.dart';
import '../widgets/adaptive_nav_shell.dart';

/// Routes that are accessible without a subscription (besides auth/onboarding
/// paths). Partner accounts and unsubscribed users can still reach these.
const _noSubscriptionPaths = {
  '/pricing',
  '/settings',
  '/accountability',
  '/notifications',
  '/notification-settings',
};

/// Prefixes (sub-routes) reachable without a subscription.
const _noSubscriptionPrefixes = {'/partner-view'};

final routerProvider = Provider<GoRouter>((ref) {
  final notifier = _RouterRefreshNotifier(ref);

  return GoRouter(
    refreshListenable: notifier,
    initialLocation: '/splash',
    redirect: (context, state) {
      // Home-screen widget / Apple Watch open the app with a raw custom-scheme
      // URL (e.g. mindsetforge://focus). Flutter's deep linking hands that
      // straight to GoRouter, which has no matching route and would render the
      // "Page Not Found" screen. Translate the known widget/watch hosts to an
      // in-app path here; the auth/onboarding gates below re-run on the result.
      // `focus` carries intent to open the Plan Day sheet (the dashboard only
      // acts on it when no focus is set yet).
      if (state.uri.scheme == 'mindsetforge') {
        switch (state.uri.host) {
          case 'focus':
            return '/dashboard?focus=plan';
          case 'dashboard':
            return '/dashboard';
          // mindsetforge://action/<field> — a routine step tapped on the
          // widget. The dashboard fires the matching in-app navigation.
          case 'action':
            final field = state.uri.pathSegments.isNotEmpty
                ? state.uri.pathSegments.first
                : '';
            return field.isEmpty ? '/dashboard' : '/dashboard?action=$field';
        }
      }

      final authAsync = ref.read(authStateProvider);
      final profileAsync = ref.read(currentUserProfileProvider);
      final user = authAsync.valueOrNull;
      final profile = profileAsync.valueOrNull;

      final location = state.matchedLocation;
      final isOnAuthPath = location == '/welcome' ||
          location == '/login' ||
          location == '/signup' ||
          location == '/splash';
      // Legal pages (and the web app-download screen) are reachable pre-auth —
      // legal is linked from signup, download-app is where web users land when
      // they try to create an account.
      final isPublicInfoPath = location == '/terms' ||
          location == '/privacy' ||
          location == '/download-app';

      if (authAsync.isLoading) return null;

      if (user == null) {
        // Capture an invite opened by a logged-out user, then send them on to
        // create an account. The accept flow resumes automatically after they
        // sign in. On web, account creation lives in the mobile app, so route
        // them to the download screen instead of signup.
        if (location.startsWith('/partner-invite/')) {
          final id = location.substring('/partner-invite/'.length);
          PendingInviteStore.set(id);
          return kIsWeb ? '/download-app' : '/signup';
        }
        // Web account creation is mobile-only — redirect signup to the app
        // download screen. Login stays available for existing users.
        if (kIsWeb && location == '/signup') return '/download-app';
        if (isOnAuthPath || isPublicInfoPath) return null;
        return '/welcome';
      }

      if (location == '/splash') return null;

      // The partner-invite accept screen must always be reachable for a signed-in
      // user, regardless of onboarding or subscription state — otherwise the gates
      // below bounce an invited friend to onboarding/pricing/dashboard.
      if (location.startsWith('/partner-invite/')) return null;

      // Resume a pending partner invite once the user has an account. This
      // takes priority over the onboarding gate so invited partners skip
      // straight to accepting (acceptPartnerInvite marks onboarding complete).
      if (PendingInviteStore.hasPending) {
        final target = '/partner-invite/${PendingInviteStore.inviteId}';
        if (location != target) return target;
        return null;
      }

      // Wait for profile to load before making routing decisions
      if (profileAsync.isLoading) return null;

      // Signed in but no Firestore profile — send to splash/welcome; splash signs
      // out and restarts at auth welcome.
      if (profile == null) {
        if (location != '/welcome' && location != '/splash') {
          return '/welcome';
        }
        return null;
      }

      // Completed users shouldn't land back on onboarding.
      if (profile.hasCompletedOnboarding && location == '/onboarding') {
        return '/dashboard';
      }

      // Onboarding gate. New users must finish onboarding before using the app.
      // Partner accounts are exempt — they support their friend first and only
      // run onboarding when they opt into their own personal features.
      final needsOnboarding = !profile.hasCompletedOnboarding;
      if (needsOnboarding && !profile.isPartnerAccount) {
        if (location == '/onboarding') return null;
        return '/onboarding';
      }

      // Subscription gate. Free "partner" accounts are exempt (they get limited
      // app access funneled toward their own trial). Regular users must have an
      // active or trialing subscription to use the full app.
      final needsSubscription = !profile.isPartnerAccount &&
          profile.userType != 'admin' &&
          !profile.hasActiveSubscription;
      final isSubscriptionAllowedPath =
          _noSubscriptionPaths.contains(location) ||
              _noSubscriptionPrefixes.any((p) => location.startsWith(p));
      if (needsSubscription && !isSubscriptionAllowedPath && !isOnAuthPath) {
        return '/pricing';
      }

      if (isOnAuthPath) return '/dashboard';
      return null;
    },
    routes: [
      GoRoute(
        path: '/splash',
        builder: (_, __) => const SplashScreen(),
      ),
      GoRoute(
        path: '/welcome',
        // No page transition so the welcome screen appears in place over the
        // splash (the shared brand block stays put); only its CTAs animate in.
        pageBuilder: (_, __) => const NoTransitionPage(child: WelcomeScreen()),
      ),
      GoRoute(
        path: '/login',
        builder: (_, __) => const LoginScreen(),
      ),
      GoRoute(
        path: '/signup',
        builder: (_, __) => const SignupScreen(),
      ),
      GoRoute(
        path: '/download-app',
        builder: (_, __) => const DownloadAppScreen(),
      ),
      GoRoute(
        path: '/onboarding',
        builder: (_, __) => const OnboardingScreen(),
      ),
      GoRoute(
        path: '/pricing',
        builder: (_, state) {
          final source =
              state.uri.queryParameters['source'] ?? 'subscription_gate';
          return PricingScreen(source: source);
        },
      ),
      // Partner invite — accessible via deep link without subscription gate
      GoRoute(
        path: '/partner-invite/:inviteId',
        builder: (_, state) => PartnerInviteScreen(
          inviteId: state.pathParameters['inviteId']!,
        ),
      ),
      // Must be declared before ShellRoute so GoRouter matches the exact path
      // before the shell's /journal/:id wildcard can capture "new" as an id.
      GoRoute(
        path: '/journal/new',
        builder: (_, __) => const NewJournalEntryScreen(),
      ),
      ShellRoute(
        builder: (context, state, child) =>
            AdaptiveNavShell(location: state.matchedLocation, child: child),
        routes: [
          GoRoute(
            path: '/dashboard',
            builder: (_, state) => DashboardScreen(
              openPlanSheet: state.uri.queryParameters['focus'] == 'plan',
              actionField: state.uri.queryParameters['action'],
            ),
          ),
          GoRoute(
            path: '/chat',
            builder: (_, state) {
              final extra = state.extra as Map<String, dynamic>?;
              return ChatScreen(
                journalContext: extra?['journalContext'] as String?,
                journalPrompt: extra?['journalPrompt'] as String?,
              );
            },
          ),
          GoRoute(
            path: '/actions',
            builder: (_, state) => ActionsScreen(
              initialTab: state.uri.queryParameters['tab'],
            ),
            routes: [
              GoRoute(
                path: 'goal/:id',
                builder: (_, state) => GoalDetailScreen(
                  goalId: state.pathParameters['id']!,
                ),
              ),
              GoRoute(
                path: 'habit/:id',
                builder: (_, state) => HabitDetailScreen(
                  habitId: state.pathParameters['id']!,
                ),
              ),
            ],
          ),
          GoRoute(
            path: '/journal',
            builder: (_, __) => const JournalScreen(),
            routes: [
              GoRoute(
                path: ':id',
                builder: (_, state) => JournalEntryDetailScreen(
                  entryId: state.pathParameters['id']!,
                ),
              ),
            ],
          ),
          GoRoute(
            path: '/mindset',
            builder: (_, __) => const MindsetScreen(),
          ),
        ],
      ),
      GoRoute(
        path: '/blueprint',
        builder: (_, __) => const BlueprintScreen(),
      ),
      GoRoute(
        path: '/affirmations',
        builder: (_, __) => const AffirmationsScreen(),
      ),
      GoRoute(
        path: '/blueprint-setup',
        builder: (_, __) => const BlueprintSetupScreen(),
      ),
      GoRoute(
        path: '/future-self',
        builder: (_, __) => const FutureSelfScreen(),
      ),
      GoRoute(
        path: '/progress',
        builder: (_, __) => const ProgressScreen(),
      ),
      GoRoute(
        path: '/settings',
        builder: (_, __) => const SettingsScreen(),
      ),
      GoRoute(
        path: '/notifications',
        builder: (_, __) => const NotificationsScreen(),
      ),
      GoRoute(
        path: '/notification-settings',
        builder: (_, __) => const NotificationSettingsScreen(),
      ),
      GoRoute(
        path: '/accountability',
        builder: (_, __) => const AccountabilityScreen(),
      ),
      GoRoute(
        path: '/partner-view/:partnerUid',
        builder: (_, state) => PartnerDashboardScreen(
          partnerUid: state.pathParameters['partnerUid']!,
        ),
      ),
      GoRoute(
        path: '/deep-dive',
        builder: (_, __) => const DeepDiveScreen(),
      ),
      GoRoute(
        path: '/terms',
        builder: (_, __) => const LegalScreen(
          title: AppStrings.termsTitle,
          sections: LegalContent.terms,
        ),
      ),
      GoRoute(
        path: '/privacy',
        builder: (_, __) => const LegalScreen(
          title: AppStrings.privacyTitle,
          sections: LegalContent.privacy,
        ),
      ),
    ],
  );
});

/// Refreshes the router only when something the `redirect` callback actually
/// reads has changed — not on every emission of the auth/profile streams.
/// Firestore commonly delivers a cache snapshot immediately followed by a
/// server snapshot on cold start; without this filter each one forces a full
/// redirect re-evaluation (and downstream rebuild of whatever's on screen),
/// which is unnecessary churn right when the app is most likely to have
/// several other providers settling at the same time.
class _RouterRefreshNotifier extends ChangeNotifier {
  String? _lastUid;
  bool? _lastHasCompletedOnboarding;
  bool? _lastIsPartnerAccount;
  bool? _lastHasActiveSubscription;
  String? _lastUserType;

  _RouterRefreshNotifier(ProviderRef ref) {
    ref.listen(authStateProvider, (_, next) {
      final uid = next.valueOrNull?.uid;
      if (uid == _lastUid) return;
      _lastUid = uid;
      notifyListeners();
    });
    ref.listen(currentUserProfileProvider, (_, next) {
      final profile = next.valueOrNull;
      final hasCompletedOnboarding = profile?.hasCompletedOnboarding;
      final isPartnerAccount = profile?.isPartnerAccount;
      final hasActiveSubscription = profile?.hasActiveSubscription;
      final userType = profile?.userType;
      if (hasCompletedOnboarding == _lastHasCompletedOnboarding &&
          isPartnerAccount == _lastIsPartnerAccount &&
          hasActiveSubscription == _lastHasActiveSubscription &&
          userType == _lastUserType) {
        return;
      }
      _lastHasCompletedOnboarding = hasCompletedOnboarding;
      _lastIsPartnerAccount = isPartnerAccount;
      _lastHasActiveSubscription = hasActiveSubscription;
      _lastUserType = userType;
      notifyListeners();
    });
  }
}
