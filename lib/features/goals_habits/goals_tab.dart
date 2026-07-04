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
import '../../core/widgets/empty_state.dart';
import '../../core/widgets/section_header.dart';
import '../../models/goal.dart';
import '../../providers/auth_provider.dart';
import '../../providers/goals_provider.dart';
import 'actions_layout.dart';
import 'goal_form_modal.dart';
import 'widgets/actions_tab_skeleton.dart';

class GoalsTab extends ConsumerWidget {
  final ActionsLayoutContext layoutContext;

  const GoalsTab({
    super.key,
    this.layoutContext = ActionsLayoutContext.mobileTab,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileAsync = ref.watch(currentUserProfileProvider);

    return profileAsync.when(
      loading: () => ActionsTabSkeleton(layoutContext: layoutContext),
      error: (_, __) => _wrapIfDesktop(
        layoutContext,
        ErrorState(
          message: AppStrings.errorGeneric,
          onRetry: () => ref.invalidate(currentUserProfileProvider),
        ),
      ),
      data: (profile) {
        if (profile == null) {
          return ActionsTabSkeleton(layoutContext: layoutContext);
        }
        return _GoalsContent(layoutContext: layoutContext);
      },
    );
  }

  static Widget _wrapIfDesktop(ActionsLayoutContext ctx, Widget child) {
    if (ctx == ActionsLayoutContext.mobileTab) return child;
    return Center(child: child);
  }
}

class _GoalsContent extends ConsumerWidget {
  final ActionsLayoutContext layoutContext;

  const _GoalsContent({required this.layoutContext});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final goals = ref.watch(goalsProvider);
    final longTerm =
        goals.where((g) => g.isLongTerm && g.status == 'active').toList();
    final shortTerm =
        goals.where((g) => !g.isLongTerm && g.status == 'active').toList();

    if (longTerm.isEmpty && shortTerm.isEmpty) {
      return GoalsTab._wrapIfDesktop(
        layoutContext,
        EmptyState(
          icon: Icons.track_changes_rounded,
          title: AppStrings.noGoalsYet,
          subtitle: AppStrings.noGoalsSubtitle,
          ctaLabel: AppStrings.addGoal,
          onCta: () => GoalFormModal.show(context, ref),
        ),
      );
    }

    final padding = actionsTabPadding(layoutContext);
    final shrinkWrap = actionsTabShrinkWrap(layoutContext);

    return ListView(
      shrinkWrap: shrinkWrap,
      physics: actionsTabScrollPhysics(layoutContext),
      padding: padding,
      children: [
        if (longTerm.isNotEmpty) ...[
          const SectionHeader(title: AppStrings.goalLongTerm),
          const SizedBox(height: AppSpacing.md),
          ...longTerm.asMap().entries.map(
                (e) => Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.md),
                  child: _GoalCard(
                    goal: e.value,
                    onTap: () => context.push('/actions/goal/${e.value.id}'),
                  ).animate().fadeIn(
                        delay: Duration(milliseconds: e.key * 60),
                        duration: 400.ms,
                      ),
                ),
              ),
        ],
        if (shortTerm.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.md),
          const SectionHeader(title: AppStrings.goalShortTerm),
          const SizedBox(height: AppSpacing.md),
          ...shortTerm.asMap().entries.map(
                (e) => Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.md),
                  child: _GoalCard(
                    goal: e.value,
                    onTap: () => context.push('/actions/goal/${e.value.id}'),
                  ).animate().fadeIn(
                        delay: Duration(milliseconds: e.key * 60),
                        duration: 400.ms,
                      ),
                ),
              ),
        ],
      ],
    );
  }
}

class _GoalCard extends StatelessWidget {
  final Goal goal;
  final VoidCallback onTap;

  const _GoalCard({required this.goal, required this.onTap});

  Color get _color {
    return switch (goal.category) {
      'career' => AppColors.categoryCareer,
      'health' => AppColors.categoryHealth,
      'relationships' => AppColors.categoryRelationships,
      'finances' => AppColors.categoryFinances,
      _ => AppColors.categoryPersonalGrowth,
    };
  }

  IconData get _icon {
    return switch (goal.category) {
      'career' => Icons.work_rounded,
      'health' => Icons.favorite_rounded,
      'relationships' => Icons.people_rounded,
      'finances' => Icons.attach_money_rounded,
      _ => Icons.auto_awesome_rounded,
    };
  }

  @override
  Widget build(BuildContext context) {
    return AppCard(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(AppSpacing.sm),
                decoration: BoxDecoration(
                  color: _color.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                ),
                child: Icon(_icon, color: _color, size: AppSpacing.iconMd),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(goal.title, style: AppTextStyles.labelLarge),
                    Text(
                      goal.category.replaceAll('_', ' ').toUpperCase(),
                      style: AppTextStyles.overline.copyWith(color: _color),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.sm,
                  vertical: AppSpacing.xs,
                ),
                decoration: BoxDecoration(
                  color: _color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
                ),
                child: Text(
                  '${goal.progressPercent.toStringAsFixed(0)}%',
                  style: AppTextStyles.labelSmall.copyWith(color: _color),
                ),
              ),
            ],
          ),
          if (goal.identityBecomes.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(
              goal.identityBecomes,
              style: AppTextStyles.bodySmall.copyWith(
                color: AppColors.textSecondary,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
          const SizedBox(height: AppSpacing.md),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: goal.progressPercent / 100,
              backgroundColor: AppColors.border,
              valueColor: AlwaysStoppedAnimation(_color),
              minHeight: 5,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${AppStrings.goalTargetPrefix} ${AppDateUtils.formatDate(goal.targetDate)}',
                style: AppTextStyles.labelSmall,
              ),
              const Icon(
                Icons.chevron_right_rounded,
                color: AppColors.textMuted,
                size: 18,
              ),
            ],
          ),
        ],
      ),
    );
  }
}
