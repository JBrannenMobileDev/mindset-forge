import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../models/goal.dart';

/// Left-hand companion panel shown beside the onboarding step pane on wide
/// screens. It replaces the mobile top progress bar with a richer, branded
/// sense of place: the brand lockup, a vertical step tracker, and a live recap
/// of what the user has told us so far (their goals + identity qualities).
///
/// Purely presentational — it reads the shell's accumulated state via params
/// and dispatches nothing.
class OnboardingCompanionPanel extends StatelessWidget {
  final int currentStep;
  final List<Goal> goals;
  final String primaryGoalId;
  final List<String> identityQualities;

  const OnboardingCompanionPanel({
    super.key,
    required this.currentStep,
    required this.goals,
    required this.primaryGoalId,
    required this.identityQualities,
  });

  static const _steps = <String>[
    'Welcome',
    'Goals',
    'Focus',
    'Identity',
    'Beliefs',
    'Reveal',
  ];

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.xxl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _BrandLockup()
              .animate()
              .fadeIn(duration: 500.ms)
              .slideX(begin: -0.15, end: 0, duration: 500.ms),
          const Spacer(),
          _StepTracker(currentStep: currentStep)
              .animate()
              .fadeIn(delay: 150.ms, duration: 500.ms),
          const SizedBox(height: AppSpacing.xxl),
          Flexible(
            child: SingleChildScrollView(
              child: _CompanionRecap(
                goals: goals,
                primaryGoalId: primaryGoalId,
                identityQualities: identityQualities,
              ),
            ),
          ),
          const Spacer(),
          Text(
            AppStrings.appTagline,
            style: AppTextStyles.bodySmall.copyWith(color: AppColors.textMuted),
          ).animate().fadeIn(delay: 500.ms, duration: 500.ms),
        ],
      ),
    );
  }
}

class _BrandLockup extends StatelessWidget {
  const _BrandLockup();

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Image.asset(
          'assets/images/splash_logo.png',
          width: 44,
          height: 44,
          fit: BoxFit.contain,
        ),
        const SizedBox(width: AppSpacing.sm),
        Text.rich(
          TextSpan(
            style: AppTextStyles.headlineSmall,
            children: const [
              TextSpan(text: AppStrings.appNamePrefix),
              TextSpan(
                text: AppStrings.appNameAccent,
                style: TextStyle(color: AppColors.primary),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Vertical stepper: a connected column of dots + labels, with completed steps
/// checked, the current step highlighted, and upcoming steps muted.
class _StepTracker extends StatelessWidget {
  final int currentStep;

  const _StepTracker({required this.currentStep});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: List.generate(OnboardingCompanionPanel._steps.length, (i) {
        final isCompleted = i < currentStep;
        final isCurrent = i == currentStep;
        final isLast = i == OnboardingCompanionPanel._steps.length - 1;
        return _StepRow(
          label: OnboardingCompanionPanel._steps[i],
          isCompleted: isCompleted,
          isCurrent: isCurrent,
          isLast: isLast,
        );
      }),
    );
  }
}

class _StepRow extends StatelessWidget {
  final String label;
  final bool isCompleted;
  final bool isCurrent;
  final bool isLast;

  const _StepRow({
    required this.label,
    required this.isCompleted,
    required this.isCurrent,
    required this.isLast,
  });

  @override
  Widget build(BuildContext context) {
    final active = isCompleted || isCurrent;
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Column(
            children: [
              _StepDot(isCompleted: isCompleted, isCurrent: isCurrent),
              if (!isLast)
                Expanded(
                  child: Container(
                    width: 2,
                    margin: const EdgeInsets.symmetric(vertical: 4),
                    color: isCompleted
                        ? AppColors.primary.withValues(alpha: 0.5)
                        : AppColors.border,
                  ),
                ),
            ],
          ),
          const SizedBox(width: AppSpacing.md),
          Padding(
            padding: EdgeInsets.only(
              top: 2,
              bottom: isLast ? 0 : AppSpacing.md,
            ),
            child: Text(
              label,
              style: AppTextStyles.labelLarge.copyWith(
                color: isCurrent
                    ? AppColors.textPrimary
                    : active
                        ? AppColors.textSecondary
                        : AppColors.textMuted,
                fontWeight: isCurrent ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StepDot extends StatelessWidget {
  final bool isCompleted;
  final bool isCurrent;

  const _StepDot({required this.isCompleted, required this.isCurrent});

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      width: 24,
      height: 24,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: isCompleted
            ? AppColors.primary
            : isCurrent
                ? AppColors.primaryContainer
                : Colors.transparent,
        border: Border.all(
          color: isCompleted || isCurrent
              ? AppColors.primary
              : AppColors.border,
          width: isCurrent ? 2 : 1,
        ),
        boxShadow: isCurrent
            ? const [
                BoxShadow(
                  color: AppColors.primaryGlow,
                  blurRadius: 12,
                  spreadRadius: 1,
                ),
              ]
            : null,
      ),
      child: isCompleted
          ? const Icon(Icons.check_rounded, size: 14, color: Colors.white)
          : isCurrent
              ? Center(
                  child: Container(
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppColors.primary,
                    ),
                  ),
                )
              : null,
    );
  }
}

/// Live recap of what the user has entered so far. Sections appear only once
/// they have content, reinforcing "here's what you're building."
class _CompanionRecap extends StatelessWidget {
  final List<Goal> goals;
  final String primaryGoalId;
  final List<String> identityQualities;

  const _CompanionRecap({
    required this.goals,
    required this.primaryGoalId,
    required this.identityQualities,
  });

  @override
  Widget build(BuildContext context) {
    final hasGoals = goals.isNotEmpty;
    final hasQualities = identityQualities.isNotEmpty;

    if (!hasGoals && !hasQualities) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (hasGoals) ...[
          const _RecapHeader(label: AppStrings.onboardingRecapGoalsLabel),
          const SizedBox(height: AppSpacing.sm),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: goals
                .map((g) => _RecapChip(
                      label: g.title,
                      starred: g.id == primaryGoalId && goals.length > 1,
                    ))
                .toList(),
          ),
        ],
        if (hasGoals && hasQualities) const SizedBox(height: AppSpacing.lg),
        if (hasQualities) ...[
          const _RecapHeader(label: AppStrings.onboardingRecapIdentityLabel),
          const SizedBox(height: AppSpacing.sm),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: identityQualities
                .map((q) => _RecapChip(label: q))
                .toList(),
          ),
        ],
      ],
    ).animate().fadeIn(duration: 300.ms);
  }
}

class _RecapHeader extends StatelessWidget {
  final String label;

  const _RecapHeader({required this.label});

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: AppTextStyles.labelSmall.copyWith(
        color: AppColors.textMuted,
        letterSpacing: 0.8,
      ),
    );
  }
}

class _RecapChip extends StatelessWidget {
  final String label;
  final bool starred;

  const _RecapChip({required this.label, this.starred = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: AppColors.primaryContainer,
        borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (starred) ...[
            const Icon(Icons.star_rounded, size: 14, color: AppColors.primary),
            const SizedBox(width: 4),
          ],
          Flexible(
            child: Text(
              label,
              style:
                  AppTextStyles.bodySmall.copyWith(color: AppColors.primary),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}
