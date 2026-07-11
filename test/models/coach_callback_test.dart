import 'package:flutter_test/flutter_test.dart';
import 'package:mindsetforge/models/coach_callback.dart';

void main() {
  group('CoachCallback', () {
    test('fromJson handles missing fields with fallbacks', () {
      final callback = CoachCallback.fromJson({
        'message': 'You skipped check-ins after logging that money fear.',
      });

      expect(callback.message, isNotEmpty);
      expect(callback.valence, 'regression');
      expect(callback.confidence, 0);
      expect(callback.isUnseen, isTrue);
    });

    test('toJson round-trips optional timestamps', () {
      const original = CoachCallback(
        id: 'cb_1',
        message: 'Your consistency jumped after that reframe.',
        valence: 'positive',
        triggerType: 'consistency_breakthrough',
        referenceLabel: 'money belief reframe',
        referenceDate: '2026-06-30',
        measurableChange: 'active days 2/7 to 6/7',
        confidence: 0.86,
        generatedAt: '2026-07-10T12:00:00.000Z',
        seenAt: '2026-07-10T12:05:00.000Z',
      );

      final restored = CoachCallback.fromJson(original.toJson());
      expect(restored.id, original.id);
      expect(restored.valence, 'positive');
      expect(restored.isPositive, isTrue);
      expect(restored.seenAt, original.seenAt);
      expect(restored.isUnseen, isFalse);
    });

    test('copyWith preserves untouched fields', () {
      const original = CoachCallback(
        id: 'cb_1',
        message: 'Hello',
        valence: 'regression',
        triggerType: 'streak_break_belief',
        referenceLabel: 'fear',
        referenceDate: '2026-06-01',
        measurableChange: '3-day gap',
        confidence: 0.8,
        generatedAt: '2026-07-01T00:00:00.000Z',
      );

      final updated = original.copyWith(seenAt: '2026-07-02T00:00:00.000Z');
      expect(updated.message, original.message);
      expect(updated.seenAt, isNotNull);
    });
  });
}
