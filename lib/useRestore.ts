"use client";

import { useCallback, useRef, type ChangeEvent } from "react";

import { BackupError, parseBackup } from "@/lib/backup";
import { useWallet } from "@/lib/store";

/**
 * Restoring has to be reachable from wherever a returning user lands — including a wiped
 * device, where the only screen is onboarding and Settings does not exist yet. Both callers
 * render the same hidden input and share this handler.
 */
export function useRestore() {
  const { actions } = useWallet();
  const inputRef = useRef<HTMLInputElement>(null);

  const onChange = useCallback(
    (e: ChangeEvent<HTMLInputElement>) => {
      const file = e.target.files?.[0];
      e.target.value = "";
      if (!file) return;
      file
        .text()
        .then((text) => {
          const payload = parseBackup(text);
          if (payload.cards.length === 0) throw new BackupError("That backup has no cards in it.");
          actions.restore(payload);
        })
        .catch((err: unknown) => {
          actions.toast(err instanceof BackupError ? err.message : "Could not read that file.");
        });
    },
    [actions],
  );

  const open = useCallback(() => inputRef.current?.click(), []);

  return {
    open,
    inputProps: {
      ref: inputRef,
      type: "file" as const,
      accept: "application/json,.json",
      onChange,
      style: { display: "none" },
    },
  };
}
