"use client";

import { useEffect } from "react";

import { CardArtFor } from "@/components/CardArt";
import { cardTheme } from "@/components/cardTheme";
import { minusIfNegative, peso } from "@/lib/format";
import { maskFor } from "@/lib/selectors";
import type { Card } from "@/lib/types";

import styles from "./CardPicker.module.css";

/**
 * Choosing a card is a decision about which pocket the money moves through, so it shows the
 * real card — its art, its name, what is actually in it — rather than a name in a chip. The
 * cards deal upward in sequence, which is also what makes the list readable as a wallet.
 */
export function CardPicker({
  cards,
  selectedId,
  title,
  disabledId,
  onSelect,
  onClose,
}: {
  cards: readonly Card[];
  selectedId: string;
  title: string;
  /** A card that cannot be chosen here — the other end of a move. */
  disabledId?: string;
  onSelect: (id: string) => void;
  onClose: () => void;
}) {
  useEffect(() => {
    const onKey = (e: KeyboardEvent) => {
      if (e.key !== "Escape") return;
      // Claim the key so the app-level handler does not also close the layer beneath.
      e.preventDefault();
      e.stopPropagation();
      onClose();
    };
    window.addEventListener("keydown", onKey, true);
    return () => window.removeEventListener("keydown", onKey, true);
  }, [onClose]);

  return (
    <div data-overlay-layer className={styles.layer} role="dialog" aria-modal="true" aria-label={title}>
      <button type="button" className={styles.backdrop} onClick={onClose} aria-label="Close" />

      <div className={styles.panel}>
        <div className={styles.grabberRow}>
          <div className={styles.grabber} />
        </div>

        <div className={styles.head}>
          <h2 className={styles.title}>{title}</h2>
          <button type="button" className={styles.close} onClick={onClose} aria-label="Close">
            <svg width={14} height={14} viewBox="0 0 24 24" fill="none" stroke="#0b0b0c" strokeWidth={2.6} strokeLinecap="round">
              <path d="M18 6L6 18M6 6l12 12" />
            </svg>
          </button>
        </div>

        <div className={styles.list}>
          {cards.map((card, i) => {
            const theme = cardTheme(card.art);
            const selected = card.id === selectedId;
            const disabled = card.id === disabledId;
            return (
              <button
                key={card.id}
                type="button"
                className={`${styles.item} ${selected ? styles.selected : ""}`}
                style={{ animationDelay: `${(i * 0.045).toFixed(3)}s` }}
                onClick={() => !disabled && onSelect(card.id)}
                disabled={disabled}
                aria-current={selected ? "true" : undefined}
              >
                <span className={styles.art} style={{ background: card.art.c1 }}>
                  <CardArtFor card={card} w={74} h={47} r={9} />
                  <span className={styles.artNick} style={{ color: theme.fg }}>
                    {card.nick.slice(0, 1).toUpperCase()}
                  </span>
                </span>

                <span className={styles.meta}>
                  <span className={styles.nick}>{card.nick}</span>
                  <span className={styles.sub}>
                    {disabled ? "Already the other side of this move" : `${card.kind} · ${maskFor(card)}`}
                  </span>
                </span>

                <span className={styles.balance}>
                  {minusIfNegative(card.bal)}₱{peso(card.bal)}
                </span>

                {selected ? (
                  <span className={styles.tick} aria-hidden="true">
                    <svg width={13} height={13} viewBox="0 0 24 24" fill="none" stroke="#fff" strokeWidth={3} strokeLinecap="round">
                      <path d="M5 13l4 4L19 7" />
                    </svg>
                  </span>
                ) : null}
              </button>
            );
          })}
        </div>
      </div>
    </div>
  );
}
