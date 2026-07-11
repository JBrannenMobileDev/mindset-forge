import 'package:flutter_test/flutter_test.dart';
import 'package:mindsetforge/models/mindset_item_progress.dart';

void main() {
  group('MindsetItemProgress', () {
    test('fromJson uses fallbacks for missing fields', () {
      final item = MindsetItemProgress.fromJson({
        'id': 'b1',
        'text': 'I am not enough',
      });

      expect(item.id, 'b1');
      expect(item.text, 'I am not enough');
      expect(item.kind, 'belief');
      expect(item.status, 'active');
      expect(item.journalSignalDays, 0);
      expect(item.coachCorroborated, false);
      expect(item.generation, 1);
    });

    test('toJson round trip preserves fields', () {
      const original = MindsetItemProgress(
        id: 'f1',
        text: 'Fear of Failure',
        kind: 'fear',
        status: 'softening',
        addedAt: '2026-01-01T00:00:00.000Z',
        softeningSince: '2026-01-10T00:00:00.000Z',
        journalSignalDays: 1,
        lastJournalSignalDate: '2026-01-10',
        generation: 2,
      );

      final restored = MindsetItemProgress.fromJson(original.toJson());
      expect(restored.id, original.id);
      expect(restored.text, original.text);
      expect(restored.kind, original.kind);
      expect(restored.status, original.status);
      expect(restored.generation, 2);
    });

    test('status getters', () {
      const active = MindsetItemProgress(
        id: '1',
        text: 'x',
        kind: 'belief',
        addedAt: '2026-01-01',
      );
      const overcome = MindsetItemProgress(
        id: '2',
        text: 'y',
        kind: 'fear',
        status: 'overcome',
        addedAt: '2026-01-01',
      );

      expect(active.isActive, isTrue);
      expect(active.isOvercome, isFalse);
      expect(overcome.isFear, isTrue);
      expect(overcome.isOvercome, isTrue);
    });
  });
}
