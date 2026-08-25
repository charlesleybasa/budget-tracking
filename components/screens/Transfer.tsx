"use client";

import { useEffect, useState } from "react";

import { CardArtFor } from "@/components/CardArt";
import { CardPicker } from "@/components/CardPicker";
import { Keypad } from "@/components/Keypad";
import { preloadSprite } from "@/components/SpriteAnimation";
import { amountDisplay, minusIfNegative, peso, peso0 } from "@/lib/format";
import { findCard } from "@/lib/selectors";
import { CELEBRATE } from "@/lib/sprites";
import { useWallet } from "@/lib/store";

const QUICK_AMOUNTS = [500, 1000, 2500, 5000];

import styles from "./Transfer.module.css";

export function Transfer() {
  const { state, actions } = useWallet();
  const [picking, setPicking] = useState<"from" | "to" | null>(null);
  const from = findCard(state.cards, state.fromId);
  const to = findCard(state.cards, state.toId);
  const amount = parseFloat(state.amt) || 0;
  const over = !!from && amount > from.bal;
  // Moving money needs somewhere to move it from and to.
  const canTransfer = !!from && !!to && state.cards.length > 1;
  const ready = canTransfer && amount > 0 && !over && from.id !== to.id;

  useEffect(() => {
    preloadSprite(CELEBRATE);
  }, []);

  return (
    <section
      className={`${styles.screen} bwEnterUp`}
      aria-label="Move money"
    >
      <div className={styles.topInset} />

      <div className={styles.nav}>
        <button type="button" className={styles.roundBtn} onClick={() => actions.go("home")} aria-label="Cancel">
          <svg width={16} height={16} viewBox="0 0 24 24" fill="none" stroke="#fff" strokeWidth={2.6} strokeLinecap="round">
            <path d="M18 6L6 18M6 6l12 12" />
          </svg>
        </button>
        <div className={styles.navTitle}>Move money</div>
        <div className={styles.navSpacer} />
      </div>

      {!canTransfer ? (
        <div className={styles.needCards}>
          <div className={styles.needTitle}>You need two cards for this.</div>
          <p className={styles.needBody}>
            Moving money shifts it between your own pockets. Add another card and this opens up.
          </p>
          <button type="button" className={styles.needBtn} onClick={() => actions.openEditor(null)}>
            Add a card
          </button>
        </div>
      ) : (
      <>
      <div className={styles.picker}>
        <button
          type="button"
          className={styles.endpoint}
          onClick={() => setPicking("from")}
          aria-label={`Move from ${from?.nick}. Change card`}
        >
          <div className={styles.thumb} style={{ background: from?.art.c1 }}>
            {from ? <CardArtFor card={from} w={52} h={34} r={8} /> : null}
          </div>
          <div style={{ flex: 1, minWidth: 0 }}>
            <div className={styles.endpointLabel}>From</div>
            <div className={styles.endpointNick}>{from?.nick}</div>
          </div>
          <div className={styles.endpointBal}>
            {minusIfNegative(from?.bal ?? 0)}₱{peso(from?.bal ?? 0)}
          </div>
          <svg className={styles.endpointChevron} width={15} height={15} viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth={2.4} strokeLinecap="round" strokeLinejoin="round">
            <path d="M9 6l6 6-6 6" />
          </svg>
        </button>

        <div className={styles.swapRow}>
          <button
            type="button"
            className={styles.swap}
            aria-label="Swap the two cards"
            onClick={() =>
              actions.patch({ fromId: state.toId, toId: state.fromId, swapRot: state.swapRot + 180 })
            }
            style={{ transform: `rotate(${state.swapRot}deg)` }}
          >
            <svg width={17} height={17} viewBox="0 0 24 24" fill="none" stroke="#0b0b0c" strokeWidth={2.5} strokeLinecap="round">
              <path d="M8 4v16M8 20l-4-4M16 20V4M16 4l4 4" />
            </svg>
          </button>
        </div>

        <button
          type="button"
          className={styles.endpoint}
          onClick={() => setPicking("to")}
          aria-label={`Move to ${to?.nick}. Change card`}
        >
          <div className={styles.thumb} style={{ background: to?.art.c1 }}>
            {to ? <CardArtFor card={to} w={52} h={34} r={8} /> : null}
          </div>
          <div style={{ flex: 1, minWidth: 0 }}>
            <div className={styles.endpointLabel}>To</div>
            <div className={styles.endpointNick}>{to?.nick}</div>
          </div>
          <div className={styles.endpointBal}>
            {minusIfNegative(to?.bal ?? 0)}₱{peso(to?.bal ?? 0)}
          </div>
          <svg className={styles.endpointChevron} width={15} height={15} viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth={2.4} strokeLinecap="round" strokeLinejoin="round">
            <path d="M9 6l6 6-6 6" />
          </svg>
        </button>

        <p className={styles.pickerHint}>Tap either card to choose where the money leaves and lands.</p>
      </div>

      <div className={styles.body}>
        <div className={styles.amountBlock}>
          <div className={styles.amountLabel}>Amount</div>
          <div className={styles.amountRow}>
            <span className={styles.amountPeso}>₱</span>
            <span className={styles.amountValue}>{amountDisplay(state.amt)}</span>
          </div>
          <div className={`${styles.amountHelp} ${over ? styles.amountHelpOver : ""}`}>
            {over
              ? `That is ₱${peso(amount - (from?.bal ?? 0))} more than ${from?.nick} has.`
              : `Available on ${from?.nick}: ₱${peso(from?.bal ?? 0)}`}
          </div>
          <div className={styles.quickRow}>
            {QUICK_AMOUNTS.map((value) => (
              <button
                key={value}
                type="button"
                className={styles.quick}
                onClick={() => actions.patch({ amt: String(value) })}
                disabled={value > (from?.bal ?? 0)}
              >
                ₱{peso0(value)}
              </button>
            ))}
          </div>
        </div>

        <Keypad tone="dark" />

        <div className={styles.submitWrap}>
          <button
            type="button"
            className={styles.submit}
            onClick={actions.doTransfer}
            style={{ background: ready ? "#ffca28" : "rgba(255,255,255,.16)" }}
            disabled={!ready}
          >
            Move it
          </button>
        </div>
      </div>
      </>
      )}

      {picking ? (
        <CardPicker
          cards={state.cards}
          title={picking === "from" ? "Move money from" : "Move money to"}
          selectedId={picking === "from" ? state.fromId : state.toId}
          disabledId={picking === "from" ? state.toId : state.fromId}
          onSelect={(id) => {
            actions.patch(picking === "from" ? { fromId: id } : { toId: id });
            setPicking(null);
          }}
          onClose={() => setPicking(null)}
        />
      ) : null}
    </section>
  );
}
