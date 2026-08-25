import type { CardArt, Sample, ScrimKey, TextMode } from "@/lib/types";

import { CARD_TEMPLATE_DATA } from "./cardTemplates.generated";

export const TEMPLATE_CATEGORIES = [
  { id: "all", label: "All" },
  { id: "banks", label: "Banks" },
  { id: "credit-cards", label: "Credit Cards" },
  { id: "digital-banks", label: "Digital Banks" },
  { id: "e-wallets", label: "E-wallets" },
  { id: "membership", label: "Membership" },
  { id: "prepaid", label: "Prepaid" },
] as const;

export type TemplateCategory = (typeof TEMPLATE_CATEGORIES)[number]["id"];
export type TemplateGroup = Exclude<TemplateCategory, "all">;

export interface CardTemplate {
  id: string;
  name: string;
  category: TemplateGroup;
  src: string;
  focal: readonly [number, number];
  sample: readonly [number, number, number];
  fallback: string;
  scrim: ScrimKey;
  textMode: TextMode;
  chip: boolean;
}

export const CARD_TEMPLATES: readonly CardTemplate[] = CARD_TEMPLATE_DATA;
export const DEFAULT_CARD_TEMPLATE = CARD_TEMPLATES[0];

const templateBySource = new Map(CARD_TEMPLATES.map((template) => [template.src, template]));

export function templateForSource(src: string | null | undefined): CardTemplate | null {
  return src ? (templateBySource.get(src) ?? null) : null;
}

export function templateToArt(template: CardTemplate, current?: CardArt): CardArt {
  return {
    ...current,
    style: "photo",
    c1: template.fallback,
    c2: "#ffffff",
    tex: "none",
    layout: current?.layout ?? "standard",
    chip: template.chip,
    tier: null,
    photo: {
      src: template.src,
      zoom: 1,
      px: template.focal[0],
      py: template.focal[1],
      scrim: template.scrim,
      blur: false,
      textMode: template.textMode,
      sample: [...template.sample] as Sample,
    },
  };
}
