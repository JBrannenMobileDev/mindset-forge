import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_spacing.dart';
import '../../core/constants/app_strings.dart';
import '../../core/constants/app_text_styles.dart';
import '../../core/widgets/shimmer_widget.dart';
import '../../core/widgets/responsive_layout.dart';
import '../../core/widgets/empty_state.dart';
import '../../core/utils/breakpoints.dart';
import '../../models/daily_completion.dart';
import '../../models/user_profile.dart';
import '../../providers/auth_provider.dart';
import '../../providers/daily_completion_provider.dart';
import '../../providers/invite_prompt_provider.dart';
import 'widgets/dashboard_header.dart';
import 'widgets/today_hero_card.dart';
import 'widgets/daily_routine_card.dart';
import 'widgets/daily_habits_card.dart';
import 'widgets/progress_overview_card.dart';
import 'widgets/getting_started_checklist.dart';
import 'widgets/accountability_banner.dart';

class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  /// Fires an invite prompt after the current frame; the controller dedupes and
  /// enforces the "don't nag" rules, so callers only detect the moment.
  void _firePrompt(InviteTrigger trigger) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref.read(invitePromptProvider).maybeShow(context, trigger);
    });
  }

  void _onPerfectDay(DailyCompletion? prev, DailyCompletion next) {
    // Only on a genuine in-session false→true transition (mirrors the
    // confetti logic in TodayHeroCard), not on initial load.
    if (prev != null && !prev.isPerfectDay && next.isPerfectDay) {
      _firePrompt(InviteTrigger.perfectDay);
    }
  }

  void _onStreakChanged(UserProfile? prev, UserProfile? next) {
    if (prev == null || next == null) return;
    final before = prev.currentStreak;
    final after = next.currentStreak;
    if (after <= before) return;

    InviteTrigger? trigger;
    if (before < 30 && after >= 30) {
      trigger = InviteTrigger.streak30;
    } else if (before < 7 && after >= 7) {
      trigger = InviteTrigger.streak7;
    } else if (before < 3 && after >= 3) {
      trigger = InviteTrigger.streak3;
    }
    if (trigger != null) _firePrompt(trigger);
  }

  @override
  Widget build(BuildContext context) {
    final profileAsync = ref.watch(currentUserProfileProvider);

    // High-intent invite moments — one prompt per visit; controller dedupes.
    ref.listen<DailyCompletion>(dailyCompletionProvider, _onPerfectDay);
    ref.listen<AsyncValue<UserProfile?>>(currentUserProfileProvider,
        (prev, next) {
      _onStreakChanged(prev?.valueOrNull, next.valueOrNull);
    });

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

            final deepDiveComplete = profile.deepDive.isFullyComplete;
            // Whether to surface the accountability banner (partner support card,
            // or an invite nudge for settled-in subscribers without a partner).
            final hasActivePartner = profile.accountabilityRelationships
                .any((r) => r.type == 'primary' && r.status == 'active');
            final inviteSnoozed = profile.invitePromptSnoozedUntil != null &&
                DateTime.now().isBefore(profile.invitePromptSnoozedUntil!);
            final showInviteNudge = !hasActivePartner &&
                !profile.invitePromptsDismissed &&
                !inviteSnoozed &&
                DateTime.now().difference(profile.createdAt).inDays >= 3;
            final showAccountabilityBanner =
                profile.isPartnerAccount || showInviteNudge;
            final allOnboardingDone = profile.identityStatement.isNotEmpty &&
                profile.goals.isNotEmpty &&
                profile.dailyCompletions.any((c) => c.journalCompleted) &&
                profile.dailyCompletions.any((c) => c.chatCompleted) &&
                profile.deepDive.modules.isNotEmpty;

            final showDeepDiveNudge =
                profile.blueprintCompleted && !deepDiveComplete;

            return LayoutBuilder(
              builder: (context, constraints) {
                if (Breakpoints.isWideWidth(constraints.maxWidth)) {
                  return _DashboardDesktopBody(
                    profile: profile,
                    showAccountabilityBanner: showAccountabilityBanner,
                    showGettingStarted: !allOnboardingDone,
                    showDeepDiveNudge: showDeepDiveNudge,
                  );
                }
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
                            top: AppSpacing.md,
                          ),
                          child: DashboardHeader(profile: profile),
                        ),
                      ),

                      // ── Accountability (partner support banner / invite CTA) ──
                      if (showAccountabilityBanner)
                        SliverToBoxAdapter(
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(
                              AppSpacing.screenPaddingH,
                              AppSpacing.lg,
                              AppSpacing.screenPaddingH,
                              0,
                            ),
                            child: AccountabilityBanner(profile: profile),
                          ),
                        ),

                      // ── Getting Started (shown until all onboarding steps done) ──
                      if (!allOnboardingDone)
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

                      // ── GROUP: Today (time-aware single hero) ────────────
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.only(top: AppSpacing.xxl),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const _GroupLabel(AppStrings.groupToday),
                              const SizedBox(height: AppSpacing.md),
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: AppSpacing.screenPaddingH,
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    TodayHeroCard(profile: profile),
                                    const SizedBox(height: AppSpacing.lg),
                                    DailyRoutineCard(profile: profile),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                      // ── GROUP: Habits (clearly separated daytime work) ───
                      const SliverToBoxAdapter(
                        child: Padding(
                          padding: EdgeInsets.only(top: AppSpacing.xxl),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _GroupLabel(AppStrings.groupHabits),
                              SizedBox(height: AppSpacing.md),
                              Padding(
                                padding: EdgeInsets.symmetric(
                                  horizontal: AppSpacing.screenPaddingH,
                                ),
                                child: DailyHabitsCard(),
                              ),
                            ],
                          ),
                        ),
                      ),

                      // ── GROUP: Your Progress (alignment | activity) ──────
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.only(top: AppSpacing.xxl),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const _GroupLabel(AppStrings.groupProgress),
                              const SizedBox(height: AppSpacing.md),
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: AppSpacing.screenPaddingH,
                                ),
                                child: ProgressOverviewCard(profile: profile),
                              ),
                            ],
                          ),
                        ),
                      ),

                      // ── Deep Dive nudge (after Blueprint, until all 5 modules complete) ───
                      if (profile.blueprintCompleted && !deepDiveComplete)
                        SliverToBoxAdapter(
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(
                              AppSpacing.screenPaddingH,
                              AppSpacing.xxl,
                              AppSpacing.screenPaddingH,
                              0,
                            ),
                            child: _DeepDiveNudgeCard(),
                          ),
                        ),

                      // Extra bottom space so the final card clears the floating
                      // nav and is comfortably scrollable into view.
                      const SliverToBoxAdapter(
                        child: SizedBox(height: 140),
                      ),
                    ],
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}

/// Wide-screen dashboard: a full-width header above two independent columns.
/// Primary (left) carries today's hero + habits; secondary (right) carries
/// onboarding/progress context. Falls back to a single column automatically
/// via [ResponsiveTwoColumn] if the content area is narrow.
class _DashboardDesktopBody extends StatelessWidget {
  final UserProfile profile;
  final bool showAccountabilityBanner;
  final bool showGettingStarted;
  final bool showDeepDiveNudge;

  const _DashboardDesktopBody({
    required this.profile,
    required this.showAccountabilityBanner,
    required this.showGettingStarted,
    required this.showDeepDiveNudge,
  });

  @override
  Widget build(BuildContext context) {
    final leftColumn = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (showAccountabilityBanner) ...[
          AccountabilityBanner(profile: profile),
          const SizedBox(height: AppSpacing.sectionGap),
        ],
        const _DesktopSectionLabel(AppStrings.groupToday),
        const SizedBox(height: AppSpacing.md),
        TodayHeroCard(profile: profile),
        const SizedBox(height: AppSpacing.lg),
        DailyRoutineCard(profile: profile),
        const SizedBox(height: AppSpacing.sectionGap),
        const _DesktopSectionLabel(AppStrings.groupHabits),
        const SizedBox(height: AppSpacing.md),
        const DailyHabitsCard(),
        if (showDeepDiveNudge) ...[
          const SizedBox(height: AppSpacing.sectionGap),
          _DeepDiveNudgeCard(),
        ],
      ],
    );

    final rightColumn = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (showGettingStarted) ...[
          GettingStartedChecklist(profile: profile),
          const SizedBox(height: AppSpacing.sectionGap),
        ],
        const _DesktopSectionLabel(AppStrings.groupProgress),
        const SizedBox(height: AppSpacing.md),
        ProgressOverviewCard(profile: profile),
      ],
    );

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      child: WebContentFrame(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: AppSpacing.xl),
            DashboardHeader(profile: profile),
            const SizedBox(height: AppSpacing.sectionGap),
            ResponsiveTwoColumn(
              primary: leftColumn,
              secondary: rightColumn,
            ),
            const SizedBox(height: AppSpacing.xxl),
          ],
        ),
      ),
    );
  }
}

/// Section label for the desktop columns — same intent as the mobile
/// `_GroupLabel` but without the screen-edge padding (the column already
/// supplies its own gutters).
class _DesktopSectionLabel extends StatelessWidget {
  final String label;

  const _DesktopSectionLabel(this.label);

  @override
  Widget build(BuildContext context) {
    return Text(
      label.toUpperCase(),
      style: AppTextStyles.overline.copyWith(
        color: AppColors.textMuted,
        letterSpacing: 1.2,
      ),
    );
  }
}

/// Lightweight section-group label (e.g. "TODAY", "YOUR PROGRESS") used to
/// chunk the dashboard into calm, related groups.
class _GroupLabel extends StatelessWidget {
  final String label;

  const _GroupLabel(this.label);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.screenPaddingH,
      ),
      child: Text(
        label.toUpperCase(),
        style: AppTextStyles.overline.copyWith(
          color: AppColors.textMuted,
          letterSpacing: 1.2,
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
                  Text('Go Deeper with Your Coach',
                      style: AppTextStyles.labelLarge),
                  const SizedBox(height: 2),
                  Text(
                    'Five modules to go deeper on your Blueprint and give your coach your full story.',
                    style: AppTextStyles.bodySmall
                        .copyWith(color: AppColors.textSecondary),
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
        AppSpacing.md,
        AppSpacing.screenPaddingH,
        100,
      ),
      children: const [
        ShimmerBox(width: 200, height: 24, borderRadius: AppSpacing.radiusSm),
        SizedBox(height: AppSpacing.sm),
        ShimmerBox(width: 140, height: 16, borderRadius: AppSpacing.radiusSm),
        SizedBox(height: AppSpacing.xl),
        ShimmerCard(height: 80),
        SizedBox(height: AppSpacing.lg),
        ShimmerCard(height: 100),
        SizedBox(height: AppSpacing.lg),
        ShimmerCard(height: 260),
      ],
    );
  }
}
