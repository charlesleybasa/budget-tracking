"use client";

import {
  createContext,
  useCallback,
  useContext,
  useEffect,
  useMemo,
  useReducer,
  useRef,
  type ReactNode,
} from "react";
import { flushSync } from "react-dom";

import { ART_STYLES, DECK_ORIGIN, DECK_STEP, PALETTES, TEXTURES } from "@/lib/constants";
import { DEFAULT_CARD_TEMPLATE, templateToArt } from "@/lib/cardTemplates";
import { peso } from "@/lib/format";
import { autoTuneScrim } from "@/lib/legibility";
import { newId } from "@/lib/ids";
import type { BackupPayload } from "@/lib/backup";
import { migrateCards, migrateEvents, migratePeople, migrateTransactions } from "@/lib/migrate";
import { LOW_BALANCE, cardIndex, findCard, findEvent, runningEvent } from "@/lib/selectors";
import {
  makePerson,
  resplitForTotal,
  splitByExact,
  splitByShares,
  splitEvenly,
} from "@/lib/split";
import { clear as clearStorage } from "@/lib/storage";
import { load, save } from "@/lib/storage";
import type {
  Card,
  CardArt,
  CardDraft,
  CardKind,
  CategoryName,
  EventGroup,
  HomeLayout,
  Person,
  PhotoArt,
  Screen,
  SearchFilter,
  SheetKind,
  Split,
  SplitMode,
  SuccessState,
  Transaction,
} from "@/lib/types";

export interface WalletState {
  hydrated: boolean;

  screen: Screen;

  // onboarding
  onboarded: boolean;
  obStep: number;
  obKind: CardKind | null;
  obName: string;
  obBal: string;
  obArt: CardArt;
  userName: string;

  // data
  cards: Card[];
  tx: Transaction[];
  /** People a spend can be split with. Local chips, not accounts — nothing syncs. */
  people: Person[];
  /** Trips and nights out a spend can belong to. */
  events: EventGroup[];
  /** Notices are derived from balances; only the dismissals are stored. */
  dismissedNotices: string[];
  activeId: string;

  // home
  homeLayout: HomeLayout;
  stackOpenId: string | null;
  trackX: number;
  /** Measured carousel step (card width + gap). Set by the deck once it knows its size. */
  deckStep: number;
  dragging: boolean;
  dragStartX: number;
  dragFrom: number;
  privacy: boolean;

  // transaction sheet
  sheet: SheetKind | null;
  sheetCardId: string;
  moveToId: string;
  amt: string;
  cat: CategoryName;
  note: string;
  /** Attached receipt photo as a data URL, or null when none is attached. */
  receipt: string | null;

  // split draft — part of the transaction sheet, not a screen of its own
  /** People this spend is being split with. Empty means "just me", the default. */
  splitWith: string[];
  splitMode: SplitMode;
  /** Shares mode, keyed by person id. */
  splitShares: Record<string, number>;
  /** Exact mode, keyed by person id, held as typed text so a half-typed "12." survives. */
  splitExact: Record<string, string>;
  /** Event this spend will be tagged with, or null. */
  sheetEventId: string | null;

  // events
  /** The event open on the event detail screen. */
  openEventId: string | null;

  /**
   * The settlement waiting on slide-to-confirm, or null. Getting paid back moves real money
   * into a real card, so it asks for a deliberate gesture rather than a tap that can happen
   * by accident in a pocket. `txId` empty means "everything this person owes".
   */
  pendingSettle: { personId: string; txId: string } | null;

  // transfer screen
  fromId: string;
  toId: string;
  swapRot: number;

  // search
  query: string;
  filter: SearchFilter;

  // nudges — preferences only; nothing schedules a real notification yet
  nudgeLowBalance: boolean;
  nudgeDailyLog: boolean;

  // editor
  ed: CardDraft | null;
  edNew: boolean;

  /** The transaction open in the edit sheet, or null when it is closed. */
  editingTxId: string | null;

  // overlays
  success: SuccessState | null;
  toast: string | null;
  /** Confirmation shown before the card currently open in the editor is deleted. */
  cardDeleteOpen: boolean;
  /**
   * The erase confirmation. It lives here rather than in the settings screen because the
   * dialog has to render above the navigation, and a screen's own transform traps anything
   * inside it in a stacking context the nav sits above.
   */
  eraseOpen: boolean;
  /**
   * Card whose receiving QR is open full screen, or null. Here rather than in the detail
   * screen for the same reason as `eraseOpen`: it has to paint over the navigation rail,
   * and a screen's own transform traps anything inside it below that.
   */
  qrCardId: string | null;
}

const DEFAULT_ART: CardArt = {
  style: "blob",
  c1: "#ffca28",
  c2: "#0b0b0c",
  tex: "grain",
  layout: "standard",
};

/** A new wallet is genuinely empty — onboarding is what puts the first card in it. */
function initialState(): WalletState {
  return {
    hydrated: false,
    screen: "onboard",
    onboarded: false,
    obStep: 0,
    obKind: null,
    obName: "",
    obBal: "",
    obArt: { ...DEFAULT_ART },
    userName: "",
    cards: [],
    tx: [],
    people: [],
    events: [],
    dismissedNotices: [],
    activeId: "",
    // Deck is the guided view: one card plus the activity panel, which is where a new
    // wallet's "log your first spend" prompt lives.
    homeLayout: "deck",
    stackOpenId: null,
    trackX: DECK_ORIGIN,
    deckStep: DECK_STEP,
    dragging: false,
    dragStartX: 0,
    dragFrom: 0,
    privacy: false,
    sheet: null,
    sheetCardId: "",
    moveToId: "",
    amt: "",
    cat: "Food",
    note: "",
    receipt: null,
    splitWith: [],
    splitMode: "even",
    splitShares: {},
    splitExact: {},
    sheetEventId: null,
    openEventId: null,
    pendingSettle: null,
    fromId: "",
    toId: "",
    swapRot: 0,
    query: "",
    filter: "All",
    nudgeLowBalance: true,
    nudgeDailyLog: true,
    ed: null,
    edNew: false,
    editingTxId: null,
    success: null,
    toast: null,
    cardDeleteOpen: false,
    eraseOpen: false,
    qrCardId: null,
  };
}

/** UI-only fields a plain patch is allowed to touch. */
type UiPatch = Partial<
  Pick<
    WalletState,
    | "privacy"
    | "homeLayout"
    | "query"
    | "filter"
    | "cat"
    | "note"
    | "receipt"
    | "amt"
    | "userName"
    | "obStep"
    | "obKind"
    | "obName"
    | "obBal"
    | "obArt"
    | "stackOpenId"
    | "sheet"
    | "sheetCardId"
    | "moveToId"
    | "fromId"
    | "toId"
    | "swapRot"
    | "toast"
    | "success"
    | "activeId"
    | "nudgeLowBalance"
    | "nudgeDailyLog"
    | "onboarded"
    | "deckStep"
    | "cardDeleteOpen"
    | "eraseOpen"
    | "qrCardId"
    | "sheetEventId"
    | "openEventId"
    | "pendingSettle"
  >
>;

type Action =
  | { type: "hydrate"; state: Partial<WalletState> }
  | { type: "patch"; patch: UiPatch }
  | { type: "go"; screen: Screen }
  | { type: "snapTo"; index: number }
  | { type: "setDeckStep"; step: number }
  | { type: "dragStart"; x: number }
  | { type: "dragMove"; x: number }
  | { type: "dragEnd" }
  | { type: "dismissNotice"; id: string }
  | { type: "pressKey"; key: string }
  | { type: "openSheet"; kind: SheetKind; cardId?: string }
  | { type: "saveTx" }
  | { type: "doTransfer" }
  | { type: "openTxEdit"; id: string }
  | { type: "closeTxEdit" }
  | { type: "saveTxEdit" }
  | { type: "deleteTx"; id: string }
  | { type: "toggleFreeze"; cardId: string }
  | { type: "openEditor"; cardId: string | null }
  | { type: "editCard"; patch: Partial<CardDraft> }
  | { type: "editArt"; patch: Partial<CardArt> }
  | { type: "editPhoto"; patch: Partial<PhotoArt> }
  | { type: "randomizeArt" }
  | { type: "saveCard" }
  | { type: "deleteCard" }
  | { type: "finishOnboarding" }
  | { type: "closeSuccess" }
  | { type: "resetEverything" }
  | { type: "restore"; payload: BackupPayload }
  | { type: "addPerson"; name: string; handle?: string }
  | { type: "editPerson"; id: string; patch: Partial<Person> }
  | { type: "deletePerson"; id: string }
  | { type: "toggleSplitPerson"; id: string }
  | { type: "setSplitMode"; mode: SplitMode }
  | { type: "setSplitShare"; id: string; shares: number }
  | { type: "setSplitExact"; id: string; value: string }
  | { type: "clearSplit" }
  | { type: "settlePart"; txId: string; personId: string; cardId?: string }
  | { type: "unsettlePart"; txId: string }
  | { type: "createEvent"; name: string; emoji: string }
  | { type: "editEvent"; id: string; patch: Partial<EventGroup> }
  | { type: "closeEvent"; id: string }
  | { type: "reopenEvent"; id: string }
  | { type: "deleteEvent"; id: string }
  | { type: "setTxEvent"; txId: string; eventId: string | null };

/**
 * The card is the same object on both screens, so the move between them is explained by
 * morphing it rather than by cross-fading two unrelated pictures of it. Everywhere else a
 * plain screen swap is faster and says as much.
 */
const MORPH_SCREENS = new Set<Screen>(["home", "detail"]);

function withToast(state: WalletState, toast: string): WalletState {
  return { ...state, toast };
}

/**
 * A dismissal only silences a notice while it is still true. Once a card climbs back above
 * the threshold its dismissal is dropped, so the nudge can fire again if it dips later.
 */
function pruneDismissals(cards: readonly Card[], dismissed: readonly string[]): string[] {
  return dismissed.filter((id) => {
    const cardId = id.startsWith("low:") ? id.slice(4) : null;
    if (!cardId) return true;
    const card = cards.find((c) => c.id === cardId);
    return !!card && card.bal < LOW_BALANCE;
  });
}

/** The people currently selected in the split draft, in the order the user picked them. */
function selectedPeople(state: WalletState): Person[] {
  return state.splitWith.flatMap((id) => {
    const person = state.people.find((p) => p.id === id);
    return person ? [person] : [];
  });
}

/**
 * The split the current draft describes, or null when the spend is just the user's. Built
 * from the draft on demand rather than kept in state, so the amount keypad and the people
 * picker can never disagree about what the split currently is.
 */
function draftSplit(state: WalletState, total: number): Split | null {
  const people = selectedPeople(state);
  if (people.length === 0 || !(total > 0)) return null;

  if (state.splitMode === "shares") {
    return splitByShares(total, people, state.splitShares);
  }
  if (state.splitMode === "exact") {
    const amounts = Object.fromEntries(
      people.map((p) => [p.id, parseFloat(state.splitExact[p.id] ?? "") || 0]),
    );
    return splitByExact(total, people, amounts);
  }
  return splitEvenly(total, people);
}

/** Clears the split draft back to "just me". */
const NO_SPLIT = {
  splitWith: [] as string[],
  splitMode: "even" as SplitMode,
  splitShares: {} as Record<string, number>,
  splitExact: {} as Record<string, string>,
};

function reducer(state: WalletState, action: Action): WalletState {
  switch (action.type) {
    case "hydrate":
      return { ...state, ...action.state, hydrated: true };

    case "patch":
      return { ...state, ...action.patch };

    // Entrances are CSS animations that replay when a screen mounts, so navigating is
    // just a screen swap — there is no motion flag that a fast second tap can strand.
    case "go":
      return { ...state, screen: action.screen };

    case "snapTo": {
      if (state.cards.length === 0) return state;
      const index = Math.max(0, Math.min(state.cards.length - 1, action.index));
      return {
        ...state,
        activeId: state.cards[index].id,
        trackX: DECK_ORIGIN - index * state.deckStep,
        dragging: false,
      };
    }

    // Re-anchoring here rather than in a follow-up dispatch keeps the track from landing
    // between cards when the viewport resizes mid-session.
    case "setDeckStep": {
      if (action.step === state.deckStep) return state;
      const index = cardIndex(state.cards, state.activeId);
      return { ...state, deckStep: action.step, trackX: DECK_ORIGIN - index * action.step };
    }

    case "dragStart":
      return { ...state, dragging: true, dragStartX: action.x, dragFrom: state.trackX };

    case "dragMove":
      if (!state.dragging) return state;
      return { ...state, trackX: state.dragFrom + (action.x - state.dragStartX) };

    case "dragEnd": {
      if (!state.dragging) return state;
      const index = Math.round((DECK_ORIGIN - state.trackX) / state.deckStep);
      return reducer(state, { type: "snapTo", index });
    }

    case "dismissNotice":
      return state.dismissedNotices.includes(action.id)
        ? state
        : { ...state, dismissedNotices: [...state.dismissedNotices, action.id] };

    case "pressKey": {
      const k = action.key;
      let a = state.amt;
      if (k === "del") {
        a = a.slice(0, -1);
      } else if (k === ".") {
        if (a.includes(".")) return state;
        a = (a || "0") + ".";
      } else {
        if (a.includes(".") && a.split(".")[1].length >= 2) return state;
        if (a.replace(".", "").length >= 8) return state;
        a = a === "0" ? k : a + k;
      }
      return { ...state, amt: a };
    }

    case "openSheet": {
      // A silent no-op is worse than a refusal: say why nothing happened.
      if (state.cards.length === 0) return withToast(state, "Add a card first.");
      // A spend logged while an event is running belongs to it unless the user says
      // otherwise — the alternative is tagging every row by hand on a trip.
      const running = action.kind === "withdraw" ? runningEvent(state.events) : undefined;
      return {
        ...state,
        ...NO_SPLIT,
        sheet: action.kind,
        amt: "",
        note: "",
        cat: "Food",
        receipt: null,
        sheetCardId: action.cardId ?? state.activeId,
        sheetEventId: running?.id ?? null,
        // An event carries its members, so the usual crowd is pre-selected on arrival.
        splitWith: running ? running.memberIds.filter((id) => state.people.some((p) => p.id === id)) : [],
      };
    }

    case "saveTx": {
      const amount = parseFloat(state.amt);
      if (!amount) return withToast(state, "Put a number in first.");

      const from = findCard(state.cards, state.sheetCardId);
      if (!from) return withToast(state, "Add a card first.");

      // Move lives in the same sheet as Spend and Top up — same amount, same keypad,
      // one intent switch.
      if (state.sheet === "move") {
        const to = findCard(state.cards, state.moveToId);
        if (!to || to.id === from.id) return withToast(state, "Pick a different card to move into.");
        if (amount > from.bal) return withToast(state, `That's more than ${from.nick} has.`);
        const moved = state.cards.map((c) =>
          c.id === from.id ? { ...c, bal: c.bal - amount } : c.id === to.id ? { ...c, bal: c.bal + amount } : c,
        );
        return {
          ...state,
          cards: moved,
          dismissedNotices: pruneDismissals(moved, state.dismissedNotices),
          tx: [
            {
              id: newId("tx"),
              cardId: to.id,
              merchant: `From ${from.nick}`,
              cat: "Bills",
              amount,
              at: Date.now(),
              note: "Moved",
            },
            ...state.tx,
          ],
          sheet: null,
          success: {
            kind: "moved",
            head: "Moved.",
            body: `₱${peso(amount)} from ${from.nick} to ${to.nick}. No fees, because no bank was involved.`,
          },
        };
      }

      const sign = state.sheet === "deposit" ? 1 : -1;
      if (sign < 0 && from.frozen) return withToast(state, `${from.nick} is frozen. Unfreeze it first.`);
      // Backstop for the two states the sheet already shows inline. A card cannot go negative:
      // an empty one has nothing to spend, and a spend larger than the balance would overdraw
      // it. Both are caught in the sheet before the user can submit; this is the guard for
      // anything that reaches the reducer another way.
      if (sign < 0 && from.bal <= 0) return withToast(state, `${from.nick} is empty. Top it up first.`);
      if (sign < 0 && amount > from.bal) {
        return withToast(state, `That's ₱${peso(amount - from.bal)} more than ${from.nick} has.`);
      }

      // Only a spend can be split — money coming in was never anybody else's.
      const split = sign < 0 ? draftSplit(state, amount) : null;
      const owed = split ? split.parts.reduce((sum, p) => sum + p.amount, 0) : 0;

      const nextCards = state.cards.map((c) => (c.id === from.id ? { ...c, bal: c.bal + sign * amount } : c));
      return {
        ...state,
        ...NO_SPLIT,
        cards: nextCards,
        dismissedNotices: pruneDismissals(nextCards, state.dismissedNotices),
        tx: [
          {
            id: newId("tx"),
            cardId: from.id,
            merchant: state.note || (sign > 0 ? "Top up" : state.cat),
            cat: state.cat,
            // The card really lost the whole bill, so this stays the full figure. What the
            // user actually spent lives in `split.mine`, and that is what analytics read.
            amount: sign * amount,
            at: Date.now(),
            note: state.note,
            ...(state.receipt ? { receipt: state.receipt } : {}),
            eventId: state.sheetEventId,
            split,
          },
          ...state.tx,
        ],
        sheet: null,
        success: {
          kind: sign > 0 ? "funded" : "logged",
          head: sign > 0 ? "Funded." : split ? "Logged and split." : "Logged it.",
          body:
            sign > 0
              ? `₱${peso(amount)} added to ${from.nick}. Look at you, being responsible.`
              : split
                ? `₱${peso(split.mine)} was yours. ₱${peso(owed)} is coming back from ${
                    split.parts.length === 1 ? split.parts[0].name : `${split.parts.length} people`
                  }.`
                : `₱${peso(amount)} off ${from.nick}. That took four seconds.`,
        },
      };
    }

    case "doTransfer": {
      const amount = parseFloat(state.amt);
      if (!amount) return withToast(state, "How much are we moving?");
      const from = findCard(state.cards, state.fromId);
      const to = findCard(state.cards, state.toId);
      if (!from || !to) return withToast(state, "Pick two cards first.");
      if (from.id === to.id) return withToast(state, "Pick a different card to move into.");
      if (amount > from.bal) return withToast(state, `That's more than ${from.nick} has.`);
      const transferred = state.cards.map((c) =>
        c.id === from.id ? { ...c, bal: c.bal - amount } : c.id === to.id ? { ...c, bal: c.bal + amount } : c,
      );
      return {
        ...state,
        cards: transferred,
        dismissedNotices: pruneDismissals(transferred, state.dismissedNotices),
        tx: [
          {
            id: newId("tx"),
            cardId: to.id,
            merchant: `From ${from.nick}`,
            cat: "Bills",
            amount,
            at: Date.now(),
            note: "Transfer",
          },
          ...state.tx,
        ],
        amt: "",
        success: {
          kind: "moved",
          head: "Moved.",
          body: `₱${peso(amount)} from ${from.nick} to ${to.nick}. No fees, because no bank was involved.`,
        },
      };
    }

    // Reopens the amount/category/note keypad the create flow uses, seeded from the entry
    // instead of blank. It shares those fields rather than a parallel set of edit-only ones,
    // since only one of "creating" and "editing" is ever open at a time.
    case "openTxEdit": {
      const tx = state.tx.find((t) => t.id === action.id);
      if (!tx) return state;
      return {
        ...state,
        editingTxId: tx.id,
        amt: String(Math.abs(tx.amount)),
        cat: tx.cat,
        note: tx.note || tx.merchant,
        receipt: tx.receipt ?? null,
      };
    }

    case "closeTxEdit":
      return { ...state, editingTxId: null };

    case "saveTxEdit": {
      const id = state.editingTxId;
      if (!id) return state;
      const original = state.tx.find((t) => t.id === id);
      if (!original) return { ...state, editingTxId: null };

      const amount = parseFloat(state.amt);
      if (!amount) return withToast(state, "Put a number in first.");

      // The sign — money in or out — isn't something the edit sheet exposes; only the
      // amount, category and label can change, not what kind of entry this is.
      const sign = original.amount < 0 ? -1 : 1;
      const newAmount = sign * amount;
      const noteText = state.note.trim();
      const updated: Transaction = {
        ...original,
        amount: newAmount,
        cat: state.cat,
        note: noteText,
        merchant: noteText || original.merchant,
        receipt: state.receipt ?? undefined,
        // Editing the bill has to move the split with it, or the owner's share would still
        // describe the old amount and every analytic reading it would be wrong.
        split: original.split ? resplitForTotal(amount, original.split) : original.split,
      };

      const delta = newAmount - original.amount;
      // Same rule as logging a spend, applied to the change rather than the whole amount:
      // this entry's original value is already reflected in the balance, so only the delta
      // can push the card under. Without this the sheet's rule would have an obvious hole —
      // block a ₱5,000 spend, then edit a ₱10 one up to ₱5,000 instead.
      const editedCard = findCard(state.cards, original.cardId);
      if (editedCard && delta < 0 && editedCard.bal + delta < 0) {
        return withToast(state, `That's ₱${peso(Math.abs(editedCard.bal + delta))} more than ${editedCard.nick} has.`);
      }
      const nextCards = state.cards.map((c) => (c.id === original.cardId ? { ...c, bal: c.bal + delta } : c));

      return withToast(
        {
          ...state,
          cards: nextCards,
          dismissedNotices: pruneDismissals(nextCards, state.dismissedNotices),
          tx: state.tx.map((t) => (t.id === id ? updated : t)),
          editingTxId: null,
        },
        "Updated.",
      );
    }

    case "deleteTx": {
      const tx = state.tx.find((t) => t.id === action.id);
      if (!tx) return state;

      // A split spend that has been settled owns the top-ups that settled it. Leaving them
      // behind would credit the user for repaying a bill that no longer exists.
      const orphans = state.tx.filter((t) => t.repaysTxId === tx.id);
      const doomed = new Set([tx.id, ...orphans.map((t) => t.id)]);

      // Reverses exactly what creating each entry did to its own card's balance.
      const nextCards = state.cards.map((c) => {
        const delta = [tx, ...orphans]
          .filter((t) => t.cardId === c.id)
          .reduce((sum, t) => sum + t.amount, 0);
        return delta ? { ...c, bal: c.bal - delta } : c;
      });

      return withToast(
        {
          ...state,
          cards: nextCards,
          dismissedNotices: pruneDismissals(nextCards, state.dismissedNotices),
          tx: state.tx.filter((t) => !doomed.has(t.id)),
          editingTxId: state.editingTxId === action.id ? null : state.editingTxId,
        },
        orphans.length ? "Deleted, along with what was paid back." : "Deleted. Balance adjusted.",
      );
    }

    case "toggleFreeze": {
      const card = findCard(state.cards, action.cardId);
      if (!card) return state;
      return withToast(
        {
          ...state,
          cards: state.cards.map((c) => (c.id === action.cardId ? { ...c, frozen: !c.frozen } : c)),
        },
        card.frozen ? `${card.nick} is live again.` : `${card.nick} frozen. No spending from it.`,
      );
    }

    case "openEditor": {
      if (action.cardId === null) {
        return {
          ...state,
          screen: "editor",
          edNew: true,
          ed: {
            id: newId("card"),
            kind: "ATM / Debit",
            nick: "",
            last4: "",
            exp: "12 / 28",
            bal: 0,
            limit: 0,
            frozen: false,
            art: templateToArt(DEFAULT_CARD_TEMPLATE, DEFAULT_ART),
          },
        };
      }
      const card = findCard(state.cards, action.cardId);
      if (!card) return state;
      return {
        ...state,
        screen: "editor",
        edNew: false,
        activeId: card.id,
        ed: { ...card, art: { ...card.art, photo: card.art.photo ? { ...card.art.photo } : null } },
      };
    }

    case "editCard":
      return state.ed ? { ...state, ed: { ...state.ed, ...action.patch } } : state;

    case "editArt":
      return state.ed ? { ...state, ed: { ...state.ed, art: { ...state.ed.art, ...action.patch } } } : state;

    case "editPhoto": {
      if (!state.ed?.art.photo) return state;
      return {
        ...state,
        ed: { ...state.ed, art: { ...state.ed.art, photo: { ...state.ed.art.photo, ...action.patch } } },
      };
    }

    case "randomizeArt": {
      if (!state.ed) return state;
      const palette = PALETTES[Math.floor(Math.random() * PALETTES.length)];
      // Photo is not a generated look — randomising into it would blank the card.
      const styles = ART_STYLES.filter((a) => a !== "photo");
      return {
        ...state,
        ed: {
          ...state.ed,
          art: {
            ...state.ed.art,
            style: styles[Math.floor(Math.random() * styles.length)],
            c1: palette[0],
            c2: palette[1],
            tex: TEXTURES[Math.floor(Math.random() * TEXTURES.length)],
          },
        },
      };
    }

    case "saveCard": {
      const ed = state.ed;
      if (!ed) return state;
      if (!ed.nick.trim()) return withToast(state, "Give it a name first.");

      if (state.edNew) {
        const cards = [...state.cards, { ...ed }];
        return withToast(
          {
            ...reducer({ ...state, cards }, { type: "snapTo", index: cards.length - 1 }),
            screen: "home",
            ed: null,
          },
          `${ed.nick} is in the deck.`,
        );
      }

      return withToast(
        {
          ...state,
          cards: state.cards.map((c) => (c.id === ed.id ? { ...ed } : c)),
          screen: "home",
          ed: null,
        },
        "Redesigned.",
      );
    }

    case "deleteCard": {
      const ed = state.ed;
      if (!ed) return state;
      const cards = state.cards.filter((c) => c.id !== ed.id);
      // The history goes with the card, so nothing is left pointing at an id that is gone.
      const tx = state.tx.filter((t) => t.cardId !== ed.id);
      const fallback = cards[0]?.id ?? "";
      const keep = (id: string) => (cards.some((c) => c.id === id) ? id : fallback);

      return withToast(
        {
          ...reducer({ ...state, cards, tx }, { type: "snapTo", index: 0 }),
          screen: "home",
          ed: null,
          cardDeleteOpen: false,
          activeId: keep(state.activeId),
          stackOpenId: state.stackOpenId === ed.id ? fallback || null : state.stackOpenId,
          sheetCardId: keep(state.sheetCardId),
          moveToId: keep(state.moveToId),
          fromId: keep(state.fromId),
          toId: keep(state.toId),
        },
        "Gone. The money went with it.",
      );
    }

    case "finishOnboarding": {
      // Templates normally provide the first nickname; Cash on hand supplies its own. Keep
      // the kind as a final fallback so interrupted or older onboarding drafts still finish
      // with a useful label rather than a generic "My card".
      const kind = state.obKind ?? "ATM / Debit";
      const card: Card = {
        id: newId("card"),
        kind,
        nick: state.obName.trim() || kind,
        last4: "",
        exp: "—",
        bal: parseFloat(state.obBal) || 0,
        limit: 0,
        frozen: false,
        art: { ...state.obArt },
      };
      return withToast(
        {
          ...state,
          cards: [...state.cards, card],
          activeId: card.id,
          stackOpenId: card.id,
          sheetCardId: card.id,
          fromId: card.id,
          trackX: DECK_ORIGIN,
          screen: "home",
          onboarded: true,
        },
        "Welcome. Log your first spend with the blue button.",
      );
    }

    case "closeSuccess":
      return { ...state, success: null, amt: "", screen: "home" };

    // A restore replaces the wallet outright — merging two histories would silently double
    // entries the user already has.
    case "restore": {
      const { payload } = action;
      const first = payload.cards[0]?.id ?? "";
      const second = payload.cards.find((c) => c.id !== first)?.id ?? first;
      return {
        ...initialState(),
        ...payload,
        hydrated: true,
        onboarded: true,
        screen: "home",
        activeId: first,
        stackOpenId: first || null,
        sheetCardId: first,
        moveToId: second,
        fromId: first,
        toId: second,
        toast: `Restored ${payload.cards.length} ${payload.cards.length === 1 ? "card" : "cards"}.`,
      };
    }

    // ── people ───────────────────────────────────────────────────────────────

    case "addPerson": {
      const name = action.name.trim();
      if (!name) return state;
      const existing = state.people.find((p) => p.name.toLowerCase() === name.toLowerCase());
      // Adding a name that is already there selects it instead of making a duplicate, which
      // is what the user meant and stops two "Migo"s owing separate halves of the same bill.
      if (existing) {
        return {
          ...state,
          people: existing.archived
            ? state.people.map((p) => (p.id === existing.id ? { ...p, archived: false } : p))
            : state.people,
          splitWith: state.splitWith.includes(existing.id)
            ? state.splitWith
            : [...state.splitWith, existing.id],
        };
      }
      const person = makePerson(name, state.people, action.handle);
      return {
        ...state,
        people: [...state.people, person],
        // Someone added from inside the sheet is there to be split with — select them.
        splitWith: state.sheet ? [...state.splitWith, person.id] : state.splitWith,
      };
    }

    case "editPerson":
      return {
        ...state,
        people: state.people.map((p) => (p.id === action.id ? { ...p, ...action.patch } : p)),
      };

    case "deletePerson": {
      const person = state.people.find((p) => p.id === action.id);
      if (!person) return state;
      // History is not rewritten: every split part carries its own name snapshot, so past
      // spends keep reading correctly after the person is gone.
      return withToast(
        {
          ...state,
          people: state.people.filter((p) => p.id !== action.id),
          splitWith: state.splitWith.filter((id) => id !== action.id),
          events: state.events.map((e) => ({
            ...e,
            memberIds: e.memberIds.filter((id) => id !== action.id),
          })),
        },
        `${person.name} removed. Their history stays.`,
      );
    }

    // ── split draft ──────────────────────────────────────────────────────────

    case "toggleSplitPerson": {
      const on = state.splitWith.includes(action.id);
      return {
        ...state,
        splitWith: on
          ? state.splitWith.filter((id) => id !== action.id)
          : [...state.splitWith, action.id],
      };
    }

    case "setSplitMode":
      return { ...state, splitMode: action.mode };

    case "setSplitShare":
      return {
        ...state,
        splitShares: { ...state.splitShares, [action.id]: Math.max(0, Math.round(action.shares)) },
      };

    case "setSplitExact":
      return { ...state, splitExact: { ...state.splitExact, [action.id]: action.value } };

    case "clearSplit":
      return { ...state, ...NO_SPLIT };

    // ── settling up ──────────────────────────────────────────────────────────

    /**
     * Getting paid back is real money arriving, not a bookkeeping entry — this is the thing
     * a shared-ledger app structurally cannot do. It tops up an actual card, and the top-up
     * carries `repaysTxId` so income stats know it is recovered money rather than earnings.
     *
     * One settlement can cover several spends at once, because that is how people actually
     * pay each other back: one transfer for the whole night, not one per dish. Every part it
     * covers points at the same settlement id, so undoing it reverses the lot as a unit.
     */
    case "settlePart": {
      // `txId` empty means "everything this person owes", which is what the owed strip asks
      // for; a specific id settles just that one spend, from the event or card detail.
      const covered = state.tx.filter(
        (t) =>
          (!action.txId || t.id === action.txId) &&
          t.split?.parts.some((p) => p.personId === action.personId && !p.settledAt),
      );
      if (covered.length === 0) return state;

      const total = Math.round(
        covered.reduce(
          (sum, t) =>
            sum +
            (t.split?.parts.find((p) => p.personId === action.personId)?.amount ?? 0) * 100,
          0,
        ),
      ) / 100;
      if (!(total > 0)) return state;

      const name =
        covered[0].split?.parts.find((p) => p.personId === action.personId)?.name ?? "They";
      const into = findCard(state.cards, action.cardId ?? covered[0].cardId);
      if (!into) return withToast(state, "Pick a card for it to land in.");

      const settlementId = newId("tx");
      const at = Date.now();
      const ids = new Set(covered.map((t) => t.id));
      const nextCards = state.cards.map((c) =>
        c.id === into.id ? { ...c, bal: c.bal + total } : c,
      );

      return {
        ...state,
        pendingSettle: null,
        cards: nextCards,
        dismissedNotices: pruneDismissals(nextCards, state.dismissedNotices),
        tx: [
          {
            id: settlementId,
            cardId: into.id,
            merchant: `${name} paid you back`,
            cat: covered[0].cat,
            amount: total,
            at,
            note:
              covered.length === 1
                ? covered[0].merchant
                : `${covered.length} spends together`,
            eventId: covered[0].eventId ?? null,
            repaysTxId: covered[0].id,
          },
          ...state.tx.map((t) =>
            !ids.has(t.id) || !t.split
              ? t
              : {
                  ...t,
                  split: {
                    ...t.split,
                    parts: t.split.parts.map((p) =>
                      p.personId === action.personId && !p.settledAt
                        ? { ...p, settledAt: at, settledTxId: settlementId }
                        : p,
                    ),
                  },
                },
          ),
        ],
        success: {
          kind: "funded",
          head: "Settled.",
          body: `₱${peso(total)} from ${name} landed in ${into.nick}. That is one fewer awkward message.`,
        },
      };
    }

    /** Reverses a whole settlement: the top-up goes, and every part it covered reopens. */
    case "unsettlePart": {
      const settlement = state.tx.find((t) => t.id === action.txId);
      if (!settlement || !settlement.repaysTxId) return state;

      const nextCards = state.cards.map((c) =>
        c.id === settlement.cardId ? { ...c, bal: c.bal - settlement.amount } : c,
      );

      return withToast(
        {
          ...state,
          cards: nextCards,
          dismissedNotices: pruneDismissals(nextCards, state.dismissedNotices),
          tx: state.tx
            .filter((t) => t.id !== settlement.id)
            .map((t) =>
              !t.split || !t.split.parts.some((p) => p.settledTxId === settlement.id)
                ? t
                : {
                    ...t,
                    split: {
                      ...t.split,
                      parts: t.split.parts.map((p) =>
                        p.settledTxId === settlement.id
                          ? { ...p, settledAt: null, settledTxId: null }
                          : p,
                      ),
                    },
                  },
            ),
        },
        `Undone. That ₱${peso(settlement.amount)} is owed again.`,
      );
    }

    // ── events ───────────────────────────────────────────────────────────────

    case "createEvent": {
      const name = action.name.trim();
      if (!name) return withToast(state, "Give the event a name first.");
      const event: EventGroup = {
        id: newId("event"),
        name,
        emoji: action.emoji || "📍",
        startedAt: Date.now(),
        endedAt: null,
        // Whoever is selected in the sheet right now is who this trip is with.
        memberIds: [...state.splitWith],
      };
      return withToast(
        { ...state, events: [event, ...state.events], sheetEventId: event.id },
        `${event.name} started. Spends will land in it.`,
      );
    }

    case "editEvent":
      return {
        ...state,
        events: state.events.map((e) => (e.id === action.id ? { ...e, ...action.patch } : e)),
      };

    case "closeEvent": {
      const event = findEvent(state.events, action.id);
      if (!event) return state;
      return withToast(
        {
          ...state,
          events: state.events.map((e) => (e.id === action.id ? { ...e, endedAt: Date.now() } : e)),
          sheetEventId: state.sheetEventId === action.id ? null : state.sheetEventId,
        },
        `${event.name} closed. Nothing new lands in it.`,
      );
    }

    case "reopenEvent":
      return {
        ...state,
        events: state.events.map((e) => (e.id === action.id ? { ...e, endedAt: null } : e)),
      };

    case "deleteEvent": {
      const event = findEvent(state.events, action.id);
      if (!event) return state;
      // Only the grouping goes. The spends are real money and stay in the wallet — dropping
      // them with the event would silently change the user's balances.
      return withToast(
        {
          ...reducer({ ...state, screen: "home" }, { type: "patch", patch: { openEventId: null } }),
          events: state.events.filter((e) => e.id !== action.id),
          tx: state.tx.map((t) => (t.eventId === action.id ? { ...t, eventId: null } : t)),
          sheetEventId: state.sheetEventId === action.id ? null : state.sheetEventId,
        },
        `${event.name} removed. The spends stayed.`,
      );
    }

    case "setTxEvent":
      return {
        ...state,
        tx: state.tx.map((t) => (t.id === action.txId ? { ...t, eventId: action.eventId } : t)),
      };

    // Everything lives on this device, so erasing it is a local operation and immediate.
    case "resetEverything": {
      clearStorage();
      return { ...initialState(), hydrated: true, screen: "onboard" };
    }

    default:
      return state;
  }
}

/** The slice written to localStorage. Ephemeral UI state is deliberately excluded. */
interface Persisted {
  cards: Card[];
  tx: Transaction[];
  people: Person[];
  events: EventGroup[];
  dismissedNotices: string[];
  activeId: string;
  userName: string;
  privacy: boolean;
  homeLayout: HomeLayout;
  onboarded: boolean;
  nudgeLowBalance: boolean;
  nudgeDailyLog: boolean;
}

export interface WalletActions {
  go: (screen: Screen) => void;
  patch: (patch: UiPatch) => void;
  snapTo: (index: number) => void;
  setDeckStep: (step: number) => void;
  dragStart: (x: number) => void;
  dragMove: (x: number) => void;
  dragEnd: () => void;
  dismissNotice: (id: string) => void;
  pressKey: (key: string) => void;
  openSheet: (kind: SheetKind, cardId?: string) => void;
  closeSheet: () => void;
  saveTx: () => void;
  doTransfer: () => void;
  openTxEdit: (id: string) => void;
  closeTxEdit: () => void;
  saveTxEdit: () => void;
  deleteTx: (id: string) => void;
  toggleFreeze: (cardId: string) => void;
  openEditor: (cardId: string | null) => void;
  editCard: (patch: Partial<CardDraft>) => void;
  editArt: (patch: Partial<CardArt>) => void;
  editPhoto: (patch: Partial<PhotoArt>) => void;
  attachPhoto: (photo: PhotoArt) => void;
  randomizeArt: () => void;
  saveCard: () => void;
  deleteCard: () => void;
  finishOnboarding: () => void;
  closeSuccess: () => void;
  resetEverything: () => void;
  restore: (payload: BackupPayload) => void;
  toast: (message: string) => void;

  // people
  addPerson: (name: string, handle?: string) => void;
  editPerson: (id: string, patch: Partial<Person>) => void;
  deletePerson: (id: string) => void;

  // split draft
  toggleSplitPerson: (id: string) => void;
  setSplitMode: (mode: SplitMode) => void;
  setSplitShare: (id: string, shares: number) => void;
  setSplitExact: (id: string, value: string) => void;
  clearSplit: () => void;

  // settling
  /** Opens the slide-to-confirm. `txId` empty means everything this person owes. */
  askSettle: (personId: string, txId?: string) => void;
  cancelSettle: () => void;
  /** `txId` empty settles everything this person owes; an id settles just that one spend. */
  settlePart: (txId: string, personId: string, cardId?: string) => void;
  /** Takes the id of the settlement top-up, and reverses the whole thing. */
  unsettlePart: (settlementTxId: string) => void;

  // events
  createEvent: (name: string, emoji: string) => void;
  editEvent: (id: string, patch: Partial<EventGroup>) => void;
  closeEvent: (id: string) => void;
  reopenEvent: (id: string) => void;
  deleteEvent: (id: string) => void;
  setTxEvent: (txId: string, eventId: string | null) => void;
  openEvent: (id: string) => void;
}

const WalletContext = createContext<{ state: WalletState; actions: WalletActions } | null>(null);

export function WalletProvider({ children }: { children: ReactNode }) {
  const [state, dispatch] = useReducer(reducer, undefined, initialState);

  // ── hydrate from the device, once ──────────────────────────────────────────
  useEffect(() => {
    const saved = load<Persisted>();
    if (!saved) {
      dispatch({ type: "hydrate", state: {} });
      return;
    }

    // Repair before trusting: a released build meets wallets written by older versions.
    const cards = migrateCards(saved.cards);
    const activeId = cards.some((c) => c.id === saved.activeId) ? saved.activeId : (cards[0]?.id ?? "");
    const otherId = cards.find((c) => c.id !== activeId)?.id ?? activeId;

    dispatch({
      type: "hydrate",
      state: {
        cards,
        tx: migrateTransactions(saved.tx, cards),
        people: migratePeople(saved.people),
        events: migrateEvents(saved.events),
        dismissedNotices: saved.dismissedNotices ?? [],
        activeId,
        stackOpenId: activeId || null,
        sheetCardId: activeId,
        fromId: activeId,
        toId: otherId,
        moveToId: otherId,
        userName: saved.userName ?? "",
        privacy: saved.privacy ?? false,
        homeLayout: saved.homeLayout ?? "stack",
        onboarded: saved.onboarded ?? false,
        nudgeLowBalance: saved.nudgeLowBalance ?? true,
        nudgeDailyLog: saved.nudgeDailyLog ?? true,
        screen: saved.onboarded || cards.length > 0 ? "home" : "onboard",
      },
    });
  }, []);

  // ── persist ────────────────────────────────────────────────────────────────
  useEffect(() => {
    if (!state.hydrated) return;
    const ok = save<Persisted>({
      cards: state.cards,
      tx: state.tx,
      people: state.people,
      events: state.events,
      dismissedNotices: state.dismissedNotices,
      activeId: state.activeId,
      userName: state.userName,
      privacy: state.privacy,
      homeLayout: state.homeLayout,
      onboarded: state.onboarded,
      nudgeLowBalance: state.nudgeLowBalance,
      nudgeDailyLog: state.nudgeDailyLog,
    });
    if (!ok) {
      dispatch({
        type: "patch",
        patch: { toast: "Out of storage — a card photo is probably too big to keep." },
      });
    }
  }, [
    state.hydrated,
    state.cards,
    state.tx,
    state.people,
    state.events,
    state.dismissedNotices,
    state.activeId,
    state.userName,
    state.privacy,
    state.homeLayout,
    state.onboarded,
    state.nudgeLowBalance,
    state.nudgeDailyLog,
  ]);

  // ── toast auto-dismiss ─────────────────────────────────────────────────────
  useEffect(() => {
    if (!state.toast) return;
    const id = window.setTimeout(() => dispatch({ type: "patch", patch: { toast: null } }), 2400);
    return () => window.clearTimeout(id);
  }, [state.toast]);

  const toast = useCallback((message: string) => dispatch({ type: "patch", patch: { toast: message } }), []);

  // Actions are memoised, so the current screen is read through a ref rather than closed over.
  const screenRef = useRef(state.screen);
  screenRef.current = state.screen;

  const go = useCallback((screen: Screen) => {
    const morphs = MORPH_SCREENS.has(screen) && MORPH_SCREENS.has(screenRef.current) && screen !== screenRef.current;
    const reduced = window.matchMedia("(prefers-reduced-motion: reduce)").matches;

    if (!morphs || reduced || typeof document.startViewTransition !== "function") {
      dispatch({ type: "go", screen });
      return;
    }

    // The API snapshots before and after the callback, so the update has to be synchronous.
    const transition = document.startViewTransition(() => {
      flushSync(() => dispatch({ type: "go", screen }));
    });
    // A transition interrupted by a faster tap rejects; the navigation itself still stands,
    // so this is noise rather than a failure worth surfacing.
    transition.finished.catch(() => {});
  }, []);

  const actions = useMemo<WalletActions>(
    () => ({
      go,
      patch: (patch) => dispatch({ type: "patch", patch }),
      snapTo: (index) => dispatch({ type: "snapTo", index }),
      setDeckStep: (step) => dispatch({ type: "setDeckStep", step }),
      dragStart: (x) => dispatch({ type: "dragStart", x }),
      dragMove: (x) => dispatch({ type: "dragMove", x }),
      dragEnd: () => dispatch({ type: "dragEnd" }),
      dismissNotice: (id) => dispatch({ type: "dismissNotice", id }),
      pressKey: (key) => dispatch({ type: "pressKey", key }),
      openSheet: (kind, cardId) => dispatch({ type: "openSheet", kind, cardId }),
      closeSheet: () => dispatch({ type: "patch", patch: { sheet: null } }),
      saveTx: () => dispatch({ type: "saveTx" }),
      doTransfer: () => dispatch({ type: "doTransfer" }),
      openTxEdit: (id) => dispatch({ type: "openTxEdit", id }),
      closeTxEdit: () => dispatch({ type: "closeTxEdit" }),
      saveTxEdit: () => dispatch({ type: "saveTxEdit" }),
      deleteTx: (id) => dispatch({ type: "deleteTx", id }),
      toggleFreeze: (cardId) => dispatch({ type: "toggleFreeze", cardId }),
      openEditor: (cardId) => dispatch({ type: "openEditor", cardId }),
      editCard: (patch) => dispatch({ type: "editCard", patch }),
      editArt: (patch) => dispatch({ type: "editArt", patch }),
      editPhoto: (patch) => dispatch({ type: "editPhoto", patch }),
      attachPhoto: (photo) => dispatch({ type: "editArt", patch: { style: "photo", photo } }),
      randomizeArt: () => dispatch({ type: "randomizeArt" }),
      saveCard: () => dispatch({ type: "saveCard" }),
      deleteCard: () => dispatch({ type: "deleteCard" }),
      finishOnboarding: () => dispatch({ type: "finishOnboarding" }),
      closeSuccess: () => dispatch({ type: "closeSuccess" }),
      resetEverything: () => dispatch({ type: "resetEverything" }),
      restore: (payload) => dispatch({ type: "restore", payload }),
      toast,

      addPerson: (name, handle) => dispatch({ type: "addPerson", name, handle }),
      editPerson: (id, patch) => dispatch({ type: "editPerson", id, patch }),
      deletePerson: (id) => dispatch({ type: "deletePerson", id }),

      toggleSplitPerson: (id) => dispatch({ type: "toggleSplitPerson", id }),
      setSplitMode: (mode) => dispatch({ type: "setSplitMode", mode }),
      setSplitShare: (id, shares) => dispatch({ type: "setSplitShare", id, shares }),
      setSplitExact: (id, value) => dispatch({ type: "setSplitExact", id, value }),
      clearSplit: () => dispatch({ type: "clearSplit" }),

      askSettle: (personId, txId = "") =>
        dispatch({ type: "patch", patch: { pendingSettle: { personId, txId } } }),
      cancelSettle: () => dispatch({ type: "patch", patch: { pendingSettle: null } }),
      settlePart: (txId, personId, cardId) => dispatch({ type: "settlePart", txId, personId, cardId }),
      unsettlePart: (settlementTxId) => dispatch({ type: "unsettlePart", txId: settlementTxId }),

      createEvent: (name, emoji) => dispatch({ type: "createEvent", name, emoji }),
      editEvent: (id, patch) => dispatch({ type: "editEvent", id, patch }),
      closeEvent: (id) => dispatch({ type: "closeEvent", id }),
      reopenEvent: (id) => dispatch({ type: "reopenEvent", id }),
      deleteEvent: (id) => dispatch({ type: "deleteEvent", id }),
      setTxEvent: (txId, eventId) => dispatch({ type: "setTxEvent", txId, eventId }),
      openEvent: (id) => {
        dispatch({ type: "patch", patch: { openEventId: id } });
        go("event");
      },
    }),
    [go, toast],
  );

  const value = useMemo(() => ({ state, actions }), [state, actions]);

  return <WalletContext.Provider value={value}>{children}</WalletContext.Provider>;
}

export function useWallet() {
  const ctx = useContext(WalletContext);
  if (!ctx) throw new Error("useWallet must be used inside a WalletProvider");
  return ctx;
}

/** The card the app is currently focused on, or undefined when the wallet is empty. */
export function useActiveCard(): Card | undefined {
  const { state } = useWallet();
  return findCard(state.cards, state.activeId);
}

export function useActiveIndex(): number {
  const { state } = useWallet();
  return cardIndex(state.cards, state.activeId);
}

export { autoTuneScrim };
