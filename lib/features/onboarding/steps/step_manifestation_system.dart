import 'package:flutter/material.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/manifestation_system_explainer.dart';

class StepManifestationSystem extends StatelessWidget {
  final VoidCallback onNext;
  final VoidCallback onBack;

  const StepManifestationSystem({
    super.key,
    required this.onNext,
    required this.onBack,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpacing.screenPaddingH),
            child: const ManifestationSystemExplainer(),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.screenPaddingH,
            AppSpacing.md,
            AppSpacing.screenPaddingH,
            AppSpacing.xl,
          ),
          child: Row(
            children: [
              AppSecondaryButton(label: 'Back', onPressed: onBack),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: AppPrimaryButton(
                  label: 'Continue',
                  onPressed: onNext,
                  icon: Icons.arrow_forward_rounded,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
