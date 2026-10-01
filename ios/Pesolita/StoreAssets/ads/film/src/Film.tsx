import React from "react";
import { AbsoluteFill, Audio, interpolate, Sequence, staticFile } from "remotion";
import { CinemaClip } from "./components/CinemaClip";
import { Flash, Scrim } from "./components/fx";
import { PhoneStage } from "./components/PhoneStage";
import { TitleCard } from "./components/TitleCard";
import { AmountHit, Kicker, PesoCounter, RunningTotal, Slam, Subtitle, TypeOn } from "./components/Type";
import { CUT, HERO, IN, MONTAGE } from "./timeline";
import { DANGER, GOLD, WHITE } from "./theme";
import { VO, VO_FILE } from "./vo";

type Span = readonly [number, number];
const Seq: React.FC<{ span: Span; children: React.ReactNode }> = ({ span, children }) => (
  <Sequence from={span[0]} durationInFrames={span[1]}>
    {children}
  </Sequence>
);

// ── Openings (the hook variants) ────────────────────────────────────────────────────────────
export type Hook = 1 | 2 | 3;

const OpenStorm: React.FC<{ hook: Hook }> = ({ hook }) => (
  <AbsoluteFill>
    <CinemaClip src="flow/s1-storm.mp4" from={IN.storm} grade="night" volume={0.5} zoom={[1.02, 1.14]} />
    <Scrim top={0.35} bottom={0.5} />
    {hook === 3 ? (
      <Slam text={"SAAN NAPUNTA\nANG SAHOD MO?"} instant size={150} y={820} out={118} />
    ) : (
      <>
        <Slam text="25" instant size={430} color={DANGER} y={760} glow="rgba(255,59,48,0.55)" out={118} />
        <TypeOn text="5 DAYS TO SAHOD." instant size={78} y={1040} />
      </>
    )}
    <Flash at={45} frames={4} peak={0.35} />
    <Flash at={120} frames={4} peak={0.3} />
  </AbsoluteFill>
);

const OpenMoth: React.FC = () => (
  <AbsoluteFill>
    <CinemaClip src="flow/s2-moth.mp4" from={IN.mothHook} grade="night" volume={0.7} zoom={[1.06, 1.16]} />
    <Scrim />
    <Kicker text="POV:" y={350} size={56} at={-10} />
    <Slam text={"5 DAYS BAGO\nSAHOD."} instant size={150} y={560} />
  </AbsoluteFill>
);

// ── Story beats ─────────────────────────────────────────────────────────────────────────────
const Moth: React.FC = () => (
  <AbsoluteFill>
    <CinemaClip src="flow/s2-moth.mp4" from={IN.moth} grade="night" volume={0.7} zoom={[1.0, 1.1]} />
    <Scrim />
    <Slam text="ONE WOMAN." at={16} size={130} y={380} out={48} />
    <Slam text="ONE WALLET." at={50} size={130} y={380} />
  </AbsoluteFill>
);

const Spend: React.FC<{ src: string; from: number; i: number; grade?: "night" | "neon" | "warm"; volume?: number }> = ({
  src,
  from,
  i,
  grade = "night",
  volume = 0.15,
}) => {
  const item = MONTAGE[i];
  const before = MONTAGE.slice(0, i).reduce((a, m) => a + m.amount, 0);
  return (
    <AbsoluteFill>
      <CinemaClip src={src} from={from} grade={grade} volume={volume} zoom={[1.08, 1.0]} />
      <Scrim top={0.6} bottom={0.4} />
      <AmountHit label={item.label} amount={item.amount} />
      <RunningTotal from={before} to={before + item.amount} />
      <Flash at={0} frames={3} peak={0.5} />
    </AbsoluteFill>
  );
};

const Libre: React.FC<{ paoloFrames: number }> = ({ paoloFrames }) => (
  <AbsoluteFill>
    <Sequence durationInFrames={paoloFrames}>
      <Spend src="flow/s6-libre.mp4" from={IN.libre} i={3} grade="warm" volume={1} />
    </Sequence>
    <Sequence from={paoloFrames}>
      <CinemaClip src="flow/s6-libre.mp4" from={IN.libreDeadpan} grade="warm" volume={0.35} zoom={[1.12, 1.2]} origin="40% 45%" />
      <RunningTotal from={4329} to={4329} />
    </Sequence>
  </AbsoluteFill>
);

const Glow: React.FC = () => (
  <AbsoluteFill>
    <CinemaClip src="flow/s7-glow.mp4" from={IN.glow} grade="night" zoom={[1.1, 1.22]} />
    <Scrim top={0.6} bottom={0.3} />
    <Slam text={"SAAN\nNAPUNTA?!"} at={2} size={190} y={470} />
  </AbsoluteFill>
);

const Insights: React.FC = () => (
  <AbsoluteFill>
    <PhoneStage src="app/insights.png" enter focusY={0.68} zoom={[1, 1.32]} zoomAt={[24, 84]} />
    <Slam text="DITO PALA." at={8} size={150} color={GOLD} y={300} glow="rgba(255,202,40,0.45)" />
    <Flash at={0} frames={6} peak={0.6} />
  </AbsoluteFill>
);

const Safe: React.FC = () => (
  <AbsoluteFill>
    <PhoneStage src="app/safe.png" enter={false} focusY={0.52} zoom={[1.0, 1.16]} zoomAt={[0, 60]} offsetY={760} shade={0.36} />
    <Kicker text="SAFE TO SPEND TODAY" y={250} size={44} at={4} />
    <PesoCounter value={3128} at={10} frames={26} y={390} size={150} />
  </AbsoluteFill>
);

const Coffee: React.FC = () => (
  <AbsoluteFill>
    <PhoneStage src="app/coffee.mp4" video from={3.5} rate={1.2} enter={false} focusY={0.3} zoom={[1.02, 1.12]} />
    <Slam text={"4 SECONDS."} at={6} size={140} y={300} color={WHITE} />
    <Kicker text="BAWAT GASTOS, LOGGED." y={420} size={40} at={18} color={GOLD} />
  </AbsoluteFill>
);

const Day30: React.FC = () => (
  <AbsoluteFill>
    <CinemaClip src="flow/s8-day30.mp4" from={IN.day30} grade="day" volume={0.4} zoom={[1.0, 1.08]} />
    <Scrim top={0.45} bottom={0.25} />
    <Slam text="DAY 30." at={4} size={150} y={330} color={WHITE} />
    <Slam text="CHILL LANG." at={26} size={150} y={480} color={GOLD} />
  </AbsoluteFill>
);

const Sting: React.FC = () => (
  <AbsoluteFill>
    <CinemaClip src="flow/s9-sting.mp4" from={IN.sting} grade="warm" volume={1} zoom={[1.04, 1.12]} />
    <Scrim top={0.5} bottom={0.3} />
    <Kicker text="BAWAL NA ANG" y={330} size={48} at={44} />
    <Slam text="GAMU-GAMO." at={46} size={140} y={450} color={GOLD} />
  </AbsoluteFill>
);

// ── Sound ───────────────────────────────────────────────────────────────────────────────────
type Cue = { sfx: string; at: number; vol?: number };
const Sfx: React.FC<{ cues: Cue[] }> = ({ cues }) => (
  <>
    {cues.map((c, i) => (
      <Sequence key={i} from={c.at}>
        <Audio src={staticFile(`sfx/${c.sfx}.wav`)} volume={c.vol ?? 0.8} />
      </Sequence>
    ))}
  </>
);

type Line = { id: keyof typeof VO; at: number; sub?: string };
const Narration: React.FC<{ lines: Line[] }> = ({ lines }) => (
  <>
    {lines.map((l, i) => {
      const [a, b, text] = VO[l.id];
      const len = Math.round((b - a) * 30);
      return (
        <React.Fragment key={i}>
          <Sequence from={l.at} durationInFrames={len + 6}>
            <Audio src={staticFile(VO_FILE)} trimBefore={Math.round(a * 30)} trimAfter={Math.round(b * 30) + 4} volume={1.15} />
          </Sequence>
          <Subtitle text={l.sub ?? text} at={l.at} until={l.at + len + 4} />
        </React.Fragment>
      );
    })}
  </>
);

/** Music ducks under the narrator (and the actors' key lines). */
const duck = (lines: Line[], extra: Span[]) => (f: number) => {
  let v = 0.85;
  const spans: Span[] = [
    ...lines.map((l) => [l.at, Math.round((VO[l.id][1] - VO[l.id][0]) * 30)] as Span),
    ...extra,
  ];
  for (const [at, len] of spans) {
    v = Math.min(v, interpolate(f, [at - 5, at, at + len, at + len + 8], [0.85, 0.42, 0.42, 0.85], {
      extrapolateLeft: "clamp",
      extrapolateRight: "clamp",
    }));
  }
  return v;
};

// ── Hero (30 s) ─────────────────────────────────────────────────────────────────────────────
export const Hero: React.FC<{ hook: Hook }> = ({ hook }) => {
  const H = HERO;
  const lines: Line[] = [
    { id: "world", at: 4 },
    { id: "woman", at: H.moth[0] + 18 },
    { id: "wallet", at: H.moth[0] + 52 },
    { id: "where", at: H.insights[0] + 4 },
    { id: "safe", at: H.safe[0] + 10 },
    { id: "log", at: H.coffee[0] + 2 },
    { id: "day30", at: H.day30[0] + 6 },
    { id: "peligro", at: H.title[0] + 2 },
    { id: "free", at: H.title[0] + 88 },
  ];
  const cues: Cue[] = [
    { sfx: "heartbeat", at: 0, vol: 0.9 },
    { sfx: "heartbeat", at: 40, vol: 0.9 },
    { sfx: "thunder", at: 40, vol: 0.5 },
    { sfx: "heartbeat", at: 80, vol: 0.9 },
    { sfx: "braam", at: H.moth[0], vol: 0.9 },
    { sfx: "whoosh-short", at: H.milktea[0] - 6 },
    { sfx: "impact", at: H.milktea[0], vol: 0.7 },
    { sfx: "impact", at: H.ride[0], vol: 0.7 },
    { sfx: "impact", at: H.parcels[0], vol: 0.75 },
    { sfx: "impact", at: H.libre[0], vol: 0.8 },
    { sfx: "riser", at: H.glow[0] - 27, vol: 0.7 },
    { sfx: "subdrop", at: H.insights[0], vol: 0.9 },
    { sfx: "whoosh", at: H.insights[0] - 8, vol: 0.8 },
    { sfx: "pop", at: H.insights[0] + 10, vol: 0.6 },
    { sfx: "whoosh-short", at: H.safe[0] - 4, vol: 0.6 },
    { sfx: "tick", at: H.coffee[0] + 10, vol: 0.6 },
    { sfx: "tick", at: H.coffee[0] + 18, vol: 0.6 },
    { sfx: "tick", at: H.coffee[0] + 26, vol: 0.6 },
    { sfx: "pop", at: H.coffee[0] + 60, vol: 0.7 },
    { sfx: "impact", at: H.title[0], vol: 1 },
    { sfx: "braam", at: H.title[0], vol: 0.8 },
    { sfx: "impact", at: H.title[0] + 22, vol: 0.7 },
    { sfx: "whoosh", at: H.title[0] + 78, vol: 0.6 },
    { sfx: "kaching", at: H.title[0] + 84, vol: 0.9 },
    { sfx: "snap", at: H.sting[0] + 39, vol: 0.5 },
  ];
  // Hook 2 opens on the moth, then the storm (so the two openings swap places).
  const openFirst = hook === 2 ? <OpenMoth /> : <OpenStorm hook={hook} />;
  const second = hook === 2 ? <OpenStorm hook={1} /> : <Moth />;
  return (
    <AbsoluteFill style={{ background: "#000" }}>
      <Audio src={staticFile("music/score.wav")} volume={duck(lines, [[H.libre[0], 33], [H.sting[0] + 30, 30]])} />
      <Seq span={H.open}>{openFirst}</Seq>
      <Seq span={H.moth}>{second}</Seq>
      <Seq span={H.milktea}>
        <Spend src="flow/s3-milktea.mp4" from={IN.milktea} i={0} grade="neon" />
      </Seq>
      <Seq span={H.ride}>
        <Spend src="flow/s4-ride.mp4" from={IN.ride} i={1} />
      </Seq>
      <Seq span={H.parcels}>
        <Spend src="flow/s5-parcels.mp4" from={IN.parcels} i={2} grade="warm" volume={0.4} />
      </Seq>
      <Seq span={H.libre}>
        <Libre paoloFrames={33} />
      </Seq>
      <Seq span={H.glow}>
        <Glow />
      </Seq>
      <Seq span={H.insights}>
        <Insights />
      </Seq>
      <Seq span={H.safe}>
        <Safe />
      </Seq>
      <Seq span={H.coffee}>
        <Coffee />
      </Seq>
      <Seq span={H.day30}>
        <Day30 />
      </Seq>
      <Seq span={H.title}>
        <TitleCard logoAt={84} />
      </Seq>
      <Seq span={H.sting}>
        <Sting />
      </Seq>
      <Sfx cues={cues} />
      <Narration lines={lines} />
    </AbsoluteFill>
  );
};

// ── 15-second cut ───────────────────────────────────────────────────────────────────────────
export const Cut15: React.FC = () => {
  const C = CUT;
  const lines: Line[] = [
    { id: "where", at: C.insights[0] + 2 },
    { id: "safe", at: C.safe[0] + 6 },
    { id: "free", at: C.title[0] + 42 },
  ];
  const cues: Cue[] = [
    { sfx: "heartbeat", at: 0, vol: 0.9 },
    { sfx: "thunder", at: 10, vol: 0.5 },
    { sfx: "braam", at: C.moth[0], vol: 0.9 },
    { sfx: "impact", at: C.milktea[0], vol: 0.7 },
    { sfx: "impact", at: C.ride[0], vol: 0.7 },
    { sfx: "impact", at: C.parcels[0], vol: 0.7 },
    { sfx: "impact", at: C.libre[0], vol: 0.8 },
    { sfx: "subdrop", at: C.insights[0], vol: 0.9 },
    { sfx: "whoosh", at: C.insights[0] - 8, vol: 0.8 },
    { sfx: "impact", at: C.title[0], vol: 1 },
    { sfx: "braam", at: C.title[0], vol: 0.8 },
    { sfx: "kaching", at: C.title[0] + 40, vol: 0.9 },
  ];
  return (
    <AbsoluteFill style={{ background: "#000" }}>
      <Audio src={staticFile("music/score-cut15.wav")} volume={duck(lines, [])} />
      <Seq span={C.open}>
        <OpenStorm hook={1} />
      </Seq>
      <Seq span={C.moth}>
        <AbsoluteFill>
          <CinemaClip src="flow/s2-moth.mp4" from={IN.moth + 0.3} grade="night" volume={0.7} />
          <Scrim />
          <Slam text="ONE WALLET." at={4} size={130} y={380} />
        </AbsoluteFill>
      </Seq>
      <Seq span={C.milktea}>
        <Spend src="flow/s3-milktea.mp4" from={IN.milktea} i={0} grade="neon" />
      </Seq>
      <Seq span={C.ride}>
        <Spend src="flow/s4-ride.mp4" from={IN.ride} i={1} />
      </Seq>
      <Seq span={C.parcels}>
        <Spend src="flow/s5-parcels.mp4" from={IN.parcels} i={2} grade="warm" />
      </Seq>
      <Seq span={C.libre}>
        <Spend src="flow/s6-libre.mp4" from={IN.libre + 0.25} i={3} grade="warm" volume={1} />
      </Seq>
      <Seq span={C.insights}>
        <Insights />
      </Seq>
      <Seq span={C.safe}>
        <Safe />
      </Seq>
      <Seq span={C.title}>
        <TitleCard logoAt={40} />
      </Seq>
      <Sfx cues={cues} />
      <Narration lines={lines} />
    </AbsoluteFill>
  );
};
