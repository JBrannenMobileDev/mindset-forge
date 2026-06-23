import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_text_styles.dart';
import '../../core/constants/app_strings.dart';
import '../../providers/auth_provider.dart';

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
    Future.delayed(const Duration(milliseconds: 2200), () {
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
      if (profile == null || profile.onboardingStep < 6) {
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

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _LogoMark()
                .animate()
                .fadeIn(duration: 600.ms)
                .scale(begin: const Offset(0.8, 0.8), duration: 600.ms, curve: Curves.easeOut),
            const SizedBox(height: 24),
            Text(
              AppStrings.appName,
              style: AppTextStyles.displayMedium.copyWith(
                color: AppColors.textPrimary,
              ),
            )
                .animate()
                .fadeIn(delay: 400.ms, duration: 600.ms)
                .slideY(begin: 0.3, end: 0, delay: 400.ms, duration: 600.ms),
            const SizedBox(height: 8),
            Text(
              AppStrings.appTagline,
              style: AppTextStyles.bodyMedium.copyWith(
                color: AppColors.textSecondary,
              ),
              textAlign: TextAlign.center,
            )
                .animate()
                .fadeIn(delay: 600.ms, duration: 600.ms),
          ],
        ),
      ),
    );
  }
}

class _LogoMark extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 80,
      height: 80,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: AppColors.primaryGlow,
            blurRadius: 30,
            spreadRadius: 4,
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Image.asset(
          'assets/images/app_icon.png',
          width: 80,
          height: 80,
          fit: BoxFit.cover,
        ),
      ),
    );
  }
}
