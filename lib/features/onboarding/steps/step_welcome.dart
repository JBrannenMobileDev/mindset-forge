import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/widgets/app_button.dart';

class StepWelcome extends StatelessWidget {
  final VoidCallback onNext;

  const StepWelcome({super.key, required this.onNext});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.screenPaddingH),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 96,
            height: 96,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [AppColors.primary, AppColors.secondary],
              ),
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: AppColors.primaryGlow,
                  blurRadius: 40,
                  spreadRadius: 8,
                ),
              ],
            ),
            child: const Icon(Icons.auto_awesome_rounded, color: Colors.white, size: 48),
          )
              .animate()
              .fadeIn(duration: 600.ms)
              .scale(begin: const Offset(0.7, 0.7), duration: 600.ms, curve: Curves.elasticOut),
          const SizedBox(height: AppSpacing.xl),
          Text(
            AppStrings.onboardingWelcomeTitle,
            style: AppTextStyles.displaySmall,
            textAlign: TextAlign.center,
          ).animate().fadeIn(delay: 300.ms, duration: 500.ms).slideY(begin: 0.3, end: 0, delay: 300.ms),
          const SizedBox(height: AppSpacing.md),
          Text(
            AppStrings.onboardingWelcomeSubtitle,
            style: AppTextStyles.bodyLarge.copyWith(color: AppColors.textSecondary),
            textAlign: TextAlign.center,
          ).animate().fadeIn(delay: 500.ms, duration: 500.ms),
          const SizedBox(height: AppSpacing.xxl),
          _FeatureRow(
            icon: Icons.psychology_rounded,
            title: 'Personalized Coaching',
            subtitle: 'A coach that adapts to you and remembers your story',
          ).animate().fadeIn(delay: 700.ms, duration: 400.ms),
          const SizedBox(height: AppSpacing.md),
          _FeatureRow(
            icon: Icons.track_changes_rounded,
            title: 'Goal Achievement System',
            subtitle: 'Break down goals into identity-driven daily actions',
          ).animate().fadeIn(delay: 800.ms, duration: 400.ms),
          const SizedBox(height: AppSpacing.md),
          _FeatureRow(
            icon: Icons.auto_fix_high_rounded,
            title: 'Mindset Reprogramming',
            subtitle: 'Replace limiting beliefs with empowering identities',
          ).animate().fadeIn(delay: 900.ms, duration: 400.ms),
          const SizedBox(height: AppSpacing.xxxl),
          AppPrimaryButton(
            label: AppStrings.onboardingNext,
            onPressed: onNext,
          ).animate().fadeIn(delay: 1000.ms, duration: 400.ms),
        ],
      ),
    );
  }
}

class _FeatureRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;

  const _FeatureRow({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: AppColors.primaryContainer,
            borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
          ),
          child: Icon(icon, color: AppColors.primary, size: AppSpacing.iconLg),
        ),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: AppTextStyles.labelLarge),
              Text(
                subtitle,
                style: AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondary),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
