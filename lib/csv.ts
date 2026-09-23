import { spendOf } from "@/lib/selectors";
import type { Card, EventGroup, Transaction } from "@/lib/types";

function escapeCell(value: string | number): string {
  const s = String(value);
  return /[",\n]/.test(s) ? `"${s.replace(/"/g, '""')}"` : s;
}

/**
 * The spreadsheet path. `Amount` is the whole bill, because that is what left the card;
 * `Your share` is what it actually cost, so a split row does not overstate the user's
 * spending the moment it lands in a pivot table.
 */
export function transactionsToCsv(
  tx: readonly Transaction[],
  cards: readonly Card[],
  events: readonly EventGroup[] = [],
): string {
  const nickOf = new Map(cards.map((c) => [c.id, c.nick]));
  const eventOf = new Map(events.map((e) => [e.id, e.name]));
  const header = [
    "Date",
    "Card",
    "Merchant",
    "Category",
    "Amount",
    "Your share",
    "Split with",
    "Owed back",
    "Event",
    "Note",
  ];
  const rows = tx.map((t) => {
    const parts = t.split?.parts ?? [];
    const owed = parts.filter((p) => !p.settledAt).reduce((sum, p) => sum + p.amount, 0);
    return [
      new Date(t.at).toISOString().slice(0, 10),
      nickOf.get(t.cardId) ?? "Deleted card",
      t.merchant,
      t.cat,
      t.amount.toFixed(2),
      (t.amount < 0 ? -spendOf(t) : t.amount).toFixed(2),
      parts.map((p) => p.name).join(" · "),
      owed.toFixed(2),
      t.eventId ? (eventOf.get(t.eventId) ?? "") : "",
      t.note,
    ];
  });
  return [header, ...rows].map((row) => row.map(escapeCell).join(",")).join("\n");
}
