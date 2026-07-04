import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_spacing.dart';
import '../../core/constants/app_text_styles.dart';
import '../../core/constants/app_strings.dart';
import '../../core/utils/app_date_utils.dart';
import '../../core/widgets/responsive_layout.dart';
import '../../core/utils/breakpoints.dart';
import 'actions_layout.dart';
import 'goal_form_modal.dart';
import 'goals_tab.dart';
import 'habits_tab.dart';
import 'priority_actions_tab.dart';

class ActionsScreen extends ConsumerStatefulWidget {
  /// Optional deep-link target tab: 'priorities' | 'goals' | 'habits'.
  final String? initialTab;

  const ActionsScreen({super.key, this.initialTab});

  @override
  ConsumerState<ActionsScreen> createState() => _ActionsScreenState();
}

class _ActionsScreenState extends ConsumerState<ActionsScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  static const _tabKeys = ['priorities', 'goals', 'habits'];

  @override
  void initState() {
    super.initState();
    final initialIndex = _tabKeys.indexOf(widget.initialTab ?? 'priorities');
    _tabController = TabController(
      length: 3,
      vsync: this,
      initialIndex: initialIndex < 0 ? 0 : initialIndex,
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _onAdd() {
    switch (_tabController.index) {
      case 1:
        GoalFormModal.show(context, ref);
      case 2:
        HabitFormModal.show(context, ref);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        bottom: false,
        child: LayoutBuilder(
          builder: (context, constraints) {
            if (Breakpoints.isWideWidth(constraints.maxWidth)) {
              return _ActionsDesktopBody(ref: ref);
            }
            return ResponsiveLayout(
              maxWidth: 680,
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.screenPaddingH,
                      AppSpacing.lg,
                      AppSpacing.screenPaddingH,
                      AppSpacing.md,
                    ),
                    child: Row(
                      children: [
                        Text(AppStrings.navActions,
                            style: AppTextStyles.headlineLarge),
                        const Spacer(),
                        AnimatedBuilder(
                          animation: _tabController,
                          builder: (context, _) {
                            final showAdd = _tabController.index != 0;
                            return AnimatedOpacity(
                              opacity: showAdd ? 1 : 0,
                              duration: const Duration(milliseconds: 200),
                              child: IgnorePointer(
                                ignoring: !showAdd,
                                child: _HeaderAddButton(onTap: _onAdd),
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                  Container(
                    margin: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.screenPaddingH,
                    ),
                    height: 44,
                    decoration: BoxDecoration(
                      color: AppColors.surfaceElevated,
                      borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: TabBar(
                      controller: _tabController,
                      indicatorSize: TabBarIndicatorSize.tab,
                      indicator: BoxDecoration(
                        color: AppColors.primary,
                        borderRadius:
                            BorderRadius.circular(AppSpacing.radiusMd - 2),
                      ),
                      dividerColor: Colors.transparent,
                      labelColor: AppColors.textPrimary,
                      unselectedLabelColor: AppColors.textSecondary,
                      labelStyle: AppTextStyles.labelLarge,
                      unselectedLabelStyle: AppTextStyles.labelMedium,
                      tabs: const [
                        Tab(text: AppStrings.actionsTabPriorities),
                        Tab(text: AppStrings.goals),
                        Tab(text: AppStrings.habits),
                      ],
                    ),
                  ),
                  Expanded(
                    child: TabBarView(
                      controller: _tabController,
                      children: const [
                        PriorityActionsTab(),
                        GoalsTab(),
                        HabitsTab(),
                      ],
                    ),
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

/// Wide-screen Actions: a single coordinated scroll with adaptive reflow —
/// three columns when roomy, two when medium, stacked when narrow beside the
/// sidebar. Mirrors the dashboard desktop body pattern.
class _ActionsDesktopBody extends StatefulWidget {
  final WidgetRef ref;

  const _ActionsDesktopBody({required this.ref});

  @override
  State<_ActionsDesktopBody> createState() => _ActionsDesktopBodyState();
}

class _ActionsDesktopBodyState extends State<_ActionsDesktopBody> {
  final ScrollController _scrollController = ScrollController();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ref = widget.ref;
    final todayLabel =
        '${AppStrings.priorityActionsTodayPrefix}${AppDateUtils.formatWeekdayLong(DateTime.now())}';

    Widget prioritiesSection(ActionsLayoutContext ctx) => _ActionsSection(
          label: AppStrings.actionsTabPriorities,
          onAdd: () => PriorityActionsTab.showAddSheet(context, ref),
          child: PriorityActionsTab(layoutContext: ctx),
        );

    Widget goalsSection(ActionsLayoutContext ctx) => _ActionsSection(
          label: AppStrings.goals,
          onAdd: () => GoalFormModal.show(context, ref),
          child: GoalsTab(layoutContext: ctx),
        );

    Widget habitsSection(ActionsLayoutContext ctx) => _ActionsSection(
          label: AppStrings.habits,
          onAdd: () => HabitFormModal.show(context, ref),
          child: HabitsTab(layoutContext: ctx),
        );

    return Scrollbar(
      controller: _scrollController,
      thumbVisibility: true,
      child: SingleChildScrollView(
        controller: _scrollController,
        physics: const ClampingScrollPhysics(),
        child: WebContentFrame(
          maxWidth: kActionsMaxWidth,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final threeColumn =
                  constraints.maxWidth >= kActionsThreeColumnMinWidth;
              final twoColumn =
                  constraints.maxWidth >= kActionsTwoColumnMinWidth;

              final header = Padding(
                padding: const EdgeInsets.only(top: AppSpacing.xl),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(AppStrings.navActions,
                        style: AppTextStyles.headlineLarge),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      todayLabel,
                      style: AppTextStyles.bodySmall
                          .copyWith(color: AppColors.textSecondary),
                    ),
                  ],
                ),
              );

              if (threeColumn) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    header,
                    const SizedBox(height: AppSpacing.sectionGap),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          flex: 2,
                          child: prioritiesSection(
                              ActionsLayoutContext.desktopColumn),
                        ),
                        const SizedBox(width: AppSpacing.lg),
                        Expanded(
                          flex: 3,
                          child: goalsSection(ActionsLayoutContext.desktopColumn),
                        ),
                        const SizedBox(width: AppSpacing.lg),
                        Expanded(
                          flex: 2,
                          child: habitsSection(ActionsLayoutContext.desktopColumn),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.xxl),
                  ],
                );
              }

              if (twoColumn) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    header,
                    const SizedBox(height: AppSpacing.sectionGap),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: prioritiesSection(
                              ActionsLayoutContext.desktopColumn),
                        ),
                        const SizedBox(width: AppSpacing.lg),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              goalsSection(ActionsLayoutContext.desktopColumn),
                              habitsSection(ActionsLayoutContext.desktopColumn),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.xxl),
                  ],
                );
              }

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  header,
                  const SizedBox(height: AppSpacing.sectionGap),
                  prioritiesSection(ActionsLayoutContext.desktopSection),
                  goalsSection(ActionsLayoutContext.desktopSection),
                  habitsSection(ActionsLayoutContext.desktopSection),
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

/// A labelled desktop section: overline header with optional add action.
class _ActionsSection extends StatelessWidget {
  final String label;
  final Widget child;
  final VoidCallback? onAdd;

  const _ActionsSection({
    required this.label,
    required this.child,
    this.onAdd,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            ActionsDesktopSectionLabel(label),
            const Spacer(),
            if (onAdd != null) _HeaderAddButton(onTap: onAdd!),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        child,
      ],
    );
  }
}

class _HeaderAddButton extends StatelessWidget {
  final VoidCallback onTap;

  const _HeaderAddButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: AppColors.primaryContainer,
            borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
            border:
                Border.all(color: AppColors.primary.withValues(alpha: 0.4)),
          ),
          child: const Icon(Icons.add_rounded,
              color: AppColors.primary, size: 22),
        ),
      ),
    );
  }
}
