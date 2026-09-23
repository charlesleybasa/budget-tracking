import { newId } from "@/lib/ids";
import type { Person, Split, SplitMode, SplitPart, Transaction } from "@/lib/types";

/**
 * Splitting in Pesolita is an annotation on a spend the user already logged — "part of this
 * ₱1,200 was never mine" — not a second ledger. That reframe is why there is no debt graph
 * here and nothing to simplify: the wallet has exactly one owner, so every debt runs in one
 * direction, toward them.
 */

/** Avatar colours new people are assigned from, in order. Drawn from the app's own palette. */
export const PERSON_COLORS: readonly string[] = [
  "#1d6ff2",
  "#0b8f6a",
  "#f0483e",
  "#7c3aed",
  "#ec4899",
  "#f97316",
  "#0891b2",
  "#ffca28",
];

/** Reserved id for the wallet owner, so "me" can sit in a list of people without being one. */
export const ME_ID = "me";

/** Centavo-accurate rounding. Money maths in floats drifts; every split lands through this. */
function centavos(n: number): number {
  return Math.round(n * 100) / 100;
}

export function nextPersonColor(existing: readonly Person[]): string {
  return PERSON_COLORS[existing.length % PERSON_COLORS.length];
}

export function makePerson(name: string, existing: readonly Person[], handle?: string): Person {
  return {
    id: newId("person"),
    name: name.trim(),
    color: nextPersonColor(existing),
    ...(handle?.trim() ? { handle: handle.trim() } : {}),
    archived: false,
  };
}

export function personInitial(name: string): string {
  return name.replace(/[^A-Za-z]/g, "").slice(0, 1).toUpperCase() || "?";
}

/**
 * Split `total` evenly between the owner and `people`.
 *
 * ₱1,000 across three is ₱333.33 each and a centavo short. The remainder always goes to the
 * wallet owner — the sheet says so out loud — rather than rotating between members the way
 * Splitwise does. With one ledger owner that rule is both simpler and impossible to argue
 * with, and deciding it here once stops it drifting between call sites.
 */
export function splitEvenly(total: number, people: readonly Person[]): Split {
  const heads = people.length + 1;
  const each = centavos(Math.floor((total * 100) / heads) / 100);
  const parts: SplitPart[] = people.map((p) => ({
    personId: p.id,
    name: p.name,
    amount: each,
    settledAt: null,
  }));
  // Whatever the floor left behind lands on the owner, so the parts always sum to the bill.
  const mine = centavos(total - each * people.length);
  return { mode: "even", mine, parts };
}

/**
 * Split by shares — "Bea had two plates". The owner always holds one share; the remainder
 * rule is the same as even, for the same reason.
 */
export function splitByShares(
  total: number,
  people: readonly Person[],
  shares: Readonly<Record<string, number>>,
  myShares = 1,
): Split {
  const mineShares = Math.max(0, myShares);
  const totalShares =
    mineShares + people.reduce((sum, p) => sum + Math.max(0, shares[p.id] ?? 1), 0);
  if (totalShares <= 0) return splitEvenly(total, people);

  const parts: SplitPart[] = people.map((p) => {
    const own = Math.max(0, shares[p.id] ?? 1);
    return {
      personId: p.id,
      name: p.name,
      amount: centavos(Math.floor((total * own * 100) / totalShares) / 100),
      shares: own,
      settledAt: null,
    };
  });
  const mine = centavos(total - parts.reduce((sum, part) => sum + part.amount, 0));
  return { mode: "shares", mine, parts };
}

/**
 * Split by exact amounts the user typed. The owner takes whatever is left over, which is
 * what makes this mode safe to edit a field at a time: the split always sums to the bill,
 * so there is no "₱20 unaccounted for" error state to design.
 */
export function splitByExact(
  total: number,
  people: readonly Person[],
  amounts: Readonly<Record<string, number>>,
): Split {
  const parts: SplitPart[] = people.map((p) => ({
    personId: p.id,
    name: p.name,
    amount: centavos(Math.max(0, amounts[p.id] ?? 0)),
    settledAt: null,
  }));
  const mine = centavos(total - parts.reduce((sum, part) => sum + part.amount, 0));
  return { mode: "exact", mine, parts };
}

/** Rebuild a split for a new total or a new set of people, keeping the mode and its inputs. */
export function resplit(total: number, people: readonly Person[], previous: Split | null): Split {
  if (!previous || previous.mode === "even") return splitEvenly(total, people);
  if (previous.mode === "shares") {
    const shares = Object.fromEntries(previous.parts.map((p) => [p.personId, p.shares ?? 1]));
    return splitByShares(total, people, shares);
  }
  const amounts = Object.fromEntries(previous.parts.map((p) => [p.personId, p.amount]));
  return splitByExact(total, people, amounts);
}

/**
 * Rescale an existing split after its transaction's amount was edited.
 *
 * Parts somebody has already paid back are left exactly as they are — money that has changed
 * hands is not ours to quietly rewrite — so only the open parts move, and the owner absorbs
 * whatever is left. Editing a ₱1,200 three-way down to ₱900 after one person settled leaves
 * their ₱400 alone and re-splits the rest.
 */
export function resplitForTotal(total: number, previous: Split): Split {
  const settled = previous.parts.filter((p) => p.settledAt);
  const open = previous.parts.filter((p) => !p.settledAt);
  const settledTotal = settled.reduce((sum, p) => sum + p.amount, 0);
  const remaining = Math.max(0, centavos(total - settledTotal));

  const people: Person[] = open.map((p) => ({
    id: p.personId,
    name: p.name,
    color: "#6d6d72",
    archived: false,
  }));
  const rebuilt = resplit(remaining, people, { ...previous, parts: open });
  const byId = new Map(rebuilt.parts.map((p) => [p.personId, p]));

  return {
    mode: previous.mode,
    mine: rebuilt.mine,
    // Original order is preserved so the editor's rows do not reshuffle under the user.
    parts: previous.parts.map((part) => {
      if (part.settledAt) return part;
      const next = byId.get(part.personId);
      return next ? { ...part, amount: next.amount, shares: next.shares ?? part.shares } : part;
    }),
  };
}

/**
 * What this transaction actually cost the wallet owner, signed the same way `amount` is.
 *
 * `amount` stays the full bill because the card really did lose that much and the balance
 * must never lie. Every spend analytic reads this instead, or the app tells the user they
 * spent ₱1,200 on dinner when they spent ₱400 and lent ₱800.
 */
export function myShare(tx: Transaction): number {
  if (!tx.split) return tx.amount;
  return tx.amount < 0 ? -tx.split.mine : tx.split.mine;
}

/** Still-unpaid parts of one split. */
export function outstandingParts(split: Split | null | undefined): SplitPart[] {
  if (!split) return [];
  return split.parts.filter((p) => !p.settledAt);
}

export interface PersonDebt {
  personId: string;
  name: string;
  color: string;
  handle?: string;
  /** Total still owed to the wallet owner. */
  amount: number;
  /** How many spends it is spread across — the reason the strip can say "3 spends". */
  count: number;
  /** Most recent event this person still owes inside, for the row's subtitle. */
  lastEventId: string | null;
}

/**
 * Who owes the wallet owner, and how much. One direction only — there is no "you owe them"
 * side to this ledger, which is what removes any need for debt simplification.
 */
export function debtsByPerson(
  tx: readonly Transaction[],
  people: readonly Person[],
): PersonDebt[] {
  const byId = new Map(people.map((p) => [p.id, p]));
  const totals = new Map<string, PersonDebt>();

  for (const t of tx) {
    for (const part of outstandingParts(t.split)) {
      const existing = totals.get(part.personId);
      if (existing) {
        existing.amount = centavos(existing.amount + part.amount);
        existing.count += 1;
        if (t.eventId) existing.lastEventId ??= t.eventId;
        continue;
      }
      const person = byId.get(part.personId);
      totals.set(part.personId, {
        personId: part.personId,
        // The part's own snapshot wins for a deleted person, so history still reads.
        name: person?.name ?? part.name,
        color: person?.color ?? "#6d6d72",
        ...(person?.handle ? { handle: person.handle } : {}),
        amount: part.amount,
        count: 1,
        lastEventId: t.eventId ?? null,
      });
    }
  }

  return [...totals.values()].filter((d) => d.amount > 0.004).sort((a, b) => b.amount - a.amount);
}

/** Everything still out with other people, across every person and event. */
export function totalOwedToYou(tx: readonly Transaction[]): number {
  return centavos(
    tx.reduce(
      (sum, t) => sum + outstandingParts(t.split).reduce((s, p) => s + p.amount, 0),
      0,
    ),
  );
}

export function splitModeLabel(mode: SplitMode): string {
  return mode === "even" ? "Evenly" : mode === "shares" ? "By shares" : "Exact amounts";
}

/**
 * The reminder text the share sheet sends. Deliberately plain and a little apologetic — a
 * message about money that reads as automated is one people do not send.
 */
export function reminderMessage(debt: PersonDebt, ownerName: string): string {
  const who = ownerName.trim();
  const sign = who ? ` — ${who}` : "";
  const amount = debt.amount.toLocaleString("en-PH", {
    minimumFractionDigits: 2,
    maximumFractionDigits: 2,
  });
  const spends = debt.count === 1 ? "spend" : `${debt.count} spends`;
  return `Hi ${debt.name}! Sorry to bug you — that's ₱${amount} from our ${spends} together whenever you get a chance${sign}`;
}
