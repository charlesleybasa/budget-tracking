"use client";

import { categoryColor } from "@/lib/constants";
import { merchantInitial, signedPeso } from "@/lib/format";
import type { Transaction } from "@/lib/types";

import styles from "./TxRow.module.css";

export interface TxRowProps {
  tx: Transaction;
  cardNick: string;
  variant: "home" | "detail" | "search";
  /** Stagger index for the entrance. */
  index?: number;
  onClick: () => void;
}

export function TxRow({ tx, cardNick, variant, index = 0, onClick }: TxRowProps) {
  const incoming = tx.amount > 0;
  const color = categoryColor(tx.cat);

  const meta =
    variant === "search"
      ? [tx.cat, cardNick, tx.note].filter(Boolean).join(" · ")
      : [tx.cat, tx.note].filter(Boolean).join(" · ");

  const border =
    variant === "detail" ? styles.bordered : variant === "search" ? styles.borderedSoft : "";

  return (
    <button
      type="button"
      className={`${styles.row} ${border}`}
      onClick={onClick}
      style={{ animationDelay: `${(index * 0.045).toFixed(3)}s` }}
    >
      <div
        className={`${styles.avatar} ${variant === "home" ? styles.avatarLarge : styles.avatarSmall}`}
        style={{
          background: incoming ? "#e7f6ee" : `${color}1f`,
          color: incoming ? "#0b8f6a" : color,
        }}
      >
        {merchantInitial(tx.merchant)}
      </div>

      <div className={styles.body}>
        <div className={styles.merchant}>{tx.merchant}</div>
        <div className={styles.meta}>{meta}</div>
      </div>

      <div className={styles.amountBlock}>
        <div className={styles.amount} style={{ color: incoming ? "#0b8f6a" : "#0b0b0c" }}>
          {signedPeso(tx.amount)}
        </div>
        {variant === "home" ? <div className={styles.cardNick}>{cardNick}</div> : null}
      </div>
    </button>
  );
}
