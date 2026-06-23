#!/bin/bash

# Dam bao script duoc chay voi quyen root
if [ "$EUID" -ne 0 ]; then
  echo -e "\e[31m[Loi] Vui long chay script bang quyen root (vi du: sudo ./run_openclaw_vps.sh)\e[0m"
  exit 1
fi

echo -e "\e[36m=================================================\e[0m"
echo -e "\e[36m   TU DONG CAI DAT & CAU HINH OPENCLAW GATEWAY   \e[0m"
echo -e "\e[36m=================================================\e[0m"
echo ""

# ---------------------------------------------------------
# Buoc 0: Cai dat phu thuoc & Don dep loi cu
# ---------------------------------------------------------
if ! command -v curl &> /dev/null || ! command -v jq &> /dev/null || ! command -v openssl &> /dev/null; then
    echo -e "\e[33m[0/4] Cai dat curl, jq, openssl...\e[0m"
    apt-get update -y -qq && apt-get install -y curl jq openssl -qq
fi

systemctl stop openclaw.service 2>/dev/null
systemctl disable openclaw.service 2>/dev/null

# ---------------------------------------------------------
# Buoc 1: Thu thap thong tin tu nguoi dung
# ---------------------------------------------------------
read -p "Nhap Port chay dich vu [Mac dinh: 18789]: " input_port
OC_PORT=${input_port:-18789}

read -p "Nhap Domain cua ban (VD: openclaw.yourdomain.com): " OC_DOMAIN
if [ -z "$OC_DOMAIN" ]; then
    echo -e "\e[31m[Loi] Domain khong duoc de trong!\e[0m"
    exit 1
fi

# ---------------------------------------------------------
# Buoc 2: Cai dat OpenClaw Core
# ---------------------------------------------------------
echo -e "\n\e[33m[1/4] Dang tai va cai dat OpenClaw...\e[0m"
curl -fsSL https://openclaw.ai/install.sh | bash

if [ $? -ne 0 ]; then
    echo -e "\e[31m[Loi] Cai dat OpenClaw that bai! Script dung lai.\e[0m"
    exit 1
fi

export PATH=$PATH:/usr/local/bin
OC_BIN=$(which openclaw 2>/dev/null)
if [ -z "$OC_BIN" ]; then
    OC_BIN="/usr/local/bin/openclaw" 
fi

# ---------------------------------------------------------
# Buoc 3: Tao cau hinh JSON bang jq (Chap nhan loi schema tam thoi)
# ---------------------------------------------------------
echo -e "\e[33m[2/4] Khoi tao va cau hinh he thong...\e[0m"

export HOME=/root
OC_DIR="$HOME/.openclaw"
OC_JSON="$OC_DIR/openclaw.json"

mkdir -p "$OC_DIR"
if [ ! -f "$OC_JSON" ]; then
    echo "{}" > "$OC_JSON"
fi

TMP_JSON=$(mktemp)
jq --argjson port "$OC_PORT" \
   --arg bind "lan" \
   '.gateway.port = $port | 
    .gateway.bind = $bind | 
    .controlUi.allowInsecureAuth = true | 
    .controlUi.dangerouslyDisableDeviceAuth = true | 
    .controlUi.allowedOrigins = ["*"]' "$OC_JSON" > "$TMP_JSON"

mv "$TMP_JSON" "$OC_JSON"
chmod 600 "$OC_JSON"

# ---------------------------------------------------------
# Buoc 4: Cau hinh System-level Service cho LXC
# ---------------------------------------------------------
echo -e "\e[33m[3/4] Cau hinh tien trinh chay ngam cho LXC (Systemd)...\e[0m"

cat > /etc/systemd/system/openclaw.service <<EOF
[Unit]
Description=OpenClaw Gateway Service
After=network.target

[Service]
Type=simple
User=root
Environment="HOME=/root"
Environment="USER=root"
WorkingDirectory=/root
ExecStart=${OC_BIN} gateway run
Restart=always
RestartSec=5
StandardOutput=syslog
StandardError=syslog
SyslogIdentifier=openclaw-gateway

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable openclaw.service
systemctl start openclaw.service >/dev/null 2>&1

# Lay IP noi bo
VPS_IP=$(hostname -I | awk '{print $1}')

# ---------------------------------------------------------
# Buoc 5: In ket qua va Huong dan tao Nginx + Fix Token
# ---------------------------------------------------------
echo -e "\n\e[32m[4/4] CAI DAT HOAN TAT! CHUAN BI KICH HOAT.\e[0m"

echo -e "\e[36m=================================================\e[0m"
echo -e "\e[35mHUONG DAN CAU HINH NGINX & TEN MIEN\e[0m"
echo -e "\e[36m=================================================\e[0m"
echo -e "\e[33m1. Copy toan bo khoi lenh sau de tao Nginx Web Server:\e[0m"
cat <<EOF
cat > /etc/nginx/sites-enabled/${OC_DOMAIN}.conf << 'CONFIG_EOF'
server {
    listen 80;
    server_name ${OC_DOMAIN};

    location / {
        proxy_pass http://${VPS_IP}:${OC_PORT};
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

echo -e "\n\e[33m2. Xin chung chi SSL tren may chu Nginx:\e[0m"
echo -e "  \e[32mnginx -t && nginx -s reload\e[0m"
echo -e "  \e[32mcertbot --nginx -d ${OC_DOMAIN}\e[0m"
echo -e ""

echo -e "\e[31m=================================================\e[0m"
echo -e "\e[31m[QUAN TRONG] BUOC FIX LOI & LAY TOKEN DANG NHAP\e[0m"
echo -e "\e[31m=================================================\e[0m"
echo -e "Ban \e[1mBAT BUOC\e[0m phai chay 2 lenh sau tren Terminal nay"
echo -e "de OpenClaw tu dong sua loi Schema va in ra Token xac thuc:"
echo -e ""
echo -e "  \e[32mopenclaw doctor --fix\e[0m"
echo -e "  \e[32mjq -r '.gateway.auth.token' ~/.openclaw/openclaw.json\e[0m"
echo -e ""
echo -e "\e[33m(Hay copy Token duoc in ra tu lenh tren cung voi URL \e[1mhttps://${OC_DOMAIN}\e[0m de dang nhap Dashboard)\e[0m"
echo -e "\e[31m=================================================\e[0m"
