import type { SpriteSheet } from "@/components/SpriteAnimation";

/**
 * The rendered animation atlases, built from PNG sequences by scripts/build-sprites.mjs.
 *
 * Every grid is exact — cols * rows === frames — because the stepping math assumes no blank
 * trailing cells. If you rebuild a sheet with a different frame count, the grid has to change
 * with it.
 */

/** Kuya Ipis celebrating; plays after a card is funded or money is moved. */
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

/** Kuya Ipis standing calmly with a gentle wing flutter; used for true empty-history states. */
export const IDLE_STEADY: SpriteSheet = {
  src: "/bee-idle-steady-30fps-v2-spritesheet.png",
  cols: 10,
  rows: 3,
  frames: 30,
  fps: 30,
  cellW: 288,
  cellH: 448,
  // Eyes open with the wing lifted, so the reduced-motion pose still feels alert.
  stillFrame: 15,
};

/**
 * Kuya Ipis waving both palms out — "no, not that much". Shown while the typed amount is
 * over the card's balance.
 */
export const NO_NO_NO: SpriteSheet = {
  src: "/nonono.png",
  cols: 10,
  rows: 6,
  frames: 60,
  fps: 24,
  cellW: 240,
  cellH: 397,
  // Both palms up and out, eyes shut — reads as a refusal even held still.
  stillFrame: 36,
};
