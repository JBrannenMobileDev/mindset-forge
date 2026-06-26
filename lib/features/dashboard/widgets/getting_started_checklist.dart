import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../models/user_profile.dart';

class GettingStartedChecklist extends StatelessWidget {
  final UserProfile profile;

  const GettingStartedChecklist({super.key, required this.profile});

  @override
  Widget build(BuildContext context) {
    final items = _buildItems(context, profile);
    final done = items.where((i) => i.isDone).length;
    final progress = done / items.length;

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceElevated,
        borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg, AppSpacing.lg, AppSpacing.lg, AppSpacing.md,
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Getting Started', style: AppTextStyles.labelLarge),
                      const SizedBox(height: 2),
                      Text(
                        '$done of ${items.length} steps complete',
                        style: AppTextStyles.bodySmall
                            .copyWith(color: AppColors.textSecondary),
                      ),
                    ],
                  ),
                ),
                Text(
                  '${(progress * 100).toStringAsFixed(0)}%',
                  style: AppTextStyles.labelLarge
                      .copyWith(color: AppColors.primary),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: progress,
                backgroundColor: AppColors.border,
                valueColor: const AlwaysStoppedAnimation(AppColors.primary),
                minHeight: 6,
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          ...items.asMap().entries.map((e) => _ChecklistRow(
                item: e.value,
                isLast: e.key == items.length - 1,
              ).animate().fadeIn(
                    delay: Duration(milliseconds: e.key * 60),
                    duration: 350.ms,
                  )),
          const SizedBox(height: AppSpacing.sm),
        ],
      ),
    ).animate().fadeIn(duration: 400.ms);
  }

  static List<_ChecklistItem> _buildItems(
      BuildContext context, UserProfile profile) {
    return [
      _ChecklistItem(
        label: 'Set your identity statement',
        isDone: profile.identityStatement.isNotEmpty,
        onTap: () => context.go('/mindset'),
      ),
      _ChecklistItem(
        label: 'Add your first affirmations',
        isDone: profile.affirmations.isNotEmpty,
        onTap: () => context.push('/affirmations'),
      ),
      _ChecklistItem(
        label: 'Complete your Mindset Blueprint',
        isDone: profile.blueprintCompleted,
        onTap: () => context.push('/blueprint-setup'),
      ),
      _ChecklistItem(
        label: 'Add your first goal',
        isDone: profile.goals.isNotEmpty,
        onTap: () => context.go('/actions?tab=goals'),
      ),
      _ChecklistItem(
        label: 'Complete your first journal entry',
        isDone: profile.dailyCompletions.any((c) => c.journalCompleted),
        onTap: () => context.go('/journal/new'),
      ),
      _ChecklistItem(
        label: 'Chat with your coach',
        isDone: profile.dailyCompletions.any((c) => c.chatCompleted),
        onTap: () => context.go('/chat'),
      ),
      _ChecklistItem(
        label: 'Complete a Deep Dive module',
        isDone: profile.deepDive.modules.isNotEmpty,
        locked: !profile.blueprintCompleted,
        onTap: () => context.push(
          profile.blueprintCompleted ? '/deep-dive' : '/blueprint-setup',
        ),
      ),
    ];
  }
}

class _ChecklistItem {
  final String label;
  final bool isDone;
  final bool locked;
  final VoidCallback onTap;

  const _ChecklistItem({
    required this.label,
    required this.isDone,
    this.locked = false,
    required this.onTap,
  });
}

class _ChecklistRow extends StatelessWidget {
  final _ChecklistItem item;
  final bool isLast;

  const _ChecklistRow({required this.item, required this.isLast});

  @override
  Widget build(BuildContext context) {
    final isLocked = item.locked && !item.isDone;

    return InkWell(
      onTap: item.isDone ? null : item.onTap,
      borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          AppSpacing.lg,
          AppSpacing.sm,
          AppSpacing.lg,
          isLast ? AppSpacing.sm : AppSpacing.xs,
        ),
        child: Row(
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                color: item.isDone ? AppColors.primary : Colors.transparent,
                shape: BoxShape.circle,
                border: Border.all(
                  color: item.isDone
                      ? AppColors.primary
                      : isLocked
                          ? AppColors.textDisabled
                          : AppColors.border,
                  width: 2,
                ),
              ),
              child: item.isDone
                  ? const Icon(Icons.check_rounded,
                      size: 13, color: Colors.white)
                  : isLocked
                      ? const Icon(Icons.lock_rounded,
                          size: 11, color: AppColors.textDisabled)
                      : null,
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Text(
                item.label,
                style: AppTextStyles.bodySmall.copyWith(
                  color: item.isDone
                      ? AppColors.textMuted
                      : isLocked
                          ? AppColors.textDisabled
                          : AppColors.textPrimary,
                  decoration:
                      item.isDone ? TextDecoration.lineThrough : null,
                  decorationColor: AppColors.textMuted,
                ),
              ),
            ),
            if (!item.isDone && !isLocked)
              const Icon(Icons.chevron_right_rounded,
                  color: AppColors.textMuted, size: 18),
            if (isLocked)
              const Icon(Icons.lock_outline_rounded,
                  color: AppColors.textDisabled, size: 16),
          ],
        ),
      ),
    );
  }
}
