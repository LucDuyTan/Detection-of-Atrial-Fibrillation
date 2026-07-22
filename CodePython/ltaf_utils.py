# ltaf_utils_hwsvm.py
"""Utilities for LTAFDB window selection.

Key additions vs a naive "full 10s inside interval" cutter:
- margin_sec (avoid rhythm-transition boundaries)
- symbol-based drops using .qrs/.qrsc (drop '|' and 'T' markers)
- stricter negative (N) filtering:
    * optional "pure N" windows only (no other beat symbols)
    * optional RR-QC thresholds (hr_mean range, outlier_ratio, SDNN)
    * optional naf_score_max (single scalar that captures 'clean-ness' of N)
- optional target_af/target_n and stratified selection
"""

from __future__ import annotations

from pathlib import Path
from typing import Dict, List, Optional, Set, Tuple

import numpy as np
import wfdb

from MSSD_NN50_PE_core import Config, build_rhythm_intervals, iter_window_starts, read_rpeaks_qrsc_else_qrs


def list_record_bases(data_dir: str, signals_unavailable: Set[str]) -> List[str]:
    """List WFDB record_base in a folder (path without extension) requiring .hea + .dat + .atr."""
    p = Path(data_dir)
    if not p.exists():
        raise FileNotFoundError(f"DATA_DIR not found: {data_dir}")

    stems = sorted({x.stem for x in p.glob("*.hea")})
    out: List[str] = []
    for s in stems:
        if s in signals_unavailable:
            continue
        base = p / s
        if base.with_suffix(".dat").exists() and base.with_suffix(".atr").exists():
            out.append(str(base))
    return out


def read_qrs_annotation_for_noise(record_base: str) -> Tuple[Optional[np.ndarray], Optional[np.ndarray], str]:
    """Noise check annotation.

    Prefer .qrs (often contains '|' and 'T'), fallback .qrsc.
    Returns: (samples_sorted, symbols_sorted, src_ext)
    """
    base = Path(record_base)
    for ext in ["qrs", "qrsc"]:
        if base.with_suffix(f".{ext}").exists():
            ann = wfdb.rdann(record_base, ext)
            samples = np.asarray(ann.sample, dtype=int)

            sym = getattr(ann, "symbol", None)
            if sym is None or len(sym) == 0:
                symbols = np.array(["N"] * len(samples), dtype=object)
            else:
                symbols = np.asarray(sym, dtype=object)

            order = np.argsort(samples)
            return samples[order], symbols[order], ext

    return None, None, "none"


def _slice_symbols(qrs_samples: np.ndarray, qrs_symbols: np.ndarray, s: int, e: int) -> np.ndarray:
    i0 = int(np.searchsorted(qrs_samples, s, side="left"))
    i1 = int(np.searchsorted(qrs_samples, e, side="left"))
    return qrs_symbols[i0:i1]


def window_has_symbol(qrs_samples: np.ndarray, qrs_symbols: np.ndarray, s: int, e: int, target_symbol: str) -> bool:
    sym = _slice_symbols(qrs_samples, qrs_symbols, s, e)
    return bool(np.any(sym == target_symbol))


def count_beats_in_window(qrs_samples: np.ndarray, qrs_symbols: np.ndarray, s: int, e: int, beat_symbol: str = "N") -> int:
    sym = _slice_symbols(qrs_samples, qrs_symbols, s, e)
    return int(np.sum(sym == beat_symbol))


def window_is_pure_symbol(qrs_samples: np.ndarray, qrs_symbols: np.ndarray, s: int, e: int, keep_symbol: str = "N") -> bool:
    sym = _slice_symbols(qrs_samples, qrs_symbols, s, e)
    if sym.size == 0:
        return False
    return bool(np.all(sym == keep_symbol))


def _rr_qc_metrics(rpeaks_in_win: np.ndarray, fs: int, hr_min: float, hr_max: float) -> Optional[Dict[str, float]]:
    """Compute RR quality metrics; returns None if basic QC fails."""
    rpeaks_in_win = np.asarray(rpeaks_in_win, dtype=int)
    if rpeaks_in_win.size < 4:
        return None

    rr = np.diff(rpeaks_in_win) / float(fs)
    if rr.size < 3 or np.any(rr <= 0):
        return None

    hr = 60.0 / rr
    hr_mean = float(np.mean(hr))
    if not (hr_min <= hr_mean <= hr_max):
        return None

    med = float(np.median(rr))
    if med <= 0:
        return None

    outlier = np.abs(rr - med) > (0.20 * med)
    outlier_ratio = float(np.mean(outlier))
    sdnn = float(np.std(rr))

    return {"hr_mean": hr_mean, "sdnn": sdnn, "outlier_ratio": outlier_ratio}


def _naf_quality_score(m: Dict[str, float]) -> float:
    """Single scalar: lower = cleaner N window."""
    hr_mean = float(m.get("hr_mean", 60.0))
    sdnn = float(m.get("sdnn", 0.0))
    outlier_ratio = float(m.get("outlier_ratio", 0.0))
    return sdnn + outlier_ratio + (0.1 * abs(hr_mean - 60.0) / 60.0)


def build_ltaf_full10s_windows(
    record_bases: List[str],
    cfg: Config,
    *,
    fs_target_for_index: int = 250,
    drop_if_artifact_bar: bool = True,
    drop_if_t_marker: bool = True,
    min_beats_in_10s: int = 7,
    print_per_record: bool = False,
) -> Tuple[List[Tuple[str, int]], List[Tuple[str, int]], Dict[str, object]]:
    """Legacy/simple cutter: full 10s windows entirely inside AF or N rhythm intervals."""

    af_set: Set[str] = {"AFIB"}

    cand = {"AF": 0, "N": 0}
    kept = {"AF": 0, "N": 0}
    dropped_reasons: Dict[str, int] = {}
    dropped_by_label: Dict[str, Dict[str, int]] = {"AF": {}, "N": {}}

    AF_kept: List[Tuple[str, int]] = []
    N_kept: List[Tuple[str, int]] = []

    def add_drop(label: str, reason: str, rec_drop: Optional[Dict[str, int]] = None):
        dropped_reasons[reason] = dropped_reasons.get(reason, 0) + 1
        d = dropped_by_label[label]
        d[reason] = d.get(reason, 0) + 1
        if rec_drop is not None:
            rec_drop[reason] = rec_drop.get(reason, 0) + 1

    for rec_base in record_bases:
        rec_name = Path(rec_base).name
        intervals, fs, _sig_len = build_rhythm_intervals(rec_base)
        win = int(cfg.window_sec * fs)
        hop = int(cfg.window_sec * fs)

        qrs_samples, qrs_symbols, qrs_src = read_qrs_annotation_for_noise(rec_base)

        rec_cand = {"AF": 0, "N": 0}
        rec_kept = {"AF": 0, "N": 0}
        rec_drop: Dict[str, int] = {}

        for itv in intervals:
            r = (itv.rhythm or "").upper()
            if r in af_set:
                label = "AF"
            elif r == "N":
                label = "N"
            else:
                continue

            for s in iter_window_starts(itv.start, itv.end, win, hop):
                e = s + win
                cand[label] += 1
                rec_cand[label] += 1

                if qrs_samples is None or qrs_symbols is None:
                    add_drop(label, "no_qrs_or_qrsc_annotation", rec_drop)
                    continue

                if drop_if_artifact_bar and window_has_symbol(qrs_samples, qrs_symbols, s, e, "|"):
                    add_drop(label, "qrs_artifact_|_inside_window", rec_drop)
                    continue

                if drop_if_t_marker and window_has_symbol(qrs_samples, qrs_symbols, s, e, "T"):
                    add_drop(label, "qrs_T_marker_inside_window", rec_drop)
                    continue

                beats = count_beats_in_window(qrs_samples, qrs_symbols, s, e, beat_symbol="N")
                if beats < min_beats_in_10s:
                    add_drop(label, f"too_few_beats(<{min_beats_in_10s})", rec_drop)
                    continue

                kept[label] += 1
                rec_kept[label] += 1

                if label == "AF":
                    AF_kept.append((rec_base, int(s)))
                else:
                    N_kept.append((rec_base, int(s)))

        if print_per_record:
            print(f"\n[{rec_name}] fs={fs}Hz, qrs_src={qrs_src}")
            print(
                f"  Candidate: AF={rec_cand['AF']} | N={rec_cand['N']} | total={rec_cand['AF'] + rec_cand['N']}"
            )
            print(
                f"  Kept     : AF={rec_kept['AF']} | N={rec_kept['N']} | total={rec_kept['AF'] + rec_kept['N']}"
            )
            drop_total = sum(rec_drop.values())
            if drop_total:
                print(f"  Dropped  : total={drop_total} | reasons={rec_drop}")
            else:
                print("  Dropped  : total=0")

    summary = {
        "data_dir": cfg.data_dir,
        "window_sec": cfg.window_sec,
        "hop_sec": cfg.window_sec,
        "fs_target_for_index": fs_target_for_index,
        "candidate": dict(cand),
        "kept": dict(kept),
        "dropped_total": int(sum(dropped_reasons.values())),
        "dropped_reasons": dict(dropped_reasons),
        "dropped_by_label": dropped_by_label,
    }
    return AF_kept, N_kept, summary


def build_ltaf_windows_filtered_bestk(
    record_bases: List[str],
    cfg: Config,
    *,
    drop_if_artifact_bar: bool = True,
    drop_if_t_marker: bool = True,
    min_beats_in_10s: int = 7,
    margin_sec: int = 30,
    adaptive_margin: bool = True,
    only_keep_pure_n: bool = True,
    apply_rr_qc_to_n: bool = True,
    hr_min: float = 40.0,
    hr_max: float = 180.0,
    outlier_ratio_max: float = 0.03,
    sdnn_max: float = 0.08,
    naf_score_max: Optional[float] = None,
    target_af: Optional[int] = None,
    target_n: Optional[int] = None,
    stratify_by_record: bool = True,
    print_per_record: bool = False,
) -> Tuple[List[Tuple[str, int]], List[Tuple[str, int]], Dict[str, object]]:
    """Paper-ish window selection for LTAF."""

    af_set: Set[str] = {"AFIB"}

    # Counters
    scanned_core = {"AF": 0, "N": 0}
    kept_after_symbol = {"AF": 0, "N": 0}
    kept_after_rr_qc_n = 0
    kept_after_score_n = 0

    dropped_reasons: Dict[str, int] = {}
    dropped_by_label: Dict[str, Dict[str, int]] = {"AF": {}, "N": {}}

    # candidates
    af_cand: List[Tuple[str, int]] = []
    # for N keep score for best-K / analysis
    n_cand_scored: List[Tuple[float, str, int]] = []  # (score, rec_name, start)

    # keep per-record for stratified selection
    af_by_rec: Dict[str, List[int]] = {}
    n_by_rec: Dict[str, List[Tuple[float, int]]] = {}

    n_scores_all: List[float] = []

    def add_drop(label: str, reason: str, rec_drop: Optional[Dict[str, int]] = None):
        dropped_reasons[reason] = dropped_reasons.get(reason, 0) + 1
        d = dropped_by_label[label]
        d[reason] = d.get(reason, 0) + 1
        if rec_drop is not None:
            rec_drop[reason] = rec_drop.get(reason, 0) + 1

    for rec_base in record_bases:
        rec_name = Path(rec_base).name
        intervals, fs, _sig_len = build_rhythm_intervals(rec_base)
        win = int(cfg.window_sec * fs)
        hop = int(cfg.window_sec * fs)  # NO overlap: 10s/10s

        # symbol annotation for noise
        qrs_samples, qrs_symbols, qrs_src = read_qrs_annotation_for_noise(rec_base)
        # rpeaks for RR-QC
        rpeaks, r_src = read_rpeaks_qrsc_else_qrs(rec_base)

        rec_drop: Dict[str, int] = {}
        rec_scanned = {"AF": 0, "N": 0}
        rec_kept_symbol = {"AF": 0, "N": 0}
        rec_n_pass_rr = 0
        rec_n_pass_score = 0

        for itv in intervals:
            r = (itv.rhythm or "").upper()
            if r in af_set:
                label = "AF"
            elif r == "N":
                label = "N"
            else:
                continue  # ignore other rhythms

            # margin trimming
            interval_len = int(itv.end - itv.start)
            margin = int(margin_sec * fs)
            if adaptive_margin:
                max_margin = max(0, (interval_len - win) // 2)
                margin = min(margin, max_margin)

            core_start = int(itv.start + margin)
            core_end = int(itv.end - margin)
            if core_end - core_start < win:
                continue

            for s in iter_window_starts(core_start, core_end, win, hop):
                e = int(s + win)

                scanned_core[label] += 1
                rec_scanned[label] += 1

                if qrs_samples is None or qrs_symbols is None:
                    add_drop(label, "no_qrs_or_qrsc_annotation", rec_drop)
                    continue

                if drop_if_artifact_bar and window_has_symbol(qrs_samples, qrs_symbols, s, e, "|"):
                    add_drop(label, "qrs_artifact_|_inside_window", rec_drop)
                    continue

                if drop_if_t_marker and window_has_symbol(qrs_samples, qrs_symbols, s, e, "T"):
                    add_drop(label, "qrs_T_marker_inside_window", rec_drop)
                    continue

                beats = count_beats_in_window(qrs_samples, qrs_symbols, s, e, beat_symbol="N")
                if beats < min_beats_in_10s:
                    add_drop(label, f"too_few_beats(<{min_beats_in_10s})", rec_drop)
                    continue

                if label == "N" and only_keep_pure_n:
                    if not window_is_pure_symbol(qrs_samples, qrs_symbols, s, e, keep_symbol="N"):
                        add_drop(label, "non_N_symbol_inside_window", rec_drop)
                        continue

                kept_after_symbol[label] += 1
                rec_kept_symbol[label] += 1

                if label == "AF":
                    af_cand.append((rec_base, int(s)))
                    af_by_rec.setdefault(rec_name, []).append(int(s))
                    continue

                # label == N
                if not apply_rr_qc_to_n:
                    # no RR-QC: assign score=0 and keep
                    n_cand_scored.append((0.0, rec_name, int(s)))
                    n_by_rec.setdefault(rec_name, []).append((0.0, int(s)))
                    kept_after_rr_qc_n += 1
                    kept_after_score_n += 1
                    rec_n_pass_rr += 1
                    rec_n_pass_score += 1
                    continue

                if rpeaks is None or rpeaks.size == 0:
                    add_drop(label, "no_rpeaks_for_rr_qc", rec_drop)
                    continue

                i0 = int(np.searchsorted(rpeaks, s, side="left"))
                i1 = int(np.searchsorted(rpeaks, e, side="left"))
                r_in = rpeaks[i0:i1]
                m = _rr_qc_metrics(r_in, fs, hr_min=hr_min, hr_max=hr_max)
                if m is None:
                    add_drop(label, "rr_qc_failed_basic", rec_drop)
                    continue

                if float(m["outlier_ratio"]) > float(outlier_ratio_max):
                    add_drop(label, f"rr_qc_outlier_ratio(>{outlier_ratio_max})", rec_drop)
                    continue

                if float(m["sdnn"]) > float(sdnn_max):
                    add_drop(label, f"rr_qc_sdnn(>{sdnn_max})", rec_drop)
                    continue

                kept_after_rr_qc_n += 1
                rec_n_pass_rr += 1

                score = float(_naf_quality_score(m))
                n_scores_all.append(score)

                if naf_score_max is not None and score > float(naf_score_max):
                    add_drop(label, f"naf_score(>{naf_score_max})", rec_drop)
                    continue

                kept_after_score_n += 1
                rec_n_pass_score += 1

                n_cand_scored.append((score, rec_name, int(s)))
                n_by_rec.setdefault(rec_name, []).append((score, int(s)))

        if print_per_record:
            print(f"\n[{rec_name}] fs={fs}Hz, qrs_src={qrs_src}, r_src={r_src}")
            print(
                f"  scanned(core): AF={rec_scanned['AF']} | N={rec_scanned['N']} | total={rec_scanned['AF'] + rec_scanned['N']}"
            )
            print(
                f"  kept(symbol) : AF={rec_kept_symbol['AF']} | N={rec_kept_symbol['N']} | total={rec_kept_symbol['AF'] + rec_kept_symbol['N']}"
            )
            print(f"  N pass RR-QC : {rec_n_pass_rr}")
            if naf_score_max is not None:
                print(f"  N pass score : {rec_n_pass_score}")
            if rec_drop:
                print(f"  dropped      : total={sum(rec_drop.values())} | reasons={rec_drop}")


    af_selected: List[Tuple[str, int]]
    n_selected: List[Tuple[str, int]]

    if target_af is None or target_af >= len(af_cand):
        af_selected = sorted(af_cand, key=lambda x: (Path(x[0]).name, x[1]))
    else:
        af_selected = []
        if stratify_by_record:
            per = {k: sorted(v) for k, v in af_by_rec.items()}
            keys = sorted(per.keys())
            idx = {k: 0 for k in keys}
            while len(af_selected) < int(target_af):
                progressed = False
                for k in keys:
                    i = idx[k]
                    if i < len(per[k]):
                        af_selected.append((str(Path(cfg.data_dir) / k), int(per[k][i])))
                        idx[k] = i + 1
                        progressed = True
                        if len(af_selected) >= int(target_af):
                            break
                if not progressed:
                    break

            if len(af_selected) < int(target_af):
                af_selected = sorted(af_cand, key=lambda x: (Path(x[0]).name, x[1]))[: int(target_af)]
        else:
            af_selected = sorted(af_cand, key=lambda x: (Path(x[0]).name, x[1]))[: int(target_af)]

    # N selection (optionally cap) - best-K by lowest score
    if target_n is None or target_n >= len(n_cand_scored):
        # keep all, deterministic order
        n_selected = sorted([(rec, s) for (_score, rec, s) in n_cand_scored], key=lambda x: (x[0], x[1]))
        # rec in n_cand_scored is record name (not base). Map back to base via record_bases list.
        name_to_base = {Path(b).name: b for b in record_bases}
        n_selected = [(name_to_base.get(rec, rec), int(s)) for (rec, s) in n_selected]
    else:
        name_to_base = {Path(b).name: b for b in record_bases}
        n_selected = []
        if stratify_by_record:
            per = {k: sorted(v, key=lambda t: t[0]) for k, v in n_by_rec.items()}
            keys = sorted(per.keys())
            idx = {k: 0 for k in keys}
            while len(n_selected) < int(target_n):
                progressed = False
                for k in keys:
                    i = idx[k]
                    if i < len(per[k]):
                        _score, s = per[k][i]
                        n_selected.append((name_to_base[k], int(s)))
                        idx[k] = i + 1
                        progressed = True
                        if len(n_selected) >= int(target_n):
                            break
                if not progressed:
                    break
            if len(n_selected) < int(target_n):
                # fallback: global best-K
                global_sorted = sorted(n_cand_scored, key=lambda t: t[0])[: int(target_n)]
                n_selected = [(name_to_base[rec], int(s)) for (_score, rec, s) in global_sorted]
        else:
            global_sorted = sorted(n_cand_scored, key=lambda t: t[0])[: int(target_n)]
            n_selected = [(name_to_base[rec], int(s)) for (_score, rec, s) in global_sorted]

    # score stats for logging
    n_score_stats = None
    if len(n_scores_all) > 0:
        arr = np.asarray(n_scores_all, dtype=float)
        n_score_stats = {
            "p50": float(np.quantile(arr, 0.50)),
            "p75": float(np.quantile(arr, 0.75)),
            "p90": float(np.quantile(arr, 0.90)),
            "p95": float(np.quantile(arr, 0.95)),
            "p99": float(np.quantile(arr, 0.99)),
        }

    summary: Dict[str, object] = {
        "scanned_core_after_margin": dict(scanned_core),
        "kept_after_symbol": dict(kept_after_symbol),
        "kept_after_rr_qc_n": int(kept_after_rr_qc_n),
        "kept_after_score_n": int(kept_after_score_n),
        "selected": {"AF": len(af_selected), "N": len(n_selected)},
        "targets": {"AF": target_af, "N": target_n},
        "dropped_total": int(sum(dropped_reasons.values())),
        "dropped_reasons": dict(dropped_reasons),
        "dropped_by_label": dropped_by_label,
        "rr_qc": {
            "apply_rr_qc_to_n": bool(apply_rr_qc_to_n),
            "hr_min": float(hr_min),
            "hr_max": float(hr_max),
            "outlier_ratio_max": float(outlier_ratio_max),
            "sdnn_max": float(sdnn_max),
            "naf_score_max": (None if naf_score_max is None else float(naf_score_max)),
        },
        "n_score_stats": n_score_stats,
    }

    return af_selected, n_selected, summary