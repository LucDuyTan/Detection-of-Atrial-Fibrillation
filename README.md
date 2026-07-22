# Hiện Thực Hệ Thống SoC Cho Thuật Toán Permutation Entropy, MSSD, NN50 Ứng Dụng Trong Tín Hiệu Điện Tim

![License](https://img.shields.io/badge/License-MIT-blue.svg)
![Language](https://img.shields.io/badge/Language-Verilog%20%7C%20Python-orange.svg)
![Platform](https://img.shields.io/badge/Platform-FPGA%2FSoC-brightgreen.svg)

## 📌 Giới thiệu (Overview)
Dự án **Hiện thực hệ thống SoC cho thuật toán Permutation Entropy, MSSD, NN50 ứng dụng trong tín hiệu điện tim** được thiết kế nhằm tự động phát hiện Rung nhĩ (Atrial Fibrillation - AFIB) từ chuỗi khoảng RR (RR interval) của tín hiệu điện tâm đồ (ECG). 

Hệ thống kết hợp tổ hợp bộ ba đặc trưng:
* **Permutation Entropy (PE)**: Định lượng độ phức tạp và tính hỗn loạn phi tuyến của tín hiệu.
* **MSSD**: Đo lường biến thiên nhịp tim ngắn hạn trong miền thời gian.
* **NN50**: Đếm số khoảng RR kế tiếp lệch nhau hơn 50ms.

Các đặc trưng này cấu thành vector đầu vào cho bộ phân loại **Linear SVM** (đã huấn luyện ngoại tuyến) nhằm đưa ra quyết định chẩn đoán chính xác trạng thái AFIB hoặc Non-AFIB với độ trễ thấp và tối ưu hóa tài nguyên phần cứng.

## ⚙️ Kiến trúc hệ thống (System Architecture)
Hệ thống phần cứng được thiết kế theo quy trình **Top-Down** bao gồm:
1. **Mảng Processing Elements (PE Array):** Gồm 12 phần tử xử lý (PE0 - PE11) hoạt động song song và đồng bộ. Mỗi PE đảm nhiệm tính toán trên một cửa sổ dữ liệu 10 giây.
2. **Cấu trúc một phần tử xử lý (Processing Element Detail):**
   * **ALU**: Thực hiện các phép toán số học như ADD, SUB, MULT, ACC, ABS, CMP, MAC.
   * **LSU (Load/Store Unit)**: Điều phối luồng dữ liệu nội bộ.
   * **Local Data Memory**: Gồm Ping-Pong RAM (nhận dữ liệu từ bên ngoài), Uni RAM, NN50 REG, PERM REG.
   * **LUT (Look-Up Table)**: Bảng tra cứu xấp xỉ các hàm phi tuyến (logarit/phân số) giúp tiết kiệm tài nguyên logic.
3. **Controller:** Khối điều khiển dựa trên Máy trạng thái hữu hạn (FSM) 10 pha để điều phối luồng dữ liệu.
4. **Định dạng số:** Sử dụng định dạng số nguyên cố định có dấu **Signed Fixed-point Q16.16**.

---

## 📊 Kết quả đạt được (Results)

### 1. Hiệu năng phân loại (Classification Performance)
Đánh giá trên hai cơ sở dữ liệu chuẩn quốc tế **MIT-BIH Atrial Fibrillation Database AFDB** và **LTAFDB**:

| Tập dữ liệu (Database) | Độ nhạy (SE) | Độ đặc hiệu (SP) | Độ chính xác (ACC) |
| :--- | :---: | :---: | :---: |
| **AFDB**   | 99.98% | 100.00% | 99.98% |
| **LTAFDB** | 99.45% | 98.30%  | 99.21% |

*Mô hình phần cứng có sai số toán học cực nhỏ 10<sup>-5</sup> so với mô hình phần mềm Golden Model, không làm sai lệch kết quả phân loại.*

### 2. Tài nguyên phần cứng (Hardware Resources)
Kết quả tổng hợp tài nguyên phần cứng:

| Tài nguyên | Số lượng sử dụng |
| :--- | :--- |
| **LUT** | 18,563 |
| **Flip-Flop (FF)** | 8,225 |
| **DSP Blocks** | 48 |
| **BRAM** | 18 |
| **Tần số tối đa ($F_{max}$)** | 130 MHz |

## 📂 Cấu trúc & Chức năng các File trong Dự án

---

### 1. `MSSD_NN50_PE_core.py` (Module Lõi)
* **Cấu hình & Cache:** Định nghĩa class `Config`, bộ nhớ đệm (Cache) cho tiêu đề header, nhãn nhịp tim (Rhythm) và các điểm sóng R-peak để tối ưu tốc độ đọc dữ liệu WFDB.
* **Xử lý khoảng nhịp (Rhythm Intervals):** Phân tích file nhãn `.atr` để chia các khoảng thời gian theo từng loại nhịp (AFIB, Normal - N,...).
* **Trích xuất đặc trưng (Feature Extraction):** Tính toán 3 đặc trưng HRV chính trên cửa sổ 10 giây:
  * **MSSD** (*Mean Square Successive Difference*): Biên độ biến thiên nhịp tim.
  * **NN50** (*Number of NN > 50ms*): Số khoảng RR kế tiếp lệch nhau trên 50ms.
  * **PE** (*Permutation Entropy*): Độ phức tạp chuỗi RR (được thiết kế dạng Bảng tra LUT tối ưu cho triển khai Verilog/phần cứng).
* **Tiện ích:** Tạo tập dữ liệu ma trận $X, y$ (`build_xy_from_windows`), tính toán các chỉ số đánh giá mô hình (`paper_metrics`: Accuracy, Sensitivity, Specificity, Precision, TP, TN, FP, FN) và đọc/ghi file cấu hình JSON.

---

### 2. `ltaf_utils_hwsvm.py` (Module Tiện ích cho LTAFDB)
* **Đọc & Kiểm tra dữ liệu LTAFDB:** Tìm kiếm bản ghi WFDB có đủ `.hea`, `.dat`, `.atr` và ưu tiên lọc nhiễu qua file chú thích `.qrs` / `.qrsc`.
* **Bộ lọc chất lượng cửa sổ (Quality Control - QC):**
  * Loại bỏ các cửa sổ chứa ký hiệu nhiễu vạch `'|'` hoặc mốc T `'T'`.
  * Lọc khoảng nhịp tim `hr_mean` (40-180 bpm), tỷ lệ điểm dị biệt `outlier_ratio`, độ lệch chuẩn `SDNN`, và điểm số chất lượng nhịp `naf_score`.
  * Tránh vùng biên chuyển tiếp nhịp bằng lề an toàn (`margin_sec`).
* **Lựa chọn cửa sổ (Window Selection):** Cắt cửa sổ không overlap (10s) và chọn lọc Best-K cửa sổ sạch nhất (dùng Stratified Selection theo record) cho cả 2 lớp AF và Normal.

---

### 3. `train_only.py` (Script Huấn luyện Mô hình)
* **Phân chia dữ liệu:** Chia tập bản ghi AFDB thành Train / Test (ví dụ 80/20) kèm khả năng ép cố định một số record vào train/test (`FORCE_TRAIN_RECORDS`, `FORCE_TEST_RECORDS`).
* **Tạo cửa sổ & Lọc Best-K:** Quét tập dữ liệu AFDB để lấy cửa sổ AF và chọn lọc tập cửa sổ Normal (NAF) đạt chuẩn QC.
* **Huấn luyện SVM:**
  * Trích xuất 3 đặc trưng (MSSD, NN50, PE).
  * Huấn luyện mô hình `LinearSVC` đi kèm bước chuẩn hóa `StandardScaler`.
* **Xuất thông số Mô hình & Phần cứng (Hardware Export):**
  * Lưu mô hình đã train ra file `svm_linear.joblib` và metadata vào `svm_linear_meta.json`.
  * **Tính toán trọng số thô ($w_{\text{raw}}, b_{\text{raw}}$):** Chuyển đổi siêu phẳng phân chia sang dạng phương trình tuyến tính thô $y = w_0 \cdot \text{MSSD} + w_1 \cdot \text{NN50} + w_2 \cdot \text{PE} + b$, sẵn sàng nhúng trực tiếp vào C++/Verilog/Phần cứng mà không cần bước Scaler phụ thuộc.

---

### 4. `test_only.py` (Script Kiểm thử trên AFDB / Tập Unseen)
* **Nạp mô hình & Cấu hình:** Đọc mô hình `svm_linear.joblib` và thông số chia dữ liệu từ `svm_linear_meta.json`.
* **Chế độ kiểm thử (`MODE`):**
  * `internal_20`: Đánh giá trên tập test 20% nội bộ tách ra từ AFDB.
  * `unseen_all`: Đánh giá trên tập dữ liệu hoàn toàn mới.
* **Trích xuất & Dự đoán:** Rút trích 3 đặc trưng, dự đoán nhãn bằng quyết định gốc `model.predict()` và tính SVM Decision Score.
* **Đầu ra:** Xuất bảng dữ liệu kết quả dự đoán chi tiết ra `test_raw_results.csv` và in các chỉ số hiệu năng (ACC, Precision, Specificity, Sensitivity).

---

### 5. `LTAFDB_hwsvm.py` (Script Đánh giá Độc lập trên LTAFDB)
* **Đánh giá trên dữ liệu dài hạn (LTAFDB):** Sử dụng mô hình SVM đã được huấn luyện từ AFDB để test trên toàn bộ tập LTAFDB (Long-Term AF Database).
* **Cắt & Lọc cửa sổ chặt chẽ:** Sử dụng hàm tiện ích từ `ltaf_utils_hwsvm.py` để trích xuất các cửa sổ 10s chất lượng cao.
* **Đánh giá & Xuất kết quả:** 
  * Trích xuất 3 đặc trưng (MSSD, NN50, PE).
  * Lưu chi tiết kết quả dự đoán từng cửa sổ ra `LTAF_test_raw_results.csv`.
  * In chỉ số đánh giá độ tổng quát hóa của mô hình trên tập dữ liệu bên ngoài.
