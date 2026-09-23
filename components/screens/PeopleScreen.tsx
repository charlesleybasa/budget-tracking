"use client";

import { useState } from "react";

import { SpriteAnimation } from "@/components/SpriteAnimation";
import { peso } from "@/lib/format";
import { IDLE_STEADY } from "@/lib/sprites";
import { findEvent } from "@/lib/selectors";
import { debtsByPerson, personInitial, reminderMessage, totalOwedToYou } from "@/lib/split";
import { useWallet } from "@/lib/store";

import styles from "./Social.module.css";

/**
 * Everyone the wallet splits with, and what they still owe.
 *
 * Reached from the owed strip and from Settings — not from the navigation, which stays at
 * four destinations. Overcrowded navigation is one of the loudest complaints about the app
 * this feature is answering.
 */
export function PeopleScreen() {
  const { state, actions } = useWallet();
  const [name, setName] = useState("");

  const debts = debtsByPerson(state.tx, state.people);
  const owedBy = new Map(debts.map((d) => [d.personId, d]));
  const roster = state.people.filter((p) => !p.archived);
  const total = totalOwedToYou(state.tx);

  const add = () => {
    if (!name.trim()) return;
    actions.addPerson(name);
    setName("");
  };

  const nudge = async (person: string, message: string) => {
    if (typeof navigator !== "undefined" && "share" in navigator) {
      try {
        await navigator.share({ text: message });
        return;
      } catch {
        // Cancelling a share is not a failure; fall through to the clipboard.
      }
    }
    try {
      await navigator.clipboard.writeText(message);
      actions.toast(`Message for ${person} copied.`);
    } catch {
      actions.toast("Could not open the share sheet.");
    }
  };

  return (
    <section className={`${styles.screen} bwEnterUp`} aria-label="People">
      <div className={styles.header}>
        <div className={styles.headerInner}>
          <div className={styles.nav}>
            <button
              type="button"
              className={styles.roundBtn}
              onClick={() => actions.go("home")}
              aria-label="Back to home"
            >
              <svg width={16} height={16} viewBox="0 0 24 24" fill="none" stroke="#fff" strokeWidth={2.6} strokeLinecap="round">
                <path d="M19 12H6M12 6l-6 6 6 6" />
              </svg>
            </button>
            <div className={styles.navTitle}>People</div>
            <div className={styles.navSpacer} />
          </div>

          <div className={styles.hero}>
            <h1 className={styles.heroTitle}>
              {total > 0 ? `₱${peso(total)} is out there` : "Nobody owes you"}
            </h1>
            <p className={styles.heroSub}>
              {total > 0
                ? "Tap paid when it lands. It tops up the card it came out of."
                : "Split a spend and whoever owes you shows up here."}
            </p>
          </div>
        </div>
      </div>

      <div className={styles.scroll}>
        <div className={styles.scrollInner}>
          <div className={styles.section}>
            <h2 className={styles.sectionTitle}>Add someone</h2>
            <div className={styles.addRow}>
              <input
                id="people-add"
                className={styles.addInput}
                value={name}
                placeholder="Their name"
                aria-label="Name of the person to add"
                onChange={(e) => setName(e.target.value)}
                onKeyDown={(e) => {
                  if (e.key === "Enter") add();
                }}
              />
              <button type="button" className={styles.addGo} onClick={add} disabled={!name.trim()}>
                Add
              </button>
            </div>
          </div>

          <div className={styles.section}>
            <h2 className={styles.sectionTitle}>
              {roster.length === 0 ? "Nobody yet" : `${roster.length === 1 ? "1 person" : `${roster.length} people`}`}
            </h2>

            {roster.length === 0 ? (
              <div className={styles.empty}>
                <SpriteAnimation sheet={IDLE_STEADY} size={120} className={styles.emptyArt} />
                <div className={styles.emptyTitle}>No one here yet</div>
                <p className={styles.emptyBody}>
                  Add the people you actually split with — housemates, the usual barkada — and
                  they will be one tap away inside the spend sheet.
                </p>
              </div>
            ) : (
              <div className={styles.rows}>
                {roster.map((person) => {
                  const debt = owedBy.get(person.id);
                  const event = findEvent(state.events, debt?.lastEventId);
                  return (
                    <div key={person.id} className={styles.row}>
                      <span className={styles.avatar} style={{ background: person.color }} aria-hidden="true">
                        {personInitial(person.name)}
                      </span>
                      <span className={styles.rowMeta}>
                        <span className={styles.rowName}>{person.name}</span>
                        <span className={styles.rowSub}>
                          {debt
                            ? `${debt.count === 1 ? "1 spend" : `${debt.count} spends`}${event ? ` · ${event.name}` : ""}`
                            : "All settled up"}
                        </span>
                      </span>

                      {debt ? (
                        <>
                          <span className={styles.rowValue}>₱{peso(debt.amount)}</span>
                          <span className={styles.rowActions}>
                            <button
                              type="button"
                              className={`${styles.pill} ${styles.pillQuiet}`}
                              onClick={() => nudge(person.name, reminderMessage(debt, state.userName))}
                            >
                              Remind
                            </button>
                            <button
                              type="button"
                              className={styles.pill}
                              onClick={() => actions.askSettle(person.id)}
                            >
                              Paid me
                            </button>
                          </span>
                        </>
                      ) : (
                        <span className={styles.rowActions}>
                          <button
                            type="button"
                            className={`${styles.pill} ${styles.pillDanger}`}
                            onClick={() => actions.deletePerson(person.id)}
                          >
                            Remove
                          </button>
                        </span>
                      )}
                    </div>
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
