"use client";

import { useWallet } from "@/lib/store";

import styles from "./Toast.module.css";

export function Toast() {
  const { state } = useWallet();
  if (!state.toast) return null;
  // Keyed on the message so a new toast restarts the animation rather than resuming it.
  return (
    <div key={state.toast} className={styles.toast} role="status" aria-live="polite">
      {state.toast}
    </div>
  );
}
