import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../core/constants/goal_meta.dart';
import '../../../core/widgets/app_button.dart';
import '../../../models/goal.dart';

/// Category accent colour for goal template tiles and focus cards.
Color goalCategoryColor(String category) =>
    const <String, Color>{
      'career': AppColors.categoryCareer,
      'health': AppColors.categoryHealth,
      'relationships': AppColors.categoryRelationships,
      'finances': AppColors.categoryFinances,
      'personal_growth': AppColors.categoryPersonalGrowth,
    }[category] ??
    AppColors.primary;

String goalCategoryLabel(String cat) =>
    const {
      'career': 'Career',
      'health': 'Health',
      'relationships': 'Relationships',
      'finances': 'Finances',
      'personal_growth': 'Personal Growth',
    }[cat] ??
    cat;

/// Short human-readable horizon label for a template's month count.
String goalHorizonLabel(int months) {
  if (months < 12) return '~$months mo';
  if (months == 12) return '~1 yr';
  return '~${(months / 12).round()} yr';
}

class GoalTemplate {
  final String id;
  final String title;
  final String description;
  final IconData icon;
  final String category;
  final int months;

  const GoalTemplate(
    this.id,
    this.title,
    this.description,
    this.icon,
    this.category,
    this.months,
  );
}

const kGoalCategories = [
  'career',
  'health',
  'relationships',
  'finances',
  'personal_growth',
];

const kGoalTemplates = [
  GoalTemplate(
    'launch_business',
    'Launch a Business',
    'Build your own company or startup',
    Icons.rocket_launch_rounded,
    'career',
    12,
  ),
  GoalTemplate(
    'get_in_shape',
    'Get in Shape',
    'Transform your health and fitness',
    Icons.fitness_center_rounded,
    'health',
    6,
  ),
  GoalTemplate(
    'build_wealth',
    'Build Wealth',
    'Grow your financial independence',
    Icons.savings_rounded,
    'finances',
    24,
  ),
  GoalTemplate(
    'side_hustle',
    'Start a Side Hustle',
    'Create additional income streams',
    Icons.trending_up_rounded,
    'career',
    9,
  ),
  GoalTemplate(
    'find_purpose',
    'Find My Purpose',
    'Discover your definite major purpose',
    Icons.explore_rounded,
    'personal_growth',
    6,
  ),
  GoalTemplate(
    'relationships',
    'Improve Relationships',
    'Deepen connections that matter',
    Icons.favorite_rounded,
    'relationships',
    6,
  ),
  GoalTemplate(
    'quit_habit',
    'Break a Bad Habit',
    'Replace negative patterns with empowering ones',
    Icons.block_rounded,
    'personal_growth',
    3,
  ),
  GoalTemplate(
    'write_book',
    'Write a Book',
    'Share your story or expertise',
    Icons.menu_book_rounded,
    'career',
    12,
  ),
  GoalTemplate(
    'learn_skill',
    'Master a New Skill',
    'Level up your capabilities',
    Icons.school_rounded,
    'personal_growth',
    6,
  ),
  GoalTemplate(
    'mental_health',
    'Improve Mental Health',
    'Build emotional resilience and peace',
    Icons.self_improvement_rounded,
    'health',
    6,
  ),
  GoalTemplate(
    'travel',
    'Travel the World',
    'Experience life beyond your comfort zone',
    Icons.flight_rounded,
    'personal_growth',
    12,
  ),
  GoalTemplate(
    'buy_home',
    'Buy a Home',
    'Secure your foundation',
    Icons.home_rounded,
    'finances',
    24,
  ),
];

GoalTemplate? templateForTitle(String title) {
  for (final t in kGoalTemplates) {
    if (t.title == title) return t;
  }
  return null;
}

GoalTemplate? templateForGoal(Goal goal) => templateForTitle(goal.title);

/// Builds [Goal] instances from the selected onboarding template ids.
List<Goal> goalsFromTemplateIds(Set<String> templateIds) {
  final now = DateTime.now();
  return kGoalTemplates
      .where((t) => templateIds.contains(t.id))
      .map(
        (t) => Goal(
          id: const Uuid().v4(),
          title: t.title,
          category: t.category,
          goalType: goalTypeFromMonths(t.months),
          description: t.description,
          targetDate: now.add(Duration(days: t.months * 30)),
          createdAt: now,
        ),
      )
      .toList();
}

/// Whether a goal title matches a curated template (already committed).
bool isTemplateGoalTitle(String title) => templateForTitle(title) != null;

/// Shared pinned footer for onboarding goal steps (Back + primary CTA).
class OnboardingGoalsFooter extends StatelessWidget {
  final VoidCallback onBack;
  final String continueLabel;
  final VoidCallback? onContinue;
  final IconData continueIcon;

  const OnboardingGoalsFooter({
    super.key,
    required this.onBack,
    this.continueLabel = 'Continue',
    required this.onContinue,
    this.continueIcon = Icons.arrow_forward_rounded,
  });

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).padding.bottom;
    final keyboardVisible = MediaQuery.of(context).viewInsets.bottom > 0;

    return Positioned(
      left: 0,
      right: 0,
      bottom: 0,
      child: AnimatedOpacity(
        opacity: keyboardVisible ? 0.0 : 1.0,
        duration: const Duration(milliseconds: 200),
        child: IgnorePointer(
          ignoring: keyboardVisible,
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  AppColors.background.withValues(alpha: 0),
                  AppColors.background,
                ],
                stops: const [0.0, 0.45],
              ),
            ),
            padding: EdgeInsets.fromLTRB(
              AppSpacing.screenPaddingH,
              AppSpacing.xl,
              AppSpacing.screenPaddingH,
              bottomInset + AppSpacing.md,
            ),
            child: Row(
              children: [
                AppSecondaryButton(
                  label: 'Back',
                  width: 100,
                  onPressed: onBack,
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: AppPrimaryButton(
                    label: continueLabel,
                    onPressed: onContinue,
                    icon: continueIcon,
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
