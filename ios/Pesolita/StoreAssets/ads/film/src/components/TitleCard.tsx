import React from "react";
import { AbsoluteFill, Img, interpolate, spring, staticFile, useCurrentFrame, useVideoConfig } from "remotion";
import { DANGER, DISPLAY, GOLD, INK, OUTFIT, WHITE } from "../theme";
import { Flash, Grain, shake } from "./fx";

/**
 * The trailer title: "PETSA DE PELIGRO" slams in red and cracks, a strike-through tears across,
 * "HINDI NA." punches in gold; then it all clears for the Pesolita logo and the CTA.
 */
export const TitleCard: React.FC<{ logoAt?: number; tagline?: string; extra?: string }> = ({
  logoAt = 50,
  tagline = "Bawat piso, may lugar.",
  extra,
}) => {
  const frame = useCurrentFrame();
  const { fps } = useVideoConfig();

  const titleIn = spring({ frame, fps, config: { damping: 12, stiffness: 200, mass: 0.7 } });
  const crack = frame >= 14;
  const strike = interpolate(frame, [16, 24], [0, 1], { extrapolateLeft: "clamp", extrapolateRight: "clamp" });
  const hindi = spring({ frame: frame - 22, fps, config: { damping: 10, stiffness: 240, mass: 0.6 } });
  const titleOut = interpolate(frame, [logoAt - 6, logoAt], [1, 0], { extrapolateLeft: "clamp", extrapolateRight: "clamp" });

  const logo = spring({ frame: frame - logoAt, fps, config: { damping: 13, stiffness: 160 } });
  const pill = spring({ frame: frame - logoAt - 10, fps, config: { damping: 14, stiffness: 180 } });

  const titleStyle: React.CSSProperties = {
    fontFamily: DISPLAY,
    fontSize: 196,
    lineHeight: 0.92,
    color: DANGER,
    textAlign: "center",
    textShadow: "0 0 60px rgba(255,59,48,0.55)",
  };
  const title = "PETSA DE\nPELIGRO";

  return (
    <AbsoluteFill style={{ background: `radial-gradient(ellipse at 50% 45%, #22080a 0%, ${INK} 70%)` }}>
      {/* Title block */}
      <AbsoluteFill style={{ opacity: titleOut, transform: shake(frame, 0, 22, 7) + " " + shake(frame, 22, 14, 6) }}>
        <div
          style={{
            position: "absolute",
            left: 60,
            right: 120,
            top: 760,
            transform: `translateY(-50%) scale(${interpolate(titleIn, [0, 1], [1.6, 1])})`,
            whiteSpace: "pre-line",
          }}
        >
          {/* Cracked: the top and bottom halves slip apart along a jagged line. */}
          <div style={{ ...titleStyle, clipPath: "polygon(0 0,100% 0,100% 47%,62% 52%,38% 45%,0 51%)", transform: crack ? "translate(-7px,-3px) rotate(-0.6deg)" : "none" }}>
            {title}
          </div>
          <div
            style={{
              ...titleStyle,
              position: "absolute",
              inset: 0,
              clipPath: "polygon(0 51%,38% 45%,62% 52%,100% 47%,100% 100%,0 100%)",
              transform: crack ? "translate(7px,4px) rotate(0.5deg)" : "none",
            }}
          >
            {title}
          </div>
          {/* Strike-through */}
          <div
            style={{
              position: "absolute",
              left: "4%",
              top: "48%",
              height: 22,
              width: `${92 * strike}%`,
              background: WHITE,
              transform: "rotate(-6deg)",
              boxShadow: "0 0 30px rgba(255,255,255,0.6)",
            }}
          />
        </div>
        <div
          style={{
            position: "absolute",
            left: 60,
            right: 120,
            top: 1090,
            transform: `translateY(-50%) scale(${interpolate(hindi, [0, 1], [1.7, 1])})`,
            opacity: frame >= 22 ? 1 : 0,
            textAlign: "center",
            fontFamily: DISPLAY,
            fontSize: 210,
            color: GOLD,
            textShadow: "0 0 50px rgba(255,202,40,0.55)",
          }}
        >
          HINDI NA.
        </div>
      </AbsoluteFill>

      {/* Logo + CTA */}
      {frame >= logoAt && (
        <AbsoluteFill style={{ alignItems: "center" }}>
          <Img
            src={staticFile("brand/icon.png")}
            style={{
              position: "absolute",
              top: 470,
              width: 300,
              height: 300,
              borderRadius: 68,
              transform: `scale(${interpolate(logo, [0, 1], [0.6, 1])}) rotate(${interpolate(logo, [0, 1], [-8, 0])}deg)`,
              boxShadow: "0 30px 80px rgba(0,0,0,0.6)",
            }}
          />
          <div style={{ position: "absolute", top: 830, fontFamily: OUTFIT, fontWeight: 900, fontSize: 150, color: WHITE, opacity: logo }}>
            Pesolita
          </div>
          <div style={{ position: "absolute", top: 1030, fontFamily: OUTFIT, fontWeight: 500, fontSize: 56, color: "#C8C8D0", opacity: logo }}>
            {tagline}
          </div>
          <div
            style={{
              position: "absolute",
              top: 1180,
              padding: "34px 64px",
              borderRadius: 80,
              background: GOLD,
              color: INK,
              fontFamily: OUTFIT,
              fontWeight: 800,
              fontSize: 54,
              transform: `scale(${pill})`,
            }}
          >
            Libre sa App Store
          </div>
          {extra && (
            <div style={{ position: "absolute", top: 1360, fontFamily: OUTFIT, fontWeight: 700, fontSize: 46, color: WHITE, opacity: pill }}>
              {extra}
            </div>
          )}
        </AbsoluteFill>
      )}
      <Flash at={0} frames={5} color={DANGER} peak={0.5} />
      <Flash at={logoAt} frames={8} peak={0.7} />
      <Grain opacity={0.07} />
    </AbsoluteFill>
  );
};
