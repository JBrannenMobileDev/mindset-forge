import 'package:flutter_test/flutter_test.dart';
import 'package:mindsetforge/models/alignment_snapshot.dart';

void main() {
  group('AlignmentSnapshot', () {
    test('fromJson handles missing fields with fallbacks', () {
      final snapshot = AlignmentSnapshot.fromJson({'date': '2026-07-10'});

      expect(snapshot.date, '2026-07-10');
      expect(snapshot.overall, 0);
      expect(snapshot.subconscious, 0);
    });

    test('toJson round-trips all layer scores', () {
      const original = AlignmentSnapshot(
        overall: 62.5,
        subconscious: 70,
        thought: 55,
        action: 60,
        results: 45,
        date: '2026-07-10',
      );

      final restored = AlignmentSnapshot.fromJson(original.toJson());
      expect(restored.overall, original.overall);
      expect(restored.thought, original.thought);
      expect(restored.date, original.date);
    });
  });
}
