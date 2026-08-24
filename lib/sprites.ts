import type { SpriteSheet } from "@/components/SpriteAnimation";

/**
 * The rendered animation atlases, built from PNG sequences by scripts/build-sprites.mjs.
 *
 * Every grid is exact — cols * rows === frames — because the stepping math assumes no blank
 * trailing cells. If you rebuild a sheet with a different frame count, the grid has to change
 * with it.
 */

/** Kuya Ipis celebrating; plays on the log-spend success screen. */
export const CELEBRATE: SpriteSheet = {
  src: "/celebrate.png",
  cols: 8,
  rows: 4,
  frames: 32,
  fps: 24,
  cellW: 300,
  cellH: 372,
  // Peak of the jump, arms up with the coins out.
  stillFrame: 19,
};

/** Kuya Ipis peeking over a ledge and waving hello; plays during onboarding. */
export const PEEKABOO: SpriteSheet = {
  src: "/peekaboo.png",
  cols: 9,
  rows: 6,
  frames: 54,
  fps: 24,
  cellW: 280,
  cellH: 246,
  // Fully up, both arms out, hearts showing — the frame that reads as "hello".
  stillFrame: 30,
};

/** Kuya Ipis holding an empty bag; shown when a card has nothing left to spend. */
export const SAD: SpriteSheet = {
  src: "/sad.png",
  cols: 10,
  rows: 6,
  frames: 60,
  fps: 24,
  cellW: 240,
  cellH: 299,
  // Eyes open, tear showing — reads as "empty" even held still.
  stillFrame: 55,
};

/** Kuya Ipis hovering happily; shown before the wallet has any recent activity. */
export const FLYING_IDLE: SpriteSheet = {
  src: "/flying-idle.png",
  cols: 10,
  rows: 6,
  frames: 60,
  fps: 24,
  cellW: 240,
  cellH: 233,
  // Wings lifted and eyes open, so the held pose still reads as flying.
  stillFrame: 7,
};
