"use client";

import { useState, type CSSProperties } from "react";

import { Mascot } from "@/components/Mascot";
import { SpriteAnimation } from "@/components/SpriteAnimation";
import { daysAgo, peso0 } from "@/lib/format";
import { biggestHit, categoryTotals, periodInsight, periodLabel, type InsightPeriod } from "@/lib/selectors";
import { IDLE_STEADY } from "@/lib/sprites";
import { useWallet } from "@/lib/store";

import styles from "./Insights.module.css";

const PERIODS: readonly InsightPeriod[] = ["week", "month", "all"];
const PERIOD_DAYS: Partial<Record<InsightPeriod, number>> = { week: 7, month: 30 };
const KICKER: Record<InsightPeriod, string> = { week: "Weekly read", month: "Monthly read", all: "All-time read" };

export function Insights() {
  const { state, actions } = useWallet();
  const [period, setPeriod] = useState<InsightPeriod>("week");
  const days = PERIOD_DAYS[period];

  const insight = periodInsight(state.tx, period);
  const hit = biggestHit(state.tx, days);
  const cats = categoryTotals(state.tx, days);
  const hasData = state.tx.length > 0;
  const max = Math.max(1, ...cats.map((c) => c.amount));
  const loggedInPeriod = state.tx.filter((t) => days === undefined || daysAgo(t.at) < days).length;

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
          <div className={styles.navTitle}>Insights</div>
          <div className={styles.navSpacer} />
        </div>

        <div className={styles.periodTrack} role="tablist" aria-label="Time period">
          {PERIODS.map((p) => (
            <button
              key={p}
              type="button"
              role="tab"
              aria-selected={period === p}
              className={styles.periodTab}
              onClick={() => setPeriod(p)}
              style={{
                background: period === p ? "#ffca28" : "transparent",
                color: period === p ? "#0b0b0c" : "rgba(255,255,255,.6)",
              }}
            >
              {periodLabel(p)}
            </button>
          ))}
        </div>

        <div className={styles.insight}>
          <div className={styles.insightArt} />
          <div style={{ position: "relative" }}>
            <div className={styles.insightKicker}>{KICKER[period]}</div>
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
              Logged {periodLabel(period).toLowerCase()}
            </div>
            <div className={styles.statValue}>{loggedInPeriod}</div>
            <div className={styles.statSub} style={{ color: "rgba(255,255,255,.45)" }}>
              {loggedInPeriod === 1 ? "transaction" : "transactions"}
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
          <div className={`${styles.empty} ${!hasData ? styles.emptyWithMascot : ""}`}>
            {!hasData ? (
              <>
                <SpriteAnimation
                  sheet={IDLE_STEADY}
                  size={88}
                  className={styles.emptyMascot}
                  fallback={<Mascot mood="idle" size={88} className={styles.emptyMascotFallback} />}
                />
                <div className={styles.emptyTitle}>Nothing logged yet.</div>
                <div className={styles.emptyCopy}>Once you start logging, this shows where it actually goes.</div>
              </>
            ) : loggedInPeriod === 0 ? (
              `Nothing logged ${periodLabel(period).toLowerCase()}. Try a wider period, or log a spend.`
            ) : (
              "Only money coming in so far. Log a spend and this fills in."
            )}
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
