"use client";

import { CardArtFor } from "@/components/CardArt";
import { Keypad } from "@/components/Keypad";
import { CATEGORIES } from "@/lib/constants";
import { peso } from "@/lib/format";
import { findCard, guessCategory } from "@/lib/selectors";
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

export function TxSheet() {
  const { state, actions } = useWallet();
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

  const cycleCard = () => {
    const i = state.cards.findIndex((c) => c.id === state.sheetCardId);
    actions.patch({ sheetCardId: state.cards[(i + 1) % state.cards.length].id });
  };

  return (
    <div className={styles.layer} role="dialog" aria-modal="true" aria-label={TITLES[sheet]}>
      <button type="button" className={styles.backdrop} onClick={actions.closeSheet} aria-label="Close" />

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
            <span className={styles.amountValue}>{state.amt || "0"}</span>
          </div>
          <div className={styles.sub}>{SUBTITLES[sheet]}</div>

          {isMove ? (
            <>
              <div className={styles.intoRow}>
                <div className={styles.thumb} style={{ background: moveTo?.art.c1 ?? "#16161a" }}>
                  {moveTo ? <CardArtFor card={moveTo} w={44} h={29} r={7} /> : null}
                </div>
                <div style={{ flex: 1, minWidth: 0 }}>
                  <div className={styles.intoLabel}>Into</div>
                  <div className={styles.intoNick}>{moveTo?.nick ?? "Pick a card"}</div>
                </div>
              </div>

              <div className={styles.chipRow}>
                {state.cards.map((card) => {
                  const active = card.id === state.moveToId;
                  return (
                    <button
                      key={card.id}
                      type="button"
                      className={styles.pickerChip}
                      aria-pressed={active}
                      onClick={() =>
                        card.id === state.sheetCardId
                          ? actions.patch({ moveToId: state.sheetCardId, sheetCardId: state.moveToId })
                          : actions.patch({ moveToId: card.id })
                      }
                      style={{
                        background: active ? "#0b0b0c" : "#f5f4f0",
                        color: active ? "#fff" : "#0b0b0c",
                      }}
                    >
                      {card.nick}
                    </button>
                  );
                })}
              </div>
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
                  aria-pressed={state.receipt}
                  onClick={() => {
                    actions.patch({ receipt: !state.receipt });
                    if (!state.receipt) actions.toast("Camera would open here.");
                  }}
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
                  {state.receipt ? "Receipt attached" : "Attach receipt"}
                </button>

                <button
                  type="button"
                  className={styles.extra}
                  aria-pressed={state.split}
                  onClick={() => actions.patch({ split: !state.split })}
                  style={{
                    background: state.split ? "#0b0b0c" : "#f5f4f0",
                    color: state.split ? "#fff" : "#6d6d72",
                  }}
                >
                  <svg
                    width={15}
                    height={15}
                    viewBox="0 0 24 24"
                    fill="none"
                    stroke={state.split ? "#fff" : "#6d6d72"}
                    strokeWidth={2.2}
                    strokeLinecap="round"
                  >
                    <circle cx={9} cy={8} r={3.2} />
                    <circle cx={17} cy={9} r={2.6} />
                    <path d="M3 19c0-3.3 2.7-5 6-5s6 1.7 6 5M16.5 14c2.6.3 4.5 2 4.5 5" />
                  </svg>
                  {state.split ? "Split 50/50" : "Split it"}
                </button>
              </div>

              {state.split ? (
                <div className={styles.splitNote}>
                  <div className={styles.splitLabel}>You&apos;re owed</div>
                  <div className={styles.splitValue}>₱{peso((parseFloat(state.amt) || 0) / 2)}</div>
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
            <button type="button" className={styles.change} onClick={cycleCard}>
              Change
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
    </div>
  );
}
