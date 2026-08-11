import type { ThemeCount } from "@/lib/summary-utils";

type ThemeChipsProps = {
  themes: ThemeCount[];
  emptyLabel?: string;
  className?: string;
};

export function ThemeChips({
  themes,
  emptyLabel = "No themes recorded yet.",
  className = "",
}: ThemeChipsProps) {
  if (themes.length === 0) {
    return <p className={`text-sm text-text-secondary ${className}`}>{emptyLabel}</p>;
  }

  return (
    <div className={`flex flex-wrap gap-2 ${className}`}>
      {themes.map(({ theme, count }) => (
        <span
          key={theme}
          className="inline-flex items-center gap-1.5 rounded-full border border-border bg-surface-elevated px-3 py-1.5 text-xs font-semibold text-text-secondary"
        >
          {theme}
          <span className="rounded-full bg-primary-container px-1.5 py-0.5 text-primary">
            {count}
          </span>
        </span>
      ))}
    </div>
  );
}
