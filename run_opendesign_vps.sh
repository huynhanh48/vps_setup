#!/bin/bash

# Dam bao script duoc chay voi quyen root
if [ "$EUID" -ne 0 ]; then
  echo -e "\e[31m[Loi] Vui long chay script bang quyen root (vi du: sudo ./run_opendesign_vps.sh)\e[0m"
  exit 1
fi

echo -e "\e[36m=================================================\e[0m"
echo -e "\e[36m   TU DONG CAI DAT OPEN DESIGN (NATIVE OS)       \e[0m"
echo -e "\e[36m=================================================\e[0m"
echo ""

# ---------------------------------------------------------
# Buoc 0: Kiem tra va cai dat Git, Curl, Openssl, NodeJS
# ---------------------------------------------------------
echo -e "\e[33m[0/5] Kiem tra va cai dat moi truong (NodeJS, pnpm)...\e[0m"

apt-get update -y -qq && apt-get install -y git openssl curl build-essential -qq

# Cai dat NodeJS (Ban 22.x hoac moi nhat an toan)
if ! command -v node &> /dev/null; then
    echo "Dang cai dat NodeJS..."
    curl -fsSL https://deb.nodesource.com/setup_22.x | bash - > /dev/null 2>&1
    apt-get install -y nodejs -qq
fi

# Kich hoat corepack de dung pnpm (Trinh quan ly goi cua Node)
corepack enable
npm install -g pnpm > /dev/null 2>&1

# ---------------------------------------------------------
# Buoc 1: Thu thap thong tin tu nguoi dung
# ---------------------------------------------------------
read -p "Nhap Port chay dich vu [Mac dinh: 7456]: " input_port
OD_PORT=${input_port:-7456}

read -p "Nhap Domain cua ban (VD: opendesign.yourdomain.com): " OD_DOMAIN
if [ -z "$OD_DOMAIN" ]; then
    echo -e "\e[31m[Loi] Domain khong duoc de trong!\e[0m"
    exit 1
fi

# ---------------------------------------------------------
# Buoc 2: Clone Repository & Cai dat thu vien
# ---------------------------------------------------------
echo -e "\n\e[33m[1/5] Kiem tra Source Code Open Design...\e[0m"
export HOME=/root
REPO_DIR="/root/open-design"

if [ -d "$REPO_DIR" ]; then
    echo -e "\e[32mThu muc '$REPO_DIR' da ton tai. Chi cap nhat thu vien...\e[0m"
    cd "$REPO_DIR"
else
    echo "Dang tai Source Code tu Github..."
    cd /root
    git clone https://github.com/nexu-io/open-design.git
    cd "$REPO_DIR"
fi

echo "Dang tai thu vien pnpm (Vui long doi vai phut)..."
pnpm install

# ---------------------------------------------------------
# Buoc 3: Cau hinh file .env
# ---------------------------------------------------------
echo -e "\n\e[33m[2/5] Khoi tao file .env va sinh token bao mat...\e[0m"

# Sinh Token Random
OD_TOKEN=$(openssl rand -hex 32)

cat > "$REPO_DIR/.env" <<EOF
NODE_ENV=production
OD_BIND_HOST=0.0.0.0
OD_HOST=0.0.0.0
OD_PORT=${OD_PORT}
OD_WEB_PORT=${OD_PORT}
OD_API_TOKEN=${OD_TOKEN}
OD_ALLOWED_ORIGINS=https://${OD_DOMAIN},http://${OD_DOMAIN}
EOF

# ---------------------------------------------------------
# Buoc 4: Build production web app
# ---------------------------------------------------------
echo -e "\n\e[33m[3/5] Build production web app...\e[0m"
cd "$REPO_DIR"

# Kiem tra va tao 2GB Swap de tranh loi Out of Memory khi build
if [ $(swapon --show | wc -l) -eq 0 ]; then
    echo -e "\e[33mKhong tim thay Swap. Dang tao 2GB Swap de tranh loi Out of Memory...\e[0m"
    fallocate -l 2G /swapfile
    chmod 600 /swapfile
    mkswap /swapfile
    swapon /swapfile
    echo '/swapfile none swap sw 0 0' >> /etc/fstab
fi

export NODE_OPTIONS="--max-old-space-size=4096"
pnpm --filter @open-design/web build

# ---------------------------------------------------------
# Buoc 5: Khoi tao Systemd Service de chay ngam
# ---------------------------------------------------------
echo -e "\e[33m[4/5] Cau hinh tien trinh chay ngam Systemd...\e[0m"

PNPM_BIN=$(which pnpm)
OD_DAEMON_PORT=$((OD_PORT + 1))

cat > /etc/systemd/system/opendesign.service <<EOF
[Unit]
Description=Open Design Native Service
After=network.target

[Service]
Type=simple
User=root
WorkingDirectory=${REPO_DIR}
EnvironmentFile=${REPO_DIR}/.env
Environment="PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"
ExecStart=${PNPM_BIN} tools-dev run web --prod --web-port ${OD_PORT} --daemon-port ${OD_DAEMON_PORT}
Restart=always
RestartSec=5
StandardOutput=syslog
StandardError=syslog
SyslogIdentifier=opendesign

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable opendesign.service
systemctl restart opendesign.service

# ---------------------------------------------------------
# Buoc 6: In huong dan Nginx Post-Install & URL
# ---------------------------------------------------------
VPS_IP=$(hostname -I | awk '{print $1}')

echo -e "\n\e[32m[5/5] CAI DAT HOAN TAT! OPEN DESIGN DANG CHAY.\e[0m"
echo -e "\e[36m=================================================\e[0m"
echo -e "\e[35mHUONG DAN CAU HINH NGINX & TEN MIEN\e[0m"
echo -e "\e[36m=================================================\e[0m"

echo -e "\e[33m1. Tao Nginx Web Server:\e[0m"
cat <<NGINX_EOF
cat > /etc/nginx/sites-enabled/${OD_DOMAIN}.conf << 'CONFIG_EOF'
server {
    listen 80;
    server_name ${OD_DOMAIN};

    location / {
        proxy_pass http://${VPS_IP}:${OD_PORT};
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;

        client_max_body_size 50M;
    }
}
CONFIG_EOF
NGINX_EOF

echo -e "\n\e[33m2. Xin chung chi SSL:\e[0m"
echo -e "  \e[32mnginx -t && nginx -s reload\e[0m"
echo -e "  \e[32mcertbot --nginx -d ${OD_DOMAIN}\e[0m"

echo -e "\n\e[36m=================================================\e[0m"
echo -e "\e[32mTHONG TIN TRUY CAP OPEN DESIGN\e[0m"
echo -e "\e[36m=================================================\e[0m"
echo -e "URL Dashboard LAN   : \e[1mhttp://${VPS_IP}:${OD_PORT}\e[0m"
echo -e "URL Dashboard Web   : \e[1mhttps://${OD_DOMAIN}\e[0m"
echo -e "API Token xac thuc  : \e[1m${OD_TOKEN}\e[0m"
echo -e "\e[33m(Log: journalctl -u opendesign -f)\e[0m"
echo -e "\e[36m=================================================\e[0m"
