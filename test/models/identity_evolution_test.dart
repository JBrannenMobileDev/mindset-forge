import 'package:flutter_test/flutter_test.dart';
import 'package:mindsetforge/core/utils/identity_evolution.dart';
import 'package:mindsetforge/models/deep_dive.dart';
import 'package:mindsetforge/models/evidence_entry.dart';
import 'package:mindsetforge/models/goal.dart';
import 'package:mindsetforge/models/identity_version.dart';
import 'package:mindsetforge/models/mindset_blueprint.dart';
import 'package:mindsetforge/models/user_profile.dart';

UserProfile _profile({
  String identityStatement = 'I am becoming stronger every day.',
  String? lastIdentityEvolvedAt,
  String? identityEvolveNudgeDismissedAt,
  DateTime? createdAt,
  List<IdentityVersion> identityHistory = const [],
  List<Goal> goals = const [],
  String? mindsetBlueprintSnapshotAt,
}) {
  return UserProfile(
    uid: 'u1',
    email: 'a@b.com',
    displayName: 'Test',
    mindsetBlueprint: const MindsetBlueprint(),
    originalMindsetBaseline: const MindsetBlueprint(),
    deepDive: DeepDive.initial(),
    identityStatement: identityStatement,
    lastIdentityEvolvedAt: lastIdentityEvolvedAt,
    identityEvolveNudgeDismissedAt: identityEvolveNudgeDismissedAt,
    identityHistory: identityHistory,
    goals: goals,
    mindsetBlueprintSnapshotAt: mindsetBlueprintSnapshotAt,
    createdAt: createdAt ?? DateTime.now().subtract(const Duration(days: 45)),
  );
}

void main() {
  group('IdentityVersion', () {
    test('round-trips through json', () {
      const version = IdentityVersion(
        statement: 'I am a builder who ships daily.',
        createdAt: '2026-01-01T00:00:00.000Z',
        source: 'onboarding',
        rationale: 'Starting point',
      );

      final restored = IdentityVersion.fromJson(version.toJson());
      expect(restored.statement, version.statement);
      expect(restored.createdAt, version.createdAt);
      expect(restored.source, version.source);
      expect(restored.rationale, version.rationale);
    });
  });

  group('IdentityEvolution', () {
    test('isDue after 30 days without evolution', () {
      final profile = _profile(
        createdAt: DateTime.now().subtract(const Duration(days: 45)),
      );
      expect(IdentityEvolution.isDue(profile), isTrue);
    });

    test('isDue when goal completed since last evolve', () {
      final lastEvolve = DateTime.now().subtract(const Duration(days: 5));
      final profile = _profile(
        lastIdentityEvolvedAt: lastEvolve.toIso8601String(),
        createdAt: DateTime.now().subtract(const Duration(days: 60)),
        goals: [
          Goal(
            id: 'g1',
            title: 'Run a 5K',
            category: 'health',
            status: 'completed',
            completedAt: DateTime.now().subtract(const Duration(days: 1)),
            createdAt: DateTime.now().subtract(const Duration(days: 90)),
            targetDate: DateTime.now().add(const Duration(days: 30)),
          ),
        ],
      );
      expect(IdentityEvolution.isDue(profile), isTrue);
    });

    test('shouldShowNudge respects dismissal until new milestone', () {
      final lastEvolve = DateTime.now().subtract(const Duration(days: 5));
      final dismissed = DateTime.now().subtract(const Duration(days: 2));
      final profile = _profile(
        lastIdentityEvolvedAt: lastEvolve.toIso8601String(),
        identityEvolveNudgeDismissedAt: dismissed.toIso8601String(),
        createdAt: DateTime.now().subtract(const Duration(days: 60)),
      );
      expect(IdentityEvolution.shouldShowNudge(profile), isFalse);
    });

    test('appendHistory caps at historyMax', () {
      final versions = List.generate(
        IdentityVersion.historyMax + 2,
        (i) => IdentityVersion(
          statement: 'Version $i',
          createdAt:
              '2026-01-${(i + 1).toString().padLeft(2, '0')}T00:00:00.000Z',
        ),
      );

      final capped = IdentityEvolution.appendHistory(
        versions.take(IdentityVersion.historyMax).toList(),
        versions.last,
      );
      expect(capped.length, IdentityVersion.historyMax);
      expect(capped.last.statement, versions.last.statement);
    });

    test('dailyProofLine returns evidence content when available', () {
      final profile = _profile().copyWith(
        evidenceLog: [
          EvidenceEntry(
            id: 'e1',
            content: 'Showed up for morning workout',
            createdAt: DateTime.now(),
          ),
        ],
      );

      expect(
        IdentityEvolution.dailyProofLine(profile),
        'Showed up for morning workout',
      );
    });
  });
}
