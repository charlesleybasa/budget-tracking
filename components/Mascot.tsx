"use client";

import { useId } from "react";

import styles from "./Mascot.module.css";

/**
 * Kuya Ipis — the wallet's mascot, drawn to the character sheet.
 *
 * Inline SVG animated with CSS rather than a Lottie: the moving parts are a bob, three
 * rotations and a blink, which CSS does in ~3KB against a ~48KB gzipped Lottie runtime.
 *
 * Anatomy follows the reference sheet rather than a generic bug: the abdomen is a brown
 * shell with a *inset* tan segmented underbelly, and the wing case is a separate darker
 * leaf laid over its left side. Painting the whole abdomen tan — the obvious shortcut —
 * loses the rim of shell that reads as the character's back.
 *
 * Everything is authored in a 200x240 viewBox, so `transform-origin` values in the
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
  // Gradients and clips are document-scoped, so two mascots on one screen would otherwise
  // share (and fight over) the same ids.
  const uid = useId().replace(/:/g, "");
  const headGrad = `${uid}-head`;
  const bodyGrad = `${uid}-body`;
  const bellyGrad = `${uid}-belly`;
  const wingGrad = `${uid}-wing`;
  const bagGrad = `${uid}-bag`;
  const bellyClip = `${uid}-bellyclip`;
  const mouthClip = `${uid}-mouthclip`;

  const moodClass = mood === "wave" ? styles.wave : mood === "cheer" ? styles.cheer : styles.idle;

  return (
    <svg
      className={`${styles.svg} ${moodClass} ${className}`}
      style={{ width: size }}
      viewBox="0 0 200 240"
      role={label ? "img" : undefined}
      aria-label={label}
      aria-hidden={label ? undefined : true}
    >
      <defs>
        <radialGradient id={headGrad} cx="36%" cy="28%" r="82%">
          <stop offset="0%" stopColor="#B2764B" />
          <stop offset="100%" stopColor="#985B33" />
        </radialGradient>
        <radialGradient id={bodyGrad} cx="40%" cy="26%" r="86%">
          <stop offset="0%" stopColor="#A9683E" />
          <stop offset="100%" stopColor="#8E5430" />
        </radialGradient>
        <radialGradient id={bellyGrad} cx="42%" cy="24%" r="88%">
          <stop offset="0%" stopColor="#D6B18B" />
          <stop offset="100%" stopColor="#BE9670" />
        </radialGradient>
        <linearGradient id={wingGrad} x1="0%" y1="0%" x2="100%" y2="100%">
          <stop offset="0%" stopColor="#70441F" />
          <stop offset="100%" stopColor="#54301A" />
        </linearGradient>
        <radialGradient id={bagGrad} cx="38%" cy="26%" r="84%">
          <stop offset="0%" stopColor="#9BD8AC" />
          <stop offset="100%" stopColor="#78BC8B" />
        </radialGradient>

        <clipPath id={bellyClip}>
          <ellipse cx="94" cy="168" rx="41" ry="46" />
        </clipPath>
        <clipPath id={mouthClip}>
          <path d="M88 122 Q100 118 112 122 Q112 140 100 140 Q88 140 88 122 Z" />
        </clipPath>
      </defs>

      <ellipse className={styles.shadow} cx="100" cy="238" rx="46" ry="6" />

      {/* Coins and sparkles sit outside the bobbing group so they rise independently. */}
      <g className={styles.burst}>
        <g className={styles.coinA}>
          <circle className={styles.coin} cx="168" cy="86" r="15" />
          <text className={styles.coinMark} x="168" y="93" textAnchor="middle">
            ₱
          </text>
        </g>
        <g className={styles.coinB}>
          <circle className={styles.coin} cx="34" cy="102" r="12" />
          <text className={styles.coinMarkSm} x="34" y="108" textAnchor="middle">
            ₱
          </text>
        </g>
        <g className={styles.coinC}>
          <circle className={styles.coin} cx="176" cy="148" r="10" />
        </g>

        <path
          className={styles.sparkA}
          d="M26 50 C27 55 29 57 34 58 C29 59 27 61 26 66 C25 61 23 59 18 58 C23 57 25 55 26 50 Z"
        />
        <path
          className={styles.sparkB}
          d="M182 44 C183 49 184.6 50.6 189 52 C184.6 53.4 183 55 182 60 C181 55 179.4 53.4 175 52 C179.4 50.6 181 49 182 44 Z"
        />
        <path
          className={styles.sparkC}
          d="M148 28 C148.8 32 150 33.2 154 34 C150 34.8 148.8 36 148 40 C147.2 36 146 34.8 142 34 C146 33.2 147.2 32 148 28 Z"
        />
      </g>

      <g className={styles.floater}>
        {/* antennae — drawn first so the head caps their base */}
        <path className={styles.antL} d="M82 62 C 74 42, 64 26, 50 14" />
        <path className={styles.antR} d="M118 62 C 126 42, 136 26, 150 15" />

        {/* legs */}
        <path className={styles.limb} d="M84 210 L79 235" />
        <path className={styles.limb} d="M116 210 L121 235" />

        {/* abdomen: shell first, then the inset underbelly it frames */}
        <ellipse className={styles.body} cx="100" cy="166" rx="53" ry="56" fill={`url(#${bodyGrad})`} />
        <ellipse className={styles.belly} cx="94" cy="168" rx="41" ry="46" fill={`url(#${bellyGrad})`} />
        <g clipPath={`url(#${bellyClip})`}>
          <path className={styles.seg} d="M52 142 Q94 153 136 142" />
          <path className={styles.seg} d="M50 164 Q94 176 138 164" />
          <path className={styles.seg} d="M52 186 Q94 198 136 186" />
          <path className={styles.seg} d="M60 206 Q94 216 128 206" />
        </g>

        {/* wing case over the abdomen's right side */}
        <path
          className={styles.wing}
          d="M136 118 C 161 133, 165 184, 134 216 C 114 191, 110 140, 136 118 Z"
          fill={`url(#${wingGrad})`}
        />
        <path className={styles.wingVein} d="M134 130 C 145 152, 143 188, 130 208" />

        {/* arms */}
        <g className={styles.armL}>
          <path className={styles.limb} d="M54 160 L34 180" />
        </g>
        <g className={styles.armR}>
          <path className={styles.limb} d="M146 160 L166 180" />
        </g>

        {/* Strap before the head, so the head is what hides where it ends. It lies over the
            wing case because a bag is worn on top of the shell, not under it. */}
        <path className={styles.strap} d="M84 178 C 100 164, 120 142, 132 120" />

        {/* drawstring bag, hanging on the pale belly opposite the wing */}
        <path className={styles.bagTuft} d="M74 182 C 70 177, 73 171, 78 172 C 80 168, 88 168, 90 172 C 95 171, 98 177, 94 182 Z" />
        <path
          className={styles.bag}
          d="M70 192 C 70 182, 76 176, 84 176 C 92 176, 98 182, 98 192 C 100 206, 92 215, 84 215 C 76 215, 68 206, 70 192 Z"
          fill={`url(#${bagGrad})`}
        />
        <path className={styles.bagTie} d="M72 185 Q84 180 96 185" />
        <text className={styles.bagMark} x="84" y="203" textAnchor="middle">
          ₱
        </text>

        {/* head */}
        <ellipse className={styles.head} cx="100" cy="100" rx="57" ry="49" fill={`url(#${headGrad})`} />

        <path className={styles.brow} d="M66 78 Q79 70 92 78" />
        <path className={styles.brow} d="M108 78 Q121 70 134 78" />

        <ellipse className={styles.cheek} cx="52" cy="122" rx="12" ry="8" />
        <ellipse className={styles.cheek} cx="148" cy="122" rx="12" ry="8" />

        <g className={styles.eyes}>
          <ellipse className={styles.eyeWhite} cx="79" cy="104" rx="17" ry="19.5" />
          <ellipse className={styles.eyeWhite} cx="121" cy="104" rx="17" ry="19.5" />
          <circle className={styles.pupil} cx="80.5" cy="106.5" r="11.5" />
          <circle className={styles.pupil} cx="122.5" cy="106.5" r="11.5" />
          <circle className={styles.glint} cx="74.5" cy="99" r="5" />
          <circle className={styles.glint} cx="116.5" cy="99" r="5" />
          <circle className={styles.glintSm} cx="86" cy="113" r="2.4" />
          <circle className={styles.glintSm} cx="128" cy="113" r="2.4" />
        </g>

        {/* the squinting smile the cheer pose swaps to */}
        <g className={styles.eyesHappy}>
          <path d="M64 108 Q79 89 94 108" />
          <path d="M106 108 Q121 89 136 108" />
        </g>

        <path className={styles.mouth} d="M88 122 Q100 118 112 122 Q112 140 100 140 Q88 140 88 122 Z" />
        <g clipPath={`url(#${mouthClip})`}>
          <ellipse className={styles.tongue} cx="100" cy="141" rx="8" ry="5.5" />
        </g>
      </g>
    </svg>
  );
}
