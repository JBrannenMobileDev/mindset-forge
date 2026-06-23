import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_card.dart';
import '../../../models/mindset_blueprint.dart';

/// Combined mindset assessment + limiting beliefs step.
class StepAssessment extends StatefulWidget {
  final MindsetBlueprint initialBlueprint;
  final List<String> initialBeliefs;
  final void Function(MindsetBlueprint blueprint, List<String> beliefs) onNext;
  final VoidCallback onBack;

  const StepAssessment({
    super.key,
    required this.initialBlueprint,
    required this.initialBeliefs,
    required this.onNext,
    required this.onBack,
  });

  @override
  State<StepAssessment> createState() => _StepAssessmentState();
}

class _StepAssessmentState extends State<StepAssessment> {
  late double _confidence;
  late double _discipline;
  late double _abundance;
  late double _resilience;
  late double _decisiveness;

  late List<String> _beliefs;
  final _beliefCtrl = TextEditingController();
  String? _errorText;

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

  static const _suggestions = [
    "I'm not good enough",
    "Money is hard to make",
    "I always fail",
    "Success isn't for people like me",
    "I don't deserve success",
    "People will judge me",
    "I'm too young/old",
    "I lack the talent",
  ];

  @override
  void initState() {
    super.initState();
    final b = widget.initialBlueprint;
    _confidence = b.confidence;
    _discipline = b.discipline;
    _abundance = b.abundanceThinking;
    _resilience = b.resilience;
    _decisiveness = b.decisiveness;
    _beliefs = List.from(widget.initialBeliefs);
  }

  @override
  void dispose() {
    _beliefCtrl.dispose();
    super.dispose();
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

  void _addBelief(String belief) {
    final trimmed = belief.trim();
    if (trimmed.isEmpty || _beliefs.contains(trimmed)) return;
    setState(() {
      _beliefs = [..._beliefs, trimmed];
      _beliefCtrl.clear();
      _errorText = null;
    });
  }

  void _removeBelief(String belief) =>
      setState(() => _beliefs = _beliefs.where((b) => b != belief).toList());

  void _tryNext() {
    if (_beliefs.isEmpty) {
      setState(() => _errorText = 'Add at least one limiting belief to continue.');
      return;
    }
    widget.onNext(
      MindsetBlueprint(
        confidence: _confidence,
        discipline: _discipline,
        abundanceThinking: _abundance,
        resilience: _resilience,
        decisiveness: _decisiveness,
      ),
      _beliefs,
    );
  }

  @override
  Widget build(BuildContext context) {
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
                  AppStrings.onboardingAssessmentTitle,
                  style: AppTextStyles.headlineLarge,
                ).animate().fadeIn(duration: 400.ms),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  AppStrings.onboardingAssessmentSubtitle,
                  style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textSecondary),
                ).animate().fadeIn(delay: 100.ms, duration: 400.ms),
                const SizedBox(height: AppSpacing.xl),

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
                Divider(color: AppColors.border),
                const SizedBox(height: AppSpacing.xl),

                // ── Limiting beliefs ──────────────────────────────────────
                Text('Your Limiting Beliefs', style: AppTextStyles.headlineMedium)
                    .animate().fadeIn(duration: 400.ms),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  'What stories are holding you back? Naming them is the first step to outwitting them.',
                  style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textSecondary),
                ).animate().fadeIn(delay: 100.ms, duration: 400.ms),
                const SizedBox(height: AppSpacing.lg),

                // Suggestions
                Wrap(
                  spacing: AppSpacing.sm,
                  runSpacing: AppSpacing.sm,
                  children: _suggestions.map((s) {
                    final added = _beliefs.contains(s);
                    return GestureDetector(
                      onTap: added ? () => _removeBelief(s) : () => _addBelief(s),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.md,
                          vertical: AppSpacing.sm,
                        ),
                        decoration: BoxDecoration(
                          color: added ? AppColors.primaryContainer : AppColors.surfaceElevated,
                          border: Border.all(
                            color: added ? AppColors.primary : AppColors.border,
                          ),
                          borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (added)
                              const Padding(
                                padding: EdgeInsets.only(right: 4),
                                child: Icon(Icons.check_rounded, size: 14, color: AppColors.primary),
                              ),
                            Text(
                              s,
                              style: AppTextStyles.bodySmall.copyWith(
                                color: added ? AppColors.primary : AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                ),

                const SizedBox(height: AppSpacing.lg),

                // Custom belief input
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _beliefCtrl,
                        style: AppTextStyles.bodyMedium,
                        cursorColor: AppColors.primary,
                        onSubmitted: _addBelief,
                        decoration: InputDecoration(
                          hintText: 'Type your own...',
                          hintStyle: AppTextStyles.bodyMedium.copyWith(color: AppColors.textMuted),
                          filled: true,
                          fillColor: AppColors.surfaceElevated,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                            borderSide: const BorderSide(color: AppColors.border),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                            borderSide: const BorderSide(color: AppColors.primary),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                            borderSide: const BorderSide(color: AppColors.border),
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: AppSpacing.md,
                            vertical: AppSpacing.md,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    IconButton.filled(
                      onPressed: () => _addBelief(_beliefCtrl.text),
                      icon: const Icon(Icons.add_rounded),
                      style: IconButton.styleFrom(backgroundColor: AppColors.primary),
                    ),
                  ],
                ),

                if (_errorText != null) ...[
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    _errorText!,
                    style: AppTextStyles.bodySmall.copyWith(color: AppColors.error),
                  ),
                ],

                const SizedBox(height: AppSpacing.xxl),
              ],
            ),
          ),
        ),

        // Footer
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.screenPaddingH,
            AppSpacing.md,
            AppSpacing.screenPaddingH,
            AppSpacing.xl,
          ),
          child: Row(
            children: [
              AppSecondaryButton(label: 'Back', onPressed: widget.onBack),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: AppPrimaryButton(
                  label: AppStrings.onboardingNext,
                  onPressed: _tryNext,
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
