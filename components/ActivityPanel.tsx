"use client";

import { useRef, useState, type PointerEvent as ReactPointerEvent } from "react";

import { ReceiptViewer } from "@/components/ReceiptViewer";
import { TxRow } from "@/components/TxRow";
import { daysLeftInMonth, monthName, peso } from "@/lib/format";
import {
  activeNotices,
  cardProgress,
  findCard,
  pacingCopy,
  progressColor,
  safeToSpend,
} from "@/lib/selectors";
import { useWallet } from "@/lib/store";
import { useAnimatedNumber } from "@/lib/useAnimatedNumber";
import type { Notice, Transaction } from "@/lib/types";

import styles from "./ActivityPanel.module.css";

/** How far left a notice must travel before it stays open on the delete action. */
const SWIPE_OPEN = -78;
const SWIPE_TRIGGER = -42;
const SWIPE_LIMIT = -84;

function NoticeCard({ notice }: { notice: Notice }) {
  const { actions } = useWallet();
  // Swipe offset is pure interaction state; it has no business in the wallet store.
  const [x, setX] = useState(0);
  const [dragging, setDragging] = useState(false);
  const startRef = useRef({ pointer: 0, base: 0 });

  const onDown = (e: ReactPointerEvent<HTMLDivElement>) => {
    startRef.current = { pointer: e.clientX, base: x };
    setDragging(true);
  };

  const onMove = (e: ReactPointerEvent<HTMLDivElement>) => {
    if (!dragging) return;
    const next = startRef.current.base + (e.clientX - startRef.current.pointer);
    setX(Math.max(SWIPE_LIMIT, Math.min(0, next)));
  };

  const onUp = () => {
    if (!dragging) return;
    setDragging(false);
    setX(x < SWIPE_TRIGGER ? SWIPE_OPEN : 0);
  };

  return (
    <div className={styles.notif}>
      <div className={styles.notifBehind}>
        <button
          type="button"
          className={styles.notifDelete}
          onClick={() => actions.dismissNotice(notice.id)}
          aria-label={`Dismiss: ${notice.title}`}
        >
          <svg width={18} height={18} viewBox="0 0 24 24" fill="none" stroke="#fff" strokeWidth={2.2} strokeLinecap="round">
            <path d="M4 7h16M9 7V5h6v2M6 7l1 13h10l1-13M10 11v6M14 11v6" />
          </svg>
        </button>
      </div>

      <div
        className={styles.notifFront}
        onPointerDown={onDown}
        onPointerMove={onMove}
        onPointerUp={onUp}
        onPointerCancel={onUp}
        style={{
          background: "#f4eedc",
          transform: `translateX(${x}px)`,
          transition: dragging ? "none" : "transform .34s var(--ease-spring)",
        }}
      >
        <div className={styles.notifArt} />
        <div style={{ position: "relative" }}>
          <div className={styles.notifTitle} style={{ color: "#0b0b0c" }}>
            {notice.title}
          </div>
          <div className={styles.notifBody} style={{ color: "rgba(11,11,12,.6)" }}>
            {notice.body}
          </div>
        </div>
      </div>
    </div>
  );
}

export function ActivityPanel() {
  const { state, actions } = useWallet();
  const [receipt, setReceipt] = useState<Transaction | null>(null);
  const active = findCard(state.cards, state.activeId);
  const progress = active ? cardProgress(active, state.tx) : 0;
  const safe = safeToSpend(state.cards, state.tx, state.activeId);
  const safeShown = useAnimatedNumber(safe);

  const notices = activeNotices(state.cards, state.dismissedNotices, state.nudgeLowBalance);

  return (
    <div className={styles.panel}>
      <div className={styles.scroll}>
        {active ? (
          <button type="button" className={styles.safeCard} onClick={() => actions.go("insights")}>
            <div className={styles.safeTop}>
              <span className={styles.safeLabel}>Safe to spend today</span>
              <span className={styles.safeDays}>
                {daysLeftInMonth()} days left in {monthName()}
              </span>
            </div>

            <div className={styles.safeAmount}>
              <span className={styles.safePeso}>₱</span>
              <span className={styles.safeValue}>{state.privacy ? "•••••" : peso(safeShown)}</span>
              <span className={styles.safeOn}>on {active.nick}</span>
            </div>

            <div className={styles.safeTrack}>
              <div
                className={styles.safeFill}
                style={{ width: `${(progress * 100).toFixed(1)}%`, background: progressColor(progress, false) }}
              />
            </div>

            <div className={styles.safeCopy}>{pacingCopy(progress, safe)}</div>
          </button>
        ) : null}

        {notices.length > 0 ? (
          <section className={styles.notifSection}>
            <h2 className={styles.sectionTitle}>Worth knowing</h2>
            <div className={styles.notifList}>
              {notices.map((n) => (
                <NoticeCard key={n.id} notice={n} />
              ))}
            </div>
          </section>
        ) : null}

        <div className={styles.activityHead}>
          <h2 className={styles.sectionTitle}>Recent activity</h2>
          {state.tx.length > 0 ? (
            <button type="button" className={styles.searchLink} onClick={() => actions.go("search")}>
              <svg width={13} height={13} viewBox="0 0 24 24" fill="none" stroke="#1d6ff2" strokeWidth={2.4} strokeLinecap="round">
                <circle cx={11} cy={11} r={7} />
                <path d="M16.5 16.5L21 21" />
              </svg>
              Search
            </button>
          ) : null}
        </div>

        {state.tx.length === 0 ? (
          <div className={styles.empty}>
            <div className={styles.emptyTitle}>Nothing logged yet.</div>
            <p className={styles.emptyBody}>
              Tap the blue button and put in what you just spent. Two taps, and this fills up.
            </p>
          </div>
        ) : (
          <>
            <div className={styles.activityList}>
              {state.tx.slice(0, 6).map((t, i) => (
                <TxRow
                  key={t.id}
                  tx={t}
                  cardNick={findCard(state.cards, t.cardId)?.nick ?? "Deleted card"}
                  variant="home"
                  index={i}
                  onClick={() => {
                    actions.patch({ activeId: t.cardId });
                    actions.go("detail");
                  }}
                  onViewReceipt={setReceipt}
                />
              ))}
            </div>

            {active ? (
              <button type="button" className={styles.seeAll} onClick={() => actions.go("detail")}>
                See everything on {active.nick}
              </button>
            ) : null}
          </>
        )}
      </div>

      {receipt?.receipt ? (
        <ReceiptViewer src={receipt.receipt} merchant={receipt.merchant} onClose={() => setReceipt(null)} />
      ) : null}
    </div>
  );
}
