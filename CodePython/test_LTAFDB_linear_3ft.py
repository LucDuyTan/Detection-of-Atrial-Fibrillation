# LTAFDB_hwsvm.py
"""LTAFDB evaluation using an AFDB-trained SVM (RCV, IQR, PE features).

This version intentionally **does NOT** tune a threshold.
It always evaluates using the SVM model's own decision boundary via `model.predict`.
"""

import joblib
import numpy as np
import pandas as pd
from Variance_Mean_PE_core import Config, build_xy_from_windows, load_json, paper_metrics
from ltaf_utils import list_record_bases, build_ltaf_windows_filtered_bestk

# ================== USER SETTINGS ==================
DATA_DIR_LTAF = r"D:/VSCode/KhoaLuan/data_ltafdb"

MODEL_PATH = "svm_linear.joblib"    
META_PATH = "svm_linear_meta.json"

SIGNALS_UNAVAILABLE = set()  # nếu có record lỗi thì thêm vào {"xxxxx", ...}

# Cắt đúng 10s, không overlap
WINDOW_SEC = 10

# Drop rules theo qrs/qrsc
DROP_IF_ARTIFACT_BAR = True   # '|'
DROP_IF_T_MARKER = True       # 'T'
MIN_BEATS_IN_10S = 7

# Tránh vùng chuyển nhịp (AF onset/termination)
MARGIN_SEC = 60
ADAPTIVE_MARGIN = True

# Lọc N "sạch" hơn
ONLY_KEEP_PURE_N = True
APPLY_RR_QC_TO_N = True
HR_MIN = 40.0
HR_MAX = 180.0
OUTLIER_RATIO_MAX = 0.02
SDNN_MAX = 0.065

# Lọc thêm theo naf-score (không bắt buộc). Set None để tắt.
NAF_SCORE_MAX = 0.035

# Nếu muốn ép gần paper counts thì đặt số; nếu không thì để None.
TARGET_AF = None
TARGET_N = None
STRATIFY_BY_RECORD = True

PRINT_PER_RECORD = False
RANDOM_SEED = 42
# ====================================================

def _safe_stack(X1: np.ndarray, X2: np.ndarray) -> np.ndarray:
    if X1 is None or len(X1) == 0:
        return X2
    if X2 is None or len(X2) == 0:
        return X1
    return np.vstack([X1, X2])

def _safe_concat(y1: np.ndarray, y2: np.ndarray) -> np.ndarray:
    if y1 is None or len(y1) == 0:
        return y2
    if y2 is None or len(y2) == 0:
        return y1
    return np.concatenate([y1, y2])

def main():
    meta = load_json(META_PATH)
    cfg_meta = meta.get("cfg", {})
    cfg = Config(
        data_dir=DATA_DIR_LTAF,
        window_sec=WINDOW_SEC,
        hop_sec=WINDOW_SEC,  # NO overlap
        signals_unavailable=frozenset(SIGNALS_UNAVAILABLE),
        random_seed=RANDOM_SEED,
    )

    print("MODE=LTAF_test_with_AFDB_model")
    print(f"Data dir: {cfg.data_dir}")
    print(
        f"Window/Hop: {cfg.window_sec}s/{cfg.hop_sec}s  (OVERLAP={'YES' if cfg.hop_sec < cfg.window_sec else 'NO'})"
    )
    print(f"signals_unavailable={sorted(list(cfg.signals_unavailable))}")

    model = joblib.load(MODEL_PATH)

    rec_all = list_record_bases(cfg.data_dir, set(cfg.signals_unavailable))
    print(f"Records found: {len(rec_all)}")

    AF_win, N_win, summary = build_ltaf_windows_filtered_bestk(
        rec_all,
        cfg,
        drop_if_artifact_bar=DROP_IF_ARTIFACT_BAR,
        drop_if_t_marker=DROP_IF_T_MARKER,
        min_beats_in_10s=MIN_BEATS_IN_10S,
        margin_sec=MARGIN_SEC,
        adaptive_margin=ADAPTIVE_MARGIN,
        only_keep_pure_n=ONLY_KEEP_PURE_N,
        apply_rr_qc_to_n=APPLY_RR_QC_TO_N,
        hr_min=HR_MIN,
        hr_max=HR_MAX,
        outlier_ratio_max=OUTLIER_RATIO_MAX,
        sdnn_max=SDNN_MAX,
        naf_score_max=NAF_SCORE_MAX,
        target_af=TARGET_AF,
        target_n=TARGET_N,
        stratify_by_record=STRATIFY_BY_RECORD,
        print_per_record=PRINT_PER_RECORD,
    )

    print("\nWINDOW SELECTION SUMMARY (LTAF):")
    print(
        f"  Scanned (core after margin): AF={summary['scanned_core_after_margin']['AF']} | N={summary['scanned_core_after_margin']['N']}"
    )
    print(
        f"  Kept after symbol filters   : AF={summary['kept_after_symbol']['AF']} | N={summary['kept_after_symbol']['N']}"
    )
    print(f"  N pass RR-QC               : {summary['kept_after_rr_qc_n']}")
    if summary['rr_qc'].get('naf_score_max', None) is not None:
        print(f"  N pass score-threshold     : {summary.get('kept_after_score_n', 0)}")
        if summary.get('n_score_stats') is not None:
            print(f"  N score stats              : {summary['n_score_stats']}")
    print(
        f"  Selected (final)           : AF={summary['selected']['AF']} | N={summary['selected']['N']}"
    )
    print(f"  Targets                    : AF={summary['targets']['AF']} | N={summary['targets']['N']}")

    # --- Feature extraction (Cập nhật 3 Features: RCV, IQR, PE) + predict ---
    X_af, y_af, st_af = build_xy_from_windows(AF_win, 1, cfg)
    X_nf, y_nf, st_nf = build_xy_from_windows(N_win, 0, cfg)

    X_test = _safe_stack(X_af, X_nf)
    y_test = _safe_concat(y_af, y_nf)

    print("\nKEPT segments after 3-feature extraction (LTAF):")
    print(f"  AF : kept={st_af['kept']} / raw={st_af['total']} (drop={st_af['dropped']})")
    print(f"  N  : kept={st_nf['kept']} / raw={st_nf['total']} (drop={st_nf['dropped']})")
    print(f"  ALL: kept={len(X_test)}")

    if len(X_test) == 0:
        raise RuntimeError("Không có sample nào sau khi tính đặc trưng trên LTAF. Kiểm tra annotations/qrs.")

    yhat = model.predict(X_test)

    y_score = model.decision_function(X_test)
    
    df_raw = pd.DataFrame(X_test, columns=["MSSD", "PNN50", "PE"])
    
    df_raw["True_Label"] = y_test
    df_raw["Predicted_Label"] = yhat
    df_raw["SVM_Raw_Score"] = y_score
    df_raw["Is_Correct"] = (df_raw["True_Label"] == df_raw["Predicted_Label"])

    df_raw = df_raw.sample(frac=1, random_state=42).reset_index(drop=True)

    out_csv_path = "LTAF_test_raw_results.csv"
    df_raw.to_csv(out_csv_path, index=False)
    print(f"\n[+] Đã xuất file Test RAW thành công tại: {out_csv_path}")
    # =========================================================================

    print("\n==================== PAPER METRICS (LTAF) ====================")
    print(paper_metrics(y_test, yhat))
    print("===============================================================")

if __name__ == "__main__":
    main()