import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../models/habit.dart';
import '../../../providers/habits_provider.dart';

/// Standalone daily habits card on the dashboard. Lists each active habit with
/// its own checkbox and self-completes when all are done. The matching
/// `habitsCompleted` daily-win flag is kept in sync by [HabitsNotifier], so this
/// widget only dispatches completion — it owns no streak logic.
class DailyHabitsCard extends ConsumerWidget {
  const DailyHabitsCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activeHabits =
        ref.watch(habitsProvider).where((h) => h.state == 'active').toList();

    if (activeHabits.isEmpty) {
      return AppCard(
        padding: EdgeInsets.zero,
        child: SizedBox(
          width: double.infinity,
          child: EmptyState(
            icon: Icons.repeat_rounded,
            title: AppStrings.noHabitsYet,
            subtitle: AppStrings.noHabitsSubtitle,
            ctaLabel: AppStrings.setUpHabits,
            onCta: () => context.go('/actions?tab=habits'),
          ),
        ),
      ).animate().fadeIn(duration: 400.ms);
    }

    final doneCount = activeHabits.where((h) => h.isCompletedToday).length;
    final allDone = doneCount == activeHabits.length;

    return AppCard(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.cardPadding,
              AppSpacing.md,
              AppSpacing.cardPadding,
              AppSpacing.sm,
            ),
            child: Row(
              children: [
                Icon(
                  allDone ? Icons.check_circle_rounded : Icons.repeat_rounded,
                  size: 18,
                  color: allDone ? AppColors.success : AppColors.primary,
                ),
                const SizedBox(width: AppSpacing.sm),
                Text(
                  allDone ? AppStrings.habitsAllDone : AppStrings.dailyHabits,
                  style: AppTextStyles.headlineSmall.copyWith(
                    color: allDone ? AppColors.success : AppColors.textPrimary,
                  ),
                ),
                const Spacer(),
                Text(
                  '$doneCount/${activeHabits.length}',
                  style: AppTextStyles.labelSmall.copyWith(
                    color: allDone ? AppColors.success : AppColors.textMuted,
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: AppColors.border),
          for (int i = 0; i < activeHabits.length; i++)
            _HabitRow(
              habit: activeHabits[i],
              isLast: i == activeHabits.length - 1,
              onComplete: () => ref
                  .read(habitsProvider.notifier)
                  .completeHabit(activeHabits[i].id),
            ).animate().fadeIn(
                  delay: Duration(milliseconds: i * 60),
                  duration: 400.ms,
                ),
        ],
      ),
    );
  }
}

class _HabitRow extends StatelessWidget {
  final Habit habit;
  final bool isLast;
  final VoidCallback onComplete;

  const _HabitRow({
    required this.habit,
    required this.isLast,
    required this.onComplete,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.cardPadding,
            vertical: AppSpacing.md,
          ),
          child: Row(
            children: [
              GestureDetector(
                onTap: habit.isCompletedToday ? null : onComplete,
                behavior: HitTestBehavior.opaque,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: habit.isCompletedToday
                        ? AppColors.primary
                        : Colors.transparent,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: habit.isCompletedToday
                          ? AppColors.primary
                          : AppColors.border,
                      width: 2,
                    ),
                  ),
                  child: habit.isCompletedToday
                      ? const Icon(Icons.check_rounded,
                          size: 16, color: Colors.white)
                      : null,
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      habit.name,
                      style: AppTextStyles.bodyMedium.copyWith(
                        decoration: habit.isCompletedToday
                            ? TextDecoration.lineThrough
                            : null,
                        color: habit.isCompletedToday
                            ? AppColors.textMuted
                            : AppColors.textPrimary,
                      ),
                    ),
                    if (habit.identityReinforces.isNotEmpty)
                      Text(
                        habit.identityReinforces,
                        style: AppTextStyles.labelSmall.copyWith(
                          color: AppColors.textMuted,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                  ],
                ),
              ),
              Row(
                children: [
                  const Icon(Icons.local_fire_department_rounded,
                      color: AppColors.warning, size: 14),
                  const SizedBox(width: 2),
                  Text(
                    '${habit.currentStreak}',
                    style:
                        AppTextStyles.labelSmall.copyWith(color: AppColors.warning),
                  ),
                ],
              ),
            ],
          ),
        ),
        if (!isLast)
          const Divider(
            height: 1,
            indent: AppSpacing.cardPadding + 28 + AppSpacing.md,
            color: AppColors.border,
          ),
      ],
    );
  }
}
