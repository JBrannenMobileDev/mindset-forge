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
import '../../../core/widgets/habit_completion_checkbox.dart';
import '../../../core/widgets/partner_locked_overlay.dart';
import '../../../models/habit.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/habits_provider.dart';
import '../../../providers/partner_limits_provider.dart';

/// Standalone daily habits card on the dashboard. Lists each active habit with
/// its own checkbox and self-completes when all are done. The matching
/// `habitsCompleted` daily-win flag is kept in sync by [HabitsNotifier], so this
/// widget only dispatches completion — it owns no streak logic.
class DailyHabitsCard extends ConsumerWidget {
  const DailyHabitsCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(currentUserProfileProvider).valueOrNull;
    final limits = ref.read(partnerLimitsProvider);
    final lockedHabitIds = profile == null
        ? const <String>{}
        : limits.lockedIds(profile, PartnerFeature.habit);
    final onLockedTap = () =>
        limits.showLockedUpgrade(context, PartnerFeature.habit);

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

    final unlockedHabits = activeHabits
        .where((h) => !lockedHabitIds.contains(h.id))
        .toList();
    final doneCount = unlockedHabits.where((h) => h.isCompletedToday).length;
    final allDone =
        unlockedHabits.isNotEmpty && doneCount == unlockedHabits.length;

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
                  '$doneCount/${unlockedHabits.length}',
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
              isLocked: lockedHabitIds.contains(activeHabits[i].id),
              onLockedTap: onLockedTap,
              onComplete: () {
                if (lockedHabitIds.contains(activeHabits[i].id)) {
                  onLockedTap();
                  return;
                }
                ref
                    .read(habitsProvider.notifier)
                    .completeHabit(activeHabits[i].id);
              },
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
  final bool isLocked;
  final VoidCallback onLockedTap;
  final VoidCallback onComplete;

  const _HabitRow({
    required this.habit,
    required this.isLast,
    required this.isLocked,
    required this.onLockedTap,
    required this.onComplete,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        PartnerLockedOverlay(
          isLocked: isLocked,
          onLockedTap: onLockedTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.cardPadding,
              vertical: AppSpacing.md,
            ),
            child: Row(
              children: [
                HabitCompletionCheckbox(
                  isDone: habit.isCompletedToday,
                  enabled: !isLocked,
                  onTap: onComplete,
                  size: 28,
                  iconSize: 16,
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
                      style: AppTextStyles.labelSmall
                          .copyWith(color: AppColors.warning),
                    ),
                  ],
                ),
              ],
            ),
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
