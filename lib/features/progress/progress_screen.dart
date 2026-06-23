import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_spacing.dart';
import '../../core/constants/app_text_styles.dart';
import '../../core/constants/app_strings.dart';
import '../../core/widgets/app_card.dart';
import '../../core/widgets/responsive_layout.dart';
import '../../core/widgets/shimmer_widget.dart';
import '../../core/utils/app_date_utils.dart';
import '../../providers/auth_provider.dart';
import '../../providers/claude_provider.dart';
import '../../providers/streak_provider.dart';
import '../../models/daily_completion.dart';

class ProgressScreen extends ConsumerStatefulWidget {
  const ProgressScreen({super.key});

  @override
  ConsumerState<ProgressScreen> createState() => _ProgressScreenState();
}

class _ProgressScreenState extends ConsumerState<ProgressScreen> {
  Map<String, String>? _weeklyInsight;
  bool _loadingInsight = false;

  Future<void> _loadInsight() async {
    final profile = ref.read(currentUserProfileProvider).valueOrNull;
    if (profile == null) return;
    setState(() => _loadingInsight = true);
    try {
      final insight = await ref
          .read(claudeServiceProvider)
          .generateStructuredWeeklyInsight(profile);
      if (mounted) setState(() => _weeklyInsight = insight);
    } catch (_) {
      // silently fail
    } finally {
      if (mounted) setState(() => _loadingInsight = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final profile = ref.watch(currentUserProfileProvider).valueOrNull;
    final streak = ref.watch(streakProvider);
    final perfectDays = ref.watch(perfectDayCountProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        title: Text(AppStrings.progress, style: AppTextStyles.headlineMedium),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () => Navigator.pop(context),
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
                  insight: _weeklyInsight,
                  isLoading: _loadingInsight,
                  onRefresh: _loadInsight,
                ).animate().fadeIn(duration: 400.ms),
                if (profile.goals.any((g) => g.status == 'completed')) ...[
                  const SizedBox(height: AppSpacing.xl),
                  Text(AppStrings.milestones, style: AppTextStyles.headlineSmall),
                  const SizedBox(height: AppSpacing.md),
                  _MilestoneTimeline(profile: profile),
                ],
              ],
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
              final dateStr = '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
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
                message: '${AppDateUtils.formatDate(d)}: ${(percent * 100).toStringAsFixed(0)}%',
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
              Container(width: 10, height: 10, decoration: BoxDecoration(color: AppColors.surfaceHighest, borderRadius: BorderRadius.circular(2))),
              const SizedBox(width: 4),
              Text('0%', style: AppTextStyles.labelSmall),
              const SizedBox(width: AppSpacing.sm),
              Container(width: 10, height: 10, decoration: BoxDecoration(color: AppColors.primary.withValues(alpha: 0.4), borderRadius: BorderRadius.circular(2))),
              const SizedBox(width: 4),
              Text('50%', style: AppTextStyles.labelSmall),
              const SizedBox(width: AppSpacing.sm),
              Container(width: 10, height: 10, decoration: BoxDecoration(color: AppColors.primary, borderRadius: BorderRadius.circular(2))),
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
        final dateStr = '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
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
                      isToday ? AppColors.primary : AppColors.primary.withValues(alpha: 0.6),
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
                  style: AppTextStyles.labelSmall.copyWith(color: AppColors.textSecondary),
                  textAlign: TextAlign.end,
                ),
              ),
              if (completion.isPerfectDay)
                const Padding(
                  padding: EdgeInsets.only(left: AppSpacing.xs),
                  child: Icon(Icons.star_rounded, color: AppColors.warning, size: 16),
                ),
            ],
          ).animate().fadeIn(delay: Duration(milliseconds: e.key * 50)),
        );
      }).toList(),
    );
  }
}

class _WeeklyInsightsSection extends StatelessWidget {
  final Map<String, String>? insight;
  final bool isLoading;
  final VoidCallback onRefresh;

  const _WeeklyInsightsSection({
    required this.insight,
    required this.isLoading,
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
              child: Text('Weekly Insight', style: AppTextStyles.headlineSmall),
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
          GestureDetector(
            onTap: onRefresh,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(AppSpacing.lg),
              decoration: BoxDecoration(
                color: AppColors.surfaceElevated,
                borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
                border: Border.all(
                    color: AppColors.primary.withValues(alpha: 0.25)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.auto_awesome_rounded,
                      color: AppColors.primary, size: 18),
                  const SizedBox(width: AppSpacing.sm),
                  Text('Generate weekly insight',
                      style: AppTextStyles.bodyMedium
                          .copyWith(color: AppColors.primary)),
                ],
              ),
            ),
          )
        else if (insight != null)
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _InsightRow(
                  icon: Icons.insights_rounded,
                  color: AppColors.primary,
                  label: 'Your Pattern',
                  text: insight!['pattern'] ?? '',
                ),
                const SizedBox(height: AppSpacing.md),
                _InsightRow(
                  icon: Icons.emoji_events_rounded,
                  color: AppColors.warning,
                  label: 'Breakthrough',
                  text: insight!['breakthrough'] ?? '',
                ),
                const SizedBox(height: AppSpacing.md),
                _InsightRow(
                  icon: Icons.bolt_rounded,
                  color: AppColors.secondary,
                  label: 'Next Week Focus',
                  text: insight!['focus'] ?? '',
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _InsightRow extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String label;
  final String text;

  const _InsightRow({
    required this.icon,
    required this.color,
    required this.label,
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
          ),
          child: Icon(icon, color: color, size: 16),
        ),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label,
                  style: AppTextStyles.labelSmall
                      .copyWith(color: AppColors.textMuted)),
              const SizedBox(height: 2),
              Text(text,
                  style: AppTextStyles.bodyMedium.copyWith(height: 1.5)),
            ],
          ),
        ),
      ],
    );
  }
}

class _MilestoneTimeline extends StatelessWidget {
  final dynamic profile;

  const _MilestoneTimeline({required this.profile});

  @override
  Widget build(BuildContext context) {
    final completed = (profile.goals as List).where((g) => g.status == 'completed').toList();
    completed.sort((a, b) => (b.completedAt ?? DateTime.now()).compareTo(a.completedAt ?? DateTime.now()));

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
                    child: const Icon(Icons.emoji_events_rounded, color: AppColors.success, size: 16),
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
                    Text(goal.title as String, style: AppTextStyles.labelLarge),
                    if (goal.completedAt != null)
                      Text(
                        AppDateUtils.formatDate(goal.completedAt as DateTime),
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
