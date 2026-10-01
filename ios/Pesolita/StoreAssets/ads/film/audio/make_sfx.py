"""Synthesises the film's sound effects into ../public/sfx/ (original, nothing to license).

  python3 audio/make_sfx.py
"""
import math
import random
from pathlib import Path

from synth import (SR, add, bandpass, drive, env, highpass, lowpass, mul, noise, reverb, saw,
                   silence, sine_sweep, write)

OUT = Path(__file__).resolve().parent.parent / "public" / "sfx"
OUT.mkdir(parents=True, exist_ok=True)


def heartbeat():
    """Lub-dub: two low thumps, the second softer."""
    out = silence(1.0)
    for at, gain in ((0.0, 1.0), (0.22, 0.7)):
        thump = mul(sine_sweep(70, 38, 0.28, 1.0), env(int(SR * 0.28), 0.004, 14))
        add(out, lowpass(thump, 180), at, gain)
    return out


def braam():
    """The trailer horn: stacked detuned saws on A1/A2/E3, filtered open then closed, driven."""
    dur = 2.8
    n = int(SR * dur)
    mix = silence(dur)
    for f, g in ((55, 1.0), (110, 0.7), (164.8, 0.45)):
        for d in (-0.006, 0.0, 0.007):
            add(mix, saw(f, dur, d), 0, g / 3)
    cutoff = lambda i: 180 + 1400 * math.exp(-((i / SR) - 0.15) ** 2 / 0.08) if i / SR > 0 else 180
    body = lowpass(lowpass(mix, cutoff), 2400)
    body = drive(body, 2.2)
    return reverb(mul(body, env(n, 0.06, 1.1, 0.0, 0.4)), 0.3, 1.5)


def impact():
    """Hit: a noise crack over a falling sub sine."""
    sub = mul(sine_sweep(95, 34, 1.4, 0.6), env(int(SR * 1.4), 0.002, 3.2))
    crack = mul(lowpass(noise(0.5, 3), 2600), env(int(SR * 0.5), 0.001, 22))
    out = silence(1.6)
    add(out, sub, 0, 1.0)
    add(out, crack, 0, 0.6)
    return reverb(drive(out, 1.6), 0.25, 1.2)


def subdrop():
    return mul(sine_sweep(140, 28, 1.3, 0.7), env(int(SR * 1.3), 0.01, 1.8))


def whoosh(seconds=0.7, seed=1):
    """Band-limited noise that swells, with its brightness sweeping up then down."""
    n = int(SR * seconds)
    x = noise(seconds, seed)
    bright = lowpass(x, lambda i: 300 + 5200 * math.sin(math.pi * i / n) ** 2)
    shaped = mul(highpass(bright, 180), [math.sin(math.pi * i / n) ** 1.6 for i in range(n)])
    # Pan left to right across the whoosh.
    left = [v * (1 - i / n * 0.8) for i, v in enumerate(shaped)]
    right = [v * (0.2 + i / n * 0.8) for i, v in enumerate(shaped)]
    return left, right


def riser(seconds=2.0):
    n = int(SR * seconds)
    tone = sine_sweep(180, 1400, seconds, 2.2)
    hiss = lowpass(noise(seconds, 5), lambda i: 400 + 7000 * (i / n) ** 2)
    out = [0.5 * a + 0.35 * b for a, b in zip(tone, hiss)]
    return mul(out, [(i / n) ** 2.2 for i in range(n)])


def tick():
    """A clock tick / keypad tap: a very short filtered click."""
    return mul(bandpass(noise(0.05, 7), 1800, 6000), env(int(SR * 0.05), 0.0005, 160))


def pop():
    return mul(sine_sweep(1100, 520, 0.09, 1.0), env(int(SR * 0.09), 0.001, 45))


def snap():
    """Wallet snapping shut: leather slap plus a low knock."""
    slap = mul(bandpass(noise(0.12, 9), 500, 4200), env(int(SR * 0.12), 0.0008, 60))
    knock = mul(sine_sweep(160, 90, 0.15, 1.0), env(int(SR * 0.15), 0.001, 35))
    out = silence(0.3)
    add(out, slap, 0, 1.0)
    add(out, knock, 0.004, 0.8)
    return out


def bell(freq, seconds, strength=1.0):
    """A bright metallic bell: inharmonic partials with separate decays."""
    n = int(SR * seconds)
    out = [0.0] * n
    for ratio, amp, decay in ((1.0, 1.0, 3.0), (2.01, 0.5, 4.5), (2.76, 0.35, 6.0), (5.4, 0.2, 9.0)):
        f = freq * ratio
        for i in range(n):
            t = i / SR
            out[i] += amp * math.sin(2 * math.pi * f * t) * math.exp(-decay * t)
    return [v * strength for v in out]


def kaching():
    """Pesolita's sonic logo: drawer 'ka' (click + coin rattle), then a two-note bright 'ching'."""
    out = silence(1.8)
    add(out, mul(bandpass(noise(0.06, 11), 800, 5000), env(int(SR * 0.06), 0.0005, 70)), 0.0, 0.9)
    rng = random.Random(4)
    for k in range(9):  # coin jingle
        f = rng.uniform(3800, 6200)
        add(out, bell(f, 0.12, 0.25), 0.02 + k * 0.018 + rng.uniform(0, 0.01), 1.0)
    add(out, bell(1318.5, 1.6), 0.12, 0.8)   # E6
    add(out, bell(1975.5, 1.5), 0.26, 0.7)   # B6
    return reverb(out, 0.22, 1.2)


def thunder():
    n = int(SR * 3.5)
    rumble = lowpass(lowpass(noise(3.5, 13), 160), 120)
    rng = random.Random(2)
    gust = [0.0] * n
    level = 0.0
    for i in range(n):
        if i % 2205 == 0:
            level = rng.uniform(0.3, 1.0)
        gust[i] = level
    gust = lowpass(gust, 3)
    return mul(mul(rumble, gust), env(n, 0.05, 0.6))


def clock_tick_tock(seconds=4.0, bpm=90):
    out = silence(seconds)
    beat = 60 / bpm
    t, k = 0.0, 0
    while t < seconds:
        add(out, tick(), t, 1.0 if k % 2 == 0 else 0.6)
        t += beat
        k += 1
    return out


if __name__ == "__main__":
    for name, fn in (("heartbeat", heartbeat), ("braam", braam), ("impact", impact), ("subdrop", subdrop),
                     ("riser", riser), ("tick", tick), ("pop", pop), ("snap", snap), ("kaching", kaching),
                     ("thunder", thunder), ("clock", clock_tick_tock)):
        write(OUT / f"{name}.wav", fn())
        print(name)
    l, r = whoosh()
    write(OUT / "whoosh.wav", l, r)
    l, r = whoosh(0.45, 2)
    write(OUT / "whoosh-short.wav", l, r)
    print("whoosh")
