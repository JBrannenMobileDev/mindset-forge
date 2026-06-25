import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../providers/auth_provider.dart';
import 'widgets/splash_view.dart';

class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen> {
  bool _minDelayPassed = false;
  bool _navigated = false;

  @override
  void initState() {
    super.initState();
    // Minimum on-screen time so the brand moment never flickers past; runs in
    // parallel with auth/profile resolution.
    Future.delayed(const Duration(milliseconds: 1500), () {
      if (mounted) setState(() => _minDelayPassed = true);
    });
  }

  void _tryNavigate() {
    if (!mounted || _navigated || !_minDelayPassed) return;

    final authAsync = ref.read(authStateProvider);
    if (authAsync.isLoading) return;

    final user = authAsync.valueOrNull;
    if (user != null) {
      final profileAsync = ref.read(currentUserProfileProvider);
      if (profileAsync.isLoading) return; // wait for next rebuild
    }

    _navigated = true;

    // Defer the navigation to after the current build frame completes.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final u = ref.read(authStateProvider).valueOrNull;
      if (u == null) {
        context.go('/login');
        return;
      }
      final profile = ref.read(currentUserProfileProvider).valueOrNull;
      if (profile == null || !profile.hasCompletedOnboarding) {
        context.go('/onboarding');
      } else {
        context.go('/dashboard');
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    // Watch both providers so we rebuild when they change, then attempt navigation.
    ref.watch(authStateProvider);
    ref.watch(currentUserProfileProvider);
    _tryNavigate();

    return const SplashView();
  }
}
