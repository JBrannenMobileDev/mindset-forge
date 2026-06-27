import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_spacing.dart';
import '../../core/constants/app_strings.dart';
import '../../core/constants/app_text_styles.dart';
import '../../core/widgets/app_button.dart';
import 'widgets/auth_scaffold.dart';

/// Branded landing screen shown to logged-out users after the splash.
///
/// On wide screens the brand sits in the [AuthScaffold] hero with the CTAs in
/// the form pane; on mobile the brand lockup heads a centered column over the
/// ambient glow. Account creation routes to the app-download screen on web,
/// since accounts can only be created in the mobile app.
class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return AuthScaffold(
      mobileGlow: true,
      mobileHeader: const Padding(
        padding: EdgeInsets.only(bottom: AppSpacing.xxl),
        child: AuthBrandBlock(),
      ),
      form: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            AppStrings.welcomeFormTitle,
            textAlign: TextAlign.center,
            style: AppTextStyles.displaySmall,
          ).animate().fadeIn(duration: 500.ms),
          const SizedBox(height: AppSpacing.sm),
          Text(
            AppStrings.welcomeFormSubtitle,
            textAlign: TextAlign.center,
            style: AppTextStyles.bodyLarge.copyWith(
              color: AppColors.textSecondary,
            ),
          ).animate().fadeIn(delay: 80.ms, duration: 500.ms),
          const SizedBox(height: AppSpacing.xl),
          AppPrimaryButton(
            label: AppStrings.getStarted,
            onPressed: () =>
                context.go(kIsWeb ? '/download-app' : '/signup'),
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
        ],
      ),
    );
  }
}
