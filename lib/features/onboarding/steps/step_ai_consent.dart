import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/widgets/app_button.dart';

/// Explicit AI data-sharing consent step, shown once during onboarding before
/// any AI call is made (the next step, [StepBlocker], is the first to call
/// the AI provider). Requires an affirmative checkbox before "Continue" is
/// enabled, so consent is a deliberate action rather than implied by
/// proceeding through onboarding.
class StepAiConsent extends StatefulWidget {
  final VoidCallback onNext;
  final VoidCallback onBack;

  const StepAiConsent({super.key, required this.onNext, required this.onBack});

  @override
  State<StepAiConsent> createState() => _StepAiConsentState();
}

class _StepAiConsentState extends State<StepAiConsent> {
  bool _agreed = false;
  bool _showHint = false;

  void _tryNext() {
    if (!_agreed) {
      setState(() => _showHint = true);
      return;
    }
    widget.onNext();
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).padding.bottom;

    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.screenPaddingH,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const SizedBox(height: AppSpacing.xl),
                Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    color: AppColors.primaryContainer,
                    borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
                  ),
                  child: const Icon(Icons.shield_rounded,
                      color: AppColors.primary, size: 34),
                ).animate().fadeIn(duration: 500.ms).scale(
                      begin: const Offset(0.7, 0.7),
                      duration: 500.ms,
                      curve: Curves.elasticOut,
                    ),
                const SizedBox(height: AppSpacing.lg),
                Text(
                  AppStrings.aiConsentTitle,
                  style: AppTextStyles.headlineLarge,
                ).animate().fadeIn(delay: 200.ms, duration: 400.ms),
                const SizedBox(height: AppSpacing.md),
                Text(
                  AppStrings.aiConsentBody,
                  style: AppTextStyles.bodyLarge.copyWith(
                    color: AppColors.textSecondary,
                    height: 1.6,
                  ),
                ).animate().fadeIn(delay: 300.ms, duration: 400.ms),
                const SizedBox(height: AppSpacing.md),
                GestureDetector(
                  onTap: () => context.push('/privacy'),
                  child: Text(
                    AppStrings.aiConsentReadMore,
                    style:
                        AppTextStyles.bodySmall.copyWith(color: AppColors.primary),
                  ),
                ).animate().fadeIn(delay: 350.ms, duration: 400.ms),
                const SizedBox(height: AppSpacing.xl),
              ],
            ),
          ),
        ),
        Padding(
          padding: EdgeInsets.fromLTRB(
            AppSpacing.screenPaddingH,
            AppSpacing.md,
            AppSpacing.screenPaddingH,
            bottomInset + AppSpacing.md,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              GestureDetector(
                onTap: () => setState(() {
                  _agreed = !_agreed;
                  if (_agreed) _showHint = false;
                }),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Checkbox(
                      value: _agreed,
                      onChanged: (v) => setState(() {
                        _agreed = v ?? false;
                        if (_agreed) _showHint = false;
                      }),
                      activeColor: AppColors.primary,
                      checkColor: Colors.white,
                      side: const BorderSide(color: AppColors.border),
                    ),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.only(top: 14),
                        child: Text(
                          AppStrings.aiConsentCheckboxLabel,
                          style: AppTextStyles.bodyMedium,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              if (_showHint) ...[
                const SizedBox(height: AppSpacing.xs),
                Padding(
                  padding: const EdgeInsets.only(left: AppSpacing.md),
                  child: Text(
                    AppStrings.aiConsentRequiredHint,
                    style:
                        AppTextStyles.bodySmall.copyWith(color: AppColors.error),
                  ),
                ),
              ],
              const SizedBox(height: AppSpacing.md),
              Row(
                children: [
                  AppSecondaryButton(
                    label: AppStrings.onboardingBack,
                    width: 100,
                    onPressed: widget.onBack,
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: AppPrimaryButton(
                      label: AppStrings.aiConsentCta,
                      onPressed: _tryNext,
                    ),
                  ),
                ],
              ),
            ],
          ).animate().fadeIn(delay: 500.ms, duration: 400.ms),
        ),
      ],
    );
  }
}
