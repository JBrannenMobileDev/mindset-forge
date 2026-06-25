import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/manifestation_system_explainer.dart';
import '../../../core/utils/manifestation_scoring.dart';
import '../../../models/user_profile.dart';
import '../../../models/manifestation_alignment.dart';

/// Opens the manifestation alignment breakdown + tips as a bottom sheet.
/// Reused by the Mindset hub's compact alignment chip (the full dashboard card
/// remains the primary at-a-glance surface).
Future<void> showAlignmentDetailSheet(
    BuildContext context, UserProfile profile) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.surface,
    shape: const RoundedRectangleBorder(
      borderRadius:
          BorderRadius.vertical(top: Radius.circular(AppSpacing.radiusXl)),
    ),
    builder: (_) => _AlignmentDetailSheet(profile: profile),
  );
}

class _AlignmentDetailSheet extends StatelessWidget {
  final UserProfile profile;

  const _AlignmentDetailSheet({required this.profile});

  @override
  Widget build(BuildContext context) {
    final alignment = ManifestationScoring.calculate(profile);
    final isRampingUp = ManifestationScoring.isRampingUp(profile);
    final rampDay = ManifestationScoring.daysSinceSignup(profile) + 1;

    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      maxChildSize: 0.95,
      minChildSize: 0.5,
      expand: false,
      builder: (_, scrollCtrl) => SingleChildScrollView(
        controller: scrollCtrl,
        padding: const EdgeInsets.fromLTRB(AppSpacing.screenPaddingH,
            AppSpacing.md, AppSpacing.screenPaddingH, AppSpacing.xl),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            _AlignmentHero(alignment: alignment)
                .animate()
                .fadeIn(duration: 400.ms),
            if (isRampingUp) ...[
              const SizedBox(height: AppSpacing.sm),
              Text(
                'Building your baseline (day $rampDay of 10)',
                style: AppTextStyles.bodySmall
                    .copyWith(color: AppColors.textMuted),
              ),
            ],
            const SizedBox(height: AppSpacing.xl),
            Row(
              children: [
                Expanded(
                  child: Text('Your Alignment Breakdown',
                      style: AppTextStyles.headlineSmall),
                ),
                IconButton(
                  onPressed: () => showManifestationSystemSheet(context),
                  icon: const Icon(Icons.info_outline_rounded),
                  color: AppColors.textSecondary,
                  iconSize: AppSpacing.iconLg,
                  tooltip: 'How this works',
                  visualDensity: VisualDensity.compact,
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              'Each layer is calculated from what you actually do, not a self-rating.',
              style: AppTextStyles.bodySmall
                  .copyWith(color: AppColors.textSecondary),
            ),
            const SizedBox(height: AppSpacing.md),
            _DimensionBreakdown(alignment: alignment)
                .animate()
                .fadeIn(delay: 200.ms),
            const SizedBox(height: AppSpacing.xl),
            Text('Tips to Level Up', style: AppTextStyles.headlineSmall),
            const SizedBox(height: AppSpacing.md),
            _TipsSection(alignment: alignment).animate().fadeIn(delay: 400.ms),
          ],
        ),
      ),
    );
  }
}

class _AlignmentHero extends StatelessWidget {
  final ManifestationAlignment alignment;

  const _AlignmentHero({required this.alignment});

  @override
  Widget build(BuildContext context) {
    final score = alignment.overall;
    return AppCard(
      child: Row(
        children: [
          SizedBox(
            width: 110,
            height: 110,
            child: Stack(
              alignment: Alignment.center,
              children: [
                CustomPaint(
                  size: const Size(110, 110),
                  painter: _ScoreRingPainter(score: score),
                ),
                Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      score.toStringAsFixed(0),
                      style: AppTextStyles.statNumber
                          .copyWith(color: AppColors.primary),
                    ),
                    Text('score', style: AppTextStyles.labelSmall),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.xl),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  alignment.masteryLevel,
                  style: AppTextStyles.headlineMedium
                      .copyWith(color: AppColors.primary),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text('Manifestation Level', style: AppTextStyles.labelSmall),
                const SizedBox(height: AppSpacing.md),
                Text(
                  _masteryDescription(alignment.masteryLevel),
                  style: AppTextStyles.bodySmall
                      .copyWith(color: AppColors.textSecondary),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _masteryDescription(String level) {
    return switch (level) {
      'Awakening' => 'You\'re becoming aware of the power of your mind.',
      'Shifting' => 'Old patterns are dissolving. New beliefs are forming.',
      'Building' => 'Your identity and actions are aligning.',
      'Manifesting' => 'Your inner and outer worlds are synchronizing.',
      _ => 'You\'ve mastered the art of aligned creation.',
    };
  }
}

class _ScoreRingPainter extends CustomPainter {
  final double score;

  _ScoreRingPainter({required this.score});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width - 12) / 2;

    final bgPaint = Paint()
      ..color = AppColors.border
      ..style = PaintingStyle.stroke
      ..strokeWidth = 8
      ..strokeCap = StrokeCap.round;

    final gradient = SweepGradient(
      colors: const [AppColors.primary, AppColors.secondary],
      startAngle: -math.pi / 2,
      endAngle: -math.pi / 2 + math.pi * 2 * (score / 100),
    );

    final fgPaint = Paint()
      ..shader =
          gradient.createShader(Rect.fromCircle(center: center, radius: radius))
      ..style = PaintingStyle.stroke
      ..strokeWidth = 8
      ..strokeCap = StrokeCap.round;

    canvas.drawCircle(center, radius, bgPaint);
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi / 2,
      math.pi * 2 * (score / 100),
      false,
      fgPaint,
    );
  }

  @override
  bool shouldRepaint(_ScoreRingPainter old) => old.score != score;
}

class _DimensionBreakdown extends StatelessWidget {
  final ManifestationAlignment alignment;

  const _DimensionBreakdown({required this.alignment});

  static const _descriptions = {
    'Subconscious':
        'Fed by morning + evening affirmations and future-self visualization.',
    'Thought': 'Fed by journaling and coaching conversations.',
    'Action': 'Fed by completing habits and priority actions.',
    'Results': 'Average progress across your active goals.',
  };

  @override
  Widget build(BuildContext context) {
    final dimensions = [
      ('Subconscious', alignment.subconscious),
      ('Thought', alignment.thought),
      ('Action', alignment.action),
      ('Results', alignment.results),
    ];

    return Column(
      children: dimensions.asMap().entries.map((e) {
        final name = e.value.$1;
        final value = e.value.$2;
        return Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.md),
          child: AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(name, style: AppTextStyles.labelLarge),
                    const Spacer(),
                    Text(
                      '${value.toStringAsFixed(0)}%',
                      style: AppTextStyles.headlineSmall
                          .copyWith(color: AppColors.primary),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.sm),
                ClipRRect(
                  borderRadius: BorderRadius.circular(3),
                  child: LinearProgressIndicator(
                    value: value / 100,
                    backgroundColor: AppColors.border,
                    valueColor:
                        const AlwaysStoppedAnimation(AppColors.primary),
                    minHeight: 6,
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  _descriptions[name] ?? '',
                  style: AppTextStyles.bodySmall
                      .copyWith(color: AppColors.textSecondary),
                ),
              ],
            ),
          ).animate().fadeIn(
              delay: Duration(milliseconds: e.key * 80), duration: 400.ms),
        );
      }).toList(),
    );
  }
}

class _TipsSection extends StatelessWidget {
  final ManifestationAlignment alignment;

  const _TipsSection({required this.alignment});

  List<String> get _tips {
    if (alignment.subconscious < 40) {
      return [
        'Practice daily affirmations, morning and evening',
        'Read your identity statement with emotion every day',
        'Journal about the version of you who has already achieved your goals',
      ];
    }
    if (alignment.action < 40) {
      return [
        'Set 3 non-negotiable priority actions each morning',
        'Track habit completion. Consistency compounds.',
        'Raise the floor, not the ceiling: show up even on bad days',
      ];
    }
    return [
      'Log daily evidence of your new identity taking shape',
      'Have your weekly insight conversation',
      'Celebrate small wins loudly. The brain needs evidence.',
    ];
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: _tips
          .asMap()
          .entries
          .map((e) => Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 28,
                      height: 28,
                      margin: const EdgeInsets.only(right: AppSpacing.md),
                      decoration: const BoxDecoration(
                        color: AppColors.primaryContainer,
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: Text(
                          '${e.key + 1}',
                          style: AppTextStyles.labelSmall
                              .copyWith(color: AppColors.primary),
                        ),
                      ),
                    ),
                    Expanded(
                      child: Text(e.value,
                          style:
                              AppTextStyles.bodyMedium.copyWith(height: 1.5)),
                    ),
                  ],
                ),
              ))
          .toList(),
    );
  }
}
