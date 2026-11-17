#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Generates:
1. Studio-grade 44.1kHz WAV audio assets for Solfa:
   - Rich acoustic-style piano notes (C3..C6)
   - Melodic & harmonic intervals
   - Key cadences (I - IV - V - I)
   - Metronome clicks (Click, Woodblock, Bell)
   - Upgraded SFX:
     * correct.wav: Joyful 4-note crystal chime arpeggio (C5 - E5 - G5 - C6 shimmer)
     * wrong.wav: Soft, warm muted wooden double-note
     * complete.wav: Celebratory session completion fanfare
2. High-resolution Solfa Logo PNG (assets/images/solfa_logo.png) and Android mipmap ic_launcher.png icons.
3. Seed JSON database content (assets/data/seed_content.json).
"""

import json
import math
import os
import struct
import wave
import zlib

SAMPLE_RATE = 44100  # 44.1 kHz CD-quality audio

BASE_DIR = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
ASSETS_DIR = os.path.join(BASE_DIR, "assets")
ANDROID_RES_DIR = os.path.join(BASE_DIR, "android", "app", "src", "main", "res")

NOTE_OFFSETS = {
    "c": 0,
    "csharp": 1,
    "d": 2,
    "dsharp": 3,
    "e": 4,
    "f": 5,
    "fsharp": 6,
    "g": 7,
    "gsharp": 8,
    "a": 9,
    "asharp": 10,
    "b": 11,
}


def midi_to_freq(midi_note: int) -> float:
    return 440.0 * (2.0 ** ((midi_note - 69) / 12.0))


def note_name_to_midi(name: str, octave: int) -> int:
    return (octave + 1) * 12 + NOTE_OFFSETS[name.lower()]


def synthesize_piano_note(freq: float, duration: float, volume: float = 0.78) -> list[float]:
    """Synthesizes a warm grand-piano tone with subtle inharmonicity and hammer attack."""
    num_samples = int(SAMPLE_RATE * duration)
    samples = [0.0] * num_samples
    attack = min(0.009, duration * 0.06)
    release_start = max(attack, duration - 0.09)

    harmonics = [
        (1.0, 1.00, 1.5),
        (2.0005, 0.48, 2.5),
        (3.0015, 0.24, 3.5),
        (4.0030, 0.12, 4.8),
        (5.0050, 0.06, 6.2),
        (6.0080, 0.03, 8.0),
    ]

    for i in range(num_samples):
        t = i / SAMPLE_RATE
        if t < attack:
            env = 0.5 * (1.0 - math.cos(math.pi * t / attack))
        elif t > release_start:
            env = max(0.0, 1.0 - (t - release_start) / (duration - release_start))
        else:
            env = 1.0

        val = 0.0
        for mult, amp, decay in harmonics:
            f_h = freq * mult
            if f_h < SAMPLE_RATE * 0.45:
                val += amp * math.exp(-decay * t) * math.sin(2.0 * math.pi * f_h * t)

        # Subtle warm hammer transient in first 12 ms
        if t < 0.012:
            transient = math.exp(-220.0 * t) * math.sin(2.0 * math.pi * (freq * 7.5) * t) * 0.08
            val += transient

        samples[i] = val * env * volume

    peak = max((abs(s) for s in samples), default=1.0)
    if peak > 0.92:
        scale = 0.90 / peak
        samples = [s * scale for s in samples]
    return samples


def mix_samples(tracks: list[list[float]], max_peak: float = 0.88) -> list[float]:
    if not tracks:
        return []
    length = max(len(t) for t in tracks)
    out = [0.0] * length
    for t in tracks:
        for i, s in enumerate(t):
            out[i] += s
    peak = max((abs(s) for s in out), default=1.0)
    if peak > 0:
        scale = min(1.0, max_peak / peak)
        out = [s * scale for s in out]
    return out


def mix_at_offsets(events: list[tuple[float, list[float]]], max_peak: float = 0.90) -> list[float]:
    """Mixes multiple sample arrays at specific start times (in seconds) for overlapping chimes."""
    if not events:
        return []
    total_len = 0
    for start_sec, samples in events:
        end_idx = int(start_sec * SAMPLE_RATE) + len(samples)
        if end_idx > total_len:
            total_len = end_idx

    out = [0.0] * total_len
    for start_sec, samples in events:
        offset = int(start_sec * SAMPLE_RATE)
        for i, s in enumerate(samples):
            out[offset + i] += s

    peak = max((abs(s) for s in out), default=1.0)
    if peak > 0:
        scale = min(1.0, max_peak / peak)
        out = [s * scale for s in out]
    return out


def concat_samples(segments: list[list[float]], gap_sec: float = 0.08) -> list[float]:
    gap = [0.0] * int(SAMPLE_RATE * gap_sec)
    out: list[float] = []
    for idx, seg in enumerate(segments):
        if idx > 0 and gap_sec > 0:
            out.extend(gap)
        out.extend(seg)
    return out


def write_wav(filepath: str, samples: list[float]) -> None:
    os.makedirs(os.path.dirname(filepath), exist_ok=True)
    with wave.open(filepath, "w") as wf:
        wf.setnchannels(1)
        wf.setsampwidth(2)
        wf.setframerate(SAMPLE_RATE)
        frames = bytearray()
        for s in samples:
            clamped = max(-0.98, min(0.98, s))
            frames.extend(struct.pack("<h", int(clamped * 32767)))
        wf.writeframes(frames)


def generate_notes() -> None:
    notes_dir = os.path.join(ASSETS_DIR, "audio", "notes")
    for octave in [2, 3, 4, 5]:
        for name in NOTE_OFFSETS:
            midi = note_name_to_midi(name, octave)
            freq = midi_to_freq(midi)
            samples = synthesize_piano_note(freq, duration=1.10)
            write_wav(os.path.join(notes_dir, f"{name}{octave}.wav"), samples)
    c6_samples = synthesize_piano_note(midi_to_freq(note_name_to_midi("c", 6)), duration=1.10)
    write_wav(os.path.join(notes_dir, "c6.wav"), c6_samples)

    comparisons = [
        ("cmp_c4_g4", 60, 67),
        ("cmp_g4_d4", 67, 62),
        ("cmp_e4_f4", 64, 65),
        ("cmp_a4_g4", 69, 67),
        ("cmp_d4_d4", 62, 62),
        ("cmp_f4_e4", 65, 64),
    ]
    for fname, m1, m2 in comparisons:
        s1 = synthesize_piano_note(midi_to_freq(m1), 0.72)
        s2 = synthesize_piano_note(midi_to_freq(m2), 0.88)
        write_wav(os.path.join(notes_dir, f"{fname}.wav"), concat_samples([s1, s2], gap_sec=0.16))


def generate_intervals() -> None:
    intervals_dir = os.path.join(ASSETS_DIR, "audio", "intervals")
    if os.path.exists(intervals_dir):
        for old_f in os.listdir(intervals_dir):
            if old_f.endswith(".wav"):
                os.remove(os.path.join(intervals_dir, old_f))
    interval_defs = [
        ("min2", 1),
        ("maj2", 2),
        ("min3", 3),
        ("maj3", 4),
        ("p4", 5),
        ("tritone", 6),
        ("p5", 7),
        ("min6", 8),
        ("maj6", 9),
        ("min7", 10),
        ("maj7", 11),
        ("p8", 12),
    ]
    roots = [("c4", 60), ("f4", 65), ("g4", 67)]
    for root_name, root_midi in roots:
        for code, semi in interval_defs:
            f1 = midi_to_freq(root_midi)
            f2 = midi_to_freq(root_midi + semi)
            n1 = synthesize_piano_note(f1, 0.72)
            n2 = synthesize_piano_note(f2, 0.92)
            asc = concat_samples([n1, n2], gap_sec=0.10)
            write_wav(os.path.join(intervals_dir, f"{root_name}_{code}_asc.wav"), asc)
            desc = concat_samples(
                [synthesize_piano_note(f2, 0.72), synthesize_piano_note(f1, 0.92)],
                gap_sec=0.10,
            )
            write_wav(os.path.join(intervals_dir, f"{root_name}_{code}_desc.wav"), desc)
            harm = mix_samples([
                synthesize_piano_note(f1, 1.20),
                synthesize_piano_note(f2, 1.20),
            ])
            write_wav(os.path.join(intervals_dir, f"{root_name}_{code}_harm.wav"), harm)


def make_chord(midi_notes: list[int], duration: float = 0.62) -> list[float]:
    tracks = [synthesize_piano_note(midi_to_freq(m), duration) for m in midi_notes]
    return mix_samples(tracks)


def generate_keys() -> None:
    keys_dir = os.path.join(ASSETS_DIR, "audio", "keys")
    major_keys = {
        "c_major": 60,
        "g_major": 55,
        "f_major": 53,
        "d_major": 62,
        "bb_major": 58,
    }
    for name, root in major_keys.items():
        chord_i = make_chord([root, root + 4, root + 7, root + 12], 0.52)
        chord_iv = make_chord([root + 5, root + 9, root + 12], 0.52)
        chord_v = make_chord([root + 7, root + 11, root + 14], 0.52)
        chord_i_end = make_chord([root, root + 4, root + 7, root + 12], 1.00)
        seq = concat_samples([chord_i, chord_iv, chord_v, chord_i_end], gap_sec=0.05)
        write_wav(os.path.join(keys_dir, f"{name}.wav"), seq)

    minor_keys = {
        "a_minor": 57,
        "e_minor": 52,
        "d_minor": 62,
        "b_minor": 59,
        "g_minor": 55,
    }
    for name, root in minor_keys.items():
        chord_i = make_chord([root, root + 3, root + 7, root + 12], 0.52)
        chord_iv = make_chord([root + 5, root + 8, root + 12], 0.52)
        chord_v = make_chord([root + 7, root + 11, root + 14], 0.52)
        chord_i_end = make_chord([root, root + 3, root + 7, root + 12], 1.00)
        seq = concat_samples([chord_i, chord_iv, chord_v, chord_i_end], gap_sec=0.05)
        write_wav(os.path.join(keys_dir, f"{name}.wav"), seq)

    # 3a. Chords for topic_chords & topic_guitar_chords (Arpeggio + Full harmonic chord)
    chord_defs = {
        "chord_c_maj": [60, 64, 67],
        "chord_a_min": [57, 60, 64],
        "chord_c_min": [60, 63, 67],
        "chord_f_maj": [53, 57, 60],
        "chord_d_min": [62, 65, 69],
        "chord_g_maj": [55, 59, 62],
        "chord_e_min": [52, 59, 64, 67],
        "chord_d_maj": [50, 57, 62, 66],
        "chord_e_maj": [52, 59, 64, 68],
        "chord_c_dim": [60, 63, 66],
        "chord_c_aug": [60, 64, 68],
        "chord_c_sus4": [60, 65, 67],
        "chord_c_maj7": [60, 64, 67, 71],
        "chord_a_min7": [57, 60, 64, 67],
        "chord_g_dom7": [55, 59, 62, 65],
    }
    for cname, midis in chord_defs.items():
        arp_notes = [synthesize_piano_note(midi_to_freq(m), 0.24) for m in midis]
        arp = concat_samples(arp_notes, gap_sec=0.02)
        block = make_chord(midis, 1.05)
        write_wav(os.path.join(keys_dir, f"{cname}.wav"), concat_samples([arp, block], gap_sec=0.08))

    # 3b. Short Melodies for topic_melody (3-note and 4-note motifs)
    melody_defs = {
        "mel_c_d_e": [60, 62, 64],
        "mel_e_d_c": [64, 62, 60],
        "mel_c_e_g": [60, 64, 67],
        "mel_g_e_c": [67, 64, 60],
        "mel_c_f_g": [60, 65, 67],
        "mel_g_a_g": [67, 69, 67],
        "mel_c_d_e_g": [60, 62, 64, 67],
        "mel_g_f_e_d": [67, 65, 64, 62],
        "mel_c_e_g_c5": [60, 64, 67, 72],
        "mel_a3_c4_e4_a4": [57, 60, 64, 69],
        "mel_d_f_a_g": [62, 65, 69, 67],
        "mel_e_g_a_g": [64, 67, 69, 67],
    }
    for mname, midis in melody_defs.items():
        segs = []
        for idx, m in enumerate(midis):
            dur = 0.65 if idx == len(midis) - 1 else 0.36
            segs.append(synthesize_piano_note(midi_to_freq(m), dur))
        write_wav(os.path.join(keys_dir, f"{mname}.wav"), concat_samples(segs, gap_sec=0.04))

    # 3c. Rhythm patterns for topic_rhythm (Percussive woodblock + piano C5/G4 rhythm hits at 100 BPM, beat = 0.6s)
    beat = 0.56
    rhy_accent = mix_samples([
        synthesize_piano_note(midi_to_freq(72), 0.18),
        synthesize_soft_marimba(880.0, 0.10, 0.85),
    ])
    rhy_norm = mix_samples([
        synthesize_piano_note(midi_to_freq(67), 0.15),
        synthesize_soft_marimba(587.33, 0.09, 0.72),
    ])
    rhy_sub = mix_samples([
        synthesize_piano_note(midi_to_freq(64), 0.11),
        synthesize_soft_marimba(440.0, 0.07, 0.58),
    ])
    rhythm_defs = {
        "rhy_quarter_4_4": [
            (0.0 * beat, rhy_accent),
            (1.0 * beat, rhy_norm),
            (2.0 * beat, rhy_norm),
            (3.0 * beat, rhy_norm),
        ],
        "rhy_half_notes": [
            (0.0 * beat, synthesize_piano_note(midi_to_freq(72), 0.95)),
            (2.0 * beat, synthesize_piano_note(midi_to_freq(67), 0.95)),
        ],
        "rhy_eighth_pair": [
            (0.0 * beat, rhy_accent), (0.5 * beat, rhy_sub),
            (1.0 * beat, rhy_norm), (1.5 * beat, rhy_sub),
            (2.0 * beat, rhy_norm), (2.5 * beat, rhy_sub),
            (3.0 * beat, rhy_norm), (3.5 * beat, rhy_sub),
        ],
        "rhy_quarter_eighth": [
            (0.0 * beat, rhy_accent),
            (1.0 * beat, rhy_norm), (1.5 * beat, rhy_sub),
            (2.0 * beat, rhy_norm),
            (3.0 * beat, rhy_norm), (3.5 * beat, rhy_sub),
        ],
        "rhy_triplet": [
            (0.0 * beat, rhy_accent), (0.333 * beat, rhy_sub), (0.666 * beat, rhy_sub),
            (1.0 * beat, rhy_norm), (1.333 * beat, rhy_sub), (1.666 * beat, rhy_sub),
            (2.0 * beat, rhy_norm), (2.333 * beat, rhy_sub), (2.666 * beat, rhy_sub),
            (3.0 * beat, rhy_norm),
        ],
        "rhy_sixteenth": [
            (0.0 * beat, rhy_accent), (0.25 * beat, rhy_sub), (0.50 * beat, rhy_sub), (0.75 * beat, rhy_sub),
            (1.0 * beat, rhy_norm), (1.25 * beat, rhy_sub), (1.50 * beat, rhy_sub), (1.75 * beat, rhy_sub),
            (2.0 * beat, rhy_norm),
            (3.0 * beat, rhy_norm),
        ],
        "rhy_dotted_eighth": [
            (0.0 * beat, rhy_accent), (0.75 * beat, rhy_sub),
            (1.0 * beat, rhy_norm), (1.75 * beat, rhy_sub),
            (2.0 * beat, rhy_norm), (2.75 * beat, rhy_sub),
            (3.0 * beat, rhy_norm),
        ],
        "rhy_syncopated": [
            (0.0 * beat, rhy_accent),
            (0.5 * beat, rhy_accent),
            (1.5 * beat, rhy_norm),
            (2.0 * beat, rhy_accent),
            (2.5 * beat, rhy_accent),
            (3.5 * beat, rhy_norm),
        ],
        "rhy_gallop": [
            (0.0 * beat, rhy_accent), (0.5 * beat, rhy_sub), (0.75 * beat, rhy_sub),
            (1.0 * beat, rhy_norm), (1.5 * beat, rhy_sub), (1.75 * beat, rhy_sub),
            (2.0 * beat, rhy_norm), (2.5 * beat, rhy_sub), (2.75 * beat, rhy_sub),
            (3.0 * beat, rhy_norm),
        ],
        "rhy_waltz_3_4": [
            (0.0 * beat, rhy_accent),
            (1.0 * beat, rhy_norm),
            (2.0 * beat, rhy_norm),
            (3.0 * beat, rhy_accent),
            (4.0 * beat, rhy_norm),
            (5.0 * beat, rhy_norm),
        ],
        "rhy_march_2_4": [
            (0.0 * beat, rhy_accent),
            (1.0 * beat, rhy_norm),
            (2.0 * beat, rhy_accent),
            (3.0 * beat, rhy_norm),
        ],
        "rhy_compound_6_8": [
            (0.0 * beat, rhy_accent), (0.38 * beat, rhy_sub), (0.76 * beat, rhy_sub),
            (1.14 * beat, rhy_norm), (1.52 * beat, rhy_sub), (1.90 * beat, rhy_sub),
        ],
    }
    for rname, events in rhythm_defs.items():
        write_wav(os.path.join(keys_dir, f"{rname}.wav"), mix_at_offsets(events, max_peak=0.92))


def synthesize_chime_bell(freq: float, duration: float, amp: float = 0.8) -> list[float]:
    """Synthesizes a sparkling, warm celesta/glockenspiel chime tone for UI reward feedback."""
    n = int(SAMPLE_RATE * duration)
    out = [0.0] * n
    attack = 0.004
    for i in range(n):
        t = i / SAMPLE_RATE
        env = (t / attack) if t < attack else math.exp(-7.5 * (t - attack))
        # Shimmering celesta overtones + slight detuned chorus warmth
        v = (
            0.70 * math.sin(2.0 * math.pi * freq * t)
            + 0.25 * math.sin(2.0 * math.pi * (freq * 1.0015) * t)
            + 0.28 * math.exp(-12.0 * t) * math.sin(2.0 * math.pi * (freq * 2.0) * t)
            + 0.12 * math.exp(-18.0 * t) * math.sin(2.0 * math.pi * (freq * 3.0) * t)
            + 0.06 * math.exp(-26.0 * t) * math.sin(2.0 * math.pi * (freq * 4.2) * t)
        )
        out[i] = v * env * amp
    return out


def synthesize_soft_marimba(freq: float, duration: float, amp: float = 0.7) -> list[float]:
    """Warm, rounded wooden marimba tone for non-harsh wrong-answer feedback."""
    n = int(SAMPLE_RATE * duration)
    out = [0.0] * n
    attack = 0.006
    for i in range(n):
        t = i / SAMPLE_RATE
        env = (t / attack) if t < attack else math.exp(-13.0 * (t - attack))
        v = (
            0.85 * math.sin(2.0 * math.pi * freq * t)
            + 0.15 * math.exp(-28.0 * t) * math.sin(2.0 * math.pi * (freq * 4.0) * t)
        )
        out[i] = v * env * amp
    return out


def generate_metronome_and_sfx() -> None:
    metro_dir = os.path.join(ASSETS_DIR, "audio", "metronome")
    sfx_dir = os.path.join(ASSETS_DIR, "audio", "sfx")

    def make_mechanical_pendulum_tick(
        cavity_freq: float,
        amp: float,
        is_accent: bool = False,
        wood_depth: float = 1.0,
    ) -> list[float]:
        """
        Synthesizes an authentic mechanical pendulum metronome (Wittner / Taktell):
        1. Sharp brass escapement latch snap (0 - 2.5 ms)
        2. Secondary pallet lock rebound (at ~3.1 ms)
        3. Hollow pyramidal mahogany/wood box cavity resonance (650 - 2800 Hz modes)
           with rapid natural acoustic damping (no electronic sine ring!).
        """
        dur = 0.085
        n = int(SAMPLE_RATE * dur)
        out = [0.0] * n
        for i in range(n):
            t = i / SAMPLE_RATE

            # 1. Brass escapement release transient (0..2.5 ms)
            snap_env = math.exp(-1150.0 * t)
            # Deterministic pseudo-broadband metallic snap + high wood surface click
            noise_like = (
                math.sin(2.0 * math.pi * 2480.0 * t + 0.3)
                + 0.85 * math.sin(2.0 * math.pi * 3720.0 * t + 1.1)
                + 0.65 * math.sin(2.0 * math.pi * 5180.0 * t + 2.4)
                + 0.45 * math.sin(2.0 * math.pi * 6890.0 * t + 0.7)
            ) * 0.38
            snap = noise_like * snap_env

            # 2. Secondary escapement tooth lock at t = 2.8 ms (classic double-impulse "tock")
            rebound = 0.0
            if t >= 0.0028:
                tr = t - 0.0028
                rebound_env = math.exp(-620.0 * tr)
                rebound = (
                    0.55 * math.sin(2.0 * math.pi * (cavity_freq * 2.15) * tr)
                    + 0.45 * math.sin(2.0 * math.pi * 3100.0 * tr)
                ) * rebound_env * 0.48

            # 3. Pyramidal wooden soundbox cavity modes
            attack_w = min(1.0, t / 0.0006)
            wood_env_low = attack_w * math.exp(-125.0 * t)
            wood_env_mid = attack_w * math.exp(-175.0 * t)
            wood_env_hi = attack_w * math.exp(-260.0 * t)

            # Slight pitch drop on initial impact (membrane/wood plate stiffness)
            f_inst = cavity_freq * (1.0 + 0.18 * math.exp(-450.0 * t))

            wood_body = (
                0.68 * wood_depth * math.sin(2.0 * math.pi * f_inst * t) * wood_env_low
                + 0.52 * math.sin(2.0 * math.pi * (f_inst * 1.54) * t) * wood_env_mid
                + 0.36 * math.sin(2.0 * math.pi * (f_inst * 2.28) * t) * wood_env_hi
                + (0.24 if is_accent else 0.14)
                * math.sin(2.0 * math.pi * (f_inst * 3.12) * t)
                * wood_env_hi
            )

            sample = (0.42 * snap + 0.25 * rebound + 0.78 * wood_body) * amp
            out[i] = sample

        # Normalize peak cleanly to target amp
        peak = max((abs(x) for x in out), default=1.0)
        if peak > 1e-6:
            scale = amp / peak
            out = [x * scale for x in out]
        return out

    # 1. Classic Mechanical Metronome (Click cơ học chuẩn: "Tick" phách đầu / "Tock" phách thường)
    mech_accent = make_mechanical_pendulum_tick(830.0, 0.95, is_accent=True, wood_depth=0.95)
    mech_normal = make_mechanical_pendulum_tick(660.0, 0.82, is_accent=False, wood_depth=1.10)
    write_wav(os.path.join(metro_dir, "click_accent.wav"), mech_accent)
    write_wav(os.path.join(metro_dir, "click_normal.wav"), mech_normal)

    # 2. Warm Hardwood Box Metronome (Hộp gỗ cơ học trầm ấm)
    wood_accent = make_mechanical_pendulum_tick(740.0, 0.94, is_accent=True, wood_depth=1.35)
    wood_normal = make_mechanical_pendulum_tick(575.0, 0.82, is_accent=False, wood_depth=1.45)
    write_wav(os.path.join(metro_dir, "woodblock_accent.wav"), wood_accent)
    write_wav(os.path.join(metro_dir, "woodblock_normal.wav"), wood_normal)

    # 3. Mechanical Metronome with Brass Bell (Máy cơ có chuông đồng ở phách 1)
    def make_mechanical_bell_accent() -> list[float]:
        dur = 0.22
        n = int(SAMPLE_RATE * dur)
        tick = make_mechanical_pendulum_tick(790.0, 0.75, is_accent=True, wood_depth=1.0)
        out = [0.0] * n
        for i in range(n):
            t = i / SAMPLE_RATE
            tick_part = tick[i] if i < len(tick) else 0.0
            # Real Wittner brass bell strike (fundamental ~2520 Hz + inharmonic bell partials)
            attack_b = min(1.0, t / 0.0008)
            bell_env = attack_b * math.exp(-16.5 * t)
            shimmer_env = attack_b * math.exp(-32.0 * t)
            bell_part = (
                0.58 * math.sin(2.0 * math.pi * 2520.0 * t) * bell_env
                + 0.28 * math.sin(2.0 * math.pi * 5240.0 * t) * shimmer_env
                + 0.14 * math.sin(2.0 * math.pi * 7610.0 * t) * shimmer_env
            ) * 0.78
            out[i] = tick_part * 0.65 + bell_part
        peak = max((abs(x) for x in out), default=1.0)
        if peak > 1e-6:
            out = [x * (0.95 / peak) for x in out]
        return out

    write_wav(os.path.join(metro_dir, "bell_accent.wav"), make_mechanical_bell_accent())
    write_wav(os.path.join(metro_dir, "bell_normal.wav"), mech_normal)

    # 4. "Metronome: Tempo Lite" Signature Quartz Digital-Acoustic Click (tempo_accent, tempo_normal, tempo_sub)
    def make_tempo_lite_click(
        pitch_hz: float,
        amp: float,
        decay_rate: float = 95.0,
        dur: float = 0.055,
        punch: float = 0.45,
    ) -> list[float]:
        """
        Synthesizes the iconic 'Metronome: Tempo Lite' (by Frozen Ape) crisp studio click:
        - Razor-sharp 1.5 ms percussive transient so every beat cuts clearly through instruments
        - Clean pitched quartz-wood resonant body (A6=1760Hz accent, D6=1174.66Hz normal, A5=880Hz subdivision)
        - Rapid, zero-ring exponential decay.
        """
        n = int(SAMPLE_RATE * dur)
        out = [0.0] * n
        for i in range(n):
            t = i / SAMPLE_RATE
            attack = min(1.0, t / 0.0005)
            # Crisp initial transient (0..1.8ms)
            transient_env = math.exp(-1350.0 * t)
            transient = (
                math.sin(2.0 * math.pi * 3200.0 * t + 0.4)
                + 0.75 * math.sin(2.0 * math.pi * 4950.0 * t + 1.2)
            ) * transient_env * punch

            # Pitched Tempo Lite tone body with slight initial pitch snap
            f_inst = pitch_hz * (1.0 + 0.08 * math.exp(-600.0 * t))
            body_env = attack * math.exp(-decay_rate * t)
            harmonic_env = attack * math.exp(-(decay_rate * 1.65) * t)
            body = (
                0.82 * math.sin(2.0 * math.pi * f_inst * t) * body_env
                + 0.24 * math.sin(2.0 * math.pi * (f_inst * 2.0) * t) * harmonic_env
                + 0.08 * math.sin(2.0 * math.pi * (f_inst * 3.0) * t) * harmonic_env
            )
            out[i] = (transient + body) * amp

        peak = max((abs(x) for x in out), default=1.0)
        if peak > 1e-6:
            scale = amp / peak
            out = [x * scale for x in out]
        return out

    tempo_accent = make_tempo_lite_click(1760.0, 0.96, decay_rate=88.0, punch=0.52)
    tempo_normal = make_tempo_lite_click(1174.66, 0.84, decay_rate=102.0, punch=0.40)
    tempo_sub = make_tempo_lite_click(880.0, 0.56, decay_rate=135.0, punch=0.28)
    write_wav(os.path.join(metro_dir, "tempo_accent.wav"), tempo_accent)
    write_wav(os.path.join(metro_dir, "tempo_normal.wav"), tempo_normal)
    write_wav(os.path.join(metro_dir, "tempo_sub.wav"), tempo_sub)

    # Subdivision ticks for click, woodblock, and bell
    mech_sub = make_mechanical_pendulum_tick(590.0, 0.52, is_accent=False, wood_depth=0.90)
    wood_sub = make_mechanical_pendulum_tick(510.0, 0.52, is_accent=False, wood_depth=1.20)
    write_wav(os.path.join(metro_dir, "click_sub.wav"), mech_sub)
    write_wav(os.path.join(metro_dir, "woodblock_sub.wav"), wood_sub)
    write_wav(os.path.join(metro_dir, "bell_sub.wav"), mech_sub)

    # UPGRADED CORRECT SFX: Sparkling overlapping 4-note celesta chime arpeggio (G5 -> B5 -> D6 -> G6)
    # Distinct from lesson piano notes, bright, rewarding, and instantaneous!
    chime_1 = synthesize_chime_bell(midi_to_freq(72), 0.32, 0.65)  # C5
    chime_2 = synthesize_chime_bell(midi_to_freq(76), 0.34, 0.72)  # E5
    chime_3 = synthesize_chime_bell(midi_to_freq(79), 0.38, 0.78)  # G5
    chime_4 = synthesize_chime_bell(midi_to_freq(84), 0.52, 0.90)  # C6
    chime_harmony = synthesize_chime_bell(midi_to_freq(76), 0.48, 0.38)  # E5 warm sustain
    correct_samples = mix_at_offsets([
        (0.00, chime_1),
        (0.055, chime_2),
        (0.110, chime_3),
        (0.165, chime_4),
        (0.165, chime_harmony),
    ], max_peak=0.92)
    write_wav(os.path.join(sfx_dir, "correct.wav"), correct_samples)

    # UPGRADED WRONG SFX: Soft muted wooden marimba double-thud (A3 -> E3)
    w1 = synthesize_soft_marimba(midi_to_freq(57), 0.18, 0.65)
    w2 = synthesize_soft_marimba(midi_to_freq(52), 0.28, 0.68)
    wrong_samples = mix_at_offsets([
        (0.00, w1),
        (0.11, w2),
    ], max_peak=0.82)
    write_wav(os.path.join(sfx_dir, "wrong.wav"), wrong_samples)

    # NEW SESSION COMPLETE FANFARE: Uplifting Major 9th shimmer arpeggio
    fanfare_events = [
        (0.00, synthesize_chime_bell(midi_to_freq(60), 0.55, 0.55)),  # C4
        (0.07, synthesize_chime_bell(midi_to_freq(64), 0.55, 0.60)),  # E4
        (0.14, synthesize_chime_bell(midi_to_freq(67), 0.55, 0.65)),  # G4
        (0.21, synthesize_chime_bell(midi_to_freq(72), 0.65, 0.75)),  # C5
        (0.28, synthesize_chime_bell(midi_to_freq(76), 0.70, 0.80)),  # E5
        (0.35, synthesize_chime_bell(midi_to_freq(79), 0.85, 0.85)),  # G5
        (0.42, synthesize_chime_bell(midi_to_freq(84), 0.95, 0.92)),  # C6
        (0.42, synthesize_chime_bell(midi_to_freq(76), 0.90, 0.45)),  # E5 chord
        (0.42, synthesize_chime_bell(midi_to_freq(79), 0.90, 0.45)),  # G5 chord
    ]
    write_wav(os.path.join(sfx_dir, "complete.wav"), mix_at_offsets(fanfare_events, max_peak=0.92))


def write_rgba_png(filepath: str, width: int, height: int, rgba_bytes: bytearray) -> None:
    """Writes a standard 32-bit RGBA PNG file using only Python stdlib (zlib + struct)."""
    os.makedirs(os.path.dirname(filepath), exist_ok=True)
    raw_data = bytearray()
    stride = width * 4
    for y in range(height):
        raw_data.append(0)  # Filter type 0 (None)
        row_start = y * stride
        raw_data.extend(rgba_bytes[row_start : row_start + stride])

    def make_chunk(chunk_type: bytes, data: bytes) -> bytes:
        crc = zlib.crc32(chunk_type + data) & 0xFFFFFFFF
        return struct.pack(">I", len(data)) + chunk_type + data + struct.pack(">I", crc)

    ihdr = struct.pack(">IIBBBBB", width, height, 8, 6, 0, 0, 0)
    compressed = zlib.compress(bytes(raw_data), level=9)
    png_bytes = (
        b"\x89PNG\r\n\x1a\n"
        + make_chunk(b"IHDR", ihdr)
        + make_chunk(b"IDAT", compressed)
        + make_chunk(b"IEND", b"")
    )
    with open(filepath, "wb") as f:
        f.write(png_bytes)


def render_solfa_logo_png(size: int) -> bytearray:
    """
    Renders a crisp, anti-aliased Solfa app icon:
    - Rounded squircle background with Minimal Pastel Indigo-Violet gradient (#7E6FF2 -> #4D3EC2)
    - Subtle glowing inner ring (#A9C8F5)
    - Stylized musical eighth-note + soundwave bars in pure white & pastel cyan
    """
    buf = bytearray(size * size * 4)
    cx = (size - 1) / 2.0
    cy = (size - 1) / 2.0
    half = size / 2.0
    corner_r = size * 0.235

    def sd_rounded_box(px: float, py: float, bx: float, by: float, r: float) -> float:
        qx = abs(px - cx) - bx + r
        qy = abs(py - cy) - by + r
        return math.hypot(max(qx, 0.0), max(qy, 0.0)) + min(max(qx, qy), 0.0) - r

    def sd_segment(px: float, py: float, ax: float, ay: float, bx: float, by: float) -> float:
        pax, pay = px - ax, py - ay
        bax, bay = bx - ax, by - ay
        denom = bax * bax + bay * bay
        h = max(0.0, min(1.0, (pax * bax + pay * bay) / denom)) if denom > 0 else 0.0
        return math.hypot(pax - bax * h, pay - bay * h)

    aa = 1.25  # Anti-aliasing feather width in pixels

    for y in range(size):
        ny = y / size
        for x in range(size):
            nx = x / size
            idx = (y * size + x) * 4

            # 1. Squircle mask
            d_box = sd_rounded_box(x, y, half * 0.92, half * 0.92, corner_r)
            if d_box > aa:
                continue
            bg_alpha = max(0.0, min(1.0, 0.5 - d_box / (2.0 * aa)))

            # 2. Gradient background (#8273F7 top-left -> #4E3FC2 bottom-right)
            t_grad = max(0.0, min(1.0, (nx * 0.55 + ny * 0.65)))
            r = int(130 * (1 - t_grad) + 76 * t_grad)
            g = int(115 * (1 - t_grad) + 61 * t_grad)
            b = int(247 * (1 - t_grad) + 196 * t_grad)

            # Soft radial highlight in top-left
            d_glow = math.hypot(nx - 0.28, ny - 0.24)
            if d_glow < 0.55:
                glow_k = ((0.55 - d_glow) / 0.55) ** 2 * 0.25
                r = min(255, int(r + (185 - r) * glow_k))
                g = min(255, int(g + (210 - g) * glow_k))
                b = min(255, int(b + (255 - b) * glow_k))

            # Subtle inner circle ring
            d_ring = abs(math.hypot(nx - 0.5, ny - 0.5) - 0.365) * size
            if d_ring < aa * 1.6:
                rk = max(0.0, 1.0 - d_ring / (aa * 1.6)) * 0.22
                r = int(r * (1 - rk) + 169 * rk)
                g = int(g * (1 - rk) + 200 * rk)
                b = int(b * (1 - rk) + 245 * rk)

            # 3. Foreground Graphic: Musical Note + Soundwave Bars
            # Note head (tilted ellipse at (0.43, 0.64))
            dx_h = nx - 0.42
            dy_h = ny - 0.64
            cos_a, sin_a = math.cos(-0.38), math.sin(-0.38)
            rx = dx_h * cos_a - dy_h * sin_a
            ry = dx_h * sin_a + dy_h * cos_a
            d_head = (math.hypot(rx / 0.105, ry / 0.078) - 1.0) * (size * 0.09)

            # Note stem from (0.495, 0.62) up to (0.495, 0.27)
            d_stem = (
                sd_segment(nx, ny, 0.495, 0.62, 0.495, 0.27) - 0.028
            ) * size

            # Note flag curve from (0.495, 0.27) to (0.64, 0.38) and (0.62, 0.46)
            d_flag1 = (
                sd_segment(nx, ny, 0.495, 0.28, 0.635, 0.365) - 0.028
            ) * size
            d_flag2 = (
                sd_segment(nx, ny, 0.635, 0.365, 0.605, 0.455) - 0.024
            ) * size

            d_note = min(d_head, d_stem, d_flag1, d_flag2)

            # Soundwave bars on left & right (representing ear training & metronome pulse)
            d_bar_l1 = (sd_segment(nx, ny, 0.23, 0.43, 0.23, 0.57) - 0.022) * size
            d_bar_l2 = (sd_segment(nx, ny, 0.31, 0.35, 0.31, 0.50) - 0.022) * size
            d_bar_r1 = (sd_segment(nx, ny, 0.72, 0.39, 0.72, 0.61) - 0.022) * size
            d_bar_r2 = (sd_segment(nx, ny, 0.80, 0.45, 0.80, 0.55) - 0.022) * size
            d_bars = min(d_bar_l1, d_bar_l2, d_bar_r1, d_bar_r2)

            if d_bars < aa:
                bk = max(0.0, min(1.0, 0.5 - d_bars / (2.0 * aa)))
                # Pastel cyan #A9C8F5
                r = int(r * (1 - bk) + 169 * bk)
                g = int(g * (1 - bk) + 205 * bk)
                b = int(b * (1 - bk) + 248 * bk)

            if d_note < aa:
                nk = max(0.0, min(1.0, 0.5 - d_note / (2.0 * aa)))
                r = int(r * (1 - nk) + 255 * nk)
                g = int(g * (1 - nk) + 255 * nk)
                b = int(b * (1 - nk) + 255 * nk)

            buf[idx] = r
            buf[idx + 1] = g
            buf[idx + 2] = b
            buf[idx + 3] = int(bg_alpha * 255)

    return buf


def generate_logos_and_icons() -> None:
    import shutil
    from collections import deque
    from PIL import Image

    images_dir = os.path.join(ASSETS_DIR, "images")
    os.makedirs(images_dir, exist_ok=True)

    uploaded_dir = r"C:\Users\Admin\.gemini\antigravity\brain\3cff7280-e008-4820-bfb9-9f5c06b7ac3d\.user_uploaded"
    src_logo = os.path.join(uploaded_dir, "media_1794470617779_09c4997b.png")
    src_bg_light = os.path.join(uploaded_dir, "media_1794471106754_b041851b.jpg")
    src_bg_dark = os.path.join(uploaded_dir, "media_1794471106755_e438a02f.jpg")

    dst_logo = os.path.join(images_dir, "solfa_logo.png")
    dst_bg_light = os.path.join(images_dir, "bg_light.jpg")
    dst_bg_dark = os.path.join(images_dir, "bg_dark.jpg")

    if os.path.exists(src_bg_light):
        shutil.copyfile(src_bg_light, dst_bg_light)
    if os.path.exists(src_bg_dark):
        dark_img = Image.open(src_bg_dark).convert("RGB")
        # Darken the background significantly into a deep midnight-obsidian tone
        # while preserving subtle neon musical note highlights
        def darken_channel_r(v: int) -> int:
            norm = v / 255.0
            return int(max(0, min(255, ((norm ** 1.55) * 0.44) * 255.0)))

        def darken_channel_g(v: int) -> int:
            norm = v / 255.0
            return int(max(0, min(255, ((norm ** 1.55) * 0.44) * 255.0)))

        def darken_channel_b(v: int) -> int:
            norm = v / 255.0
            return int(max(0, min(255, ((norm ** 1.68) * 0.36) * 255.0)))

        r_ch, g_ch, b_ch = dark_img.split()
        r_ch = r_ch.point(darken_channel_r)
        g_ch = g_ch.point(darken_channel_g)
        b_ch = b_ch.point(darken_channel_b)
        darkened = Image.merge("RGB", (r_ch, g_ch, b_ch))
        darkened.save(dst_bg_dark, "JPEG", quality=94)

    if os.path.exists(src_logo):
        img = Image.open(src_logo).convert("RGBA")
        # Crop to native alpha bounding box and pad evenly into a square 512x512 RGBA image
        bbox = img.getbbox()
        cropped = img.crop(bbox) if bbox else img
        cw, ch = cropped.size
        side = int(max(cw, ch) * 1.04)
        square = Image.new("RGBA", (side, side), (0, 0, 0, 0))
        square.paste(cropped, ((side - cw) // 2, (side - ch) // 2), cropped)
        final_logo = square.resize((512, 512), Image.Resampling.LANCZOS)
        final_logo.save(dst_logo, "PNG")

        # Generate Android mipmap ic_launcher.png icons from the new logo
        mipmap_sizes = {
            "mipmap-mdpi": 48,
            "mipmap-hdpi": 72,
            "mipmap-xhdpi": 96,
            "mipmap-xxhdpi": 144,
            "mipmap-xxxhdpi": 192,
        }
        for folder, px in mipmap_sizes.items():
            target_dir = os.path.join(ANDROID_RES_DIR, folder)
            if os.path.exists(target_dir):
                icon_img = final_logo.resize((px, px), Image.Resampling.LANCZOS)
                icon_img.save(os.path.join(target_dir, "ic_launcher.png"), "PNG")
        print("Processed user Solfa logo, Light/Dark backgrounds, and Android launcher icons.")
    elif not os.path.exists(dst_logo):
        logo_256 = render_solfa_logo_png(256)
        write_rgba_png(dst_logo, 256, 256, logo_256)


def generate_seed_json() -> None:
    topics = [
        {
            "id": "topic_notes",
            "code": "note_recognition",
            "name": "Nhận biết nốt",
            "description": "Nghe cao độ Đô (C) – Si (B) và đối chiếu trực tiếp trên phím đàn Piano.",
            "sort_order": 1,
            "is_enabled": True,
        },
        {
            "id": "topic_staff_reading",
            "code": "staff_reading",
            "name": "Đọc nốt nhạc",
            "description": "Nhìn vị trí nốt trên khuông nhạc 5 dòng kẻ (Khóa Sol 𝄞 & Khóa Fa 𝄢) và chọn đúng tên nốt (không phát tiếng trước).",
            "sort_order": 2,
            "is_enabled": True,
        },
        {
            "id": "topic_intervals",
            "code": "interval_recognition",
            "name": "Nhận biết quãng",
            "description": "Phân biệt khoảng cách cao độ từ quãng 2 đến quãng 8 (giai điệu & hòa thanh).",
            "sort_order": 3,
            "is_enabled": True,
        },
        {
            "id": "topic_keys",
            "code": "key_recognition",
            "name": "Nhận biết giọng",
            "description": "Cảm nhận màu sắc Trưởng – Thứ và nhận diện hóa biểu các giọng cơ bản.",
            "sort_order": 4,
            "is_enabled": True,
        },
        {
            "id": "topic_chords",
            "code": "chord_recognition",
            "name": "Nhận biết hợp âm",
            "description": "Phân biệt hợp âm Trưởng, Thứ, Tăng, Giảm, Sus4 và hợp âm 7 (Maj7, m7, Dom7).",
            "sort_order": 5,
            "is_enabled": True,
        },
        {
            "id": "topic_melody",
            "code": "melody_recognition",
            "name": "Nhận biết giai điệu",
            "description": "Nghe và xác định chuỗi 3–4 nốt giai điệu ngắn đi lên, đi xuống hoặc rải hợp âm.",
            "sort_order": 6,
            "is_enabled": True,
        },
        {
            "id": "topic_rhythm",
            "code": "rhythm_recognition",
            "name": "Nhận biết nhịp điệu",
            "description": "Nhận diện mẫu tiết tấu (Đen, Móc đơn, Liên 3, Đảo phách) và các loại nhịp 2/4, 3/4, 4/4, 6/8.",
            "sort_order": 7,
            "is_enabled": True,
        },
    ]

    levels = [
        {"id": "lvl_notes_basic", "topic_id": "topic_notes", "code": "level_1_c4_natural", "name": "Mức 1: Dễ (C4 Tự nhiên)", "difficulty": 1, "unlock_rule": "always_unlocked"},
        {"id": "lvl_notes_inter", "topic_id": "topic_notes", "code": "level_2_c4_chromatic", "name": "Mức 2: Trung bình (C4 có #/b)", "difficulty": 2, "unlock_rule": "always_unlocked"},
        {"id": "lvl_notes_adv", "topic_id": "topic_notes", "code": "level_3_multi_natural", "name": "Mức 3: Khá (C3–C5 Tự nhiên)", "difficulty": 3, "unlock_rule": "always_unlocked"},
        {"id": "lvl_notes_master", "topic_id": "topic_notes", "code": "level_4_multi_chromatic", "name": "Mức 4: Nâng cao (C3–C5 Đầy đủ #/b)", "difficulty": 4, "unlock_rule": "always_unlocked"},
        {"id": "lvl_staff_basic", "topic_id": "topic_staff_reading", "code": "staff_level_1_treble_natural", "name": "Mức 1: Dễ (Khóa Sol C4–B4)", "difficulty": 1, "unlock_rule": "always_unlocked"},
        {"id": "lvl_staff_inter", "topic_id": "topic_staff_reading", "code": "staff_level_2_treble_chromatic", "name": "Mức 2: Trung bình (Khóa Sol có #/b)", "difficulty": 2, "unlock_rule": "always_unlocked"},
        {"id": "lvl_staff_adv", "topic_id": "topic_staff_reading", "code": "staff_level_3_treble_bass_natural", "name": "Mức 3: Khá (Khóa Sol & Fa C3–C5)", "difficulty": 3, "unlock_rule": "always_unlocked"},
        {"id": "lvl_staff_master", "topic_id": "topic_staff_reading", "code": "staff_level_4_treble_bass_chromatic", "name": "Mức 4: Nâng cao (Khóa Sol & Fa đầy đủ #/b)", "difficulty": 4, "unlock_rule": "always_unlocked"},
        {"id": "lvl_intervals_basic", "topic_id": "topic_intervals", "code": "basic", "name": "Cơ bản", "difficulty": 1, "unlock_rule": "always_unlocked"},
        {"id": "lvl_intervals_inter", "topic_id": "topic_intervals", "code": "intermediate", "name": "Trung bình", "difficulty": 2, "unlock_rule": "always_unlocked"},
        {"id": "lvl_intervals_adv", "topic_id": "topic_intervals", "code": "advanced", "name": "Nâng cao", "difficulty": 3, "unlock_rule": "always_unlocked"},
        {"id": "lvl_keys_basic", "topic_id": "topic_keys", "code": "basic", "name": "Cơ bản", "difficulty": 1, "unlock_rule": "always_unlocked"},
        {"id": "lvl_keys_inter", "topic_id": "topic_keys", "code": "intermediate", "name": "Trung bình", "difficulty": 2, "unlock_rule": "always_unlocked"},
        {"id": "lvl_keys_adv", "topic_id": "topic_keys", "code": "advanced", "name": "Nâng cao", "difficulty": 3, "unlock_rule": "always_unlocked"},
        {"id": "lvl_chords_basic", "topic_id": "topic_chords", "code": "basic", "name": "Cơ bản (Hợp âm Trưởng & Thứ)", "difficulty": 1, "unlock_rule": "always_unlocked"},
        {"id": "lvl_chords_inter", "topic_id": "topic_chords", "code": "intermediate", "name": "Trung bình (Trưởng, Thứ, Tăng, Giảm)", "difficulty": 2, "unlock_rule": "always_unlocked"},
        {"id": "lvl_chords_adv", "topic_id": "topic_chords", "code": "advanced", "name": "Nâng cao (Hợp âm 7 & Sus4)", "difficulty": 3, "unlock_rule": "always_unlocked"},
        {"id": "lvl_melody_basic", "topic_id": "topic_melody", "code": "basic", "name": "Cơ bản (Giai điệu 3 nốt)", "difficulty": 1, "unlock_rule": "always_unlocked"},
        {"id": "lvl_melody_inter", "topic_id": "topic_melody", "code": "intermediate", "name": "Trung bình (Giai điệu 4 nốt liền bậc)", "difficulty": 2, "unlock_rule": "always_unlocked"},
        {"id": "lvl_melody_adv", "topic_id": "topic_melody", "code": "advanced", "name": "Nâng cao (Giai điệu nhảy quãng & Rải hợp âm)", "difficulty": 3, "unlock_rule": "always_unlocked"},
        {"id": "lvl_rhythm_basic", "topic_id": "topic_rhythm", "code": "basic", "name": "Cơ bản (Trắng, Đen, Móc đơn)", "difficulty": 1, "unlock_rule": "always_unlocked"},
        {"id": "lvl_rhythm_inter", "topic_id": "topic_rhythm", "code": "intermediate", "name": "Trung bình (Liên 3, Móc kép, Chấm dôi)", "difficulty": 2, "unlock_rule": "always_unlocked"},
        {"id": "lvl_rhythm_adv", "topic_id": "topic_rhythm", "code": "advanced", "name": "Nâng cao (Đảo phách & Nhịp 2/4, 3/4, 6/8)", "difficulty": 3, "unlock_rule": "always_unlocked"},
    ]

    questions = [
        {
            "id": "q_note_b01",
            "topic_id": "topic_notes",
            "level_id": "lvl_notes_basic",
            "type": "listen_note",
            "prompt": "[Mức 1 • C4 Tự nhiên] Nghe âm thanh và chọn đúng tên nốt (hoặc bấm trực tiếp phím đàn):",
            "explanation": "Đây là nốt Đô (C4) – tần số chuẩn 261.6 Hz, nằm ngay bên trái cụm 2 phím đen.",
            "audio_asset": "assets/audio/notes/c4.wav",
            "difficulty": 1,
            "version": 2,
            "options": [
                {"id": "q_note_b01_o1", "option_key": "C4", "label": "Đô (C4)", "is_correct": True, "sort_order": 1},
                {"id": "q_note_b01_o2", "option_key": "D4", "label": "Rê (D4)", "is_correct": False, "sort_order": 2},
                {"id": "q_note_b01_o3", "option_key": "E4", "label": "Mi (E4)", "is_correct": False, "sort_order": 3},
                {"id": "q_note_b01_o4", "option_key": "G4", "label": "Sol (G4)", "is_correct": False, "sort_order": 4},
            ],
        },
        {
            "id": "q_note_b02",
            "topic_id": "topic_notes",
            "level_id": "lvl_notes_basic",
            "type": "listen_note",
            "prompt": "[Mức 1 • C4 Tự nhiên] Nghe âm thanh và chọn đúng tên nốt (hoặc bấm trực tiếp phím đàn):",
            "explanation": "Nốt Rê (D4) cao hơn nốt Đô (C4) đúng 1 cung nguyên, nằm giữa 2 phím đen C# và D#.",
            "audio_asset": "assets/audio/notes/d4.wav",
            "difficulty": 1,
            "version": 2,
            "options": [
                {"id": "q_note_b02_o1", "option_key": "C4", "label": "Đô (C4)", "is_correct": False, "sort_order": 1},
                {"id": "q_note_b02_o2", "option_key": "D4", "label": "Rê (D4)", "is_correct": True, "sort_order": 2},
                {"id": "q_note_b02_o3", "option_key": "F4", "label": "Fa (F4)", "is_correct": False, "sort_order": 3},
                {"id": "q_note_b02_o4", "option_key": "A4", "label": "La (A4)", "is_correct": False, "sort_order": 4},
            ],
        },
        {
            "id": "q_note_b03",
            "topic_id": "topic_notes",
            "level_id": "lvl_notes_basic",
            "type": "listen_note",
            "prompt": "[Mức 1 • C4 Tự nhiên] Nghe âm thanh và chọn đúng tên nốt (hoặc bấm trực tiếp phím đàn):",
            "explanation": "Nốt Mi (E4) là bậc III của âm giai Đô Trưởng, nằm ngay bên phải cụm 2 phím đen.",
            "audio_asset": "assets/audio/notes/e4.wav",
            "difficulty": 1,
            "version": 2,
            "options": [
                {"id": "q_note_b03_o1", "option_key": "D4", "label": "Rê (D4)", "is_correct": False, "sort_order": 1},
                {"id": "q_note_b03_o2", "option_key": "E4", "label": "Mi (E4)", "is_correct": True, "sort_order": 2},
                {"id": "q_note_b03_o3", "option_key": "G4", "label": "Sol (G4)", "is_correct": False, "sort_order": 3},
                {"id": "q_note_b03_o4", "option_key": "B4", "label": "Si (B4)", "is_correct": False, "sort_order": 4},
            ],
        },
        {
            "id": "q_note_b04",
            "topic_id": "topic_notes",
            "level_id": "lvl_notes_basic",
            "type": "listen_note",
            "prompt": "[Mức 1 • C4 Tự nhiên] Nghe âm thanh và chọn đúng tên nốt (hoặc bấm trực tiếp phím đàn):",
            "explanation": "Nốt Sol (G4) cách nốt Đô (C4) một quãng 5 đúng (bậc V trong giọng Đô Trưởng).",
            "audio_asset": "assets/audio/notes/g4.wav",
            "difficulty": 1,
            "version": 2,
            "options": [
                {"id": "q_note_b04_o1", "option_key": "E4", "label": "Mi (E4)", "is_correct": False, "sort_order": 1},
                {"id": "q_note_b04_o2", "option_key": "F4", "label": "Fa (F4)", "is_correct": False, "sort_order": 2},
                {"id": "q_note_b04_o3", "option_key": "G4", "label": "Sol (G4)", "is_correct": True, "sort_order": 3},
                {"id": "q_note_b04_o4", "option_key": "A4", "label": "La (A4)", "is_correct": False, "sort_order": 4},
            ],
        },
        {
            "id": "q_note_b05",
            "topic_id": "topic_notes",
            "level_id": "lvl_notes_basic",
            "type": "listen_note",
            "prompt": "[Mức 1 • C4 Tự nhiên] Nghe âm thanh và chọn đúng tên nốt (hoặc bấm trực tiếp phím đàn):",
            "explanation": "Phím trắng đầu tiên bên trái cụm 3 phím đen là nốt Fa (F4), cao hơn Mi (E4) nửa cung.",
            "audio_asset": "assets/audio/notes/f4.wav",
            "difficulty": 1,
            "version": 2,
            "options": [
                {"id": "q_note_b05_o1", "option_key": "C4", "label": "Đô (C4)", "is_correct": False, "sort_order": 1},
                {"id": "q_note_b05_o2", "option_key": "E4", "label": "Mi (E4)", "is_correct": False, "sort_order": 2},
                {"id": "q_note_b05_o3", "option_key": "F4", "label": "Fa (F4)", "is_correct": True, "sort_order": 3},
                {"id": "q_note_b05_o4", "option_key": "A4", "label": "La (A4)", "is_correct": False, "sort_order": 4},
            ],
        },
        {
            "id": "q_note_b06",
            "topic_id": "topic_notes",
            "level_id": "lvl_notes_basic",
            "type": "listen_note",
            "prompt": "[Mức 1 • C4 Tự nhiên] Nghe âm chuẩn 440 Hz và chọn đúng tên nốt (hoặc bấm phím đàn):",
            "explanation": "Tần số 440 Hz chính là nốt La chuẩn (A4) dùng để lên dây nhạc cụ quốc tế.",
            "audio_asset": "assets/audio/notes/a4.wav",
            "difficulty": 1,
            "version": 2,
            "options": [
                {"id": "q_note_b06_o1", "option_key": "F4", "label": "Fa (F4)", "is_correct": False, "sort_order": 1},
                {"id": "q_note_b06_o2", "option_key": "G4", "label": "Sol (G4)", "is_correct": False, "sort_order": 2},
                {"id": "q_note_b06_o3", "option_key": "A4", "label": "La (A4)", "is_correct": True, "sort_order": 3},
                {"id": "q_note_b06_o4", "option_key": "B4", "label": "Si (B4)", "is_correct": False, "sort_order": 4},
            ],
        },
        {
            "id": "q_note_b07",
            "topic_id": "topic_notes",
            "level_id": "lvl_notes_basic",
            "type": "listen_note",
            "prompt": "[Mức 1 • C4 Tự nhiên] Nghe âm thanh và chọn đúng tên nốt (hoặc bấm trực tiếp phím đàn):",
            "explanation": "Nốt Si (B4) là bậc VII (nốt dẫn) nằm ngay bên phải cụm 3 phím đen.",
            "audio_asset": "assets/audio/notes/b4.wav",
            "difficulty": 1,
            "version": 2,
            "options": [
                {"id": "q_note_b07_o1", "option_key": "E4", "label": "Mi (E4)", "is_correct": False, "sort_order": 1},
                {"id": "q_note_b07_o2", "option_key": "G4", "label": "Sol (G4)", "is_correct": False, "sort_order": 2},
                {"id": "q_note_b07_o3", "option_key": "A4", "label": "La (A4)", "is_correct": False, "sort_order": 3},
                {"id": "q_note_b07_o4", "option_key": "B4", "label": "Si (B4)", "is_correct": True, "sort_order": 4},
            ],
        },
        {
            "id": "q_note_i01",
            "topic_id": "topic_notes",
            "level_id": "lvl_notes_inter",
            "type": "listen_note",
            "prompt": "[Mức 2 • C4 có dấu #/b] Nghe nốt nhạc trong quãng 4 và chọn tên nốt đúng:",
            "explanation": "Nốt Đô thăng / Rê giáng (C#4 / Db4) là phím đen đầu tiên trong cụm 2 phím đen.",
            "audio_asset": "assets/audio/notes/csharp4.wav",
            "difficulty": 2,
            "version": 2,
            "options": [
                {"id": "q_note_i01_o1", "option_key": "C4", "label": "Đô (C4)", "is_correct": False, "sort_order": 1},
                {"id": "q_note_i01_o2", "option_key": "C#4", "label": "Đô# / Rêb (C#4)", "is_correct": True, "sort_order": 2},
                {"id": "q_note_i01_o3", "option_key": "D4", "label": "Rê (D4)", "is_correct": False, "sort_order": 3},
                {"id": "q_note_i01_o4", "option_key": "D#4", "label": "Rê# / Mib (D#4)", "is_correct": False, "sort_order": 4},
            ],
        },
        {
            "id": "q_note_i02",
            "topic_id": "topic_notes",
            "level_id": "lvl_notes_inter",
            "type": "listen_note",
            "prompt": "[Mức 2 • C4 có dấu #/b] Nghe nốt nhạc trong quãng 4 và chọn tên nốt đúng:",
            "explanation": "Nốt Rê thăng / Mi giáng (D#4 / Eb4) là phím đen thứ hai trong cụm 2 phím đen.",
            "audio_asset": "assets/audio/notes/dsharp4.wav",
            "difficulty": 2,
            "version": 2,
            "options": [
                {"id": "q_note_i02_o1", "option_key": "D4", "label": "Rê (D4)", "is_correct": False, "sort_order": 1},
                {"id": "q_note_i02_o2", "option_key": "D#4", "label": "Rê# / Mib (D#4)", "is_correct": True, "sort_order": 2},
                {"id": "q_note_i02_o3", "option_key": "E4", "label": "Mi (E4)", "is_correct": False, "sort_order": 3},
                {"id": "q_note_i02_o4", "option_key": "F#4", "label": "Fa# / Solb (F#4)", "is_correct": False, "sort_order": 4},
            ],
        },
        {
            "id": "q_note_i03",
            "topic_id": "topic_notes",
            "level_id": "lvl_notes_inter",
            "type": "listen_note",
            "prompt": "[Mức 2 • C4 có dấu #/b] Nghe nốt có dấu hóa trong quãng 4 (có thể đối chiếu C4):",
            "explanation": "Nốt Fa thăng / Sol giáng (F#4 / Gb4) nằm chính giữa Fa (F4) và Sol (G4), là phím đen đầu cụm 3 phím đen.",
            "audio_asset": "assets/audio/notes/fsharp4.wav",
            "difficulty": 2,
            "version": 2,
            "options": [
                {"id": "q_note_i03_o1", "option_key": "F4", "label": "Fa (F4)", "is_correct": False, "sort_order": 1},
                {"id": "q_note_i03_o2", "option_key": "F#4", "label": "Fa# / Solb (F#4)", "is_correct": True, "sort_order": 2},
                {"id": "q_note_i03_o3", "option_key": "G4", "label": "Sol (G4)", "is_correct": False, "sort_order": 3},
                {"id": "q_note_i03_o4", "option_key": "G#4", "label": "Sol# / Lab (G#4)", "is_correct": False, "sort_order": 4},
            ],
        },
        {
            "id": "q_note_a01",
            "topic_id": "topic_notes",
            "level_id": "lvl_notes_adv",
            "type": "listen_note",
            "prompt": "[Mức 3 • Đa quãng C3–C5 Tự nhiên] Nghe và nhận diện chính xác tên nốt và quãng tám:",
            "explanation": "Đây là nốt Đô cao (C5) ở quãng tám 5 (tần số 523.25 Hz), cao hơn C4 đúng 1 quãng tám.",
            "audio_asset": "assets/audio/notes/c5.wav",
            "difficulty": 3,
            "version": 2,
            "options": [
                {"id": "q_note_a01_o1", "option_key": "C4", "label": "Đô 4 (C4)", "is_correct": False, "sort_order": 1},
                {"id": "q_note_a01_o2", "option_key": "G4", "label": "Sol 4 (G4)", "is_correct": False, "sort_order": 2},
                {"id": "q_note_a01_o3", "option_key": "C5", "label": "Đô cao (C5)", "is_correct": True, "sort_order": 3},
                {"id": "q_note_a01_o4", "option_key": "E5", "label": "Mi cao (E5)", "is_correct": False, "sort_order": 4},
            ],
        },
        {
            "id": "q_note_a02",
            "topic_id": "topic_notes",
            "level_id": "lvl_notes_adv",
            "type": "listen_note",
            "prompt": "[Mức 3 • Đa quãng C3–C5 Tự nhiên] Nghe nốt trầm ở quãng tám 3 và chọn đáp án đúng:",
            "explanation": "Đây là nốt Sol trầm (G3) ở quãng tám 3 (tần số 196.0 Hz).",
            "audio_asset": "assets/audio/notes/g3.wav",
            "difficulty": 3,
            "version": 2,
            "options": [
                {"id": "q_note_a02_o1", "option_key": "E3", "label": "Mi trầm (E3)", "is_correct": False, "sort_order": 1},
                {"id": "q_note_a02_o2", "option_key": "G3", "label": "Sol trầm (G3)", "is_correct": True, "sort_order": 2},
                {"id": "q_note_a02_o3", "option_key": "A3", "label": "La trầm (A3)", "is_correct": False, "sort_order": 3},
                {"id": "q_note_a02_o4", "option_key": "C4", "label": "Đô 4 (C4)", "is_correct": False, "sort_order": 4},
            ],
        },
        {
            "id": "q_note_m01",
            "topic_id": "topic_notes",
            "level_id": "lvl_notes_master",
            "type": "listen_note",
            "prompt": "[Mức 4 • Nâng cao C3–C5 + #/b] Nghe âm thanh (không tham chiếu C4) và chọn chính xác tên nốt:",
            "explanation": "Đây là nốt Fa thăng trầm (F#3 / Gb3) ở quãng tám 3.",
            "audio_asset": "assets/audio/notes/fsharp3.wav",
            "difficulty": 4,
            "version": 2,
            "options": [
                {"id": "q_note_m01_o1", "option_key": "F3", "label": "Fa trầm (F3)", "is_correct": False, "sort_order": 1},
                {"id": "q_note_m01_o2", "option_key": "F#3", "label": "Fa# / Solb trầm (F#3)", "is_correct": True, "sort_order": 2},
                {"id": "q_note_m01_o3", "option_key": "G#4", "label": "Sol# / Lab (G#4)", "is_correct": False, "sort_order": 3},
                {"id": "q_note_m01_o4", "option_key": "C#5", "label": "Đô# / Rêb cao (C#5)", "is_correct": False, "sort_order": 4},
            ],
        },
        {
            "id": "q_int_b01",
            "topic_id": "topic_intervals",
            "level_id": "lvl_intervals_basic",
            "type": "interval_melodic",
            "prompt": "Nghe hai nốt đi lên từ Đô (C4). Khoảng cách giữa hai nốt này là quãng mấy?",
            "explanation": "Đô (C4) lên Rê (D4) cách nhau 1 cung nguyên, gọi là Quãng 2 trưởng (M2).",
            "audio_asset": "assets/audio/intervals/c4_maj2_asc.wav",
            "difficulty": 1,
            "version": 1,
            "options": [
                {"id": "q_int_b01_o1", "option_key": "M2", "label": "Quãng 2 trưởng", "is_correct": True, "sort_order": 1},
                {"id": "q_int_b01_o2", "option_key": "M3", "label": "Quãng 3 trưởng", "is_correct": False, "sort_order": 2},
                {"id": "q_int_b01_o3", "option_key": "P5", "label": "Quãng 5 đúng", "is_correct": False, "sort_order": 3},
                {"id": "q_int_b01_o4", "option_key": "P8", "label": "Quãng 8 đúng", "is_correct": False, "sort_order": 4},
            ],
        },
        {
            "id": "q_int_b02",
            "topic_id": "topic_intervals",
            "level_id": "lvl_intervals_basic",
            "type": "interval_melodic",
            "prompt": "Nghe hai nốt đi lên tạo màu sắc tươi sáng (Đô → Mi). Đây là quãng nào?",
            "explanation": "Đô (C4) lên Mi (E4) gồm 2 cung nguyên (4 nửa cung), là Quãng 3 trưởng (M3).",
            "audio_asset": "assets/audio/intervals/c4_maj3_asc.wav",
            "difficulty": 1,
            "version": 1,
            "options": [
                {"id": "q_int_b02_o1", "option_key": "M2", "label": "Quãng 2 trưởng", "is_correct": False, "sort_order": 1},
                {"id": "q_int_b02_o2", "option_key": "M3", "label": "Quãng 3 trưởng", "is_correct": True, "sort_order": 2},
                {"id": "q_int_b02_o3", "option_key": "P4", "label": "Quãng 4 đúng", "is_correct": False, "sort_order": 3},
                {"id": "q_int_b02_o4", "option_key": "P5", "label": "Quãng 5 đúng", "is_correct": False, "sort_order": 4},
            ],
        },
        {
            "id": "q_int_b03",
            "topic_id": "topic_intervals",
            "level_id": "lvl_intervals_basic",
            "type": "interval_melodic",
            "prompt": "Nghe hai nốt đi lên gợi âm hưởng mở đầu nhạc hiệu / kèn lệnh (Đô → Fa):",
            "explanation": "Đô (C4) lên Fa (F4) cách nhau 2,5 cung (5 nửa cung), là Quãng 4 đúng (P4).",
            "audio_asset": "assets/audio/intervals/c4_p4_asc.wav",
            "difficulty": 1,
            "version": 1,
            "options": [
                {"id": "q_int_b03_o1", "option_key": "M3", "label": "Quãng 3 trưởng", "is_correct": False, "sort_order": 1},
                {"id": "q_int_b03_o2", "option_key": "P4", "label": "Quãng 4 đúng", "is_correct": True, "sort_order": 2},
                {"id": "q_int_b03_o3", "option_key": "P5", "label": "Quãng 5 đúng", "is_correct": False, "sort_order": 3},
                {"id": "q_int_b03_o4", "option_key": "P8", "label": "Quãng 8 đúng", "is_correct": False, "sort_order": 4},
            ],
        },
        {
            "id": "q_int_b04",
            "topic_id": "topic_intervals",
            "level_id": "lvl_intervals_basic",
            "type": "interval_melodic",
            "prompt": "Nghe hai nốt đi lên có độ hòa hợp vững chãi (Đô → Sol, bậc I lên bậc V):",
            "explanation": "Đô (C4) lên Sol (G4) cách nhau 3,5 cung (7 nửa cung), là Quãng 5 đúng (P5).",
            "audio_asset": "assets/audio/intervals/c4_p5_asc.wav",
            "difficulty": 1,
            "version": 1,
            "options": [
                {"id": "q_int_b04_o1", "option_key": "M2", "label": "Quãng 2 trưởng", "is_correct": False, "sort_order": 1},
                {"id": "q_int_b04_o2", "option_key": "P4", "label": "Quãng 4 đúng", "is_correct": False, "sort_order": 2},
                {"id": "q_int_b04_o3", "option_key": "P5", "label": "Quãng 5 đúng", "is_correct": True, "sort_order": 3},
                {"id": "q_int_b04_o4", "option_key": "P8", "label": "Quãng 8 đúng", "is_correct": False, "sort_order": 4},
            ],
        },
        {
            "id": "q_int_b05",
            "topic_id": "topic_intervals",
            "level_id": "lvl_intervals_basic",
            "type": "interval_melodic",
            "prompt": "Nghe hai nốt có cùng tên Đô nhưng cách nhau một bậc quãng tám (C4 → C5):",
            "explanation": "Khoảng cách 12 nửa cung giữa C4 và C5 là Quãng 8 đúng (Octave - P8).",
            "audio_asset": "assets/audio/intervals/c4_p8_asc.wav",
            "difficulty": 1,
            "version": 1,
            "options": [
                {"id": "q_int_b05_o1", "option_key": "M3", "label": "Quãng 3 trưởng", "is_correct": False, "sort_order": 1},
                {"id": "q_int_b05_o2", "option_key": "P5", "label": "Quãng 5 đúng", "is_correct": False, "sort_order": 2},
                {"id": "q_int_b05_o3", "option_key": "M6", "label": "Quãng 6 trưởng", "is_correct": False, "sort_order": 3},
                {"id": "q_int_b05_o4", "option_key": "P8", "label": "Quãng 8 đúng (Octave)", "is_correct": True, "sort_order": 4},
            ],
        },
        {
            "id": "q_int_i01",
            "topic_id": "topic_intervals",
            "level_id": "lvl_intervals_inter",
            "type": "interval_melodic",
            "prompt": "Nghe hai nốt đi lên mang màu sắc trầm buồn (C4 → Eb4). Đây là quãng gì?",
            "explanation": "Cách nhau 1,5 cung (3 nửa cung) là Quãng 3 thứ (m3), đặc trưng của hợp âm thứ.",
            "audio_asset": "assets/audio/intervals/c4_min3_asc.wav",
            "difficulty": 2,
            "version": 1,
            "options": [
                {"id": "q_int_i01_o1", "option_key": "m2", "label": "Quãng 2 thứ", "is_correct": False, "sort_order": 1},
                {"id": "q_int_i01_o2", "option_key": "m3", "label": "Quãng 3 thứ", "is_correct": True, "sort_order": 2},
                {"id": "q_int_i01_o3", "option_key": "M3", "label": "Quãng 3 trưởng", "is_correct": False, "sort_order": 3},
                {"id": "q_int_i01_o4", "option_key": "P4", "label": "Quãng 4 đúng", "is_correct": False, "sort_order": 4},
            ],
        },
        {
            "id": "q_int_i02",
            "topic_id": "topic_intervals",
            "level_id": "lvl_intervals_inter",
            "type": "interval_melodic",
            "prompt": "Nghe quãng giai điệu đi xuống từ Sol (G4) về Đô (C4). Xác định tên quãng:",
            "explanation": "Sol (G4) đi xuống Đô (C4) là Quãng 5 đúng đi xuống (P5 descending).",
            "audio_asset": "assets/audio/intervals/c4_p5_desc.wav",
            "difficulty": 2,
            "version": 1,
            "options": [
                {"id": "q_int_i02_o1", "option_key": "M3", "label": "Quãng 3 trưởng đi xuống", "is_correct": False, "sort_order": 1},
                {"id": "q_int_i02_o2", "option_key": "P4", "label": "Quãng 4 đúng đi xuống", "is_correct": False, "sort_order": 2},
                {"id": "q_int_i02_o3", "option_key": "P5", "label": "Quãng 5 đúng đi xuống", "is_correct": True, "sort_order": 3},
                {"id": "q_int_i02_o4", "option_key": "P8", "label": "Quãng 8 đúng đi xuống", "is_correct": False, "sort_order": 4},
            ],
        },
        {
            "id": "q_int_i03",
            "topic_id": "topic_intervals",
            "level_id": "lvl_intervals_inter",
            "type": "interval_melodic",
            "prompt": "Nghe hai nốt đi lên từ C4 đến A4 (9 nửa cung). Đây là quãng nào?",
            "explanation": "Từ Đô (C4) lên La (A4) là Quãng 6 trưởng (M6), có âm hưởng rộng mở và ấm áp.",
            "audio_asset": "assets/audio/intervals/c4_maj6_asc.wav",
            "difficulty": 2,
            "version": 1,
            "options": [
                {"id": "q_int_i03_o1", "option_key": "P5", "label": "Quãng 5 đúng", "is_correct": False, "sort_order": 1},
                {"id": "q_int_i03_o2", "option_key": "m6", "label": "Quãng 6 thứ", "is_correct": False, "sort_order": 2},
                {"id": "q_int_i03_o3", "option_key": "M6", "label": "Quãng 6 trưởng", "is_correct": True, "sort_order": 3},
                {"id": "q_int_i03_o4", "option_key": "M7", "label": "Quãng 7 trưởng", "is_correct": False, "sort_order": 4},
            ],
        },
        {
            "id": "q_int_a01",
            "topic_id": "topic_intervals",
            "level_id": "lvl_intervals_adv",
            "type": "interval_harmonic",
            "prompt": "Nghe hai nốt phát ĐỒNG THỜI (quãng hòa thanh) có độ căng thẳng đặc trưng (3 cung):",
            "explanation": "Khoảng cách 6 nửa cung (C4 - F#4) là Quãng 4 tăng / 5 giảm (Tritone), có tính nghịch và căng thẳng mạnh.",
            "audio_asset": "assets/audio/intervals/c4_tritone_harm.wav",
            "difficulty": 3,
            "version": 1,
            "options": [
                {"id": "q_int_a01_o1", "option_key": "P4", "label": "Quãng 4 đúng", "is_correct": False, "sort_order": 1},
                {"id": "q_int_a01_o2", "option_key": "tritone", "label": "Quãng 4 tăng / 5 giảm (Tritone)", "is_correct": True, "sort_order": 2},
                {"id": "q_int_a01_o3", "option_key": "P5", "label": "Quãng 5 đúng", "is_correct": False, "sort_order": 3},
                {"id": "q_int_a01_o4", "option_key": "M6", "label": "Quãng 6 trưởng", "is_correct": False, "sort_order": 4},
            ],
        },
        {
            "id": "q_int_a02",
            "topic_id": "topic_intervals",
            "level_id": "lvl_intervals_adv",
            "type": "interval_harmonic",
            "prompt": "Nghe quãng hòa thanh (hai nốt phát cùng lúc) và xác định chất lượng quãng:",
            "explanation": "Hai nốt cách nhau 11 nửa cung (C4 và B4) tạo nên Quãng 7 trưởng (M7) sắc nét.",
            "audio_asset": "assets/audio/intervals/c4_maj7_harm.wav",
            "difficulty": 3,
            "version": 1,
            "options": [
                {"id": "q_int_a02_o1", "option_key": "M6", "label": "Quãng 6 trưởng", "is_correct": False, "sort_order": 1},
                {"id": "q_int_a02_o2", "option_key": "m7", "label": "Quãng 7 thứ", "is_correct": False, "sort_order": 2},
                {"id": "q_int_a02_o3", "option_key": "M7", "label": "Quãng 7 trưởng", "is_correct": True, "sort_order": 3},
                {"id": "q_int_a02_o4", "option_key": "P8", "label": "Quãng 8 đúng", "is_correct": False, "sort_order": 4},
            ],
        },
        {
            "id": "q_key_b01",
            "topic_id": "topic_keys",
            "level_id": "lvl_keys_basic",
            "type": "key_quality",
            "prompt": "Nghe chuỗi hòa âm I – IV – V – I sau đây và cho biết đoạn nhạc thuộc điệu thức nào?",
            "explanation": "Chuỗi hợp âm kết thúc vững chãi ở hợp âm Đô Trưởng (C-E-G) với quãng 3 trưởng sáng rõ → Điệu Trưởng (Major).",
            "audio_asset": "assets/audio/keys/c_major.wav",
            "difficulty": 1,
            "version": 1,
            "options": [
                {"id": "q_key_b01_o1", "option_key": "major", "label": "Giọng Trưởng (Major) – tươi sáng, vững chãi", "is_correct": True, "sort_order": 1},
                {"id": "q_key_b01_o2", "option_key": "minor", "label": "Giọng Thứ (Minor) – trầm lắng, mềm mại", "is_correct": False, "sort_order": 2},
            ],
        },
        {
            "id": "q_key_b02",
            "topic_id": "topic_keys",
            "level_id": "lvl_keys_basic",
            "type": "key_quality",
            "prompt": "Nghe chuỗi hòa âm i – iv – V – i và xác định màu sắc điệu thức:",
            "explanation": "Hợp âm chủ La Thứ (A-C-E) có bậc III là quãng 3 thứ tạo màu sắc trầm lắng đặc trưng của Giọng Thứ (Minor).",
            "audio_asset": "assets/audio/keys/a_minor.wav",
            "difficulty": 1,
            "version": 1,
            "options": [
                {"id": "q_key_b02_o1", "option_key": "major", "label": "Giọng Trưởng (Major)", "is_correct": False, "sort_order": 1},
                {"id": "q_key_b02_o2", "option_key": "minor", "label": "Giọng Thứ (Minor)", "is_correct": True, "sort_order": 2},
            ],
        },
        {
            "id": "q_key_b03",
            "topic_id": "topic_keys",
            "level_id": "lvl_keys_basic",
            "type": "key_signature",
            "prompt": "Nghe chuỗi hòa âm giọng Đô Trưởng (C Major). Giọng Đô Trưởng có bao nhiêu dấu hóa ở hóa biểu?",
            "explanation": "Đô Trưởng (C Major) và giọng song song La Thứ (A Minor) không có dấu thăng hay dấu giáng nào ở hóa biểu.",
            "audio_asset": "assets/audio/keys/c_major.wav",
            "difficulty": 1,
            "version": 1,
            "options": [
                {"id": "q_key_b03_o1", "option_key": "0", "label": "0 dấu hóa (Không thăng, không giáng)", "is_correct": True, "sort_order": 1},
                {"id": "q_key_b03_o2", "option_key": "1s", "label": "1 dấu thăng (Fa#)", "is_correct": False, "sort_order": 2},
                {"id": "q_key_b03_o3", "option_key": "1b", "label": "1 dấu giáng (Sib)", "is_correct": False, "sort_order": 3},
                {"id": "q_key_b03_o4", "option_key": "2s", "label": "2 dấu thăng (Fa#, Đô#)", "is_correct": False, "sort_order": 4},
            ],
        },
        {
            "id": "q_key_b04",
            "topic_id": "topic_keys",
            "level_id": "lvl_keys_basic",
            "type": "key_quality",
            "prompt": "Nghe chuỗi hòa âm sau và nhận biết đây là giọng Trưởng hay giọng Thứ:",
            "explanation": "Đây là chuỗi hòa âm giọng Sol Trưởng (G Major) có màu sắc sáng rõ của điệu thức Trưởng.",
            "audio_asset": "assets/audio/keys/g_major.wav",
            "difficulty": 1,
            "version": 1,
            "options": [
                {"id": "q_key_b04_o1", "option_key": "major", "label": "Giọng Trưởng (Major)", "is_correct": True, "sort_order": 1},
                {"id": "q_key_b04_o2", "option_key": "minor", "label": "Giọng Thứ (Minor)", "is_correct": False, "sort_order": 2},
            ],
        },
        {
            "id": "q_key_b05",
            "topic_id": "topic_keys",
            "level_id": "lvl_keys_basic",
            "type": "key_quality",
            "prompt": "Nghe chuỗi hòa âm sau và phân biệt màu sắc Trưởng / Thứ:",
            "explanation": "Đây là chuỗi hòa âm giọng Rê Thứ (D Minor) mang màu sắc sâu lắng của điệu Thứ.",
            "audio_asset": "assets/audio/keys/d_minor.wav",
            "difficulty": 1,
            "version": 1,
            "options": [
                {"id": "q_key_b05_o1", "option_key": "major", "label": "Giọng Trưởng (Major)", "is_correct": False, "sort_order": 1},
                {"id": "q_key_b05_o2", "option_key": "minor", "label": "Giọng Thứ (Minor)", "is_correct": True, "sort_order": 2},
            ],
        },
        {
            "id": "q_key_i01",
            "topic_id": "topic_keys",
            "level_id": "lvl_keys_inter",
            "type": "key_signature",
            "prompt": "Nghe chuỗi hòa âm giọng Sol Trưởng (G Major). Hóa biểu của Sol Trưởng có dấu hóa nào?",
            "explanation": "Sol Trưởng (G Major) và Mi Thứ (E Minor) có 1 dấu thăng tại nốt Fa (F#).",
            "audio_asset": "assets/audio/keys/g_major.wav",
            "difficulty": 2,
            "version": 1,
            "options": [
                {"id": "q_key_i01_o1", "option_key": "0", "label": "Không có dấu hóa", "is_correct": False, "sort_order": 1},
                {"id": "q_key_i01_o2", "option_key": "1s", "label": "1 dấu thăng (Fa#)", "is_correct": True, "sort_order": 2},
                {"id": "q_key_i01_o3", "option_key": "1b", "label": "1 dấu giáng (Sib)", "is_correct": False, "sort_order": 3},
                {"id": "q_key_i01_o4", "option_key": "2s", "label": "2 dấu thăng (Fa#, Đô#)", "is_correct": False, "sort_order": 4},
            ],
        },
        {
            "id": "q_key_i02",
            "topic_id": "topic_keys",
            "level_id": "lvl_keys_inter",
            "type": "key_signature",
            "prompt": "Nghe chuỗi hòa âm giọng Fa Trưởng (F Major). Hóa biểu của Fa Trưởng có dấu hóa nào?",
            "explanation": "Fa Trưởng (F Major) và Rê Thứ (D Minor) có 1 dấu giáng tại nốt Si (Bb).",
            "audio_asset": "assets/audio/keys/f_major.wav",
            "difficulty": 2,
            "version": 1,
            "options": [
                {"id": "q_key_i02_o1", "option_key": "1s", "label": "1 dấu thăng (Fa#)", "is_correct": False, "sort_order": 1},
                {"id": "q_key_i02_o2", "option_key": "1b", "label": "1 dấu giáng (Sib)", "is_correct": True, "sort_order": 2},
                {"id": "q_key_i02_o3", "option_key": "2b", "label": "2 dấu giáng (Sib, Mib)", "is_correct": False, "sort_order": 3},
                {"id": "q_key_i02_o4", "option_key": "0", "label": "Không có dấu hóa", "is_correct": False, "sort_order": 4},
            ],
        },
        {
            "id": "q_key_i03",
            "topic_id": "topic_keys",
            "level_id": "lvl_keys_inter",
            "type": "key_center",
            "prompt": "Nghe chuỗi hòa âm (có thể đối chiếu C4) và xác định tên giọng Thứ sau đây:",
            "explanation": "Chuỗi hòa âm kết về âm chủ La (A3) với quãng 3 thứ La–Đô → Giọng La Thứ (A Minor).",
            "audio_asset": "assets/audio/keys/a_minor.wav",
            "difficulty": 2,
            "version": 1,
            "options": [
                {"id": "q_key_i03_o1", "option_key": "Am", "label": "La Thứ (A Minor)", "is_correct": True, "sort_order": 1},
                {"id": "q_key_i03_o2", "option_key": "C", "label": "Đô Trưởng (C Major)", "is_correct": False, "sort_order": 2},
                {"id": "q_key_i03_o3", "option_key": "Dm", "label": "Rê Thứ (D Minor)", "is_correct": False, "sort_order": 3},
                {"id": "q_key_i03_o4", "option_key": "G", "label": "Sol Trưởng (G Major)", "is_correct": False, "sort_order": 4},
            ],
        },
        {
            "id": "q_key_a01",
            "topic_id": "topic_keys",
            "level_id": "lvl_keys_adv",
            "type": "key_center",
            "prompt": "Nghe chuỗi hòa âm có 2 dấu thăng (Fa#, Đô#) và màu sắc Trưởng tươi sáng. Đây là giọng nào?",
            "explanation": "Giọng Trưởng có 2 dấu thăng (Fa#, Đô#) và âm chủ cao hơn Đô 1 cung là Rê Trưởng (D Major).",
            "audio_asset": "assets/audio/keys/d_major.wav",
            "difficulty": 3,
            "version": 1,
            "options": [
                {"id": "q_key_a01_o1", "option_key": "G", "label": "Sol Trưởng (G Major)", "is_correct": False, "sort_order": 1},
                {"id": "q_key_a01_o2", "option_key": "D", "label": "Rê Trưởng (D Major)", "is_correct": True, "sort_order": 2},
                {"id": "q_key_a01_o3", "option_key": "Bm", "label": "Si Thứ (B Minor)", "is_correct": False, "sort_order": 3},
                {"id": "q_key_a01_o4", "option_key": "Bb", "label": "Si giáng Trưởng (Bb Major)", "is_correct": False, "sort_order": 4},
            ],
        },
        {
            "id": "q_key_a02",
            "topic_id": "topic_keys",
            "level_id": "lvl_keys_adv",
            "type": "key_center",
            "prompt": "Nghe chuỗi hòa âm có 2 dấu giáng (Sib, Mib) và màu sắc Thứ trầm lắng. Đây là giọng nào?",
            "explanation": "Giọng Thứ song song với Si giáng Trưởng (2 dấu giáng) là Sol Thứ (G Minor).",
            "audio_asset": "assets/audio/keys/g_minor.wav",
            "difficulty": 3,
            "version": 1,
            "options": [
                {"id": "q_key_a02_o1", "option_key": "Dm", "label": "Rê Thứ (D Minor)", "is_correct": False, "sort_order": 1},
                {"id": "q_key_a02_o2", "option_key": "Em", "label": "Mi Thứ (E Minor)", "is_correct": False, "sort_order": 2},
                {"id": "q_key_a02_o3", "option_key": "Gm", "label": "Sol Thứ (G Minor)", "is_correct": True, "sort_order": 3},
                {"id": "q_key_a02_o4", "option_key": "Bb", "label": "Si giáng Trưởng (Bb Major)", "is_correct": False, "sort_order": 4},
            ],
        },
    ]

    presets = [
        {"id": "preset_slow", "name": "Luyện chậm (Largo)", "bpm": 60, "numerator": 4, "denominator": 4, "sound_type": "tempo"},
        {"id": "preset_walk", "name": "Vừa phải (Andante)", "bpm": 90, "numerator": 4, "denominator": 4, "sound_type": "tempo"},
        {"id": "preset_waltz", "name": "Nhịp Valse 3/4", "bpm": 110, "numerator": 3, "denominator": 4, "sound_type": "bell"},
        {"id": "preset_tempo_std", "name": "Chuẩn Tempo Lite", "bpm": 120, "numerator": 4, "denominator": 4, "sound_type": "tempo"},
        {"id": "preset_allegro", "name": "Nhanh (Allegro)", "bpm": 132, "numerator": 4, "denominator": 4, "sound_type": "click"},
    ]

    seed_data = {
        "content_version": 7,
        "topics": topics,
        "levels": levels,
        "questions": questions,
        "metronome_presets": presets,
    }

    data_dir = os.path.join(ASSETS_DIR, "data")
    os.makedirs(data_dir, exist_ok=True)
    seed_path = os.path.join(data_dir, "seed_content.json")
    with open(seed_path, "w", encoding="utf-8") as f:
        json.dump(seed_data, f, ensure_ascii=False, indent=2)
    print("Generated seed_content.json.")


def main() -> None:
    print("Generating upgraded Solfa 44.1kHz audio, chime SFX, logos, and seed content...")
    generate_logos_and_icons()
    generate_notes()
    generate_intervals()
    generate_keys()
    generate_metronome_and_sfx()
    generate_seed_json()
    print("All assets and logos generated successfully!")


if __name__ == "__main__":
    main()
