"""The film's original score, synthesised to ../public/music/score.wav (nothing to license).

  python3 audio/make_score.py

It follows the hero cut (see src/timeline.ts): tension until the "SAAN NAPUNTA?!" dropout,
a hopeful groove when the app appears, a major resolve on day 30, a big chord under the title,
then a light comic sting. Impacts, whooshes and the ka-ching live in public/sfx and are placed
on exact frames in Remotion, so this bed stays musical rather than busy.
"""
import math
import sys
from pathlib import Path

from synth import SR, add, env, lowpass, mul, noise, reverb, saw, silence, sine_sweep, write

OUT = Path(__file__).resolve().parent.parent / "public" / "music"
OUT.mkdir(parents=True, exist_ok=True)

LENGTH = 33.0
BPM = 90
BEAT = 60 / BPM
# Section boundaries (seconds): must match src/timeline.ts.
DROP, APP, DAY30, TITLE, STING = 11.7, 13.5, 22.0, 25.0, 30.0
PULSE, NAME = 4.5, "score.wav"
if len(sys.argv) > 1 and sys.argv[1] == "cut15":
    # The 15 s cut: tension to the app reveal at 6.5 s, groove, title at 11.5 s, no day-30 or sting.
    LENGTH, DROP, APP, DAY30, TITLE, STING = 16.0, 6.3, 6.5, 11.5, 11.5, 16.0
    PULSE, NAME = 2.0, "score-cut15.wav"


def hz(midi):
    return 440 * 2 ** ((midi - 69) / 12)


def pad(notes, seconds, bright=900, level=1.0):
    """Soft detuned-saw chord, filtered."""
    buf = silence(seconds)
    for m in notes:
        for d in (-0.004, 0.004):
            add(buf, saw(hz(m), seconds, d), 0, 0.18 * level)
    return mul(lowpass(lowpass(buf, bright), bright * 1.6), env(len(buf), 0.4, 0.15, 0.7, 0.5))


def pluck(midi, seconds=0.5, level=1.0, bright=2600):
    tone = saw(hz(midi), seconds)
    shaped = mul(lowpass(tone, lambda i: 400 + bright * math.exp(-i / SR * 9)), env(len(tone), 0.002, 7))
    return [v * level for v in shaped]


def kick():
    return mul(sine_sweep(120, 42, 0.35, 0.5), env(int(SR * 0.35), 0.002, 9))


def shaker():
    return mul(lowpass(noise(0.08), 9000), env(int(SR * 0.08), 0.001, 55))


def main():
    mix = silence(LENGTH)

    # A. Tension (0 to DROP): low drone, A-minor pad swelling, pulsing low A in eighths from 4.5 s.
    drone = mul(lowpass(saw(hz(33), DROP + 0.5), 140), env(int(SR * (DROP + 0.5)), 1.5, 0.05, 0.9, 0.4))
    add(mix, drone, 0, 0.9)
    add(mix, pad([57, 60, 64], DROP, 700, 0.8), 0, 1.0)            # A3 C4 E4
    t = PULSE
    while t < DROP - 0.1:
        progress = (t - PULSE) / (DROP - PULSE)
        add(mix, pluck(45, 0.3, 0.55 + 0.4 * progress, 900 + 1800 * progress), t)
        t += BEAT / 2
    # Clock ticks in the cold open (the countdown feeling).
    t = 0.0
    while t < PULSE:
        tick = mul(lowpass(noise(0.03), 5000), env(int(SR * 0.03), 0.0005, 150))
        add(mix, tick, t, 0.25)
        t += BEAT

    # B. Dropout (DROP to APP): nothing but a held low note fading, so the SFX riser owns it.
    add(mix, mul(lowpass(saw(hz(33), APP - DROP), 90), env(int(SR * (APP - DROP)), 0.01, 1.8)), DROP, 0.5)

    # C. Discovery groove (APP to DAY30): Am F C G, two beats each, arpeggios, kick and shaker.
    chords = [[57, 60, 64], [53, 57, 60], [48, 52, 55], [55, 59, 62]]
    t, k = APP, 0
    while t < DAY30 - 0.05:
        chord = chords[k % 4]
        add(mix, pad([n + 12 for n in chord], 2 * BEAT, 1500, 0.55), t)
        for j, n in enumerate([chord[0] + 12, chord[1] + 12, chord[2] + 12, chord[1] + 24]):
            add(mix, pluck(n, 0.35, 0.55, 3200), t + j * BEAT / 2)
        add(mix, kick(), t, 0.8)
        add(mix, kick(), t + BEAT, 0.6)
        for s in range(4):
            add(mix, shaker(), t + s * BEAT / 2 + BEAT / 4, 0.18)
        t += 2 * BEAT
        k += 1

    # D. Day 30 resolve (DAY30 to TITLE): bright C major to F major, sparkle.
    if TITLE - DAY30 > 0.5:
        add(mix, pad([60, 64, 67, 72], TITLE - DAY30, 2600, 0.8), DAY30)
        for j, n in enumerate([72, 76, 79, 84, 79, 76, 72, 79]):
            add(mix, pluck(n, 0.4, 0.35, 4200), DAY30 + j * BEAT / 2)
        add(mix, kick(), DAY30, 0.7)

    # E. Title (TITLE to STING): one big C-major chord hit, then let it ring under the ka-ching.
    add(mix, pad([36, 48, 55, 60, 64, 67, 72], STING - TITLE, 3000, 1.3), TITLE)
    add(mix, kick(), TITLE, 1.0)

    # F. Sting (STING to end): a cheeky three-note pluck, then the snap SFX lands in Remotion.
    for j, n in enumerate([72, 71, 67]):
        add(mix, pluck(n, 0.35, 0.5, 3000), STING + 0.3 + j * 0.22)

    # Gentle room on everything, fade the tail.
    mix = reverb(mix, 0.18, 1.4)[: int(SR * LENGTH)]
    fade = int(SR * 0.8)
    for i in range(fade):
        mix[-fade + i] *= 1 - i / fade
    write(OUT / NAME, mix, peak=0.7)
    print(NAME, LENGTH, "s")


if __name__ == "__main__":
    main()
