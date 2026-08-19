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
  | "Cash on hand"
  | "E-wallet"
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
  | "settings";

export type SheetKind = "withdraw" | "deposit" | "move";
export type HomeLayout = "deck" | "stack";
export type SearchFilter = "All" | "Money in" | "Money out" | CategoryName;

export interface SuccessState {
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
}
