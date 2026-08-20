"use client";

import { useEffect, useRef, useState } from "react";

import { useWallet } from "@/lib/store";
import { useBackup } from "@/lib/useBackup";

import styles from "./EraseDialog.module.css";

function plural(n: number, one: string, many: string): string {
  return `${n} ${n === 1 ? one : many}`;
}

/**
 * Confirmation for the one action in the app that cannot be undone.
 *
 * The design leans on four things rather than on friction for its own sake:
 * it names exactly what is about to be lost, it offers the backup that turns an
 * irreversible action into a reversible one, it makes the acknowledgement an explicit
 * act rather than a second tap in the same place, and it makes keeping the data the
 * default the dialog opens on. The destructive button stays inert until the box is
 * ticked, so no single stray press anywhere in this dialog can erase anything.
 *
 * It is deliberately a centred alert rather than one of the app's bottom sheets: the
 * routine sheets are for routine work, and this is not that.
 *
 * Rendered from the shell beside the other overlays, not from the settings screen: a screen
 * carries a transform for its enter animation, which makes it a stacking context, and
 * anything inside it stays under the navigation however high its z-index goes.
 */
export function EraseDialog() {
  const { state, actions } = useWallet();
  const onBackup = useBackup();
  const [acknowledged, setAcknowledged] = useState(false);
  const [backedUp, setBackedUp] = useState(false);
  const panelRef = useRef<HTMLDivElement>(null);
  const cancelRef = useRef<HTMLButtonElement>(null);

  const open = state.eraseOpen;
  const cardCount = state.cards.length;
  const txCount = state.tx.length;
  const oldestAt = txCount > 0 ? Math.min(...state.tx.map((t) => t.at)) : null;

  const onClose = () => actions.patch({ eraseOpen: false });
  const onErase = () => {
    actions.patch({ eraseOpen: false });
    actions.resetEverything();
  };

  // Opening on the safe choice means the first thing a keyboard or switch user can press
  // is the one that keeps their data.
  useEffect(() => {
    if (!open) return;
    // Each opening starts from a clean slate; a tick left over from last time would be a
    // consent the user did not give this time.
    setAcknowledged(false);
    setBackedUp(false);
    const previous = document.activeElement as HTMLElement | null;
    cancelRef.current?.focus();
    return () => previous?.focus?.();
  }, [open]);

  useEffect(() => {
    if (!open) return;
    const onKey = (e: KeyboardEvent) => {
      if (e.key === "Escape") {
        // Claim the key so the app-level handler does not also close the screen beneath.
        e.preventDefault();
        e.stopPropagation();
        onClose();
        return;
      }
      if (e.key !== "Tab") return;

      // A modal that leaks focus to the page behind it is not modal.
      const panel = panelRef.current;
      if (!panel) return;
      const focusable = [...panel.querySelectorAll<HTMLElement>("button, input, [href], [tabindex]:not([tabindex='-1'])")].filter(
        (el) => !el.hasAttribute("disabled"),
      );
      if (focusable.length === 0) return;
      const first = focusable[0];
      const last = focusable[focusable.length - 1];
      const active = document.activeElement;
      if (e.shiftKey && (active === first || !panel.contains(active))) {
        e.preventDefault();
        last.focus();
      } else if (!e.shiftKey && active === last) {
        e.preventDefault();
        first.focus();
      }
    };
    window.addEventListener("keydown", onKey, true);
    return () => window.removeEventListener("keydown", onKey, true);
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [open]);

  if (!open) return null;

  const nothingStored = cardCount === 0 && txCount === 0;
  const historyFrom =
    oldestAt === null
      ? null
      : new Date(oldestAt).toLocaleDateString(undefined, { day: "numeric", month: "long", year: "numeric" });

  return (
    <div
      data-overlay-layer
      className={styles.layer}
      role="alertdialog"
      aria-modal="true"
      aria-labelledby="erase-title"
      aria-describedby="erase-stakes"
    >
      {/* A pointer affordance only, kept out of the tab order: keyboard users already have
          Escape and the Keep button, and a focusable backdrop just adds a stop that reads
          as nothing. */}
      <button
        type="button"
        tabIndex={-1}
        className={styles.backdrop}
        onClick={onClose}
        aria-hidden="true"
      />

      <div className={styles.panel} ref={panelRef}>
        <div className={styles.mark} aria-hidden="true">
          <svg width={22} height={22} viewBox="0 0 24 24" fill="none" stroke="var(--red-deep)" strokeWidth={2.1} strokeLinecap="round">
            <path d="M4 7h16M9 7V5h6v2M6 7l1 13h10l1-13M10 11v6M14 11v6" />
          </svg>
        </div>

        <h2 className={styles.title} id="erase-title">
          Start over?
        </h2>

        <p className={styles.stakes} id="erase-stakes">
          {nothingStored ? (
            <>This clears your name and preferences and returns you to the first-run screen.</>
          ) : (
            <>
              <strong className={styles.strong}>
                {plural(cardCount, "card", "cards")} and {plural(txCount, "entry", "entries")}
              </strong>{" "}
              will be deleted from this device
              {historyFrom ? <>, including everything logged since {historyFrom}</> : null}. Pesolita keeps no copy
              anywhere else, so this cannot be undone.
            </>
          )}
        </p>

        {nothingStored ? null : (
          <button
            type="button"
            className={`${styles.backup} ${backedUp ? styles.backupDone : ""}`}
            onClick={() => setBackedUp(onBackup() || backedUp)}
          >
            <span className={styles.backupIcon} aria-hidden="true">
              {backedUp ? (
                <svg width={15} height={15} viewBox="0 0 24 24" fill="none" stroke="var(--green)" strokeWidth={2.6} strokeLinecap="round">
                  <path d="M5 13l4 4L19 7" />
                </svg>
              ) : (
                <svg width={15} height={15} viewBox="0 0 24 24" fill="none" stroke="var(--ink)" strokeWidth={2.2} strokeLinecap="round">
                  <path d="M12 4v11m0 0l-4-4m4 4l4-4M5 19h14" />
                </svg>
              )}
            </span>
            <span className={styles.backupText}>
              <span className={styles.backupLabel}>{backedUp ? "Backup saved" : "Download a backup first"}</span>
              <span className={styles.backupSub}>
                {backedUp
                  ? "You can restore it from this screen later"
                  : "One file you can restore from, if you change your mind"}
              </span>
            </span>
          </button>
        )}

        <label className={styles.ack}>
          <input
            type="checkbox"
            className={styles.ackBox}
            checked={acknowledged}
            onChange={(e) => setAcknowledged(e.target.checked)}
          />
          <span className={styles.ackTick} aria-hidden="true">
            <svg width={12} height={12} viewBox="0 0 24 24" fill="none" stroke="#fff" strokeWidth={3.2} strokeLinecap="round">
              <path d="M5 13l4 4L19 7" />
            </svg>
          </span>
          <span className={styles.ackText}>I understand this permanently erases my wallet.</span>
        </label>

        <div className={styles.actions}>
          <button type="button" className={styles.keep} onClick={onClose} ref={cancelRef}>
            Keep my data
          </button>
          <button
            type="button"
            className={styles.erase}
            onClick={onErase}
            disabled={!acknowledged}
            aria-describedby="erase-gate"
          >
            Erase everything
          </button>
        </div>

        <p className={styles.gate} id="erase-gate" aria-live="polite">
          {acknowledged ? "Erasing is now enabled." : "Tick the box above to enable erasing."}
        </p>
      </div>
    </div>
  );
}
