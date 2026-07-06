import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import '../constants/app_spacing.dart';
import '../constants/app_strings.dart';
import '../constants/app_text_styles.dart';
import 'app_button.dart';
import 'store_buttons.dart';

/// Shown when a single feature (not the whole app) is gated behind a minimum
/// build number — see `ensureFeatureVersion` in `lib/core/utils/version_gate.dart`.
///
/// Unlike `UpdateRequiredScreen` (the app-wide terminal gate), the rest of the
/// app still works here, so this dialog is closeable: the user can dismiss it
/// and keep using everything else, they just can't complete the one gated
/// action until they update.
Future<void> showUpdateRequiredDialog(BuildContext context, {String? message}) {
  return showDialog(
    context: context,
    barrierColor: AppColors.scrim,
    builder: (dialogContext) => Dialog(
      backgroundColor: AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppSpacing.radiusXl),
        side: BorderSide(color: AppColors.primary.withValues(alpha: 0.25)),
      ),
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.system_update_rounded,
              color: AppColors.primary,
              size: 40,
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              AppStrings.updateRequiredTitle,
              style: AppTextStyles.headlineSmall,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              message ?? AppStrings.updateRequiredBody,
              style: AppTextStyles.bodyMedium
                  .copyWith(color: AppColors.textSecondary),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.lg),
            const StoreButtons(),
            const SizedBox(height: AppSpacing.sm),
            AppTextButton(
              label: AppStrings.updateRequiredMaybeLater,
              onPressed: () => Navigator.of(dialogContext).pop(),
            ),
          ],
        ),
      ),
    ),
  );
}
