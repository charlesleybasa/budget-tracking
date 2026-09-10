/** Timing and easing copied from the supplied Pesolita celebration source. */
export const CELEBRATION_SECONDS = 3.6;
export const BURST_AT = 1.4;
export const LAND_AT = 1.845;
export const SOURCE_SCALE = 2.2;
type Ease = (value: number) => number;
type Key = [number, number, Ease?];
const eio: Ease = u => u < 0.5 ? 2 * u * u : 1 - Math.pow(-2 * u + 2, 2) / 2;
const eOut: Ease = u => 1 - Math.pow(1 - u, 3);
const eIn: Ease = u => u * u * u;
const eOutQ: Ease = u => 1 - (1 - u) * (1 - u);
const eInQ: Ease = u => u * u;
const eBack: Ease = u => 1 + 2 * Math.pow(u - 1, 3) + 1.2 * Math.pow(u - 1, 2);

function keyframe(t: number, keys: Key[]) {
  if (t <= keys[0][0]) return keys[0][1];
  for (let i = 1; i < keys.length; i++) {
    if (t <= keys[i][0]) {
      const [t0, v0] = keys[i - 1];
      const [t1, v1, ease = eio] = keys[i];
      return v0 + (v1 - v0) * ease((t - t0) / (t1 - t0));
    }
  }
  return keys[keys.length - 1][1];
}

const TRACKS = {
  rootY: [
    [0, 0], [0.85, 0, eio], [1.04, -0.058, eOut], [1.16, -0.048, eio],
    [1.26, 0.075, eIn], [1.42, 0.295, eOutQ], [1.60, 0.255, eio],
    [1.82, 0, eInQ], [1.90, -0.048, eOut], [2.02, 0.022, eOut], [2.14, 0, eio], [3.6, 0],
  ],
  squash: [
    [0, 1], [0.86, 1, eio], [1.04, 0.865, eOut], [1.16, 0.9, eio], [1.26, 1.13, eOut],
    [1.45, 1.05, eio], [1.78, 1.1, eio], [1.88, 0.83, eOut], [1.99, 1.06, eOut],
    [2.12, 0.985, eio], [2.26, 1, eio], [3.6, 1],
  ],
  armRaise: [
    [0, 0], [0.55, 0.03, eio], [0.9, -0.17, eOut], [1.14, -0.22, eio],
    [1.32, 0.97, eOut], [1.48, 1.06, eio], [1.78, 1.0, eio], [1.92, 0.86, eOut],
    [2.06, 1.0, eOut], [2.9, 1.0, eio], [3.3, 0.05, eio], [3.6, 0],
  ],
  happy: [
    [0, 0], [1.06, 0, eio], [1.2, 1, eOut], [2.88, 1, eio], [3.08, 0, eOut], [3.6, 0],
  ],
  eyeWide: [
    [0, 1], [0.56, 1, eio], [0.72, 1.13, eBack], [1.06, 1.09, eio], [1.2, 1, eio], [3.6, 1],
  ],
  mouth: [
    [0, 0.42], [0.56, 0.46, eio], [0.76, 0.64, eOut], [1.04, 0.5, eio], [1.22, 1, eOut],
    [1.9, 0.95, eio], [2.3, 0.9, eio], [2.9, 0.86, eio], [3.24, 0.45, eio], [3.6, 0.42],
  ],
  lean: [
    [0, 0], [0.86, -0.025, eio], [1.04, 0.17, eOut], [1.26, -0.11, eOut], [1.45, -0.04, eio],
    [1.82, 0.07, eio], [1.9, 0.13, eOut], [2.12, -0.03, eio], [2.34, 0, eio], [3.6, 0],
  ],
  crouch: [
    [0, 0.06], [0.86, 0.1, eio], [1.04, 1, eOut], [1.16, 0.86, eio], [1.28, 0, eOut],
    [1.44, 0.32, eio], [1.66, 0.26, eio], [1.8, 0, eIn], [1.9, 0.95, eOut],
    [2.02, 0.28, eOut], [2.18, 0.09, eio], [3.6, 0.06],
  ],
  perk: [
    [0, 0], [0.6, 0, eio], [0.76, 1, eBack], [1.14, 0.9, eio], [1.45, 0.72, eio],
    [2.9, 0.5, eio], [3.24, 0, eio], [3.6, 0],
  ],
  push: [
    [0, 0], [1.06, 0, eio], [1.42, 1, eOut], [1.95, 0.62, eio], [2.7, 0.32, eio], [3.42, 0, eio], [3.6, 0],
  ],
} satisfies Record<string, Key[]>;

export function sampleCelebration(seconds: number, reducedMotion = false) {
  const time = reducedMotion ? 0 : Math.max(0, Math.min(seconds, CELEBRATION_SECONDS));
  return {
    time,
    rootY: keyframe(time, TRACKS.rootY) + 0.009 * Math.sin(time / CELEBRATION_SECONDS * Math.PI * 4),
    squash: keyframe(time, TRACKS.squash),
    armRaise: keyframe(time, TRACKS.armRaise),
    happy: keyframe(time, TRACKS.happy),
    eyeWide: keyframe(time, TRACKS.eyeWide),
    mouth: keyframe(time, TRACKS.mouth),
    lean: keyframe(time, TRACKS.lean),
    crouch: keyframe(time, TRACKS.crouch),
    perk: keyframe(time, TRACKS.perk),
    push: keyframe(time, TRACKS.push),
  };
}

// Bake the source's spring response at a fixed step so seeking, replay, and
// background-tab resumes all produce the same antenna pose.
const SPRING_HZ = 240;
const antennaSpring = new Float32Array(Math.ceil(CELEBRATION_SECONDS * SPRING_HZ) + 1);
let springPosition = 0;
let springVelocity = 0;
let previousY = sampleCelebration(0).rootY;
for (let frame = 1; frame < antennaSpring.length; frame++) {
  const rootY = sampleCelebration(frame / SPRING_HZ).rootY;
  const verticalVelocity = (rootY - previousY) * SPRING_HZ;
  previousY = rootY;
  const target = -verticalVelocity * 0.55 * 0.31;
  springVelocity += (target - springPosition) * 118 / SPRING_HZ;
  springVelocity -= springVelocity * 10.6 / SPRING_HZ;
  springPosition += springVelocity / SPRING_HZ;
  antennaSpring[frame] = springPosition;
}

export function sampleAntennaSpring(time: number) {
  const frame = Math.max(0, Math.min(time * SPRING_HZ, antennaSpring.length - 1));
  const before = Math.floor(frame);
  const after = Math.min(before + 1, antennaSpring.length - 1);
  return antennaSpring[before] + (antennaSpring[after] - antennaSpring[before]) * (frame - before);
}
