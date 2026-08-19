"use client";

import { useEffect, useRef } from "react";

import { CardArtFor } from "@/components/CardArt";
import { ProgressRing } from "@/components/ProgressRing";
import { TxRow } from "@/components/TxRow";
import { cardTheme } from "@/components/cardTheme";
import { dayLabel, minusIfNegative, peso, peso0 } from "@/lib/format";
import { useWallet } from "@/lib/store";
import { cardProgress, findCard, groupByDay, limitCopy, maskFor, spentOnCard } from "@/lib/selectors";
import { useElementWidth } from "@/lib/useElementWidth";

import type { CardArt } from "@/lib/types";

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
  const wrapRef = useRef<HTMLDivElement>(null);
  const wrapWidth = useElementWidth(wrapRef);
  const cardW = Math.min(320, Math.max(240, (wrapWidth ?? 360) - 40));
  const cardH = Math.round(cardW * (196 / 320));

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
            background: card.art.c1,
            viewTransitionName: "wallet-card",
          }}
        >
          <CardArtFor card={card} w={cardW} h={cardH} />
          <div className={styles.cardInner}>
            <div className={styles.cardKind} style={{ color: theme.fgDim }}>
              {card.kind}
            </div>
            <div>
              <div className={styles.balanceRow} style={{ color: theme.fg }}>
                <span className={styles.balancePeso}>{state.privacy ? "" : minusIfNegative(card.bal)}₱</span>
                <span className={styles.balanceValue}>{state.privacy ? "•••••" : peso(card.bal)}</span>
              </div>
              <div className={styles.cardMask} style={{ color: theme.dark ? "rgba(11,11,12,.6)" : "rgba(255,255,255,.6)" }}>
                {maskFor(card)}
              </div>
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
              Log spend
            </button>
            <button
              type="button"
              className={`${styles.actionBtn} ${styles.actionSand}`}
              onClick={() => {
                actions.patch({ amt: "", fromId: card.id });
                actions.go("transfer");
              }}
            >
              Move money
            </button>
          </div>

          <h2 className={styles.historyTitle}>History</h2>

          {groups.length === 0 ? (
            <div className={styles.empty}>
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
                    <TxRow key={t.id} tx={t} cardNick={card.nick} variant="detail" onClick={() => actions.go("search")} />
                  ))}
                </div>
              </div>
            ))
          )}
        </div>
      </div>
    </section>
  );
}
