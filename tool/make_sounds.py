"""Synthesises every sound in the game into assets/audio/.

Nothing here is sampled: each effect and both music loops are built from
oscillators and noise, so the files are original work of this project and
can be rebuilt byte for byte. Run from the repository root:

    python tool/make_sounds.py

Needs Python 3 and numpy. Output is 16-bit mono WAV at 22.05 kHz, which every
platform audioplayers supports (Windows cannot decode Ogg).

The sounds borrow the idea of the stock animation sounds every slide editor
once shipped with -- a click per bullet, a whoosh, a drum roll, applause --
without borrowing any recording.
"""

from __future__ import annotations

import pathlib
import wave

import numpy as np

RATE = 22050
OUT = pathlib.Path(__file__).resolve().parent.parent / "assets" / "audio"
rng = np.random.default_rng(20260927)


# --- Building blocks ---------------------------------------------------------


def t_axis(seconds: float) -> np.ndarray:
    return np.arange(int(seconds * RATE)) / RATE


def sweep(f0: float, f1: float, seconds: float, curve: float = 1.0) -> np.ndarray:
    """Phase of a sine gliding from f0 to f1, shaped by curve (1 = linear)."""
    t = t_axis(seconds)
    x = (t / seconds) ** curve
    freq = f0 + (f1 - f0) * x
    return 2 * np.pi * np.cumsum(freq) / RATE


def env(seconds: float, attack: float, decay: float) -> np.ndarray:
    """Linear attack into an exponential decay (decay = time to -60 dB)."""
    t = t_axis(seconds)
    rise = np.clip(t / max(attack, 1e-4), 0, 1)
    fall = np.exp(-6.9 * np.clip(t - attack, 0, None) / max(decay, 1e-4))
    return rise * fall


def noise(seconds: float) -> np.ndarray:
    return rng.uniform(-1, 1, int(seconds * RATE))


def lowpass(x: np.ndarray, cutoff) -> np.ndarray:
    """One-pole lowpass; cutoff may be a number or a per-sample array."""
    cutoff = np.broadcast_to(np.asarray(cutoff, dtype=float), x.shape)
    a = 1 - np.exp(-2 * np.pi * cutoff / RATE)
    y = np.empty_like(x)
    acc = 0.0
    for i, (s, k) in enumerate(zip(x, a)):
        acc += k * (s - acc)
        y[i] = acc
    return y


def highpass(x: np.ndarray, cutoff: float) -> np.ndarray:
    return x - lowpass(x, cutoff)


def pluck(freq: float, seconds: float, bright: float = 3.0) -> np.ndarray:
    """A marimba-ish FM pluck: the corporate template's favourite instrument."""
    t = t_axis(seconds)
    mod = np.sin(2 * np.pi * freq * 4 * t) * bright * np.exp(-t * 18)
    return np.sin(2 * np.pi * freq * t + mod) * env(seconds, 0.003, seconds)


def mix(length: float, *parts: tuple[float, np.ndarray]) -> np.ndarray:
    """Places each (start seconds, samples) into a buffer of length seconds."""
    out = np.zeros(int(length * RATE))
    for start, samples in parts:
        i = int(start * RATE)
        n = min(len(samples), len(out) - i)
        if n > 0:
            out[i : i + n] += samples[:n]
    return out


def write(name: str, x: np.ndarray, peak: float = 0.89) -> float:
    x = x / max(np.max(np.abs(x)), 1e-9) * peak
    # A few milliseconds of fade at each end, so nothing clicks.
    fade = min(int(0.004 * RATE), len(x) // 2)
    x[:fade] *= np.linspace(0, 1, fade)
    x[-fade:] *= np.linspace(1, 0, fade)
    OUT.mkdir(parents=True, exist_ok=True)
    with wave.open(str(OUT / name), "wb") as f:
        f.setnchannels(1)
        f.setsampwidth(2)
        f.setframerate(RATE)
        f.writeframes((x * 32767).astype("<i2").tobytes())
    seconds = len(x) / RATE
    print(f"{name:28} {seconds:5.2f} s")
    return seconds


# --- Effects -----------------------------------------------------------------


def click() -> np.ndarray:
    """A bullet point leaving: a dry typewriter-style tick."""
    d = 0.05
    body = np.sin(sweep(2400, 900, d, 0.5)) * env(d, 0.001, 0.025)
    snap = highpass(noise(d), 2500) * env(d, 0.0005, 0.012)
    return body * 0.6 + snap


def player_hit() -> np.ndarray:
    """The presenter shrinking a size: a quick downward boing."""
    d = 0.22
    return np.sin(sweep(620, 240, d, 0.6)) * env(d, 0.002, 0.2) + 0.25 * np.sin(
        2 * sweep(620, 240, d, 0.6)
    ) * env(d, 0.002, 0.08)


def player_lost() -> np.ndarray:
    """Deflating: a slide whistle all the way down, wobbling as it goes."""
    d = 1.1
    t = t_axis(d)
    wobble = 1 + 0.03 * np.sin(2 * np.pi * 7 * t)
    phase = sweep(900, 110, d, 0.7) * wobble
    tone = np.sin(phase) + 0.3 * np.sin(2 * phase)
    air = lowpass(noise(d), 1800) * 0.25
    return (tone + air) * env(d, 0.01, 1.1)


def shrink_to_fit_hit() -> np.ndarray:
    """A point size lost: a short falling pip."""
    d = 0.1
    return np.sin(sweep(1300, 700, d)) * env(d, 0.001, 0.08)


def shrink_to_fit_defeated() -> np.ndarray:
    """Shrinking to nothing: pips racing upward until they vanish."""
    d = 0.7
    parts = []
    for i in range(8):
        f = 500 * 1.19**i
        parts.append((i * 0.07, np.sin(sweep(f, f * 1.1, 0.12)) * env(0.12, 0.001, 0.1) * (1 - i / 10)))
    return mix(d, *parts)


def diagram_hit() -> np.ndarray:
    """A shape knocked: a woody block."""
    d = 0.12
    t = t_axis(d)
    tone = np.sin(2 * np.pi * 540 * t) + 0.5 * np.sin(2 * np.pi * 1460 * t)
    return tone * env(d, 0.0008, 0.07) + 0.3 * highpass(noise(d), 3000) * env(d, 0.0005, 0.01)


def diagram_break() -> np.ndarray:
    """A shape breaking off the diagram: a crisp pop and a scatter of bits."""
    d = 0.35
    pop = np.sin(sweep(900, 180, 0.08)) * env(0.08, 0.001, 0.07)
    parts = [(0, pop)]
    for i in range(6):
        f = rng.uniform(1800, 3600)
        parts.append((0.03 + i * 0.035, np.sin(2 * np.pi * f * t_axis(0.05)) * env(0.05, 0.001, 0.04) * 0.4))
    return mix(d, *parts)


def diagram_reflow() -> np.ndarray:
    """The survivors re-laying themselves out: a quick card shuffle."""
    d = 0.4
    parts = []
    for i in range(7):
        burst = highpass(noise(0.04), 1500) * env(0.04, 0.002, 0.03)
        parts.append((i * 0.045 + rng.uniform(0, 0.01), burst * (0.6 + 0.4 * rng.random())))
    return mix(d, *parts)


def diagram_defeated() -> np.ndarray:
    """The whole diagram collapsing: blocks tumbling down a scale."""
    d = 1.0
    notes = [784, 659, 587, 523, 440, 392, 330, 262]
    parts = [(i * 0.085, pluck(f, 0.3, 2.0)) for i, f in enumerate(notes)]
    thud = np.sin(sweep(140, 50, 0.3)) * env(0.3, 0.002, 0.28)
    parts.append((len(notes) * 0.085, thud * 1.4))
    return mix(d, *parts)


def whoosh() -> np.ndarray:
    """A fly-in entrance: air swept past."""
    d = 0.42
    t = t_axis(d)
    shape = np.sin(np.pi * t / d) ** 2
    cutoff = 400 + 3200 * shape
    return lowpass(noise(d), cutoff) * shape


def drum_roll() -> np.ndarray:
    """Into the fight: a snare roll swelling into a cymbal crash."""
    roll = 1.3
    d = roll + 0.9
    parts = []
    n = 34
    for i in range(n):
        at = roll * i / n
        level = 0.25 + 0.75 * (i / n) ** 1.5
        hit = (highpass(noise(0.06), 1200) + 0.4 * np.sin(2 * np.pi * 190 * t_axis(0.06))) * env(0.06, 0.001, 0.05)
        parts.append((at, hit * level))
    crash = highpass(noise(0.9), 4000) * env(0.9, 0.002, 0.85)
    kick = np.sin(sweep(160, 45, 0.25)) * env(0.25, 0.001, 0.22)
    parts += [(roll, crash * 1.1), (roll, kick * 1.3)]
    return mix(d, *parts)


def applause() -> np.ndarray:
    """A win: a small, polite, slightly relieved room clapping."""
    d = 2.6
    parts = []
    for _ in range(260):
        at = rng.uniform(0, 2.2) ** 1.15
        clap = lowpass(highpass(noise(0.03), 900), 5000) * env(0.03, 0.001, 0.025)
        parts.append((at, clap * rng.uniform(0.4, 1.0)))
    x = mix(d, *parts)
    return x * env(d, 0.15, 2.4)


def template_hit() -> np.ndarray:
    """A layout knocked: a papery tap."""
    d = 0.12
    tap = lowpass(highpass(noise(d), 700), 4000) * env(d, 0.001, 0.05)
    tone = np.sin(2 * np.pi * 820 * t_axis(d)) * env(d, 0.001, 0.06) * 0.5
    return tap + tone


def template_layout_off() -> np.ndarray:
    """A layout stripped off the master: a quick peel, then a drop."""
    d = 0.45
    t = t_axis(0.25)
    peel = lowpass(noise(0.25), 1200 + 5000 * t / 0.25) * env(0.25, 0.01, 0.24)
    drop = np.sin(sweep(500, 160, 0.2)) * env(0.2, 0.001, 0.18)
    return mix(d, (0, peel * 0.8), (0.2, drop))


def theme_warning() -> np.ndarray:
    """Applying theme…: a progress bar that ticks faster as it fills."""
    d = 1.2
    parts = []
    at = 0.0
    gap = 0.2
    i = 0
    while at < 1.1:
        f = 880 if i % 2 == 0 else 1175
        parts.append((at, np.sin(2 * np.pi * f * t_axis(0.05)) * env(0.05, 0.001, 0.04) * 0.6))
        at += gap
        gap = max(0.06, gap * 0.82)
        i += 1
    return mix(d, *parts)


def theme_applied() -> np.ndarray:
    """The new theme landing: a shimmering chord swept in on a whoosh."""
    d = 0.8
    chord_ = [hz("C", 5), hz("E", 5), hz("G", 5), hz("C", 6)]
    shimmer = sum(pluck(f, d, 1.5) for f in chord_) / 4
    air = lowpass(noise(d), 2500) * env(d, 0.05, 0.4) * 0.5
    return shimmer + air


def template_closed() -> np.ndarray:
    """The template closing for good: three notes down, and a lid shut."""
    d = 1.1
    notes = [hz("G", 4), hz("E", 4), hz("C", 4)]
    parts = [(i * 0.16, pluck(f, 0.4, 2.0)) for i, f in enumerate(notes)]
    thump = np.sin(sweep(120, 45, 0.3)) * env(0.3, 0.002, 0.28)
    parts.append((0.5, thump * 1.5))
    return mix(d, *parts)


def build_tag_hit() -> np.ndarray:
    """A tag knocked: a small glassy tick."""
    d = 0.1
    t = t_axis(d)
    return (np.sin(2 * np.pi * 1760 * t) + 0.4 * np.sin(2 * np.pi * 2640 * t)) * env(d, 0.001, 0.06)


def build_step_deleted() -> np.ndarray:
    """A step deleted: a backspace-like double click and a falling blip."""
    d = 0.4
    tick = highpass(noise(0.03), 2000) * env(0.03, 0.0005, 0.02)
    blip = np.sin(sweep(1400, 500, 0.2)) * env(0.2, 0.002, 0.18)
    return mix(d, (0, tick), (0.06, tick * 0.7), (0.12, blip))


def build_reorder() -> np.ndarray:
    """The queue reordering itself: a quick run of shuffled notes."""
    d = 0.6
    notes = [hz(n, 5) for n in ["E", "C", "G", "D", "A", "F"]]
    return mix(d, *[(i * 0.07, pluck(f, 0.2, 2.5) * 0.7) for i, f in enumerate(notes)])


def build_step_started() -> np.ndarray:
    """A step starting: a short upward sparkle."""
    d = 0.3
    return np.sin(sweep(700, 1600, d, 0.5)) * env(d, 0.004, 0.25) * 0.8


def build_emptied() -> np.ndarray:
    """The queue emptied: a last flourish, rising to a held chord."""
    d = 1.2
    run = [hz(n, 5) for n in ["C", "D", "E", "G"]]
    parts = [(i * 0.08, pluck(f, 0.25, 2.0)) for i, f in enumerate(run)]
    held = sum(pluck(f, 0.8, 1.2) for f in chord("C", "maj", 5)) / 4
    parts.append((0.36, held * 1.2))
    return mix(d, *parts)


# --- Music -------------------------------------------------------------------

NOTE = {n: i for i, n in enumerate("C C# D D# E F F# G G# A A# B".split())}


def hz(name: str, octave: int) -> float:
    return 440.0 * 2 ** ((NOTE[name] - 9) / 12 + (octave - 4))


def chord(root: str, quality: str, octave: int) -> list[float]:
    steps = {"maj": [0, 4, 7, 12], "min": [0, 3, 7, 12], "sus": [0, 5, 7, 12]}[quality]
    base = NOTE[root]
    return [440.0 * 2 ** ((base + s - 9) / 12 + (octave - 4)) for s in steps]


def kick() -> np.ndarray:
    return np.sin(sweep(150, 48, 0.22)) * env(0.22, 0.001, 0.2)


def hat(length: float = 0.04) -> np.ndarray:
    return highpass(noise(length), 6000) * env(length, 0.0005, length * 0.8)


def clap() -> np.ndarray:
    return lowpass(highpass(noise(0.12), 900), 4500) * env(0.12, 0.001, 0.1)


def loop(parts: list[tuple[float, np.ndarray]], length: float) -> np.ndarray:
    """Mixes parts into exactly length seconds, wrapping tails to the start so
    the loop joins without a gap or a click."""
    tail = 2.0
    x = mix(length + tail, *parts)
    body = x[: int(length * RATE)].copy()
    wrap = x[int(length * RATE) :]
    body[: len(wrap)] += wrap
    return body


def write_loop(name: str, x: np.ndarray, peak: float = 0.7) -> None:
    """Loops are written without end fades: the wrap already makes them seamless."""
    x = x / max(np.max(np.abs(x)), 1e-9) * peak
    with wave.open(str(OUT / name), "wb") as f:
        f.setnchannels(1)
        f.setsampwidth(2)
        f.setframerate(RATE)
        f.writeframes((x * 32767).astype("<i2").tobytes())
    print(f"{name:28} {len(x) / RATE:5.2f} s (loop)")


def menu_loop() -> np.ndarray:
    """The template's hold music: I-vi-IV-V in C, marimba arpeggios, a bass
    that is a bit too pleased with itself, and polite claps on 2 and 4."""
    bpm = 108
    beat = 60 / bpm
    progression = [("C", "maj"), ("A", "min"), ("F", "maj"), ("G", "maj")] * 2
    bars = len(progression)
    parts = []
    for bar, (root, quality) in enumerate(progression):
        start = bar * 4 * beat
        notes = chord(root, quality, 4)
        pattern = [0, 1, 2, 3, 2, 1, 2, 3]
        for i, n in enumerate(pattern):
            parts.append((start + i * beat / 2, pluck(notes[n], beat * 0.9) * 0.45))
        bass = hz(root, 2)
        for b, (off, mult) in enumerate([(0, 1), (1.5, 1), (2, 1.5), (3, 2)]):
            t = t_axis(beat * 0.45)
            tone = np.sin(2 * np.pi * bass * mult * t) + 0.3 * np.sin(4 * np.pi * bass * mult * t)
            parts.append((start + off * beat, tone * env(beat * 0.45, 0.004, beat * 0.4) * 0.55))
        for b in range(4):
            parts.append((start + b * beat, kick() * (0.5 if b % 2 == 0 else 0.0)))
            if b % 2 == 1:
                parts.append((start + b * beat, clap() * 0.25))
            parts.append((start + b * beat + beat / 2, hat() * 0.18))
        # A chime at the top of every other bar, for that stock-photo sparkle.
        if bar % 2 == 0:
            parts.append((start, pluck(notes[-1] * 2, beat * 2, 1.2) * 0.2))
    return loop(parts, bars * 4 * beat)


def fight_loop() -> np.ndarray:
    """The same template at a deadline: faster, busier, still in a major key."""
    bpm = 138
    beat = 60 / bpm
    progression = [("D", "maj"), ("A", "maj"), ("B", "min"), ("G", "maj")] * 2
    bars = len(progression)
    parts = []
    for bar, (root, quality) in enumerate(progression):
        start = bar * 4 * beat
        notes = chord(root, quality, 4)
        # Square-ish stabs on the offbeats.
        for i in range(8):
            if i % 2 == 1:
                t = t_axis(beat * 0.3)
                stab = sum(np.sign(np.sin(2 * np.pi * f * t)) for f in notes[:3]) / 3
                stab = lowpass(stab, 2200) * env(beat * 0.3, 0.002, beat * 0.25)
                parts.append((start + i * beat / 2, stab * 0.3))
        # A running arpeggio in sixteenths.
        for i in range(16):
            f = notes[[0, 1, 2, 3, 2, 1, 2, 3][i % 8]] * (2 if i >= 8 else 1)
            parts.append((start + i * beat / 4, pluck(f, beat * 0.4, 2.5) * 0.25))
        bass = hz(root, 2)
        for i in range(8):
            t = t_axis(beat * 0.4)
            saw = 2 * ((bass * t) % 1) - 1
            tone = lowpass(saw, 700) * env(beat * 0.4, 0.003, beat * 0.35)
            parts.append((start + i * beat / 2, tone * 0.55))
        for b in range(4):
            parts.append((start + b * beat, kick() * 0.8))
            if b % 2 == 1:
                parts.append((start + b * beat, clap() * 0.4))
            for s in range(4):
                parts.append((start + b * beat + s * beat / 4, hat(0.03) * (0.2 if s % 2 else 0.1)))
    return loop(parts, bars * 4 * beat)


def main() -> None:
    effects = {
        "click.wav": click,
        "player_hit.wav": player_hit,
        "player_lost.wav": player_lost,
        "shrink_to_fit_hit.wav": shrink_to_fit_hit,
        "shrink_to_fit_defeated.wav": shrink_to_fit_defeated,
        "diagram_hit.wav": diagram_hit,
        "diagram_break.wav": diagram_break,
        "diagram_reflow.wav": diagram_reflow,
        "diagram_defeated.wav": diagram_defeated,
        "whoosh.wav": whoosh,
        "drum_roll.wav": drum_roll,
        "applause.wav": applause,
    }
    for name, build in effects.items():
        write(name, build())
    write_loop("menu_loop.wav", menu_loop())
    write_loop("fight_loop.wav", fight_loop())

    # Added with later bosses. Kept after everything above, because every
    # sound draws from one seeded random sequence: appending leaves the older
    # files byte for byte the same.
    later = {
        "template_hit.wav": template_hit,
        "template_layout_off.wav": template_layout_off,
        "theme_warning.wav": theme_warning,
        "theme_applied.wav": theme_applied,
        "template_closed.wav": template_closed,
        "build_tag_hit.wav": build_tag_hit,
        "build_step_deleted.wav": build_step_deleted,
        "build_reorder.wav": build_reorder,
        "build_step_started.wav": build_step_started,
        "build_emptied.wav": build_emptied,
    }
    for name, build in later.items():
        write(name, build())


if __name__ == "__main__":
    main()
