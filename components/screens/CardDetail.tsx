"use client";

import { useEffect, useRef, useState } from "react";

import { CardArtFor } from "@/components/CardArt";
import { Mascot } from "@/components/Mascot";
import { ProgressRing } from "@/components/ProgressRing";
import { ReceiptViewer } from "@/components/ReceiptViewer";
import { SpriteAnimation } from "@/components/SpriteAnimation";
import { TxRow } from "@/components/TxRow";
import { cardTheme } from "@/components/cardTheme";
import { dayLabel, minusIfNegative, peso, peso0 } from "@/lib/format";
import { useWallet } from "@/lib/store";
import { cardProgress, findCard, groupByDay, limitCopy, maskFor, spentOnCard } from "@/lib/selectors";
import { FLYING_IDLE } from "@/lib/sprites";
import { useElementWidth } from "@/lib/useElementWidth";
import { useLongPress } from "@/lib/useLongPress";

import type { CardArt, Transaction } from "@/lib/types";

import styles from "./CardDetail.module.css";

const DEFAULT_ART: CardArt = { style: "mesh", c1: "#0b0b0c", c2: "#ffca28", tex: "none", layout: "standard" };

export function CardDetail() {
  const { state, actions } = useWallet();
  const card = findCard(state.cards, state.activeId);

  // The wallet can be empty (a brand new user, or the last card deleted); there is nothing
  // to detail, so send them back rather than rendering a card-shaped hole.
  useEffect(() => {
    if (!card) actions.go("home");
  }, [card, actions]);

  const theme = cardTheme(card?.art ?? DEFAULT_ART);

  // The artwork scales off its rendered width, so the hero card is measured, not fixed.
  const [receipt, setReceipt] = useState<Transaction | null>(null);
  const [flipped, setFlipped] = useState(false);
  const [copied, setCopied] = useState(false);
  const wrapRef = useRef<HTMLDivElement>(null);
  const wrapWidth = useElementWidth(wrapRef);
  const cardW = Math.min(320, Math.max(240, (wrapWidth ?? 360) - 40));
  const cardH = Math.round(cardW * (196 / 320));

  // The card is captured before the early return, so the callback never reads a stale id.
  const qrCardId = card?.id ?? null;
  const openQr = () => actions.patch({ qrCardId });
  const longPress = useLongPress(openQr);

  if (!card) return null;

  const spent = spentOnCard(state.tx, card.id);
  const limit = card.limit || card.bal;
  const progress = cardProgress(card, state.tx);
  const groups = groupByDay(state.tx, card.id);

  return (
    <section
      className={`${styles.screen} bwEnterSide`}
      aria-label={`${card.nick} detail`}
    >
      <div className={styles.topInset} />

      <div className={styles.nav}>
        <button type="button" className={`${styles.roundBtn} ${styles.backBtn}`} onClick={() => actions.go("home")} aria-label="Back to home">
          <svg width={16} height={16} viewBox="0 0 24 24" fill="none" stroke="#fff" strokeWidth={2.6} strokeLinecap="round">
            <path d="M19 12H6M12 6l-6 6 6 6" />
          </svg>
        </button>
        <div className={styles.navTitle}>{card.nick}</div>
        <button
          type="button"
          className={styles.roundBtn}
          onClick={() => actions.openEditor(card.id)}
          aria-label={`Redesign ${card.nick}`}
        >
          <svg width={15} height={15} viewBox="0 0 24 24" fill="none" stroke="#fff" strokeWidth={2.3} strokeLinecap="round">
            <path d="M4 20h4l10-10-4-4L4 16v4zM14 6l4 4" />
          </svg>
        </button>
      </div>

      <div className={styles.cardWrap} ref={wrapRef}>
        <div
          className={styles.card}
          style={{
            width: cardW,
            height: cardH,
            viewTransitionName: "wallet-card",
          }}
        >
          {/* The flip rides an inner element so the outer keeps its view-transition name. */}
          <div className={`${styles.flipper} ${flipped ? styles.flipped : ""}`}>
            <button
              type="button"
              className={`${styles.face} ${styles.front}`}
              // `backface-visibility: hidden` hides the rotated-away face visually, but not
              // every browser excludes it from hit-testing too — some still let it swallow
              // taps meant for the face on top. Pointer events are turned off explicitly
              // here rather than trusted to the 3D transform.
              style={{ background: card.art.c1, pointerEvents: flipped ? "none" : "auto" }}
              onClick={() => setFlipped(true)}
              aria-label={`${card.nick}. Show receiving details`}
              tabIndex={flipped ? -1 : 0}
            >
              <CardArtFor card={card} w={cardW} h={cardH} />
              <span className={styles.cardInner}>
                <span className={styles.cardKind} style={{ color: theme.fgDim }}>
                  {card.kind}
                </span>
                <span className={styles.cardFoot}>
                  <span className={styles.balanceRow} style={{ color: theme.fg }}>
                    <span className={styles.balancePeso}>{state.privacy ? "" : minusIfNegative(card.bal)}₱</span>
                    <span className={styles.balanceValue}>{state.privacy ? "•••••" : peso(card.bal)}</span>
                  </span>
                  <span
                    className={styles.cardMask}
                    style={{ color: theme.dark ? "rgba(11,11,12,.6)" : "rgba(255,255,255,.6)" }}
                  >
                    {maskFor(card)}
                  </span>
                </span>
              </span>
              <span className={styles.flipHint} style={{ color: theme.fgDim }} aria-hidden="true">
                <svg width={13} height={13} viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth={2.2} strokeLinecap="round">
                  <path d="M3 12a9 9 0 0114-7.5M21 12a9 9 0 01-14 7.5M17 4v4h-4M7 20v-4h4" />
                </svg>
              </span>
            </button>

            {/* A div, not a button: it holds the account-number button below, and buttons
                can't nest. Tapping anywhere on this face that isn't one of those controls
                flips the card back, the same way tapping the front flipped it here. */}
            <div
              className={`${styles.face} ${styles.back}`}
              role="button"
              tabIndex={flipped ? 0 : -1}
              aria-label={`${card.nick}. Show card front`}
              // Same reasoning as the front face: don't trust backface-visibility alone to
              // keep this face out of hit-testing while it's rotated away.
              style={{ pointerEvents: flipped ? "auto" : "none" }}
              onClick={() => setFlipped(false)}
              onKeyDown={(e) => {
                if (e.key !== "Enter" && e.key !== " ") return;
                e.preventDefault();
                setFlipped(false);
              }}
            >
              <div className={styles.backHead}>
                <div className={styles.backTitle}>Receive money</div>
                <button
                  type="button"
                  className={styles.backClose}
                  onClick={() => setFlipped(false)}
                  aria-label="Show the front of the card"
                  tabIndex={flipped ? 0 : -1}
                >
                  <svg width={14} height={14} viewBox="0 0 24 24" fill="none" stroke="#fff" strokeWidth={2.4} strokeLinecap="round">
                    <path d="M18 6L6 18M6 6l12 12" />
                  </svg>
                </button>
              </div>

              {card.qr ? (
                <button
                  type="button"
                  className={styles.qrTrigger}
                  tabIndex={flipped ? 0 : -1}
                  aria-label={`Show ${card.nick}'s QR full screen`}
                  onClick={(e) => {
                    // Without this the tap bubbles to the face and flips the card away —
                    // the opposite of what someone reaching for the code wants.
                    e.stopPropagation();
                    openQr();
                  }}
                  {...longPress}
                >
                  {/* eslint-disable-next-line @next/next/no-img-element */}
                  <img
                    className={styles.backQr}
                    src={card.qr}
                    alt=""
                    draggable={false}
                    aria-hidden="true"
                  />
                  <span className={styles.qrHint}>
                    <svg width={11} height={11} viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth={2.4} strokeLinecap="round" strokeLinejoin="round">
                      <path d="M9 3H3v6M15 3h6v6M9 21H3v-6M15 21h6v-6" />
                    </svg>
                    Hold to enlarge
                  </span>
                </button>
              ) : null}

              <div className={styles.backDetails}>
                {card.accountNumber ? (
                  <button
                    type="button"
                    className={styles.backAccount}
                    tabIndex={flipped ? 0 : -1}
                    onClick={(e) => {
                      // Copying is the point of tapping this row — flipping the card away
                      // right after would undercut it, so this stays on the back.
                      e.stopPropagation();
                      navigator.clipboard
                        ?.writeText(card.accountNumber ?? "")
                        .then(() => {
                          setCopied(true);
                          window.setTimeout(() => setCopied(false), 1600);
                        })
                        .catch(() => actions.toast("Could not copy — long-press to select it."));
                    }}
                  >
                    <span className={styles.backLabel}>{copied ? "Copied" : "Account number · tap to copy"}</span>
                    <span className={styles.backNumber}>{card.accountNumber}</span>
                  </button>
                ) : null}

                {!card.qr && !card.accountNumber ? (
                  <button
                    type="button"
                    className={styles.backEmpty}
                    tabIndex={flipped ? 0 : -1}
                    onClick={(e) => {
                      e.stopPropagation();
                      actions.openEditor(card.id);
                    }}
                  >
                    <span className={styles.backEmptyTitle}>Nothing to show yet</span>
                    <span className={styles.backEmptySub}>Add your QR or account number so people can pay you</span>
                  </button>
                ) : null}
              </div>

              <span className={styles.flipHint} aria-hidden="true">
                <svg width={13} height={13} viewBox="0 0 24 24" fill="none" stroke="rgba(255,255,255,.55)" strokeWidth={2.2} strokeLinecap="round">
                  <path d="M3 12a9 9 0 0114-7.5M21 12a9 9 0 01-14 7.5M17 4v4h-4M7 20v-4h4" />
                </svg>
              </span>
            </div>
          </div>
        </div>
      </div>

      <div className={styles.sheet}>
        <div className={styles.sheetScroll}>
          <div className={styles.limitCard}>
            <div className={styles.ringWrap}>
              <ProgressRing progress={progress} size={76} goalMode={!!card.goal} />
              <div className={styles.ringLabel}>{Math.round(progress * 100)}%</div>
            </div>
            <div style={{ flex: 1 }}>
              <div className={styles.limitLabel}>{card.goal ? "Goal progress" : "Spent this month"}</div>
              <div className={styles.limitValue}>
                ₱{peso0(card.goal ? card.bal : spent)}{" "}
                <span className={styles.limitOf}>of ₱{peso0(card.goal ?? limit)}</span>
              </div>
              <div className={styles.limitCopy}>{limitCopy(card, progress)}</div>
            </div>
          </div>

          <div className={styles.actions}>
            <button
              type="button"
              className={`${styles.actionBtn} ${styles.actionInk}`}
              onClick={() => actions.openSheet("withdraw", card.id)}
            >
              <svg className={styles.actionIcon} viewBox="0 0 24 24" fill="none" aria-hidden="true">
                <path d="M12 4v12m0 0-4-4m4 4 4-4M5 20h14" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round" />
              </svg>
              Log spend
            </button>
            <button
              type="button"
              className={`${styles.actionBtn} ${styles.actionTopup}`}
              onClick={() => actions.openSheet("deposit", card.id)}
            >
              <svg className={styles.actionIcon} viewBox="0 0 24 24" fill="none" aria-hidden="true">
                <path d="M12 20V8m0 0-4 4m4-4 4 4M5 4h14" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round" />
              </svg>
              Top up
            </button>
            <button
              type="button"
              className={`${styles.actionBtn} ${styles.actionSand}`}
              onClick={() => {
                actions.patch({ amt: "", fromId: card.id });
                actions.go("transfer");
              }}
            >
              <svg className={styles.actionIcon} viewBox="0 0 24 24" fill="none" aria-hidden="true">
                <path d="M7 7h12m0 0-3-3m3 3-3 3M17 17H5m0 0 3 3m-3-3 3-3" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round" />
              </svg>
              Move money
            </button>
          </div>

          <h2 className={styles.historyTitle}>History</h2>

          {groups.length === 0 ? (
            <div className={styles.empty}>
              <SpriteAnimation
                sheet={FLYING_IDLE}
                size={118}
                className={styles.emptyMascot}
                fallback={<Mascot mood="idle" size={92} className={styles.emptyMascotFallback} />}
              />
              <div className={styles.emptyTitle}>Nothing on this card yet.</div>
              <div className={styles.emptyBody}>Log a spend or a top up and it shows up here immediately.</div>
            </div>
          ) : (
            groups.map((group) => (
              <div key={group.day} className={styles.group}>
                <div className={styles.groupHead}>
                  <div className={styles.groupDay}>{dayLabel(group.at)}</div>
                  <div className={styles.groupTotal}>₱{peso(group.total)}</div>
                </div>
                <div className={styles.groupRows}>
                  {group.rows.map((t) => (
                    <TxRow
                      key={t.id}
                      tx={t}
                      cardNick={card.nick}
                      variant="detail"
                      onClick={() => actions.openTxEdit(t.id)}
                      onViewReceipt={setReceipt}
                    />
                  ))}
                </div>
              </div>
            ))
          )}
        </div>
      </div>

      {receipt?.receipt ? (
        <ReceiptViewer src={receipt.receipt} merchant={receipt.merchant} onClose={() => setReceipt(null)} />
      ) : null}
    </section>
  );
}
