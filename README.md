# 🚀 AI DevOps VPS Setup

Bộ script Bash tự động hoá toàn diện quá trình cài đặt, cấu hình và triển khai các công cụ AI & DevOps trên VPS Linux. Hệ thống sử dụng kiến trúc modular, cho phép cài đặt độc lập hoặc triển khai toàn bộ stack chỉ với một menu tương tác.

Các dịch vụ được hỗ trợ:
* **Hermes Agent:** AI Agent Dashboard.
* **n8n (AI Starter Kit):** Nền tảng tự động hóa Workflow (tích hợp sẵn Docker, Postgres).
* **OpenClaw Gateway:** Cổng giao tiếp nội bộ/LAN cho các tác nhân AI.
* **9Router:** Hệ thống định tuyến ứng dụng/proxy.
* **OpenDesign:** Môi trường thiết kế mở.

---

## 📋 Yêu cầu hệ thống

* **Hệ điều hành:** Ubuntu / Debian (Khuyến nghị Ubuntu 22.04 LTS hoặc mới hơn).
* **Quyền hạn:** Cần chạy dưới quyền `root` (hoặc thông qua `sudo`).
* **Mạng:** VPS đã được mở các port cơ bản (80, 443) để cấu hình tên miền và SSL.
* **Môi trường:** Đã cài đặt Docker và curl (script hỗ trợ tự động cài đặt nếu VPS chưa có).

---

## ⚙️ Hướng dẫn cài đặt và sử dụng

### 1. Tải mã nguồn về máy chủ
Truy cập vào VPS của bạn và chạy lệnh sau để tải bộ script về:
```bash
git clone https://github.com/huynhanh48/vps_setup.git
cd vps_setup
```

### 2. Chạy script điều khiển (Master Script)
Chạy trực tiếp `setup_master.sh` với quyền root. Script sẽ tự động cấp quyền thực thi cho tất cả các script con nằm cùng thư mục.
```bash
sudo ./setup_master.sh
```

### 3. Chọn tuỳ chọn từ Menu Tương Tác
Khi menu hiện lên, bạn có thể nhập số từ `0` đến `6` để chọn dịch vụ muốn cài đặt:

```text
=================================================
        AI DEVOPS AUTO-DEPLOYMENT MENU           
=================================================
1. Cai dat Hermes Agent
2. Cai dat n8n AI Starter Kit
3. Cai dat OpenClaw Gateway
4. Cai dat 9Router
5. Cai dat OpenDesign
6. Cai dat TAT CA (Deploy tuan tu 5 dich vu)
0. Thoat
=================================================
```

* **Lưu ý:** Nếu bạn thiết lập VPS mới hoàn toàn, nên chọn **Option 6** để cài đặt đầy đủ tất cả các dịch vụ tự động theo thứ tự. Các script con sẽ có thể yêu cầu bạn nhập thông tin cấu hình (như Domain, Email) trong quá trình chạy.
