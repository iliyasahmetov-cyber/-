#!/usr/bin/env python3
"""Procedurally generate the game's calming audio assets.

Everything is synthesised from sine partials so the sound is soft and
non-irritating (a slow, gently evolving pad plus two short muted chimes).
No external/royalty audio is used. Re-run to regenerate the WAV files:

    python3 tool/generate_audio.py
"""
import math
import os
import struct
import wave

SR = 44100
OUT_DIR = os.path.join(os.path.dirname(__file__), "..", "assets", "audio")


def write_wav(path, samples):
    frames = bytearray()
    for s in samples:
        s = max(-1.0, min(1.0, s))
        frames += struct.pack("<h", int(s * 32767))
    with wave.open(path, "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(bytes(frames))
    print(f"wrote {path} ({len(samples)/SR:.1f}s)")


def seamless_freq(freq, dur):
    """Snap a frequency so it completes a whole number of cycles over dur,
    guaranteeing a click-free loop point."""
    cycles = max(1, round(freq * dur))
    return cycles / dur


def make_ambient(dur=16.0):
    n = int(SR * dur)
    # A calm, open chord (A add9-ish), low in the mix.
    partials = [
        (110.00, 0.18),  # A2
        (164.81, 0.14),  # E3
        (220.00, 0.16),  # A3
        (277.18, 0.10),  # C#4
        (329.63, 0.08),  # E4
    ]
    partials = [(seamless_freq(f, dur), a) for f, a in partials]
    # Slow amplitude movement (integer LFO cycles => seamless).
    lfo = [seamless_freq(0.05 * (i + 1), dur) for i in range(len(partials))]

    out = [0.0] * n
    for idx, (f, amp) in enumerate(partials):
        w = 2 * math.pi * f
        lw = 2 * math.pi * lfo[idx]
        ph = idx * 0.7
        for i in range(n):
            t = i / SR
            trem = 0.82 + 0.18 * math.sin(lw * t + ph)
            out[i] += amp * trem * math.sin(w * t)
    peak = max(abs(x) for x in out) or 1.0
    # Keep it gentle (~-14 dBFS).
    g = 0.2 / peak
    return [x * g for x in out]


def make_chime(freqs, dur=0.5, tau=0.18, gain=0.28):
    n = int(SR * dur)
    out = [0.0] * n
    for f in freqs:
        w = 2 * math.pi * f
        for i in range(n):
            t = i / SR
            env = math.exp(-t / tau)
            # 5ms fade-in to avoid a click.
            if t < 0.005:
                env *= t / 0.005
            out[i] += math.sin(w * t) * env
            out[i] += 0.25 * math.sin(2 * w * t) * env
    peak = max(abs(x) for x in out) or 1.0
    g = gain / peak
    return [x * g for x in out]


def main():
    os.makedirs(OUT_DIR, exist_ok=True)
    write_wav(os.path.join(OUT_DIR, "ambient.wav"), make_ambient())
    # Soft two-note "match" bell (A5 + E6).
    write_wav(
        os.path.join(OUT_DIR, "match.wav"),
        make_chime([880.0, 1318.51], dur=0.55, tau=0.20, gain=0.30),
    )
    # Very short, quiet "select" tick (D5).
    write_wav(
        os.path.join(OUT_DIR, "select.wav"),
        make_chime([587.33], dur=0.12, tau=0.04, gain=0.16),
    )


if __name__ == "__main__":
    main()
