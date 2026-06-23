import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_spacing.dart';
import '../../core/constants/app_text_styles.dart';
import '../../core/constants/app_strings.dart';
import '../../core/widgets/responsive_layout.dart';
import 'goals_tab.dart';
import 'habits_tab.dart';
import 'priority_actions_tab.dart';

class ActionsScreen extends ConsumerWidget {
  const ActionsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        backgroundColor: AppColors.background,
        body: SafeArea(
          bottom: false,
          child: ResponsiveLayout(
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
                    Text('Actions', style: AppTextStyles.headlineLarge),
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
                  indicatorSize: TabBarIndicatorSize.tab,
                  indicator: BoxDecoration(
                    color: AppColors.primary,
                    borderRadius: BorderRadius.circular(AppSpacing.radiusMd - 2),
                  ),
                  dividerColor: Colors.transparent,
                  labelStyle: AppTextStyles.labelLarge.copyWith(color: Colors.white),
                  unselectedLabelStyle: AppTextStyles.labelMedium,
                  unselectedLabelColor: AppColors.textSecondary,
                  tabs: const [
                    Tab(text: AppStrings.goals),
                    Tab(text: AppStrings.habits),
                    Tab(text: 'Today'),
                  ],
                ),
              ),
              const Expanded(
                child: TabBarView(
                  children: [
                    GoalsTab(),
                    HabitsTab(),
                    PriorityActionsTab(),
                  ],
                ),
              ),
            ],
            ),
          ),
        ),
      ),
    );
  }
}
