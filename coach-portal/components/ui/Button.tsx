import Link from "next/link";
import { ButtonHTMLAttributes, ReactNode } from "react";
import { Spinner } from "@/components/ui/Spinner";

type Variant = "primary" | "secondary" | "ghost" | "danger";
type Size = "sm" | "md" | "lg";

const base =
  "inline-flex items-center justify-center gap-2 font-semibold rounded-xl transition-all duration-200 whitespace-nowrap focus:outline-none focus-visible:ring-2 focus-visible:ring-primary/60 disabled:cursor-not-allowed disabled:opacity-50";

const sizes: Record<Size, string> = {
  sm: "h-9 px-3.5 text-sm",
  md: "h-11 px-5 text-sm",
  lg: "h-13 px-6 text-base",
};

const variants: Record<Variant, string> = {
  primary:
    "bg-primary text-white shadow-[0_0_24px_rgba(155,64,255,0.3)] hover:shadow-[0_0_32px_rgba(155,64,255,0.45)] hover:brightness-110 active:scale-[0.98]",
  secondary:
    "border border-border bg-surface-elevated text-text-primary hover:border-primary/50 hover:bg-surface-highest active:scale-[0.98]",
  ghost: "text-text-secondary hover:text-text-primary hover:bg-surface-elevated",
  danger:
    "border border-error/40 bg-error/10 text-error hover:bg-error/20 active:scale-[0.98]",
};

type CommonProps = {
  children: ReactNode;
  variant?: Variant;
  size?: Size;
  className?: string;
  isLoading?: boolean;
};

type ButtonAsButtonProps = CommonProps &
  Omit<ButtonHTMLAttributes<HTMLButtonElement>, "className"> & {
    href?: undefined;
  };

type ButtonAsLinkProps = CommonProps & {
  href: string;
  disabled?: boolean;
};

type ButtonProps = ButtonAsButtonProps | ButtonAsLinkProps;

export function Button(props: ButtonProps) {
  const { children, variant = "primary", size = "md", className = "", isLoading = false } = props;
  const classes = `${base} ${sizes[size]} ${variants[variant]} ${className}`;

  if ("href" in props && props.href) {
    const { href, disabled } = props;
    if (disabled) {
      return (
        <span className={`${classes} pointer-events-none opacity-50`} aria-disabled>
          {children}
        </span>
      );
    }
    return (
      <Link href={href} className={classes}>
        {children}
      </Link>
    );
  }

  const { disabled, ...rest } = props as ButtonAsButtonProps;
  return (
    <button type="button" disabled={disabled || isLoading} className={classes} {...rest}>
      {isLoading && <Spinner size={16} />}
      {children}
    </button>
  );
}
