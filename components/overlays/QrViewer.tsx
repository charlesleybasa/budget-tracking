"use client";

import { useEffect, useRef, useState } from "react";

import { useWallet } from "@/lib/store";
import { findCard } from "@/lib/selectors";

import styles from "./QrViewer.module.css";

/**
 * The receiving QR, as big as the screen allows.
 *
 * Every decision here follows from what this screen is actually for: another person pointing
 * their camera at it. So it is white rather than the app's ink — a scanner needs a light
 * field and a quiet zone around the code, and a white full screen also drives the panel
 * backlight up, which is what makes a code readable outdoors. It also holds a wake lock,
 * because a screen that dims halfway through being scanned is the single most annoying way
 * for this to fail.
 */
export function QrViewer() {
  const { state, actions } = useWallet();
  const [copied, setCopied] = useState(false);
  const closeRef = useRef<HTMLButtonElement>(null);

  const card = state.qrCardId ? findCard(state.cards, state.qrCardId) : undefined;
  const open = !!state.qrCardId && !!card?.qr;

  const close = () => actions.patch({ qrCardId: null });

  useEffect(() => {
    if (!open) return;
    const previous = document.activeElement as HTMLElement | null;
    closeRef.current?.focus();
    return () => previous?.focus?.();
  }, [open]);

  useEffect(() => {
    if (!open) return;
    const onKey = (e: KeyboardEvent) => {
      if (e.key !== "Escape") return;
      // Claim the key so the app-level handler does not also pop the screen underneath.
      e.preventDefault();
      e.stopPropagation();
      close();
    };
    window.addEventListener("keydown", onKey, true);
    return () => window.removeEventListener("keydown", onKey, true);
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [open]);

  // Hold the screen awake for as long as the code is up. Unsupported everywhere it is
  // unsupported — Safari before 16.4, any non-secure origin — so it is strictly a bonus and
  // never gated on.
  useEffect(() => {
    if (!open) return;
    type WakeLockSentinel = { release: () => Promise<void> };
    type WakeLockNav = { wakeLock?: { request: (t: "screen") => Promise<WakeLockSentinel> } };
    const nav = navigator as Navigator & WakeLockNav;
    if (!nav.wakeLock) return;

    let sentinel: WakeLockSentinel | null = null;
    let dropped = false;
    const acquire = () => {
      nav.wakeLock
        ?.request("screen")
        .then((s) => {
          if (dropped) void s.release();
          else sentinel = s;
        })
        .catch(() => {
          // Denied (backgrounded tab, battery saver). The QR still shows; it just may dim.
        });
    };
    acquire();

    // A lock is dropped whenever the tab is hidden, so it has to be retaken on return.
    const onVisible = () => {
      if (document.visibilityState === "visible") acquire();
    };
    document.addEventListener("visibilitychange", onVisible);

    return () => {
      dropped = true;
      document.removeEventListener("visibilitychange", onVisible);
      void sentinel?.release();
    };
  }, [open]);

  if (!open || !card?.qr) return null;

  return (
    <div
      data-overlay-layer
      className={styles.layer}
      role="dialog"
      aria-modal="true"
      aria-label={`Receiving QR for ${card.nick}`}
    >
      <div className={styles.head}>
        <div className={styles.who}>
          <span className={styles.kicker}>Scan to pay</span>
          <span className={styles.nick}>{card.nick}</span>
        </div>
        <button type="button" className={styles.close} onClick={close} aria-label="Close" ref={closeRef}>
          <svg width={17} height={17} viewBox="0 0 24 24" fill="none" stroke="#0b0b0c" strokeWidth={2.5} strokeLinecap="round">
            <path d="M18 6L6 18M6 6l12 12" />
          </svg>
        </button>
      </div>

      {/* The white plate is the quiet zone. A QR pressed to the edge of a coloured field is
          measurably harder to read, so the padding is functional, not decorative. */}
      <div className={styles.plate}>
        {/* eslint-disable-next-line @next/next/no-img-element */}
        <img className={styles.qr} src={card.qr} alt={`Receiving QR code for ${card.nick}`} draggable={false} />
      </div>

      {card.accountNumber ? (
        <button
          type="button"
          className={styles.account}
          onClick={() => {
            navigator.clipboard
              ?.writeText(card.accountNumber ?? "")
              .then(() => {
                setCopied(true);
                window.setTimeout(() => setCopied(false), 1600);
              })
              .catch(() => actions.toast("Could not copy — long-press to select it."));
          }}
        >
          <span className={styles.accountLabel}>{copied ? "Copied" : "Account number · tap to copy"}</span>
          <span className={styles.accountNumber}>{card.accountNumber}</span>
        </button>
      ) : null}

      <p className={styles.hint}>Screen stays awake while this is open.</p>
    </div>
  );
}
