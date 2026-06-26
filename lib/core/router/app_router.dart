import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../features/auth/splash_screen.dart';
import '../../features/auth/welcome_screen.dart';
import '../../features/auth/login_screen.dart';
import '../../features/auth/signup_screen.dart';
import '../../features/onboarding/onboarding_screen.dart';
import '../../features/pricing/pricing_screen.dart';
import '../../features/dashboard/dashboard_screen.dart';
import '../../features/coach_chat/chat_screen.dart';
import '../../features/goals_habits/actions_screen.dart';
import '../../features/goals_habits/goal_detail_screen.dart';
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
import '../widgets/bottom_nav_shell.dart';

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
      final authAsync = ref.read(authStateProvider);
      final profileAsync = ref.read(currentUserProfileProvider);
      final user = authAsync.valueOrNull;
      final profile = profileAsync.valueOrNull;

      final location = state.matchedLocation;
      final isOnAuthPath = location == '/welcome' ||
          location == '/login' ||
          location == '/signup' ||
          location == '/splash';
      // Legal pages are reachable pre-auth (linked from the signup screen).
      final isPublicInfoPath = location == '/terms' || location == '/privacy';

      if (authAsync.isLoading) return null;

      if (user == null) {
        // Capture an invite opened by a logged-out user, then send them to
        // sign-up. The accept flow resumes automatically after they sign in.
        if (location.startsWith('/partner-invite/')) {
          final id = location.substring('/partner-invite/'.length);
          PendingInviteStore.set(id);
          return '/signup';
        }
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

      // Onboarding gate. New users must finish onboarding before using the app.
      // Partner accounts are exempt — they support their friend first and only
      // run onboarding when they opt into their own personal features.
      final needsOnboarding =
          profile == null || !profile.hasCompletedOnboarding;
      if (needsOnboarding && !(profile?.isPartnerAccount ?? false)) {
        if (location == '/onboarding') return null;
        return '/onboarding';
      }
      // Past this point a null profile is impossible (it would not be a partner
      // and would have been redirected above) — guard for null safety.
      if (profile == null) return null;

      // Subscription gate. Free "partner" accounts are exempt (they get limited
      // app access funneled toward their own trial). Regular users must have an
      // active or trialing subscription to use the full app.
      final needsSubscription = !profile.isPartnerAccount &&
          profile.userType != 'admin' &&
          !profile.hasActiveSubscription;
      final isSubscriptionAllowedPath =
          _noSubscriptionPaths.contains(location) ||
              _noSubscriptionPrefixes.any((p) => location.startsWith(p));
      if (needsSubscription &&
          !isSubscriptionAllowedPath &&
          !isOnAuthPath) {
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
        path: '/onboarding',
        builder: (_, __) => const OnboardingScreen(),
      ),
      GoRoute(
        path: '/pricing',
        builder: (_, __) => const PricingScreen(),
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
            BottomNavShell(child: child, location: state.matchedLocation),
        routes: [
          GoRoute(
            path: '/dashboard',
            builder: (_, __) => const DashboardScreen(),
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

class _RouterRefreshNotifier extends ChangeNotifier {
  _RouterRefreshNotifier(ProviderRef ref) {
    ref.listen(authStateProvider, (_, __) => notifyListeners());
    ref.listen(currentUserProfileProvider, (_, __) => notifyListeners());
  }
}
