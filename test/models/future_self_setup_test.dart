import 'package:flutter_test/flutter_test.dart';
import 'package:mindsetforge/models/future_self_setup.dart';

void main() {
  group('FutureSelfScene', () {
    test('round-trips through json with all fields', () {
      final scene = FutureSelfScene(
        id: 'abc',
        title: 'Morning in my dream home',
        setting: 'The kitchen, early morning',
        people: 'My wife, my kids',
        beats: const ['Wake up rested', 'Meditate', 'Make coffee'],
        sensory: 'Warm light, smell of coffee',
        goalIds: const ['g1', 'g2'],
        customAccomplishments: const ['Sold the company'],
        script: 'I am here...',
        scriptHash: 'hash123',
        narrationUrl: 'https://example.com/a.mp3',
        narrationVoice: 'en-US-Chirp3-HD-Aoede',
        createdAt: DateTime.parse('2026-01-01T08:00:00.000Z'),
      );

      final restored = FutureSelfScene.fromJson(scene.toJson());

      expect(restored.id, 'abc');
      expect(restored.title, 'Morning in my dream home');
      expect(restored.setting, 'The kitchen, early morning');
      expect(restored.people, 'My wife, my kids');
      expect(restored.beats, ['Wake up rested', 'Meditate', 'Make coffee']);
      expect(restored.sensory, 'Warm light, smell of coffee');
      expect(restored.goalIds, ['g1', 'g2']);
      expect(restored.customAccomplishments, ['Sold the company']);
      expect(restored.script, 'I am here...');
      expect(restored.scriptHash, 'hash123');
      expect(restored.narrationUrl, 'https://example.com/a.mp3');
      expect(restored.narrationVoice, 'en-US-Chirp3-HD-Aoede');
      expect(restored.createdAt, DateTime.parse('2026-01-01T08:00:00.000Z'));
    });

    test('fromJson uses safe fallbacks for missing fields', () {
      final scene = FutureSelfScene.fromJson({'id': 'x'});
      expect(scene.id, 'x');
      expect(scene.title, '');
      expect(scene.beats, isEmpty);
      expect(scene.goalIds, isEmpty);
      expect(scene.customAccomplishments, isEmpty);
      expect(scene.framing, 'timeOfDay');
      expect(scene.focus, '');
      expect(scene.script, isNull);
      expect(scene.hasScript, isFalse);
      expect(scene.hasNarration, isFalse);
    });

    test('displayTitle prefers title, falls back to legacy label then Scene', () {
      final base = FutureSelfScene(id: 'x', createdAt: DateTime(2026));
      expect(base.displayTitle, 'Scene');
      expect(base.copyWith(focusLabel: 'Morning').displayTitle, 'Morning');
      expect(base.copyWith(title: 'My scene').displayTitle, 'My scene');
    });

    test('hasScript / hasNarration reflect presence of content', () {
      final base = FutureSelfScene(id: 'x', createdAt: DateTime(2026));
      expect(base.hasScript, isFalse);
      expect(base.copyWith(script: '  ').hasScript, isFalse);
      expect(base.copyWith(script: 'text').hasScript, isTrue);
      expect(base.copyWith(narrationUrl: 'https://a').hasNarration, isTrue);
    });
  });

  group('FutureSelfSceneTemplates', () {
    test('all templates have a key, label, and at least a few beats', () {
      expect(FutureSelfSceneTemplates.all, isNotEmpty);
      for (final t in FutureSelfSceneTemplates.all) {
        expect(t.key, isNotEmpty);
        expect(t.label, isNotEmpty);
        expect(t.beats.length, greaterThanOrEqualTo(3));
      }
    });
  });

  group('FutureSelfSetup', () {
    test('round-trips a scene library through json', () {
      final setup = FutureSelfSetup(
        identityAnchor: 'builds calmly',
        emotionalTone: 'Calm',
        amplifiers: const ['Focused', 'Decisive'],
        scenes: [
          FutureSelfScene(
            id: '1',
            title: 'Morning',
            beats: const ['Wake', 'Coffee'],
            script: 'a',
            createdAt: DateTime(2026, 1, 1),
          ),
          FutureSelfScene(
            id: '2',
            title: 'Dinner party',
            createdAt: DateTime(2026, 1, 2),
          ),
        ],
        createdAt: DateTime(2026, 1, 1),
      );

      final restored = FutureSelfSetup.fromJson(setup.toJson());
      expect(restored.scenes.length, 2);
      expect(restored.scenes.first.id, '1');
      expect(restored.scenes.first.beats, ['Wake', 'Coffee']);
      expect(restored.scenes[1].title, 'Dinner party');
      expect(restored.hasPractice, isTrue);
      expect(restored.amplifiers, ['Focused', 'Decisive']);
    });

    test('hasPractice is false with no scripted scenes', () {
      final setup = FutureSelfSetup(
        scenes: [FutureSelfScene(id: '1', createdAt: DateTime(2026))],
        createdAt: DateTime(2026),
      );
      expect(setup.hasPractice, isFalse);
    });

    test('canAddScene respects the max scene limit', () {
      List<FutureSelfScene> make(int n) => List.generate(
            n,
            (i) => FutureSelfScene(id: '$i', createdAt: DateTime(2026)),
          );
      expect(
        FutureSelfSetup(scenes: make(2), createdAt: DateTime(2026)).canAddScene,
        isTrue,
      );
      expect(
        FutureSelfSetup(
          scenes: make(FutureSelfSetup.maxScenes),
          createdAt: DateTime(2026),
        ).canAddScene,
        isFalse,
      );
    });

    test('migrates a legacy generatedScript into the first scene', () {
      final json = {
        'identityAnchor': 'ships work',
        'generatedScript': 'The morning begins...',
        'createdAt': '2025-06-01T00:00:00.000Z',
      };

      final setup = FutureSelfSetup.fromJson(json);
      expect(setup.scenes.length, 1);
      expect(setup.scenes.first.script, 'The morning begins...');
      expect(setup.scenes.first.title, 'Your day');
      expect(setup.scenes.first.displayTitle, 'Your day');
      expect(setup.hasPractice, isTrue);
    });

    test('does not create a scene when there is no legacy script', () {
      final setup = FutureSelfSetup.fromJson({'identityAnchor': 'x'});
      expect(setup.scenes, isEmpty);
      expect(setup.hasPractice, isFalse);
    });
  });
}
