# 🚀 AI DevOps VPS Setup

Bộ script Bash tự động hoá toàn diện quá trình cài đặt, cấu hình và triển khai các công cụ AI & DevOps trên VPS Linux. Hệ thống sử dụng kiến trúc modular, cho phép cài đặt độc lập hoặc triển khai toàn bộ stack chỉ với một menu tương tác.

Các dịch vụ được hỗ trợ:
* **Hermes Agent:** AI Agent Dashboard.
* **n8n (AI Starter Kit):** Nền tảng tự động hóa Workflow (tích hợp sẵn Docker, Postgres).
* **OpenClaw Gateway:** Cổng giao tiếp nội bộ/LAN cho các tác nhân AI.

---

## 📋 Yêu cầu hệ thống

* **Hệ điều hành:** Ubuntu / Debian (Khuyến nghị Ubuntu 22.04 LTS hoặc mới hơn).
* **Quyền hạn:** Cần chạy dưới quyền `root` (hoặc thông qua `sudo`).
* **Mạng:** VPS đã được mở các port cơ bản (80, 443) để cấu hình tên miền và SSL.

---

## ⚙️ Hướng dẫn cài đặt và sử dụng

### 1. Tải mã nguồn về máy chủ
Truy cập vào VPS của bạn và chạy lệnh sau để tải bộ script về:
```bash
git clone [https://github.com/huynhanh48/vps_setup.git](https://github.com/huynhanh48/vps_setup.git)
cd vps_setup
