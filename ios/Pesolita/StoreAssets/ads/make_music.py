"""An original 19-second music bed for the Pesolita ad: 120 BPM, bright and light.

Synthesised here from scratch — kick, clap, hats, bass, pad and a pluck hook over
C–G–Am–F — so there is nothing to license. Pure Python; writes music.wav.
"""
import math
import random
import struct
import wave

SR = 44100
BPM = 120
BEAT = 60 / BPM
LENGTH = 19.0
N = int(SR * LENGTH)
random.seed(7)

mix = [0.0] * N
pump = [1.0] * N  # sidechain: pad and bass duck under each kick


def add(start, samples, gain):
    i0 = int(start * SR)
    for i, v in enumerate(samples):
        j = i0 + i
        if j >= N:
            break
        mix[j] += v * gain


def note_hz(midi):
    return 440 * 2 ** ((midi - 69) / 12)


def kick():
    out, phase = [], 0.0
    for i in range(int(0.32 * SR)):
        t = i / SR
        f = 48 + 90 * math.exp(-t * 28)
        phase += 2 * math.pi * f / SR
        out.append(math.sin(phase) * math.exp(-t * 9))
    return out


def clap():
    out, prev = [], 0.0
    for i in range(int(0.22 * SR)):
        t = i / SR
        n = random.uniform(-1, 1)
        hp = n - prev  # crude high-pass keeps it snappy
        prev = n
        env = math.exp(-t * 22) + 0.6 * math.exp(-max(0, t - 0.012) * 30) * (t > 0.012)
        out.append(hp * env * 0.5)
    return out


def hat(open_=False):
    out, prev = [], 0.0
    d = 0.12 if open_ else 0.035
    for i in range(int(d * SR)):
        t = i / SR
        n = random.uniform(-1, 1)
        out.append((n - prev) * math.exp(-t / d * 4))
        prev = n
    return out


def tone(freq, dur, harmonics, attack=0.005, decay=6.0, sustain=0.0):
    out = []
    for i in range(int(dur * SR)):
        t = i / SR
        env = min(1, t / attack) * (sustain + (1 - sustain) * math.exp(-t * decay))
        v = sum(a * math.sin(2 * math.pi * freq * k * t) for k, a in harmonics)
        out.append(v * env)
    # short release so notes never click
    rel = int(0.02 * SR)
    for k in range(min(rel, len(out))):
        out[-1 - k] *= k / rel
    return out


# C – G – Am – F, one bar (four beats) each.
CHORDS = [
    (48, [60, 64, 67, 72]),   # C
    (43, [59, 62, 67, 71]),   # G
    (45, [60, 64, 69, 72]),   # Am
    (41, [60, 65, 69, 72]),   # F
]
BAR = 4 * BEAT
bars = int(math.ceil(LENGTH / BAR))
DRUMS_END = 18.0

k, c, h, ho = kick(), clap(), hat(), hat(True)
for b in range(bars):
    t0 = b * BAR
    root, chord = CHORDS[b % 4]
    for beat in range(4):
        tb = t0 + beat * BEAT
        if tb >= DRUMS_END:
            continue
        add(tb, k, 0.9)
        for j in range(int(0.22 * SR)):
            idx = int(tb * SR) + j
            if idx < N:
                pump[idx] = min(pump[idx], 0.35 + 0.65 * (j / (0.22 * SR)))
        if beat in (1, 3):
            add(tb, c, 0.55)
        add(tb + BEAT / 2, ho if beat == 3 else h, 0.18)
        add(tb + BEAT / 4, h, 0.07)
        add(tb + 3 * BEAT / 4, h, 0.07)

    # Bass: root on eighths, octave jump on the last one.
    if t0 < DRUMS_END:
        for e in range(8):
            midi = root + (12 if e == 7 else 0)
            add(t0 + e * BEAT / 2, tone(note_hz(midi), BEAT / 2 * 0.9, [(1, 1), (2, 0.35), (3, 0.12)], decay=5), 0.30)

    # Pad: the chord, softly, all bar long.
    for m in chord:
        add(t0, tone(note_hz(m), BAR, [(1, 1), (2, 0.18)], attack=0.08, decay=0.6, sustain=0.55), 0.045)

# Pluck hook, a small rising figure that answers every two bars.
HOOK = [(0.0, 76), (0.5, 79), (1.0, 81), (1.5, 79), (2.5, 76), (3.0, 74), (3.5, 72)]
for b in range(0, bars, 2):
    t0 = b * BAR
    if t0 >= DRUMS_END:
        break
    for off, m in HOOK:
        add(t0 + off * BEAT, tone(note_hz(m), 0.35, [(1, 1), (2, 0.45), (3, 0.2), (4, 0.1)], decay=11), 0.16)

# Ending: one held C chord ringing out under the end card.
for m in [48, 60, 64, 67, 72, 76]:
    add(DRUMS_END, tone(note_hz(m), LENGTH - DRUMS_END, [(1, 1), (2, 0.25)], attack=0.01, decay=2.2), 0.09)
add(DRUMS_END, k, 0.8)

# Apply the pump to everything but the drums would be ideal; applying to all is close enough
# and keeps the groove breathing.
for i in range(N):
    mix[i] *= 0.55 + 0.45 * pump[i]

peak = max(abs(v) for v in mix) or 1
fade = int(0.35 * SR)
with wave.open("music.wav", "w") as w:
    w.setnchannels(2)
    w.setsampwidth(2)
    w.setframerate(SR)
    frames = bytearray()
    for i, v in enumerate(mix):
        v = v / peak * 0.89
        if i > N - fade:
            v *= (N - i) / fade
        s = int(max(-1, min(1, v)) * 32767)
        frames += struct.pack("<hh", s, s)
    w.writeframes(bytes(frames))
print("music.wav", LENGTH, "s")
