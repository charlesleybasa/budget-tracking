"use client";

import type { CSSProperties } from "react";

import { Mascot } from "@/components/Mascot";
import { SpriteAnimation } from "@/components/SpriteAnimation";
import { CELEBRATE } from "@/lib/sprites";
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
      <div className={styles.art}>
        <span className={styles.spotlight} aria-hidden="true" />
        <SpriteAnimation
          sheet={CELEBRATE}
          size={168}
          className={styles.mascot}
          fallback={<Mascot mood="cheer" size={168} />}
        />
      </div>

      <div className={`${styles.copy} ${styles.copyWithArt}`}>
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
