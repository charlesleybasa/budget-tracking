"use client";

import { useEffect, useRef, useState, type ChangeEvent } from "react";

import { CardArtFor } from "@/components/CardArt";
import { CardPicker } from "@/components/CardPicker";
import { preloadSprite } from "@/components/SpriteAnimation";
import { CELEBRATE } from "@/lib/sprites";
import { Keypad } from "@/components/Keypad";
import { CATEGORIES } from "@/lib/constants";
import { amountDisplay } from "@/lib/format";
import { findCard, guessCategory } from "@/lib/selectors";
import { ImageError, RECEIPT_OPTIONS, readImage } from "@/lib/image";
import { useWallet } from "@/lib/store";
import type { SheetKind } from "@/lib/types";

import styles from "./TxSheet.module.css";

const MODES: ReadonlyArray<readonly [SheetKind, string]> = [
  ["withdraw", "Spend"],
  ["deposit", "Top up"],
  ["move", "Move"],
];

const TITLES: Record<SheetKind, string> = {
  withdraw: "Log a spend",
  deposit: "Top up a card",
  move: "Move money",
};

const SUBTITLES: Record<SheetKind, string> = {
  withdraw: "Cash, card, tap — you type it, we remember it",
  deposit: "Cash in, salary, refund — anything coming in",
  move: "Same money, different pocket. Your total will not budge.",
};

const SIGNS: Record<SheetKind, string> = { withdraw: "−", deposit: "+", move: "" };
const ACCENTS: Record<SheetKind, string> = { withdraw: "#f0483e", deposit: "#0b8f6a", move: "#1d6ff2" };
const SOURCE_LABELS: Record<SheetKind, string> = { withdraw: "Out of", deposit: "Into", move: "From" };
const SUBMIT_LABELS: Record<SheetKind, string> = { withdraw: "Log it", deposit: "Add it", move: "Move it" };
const SOURCE_TITLES: Record<SheetKind, string> = {
  withdraw: "Spend out of",
  deposit: "Top up into",
  move: "Move it out of",
};

export function TxSheet() {
  const { state, actions } = useWallet();
  // Every hook runs before the early returns below, so the order never changes.
  const receiptRef = useRef<HTMLInputElement>(null);
  // Which end of the transaction the picker is choosing for, if it is open.
  const [picking, setPicking] = useState<"source" | "destination" | null>(null);

  // Fetch the celebration atlas while the amount is still being typed, so the success screen
  // it feeds has it in cache by the time it renders.
  useEffect(() => {
    preloadSprite(CELEBRATE);
  }, []);

  const sheet = state.sheet;
  if (!sheet) return null;

  const source = findCard(state.cards, state.sheetCardId);
  const moveTo = findCard(state.cards, state.moveToId);
  const isMove = sheet === "move";
  const ready = parseFloat(state.amt) > 0;
  const guess = guessCategory(state.note, state.cat);

  // Guarded rather than rendered empty: the sheet is only reachable with a card, but a
  // stale open sheet after deleting the last one would otherwise crash.
  if (!source) return null;

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
    <div className={styles.layer} role="dialog" aria-modal="true" aria-label={TITLES[sheet]}>
      <button type="button" className={styles.backdrop} onClick={actions.closeSheet} aria-label="Close" />

      {/* `capture` asks a phone for the camera directly; desktop falls back to the picker. */}
      <input
        ref={receiptRef}
        type="file"
        accept="image/*"
        capture="environment"
        onChange={onReceiptFile}
        style={{ display: "none" }}
      />

      <div className={styles.panel}>
        <div className={styles.grabberRow}>
          <div className={styles.grabber} />
        </div>

        <div className={styles.head}>
          <h2 className={styles.title}>{TITLES[sheet]}</h2>
          <button type="button" className={styles.close} onClick={actions.closeSheet} aria-label="Close">
            <svg width={14} height={14} viewBox="0 0 24 24" fill="none" stroke="#0b0b0c" strokeWidth={2.6} strokeLinecap="round">
              <path d="M18 6L6 18M6 6l12 12" />
            </svg>
          </button>
        </div>

        <div className={styles.modes}>
          <div className={styles.modeTrack}>
            {MODES.map(([kind, name]) => (
              <button
                key={kind}
                type="button"
                className={styles.mode}
                aria-pressed={sheet === kind}
                onClick={() => actions.patch({ sheet: kind })}
                style={{
                  background: sheet === kind ? "#0b0b0c" : "transparent",
                  color: sheet === kind ? "#fff" : "#6d6d72",
                }}
              >
                {name}
              </button>
            ))}
          </div>
        </div>

        <div className={styles.body}>
          <div className={styles.amount}>
            <span className={styles.amountSign} style={{ color: ACCENTS[sheet] }}>
              {SIGNS[sheet]}₱
            </span>
            <span className={styles.amountValue}>{amountDisplay(state.amt)}</span>
          </div>
          <div className={styles.sub}>{SUBTITLES[sheet]}</div>

          {isMove ? (
            <>
              <button type="button" className={styles.intoRow} onClick={() => setPicking("destination")}>
                <div className={styles.thumb} style={{ background: moveTo?.art.c1 ?? "#16161a" }}>
                  {moveTo ? <CardArtFor card={moveTo} w={44} h={29} r={7} /> : null}
                </div>
                <div style={{ flex: 1, minWidth: 0 }}>
                  <div className={styles.intoLabel}>Into</div>
                  <div className={styles.intoNick}>{moveTo?.nick ?? "Pick a card"}</div>
                </div>
                <svg className={styles.intoChevron} width={16} height={16} viewBox="0 0 24 24" fill="none" stroke="#6b8fd0" strokeWidth={2.4} strokeLinecap="round" strokeLinejoin="round">
                  <path d="M6 9l6 6 6-6" />
                </svg>
              </button>

              <button type="button" className={styles.pickTrigger} onClick={() => setPicking("destination")}>
                Choose a different card
                <svg width={14} height={14} viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth={2.4} strokeLinecap="round" strokeLinejoin="round">
                  <path d="M6 9l6 6 6-6" />
                </svg>
              </button>
            </>
          ) : (
            <>
              <div className={styles.catRow}>
                {CATEGORIES.map((cat) => {
                  const active = state.cat === cat.name;
                  return (
                    <button
                      key={cat.name}
                      type="button"
                      className={styles.catChip}
                      aria-pressed={active}
                      onClick={() => actions.patch({ cat: cat.name })}
                      style={{
                        background: active ? "#0b0b0c" : "#f5f4f0",
                        color: active ? "#fff" : "#0b0b0c",
                      }}
                    >
                      <span className={styles.catDot} style={{ background: cat.color }} />
                      {cat.name}
                    </button>
                  );
                })}
              </div>

              <div className={styles.noteField}>
                <svg width={15} height={15} viewBox="0 0 24 24" fill="none" stroke="#a9a9ae" strokeWidth={2.2} strokeLinecap="round">
                  <path d="M4 7h16M4 12h16M4 17h9" />
                </svg>
                <input
                  className={styles.noteInput}
                  value={state.note}
                  onChange={(e) => actions.patch({ note: e.target.value })}
                  placeholder="What was it? (I'll guess the category)"
                  aria-label="Note"
                />
              </div>

              {guess ? (
                <button type="button" className={styles.guess} onClick={() => actions.patch({ cat: guess })}>
                  <span className={styles.guessTick}>
                    <svg width={12} height={12} viewBox="0 0 24 24" fill="none" stroke="#fff" strokeWidth={3} strokeLinecap="round">
                      <path d="M5 13l4 4L19 7" />
                    </svg>
                  </span>
                  <span className={styles.guessText}>
                    Looks like <strong>{guess}</strong> — tap to use it
                  </span>
                </button>
              ) : null}

              <div className={styles.extras}>
                <button
                  type="button"
                  className={styles.extra}
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
                <div className={styles.receiptRow}>
                  {/* eslint-disable-next-line @next/next/no-img-element */}
                  <img className={styles.receiptThumb} src={state.receipt} alt="Attached receipt" />
                  <div className={styles.receiptMeta}>
                    <div className={styles.receiptTitle}>Receipt attached</div>
                    <div className={styles.receiptSub}>Saved with this entry</div>
                  </div>
                  <button
                    type="button"
                    className={styles.receiptRemove}
                    onClick={() => actions.patch({ receipt: null })}
                    aria-label="Remove receipt"
                  >
                    <svg width={15} height={15} viewBox="0 0 24 24" fill="none" stroke="#c62f26" strokeWidth={2.2} strokeLinecap="round">
                      <path d="M18 6L6 18M6 6l12 12" />
                    </svg>
                  </button>
                </div>
              ) : null}
            </>
          )}

          <div className={styles.sourceRow}>
            <div className={styles.thumb} style={{ background: source.art.c1 }}>
              <CardArtFor card={source} w={44} h={29} r={7} />
            </div>
            <div style={{ flex: 1, minWidth: 0 }}>
              <div className={styles.sourceLabel}>{SOURCE_LABELS[sheet]}</div>
              <div className={styles.sourceNick}>{source.nick}</div>
            </div>
            <button type="button" className={styles.change} onClick={() => setPicking("source")}>
              Change
              <svg width={14} height={14} viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth={2.4} strokeLinecap="round" strokeLinejoin="round">
                <path d="M6 9l6 6 6-6" />
              </svg>
            </button>
          </div>
        </div>

        <Keypad tone="light" />

        <div className={styles.submitWrap}>
          <button
            type="button"
            className={styles.submit}
            onClick={actions.saveTx}
            style={{
              background: ready ? "#0b0b0c" : "#eceae4",
              color: ready ? "#fff" : "#a9a9ae",
            }}
          >
            {SUBMIT_LABELS[sheet]}
          </button>
        </div>
      </div>

      {picking ? (
        <CardPicker
          cards={state.cards}
          title={picking === "source" ? SOURCE_TITLES[sheet] : "Move it into"}
          selectedId={picking === "source" ? state.sheetCardId : state.moveToId}
          disabledId={
            isMove ? (picking === "source" ? state.moveToId : state.sheetCardId) : undefined
          }
          onSelect={(id) => {
            actions.patch(picking === "source" ? { sheetCardId: id } : { moveToId: id });
            setPicking(null);
          }}
          onClose={() => setPicking(null)}
        />
      ) : null}
    </div>
  );
}
