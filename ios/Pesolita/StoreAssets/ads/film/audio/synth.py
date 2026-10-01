"""Tiny pure-Python synth shared by make_sfx.py and make_score.py (no numpy needed).

Everything here is original synthesis, so the ad's sound has nothing to license.
Buffers are lists of floats at 44.1 kHz, mono unless a function says otherwise.
"""
import math
import random
import struct
import wave

SR = 44100


def silence(seconds):
    return [0.0] * int(SR * seconds)


def add(dst, src, at=0.0, gain=1.0):
    """Mixes src into dst starting at `at` seconds, growing dst if needed."""
    start = int(SR * at)
    if start + len(src) > len(dst):
        dst.extend([0.0] * (start + len(src) - len(dst)))
    for i, v in enumerate(src):
        dst[start + i] += v * gain
    return dst


def env(n, attack, decay, sustain=0.0, release=None):
    """Attack (s), exponential decay rate (1/s) down to sustain; optional linear release (s)."""
    a = max(1, int(SR * attack))
    out = []
    for i in range(n):
        if i < a:
            out.append(i / a)
        else:
            t = (i - a) / SR
            out.append(sustain + (1 - sustain) * math.exp(-decay * t))
    if release:
        r = min(n, int(SR * release))
        for i in range(r):
            out[n - r + i] *= 1 - i / r
    return out


def sine_sweep(f0, f1, seconds, curve=2.0):
    """Sine whose pitch glides from f0 to f1 (exponential-ish when curve > 1)."""
    n, phase, out = int(SR * seconds), 0.0, []
    for i in range(n):
        x = (i / n) ** curve
        f = f0 + (f1 - f0) * x
        phase += 2 * math.pi * f / SR
        out.append(math.sin(phase))
    return out


def saw(freq, seconds, detune=0.0):
    n, out, ph = int(SR * seconds), [], random.random()
    f = freq * (1 + detune)
    for _ in range(n):
        ph = (ph + f / SR) % 1.0
        out.append(2 * ph - 1)
    return out


def noise(seconds, seed=None):
    rng = random.Random(seed)
    return [rng.uniform(-1, 1) for _ in range(int(SR * seconds))]


def lowpass(x, cutoff):
    """One-pole low-pass; `cutoff` may be a number or a function of sample index."""
    out, y = [], 0.0
    for i, v in enumerate(x):
        c = cutoff(i) if callable(cutoff) else cutoff
        a = 1 - math.exp(-2 * math.pi * c / SR)
        y += a * (v - y)
        out.append(y)
    return out


def highpass(x, cutoff):
    low = lowpass(x, cutoff)
    return [a - b for a, b in zip(x, low)]


def bandpass(x, lo, hi):
    return lowpass(highpass(x, lo), hi)


def mul(x, e):
    return [a * b for a, b in zip(x, e)]


def drive(x, amount):
    """Soft saturation (tanh), keeping peak level roughly constant."""
    k = math.tanh(amount)
    return [math.tanh(v * amount) / k for v in x]


def normalize(x, peak=0.89):
    m = max((abs(v) for v in x), default=0) or 1
    return [v * peak / m for v in x]


def reverb(x, mix=0.25, decay=1.6):
    """Cheap Schroeder-style room: four feedback combs plus an all-pass."""
    out = list(x) + [0.0] * int(SR * decay)
    wet = [0.0] * len(out)
    for d_ms, g in ((29.7, 0.77), (37.1, 0.74), (41.1, 0.72), (43.7, 0.70)):
        d = int(SR * d_ms / 1000)
        buf = [0.0] * len(out)
        for i in range(len(out)):
            src = out[i] if i < len(x) else 0.0
            buf[i] = src + (g * buf[i - d] if i >= d else 0.0)
            wet[i] += buf[i] * 0.25
    return [a * (1 - mix) + b * mix for a, b in zip(out, wet)]


def write(path, left, right=None, peak=0.89):
    right = right if right is not None else left
    n = max(len(left), len(right))
    left = left + [0.0] * (n - len(left))
    right = right + [0.0] * (n - len(right))
    m = max(max((abs(v) for v in left), default=0), max((abs(v) for v in right), default=0)) or 1
    g = peak / m
    with wave.open(str(path), "w") as w:
        w.setnchannels(2)
        w.setsampwidth(2)
        w.setframerate(SR)
        frames = bytearray()
        for a, b in zip(left, right):
            frames += struct.pack("<hh", int(max(-1, min(1, a * g)) * 32767), int(max(-1, min(1, b * g)) * 32767))
        w.writeframes(bytes(frames))
