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

---

## ⚙️ Kiến trúc hệ thống (System Architecture)

Hệ thống phần cứng được thiết kế theo quy trình **Top-Down** bao gồm hai cấp kiến trúc chính:

### 1. Kiến trúc tổng thể (Overall System Architecture)

![Overall System Architecture](images/overall_architecture.png)

* **PEA Controller**: Khối điều khiển trung tâm phát tín hiệu điều khiển đồng bộ đến toàn bộ 12 phần tử xử lý (PE0 - PE11) để phối hợp chu trình tính toán.
* **Mảng PE (PE0 – PE11)**: Gồm 12 phần tử xử lý hoạt động song song. Mỗi PE đảm nhiệm tính toán trên một cửa sổ dữ liệu 10 giây.
* **Giao tiếp Bus (DATA BUS)**:
  * **RRI (32-bit)**: Tín hiệu chuỗi khoảng RR đầu vào truyền tới mảng PE qua Data Bus.
  * **AF/NAF (1-bit)**: Tín hiệu kết quả chẩn đoán (AFIB hay Non-AFIB) xuất ra Data Bus.

---

### 2. Cấu trúc chi tiết phần tử xử lý (Processing Element Detail)

![Processing Element Architecture](images/pe_architecture.png)

Một phần tử xử lý (PE) bao gồm các thành phần chính:

* **ALU (Arithmetic Logic Unit)**:
  * Nhận lệnh từ tín hiệu điều khiển `CFG_ALU`.
  * Thực hiện các phép toán số học và logic (ADD, SUB, MULT, ACC, ABS, CMP, MAC) qua hai luồng dữ liệu 32-bit kết nối trực tiếp với LSU.
* **LSU (Load/Store Unit)**:
  * Nhận lệnh từ tín hiệu điều khiển `CFG_LSU`.
  * Đóng vai trò bộ điều phối luồng dữ liệu trung tâm kết nối giữa ALU, bộ nhớ nội bộ (Local Data Memory) và khối LUT.
* **Local Data Memory**:
  * **Ping-Pong RAM (32-bit x 64)**: Nhận trực tiếp dữ liệu `RRI` (32-bit) từ bên ngoài; cơ chế bộ nhớ đệm kép cho phép ghi dữ liệu mới song song với quá trình đọc/xử lý dữ liệu cũ.
  * **Uni RAM (32-bit x 64)**: Lưu trữ các kết quả trung gian và xuất trực tiếp tín hiệu chẩn đoán `AF/NAF` (1-bit).
  * **NN50 REG (16-bit)**: Thanh ghi lưu trữ giá trị đếm đặc trưng NN50.
  * **PERM REG[7:0] (16-bit)**: Mảng thanh ghi lưu trữ tần suất các dạng hoán vị phục vụ tính toán Permutation Entropy.
* **LUT (Look-Up Table)**:
  * Bảng tra cứu kết nối với LSU qua bus 32-bit, xấp xỉ các hàm phi tuyến (logarit/phân số) giúp tiết kiệm tài nguyên logic.
* **Định dạng số**: Sử dụng định dạng số nguyên cố định có dấu **Signed Fixed-point Q16.16**.

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
| **Tần số tối đa (Fmax)** | 130 MHz |
