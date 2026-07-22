# train_only.py
from pathlib import Path
import joblib
import numpy as np
from sklearn.pipeline import Pipeline
from sklearn.preprocessing import StandardScaler
from sklearn.svm import LinearSVC

from Variance_Mean_PE_core import (
    Config, list_local_record_bases, build_AF_windows, build_NAF_windows_best_k,
    build_xy_from_windows, paper_metrics, save_json,
)

# ================== USER SETTINGS ==================
DATA_DIR = r"D:/VSCode/KhoaLuan/data_afdb"

WINDOW_SEC = 10
HOP_SEC = 5  

TRAIN_RATIO = 0.80

# NAF target 
TARGET_NAF_TOTAL = 12500

# NAF QC + best-K
HR_MIN = 40.0
HR_MAX = 180.0
OUTLIER_RATIO_MAX = 0.10
SDNN_MAX = 0.12  # seconds
ADAPTIVE_MARGIN = True
MARGIN_SEC_TRAIN = 60
MARGIN_SEC_TEST = 0

SIGNALS_UNAVAILABLE = {"00735", "03665"}  # nếu muốn bỏ record lỗi
FORCE_TRAIN_RECORDS = {"05091"}
FORCE_TEST_RECORDS = {"07859"}


MODEL_OUT = "svm_linear.joblib"
META_OUT = "svm_linear_meta.json"
RANDOM_SEED = 42


def split_records_by_name(
    rec_bases,
    train_ratio: float,
    force_train: set,
    force_test: set,
):

    name_to_base = {Path(r).name: r for r in rec_bases}
    rec_names = sorted(name_to_base.keys())

    missing_train = force_train - set(rec_names)
    missing_test = force_test - set(rec_names)
    if missing_train or missing_test:
        raise ValueError(f"Forced records not found. missing_train={missing_train}, missing_test={missing_test}")
    if force_train & force_test:
        raise ValueError(f"Forced sets overlap: {force_train & force_test}")

    n_train = int(len(rec_names) * train_ratio)
    train_set = set(rec_names[:n_train])
    test_set = set(rec_names[n_train:])

    train_set |= set(force_train)
    test_set -= set(force_train)

    test_set |= set(force_test)
    train_set -= set(force_test)

    movable_from_train = [x for x in rec_names if x in train_set and x not in force_train]
    movable_from_train.sort(reverse=True)
    while len(train_set) > n_train:
        x = movable_from_train.pop(0)
        train_set.remove(x)
        test_set.add(x)

    movable_from_test = [x for x in rec_names if x in test_set and x not in force_test]
    movable_from_test.sort()
    while len(train_set) < n_train:
        x = movable_from_test.pop(0)
        test_set.remove(x)
        train_set.add(x)

    train = [name_to_base[n] for n in rec_names if n in train_set]
    test = [name_to_base[n] for n in rec_names if n in test_set]
    return train, test, sorted(train_set), sorted(test_set)


def svm_params_for_paper(window_sec: int):  
    if window_sec == 10:
        return dict(C=0.1)
    if window_sec == 30:
        return dict(C=10.0)
    raise ValueError("Paper chỉ nêu window 10s hoặc 30s.")

def main():
    cfg = Config(
        data_dir=DATA_DIR,
        window_sec=WINDOW_SEC,
        hop_sec=HOP_SEC,
        signals_unavailable=frozenset(SIGNALS_UNAVAILABLE),
        random_seed=RANDOM_SEED,
    )

    rec_all = list_local_record_bases(cfg)
    rec_train, rec_test, train_names, test_names = split_records_by_name(
        rec_all,
        train_ratio=TRAIN_RATIO,
        force_train=set(FORCE_TRAIN_RECORDS),
        force_test=set(FORCE_TEST_RECORDS),
    )

    print(f"Records: total={len(rec_all)}, train={len(rec_train)}, test={len(rec_test)}")
    print(f"Window/Hop: {cfg.window_sec}s/{cfg.hop_sec}s  (OVERLAP={'YES' if cfg.hop_sec < cfg.window_sec else 'NO'})")

    # ========== AF: lấy ALL windows theo rhythm AFIB/AFL ==========
    AF_train = build_AF_windows(rec_train, cfg)
    AF_test = build_AF_windows(rec_test, cfg)

    # ========== NAF: lấy BEST-K ==========
    naf_train_k = int(TARGET_NAF_TOTAL * TRAIN_RATIO)
    naf_test_k = TARGET_NAF_TOTAL - naf_train_k

    NAF_train, naf_train_stats = build_NAF_windows_best_k(
        rec_train, cfg,
        target_k=naf_train_k,
        margin_sec=MARGIN_SEC_TRAIN,
        adaptive_margin=ADAPTIVE_MARGIN,
        hr_min=HR_MIN, hr_max=HR_MAX,
        outlier_ratio_max=OUTLIER_RATIO_MAX,
        sdnn_max=SDNN_MAX,
    )

    NAF_test, naf_test_stats = build_NAF_windows_best_k(
        rec_test, cfg,
        target_k=naf_test_k,
        margin_sec=MARGIN_SEC_TEST,
        adaptive_margin=ADAPTIVE_MARGIN,
        hr_min=HR_MIN, hr_max=HR_MAX,
        outlier_ratio_max=OUTLIER_RATIO_MAX,
        sdnn_max=SDNN_MAX,
    )

    print("\nRAW windows counts:")
    print(f"  TRAIN: AF={len(AF_train)} | NAF(bestK)={len(NAF_train)}")
    print(f"  TEST : AF={len(AF_test)}  | NAF(bestK)={len(NAF_test)}")
    print("\nNAF selection stats:")
    print(f"  TRAIN stats: {naf_train_stats}")
    print(f"  TEST  stats: {naf_test_stats}")

    # ========== Feature extraction (train only) ==========
    X_af, y_af, st_af = build_xy_from_windows(AF_train, 1, cfg)
    X_nf, y_nf, st_nf = build_xy_from_windows(NAF_train, 0, cfg)

    if len(X_af) == 0 or len(X_nf) == 0:
        raise RuntimeError(
            f"Không đủ sample sau khi tính đặc trưng (MSSD, PNN50, PE). "
            f"AF_kept={len(X_af)}, NAF_kept={len(X_nf)}. "
            f"Kiểm tra R-peaks (qrsc/qrs) hoặc dữ liệu."
        )

    X_train = np.vstack([X_af, X_nf])
    y_train = np.concatenate([y_af, y_nf])

    print("\nKEPT segments after feature extraction (train):")
    print(f"  AF : kept={st_af['kept']} / raw={st_af['total']} (drop={st_af['dropped']})")
    print(f"  NAF: kept={st_nf['kept']} / raw={st_nf['total']} (drop={st_nf['dropped']})")
    print(f"  ALL: kept={len(X_train)}")

    # ========== Train SVM paper params ==========
    svm_kwargs = svm_params_for_paper(cfg.window_sec)
    model = Pipeline([("scaler", StandardScaler()), ("svm", LinearSVC(**svm_kwargs, dual="auto", max_iter=20000))])
    model.fit(X_train, y_train)

    # sanity on train
    yhat_tr = model.predict(X_train)
    print("\nTrain metrics (sanity):")
    print(paper_metrics(y_train, yhat_tr))

    # save model
    joblib.dump(model, MODEL_OUT)
    print(f"\nSaved model to: {MODEL_OUT}")

    scaler_step = model.named_steps["scaler"]
    svm_step = model.named_steps["svm"]

    w_scaled = svm_step.coef_[0].tolist()
    b_scaled = float(svm_step.intercept_[0])
    mean_arr = scaler_step.mean_.tolist()
    scale_arr = scaler_step.scale_.tolist()

    w_raw = [w / s for w, s in zip(w_scaled, scale_arr)]
    b_raw = b_scaled - sum(w * m for w, m in zip(w_raw, mean_arr))
    cpp_equation = f"float y = ({w_raw[0]:.6f} * MSSD) + ({w_raw[1]:.6f} * NN50) + ({w_raw[2]:.6f} * PE) + ({b_raw:.6f});"
    
    hardware_export = {
        "features": ["MSSD", "NN50", "PE"],
        "scaler": {
            "mean": mean_arr,
            "scale": scale_arr
        },
        "svm_scaled": {
            "w_scaled": w_scaled,
            "b_scaled": b_scaled
        },
        "hardware_form": {
            "w_raw": w_raw,
            "b_raw": b_raw,
            "equation": "y = (w_raw[0]*MSSD) + (w_raw[1]*NN50) + (w_raw[2]*PE) + b_raw",
            "equation_cpp": cpp_equation,
            "decision": "AFIB if y > 0 else Normal"
        }
    }
    
    meta = {
        "cfg": {
            "data_dir": cfg.data_dir,
            "window_sec": cfg.window_sec,
            "hop_sec": cfg.hop_sec,
            "signals_unavailable": sorted(list(cfg.signals_unavailable)),
        },
        "paper_setup": {
            "TARGET_NAF_TOTAL": TARGET_NAF_TOTAL,
            "TRAIN_RATIO": TRAIN_RATIO,
            "NAF_train_k": naf_train_k,
            "NAF_test_k": naf_test_k,
            "QC": {
                "HR_MIN": HR_MIN, "HR_MAX": HR_MAX,
                "OUTLIER_RATIO_MAX": OUTLIER_RATIO_MAX,
                "SDNN_MAX": SDNN_MAX,
                "MARGIN_SEC_TRAIN": MARGIN_SEC_TRAIN,
                "MARGIN_SEC_TEST": MARGIN_SEC_TEST,
                "ADAPTIVE_MARGIN": ADAPTIVE_MARGIN,
            },
        },
        "svm_params_paper": svm_kwargs,
        "split": {
            "train_record_names": train_names,
            "test_record_names": test_names,
            "force_train_records": sorted(list(FORCE_TRAIN_RECORDS)),
            "force_test_records": sorted(list(FORCE_TEST_RECORDS)),
        },
        "raw_counts": {
            "train_AF": len(AF_train),
            "train_NAF_selected": len(NAF_train),
            "test_AF": len(AF_test),
            "test_NAF_selected": len(NAF_test),
        },
        "naf_stats": {
            "train": naf_train_stats,
            "test": naf_test_stats,
        },
        "kept_counts_train": {
            "train_AF_kept": int(len(X_af)),
            "train_NAF_kept": int(len(X_nf)),
            "train_total_kept": int(len(X_train)),
        },
        "labels": {"0": "non-AF(N)", "1": "AF"},
        "hardware_params": hardware_export 
    }
    save_json(META_OUT, meta)
    print(f"Saved meta to: {META_OUT}")


if __name__ == "__main__":
    main()