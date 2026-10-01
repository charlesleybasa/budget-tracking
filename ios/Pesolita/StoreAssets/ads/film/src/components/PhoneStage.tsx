import React from "react";
import { AbsoluteFill, Img, interpolate, OffthreadVideo, spring, staticFile, useCurrentFrame, useVideoConfig } from "remotion";
import { GOLD, INK } from "../theme";
import { Grain } from "./fx";

// The capture is 1320×2868 (iPhone 17 Pro Max). On stage the phone is 760 px wide.
const PW = 760;
const PH = Math.round((PW * 2868) / 1320);
const BEZEL = 20;
const R = 112;

/**
 * The real app on a dark stage: the phone swings in from a 3D tilt, then the camera pushes in
 * toward `focusY` (0..1 of the screen height) so one card fills the frame.
 */
export const PhoneStage: React.FC<{
  src: string;
  video?: boolean;
  from?: number; // seconds into a video
  rate?: number;
  enter?: boolean; // swing in (first app scene) or arrive already settled
  focusY?: number;
  zoom?: [number, number];
  zoomAt?: [number, number]; // frames over which the push-in happens
  glow?: string;
  offsetY?: number; // push the phone lower to leave room for type above it
  shade?: number; // how far down the dark top band reaches (0..1)
}> = ({ src, video, from = 0, rate = 1, enter = true, focusY = 0.5, zoom = [1, 1.08], zoomAt = [0, 90], glow = GOLD, offsetY = 240, shade = 0.26 }) => {
  const frame = useCurrentFrame();
  const { fps } = useVideoConfig();
  const swing = enter ? spring({ frame, fps, config: { damping: 16, stiffness: 120, mass: 0.9 } }) : 1;
  const rotY = interpolate(swing, [0, 1], [-38, 0]);
  const rotX = interpolate(swing, [0, 1], [14, 0]);
  const lift = interpolate(swing, [0, 1], [260, 0]);
  const z = interpolate(frame, zoomAt, zoom, { extrapolateLeft: "clamp", extrapolateRight: "clamp" });
  // Push toward the focus point: shift the phone so focusY sits near the frame's centre line.
  const focusShift = interpolate(z, [zoom[0], zoom[1]], [0, (0.5 - focusY) * PH * (zoom[1] - 1) * 0.9]);
  const glowPulse = 0.35 + 0.1 * Math.sin(frame / 8);
  return (
    <AbsoluteFill style={{ background: `radial-gradient(ellipse at 50% 55%, #1b1b22 0%, ${INK} 70%)`, overflow: "hidden" }}>
      <AbsoluteFill
        style={{
          background: `radial-gradient(circle at 50% 58%, ${glow}${Math.round(glowPulse * 255)
            .toString(16)
            .padStart(2, "0")} 0%, rgba(0,0,0,0) 45%)`,
          filter: "blur(40px)",
        }}
      />
      <AbsoluteFill style={{ perspective: 1800, alignItems: "center", justifyContent: "center" }}>
        <div
          style={{
            width: PW + BEZEL * 2,
            height: PH + BEZEL * 2,
            marginTop: offsetY,
            borderRadius: R + BEZEL,
            background: "#060607",
            boxShadow: "0 60px 120px rgba(0,0,0,0.65), inset 0 0 0 3px rgba(255,255,255,0.18)",
            padding: BEZEL,
            transform: `translateY(${lift + focusShift}px) rotateY(${rotY}deg) rotateX(${rotX}deg) scale(${z})`,
            transformOrigin: `50% ${focusY * 100}%`,
          }}
        >
          <div style={{ width: PW, height: PH, borderRadius: R, overflow: "hidden", background: "#000" }}>
            {video ? (
              <OffthreadVideo
                src={staticFile(src)}
                trimBefore={Math.round(from * fps)}
                playbackRate={rate}
                muted
                style={{ width: "100%", height: "100%", objectFit: "cover" }}
              />
            ) : (
              <Img src={staticFile(src)} style={{ width: "100%", height: "100%", objectFit: "cover" }} />
            )}
          </div>
        </div>
      </AbsoluteFill>
      <AbsoluteFill
        style={{ background: `linear-gradient(180deg, rgba(11,11,13,0.95) 0%, rgba(11,11,13,0.9) ${shade * 60}%, rgba(11,11,13,0) ${shade * 100}%)`, pointerEvents: "none" }}
      />
      <Grain opacity={0.06} />
    </AbsoluteFill>
  );
};
