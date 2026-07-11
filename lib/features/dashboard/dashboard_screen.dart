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
import '../../core/widgets/hover_builder.dart';
import '../../core/utils/breakpoints.dart';
import '../../core/utils/app_date_utils.dart';
import '../../models/daily_completion.dart';
import '../../models/user_profile.dart';
import '../../providers/auth_provider.dart';
import '../../providers/daily_completion_provider.dart';
import '../../providers/invite_prompt_provider.dart';
import 'widgets/dashboard_header.dart';
import 'widgets/today_hero_card.dart';
import 'widgets/daily_wins_shared.dart';
import 'widgets/plan_day_bottom_sheet.dart';
import 'widgets/evening_focus_card.dart';
import 'widgets/daily_routine_card.dart';
import 'widgets/daily_habits_card.dart';
import 'widgets/progress_overview_card.dart';
import 'widgets/getting_started_checklist.dart';
import 'widgets/accountability_banner.dart';
import 'widgets/weekly_insight_banner.dart';
import 'widgets/coach_callback_banner.dart';
import 'widgets/blueprint_evolution_banner.dart';

class DashboardScreen extends ConsumerStatefulWidget {
  /// When true (deep link `mindsetforge://focus` → `/dashboard?focus=plan`,
  /// fired by the home-screen widget / watch), the dashboard opens the Plan Day
  /// sheet on load if today's #1 focus hasn't been set yet.
  final bool openPlanSheet;

  /// A routine win field from `mindsetforge://action/<field>` →
  /// `/dashboard?action=<field>` (the widget surfaced this as the next action).
  /// On load the dashboard fires the matching navigation via `winNavCallback`.
  final String? actionField;

  const DashboardScreen({
    super.key,
    this.openPlanSheet = false,
    this.actionField,
  });

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  /// Guards against re-scheduling the deep-link action on every rebuild while
  /// the query param is still present. Reset once the param is consumed.
  bool _deepLinkScheduled = false;

  bool get _hasDeepLinkIntent =>
      widget.openPlanSheet ||
      (widget.actionField != null && widget.actionField!.isNotEmpty);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _tryDeepLink());
  }

  @override
  void didUpdateWidget(DashboardScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.openPlanSheet != widget.openPlanSheet ||
        oldWidget.actionField != widget.actionField) {
      _deepLinkScheduled = false;
      _tryDeepLink();
    }
  }

  /// Runs the deep-link action once profile data is available.
  void _tryDeepLink() {
    if (!_hasDeepLinkIntent) return;
    final profile = ref.read(currentUserProfileProvider).valueOrNull;
    if (profile != null) _handleActionDeepLink(profile);
  }

  /// Acts on the widget/watch deep links: `?focus=plan` opens the Plan Day
  /// sheet when no focus is set; `?action=<field>` fires the matching routine
  /// navigation via the shared `winNavCallback`. The query param is consumed so
  /// the action can't retrigger on rebuild.
  void _handleActionDeepLink(UserProfile profile) {
    final field = widget.actionField;
    final wantsPlan = widget.openPlanSheet;
    if (!wantsPlan && (field == null || field.isEmpty)) {
      _deepLinkScheduled = false;
      return;
    }
    if (_deepLinkScheduled) return;
    _deepLinkScheduled = true;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      // Drop the deep-link param so the action doesn't refire on rebuild.
      context.go('/dashboard');

      if (field != null && field.isNotEmpty) {
        winNavCallback(
          context: context,
          ref: ref,
          profile: profile,
          field: field,
        )();
        return;
      }

      // `?focus=plan` → open Plan Day only when today's focus isn't set yet.
      final hasFocusToday = profile.dailyFocusAction.isNotEmpty &&
          profile.dailyFocusActionDate ==
              AppDateUtils.todayStringWithGracePeriod();
      if (hasFocusToday) return;
      showPlanDaySheet(context, ref, profile);
    });
  }

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
    if (before < 100 && after >= 100) {
      trigger = InviteTrigger.streak100;
    } else if (before < 60 && after >= 60) {
      trigger = InviteTrigger.streak60;
    } else if (before < 30 && after >= 30) {
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
      next.whenData((profile) {
        if (profile != null) _tryDeepLink();
      });
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

            // Evening "last call": the evening routine owns the hero after 5 PM,
            // so surface an incomplete #1 Focus as its own card beneath the hero
            // rather than letting it slip out of view.
            final hasFocusToday = profile.dailyFocusAction.isNotEmpty &&
                profile.dailyFocusActionDate ==
                    AppDateUtils.todayStringWithGracePeriod();
            final showOpenFocusCard =
                AppDateUtils.sessionPeriod() == 'evening' &&
                    hasFocusToday &&
                    !profile.isDailyFocusComplete;

            // Single source of truth: both layouts render from this list, so a
            // card added once appears on mobile and web without drift.
            final sections = _dashboardSections(
              profile: profile,
              showAccountabilityBanner: showAccountabilityBanner,
              showGettingStarted: !allOnboardingDone,
              showOpenFocusCard: showOpenFocusCard,
              showDeepDiveNudge: showDeepDiveNudge,
            );

            // Web small screens never reach here (the shell shows the download
            // gate), so the mobile branch below is native-only. Desktop turns on
            // exactly when the sidebar appears, keyed off the true viewport.
            if (Breakpoints.isWide(context)) {
              return _DashboardDesktopBody(
                profile: profile,
                sections: sections,
              );
            }
            return ResponsiveLayout(
              maxWidth: 680,
              child: CustomScrollView(
                physics: const BouncingScrollPhysics(),
                slivers: _dashboardMobileSlivers(context, profile, sections),
              ),
            );
          },
        ),
      ),
    );
  }
}

/// Single source of truth for the dashboard's content cards. Both the mobile
/// (`CustomScrollView`) and desktop (`_DashboardDesktopBody`) layouts render
/// from the same ordered, grouped list, so a card added here shows up in both
/// and the two can never drift. Header/streak stay layout-specific by design.
enum _DashGroup { top, today, habits, progress }

class _DashSection {
  final _DashGroup group;
  final WidgetBuilder build;
  const _DashSection(this.group, this.build);
}

List<_DashSection> _dashboardSections({
  required UserProfile profile,
  required bool showAccountabilityBanner,
  required bool showGettingStarted,
  required bool showOpenFocusCard,
  required bool showDeepDiveNudge,
}) =>
    [
      if (profile.hasUnreadWeeklyInsight)
        _DashSection(
            _DashGroup.top, (_) => WeeklyInsightBanner(profile: profile)),
      if (profile.hasBlueprintEvolutionReady)
        _DashSection(_DashGroup.top,
            (_) => BlueprintEvolutionBanner(profile: profile)),
      if (profile.hasPendingCallback && !profile.hasBlueprintEvolutionReady)
        _DashSection(
            _DashGroup.top, (_) => CoachCallbackBanner(profile: profile)),
      if (showAccountabilityBanner)
        _DashSection(
            _DashGroup.top, (_) => AccountabilityBanner(profile: profile)),
      if (showGettingStarted)
        _DashSection(
            _DashGroup.top, (_) => GettingStartedChecklist(profile: profile)),
      _DashSection(_DashGroup.today, (_) => TodayHeroCard(profile: profile)),
      if (showOpenFocusCard)
        _DashSection(
            _DashGroup.today, (_) => EveningFocusCard(profile: profile)),
      _DashSection(_DashGroup.today, (_) => DailyRoutineCard(profile: profile)),
      _DashSection(_DashGroup.habits, (_) => const DailyHabitsCard()),
      if (showDeepDiveNudge)
        _DashSection(_DashGroup.habits, (_) => _DeepDiveNudgeCard()),
      _DashSection(
          _DashGroup.progress, (_) => ProgressOverviewCard(profile: profile)),
    ];

/// Builds the mobile dashboard slivers from the shared section list: header,
/// full-width `top` cards, then a labelled group per [_DashGroup].
List<Widget> _dashboardMobileSlivers(
  BuildContext context,
  UserProfile profile,
  List<_DashSection> sections,
) {
  Widget group(_DashGroup g, String label) {
    final cards = sections.where((s) => s.group == g).toList();
    if (cards.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.xxl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _GroupLabel(label),
          const SizedBox(height: AppSpacing.md),
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.screenPaddingH,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (var i = 0; i < cards.length; i++) ...[
                  if (i > 0) const SizedBox(height: AppSpacing.lg),
                  cards[i].build(context),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  final topSections =
      sections.where((s) => s.group == _DashGroup.top).toList();

  return [
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
    for (final s in topSections)
      SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.screenPaddingH,
            AppSpacing.lg,
            AppSpacing.screenPaddingH,
            0,
          ),
          child: s.build(context),
        ),
      ),
    SliverToBoxAdapter(child: group(_DashGroup.today, AppStrings.groupToday)),
    SliverToBoxAdapter(child: group(_DashGroup.habits, AppStrings.groupHabits)),
    SliverToBoxAdapter(
        child: group(_DashGroup.progress, AppStrings.groupProgress)),
    // Extra bottom space so the final card clears the floating nav.
    const SliverToBoxAdapter(child: SizedBox(height: 140)),
  ];
}

// Dashboard desktop grid tuning. The frame is a touch wider than the shared
// web content max so the two columns + full-width progress card can breathe;
// the reflow threshold is measured on the padded content area beside the
// sidebar (so the 900px viewport / ~660px content case collapses to one column).
const double _kDashboardMaxWidth = 1200;
const double _kTwoColumnMinWidth = 720;
const double _kStreakCardWidth = 320;

/// Wide-screen dashboard. A two-part header band (greeting + streak momentum)
/// sits above an adaptive grid: TODAY (hero + routine) and HABITS columns side
/// by side, with a full-width PROGRESS card beneath. Reflows to a single column
/// when the content area beside the sidebar is narrow.
class _DashboardDesktopBody extends StatefulWidget {
  final UserProfile profile;
  final List<_DashSection> sections;

  const _DashboardDesktopBody({
    required this.profile,
    required this.sections,
  });

  @override
  State<_DashboardDesktopBody> createState() => _DashboardDesktopBodyState();
}

class _DashboardDesktopBodyState extends State<_DashboardDesktopBody> {
  final ScrollController _scrollController = ScrollController();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final profile = widget.profile;
    final sections = widget.sections;

    List<Widget> cardsFor(_DashGroup g) =>
        sections.where((s) => s.group == g).map((s) => s.build(context)).toList();

    // Label + cards for a group, each card separated by a consistent gap.
    Widget labelledColumn(String label, List<Widget> cards) => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _DesktopSectionLabel(label),
            const SizedBox(height: AppSpacing.md),
            for (var i = 0; i < cards.length; i++) ...[
              if (i > 0) const SizedBox(height: AppSpacing.lg),
              cards[i],
            ],
          ],
        );

    return Scrollbar(
      controller: _scrollController,
      thumbVisibility: true,
      child: SingleChildScrollView(
        controller: _scrollController,
        // Desktop/web uses a mouse — clamp instead of the mobile bounce.
        physics: const ClampingScrollPhysics(),
        child: WebContentFrame(
          maxWidth: _kDashboardMaxWidth,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final twoColumn = constraints.maxWidth >= _kTwoColumnMinWidth;

              final todayColumn =
                  labelledColumn(AppStrings.groupToday, cardsFor(_DashGroup.today));
              final habitsColumn = labelledColumn(
                  AppStrings.groupHabits, cardsFor(_DashGroup.habits));

              final grid = twoColumn
                  ? Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(flex: 3, child: todayColumn),
                        const SizedBox(width: AppSpacing.lg),
                        Expanded(flex: 2, child: habitsColumn),
                      ],
                    )
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        todayColumn,
                        const SizedBox(height: AppSpacing.sectionGap),
                        habitsColumn,
                      ],
                    );

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: AppSpacing.xl),
                  _HeaderBand(profile: profile, twoColumn: twoColumn),
                  const SizedBox(height: AppSpacing.sectionGap),
                  for (final card in cardsFor(_DashGroup.top)) ...[
                    card,
                    const SizedBox(height: AppSpacing.sectionGap),
                  ],
                  grid,
                  const SizedBox(height: AppSpacing.sectionGap),
                  labelledColumn(
                      AppStrings.groupProgress, cardsFor(_DashGroup.progress)),
                  const SizedBox(height: AppSpacing.xxl),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

/// The desktop header band: greeting/wisdom paired with the bounded streak
/// momentum card. Side by side when there's room, stacked when narrow.
class _HeaderBand extends StatelessWidget {
  final UserProfile profile;
  final bool twoColumn;

  const _HeaderBand({required this.profile, required this.twoColumn});

  @override
  Widget build(BuildContext context) {
    if (!twoColumn) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          DashboardHeader(
            profile: profile,
            showAvatar: false,
            showStreak: false,
          ),
          const SizedBox(height: AppSpacing.lg),
          StreakMomentumCard(profile: profile),
        ],
      );
    }
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: DashboardHeader(
            profile: profile,
            showAvatar: false,
            showStreak: false,
          ),
        ),
        const SizedBox(width: AppSpacing.xl),
        SizedBox(
          width: _kStreakCardWidth,
          child: StreakMomentumCard(profile: profile),
        ),
      ],
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
      child: HoverBuilder(
        builder: (context, hovered) => AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.all(AppSpacing.lg),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                AppColors.secondary.withValues(alpha: 0.15),
                AppColors.primary.withValues(alpha: 0.10),
              ],
            ),
            borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
            border: Border.all(
              color: AppColors.secondary.withValues(alpha: hovered ? 0.6 : 0.3),
            ),
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
        ),
      ).animate().fadeIn(duration: 400.ms),
    );
  }
}

/// Loading placeholder that mirrors the loaded layout: a centered single column
/// on narrow (native mobile) and the desktop header band + grid on wide, so the
/// dashboard doesn't visibly re-flow when the profile resolves.
class _DashboardSkeleton extends StatelessWidget {
  const _DashboardSkeleton();

  @override
  Widget build(BuildContext context) {
    if (Breakpoints.isWide(context)) {
      return SingleChildScrollView(
        physics: const ClampingScrollPhysics(),
        child: WebContentFrame(
          maxWidth: _kDashboardMaxWidth,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final twoColumn = constraints.maxWidth >= _kTwoColumnMinWidth;

              const greeting = Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ShimmerBox(
                      width: 220,
                      height: 28,
                      borderRadius: AppSpacing.radiusSm),
                  SizedBox(height: AppSpacing.sm),
                  ShimmerBox(
                      width: 260,
                      height: 16,
                      borderRadius: AppSpacing.radiusSm),
                ],
              );
              final headerBand = twoColumn
                  ? const Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(child: greeting),
                        SizedBox(width: AppSpacing.xl),
                        SizedBox(
                          width: _kStreakCardWidth,
                          child: ShimmerCard(height: 150),
                        ),
                      ],
                    )
                  : const Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        greeting,
                        SizedBox(height: AppSpacing.lg),
                        ShimmerCard(height: 150),
                      ],
                    );

              const todayCol = Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ShimmerCard(height: 180),
                  SizedBox(height: AppSpacing.lg),
                  ShimmerCard(height: 260),
                ],
              );
              const habitsCol = Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [ShimmerCard(height: 220)],
              );
              final grid = twoColumn
                  ? const Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(flex: 3, child: todayCol),
                        SizedBox(width: AppSpacing.lg),
                        Expanded(flex: 2, child: habitsCol),
                      ],
                    )
                  : const Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        todayCol,
                        SizedBox(height: AppSpacing.sectionGap),
                        habitsCol,
                      ],
                    );

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: AppSpacing.xl),
                  headerBand,
                  const SizedBox(height: AppSpacing.sectionGap),
                  grid,
                  const SizedBox(height: AppSpacing.sectionGap),
                  const ShimmerCard(height: 200),
                  const SizedBox(height: AppSpacing.xxl),
                ],
              );
            },
          ),
        ),
      );
    }

    return ResponsiveLayout(
      maxWidth: 680,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.screenPaddingH,
          AppSpacing.md,
          AppSpacing.screenPaddingH,
          140,
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
      ),
    );
  }
}
