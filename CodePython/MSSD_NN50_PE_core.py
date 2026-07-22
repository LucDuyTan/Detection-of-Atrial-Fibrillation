import json
import math
from dataclasses import dataclass
from pathlib import Path
from typing import Any, Dict, List, Optional, Set, Tuple
from collections import defaultdict, Counter

import numpy as np
import wfdb


# ------------------- Config -------------------
@dataclass(frozen=True)
class Config:
    data_dir: str
    window_sec: int = 10
    hop_sec: int = 5 
    signals_unavailable: Set[str] = frozenset()
    random_seed: int = 42


# ------------------- Caches -------------------
_HDR_CACHE: Dict[str, Tuple[int, int]] = {}
_RPEAK_CACHE: Dict[str, Tuple[Optional[np.ndarray], str]] = {}
_ATR_CACHE: Dict[str, Tuple[List["RhythmInterval"], int, int]] = {}

def clear_caches():
    _HDR_CACHE.clear()
    _RPEAK_CACHE.clear()
    _ATR_CACHE.clear()

def _get_fs_siglen_cached(record_base: str) -> Tuple[int, int]:
    if record_base in _HDR_CACHE:
        return _HDR_CACHE[record_base]
    header = wfdb.rdheader(record_base)
    fs = int(round(header.fs))
    sig_len = int(header.sig_len)
    _HDR_CACHE[record_base] = (fs, sig_len)
    return fs, sig_len

# ------------------- Record utils -------------------
def list_local_record_bases(cfg: Config) -> List[str]:
    p = Path(cfg.data_dir)
    if not p.exists():
        raise FileNotFoundError(f"DATA_DIR not found: {cfg.data_dir}")

    stems = sorted({x.stem for x in p.glob("*.hea")})
    bases: List[str] = []
    for s in stems:
        if s in cfg.signals_unavailable:
            continue
        base = p / s
        if base.with_suffix(".dat").exists() and base.with_suffix(".atr").exists():
            bases.append(str(base))
    return bases

def read_rpeaks_qrsc_else_qrs(record_base: str) -> Tuple[Optional[np.ndarray], str]:
    if record_base in _RPEAK_CACHE:
        return _RPEAK_CACHE[record_base]
    base = Path(record_base)
    if base.with_suffix(".qrsc").exists():
        ann = wfdb.rdann(record_base, "qrsc")
        r = np.asarray(ann.sample, dtype=int); r.sort()
        _RPEAK_CACHE[record_base] = (r, "qrsc")
        return r, "qrsc"
    if base.with_suffix(".qrs").exists():
        ann = wfdb.rdann(record_base, "qrs")
        r = np.asarray(ann.sample, dtype=int); r.sort()
        _RPEAK_CACHE[record_base] = (r, "qrs")
        return r, "qrs"
    _RPEAK_CACHE[record_base] = (None, "none")
    return None, "none"

@dataclass(frozen=True)
class RhythmInterval:
    start: int
    end: int
    rhythm: str

def _clean_aux_note(note: str) -> str:
    if not note: return ""
    note = note.replace("\x00", "").strip()
    if note.startswith("("): note = note[1:].strip()
    return note.replace(")", "").strip()

def build_rhythm_intervals(record_base: str) -> Tuple[List[RhythmInterval], int, int]:
    if record_base in _ATR_CACHE: return _ATR_CACHE[record_base]
    fs, sig_len = _get_fs_siglen_cached(record_base)
    ann = wfdb.rdann(record_base, extension="atr")
    events: List[Tuple[int, str]] = []
    for s, aux in zip(ann.sample, ann.aux_note):
        aux = (aux or "").replace("\x00", "").strip()
        if aux.startswith("("):
            lab = _clean_aux_note(aux)
            if lab: events.append((int(s), lab))
    events.sort(key=lambda x: x[0])
    intervals: List[RhythmInterval] = []
    current = "N"; start = 0
    for s, lab in events:
        s = max(0, min(sig_len, int(s)))
        if s > start: intervals.append(RhythmInterval(start=start, end=s, rhythm=current))
        current = lab; start = s
    if start < sig_len: intervals.append(RhythmInterval(start=start, end=sig_len, rhythm=current))
    if not intervals: intervals = [RhythmInterval(start=0, end=sig_len, rhythm="N")]
    _ATR_CACHE[record_base] = (intervals, fs, sig_len)
    return intervals, fs, sig_len

def iter_window_starts(itv_start: int, itv_end: int, win: int, hop: int):
    last = itv_end - win
    s = itv_start
    while s <= last:
        yield s
        s += hop

# ------------------- Build windows -------------------
def build_AF_windows(record_bases: List[str], cfg: Config) -> List[Tuple[str, int]]:
    af_set: Set[str] = {"AFIB"}
    AF: List[Tuple[str, int]] = []
    for rec_base in record_bases:
        intervals, fs, _ = build_rhythm_intervals(rec_base)
        win = cfg.window_sec * fs
        hop = cfg.hop_sec * fs
        for itv in intervals:
            if (itv.rhythm or "").upper() not in af_set: continue
            for s in iter_window_starts(itv.start, itv.end, win, hop):
                AF.append((rec_base, int(s)))
    AF.sort(key=lambda x: (Path(x[0]).name, x[1]))
    return AF

def _rr_qc_metrics(rpeaks_in_win: np.ndarray, fs: int, hr_min: float, hr_max: float) -> Optional[Dict[str, float]]:
    if rpeaks_in_win.size < 4: return None
    rr = np.diff(rpeaks_in_win) / fs
    if rr.size < 3 or np.any(rr <= 0): return None
    hr = 60.0 / rr
    hr_mean = float(np.mean(hr))
    if not (hr_min <= hr_mean <= hr_max): return None
    med = float(np.median(rr))
    if med <= 0: return None
    outlier = np.abs(rr - med) > (0.20 * med)
    outlier_ratio = float(np.mean(outlier))
    sdnn = float(np.std(rr))
    return {"hr_mean": hr_mean, "sdnn": sdnn, "outlier_ratio": outlier_ratio}

def _naf_quality_score(m: Dict[str, float]) -> float:
    return (m["sdnn"] * 1.0) + (m["outlier_ratio"] * 1.0) + (abs(m["hr_mean"] - 60.0) / 60.0 * 0.1)

def build_NAF_windows_best_k(record_bases: List[str], cfg: Config, target_k: int, margin_sec: int, adaptive_margin: bool, hr_min: float, hr_max: float, outlier_ratio_max: float, sdnn_max: float) -> Tuple[List[Tuple[str, int]], Dict[str, int]]:
    cand = []; total_windows = 0; pass_qc = 0
    for rec_base in record_bases:
        intervals, fs, _ = build_rhythm_intervals(rec_base)
        win = cfg.window_sec * fs; hop = cfg.hop_sec * fs
        rpeaks, _ = read_rpeaks_qrsc_else_qrs(rec_base)
        if rpeaks is None: continue
        for itv in intervals:
            if (itv.rhythm or "").upper() != "N": continue
            itv_len = itv.end - itv.start; margin = margin_sec * fs
            if adaptive_margin: margin = min(margin, max(0, (itv_len - win) // 2))
            core_start = itv.start + margin; core_end = itv.end - margin
            if core_end - core_start < win: continue
            for s in iter_window_starts(core_start, core_end, win, hop):
                total_windows += 1; e = s + win
                i0 = int(np.searchsorted(rpeaks, s, side="left"))
                i1 = int(np.searchsorted(rpeaks, e, side="left"))
                rp = rpeaks[i0:i1]
                m = _rr_qc_metrics(rp, fs, hr_min=hr_min, hr_max=hr_max)
                if m is None or m["outlier_ratio"] > outlier_ratio_max or m["sdnn"] > sdnn_max: continue
                pass_qc += 1; score = _naf_quality_score(m)
                cand.append((score, Path(rec_base).name, int(s), rec_base))
    cand.sort(key=lambda x: (x[0], x[1], x[2]))
    picked = cand[:target_k]
    windows = [(rec_base_full, s) for _, _, s, rec_base_full in picked]
    return windows, {"naf_total_windows_scanned": total_windows, "naf_pass_qc": pass_qc, "naf_candidate_count": len(cand), "naf_selected_k": len(windows)}


# ------------------- Features -------------------

def mssd(rr: np.ndarray) -> float:
    """
    Mean Square Successive Difference (MSSD)
    Đo lường biên độ biến thiên nhịp tim (Đơn vị: s^2).
    """
    if len(rr) < 2: return 0.0
    diffs = np.diff(rr)
    return float(np.mean(np.square(diffs)))


def nn50(rr: np.ndarray) -> float:
    """Đếm số khoảng lệch nhịp kế tiếp vượt quá 0.05 giây (tương đương 50 ms)"""
    if len(rr) < 2: return 0.0
    diffs = np.abs(np.diff(rr))
    nn50_count = np.sum(diffs > 0.05) 
    return float(nn50_count)


def permutation_entropy(rr: np.ndarray, m: int = 3, tau: int = 1) -> float:
    """Permutation Entropy (PE) - Triển khai bằng LUT trên Verilog"""
    n = len(rr)
    if n < m: return 0.0
    patterns = []
    for i in range(n - (m - 1) * tau):
        sub_seq = rr[i : i + m * tau : tau]
        pattern = tuple(np.argsort(sub_seq))
        patterns.append(pattern)
    counts = Counter(patterns)
    total_patterns = len(patterns)
    pe = 0.0
    for count in counts.values():
        p = count / total_patterns
        pe -= p * math.log2(p)
    return float(pe)


def _compute_3_features(rpeaks: np.ndarray, fs: int, start_sample: int, cfg: Config) -> Optional[Tuple[float, float, float]]:
    """Tính toán 3 đặc trưng : MSSD, NN50, PE theo đơn vị giây (s)"""
    win = cfg.window_sec * fs
    s = int(start_sample); e = s + win
    i0 = int(np.searchsorted(rpeaks, s, side="left"))
    i1 = int(np.searchsorted(rpeaks, e, side="left"))
    rp = rpeaks[i0:i1]
    
    if rp.size < 4: return None
    rr = np.diff(rp) / float(fs)
    if rr.size < 3: return None

    feat1_mssd = mssd(rr)
    feat2_nn50 = float(nn50(rr)) 
    feat3_pe = permutation_entropy(rr, m=3, tau=1)
    return (feat1_mssd, feat2_nn50, feat3_pe)


def build_xy_from_windows(windows: List[Tuple[str, int]], label: int, cfg: "Config") -> Tuple[np.ndarray, np.ndarray, Dict[str, Any]]:
    """X: (N, 3) chứa (MSSD, NN50, PE) tính bằng đơn vị giây (s)"""
    feats = []; kept = 0
    by_rec = defaultdict(list)
    for rec_base, s in windows: by_rec[rec_base].append(int(s))
    for rec_base, starts in by_rec.items():
        fs, _ = _get_fs_siglen_cached(rec_base)
        rpeaks, _ = read_rpeaks_qrsc_else_qrs(rec_base)
        if rpeaks is None: continue
        for s in starts:
            f = _compute_3_features(rpeaks, fs, s, cfg)
            if f is None: continue
            feats.append(f); kept += 1
    X = np.array(feats, dtype=np.float64) if feats else np.empty((0, 3), dtype=np.float64)
    y = np.full((len(X),), int(label), dtype=np.int64)
    return X, y, {"total": len(windows), "kept": kept, "dropped": len(windows) - kept}

# ------------------- Metrics -------------------
def paper_metrics(y_true: np.ndarray, y_pred: np.ndarray) -> Dict[str, float]:
    y_true = y_true.astype(int); y_pred = y_pred.astype(int)
    tp = int(np.sum((y_true == 1) & (y_pred == 1)))
    tn = int(np.sum((y_true == 0) & (y_pred == 0)))
    fp = int(np.sum((y_true == 0) & (y_pred == 1)))
    fn = int(np.sum((y_true == 1) & (y_pred == 0)))
    denom = tp + tn + fp + fn
    return {
        "TP": tp, "TN": tn, "FP": fp, "FN": fn,
        "ACC(%)": (tp + tn) / denom * 100.0 if denom else 0,
        "Precision(%)": tp / (tp + fp) * 100.0 if (tp + fp) else 0,
        "Specificity(%)": tn / (tn + fp) * 100.0 if (tn + fp) else 0,
        "Sensitivity(%)": tp / (tp + fn) * 100.0 if (tp + fn) else 0,
    }

def save_json(path: str, obj: dict) -> None:
    Path(path).write_text(json.dumps(obj, indent=2, ensure_ascii=False), encoding="utf-8")
def load_json(path: str) -> dict:
    return json.loads(Path(path).read_text(encoding="utf-8"))
