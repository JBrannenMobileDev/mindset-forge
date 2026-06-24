import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/widgets/section_header.dart';
import '../../../models/user_profile.dart';
import '../../../models/goal.dart';

class GoalsSummaryWidget extends StatelessWidget {
  final UserProfile profile;

  const GoalsSummaryWidget({super.key, required this.profile});

  Color _categoryColor(String category) {
    return switch (category) {
      'career' => AppColors.categoryCareer,
      'health' => AppColors.categoryHealth,
      'relationships' => AppColors.categoryRelationships,
      'finances' => AppColors.categoryFinances,
      _ => AppColors.categoryPersonalGrowth,
    };
  }

  IconData _categoryIcon(String category) {
    return switch (category) {
      'career' => Icons.work_rounded,
      'health' => Icons.favorite_rounded,
      'relationships' => Icons.people_rounded,
      'finances' => Icons.attach_money_rounded,
      _ => Icons.auto_awesome_rounded,
    };
  }

  @override
  Widget build(BuildContext context) {
    final activeGoals = profile.goals.where((g) => g.status == 'active').toList();

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.screenPaddingH),
          child: SectionHeader(
            title: AppStrings.goalsSummary,
            actionLabel: 'See All',
            onAction: () => context.go('/actions?tab=goals'),
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        if (activeGoals.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.screenPaddingH),
            child: GestureDetector(
              onTap: () => context.go('/actions?tab=goals'),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(AppSpacing.lg),
                decoration: BoxDecoration(
                  color: AppColors.surfaceElevated,
                  borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
                  border: Border.all(color: AppColors.border),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.add_circle_outline_rounded, color: AppColors.primary, size: 20),
                    const SizedBox(width: AppSpacing.sm),
                    Text(
                      'Add your first goal',
                      style: AppTextStyles.labelLarge.copyWith(color: AppColors.primary),
                    ),
                  ],
                ),
              ),
            ),
          )
        else
          SizedBox(
            height: 160,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.screenPaddingH),
              itemCount: activeGoals.length,
              separatorBuilder: (_, __) => const SizedBox(width: AppSpacing.md),
              itemBuilder: (_, i) {
                final goal = activeGoals[i];
                return _GoalCard(
                  goal: goal,
                  color: _categoryColor(goal.category),
                  icon: _categoryIcon(goal.category),
                ).animate().fadeIn(delay: Duration(milliseconds: i * 80), duration: 400.ms);
              },
            ),
          ),
      ],
    );
  }
}

class _GoalCard extends StatelessWidget {
  final Goal goal;
  final Color color;
  final IconData icon;

  const _GoalCard({
    required this.goal,
    required this.color,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 200,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surfaceElevated,
        borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(AppSpacing.xs),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                ),
                child: Icon(icon, color: color, size: 16),
              ),
              const Spacer(),
              Text(
                '${goal.progressPercent.toStringAsFixed(0)}%',
                style: AppTextStyles.labelSmall.copyWith(color: color),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Expanded(
            child: Text(
              goal.title,
              style: AppTextStyles.labelLarge,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          ClipRRect(
            borderRadius: BorderRadius.circular(2),
            child: LinearProgressIndicator(
              value: goal.progressPercent / 100,
              backgroundColor: AppColors.border,
              valueColor: AlwaysStoppedAnimation(color),
              minHeight: 4,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'Due ${goal.targetDate.month}/${goal.targetDate.year}',
            style: AppTextStyles.labelSmall,
          ),
        ],
      ),
    );
  }
}
