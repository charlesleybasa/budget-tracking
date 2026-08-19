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
  /** Present when the entry carries a receipt; opens the viewer instead of the row action. */
  onViewReceipt?: (tx: Transaction) => void;
}

export function TxRow({ tx, cardNick, variant, index = 0, onClick, onViewReceipt }: TxRowProps) {
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

      {tx.receipt && onViewReceipt ? (
        <span
          role="button"
          tabIndex={0}
          className={styles.receipt}
          aria-label={`View receipt for ${tx.merchant}`}
          onClick={(e) => {
            e.stopPropagation();
            onViewReceipt(tx);
          }}
          onKeyDown={(e) => {
            if (e.key !== "Enter" && e.key !== " ") return;
            e.preventDefault();
            e.stopPropagation();
            onViewReceipt(tx);
          }}
        >
          <svg width={14} height={14} viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth={2.2} strokeLinecap="round">
            <rect x={3} y={5} width={18} height={14} rx={3} />
            <circle cx={12} cy={12} r={3.2} />
          </svg>
        </span>
      ) : null}

      <div className={styles.amountBlock}>
        <div className={styles.amount} style={{ color: incoming ? "#0b8f6a" : "#0b0b0c" }}>
          {signedPeso(tx.amount)}
        </div>
        {variant === "home" ? <div className={styles.cardNick}>{cardNick}</div> : null}
      </div>
    </button>
  );
}
