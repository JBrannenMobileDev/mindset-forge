import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../constants/app_colors.dart';
import '../constants/app_spacing.dart';
import '../constants/app_strings.dart';
import '../constants/app_text_styles.dart';
import 'store_buttons.dart';

/// Full-screen terminal gate shown when the installed build is below
/// `AppVersionGateService`'s global `minBuildNumber` — the app is replaced
/// with this screen entirely (see `_InitAppState.build` in `lib/main.dart`).
///
/// Unlike `showUpdateRequiredDialog` (used for single-feature gates), this
/// has no dismiss action: when the global gate is active nothing else in the
/// app works either, so there is nothing to fall back to but updating.
class UpdateRequiredScreen extends StatelessWidget {
  const UpdateRequiredScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.screenPaddingH,
              vertical: AppSpacing.xxl,
            ),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const _UpdateIcon(),
                  const SizedBox(height: AppSpacing.xl),
                  Text(
                    AppStrings.updateRequiredTitle,
                    textAlign: TextAlign.center,
                    style: AppTextStyles.displaySmall,
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    AppStrings.updateRequiredAppBody,
                    textAlign: TextAlign.center,
                    style: AppTextStyles.bodyLarge.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  const StoreButtons(),
                ],
              ).animate().fadeIn(duration: 400.ms),
            ),
          ),
        ),
      ),
    );
  }
}

/// Gradient icon badge — the hero mark for the update-required screen.
class _UpdateIcon extends StatelessWidget {
  const _UpdateIcon();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: 72,
        height: 72,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [AppColors.primary, AppColors.secondary],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(AppSpacing.radiusXl),
          boxShadow: const [
            BoxShadow(color: AppColors.primaryGlow, blurRadius: 32),
          ],
        ),
        child: const Icon(
          Icons.system_update_rounded,
          color: Colors.white,
          size: 40,
        ),
      ),
    );
  }
}
