import { ReactNode } from "react";

interface CardProps {
  children: ReactNode;
  className?: string;
  glow?: boolean;
}

export function Card({ children, className = "", glow = false }: CardProps) {
  return (
    <div
      className={`rounded-2xl border border-border bg-surface-elevated p-6 ${
        glow ? "border-primary/30 shadow-[0_0_36px_rgba(155,64,255,0.16)]" : ""
      } ${className}`}
    >
      {children}
    </div>
  );
}
