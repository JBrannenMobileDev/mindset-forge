import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mindsetforge/models/coach_callback.dart';
import 'package:mindsetforge/providers/auth_provider.dart';
import 'package:mindsetforge/providers/coach_callback_provider.dart';

import '../mocks/mock_firestore_service.dart' show FakeUser, MockFirestoreService;

class _CapturingFirestoreService extends MockFirestoreService {
  final List<({String uid, Map<String, dynamic> fields})> updateCalls = [];

  @override
  Future<void> updateUserField(String uid, Map<String, dynamic> fields) {
    updateCalls.add((uid: uid, fields: fields));
    return Future.value();
  }
}

const _callback = CoachCallback(
  id: 'cb_test',
  message: 'I noticed your consistency jump after that belief reframe.',
  valence: 'positive',
  triggerType: 'consistency_breakthrough',
  referenceLabel: 'money belief',
  referenceDate: '2026-06-30',
  measurableChange: 'active days 2/7 to 6/7',
  confidence: 0.9,
  generatedAt: '2026-07-10T12:00:00.000Z',
);

void main() {
  group('CoachCallbackNotifier', () {
    test('markSeen writes seenAt and clears busy state', () async {
      final firestore = _CapturingFirestoreService();
      final container = ProviderContainer(
        overrides: [
          firestoreServiceProvider.overrideWithValue(firestore),
          authStateProvider.overrideWith((ref) => Stream.value(FakeUser('u1'))),
        ],
      );
      addTearDown(container.dispose);

      await container.read(authStateProvider.future);
      final notifier = container.read(coachCallbackBusyProvider.notifier);

      await notifier.markSeen(_callback);

      expect(firestore.updateCalls, hasLength(1));
      expect(firestore.updateCalls.first.uid, 'u1');
      expect(
        firestore.updateCalls.first.fields['pendingCallback.seenAt'],
        isA<String>(),
      );
      expect(container.read(coachCallbackBusyProvider), isFalse);
    });

    test('clearPending nulls pendingCallback field', () async {
      final firestore = _CapturingFirestoreService();
      final container = ProviderContainer(
        overrides: [
          firestoreServiceProvider.overrideWithValue(firestore),
          authStateProvider.overrideWith((ref) => Stream.value(FakeUser('u1'))),
        ],
      );
      addTearDown(container.dispose);

      await container.read(authStateProvider.future);
      await container.read(coachCallbackBusyProvider.notifier).clearPending();

      expect(firestore.updateCalls.single.fields['pendingCallback'], isNull);
    });

    test('markSeen no-ops without auth uid', () async {
      final firestore = _CapturingFirestoreService();
      final container = ProviderContainer(
        overrides: [
          firestoreServiceProvider.overrideWithValue(firestore),
          authStateProvider.overrideWith((ref) => const Stream.empty()),
        ],
      );
      addTearDown(container.dispose);

      await container.read(coachCallbackBusyProvider.notifier).markSeen(_callback);

      expect(firestore.updateCalls, isEmpty);
    });
  });
}
