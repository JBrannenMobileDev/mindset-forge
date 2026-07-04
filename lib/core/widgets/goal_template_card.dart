import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../constants/app_colors.dart';
import '../constants/app_spacing.dart';
import '../constants/app_strings.dart';
import '../constants/app_text_styles.dart';
import '../constants/goal_templates.dart';
import 'hoverable.dart';

/// Curated goal template tile — shared by onboarding (multi-select) and the
/// in-app goal gallery (single-select).
class GoalTemplateCard extends StatelessWidget {
  final GoalTemplate template;
  final int index;
  final bool selected;
  final bool committed;
  final VoidCallback? onTap;

  const GoalTemplateCard({
    super.key,
    required this.template,
    required this.index,
    required this.selected,
    this.committed = false,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = goalCategoryColor(template.category);
    return Hoverable(
      cursor: committed ? SystemMouseCursors.basic : SystemMouseCursors.click,
      onTap: onTap,
      builder: (context, hovered) => AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: committed
              ? AppColors.surfaceElevated.withValues(alpha: 0.4)
              : selected
                  ? color.withValues(alpha: 0.12)
                  : hovered
                      ? color.withValues(alpha: 0.06)
                      : AppColors.surfaceElevated,
          borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
          border: Border.all(
            color: committed
                ? AppColors.border.withValues(alpha: 0.5)
                : selected
                    ? color.withValues(alpha: 0.7)
                    : hovered
                        ? color.withValues(alpha: 0.5)
                        : AppColors.border,
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: committed
                        ? AppColors.textMuted.withValues(alpha: 0.12)
                        : color.withValues(alpha: selected ? 0.25 : 0.15),
                    borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                  ),
                  child: Icon(
                    template.icon,
                    size: 26,
                    color: committed
                        ? AppColors.textMuted
                        : selected
                            ? color
                            : color.withValues(alpha: 0.85),
                  ),
                ),
                const Spacer(),
                if (selected)
                  Container(
                    width: 20,
                    height: 20,
                    decoration: BoxDecoration(
                      color: color,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.check_rounded,
                      color: Colors.white,
                      size: 13,
                    ),
                  )
                else if (committed)
                  const Icon(Icons.check_rounded,
                      color: AppColors.textMuted, size: 16)
                else
                  Text(
                    goalHorizonLabel(template.months),
                    style: AppTextStyles.labelSmall
                        .copyWith(color: AppColors.textMuted),
                  ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              template.title,
              style: AppTextStyles.labelLarge.copyWith(
                color: committed
                    ? AppColors.textMuted
                    : selected
                        ? color
                        : AppColors.textPrimary,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 3),
            Text(
              template.description,
              style: AppTextStyles.bodySmall.copyWith(
                color: committed
                    ? AppColors.textDisabled
                    : AppColors.textMuted,
                height: 1.3,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    ).animate().fadeIn(
          delay: Duration(milliseconds: index * 40),
          duration: 300.ms,
        );
  }
}

/// "Write your own" / "Start from scratch" tile at the end of the template grid.
class GoalSomethingElseTile extends StatelessWidget {
  final int index;
  final VoidCallback onTap;
  final String title;
  final String subtitle;
  final IconData icon;

  const GoalSomethingElseTile({
    super.key,
    required this.index,
    required this.onTap,
    this.title = AppStrings.onboardingGoalsSomethingElse,
    this.subtitle = AppStrings.onboardingGoalsSomethingElseHint,
    this.icon = Icons.edit_rounded,
  });

  @override
  Widget build(BuildContext context) {
    return Hoverable(
      onTap: onTap,
      builder: (context, hovered) => AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: AppColors.surfaceElevated,
          borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
          border: Border.fromBorderSide(
            BorderSide(
              color: hovered
                  ? AppColors.textSecondary.withValues(alpha: 0.5)
                  : AppColors.border,
            ),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: AppColors.textMuted.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
              ),
              child: Icon(icon, size: 24, color: AppColors.textSecondary),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              title,
              style: AppTextStyles.labelLarge
                  .copyWith(color: AppColors.textSecondary),
            ),
            const SizedBox(height: 3),
            Text(
              subtitle,
              style: AppTextStyles.bodySmall.copyWith(
                color: AppColors.textMuted,
                height: 1.3,
              ),
            ),
          ],
        ),
      ),
    ).animate().fadeIn(
          delay: Duration(milliseconds: index * 40),
          duration: 300.ms,
        );
  }
}
