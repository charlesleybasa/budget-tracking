import type {
  ArtStyle,
  CardKind,
  Category,
  CategoryName,
  ScrimKey,
  Texture,
  Tier,
} from "@/lib/types";
import type { TemplateGroup } from "@/lib/cardTemplates";

/** Card palettes offered in the editor, as [base, accent] pairs. */
export const PALETTES: ReadonlyArray<readonly [string, string]> = [
  ["#ffca28", "#0b0b0c"],
  ["#1d6ff2", "#f4eedc"],
  ["#f4eedc", "#f0483e"],
  ["#f9a8b4", "#f0483e"],
  ["#16161a", "#ffca28"],
  ["#0b8f6a", "#f4eedc"],
];

/**
 * The card style gallery. Style is the pattern only — colour comes from the palette, so
 * picking a look never silently changes the user's colours.
 */
export const CARD_STYLES: ReadonlyArray<readonly [ArtStyle, string]> = [
  ["blob", "Blob"],
  ["wave", "Wave"],
  ["arc", "Arc"],
  ["mesh", "Mesh"],
  ["grid", "Grid"],
  ["confetti", "Confetti"],
  ["planes", "Planes"],
  ["orbit", "Orbit"],
  ["irid", "Iridescent"],
  ["foil", "Foil"],
  ["crest", "Crest"],
  ["metal", "Metal"],
  ["glyph", "Initial"],
  ["photo", "Photo"],
];

export const ART_STYLES: readonly ArtStyle[] = CARD_STYLES.map(([key]) => key);

export const ART_NAMES: Record<string, string> = Object.fromEntries(CARD_STYLES);

/**
 * High-frequency pattern styles are as hostile to text as a photo is, so they go through the
 * same scrim/contrast machinery. `amax` / `wmax` are the PEAK alpha the accent and the white
 * highlight ever reach in that style, derived from each pattern's stripe duty-cycle × layer
 * opacity in the art engine. These drive the extremes a glyph can land on; a watermark at 0.13
 * must not be modelled as a near-solid stripe, or the tuner washes the card out to protect text
 * that was never at risk.
 *
 * Every style with an accent region belongs in this table — an omission is a silent contrast
 * failure, because `darkText` would then judge the card by its base colour alone.
 */
export const PATTERN_DUTY: Record<string, { amax: number; wmax: number }> = {
  grid: { amax: 0.95, wmax: 0.05 },
  planes: { amax: 0.85, wmax: 0.3 },
  metal: { amax: 0.9, wmax: 0.5 },
  glyph: { amax: 0.15, wmax: 0.14 },
  orbit: { amax: 0.55, wmax: 0.3 },
  foil: { amax: 0.95, wmax: 0.12 },
  irid: { amax: 0.9, wmax: 0.55 },
  crest: { amax: 0.85, wmax: 0.26 },
  blob: { amax: 0.92, wmax: 0.93 },
  wave: { amax: 0.9, wmax: 0.95 },
  arc: { amax: 0.95, wmax: 0.05 },
  mesh: { amax: 0.95, wmax: 0.32 },
  confetti: { amax: 0.9, wmax: 0.8 },
};

/**
 * Scrim ladder. A semi-transparent gradient behind the text is the standard fix for
 * text-over-photo legibility; `veil` is the uniform-overlay variant for busy images.
 */
export const SCRIM: Record<ScrimKey, number> = {
  off: 0,
  soft: 0.32,
  strong: 0.55,
  veil: 0.5,
};

export const SCRIM_NAMES: Record<ScrimKey, string> = {
  off: "None",
  soft: "Soft",
  strong: "Strong",
  veil: "Full veil",
};

export const SCRIM_ORDER: readonly ScrimKey[] = ["off", "soft", "strong", "veil"];

export const TEXTURES: readonly Texture[] = ["none", "grain", "dots", "stripes"];

export const TIERS: readonly Tier[] = ["GOLD", "PLATINUM", "SIGNATURE"];

export const CATEGORIES: readonly Category[] = [
  { name: "Food", color: "#f0483e" },
  { name: "Transport", color: "#1d6ff2" },
  { name: "Bills", color: "#7c3aed" },
  { name: "Groceries", color: "#0b8f6a" },
  { name: "Shopping", color: "#ffca28" },
  { name: "Load", color: "#ec4899" },
  { name: "Health", color: "#0891b2" },
  { name: "Fun", color: "#f97316" },
];

export function categoryColor(name: string): string {
  return (CATEGORIES.find((c) => c.name === name) ?? CATEGORIES[0]).color;
}

/** Keyword table behind the "I'll guess the category" hint in the log-a-spend sheet. */
export const CATEGORY_GUESSES: ReadonlyArray<readonly [readonly string[], CategoryName]> = [
  [
    ["jollibee", "mcdo", "grab food", "kanto", "lunch", "coffee", "starbucks", "milk tea", "silog"],
    "Food",
  ],
  [["grab", "angkas", "jeep", "lrt", "mrt", "gas", "toll", "taxi", "fare"], "Transport"],
  [["meralco", "maynilad", "globe", "pldt", "rent", "water", "internet", "bill"], "Bills"],
  [["sm", "puregold", "palengke", "market", "grocer", "landers"], "Groceries"],
  [["shopee", "lazada", "uniqlo", "shoes", "tiktok shop"], "Shopping"],
  [["load", "data", "promo", "gigafest"], "Load"],
  [["mercury", "watsons", "clinic", "vitamin", "doctor", "gym"], "Health"],
  [["netflix", "spotify", "movie", "cinema", "concert", "game"], "Fun"],
];

/**
 * Onboarding mirrors the template folders. The stored card kind stays singular and useful
 * in the wallet; the user-facing label names the template category they are choosing from.
 * Cash is the one intentionally image-free route and keeps the DIY art engine.
 */
export const CARD_KINDS: ReadonlyArray<readonly [CardKind, string, string, TemplateGroup | null]> = [
  ["ATM / Debit", "Banks", "Traditional bank cards", "banks"],
  ["Credit card", "Credit Cards", "Borrowed spending", "credit-cards"],
  ["Digital bank", "Digital Banks", "App-first bank accounts", "digital-banks"],
  ["E-wallet", "E-wallets", "GCash, Maya and more", "e-wallets"],
  ["Membership card", "Membership Cards", "Rewards and loyalty", "membership"],
  ["Prepaid card", "Prepaid Cards", "Load it before spending", "prepaid"],
  ["Cash on hand", "Cash on hand", "DIY card for physical pesos", null],
];

export const SEARCH_FILTERS = [
  "All",
  "Money out",
  "Money in",
  "Food",
  "Transport",
  "Bills",
  "Shopping",
] as const;

/** Card geometry the art engine is authored against; every size scales off this width. */
export const CARD_W = 320;
export const CARD_H = 196;
export const CARD_R = 22;
/** Deck carousel step: card width + gap. */
export const DECK_STEP = 334;
export const DECK_ORIGIN = 22;
