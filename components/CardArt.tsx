import type { CSSProperties, ReactNode } from "react";
import { memo } from "react";

import { isLight } from "@/lib/color";
import { CARD_H, CARD_R, CARD_W, SCRIM } from "@/lib/constants";
import { measure, patternScrim } from "@/lib/legibility";
import type { Card, CardArt as CardArtModel } from "@/lib/types";

/** CSS custom properties are not in the CSSProperties index signature. */
type Style = CSSProperties & Record<string, string | number | undefined>;

const fill: Style = { position: "absolute", inset: 0 };

export interface CardArtProps {
  art: CardArtModel;
  /** Rendered width in px. Every dimension in the artwork scales off this. */
  w?: number;
  h?: number;
  /** Corner radius. Thumbnails pass 0 and let the wrapper clip. */
  r?: number;
}

/**
 * Paints a card's generative background: pattern layers, amplitude damping, texture, a
 * contrast scrim, and the EMV chip anatomy. Purely presentational — all tuning decisions
 * come from `lib/legibility`.
 */
function CardArtImpl({ art, w = CARD_W, h = CARD_H, r = CARD_R }: CardArtProps) {
  const { c1, c2, style } = art;
  // Scale factor against the geometry the artwork was authored at.
  const k = w / CARD_W;
  const px = (f: number) => Math.round(f * w);

  let layers: ReactNode[] = [];

  if (style === "blob") {
    layers = [
      <div
        key="a"
        style={{
          position: "absolute",
          left: -px(0.1),
          top: -px(0.13),
          width: px(0.47),
          height: px(0.47),
          borderRadius: "50% 50% 42% 58%/55% 45% 55% 45%",
          background: c2,
          opacity: 0.92,
        }}
      />,
      <svg key="b" viewBox="0 0 320 196" preserveAspectRatio="none" style={{ ...fill, width: "100%", height: "100%" }}>
        <path
          d="M-8 44 C36 4 88 66 136 28 C178 -6 210 34 258 8 C292 -10 328 6 336 26 L336 -12 L-8 -12 Z"
          fill="#fff"
          opacity={0.93}
        />
      </svg>,
      <div
        key="c"
        style={{
          position: "absolute",
          right: -px(0.08),
          bottom: -px(0.12),
          width: px(0.34),
          height: px(0.34),
          borderRadius: "46% 54% 60% 40%/48% 62% 38% 52%",
          background: c2,
          opacity: 0.16,
        }}
      />,
    ];
  } else if (style === "wave") {
    layers = [
      <svg key="a" viewBox="0 0 320 196" preserveAspectRatio="none" style={{ ...fill, width: "100%", height: "100%" }}>
        <path d="M0 132 C56 96 92 168 160 132 C226 97 260 158 320 124 L320 196 L0 196 Z" fill={c2} opacity={0.9} />
        <path d="M0 156 C60 122 96 190 164 154 C230 119 262 178 320 148 L320 196 L0 196 Z" fill="#fff" opacity={0.28} />
        <circle cx={268} cy={44} r={40} fill="#fff" opacity={0.14} />
      </svg>,
    ];
  } else if (style === "arc") {
    layers = [
      <svg key="a" viewBox="0 0 320 196" preserveAspectRatio="none" style={{ ...fill, width: "100%", height: "100%" }}>
        <circle cx={300} cy={190} r={150} fill={c2} opacity={0.16} />
        <circle cx={300} cy={190} r={104} fill={c2} opacity={0.3} />
        <circle cx={300} cy={190} r={58} fill={c2} opacity={0.95} />
        <path d="M0 0 L104 0 A104 104 0 0 1 0 104 Z" fill={c2} opacity={0.85} />
      </svg>,
    ];
  } else if (style === "grid") {
    layers = [
      <div
        key="a"
        style={{
          ...fill,
          backgroundImage: `linear-gradient(${c2} 1.2px,transparent 1.2px),linear-gradient(90deg,${c2} 1.2px,transparent 1.2px)`,
          backgroundSize: `${px(0.075)}px ${px(0.075)}px`,
          opacity: 0.3,
        }}
      />,
      <div
        key="b"
        style={{
          position: "absolute",
          right: px(0.06),
          top: px(0.1),
          width: px(0.2),
          height: px(0.2),
          background: c2,
          borderRadius: 4,
          transform: "rotate(45deg)",
          opacity: 0.95,
        }}
      />,
      <div
        key="c"
        style={{
          position: "absolute",
          left: px(0.05),
          bottom: px(0.05),
          width: px(0.42),
          height: 3,
          background: c2,
          opacity: 0.8,
        }}
      />,
    ];
  } else if (style === "confetti") {
    const seeds: ReadonlyArray<readonly [number, number, number, number]> = [
      [0.08, 0.12, 14, 22],
      [0.24, 0.58, 9, -14],
      [0.42, 0.2, 12, 40],
      [0.6, 0.66, 8, 8],
      [0.74, 0.3, 15, -32],
      [0.88, 0.74, 10, 18],
      [0.34, 0.84, 7, 60],
      [0.52, 0.42, 11, -20],
      [0.16, 0.4, 8, 34],
      [0.92, 0.18, 12, 6],
    ];
    layers = seeds.map(([x, y, size, rot], i) => (
      <div
        key={`c${i}`}
        style={{
          position: "absolute",
          left: px(x),
          top: y * h,
          width: size,
          height: size * 0.42,
          background: i % 3 === 0 ? "#fff" : c2,
          borderRadius: 100,
          transform: `rotate(${rot}deg)`,
          opacity: i % 3 === 0 ? 0.8 : 0.92,
        }}
      />
    ));
    layers.push(
      <div key="glow" style={{ ...fill, background: "radial-gradient(70% 90% at 20% 0%,rgba(255,255,255,.4),transparent)" }} />,
    );
  } else if (style === "planes") {
    layers = [
      <div key="a" style={{ ...fill, background: `linear-gradient(118deg,${c1} 0 38%,${c2} 38% 56%,${c1} 56% 100%)` }} />,
      <div
        key="b"
        style={{ ...fill, background: "linear-gradient(132deg,rgba(255,255,255,0) 44%,rgba(255,255,255,.22) 50%,rgba(255,255,255,0) 56%)" }}
      />,
      <div
        key="c"
        style={{
          position: "absolute",
          left: 0,
          bottom: 0,
          width: "58%",
          height: "54%",
          backgroundImage: "radial-gradient(rgba(255,255,255,.3) 1px,transparent 1.2px)",
          backgroundSize: `${7 * k}px ${7 * k}px`,
          maskImage: "linear-gradient(30deg,#000,transparent 72%)",
          WebkitMaskImage: "linear-gradient(30deg,#000,transparent 72%)",
        }}
      />,
      <div
        key="d"
        style={{
          position: "absolute",
          right: "-8%",
          top: "-30%",
          width: "52%",
          height: "160%",
          background: c2,
          opacity: 0.5,
          transform: "rotate(24deg)",
        }}
      />,
    ];
  } else if (style === "metal") {
    layers = [
      <div
        key="a"
        style={{ ...fill, background: `linear-gradient(104deg,${c1} 0%,${c2} 34%,${c1} 58%,${c2} 82%,${c1} 100%)` }}
      />,
      <div
        key="b"
        style={{ ...fill, backgroundImage: "repeating-linear-gradient(104deg,rgba(255,255,255,.16) 0 1px,rgba(0,0,0,.05) 1px 3px)" }}
      />,
      <div
        key="c"
        style={{
          position: "absolute",
          left: "-10%",
          top: "18%",
          width: "130%",
          height: "54%",
          background: "radial-gradient(60% 100% at 40% 50%,rgba(255,255,255,.5),transparent 70%)",
          transform: "rotate(-8deg)",
        }}
      />,
    ];
    if (art.tier) {
      layers.push(
        <div
          key="tier"
          style={{
            position: "absolute",
            right: 19 * k,
            top: 18 * k,
            font: `500 ${10 * k}px/1 var(--font-outfit),sans-serif`,
            letterSpacing: ".28em",
            color: "rgba(0,0,0,.5)",
          }}
        >
          {art.tier}
        </div>,
      );
    }
  } else if (style === "glyph") {
    layers = [
      <div key="a" style={{ ...fill, background: c1 }} />,
      <div
        key="b"
        style={{
          position: "absolute",
          right: "-4%",
          top: "50%",
          transform: "translateY(-50%)",
          font: `800 ${h * 1.15}px/0.78 var(--font-outfit),sans-serif`,
          color: c2,
          opacity: 0.13,
          letterSpacing: "-.06em",
        }}
      >
        {art.glyph || "S"}
      </div>,
      <div key="c" style={{ ...fill, background: "radial-gradient(80% 70% at 12% 8%,rgba(255,255,255,.14),transparent 62%)" }} />,
    ];
  } else if (style === "orbit") {
    layers = [
      <div key="a" style={{ ...fill, background: c1 }} />,
      <div
        key="b"
        style={{
          ...fill,
          backgroundImage: `repeating-radial-gradient(circle at 88% 78%,${c2} 0 ${11 * k}px,rgba(255,255,255,0) ${11 * k}px ${24 * k}px)`,
          opacity: 0.55,
        }}
      />,
      <div
        key="c"
        style={{
          ...fill,
          backgroundImage: "radial-gradient(rgba(255,255,255,.6) .8px,transparent 1px)",
          backgroundSize: `${16 * k}px ${13 * k}px`,
          opacity: 0.5,
        }}
      />,
    ];
  } else if (style === "foil") {
    layers = [
      <div key="a" style={{ ...fill, background: c1 }} />,
      <div
        key="b"
        style={{
          position: "absolute",
          right: "-24%",
          top: "-46%",
          width: "96%",
          height: "190%",
          borderRadius: "50%",
          border: `${3.2 * k}px solid ${c2}`,
          opacity: 0.95,
          transform: "rotate(-16deg)",
        }}
      />,
      <div
        key="c"
        style={{
          position: "absolute",
          right: "-14%",
          top: "-24%",
          width: "72%",
          height: "150%",
          borderRadius: "50%",
          border: `${1.4 * k}px solid ${c2}`,
          opacity: 0.5,
          transform: "rotate(-16deg)",
        }}
      />,
      <div key="d" style={{ ...fill, background: "linear-gradient(120deg,transparent 40%,rgba(255,255,255,.1) 52%,transparent 62%)" }} />,
    ];
  } else if (style === "irid") {
    layers = [
      <div key="a" style={{ ...fill, background: `conic-gradient(from 200deg at 32% 20%,${c1},${c2},#fdf1c9,${c1})` }} />,
      <div key="b" style={{ ...fill, background: "radial-gradient(70% 90% at 78% 88%,rgba(255,255,255,.55),transparent 64%)" }} />,
      <div
        key="c"
        style={{
          ...fill,
          backgroundImage: "radial-gradient(rgba(255,255,255,.5) .7px,transparent .9px)",
          backgroundSize: `${6 * k}px ${6 * k}px`,
          opacity: 0.5,
        }}
      />,
    ];
  } else if (style === "crest") {
    layers = [
      <div key="a" style={{ ...fill, background: `linear-gradient(160deg,${c1} 0%,#071736 100%)` }} />,
      <div
        key="b"
        style={{
          ...fill,
          backgroundImage: `repeating-radial-gradient(circle at 74% 116%,rgba(255,255,255,.26) 0 1px,rgba(255,255,255,0) 1px ${13 * k}px)`,
        }}
      />,
      <div
        key="c"
        style={{
          position: "absolute",
          left: "-6%",
          top: "-40%",
          width: "46%",
          height: "180%",
          background: c2,
          opacity: 0.85,
          transform: "rotate(18deg)",
        }}
      />,
      <div
        key="d"
        style={{ ...fill, backgroundImage: `repeating-linear-gradient(90deg,rgba(255,255,255,.07) 0 1px,transparent 1px ${9 * k}px)` }}
      />,
    ];
  } else if (style === "photo") {
    const p = art.photo;
    if (!p?.src) {
      layers = [
        <div key="a" style={{ ...fill, background: `linear-gradient(135deg,${c1} 0%,${c2} 100%)` }} />,
        <div
          key="b"
          style={{
            ...fill,
            display: "flex",
            flexDirection: "column",
            alignItems: "center",
            justifyContent: "center",
            gap: 8,
          }}
        >
          <svg width={26} height={26} viewBox="0 0 24 24" fill="none" stroke="rgba(255,255,255,.9)" strokeWidth={2} strokeLinecap="round">
            <rect x={3} y={5} width={18} height={14} rx={3} />
            <path d="M3 16l5-5 4 4 3-3 6 6" />
            <circle cx={8.5} cy={9.5} r={1.4} />
          </svg>
          <div style={{ font: "600 11px/1 var(--font-outfit),sans-serif", color: "rgba(255,255,255,.9)", letterSpacing: ".04em" }}>
            Your photo here
          </div>
        </div>,
      ];
    } else {
      const metrics = measure(p);
      const alpha = SCRIM[p.scrim];
      const rgb = metrics.scrimIsDark ? "0,0,0" : "255,255,255";
      layers = [
        <div key="img" style={{ ...fill, overflow: "hidden" }}>
          <div
            style={{
              position: "absolute",
              inset: "-2%",
              backgroundImage: `url(${p.src})`,
              backgroundSize: "cover",
              backgroundPosition: "center",
              transform: `scale(${p.zoom || 1}) translate(${p.px || 0}%,${p.py || 0}%)`,
              filter: p.blur ? "blur(7px)" : "none",
              transition: "transform .18s ease-out, filter .3s",
            }}
          />
        </div>,
      ];
      if (alpha > 0) {
        layers.push(
          <div
            key="scrim"
            style={{
              ...fill,
              transition: "background .3s",
              background:
                p.scrim === "veil"
                  ? `rgba(${rgb},${alpha})`
                  : `linear-gradient(to top,rgba(${rgb},${alpha}) 0%,rgba(${rgb},${(alpha * 0.62).toFixed(3)}) 38%,rgba(${rgb},0) 76%),linear-gradient(to bottom,rgba(${rgb},${(alpha * 0.45).toFixed(3)}) 0%,rgba(${rgb},0) 34%)`,
            }}
          />,
        );
      }
    }
  } else {
    // mesh — the default soft-focus wash
    layers = [
      <div
        key="a"
        style={{
          ...fill,
          background: `radial-gradient(60% 80% at 12% 8%,${c2} 0%,transparent 62%),radial-gradient(55% 70% at 92% 88%,${c2} 0%,transparent 60%),radial-gradient(40% 50% at 70% 18%,rgba(255,255,255,.32) 0%,transparent 70%)`,
          opacity: 0.95,
        }}
      />,
    ];
  }

  // Damp the pattern to the tuned amplitude. The flat c1 base sits behind, so lowering the
  // group's opacity blends it toward c1 exactly as patternExtremes models.
  const tuned = patternScrim(art);
  const painted: ReactNode[] =
    tuned && tuned.k < 1 && layers.length
      ? [
          <div key="pattern" style={{ ...fill, opacity: tuned.k }}>
            {layers}
          </div>,
        ]
      : layers;

  if (art.tex === "grain") {
    painted.push(
      <div
        key="tex"
        style={{
          ...fill,
          backgroundImage: "radial-gradient(rgba(0,0,0,.5) .7px,transparent .8px)",
          backgroundSize: "3.5px 3.5px",
          opacity: 0.16,
          mixBlendMode: "multiply",
        }}
      />,
    );
  } else if (art.tex === "dots") {
    painted.push(
      <div
        key="tex"
        style={{
          ...fill,
          backgroundImage: "radial-gradient(rgba(0,0,0,.42) 1.6px,transparent 1.7px)",
          backgroundSize: "13px 13px",
          opacity: 0.2,
        }}
      />,
    );
  } else if (art.tex === "stripes") {
    painted.push(
      <div
        key="tex"
        style={{ ...fill, backgroundImage: "repeating-linear-gradient(115deg,rgba(255,255,255,.16) 0 2px,transparent 2px 11px)" }}
      />,
    );
  }

  // Scrim behind BOTH text zones — deck cards carry the balance bottom-left, stack cards carry
  // it top-right, so a pattern card has to protect top and bottom alike. Both ends get the
  // full-strength stop, decaying into the untouched middle.
  if (tuned && tuned.alpha > 0) {
    const rgb = tuned.scrimIsDark ? "0,0,0" : "255,255,255";
    const a = tuned.alpha;
    painted.push(
      <div
        key="pattern-scrim"
        style={{
          ...fill,
          background: `linear-gradient(to top,rgba(${rgb},${a}) 0%,rgba(${rgb},${(a * 0.62).toFixed(3)}) 26%,rgba(${rgb},0) 52%),linear-gradient(to bottom,rgba(${rgb},${a}) 0%,rgba(${rgb},${(a * 0.62).toFixed(3)}) 24%,rgba(${rgb},0) 48%)`,
        }}
      />,
    );
  }

  // EMV chip + contactless mark: the functional anatomy of a real PH ATM/debit card. The
  // network badge is a neutral placeholder — a live build drops the issuer's mark in.
  if (art.chip) {
    const chipW = 40 * k;
    const chipH = 30 * k;
    const dark = tuned ? tuned.useDark : isLight(c1);
    const line = dark ? "rgba(0,0,0,.35)" : "rgba(255,255,255,.45)";
    // On a plate, so the badge never has to fight the pattern underneath it.
    const plate = dark ? "rgba(255,255,255,.92)" : "rgba(11,11,12,.72)";
    const plateFg = dark ? "#0b0b0c" : "#ffffff";

    painted.push(
      <div key="chip" style={{ position: "absolute", left: 19 * k, top: 74 * k, display: "flex", alignItems: "center", gap: 10 * k }}>
        <div
          style={{
            width: chipW,
            height: chipH,
            borderRadius: 5 * k,
            background: "linear-gradient(135deg,#e8c86a 0%,#f6e6ae 38%,#c9a03f 70%,#eddba0 100%)",
            position: "relative",
            overflow: "hidden",
            boxShadow: `inset 0 0 0 ${0.8 * k}px rgba(0,0,0,.22)`,
          }}
        >
          <div
            style={{
              ...fill,
              backgroundImage: `linear-gradient(0deg,rgba(120,90,20,.55) 0 ${1 * k}px,transparent ${1 * k}px ${6 * k}px)`,
            }}
          />
          <div
            style={{
              position: "absolute",
              left: "28%",
              top: "18%",
              width: "44%",
              height: "64%",
              border: `${0.9 * k}px solid rgba(120,90,20,.6)`,
              borderRadius: 2 * k,
            }}
          />
        </div>
        <div style={{ display: "flex", alignItems: "center", gap: 1.5 * k }}>
          {[0, 1, 2].map((i) => (
            <div
              key={i}
              style={{
                width: 3.4 * k,
                height: (9 + i * 5) * k,
                borderRight: `${1.9 * k}px solid ${line}`,
                borderTopRightRadius: 9 * k,
                borderBottomRightRadius: 9 * k,
              }}
            />
          ))}
        </div>
      </div>,
      <div
        key="network"
        style={{
          position: "absolute",
          right: 19 * k,
          top: 74 * k,
          height: 22 * k,
          padding: `0 ${8 * k}px`,
          borderRadius: 100 * k,
          background: plate,
          display: "flex",
          alignItems: "center",
          gap: 5 * k,
        }}
      >
        <div style={{ display: "flex", alignItems: "center" }}>
          <div style={{ width: 11 * k, height: 11 * k, borderRadius: 100, background: plateFg, opacity: 0.85 }} />
          <div style={{ width: 11 * k, height: 11 * k, borderRadius: 100, background: plateFg, opacity: 0.42, marginLeft: -4.5 * k }} />
        </div>
        <div style={{ font: `700 ${9.5 * k}px/1 var(--font-outfit),sans-serif`, letterSpacing: ".13em", color: plateFg }}>DEBIT</div>
      </div>,
    );
  }

  painted.push(
    <div
      key="shine"
      style={{
        position: "absolute",
        top: 0,
        left: 0,
        width: "42%",
        height: "100%",
        background: "linear-gradient(100deg,transparent,rgba(255,255,255,.3),transparent)",
        animation: "bwShine 5.5s 1.2s ease-in-out infinite",
      }}
    />,
  );

  return (
    <div style={{ ...fill, overflow: "hidden", borderRadius: r, background: c1 } as Style}>{painted}</div>
  );
}

export const CardArt = memo(CardArtImpl);

/** Card art with the oversized initial the `glyph` template composes around. */
export function CardArtFor({
  card,
  w,
  h,
  r,
}: {
  card: Pick<Card, "art" | "nick">;
  w?: number;
  h?: number;
  r?: number;
}) {
  const glyph = (card.nick || "?").trim().charAt(0).toUpperCase();
  return <CardArt art={{ ...card.art, glyph }} w={w} h={h} r={r} />;
}
