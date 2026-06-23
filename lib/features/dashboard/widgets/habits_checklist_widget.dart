import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/section_header.dart';
import '../../../models/user_profile.dart';
import '../../../models/habit.dart';
import '../../../providers/habits_provider.dart';
import '../../../providers/daily_completion_provider.dart';

class HabitsChecklistWidget extends ConsumerWidget {
  final UserProfile profile;

  const HabitsChecklistWidget({super.key, required this.profile});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final habits = ref.watch(habitsProvider);
    final activeHabits = habits.where((h) => h.state == 'active').toList();

    return Column(
      children: [
        SectionHeader(
          title: AppStrings.habitsToday,
          actionLabel: 'Manage',
          onAction: () => context.go('/actions'),
        ),
        const SizedBox(height: AppSpacing.md),
        if (activeHabits.isEmpty)
          AppCard(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.add_rounded, color: AppColors.primary, size: 20),
                const SizedBox(width: AppSpacing.sm),
                Text(
                  'Add habits to track daily progress',
                  style: AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondary),
                ),
              ],
            ),
          )
        else
          AppCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: List.generate(
                activeHabits.length.clamp(0, 5),
                (i) => _HabitRow(
                  habit: activeHabits[i],
                  isLast: i == (activeHabits.length.clamp(0, 5) - 1),
                  onComplete: () async {
                    await ref.read(habitsProvider.notifier).completeHabit(activeHabits[i].id);
                    final allDone = ref
                        .read(habitsProvider)
                        .where((h) => h.state == 'active')
                        .every((h) => h.isCompletedToday);
                    if (allDone) {
                      await ref.read(dailyCompletionProvider.notifier).toggle('habitsCompleted', true);
                    }
                  },
                ).animate().fadeIn(delay: Duration(milliseconds: i * 60), duration: 400.ms),
              ),
            ),
          ),
      ],
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
                      ? const Icon(Icons.check_rounded, size: 16, color: Colors.white)
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
                    style: AppTextStyles.labelSmall.copyWith(color: AppColors.warning),
                  ),
                ],
              ),
            ],
          ),
        ),
        if (!isLast)
          const Divider(height: 1, indent: AppSpacing.cardPadding + 28 + AppSpacing.md),
      ],
    );
  }
}
