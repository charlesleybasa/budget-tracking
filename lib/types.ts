/**
 * Every generative style the card engine can paint. One flat list: the editor offers these
 * as a single gallery rather than splitting them across overlapping pickers.
 */
export type ArtStyle =
  | "blob"
  | "wave"
  | "arc"
  | "grid"
  | "confetti"
  | "mesh"
  | "planes"
  | "metal"
  | "glyph"
  | "orbit"
  | "foil"
  | "irid"
  | "crest"
  | "photo";

export type ScrimKey = "off" | "soft" | "strong" | "veil";
export type TextMode = "auto" | "light" | "dark";
export type Texture = "none" | "grain" | "dots" | "stripes";
export type CardLayout = "standard" | "compact";
export type Tier = "GOLD" | "PLATINUM" | "SIGNATURE";

/** An average RGB sample of the region the balance sits over. */
export type Sample = [number, number, number];

export interface PhotoArt {
  src: string;
  zoom: number;
  /** Reframing offsets, in percent of the backing element. */
  px: number;
  py: number;
  scrim: ScrimKey;
  blur: boolean;
  textMode: TextMode;
  sample: Sample;
}

export interface CardArt {
  style: ArtStyle;
  /** Base colour — every pattern paints over this, so it always shows between the marks. */
  c1: string;
  /** Accent colour. */
  c2: string;
  tex: Texture;
  layout: CardLayout;
  chip?: boolean;
  tier?: Tier | null;
  /** Oversized initial used as the composition anchor by the `glyph` style. */
  glyph?: string;
  photo?: PhotoArt | null;
}

export type CardKind =
  | "ATM / Debit"
  | "Credit card"
  | "Digital bank"
  | "Cash on hand"
  | "E-wallet"
  | "Membership card"
  | "Prepaid card"
  | "Savings goal"
  | "Emergency fund"
  | "Shared";

export interface Card {
  id: string;
  kind: CardKind;
  nick: string;
  last4: string;
  exp: string;
  bal: number;
  /** Monthly spend ceiling. 0 means "no limit set". */
  limit: number;
  art: CardArt;
  frozen: boolean;
  /** Present on savings cards — progress is measured toward this, not against `limit`. */
  goal?: number;
  /** Shown on the back of the card, so money can be sent to it. */
  accountNumber?: string;
  /** A receiving QR the user photographed or saved, as a data URL. */
  qr?: string;
}

export type CategoryName =
  | "Food"
  | "Transport"
  | "Bills"
  | "Groceries"
  | "Shopping"
  | "Load"
  | "Health"
  | "Fun";

export interface Category {
  name: CategoryName;
  color: string;
}

export interface Transaction {
  id: string;
  /**
   * Owning card. The design comp keyed this by array index, which silently reassigns
   * history to a neighbouring card as soon as one is deleted — so it is an id here.
   */
  cardId: string;
  merchant: string;
  cat: CategoryName;
  /** Negative is money out, positive is money in. */
  amount: number;
  /**
   * When it happened, epoch milliseconds. Stored as an instant rather than as "days ago",
   * which would freeze every entry on the day it was created.
   */
  at: number;
  note: string;
  /** Photo of the receipt, downscaled to a data URL. */
  receipt?: string;
  /** The event this belongs to, when it was logged inside one. */
  eventId?: string | null;
  /**
   * Set when part of this spend was other people's. `amount` stays the full figure — the
   * card really did lose that much — and `split.mine` is what every spend analytic counts.
   */
  split?: Split | null;
  /** Set on a settlement top-up, pointing back at the spend it repays. */
  repaysTxId?: string | null;
}

/**
 * Someone a spend can be split with. Local to the device — there is no account behind it,
 * no invite and no network call, which is what lets splitting exist in an offline wallet.
 */
export interface Person {
  id: string;
  name: string;
  /** Avatar colour. Paired with the initial, so nobody has to upload a photo. */
  color: string;
  /** GCash number or handle. Only ever used to prefill a reminder message. */
  handle?: string;
  /**
   * Archived rather than deleted, so a name stays selectable in history without cluttering
   * the picker. Deleting outright is still offered; see `SplitPart.name`.
   */
  archived: boolean;
}

/** A trip, a night out, a shared household month — the container a spend can belong to. */
export interface EventGroup {
  id: string;
  /** "Day 1 Thailand". */
  name: string;
  emoji: string;
  startedAt: number;
  /** Null while the event is still running. */
  endedAt: number | null;
  /** Pre-selected on every spend logged while this event is open. */
  memberIds: string[];
}

/**
 * How a bill was carved up. `even` is the default and covers almost everything; the other
 * two are behind a single toggle rather than a mode picker.
 */
export type SplitMode = "even" | "shares" | "exact";

/** One person's slice of one spend. */
export interface SplitPart {
  personId: string;
  /**
   * The person's name as it was when the split was saved. A snapshot rather than a lookup,
   * because deleting a person must never rewrite what a night actually cost.
   */
  name: string;
  /** What they owe, in pesos. Always stored resolved — never a ratio or a percentage. */
  amount: number;
  /** Shares mode only, kept so the editor reopens in the state the user left it. */
  shares?: number;
  /** When they paid it back, or null/undefined while it is still outstanding. */
  settledAt?: number | null;
  /** The top-up that settling created, so un-settling can reverse exactly that. */
  settledTxId?: string | null;
}

/**
 * The split carried by a transaction. `mine` is stored rather than derived so the rounding
 * remainder is decided once, at save time, instead of drifting between call sites.
 */
export interface Split {
  mode: SplitMode;
  /** The wallet owner's own share. This, not `amount`, is what spend analytics count. */
  mine: number;
  parts: SplitPart[];
}

export type NoticeKind = "low";

export interface Notice {
  id: string;
  kind: NoticeKind;
  title: string;
  body: string;
}

export type Screen =
  | "onboard"
  | "home"
  | "detail"
  | "insights"
  | "search"
  | "editor"
  | "transfer"
  | "settings"
  | "people"
  | "events"
  | "event";

export type SheetKind = "withdraw" | "deposit" | "move";
export type HomeLayout = "deck" | "stack";
export type SearchFilter = "All" | "Money in" | "Money out" | "Split" | CategoryName;

export interface SuccessState {
  kind: "funded" | "logged" | "moved";
  head: string;
  body: string;
}

/** The draft card being edited in the card editor. */
export interface CardDraft {
  id: string;
  kind: CardKind;
  nick: string;
  last4: string;
  exp: string;
  bal: number;
  limit: number;
  art: CardArt;
  frozen: boolean;
  goal?: number;
  accountNumber?: string;
  qr?: string;
}
