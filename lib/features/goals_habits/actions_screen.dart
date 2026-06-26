import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_spacing.dart';
import '../../core/constants/app_text_styles.dart';
import '../../core/constants/app_strings.dart';
import '../../core/widgets/responsive_layout.dart';
import '../../core/utils/breakpoints.dart';
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
              return _buildDesktop(context);
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
                        // Tab-aware add action — hidden on the Priorities tab,
                        // which plans via the Plan Day sheet instead of a "+".
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

  /// Wide layout: all three action surfaces shown at once, side by side,
  /// so nothing is hidden behind a tab on a roomy screen.
  Widget _buildDesktop(BuildContext context) {
    return WebContentFrame(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg),
            child:
                Text(AppStrings.navActions, style: AppTextStyles.headlineLarge),
          ),
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Expanded(
                  flex: 2,
                  child: _ActionsColumn(
                    title: AppStrings.actionsTabPriorities,
                    child: PriorityActionsTab(),
                  ),
                ),
                const SizedBox(width: AppSpacing.lg),
                Expanded(
                  flex: 3,
                  child: _ActionsColumn(
                    title: AppStrings.goals,
                    onAdd: () => GoalFormModal.show(context, ref),
                    child: const GoalsTab(),
                  ),
                ),
                const SizedBox(width: AppSpacing.lg),
                Expanded(
                  flex: 2,
                  child: _ActionsColumn(
                    title: AppStrings.habits,
                    onAdd: () => HabitFormModal.show(context, ref),
                    child: const HabitsTab(),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// A single titled column in the desktop Actions layout: a header (with an
/// optional add action) above its scrollable tab content.
class _ActionsColumn extends StatelessWidget {
  final String title;
  final Widget child;
  final VoidCallback? onAdd;

  const _ActionsColumn({
    required this.title,
    required this.child,
    this.onAdd,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.md),
          child: Row(
            children: [
              Text(title, style: AppTextStyles.headlineSmall),
              const Spacer(),
              if (onAdd != null) _HeaderAddButton(onTap: onAdd!),
            ],
          ),
        ),
        Expanded(child: child),
      ],
    );
  }
}

class _HeaderAddButton extends StatelessWidget {
  final VoidCallback onTap;

  const _HeaderAddButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: AppColors.primaryContainer,
          borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
          border: Border.all(color: AppColors.primary.withValues(alpha: 0.4)),
        ),
        child:
            const Icon(Icons.add_rounded, color: AppColors.primary, size: 22),
      ),
    );
  }
}
