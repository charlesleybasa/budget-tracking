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
import { peso } from "@/lib/format";
import { autoTuneScrim } from "@/lib/legibility";
import { newId } from "@/lib/ids";
import type { BackupPayload } from "@/lib/backup";
import { migrateCards, migrateTransactions } from "@/lib/migrate";
import { LOW_BALANCE, cardIndex, findCard } from "@/lib/selectors";
import { clear as clearStorage } from "@/lib/storage";
import { load, save } from "@/lib/storage";
import type {
  Card,
  CardArt,
  CardDraft,
  CardKind,
  CategoryName,
  HomeLayout,
  PhotoArt,
  Screen,
  SearchFilter,
  SheetKind,
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
    | "eraseOpen"
    | "qrCardId"
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
  | { type: "restore"; payload: BackupPayload };

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

    case "openSheet":
      // A silent no-op is worse than a refusal: say why nothing happened.
      if (state.cards.length === 0) return withToast(state, "Add a card first.");
      return {
        ...state,
        sheet: action.kind,
        amt: "",
        note: "",
        cat: "Food",
        receipt: null,
        sheetCardId: action.cardId ?? state.activeId,
      };

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

      const nextCards = state.cards.map((c) => (c.id === from.id ? { ...c, bal: c.bal + sign * amount } : c));
      return {
        ...state,
        cards: nextCards,
        dismissedNotices: pruneDismissals(nextCards, state.dismissedNotices),
        tx: [
          {
            id: newId("tx"),
            cardId: from.id,
            merchant: state.note || (sign > 0 ? "Top up" : state.cat),
            cat: state.cat,
            amount: sign * amount,
            at: Date.now(),
            note: state.note,
            ...(state.receipt ? { receipt: state.receipt } : {}),
          },
          ...state.tx,
        ],
        sheet: null,
        success: {
          head: sign > 0 ? "Funded." : "Logged it.",
          body:
            sign > 0
              ? `₱${peso(amount)} added to ${from.nick}. Look at you, being responsible.`
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
      // Reverses exactly what creating it did to its own card's balance — nothing else
      // touched that entry, so nothing else needs undoing.
      const nextCards = state.cards.map((c) => (c.id === tx.cardId ? { ...c, bal: c.bal - tx.amount } : c));
      return withToast(
        {
          ...state,
          cards: nextCards,
          dismissedNotices: pruneDismissals(nextCards, state.dismissedNotices),
          tx: state.tx.filter((t) => t.id !== action.id),
          editingTxId: state.editingTxId === action.id ? null : state.editingTxId,
        },
        "Deleted. Balance adjusted.",
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
            art: { ...DEFAULT_ART },
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
      const card: Card = {
        id: newId("card"),
        kind: state.obKind ?? "ATM / Debit",
        nick: state.obName.trim() || "My card",
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
