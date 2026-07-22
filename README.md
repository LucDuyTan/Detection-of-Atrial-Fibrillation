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

