"""Audio helpers: decode with ffmpeg into numpy, find loop points."""
from __future__ import annotations

import subprocess
from pathlib import Path

import numpy as np

from paths import OST  # noqa: E402  (original soundtrack, see paths.py)
PREFIX = "Mario Story Original Sound Track - Yuka Tsujiyoko - "


def track_path(title: str) -> Path:
    return OST / f"{PREFIX}{title}.flac"


def decode(path: Path, sr: int = 44100, mono: bool = False) -> np.ndarray:
    ch = 1 if mono else 2
    cmd = ["ffmpeg", "-v", "error", "-i", str(path), "-f", "f32le", "-acodec", "pcm_f32le",
           "-ac", str(ch), "-ar", str(sr), "-"]
    raw = subprocess.run(cmd, capture_output=True, check=True).stdout
    a = np.frombuffer(raw, dtype=np.float32)
    return a.reshape(-1, ch) if not mono else a


def rms_env(x: np.ndarray, sr: int, win: float = 0.05) -> np.ndarray:
    n = int(sr * win)
    m = len(x) // n
    seg = x[: m * n].reshape(m, n)
    return np.sqrt(np.mean(seg ** 2, axis=1) + 1e-12)


def silences(x: np.ndarray, sr: int, thresh_db: float = -50, min_len: float = 0.35):
    env = rms_env(x, sr)
    db = 20 * np.log10(env)
    quiet = db < thresh_db
    out = []
    i = 0
    while i < len(quiet):
        if quiet[i]:
            j = i
            while j < len(quiet) and quiet[j]:
                j += 1
            if (j - i) * 0.05 >= min_len:
                out.append((i * 0.05, j * 0.05))
            i = j
        else:
            i += 1
    return out


def spectral_frames(x: np.ndarray, sr: int, hop: int = 512, nfft: int = 2048) -> np.ndarray:
    n = (len(x) - nfft) // hop
    idx = np.arange(nfft)[None, :] + hop * np.arange(n)[:, None]
    win = np.hanning(nfft).astype(np.float32)
    frames = x[idx] * win
    spec = np.abs(np.fft.rfft(frames, axis=1))
    # compress to log bands
    bands = np.logspace(np.log10(3), np.log10(nfft // 2), 48).astype(int)
    feats = np.add.reduceat(spec, np.unique(bands), axis=1)
    feats = np.log1p(feats)
    feats -= feats.mean(axis=1, keepdims=True)
    norm = np.linalg.norm(feats, axis=1, keepdims=True) + 1e-9
    return feats / norm


def _longest_run(good: np.ndarray, gap: int):
    """Longest run of True allowing internal False gaps up to `gap` frames."""
    best_len, best_start = 0, 0
    cur_start, last_true, in_run = 0, -10**9, False
    for i, g in enumerate(good):
        if g:
            if not in_run or i - last_true > gap + 1:
                cur_start = i
                in_run = True
            last_true = i
            if last_true - cur_start + 1 > best_len:
                best_len = last_true - cur_start + 1
                best_start = cur_start
    return best_len, best_start


def loop_candidates(mono: np.ndarray, sr: int, min_loop: float = 12.0, thr: float = 0.88,
                    min_run: float = 5.0, top: int = 10):
    """Spectral pre-selection: lags whose matching run is long. [(R_s, lag_s, start_s)]"""
    hop = 256
    f = spectral_frames(mono, sr, hop=hop, nfft=1024)
    fps = sr / hop
    n = len(f)
    min_lag = int(min_loop * fps)
    max_lag = int(n * 0.85)
    gap = int(0.6 * fps)
    runs = np.zeros(max_lag + 1)
    starts = np.zeros(max_lag + 1, int)
    for lag in range(min_lag, max_lag):
        s = np.einsum("ij,ij->i", f[: n - lag], f[lag:])
        good = s > thr
        if good.sum() < min_run * fps:
            continue
        R, st = _longest_run(good, gap)
        runs[lag] = R
        starts[lag] = st
    # local maxima
    peaks = []
    for lag in range(min_lag + 1, max_lag - 1):
        if runs[lag] >= min_run * fps and runs[lag] >= runs[lag - 1] and runs[lag] >= runs[lag + 1]:
            if peaks and lag - peaks[-1][1] < 3:
                if runs[lag] > peaks[-1][0]:
                    peaks[-1] = (runs[lag], lag, starts[lag])
                continue
            peaks.append((runs[lag], lag, starts[lag]))
    peaks.sort(reverse=True)
    return [(R / fps, lag / fps, st / fps) for R, lag, st in peaks[:top]]


def find_loop(stereo: np.ndarray, sr: int, mono_lo: np.ndarray, sr_lo: int):
    """Return dict(start, lag_samples, corr, run) choosing the sample-exact repeat."""
    cands = loop_candidates(mono_lo, sr_lo)
    scored = []
    for R, lag, st in cands:
        mid = st + max(0.0, min(R - 2.0, R * 0.5) - 0.75)
        lag_s, corr = refine_sample(stereo, sr, mid - 2.0, lag)
        scored.append({"run": R, "lag": lag_s, "start": st, "corr": corr})
    if not scored:
        return None
    exact = [c for c in scored if c["corr"] >= 0.95]
    if exact:
        best = max(exact, key=lambda c: c["run"])
    else:
        ok = [c for c in scored if c["corr"] >= 0.6]
        best = max(ok or scored, key=lambda c: (c["run"] if ok else c["corr"]))
    best["all"] = scored
    return best


def refine_sample(stereo: np.ndarray, sr: int, start_s: float, lag_s: float, search: float = 0.03):
    """Refine the lag to sample accuracy by cross-correlating a window."""
    mono = stereo.mean(axis=1)
    st = int((start_s + 2.0) * sr)
    w = int(1.5 * sr)
    ref = mono[st: st + w]
    lag0 = int(lag_s * sr)
    rad = int(search * sr)
    seg = mono[st + lag0 - rad: st + lag0 + rad + w]
    if len(seg) < w + 2 * rad or len(ref) < w:
        return lag0, 0.0
    # FFT cross-correlation
    nfft = 1 << int(np.ceil(np.log2(len(seg) + w)))
    c = np.fft.irfft(np.fft.rfft(seg, nfft) * np.conj(np.fft.rfft(ref, nfft)), nfft)[: 2 * rad + 1]
    k = int(np.argmax(c))
    lag = lag0 - rad + k
    a = mono[st: st + w]
    b = mono[st + lag: st + lag + w]
    corr = float(np.dot(a, b) / (np.linalg.norm(a) * np.linalg.norm(b) + 1e-9))
    return lag, corr
