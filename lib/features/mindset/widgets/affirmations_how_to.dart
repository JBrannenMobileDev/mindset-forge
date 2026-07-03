import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/manifestation_system_explainer.dart';

/// Dismissible primer shown at the top of the Affirmations screen for users who
/// have not yet dismissed it. Explains what affirmations are in plain language,
/// acknowledges the seeded starters, and links to the full how-to sheet. Never
/// blocks the list or setup actions.
class AffirmationsIntroCard extends StatelessWidget {
  final VoidCallback onLearnMore;
  final VoidCallback onDismiss;

  const AffirmationsIntroCard({
    super.key,
    required this.onLearnMore,
    required this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: AppColors.primaryContainer,
                  borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                ),
                child: const Icon(Icons.lightbulb_outline_rounded,
                    size: 18, color: AppColors.primary),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(AppStrings.affirmationsIntroTitle,
                    style: AppTextStyles.headlineSmall),
              ),
              GestureDetector(
                onTap: onDismiss,
                child: Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: AppColors.surfaceElevated,
                    borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
                  ),
                  child: const Icon(Icons.close_rounded,
                      size: 15, color: AppColors.textMuted),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            AppStrings.affirmationsIntroBody,
            style: AppTextStyles.bodyMedium
                .copyWith(color: AppColors.textSecondary),
          ),
          const SizedBox(height: AppSpacing.sm),
          Align(
            alignment: Alignment.centerLeft,
            child: AppTextButton(
              label: AppStrings.affirmationsIntroLearnMore,
              onPressed: onLearnMore,
            ),
          ),
        ],
      ),
    ).animate().fadeIn(duration: 400.ms);
  }
}

/// Shared, always-available education content: what affirmations are, how to run
/// a session well, and why morning + evening. Single source of truth for the
/// how-to sheet.
class AffirmationsHowToContent extends StatelessWidget {
  final VoidCallback? onOpenSystem;

  const AffirmationsHowToContent({super.key, this.onOpenSystem});

  @override
  Widget build(BuildContext context) {
    const steps = AppStrings.affirmationsHowToSteps;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          AppStrings.affirmationsHowToIntro,
          style: AppTextStyles.bodyMedium
              .copyWith(color: AppColors.textSecondary, height: 1.6),
        ),
        const SizedBox(height: AppSpacing.lg),
        ...steps.asMap().entries.map(
              (e) => Padding(
                padding: EdgeInsets.only(
                    bottom: e.key == steps.length - 1 ? 0 : AppSpacing.lg),
                child: _Step(
                  number: e.key + 1,
                  title: e.value.$1,
                  body: e.value.$2,
                ),
              ),
            ),
        const SizedBox(height: AppSpacing.lg),
        const _WhyBlock(
          title: AppStrings.manifestationWindowTitle,
          body: AppStrings.manifestationWindowBody,
        ),
        const SizedBox(height: AppSpacing.md),
        Container(
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            color: AppColors.primaryContainer,
            borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
            border:
                Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.favorite_rounded,
                  color: AppColors.primary, size: 16),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  AppStrings.affirmationsHowToReassurance,
                  style: AppTextStyles.bodySmall.copyWith(
                      color: AppColors.textSecondary, height: 1.5),
                ),
              ),
            ],
          ),
        ),
        if (onOpenSystem != null) ...[
          const SizedBox(height: AppSpacing.sm),
          Align(
            alignment: Alignment.centerLeft,
            child: AppTextButton(
              label: AppStrings.affirmationsHowToSystemLink,
              onPressed: onOpenSystem!,
            ),
          ),
        ],
      ],
    );
  }
}

class _Step extends StatelessWidget {
  final int number;
  final String title;
  final String body;

  const _Step({required this.number, required this.title, required this.body});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 30,
          height: 30,
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.15),
            shape: BoxShape.circle,
            border:
                Border.all(color: AppColors.primary.withValues(alpha: 0.4)),
          ),
          child: Center(
            child: Text('$number',
                style: AppTextStyles.labelLarge
                    .copyWith(color: AppColors.primary)),
          ),
        ),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: AppTextStyles.labelLarge),
              const SizedBox(height: AppSpacing.xs),
              Text(body,
                  style: AppTextStyles.bodySmall.copyWith(
                      color: AppColors.textSecondary, height: 1.6)),
            ],
          ),
        ),
      ],
    );
  }
}

class _WhyBlock extends StatelessWidget {
  final String title;
  final String body;

  const _WhyBlock({required this.title, required this.body});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surfaceElevated,
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: AppTextStyles.labelLarge),
          const SizedBox(height: AppSpacing.xs),
          Text(body,
              style: AppTextStyles.bodySmall
                  .copyWith(color: AppColors.textSecondary, height: 1.6)),
        ],
      ),
    );
  }
}

/// Opens the affirmations education as a draggable bottom sheet with a "Got it"
/// dismiss. Modeled on [showManifestationSystemSheet].
Future<void> showAffirmationsHowToSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: AppColors.surface,
    barrierColor: AppColors.scrim,
    isScrollControlled: true,
    useRootNavigator: true,
    shape: const RoundedRectangleBorder(
      borderRadius:
          BorderRadius.vertical(top: Radius.circular(AppSpacing.radiusXl)),
    ),
    builder: (sheetContext) => DraggableScrollableSheet(
      initialChildSize: 0.85,
      maxChildSize: 0.95,
      minChildSize: 0.5,
      expand: false,
      builder: (_, controller) => Column(
        children: [
          const SizedBox(height: AppSpacing.md),
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.border,
                borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          Expanded(
            child: SingleChildScrollView(
              controller: controller,
              padding: EdgeInsets.fromLTRB(
                AppSpacing.lg,
                0,
                AppSpacing.lg,
                AppSpacing.xxl + MediaQuery.of(sheetContext).padding.bottom,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(AppStrings.affirmationsHowToTitle,
                      style: AppTextStyles.headlineMedium),
                  const SizedBox(height: AppSpacing.lg),
                  AffirmationsHowToContent(
                    onOpenSystem: () {
                      Navigator.of(sheetContext).pop();
                      showManifestationSystemSheet(context);
                    },
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  AppPrimaryButton(
                    label: AppStrings.affirmationsHowToCta,
                    onPressed: () => Navigator.of(sheetContext).pop(),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    ),
  );
}
