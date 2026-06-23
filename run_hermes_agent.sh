#!/bin/bash

# Dam bao script duoc chay voi quyen root
if [ "$EUID" -ne 0 ]; then
  echo -e "\e[31m[Loi] Vui long chay script bang quyen root (vi du: sudo ./run_hermes_vps.sh)\e[0m"
  exit 1
fi

echo -e "\e[36m=================================================\e[0m"
echo -e "\e[36m    TU DONG CAI DAT & CAU HINH HERMES AGENT      \e[0m"
echo -e "\e[36m=================================================\e[0m"
echo ""

# ---------------------------------------------------------
# Buoc 0: Kiem tra va cai dat cac cong cu can thiet (curl, openssl)
# ---------------------------------------------------------
if ! command -v curl &> /dev/null || ! command -v openssl &> /dev/null; then
    echo -e "\e[33m[0/4] Phat hien thieu 'curl' hoac 'openssl'. Dang tien hanh cai dat...\e[0m"
    apt-get update -y -qq && apt-get install -y curl openssl -qq
    if [ $? -ne 0 ]; then
        echo -e "\e[31m[Loi] Khong the cai dat curl. Vui long kiem tra lai ket noi mang cua VPS.\e[0m"
        exit 1
    fi
fi

# ---------------------------------------------------------
# Buoc 1: Thu thap thong tin tu nguoi dung
# ---------------------------------------------------------
read -p "Nhap Username cho Dashboard [Mac dinh: admin]: " input_user
HERMES_USER=${input_user:-admin}

read -sp "Nhap Password cho Dashboard: " HERMES_PASS
echo ""
if [ -z "$HERMES_PASS" ]; then
    echo -e "\e[31m[Loi] Password khong duoc de trong!\e[0m"
    exit 1
fi

read -p "Nhap Port chay dich vu [Mac dinh: 9119]: " input_port
HERMES_PORT=${input_port:-9119}

read -p "Nhap Domain cua ban (VD: hermes.yourdomain.com): " HERMES_DOMAIN
if [ -z "$HERMES_DOMAIN" ]; then
    echo -e "\e[31m[Loi] Domain khong duoc de trong!\e[0m"
    exit 1
fi

# ---------------------------------------------------------
# Buoc 2: Cai dat Hermes Agent
# ---------------------------------------------------------
echo -e "\n\e[33m[1/4] Dang tai va cai dat Hermes Agent tu NousResearch...\e[0m"
curl -fsSL https://hermes-agent.nousresearch.com/install.sh | bash

# Kiem tra xem tien trinh cai dat co thanh cong khong
if [ $? -ne 0 ]; then
    echo -e "\e[31m[Loi] Cai dat Hermes Agent that bai! Script da bi dung lai.\e[0m"
    exit 1
fi

# ---------------------------------------------------------
# Buoc 3: Tao cau hinh .env
# ---------------------------------------------------------
echo -e "\e[33m[2/4] Khoi tao moi truong bao mat...\e[0m"
mkdir -p ~/.hermes
HERMES_SECRET=$(openssl rand -base64 32)

cat > ~/.hermes/.env <<EOF
HERMES_DASHBOARD_BASIC_AUTH_USERNAME=${HERMES_USER}
HERMES_DASHBOARD_BASIC_AUTH_PASSWORD=${HERMES_PASS}
# Recommended: a stable signing secret so sessions survive restarts.
HERMES_DASHBOARD_BASIC_AUTH_SECRET=${HERMES_SECRET}
EOF

chmod 600 ~/.hermes/.env

# Lay duong dan tuyet doi cua lenh hermes
HERMES_BIN=$(which hermes 2>/dev/null)
if [ -z "$HERMES_BIN" ]; then
    HERMES_BIN="/usr/local/bin/hermes" # Fallback path
fi

# ---------------------------------------------------------
# Buoc 4: Tao va kich hoat Systemd Service
# ---------------------------------------------------------
echo -e "\e[33m[3/4] Cau hinh tien trinh chay ngam (Systemd)...\e[0m"

cat > /etc/systemd/system/hermes.service <<EOF
[Unit]
Description=Hermes Dashboard Service
After=network.target

[Service]
Type=simple
User=root
WorkingDirectory=/root
ExecStart=${HERMES_BIN} dashboard --no-open --host 0.0.0.0 --port ${HERMES_PORT}
Restart=always
RestartSec=5
StandardOutput=syslog
StandardError=syslog
SyslogIdentifier=hermes-dashboard

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable hermes.service
systemctl restart hermes.service

# Lay IP noi bo cua VPS hien tai de huong dan proxy
VPS_IP=$(hostname -I | awk '{print $1}')

# ---------------------------------------------------------
# Buoc 5: In huong dan Post-Install
# ---------------------------------------------------------
echo -e "\n\e[32m[4/4] CAI DAT HOAN TAT! SERVICE DANG CHAY NGAM.\e[0m"
echo -e "\e[36m=================================================\e[0m"
echo -e "\e[35mHUONG DAN CAU HINH NGINX & TEN MIEN\e[0m"
echo -e "\e[36m=================================================\e[0m"
echo -e "Hay thuc hien cac buoc sau tren may chu chua \e[1mNginx Web Server\e[0m cua ban:\n"

echo -e "\e[33m1. Copy toan bo khoi lenh sau dan vao terminal de tao file Nginx:\e[0m"
cat <<EOF
cat > /etc/nginx/sites-enabled/${HERMES_DOMAIN}.conf << 'CONFIG_EOF'
server {
    listen 80;
    server_name ${HERMES_DOMAIN};

    location / {
        proxy_pass http://${VPS_IP}:${HERMES_PORT};
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
    }
}
CONFIG_EOF
EOF

echo -e "\n\e[33m2. Tro ban ghi DNS:\e[0m"
echo -e "Truy cap trang quan ly ten mien, tao ban ghi \e[1mA\e[0m cho host \e[1m@\e[0m (hoac \e[1m${HERMES_DOMAIN}\e[0m)"
echo -e "Tro ve dia chi \e[1mPublic IP\e[0m cua mang nha ban."

echo -e "\n\e[33m3. Kiem tra, nap cau hinh va xin SSL:\e[0m"
echo -e "Chay lan luot 3 lenh sau:"
echo -e "  \e[32mnginx -t\e[0m"
echo -e "  \e[32mnginx -s reload\e[0m"
echo -e "  \e[32mcertbot --nginx -d ${HERMES_DOMAIN}\e[0m"
echo -e "\e[36m=================================================\e[0m"
echo -e "Trang thai Service hien tai:"
systemctl status hermes.service --no-pager | head -n 3
