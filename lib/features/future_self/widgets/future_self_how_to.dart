import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/constants/app_text_styles.dart';

/// The shared "how to practice" method content (4 numbered steps + reassurance).
/// Single source of truth used by both the one-time primer screen and the
/// always-available expandable guide on the detail screen.
class FutureSelfHowToContent extends StatelessWidget {
  /// When true, shows the intro line above the steps (used by the primer).
  final bool showIntro;

  const FutureSelfHowToContent({super.key, this.showIntro = true});

  @override
  Widget build(BuildContext context) {
    const steps = AppStrings.futureSelfHowToSteps;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (showIntro) ...[
          Text(
            AppStrings.futureSelfHowToIntro,
            style: AppTextStyles.bodyMedium
                .copyWith(color: AppColors.textSecondary, height: 1.6),
          ),
          const SizedBox(height: AppSpacing.lg),
        ],
        ...steps.asMap().entries.map(
              (e) => Padding(
                padding: EdgeInsets.only(
                    bottom: e.key == steps.length - 1
                        ? 0
                        : AppSpacing.lg),
                child: _Step(
                  number: e.key + 1,
                  title: e.value.$1,
                  body: e.value.$2,
                ),
              ),
            ),
        const SizedBox(height: AppSpacing.lg),
        Container(
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            color: AppColors.futureSelfAccent.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
            border: Border.all(
                color: AppColors.futureSelfAccent.withValues(alpha: 0.2)),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.favorite_rounded,
                  color: AppColors.futureSelfAccent, size: 16),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  AppStrings.futureSelfHowToReassurance,
                  style: AppTextStyles.bodySmall.copyWith(
                      color: AppColors.textSecondary, height: 1.5),
                ),
              ),
            ],
          ),
        ),
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
            color: AppColors.futureSelfAccent.withValues(alpha: 0.15),
            shape: BoxShape.circle,
            border: Border.all(
                color: AppColors.futureSelfAccent.withValues(alpha: 0.4)),
          ),
          child: Center(
            child: Text('$number',
                style: AppTextStyles.labelLarge
                    .copyWith(color: AppColors.futureSelfAccent)),
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

/// One-time primer shown before the user's first practice. Pops with `true`
/// when the user is ready to begin so the caller can proceed into the player.
class FutureSelfHowToScreen extends StatelessWidget {
  const FutureSelfHowToScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.futureSelfBackground,
      appBar: AppBar(
        backgroundColor: AppColors.futureSelfBackground,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close_rounded,
              color: AppColors.futureSelfAccent),
          onPressed: () => Navigator.of(context).pop(false),
        ),
        title: Text(
          AppStrings.futureSelfHowToTitle,
          style: AppTextStyles.headlineSmall
              .copyWith(color: AppColors.futureSelfAccent),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            const Expanded(
              child: SingleChildScrollView(
                padding: EdgeInsets.fromLTRB(AppSpacing.screenPaddingH,
                    AppSpacing.md, AppSpacing.screenPaddingH, AppSpacing.xl),
                child: FutureSelfHowToContent(),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(AppSpacing.screenPaddingH,
                  AppSpacing.sm, AppSpacing.screenPaddingH, AppSpacing.lg),
              child: SizedBox(
                height: AppSpacing.buttonHeight,
                child: ElevatedButton(
                  onPressed: () => Navigator.of(context).pop(true),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.futureSelfAccent,
                    foregroundColor: Colors.black,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius:
                          BorderRadius.circular(AppSpacing.radiusMd),
                    ),
                  ),
                  child: Text(AppStrings.futureSelfHowToBegin,
                      style: AppTextStyles.button.copyWith(color: Colors.black)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
