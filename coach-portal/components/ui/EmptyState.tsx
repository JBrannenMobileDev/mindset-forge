import { ReactNode } from "react";

interface EmptyStateProps {
  icon?: ReactNode;
  title: string;
  subtitle?: string;
  action?: ReactNode;
  className?: string;
}

export function EmptyState({ icon, title, subtitle, action, className = "" }: EmptyStateProps) {
  return (
    <div
      className={`flex flex-col items-center justify-center rounded-2xl border border-border bg-surface-elevated px-8 py-14 text-center ${className}`}
    >
      {icon && (
        <div className="mb-4 flex h-14 w-14 items-center justify-center rounded-full bg-primary-container text-primary">
          {icon}
        </div>
      )}
      <h3 className="font-display text-lg font-semibold text-text-primary">{title}</h3>
      {subtitle && <p className="mt-2 max-w-sm text-sm text-text-secondary">{subtitle}</p>}
      {action && <div className="mt-6">{action}</div>}
    </div>
  );
}
