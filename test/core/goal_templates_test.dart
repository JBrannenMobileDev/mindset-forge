import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mindsetforge/core/constants/app_colors.dart';
import 'package:mindsetforge/core/constants/app_strings.dart';
import 'package:mindsetforge/core/constants/goal_templates.dart';

void main() {
  group('kGoalCategories', () {
    test('contains all seven curated slugs', () {
      expect(kGoalCategories, hasLength(7));
      expect(kGoalCategories, containsAll([
        'career',
        'health',
        'relationships',
        'finances',
        'personal_growth',
        'spirituality',
        'learning',
      ]));
    });
  });

  group('goalCategoryLabel', () {
    test('returns localized labels for curated slugs', () {
      expect(goalCategoryLabel('spirituality'), AppStrings.categorySpirituality);
      expect(goalCategoryLabel('learning'), AppStrings.categoryLearning);
    });

    test('prettifies legacy underscore slugs', () {
      expect(goalCategoryLabel('some_legacy_slug'), 'Some Legacy Slug');
    });

    test('returns custom free-text labels as typed', () {
      expect(goalCategoryLabel('Creative Arts'), 'Creative Arts');
    });
  });

  group('goalCategoryColor', () {
    test('maps new categories to distinct tokens', () {
      expect(goalCategoryColor('spirituality'), AppColors.categorySpirituality);
      expect(goalCategoryColor('learning'), AppColors.categoryLearning);
    });

    test('falls back to primary for custom categories', () {
      expect(goalCategoryColor('Creative Arts'), AppColors.primary);
    });
  });

  group('goalCategoryIcon', () {
    test('maps new categories to icons', () {
      expect(goalCategoryIcon('spirituality'), Icons.self_improvement_rounded);
      expect(goalCategoryIcon('learning'), Icons.school_rounded);
    });

    test('falls back to flag for custom categories', () {
      expect(goalCategoryIcon('Creative Arts'), Icons.flag_rounded);
    });
  });

  group('isCuratedGoalCategory', () {
    test('returns true for curated slugs only', () {
      expect(isCuratedGoalCategory('learning'), isTrue);
      expect(isCuratedGoalCategory('Creative Arts'), isFalse);
    });
  });
}
