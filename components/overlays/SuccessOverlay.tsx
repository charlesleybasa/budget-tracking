"use client";

import type { CSSProperties } from "react";

import { useWallet } from "@/lib/store";

import styles from "./SuccessOverlay.module.css";

const CONFETTI_COLORS = ["#ffca28", "#f4eedc", "#f9a8b4", "#ffffff"];
const PIECES = 22;

function Confetti() {
  return (
    <div className={styles.confetti} aria-hidden="true">
      {Array.from({ length: PIECES }).map((_, i) => {
        const angle = (i / PIECES) * Math.PI * 2;
        const distance = 150 + (i % 5) * 46;
        return (
          <span
            key={i}
            className={styles.piece}
            style={
              {
                borderRadius: i % 3 ? 100 : 2,
                background: CONFETTI_COLORS[i % 4],
                "--bwX": `${Math.cos(angle) * distance}px`,
                "--bwY": `${Math.sin(angle) * distance}px`,
                "--bwR": `${i * 47}deg`,
                animationDelay: `${((i % 6) * 0.035).toFixed(3)}s`,
              } as CSSProperties
            }
          />
        );
      })}
    </div>
  );
}

export function SuccessOverlay() {
  const { state, actions } = useWallet();
  if (!state.success) return null;

  return (
    <div className={styles.screen} role="dialog" aria-modal="true" aria-label={state.success.head}>
      <Confetti />

      <div className={styles.art} aria-hidden="true">
        <div className={styles.face} />
        <div className={styles.eye} style={{ left: 34 }} />
        <div className={styles.eye} style={{ left: 62 }} />
        <div className={styles.mouth} />
        <div className={styles.coin} />
        <div className={styles.tile} />
      </div>

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
