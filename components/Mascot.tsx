"use client";

import styles from "./Mascot.module.css";

/**
 * Kuya Ipis — the wallet's mascot.
 *
 * Drawn as inline SVG and animated with CSS rather than shipped as a Lottie: the moving
 * parts here are a bob, a couple of rotations and a blink, which CSS does in ~3KB. A Lottie
 * runtime is ~48KB gzipped, which is a poor trade on a phone-first app whose whole card-art
 * engine is already inline SVG.
 *
 * Everything is authored in a 120x140 viewBox, so `transform-origin` values in the
 * stylesheet are plain user units against that grid.
 */
export type MascotMood = "idle" | "wave" | "cheer";

export function Mascot({
  mood = "idle",
  size = 120,
  label,
  className = "",
}: {
  mood?: MascotMood;
  /** Rendered width in px; height follows the artwork's ratio. */
  size?: number;
  /** Supply only when the mascot carries meaning no nearby text already carries. */
  label?: string;
  className?: string;
}) {
  const moodClass = mood === "wave" ? styles.wave : mood === "cheer" ? styles.cheer : styles.idle;

  return (
    <svg
      className={`${styles.svg} ${moodClass} ${className}`}
      style={{ width: size }}
      viewBox="0 0 120 140"
      role={label ? "img" : undefined}
      aria-label={label}
      aria-hidden={label ? undefined : true}
    >
      <ellipse className={styles.shadow} cx="60" cy="132" rx="25" ry="4.5" />

      {/* Coins and sparkles sit outside the bobbing group so they rise independently. */}
      <g className={styles.burst}>
        <g className={styles.coinA}>
          <circle className={styles.coin} cx="99" cy="52" r="8.5" />
          <text className={styles.coinMark} x="99" y="56" textAnchor="middle">
            ₱
          </text>
        </g>
        <g className={styles.coinB}>
          <circle className={styles.coin} cx="22" cy="60" r="7" />
          <text className={styles.coinMarkSm} x="22" y="63.5" textAnchor="middle">
            ₱
          </text>
        </g>
        <g className={styles.coinC}>
          <circle className={styles.coin} cx="104" cy="86" r="6" />
        </g>

        <path className={styles.sparkA} d="M14 34 Q15 38 19 39 Q15 40 14 44 Q13 40 9 39 Q13 38 14 34 Z" />
        <path className={styles.sparkB} d="M108 30 Q109 34 113 35 Q109 36 108 40 Q107 36 103 35 Q107 34 108 30 Z" />
        <path className={styles.sparkC} d="M88 20 Q89 23 92 24 Q89 25 88 28 Q87 25 84 24 Q87 23 88 20 Z" />
      </g>

      <g className={styles.floater}>
        {/* antennae — drawn first so the head caps their base */}
        <path className={styles.antL} d="M49 30 C 44 18, 38 11, 31 7" />
        <path className={styles.antR} d="M71 30 C 76 18, 82 11, 89 8" />

        {/* legs */}
        <path className={styles.limb} d="M50 114 L47 128" />
        <path className={styles.limb} d="M70 114 L73 128" />

        {/* abdomen */}
        <ellipse className={styles.body} cx="60" cy="92" rx="30" ry="30" />
        <path className={styles.seg} d="M40 80 Q60 86 80 80" />
        <path className={styles.seg} d="M38 92 Q60 99 82 92" />
        <path className={styles.seg} d="M42 105 Q60 111 78 105" />

        {/* wing case, overlapping the abdomen's left edge */}
        <path className={styles.wing} d="M36 70 C 24 80, 24 106, 41 119 C 49 104, 50 82, 36 70 Z" />

        {/* arms */}
        <g className={styles.armL}>
          <path className={styles.limb} d="M33 92 L26 102" />
        </g>
        <g className={styles.armR}>
          <path className={styles.limb} d="M87 92 L94 102" />
        </g>

        {/* Strap first: it runs up to the shoulder and the head is what hides its top end. */}
        <path className={styles.strap} d="M57 93 C 64 86, 72 80, 77 71" />

        {/* sling bag, on the pale belly rather than over the wing case */}
        <path
          className={styles.bag}
          d="M49 101 C 49 95, 53 92, 57 92 C 61 92, 65 95, 65 101 C 67 111, 62 117, 57 117 C 52 117, 47 111, 49 101 Z"
        />
        <path className={styles.bagTie} d="M51 95.5 Q57 92.5 63 95.5" />
        <text className={styles.bagMark} x="57" y="109" textAnchor="middle">
          ₱
        </text>

        {/* head */}
        <ellipse className={styles.head} cx="60" cy="52" rx="33" ry="31" />

        <path className={styles.brow} d="M41 39 Q48 35 55 39" />
        <path className={styles.brow} d="M65 39 Q72 35 79 39" />

        <ellipse className={styles.cheek} cx="33" cy="63" rx="6.5" ry="4.6" />
        <ellipse className={styles.cheek} cx="87" cy="63" rx="6.5" ry="4.6" />

        <g className={styles.eyes}>
          <ellipse className={styles.eyeWhite} cx="48" cy="54" rx="8.5" ry="9.5" />
          <ellipse className={styles.eyeWhite} cx="72" cy="54" rx="8.5" ry="9.5" />
          <circle className={styles.pupil} cx="48.5" cy="55.2" r="5.4" />
          <circle className={styles.pupil} cx="72.5" cy="55.2" r="5.4" />
          <circle className={styles.glint} cx="45.9" cy="51.2" r="2.1" />
          <circle className={styles.glint} cx="69.9" cy="51.2" r="2.1" />
        </g>

        {/* the squinting smile the cheer pose swaps to */}
        <g className={styles.eyesHappy}>
          <path d="M41 57 Q48 47.5 55 57" />
          <path d="M65 57 Q72 47.5 79 57" />
        </g>

        <path className={styles.mouth} d="M52 67 A 8.4 8.4 0 0 0 68 67 Z" />

      </g>
    </svg>
  );
}
