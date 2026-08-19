"use client";

import { useEffect, useRef, type PointerEvent as ReactPointerEvent } from "react";

import { ActivityPanel } from "@/components/ActivityPanel";
import { CardArtFor } from "@/components/CardArt";
import { cardTheme } from "@/components/cardTheme";
import { greetingFor, minusIfNegative, peso } from "@/lib/format";
import { useElementWidth } from "@/lib/useElementWidth";
import { useWallet } from "@/lib/store";
import { balanceText, maskFor, safeToSpend, totalBalance } from "@/lib/selectors";
import { useAnimatedNumber } from "@/lib/useAnimatedNumber";
import type { Card } from "@/lib/types";

import styles from "./Home.module.css";

/** Collapsed rows are 84px of visible edge; the open one shows its whole face. */
const STACK_CLOSED = 84;
const STACK_OPEN = 208;
const STACK_CARD_H = 196;

/** The artwork is authored at 320x196; deck cards keep that ratio at whatever width fits. */
const CARD_RATIO = 196 / 320;
const DECK_MAX_W = 320;
const DECK_GAP = 14;
const DECK_PAD = 22;

function deckCardWidth(viewport: number | null): number {
  if (!viewport) return DECK_MAX_W;
  return Math.max(232, Math.min(DECK_MAX_W, viewport - DECK_PAD * 2));
}

function DeckCard({
  card,
  index,
  w,
  h,
  onOpen,
}: {
  card: Card;
  index: number;
  w: number;
  h: number;
  onOpen: (index: number) => void;
}) {
  const { state, actions } = useWallet();
  const theme = cardTheme(card.art);
  const active = card.id === state.activeId;
  const compact = card.art.layout === "compact";

  return (
    <div
      className={styles.deckCard}
      role="button"
      tabIndex={0}
      onClick={() => onOpen(index)}
      onKeyDown={(e) => {
        if (e.key === "Enter" || e.key === " ") {
          e.preventDefault();
          onOpen(index);
        }
      }}
      style={{
        width: w,
        height: h,
        background: card.art.c1,
        filter: card.frozen ? "saturate(.25)" : "none",
        opacity: card.frozen ? 0.82 : 1,
        // Only the card being opened carries the name — it must be unique per snapshot.
        viewTransitionName: active ? "wallet-card" : undefined,
      }}
    >
      <CardArtFor card={card} w={w} h={h} />

      <div className={styles.cardInner}>
        <div className={styles.cardTopRow}>
          <div>
            <div className={styles.cardKind} style={{ color: theme.fgDim }}>
              {card.kind}
            </div>
            <div className={styles.cardNick} style={{ color: theme.fg }}>
              {card.nick}
            </div>
          </div>

          <button
            type="button"
            className={styles.freeze}
            aria-label={card.frozen ? `Unfreeze ${card.nick}` : `Freeze ${card.nick}`}
            aria-pressed={card.frozen}
            onClick={(e) => {
              e.stopPropagation();
              actions.toggleFreeze(card.id);
            }}
            style={{
              background: card.frozen
                ? theme.dark
                  ? "rgba(11,11,12,.25)"
                  : "rgba(255,255,255,.22)"
                : theme.dark
                  ? "#0b0b0c"
                  : "#ffffff",
            }}
          >
            <span
              className={styles.freezeKnob}
              style={{
                background: card.frozen ? (theme.dark ? "#0b0b0c" : "#fff") : theme.dark ? "#ffca28" : "#0b0b0c",
                transform: card.frozen ? "translateX(0)" : "translateX(19px)",
              }}
            />
          </button>
        </div>

        <div>
          <div className={styles.balanceRow}>
            <span className={styles.balancePeso} style={{ color: theme.fg }}>
              {state.privacy ? "" : minusIfNegative(card.bal)}₱
            </span>
            <span className={styles.balanceValue} style={{ color: theme.fg }}>
              {balanceText(card, state.privacy)}
            </span>
          </div>

          <div className={styles.cardFootRow}>
            <div>
              <div className={styles.footLabel} style={{ color: theme.fgDim }}>
                {compact ? "Goal" : "Card"}
              </div>
              <div className={styles.footValue} style={{ color: theme.fg }}>
                {maskFor(card)}
              </div>
            </div>
            <div style={{ textAlign: "right" }}>
              <div className={styles.footLabel} style={{ color: theme.fgDim }}>
                {compact ? "Target" : "Exp date"}
              </div>
              <div className={styles.footValue} style={{ color: theme.fg, letterSpacing: 0 }}>
                {card.exp || "—"}
              </div>
            </div>
          </div>
        </div>
      </div>

      {card.frozen ? (
        <div className={styles.frost}>
          <div className={styles.frostPill}>Frozen</div>
        </div>
      ) : null}
    </div>
  );
}

function Deck() {
  const { state, actions } = useWallet();
  const viewportRef = useRef<HTMLDivElement>(null);
  const viewportWidth = useElementWidth(viewportRef);

  const cardW = deckCardWidth(viewportWidth);
  const cardH = Math.round(cardW * CARD_RATIO);
  const step = cardW + DECK_GAP;

  // The reducer needs the same step the layout is using, or snapping lands between cards.
  const setDeckStep = actions.setDeckStep;
  useEffect(() => {
    setDeckStep(step);
  }, [setDeckStep, step]);

  // A carousel drag ends with a pointerup over a card, which the browser also reports as a
  // click. Past a few pixels of travel that click is part of the drag, not a tap.
  const DRAG_SLOP = 6;
  const pressRef = useRef({ x: 0, moved: false });

  const onPointerDown = (e: ReactPointerEvent<HTMLDivElement>) => {
    pressRef.current = { x: e.clientX, moved: false };
    actions.dragStart(e.clientX);
    try {
      e.currentTarget.setPointerCapture(e.pointerId);
    } catch {
      // Pointer capture is a nicety; dragging still works without it.
    }
  };

  const onPointerMove = (e: ReactPointerEvent<HTMLDivElement>) => {
    if (Math.abs(e.clientX - pressRef.current.x) > DRAG_SLOP) pressRef.current.moved = true;
    actions.dragMove(e.clientX);
  };

  const openCard = (index: number) => {
    if (pressRef.current.moved) return;
    if (state.cards[index]?.id === state.activeId) actions.go("detail");
    else actions.snapTo(index);
  };

  return (
    <>
      <div
        ref={viewportRef}
        className={styles.deckViewport}
        style={{ height: cardH + 10 }}
        onPointerDown={onPointerDown}
        onPointerMove={onPointerMove}
        onPointerUp={actions.dragEnd}
        onPointerCancel={actions.dragEnd}
      >
        <div
          className={styles.deckTrack}
          style={{
            transform: `translate3d(${state.trackX}px,0,0)`,
            transition: state.dragging ? "none" : "transform .48s var(--ease-spring)",
          }}
        >
          {state.cards.map((card, i) => (
            <DeckCard key={card.id} card={card} index={i} w={cardW} h={cardH} onOpen={openCard} />
          ))}

          <button
            type="button"
            className={styles.newCardTile}
            style={{ width: Math.round(cardW * 0.47), height: cardH }}
            onClick={() => actions.openEditor(null)}
          >
            <span className={styles.newCardIcon}>
              <svg width={17} height={17} viewBox="0 0 24 24" fill="none" stroke="rgba(255,255,255,.8)" strokeWidth={2.4} strokeLinecap="round">
                <path d="M12 5v14M5 12h14" />
              </svg>
            </span>
            <span className={styles.newCardLabel}>New card</span>
          </button>
        </div>
      </div>

      <div className={styles.dots}>
        {state.cards.map((card, i) => (
          <button
            key={card.id}
            type="button"
            className={styles.dot}
            aria-label={`Go to ${card.nick}`}
            onClick={() => actions.snapTo(i)}
            style={{
              width: card.id === state.activeId ? 18 : 5,
              background: card.id === state.activeId ? "#ffca28" : "rgba(255,255,255,.24)",
            }}
          />
        ))}
      </div>
    </>
  );
}

function StackCard({ card, index, w }: { card: Card; index: number; w: number }) {
  const { state, actions } = useWallet();
  const theme = cardTheme(card.art);
  const open = state.stackOpenId === card.id;

  let y = 0;
  for (let j = 0; j < index; j += 1) {
    y += state.cards[j].id === state.stackOpenId ? STACK_OPEN : STACK_CLOSED;
  }

  return (
    <div
      className={styles.stackCard}
      role="button"
      tabIndex={0}
      onClick={() => {
        if (open) actions.go("detail");
        else actions.patch({ stackOpenId: card.id, activeId: card.id });
      }}
      onKeyDown={(e) => {
        if (e.key !== "Enter" && e.key !== " ") return;
        e.preventDefault();
        if (open) actions.go("detail");
        else actions.patch({ stackOpenId: card.id, activeId: card.id });
      }}
      style={{
        background: card.art.c1,
        zIndex: index + 1,
        boxShadow: open ? "0 20px 38px rgba(0,0,0,.5)" : "0 -3px 14px rgba(0,0,0,.35)",
        transform: `translate3d(0,${y}px,0) scale(${open ? 1 : 0.982})`,
        filter: card.frozen ? "saturate(.25)" : "none",
        opacity: card.frozen ? 0.82 : 1,
        viewTransitionName: open ? "wallet-card" : undefined,
      }}
    >
      {/* The deal rides on an inner element, so the outer card keeps its stack position. */}
      <div className={styles.stackDeal} style={{ animationDelay: `${(0.055 * index).toFixed(3)}s` }}>
        <CardArtFor card={card} w={w} h={STACK_CARD_H} />

        <div className={styles.stackFace}>
          <div className={styles.stackTopRow}>
            <div style={{ minWidth: 0 }}>
              <div className={styles.stackKind} style={{ color: theme.fgDim }}>
                {card.kind}
              </div>
              <div className={styles.stackNick} style={{ color: theme.fg }}>
                {card.nick}
              </div>
            </div>
            <div style={{ textAlign: "right", flex: "none" }}>
              <div className={styles.stackStripLabel} style={{ color: theme.fgDim }}>
                {card.goal ? "Saved" : "Left"}
              </div>
              <div className={styles.stackBalance}>
                <span className={styles.stackPeso} style={{ color: theme.fg }}>
                  {state.privacy ? "" : minusIfNegative(card.bal)}₱
                </span>
                <span className={styles.stackValue} style={{ color: theme.fg }}>
                  {balanceText(card, state.privacy)}
                </span>
              </div>
            </div>
          </div>

          <div style={{ flex: 1 }} />

          <div className={styles.stackFootRow}>
            <div>
              <div className={styles.footLabel} style={{ color: theme.fgDim }}>
                {card.art.layout === "compact" ? "Goal" : "Card"}
              </div>
              <div className={styles.footValue} style={{ color: theme.fg, whiteSpace: "nowrap" }}>
                {maskFor(card)}
              </div>
            </div>

            {open ? (
              <div style={{ display: "flex", gap: 7 }}>
                <button
                  type="button"
                  className={styles.miniBtn}
                  onClick={(e) => {
                    e.stopPropagation();
                    actions.openSheet("deposit", card.id);
                  }}
                  style={{
                    background: theme.dark ? "rgba(11,11,12,.1)" : "rgba(255,255,255,.2)",
                    color: theme.fg,
                  }}
                >
                  Top up
                </button>
                <button
                  type="button"
                  className={styles.miniBtn}
                  onClick={(e) => {
                    e.stopPropagation();
                    actions.openSheet("withdraw", card.id);
                  }}
                  style={{
                    background: theme.dark ? "#0b0b0c" : "#ffffff",
                    color: theme.dark ? "#ffffff" : "#0b0b0c",
                  }}
                >
                  Spend
                </button>
              </div>
            ) : null}
          </div>
        </div>

        {card.frozen ? (
          <div className={styles.frost}>
            <div className={styles.frostPill}>Frozen</div>
          </div>
        ) : null}
      </div>
    </div>
  );
}

function WalletStack() {
  const { state, actions } = useWallet();
  const stackRef = useRef<HTMLDivElement>(null);
  const stackWidth = useElementWidth(stackRef);
  const safeShown = useAnimatedNumber(safeToSpend(state.cards, state.tx, state.activeId));

  const stackHeight =
    state.cards
      .slice(0, -1)
      .reduce((sum, c) => sum + (c.id === state.stackOpenId ? STACK_OPEN : STACK_CLOSED), 0) + STACK_CARD_H;
  // Room for the add affordance, which rides inside the stack on a transform.
  const addOffset = stackHeight + 14;

  return (
    <div className={styles.stackScroll}>
      <div className={styles.tileRow}>
        <button type="button" className={styles.tileDark} onClick={() => actions.go("insights")}>
          <div className={styles.tileLabel}>Safe today</div>
          <div className={styles.tileAmount}>
            <span className={styles.tilePeso}>₱</span>
            <span className={styles.tileValue}>{state.privacy ? "•••••" : peso(safeShown)}</span>
          </div>
        </button>

        <button type="button" className={styles.tileAccent} onClick={() => actions.openSheet("withdraw")}>
          <div className={styles.tileLabelInk}>Quick</div>
          <div className={styles.tileAction}>
            <svg width={15} height={15} viewBox="0 0 24 24" fill="none" stroke="#0b0b0c" strokeWidth={2.6} strokeLinecap="round">
              <path d="M7 17L17 7M9 7h8v8" />
            </svg>
            <span className={styles.tileActionLabel}>Log spend</span>
          </div>
        </button>
      </div>

      <div className={styles.stackHead}>
        <h2 className={styles.stackTitle}>Your cards</h2>
        <div className={styles.stackHint}>Tap to open · tap again for history</div>
      </div>

      <div ref={stackRef} className={styles.stackArea} style={{ height: addOffset + 52 }}>
        {state.cards.map((card, i) => (
          <StackCard key={card.id} card={card} index={i} w={stackWidth ?? 320} />
        ))}

        <button
          type="button"
          className={styles.addCard}
          style={{ transform: `translate3d(0,${addOffset}px,0)` }}
          onClick={() => actions.openEditor(null)}
        >
          <svg width={15} height={15} viewBox="0 0 24 24" fill="none" stroke="rgba(255,255,255,.75)" strokeWidth={2.5} strokeLinecap="round">
            <path d="M12 5v14M5 12h14" />
          </svg>
          <span className={styles.addCardLabel}>Add a card</span>
        </button>
      </div>
    </div>
  );
}

export function Home() {
  const { state, actions } = useWallet();
  const deck = state.homeLayout === "deck";
  const totalShown = useAnimatedNumber(totalBalance(state.cards));
  const empty = state.cards.length === 0;

  return (
    <section className={`${styles.screen} bwEnterUp`} aria-label="Home">
      <div className={styles.topInset} />

      <header className={styles.header}>
        <div className={styles.greetingBlock}>
          <div className={styles.greeting}>
            {greetingFor()}, {state.userName.trim().split(" ")[0] || "there"}
          </div>
          <div className={styles.total}>
            {empty
              ? "Your wallet"
              : `Total ${state.privacy ? "₱•••••" : `${minusIfNegative(totalShown)}₱${peso(totalShown)}`}`}
          </div>
        </div>

        <div className={styles.headerActions}>
          {empty ? null : (
          <button
            type="button"
            className={styles.roundBtn}
            onClick={() => actions.patch({ homeLayout: deck ? "stack" : "deck" })}
            aria-label={deck ? "Switch to wallet stack" : "Switch to card deck"}
          >
            {deck ? (
              <svg width={16} height={16} viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth={2.1} strokeLinecap="round">
                <rect x={3} y={6} width={18} height={5} rx={2} />
                <rect x={3} y={14} width={18} height={5} rx={2} />
              </svg>
            ) : (
              <svg width={16} height={16} viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth={2.1} strokeLinecap="round">
                <rect x={2} y={7} width={9} height={11} rx={2} />
                <rect x={13} y={7} width={9} height={11} rx={2} />
              </svg>
            )}
          </button>
          )}

          {empty ? null : (
          <button
            type="button"
            className={styles.roundBtn}
            onClick={() => actions.patch({ privacy: !state.privacy })}
            aria-label={state.privacy ? "Show balances" : "Hide balances"}
            aria-pressed={state.privacy}
          >
            <svg width={16} height={16} viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth={2.1} strokeLinecap="round">
              <path d="M2 12s3.6-6.5 10-6.5S22 12 22 12s-3.6 6.5-10 6.5S2 12 2 12z" />
              <circle cx={12} cy={12} r={2.8} />
              {state.privacy ? <path d="M4 20L20 4" /> : null}
            </svg>
          </button>
          )}

          <button type="button" className={styles.roundBtn} onClick={() => actions.openEditor(null)} aria-label="New card">
            <svg width={16} height={16} viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth={2.4} strokeLinecap="round">
              <path d="M12 5v14M5 12h14" />
            </svg>
          </button>
        </div>
      </header>

      {empty ? (
        <div className={styles.emptyWallet}>
          <div className={styles.emptyArt} aria-hidden="true">
            <div className={styles.emptyCard} />
            <div className={styles.emptyCard} />
            <div className={styles.emptyCard} />
          </div>
          <h2 className={styles.emptyTitle}>No cards yet.</h2>
          <p className={styles.emptyBody}>
            Make one for each pocket of your money — your bank card, your e-wallet, the cash
            actually in your wallet. You type the numbers; nothing is connected to a bank.
          </p>
          <button type="button" className={styles.emptyBtn} onClick={() => actions.openEditor(null)}>
            Make your first card
          </button>
        </div>
      ) : (
      <div className={`${styles.panes} ${deck ? styles.panesDeck : styles.panesStack}`}>
        <div className={styles.walletPane}>
          {deck ? (
            <>
              <Deck />
              <div className={styles.quickRow}>
                <button type="button" className={styles.quickBtn} onClick={() => actions.openSheet("withdraw")}>
                  <span className={styles.quickIcon}>
                    <svg width={14} height={14} viewBox="0 0 24 24" fill="none" stroke="#fff" strokeWidth={2.6} strokeLinecap="round">
                      <path d="M7 17L17 7M9 7h8v8" />
                    </svg>
                  </span>
                  <span className={styles.quickLabel}>Spend</span>
                </button>

                <button type="button" className={styles.quickBtn} onClick={() => actions.openSheet("deposit")}>
                  <span className={styles.quickIcon}>
                    <svg width={14} height={14} viewBox="0 0 24 24" fill="none" stroke="#fff" strokeWidth={2.6} strokeLinecap="round">
                      <path d="M17 7L7 17M15 17H7V9" />
                    </svg>
                  </span>
                  <span className={styles.quickLabel}>Top up</span>
                </button>
              </div>
            </>
          ) : (
            <WalletStack />
          )}
        </div>

        <div className={styles.activityPane}>
          <ActivityPanel />
        </div>
      </div>
      )}
    </section>
  );
}
