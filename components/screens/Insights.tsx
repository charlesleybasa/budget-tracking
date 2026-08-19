"use client";

import type { CSSProperties } from "react";

import { daysAgo, peso0 } from "@/lib/format";
import { biggestHit, categoryTotals, weeklyInsight } from "@/lib/selectors";
import { useWallet } from "@/lib/store";

import styles from "./Insights.module.css";

export function Insights() {
  const { state, actions } = useWallet();

  const insight = weeklyInsight(state.tx);
  const hit = biggestHit(state.tx);
  const cats = categoryTotals(state.tx);
  const hasData = state.tx.length > 0;
  const max = Math.max(1, ...cats.map((c) => c.amount));
  const loggedThisWeek = state.tx.filter((t) => daysAgo(t.at) < 7).length;

  return (
    <section
      className={`${styles.screen} bwEnterUp`}
      aria-label="Insights"
    >
      <div className={styles.header}>
        <div className={styles.headerInner}>
        <div className={styles.nav}>
          <button type="button" className={`${styles.roundBtn} ${styles.backBtn}`} onClick={() => actions.go("home")} aria-label="Back to home">
            <svg width={16} height={16} viewBox="0 0 24 24" fill="none" stroke="#fff" strokeWidth={2.6} strokeLinecap="round">
              <path d="M19 12H6M12 6l-6 6 6 6" />
            </svg>
          </button>
          <div className={styles.navTitle}>This week</div>
          <div className={styles.navSpacer} />
        </div>

        <div className={styles.insight}>
          <div className={styles.insightArt} />
          <div style={{ position: "relative" }}>
            <div className={styles.insightKicker}>Weekly read</div>
            <h1 className={styles.insightHead}>{insight.head}</h1>
            <p className={styles.insightBody}>{insight.body}</p>
          </div>
        </div>
        </div>
      </div>

      <div className={styles.scroll}>
        <div className={styles.scrollInner}>
        <div className={styles.stats}>
          <div className={styles.stat} style={{ background: "#0b0b0c", color: "#fff" }}>
            <div className={styles.statLabel} style={{ color: "rgba(255,255,255,.45)" }}>
              Logged this week
            </div>
            <div className={styles.statValue}>{loggedThisWeek}</div>
            <div className={styles.statSub} style={{ color: "rgba(255,255,255,.45)" }}>
              {loggedThisWeek === 1 ? "transaction" : "transactions"}
            </div>
          </div>

          <div className={styles.stat} style={{ background: "#f5f4f0", color: "#0b0b0c" }}>
            <div className={styles.statLabel} style={{ color: "#8a8a8f" }}>
              Biggest single hit
            </div>
            <div className={styles.statValue}>{hit.value}</div>
            <div className={styles.statSub} style={{ color: "#8a8a8f" }}>
              {hit.sub}
            </div>
          </div>
        </div>

        <section>
        <h2 className={styles.sectionTitle}>Where it went</h2>
        {cats.length === 0 ? (
          <div className={styles.empty}>
            {hasData
              ? "Only money coming in so far. Log a spend and this fills in."
              : "Nothing logged yet. Once you start logging, this shows where it actually goes."}
          </div>
        ) : (
          <div className={styles.catList}>
            {cats.map((cat, i) => (
              <div key={cat.name}>
                <div className={styles.catHead}>
                  <div className={styles.catName}>
                    <span className={styles.catDot} style={{ background: cat.color }} />
                    {cat.name}
                  </div>
                  <div className={styles.catAmount}>₱{peso0(cat.amount)}</div>
                </div>
                <div className={styles.catTrack}>
                  <div
                    className={styles.catFill}
                    style={
                      {
                        "--bar-w": `${((cat.amount / max) * 100).toFixed(1)}%`,
                        width: `${((cat.amount / max) * 100).toFixed(1)}%`,
                        background: cat.color,
                        animationDelay: `${(i * 0.06).toFixed(2)}s`,
                      } as CSSProperties
                    }
                  />
                </div>
              </div>
            ))}
          </div>
        )}

        </section>

        </div>
      </div>
    </section>
  );
}
