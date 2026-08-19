import type { Card, Transaction } from "@/lib/types";

function escapeCell(value: string | number): string {
  const s = String(value);
  return /[",\n]/.test(s) ? `"${s.replace(/"/g, '""')}"` : s;
}

export function transactionsToCsv(tx: readonly Transaction[], cards: readonly Card[]): string {
  const nickOf = new Map(cards.map((c) => [c.id, c.nick]));
  const header = ["Date", "Card", "Merchant", "Category", "Amount", "Note"];
  const rows = tx.map((t) => [
    new Date(t.at).toISOString().slice(0, 10),
    nickOf.get(t.cardId) ?? "Deleted card",
    t.merchant,
    t.cat,
    t.amount.toFixed(2),
    t.note,
  ]);
  return [header, ...rows].map((row) => row.map(escapeCell).join(",")).join("\n");
}

