// Frame timings for the films (30 fps). audio/make_score.py mirrors the section boundaries.
export const FPS = 30;
export const W = 1080;
export const H = 1920;

export const s = (seconds: number) => Math.round(seconds * FPS);

// Hero, 33 s. Each entry: [from, duration].
export const HERO = {
  open: [0, 135], // storm + "25" (or a hook variant)
  moth: [135, 84], // "ONE WOMAN. ONE WALLET."
  milktea: [219, 33],
  ride: [252, 33],
  parcels: [285, 33],
  libre: [318, 54], // Paolo: "Libre ko na!" (33 f), then Mika's deadpan (21 f) as the music drops
  glow: [372, 33], // "SAAN NAPUNTA?!"
  insights: [405, 90], // "DITO PALA."
  safe: [495, 90], // safe to spend today
  coffee: [585, 75], // 4 seconds
  day30: [660, 90], // "DAY 30. CHILL LANG."
  title: [750, 150], // PETSA DE PELIGRO? HINDI NA. -> logo + "Free on the App Store"
  sting: [900, 90], // the moth tries to come back
} as const;
export const HERO_LEN = 990;

// The ~16-second cut-down.
export const CUT = {
  open: [0, 60],
  moth: [60, 60],
  milktea: [120, 19],
  ride: [139, 19],
  parcels: [158, 19],
  libre: [177, 18],
  insights: [195, 75],
  safe: [270, 75],
  title: [345, 135],
} as const;
export const CUT_LEN = 480;

// The montage amounts (all ₱) and what they were spent on.
export const MONTAGE = [
  { key: "milktea", label: "MILK TEA", amount: 180 },
  { key: "ride", label: "RIDE HOME", amount: 350 },
  { key: "parcels", label: "ADD TO CART", amount: 1299 },
  { key: "libre", label: "“LIBRE KO NA!”", amount: 2500 },
] as const;

// Where each Flow clip is cut from (seconds into the clip), measured from the footage.
export const IN = {
  storm: 0.0, // lightning at 1.5 s and 4.0 s
  moth: 3.4, // the moth flutters out at 3.6 s, deadpan to camera from 5.5 s
  mothHook: 5.0, // hook 2 cold open: the moth by the lamp, then the stare
  milktea: 0.6, // the glass slides in
  ride: 4.0, // head against the rainy window
  parcels: 5.3, // the boxes topple
  libre: 1.3, // "Libre ko na!" at 1.6-2.2 s, cheer at 2.5 s
  libreDeadpan: 6.1, // Mika's flat stare
  glow: 5.8, // deadpan turning into a knowing half-smile
  day30: 5.0, // phone buzz, calm smile, nod
  sting: 4.4, // the snap lands at 5.7 s
} as const;
