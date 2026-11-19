"""Convert the selected OST tracks (FLAC) into OGG files the game plays whole.

No loop points any more: a CD recording's own repeat is never quite the same
twice, and splicing it back on itself was audible. Each track is kept from
its first note to the start of its fade-out; the AudioManager crossfades it
into the next track of its playlist (every stage pairs two similar themes,
other music crossfades into itself). Loudness is normalised, metadata goes
to game/data/music.json.

Usage: python build_music.py [track_id ...]
"""
import json
import subprocess
import sys
import tempfile
import wave
from pathlib import Path

import numpy as np

from audio_lib import decode, track_path

ROOT = Path(__file__).resolve().parent.parent
OUT_DIR = ROOT / "game" / "assets" / "music"
CATALOG = ROOT / "game" / "data" / "music.json"
SR = 44100

# id -> (OST title, display name, loop?)  -- the display names are shown in the jukebox.
TRACKS = {
    "menu_toybox": ("Shy Guy's Toy Box", "Shy Guy's Toy Box", True),
    "stage_toybox": ("Go! Go! By Toy Train", "Go! Go! By Toy Train", True),
    "stage_meadow": ("Over Field and Stream", "Over Field and Stream", True),
    "stage_flowers": ("Flower Rondo", "Flower Rondo", True),
    "stage_desert": ("Traversing Dry-Dry Desert", "Traversing Dry-Dry Desert", True),
    "stage_jungle": ("The Neverending Jungle by the Waterside", "Jungle by the Waterside", True),
    "stage_volcano": ("The Burning Hot Volcano Cavern", "Burning Hot Volcano Cavern", True),
    "stage_snow": ("Shiver Snowfield", "Shiver Snowfield", True),
    "stage_stars": ("Shooting Star Summit", "Shooting Star Summit", True),
    "stage_bowser": ("The Terrible Bowser's Castle", "The Terrible Bowser's Castle", True),
    "mode_sprint": ("A Shy Guy Riot - There's Trouble in the City!", "A Shy Guy Riot!", True),
    "mode_ultra": ("Fall in Step and Let's Go", "Fall in Step and Let's Go", True),
    "results_clear": ("Now That That's Over With...", "Now That That's Over With...", True),
    "results_over": ("Downhearted Peach", "Downhearted Peach", True),
    "credits": ("The Parade Continues", "The Parade Continues", True),
    "extra_forest": ("Lost in the Forever Forest", "Lost in the Forever Forest", True),
    "extra_crystal": ("Crystal Palace", "Crystal Palace", True),
    "extra_koopa": ("Koopa Village", "Koopa Village", True),
    "extra_goomba": ("Sunny Goomba Village", "Sunny Goomba Village", True),
    "extra_starroad": ("Star Road", "Star Road", True),
    "extra_party": ("Princess Peach's Party", "Princess Peach's Party", True),
    "extra_general": ("General Guy Appears", "General Guy Appears", True),
    "extra_peaceful": ("Peaceful Mushroom Kingdom", "Peaceful Mushroom Kingdom", True),
    "extra_outpost": ("Dry-Dry Outpost", "Dry-Dry Outpost", True),
    "extra_shiver": ("Snow Falls on Shiver City", "Snow Falls on Shiver City", True),
    "extra_beginning": ("It's the Beginning!", "It's the Beginning!", True),
    "extra_train": ("Mt. Rugged's Pretty Rugged", "Mt. Rugged's Pretty Rugged", True),
    "extra_bowser": ("Bowser, My Old Enemy!", "Bowser, My Old Enemy!", True),
    "extra_yoshi": ("Welcome to Yoshi Village", "Welcome to Yoshi Village", True),
    "extra_lavalava": ("Escape from Mt. Lavalava", "Escape from Mt. Lavalava", True),
    "extra_starhaven": ("Star Haven", "Star Haven", True),
}

TARGET_RMS_DB = -17.0
WIN = 0.25          # s, loudness window for the fade-out search
TAIL = 0.6          # s kept after the last full-level window, faded to silence


def write_wav(path: Path, data: np.ndarray):
    pcm = np.clip(data, -1.0, 1.0)
    pcm = (pcm * 32767.0).astype("<i2")
    with wave.open(str(path), "wb") as w:
        w.setnchannels(2)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(pcm.tobytes())


def _body_range(stereo: np.ndarray) -> tuple[int, int]:
    """First note .. start of the CD fade-out (plus a short tail)."""
    mono = np.abs(stereo).mean(axis=1)
    n = int(WIN * SR)
    k = len(mono) // n
    rms = np.sqrt((mono[:k * n].reshape(k, n) ** 2).mean(axis=1))
    ref = float(np.median(rms[: max(1, int(k * 0.8))]))
    loud = np.nonzero(rms >= ref * 0.5)[0]
    first = int(np.nonzero(mono > 0.004)[0][0]) if np.any(mono > 0.004) else 0
    last = (int(loud[-1]) + 1) * n if len(loud) else len(mono)
    return max(0, first - int(0.02 * SR)), min(len(mono), last + int(TAIL * SR))


def process(tid: str, catalog: dict):
    title, display, _ = TRACKS[tid]
    stereo = decode(track_path(title), SR)
    a, b = _body_range(stereo)
    stereo = stereo[a:b].copy()
    t = int(TAIL * SR)
    stereo[-t:] *= np.linspace(1.0, 0.0, t, dtype=np.float32)[:, None]
    info = {"title": display, "source": title}
    rms = float(np.sqrt(np.mean(stereo ** 2)) + 1e-9)
    gain = 10 ** (TARGET_RMS_DB / 20) / rms
    peak = float(np.max(np.abs(stereo))) * gain
    if peak > 0.98:
        gain *= 0.98 / peak
    stereo = stereo * gain
    info["gain_db"] = round(20 * np.log10(gain), 2)
    OUT_DIR.mkdir(parents=True, exist_ok=True)
    with tempfile.TemporaryDirectory() as td:
        wav = Path(td) / "t.wav"
        write_wav(wav, stereo)
        ogg = OUT_DIR / f"{tid}.ogg"
        subprocess.run(["ffmpeg", "-v", "error", "-y", "-i", str(wav), "-c:a", "libvorbis", "-q:a", "3", str(ogg)],
                       check=True)
    info["file"] = f"res://assets/music/{tid}.ogg"
    info["duration"] = round(len(stereo) / SR, 3)
    catalog[tid] = info
    print(f"{tid:16s} {info['duration']:7.2f}s (cut {a / SR:.2f}..{b / SR:.2f}) gain {info['gain_db']:+.1f} dB")


def main():
    ids = sys.argv[1:] or list(TRACKS)
    catalog = json.loads(CATALOG.read_text(encoding="utf-8")) if CATALOG.exists() else {}
    for tid in ids:
        process(tid, catalog)
    CATALOG.parent.mkdir(parents=True, exist_ok=True)
    ordered = {k: catalog[k] for k in TRACKS if k in catalog}
    CATALOG.write_text(json.dumps(ordered, indent=1, ensure_ascii=False), encoding="utf-8")


if __name__ == "__main__":
    main()
