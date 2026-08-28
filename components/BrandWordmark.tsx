import { MascotMark } from "@/components/MascotMark";

import styles from "./BrandWordmark.module.css";

export function BrandWordmark({
  size = "medium",
  tone = "onDark",
  showMark = true,
  className = "",
}: {
  size?: "small" | "medium" | "large";
  tone?: "onDark" | "onLight";
  showMark?: boolean;
  className?: string;
}) {
  return (
    <span
      className={`${styles.wordmark} ${styles[size]} ${tone === "onLight" ? styles.onLight : ""} ${className}`}
    >
      {showMark ? (
        <span className={styles.mark}>
          <MascotMark />
        </span>
      ) : null}
      <span className={styles.text} aria-label="Pesolita">
        <span className={styles.peso}>Peso</span>
        <span className={styles.lita}>lita</span>
      </span>
    </span>
  );
}
