import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../features/auth/splash_screen.dart';
import '../../features/auth/login_screen.dart';
import '../../features/auth/signup_screen.dart';
import '../../features/onboarding/onboarding_screen.dart';
import '../../features/pricing/pricing_screen.dart';
import '../../features/dashboard/dashboard_screen.dart';
import '../../features/coach_chat/chat_screen.dart';
import '../../features/goals_habits/actions_screen.dart';
import '../../features/journal/journal_screen.dart';
import '../../features/journal/new_journal_entry_screen.dart';
import '../../features/journal/journal_entry_detail_screen.dart';
import '../../features/mindset/mindset_screen.dart';
import '../../features/future_self/future_self_screen.dart';
import '../../features/progress/progress_screen.dart';
import '../../features/settings/settings_screen.dart';
import '../../features/notifications/notifications_screen.dart';
import '../../features/accountability/accountability_screen.dart';
import '../../features/accountability/partner_invite_screen.dart';
import '../../features/accountability/partner_dashboard_screen.dart';
import '../../features/deep_dive/deep_dive_screen.dart';
import '../../providers/auth_provider.dart';
import '../widgets/bottom_nav_shell.dart';

/// Routes that are accessible without a subscription (besides auth/onboarding paths).
// ignore: unused_element
const _noSubscriptionPaths = {'/pricing', '/settings'};

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
      final isOnAuthPath = location == '/login' ||
          location == '/signup' ||
          location == '/splash';

      if (authAsync.isLoading) return null;

      if (user == null) {
        if (isOnAuthPath) return null;
        return '/login';
      }

      if (location == '/splash') return null;

      // Wait for profile to load before making routing decisions
      if (profileAsync.isLoading) return null;

      // No profile doc or onboarding incomplete → send to onboarding
      if (profile == null || profile.onboardingStep < 6) {
        if (location == '/onboarding') return null;
        return '/onboarding';
      }

      // Subscription gate disabled during development — re-enable before App Store release.
      // final needsSubscription = profile.userType == 'user' &&
      //     profile.subscriptionStatus != 'active' &&
      //     profile.subscriptionStatus != 'trialing';
      // if (needsSubscription && !_noSubscriptionPaths.contains(location) && !isOnAuthPath) {
      //   return '/pricing';
      // }

      if (isOnAuthPath) return '/dashboard';
      return null;
    },
    routes: [
      GoRoute(
        path: '/splash',
        builder: (_, __) => const SplashScreen(),
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
              );
            },
          ),
          GoRoute(
            path: '/actions',
            builder: (_, __) => const ActionsScreen(),
          ),
          GoRoute(
            path: '/journal',
            builder: (_, __) => const JournalScreen(),
            routes: [
              GoRoute(
                path: 'new',
                builder: (_, __) => const NewJournalEntryScreen(),
              ),
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
    ],
  );
});

class _RouterRefreshNotifier extends ChangeNotifier {
  _RouterRefreshNotifier(ProviderRef ref) {
    ref.listen(authStateProvider, (_, __) => notifyListeners());
    ref.listen(currentUserProfileProvider, (_, __) => notifyListeners());
  }
}
