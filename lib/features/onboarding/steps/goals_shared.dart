import 'package:flutter/material.dart';
export '../../../core/constants/goal_templates.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../core/widgets/app_button.dart';

/// Shared pinned footer for onboarding goal steps (Back + primary CTA).
class OnboardingGoalsFooter extends StatelessWidget {
  final VoidCallback onBack;
  final String continueLabel;
  final VoidCallback? onContinue;
  final IconData continueIcon;

  const OnboardingGoalsFooter({
    super.key,
    required this.onBack,
    this.continueLabel = 'Continue',
    required this.onContinue,
    this.continueIcon = Icons.arrow_forward_rounded,
  });

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).padding.bottom;
    final keyboardVisible = MediaQuery.of(context).viewInsets.bottom > 0;

    return Positioned(
      left: 0,
      right: 0,
      bottom: 0,
      child: AnimatedOpacity(
        opacity: keyboardVisible ? 0.0 : 1.0,
        duration: const Duration(milliseconds: 200),
        child: IgnorePointer(
          ignoring: keyboardVisible,
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  AppColors.background.withValues(alpha: 0),
                  AppColors.background,
                ],
                stops: const [0.0, 0.45],
              ),
            ),
            padding: EdgeInsets.fromLTRB(
              AppSpacing.screenPaddingH,
              AppSpacing.xl,
              AppSpacing.screenPaddingH,
              bottomInset + AppSpacing.md,
            ),
            child: Row(
              children: [
                AppSecondaryButton(
                  label: 'Back',
                  width: 100,
                  onPressed: onBack,
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: AppPrimaryButton(
                    label: continueLabel,
                    onPressed: onContinue,
                    icon: continueIcon,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
