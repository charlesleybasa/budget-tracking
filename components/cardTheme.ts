import { usesDarkText } from "@/lib/legibility";
import type { CardArt } from "@/lib/types";

export interface CardTheme {
  /** True when the card prints its text in near-black. */
  dark: boolean;
  fg: string;
  fgDim: string;
}

/** Foreground colours a card's own artwork has earned, per the legibility tuner. */
export function cardTheme(art: CardArt): CardTheme {
  const dark = usesDarkText(art);
  return {
    dark,
    fg: dark ? "#0b0b0c" : "#ffffff",
    fgDim: dark ? "rgba(11,11,12,.5)" : "rgba(255,255,255,.55)",
  };
}
