"use client";

import { useEffect } from "react";

import styles from "./ReceiptViewer.module.css";

/** Full-screen look at a saved receipt. Escape and the backdrop both close it. */
export function ReceiptViewer({ src, merchant, onClose }: { src: string; merchant: string; onClose: () => void }) {
  useEffect(() => {
    const onKey = (e: KeyboardEvent) => {
      if (e.key === "Escape") {
        // Claim the key so the app-level handler does not also close the layer beneath.
        e.preventDefault();
        e.stopPropagation();
        onClose();
      }
    };
    window.addEventListener("keydown", onKey, true);
    return () => window.removeEventListener("keydown", onKey, true);
  }, [onClose]);

  return (
    <div data-overlay-layer className={styles.layer} role="dialog" aria-modal="true" aria-label={`Receipt for ${merchant}`}>
      <button type="button" className={styles.backdrop} onClick={onClose} aria-label="Close receipt" />

      <div className={styles.panel}>
        <div className={styles.head}>
          <div className={styles.title}>{merchant}</div>
          <button type="button" className={styles.close} onClick={onClose} aria-label="Close">
            <svg width={15} height={15} viewBox="0 0 24 24" fill="none" stroke="#fff" strokeWidth={2.6} strokeLinecap="round">
              <path d="M18 6L6 18M6 6l12 12" />
            </svg>
          </button>
        </div>
        {/* eslint-disable-next-line @next/next/no-img-element */}
        <img className={styles.image} src={src} alt={`Receipt for ${merchant}`} />
      </div>
    </div>
  );
}
