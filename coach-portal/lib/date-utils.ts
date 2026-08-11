/**
 * Calendar-day helpers for 'YYYY-MM-DD' keys.
 *
 * `lastEntryAt`, schedule dates, and `usedDates` are day keys, not timestamps.
 * Building Dates from explicit Y/M/D parts (instead of `new Date(dayKey)`, which
 * parses as UTC midnight) avoids an off-by-one day in negative-offset timezones.
 */

/**
 * Midnight to 4 AM still counts as the previous day.
 *
 * The app resolves "today" with `AppDateUtils.todayStringWithGracePeriod()` and
 * the summary trigger stamps `date` the same way, because that is the day
 * boundary every streak and `journalCompleted` flag already uses. Without this,
 * a coach looking at the portal at 1 AM would see tomorrow's prompt labelled as
 * today's while players were still on yesterday's, and "wrote today" would read
 * zero for four hours every night.
 */
const DAY_GRACE_PERIOD_MS = 4 * 60 * 60 * 1000;

/** "Now" shifted into the active day, which is what every default below uses. */
function activeNow(): Date {
  return new Date(Date.now() - DAY_GRACE_PERIOD_MS);
}

export function toDayKey(date: Date): string {
  const y = date.getFullYear();
  const m = String(date.getMonth() + 1).padStart(2, "0");
  const d = String(date.getDate()).padStart(2, "0");
  return `${y}-${m}-${d}`;
}

export function dayKeyToDate(dayKey: string): Date | null {
  const [y, m, d] = dayKey.split("-").map(Number);
  if (!y || !m || !d) return null;
  return new Date(y, m - 1, d);
}

export function formatDayKey(dayKey: string | null, emptyLabel = "None"): string {
  if (!dayKey) return emptyLabel;
  const date = dayKeyToDate(dayKey);
  if (!date) return dayKey;
  return date.toLocaleDateString(undefined, {
    month: "short",
    day: "numeric",
    year: "numeric",
  });
}

export function formatWeekday(dayKey: string): string {
  const date = dayKeyToDate(dayKey);
  if (!date) return "";
  return date.toLocaleDateString(undefined, { weekday: "short" });
}

/** Next `count` calendar days starting from the current active day. */
export function upcomingDayKeys(count: number, from: Date = activeNow()): string[] {
  const start = new Date(from.getFullYear(), from.getMonth(), from.getDate());
  return Array.from({ length: count }, (_, i) => {
    const d = new Date(start.getFullYear(), start.getMonth(), start.getDate() + i);
    return toDayKey(d);
  });
}

/** The active day, matching the app's 4 AM to 4 AM day. */
export function todayDayKey(from: Date = activeNow()): string {
  return toDayKey(from);
}

/** Previous `count` days ending on the current active day (inclusive). */
export function pastDayKeys(count: number, from: Date = activeNow()): string[] {
  const end = new Date(from.getFullYear(), from.getMonth(), from.getDate());
  return Array.from({ length: count }, (_, i) => {
    const d = new Date(end.getFullYear(), end.getMonth(), end.getDate() - (count - 1 - i));
    return toDayKey(d);
  });
}

/** Whole days from `from` to `to` (both YYYY-MM-DD). Positive when `to` is later. */
export function dayKeyDiff(from: string, to: string): number {
  const a = dayKeyToDate(from);
  const b = dayKeyToDate(to);
  if (!a || !b) return 0;
  return Math.round((b.getTime() - a.getTime()) / 86_400_000);
}

const ISO_WEEK_PATTERN = /^\d{4}-W(0[1-9]|[1-4]\d|5[0-3])$/;

export function isValidIsoWeek(period: string): boolean {
  return ISO_WEEK_PATTERN.test(period);
}

/** ISO week label of the current active day, e.g. `2026-W33`. */
export function currentIsoWeek(from: Date = activeNow()): string {
  const d = new Date(from.getFullYear(), from.getMonth(), from.getDate());
  d.setDate(d.getDate() + 3 - ((d.getDay() + 6) % 7));
  const week1 = new Date(d.getFullYear(), 0, 4);
  const weekNum =
    1 +
    Math.round(
      ((d.getTime() - week1.getTime()) / 86_400_000 - 3 + ((week1.getDay() + 6) % 7)) / 7,
    );
  return `${d.getFullYear()}-W${String(weekNum).padStart(2, "0")}`;
}

export function formatReportPeriod(periodStart: string, periodEnd: string): string {
  const start = formatDayKey(periodStart);
  const end = formatDayKey(periodEnd);
  return `${start} to ${end}`;
}

/** Extract YYYY-MM-DD for `<input type="date">` from an ISO timestamp or day key. */
export function toDateInputValue(isoOrDayKey: string): string {
  if (/^\d{4}-\d{2}-\d{2}/.test(isoOrDayKey)) return isoOrDayKey.slice(0, 10);
  const parsed = Date.parse(isoOrDayKey);
  if (Number.isNaN(parsed)) return "";
  return toDayKey(new Date(parsed));
}
