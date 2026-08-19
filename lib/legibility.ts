import { PATTERN_DUTY, SCRIM, SCRIM_ORDER } from "@/lib/constants";
import { contrastRatio, hexToRgb, isLight, relativeLuminance } from "@/lib/color";
import type { CardArt, Sample, ScrimKey, TextMode } from "@/lib/types";

/** WCAG AA for normal text. Everything below tunes toward this floor. */
const AA = 4.5;

const NEUTRAL_SAMPLE: Sample = [128, 128, 128];

export interface LegibilityInput {
  sample?: Sample;
  scrim?: ScrimKey;
  textMode?: TextMode;
}

export interface LegibilityMetrics {
  /** True when the card should print its text in near-black rather than white. */
  useDark: boolean;
  ratio: number;
  /** True when the scrim itself is a dark wash (it is, unless the text is dark). */
  scrimIsDark: boolean;
}

/**
 * Contrast of the card's text against the artwork AFTER the scrim is composited over it.
 * `sample` is the average colour of the region the balance actually sits in.
 */
export function measure(input: LegibilityInput): LegibilityMetrics {
  const key = input.scrim ?? "soft";
  const mode = input.textMode ?? "auto";
  // Text sits low, in the dense part of the gradient, so it sees most (not all) of the alpha.
  // A uniform veil is the exception — it is the same alpha everywhere.
  const alpha = SCRIM[key] * (key === "veil" ? 1 : 0.86);
  const sample = input.sample ?? NEUTRAL_SAMPLE;

  const rawLum = relativeLuminance(sample);
  const scrimIsDark = mode !== "dark";
  const scrimValue = scrimIsDark ? 0 : 255;
  const blended = sample.map((v) => v * (1 - alpha) + scrimValue * alpha) as Sample;
  const blendedLum = relativeLuminance(blended);

  // With no scrim at all, a bright image is better served by dark text.
  const useDark = mode === "auto" ? alpha === 0 && rawLum > 0.55 : mode === "dark";
  const textLum = useDark ? 0 : 1;

  return {
    useDark,
    ratio: Math.round(contrastRatio(blendedLum, textLum) * 10) / 10,
    scrimIsDark,
  };
}

/** The smallest scrim that clears AA — keeps as much of the photo visible as possible. */
export function autoTuneScrim(photo: LegibilityInput): ScrimKey {
  for (const key of SCRIM_ORDER) {
    if (measure({ ...photo, scrim: key }).ratio >= AA) return key;
  }
  return "veil";
}

/**
 * A pattern's luminance extremes at amplitude `k`. Glyphs cross the whole amplitude, not the
 * mean, so both ends have to clear the contrast floor — tuning on the average leaves every
 * stroke that lands on a dark bar failing.
 *
 * The bare base is in the set deliberately: every pattern paints over `c1`, so `c1` always shows
 * between the marks. Omitting it makes a near-black base with a light accent look mid-toned.
 */
export function patternExtremes(art: Pick<CardArt, "style" | "c1" | "c2">, k: number): Sample[] {
  const c1 = hexToRgb(art.c1);
  const c2 = hexToRgb(art.c2);
  const duty = PATTERN_DUTY[art.style] ?? { amax: 0.9, wmax: 0.55 };
  return [
    c1,
    c1.map((v, i) => v * (1 - duty.amax * k) + c2[i] * duty.amax * k) as unknown as Sample,
    c1.map((v) => v * (1 - duty.wmax * k) + 255 * duty.wmax * k) as unknown as Sample,
  ];
}

export interface PatternTuning {
  /** Amplitude the pattern group is damped to, 0–1. */
  k: number;
  scrim: ScrimKey;
  alpha: number;
  useDark: boolean;
  scrimIsDark: boolean;
  ratio: number;
}

const AMPLITUDES = [1, 0.8, 0.62, 0.48, 0.36, 0.26, 0.18, 0.12] as const;

/**
 * Find the MOST visible pattern (largest amplitude) whose darkest and brightest bands both clear
 * AA under one text colour plus the lightest scrim that works. Damping amplitude beats masking
 * the pattern out of the text zones: the pattern survives across the whole card.
 *
 * Scrim is the OUTER loop because a heavy scrim washes the whole card out, while damping the
 * amplitude only softens the pattern — so exhaust every amplitude scrim-free before reaching
 * for a scrim at all.
 */
function tunePattern(art: Pick<CardArt, "style" | "c1" | "c2">): PatternTuning {
  for (const scrim of ["off", "soft", "strong"] as const) {
    for (const k of AMPLITUDES) {
      const extremes = patternExtremes(art, k);
      for (const textMode of ["light", "dark"] as const) {
        const metrics = extremes.map((sample) => measure({ sample, scrim, textMode }));
        const worst = Math.min(...metrics.map((m) => m.ratio));
        if (worst >= AA) {
          return {
            k,
            scrim,
            alpha: SCRIM[scrim],
            useDark: textMode === "dark",
            scrimIsDark: metrics[0].scrimIsDark,
            ratio: worst,
          };
        }
      }
    }
  }

  // Nothing cleared AA. Fall back to the quietest pattern behind the heaviest gradient scrim.
  const extremes = patternExtremes(art, 0.12);
  const m = measure({ sample: extremes[0], scrim: "strong", textMode: "auto" });
  return {
    k: 0.12,
    scrim: "strong",
    alpha: SCRIM.strong,
    useDark: m.useDark,
    scrimIsDark: m.scrimIsDark,
    ratio: m.ratio,
  };
}

/**
 * Memoised: the search is 3 scrims × 8 amplitudes × 2 text colours, and the art engine runs for
 * every card and every editor thumbnail on each render. Keyed on the only inputs it reads.
 */
const tuningCache = new Map<string, PatternTuning>();

export function patternScrim(art: Pick<CardArt, "style" | "c1" | "c2">): PatternTuning | null {
  if (!PATTERN_DUTY[art.style]) return null;
  const key = `${art.style}|${art.c1}|${art.c2}`;
  const cached = tuningCache.get(key);
  if (cached) return cached;
  const tuning = tunePattern(art);
  tuningCache.set(key, tuning);
  return tuning;
}

/** Should this card print its text in near-black? */
export function usesDarkText(art: CardArt): boolean {
  if (art.style === "photo" && art.photo?.src) return measure(art.photo).useDark;
  return patternScrim(art)?.useDark ?? isLight(art.c1);
}
