"use client";

import { useRef, useState, type ChangeEvent } from "react";

import { Keypad } from "@/components/Keypad";
import { CATEGORIES } from "@/lib/constants";
import { amountDisplay } from "@/lib/format";
import { ImageError, RECEIPT_OPTIONS, readImage } from "@/lib/image";
import { findCard, guessCategory } from "@/lib/selectors";
import { useWallet } from "@/lib/store";

// Reused rather than duplicated: this sheet is the same shape as the create-a-spend sheet
// (grabber, head, amount, category chips, note field, receipt, keypad, submit), so it draws
// from the same compiled classes instead of restating ~300 lines of near-identical CSS.
import txStyles from "./TxSheet.module.css";
import styles from "./TxEditSheet.module.css";

export function TxEditSheet() {
  const { state, actions } = useWallet();
  const receiptRef = useRef<HTMLInputElement>(null);
  const [confirmDelete, setConfirmDelete] = useState(false);

  const id = state.editingTxId;
  const original = id ? (state.tx.find((t) => t.id === id) ?? null) : null;
  if (!id || !original) return null;

  const card = findCard(state.cards, original.cardId);
  const incoming = original.amount > 0;
  const ready = parseFloat(state.amt) > 0;
  const guess = guessCategory(state.note, state.cat);

  const close = () => {
    setConfirmDelete(false);
    actions.closeTxEdit();
  };

  const onReceiptFile = (e: ChangeEvent<HTMLInputElement>) => {
    const file = e.target.files?.[0];
    e.target.value = "";
    if (!file) return;
    readImage(file, RECEIPT_OPTIONS)
      .then((receipt) => {
        actions.patch({ receipt });
        actions.toast("Receipt attached.");
      })
      .catch((err: unknown) => {
        actions.toast(err instanceof ImageError ? err.message : "Could not attach that photo.");
      });
  };

  return (
    <div className={txStyles.layer} role="dialog" aria-modal="true" aria-label="Edit entry">
      <button type="button" className={txStyles.backdrop} onClick={close} aria-label="Close" />

      <input
        ref={receiptRef}
        type="file"
        accept="image/*"
        capture="environment"
        onChange={onReceiptFile}
        style={{ display: "none" }}
      />

      <div className={txStyles.panel}>
        <div className={txStyles.grabberRow}>
          <div className={txStyles.grabber} />
        </div>

        <div className={txStyles.head}>
          <h2 className={txStyles.title}>Edit entry</h2>
          <button type="button" className={txStyles.close} onClick={close} aria-label="Close">
            <svg width={14} height={14} viewBox="0 0 24 24" fill="none" stroke="#0b0b0c" strokeWidth={2.6} strokeLinecap="round">
              <path d="M18 6L6 18M6 6l12 12" />
            </svg>
          </button>
        </div>

        <div className={txStyles.body}>
          <div className={txStyles.amount}>
            <span className={txStyles.amountSign} style={{ color: incoming ? "#0b8f6a" : "#f0483e" }}>
              {incoming ? "+₱" : "−₱"}
            </span>
            <span className={txStyles.amountValue}>{amountDisplay(state.amt)}</span>
          </div>
          <div className={txStyles.sub}>
            {incoming ? "Money in" : "Money out"} · on {card?.nick ?? "a deleted card"}
          </div>

          <div className={txStyles.catRow}>
            {CATEGORIES.map((cat) => {
              const active = state.cat === cat.name;
              return (
                <button
                  key={cat.name}
                  type="button"
                  className={txStyles.catChip}
                  aria-pressed={active}
                  onClick={() => actions.patch({ cat: cat.name })}
                  style={{
                    background: active ? "#0b0b0c" : "#f5f4f0",
                    color: active ? "#fff" : "#0b0b0c",
                  }}
                >
                  <span className={txStyles.catDot} style={{ background: cat.color }} />
                  {cat.name}
                </button>
              );
            })}
          </div>

          <div className={txStyles.noteField}>
            <svg width={15} height={15} viewBox="0 0 24 24" fill="none" stroke="#a9a9ae" strokeWidth={2.2} strokeLinecap="round">
              <path d="M4 7h16M4 12h16M4 17h9" />
            </svg>
            <input
              className={txStyles.noteInput}
              value={state.note}
              onChange={(e) => actions.patch({ note: e.target.value })}
              placeholder="What was it?"
              aria-label="Note"
            />
          </div>

          {guess ? (
            <button type="button" className={txStyles.guess} onClick={() => actions.patch({ cat: guess })}>
              <span className={txStyles.guessTick}>
                <svg width={12} height={12} viewBox="0 0 24 24" fill="none" stroke="#fff" strokeWidth={3} strokeLinecap="round">
                  <path d="M5 13l4 4L19 7" />
                </svg>
              </span>
              <span className={txStyles.guessText}>
                Looks like <strong>{guess}</strong> — tap to use it
              </span>
            </button>
          ) : null}

          <div className={txStyles.extras}>
            <button
              type="button"
              className={txStyles.extra}
              onClick={() => receiptRef.current?.click()}
              style={{
                background: state.receipt ? "#0b0b0c" : "#f5f4f0",
                color: state.receipt ? "#fff" : "#6d6d72",
              }}
            >
              <svg
                width={15}
                height={15}
                viewBox="0 0 24 24"
                fill="none"
                stroke={state.receipt ? "#fff" : "#6d6d72"}
                strokeWidth={2.2}
                strokeLinecap="round"
              >
                <rect x={3} y={5} width={18} height={14} rx={3} />
                <circle cx={12} cy={12} r={3.2} />
              </svg>
              {state.receipt ? "Replace receipt" : "Attach receipt"}
            </button>
          </div>

          {state.receipt ? (
            <div className={txStyles.receiptRow}>
              {/* eslint-disable-next-line @next/next/no-img-element */}
              <img className={txStyles.receiptThumb} src={state.receipt} alt="Attached receipt" />
              <div className={txStyles.receiptMeta}>
                <div className={txStyles.receiptTitle}>Receipt attached</div>
                <div className={txStyles.receiptSub}>Saved with this entry</div>
              </div>
              <button
                type="button"
                className={txStyles.receiptRemove}
                onClick={() => actions.patch({ receipt: null })}
                aria-label="Remove receipt"
              >
                <svg width={15} height={15} viewBox="0 0 24 24" fill="none" stroke="#c62f26" strokeWidth={2.2} strokeLinecap="round">
                  <path d="M18 6L6 18M6 6l12 12" />
                </svg>
              </button>
            </div>
          ) : null}
        </div>

        <Keypad tone="light" />

        <div className={styles.footer}>
          {/* A second tap confirms — one entry is a small enough loss that the full erase-
              everything dialog would be a mismatch, but a bare instant delete on a financial
              record is one careless tap away from a surprise. */}
          <button
            type="button"
            className={`${styles.delete} ${confirmDelete ? styles.deleteConfirm : ""}`}
            onClick={() => {
              if (!confirmDelete) {
                setConfirmDelete(true);
                window.setTimeout(() => setConfirmDelete(false), 3200);
                return;
              }
              actions.deleteTx(id);
            }}
          >
            {confirmDelete ? "Tap again to delete" : "Delete entry"}
          </button>

          <button
            type="button"
            className={txStyles.submit}
            onClick={actions.saveTxEdit}
            style={{
              flex: 1,
              background: ready ? "#0b0b0c" : "#eceae4",
              color: ready ? "#fff" : "#a9a9ae",
            }}
          >
            Save changes
          </button>
        </div>
      </div>
    </div>
  );
}
