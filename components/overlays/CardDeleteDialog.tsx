"use client";

import { useEffect, useRef } from "react";

import { useWallet } from "@/lib/store";

import styles from "./EraseDialog.module.css";

function entriesLabel(count: number): string {
  return `${count} ${count === 1 ? "history entry" : "history entries"}`;
}

/** A focused, reversible first step before the editor's destructive delete action. */
export function CardDeleteDialog() {
  const { state, actions } = useWallet();
  const panelRef = useRef<HTMLDivElement>(null);
  const cancelRef = useRef<HTMLButtonElement>(null);
  const open = state.cardDeleteOpen;
  const card = state.ed;
  const entryCount = card ? state.tx.filter((tx) => tx.cardId === card.id).length : 0;

  const onClose = () => actions.patch({ cardDeleteOpen: false });

  useEffect(() => {
    if (!open) return;
    const previous = document.activeElement as HTMLElement | null;
    cancelRef.current?.focus();

    const onKey = (event: KeyboardEvent) => {
      if (event.key === "Escape") {
        event.preventDefault();
        event.stopPropagation();
        actions.patch({ cardDeleteOpen: false });
        return;
      }
      if (event.key !== "Tab") return;

      const panel = panelRef.current;
      if (!panel) return;
      const focusable = [...panel.querySelectorAll<HTMLElement>("button, [href], [tabindex]:not([tabindex='-1'])")].filter(
        (element) => !element.hasAttribute("disabled"),
      );
      if (focusable.length === 0) return;
      const first = focusable[0];
      const last = focusable[focusable.length - 1];
      const active = document.activeElement;
      if (event.shiftKey && (active === first || !panel.contains(active))) {
        event.preventDefault();
        last.focus();
      } else if (!event.shiftKey && active === last) {
        event.preventDefault();
        first.focus();
      }
    };

    window.addEventListener("keydown", onKey, true);
    return () => {
      window.removeEventListener("keydown", onKey, true);
      previous?.focus?.();
    };
  }, [open, actions]);

  if (!open || !card) return null;

  return (
    <div
      data-overlay-layer
      className={styles.layer}
      role="alertdialog"
      aria-modal="true"
      aria-labelledby="delete-card-title"
      aria-describedby="delete-card-stakes"
    >
      <button
        type="button"
        tabIndex={-1}
        className={styles.backdrop}
        onClick={onClose}
        aria-hidden="true"
      />

      <div className={styles.panel} ref={panelRef}>
        <div className={styles.mark} aria-hidden="true">
          <svg
            width={22}
            height={22}
            viewBox="0 0 24 24"
            fill="none"
            stroke="var(--red-deep)"
            strokeWidth={2.1}
            strokeLinecap="round"
          >
            <path d="M4 7h16M9 7V5h6v2M6 7l1 13h10l1-13M10 11v6M14 11v6" />
          </svg>
        </div>

        <h2 className={styles.title} id="delete-card-title">
          Delete {card.nick}?
        </h2>
        <p className={styles.stakes} id="delete-card-stakes">
          {entryCount > 0 ? (
            <>
              This removes the card and <strong className={styles.strong}>{entriesLabel(entryCount)}</strong> from
              this device.
            </>
          ) : (
            <>This removes the card from your wallet.</>
          )}{" "}
          This cannot be undone.
        </p>

        <div className={styles.actions}>
          <button type="button" className={styles.keep} onClick={onClose} ref={cancelRef}>
            Keep card
          </button>
          <button type="button" className={styles.erase} onClick={actions.deleteCard}>
            Delete card
          </button>
        </div>
      </div>
    </div>
  );
}
