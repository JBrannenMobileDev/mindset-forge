import type { TeamEntrySummaryDoc } from "@/lib/types";

export type ThemeCount = { theme: string; count: number };

export type MoodPoint = { date: string; average: number; count: number };

export function filterEntriesInRange(
  entries: TeamEntrySummaryDoc[],
  start: string,
  end: string,
): TeamEntrySummaryDoc[] {
  return entries.filter((entry) => entry.date >= start && entry.date <= end);
}

export function aggregateThemes(entries: TeamEntrySummaryDoc[], limit = 10): ThemeCount[] {
  const counts = new Map<string, number>();
  for (const entry of entries) {
    for (const theme of entry.themes) {
      const label = theme.trim();
      if (!label) continue;
      counts.set(label, (counts.get(label) ?? 0) + 1);
    }
  }
  return [...counts.entries()]
    .map(([theme, count]) => ({ theme, count }))
    .sort((a, b) => b.count - a.count || a.theme.localeCompare(b.theme))
    .slice(0, limit);
}

export function averageMoodByDay(
  entries: TeamEntrySummaryDoc[],
  dayKeys: string[],
): MoodPoint[] {
  const byDay = new Map<string, { sum: number; count: number }>();
  for (const key of dayKeys) {
    byDay.set(key, { sum: 0, count: 0 });
  }
  for (const entry of entries) {
    const bucket = byDay.get(entry.date);
    if (!bucket) continue;
    bucket.sum += entry.moodScore;
    bucket.count += 1;
  }
  return dayKeys.map((date) => {
    const bucket = byDay.get(date)!;
    return {
      date,
      average: bucket.count > 0 ? bucket.sum / bucket.count : 0,
      count: bucket.count,
    };
  });
}

export function countUniquePlayersOnDate(entries: TeamEntrySummaryDoc[], date: string): number {
  const uids = new Set<string>();
  for (const entry of entries) {
    if (entry.date === date) uids.add(entry.playerUid);
  }
  return uids.size;
}

export function countPlayersWithEntriesInRange(
  entries: TeamEntrySummaryDoc[],
  start: string,
  end: string,
): number {
  const uids = new Set<string>();
  for (const entry of entries) {
    if (entry.date >= start && entry.date <= end) uids.add(entry.playerUid);
  }
  return uids.size;
}

export function countEntryDaysInRange(
  entries: TeamEntrySummaryDoc[],
  start: string,
  end: string,
): number {
  const days = new Set<string>();
  for (const entry of entries) {
    if (entry.date >= start && entry.date <= end) days.add(entry.date);
  }
  return days.size;
}

export function participationRate(daysWithEntries: number, totalDays: number): number {
  if (totalDays <= 0) return 0;
  return Math.round((daysWithEntries / totalDays) * 100);
}
