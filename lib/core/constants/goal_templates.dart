import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../../models/goal.dart';
import 'app_colors.dart';
import 'app_strings.dart';
import 'goal_meta.dart';

/// Category accent colour for goal template tiles and cards.
Color goalCategoryColor(String category) =>
    const <String, Color>{
      'career': AppColors.categoryCareer,
      'health': AppColors.categoryHealth,
      'relationships': AppColors.categoryRelationships,
      'finances': AppColors.categoryFinances,
      'personal_growth': AppColors.categoryPersonalGrowth,
      'spirituality': AppColors.categorySpirituality,
      'learning': AppColors.categoryLearning,
    }[category] ??
    AppColors.primary;

/// True when [category] is one of the curated slugs in [kGoalCategories].
bool isCuratedGoalCategory(String category) =>
    kGoalCategories.contains(category);

/// Prettifies legacy underscore slugs; leaves free-text custom labels as typed.
String _prettifyCategorySlug(String category) {
  if (!category.contains('_')) return category;
  return category
      .split('_')
      .map((w) =>
          w.isEmpty ? w : '${w[0].toUpperCase()}${w.substring(1).toLowerCase()}')
      .join(' ');
}

/// Localized display label for a goal category slug or custom label.
String goalCategoryLabel(String category) => switch (category) {
      'career' => AppStrings.categoryCareer,
      'health' => AppStrings.categoryHealth,
      'relationships' => AppStrings.categoryRelationships,
      'finances' => AppStrings.categoryFinances,
      'personal_growth' => AppStrings.categoryPersonalGrowth,
      'spirituality' => AppStrings.categorySpirituality,
      'learning' => AppStrings.categoryLearning,
      _ => _prettifyCategorySlug(category),
    };

IconData goalCategoryIcon(String category) => switch (category) {
      'career' => Icons.work_rounded,
      'health' => Icons.favorite_rounded,
      'relationships' => Icons.people_rounded,
      'finances' => Icons.attach_money_rounded,
      'personal_growth' => Icons.auto_awesome_rounded,
      'spirituality' => Icons.self_improvement_rounded,
      'learning' => Icons.school_rounded,
      _ => Icons.flag_rounded,
    };

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
  'spirituality',
  'learning',
];

/// Dropdown sentinel for onboarding / forms when the user picks "Other".
const kGoalCategoryOtherSentinel = '__other__';

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
    'learning',
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
    'deepen_practice',
    'Deepen My Practice',
    'Build a daily spiritual or mindfulness practice',
    Icons.spa_rounded,
    'spirituality',
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

/// Builds [Goal] instances from the selected template ids (onboarding multi-select).
List<Goal> goalsFromTemplateIds(Set<String> templateIds) {
  final now = DateTime.now();
  return kGoalTemplates
      .where((t) => templateIds.contains(t.id))
      .map((t) => goalDraftFromTemplate(t, now: now))
      .toList();
}

/// Pre-fills a new goal from a curated template (in-app gallery pick).
Goal goalDraftFromTemplate(GoalTemplate template, {DateTime? now}) {
  final created = now ?? DateTime.now();
  return Goal(
    id: const Uuid().v4(),
    title: template.title,
    category: template.category,
    goalType: goalTypeFromMonths(template.months),
    description: template.description,
    targetDate: created.add(Duration(days: template.months * 30)),
    createdAt: created,
  );
}

/// Whether a goal title matches a curated template (already committed).
bool isTemplateGoalTitle(String title) => templateForTitle(title) != null;
