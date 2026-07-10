import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_spacing.dart';
import '../../core/constants/app_text_styles.dart';
import '../../core/constants/app_strings.dart';
import '../../core/utils/app_date_utils.dart';
import '../../core/widgets/app_card.dart';
import '../../models/habit.dart';
import '../../providers/habits_provider.dart';
import 'habits_tab.dart';

/// Read-only drill-down for a single habit: streak/rate stats plus a
/// GitHub-style completion heatmap. Mirrors the "pushed screen" structure and
/// activity-heatmap visuals used by [GoalDetailScreen]/`progress_screen.dart`
/// for consistency across the app.
class HabitDetailScreen extends ConsumerWidget {
  final String habitId;

  const HabitDetailScreen({super.key, required this.habitId});

  Future<void> _confirmDelete(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      barrierColor: AppColors.scrim,
      builder: (dialogContext) => Dialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSpacing.radiusXl),
          side: BorderSide(color: AppColors.error.withValues(alpha: 0.25)),
        ),
        insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.delete_outline_rounded,
                  color: AppColors.error, size: 32),
              const SizedBox(height: AppSpacing.md),
              Text(AppStrings.habitDeleteConfirmTitle,
                  style: AppTextStyles.headlineSmall),
              const SizedBox(height: AppSpacing.sm),
              Text(
                AppStrings.habitDeleteConfirmBody,
                style: AppTextStyles.bodyMedium
                    .copyWith(color: AppColors.textSecondary),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSpacing.xl),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.of(dialogContext).pop(false),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: AppColors.border),
                        padding: const EdgeInsets.symmetric(
                            vertical: AppSpacing.md),
                        shape: RoundedRectangleBorder(
                          borderRadius:
                              BorderRadius.circular(AppSpacing.radiusMd),
                        ),
                      ),
                      child: Text(AppStrings.cancel,
                          style: AppTextStyles.labelLarge),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => Navigator.of(dialogContext).pop(true),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.error,
                        padding: const EdgeInsets.symmetric(
                            vertical: AppSpacing.md),
                        shape: RoundedRectangleBorder(
                          borderRadius:
                              BorderRadius.circular(AppSpacing.radiusMd),
                        ),
                      ),
                      child: Text(AppStrings.delete,
                          style: AppTextStyles.labelLarge
                              .copyWith(color: Colors.white)),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );

    if (confirmed == true && context.mounted) {
      final deleted =
          await ref.read(habitsProvider.notifier).deleteHabit(habitId);
      if (!context.mounted) return;
      if (deleted) {
        context.pop();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(AppStrings.errorGeneric),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final habits = ref.watch(habitsProvider);
    final matches = habits.where((h) => h.id == habitId);
    final habit = matches.isEmpty ? null : matches.first;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () => context.pop(),
        ),
        title: Text(AppStrings.habitDetailTitle, style: AppTextStyles.headlineMedium),
        actions: habit == null
            ? null
            : [
                IconButton(
                  icon: const Icon(Icons.edit_rounded),
                  onPressed: () =>
                      HabitFormModal.show(context, ref, editHabit: habit),
                ),
                PopupMenuButton<String>(
                  color: AppColors.surfaceElevated,
                  icon: const Icon(Icons.more_vert_rounded),
                  onSelected: (value) async {
                    if (value == 'toggle') {
                      final isActive = habit.state == 'active';
                      await ref.read(habitsProvider.notifier).toggleState(
                            habit.id,
                            isActive ? 'paused' : 'active',
                          );
                    } else if (value == 'delete') {
                      await _confirmDelete(context, ref);
                    }
                  },
                  itemBuilder: (_) => [
                    PopupMenuItem(
                      value: 'toggle',
                      child: Text(
                        habit.state == 'active'
                            ? AppStrings.habitPause
                            : AppStrings.habitResume,
                        style: AppTextStyles.bodyMedium,
                      ),
                    ),
                    PopupMenuItem(
                      value: 'delete',
                      child: Text(
                        AppStrings.habitDelete,
                        style: AppTextStyles.bodyMedium
                            .copyWith(color: AppColors.error),
                      ),
                    ),
                  ],
                ),
              ],
      ),
      body: habit == null
          ? Center(
              child: Text(
                AppStrings.habitNotFound,
                style: AppTextStyles.bodyMedium
                    .copyWith(color: AppColors.textSecondary),
              ),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.all(AppSpacing.screenPaddingH),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _HabitDetailHeader(habit: habit).animate().fadeIn(duration: 400.ms),
                  const SizedBox(height: AppSpacing.xl),
                  _HabitStatsRow(habit: habit).animate().fadeIn(delay: 100.ms),
                  const SizedBox(height: AppSpacing.xl),
                  Text(AppStrings.habitHistoryTitle, style: AppTextStyles.labelLarge),
                  const SizedBox(height: AppSpacing.sm),
                  _HabitHeatmap(habit: habit).animate().fadeIn(delay: 150.ms),
                  const SizedBox(height: 100),
                ],
              ),
            ),
    );
  }
}

class _HabitDetailHeader extends StatelessWidget {
  final Habit habit;

  const _HabitDetailHeader({required this.habit});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(habit.name, style: AppTextStyles.headlineLarge),
            ),
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.sm,
                vertical: 2,
              ),
              decoration: BoxDecoration(
                color: habit.state == 'active'
                    ? AppColors.secondaryContainer
                    : AppColors.surfaceHighest,
                borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
              ),
              child: Text(
                habit.frequency,
                style: AppTextStyles.labelSmall.copyWith(
                  color: habit.state == 'active'
                      ? AppColors.secondary
                      : AppColors.textMuted,
                ),
              ),
            ),
          ],
        ),
        if (habit.trigger.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: [
              const Icon(Icons.bolt_rounded, color: AppColors.textMuted, size: 14),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  '${AppStrings.habitWhenPrefix} ${habit.trigger}',
                  style: AppTextStyles.bodyMedium
                      .copyWith(color: AppColors.textSecondary),
                ),
              ),
            ],
          ),
        ],
        if (habit.identityReinforces.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.sm),
          Text(
            habit.identityReinforces,
            style: AppTextStyles.bodyMedium.copyWith(
              color: AppColors.primary,
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
      ],
    );
  }
}

class _HabitStatsRow extends StatelessWidget {
  final Habit habit;

  const _HabitStatsRow({required this.habit});

  @override
  Widget build(BuildContext context) {
    final stats = _computeStats(habit);
    return Row(
      children: [
        Expanded(
          child: _StatCard(
            value: '${habit.currentStreak}',
            label: AppStrings.currentStreak,
            icon: Icons.local_fire_department_rounded,
            color: AppColors.warning,
          ),
        ),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: _StatCard(
            value: '${(stats.completionRate * 100).round()}%',
            label: AppStrings.habitCompletionRate,
            icon: Icons.donut_large_rounded,
            color: AppColors.primary,
          ),
        ),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: _StatCard(
            value: '${stats.totalCompletions}',
            label: AppStrings.habitTotalCompletions,
            icon: Icons.check_circle_rounded,
            color: AppColors.secondary,
          ),
        ),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  final String value;
  final String label;
  final IconData icon;
  final Color color;

  const _StatCard({
    required this.value,
    required this.label,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.sm + 2),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(height: AppSpacing.xs),
          Text(value, style: AppTextStyles.headlineSmall.copyWith(color: color)),
          Text(
            label,
            style: AppTextStyles.labelSmall,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

class _HabitStats {
  final int totalCompletions;
  final double completionRate;

  const _HabitStats(this.totalCompletions, this.completionRate);
}

/// Completion rate over a rolling window (8 weeks), clamped to how long the
/// habit has actually existed so a brand-new habit doesn't start at a
/// misleadingly low rate. Daily habits are scored per-day, weekly per-week,
/// both via [Habit.hasCompletionInPeriodContaining] so the rate matches what
/// the heatmap below visually shows.
_HabitStats _computeStats(Habit habit) {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final createdDay =
      DateTime(habit.createdAt.year, habit.createdAt.month, habit.createdAt.day);

  if (habit.frequency == 'weekly') {
    const windowWeeks = 8;
    final currentWeekStart = today.subtract(Duration(days: today.weekday - 1));
    final createdWeekStart =
        createdDay.subtract(Duration(days: createdDay.weekday - 1));
    final elapsedWeeks =
        (currentWeekStart.difference(createdWeekStart).inDays / 7).round() + 1;
    final totalWeeks = elapsedWeeks.clamp(1, windowWeeks);

    var satisfied = 0;
    for (var i = 0; i < totalWeeks; i++) {
      final weekStart = currentWeekStart.subtract(Duration(days: 7 * i));
      if (habit.hasCompletionInPeriodContaining(weekStart)) satisfied++;
    }
    return _HabitStats(habit.completionHistory.length, satisfied / totalWeeks);
  }

  const windowDays = 56;
  final elapsedDays = today.difference(createdDay).inDays + 1;
  final totalDays = elapsedDays.clamp(1, windowDays);

  var satisfied = 0;
  for (var i = 0; i < totalDays; i++) {
    final day = today.subtract(Duration(days: i));
    if (habit.hasCompletionInPeriodContaining(day)) satisfied++;
  }
  return _HabitStats(habit.completionHistory.length, satisfied / totalDays);
}

class _HabitHeatmap extends StatelessWidget {
  final Habit habit;

  const _HabitHeatmap({required this.habit});

  @override
  Widget build(BuildContext context) {
    final days = AppDateUtils.lastNDays(56);
    final createdDay =
        DateTime(habit.createdAt.year, habit.createdAt.month, habit.createdAt.day);

    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Last 8 weeks', style: AppTextStyles.labelSmall),
          const SizedBox(height: AppSpacing.sm),
          Wrap(
            spacing: 3,
            runSpacing: 3,
            children: days.map((d) {
              final dayOnly = DateTime(d.year, d.month, d.day);
              final beforeCreation = dayOnly.isBefore(createdDay);
              final done = !beforeCreation &&
                  habit.hasCompletionInPeriodContaining(dayOnly);
              final color = beforeCreation
                  ? AppColors.surfaceHighest.withValues(alpha: 0.3)
                  : done
                      ? AppColors.primary
                      : AppColors.surfaceHighest;
              final status = beforeCreation ? '' : (done ? ' — done' : ' — missed');
              return Tooltip(
                message: '${AppDateUtils.formatDate(d)}$status',
                child: Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: AppSpacing.sm),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  color: AppColors.surfaceHighest,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 4),
              Text('Missed', style: AppTextStyles.labelSmall),
              const SizedBox(width: AppSpacing.sm),
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 4),
              Text('Done', style: AppTextStyles.labelSmall),
            ],
          ),
        ],
      ),
    );
  }
}
