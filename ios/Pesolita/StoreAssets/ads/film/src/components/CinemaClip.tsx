import React from "react";
import { AbsoluteFill, interpolate, OffthreadVideo, staticFile, useCurrentFrame, useVideoConfig } from "remotion";
import { Grain, Vignette } from "./fx";

type Grade = "night" | "warm" | "neon" | "day";

// A light, consistent grade across the Flow shots: teal shadows / warm highlights for night,
// golden lift for day. Applied as a CSS filter plus a soft-light colour wash.
const GRADES: Record<Grade, { filter: string; wash: string }> = {
  night: {
    filter: "contrast(1.12) saturate(1.08) brightness(0.96)",
    wash: "linear-gradient(180deg, rgba(0,120,140,0.22), rgba(255,140,40,0.14))",
  },
  warm: {
    filter: "contrast(1.1) saturate(1.12)",
    wash: "linear-gradient(180deg, rgba(255,170,60,0.16), rgba(120,40,0,0.18))",
  },
  neon: {
    filter: "contrast(1.08) saturate(1.2)",
    wash: "linear-gradient(180deg, rgba(160,0,200,0.12), rgba(0,160,200,0.12))",
  },
  day: {
    filter: "contrast(1.06) saturate(1.1) brightness(1.03)",
    wash: "linear-gradient(180deg, rgba(255,210,120,0.18), rgba(255,170,80,0.06))",
  },
};

/**
 * One Flow shot: cut in at `from` seconds, slow push-in across its sequence, graded, grained.
 * Volume is the clip's own (Omni's native) sound: the actor's line, the room, the rain.
 */
export const CinemaClip: React.FC<{
  src: string;
  from: number;
  grade?: Grade;
  volume?: number;
  zoom?: [number, number];
  rate?: number;
  origin?: string;
}> = ({ src, from, grade = "night", volume = 0, zoom = [1.04, 1.12], rate = 1, origin = "50% 45%" }) => {
  const frame = useCurrentFrame();
  const { fps, durationInFrames } = useVideoConfig();
  const scale = interpolate(frame, [0, durationInFrames], zoom, { extrapolateRight: "clamp" });
  const g = GRADES[grade];
  return (
    <AbsoluteFill style={{ background: "#000", overflow: "hidden" }}>
      <AbsoluteFill style={{ transform: `scale(${scale})`, transformOrigin: origin, filter: g.filter }}>
        <OffthreadVideo
          src={staticFile(src)}
          trimBefore={Math.round(from * fps)}
          playbackRate={rate}
          volume={volume}
          style={{ width: "100%", height: "100%", objectFit: "cover" }}
        />
      </AbsoluteFill>
      <AbsoluteFill style={{ background: g.wash, mixBlendMode: "soft-light" }} />
      <Vignette />
      <Grain />
    </AbsoluteFill>
  );
};
