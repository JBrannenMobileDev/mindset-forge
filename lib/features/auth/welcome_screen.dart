import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_spacing.dart';
import '../../core/constants/app_strings.dart';
import '../../core/constants/app_text_styles.dart';
import '../../core/widgets/app_button.dart';

/// Branded landing screen shown to logged-out users after the splash.
///
/// Mirrors the splash visual language (dark background, ambient glow, glowing
/// brain mark, app name + tagline) but is interactive: it presents a primary
/// "Get Started" CTA and a secondary "Log in" link rather than auto-navigating.
class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        children: [
          const Positioned.fill(child: _AmbientGlow()),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.screenPaddingH,
              ),
              child: ConstrainedBox(
                constraints:
                    const BoxConstraints(maxWidth: AppSpacing.maxContentWidth),
                child: Column(
                  children: [
                    const Spacer(flex: 3),
                    const _LogoMark(),
                    const SizedBox(height: 28),
                    Text.rich(
                      TextSpan(
                        style: AppTextStyles.displayMedium
                            .copyWith(color: AppColors.textPrimary),
                        children: const [
                          TextSpan(text: AppStrings.appNamePrefix),
                          TextSpan(
                            text: AppStrings.appNameAccent,
                            style: TextStyle(color: AppColors.primary),
                          ),
                        ],
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 10),
                    Text(
                      AppStrings.appTagline,
                      textAlign: TextAlign.center,
                      style: AppTextStyles.bodyLarge
                          .copyWith(color: AppColors.textSecondary),
                    ),
                    const Spacer(flex: 4),
                    AppPrimaryButton(
                      label: AppStrings.getStarted,
                      onPressed: () => context.go('/signup'),
                    )
                        .animate()
                        .fadeIn(delay: 150.ms, duration: 500.ms)
                        .slideY(
                          begin: 0.3,
                          end: 0,
                          delay: 150.ms,
                          duration: 500.ms,
                        ),
                    const SizedBox(height: AppSpacing.sm),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          AppStrings.alreadyHaveAccount,
                          style: AppTextStyles.bodyMedium.copyWith(
                            color: AppColors.textSecondary,
                          ),
                        ),
                        AppTextButton(
                          label: AppStrings.loginLink,
                          onPressed: () => context.go('/login'),
                        ),
                      ],
                    ).animate().fadeIn(delay: 300.ms, duration: 500.ms),
                    const SizedBox(height: AppSpacing.lg),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AmbientGlow extends StatelessWidget {
  const _AmbientGlow();

  @override
  Widget build(BuildContext context) {
    return const DecoratedBox(
      decoration: BoxDecoration(
        gradient: RadialGradient(
          center: Alignment(0, -0.35),
          radius: 0.9,
          colors: [
            Color(0x269B40FF),
            Color(0x000A0A0F),
          ],
          stops: [0.0, 1.0],
        ),
      ),
    );
  }
}

class _LogoMark extends StatelessWidget {
  const _LogoMark();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 200,
      height: 200,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: AppColors.primary.withValues(alpha: 0.40),
                  blurRadius: 56,
                  spreadRadius: 8,
                ),
              ],
            ),
          )
              .animate(onPlay: (c) => c.repeat(reverse: true))
              .scaleXY(
                begin: 0.88,
                end: 1.18,
                duration: 2000.ms,
                curve: Curves.easeInOut,
              )
              .fade(begin: 0.4, end: 1.0, duration: 2000.ms),
          Image.asset(
            'assets/images/splash_logo.png',
            width: 200,
            height: 200,
            fit: BoxFit.contain,
          ),
        ],
      ),
    );
  }
}
