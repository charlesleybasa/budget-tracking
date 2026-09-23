"use client";

import { useEffect, useRef, useState, type CSSProperties, type PointerEvent as ReactPointerEvent } from "react";

import { CardArtFor } from "@/components/CardArt";
import { CardPicker } from "@/components/CardPicker";
import { peso } from "@/lib/format";
import { findCard } from "@/lib/selectors";
import { debtsByPerson } from "@/lib/split";
import { useWallet } from "@/lib/store";

import styles from "./SettleSlider.module.css";

/** Frames in the atlas. The last index is 7, so progress maps onto 0–7. */
const FRAMES = 8;
/** How far along the track counts as committed once the thumb is released. */
const COMMIT_AT = 0.9;
const THUMB = 52;
const INSET = 5;

/**
 * Slide to confirm that somebody paid you back.
 *
 * Settling moves real money into a real card — the one thing a shared-ledger app cannot do —
 * so it asks for a deliberate gesture rather than a tap. The character's eyes widen and the
 * sparkles arrive as the thumb travels, which gives the extra half-second a payoff instead of
 * making it feel like friction.
 */
export function SettleSlider() {
  const { state, actions } = useWallet();
  const trackRef = useRef<HTMLDivElement>(null);
  /**
   * The track's measured width.
   *
   * A `translateX` percentage resolves against the thumb's own 52px box rather than the
   * track, so the travel has to be real pixels. It is held through a callback ref rather
   * than `useElementWidth`, because the track only exists once the dialog opens — an effect
   * keyed on a ref object alone would have already run against a null node and never re-run.
   */
  const [track, setTrack] = useState<HTMLDivElement | null>(null);
  const [trackWidth, setTrackWidth] = useState(0);
  const [progress, setProgress] = useState(0);
  const [dragging, setDragging] = useState(false);
  const [committed, setCommitted] = useState(false);
  /**
   * Where the money lands. Null means "the card it came out of", which is the right default
   * and usually right — but not always: you can pay for dinner with GCash and be handed cash
   * back. Forcing it into the source card would leave both cards disagreeing with reality,
   * which is the one thing a manual wallet cannot afford.
   */
  const [intoId, setIntoId] = useState<string | null>(null);
  const [picking, setPicking] = useState(false);

  useEffect(() => {
    if (!track) return;
    const observer = new ResizeObserver((entries) => {
      const next = entries[0]?.contentRect.width;
      if (next) setTrackWidth(Math.round(next));
    });
    observer.observe(track);
    setTrackWidth(Math.round(track.getBoundingClientRect().width));
    return () => observer.disconnect();
  }, [track]);

  const pending = state.pendingSettle;

  // Reset whenever a different settlement is asked for, so a previous drag never carries over.
  useEffect(() => {
    setProgress(0);
    setDragging(false);
    setCommitted(false);
    setIntoId(null);
    setPicking(false);
  }, [pending?.personId, pending?.txId]);

  // Escape backs out, matching every other layer in the app.
  useEffect(() => {
    if (!pending) return;
    const onKey = (e: KeyboardEvent) => {
      if (e.key === "Escape") actions.cancelSettle();
    };
    window.addEventListener("keydown", onKey);
    return () => window.removeEventListener("keydown", onKey);
  }, [pending, actions]);

  if (!pending) return null;

  // Only the parts this settlement actually covers, so the figure matches what will move.
  const scoped = pending.txId ? state.tx.filter((t) => t.id === pending.txId) : state.tx;
  const debt = debtsByPerson(scoped, state.people).find((d) => d.personId === pending.personId);
  if (!debt) return null;

  const sourceTx = scoped.find((t) =>
    t.split?.parts.some((p) => p.personId === pending.personId && !p.settledAt),
  );
  const into = findCard(state.cards, intoId ?? sourceTx?.cardId ?? null);

  const commit = () => {
    if (committed) return;
    setCommitted(true);
    setProgress(1);
    // Let the last frame and the filled track land before the success screen takes over.
    window.setTimeout(() => actions.settlePart(pending.txId, pending.personId, into?.id), 260);
  };

  const positionFor = (clientX: number) => {
    const track = trackRef.current;
    if (!track) return 0;
    const rect = track.getBoundingClientRect();
    const travel = Math.max(1, rect.width - THUMB - INSET * 2);
    return Math.max(0, Math.min(1, (clientX - rect.left - INSET - THUMB / 2) / travel));
  };

  const onDown = (e: ReactPointerEvent<HTMLDivElement>) => {
    if (committed) return;
    e.currentTarget.setPointerCapture(e.pointerId);
    setDragging(true);
    setProgress(positionFor(e.clientX));
  };

  const onMove = (e: ReactPointerEvent<HTMLDivElement>) => {
    if (!dragging || committed) return;
    setProgress(positionFor(e.clientX));
  };

  const onUp = () => {
    if (!dragging || committed) return;
    setDragging(false);
    // Past the line it commits; short of it the thumb springs back rather than sitting in a
    // half-done state the user has to interpret.
    if (progress >= COMMIT_AT) commit();
    else setProgress(0);
  };

  const onKeyDown = (e: React.KeyboardEvent<HTMLDivElement>) => {
    if (committed) return;
    if (e.key === "ArrowRight" || e.key === "ArrowUp") {
      e.preventDefault();
      setProgress((p) => Math.min(1, p + 0.2));
    } else if (e.key === "ArrowLeft" || e.key === "ArrowDown") {
      e.preventDefault();
      setProgress((p) => Math.max(0, p - 0.2));
    } else if (e.key === "Enter" || e.key === " ") {
      e.preventDefault();
      commit();
    } else if (e.key === "End") {
      e.preventDefault();
      commit();
    }
  };

  const frame = Math.round(progress * (FRAMES - 1));
  const travel = Math.max(0, trackWidth - THUMB - INSET * 2);

  const vars = {
    "--settle-p": progress,
    "--settle-x": `${(travel * progress).toFixed(1)}px`,
    "--settle-glow": (progress * 0.9).toFixed(3),
  } as CSSProperties;

  return (
    <div
      className={styles.layer}
      role="dialog"
      aria-modal="true"
      aria-label={`Confirm that ${debt.name} paid you back`}
      data-overlay-layer
    >
      <button type="button" className={styles.backdrop} onClick={actions.cancelSettle} aria-label="Cancel" />

      <div className={styles.panel} style={vars}>
        <div className={styles.grabberRow}>
          <div className={styles.grabber} />
        </div>

        <div className={styles.stage}>
          <div className={styles.glow} aria-hidden="true" />
          <div className={styles.character} data-frame={frame} role="img" aria-hidden="true" />
        </div>

        <div className={styles.who}>{debt.name} paid you back</div>
        <div className={styles.amount}>
          <span className={styles.amountPeso}>+₱</span>
          <span className={styles.amountValue}>{peso(debt.amount)}</span>
        </div>
        <p className={styles.into}>
          Across {debt.count === 1 ? "1 spend" : `${debt.count} spends`}.
        </p>

        {into ? (
          <button
            type="button"
            className={styles.landing}
            onClick={() => setPicking(true)}
            disabled={committed || state.cards.length < 2}
            aria-label={`Lands in ${into.nick}. Change card`}
          >
            <span className={styles.landingThumb} style={{ background: into.art.c1 }}>
              <CardArtFor card={into} w={44} h={29} r={7} />
            </span>
            <span className={styles.landingMeta}>
              <span className={styles.landingLabel}>Lands in</span>
              <span className={styles.landingNick}>{into.nick}</span>
            </span>
            {state.cards.length > 1 ? (
              <span className={styles.landingChange}>
                Change
                <svg width={14} height={14} viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth={2.4} strokeLinecap="round" strokeLinejoin="round">
                  <path d="M6 9l6 6 6-6" />
                </svg>
              </span>
            ) : null}
          </button>
        ) : null}

        <div
          ref={(node) => {
            trackRef.current = node;
            setTrack(node);
          }}
          className={styles.track}
          onPointerDown={onDown}
          onPointerMove={onMove}
          onPointerUp={onUp}
          onPointerCancel={onUp}
          onKeyDown={onKeyDown}
          role="slider"
          tabIndex={0}
          aria-valuemin={0}
          aria-valuemax={100}
          aria-valuenow={Math.round(progress * 100)}
          aria-valuetext={`${Math.round(progress * 100)} percent. Slide fully right to confirm.`}
          aria-label={`Slide to confirm ₱${peso(debt.amount)} from ${debt.name}`}
        >
          <div className={styles.fill} />
          <div className={styles.trackLabel}>Slide to confirm</div>
          <div className={styles.trackDone}>Got it back</div>
          <div className={`${styles.thumb} ${dragging ? "" : styles.thumbSettling}`}>
            <svg width={20} height={20} viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth={2.6} strokeLinecap="round" strokeLinejoin="round">
              {committed ? <path d="M5 13l4 4L19 7" /> : <path d="M9 6l6 6-6 6" />}
            </svg>
          </div>
        </div>

        {/* Dragging is not available to everyone, so the same commitment is one press away. */}
        <button type="button" className={styles.assist} onClick={commit}>
          Or tap here to confirm
        </button>
        <button type="button" className={styles.cancel} onClick={actions.cancelSettle}>
          Not yet
        </button>
      </div>

      {picking ? (
        <CardPicker
          cards={state.cards}
          title="Land it in"
          selectedId={into?.id ?? ""}
          onSelect={(id) => {
            setIntoId(id);
            setPicking(false);
          }}
          onClose={() => setPicking(false)}
        />
      ) : null}
    </div>
  );
}
