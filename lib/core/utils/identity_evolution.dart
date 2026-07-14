import '../../models/identity_version.dart';
import '../../models/user_profile.dart';

/// Proposed identity evolution from AI (not yet persisted).
class IdentityEvolutionProposal {
  final String statement;
  final String rationale;

  const IdentityEvolutionProposal({
    required this.statement,
    required this.rationale,
  });
}

/// Milestone reasons that can trigger an identity evolution nudge.
enum IdentityEvolveReason {
  timeElapsed,
  blueprintReassessed,
  goalCompleted,
}

/// Pure helpers for deciding when the identity statement should evolve.
abstract final class IdentityEvolution {
  static const int daysBetweenEvolutions = 30;

  /// ISO timestamp of the last identity change (evolve or manual edit with history).
  static DateTime lastChangedAt(UserProfile profile) {
    if (profile.lastIdentityEvolvedAt != null) {
      final parsed = DateTime.tryParse(profile.lastIdentityEvolvedAt!);
      if (parsed != null) return parsed;
    }
    return profile.createdAt;
  }

  /// Returns active milestone reasons since [since], or since last change when null.
  static List<IdentityEvolveReason> activeReasons(
    UserProfile profile, {
    DateTime? since,
  }) {
    final anchor = since ?? lastChangedAt(profile);
    final reasons = <IdentityEvolveReason>[];

    if (DateTime.now().difference(anchor).inDays >= daysBetweenEvolutions) {
      reasons.add(IdentityEvolveReason.timeElapsed);
    }

    if (_blueprintReassessedSince(profile, anchor)) {
      reasons.add(IdentityEvolveReason.blueprintReassessed);
    }

    if (_goalCompletedSince(profile, anchor)) {
      reasons.add(IdentityEvolveReason.goalCompleted);
    }

    return reasons;
  }

  static bool isDue(UserProfile profile) {
    if (profile.identityStatement.trim().isEmpty) return false;
    return activeReasons(profile).isNotEmpty;
  }

  /// Whether the evolve nudge should appear (due and not dismissed for current milestones).
  static bool shouldShowNudge(UserProfile profile) {
    if (!isDue(profile)) return false;

    final dismissedAt = profile.identityEvolveNudgeDismissedAt;
    if (dismissedAt == null) return true;

    final parsed = DateTime.tryParse(dismissedAt);
    if (parsed == null) return true;

    // Show again only if a new milestone fired after dismissal.
    return activeReasons(profile, since: parsed).isNotEmpty;
  }

  static bool _blueprintReassessedSince(UserProfile profile, DateTime since) {
    final snapshotAt = profile.mindsetBlueprintSnapshotAt;
    if (snapshotAt != null) {
      final parsed = DateTime.tryParse(snapshotAt);
      if (parsed != null && parsed.isAfter(since)) return true;
    }

    for (final snap in profile.blueprintSnapshotHistory) {
      final parsed = DateTime.tryParse(snap.createdAt);
      if (parsed != null && parsed.isAfter(since)) return true;
    }

    final recalculated = profile.blueprintLastRecalculatedAt;
    if (recalculated != null) {
      final parsed = DateTime.tryParse(recalculated);
      if (parsed != null && parsed.isAfter(since)) return true;
    }

    return false;
  }

  static bool _goalCompletedSince(UserProfile profile, DateTime since) {
    for (final goal in profile.goals) {
      if (goal.status != 'completed') continue;
      final completedAt = goal.completedAt;
      if (completedAt != null && completedAt.isAfter(since)) return true;
    }
    return false;
  }

  /// Appends [version] to history, capping at [IdentityVersion.historyMax].
  static List<IdentityVersion> appendHistory(
    List<IdentityVersion> history,
    IdentityVersion version,
  ) {
    final updated = [...history, version];
    if (updated.length <= IdentityVersion.historyMax) return updated;
    return updated.sublist(updated.length - IdentityVersion.historyMax);
  }

  /// Rotating proof line for the daily identity read ritual.
  static String dailyProofLine(UserProfile profile) {
    final options = <String>[];

    for (final entry in profile.evidenceLog.reversed.take(10)) {
      final content = entry.content.trim();
      if (content.isNotEmpty) options.add(content);
    }

    final recentGoals = profile.goals
        .where((g) => g.status == 'completed' && g.completedAt != null)
        .toList()
      ..sort((a, b) => b.completedAt!.compareTo(a.completedAt!));
    for (final goal in recentGoals.take(3)) {
      options.add('Completed: ${goal.title}');
    }

    if (profile.currentStreak >= 3) {
      options.add('${profile.currentStreak}-day streak of showing up');
    }

    if (options.isEmpty) return '';
    final dayIndex = DateTime.now().difference(
      DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day),
    ).inDays;
    return options[dayIndex % options.length];
  }

  /// Rotates framing copy for the daily read so repetition stays fresh.
  static int dailyFramingIndex() {
    final dayOfYear = DateTime.now().difference(
      DateTime(DateTime.now().year),
    ).inDays;
    return dayOfYear % 4;
  }
}
