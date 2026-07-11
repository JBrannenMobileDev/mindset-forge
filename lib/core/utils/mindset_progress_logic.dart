import '../../models/mindset_item_progress.dart';

/// Tunable thresholds mirrored from server `app_config/mindset_progress`.
class MindsetProgressThresholds {
  final int minItemAgeDays;
  final int beliefJournalDistinctDays;
  final int fearJournalDistinctDays;
  final double readinessOvercomeShare;
  final int readinessMinOvercome;
  final int excavationCooldownDays;
  final int readinessMinActiveDaysPastWeek;

  const MindsetProgressThresholds({
    this.minItemAgeDays = 14,
    this.beliefJournalDistinctDays = 2,
    this.fearJournalDistinctDays = 3,
    this.readinessOvercomeShare = 0.6,
    this.readinessMinOvercome = 2,
    this.excavationCooldownDays = 30,
    this.readinessMinActiveDaysPastWeek = 3,
  });
}

bool looselyMatchesText(String a, String b) {
  final na = a.trim().toLowerCase();
  final nb = b.trim().toLowerCase();
  if (na.isEmpty || nb.isEmpty) return false;
  return na == nb || na.contains(nb) || nb.contains(na);
}

int daysSinceIso(String? iso, DateTime now) {
  if (iso == null || iso.isEmpty) return 0;
  final parsed = DateTime.tryParse(iso);
  if (parsed == null) return 0;
  return now.difference(parsed).inDays;
}

/// Whether a single journal tag is enough to graduate (never).
bool canPromoteToOvercome({
  required MindsetItemProgress item,
  required MindsetProgressThresholds thresholds,
  required DateTime now,
  bool hasRecentRegression = false,
}) {
  if (item.isOvercome) return false;
  if (hasRecentRegression) return false;
  if (daysSinceIso(item.addedAt, now) < thresholds.minItemAgeDays) {
    return false;
  }

  if (item.isBelief) {
    return item.journalSignalDays >= thresholds.beliefJournalDistinctDays &&
        item.coachCorroborated;
  }

  return item.journalSignalDays >= thresholds.fearJournalDistinctDays;
}

/// Whether the user cohort is ready for a deeper excavation offer.
bool isBlueprintEvolutionReady({
  required List<MindsetItemProgress> beliefProgress,
  required List<MindsetItemProgress> fearProgress,
  required bool blueprintCompleted,
  required bool alreadyReady,
  required String? lastExcavationAt,
  required int activeDaysPastWeek,
  required DateTime now,
  MindsetProgressThresholds thresholds = const MindsetProgressThresholds(),
}) {
  if (!blueprintCompleted || alreadyReady) return alreadyReady;

  if (daysSinceIso(lastExcavationAt, now) <
      thresholds.excavationCooldownDays) {
    return false;
  }

  if (activeDaysPastWeek < thresholds.readinessMinActiveDaysPastWeek) {
    return false;
  }

  final all = [...beliefProgress, ...fearProgress];
  if (all.isEmpty) return false;

  final overcomeCount = all.where((i) => i.isOvercome).length;
  if (overcomeCount < thresholds.readinessMinOvercome) return false;

  final share = overcomeCount / all.length;
  return share >= thresholds.readinessOvercomeShare;
}
