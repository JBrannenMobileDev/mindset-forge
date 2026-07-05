import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/shimmer_widget.dart';
import '../../../models/mindset_blueprint.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/claude_provider.dart';

/// Mindset trait assessment step.
///
/// Rather than handing the user 5 blank sliders and asking them to guess a
/// number 1-10 (noisy, no anchoring, invites social-desirability bias), we
/// infer a starting point from what they've already told the app — situation,
/// aspired qualities, goals, and the limiting beliefs they selected — via
/// [ClaudeService.inferBaselineBlueprint], then let them react and tune
/// (recognition, not blank recall). Limiting beliefs are NOT re-collected
/// here; they were already captured in onboarding's `StepBlocker` and remain
/// editable in the Blueprint tab, so this step only recaps them for context.
class StepAssessment extends ConsumerStatefulWidget {
  final MindsetBlueprint initialBlueprint;
  final List<String> initialBeliefs;
  final bool blueprintCompleted;
  final void Function(MindsetBlueprint blueprint) onNext;
  final VoidCallback onBack;

  const StepAssessment({
    super.key,
    required this.initialBlueprint,
    required this.initialBeliefs,
    required this.blueprintCompleted,
    required this.onNext,
    required this.onBack,
  });

  @override
  ConsumerState<StepAssessment> createState() => _StepAssessmentState();
}

class _StepAssessmentState extends ConsumerState<StepAssessment> {
  late double _confidence;
  late double _discipline;
  late double _abundance;
  late double _resilience;
  late double _decisiveness;

  bool _loading = false;

  static const _traits = [
    _TraitMeta(
      name: AppStrings.traitConfidence,
      description: 'How confident are you in your abilities?',
      icon: Icons.star_rounded,
    ),
    _TraitMeta(
      name: AppStrings.traitDiscipline,
      description: 'How consistently do you follow through?',
      icon: Icons.fitness_center_rounded,
    ),
    _TraitMeta(
      name: AppStrings.traitAbundance,
      description: 'Do you believe resources and opportunities are limitless?',
      icon: Icons.attach_money_rounded,
    ),
    _TraitMeta(
      name: AppStrings.traitResilience,
      description: 'How well do you bounce back from setbacks?',
      icon: Icons.shield_rounded,
    ),
    _TraitMeta(
      name: AppStrings.traitDecisiveness,
      description: 'How quickly and confidently do you make decisions?',
      icon: Icons.bolt_rounded,
    ),
  ];

  @override
  void initState() {
    super.initState();
    _applyBlueprint(widget.initialBlueprint);
    if (!widget.blueprintCompleted) {
      _inferBaseline();
    }
  }

  void _applyBlueprint(MindsetBlueprint b) {
    _confidence = b.confidence;
    _discipline = b.discipline;
    _abundance = b.abundanceThinking;
    _resilience = b.resilience;
    _decisiveness = b.decisiveness;
  }

  Future<void> _inferBaseline() async {
    final profile = ref.read(currentUserProfileProvider).valueOrNull;
    if (profile == null) return;
    setState(() => _loading = true);
    final inferred =
        await ref.read(claudeServiceProvider).inferBaselineBlueprint(profile);
    if (!mounted) return;
    setState(() {
      _applyBlueprint(inferred);
      _loading = false;
    });
  }

  double _getTraitValue(int index) => switch (index) {
        0 => _confidence,
        1 => _discipline,
        2 => _abundance,
        3 => _resilience,
        4 => _decisiveness,
        _ => 5.0,
      };

  void _setTraitValue(int index, double value) {
    setState(() {
      switch (index) {
        case 0: _confidence = value;
        case 1: _discipline = value;
        case 2: _abundance = value;
        case 3: _resilience = value;
        case 4: _decisiveness = value;
      }
    });
  }

  String _emoji(double value) {
    if (value <= 3) return '😟';
    if (value <= 6) return '😐';
    return '💪';
  }

  void _tryNext() {
    widget.onNext(
      MindsetBlueprint(
        confidence: _confidence,
        discipline: _discipline,
        abundanceThinking: _abundance,
        resilience: _resilience,
        decisiveness: _decisiveness,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final keyboardVisible = MediaQuery.of(context).viewInsets.bottom > 0;
    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.screenPaddingH,
              vertical: AppSpacing.md,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Trait sliders ──────────────────────────────────────────
                Text(
                  AppStrings.blueprintAssessmentTitle,
                  style: AppTextStyles.headlineLarge,
                ).animate().fadeIn(duration: 400.ms),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  AppStrings.blueprintAssessmentSubtitle,
                  style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textSecondary),
                ).animate().fadeIn(delay: 100.ms, duration: 400.ms),
                const SizedBox(height: AppSpacing.xl),

                if (_loading) ...[
                  Row(
                    children: [
                      const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: AppColors.primary),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Text(
                        AppStrings.blueprintAssessmentLoading,
                        style: AppTextStyles.bodyMedium
                            .copyWith(color: AppColors.textSecondary),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  const ShimmerList(count: 5, itemHeight: 120),
                ] else
                  ...List.generate(_traits.length, (i) {
                    final value = _getTraitValue(i);
                    return Padding(
                      padding: const EdgeInsets.only(bottom: AppSpacing.md),
                      child: AppCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(_traits[i].icon, color: AppColors.primary, size: 20),
                                const SizedBox(width: AppSpacing.sm),
                                Text(_traits[i].name, style: AppTextStyles.labelLarge),
                                const Spacer(),
                                Text(_emoji(value), style: const TextStyle(fontSize: 20)),
                                const SizedBox(width: AppSpacing.sm),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: AppSpacing.sm,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: AppColors.primaryContainer,
                                    borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
                                  ),
                                  child: Text(
                                    value.toStringAsFixed(0),
                                    style: AppTextStyles.labelLarge.copyWith(color: AppColors.primary),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: AppSpacing.xs),
                            Text(
                              _traits[i].description,
                              style: AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondary),
                            ),
                            const SizedBox(height: AppSpacing.sm),
                            Row(
                              children: [
                                Text('1', style: AppTextStyles.labelSmall),
                                Expanded(
                                  child: Slider(
                                    value: value,
                                    min: 1,
                                    max: 10,
                                    divisions: 9,
                                    label: value.toStringAsFixed(0),
                                    onChanged: (v) => _setTraitValue(i, v),
                                  ),
                                ),
                                Text('10', style: AppTextStyles.labelSmall),
                              ],
                            ),
                          ],
                        ),
                      ).animate().fadeIn(delay: Duration(milliseconds: 200 + i * 80), duration: 400.ms),
                    );
                  }),

                const SizedBox(height: AppSpacing.xl),
                const Divider(color: AppColors.border),
                const SizedBox(height: AppSpacing.xl),

                // ── Limiting beliefs recap (already captured in onboarding) ──
                Text(AppStrings.blueprintBeliefsRecapTitle, style: AppTextStyles.headlineMedium)
                    .animate().fadeIn(duration: 400.ms),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  widget.initialBeliefs.isEmpty
                      ? AppStrings.blueprintBeliefsRecapEmpty
                      : AppStrings.blueprintBeliefsRecapCaption,
                  style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textSecondary),
                ).animate().fadeIn(delay: 100.ms, duration: 400.ms),

                if (widget.initialBeliefs.isNotEmpty) ...[
                  const SizedBox(height: AppSpacing.lg),
                  Wrap(
                    spacing: AppSpacing.sm,
                    runSpacing: AppSpacing.sm,
                    children: widget.initialBeliefs.map((belief) {
                      return Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.md,
                          vertical: AppSpacing.sm,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.surfaceElevated,
                          border: Border.all(color: AppColors.border),
                          borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
                        ),
                        child: Text(
                          belief,
                          style: AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondary),
                        ),
                      );
                    }).toList(),
                  ),
                ],

                const SizedBox(height: AppSpacing.xxl),
              ],
            ),
          ),
        ),

        // Footer
        AnimatedOpacity(
          opacity: keyboardVisible ? 0.0 : 1.0,
          duration: const Duration(milliseconds: 200),
          child: IgnorePointer(
            ignoring: keyboardVisible,
            child: Padding(
              padding: EdgeInsets.fromLTRB(
                AppSpacing.screenPaddingH,
                AppSpacing.md,
                AppSpacing.screenPaddingH,
                MediaQuery.of(context).padding.bottom + AppSpacing.md,
              ),
              child: Row(
                children: [
                  AppSecondaryButton(label: 'Back', width: 100, onPressed: widget.onBack),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: AppPrimaryButton(
                      label: AppStrings.onboardingNext,
                      onPressed: _loading ? null : _tryNext,
                      icon: Icons.arrow_forward_rounded,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _TraitMeta {
  final String name;
  final String description;
  final IconData icon;

  const _TraitMeta({
    required this.name,
    required this.description,
    required this.icon,
  });
}
