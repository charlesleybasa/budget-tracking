import React from "react";
import { AbsoluteFill, interpolate, random, useCurrentFrame } from "remotion";

/** Pseudo-random handheld/impact shake. Returns a CSS transform for `frame - start`. */
export const shake = (frame: number, start: number, intensity: number, decay = 10) => {
  const t = frame - start;
  if (t < 0 || t > decay * 3) return "translate(0px, 0px)";
  const k = intensity * Math.exp(-t / decay);
  const x = (random(`x${Math.floor(frame)}`) - 0.5) * 2 * k;
  const y = (random(`y${Math.floor(frame)}`) - 0.5) * 2 * k;
  const r = (random(`r${Math.floor(frame)}`) - 0.5) * 0.6 * (k / Math.max(intensity, 1));
  return `translate(${x}px, ${y}px) rotate(${r}deg)`;
};

/** Animated film grain (SVG noise re-seeded every frame). */
export const Grain: React.FC<{ opacity?: number }> = ({ opacity = 0.09 }) => {
  const frame = useCurrentFrame();
  return (
    <AbsoluteFill style={{ opacity, mixBlendMode: "overlay", pointerEvents: "none" }}>
      <svg width="100%" height="100%">
        <filter id={`g${frame}`}>
          <feTurbulence type="fractalNoise" baseFrequency="0.9" numOctaves={2} seed={frame % 97} />
          <feColorMatrix type="saturate" values="0" />
        </filter>
        <rect width="100%" height="100%" filter={`url(#g${frame})`} />
      </svg>
    </AbsoluteFill>
  );
};

/** Dark edges that pull the eye to the centre. */
export const Vignette: React.FC<{ strength?: number }> = ({ strength = 0.62 }) => (
  <AbsoluteFill
    style={{
      background: `radial-gradient(ellipse 85% 70% at 50% 46%, rgba(0,0,0,0) 45%, rgba(0,0,0,${strength}) 100%)`,
      pointerEvents: "none",
    }}
  />
);

/** A short white (or coloured) flash, e.g. on a cut or an impact. */
export const Flash: React.FC<{ at?: number; frames?: number; color?: string; peak?: number }> = ({
  at = 0,
  frames = 6,
  color = "#fff",
  peak = 0.85,
}) => {
  const frame = useCurrentFrame();
  const o = interpolate(frame, [at, at + 1, at + frames], [0, peak, 0], {
    extrapolateLeft: "clamp",
    extrapolateRight: "clamp",
  });
  return <AbsoluteFill style={{ background: color, opacity: o, pointerEvents: "none" }} />;
};

/** Letterbox-style top/bottom shade so type reads over any shot. */
export const Scrim: React.FC<{ top?: number; bottom?: number }> = ({ top = 0.55, bottom = 0.45 }) => (
  <AbsoluteFill
    style={{
      background: `linear-gradient(180deg, rgba(0,0,0,${top}) 0%, rgba(0,0,0,0) 32%, rgba(0,0,0,0) 62%, rgba(0,0,0,${bottom}) 100%)`,
      pointerEvents: "none",
    }}
  />
);
