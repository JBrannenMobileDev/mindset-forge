import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import '../constants/app_spacing.dart';
import '../constants/app_strings.dart';
import '../constants/app_text_styles.dart';
import 'app_card.dart';
import '../../models/weekly_insight.dart';

/// Renders the three-section weekly insight card (pattern / breakthrough / focus).
class WeeklyInsightCard extends StatelessWidget {
  final WeeklyInsight insight;

  const WeeklyInsightCard({super.key, required this.insight});

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          WeeklyInsightRow(
            icon: Icons.insights_rounded,
            color: AppColors.primary,
            label: AppStrings.weeklyInsightPattern,
            text: insight.pattern,
          ),
          const SizedBox(height: AppSpacing.md),
          WeeklyInsightRow(
            icon: Icons.emoji_events_rounded,
            color: AppColors.warning,
            label: AppStrings.weeklyInsightBreakthrough,
            text: insight.breakthrough,
          ),
          const SizedBox(height: AppSpacing.md),
          WeeklyInsightRow(
            icon: Icons.bolt_rounded,
            color: AppColors.secondary,
            label: AppStrings.weeklyInsightFocus,
            text: insight.focus,
          ),
        ],
      ),
    );
  }
}

class WeeklyInsightRow extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String label;
  final String text;

  const WeeklyInsightRow({
    super.key,
    required this.icon,
    required this.color,
    required this.label,
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
          ),
          child: Icon(icon, color: color, size: 16),
        ),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: AppTextStyles.labelSmall
                    .copyWith(color: AppColors.textMuted),
              ),
              const SizedBox(height: 2),
              Text(
                text,
                style: AppTextStyles.bodyMedium.copyWith(height: 1.5),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
