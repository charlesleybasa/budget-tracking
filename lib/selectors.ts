import { CATEGORIES, CATEGORY_GUESSES } from "@/lib/constants";
import { daysAgo, daysLeftInMonth, peso, peso0 } from "@/lib/format";
import { ME_ID, myShare } from "@/lib/split";
import type {
  Card,
  CategoryName,
  EventGroup,
  Notice,
  Person,
  SearchFilter,
  Transaction,
} from "@/lib/types";

/**
 * Money the wallet owner actually spent on this entry, as a positive figure. Zero for
 * anything that is not a spend.
 *
 * Every analytic below goes through this rather than reading `amount`, because `amount` is
 * the whole bill — including the part that belonged to other people and is coming back.
 * Reading `amount` directly would tell someone they spent ₱1,200 on dinner when they spent
 * ₱400 and lent ₱800, and would throttle their safe-to-spend meter over money they are owed.
 */
export function spendOf(tx: Transaction): number {
  const share = myShare(tx);
  return share < 0 ? Math.abs(share) : 0;
}

/** True when an instant falls inside the current calendar month. */
export function isThisMonth(at: number, now: Date = new Date()): boolean {
  const then = new Date(at);
  return then.getMonth() === now.getMonth() && then.getFullYear() === now.getFullYear();
}

/** Undefined when the wallet is empty — callers must handle a wallet with no cards. */
export function findCard(cards: readonly Card[], id: string | null): Card | undefined {
  return cards.find((c) => c.id === id) ?? cards[0];
}

export function cardIndex(cards: readonly Card[], id: string | null): number {
  const i = cards.findIndex((c) => c.id === id);
  return i < 0 ? 0 : i;
}

/**
 * Money out of a card this calendar month. The limit it is measured against is monthly.
 * Counts the owner's share of a split spend, not the whole bill.
 */
export function spentOnCard(tx: readonly Transaction[], cardId: string, now?: Date): number {
  return tx
    .filter((t) => t.cardId === cardId && isThisMonth(t.at, now))
    .reduce((sum, t) => sum + spendOf(t), 0);
}

/** What is left of today's slice of the month, capped by what the card actually holds. */
export function safeToSpend(cards: readonly Card[], tx: readonly Transaction[], cardId: string, now?: Date): number {
  const card = findCard(cards, cardId);
  if (!card) return 0;
  const ceiling = card.limit || card.bal;
  const left = Math.max(0, ceiling - spentOnCard(tx, card.id, now));
  const days = Math.max(1, daysLeftInMonth(now));
  return Math.max(0, Math.min(card.bal, left / days));
}

/** Fraction of the card's ceiling used — or, for a savings card, progress toward the goal. */
export function cardProgress(card: Card, tx: readonly Transaction[], now?: Date): number {
  if (card.goal) return Math.min(1, card.bal / card.goal);
  const limit = card.limit || card.bal;
  return limit ? Math.min(1, spentOnCard(tx, card.id, now) / limit) : 0;
}

export function totalBalance(cards: readonly Card[]): number {
  return cards.reduce((sum, c) => sum + c.bal, 0);
}

export interface DayGroup {
  /** Whole days before today — unique per group, so it is also the React key. */
  day: number;
  /** Representative instant for the day, used for the heading. */
  at: number;
  total: number;
  rows: Transaction[];
}

/** A card's history, bucketed by day, most recent first. */
export function groupByDay(tx: readonly Transaction[], cardId: string): DayGroup[] {
  const buckets = new Map<number, Transaction[]>();
  for (const t of tx) {
    if (t.cardId !== cardId) continue;
    const day = daysAgo(t.at);
    const list = buckets.get(day);
    if (list) list.push(t);
    else buckets.set(day, [t]);
  }
  return [...buckets.entries()]
    .sort((a, b) => a[0] - b[0])
    .map(([day, rows]) => ({
      day,
      at: rows[0].at,
      total: rows.reduce((sum, t) => sum + Math.abs(t.amount), 0),
      rows,
    }));
}

export interface CategoryTotal {
  name: CategoryName;
  color: string;
  amount: number;
}

export function categoryTotals(tx: readonly Transaction[], withinDays?: number): CategoryTotal[] {
  return CATEGORIES.map((c) => ({
    name: c.name,
    color: c.color,
    amount: tx
      .filter((t) => t.cat === c.name && (withinDays === undefined || daysAgo(t.at) < withinDays))
      .reduce((sum, t) => sum + spendOf(t), 0),
  }))
    .filter((c) => c.amount > 0)
    .sort((a, b) => b.amount - a.amount);
}

export function searchTransactions(
  tx: readonly Transaction[],
  query: string,
  filter: SearchFilter,
): Transaction[] {
  const q = query.toLowerCase().trim();
  return tx.filter((t) => {
    const matchesQuery =
      !q ||
      t.merchant.toLowerCase().includes(q) ||
      t.cat.toLowerCase().includes(q) ||
      t.note.toLowerCase().includes(q);
    const matchesFilter =
      filter === "All"
        ? true
        : filter === "Money in"
          ? t.amount > 0
          : filter === "Money out"
            ? t.amount < 0
            : filter === "Split"
              ? !!t.split
              : t.cat === filter;
    return matchesQuery && matchesFilter;
  });
}

/** Category suggested by a free-text note, or null when it is already selected or unknown. */
export function guessCategory(note: string, current: CategoryName): CategoryName | null {
  const n = note.toLowerCase().trim();
  if (n.length < 3) return null;
  for (const [words, cat] of CATEGORY_GUESSES) {
    if (words.some((w) => n.includes(w))) return cat === current ? null : cat;
  }
  return null;
}

export type InsightPeriod = "week" | "month" | "all";

/** Rolling window each period looks back over. "All time" has no window — and no "prior"
 *  window to compare against, which is why it gets its own branch below rather than just a
 *  very large number here. */
const PERIOD_DAYS: Record<Exclude<InsightPeriod, "all">, number> = { week: 7, month: 30 };

export function periodLabel(period: InsightPeriod): string {
  return period === "week" ? "This week" : period === "month" ? "This month" : "All time";
}

export interface WeeklyInsight {
  head: string;
  body: string;
}

/**
 * The period's dominant spending category, and — for week/month — how it moved against the
 * equivalent period before it. All time has nothing to compare against, so it just names
 * the leader.
 */
export function periodInsight(tx: readonly Transaction[], period: InsightPeriod): WeeklyInsight {
  if (period === "all") {
    const totals = categoryTotals(tx);
    if (totals.length === 0) {
      return {
        head: "Nothing yet",
        body: "Once you log a spend, this shows where it's actually been going.",
      };
    }
    const top = totals[0];
    return {
      head: `${top.name} leads overall`,
      body: `₱${peso0(top.amount)} on ${top.name.toLowerCase()} across everything you've logged — more than any other category.`,
    };
  }

  const days = PERIOD_DAYS[period];
  const noun = period === "week" ? "week" : "month";
  const current = categoryTotals(tx, days);
  if (current.length === 0) {
    return {
      head: `A quiet ${noun}`,
      body: `Nothing logged in the last ${days} days. Either you spent nothing, or you owe your future self some typing.`,
    };
  }

  const top = current[0];
  const prior = tx
    .filter((t) => {
      const d = daysAgo(t.at);
      return d >= days && d < days * 2 && t.cat === top.name;
    })
    .reduce((sum, t) => sum + spendOf(t), 0);
  const delta = top.amount - prior;
  const direction = delta > 0 ? "up" : "down";

  return {
    head: `${top.name} is quietly winning`,
    body:
      prior > 0
        ? `₱${peso0(top.amount)} on ${top.name.toLowerCase()} this ${noun} — ${direction} ₱${peso0(Math.abs(delta))} from the ${noun} before. Everything else you actually held steady.`
        : `₱${peso0(top.amount)} on ${top.name.toLowerCase()} this ${noun}, and nothing there the ${noun} before. Worth watching.`,
  };
}

export interface BiggestHit {
  value: string;
  sub: string;
}

/** The single worst hit to the user's own money — their share of it, not the whole bill. */
export function biggestHit(tx: readonly Transaction[], withinDays?: number): BiggestHit {
  const out = tx.filter(
    (t) => spendOf(t) > 0 && (withinDays === undefined || daysAgo(t.at) < withinDays),
  );
  if (out.length === 0) return { value: "₱0", sub: "nothing logged yet" };
  const worst = out.reduce((a, b) => (spendOf(b) > spendOf(a) ? b : a));
  const shared = worst.split ? " · your share" : "";
  return {
    value: `₱${peso0(spendOf(worst))}`,
    sub: `${worst.merchant} · ${worst.cat}${shared}`,
  };
}

/** Copy under the safe-to-spend meter, keyed off how much of the ceiling is gone. */
export function pacingCopy(progress: number, perDay: number): string {
  if (progress > 0.9) return "You've used almost the whole limit. Coast until payday.";
  if (progress > 0.6) return `Pacing is fine. Stay under ₱${peso0(perDay)} a day and you land clean.`;
  return "Comfortable. You could even move some into savings.";
}

export function limitCopy(card: Card, progress: number): string {
  if (card.goal) return progress >= 1 ? "Goal reached. Nicely done." : "Keep going — it adds up faster than it feels.";
  if (progress > 0.9) return "Limit basically reached. Breathe.";
  return "On track for the month.";
}

/** Colour ramp shared by the meter and the detail ring. */
export function progressColor(progress: number, goalMode: boolean): string {
  if (goalMode) return progress > 0.66 ? "#0b8f6a" : progress > 0.33 ? "#ffca28" : "#1d6ff2";
  return progress > 0.9 ? "#f0483e" : progress > 0.7 ? "#ffca28" : "#0b8f6a";
}

export function maskFor(card: Card): string {
  if (card.last4) return `•••• •••• ${card.last4}`;
  return card.kind === "Cash on hand" ? "Physical pesos" : "No number";
}

export function balanceText(card: Card, privacy: boolean): string {
  if (privacy) return "•••••";
  return card.art.layout === "compact" ? peso0(card.bal) : peso(card.bal);
}

/** A card below this is worth mentioning on the home screen. */
export const LOW_BALANCE = 1500;

/**
 * Notices are derived from the wallet itself rather than seeded, so what the user sees is
 * always true of their actual money. Dismissals are remembered by id.
 */
export function activeNotices(
  cards: readonly Card[],
  dismissed: readonly string[],
  lowBalanceEnabled: boolean,
): Notice[] {
  if (!lowBalanceEnabled) return [];
  return cards
    .filter((c) => c.bal < LOW_BALANCE && !dismissed.includes(`low:${c.id}`))
    .map((c) => ({
      id: `low:${c.id}`,
      kind: "low" as const,
      title: `${c.nick} is running thin`,
      body: `Down to ₱${peso0(c.bal)}. Worth topping up before it catches you out.`,
    }));
}

// ── events ───────────────────────────────────────────────────────────────────

export function findEvent(events: readonly EventGroup[], id: string | null | undefined): EventGroup | undefined {
  if (!id) return undefined;
  return events.find((e) => e.id === id);
}

/** The event a new spend should default into: the most recently started one still running. */
export function runningEvent(events: readonly EventGroup[]): EventGroup | undefined {
  return events.filter((e) => e.endedAt === null).sort((a, b) => b.startedAt - a.startedAt)[0];
}

export function eventTransactions(tx: readonly Transaction[], eventId: string): Transaction[] {
  return tx.filter((t) => t.eventId === eventId);
}

export interface EventTotals {
  /** Everything the event cost, across everyone — the sum of the bills. */
  total: number;
  /** What it cost the wallet owner. */
  mine: number;
  /** Still out with other people. */
  owed: number;
  /** Already paid back. */
  settled: number;
  count: number;
}

export function eventTotals(tx: readonly Transaction[], eventId: string): EventTotals {
  const rows = eventTransactions(tx, eventId);
  let total = 0;
  let mine = 0;
  let owed = 0;
  let settled = 0;

  for (const t of rows) {
    if (t.amount >= 0) continue;
    total += Math.abs(t.amount);
    mine += spendOf(t);
    for (const part of t.split?.parts ?? []) {
      if (part.settledAt) settled += part.amount;
      else owed += part.amount;
    }
  }

  const round = (n: number) => Math.round(n * 100) / 100;
  return {
    total: round(total),
    mine: round(mine),
    owed: round(owed),
    settled: round(settled),
    count: rows.length,
  };
}

export interface EventShare {
  personId: string;
  name: string;
  color: string;
  /** Everything this person was on the hook for, settled or not. */
  amount: number;
  owed: number;
}

/**
 * Per-person totals inside one event, the owner included. Ordered by size so the bars read
 * as a ranking rather than as an arbitrary list.
 */
export function eventShares(
  tx: readonly Transaction[],
  eventId: string,
  people: readonly Person[],
  ownerName: string,
): EventShare[] {
  const byId = new Map(people.map((p) => [p.id, p]));
  const rows = eventTransactions(tx, eventId).filter((t) => t.amount < 0);
  const out = new Map<string, EventShare>();

  const bump = (id: string, name: string, color: string, amount: number, owed: number) => {
    const existing = out.get(id);
    if (existing) {
      existing.amount = Math.round((existing.amount + amount) * 100) / 100;
      existing.owed = Math.round((existing.owed + owed) * 100) / 100;
      return;
    }
    out.set(id, { personId: id, name, color, amount, owed });
  };

  for (const t of rows) {
    bump(ME_ID, ownerName.trim() || "You", "#0b0b0c", spendOf(t), 0);
    for (const part of t.split?.parts ?? []) {
      const person = byId.get(part.personId);
      bump(
        part.personId,
        person?.name ?? part.name,
        person?.color ?? "#6d6d72",
        part.amount,
        part.settledAt ? 0 : part.amount,
      );
    }
  }

  return [...out.values()].filter((s) => s.amount > 0).sort((a, b) => b.amount - a.amount);
}

/** Events with something logged in them, most recent first; running events lead. */
export function sortedEvents(events: readonly EventGroup[]): EventGroup[] {
  return [...events].sort((a, b) => {
    if ((a.endedAt === null) !== (b.endedAt === null)) return a.endedAt === null ? -1 : 1;
    return b.startedAt - a.startedAt;
  });
}

export function eventDateLabel(event: EventGroup): string {
  const started = new Date(event.startedAt).toLocaleDateString("en-PH", {
    day: "numeric",
    month: "short",
  });
  if (event.endedAt === null) return `${started} · still running`;
  const ended = new Date(event.endedAt).toLocaleDateString("en-PH", { day: "numeric", month: "short" });
  return started === ended ? `${started} · closed` : `${started} – ${ended}`;
}
