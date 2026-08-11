"use client";

import { ReactNode } from "react";
import { Button } from "@/components/ui/Button";
import { Card } from "@/components/ui/Card";

interface ConfirmDialogProps {
  open: boolean;
  title: string;
  description: ReactNode;
  confirmLabel?: string;
  cancelLabel?: string;
  danger?: boolean;
  isLoading?: boolean;
  error?: string | null;
  onConfirm: () => void;
  onCancel: () => void;
}

/**
 * Generic confirm modal for destructive or consequential actions (e.g.
 * removing a player). Not in the Phase 5 scaffold; added here since roster is
 * the first page that needs one and later phases (prompts, schedule) will
 * want the same pattern for their own delete/unassign actions.
 */
export function ConfirmDialog({
  open,
  title,
  description,
  confirmLabel = "Confirm",
  cancelLabel = "Cancel",
  danger = false,
  isLoading = false,
  error,
  onConfirm,
  onCancel,
}: ConfirmDialogProps) {
  if (!open) return null;

  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center bg-background/80 px-6">
      <div className="w-full max-w-sm">
        <Card className="border-border">
          <h2 className="font-display text-lg font-semibold text-text-primary">{title}</h2>
          <div className="mt-3 text-sm text-text-secondary">{description}</div>
          {error && (
            <div className="mt-4 rounded-xl border border-error/30 bg-error/10 px-4 py-3 text-sm text-error">
              {error}
            </div>
          )}
          <div className="mt-6 flex justify-end gap-3">
            <Button variant="ghost" onClick={onCancel} disabled={isLoading}>
              {cancelLabel}
            </Button>
            <Button
              variant={danger ? "danger" : "primary"}
              onClick={onConfirm}
              isLoading={isLoading}
              disabled={isLoading}
            >
              {confirmLabel}
            </Button>
          </div>
        </Card>
      </div>
    </div>
  );
}
