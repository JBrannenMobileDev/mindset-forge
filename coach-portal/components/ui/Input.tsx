import {
  InputHTMLAttributes,
  ReactNode,
  TextareaHTMLAttributes,
  forwardRef,
} from "react";

const fieldClasses =
  "w-full rounded-xl border border-border bg-background px-4 py-3 text-sm text-text-primary outline-none transition-colors placeholder:text-text-muted focus:border-primary disabled:cursor-not-allowed disabled:opacity-50";

function FieldChrome({
  label,
  hint,
  error,
  children,
}: {
  label?: string;
  hint?: string;
  error?: string;
  children: ReactNode;
}) {
  return (
    <label className="block">
      {label && <span className="text-sm font-semibold text-text-primary">{label}</span>}
      <div className={label ? "mt-2" : ""}>{children}</div>
      {error ? (
        <p className="mt-1.5 text-xs text-error">{error}</p>
      ) : hint ? (
        <p className="mt-1.5 text-xs text-text-secondary">{hint}</p>
      ) : null}
    </label>
  );
}

type InputProps = InputHTMLAttributes<HTMLInputElement> & {
  label?: string;
  hint?: string;
  error?: string;
};

/** Styled text input matching the portal's design tokens. Missing from the Phase 5 scaffold. */
export const Input = forwardRef<HTMLInputElement, InputProps>(function Input(
  { label, hint, error, className = "", ...props },
  ref,
) {
  return (
    <FieldChrome label={label} hint={hint} error={error}>
      <input ref={ref} className={`${fieldClasses} ${className}`} {...props} />
    </FieldChrome>
  );
});

type TextareaProps = TextareaHTMLAttributes<HTMLTextAreaElement> & {
  label?: string;
  hint?: string;
  error?: string;
};

export const Textarea = forwardRef<HTMLTextAreaElement, TextareaProps>(function Textarea(
  { label, hint, error, className = "", ...props },
  ref,
) {
  return (
    <FieldChrome label={label} hint={hint} error={error}>
      <textarea ref={ref} className={`${fieldClasses} resize-none ${className}`} {...props} />
    </FieldChrome>
  );
});
