import { newId } from "@/lib/ids";
import type { Card, Transaction } from "@/lib/types";

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
      } satisfies Transaction,
    ];
  });
}
