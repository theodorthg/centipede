#!/usr/bin/env python3
"""Synthesize placeholder SFX for every key in sound_manager.gd's SOUNDS map.

Pure stdlib (wave/struct/math/random) — no audio libraries needed. These are
NOT final audio, just distinguishable retro-arcade bleeps/noises so the game
has audible feedback until the user supplies real clips (see sound_manager.gd's
own doc comment and the learn-path CLAUDE.md's "Sounds kommen meist später").
Re-run after tweaking a definition below:

    python3 assets/sounds/gen_placeholder_sfx.py

Output: assets/sounds/<key>.wav (mono, 44100 Hz, 16-bit PCM).
"""
import math
import os
import random
import struct
import wave

RATE = 44100
HERE = os.path.dirname(os.path.abspath(__file__))


def _fade(samples, fade_in_s=0.004, fade_out_s=0.015):
    n = len(samples)
    fin = max(1, int(fade_in_s * RATE))
    fout = max(1, int(fade_out_s * RATE))
    for i in range(min(fin, n)):
        samples[i] *= i / fin
    for i in range(min(fout, n)):
        samples[n - 1 - i] *= i / fout
    return samples


def sine_sweep(f0, f1, dur, amp=0.5):
    n = int(dur * RATE)
    out = []
    phase = 0.0
    for i in range(n):
        t = i / n if n > 1 else 0.0
        freq = f0 + (f1 - f0) * t
        phase += 2 * math.pi * freq / RATE
        out.append(amp * math.sin(phase))
    return _fade(out)


def square_sweep(f0, f1, dur, amp=0.3):
    n = int(dur * RATE)
    out = []
    phase = 0.0
    for i in range(n):
        t = i / n if n > 1 else 0.0
        freq = f0 + (f1 - f0) * t
        phase += 2 * math.pi * freq / RATE
        out.append(amp * (1.0 if math.sin(phase) >= 0 else -1.0))
    return _fade(out)


def noise_burst(dur, amp=0.4, decay=3.0):
    n = int(dur * RATE)
    out = []
    for i in range(n):
        env = math.exp(-decay * i / n)
        out.append(amp * env * random.uniform(-1.0, 1.0))
    return _fade(out, fade_out_s=0.005)


def tone(freq, dur, amp=0.4, wave_fn=math.sin, decay=0.0):
    n = int(dur * RATE)
    out = []
    for i in range(n):
        env = math.exp(-decay * i / n) if decay > 0 else 1.0
        out.append(amp * env * wave_fn(2 * math.pi * freq * i / RATE))
    return _fade(out)


def concat(*parts):
    out = []
    for p in parts:
        out.extend(p)
    return out


def mix(*parts):
    n = max(len(p) for p in parts)
    out = [0.0] * n
    for p in parts:
        for i, v in enumerate(p):
            out[i] += v
    peak = max(1.0, max(abs(v) for v in out))
    return [v / peak * 0.9 for v in out] if peak > 1.0 else out


def silence(dur):
    return [0.0] * int(dur * RATE)


def write_wav(name, samples):
    path = os.path.join(HERE, f"{name}.wav")
    with wave.open(path, "w") as f:
        f.setnchannels(1)
        f.setsampwidth(2)
        f.setframerate(RATE)
        frames = b"".join(
            struct.pack("<h", max(-32767, min(32767, int(s * 32767))))
            for s in samples
        )
        f.writeframes(frames)
    print(f"  {name}.wav  ({len(samples) / RATE:.2f}s)")


SEMITONE = 2.0 ** (1.0 / 12.0)


def note(n, base=261.63):  # n=0 -> middle C
    return base * (SEMITONE ** n)


def build():
    random.seed(1)
    sounds = {}

    sounds["shoot"] = sine_sweep(1200, 400, 0.09, amp=0.35)

    sounds["mushroom-hit"] = tone(220, 0.05, amp=0.3, wave_fn=math.sin, decay=6.0)

    sounds["mushroom-break"] = mix(
        noise_burst(0.14, amp=0.35, decay=4.0),
        tone(110, 0.12, amp=0.25, decay=5.0),
    )

    sounds["segment-kill"] = square_sweep(900, 260, 0.13, amp=0.22)

    sounds["spider-kill"] = concat(
        square_sweep(800, 200, 0.09, amp=0.22),
        silence(0.02),
        square_sweep(600, 150, 0.11, amp=0.22),
    )

    sounds["flea-kill"] = sine_sweep(320, 950, 0.09, amp=0.3)

    sounds["scorpion-kill"] = mix(
        noise_burst(0.32, amp=0.4, decay=2.2),
        sine_sweep(160, 40, 0.3, amp=0.3),
    )

    sounds["player-death"] = mix(
        sine_sweep(500, 60, 0.55, amp=0.3),
        noise_burst(0.4, amp=0.2, decay=2.0),
    )

    # C5 E5 G5 C6 — cheerful rising arpeggio
    sounds["extra-life"] = concat(*[
        tone(note(n, base=523.25), 0.09, amp=0.3, decay=1.5) for n in [0, 4, 7, 12]
    ])

    # short rising stinger — G4 C5 E5
    sounds["get-ready"] = concat(*[
        tone(note(n, base=392.0), 0.15, amp=0.32, decay=1.0) for n in [0, 5, 9]
    ])

    # proper little fanfare — C5 E5 G5 C6 held G5, square+sine blend for "brass" feel
    fanfare_notes = [0, 4, 7, 12]
    fanfare = concat(*[
        mix(
            tone(note(n, base=523.25), 0.12, amp=0.22, decay=0.5),
            square_sweep(note(n, base=523.25), note(n, base=523.25), 0.12, amp=0.12),
        ) for n in fanfare_notes
    ])
    fanfare = concat(fanfare, tone(note(7, base=523.25), 0.35, amp=0.28, decay=1.2))
    sounds["wave-cleared"] = fanfare

    sounds["game-over"] = concat(*[
        tone(note(n, base=392.0), 0.28, amp=0.28, decay=1.0) for n in [0, -2, -4]
    ])

    # soft ambient pad loop — restarted by sound_manager.gd's own loop logic,
    # a small seam at the restart point is fine for a placeholder
    pad = mix(
        tone(note(0, base=196.0), 3.2, amp=0.10, decay=0.05),
        tone(note(7, base=196.0), 3.2, amp=0.07, decay=0.05),
        tone(note(12, base=196.0), 3.2, amp=0.05, decay=0.05),
    )
    sounds["menu-music"] = pad

    return sounds


if __name__ == "__main__":
    for key, samples in build().items():
        write_wav(key, samples)
