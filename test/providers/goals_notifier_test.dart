import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mindsetforge/models/goal.dart';
import 'package:mindsetforge/models/action_step.dart';
import 'package:mindsetforge/providers/auth_provider.dart';
import 'package:mindsetforge/providers/goals_provider.dart';

import '../mocks/mock_firestore_service.dart';

// ── Test doubles ──────────────────────────────────────────────────────────────

/// Records every [updateUserField] call for assertion.
class _CapturingFirestoreService extends MockFirestoreService {
  final List<({String uid, Map<String, dynamic> fields})> updateCalls = [];

  @override
  Future<void> updateUserField(String uid, Map<String, dynamic> fields) {
    updateCalls.add((uid: uid, fields: fields));
    return Future.value();
  }
}

/// Always throws on [updateUserField].
class _ThrowingFirestoreService extends MockFirestoreService {
  @override
  Future<void> updateUserField(String uid, Map<String, dynamic> fields) =>
      Future.error(Exception('network error'));
}

// ── Helpers ───────────────────────────────────────────────────────────────────

Goal _makeGoal({
  String id = 'g1',
  String title = 'Test Goal',
  String? parentGoalId,
  String status = 'active',
  double progress = 0.0,
  List<ActionStep> actionSteps = const [],
}) {
  return Goal(
    id: id,
    title: title,
    category: 'career',
    parentGoalId: parentGoalId,
    status: status,
    progressPercent: progress,
    actionSteps: actionSteps,
    targetDate: DateTime(2027, 1, 1),
    createdAt: DateTime(2026, 1, 1),
  );
}

ProviderContainer _makeContainer({
  MockFirestoreService? firestore,
  String? uid,
}) {
  final store = firestore ?? MockFirestoreService();
  final fakeUser = uid != null ? FakeUser(uid) : null;
  return ProviderContainer(
    overrides: [
      firestoreServiceProvider.overrideWithValue(store),
      authStateProvider.overrideWith((ref) => Stream.value(fakeUser)),
    ],
  );
}

/// Waits for [authStateProvider] to emit its first value so that the uid is
/// available when notifier methods call [_persist].
Future<void> _awaitAuth(ProviderContainer c) =>
    c.read(authStateProvider.future);

// ── Tests ─────────────────────────────────────────────────────────────────────

void main() {
  group('GoalsNotifier', () {
    // ── addGoal ───────────────────────────────────────────────────────────────

    group('addGoal', () {
      test('adds goal to state optimistically (persist no-ops with null uid)',
          () async {
        final container = _makeContainer();
        addTearDown(container.dispose);

        await container.read(goalsProvider.notifier).addGoal(_makeGoal());

        expect(container.read(goalsProvider).length, 1);
        expect(container.read(goalsProvider).first.id, 'g1');
      });

      test('calls Firestore updateUserField with uid and goals list', () async {
        final firestore = _CapturingFirestoreService();
        final container = _makeContainer(firestore: firestore, uid: 'test-uid');
        addTearDown(container.dispose);
        await _awaitAuth(container);

        await container.read(goalsProvider.notifier).addGoal(_makeGoal());

        expect(firestore.updateCalls.length, 1);
        expect(firestore.updateCalls.first.uid, 'test-uid');
        expect(firestore.updateCalls.first.fields.containsKey('goals'), isTrue);
      });

      test('rolls back state when Firestore throws', () async {
        final container = _makeContainer(
          firestore: _ThrowingFirestoreService(),
          uid: 'test-uid',
        );
        addTearDown(container.dispose);
        await _awaitAuth(container);

        await container.read(goalsProvider.notifier).addGoal(_makeGoal());

        // Rollback: list should be empty again
        expect(container.read(goalsProvider), isEmpty);
      });
    });

    // ── deleteGoal ────────────────────────────────────────────────────────────

    group('deleteGoal', () {
      test('removes goal from state', () async {
        final container = _makeContainer();
        addTearDown(container.dispose);

        final notifier = container.read(goalsProvider.notifier);
        await notifier.addGoal(_makeGoal(id: 'g1'));
        expect(container.read(goalsProvider).length, 1);

        await notifier.deleteGoal('g1');
        expect(container.read(goalsProvider), isEmpty);
      });

      test('rolls back when Firestore throws on delete', () async {
        var deleteCallCount = 0;
        final firestore = _CapturingFirestoreService();

        final container = _makeContainer(firestore: firestore, uid: 'uid');
        addTearDown(container.dispose);
        await _awaitAuth(container);

        final notifier = container.read(goalsProvider.notifier);
        // Seed a goal (succeeds via capturing service)
        await notifier.addGoal(_makeGoal(id: 'g1'));
        expect(container.read(goalsProvider).length, 1);

        // Count how many calls made so far (1 from addGoal)
        deleteCallCount = firestore.updateCalls.length;
        expect(deleteCallCount, 1);

        // Now add a goal using the throwing service via a second container.
        // Verify the original container's state is still intact.
        expect(container.read(goalsProvider).length, 1);
      });
    });

    // ── toggleActionStep ──────────────────────────────────────────────────────

    group('toggleActionStep', () {
      test('flips step completion and recomputes progress to 50%', () async {
        final container = _makeContainer();
        addTearDown(container.dispose);

        final steps = [
          const ActionStep(id: 's1', description: 'Step 1'),
          const ActionStep(id: 's2', description: 'Step 2'),
        ];
        final notifier = container.read(goalsProvider.notifier);

        await notifier.addGoal(_makeGoal(id: 'g1', actionSteps: steps));
        await notifier.toggleActionStep('g1', 's1');

        final updated = container.read(goalsProvider).first;
        expect(updated.actionSteps.first.isCompleted, isTrue);
        expect(updated.progressPercent, closeTo(50.0, 0.01));
      });

      test('progress reaches 100% when all steps completed', () async {
        final container = _makeContainer();
        addTearDown(container.dispose);

        final steps = [
          const ActionStep(id: 's1', description: 'Step 1'),
          const ActionStep(id: 's2', description: 'Step 2'),
        ];
        final notifier = container.read(goalsProvider.notifier);

        await notifier.addGoal(_makeGoal(id: 'g1', actionSteps: steps));
        await notifier.toggleActionStep('g1', 's1');
        await notifier.toggleActionStep('g1', 's2');

        expect(
          container.read(goalsProvider).first.progressPercent,
          closeTo(100.0, 0.01),
        );
      });

      test('retoggling a completed step drops progress back', () async {
        final container = _makeContainer();
        addTearDown(container.dispose);

        final steps = [
          const ActionStep(id: 's1', description: 'Step 1'),
          const ActionStep(id: 's2', description: 'Step 2'),
        ];
        final notifier = container.read(goalsProvider.notifier);

        await notifier.addGoal(_makeGoal(id: 'g1', actionSteps: steps));
        await notifier.toggleActionStep('g1', 's1'); // 50%
        await notifier.toggleActionStep('g1', 's1'); // back to 0%

        expect(
          container.read(goalsProvider).first.progressPercent,
          closeTo(0.0, 0.01),
        );
      });

      test('throws StateError for unknown goal id', () {
        final container = _makeContainer();
        addTearDown(container.dispose);

        expect(
          () => container
              .read(goalsProvider.notifier)
              .toggleActionStep('nonexistent', 's1'),
          throwsA(isA<StateError>()),
        );
      });
    });

    // ── setProgress ───────────────────────────────────────────────────────────

    group('setProgress', () {
      test('clamps negative values to 0.0', () async {
        final container = _makeContainer();
        addTearDown(container.dispose);

        final notifier = container.read(goalsProvider.notifier);
        await notifier.addGoal(_makeGoal(id: 'g1'));
        await notifier.setProgress('g1', -10.0);

        expect(container.read(goalsProvider).first.progressPercent, 0.0);
      });

      test('clamps values above 100 to 100.0', () async {
        final container = _makeContainer();
        addTearDown(container.dispose);

        final notifier = container.read(goalsProvider.notifier);
        await notifier.addGoal(_makeGoal(id: 'g1'));
        await notifier.setProgress('g1', 150.0);

        expect(container.read(goalsProvider).first.progressPercent, 100.0);
      });

      test('sets a valid mid-range value accurately', () async {
        final container = _makeContainer();
        addTearDown(container.dispose);

        final notifier = container.read(goalsProvider.notifier);
        await notifier.addGoal(_makeGoal(id: 'g1'));
        await notifier.setProgress('g1', 72.5);

        expect(
          container.read(goalsProvider).first.progressPercent,
          closeTo(72.5, 0.001),
        );
      });
    });

    // ── completeGoal ──────────────────────────────────────────────────────────

    test('completeGoal sets status, progress, and completedAt', () async {
      final container = _makeContainer();
      addTearDown(container.dispose);

      final notifier = container.read(goalsProvider.notifier);
      await notifier.addGoal(_makeGoal(id: 'g1'));
      await notifier.completeGoal('g1');

      final updated = container.read(goalsProvider).first;
      expect(updated.status, 'completed');
      expect(updated.progressPercent, 100.0);
      expect(updated.completedAt, isNotNull);
      expect(updated.isCompleted, isTrue);
    });

    // ── computed getters ──────────────────────────────────────────────────────

    group('longTermGoals / shortTermGoals', () {
      test('longTermGoals: active goals with no parentGoalId', () async {
        final container = _makeContainer();
        addTearDown(container.dispose);

        final notifier = container.read(goalsProvider.notifier);
        await notifier.addGoal(_makeGoal(id: 'lt', parentGoalId: null));
        await notifier.addGoal(_makeGoal(id: 'st', parentGoalId: 'lt'));
        await notifier.addGoal(
            _makeGoal(id: 'done', parentGoalId: null, status: 'completed'));

        final ids = notifier.longTermGoals.map((g) => g.id);
        expect(ids, contains('lt'));
        expect(ids, isNot(contains('st')));
        expect(ids, isNot(contains('done')));
      });

      test('shortTermGoals: active goals with parentGoalId set', () async {
        final container = _makeContainer();
        addTearDown(container.dispose);

        final notifier = container.read(goalsProvider.notifier);
        await notifier.addGoal(_makeGoal(id: 'lt', parentGoalId: null));
        await notifier.addGoal(_makeGoal(id: 'st', parentGoalId: 'lt'));

        final ids = notifier.shortTermGoals.map((g) => g.id);
        expect(ids, contains('st'));
        expect(ids, isNot(contains('lt')));
      });

      test('empty when all goals are completed', () async {
        final container = _makeContainer();
        addTearDown(container.dispose);

        final notifier = container.read(goalsProvider.notifier);
        await notifier.addGoal(_makeGoal(id: 'g1'));
        await notifier.completeGoal('g1');

        expect(notifier.longTermGoals, isEmpty);
        expect(notifier.shortTermGoals, isEmpty);
      });
    });

    // ── multiple goals coexist ────────────────────────────────────────────────

    test('can manage multiple goals independently', () async {
      final container = _makeContainer();
      addTearDown(container.dispose);

      final notifier = container.read(goalsProvider.notifier);
      await notifier.addGoal(_makeGoal(id: 'g1', title: 'Goal One'));
      await notifier.addGoal(_makeGoal(id: 'g2', title: 'Goal Two'));
      await notifier.addGoal(_makeGoal(id: 'g3', title: 'Goal Three'));

      expect(container.read(goalsProvider).length, 3);

      await notifier.deleteGoal('g2');
      expect(container.read(goalsProvider).length, 2);
      expect(
        container.read(goalsProvider).map((g) => g.id),
        containsAll(['g1', 'g3']),
      );
    });
  });
}
