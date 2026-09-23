"use client";

import { useState } from "react";

import { SpriteAnimation } from "@/components/SpriteAnimation";
import { dayLabel, peso, peso0 } from "@/lib/format";
import { IDLE_STEADY } from "@/lib/sprites";
import {
  eventDateLabel,
  eventShares,
  eventTotals,
  eventTransactions,
  findEvent,
  spendOf,
} from "@/lib/selectors";
import { shareEvent } from "@/lib/shareCard";
import { ME_ID, personInitial, reminderMessage, debtsByPerson } from "@/lib/split";
import { useWallet } from "@/lib/store";

import styles from "./Social.module.css";

/**
 * One event — what it cost, who still owes, and every spend inside it.
 *
 * Reached from the events list, the Insights chips and the owed strip. Settling here is the
 * same action as everywhere else: it tops up a real card, because the money really moved.
 */
export function EventDetail() {
  const { state, actions } = useWallet();
  const [confirmDelete, setConfirmDelete] = useState(false);

  const event = findEvent(state.events, state.openEventId);
  // A deleted event leaves the screen without a subject; bounce rather than render nothing.
  if (!event) {
    return (
      <section className={`${styles.screen} bwEnterUp`} aria-label="Event">
        <div className={styles.scroll}>
          <div className={styles.scrollInner}>
            <div className={styles.empty}>
              <div className={styles.emptyTitle}>That event is gone</div>
              <p className={styles.emptyBody}>It was removed. The spends inside it stayed in your wallet.</p>
              <button type="button" className={styles.addGo} style={{ marginTop: 14 }} onClick={() => actions.go("events")}>
                Back to events
              </button>
            </div>
          </div>
        </div>
      </section>
    );
  }

  const totals = eventTotals(state.tx, event.id);
  const shares = eventShares(state.tx, event.id, state.people, state.userName);
  const rows = eventTransactions(state.tx, event.id).filter((t) => t.amount < 0);
  const max = Math.max(1, ...shares.map((s) => s.amount));

  // Only people who still owe inside this event, so the section is a to-do rather than a list.
  const owing = debtsByPerson(
    state.tx.filter((t) => t.eventId === event.id),
    state.people,
  );

  const share = async () => {
    const outcome = await shareEvent({ event, totals, shares });
    if (outcome === "copied") actions.toast("Summary copied. Paste it in the group chat.");
    else if (outcome === "failed") actions.toast("Could not share that.");
  };

  const nudge = async (name: string, message: string) => {
    if (typeof navigator !== "undefined" && "share" in navigator) {
      try {
        await navigator.share({ text: message });
        return;
      } catch {
        // Cancelling is not a failure — fall through to the clipboard.
      }
    }
    try {
      await navigator.clipboard.writeText(message);
      actions.toast(`Message for ${name} copied.`);
    } catch {
      actions.toast("Could not open the share sheet.");
    }
  };

  return (
    <section className={`${styles.screen} bwEnterUp`} aria-label={event.name}>
      <div className={styles.header}>
        <div className={styles.headerInner}>
          <div className={styles.nav}>
            <button
              type="button"
              className={styles.roundBtn}
              onClick={() => actions.go("events")}
              aria-label="Back to events"
            >
              <svg width={16} height={16} viewBox="0 0 24 24" fill="none" stroke="#fff" strokeWidth={2.6} strokeLinecap="round">
                <path d="M19 12H6M12 6l-6 6 6 6" />
              </svg>
            </button>
            <div className={styles.navTitle}>Event</div>
            <button
              type="button"
              className={styles.roundBtn}
              onClick={() => (event.endedAt === null ? actions.closeEvent(event.id) : actions.reopenEvent(event.id))}
              aria-label={event.endedAt === null ? "Close this event" : "Reopen this event"}
            >
              {event.endedAt === null ? (
                <svg width={15} height={15} viewBox="0 0 24 24" fill="none" stroke="#fff" strokeWidth={2.4} strokeLinecap="round" strokeLinejoin="round">
                  <path d="M5 13l4 4L19 7" />
                </svg>
              ) : (
                <svg width={15} height={15} viewBox="0 0 24 24" fill="none" stroke="#fff" strokeWidth={2.4} strokeLinecap="round" strokeLinejoin="round">
                  <path d="M4 12a8 8 0 1 0 2.5-5.8M4 4v4h4" />
                </svg>
              )}
            </button>
          </div>

          <div className={styles.hero}>
            <div className={styles.heroEmoji} aria-hidden="true">
              {event.emoji}
            </div>
            <h1 className={styles.heroTitle}>{event.name}</h1>
            <p className={styles.heroSub}>
              {eventDateLabel(event)}
              {totals.count > 0 ? ` · ${totals.count === 1 ? "1 spend" : `${totals.count} spends`}` : ""}
            </p>

            <div className={styles.stats}>
              <div className={styles.stat}>
                <div className={styles.statKey}>Event total</div>
                <div className={styles.statValue}>₱{peso0(totals.total)}</div>
              </div>
              <div className={styles.stat}>
                <div className={styles.statKey}>Your share</div>
                <div className={styles.statValue}>₱{peso0(totals.mine)}</div>
              </div>
              {totals.owed > 0 ? (
                <div className={styles.stat}>
                  <div className={styles.statKey}>Still out</div>
                  <div className={`${styles.statValue} ${styles.statAccent}`}>₱{peso0(totals.owed)}</div>
                </div>
              ) : null}
            </div>
          </div>
        </div>
      </div>

      <div className={styles.scroll}>
        <div className={styles.scrollInner}>
          {rows.length === 0 ? (
            <div className={styles.empty}>
              <SpriteAnimation sheet={IDLE_STEADY} size={120} className={styles.emptyArt} />
              <div className={styles.emptyTitle}>Nothing in it yet</div>
              <p className={styles.emptyBody}>
                {event.endedAt === null
                  ? "This event is running, so the next spend you log lands here on its own."
                  : "This event closed without anything logged against it."}
              </p>
            </div>
          ) : (
            <>
              {owing.length > 0 ? (
                <div className={styles.section}>
                  <h2 className={styles.sectionTitle}>Still to come back</h2>
                  <div className={styles.rows}>
                    {owing.map((debt) => (
                      <div key={debt.personId} className={styles.row}>
                        <span className={styles.avatar} style={{ background: debt.color }} aria-hidden="true">
                          {personInitial(debt.name)}
                        </span>
                        <span className={styles.rowMeta}>
                          <span className={styles.rowName}>{debt.name}</span>
                          <span className={styles.rowSub}>
                            {debt.count === 1 ? "1 spend" : `${debt.count} spends`} in this event
                          </span>
                        </span>
                        <span className={styles.rowValue}>₱{peso(debt.amount)}</span>
                        <span className={styles.rowActions}>
                          <button
                            type="button"
                            className={`${styles.pill} ${styles.pillQuiet}`}
                            onClick={() => nudge(debt.name, reminderMessage(debt, state.userName))}
                          >
                            Remind
                          </button>
                          <button
                            type="button"
                            className={styles.pill}
                            onClick={() => actions.askSettle(debt.personId)}
                          >
                            Paid me
                          </button>
                        </span>
                      </div>
                    ))}
                  </div>
                </div>
              ) : null}

              <div className={styles.section}>
                <h2 className={styles.sectionTitle}>Who carried what</h2>
                <div className={styles.bars}>
                  {shares.map((s) => (
                    <div key={s.personId} className={styles.bar}>
                      <div className={styles.barLabel}>
                        <span className={styles.barName}>{s.personId === ME_ID ? "You" : s.name}</span>
                        <span className={styles.barValue}>
                          ₱{peso0(s.amount)}
                          {s.owed > 0 ? ` · ₱${peso0(s.owed)} owed` : ""}
                        </span>
                      </div>
                      <div className={styles.barTrack}>
                        <div
                          className={styles.barFill}
                          style={{
                            width: `${(s.amount / max) * 100}%`,
                            background: s.personId === ME_ID ? "#ffca28" : s.color,
                          }}
                        />
                      </div>
                    </div>
                  ))}
                </div>
              </div>

              <div className={styles.section}>
                <h2 className={styles.sectionTitle}>Every spend</h2>
                <div style={{ marginTop: 6 }}>
                  {rows.map((tx) => {
                    const parts = tx.split?.parts ?? [];
                    return (
                      <button
                        key={tx.id}
                        type="button"
                        className={styles.txRow}
                        onClick={() => actions.openTxEdit(tx.id)}
                      >
                        <span className={styles.txMeta}>
                          <span className={styles.txName}>{tx.merchant}</span>
                          <span className={styles.txSub}>
                            {tx.cat} · {dayLabel(tx.at)}
                          </span>
                        </span>
                        {parts.length > 0 ? (
                          <span className={styles.stack} aria-hidden="true">
                            <span className={styles.stackAvatar} style={{ background: "#0b0b0c" }}>
                              {personInitial(state.userName || "You")}
                            </span>
                            {parts.slice(0, 3).map((p) => (
                              <span
                                key={p.personId}
                                className={styles.stackAvatar}
                                style={{
                                  background:
                                    state.people.find((person) => person.id === p.personId)?.color ?? "#6d6d72",
                                }}
                              >
                                {personInitial(p.name)}
                              </span>
                            ))}
                          </span>
                        ) : null}
                        <span>
                          <span className={styles.txValue}>₱{peso0(Math.abs(tx.amount))}</span>
                          {tx.split ? (
                            <span className={styles.txShare}>₱{peso0(spendOf(tx))} yours</span>
                          ) : null}
                        </span>
                      </button>
                    );
                  })}
                </div>
              </div>

              <div className={styles.shareRow}>
                <button type="button" className={styles.share} onClick={share}>
                  <svg width={16} height={16} viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth={2.2} strokeLinecap="round" strokeLinejoin="round">
                    <path d="M12 16V4M8 8l4-4 4 4M5 15v3a2 2 0 002 2h10a2 2 0 002-2v-3" />
                  </svg>
                  Share summary
                </button>
              </div>
            </>
          )}

          <div className={styles.danger}>
            {confirmDelete ? (
              <button
                type="button"
                className={styles.dangerBtn}
                onClick={() => {
                  actions.deleteEvent(event.id);
                  setConfirmDelete(false);
                }}
              >
                Tap again to remove — the spends stay
              </button>
            ) : (
              <button type="button" className={styles.dangerBtn} onClick={() => setConfirmDelete(true)}>
                Remove this event
              </button>
            )}
          </div>
        </div>
      </div>
    </section>
  );
}
