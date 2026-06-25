import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/widgets/app_button.dart';

class StepLimitingBeliefs extends StatefulWidget {
  final void Function(List<String> beliefs) onNext;
  final VoidCallback onBack;

  const StepLimitingBeliefs({
    super.key,
    required this.onNext,
    required this.onBack,
  });

  @override
  State<StepLimitingBeliefs> createState() => _StepLimitingBeliefsState();
}

class _StepLimitingBeliefsState extends State<StepLimitingBeliefs> {
  final List<String> _beliefs = [];
  final _controller = TextEditingController();
  bool _showError = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _addBelief(String text) {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return;
    if (_beliefs.contains(trimmed)) return;
    setState(() {
      _beliefs.add(trimmed);
      _controller.clear();
      _showError = false;
    });
  }

  void _removeBelief(String belief) {
    setState(() => _beliefs.remove(belief));
  }

  void _tryNext() {
    if (_beliefs.isEmpty) {
      setState(() => _showError = true);
      return;
    }
    widget.onNext(_beliefs);
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.screenPaddingH,
        vertical: AppSpacing.md,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            AppStrings.onboardingBeliefsTitle,
            style: AppTextStyles.headlineLarge,
          ).animate().fadeIn(duration: 400.ms),
          const SizedBox(height: AppSpacing.sm),
          Text(
            AppStrings.onboardingBeliefsSubtitle,
            style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textSecondary),
          ).animate().fadeIn(delay: 100.ms, duration: 400.ms),
          const SizedBox(height: AppSpacing.xl),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _controller,
                  style: AppTextStyles.bodyLarge,
                  textInputAction: TextInputAction.done,
                  onSubmitted: _addBelief,
                  decoration: InputDecoration(
                    hintText: AppStrings.onboardingBeliefsHint,
                    hintStyle: AppTextStyles.bodyMedium.copyWith(
                      color: AppColors.textMuted,
                    ),
                    filled: true,
                    fillColor: AppColors.surfaceElevated,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                      borderSide: const BorderSide(color: AppColors.border),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                      borderSide: const BorderSide(color: AppColors.border),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                      borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              SizedBox(
                height: AppSpacing.inputHeight,
                child: ElevatedButton(
                  onPressed: () => _addBelief(_controller.text),
                  child: const Icon(Icons.add_rounded),
                ),
              ),
            ],
          ).animate().fadeIn(delay: 200.ms, duration: 400.ms),
          const SizedBox(height: AppSpacing.lg),
          if (_beliefs.isNotEmpty) ...[
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: _beliefs.map((b) => _BeliefChip(
                    belief: b,
                    onRemove: () => _removeBelief(b),
                  )).toList(),
            ),
            const SizedBox(height: AppSpacing.lg),
          ],
          Text(
            'Suggestions (tap to add):',
            style: AppTextStyles.labelMedium,
          ).animate().fadeIn(delay: 300.ms),
          const SizedBox(height: AppSpacing.sm),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: AppStrings.suggestedBeliefs
                .where((b) => !_beliefs.contains(b))
                .map((b) => GestureDetector(
                      onTap: () => _addBelief(b),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.md,
                          vertical: AppSpacing.sm,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          border: Border.all(color: AppColors.border),
                          borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
                        ),
                        child: Text(
                          b,
                          style: AppTextStyles.bodySmall.copyWith(
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ),
                    ))
                .toList(),
          ).animate().fadeIn(delay: 400.ms, duration: 400.ms),
          if (_showError) ...[
            const SizedBox(height: AppSpacing.md),
            Text(
              'Add at least one limiting belief to continue.',
              style: AppTextStyles.bodySmall.copyWith(color: AppColors.error),
            ),
          ],
          const SizedBox(height: AppSpacing.xxl),
          AppPrimaryButton(
            label: AppStrings.onboardingNext,
            onPressed: _tryNext,
          ),
          const SizedBox(height: AppSpacing.md),
          AppSecondaryButton(
            label: AppStrings.onboardingBack,
            onPressed: widget.onBack,
          ),
          const SizedBox(height: AppSpacing.xxl),
        ],
      ),
    );
  }
}

class _BeliefChip extends StatelessWidget {
  final String belief;
  final VoidCallback onRemove;

  const _BeliefChip({required this.belief, required this.onRemove});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: AppColors.primaryContainer,
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
        borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            belief,
            style: AppTextStyles.bodySmall.copyWith(color: AppColors.primary),
          ),
          const SizedBox(width: AppSpacing.xs),
          GestureDetector(
            onTap: onRemove,
            child: const Icon(Icons.close_rounded, size: 14, color: AppColors.primary),
          ),
        ],
      ),
    );
  }
}
