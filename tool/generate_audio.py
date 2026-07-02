#!/usr/bin/env python3
"""Procedurally generate the game's calming audio assets.

The background track is a soft, gently looping music-box / kalimba melody over a
warm mid-register pad — pleasant and easy to get used to, with NO heavy bass
(nothing below ~C3) so it never feels oppressive. Two short muted chimes cover
tile select/match. Everything is synthesised from sine partials; no third-party
audio is used. Re-run to regenerate:

    python3 tool/generate_audio.py
"""
import math
import os
import struct
import wave

SR = 44100
OUT_DIR = os.path.join(os.path.dirname(__file__), "..", "assets", "audio")

# Equal-temperament note table (A4 = 440 Hz).
_A4 = 440.0
_NAMES = ["C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B"]


def note(name, octave):
    idx = _NAMES.index(name)
    midi = (octave + 1) * 12 + idx
    return _A4 * (2 ** ((midi - 69) / 12))


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


def _add_pluck(buf, start, freq, dur=0.9, gain=0.5, tau=0.35):
    """A soft music-box style note: sine + a couple of gentle harmonics with a
    quick attack and smooth exponential decay."""
    n0 = int(start * SR)
    n = int(dur * SR)
    w = 2 * math.pi * freq
    for i in range(n):
        idx = n0 + i
        if idx < 0 or idx >= len(buf):
            continue
        t = i / SR
        env = math.exp(-t / tau)
        if t < 0.008:  # 8ms attack to avoid clicks
            env *= t / 0.008
        val = math.sin(w * t)
        val += 0.35 * math.sin(2 * w * t)
        val += 0.12 * math.sin(3 * w * t)
        buf[idx] += gain * env * val


def seamless_freq(freq, dur):
    cycles = max(1, round(freq * dur))
    return cycles / dur


def make_music(dur=16.0):
    n = int(SR * dur)
    buf = [0.0] * n

    # Calm, cheerful progression: C - G - Am - F (I-V-vi-IV), 4s per chord.
    progression = [
        [note("C", 4), note("E", 4), note("G", 4), note("C", 5)],
        [note("G", 3), note("B", 3), note("D", 4), note("G", 4)],
        [note("A", 3), note("C", 4), note("E", 4), note("A", 4)],
        [note("F", 3), note("A", 3), note("C", 4), note("F", 4)],
    ]
    bar = dur / len(progression)

    # Arpeggio pattern (indices into the 4-note chord), eighth notes.
    pattern = [0, 1, 2, 3, 2, 1, 0, 2]
    step = bar / len(pattern)

    for b, chord in enumerate(progression):
        base = b * bar
        # Sparkling arpeggio, one octave up for a music-box feel.
        for k, pi in enumerate(pattern):
            _add_pluck(
                buf,
                base + k * step,
                chord[pi] * 2.0,
                dur=step * 2.2,
                gain=0.42,
                tau=0.30,
            )
        # Warm sustained pad from the chord (mid register, no deep bass).
        for f in chord:
            fa = seamless_freq(f, dur)
            w = 2 * math.pi * fa
            lw = 2 * math.pi * seamless_freq(0.25, dur)
            for i in range(n):
                t = i / SR
                # Fade the pad in/out within its own bar so bars blend softly.
                lt = (t - base)
                if 0 <= lt < bar:
                    barenv = math.sin(math.pi * lt / bar)  # 0..1..0
                else:
                    barenv = 0.0
                trem = 0.9 + 0.1 * math.sin(lw * t)
                buf[i] += 0.05 * barenv * trem * math.sin(w * t)

    peak = max(abs(x) for x in buf) or 1.0
    g = 0.6 / peak
    out = [x * g for x in buf]
    # Tiny 12ms fades at the very edges as a safety net for the loop seam.
    fade = int(0.012 * SR)
    for i in range(fade):
        f = i / fade
        out[i] *= f
        out[n - 1 - i] *= f
    return out


def make_chime(freqs, dur=0.5, tau=0.18, gain=0.22):
    n = int(SR * dur)
    out = [0.0] * n
    for f in freqs:
        w = 2 * math.pi * f
        for i in range(n):
            t = i / SR
            env = math.exp(-t / tau)
            if t < 0.006:
                env *= t / 0.006
            out[i] += math.sin(w * t) * env
            out[i] += 0.2 * math.sin(2 * w * t) * env
    peak = max(abs(x) for x in out) or 1.0
    g = gain / peak
    return [x * g for x in out]


def main():
    os.makedirs(OUT_DIR, exist_ok=True)
    write_wav(os.path.join(OUT_DIR, "ambient.wav"), make_music())
    # Soft, pleasant "match" bell (C6 + E6), gentle.
    write_wav(
        os.path.join(OUT_DIR, "match.wav"),
        make_chime([note("C", 6), note("E", 6)], dur=0.5, tau=0.16, gain=0.24),
    )
    # Very short, quiet "select" tick (G5).
    write_wav(
        os.path.join(OUT_DIR, "select.wav"),
        make_chime([note("G", 5)], dur=0.11, tau=0.035, gain=0.13),
    )


if __name__ == "__main__":
    main()
