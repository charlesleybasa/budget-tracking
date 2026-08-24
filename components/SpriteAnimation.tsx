"use client";

import {
  useEffect,
  useRef,
  useState,
  type AnimationEvent,
  type CSSProperties,
  type ReactNode,
} from "react";

import styles from "./SpriteAnimation.module.css";

export interface SpriteSheet {
  /** Public path to the atlas. */
  src: string;
  cols: number;
  rows: number;
  /** Must equal cols * rows — the stepping math assumes no blank trailing cells. */
  frames: number;
  fps: number;
  /** Cell dimensions in the atlas, used only for the aspect ratio. */
  cellW: number;
  cellH: number;
  /** Frame held under `prefers-reduced-motion`, as a 0-based index. */
  stillFrame: number;
}

/**
 * Preloads an atlas so it is in cache before the screen that needs it renders.
 * Safe to call repeatedly; every call after the first is a cache hit.
 */
export function preloadSprite(sheet: SpriteSheet) {
  if (typeof window === "undefined") return;
  const img = new window.Image();
  img.src = sheet.src;
}

/**
 * Plays a rendered PNG sequence off a sprite atlas.
 *
 * Deliberately not Lottie. Lottie is a vector format and these sequences are rendered
 * rasters, so a Lottie of one is the same frames base64'd into JSON plus a ~48KB runtime —
 * measured at roughly twice the bytes for identical pixels. A sheet and `steps()` needs no
 * runtime at all.
 *
 * `fallback` renders until the atlas has decoded, so a slow connection sees something
 * immediately rather than an empty box, and a failed request degrades to it rather than to
 * nothing.
 */
export function SpriteAnimation({
  sheet,
  size,
  fallback = null,
  className = "",
  label,
  loop = true,
  replayDelayMs,
}: {
  sheet: SpriteSheet;
  /** Rendered width in px; height follows the cell's aspect ratio. */
  size: number;
  fallback?: ReactNode;
  className?: string;
  /** Supply only when the animation carries meaning no nearby text already carries. */
  label?: string;
  /** Set false to play one complete cycle and hold the final frame. */
  loop?: boolean;
  /** When supplied for a one-shot animation, restart it after this delay. */
  replayDelayMs?: number;
}) {
  const [ready, setReady] = useState(false);
  const [playback, setPlayback] = useState(0);
  const replayTimerRef = useRef<number | null>(null);

  useEffect(() => {
    const img = new window.Image();
    let cancelled = false;
    img.onload = () => {
      if (!cancelled) setReady(true);
    };
    img.src = sheet.src;
    // A cached atlas can already be complete before onload is wired up.
    if (img.complete && img.naturalWidth > 0) setReady(true);
    return () => {
      cancelled = true;
    };
  }, [sheet.src]);

  useEffect(
    () => () => {
      if (replayTimerRef.current !== null) window.clearTimeout(replayTimerRef.current);
    },
    [],
  );

  const onAnimationEnd = (event: AnimationEvent<HTMLDivElement>) => {
    // The row animation spans the complete sheet. The column and fade animations finish
    // sooner, so listening to either would restart before every frame has played.
    if (loop || replayDelayMs === undefined || !event.animationName.includes("spriteRow")) return;
    replayTimerRef.current = window.setTimeout(() => setPlayback((value) => value + 1), replayDelayMs);
  };

  const style = {
    "--sheet": `url("${sheet.src}")`,
    "--cols": sheet.cols,
    "--rows": sheet.rows,
    "--frames": sheet.frames,
    "--fps": sheet.fps,
    "--cell-w": sheet.cellW,
    "--cell-h": sheet.cellH,
    // One complete sheet needs one column pass per row, but only one row pass.
    "--col-iterations": loop ? "infinite" : sheet.rows,
    "--row-iterations": loop ? "infinite" : 1,
    // Percentages that land the still frame on its exact cell: n/(count-1) of the range.
    "--still-x": `${((sheet.stillFrame % sheet.cols) / (sheet.cols - 1)) * 100}%`,
    "--still-y": `${(Math.floor(sheet.stillFrame / sheet.cols) / (sheet.rows - 1)) * 100}%`,
  } as CSSProperties;

  return (
    <div
      className={className}
      style={{ width: size, position: "relative" }}
      role={label ? "img" : undefined}
      aria-label={label}
      aria-hidden={label ? undefined : true}
    >
      {ready ? (
        <div key={playback} className={styles.sprite} style={style} onAnimationEnd={onAnimationEnd} />
      ) : (
        fallback
      )}
    </div>
  );
}
