import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/services/getting_started_expand_store.dart';
import '../../../core/utils/breakpoints.dart';
import '../../../core/widgets/widget_education_sheet.dart';
import '../../../models/user_profile.dart';

class GettingStartedChecklist extends StatefulWidget {
  final UserProfile profile;

  const GettingStartedChecklist({super.key, required this.profile});

  @override
  State<GettingStartedChecklist> createState() =>
      _GettingStartedChecklistState();
}

class _GettingStartedChecklistState extends State<GettingStartedChecklist> {
  bool _expanded = false;

  @override
  void initState() {
    super.initState();
    _loadExpandedPref();
  }

  Future<void> _loadExpandedPref() async {
    final stored = await GettingStartedExpandStore.isExpanded();
    if (!mounted) return;
    setState(() => _expanded = stored);
  }

  void _setExpanded(bool value) {
    setState(() => _expanded = value);
    GettingStartedExpandStore.setExpanded(value);
  }

  @override
  Widget build(BuildContext context) {
    final items = _buildItems(context, widget.profile);
    final done = items.where((i) => i.isDone).length;
    final progress = done / items.length;
    final incomplete = items.where((i) => !i.isDone).toList();
    final isCompact = !Breakpoints.isWide(context);
    final forceExpanded = isCompact && incomplete.length <= 2;
    final isExpanded = !isCompact || forceExpanded || _expanded;
    final nextItem = _nextIncompleteItem(items);
    final progressLabel = AppStrings.gettingStartedProgress
        .replaceAll('{done}', '$done')
        .replaceAll('{total}', '${items.length}');

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
                      Text(AppStrings.gettingStartedTitle,
                          style: AppTextStyles.labelLarge),
                      const SizedBox(height: 2),
                      Text(
                        progressLabel,
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
          AnimatedSize(
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeInOut,
            alignment: Alignment.topCenter,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (isExpanded)
                  ...incomplete.asMap().entries.map(
                        (e) => _ChecklistRow(
                          item: e.value,
                          isLast: e.key == incomplete.length - 1 &&
                              (!isCompact || forceExpanded),
                        ),
                      )
                else if (nextItem != null)
                  _ChecklistRow(item: nextItem, isLast: false),
                if (isCompact && !forceExpanded)
                  _ExpandToggle(
                    expanded: isExpanded,
                    onTap: () => _setExpanded(!isExpanded),
                  ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
        ],
      ),
    ).animate().fadeIn(duration: 400.ms);
  }

  static _ChecklistItem? _nextIncompleteItem(List<_ChecklistItem> items) {
    for (final item in items) {
      if (!item.isDone && !item.locked) return item;
    }
    for (final item in items) {
      if (!item.isDone) return item;
    }
    return null;
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
        label: 'Add your first habit',
        isDone: profile.habits.isNotEmpty,
        onTap: () => context.go('/actions?tab=habits'),
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
      _ChecklistItem(
        label: 'Add the Focus Widget to your home screen',
        isDone: profile.widgetPromptSeen,
        onTap: () => showWidgetEducationSheet(context),
      ),
    ];
  }
}

class _ExpandToggle extends StatelessWidget {
  final bool expanded;
  final VoidCallback onTap;

  const _ExpandToggle({required this.expanded, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg,
          AppSpacing.xs,
          AppSpacing.lg,
          AppSpacing.xs,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              expanded
                  ? AppStrings.gettingStartedCollapse
                  : AppStrings.gettingStartedViewAll,
              style: AppTextStyles.labelSmall.copyWith(color: AppColors.primary),
            ),
            const SizedBox(width: AppSpacing.xs),
            Icon(
              expanded
                  ? Icons.expand_less_rounded
                  : Icons.expand_more_rounded,
              size: 16,
              color: AppColors.primary,
            ),
          ],
        ),
      ),
    );
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
