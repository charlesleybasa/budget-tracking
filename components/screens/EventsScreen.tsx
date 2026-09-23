"use client";

import { useState } from "react";

import { SpriteAnimation } from "@/components/SpriteAnimation";
import { peso, peso0 } from "@/lib/format";
import { IDLE_STEADY } from "@/lib/sprites";
import { eventDateLabel, eventTotals, sortedEvents } from "@/lib/selectors";
import { useWallet } from "@/lib/store";

import styles from "./Social.module.css";

/**
 * Every trip and night out the wallet has grouped.
 *
 * An event is a lens on spends that already exist, so this screen is reached from Insights
 * and from the spend sheet rather than from the tab bar.
 */
export function EventsScreen() {
  const { state, actions } = useWallet();
  const [name, setName] = useState("");

  const events = sortedEvents(state.events);
  const running = events.filter((e) => e.endedAt === null);

  const start = () => {
    if (!name.trim()) return;
    actions.createEvent(name, "📍");
    setName("");
  };

  return (
    <section className={`${styles.screen} bwEnterUp`} aria-label="Events">
      <div className={styles.header}>
        <div className={styles.headerInner}>
          <div className={styles.nav}>
            <button
              type="button"
              className={styles.roundBtn}
              onClick={() => actions.go("insights")}
              aria-label="Back to insights"
            >
              <svg width={16} height={16} viewBox="0 0 24 24" fill="none" stroke="#fff" strokeWidth={2.6} strokeLinecap="round">
                <path d="M19 12H6M12 6l-6 6 6 6" />
              </svg>
            </button>
            <div className={styles.navTitle}>Events</div>
            <div className={styles.navSpacer} />
          </div>

          <div className={styles.hero}>
            <h1 className={styles.heroTitle}>
              {running.length > 0 ? `${running[0].emoji} ${running[0].name}` : "Trips and nights out"}
            </h1>
            <p className={styles.heroSub}>
              {running.length > 0
                ? "Running now — new spends land in it automatically."
                : "Group a run of spends so you can see what the whole thing cost."}
            </p>
          </div>
        </div>
      </div>

      <div className={styles.scroll}>
        <div className={styles.scrollInner}>
          <div className={styles.section}>
            <h2 className={styles.sectionTitle}>Start an event</h2>
            <div className={styles.addRow}>
              <input
                id="events-add"
                className={styles.addInput}
                value={name}
                placeholder="Day 1 Thailand"
                aria-label="Name of the new event"
                onChange={(e) => setName(e.target.value)}
                onKeyDown={(e) => {
                  if (e.key === "Enter") start();
                }}
              />
              <button type="button" className={styles.addGo} onClick={start} disabled={!name.trim()}>
                Start
              </button>
            </div>
          </div>

          <div className={styles.section}>
            <h2 className={styles.sectionTitle}>
              {events.length === 0 ? "Nothing grouped yet" : "All events"}
            </h2>

            {events.length === 0 ? (
              <div className={styles.empty}>
                <SpriteAnimation sheet={IDLE_STEADY} size={120} className={styles.emptyArt} />
                <div className={styles.emptyTitle}>No events yet</div>
                <p className={styles.emptyBody}>
                  Start one before a trip and every spend you log lands inside it, so the total
                  is already waiting when you get home.
                </p>
              </div>
            ) : (
              <div className={styles.rows}>
                {events.map((event) => {
                  const totals = eventTotals(state.tx, event.id);
                  return (
                    <button
                      key={event.id}
                      type="button"
                      className={`${styles.row} ${styles.rowButton}`}
                      onClick={() => actions.openEvent(event.id)}
                    >
                      <span className={`${styles.avatar} ${styles.avatarEmoji}`} aria-hidden="true">
                        {event.emoji}
                      </span>
                      <span className={styles.rowMeta}>
                        <span className={styles.rowName}>{event.name}</span>
                        <span className={styles.rowSub}>
                          {eventDateLabel(event)}
                          {totals.count > 0 ? ` · ${totals.count === 1 ? "1 spend" : `${totals.count} spends`}` : ""}
                        </span>
                      </span>
                      <span>
                        <span className={styles.rowValue}>₱{peso0(totals.total)}</span>
                        {totals.owed > 0 ? (
                          <span className={styles.txShare}>₱{peso(totals.owed)} owed</span>
                        ) : null}
                      </span>
                    </button>
                  );
                })}
              </div>
            )}
          </div>
        </div>
      </div>
    </section>
  );
}
