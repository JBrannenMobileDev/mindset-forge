import 'package:flutter_test/flutter_test.dart';
import 'package:mindsetforge/core/constants/app_strings.dart';
import 'package:mindsetforge/features/future_self/widgets/future_self_scene_editor.dart';

void main() {
  group('SceneDraft', () {
    test('isValid requires title and flow text', () {
      const empty = SceneDraft();
      expect(empty.isValid, isFalse);

      const titleOnly = SceneDraft(title: 'Morning');
      expect(titleOnly.isValid, isFalse);

      const flowOnly = SceneDraft(flowText: 'I wake up rested.');
      expect(flowOnly.isValid, isFalse);

      const valid = SceneDraft(
        title: 'Morning',
        flowText: 'I wake up rested and make coffee.',
      );
      expect(valid.isValid, isTrue);
    });

    test('validationHint reports missing title first', () {
      const draft = SceneDraft(flowText: 'Some flow');
      expect(draft.validationHint, AppStrings.futureSelfBuilderNeedsTitle);
    });

    test('validationHint reports missing flow when title present', () {
      const draft = SceneDraft(title: 'Morning');
      expect(draft.validationHint, AppStrings.futureSelfBuilderNeedsFlow);
    });

    test('validationHint is null when valid', () {
      const draft = SceneDraft(
        title: 'Morning',
        flowText: 'I wake up rested.',
      );
      expect(draft.validationHint, isNull);
    });

    test('toJson and fromJson round-trip preserves flowText', () {
      const original = SceneDraft(
        title: 'Dream home morning',
        setting: 'Sunlit kitchen',
        people: 'My partner',
        flowText:
            'I wake up rested with light on my face. A few quiet minutes, then coffee brewing.',
        sensory: 'Warm and calm',
        goalIds: ['goal-1', 'goal-2'],
      );

      final restored = SceneDraft.fromJson(original.toJson());

      expect(restored.title, original.title);
      expect(restored.setting, original.setting);
      expect(restored.people, original.people);
      expect(restored.flowText, original.flowText);
      expect(restored.sensory, original.sensory);
      expect(restored.goalIds, original.goalIds);
    });

    test('beats holds full flow as single entry when emitted from builder logic',
        () {
      const draft = SceneDraft(
        title: 'Morning',
        flowText: '  I wake up rested.  ',
        beats: ['I wake up rested.'],
      );
      expect(draft.beats, ['I wake up rested.']);
      expect(draft.isValid, isTrue);
    });
  });
}
