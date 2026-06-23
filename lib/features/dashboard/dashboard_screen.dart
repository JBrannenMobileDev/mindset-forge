import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_spacing.dart';
import '../../core/constants/app_text_styles.dart';
import '../../core/widgets/shimmer_widget.dart';
import '../../core/widgets/responsive_layout.dart';
import '../../core/widgets/empty_state.dart';
import '../../providers/auth_provider.dart';
import 'widgets/dashboard_header.dart';
import 'widgets/daily_wins_tracker.dart';
import 'widgets/focus_mode_banner.dart';
import 'widgets/alignment_score_widget.dart';
import 'widgets/weekly_chart_widget.dart';
import 'widgets/getting_started_checklist.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileAsync = ref.watch(currentUserProfileProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        bottom: false,
        child: profileAsync.when(
          loading: () => const _DashboardSkeleton(),
          error: (e, _) => ErrorState(
            message: 'Failed to load dashboard. Please restart the app.',
            onRetry: () => ref.invalidate(currentUserProfileProvider),
          ),
          data: (profile) {
            if (profile == null) {
              return const _DashboardSkeleton();
            }

            final hasHadPerfectDay = profile.dailyCompletions.any((c) => c.isPerfectDay);
            final deepDiveComplete = profile.deepDive.isFullyComplete;

            return ResponsiveLayout(
              maxWidth: 680,
              child: CustomScrollView(
                physics: const BouncingScrollPhysics(),
                slivers: [
                  // ── Header ──────────────────────────────────────────
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.only(
                        left: AppSpacing.screenPaddingH,
                        right: AppSpacing.screenPaddingH,
                        top: AppSpacing.xxl + AppSpacing.md,
                      ),
                      child: DashboardHeader(profile: profile),
                    ),
                  ),

                  // ── Current Focus banner (only after committing) ─────
                  SliverToBoxAdapter(
                    child: FocusModeBanner(profile: profile),
                  ),

                  // ── Getting Started (shown until first perfect day) ──
                  if (!hasHadPerfectDay)
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(
                          AppSpacing.screenPaddingH,
                          AppSpacing.sectionGap,
                          AppSpacing.screenPaddingH,
                          0,
                        ),
                        child: GettingStartedChecklist(profile: profile),
                      ),
                    ),

                  // ── Daily Wins Tracker (hero) ─────────────────────────
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(
                        AppSpacing.screenPaddingH,
                        AppSpacing.sectionGap,
                        AppSpacing.screenPaddingH,
                        0,
                      ),
                      child: DailyWinsTracker(profile: profile),
                    ),
                  ),

                  // ── Deep Dive nudge (until all 5 modules complete) ───
                  if (!deepDiveComplete)
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(
                          AppSpacing.screenPaddingH,
                          AppSpacing.sectionGap,
                          AppSpacing.screenPaddingH,
                          0,
                        ),
                        child: _DeepDiveNudgeCard(),
                      ),
                    ),

                  // ── Manifestation Alignment ──────────────────────────
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(
                        AppSpacing.screenPaddingH,
                        AppSpacing.sectionGap,
                        AppSpacing.screenPaddingH,
                        0,
                      ),
                      child: AlignmentScoreWidget(profile: profile),
                    ),
                  ),

                  // ── Weekly Activity Chart ─────────────────────────────
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(
                        AppSpacing.screenPaddingH,
                        AppSpacing.sectionGap,
                        AppSpacing.screenPaddingH,
                        0,
                      ),
                      child: WeeklyChartWidget(profile: profile),
                    ),
                  ),

                  const SliverToBoxAdapter(
                    child: SizedBox(height: 100),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class _DeepDiveNudgeCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => context.push('/deep-dive'),
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.lg),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              AppColors.secondary.withValues(alpha: 0.15),
              AppColors.primary.withValues(alpha: 0.10),
            ],
          ),
          borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
          border: Border.all(color: AppColors.secondary.withValues(alpha: 0.3)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(AppSpacing.sm),
              decoration: BoxDecoration(
                color: AppColors.secondary.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
              ),
              child: const Icon(Icons.psychology_alt_rounded,
                  color: AppColors.secondary, size: 24),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Complete Your Deep Dive', style: AppTextStyles.labelLarge),
                  const SizedBox(height: 2),
                  Text(
                    'Five modules to unlock your deepest patterns and tune your coach.',
                    style: AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondary),
                  ),
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            const Icon(Icons.arrow_forward_ios_rounded,
                color: AppColors.textMuted, size: 14),
          ],
        ),
      ).animate().fadeIn(duration: 400.ms),
    );
  }
}

class _DashboardSkeleton extends StatelessWidget {
  const _DashboardSkeleton();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.screenPaddingH,
        AppSpacing.xxl + AppSpacing.md,
        AppSpacing.screenPaddingH,
        100,
      ),
      children: [
        ShimmerBox(width: 200, height: 24, borderRadius: AppSpacing.radiusSm),
        const SizedBox(height: AppSpacing.sm),
        ShimmerBox(width: 140, height: 16, borderRadius: AppSpacing.radiusSm),
        const SizedBox(height: AppSpacing.xl),
        const ShimmerCard(height: 80),
        const SizedBox(height: AppSpacing.lg),
        const ShimmerCard(height: 100),
        const SizedBox(height: AppSpacing.lg),
        const ShimmerCard(height: 260),
      ],
    );
  }
}
