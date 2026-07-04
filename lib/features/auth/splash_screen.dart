import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/utils/boot_log.dart';
import '../../providers/auth_notifier.dart';
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
    bootLog('SplashScreen auth loading=${authAsync.isLoading} '
        'user=${authAsync.valueOrNull?.uid}');
    if (authAsync.isLoading) return;

    final user = authAsync.valueOrNull;
    if (user != null) {
      final profileAsync = ref.read(currentUserProfileProvider);
      bootLog('SplashScreen profile loading=${profileAsync.isLoading} '
          'hasValue=${profileAsync.hasValue}');
      if (profileAsync.isLoading) return; // wait for next rebuild
    }

    _navigated = true;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _navigateFromSplash();
    });
  }

  Future<void> _navigateFromSplash() async {
    if (!mounted) return;

    final u = ref.read(authStateProvider).valueOrNull;
    if (u == null) {
      context.go('/welcome');
      return;
    }

    final profile = ref.read(currentUserProfileProvider).valueOrNull;
    if (profile == null) {
      // Signed in but no Firestore profile — broken/orphan session.
      await ref.read(authNotifierProvider.notifier).signOut();
      if (!mounted) return;
      context.go('/welcome');
      return;
    }

    if (!profile.hasCompletedOnboarding) {
      context.go('/onboarding');
    } else {
      context.go('/dashboard');
    }
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
