# test_only.py
from pathlib import Path
import json
import random

import joblib
import numpy as np
import matplotlib.pyplot as plt
import wfdb
import pandas as pd

from MSSD_NN50_PE_core import (
    Config, list_local_record_bases, build_AF_windows, build_NAF_windows_best_k,
    build_xy_from_windows, paper_metrics, load_json
)

# ================== USER SETTINGS ==================
MODE = "internal_20"  # "internal_20" hoặc "unseen_all"

DATA_DIR_AFDB = r"D:/VSCode/KhoaLuan/data_afdb"
DATA_DIR_UNSEEN = r"D:/path/to/LTAF_or_CPSC"  # chỉ dùng khi MODE="unseen_all"

MODEL_PATH = "svm_linear.joblib"
META_PATH = "svm_linear_meta.json"

# Nếu bạn muốn override thì set ở đây, còn không None => lấy từ meta
SIGNALS_UNAVAILABLE_OVERRIDE = None  # ví dụ {"00735", "03665"} hoặc None
RANDOM_SEED = 42
# ===================================================

def filter_records_by_names(record_bases, names_set):
    return [b for b in record_bases if Path(b).name in names_set]

def safe_stack(X1: np.ndarray, X2: np.ndarray) -> np.ndarray:
    if X1 is None or len(X1) == 0:
        return X2
    if X2 is None or len(X2) == 0:
        return X1
    return np.vstack([X1, X2])

def safe_concat(y1: np.ndarray, y2: np.ndarray) -> np.ndarray:
    if y1 is None or len(y1) == 0:
        return y2
    if y2 is None or len(y2) == 0:
        return y1
    return np.concatenate([y1, y2])

def plot_random_waves(windows, label_name, color, num_plots=2):
    if not windows:
        return
    
    # Chọn ngẫu nhiên vài đoạn để vẽ
    samples = random.sample(windows, min(num_plots, len(windows)))
    
    for win in samples:
        try:
            # Truy xuất thông tin linh hoạt (hỗ trợ cả dạng dict và dạng object)
            if isinstance(win, dict):
                rec_path = win.get('rec_path', win.get('rec'))
                start = win['start']
                end = win['end']
            else:
                rec_path = win.rec_path if hasattr(win, 'rec_path') else win.rec
                start = win.start
                end = win.end
        except Exception as e:
            print(f"Không thể lấy thông tin window (kiểm tra lại cấu trúc object): {e}")
            continue
            
        try:
            record = wfdb.rdrecord(str(rec_path), sampfrom=start, sampto=end)
            
            plt.figure(figsize=(12, 4))
            plt.plot(record.p_signal[:, 0], color=color, linewidth=1)
            plt.title(f"Waveform of {label_name} | Record: {Path(rec_path).name} | Range: {start}-{end}")
            plt.xlabel("Samples (Thời gian)")
            plt.ylabel("Amplitude (mV)")
            plt.grid(True, linestyle='--', alpha=0.6)
            plt.tight_layout()
            plt.show()
        except Exception as e:
            print(f"Lỗi khi đọc/vẽ wfdb cho file {rec_path}: {e}")

def main():
    meta = load_json(META_PATH)

    # ---------- Load cfg from meta ----------
    cfg_meta = meta.get("cfg", {})
    paper_setup = meta.get("paper_setup", {})
    qc = paper_setup.get("QC", {})

    window_sec = int(cfg_meta.get("window_sec", 10))
    hop_sec = int(cfg_meta.get("hop_sec", 5))

    if SIGNALS_UNAVAILABLE_OVERRIDE is not None:
        signals_unavailable = frozenset(SIGNALS_UNAVAILABLE_OVERRIDE)
    else:
        signals_unavailable = frozenset(cfg_meta.get("signals_unavailable", []))

    data_dir = DATA_DIR_AFDB if MODE == "internal_20" else DATA_DIR_UNSEEN

    cfg = Config(
        data_dir=data_dir,
        window_sec=window_sec,
        hop_sec=hop_sec,
        signals_unavailable=signals_unavailable,
        random_seed=RANDOM_SEED,
    )

    print(f"MODE={MODE}")
    print(f"Data dir: {cfg.data_dir}")
    print(f"Window/Hop: {cfg.window_sec}s/{cfg.hop_sec}s  (OVERLAP={'YES' if cfg.hop_sec < cfg.window_sec else 'NO'})")
    print(f"signals_unavailable={sorted(list(cfg.signals_unavailable))}")

    # ---------- Load model ----------
    model = joblib.load(MODEL_PATH)
    # ---------- List records ----------
    rec_all = list_local_record_bases(cfg)

    if MODE == "internal_20":
        test_names = set(meta["split"]["test_record_names"])
        rec_test = filter_records_by_names(rec_all, test_names)
        print(f"\nInternal test records: {len(rec_test)} / {len(rec_all)}")
    else:
        rec_test = rec_all
        print(f"\nUnseen test records: {len(rec_test)}")

    if len(rec_test) == 0:
        raise RuntimeError("Không có record nào để test. Kiểm tra folder + signals_unavailable + MODE.")

    # ---------- Build windows ----------
    AF_test = build_AF_windows(rec_test, cfg)

    target_naf_total = int(paper_setup.get("TARGET_NAF_TOTAL", 3000))
    train_ratio = float(paper_setup.get("TRAIN_RATIO", 0.80))
    naf_train_k = int(paper_setup.get("NAF_train_k", int(target_naf_total * train_ratio)))
    naf_test_k = int(paper_setup.get("NAF_test_k", target_naf_total - naf_train_k))

    hr_min = float(qc.get("HR_MIN", 40.0))
    hr_max = float(qc.get("HR_MAX", 180.0))
    outlier_ratio_max = float(qc.get("OUTLIER_RATIO_MAX", 0.10))
    sdnn_max = float(qc.get("SDNN_MAX", 0.12))
    margin_sec_test = int(qc.get("MARGIN_SEC_TEST", 0))
    adaptive_margin = bool(qc.get("ADAPTIVE_MARGIN", True))

    if MODE != "internal_20":
        naf_test_k = target_naf_total

    NAF_test, naf_test_stats = build_NAF_windows_best_k(
        rec_test, cfg, target_k=naf_test_k,
        margin_sec=margin_sec_test, adaptive_margin=adaptive_margin,
        hr_min=hr_min, hr_max=hr_max, outlier_ratio_max=outlier_ratio_max, sdnn_max=sdnn_max,
    )

    print("\nRAW windows counts (same logic as train):")
    print(f"  TEST: AF(all)={len(AF_test)} | NAF(bestK)={len(NAF_test)}")
    print("\nNAF selection stats (test):")
    print(f"  {naf_test_stats}")

    # ---------- Feature extraction (test) ----------
    X_af, y_af, st_af = build_xy_from_windows(AF_test, 1, cfg)
    X_nf, y_nf, st_nf = build_xy_from_windows(NAF_test, 0, cfg)

    X_test = safe_stack(X_af, X_nf)
    y_test = safe_concat(y_af, y_nf)

    print("\nKEPT segments after feature extraction (test):")
    print(f"  TEST AF : kept={st_af['kept']} / raw={st_af['total']} (drop={st_af['dropped']})")
    print(f"  TEST NAF: kept={st_nf['kept']} / raw={st_nf['total']} (drop={st_nf['dropped']})")
    print(f"  TEST ALL: kept={len(X_test)}")

    # ---------- Predict + metrics ----------
    yhat = model.predict(X_test)
    y_score = model.decision_function(X_test)

    df_raw = pd.DataFrame(X_test, columns=["MSSD", "NN50", "PE"])
    df_raw["True_Label"] = y_test
    df_raw["Predicted_Label"] = yhat
    df_raw["SVM_Raw_Score"] = y_score

    df_raw["Is_Correct"] = (df_raw["True_Label"] == df_raw["Predicted_Label"])

    # Lưu ra file CSV
    out_csv_path = "test_raw_results.csv"
    df_raw.to_csv(out_csv_path, index=False)
    print(f"\n[+] Đã xuất file Test RAW thành công tại: {out_csv_path}")

    print("\n==================== PAPER METRICS ====================")
    print(paper_metrics(y_test, yhat))
    print("=======================================================")

if __name__ == "__main__":
    main()