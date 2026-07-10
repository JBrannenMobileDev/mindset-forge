import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/constants/goal_templates.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_spacing.dart';
import '../../core/constants/app_text_styles.dart';
import '../../core/constants/app_strings.dart';
import '../../core/utils/app_date_utils.dart';
import '../../core/widgets/app_card.dart';
import '../../core/widgets/empty_state.dart';
import '../../core/widgets/section_header.dart';
import '../../core/widgets/partner_locked_overlay.dart';
import '../../models/goal.dart';
import '../../models/user_profile.dart';
import '../../providers/auth_provider.dart';
import '../../providers/goals_provider.dart';
import '../../providers/partner_limits_provider.dart';
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
        return _GoalsContent(
          layoutContext: layoutContext,
          primaryGoalId: profile.primaryGoalId,
          profile: profile,
        );
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
  final String primaryGoalId;
  final UserProfile profile;

  const _GoalsContent({
    required this.layoutContext,
    required this.primaryGoalId,
    required this.profile,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final goals = ref.watch(goalsProvider);
    final limits = ref.read(partnerLimitsProvider);
    final lockedGoalIds = limits.lockedIds(profile, PartnerFeature.goal);
    final onLockedGoalTap =
        () => limits.showLockedUpgrade(context, PartnerFeature.goal);
    final active = goals.where((g) => g.status == 'active').toList();
    final completed = goals.where((g) => g.status == 'completed').toList()
      ..sort((a, b) => (b.completedAt ?? b.createdAt)
          .compareTo(a.completedAt ?? a.createdAt));

    if (active.isEmpty && completed.isEmpty) {
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

    // Pin the North Star to the top, keeping the rest in creation order.
    final northStar = active.where((g) => g.id == primaryGoalId).toList();
    final rest = active.where((g) => g.id != primaryGoalId).toList();
    final orderedActive = [...northStar, ...rest];

    final padding = actionsTabPadding(layoutContext);
    final shrinkWrap = actionsTabShrinkWrap(layoutContext);

    return ListView(
      shrinkWrap: shrinkWrap,
      physics: actionsTabScrollPhysics(layoutContext),
      padding: padding,
      children: [
        if (orderedActive.isNotEmpty) ...[
          ...orderedActive.asMap().entries.map(
                (e) => Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.md),
                  child: _GoalCard(
                    goal: e.value,
                    isNorthStar: e.value.id == primaryGoalId,
                    isLocked: lockedGoalIds.contains(e.value.id),
                    onLockedTap: onLockedGoalTap,
                    onTap: lockedGoalIds.contains(e.value.id)
                        ? onLockedGoalTap
                        : () => context.push('/actions/goal/${e.value.id}'),
                  ).animate().fadeIn(
                        delay: Duration(milliseconds: e.key * 60),
                        duration: 400.ms,
                      ),
                ),
              ),
        ],
        if (completed.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.md),
          SectionHeader(
              title: '${AppStrings.goalCompletedSection} (${completed.length})'),
          const SizedBox(height: AppSpacing.md),
          ...completed.map(
            (g) => Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.sm),
              child: _CompletedGoalTile(
                goal: g,
                isLocked: lockedGoalIds.contains(g.id),
                onLockedTap: onLockedGoalTap,
                onTap: lockedGoalIds.contains(g.id)
                    ? onLockedGoalTap
                    : () => context.push('/actions/goal/${g.id}'),
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
  final bool isNorthStar;
  final VoidCallback onTap;
  final bool isLocked;
  final VoidCallback? onLockedTap;

  const _GoalCard({
    required this.goal,
    required this.isNorthStar,
    required this.onTap,
    this.isLocked = false,
    this.onLockedTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = goalCategoryColor(goal.category);
    final progress = goal.derivedProgress;

    return PartnerLockedOverlay(
      isLocked: isLocked,
      onLockedTap: onLockedTap,
      child: AppCard(
        onTap: onTap,
        borderColor: isNorthStar ? AppColors.primary.withValues(alpha: 0.5) : null,
        child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (isNorthStar) ...[
            Row(
              children: [
                const Icon(Icons.star_rounded,
                    color: AppColors.primary, size: 14),
                const SizedBox(width: 4),
                Text(
                  AppStrings.goalNorthStar.toUpperCase(),
                  style: AppTextStyles.overline
                      .copyWith(color: AppColors.primary),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
          ],
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(AppSpacing.sm),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                ),
                child: Icon(goalCategoryIcon(goal.category),
                    color: color, size: AppSpacing.iconMd),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(goal.title, style: AppTextStyles.labelLarge),
                    Text(
                      goal.category.replaceAll('_', ' ').toUpperCase(),
                      style: AppTextStyles.overline.copyWith(color: color),
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
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
                ),
                child: Text(
                  '${progress.toStringAsFixed(0)}%',
                  style: AppTextStyles.labelSmall.copyWith(color: color),
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
              value: progress / 100,
              backgroundColor: AppColors.border,
              valueColor: AlwaysStoppedAnimation(color),
              minHeight: 5,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                goal.hasSteps
                    ? AppStrings.goalMilestoneProgress(
                        goal.completedStepCount, goal.actionSteps.length)
                    : '${AppStrings.goalTargetPrefix} ${AppDateUtils.formatDate(goal.targetDate)}',
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
      ),
    );
  }
}

/// Compact tile for a finished goal — kept visible as proof of progress rather
/// than vanishing on completion.
class _CompletedGoalTile extends StatelessWidget {
  final Goal goal;
  final VoidCallback onTap;
  final bool isLocked;
  final VoidCallback? onLockedTap;

  const _CompletedGoalTile({
    required this.goal,
    required this.onTap,
    this.isLocked = false,
    this.onLockedTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = goalCategoryColor(goal.category);
    return PartnerLockedOverlay(
      isLocked: isLocked,
      onLockedTap: onLockedTap,
      child: AppCard(
        onTap: onTap,
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm + 2,
        ),
        child: Row(
        children: [
          Icon(Icons.check_circle_rounded, color: color, size: 20),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              goal.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTextStyles.bodyMedium
                  .copyWith(color: AppColors.textSecondary),
            ),
          ),
          if (goal.completedAt != null)
            Text(
              AppDateUtils.formatDate(goal.completedAt!),
              style: AppTextStyles.labelSmall,
            ),
        ],
      ),
      ),
    );
  }
}
