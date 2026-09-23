import { newId } from "@/lib/ids";
import { PERSON_COLORS } from "@/lib/split";
import type {
  Card,
  EventGroup,
  Person,
  Split,
  SplitMode,
  SplitPart,
  Transaction,
} from "@/lib/types";

/** Shapes written by earlier builds that still need to load cleanly. */
interface LegacyTransaction extends Partial<Transaction> {
  /** Pre-timestamp builds stored "days before today" instead of an instant. */
  dayOffset?: number;
}

/** Art styles that no longer exist fall back to the closest survivor. */
const RETIRED_STYLES: Record<string, string> = {
  banig: "grid",
  binakol: "orbit",
  tnalak: "planes",
  yakan: "grid",
  kalinga: "planes",
  pina: "irid",
  pixweave: "grid",
};

/**
 * Persisted data outlives the code that wrote it. Anything loaded from the device is repaired
 * here rather than trusted: a released build will meet wallets written by every version before
 * it, and a single missing field used to surface as "Invalid Date" in the history.
 */
export function migrateCards(raw: unknown): Card[] {
  if (!Array.isArray(raw)) return [];
  return raw.flatMap((value) => {
    const card = value as Partial<Card>;
    if (!card || typeof card !== "object" || !card.art) return [];
    const style = card.art.style as string;
    return [
      {
        id: card.id ?? newId("card"),
        kind: card.kind ?? "ATM / Debit",
        nick: card.nick ?? "Untitled card",
        last4: card.last4 ?? "",
        exp: card.exp ?? "—",
        bal: Number.isFinite(card.bal) ? (card.bal as number) : 0,
        limit: Number.isFinite(card.limit) ? (card.limit as number) : 0,
        frozen: !!card.frozen,
        ...(card.goal ? { goal: card.goal } : {}),
        ...(typeof card.accountNumber === "string" ? { accountNumber: card.accountNumber } : {}),
        ...(typeof card.qr === "string" ? { qr: card.qr } : {}),
        art: {
          ...card.art,
          style: (RETIRED_STYLES[style] ?? style ?? "blob") as Card["art"]["style"],
          c1: card.art.c1 ?? "#ffca28",
          c2: card.art.c2 ?? "#0b0b0c",
          tex: card.art.tex ?? "none",
          layout: card.art.layout ?? "standard",
        },
      } satisfies Card,
    ];
  });
}

export function migratePeople(raw: unknown): Person[] {
  if (!Array.isArray(raw)) return [];
  return raw.flatMap((value, i) => {
    const person = value as Partial<Person>;
    if (!person || typeof person !== "object" || typeof person.name !== "string") return [];
    return [
      {
        id: person.id ?? newId("person"),
        name: person.name,
        color: person.color ?? PERSON_COLORS[i % PERSON_COLORS.length],
        ...(typeof person.handle === "string" && person.handle ? { handle: person.handle } : {}),
        archived: !!person.archived,
      } satisfies Person,
    ];
  });
}

export function migrateEvents(raw: unknown, now = Date.now()): EventGroup[] {
  if (!Array.isArray(raw)) return [];
  return raw.flatMap((value) => {
    const event = value as Partial<EventGroup>;
    if (!event || typeof event !== "object" || typeof event.name !== "string") return [];
    return [
      {
        id: event.id ?? newId("event"),
        name: event.name,
        emoji: typeof event.emoji === "string" && event.emoji ? event.emoji : "📍",
        startedAt: Number.isFinite(event.startedAt) ? (event.startedAt as number) : now,
        // Anything that is not a real instant means "still running", not "ended at NaN".
        endedAt: Number.isFinite(event.endedAt) ? (event.endedAt as number) : null,
        memberIds: Array.isArray(event.memberIds)
          ? event.memberIds.filter((id): id is string => typeof id === "string")
          : [],
      } satisfies EventGroup,
    ];
  });
}

const SPLIT_MODES: readonly SplitMode[] = ["even", "shares", "exact"];

/**
 * A split whose parts no longer add up is worse than no split at all — it would quietly
 * misreport what the user spent. Anything unrepairable is dropped, which leaves the
 * transaction as a plain unsplit spend at its full amount: wrong about who owed what, but
 * never wrong about the money.
 */
function migrateSplit(raw: unknown, total: number): Split | null {
  if (!raw || typeof raw !== "object") return null;
  const split = raw as Partial<Split>;
  if (!Array.isArray(split.parts)) return null;

  const parts: SplitPart[] = split.parts.flatMap((value) => {
    const part = value as Partial<SplitPart>;
    if (!part || typeof part !== "object" || typeof part.personId !== "string") return [];
    if (!Number.isFinite(part.amount)) return [];
    return [
      {
        personId: part.personId,
        name: typeof part.name === "string" && part.name ? part.name : "Someone",
        amount: Math.max(0, part.amount as number),
        ...(Number.isFinite(part.shares) ? { shares: part.shares as number } : {}),
        settledAt: Number.isFinite(part.settledAt) ? (part.settledAt as number) : null,
        ...(typeof part.settledTxId === "string" ? { settledTxId: part.settledTxId } : {}),
      } satisfies SplitPart,
    ];
  });
  if (parts.length === 0) return null;

  const others = parts.reduce((sum, p) => sum + p.amount, 0);
  // `mine` is authoritative when it is present and sane; otherwise it is the remainder,
  // which is the same rule `splitEvenly` applies when the split is first created.
  const stored = Number.isFinite(split.mine) ? (split.mine as number) : NaN;
  const mine = Number.isFinite(stored) && stored >= 0 ? stored : Math.max(0, total - others);
  if (others + mine > total + 0.5) return null;

  return {
    mode: SPLIT_MODES.includes(split.mode as SplitMode) ? (split.mode as SplitMode) : "even",
    mine: Math.round(mine * 100) / 100,
    parts,
  };
}

export function migrateTransactions(raw: unknown, cards: readonly Card[], now = Date.now()): Transaction[] {
  if (!Array.isArray(raw)) return [];
  const known = new Set(cards.map((c) => c.id));
  return raw.flatMap((value) => {
    const tx = value as LegacyTransaction;
    if (!tx || typeof tx !== "object" || !tx.cardId || !known.has(tx.cardId)) return [];
    if (!Number.isFinite(tx.amount)) return [];

    // Pre-timestamp rows carry a day offset; anything else is anchored to now so the row is
    // still readable rather than rendering as an invalid date.
    const at = Number.isFinite(tx.at)
      ? (tx.at as number)
      : now - (Number.isFinite(tx.dayOffset) ? (tx.dayOffset as number) : 0) * 864e5;

    return [
      {
        id: tx.id ?? newId("tx"),
        cardId: tx.cardId,
        merchant: tx.merchant ?? "Untitled",
        cat: tx.cat ?? "Bills",
        amount: tx.amount as number,
        at,
        note: tx.note ?? "",
        ...(typeof tx.receipt === "string" ? { receipt: tx.receipt } : {}),
        eventId: typeof tx.eventId === "string" ? tx.eventId : null,
        split: migrateSplit(tx.split, Math.abs(tx.amount as number)),
        repaysTxId: typeof tx.repaysTxId === "string" ? tx.repaysTxId : null,
      } satisfies Transaction,
    ];
  });
}
