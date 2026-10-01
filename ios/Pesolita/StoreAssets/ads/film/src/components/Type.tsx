import React from "react";
import { interpolate, spring, useCurrentFrame, useVideoConfig } from "remotion";
import { DISPLAY, GOLD, OUTFIT, WHITE } from "../theme";
import { shake } from "./fx";

const peso = (n: number, decimals = 0) =>
  "₱" + n.toLocaleString("en-US", { minimumFractionDigits: decimals, maximumFractionDigits: decimals });

/**
 * Trailer title slam: drops in big and blurred, snaps to rest with a little overshoot, an RGB
 * split that settles, and a camera shake on impact. `instant` = already at rest on frame 0
 * (thumbnail frames), with only a gentle breathing scale.
 */
export const Slam: React.FC<{
  text: string;
  at?: number;
  size?: number;
  color?: string;
  font?: string;
  y?: number;
  tracking?: number;
  instant?: boolean;
  out?: number; // frame to start fading out
  glow?: string;
  weight?: number;
}> = ({ text, at = 0, size = 150, color = WHITE, font = DISPLAY, y = 820, tracking = 2, instant, out, glow, weight = 400 }) => {
  const frame = useCurrentFrame();
  const { fps } = useVideoConfig();
  const t = frame - at;
  if (t < 0) return null;
  const pop = instant ? 1 : spring({ frame: t, fps, config: { damping: 11, stiffness: 220, mass: 0.6 } });
  const scale = instant ? interpolate(t, [0, 120], [1.03, 1], { extrapolateRight: "clamp" }) : interpolate(pop, [0, 1], [1.45, 1]);
  const blur = instant ? 0 : interpolate(t, [0, 5], [14, 0], { extrapolateRight: "clamp" });
  const split = instant ? 0 : interpolate(t, [0, 10], [12, 0], { extrapolateRight: "clamp" });
  const fadeIn = instant ? 1 : interpolate(t, [0, 3], [0, 1], { extrapolateRight: "clamp" });
  const fadeOut = out !== undefined ? interpolate(frame, [out, out + 6], [1, 0], { extrapolateLeft: "clamp", extrapolateRight: "clamp" }) : 1;
  return (
    <div
      style={{
        position: "absolute",
        left: 60,
        right: 120, // keep clear of TikTok / Reels buttons on the right edge
        top: y,
        transform: `translateY(-50%) ${shake(frame, at, instant ? 0 : 16, 6)} scale(${scale})`,
        textAlign: "center",
        fontFamily: font,
        fontWeight: weight,
        fontSize: size,
        lineHeight: 0.95,
        letterSpacing: tracking,
        color,
        opacity: fadeIn * fadeOut,
        filter: `blur(${blur}px)`,
        textShadow: [
          `${split}px 0 0 rgba(255,40,60,0.75)`,
          `${-split}px 0 0 rgba(40,220,255,0.75)`,
          glow ? `0 0 40px ${glow}` : "0 6px 30px rgba(0,0,0,0.55)",
        ].join(", "),
        whiteSpace: "pre-line",
      }}
    >
      {text}
    </div>
  );
};

/** Typewriter line, letter by letter, with a blinking block cursor. */
export const TypeOn: React.FC<{
  text: string;
  at?: number;
  cps?: number;
  size?: number;
  y?: number;
  color?: string;
  font?: string;
  instant?: boolean;
}> = ({ text, at = 0, cps = 26, size = 64, y = 1040, color = WHITE, font = DISPLAY, instant }) => {
  const frame = useCurrentFrame();
  const { fps } = useVideoConfig();
  const t = frame - at;
  if (t < 0) return null;
  const n = instant ? text.length : Math.min(text.length, Math.floor((t / fps) * cps));
  const cursor = Math.floor(frame / 8) % 2 === 0 && n < text.length + 6;
  return (
    <div
      style={{
        position: "absolute",
        left: 60,
        right: 120,
        top: y,
        transform: "translateY(-50%)",
        textAlign: "center",
        fontFamily: font,
        fontSize: size,
        letterSpacing: 8,
        color,
        textShadow: "0 4px 24px rgba(0,0,0,0.6)",
      }}
    >
      {text.slice(0, n)}
      <span style={{ opacity: cursor ? 1 : 0, color: GOLD }}>▍</span>
    </div>
  );
};

/** Small spaced kicker label above a big number. */
export const Kicker: React.FC<{ text: string; y: number; color?: string; at?: number; size?: number }> = ({
  text,
  y,
  color = WHITE,
  at = 0,
  size = 40,
}) => {
  const frame = useCurrentFrame();
  const o = interpolate(frame - at, [0, 6], [0, 1], { extrapolateLeft: "clamp", extrapolateRight: "clamp" });
  const dy = interpolate(frame - at, [0, 8], [18, 0], { extrapolateLeft: "clamp", extrapolateRight: "clamp" });
  return (
    <div
      style={{
        position: "absolute",
        left: 60,
        right: 120,
        top: y + dy,
        transform: "translateY(-50%)",
        textAlign: "center",
        fontFamily: OUTFIT,
        fontWeight: 800,
        fontSize: size,
        letterSpacing: 10,
        color,
        opacity: o,
        textShadow: "0 3px 18px rgba(0,0,0,0.7)",
      }}
    >
      {text}
    </div>
  );
};

/** A spend hitting the screen: label, then a huge gold ₱ amount punching in. */
export const AmountHit: React.FC<{ label: string; amount: number }> = ({ label, amount }) => (
  <>
    <Kicker text={label} y={700} />
    <Slam text={peso(amount)} at={1} size={210} color={GOLD} y={860} tracking={0} glow="rgba(255,202,40,0.45)" />
  </>
);

/** Running "GASTOS" total in the corner, ticking up between `from` and `to`. */
export const RunningTotal: React.FC<{ from: number; to: number }> = ({ from, to }) => {
  const frame = useCurrentFrame();
  const v = Math.round(interpolate(frame, [2, 14], [from, to], { extrapolateLeft: "clamp", extrapolateRight: "clamp" }));
  return (
    <div
      style={{
        position: "absolute",
        top: 250,
        left: 60,
        fontFamily: OUTFIT,
        color: WHITE,
        textShadow: "0 3px 14px rgba(0,0,0,0.8)",
      }}
    >
      <div style={{ fontSize: 30, fontWeight: 800, letterSpacing: 8, opacity: 0.8 }}>GASTOS THIS WEEK</div>
      <div style={{ fontFamily: DISPLAY, fontSize: 84, color: "#FF5A4E", letterSpacing: 1 }}>{peso(v)}</div>
    </div>
  );
};

/** A big ₱ number counting up (safe to spend). */
export const PesoCounter: React.FC<{ value: number; at?: number; frames?: number; y?: number; size?: number }> = ({
  value,
  at = 0,
  frames = 24,
  y = 1180,
  size = 170,
}) => {
  const frame = useCurrentFrame();
  const t = interpolate(frame - at, [0, frames], [0, 1], { extrapolateLeft: "clamp", extrapolateRight: "clamp" });
  const eased = 1 - Math.pow(1 - t, 3);
  if (frame < at) return null;
  return (
    <div
      style={{
        position: "absolute",
        left: 60,
        right: 120,
        top: y,
        transform: `translateY(-50%) ${shake(frame, at + frames, 10, 5)}`,
        textAlign: "center",
        fontFamily: DISPLAY,
        fontSize: size,
        color: GOLD,
        textShadow: "0 0 50px rgba(255,202,40,0.45), 0 6px 30px rgba(0,0,0,0.6)",
      }}
    >
      {peso(value * eased, 2)}
    </div>
  );
};

/** Burned-in subtitle for the narrator, so the story works with the sound off. */
export const Subtitle: React.FC<{ text: string; at: number; until: number }> = ({ text, at, until }) => {
  const frame = useCurrentFrame();
  if (frame < at || frame > until) return null;
  const o = interpolate(frame, [at, at + 4, until - 4, until], [0, 1, 1, 0]);
  return (
    <div
      style={{
        position: "absolute",
        left: 80,
        right: 140,
        top: 1478,
        display: "flex",
        justifyContent: "center",
        opacity: o,
      }}
    >
      <div
        style={{
          fontFamily: OUTFIT,
          fontWeight: 600,
          fontSize: 40,
          lineHeight: 1.25,
          color: WHITE,
          background: "rgba(0,0,0,0.55)",
          padding: "12px 26px",
          borderRadius: 18,
          textAlign: "center",
        }}
      >
        {text}
      </div>
    </div>
  );
};
