"use client";

import { useWallet } from "@/lib/store";

import styles from "./Keypad.module.css";

const KEYS = ["1", "2", "3", "4", "5", "6", "7", "8", "9", ".", "0", "del"] as const;

export function Keypad({ tone }: { tone: "light" | "dark" }) {
  const { actions } = useWallet();
  const fg = tone === "light" ? "#0b0b0c" : "#fff";

  return (
    <div className={`${styles.pad} ${tone === "light" ? styles.light : styles.dark}`}>
      {KEYS.map((key) => (
        <button
          key={key}
          type="button"
          className={styles.key}
          onClick={() => actions.pressKey(key)}
          aria-label={key === "del" ? "Delete" : key}
        >
          {key === "del" ? (
            <svg width={22} height={22} viewBox="0 0 24 24" fill="none" stroke={fg} strokeWidth={2.2} strokeLinecap="round">
              <path d="M10 5h9a2 2 0 012 2v10a2 2 0 01-2 2h-9L3 12z" />
              <path d="M18 9l-5 6M13 9l5 6" />
            </svg>
          ) : (
            key
          )}
        </button>
      ))}
    </div>
  );
}
