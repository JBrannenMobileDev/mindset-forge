import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/utils/manifestation_scoring.dart';
import '../../../models/user_profile.dart';

/// Header-less alignment content (ring + dimension bars + ramp note).
/// Wrapped by `ProgressOverviewCard`; carries no `SectionHeader`/`AppCard`.
class AlignmentScoreBody extends StatelessWidget {
  final UserProfile profile;

  const AlignmentScoreBody({super.key, required this.profile});

  @override
  Widget build(BuildContext context) {
    final alignment = ManifestationScoring.calculate(profile);
    final score = alignment.overall;
    final isRampingUp = ManifestationScoring.isRampingUp(profile);
    final rampDay = ManifestationScoring.daysSinceSignup(profile) + 1;

    return Column(
      children: [
        Row(
          children: [
            _CircularScore(score: score),
            const SizedBox(width: AppSpacing.xl),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    alignment.masteryLevel,
                    style: AppTextStyles.headlineSmall.copyWith(
                      color: AppColors.primary,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    'Manifestation Level',
                    style: AppTextStyles.labelSmall,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  _DimensionBar(
                      label: 'Subconscious', value: alignment.subconscious),
                  const SizedBox(height: AppSpacing.xs),
                  _DimensionBar(label: 'Thought', value: alignment.thought),
                  const SizedBox(height: AppSpacing.xs),
                  _DimensionBar(label: 'Action', value: alignment.action),
                  const SizedBox(height: AppSpacing.xs),
                  _DimensionBar(label: 'Results', value: alignment.results),
                ],
              ),
            ),
          ],
        ),
        if (isRampingUp) ...[
          const SizedBox(height: AppSpacing.md),
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'Building your baseline (day $rampDay of 10)',
              style: AppTextStyles.bodySmall.copyWith(
                color: AppColors.textMuted,
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _CircularScore extends StatelessWidget {
  final double score;

  const _CircularScore({required this.score});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 100,
      height: 100,
      child: Stack(
        alignment: Alignment.center,
        children: [
          CustomPaint(
            size: const Size(100, 100),
            painter: _ScoreRingPainter(score: score),
          ),
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                '${score.toStringAsFixed(0)}%',
                style: AppTextStyles.statNumber.copyWith(
                  color: AppColors.primary,
                  fontSize: 28,
                ),
              ),
              Text(
                'aligned',
                style: AppTextStyles.labelSmall,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ScoreRingPainter extends CustomPainter {
  final double score;

  _ScoreRingPainter({required this.score});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width - 12) / 2;
    const strokeWidth = 8.0;

    final bgPaint = Paint()
      ..color = AppColors.borderSubtle
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    final rect = Rect.fromCircle(center: center, radius: radius);
    final fgPaint = Paint()
      ..color = AppColors.secondary
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    canvas.drawCircle(center, radius, bgPaint);
    canvas.drawArc(
      rect,
      -math.pi / 2,
      math.pi * 2 * (score / 100),
      false,
      fgPaint,
    );
  }

  @override
  bool shouldRepaint(_ScoreRingPainter old) => old.score != score;
}

class _DimensionBar extends StatelessWidget {
  final String label;
  final double value;

  const _DimensionBar({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(
          width: 92,
          child: Text(
            label,
            style: AppTextStyles.labelSmall.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(2),
            child: LinearProgressIndicator(
              value: value / 100,
              backgroundColor: AppColors.border,
              valueColor: const AlwaysStoppedAnimation(AppColors.primary),
              minHeight: 4,
            ),
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Text(
          '${value.toStringAsFixed(0)}%',
          style: AppTextStyles.labelSmall.copyWith(color: AppColors.primary),
        ),
      ],
    );
  }
}
