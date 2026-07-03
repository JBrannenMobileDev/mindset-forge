import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_spacing.dart';
import '../../core/constants/app_text_styles.dart';
import '../../core/constants/app_strings.dart';
import '../../core/widgets/app_card.dart';
import '../../core/widgets/responsive_layout.dart';
import '../../core/widgets/section_header.dart';
import '../../core/widgets/shimmer_widget.dart';
import '../../core/widgets/weekly_insight_card.dart';
import '../../core/utils/app_date_utils.dart';
import '../../models/user_profile.dart';
import '../../models/weekly_insight.dart';
import '../../providers/auth_provider.dart';
import '../../providers/streak_provider.dart';
import '../../providers/weekly_insight_provider.dart';
import '../../models/daily_completion.dart';
import '../mindset/blueprint_tab.dart';
import '../../core/widgets/app_button.dart';

class ProgressScreen extends ConsumerStatefulWidget {
  const ProgressScreen({super.key});

  @override
  ConsumerState<ProgressScreen> createState() => _ProgressScreenState();
}

class _ProgressScreenState extends ConsumerState<ProgressScreen> {
  bool _markedViewed = false;

  int _activeDaysThisWeek(List<DailyCompletion> completions) {
    final days = AppDateUtils.lastNDays(7);
    var count = 0;
    for (final d in days) {
      final dateStr =
          '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
      final completion = completions.firstWhere(
        (c) => c.date == dateStr,
        orElse: () => DailyCompletion(date: dateStr),
      );
      if (completion.completedCount >= 3) count++;
    }
    return count;
  }

  Future<void> _refreshInsight(UserProfile profile) async {
    final ok = await ref.read(weeklyInsightRefreshingProvider.notifier).refresh(profile);
    if (!mounted) return;
    if (!ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppStrings.weeklyInsightRefreshLimit),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  void _showPastInsightSheet(WeeklyInsight insight) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.surface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppSpacing.radiusXl),
        ),
      ),
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.55,
        maxChildSize: 0.92,
        minChildSize: 0.4,
        expand: false,
        builder: (_, ctrl) => SingleChildScrollView(
          controller: ctrl,
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg,
            AppSpacing.sm,
            AppSpacing.lg,
            AppSpacing.xxxl,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: AppSpacing.lg),
                  decoration: BoxDecoration(
                    color: AppColors.border,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Text(
                '${AppStrings.weeklyInsightWeekEnding} ${_formatWeekEnding(insight.weekEnding)}',
                style: AppTextStyles.headlineSmall,
              ),
              const SizedBox(height: AppSpacing.md),
              WeeklyInsightCard(insight: insight),
            ],
          ),
        ),
      ),
    );
  }

  String _formatWeekEnding(String weekEnding) {
    final parsed = DateTime.tryParse(weekEnding);
    if (parsed != null) return AppDateUtils.formatDate(parsed);
    final parts = weekEnding.split('-');
    if (parts.length == 3) {
      final d = DateTime(
        int.parse(parts[0]),
        int.parse(parts[1]),
        int.parse(parts[2]),
      );
      return AppDateUtils.formatDate(d);
    }
    return weekEnding;
  }

  @override
  Widget build(BuildContext context) {
    final profile = ref.watch(currentUserProfileProvider).valueOrNull;
    final streak = ref.watch(streakProvider);
    final perfectDays = ref.watch(perfectDayCountProvider);
    final isRefreshing = ref.watch(weeklyInsightRefreshingProvider);

    final insight = profile?.weeklyInsight;
    if (insight != null && insight.isUnread && !_markedViewed) {
      _markedViewed = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ref.read(weeklyInsightRefreshingProvider.notifier).markViewedIfNeeded(insight);
      });
    } else if (insight == null || !insight.isUnread) {
      _markedViewed = false;
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        title: Text(AppStrings.progress, style: AppTextStyles.headlineMedium),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () => context.pop(),
        ),
      ),
      body: profile == null
          ? const _ProgressSkeleton()
          : ResponsiveLayout(
              maxWidth: 680,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.screenPaddingH,
                  AppSpacing.md,
                  AppSpacing.screenPaddingH,
                  100,
                ),
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: _StatCard(
                          value: '$streak',
                          label: AppStrings.currentStreak,
                          icon: Icons.local_fire_department_rounded,
                          color: AppColors.warning,
                        ).animate().fadeIn(duration: 400.ms),
                      ),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: _StatCard(
                          value: '$perfectDays',
                          label: AppStrings.perfectDays,
                          icon: Icons.star_rounded,
                          color: AppColors.primary,
                        ).animate().fadeIn(delay: 100.ms),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  Text('Activity Heatmap', style: AppTextStyles.headlineSmall),
                  const SizedBox(height: AppSpacing.md),
                  _ActivityHeatmap(completions: profile.dailyCompletions),
                  const SizedBox(height: AppSpacing.xl),
                  Text('Weekly Breakdown', style: AppTextStyles.headlineSmall),
                  const SizedBox(height: AppSpacing.md),
                  _WeeklyBreakdown(completions: profile.dailyCompletions),
                  const SizedBox(height: AppSpacing.xl),
                  _WeeklyInsightsSection(
                    insight: insight,
                    isLoading: isRefreshing,
                    activeDays: _activeDaysThisWeek(profile.dailyCompletions),
                    onRefresh: () => _refreshInsight(profile),
                  ).animate().fadeIn(duration: 400.ms),
                  if (profile.blueprintCompleted) ...[
                    const SizedBox(height: AppSpacing.xl),
                    _BlueprintGrowthSection(profile: profile),
                  ],
                  if (profile.weeklyInsightHistory.isNotEmpty) ...[
                    const SizedBox(height: AppSpacing.xl),
                    SectionHeader(title: AppStrings.weeklyInsightPastReviews),
                    const SizedBox(height: AppSpacing.md),
                    ...profile.weeklyInsightHistory.asMap().entries.map((e) {
                      final item = e.value;
                      return Padding(
                        padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                        child: _PastReviewTile(
                          label: _formatWeekEnding(item.weekEnding),
                          onTap: () => _showPastInsightSheet(item),
                        ).animate().fadeIn(
                              delay: Duration(milliseconds: e.key * 40),
                            ),
                      );
                    }),
                  ],
                  if (profile.goals.any((g) => g.status == 'completed')) ...[
                    const SizedBox(height: AppSpacing.xl),
                    Text(AppStrings.milestones,
                        style: AppTextStyles.headlineSmall),
                    const SizedBox(height: AppSpacing.md),
                    _MilestoneTimeline(profile: profile),
                  ],
                ],
              ),
            ),
    );
  }
}

class _PastReviewTile extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const _PastReviewTile({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surfaceElevated,
      borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.md,
          ),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: AppColors.primaryContainer,
                  borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                ),
                child: const Icon(
                  Icons.history_rounded,
                  color: AppColors.primary,
                  size: 18,
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      AppStrings.weeklyInsightWeekEnding,
                      style: AppTextStyles.labelSmall,
                    ),
                    Text(label, style: AppTextStyles.labelLarge),
                  ],
                ),
              ),
              const Icon(
                Icons.chevron_right_rounded,
                color: AppColors.textMuted,
                size: 20,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ProgressSkeleton extends StatelessWidget {
  const _ProgressSkeleton();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.screenPaddingH,
        AppSpacing.md,
        AppSpacing.screenPaddingH,
        100,
      ),
      children: [
        Row(
          children: [
            Expanded(child: ShimmerCard(height: 100)),
            const SizedBox(width: AppSpacing.md),
            Expanded(child: ShimmerCard(height: 100)),
          ],
        ),
        const SizedBox(height: AppSpacing.xl),
        ShimmerBox(width: 160, height: 20, borderRadius: AppSpacing.radiusSm),
        const SizedBox(height: AppSpacing.md),
        const ShimmerCard(height: 160),
        const SizedBox(height: AppSpacing.xl),
        ShimmerBox(width: 160, height: 20, borderRadius: AppSpacing.radiusSm),
        const SizedBox(height: AppSpacing.md),
        const ShimmerList(count: 7, itemHeight: 32),
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 28),
          const SizedBox(height: AppSpacing.sm),
          Text(value, style: AppTextStyles.statNumber.copyWith(color: color)),
          Text(label, style: AppTextStyles.labelSmall),
        ],
      ),
    );
  }
}

class _ActivityHeatmap extends StatelessWidget {
  final List<DailyCompletion> completions;

  const _ActivityHeatmap({required this.completions});

  @override
  Widget build(BuildContext context) {
    final days = AppDateUtils.lastNDays(56);

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
              final dateStr =
                  '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
              final completion = completions.firstWhere(
                (c) => c.date == dateStr,
                orElse: () => DailyCompletion(date: dateStr),
              );
              final percent = completion.completionPercent;
              final color = percent == 0
                  ? AppColors.surfaceHighest
                  : percent < 0.5
                      ? AppColors.primary.withValues(alpha: 0.3)
                      : percent < 1.0
                          ? AppColors.primary.withValues(alpha: 0.6)
                          : AppColors.primary;

              return Tooltip(
                message:
                    '${AppDateUtils.formatDate(d)}: ${(percent * 100).toStringAsFixed(0)}%',
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
                      borderRadius: BorderRadius.circular(2))),
              const SizedBox(width: 4),
              Text('0%', style: AppTextStyles.labelSmall),
              const SizedBox(width: AppSpacing.sm),
              Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.4),
                      borderRadius: BorderRadius.circular(2))),
              const SizedBox(width: 4),
              Text('50%', style: AppTextStyles.labelSmall),
              const SizedBox(width: AppSpacing.sm),
              Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                      color: AppColors.primary,
                      borderRadius: BorderRadius.circular(2))),
              const SizedBox(width: 4),
              Text('100%', style: AppTextStyles.labelSmall),
            ],
          ),
        ],
      ),
    );
  }
}

class _WeeklyBreakdown extends StatelessWidget {
  final List<DailyCompletion> completions;

  const _WeeklyBreakdown({required this.completions});

  @override
  Widget build(BuildContext context) {
    final days = AppDateUtils.lastNDays(7);

    return Column(
      children: days.asMap().entries.map((e) {
        final d = e.value;
        final dateStr =
            '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
        final completion = completions.firstWhere(
          (c) => c.date == dateStr,
          orElse: () => DailyCompletion(date: dateStr),
        );
        final isToday = AppDateUtils.isSameDay(d, DateTime.now());

        return Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.sm),
          child: Row(
            children: [
              SizedBox(
                width: 36,
                child: Text(
                  AppDateUtils.weekdayShort(d),
                  style: AppTextStyles.labelSmall.copyWith(
                    color: isToday ? AppColors.primary : AppColors.textSecondary,
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: completion.completionPercent,
                    backgroundColor: AppColors.border,
                    valueColor: AlwaysStoppedAnimation(
                      isToday
                          ? AppColors.primary
                          : AppColors.primary.withValues(alpha: 0.6),
                    ),
                    minHeight: 20,
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              SizedBox(
                width: 36,
                child: Text(
                  '${(completion.completionPercent * 100).toStringAsFixed(0)}%',
                  style: AppTextStyles.labelSmall
                      .copyWith(color: AppColors.textSecondary),
                  textAlign: TextAlign.end,
                ),
              ),
              if (completion.isPerfectDay)
                const Padding(
                  padding: EdgeInsets.only(left: AppSpacing.xs),
                  child: Icon(Icons.star_rounded,
                      color: AppColors.warning, size: 16),
                ),
            ],
          ).animate().fadeIn(delay: Duration(milliseconds: e.key * 50)),
        );
      }).toList(),
    );
  }
}

class _BlueprintGrowthSection extends StatelessWidget {
  final UserProfile profile;

  const _BlueprintGrowthSection({required this.profile});

  @override
  Widget build(BuildContext context) {
    final current = profile.mindsetBlueprint;
    final baseline = profile.originalMindsetBaseline;
    final (trait, delta) = blueprintLargestShift(current, baseline);
    final hasShift = delta != '+0.0' && delta != '0.0' && delta != '-0.0';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(AppStrings.blueprintGrowthTitle, style: AppTextStyles.headlineSmall),
        const SizedBox(height: AppSpacing.md),
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (hasShift)
                Text(
                  AppStrings.blueprintGrowthSinceBaseline(trait, delta),
                  style: AppTextStyles.bodyMedium.copyWith(height: 1.5),
                )
              else
                Text(
                  AppStrings.blueprintSnapshotPrompt,
                  style: AppTextStyles.bodyMedium.copyWith(
                    color: AppColors.textSecondary,
                    height: 1.5,
                  ),
                ),
              const SizedBox(height: AppSpacing.md),
              AppSecondaryButton(
                label: AppStrings.blueprintTakeSnapshot,
                onPressed: () => context.push('/blueprint-snapshot'),
                icon: Icons.camera_alt_rounded,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _WeeklyInsightsSection extends StatelessWidget {
  final WeeklyInsight? insight;
  final bool isLoading;
  final int activeDays;
  final VoidCallback onRefresh;

  const _WeeklyInsightsSection({
    required this.insight,
    required this.isLoading,
    required this.activeDays,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(AppStrings.weeklyInsight,
                  style: AppTextStyles.headlineSmall),
            ),
            if (insight != null && insight!.isUnread)
              Container(
                margin: const EdgeInsets.only(right: AppSpacing.sm),
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.sm,
                  vertical: 2,
                ),
                decoration: BoxDecoration(
                  color: AppColors.primaryContainer,
                  borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
                ),
                child: Text(
                  'New',
                  style: AppTextStyles.labelSmall
                      .copyWith(color: AppColors.primary),
                ),
              ),
            IconButton(
              onPressed: isLoading ? null : onRefresh,
              icon: isLoading
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                          color: AppColors.primary, strokeWidth: 2),
                    )
                  : const Icon(Icons.refresh_rounded,
                      color: AppColors.primary, size: 20),
              tooltip: 'Refresh insight',
              padding: EdgeInsets.zero,
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        if (insight == null && !isLoading)
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  AppStrings.weeklyInsightUnlockHint,
                  style: AppTextStyles.bodyMedium
                      .copyWith(color: AppColors.textSecondary),
                ),
                if (activeDays >= 3) ...[
                  const SizedBox(height: AppSpacing.md),
                  GestureDetector(
                    onTap: onRefresh,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.auto_awesome_rounded,
                            color: AppColors.primary, size: 18),
                        const SizedBox(width: AppSpacing.sm),
                        Text(
                          AppStrings.weeklyInsightGenerate,
                          style: AppTextStyles.bodyMedium
                              .copyWith(color: AppColors.primary),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          )
        else if (insight != null)
          WeeklyInsightCard(insight: insight!),
      ],
    );
  }
}

class _MilestoneTimeline extends StatelessWidget {
  final UserProfile profile;

  const _MilestoneTimeline({required this.profile});

  @override
  Widget build(BuildContext context) {
    final completed =
        profile.goals.where((g) => g.status == 'completed').toList();
    completed.sort((a, b) =>
        (b.completedAt ?? DateTime.now()).compareTo(a.completedAt ?? DateTime.now()));

    return Column(
      children: completed.asMap().entries.map((e) {
        final goal = e.value;
        return Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.md),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Column(
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: const BoxDecoration(
                      color: AppColors.successContainer,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.emoji_events_rounded,
                        color: AppColors.success, size: 16),
                  ),
                  if (e.key < completed.length - 1)
                    Container(width: 2, height: 40, color: AppColors.border),
                ],
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(goal.title, style: AppTextStyles.labelLarge),
                    if (goal.completedAt != null)
                      Text(
                        AppDateUtils.formatDate(goal.completedAt!),
                        style: AppTextStyles.labelSmall,
                      ),
                  ],
                ),
              ),
            ],
          ).animate().fadeIn(delay: Duration(milliseconds: e.key * 80)),
        );
      }).toList(),
    );
  }
}
