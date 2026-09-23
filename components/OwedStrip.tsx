"use client";

import { peso, peso0 } from "@/lib/format";
import { findEvent } from "@/lib/selectors";
import { debtsByPerson, personInitial, reminderMessage, totalOwedToYou } from "@/lib/split";
import { useWallet } from "@/lib/store";

import styles from "./OwedStrip.module.css";

/** Rows shown before the strip defers to the full people screen. */
const VISIBLE = 4;

/**
 * Money that is out with other people.
 *
 * One direction only — there is no "you owe them" side to this ledger, which is why there is
 * nothing here to simplify and no debt graph to read. Tapping "Paid me" is not bookkeeping:
 * it tops up a real card, because the money really did come back.
 */
export function OwedStrip() {
  const { state, actions } = useWallet();

  const debts = debtsByPerson(state.tx, state.people);
  if (debts.length === 0) return null;

  const total = totalOwedToYou(state.tx);
  const events = new Set(debts.map((d) => d.lastEventId).filter(Boolean));
  const shown = debts.slice(0, VISIBLE);

  const nudge = async (name: string, message: string) => {
    // The share sheet is the whole "sharing" story: the app still makes no network call.
    if (typeof navigator !== "undefined" && "share" in navigator) {
      try {
        await navigator.share({ text: message });
        return;
      } catch {
        // A cancelled share is not a failure — fall through to the clipboard.
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
    <section className={styles.strip} aria-label="Money out with friends">
      <div className={styles.head}>
        <div>
          <div className={styles.cap}>Out with friends</div>
          <div className={styles.total}>₱{peso(total)}</div>
          <div className={styles.sub}>
            {debts.length === 1 ? "1 person" : `${debts.length} people`}
            {events.size > 0 ? ` · ${events.size === 1 ? "1 event" : `${events.size} events`}` : ""}
          </div>
        </div>
      </div>

      <div className={styles.list}>
        {shown.map((debt) => {
          const event = findEvent(state.events, debt.lastEventId);
          const spends = debt.count === 1 ? "1 spend" : `${debt.count} spends`;
          return (
            <div key={debt.personId} className={styles.row}>
              <span className={styles.avatar} style={{ background: debt.color }} aria-hidden="true">
                {personInitial(debt.name)}
              </span>
              <span className={styles.meta}>
                <span className={styles.name}>{debt.name}</span>
                <span className={styles.where}>
                  {event ? `${event.name} · ${spends}` : spends}
                </span>
              </span>
              <span className={styles.due}>₱{peso0(debt.amount)}</span>
              <button
                type="button"
                className={styles.nudge}
                aria-label={`Send ${debt.name} a reminder`}
                onClick={() => nudge(debt.name, reminderMessage(debt, state.userName))}
              >
                <svg width={15} height={15} viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth={2.2} strokeLinecap="round" strokeLinejoin="round">
                  <path d="M4 12l16-8-6 16-2.5-6.5L4 12z" />
                </svg>
              </button>
              <button
                type="button"
                className={styles.paid}
                onClick={() => actions.askSettle(debt.personId)}
              >
                Paid me
              </button>
            </div>
          );
        })}
      </div>

      <div className={styles.foot}>
        <span className={styles.footNote}>
          {debts.length > VISIBLE
            ? `${debts.length - VISIBLE} more waiting`
            : "Lands back in the card it came out of."}
        </span>
        <button type="button" className={styles.more} onClick={() => actions.go("people")}>
          See everyone
        </button>
      </div>
    </section>
  );
}
