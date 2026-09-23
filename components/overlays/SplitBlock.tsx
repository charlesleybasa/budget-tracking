"use client";

import { useState } from "react";

import { peso } from "@/lib/format";
import { runningEvent, sortedEvents } from "@/lib/selectors";
import { personInitial, splitByExact, splitByShares, splitEvenly } from "@/lib/split";
import { useWallet } from "@/lib/store";
import type { Person, Split, SplitMode } from "@/lib/types";

import styles from "./SplitBlock.module.css";

const MODES: ReadonlyArray<readonly [SplitMode, string]> = [
  ["even", "Evenly"],
  ["shares", "Shares"],
  ["exact", "Exact"],
];

/**
 * The split row in the transaction sheet.
 *
 * Three states, and the header is the control that moves between them:
 *
 * - **Just me** — nobody picked. An invitation row.
 * - **Collapsed** — people picked, editor folded away. The summary row keeps the avatars and
 *   the user's share visible, so collapsing hides the controls without hiding the answer.
 * - **Expanded** — the full editor.
 *
 * Splitting stays one tap deeper than logging rather than a flow of its own, because the
 * complaint people make about Splitwise is that adding an expense costs several screens.
 */
export function SplitBlock({ total }: { total: number }) {
  const { state, actions } = useWallet();
  const [expanded, setExpanded] = useState(false);
  const [adding, setAdding] = useState(false);
  const [draftName, setDraftName] = useState("");
  const [newEvent, setNewEvent] = useState(false);
  const [eventName, setEventName] = useState("");

  const roster = state.people.filter((p) => !p.archived);
  const chosen: Person[] = state.splitWith.flatMap((id) => {
    const person = state.people.find((p) => p.id === id);
    return person ? [person] : [];
  });

  // Previewed live from the typed amount, so the number the user actually cares about —
  // their own share — is never a screen away or a submit away.
  const preview: Split | null =
    chosen.length > 0 && total > 0
      ? state.splitMode === "shares"
        ? splitByShares(total, chosen, state.splitShares)
        : state.splitMode === "exact"
          ? splitByExact(
              total,
              chosen,
              Object.fromEntries(chosen.map((p) => [p.id, parseFloat(state.splitExact[p.id] ?? "") || 0])),
            )
          : splitEvenly(total, chosen)
      : null;

  const owed = preview ? preview.parts.reduce((sum, p) => sum + p.amount, 0) : 0;
  const amountFor = (id: string) => preview?.parts.find((p) => p.personId === id)?.amount ?? null;
  // Only worth mentioning when the division actually left a remainder behind.
  const hasRemainder =
    !!preview && preview.mode === "even" && preview.parts.length > 0 && preview.mine !== preview.parts[0].amount;

  const submitPerson = () => {
    const name = draftName.trim();
    if (!name) return;
    actions.addPerson(name);
    setDraftName("");
    setAdding(false);
  };

  const submitEvent = () => {
    const name = eventName.trim();
    if (!name) return;
    actions.createEvent(name, "📍");
    setEventName("");
    setNewEvent(false);
  };

  const events = sortedEvents(state.events);
  const running = runningEvent(state.events);

  const eventStrip = (
    <EventChips
      events={events}
      running={running}
      selectedId={state.sheetEventId}
      onSelect={(id) => actions.patch({ sheetEventId: id })}
      newEvent={newEvent}
      setNewEvent={setNewEvent}
      eventName={eventName}
      setEventName={setEventName}
      submitEvent={submitEvent}
    />
  );

  // ── Just me ────────────────────────────────────────────────────────────────
  if (chosen.length === 0 && !expanded) {
    return (
      <>
        <button type="button" className={styles.closed} onClick={() => setExpanded(true)}>
          <span className={styles.closedIcon} aria-hidden="true">
            🤝
          </span>
          <span className={styles.closedText}>
            <span className={styles.closedTitle}>Just me</span>
            <span className={styles.closedSub}>Tap to split it with someone</span>
          </span>
          <Chevron open={false} />
        </button>
        {eventStrip}
      </>
    );
  }

  // ── Collapsed, with people ─────────────────────────────────────────────────
  if (!expanded) {
    return (
      <>
        <button
          type="button"
          className={`${styles.closed} ${styles.closedActive}`}
          onClick={() => setExpanded(true)}
          aria-expanded={false}
        >
          <span className={styles.stack} aria-hidden="true">
            <span className={styles.stackAvatar} style={{ background: "#0b0b0c" }}>
              {personInitial(state.userName || "You")}
            </span>
            {chosen.slice(0, 3).map((p) => (
              <span key={p.id} className={styles.stackAvatar} style={{ background: p.color }}>
                {personInitial(p.name)}
              </span>
            ))}
          </span>
          <span className={styles.closedText}>
            <span className={styles.closedTitle}>
              Split {chosen.length + 1} ways
            </span>
            <span className={styles.closedSub}>
              {preview ? `₱${peso(preview.mine)} yours · ₱${peso(owed)} back` : "Type an amount"}
            </span>
          </span>
          <Chevron open={false} />
        </button>
        {eventStrip}
      </>
    );
  }

  // ── Expanded ───────────────────────────────────────────────────────────────
  return (
    <>
      <div className={styles.open}>
        <button
          type="button"
          className={styles.head}
          onClick={() => setExpanded(false)}
          aria-expanded
          aria-label="Collapse the split"
        >
          <span className={styles.headTitle}>
            <span aria-hidden="true">🤝</span>
            Split with
          </span>
          <span className={styles.headRight}>
            {preview ? <span className={styles.headShare}>₱{peso(preview.mine)} yours</span> : null}
            <Chevron open />
          </span>
        </button>

        <div className={styles.modeRow}>
          <div className={styles.modeTrack} role="group" aria-label="How to divide it">
            {MODES.map(([mode, label]) => (
              <button
                key={mode}
                type="button"
                className={`${styles.mode} ${state.splitMode === mode ? styles.modeOn : ""}`}
                aria-pressed={state.splitMode === mode}
                onClick={() => actions.setSplitMode(mode)}
              >
                {label}
              </button>
            ))}
          </div>
        </div>

        <div className={styles.people}>
          {/* The owner is always in the split and cannot be removed — it is their wallet. */}
          <span className={styles.person}>
            <span className={`${styles.avatar} ${styles.avatarOn}`} style={{ background: "#0b0b0c" }}>
              {personInitial(state.userName || "You")}
            </span>
            <span className={styles.personName}>You</span>
            {/* Blank rather than a dash: a "—" under a face reads as a control to tap. */}
            <span className={styles.personAmount}>
              {preview ? `₱${peso(preview.mine)}` : " "}
            </span>
          </span>

          {roster.map((person) => {
            const on = state.splitWith.includes(person.id);
            const amount = on ? amountFor(person.id) : null;
            return (
              <button
                key={person.id}
                type="button"
                className={styles.person}
                aria-pressed={on}
                aria-label={`${on ? "Remove" : "Add"} ${person.name}`}
                onClick={() => actions.toggleSplitPerson(person.id)}
              >
                <span
                  className={`${styles.avatar} ${on ? styles.avatarOn : styles.avatarOff}`}
                  style={{ background: person.color }}
                >
                  {personInitial(person.name)}
                </span>
                <span className={styles.personName}>{person.name}</span>
                <span className={`${styles.personAmount} ${on ? "" : styles.personMuted}`}>
                  {amount !== null ? `₱${peso(amount)}` : " "}
                </span>
              </button>
            );
          })}

          {adding ? null : (
            <button
              type="button"
              className={styles.addPersonWrap}
              onClick={() => setAdding(true)}
              aria-label="Add someone"
            >
              <span className={styles.addPerson} aria-hidden="true">
                +
              </span>
              <span className={styles.personName}>Add</span>
              <span className={styles.personAmount}>&nbsp;</span>
            </button>
          )}
        </div>

        {adding ? (
          <div className={styles.addRow}>
            <input
              id="split-add-person"
              className={styles.addInput}
              value={draftName}
              autoFocus
              placeholder="Their name"
              aria-label="Name of the person to split with"
              onChange={(e) => setDraftName(e.target.value)}
              onKeyDown={(e) => {
                if (e.key === "Enter") submitPerson();
                if (e.key === "Escape") {
                  setDraftName("");
                  setAdding(false);
                }
              }}
            />
            <button type="button" className={styles.addGo} onClick={submitPerson} disabled={!draftName.trim()}>
              Add
            </button>
          </div>
        ) : null}

        {state.splitMode !== "even" && chosen.length > 0 ? (
          <div className={styles.rows}>
            {chosen.map((person) => (
              <div key={person.id} className={styles.row}>
                <span className={styles.rowDot} style={{ background: person.color }}>
                  {personInitial(person.name)}
                </span>
                <span className={styles.rowName}>{person.name}</span>
                {state.splitMode === "shares" ? (
                  <span className={styles.stepper}>
                    <button
                      type="button"
                      className={styles.step}
                      aria-label={`One fewer share for ${person.name}`}
                      disabled={(state.splitShares[person.id] ?? 1) <= 0}
                      onClick={() => actions.setSplitShare(person.id, (state.splitShares[person.id] ?? 1) - 1)}
                    >
                      −
                    </button>
                    <span className={styles.stepValue}>{state.splitShares[person.id] ?? 1}</span>
                    <button
                      type="button"
                      className={styles.step}
                      aria-label={`One more share for ${person.name}`}
                      onClick={() => actions.setSplitShare(person.id, (state.splitShares[person.id] ?? 1) + 1)}
                    >
                      +
                    </button>
                  </span>
                ) : (
                  <span className={styles.exactField}>
                    <span className={styles.exactPeso}>₱</span>
                    <input
                      id={`split-exact-${person.id}`}
                      className={styles.exactInput}
                      inputMode="decimal"
                      value={state.splitExact[person.id] ?? ""}
                      placeholder="0"
                      aria-label={`Exact amount for ${person.name}`}
                      onChange={(e) => actions.setSplitExact(person.id, e.target.value.replace(/[^0-9.]/g, ""))}
                    />
                  </span>
                )}
              </div>
            ))}
          </div>
        ) : null}

        <div className={styles.summary}>
          <div className={styles.summaryRow}>
            <span className={styles.summaryLabel}>Your share</span>
            <span className={styles.summaryValue}>{preview ? `₱${peso(preview.mine)}` : "—"}</span>
          </div>
          {preview ? (
            <span className={styles.back}>
              ₱{peso(owed)} comes back to you
              {hasRemainder ? " · you cover the odd centavo" : ""}
            </span>
          ) : (
            <span className={styles.hint}>
              {chosen.length === 0
                ? "Pick who was in on it and the numbers appear."
                : "Type an amount and the numbers appear."}
            </span>
          )}
        </div>

        {chosen.length > 0 ? (
          <button
            type="button"
            className={styles.clear}
            onClick={() => {
              // Clears the people only. The event tag is a separate choice and survives.
              actions.clearSplit();
              setExpanded(false);
            }}
          >
            <svg width={13} height={13} viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth={2.4} strokeLinecap="round">
              <path d="M18 6L6 18M6 6l12 12" />
            </svg>
            Actually, it was just me
          </button>
        ) : null}
      </div>

      {eventStrip}
    </>
  );
}

function Chevron({ open }: { open: boolean }) {
  return (
    <svg
      className={`${styles.chevron} ${open ? styles.chevronOpen : ""}`}
      width={16}
      height={16}
      viewBox="0 0 24 24"
      fill="none"
      stroke="currentColor"
      strokeWidth={2.4}
      strokeLinecap="round"
      strokeLinejoin="round"
      aria-hidden="true"
    >
      <path d="M6 9l6 6 6-6" />
    </svg>
  );
}

/**
 * The event row. An event is a filter on a spend, not a place in the app — so it lives as a
 * strip of chips here rather than as a destination in the navigation.
 */
function EventChips({
  events,
  running,
  selectedId,
  onSelect,
  newEvent,
  setNewEvent,
  eventName,
  setEventName,
  submitEvent,
}: {
  events: ReturnType<typeof sortedEvents>;
  running: ReturnType<typeof runningEvent>;
  selectedId: string | null;
  onSelect: (id: string | null) => void;
  newEvent: boolean;
  setNewEvent: (v: boolean) => void;
  eventName: string;
  setEventName: (v: string) => void;
  submitEvent: () => void;
}) {
  if (newEvent) {
    return (
      <div className={styles.addRow} style={{ marginTop: 10 }}>
        <input
          id="split-new-event"
          className={styles.addInput}
          value={eventName}
          autoFocus
          placeholder="Day 1 Thailand"
          aria-label="Name of the new event"
          onChange={(e) => setEventName(e.target.value)}
          onKeyDown={(e) => {
            if (e.key === "Enter") submitEvent();
            if (e.key === "Escape") {
              setEventName("");
              setNewEvent(false);
            }
          }}
        />
        <button type="button" className={styles.addGo} onClick={submitEvent} disabled={!eventName.trim()}>
          Start
        </button>
      </div>
    );
  }

  // Closed events are still offered, but only the few most recent — a trip from last year
  // is not what someone is tagging tonight's dinner with.
  const offered = events.filter((e) => e.endedAt === null || e.id === selectedId).slice(0, 6);
  if (offered.length === 0 && !running) {
    return (
      <div className={styles.events}>
        <button
          type="button"
          className={`${styles.eventChip} ${styles.eventNew}`}
          onClick={() => setNewEvent(true)}
        >
          + Start an event
        </button>
      </div>
    );
  }

  return (
    <div className={styles.events} aria-label="Event this belongs to">
      <button
        type="button"
        className={`${styles.eventChip} ${selectedId === null ? styles.eventChipOn : ""}`}
        aria-pressed={selectedId === null}
        onClick={() => onSelect(null)}
      >
        No event
      </button>
      {offered.map((event) => (
        <button
          key={event.id}
          type="button"
          className={`${styles.eventChip} ${selectedId === event.id ? styles.eventChipOn : ""}`}
          aria-pressed={selectedId === event.id}
          onClick={() => onSelect(event.id)}
        >
          <span aria-hidden="true">{event.emoji}</span>
          {event.name}
        </button>
      ))}
      <button
        type="button"
        className={`${styles.eventChip} ${styles.eventNew}`}
        onClick={() => setNewEvent(true)}
      >
        + Event
      </button>
    </div>
  );
}
