"use client";

import { useEffect, useState } from "react";

import { Mascot } from "@/components/Mascot";

import styles from "./CelebrateSprite.module.css";

/** Where the atlas lives. Exported so callers can warm it before it is needed. */
export const CELEBRATE_SHEET = "/celebrate.png";

/**
 * Preloads the celebration atlas. Called when the log-spend sheet opens, so the 246KB is
 * usually already in cache by the time the success screen wants it — the user spends a few
 * seconds typing an amount, which is exactly the window to spend on the fetch.
 *
 * Safe to call repeatedly; the browser cache makes every call after the first free.
 */
export function preloadCelebrate() {
  if (typeof window === "undefined") return;
  const img = new window.Image();
  img.src = CELEBRATE_SHEET;
}

/**
 * The rendered celebration, played frame by frame off a sprite sheet.
 *
 * Not a Lottie: the source is 32 rendered PNGs, and Lottie is a vector format, so a Lottie of
 * this would be the same frames base64'd into JSON plus a ~48KB runtime — measured at roughly
 * twice the bytes for identical pixels. A sheet and `steps()` needs no runtime at all.
 *
 * The hand-drawn vector mascot shows underneath until the atlas has decoded, so a slow
 * connection gets a celebration immediately rather than an empty box, and a failed request
 * degrades to the mascot instead of to nothing.
 */
export function CelebrateSprite({ size = 168, className = "" }: { size?: number; className?: string }) {
  const [ready, setReady] = useState(false);

  useEffect(() => {
    const img = new window.Image();
    let cancelled = false;
    img.onload = () => {
      if (!cancelled) setReady(true);
    };
    img.src = CELEBRATE_SHEET;
    // A cached image can be complete before onload is ever wired up.
    if (img.complete && img.naturalWidth > 0) setReady(true);
    return () => {
      cancelled = true;
    };
  }, []);

  return (
    <div className={className} style={{ width: size, position: "relative" }}>
      {ready ? null : <Mascot mood="cheer" size={size} />}
      {ready ? <div className={`${styles.sprite} ${styles.fadeIn}`} /> : null}
    </div>
  );
}
