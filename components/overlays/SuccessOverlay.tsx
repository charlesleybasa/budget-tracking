"use client";

import { useWallet } from "@/lib/store";

import styles from "./SuccessOverlay.module.css";

export function SuccessOverlay() {
  const { state, actions } = useWallet();
  if (!state.success) return null;

  return (
    <div className={styles.screen} role="dialog" aria-modal="true" aria-label={state.success.head}>
      <div className={styles.copy}>
        <h2 className={styles.head}>{state.success.head}</h2>
        <p className={styles.body}>{state.success.body}</p>
      </div>

      <div className={styles.footer}>
        <button type="button" className={styles.button} onClick={actions.closeSuccess}>
          Nice, back to my cards
        </button>
      </div>
    </div>
  );
}
