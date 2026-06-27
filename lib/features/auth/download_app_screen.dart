import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_spacing.dart';
import '../../core/constants/app_strings.dart';
import '../../core/constants/app_text_styles.dart';
import '../../core/widgets/app_button.dart';
import '../../core/widgets/store_buttons.dart';
import 'widgets/auth_scaffold.dart';

/// Shown to web users who try to create an account. Accounts (and the
/// subscriptions that back them) are only available in the mobile app, so we
/// direct them to the stores while keeping login available for existing users.
class DownloadAppScreen extends StatelessWidget {
  const DownloadAppScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return AuthScaffold(
      form: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            AppStrings.downloadTitle,
            style: AppTextStyles.displaySmall,
          ).animate().fadeIn(duration: 400.ms),
          const SizedBox(height: AppSpacing.sm),
          Text(
            AppStrings.downloadSubtitle,
            style: AppTextStyles.bodyLarge.copyWith(
              color: AppColors.textSecondary,
            ),
          ).animate().fadeIn(delay: 100.ms, duration: 400.ms),
          const SizedBox(height: AppSpacing.xxl),
          const StoreButtons().animate().fadeIn(delay: 200.ms, duration: 400.ms),
          const SizedBox(height: AppSpacing.xl),
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
          ).animate().fadeIn(delay: 300.ms, duration: 400.ms),
        ],
      ),
    );
  }
}
