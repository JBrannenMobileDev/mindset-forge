import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/widgets/app_button.dart';
import '../../../models/goal.dart';
import '../../../models/mindset_blueprint.dart';

/// Read-only review of everything collected during onboarding before
/// triggering the AI analysis.
class StepSummary extends StatelessWidget {
  final String identityStatement;
  final List<Goal> goals;
  final MindsetBlueprint blueprint;
  final List<String> limitingBeliefs;
  final double mentalToughnessScore;
  final List<String> fearsDrift;
  final VoidCallback onComplete;
  final VoidCallback onBack;

  const StepSummary({
    super.key,
    required this.identityStatement,
    required this.goals,
    required this.blueprint,
    required this.limitingBeliefs,
    required this.mentalToughnessScore,
    required this.fearsDrift,
    required this.onComplete,
    required this.onBack,
  });

  static const _traitLabels = ['Confidence', 'Discipline', 'Abundance', 'Resilience', 'Decisiveness'];

  List<double> get _traitScores => [
        blueprint.confidence,
        blueprint.discipline,
        blueprint.abundanceThinking,
        blueprint.resilience,
        blueprint.decisiveness,
      ];

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpacing.screenPaddingH),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Your Profile', style: AppTextStyles.headlineMedium)
                    .animate().fadeIn(duration: 400.ms),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  'Review everything before we generate your personalized analysis.',
                  style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textSecondary),
                ).animate().fadeIn(delay: 100.ms, duration: 400.ms),

                const SizedBox(height: AppSpacing.xl),

                // Identity statement
                _Section(
                  icon: Icons.person_rounded,
                  title: 'Identity Statement',
                  delay: 200,
                  child: identityStatement.isNotEmpty
                      ? Text(
                          '"$identityStatement"',
                          style: AppTextStyles.bodyLarge.copyWith(
                            fontStyle: FontStyle.italic,
                            height: 1.5,
                          ),
                        )
                      : Text('Not set',
                          style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textMuted)),
                ),

                const SizedBox(height: AppSpacing.md),

                // Goals
                _Section(
                  icon: Icons.flag_rounded,
                  title: 'Goals (${goals.length})',
                  delay: 280,
                  child: goals.isEmpty
                      ? Text('No goals added',
                          style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textMuted))
                      : Wrap(
                          spacing: AppSpacing.sm,
                          runSpacing: AppSpacing.sm,
                          children: goals.map((g) => _Chip(label: g.title)).toList(),
                        ),
                ),

                const SizedBox(height: AppSpacing.md),

                // Mindset scores
                _Section(
                  icon: Icons.bar_chart_rounded,
                  title: 'Mindset Blueprint',
                  delay: 360,
                  child: Column(
                    children: List.generate(_traitLabels.length, (i) {
                      final score = _traitScores[i];
                      return Padding(
                        padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                        child: Row(
                          children: [
                            SizedBox(
                              width: 100,
                              child: Text(
                                _traitLabels[i],
                                style: AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondary),
                              ),
                            ),
                            Expanded(
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
                                child: LinearProgressIndicator(
                                  value: score / 10,
                                  minHeight: 6,
                                  backgroundColor: AppColors.border,
                                  valueColor: const AlwaysStoppedAnimation(AppColors.primary),
                                ),
                              ),
                            ),
                            const SizedBox(width: AppSpacing.sm),
                            Text(
                              score.toStringAsFixed(0),
                              style: AppTextStyles.labelSmall.copyWith(color: AppColors.primary),
                            ),
                          ],
                        ),
                      );
                    }),
                  ),
                ),

                const SizedBox(height: AppSpacing.md),

                // Limiting beliefs
                _Section(
                  icon: Icons.psychology_rounded,
                  title: 'Limiting Beliefs',
                  delay: 440,
                  child: limitingBeliefs.isEmpty
                      ? Text('None added',
                          style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textMuted))
                      : Wrap(
                          spacing: AppSpacing.sm,
                          runSpacing: AppSpacing.sm,
                          children: limitingBeliefs
                              .map((b) => _Chip(label: b, subtle: true))
                              .toList(),
                        ),
                ),

                const SizedBox(height: AppSpacing.md),

                // Mental toughness
                _Section(
                  icon: Icons.bolt_rounded,
                  title: 'Mental Toughness',
                  delay: 520,
                  child: Row(
                    children: [
                      Text(
                        '${mentalToughnessScore.toStringAsFixed(0)}/100',
                        style: AppTextStyles.headlineSmall.copyWith(color: AppColors.primary),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      _toughnessBadge(mentalToughnessScore),
                    ],
                  ),
                ),

                const SizedBox(height: AppSpacing.md),

                // Fears
                _Section(
                  icon: Icons.remove_red_eye_rounded,
                  title: 'Fears to Outwit',
                  delay: 600,
                  child: fearsDrift.isEmpty
                      ? Text('Not assessed',
                          style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textMuted))
                      : Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (fearsDrift.isNotEmpty)
                              _FearRow(label: fearsDrift[0], badge: 'Primary', color: AppColors.error),
                            if (fearsDrift.length > 1) ...[
                              const SizedBox(height: AppSpacing.sm),
                              _FearRow(label: fearsDrift[1], badge: 'Secondary', color: AppColors.warning),
                            ],
                          ],
                        ),
                ),

                const SizedBox(height: AppSpacing.xxl),
              ],
            ),
          ),
        ),

        // Footer
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.screenPaddingH, AppSpacing.md,
            AppSpacing.screenPaddingH, AppSpacing.xl,
          ),
          child: Column(
            children: [
              AppPrimaryButton(
                label: 'Complete & Start Your Journey',
                onPressed: onComplete,
                icon: Icons.rocket_launch_rounded,
              ),
              const SizedBox(height: AppSpacing.sm),
              AppSecondaryButton(label: 'Back', onPressed: onBack),
            ],
          ),
        ),
      ],
    );
  }

  Widget _toughnessBadge(double score) {
    final label = score <= 33 ? 'Still Building' : score <= 66 ? 'Rising' : 'Champion';
    final color = score <= 33 ? AppColors.error : score <= 66 ? AppColors.warning : AppColors.success;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(label, style: AppTextStyles.labelSmall.copyWith(color: color)),
    );
  }
}

class _Section extends StatelessWidget {
  final IconData icon;
  final String title;
  final Widget child;
  final int delay;

  const _Section({
    required this.icon,
    required this.title,
    required this.child,
    required this.delay,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.surfaceElevated,
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: AppColors.primary, size: 18),
              const SizedBox(width: AppSpacing.sm),
              Text(title, style: AppTextStyles.labelLarge),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          child,
        ],
      ),
    ).animate().fadeIn(delay: Duration(milliseconds: delay), duration: 400.ms);
  }
}

class _Chip extends StatelessWidget {
  final String label;
  final bool subtle;

  const _Chip({required this.label, this.subtle = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.xs),
      decoration: BoxDecoration(
        color: subtle ? AppColors.background : AppColors.primaryContainer,
        borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
        border: Border.all(
          color: subtle ? AppColors.border : AppColors.primary.withValues(alpha: 0.3),
        ),
      ),
      child: Text(
        label,
        style: AppTextStyles.bodySmall.copyWith(
          color: subtle ? AppColors.textSecondary : AppColors.primary,
        ),
      ),
    );
  }
}

class _FearRow extends StatelessWidget {
  final String label;
  final String badge;
  final Color color;

  const _FearRow({required this.label, required this.badge, required this.color});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: 2),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
          ),
          child: Text(badge, style: AppTextStyles.labelSmall.copyWith(color: color)),
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(child: Text(label, style: AppTextStyles.bodyMedium)),
      ],
    );
  }
}
