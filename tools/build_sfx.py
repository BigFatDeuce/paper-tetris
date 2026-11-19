"""Sound effects for Paper Tetris, made from the Paper Mario 64 samples.

1. A tiny sampler plays the PM64 instruments (marimba, celesta, brass,
   timpani...) to build the gameplay sounds and short original jingles.
2. A curated library of raw PM64 effects (menus, jumps, fanfares...) is
   copied into assets/sfx/pm/ so they can be used directly and swapped in
   the in-game Sound Test.
3. data/sfx.json maps every game event to a file (+ volume / pitch).
"""
import json
import shutil
import struct
import wave
from pathlib import Path

import numpy as np

from paths import SAMPLES  # noqa: E402
ROOT = Path(__file__).resolve().parent.parent
OUT = ROOT / "game" / "assets" / "sfx"
LIB = OUT / "pm"
CATALOG = ROOT / "game" / "data" / "sfx.json"
SR = 32000

NOTE = {"C": 0, "C#": 1, "D": 2, "D#": 3, "E": 4, "F": 5, "F#": 6, "G": 7, "G#": 8, "A": 9, "A#": 10, "B": 11}


def midi(name: str) -> int:
    n = name[:-1]
    return NOTE[n] + 12 * (int(name[-1]) + 1)


INST = {
    "marimba": ("pitch percussion/PM64 Marimba 1 F#4.wav", "F#4"),
    "marimba_hi": ("pitch percussion/PM64 Marimba 1 F#5.wav", "F#5"),
    "celesta": ("pitch percussion/PM64 Celesta C6.wav", "C6"),
    "chime": ("pitch percussion/PM64 Chime 8 C6.wav", "C6"),
    "bell": ("pitch percussion/PM64 Bell 1 F#5.wav", "F#5"),
    "vibes": ("pitch percussion/PM64 Vibraphone 2 F#4.wav", "F#4"),
    "musicbox": ("pitch percussion/PM64 MIDI Music Box F#5.wav", "F#5"),
    "kalimba": ("pitch percussion/PM64 Kalimba F#4.wav", "F#4"),
    "steelpan": ("pitch percussion/PM64 Steel Pan F#4.wav", "F#4"),
    "timpani": ("pitch percussion/PM64 Timpani G2.wav", "G2"),
    "timpani_m": ("pitch percussion/PM64 Timpani Muffled G2.wav", "G2"),
    "brass": ("brass/PM64 MIDI Brass Section F#4.wav", "F#4"),
    "trumpet": ("brass/PM64 Trumpet F#5.wav", "F#5"),
    "horn": ("brass/PM64 French Horn F#3.wav", "F#3"),
    "tuba": ("brass/PM64 Tuba F#2.wav", "F#2"),
    "trombone": ("brass/PM64 Trombone F#3.wav", "F#3"),
    "strings": ("strings (bowed, harps)/PM64 Strings 1 F#4.wav", "F#4"),
    "pizz": ("strings (bowed, harps)/PM64 Pizzicato String F#3.wav", "F#3"),
    "harp": ("strings (bowed, harps)/PM64 Harp C5.wav", "C5"),
    "flute": ("wind/PM64 Flute F#5.wav", "F#5"),
    "piccolo": ("wind/PM64 Piccolo C6.wav", "C6"),
    "ocarina": ("wind/PM64 Ocarina F#4.wav", "F#4"),
    "sine": ("synth lead/PM64 Sine Wave Blip F#6.wav", "F#6"),
    "orchhit": ("synth lead/PM64 Orchestra Hit.wav", "C4"),
    "woodblock_hi": ("percussion/shakers and clicks/PM64 Woodblock High.wav", "C5"),
    "woodblock_lo": ("percussion/shakers and clicks/PM64 Woodblock Low.wav", "C5"),
    "castanets": ("percussion/shakers and clicks/PM64 Castanets.wav", "C5"),
    "sticks": ("percussion/shakers and clicks/PM64 Drumsticks.wav", "C5"),
    "snareroll": ("percussion/snares/PM64 Snare Drumroll.wav", "C5"),
    "snare": ("percussion/snares/BANK_00_INSTR_0001_SND_0000.wav", "C5"),
    "kick": ("percussion/kicks/BANK_00_INSTR_0000_SND_0000.wav", "C5"),
    "tambourine": ("percussion/hats/PM64 Tambourine.wav", "C5"),
    "cymbal_rev": ("percussion/crashes and reverse cymbals/PM64 Reverse Cymbal.wav", "C5"),
    "gong": ("percussion/crashes and reverse cymbals/PM64 Gong.wav", "C5"),
    "airy": ("percussion/misc/PM64 Airy Blip Sound.wav", "C5"),
    "sleigh": ("percussion/misc/PM64 Sleigh Bells.wav", "C5"),
    "vibraslap": ("percussion/misc/PM64 Vibraslap.wav", "C5"),
    "gliss_up": ("samples and misc/PM64 Glissando Upwards From C5.wav", "C5"),
    "gliss_down": ("samples and misc/PM64 Glissando Downwards.wav", "C5"),
    "whip": ("samples and misc/PM64 Whip Crack.wav", "C5"),
}

_cache = {}


def read_wav(path: Path):
    with wave.open(str(path)) as w:
        sr, ch, sw, n = w.getframerate(), w.getnchannels(), w.getsampwidth(), w.getnframes()
        raw = w.readframes(n)
    a = np.frombuffer(raw, dtype=np.int16 if sw == 2 else np.uint8).astype(np.float32)
    if sw == 1:
        a = (a - 128.0) * 256.0
    a = a.reshape(-1, ch).mean(axis=1) / 32768.0
    return a, sr


def inst(name):
    if name not in _cache:
        rel, root = INST[name]
        a, sr = read_wav(SAMPLES / rel)
        # trim leading silence
        nz = np.nonzero(np.abs(a) > 0.002)[0]
        if len(nz):
            a = a[max(nz[0] - 8, 0):]
        _cache[name] = (a, sr, midi(root))
    return _cache[name]


def note(name, pitch, dur=None, vel=1.0, attack=0.002, release=0.05, vibrato=0.0, bend=0.0):
    """Render one note. pitch: note name, midi number or None (= root)."""
    a, sr, root = inst(name)
    m = root if pitch is None else (midi(pitch) if isinstance(pitch, str) else pitch)
    ratio = 2 ** ((m - root) / 12.0) * sr / SR
    max_len = int(len(a) / ratio) - 1
    n = max_len if dur is None else min(int(dur * SR), max_len)
    t = np.arange(n, dtype=np.float32)
    if vibrato or bend:
        sec = t / SR
        r = ratio * (2 ** ((vibrato * np.sin(2 * np.pi * 5.5 * sec) * np.clip(sec * 3, 0, 1)
                             + bend * sec) / 12.0))
        pos = np.cumsum(r)
        pos = pos[pos < len(a) - 1]
        n = len(pos)
    else:
        pos = t * ratio
    i = pos.astype(np.int64)
    f = pos - i
    out = a[i] * (1 - f) + a[np.minimum(i + 1, len(a) - 1)] * f
    env = np.ones(n, np.float32)
    na = max(int(attack * SR), 1)
    env[:na] = np.linspace(0, 1, na)
    nr = min(int(release * SR), n)
    if dur is not None and nr > 0:
        env[n - nr:] *= np.linspace(1, 0, nr)
    return out * env * vel


def noise_burst(dur, vel=0.5, lp=0.15, decay=30.0):
    n = int(dur * SR)
    rng = np.random.default_rng(3)
    x = rng.standard_normal(n).astype(np.float32)
    # one-pole low-pass
    y = np.zeros_like(x)
    acc = 0.0
    for k in range(n):
        acc += lp * (x[k] - acc)
        y[k] = acc
    env = np.exp(-np.arange(n) / SR * decay)
    return y * env * vel / (np.max(np.abs(y)) + 1e-9)


class Mix:
    def __init__(self, length=4.0):
        self.buf = np.zeros(int(length * SR), np.float32)
        self.end = 0

    def add(self, sig, at=0.0, gain=1.0):
        s = int(at * SR)
        e = min(s + len(sig), len(self.buf))
        self.buf[s:e] += sig[: e - s] * gain
        self.end = max(self.end, e)
        return self

    def render(self, peak=0.89, reverb=0.12, tail=0.35):
        y = self.buf[: min(len(self.buf), self.end + int(tail * SR))].copy()
        if reverb > 0:
            y = add_reverb(y, reverb)
        m = np.max(np.abs(y)) + 1e-9
        y = y * (peak / m)
        fade = min(int(0.01 * SR), len(y))
        y[-fade:] *= np.linspace(1, 0, fade)
        return y


def add_reverb(y, mix=0.12, length=0.7):
    rng = np.random.default_rng(11)
    n = int(length * SR)
    ir = rng.standard_normal(n).astype(np.float32) * np.exp(-np.arange(n) / SR * 7.0)
    ir[: int(0.012 * SR)] = 0  # pre-delay
    ir /= np.sqrt(np.sum(ir ** 2))
    L = len(y) + n
    nfft = 1 << int(np.ceil(np.log2(L)))
    wet = np.fft.irfft(np.fft.rfft(y, nfft) * np.fft.rfft(ir, nfft), nfft)[: len(y) + n // 2]
    out = np.zeros(len(wet), np.float32)
    out[: len(y)] += y
    out += wet * mix
    return out


def write(name, y):
    OUT.mkdir(parents=True, exist_ok=True)
    pcm = (np.clip(y, -1, 1) * 32767).astype("<i2")
    with wave.open(str(OUT / f"{name}.wav"), "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(pcm.tobytes())


def arp(m, inst_name, notes, start=0.0, step=0.05, dur=0.5, vel=0.8, gain=1.0):
    for k, n in enumerate(notes):
        m.add(note(inst_name, n, dur, vel), start + k * step, gain)
    return m


# ------------------------------------------------------------------ designs

def build_designed():
    # --- piece handling (short, soft, frequent) ---
    write("move", Mix(0.3).add(note("woodblock_hi", "G5", 0.06, 0.55)).render(0.55, reverb=0.04, tail=0.05))
    write("rotate", Mix(0.3).add(note("marimba_hi", "D6", 0.09, 0.7, release=0.04))
          .add(note("woodblock_hi", "C6", 0.03, 0.2)).render(0.6, reverb=0.05, tail=0.08))
    write("rotate_fail", Mix(0.3).add(note("woodblock_lo", "C4", 0.06, 0.6)).render(0.45, reverb=0.03, tail=0.05))
    write("lock", Mix(0.4).add(note("woodblock_lo", "A4", 0.09, 0.7))
          .add(noise_burst(0.07, 0.35, lp=0.08, decay=60)).render(0.6, reverb=0.06, tail=0.1))
    write("hard_drop", Mix(0.8).add(note("timpani_m", "D2", 0.4, 1.0))
          .add(note("kick", None, 0.25, 0.9))
          .add(noise_burst(0.12, 0.6, lp=0.12, decay=35)).render(0.86, reverb=0.1, tail=0.15))
    write("hold", Mix(0.5).add(note("harp", "G5", 0.25, 0.6), 0.0).add(note("harp", "D6", 0.25, 0.6), 0.035)
          .add(note("harp", "G6", 0.3, 0.6), 0.07).add(note("airy", None, 0.2, 0.25)).render(0.6, tail=0.2))
    write("soft_drop", Mix(0.2).add(note("sticks", None, 0.04, 0.4)).render(0.25, reverb=0.0, tail=0.02))

    # --- line clears: brighter the more lines ---
    c1 = Mix(1.5)
    arp(c1, "marimba", ["C5", "E5", "G5"], step=0.045, dur=0.45, vel=0.9)
    c1.add(note("celesta", "C6", 0.6, 0.5), 0.09)
    write("clear1", c1.render(0.8))
    c2 = Mix(1.5)
    arp(c2, "marimba", ["C5", "E5", "G5", "C6"], step=0.045, dur=0.5, vel=0.9)
    arp(c2, "celesta", ["E6", "G6"], start=0.12, step=0.05, dur=0.6, vel=0.55)
    write("clear2", c2.render(0.82))
    c3 = Mix(1.8)
    arp(c3, "vibes", ["C5", "E5", "G5", "C6", "E6"], step=0.042, dur=0.6, vel=0.85)
    arp(c3, "celesta", ["G6", "C7"], start=0.16, step=0.05, dur=0.7, vel=0.55)
    c3.add(note("tambourine", None, 0.3, 0.35), 0.0)
    write("clear3", c3.render(0.85))
    c4 = Mix(2.6)
    c4.add(note("orchhit", "C4", 0.6, 0.9), 0.0)
    c4.add(note("timpani", "C3", 0.9, 0.8), 0.0)
    arp(c4, "brass", ["C4", "E4", "G4"], step=0.0, dur=0.55, vel=0.55)
    arp(c4, "brass", ["F4", "A4", "C5"], start=0.18, step=0.0, dur=0.3, vel=0.5)
    arp(c4, "brass", ["G4", "C5", "E5"], start=0.32, step=0.0, dur=0.8, vel=0.6)
    arp(c4, "celesta", ["C6", "E6", "G6", "C7", "E7", "G7"], start=0.3, step=0.045, dur=0.8, vel=0.5)
    c4.add(note("chime", "C7", 1.0, 0.35), 0.55)
    c4.add(note("tambourine", None, 0.4, 0.4), 0.32)
    write("clear4", c4.render(0.9))

    # --- T-spin, back-to-back, combo, perfect clear ---
    ts = Mix(1.8)
    ts.add(note("gliss_up", None, 0.5, 0.5), 0.0)
    arp(ts, "musicbox", ["A5", "C#6", "E6", "A6"], start=0.05, step=0.06, dur=0.6, vel=0.7)
    ts.add(note("chime", "E7", 0.8, 0.35), 0.28)
    write("tspin", ts.render(0.85))
    b2b = Mix(1.2)
    arp(b2b, "trumpet", ["G5", "C6"], step=0.09, dur=0.35, vel=0.7)
    b2b.add(note("snare", None, 0.2, 0.5), 0.09)
    write("b2b", b2b.render(0.75))
    write("combo", Mix(1.0).add(note("celesta", "C6", 0.5, 0.9)).add(note("marimba_hi", "C6", 0.2, 0.4))
          .render(0.7, tail=0.2))
    pc = Mix(3.5)
    pc.add(note("cymbal_rev", None, 0.9, 0.5), 0.0)
    pc.add(note("orchhit", "C4", 0.7, 0.9), 0.9)
    pc.add(note("timpani", "C3", 1.2, 0.8), 0.9)
    arp(pc, "brass", ["C4", "E4", "G4", "C5"], start=0.9, step=0.0, dur=1.2, vel=0.5)
    arp(pc, "celesta", ["C6", "D6", "E6", "G6", "A6", "C7", "D7", "E7", "G7"], start=0.95, step=0.04, dur=0.9, vel=0.5)
    pc.add(note("chime", "C7", 1.4, 0.4), 1.35)
    write("perfect", pc.render(0.9))

    # --- level up fanfare (original motif) ---
    lv = Mix(2.5)
    lv.add(note("snareroll", None, 0.45, 0.35), 0.0)
    seq = [("G5", 0.0, 0.11), ("G5", 0.12, 0.11), ("G5", 0.24, 0.11), ("C6", 0.36, 0.5)]
    for n, t, d in seq:
        lv.add(note("trumpet", n, d, 0.75), t)
    arp(lv, "brass", ["C4", "E4", "G4"], start=0.36, step=0.0, dur=0.6, vel=0.5)
    lv.add(note("timpani", "C3", 0.8, 0.7), 0.36)
    arp(lv, "celesta", ["G6", "C7", "E7"], start=0.42, step=0.06, dur=0.7, vel=0.4)
    write("level_up", lv.render(0.88))

    # --- countdown ---
    write("count", Mix(1.0).add(note("bell", "A5", 0.5, 0.8)).add(note("woodblock_hi", "A5", 0.05, 0.4))
          .render(0.75, tail=0.2))
    go = Mix(1.6)
    arp(go, "brass", ["C5", "E5", "G5"], step=0.0, dur=0.5, vel=0.6)
    go.add(note("trumpet", "C6", 0.5, 0.8), 0.0)
    go.add(note("timpani", "C3", 0.7, 0.7), 0.0)
    go.add(note("bell", "C6", 0.8, 0.5), 0.0)
    write("go", go.render(0.85))

    # --- victory jingle (goal reached) ---
    v = Mix(4.5)
    melody = [("C5", 0.00, 0.14), ("E5", 0.15, 0.14), ("G5", 0.30, 0.14), ("C6", 0.45, 0.30),
              ("A5", 0.80, 0.14), ("C6", 0.95, 0.14), ("F6", 1.10, 0.30),
              ("E6", 1.45, 0.14), ("D6", 1.60, 0.14), ("E6", 1.75, 0.14), ("G6", 1.90, 0.9)]
    for n, t, d in melody:
        v.add(note("trumpet", n, d, 0.75), t)
    chords = [(["C4", "E4", "G4"], 0.0, 0.7), (["F4", "A4", "C5"], 0.8, 0.6), (["G4", "B4", "D5"], 1.45, 0.4),
              (["C4", "E4", "G4", "C5"], 1.9, 1.1)]
    for ch, t, d in chords:
        for n in ch:
            v.add(note("brass", n, d, 0.42), t)
    for t, n in [(0.0, "C3"), (0.8, "F2"), (1.45, "G2"), (1.9, "C3")]:
        v.add(note("timpani", n, 0.7, 0.7), t)
    v.add(note("snareroll", None, 0.45, 0.35), 1.45)
    arp(v, "celesta", ["C7", "E7", "G7", "C8"], start=1.95, step=0.06, dur=0.8, vel=0.35)
    v.add(note("chime", "C7", 1.2, 0.35), 2.1)
    write("victory", v.render(0.9))

    # --- game over: a sad, slightly comic descending motif ---
    g = Mix(4.0)
    for n, t, d in [("G3", 0.0, 0.35), ("F#3", 0.4, 0.35), ("F3", 0.8, 0.35)]:
        g.add(note("trombone", n, d, 0.8, release=0.08), t)
    g.add(note("trombone", "E3", 1.3, 0.85, release=0.4, vibrato=0.35, bend=-0.6), 1.2)
    g.add(note("tuba", "C2", 1.4, 0.6, release=0.4), 1.2)
    g.add(note("timpani_m", "C2", 0.8, 0.6), 1.2)
    g.add(note("vibraslap", None, 0.8, 0.3), 2.3)
    write("game_over", g.render(0.85))

    # --- records & results ---
    rec = Mix(3.0)
    arp(rec, "celesta", ["C6", "E6", "G6", "C7", "G6", "C7", "E7", "G7"], step=0.07, dur=0.8, vel=0.6)
    arp(rec, "vibes", ["C5", "E5", "G5", "C6"], step=0.14, dur=0.9, vel=0.5)
    rec.add(note("chime", "C7", 1.4, 0.4), 0.56)
    rec.add(note("sleigh", None, 0.8, 0.3), 0.5)
    write("new_record", rec.render(0.85))
    tally = Mix(0.4).add(note("marimba_hi", "G6", 0.06, 0.6)).render(0.45, reverb=0.03, tail=0.05)
    write("tally", tally)

    # --- menus (soft, wooden) ---
    write("menu_move", Mix(0.3).add(note("woodblock_hi", "E6", 0.05, 0.5)).add(note("marimba_hi", "E6", 0.08, 0.35))
          .render(0.5, reverb=0.04, tail=0.06))
    sel = Mix(0.8)
    sel.add(note("marimba_hi", "C6", 0.25, 0.7)).add(note("celesta", "G6", 0.4, 0.5), 0.05)
    write("menu_select", sel.render(0.7, tail=0.2))
    write("menu_back", Mix(0.5).add(note("marimba", "G4", 0.15, 0.8)).add(note("marimba", "D4", 0.2, 0.7), 0.06)
          .render(0.6, reverb=0.06, tail=0.1))
    write("menu_deny", Mix(0.5).add(note("woodblock_lo", "C4", 0.07, 0.7)).add(note("woodblock_lo", "C4", 0.07, 0.7), 0.09)
          .render(0.55, reverb=0.03, tail=0.05))
    write("menu_tick", Mix(0.2).add(note("sticks", None, 0.05, 0.7)).render(0.45, reverb=0.02, tail=0.03))
    op = Mix(0.8)
    op.add(note("harp", "C5", 0.2, 0.5), 0.0).add(note("harp", "G5", 0.2, 0.5), 0.03)
    op.add(note("harp", "C6", 0.3, 0.5), 0.06).add(noise_burst(0.12, 0.25, lp=0.3, decay=25), 0.0)
    write("window_open", op.render(0.6, tail=0.2))
    cl = Mix(0.8)
    cl.add(note("harp", "C6", 0.2, 0.5), 0.0).add(note("harp", "G5", 0.2, 0.5), 0.03)
    cl.add(note("harp", "C5", 0.3, 0.5), 0.06)
    write("window_close", cl.render(0.55, tail=0.2))
    write("pause", Mix(0.8).add(note("vibes", "E5", 0.3, 0.7)).add(note("vibes", "B4", 0.4, 0.6), 0.08)
          .render(0.6, tail=0.2))
    # page turn / pop-up book swish
    pg = Mix(1.0)
    pg.add(noise_burst(0.35, 0.6, lp=0.35, decay=8), 0.0)
    pg.add(note("gliss_up", None, 0.3, 0.25), 0.05)
    write("page_turn", pg.render(0.6, reverb=0.08, tail=0.1))
    # iris transitions
    write("transition_close", Mix(0.8).add(note("gliss_down", None, 0.4, 0.4)).render(0.4, tail=0.1))
    write("transition_open", Mix(0.8).add(note("gliss_up", None, 0.35, 0.35)).render(0.35, tail=0.1))
    # coins / tally / stage popups
    st = Mix(1.2)
    arp(st, "steelpan", ["C5", "G5", "C6"], step=0.06, dur=0.4, vel=0.7)
    write("stage_pop", st.render(0.7))
    write("pop", Mix(0.3).add(note("sine", "C6", 0.08, 0.8, bend=40)).render(0.5, reverb=0.03, tail=0.05))
    write("danger", Mix(1.0).add(note("bell", "F5", 0.25, 0.6)).add(note("bell", "F5", 0.25, 0.5), 0.3)
          .render(0.5, tail=0.15))


# raw PM64 effects copied as a library (bank -> instruments to keep, or all)
LIB_BANKS = ["17", "18", "19", "1A", "1B", "1C", "1F", "26", "29", "2A", "34", "35", "38", "39", "42", "47"]


def build_library():
    LIB.mkdir(parents=True, exist_ok=True)
    names = []
    for b in LIB_BANKS:
        for f in sorted((SAMPLES / "sfx").glob(f"BANK_{b}_INSTR_*_SND_0000*.wav")):
            a, sr = read_wav(f)
            if len(a) < 200:
                continue
            m = np.max(np.abs(a)) + 1e-9
            a = a * (0.89 / m)
            inst_id = f.stem.split("_")[3]
            extra = "_" + f.stem.split("_")[-1] if f.stem.endswith(("16k", "22k")) else ""
            name = f"{b}_{inst_id}{extra}".lower()
            pcm = (np.clip(a, -1, 1) * 32767).astype("<i2")
            with wave.open(str(LIB / f"{name}.wav"), "wb") as w:
                w.setnchannels(1)
                w.setsampwidth(2)
                w.setframerate(sr)
                w.writeframes(pcm.tobytes())
            names.append(name)
    return names


def build_catalog(lib_names):
    d = lambda n: f"res://assets/sfx/{n}.wav"
    p = lambda n: f"res://assets/sfx/pm/{n}.wav"
    cat = {
        "move": {"file": d("move"), "volume_db": -6.0, "pitch_var": 0.02},
        "rotate": {"file": d("rotate"), "volume_db": -5.0, "pitch_var": 0.02},
        "rotate_fail": {"file": d("rotate_fail"), "volume_db": -8.0},
        "soft_drop": {"file": d("soft_drop"), "volume_db": -14.0},
        "lock": {"file": d("lock"), "volume_db": -5.0, "pitch_var": 0.03},
        "hard_drop": {"file": d("hard_drop"), "volume_db": -2.0, "pitch_var": 0.03},
        "hold": {"file": d("hold"), "volume_db": -4.0},
        "clear1": {"file": d("clear1"), "volume_db": -3.0},
        "clear2": {"file": d("clear2"), "volume_db": -3.0},
        "clear3": {"file": d("clear3"), "volume_db": -2.0},
        "clear4": {"file": d("clear4"), "volume_db": -1.0},
        "tspin": {"file": d("tspin"), "volume_db": -2.0},
        "b2b": {"file": d("b2b"), "volume_db": -4.0},
        "combo": {"file": d("combo"), "volume_db": -5.0, "stack": True},
        "perfect": {"file": d("perfect"), "volume_db": 0.0},
        "level_up": {"file": d("level_up"), "volume_db": -2.0},
        "count": {"file": d("count"), "volume_db": -3.0},
        "go": {"file": d("go"), "volume_db": -2.0},
        "victory": {"file": d("victory"), "volume_db": 0.0},
        "game_over": {"file": d("game_over"), "volume_db": 0.0},
        "new_record": {"file": d("new_record"), "volume_db": -2.0},
        "tally": {"file": d("tally"), "volume_db": -10.0, "stack": True},
        "menu_move": {"file": d("menu_move"), "volume_db": -4.0},
        "menu_select": {"file": d("menu_select"), "volume_db": -3.0},
        "menu_back": {"file": d("menu_back"), "volume_db": -4.0},
        "menu_deny": {"file": d("menu_deny"), "volume_db": -5.0},
        "menu_tick": {"file": d("menu_tick"), "volume_db": -6.0, "stack": True},
        "window_open": {"file": d("window_open"), "volume_db": -6.0},
        "window_close": {"file": d("window_close"), "volume_db": -7.0},
        "pause": {"file": d("pause"), "volume_db": -4.0},
        "page_turn": {"file": d("page_turn"), "volume_db": -6.0},
        "transition_close": {"file": d("transition_close"), "volume_db": -10.0},
        "transition_open": {"file": d("transition_open"), "volume_db": -10.0},
        "stage_pop": {"file": d("stage_pop"), "volume_db": -6.0},
        "pop": {"file": d("pop"), "volume_db": -9.0, "pitch_var": 0.1, "stack": True},
        "danger": {"file": d("danger"), "volume_db": -8.0},
        # raw Paper Mario 64 effects (decor and flourishes)
        "pm_happy_chime": {"file": p("17_0000"), "volume_db": -6.0},
        "pm_boing": {"file": p("18_0000"), "volume_db": -12.0, "pitch_var": 0.08, "stack": True},
        "pm_jump": {"file": p("1c_0001"), "volume_db": -14.0, "pitch_var": 0.08, "stack": True},
        "pm_twinkle": {"file": p("1b_0009"), "volume_db": -8.0},
        "pm_ching": {"file": p("1a_000d"), "volume_db": -8.0},
        "pm_fanfare": {"file": p("47_0001"), "volume_db": -4.0},
        "pm_cheer": {"file": p("35_0008"), "volume_db": -10.0},
        "pm_lucky": {"file": p("38_0001"), "volume_db": -6.0},
        "pm_scream": {"file": p("42_000d"), "volume_db": -14.0, "pitch_var": 0.1, "stack": True},
        "pm_balloon_pop": {"file": p("39_0003"), "volume_db": -10.0},
        "pm_paper": {"file": p("29_000f"), "volume_db": -10.0},
    }
    for k, v in cat.items():
        path = Path(str(v["file"]).replace("res://", str(ROOT / "game") + "/"))
        if not path.exists():
            raise SystemExit(f"missing {k}: {path}")
    CATALOG.write_text(json.dumps(cat, indent=1), encoding="utf-8")
    (ROOT / "game" / "data" / "sfx_library.json").write_text(
        json.dumps(sorted(lib_names) + [], indent=0), encoding="utf-8")


if __name__ == "__main__":
    build_designed()
    names = build_library()
    build_catalog(names)
    print("designed sfx + library:", len(names))
