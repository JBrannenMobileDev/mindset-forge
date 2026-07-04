import 'package:flutter_test/flutter_test.dart';
import 'package:mindsetforge/models/goal.dart';
import 'package:mindsetforge/models/action_step.dart';

void main() {
  group('Goal', () {
    final now = DateTime(2026, 1, 15);
    final target = DateTime(2027, 1, 15);

    // ── Computed getters ──────────────────────────────────────────────────────

    group('derivedProgress', () {
      Goal goalWithSteps(List<ActionStep> steps, {double manual = 0.0}) => Goal(
            id: '1',
            title: 'T',
            category: 'career',
            targetDate: target,
            createdAt: now,
            progressPercent: manual,
            actionSteps: steps,
          );

      test('falls back to manual progressPercent when there are no steps', () {
        expect(goalWithSteps(const [], manual: 42.0).derivedProgress, 42.0);
      });

      test('derives from completed/total steps when steps exist', () {
        final goal = goalWithSteps(const [
          ActionStep(id: 's1', title: 'A', isCompleted: true),
          ActionStep(id: 's2', title: 'B', isCompleted: true),
          ActionStep(id: 's3', title: 'C'),
          ActionStep(id: 's4', title: 'D'),
        ], manual: 0.0);
        expect(goal.derivedProgress, closeTo(50.0, 0.001));
        expect(goal.completedStepCount, 2);
        expect(goal.hasSteps, isTrue);
      });
    });

    group('isCompleted', () {
      test('true when status is completed', () {
        final goal = Goal(
          id: '1',
          title: 'T',
          category: 'career',
          status: 'completed',
          targetDate: target,
          createdAt: now,
        );
        expect(goal.isCompleted, isTrue);
      });

      test('false when status is active', () {
        final goal = Goal(
          id: '1',
          title: 'T',
          category: 'career',
          targetDate: target,
          createdAt: now,
        );
        expect(goal.isCompleted, isFalse);
      });
    });

    group('isLongHorizon', () {
      test('true for long_term', () {
        final goal = Goal(
          id: '1',
          title: 'T',
          category: 'career',
          goalType: kGoalTypeLongTerm,
          targetDate: target,
          createdAt: now,
        );
        expect(goal.isLongHorizon, isTrue);
      });

      test('true for life_goal', () {
        final goal = Goal(
          id: '1',
          title: 'T',
          category: 'career',
          goalType: kGoalTypeLifeGoal,
          targetDate: target,
          createdAt: now,
        );
        expect(goal.isLongHorizon, isTrue);
      });

      test('false for short_term', () {
        final goal = Goal(
          id: '1',
          title: 'T',
          category: 'career',
          goalType: kGoalTypeShortTerm,
          targetDate: target,
          createdAt: now,
        );
        expect(goal.isLongHorizon, isFalse);
      });

      test('false for medium_term', () {
        final goal = Goal(
          id: '1',
          title: 'T',
          category: 'career',
          goalType: kGoalTypeMediumTerm,
          targetDate: target,
          createdAt: now,
        );
        expect(goal.isLongHorizon, isFalse);
      });
    });

    // ── fromJson / toJson ────────────────────────────────────────────────────

    group('fromJson', () {
      test('round-trip preserves all fields', () {
        final step = ActionStep(
          id: 's1',
          description: 'Step one',
          isCompleted: true,
          completedAt: now,
        );
        final original = Goal(
          id: 'g1',
          title: 'Become a CTO',
          category: 'career',
          goalType: kGoalTypeLongTerm,
          description: 'Lead tech at a startup',
          targetDate: target,
          progressPercent: 42.0,
          actionSteps: [step],
          status: 'active',
          createdAt: now,
        );

        final json = original.toJson();
        final restored = Goal.fromJson(json);

        expect(restored.id, original.id);
        expect(restored.title, original.title);
        expect(restored.category, original.category);
        expect(restored.goalType, original.goalType);
        expect(restored.description, original.description);
        expect(restored.progressPercent, original.progressPercent);
        expect(restored.status, original.status);
        expect(restored.actionSteps.length, 1);
        expect(restored.actionSteps.first.id, 's1');
        expect(restored.actionSteps.first.isCompleted, isTrue);
      });

      test('missing goalType with parentGoalId → infers short_term', () {
        final json = {
          'id': '1',
          'title': 'Sub',
          'category': 'career',
          'parentGoalId': 'parent-1',
          'targetDate': target.toIso8601String(),
          'createdAt': now.toIso8601String(),
        };
        final goal = Goal.fromJson(json);
        expect(goal.goalType, kGoalTypeShortTerm);
      });

      test('missing goalType without parentGoalId → defaults to long_term', () {
        final json = {
          'id': '1',
          'title': 'Top',
          'category': 'career',
          'targetDate': target.toIso8601String(),
          'createdAt': now.toIso8601String(),
        };
        final goal = Goal.fromJson(json);
        expect(goal.goalType, kGoalTypeLongTerm);
      });

      test('invalid targetDate → defaults to ~90 days from now', () {
        final json = {
          'id': '1',
          'title': 'T',
          'category': 'career',
          'targetDate': 'not-a-date',
          'createdAt': now.toIso8601String(),
        };
        final before = DateTime.now().add(const Duration(days: 89));
        final after = DateTime.now().add(const Duration(days: 91));
        final goal = Goal.fromJson(json);
        expect(goal.targetDate.isAfter(before), isTrue);
        expect(goal.targetDate.isBefore(after), isTrue);
      });

      test('missing fields get safe defaults', () {
        final goal = Goal.fromJson({'id': '1', 'title': 'Minimal'});
        expect(goal.category, 'personal_growth');
        expect(goal.status, 'active');
        expect(goal.progressPercent, 0.0);
        expect(goal.actionSteps, isEmpty);
        expect(goal.completedAt, isNull);
        expect(goal.description, '');
      });
    });

    // ── copyWith ─────────────────────────────────────────────────────────────

    test('copyWith creates new instance with changed fields', () {
      final original = Goal(
        id: '1',
        title: 'Old',
        category: 'career',
        targetDate: target,
        createdAt: now,
      );
      final updated = original.copyWith(title: 'New', progressPercent: 50.0);

      expect(updated.title, 'New');
      expect(updated.progressPercent, 50.0);
      expect(updated.id, original.id);
      expect(updated.category, original.category);
    });
  });
}
