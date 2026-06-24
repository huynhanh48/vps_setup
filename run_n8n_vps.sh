#!/bin/bash

# Dam bao script duoc chay voi quyen root
if [ "$EUID" -ne 0 ]; then
  echo -e "\e[31m[Loi] Vui long chay script bang quyen root (vi du: sudo ./run_n8n_vps.sh)\e[0m"
  exit 1
fi

echo -e "\e[36m=================================================\e[0m"
echo -e "\e[36m   TU DONG CAI DAT & CAU HINH N8N AI STARTER     \e[0m"
echo -e "\e[36m=================================================\e[0m"
echo ""

# ---------------------------------------------------------
# Buoc 0: Kiem tra va cai dat Git, Docker, Openssl
# ---------------------------------------------------------
echo -e "\e[33m[0/4] Kiem tra phu thuoc he thong...\e[0m"

# Cai dat git, curl & openssl neu chua co
if ! command -v git &> /dev/null || ! command -v openssl &> /dev/null || ! command -v curl &> /dev/null; then
    echo "Dang cai dat git, curl va openssl..."
    apt-get update -y -qq && apt-get install -y git curl openssl -qq
fi

# Cai dat Docker neu chua co
if ! command -v docker &> /dev/null; then
    echo -e "\e[33mChua co Docker. Dang cai dat Docker Engine tu get.docker.com...\e[0m"
    curl -fsSL https://get.docker.com -o get-docker.sh
    sh get-docker.sh
    rm get-docker.sh
    echo "Cai dat Docker hoan tat!"
else
    echo "Docker da duoc cai dat. Bo qua."
fi

# ---------------------------------------------------------
# Buoc 1: Thu thap thong tin tu nguoi dung
# ---------------------------------------------------------
read -p "POSTGRES_USER [Mac dinh: root]: " input_pg_user
PG_USER=${input_pg_user:-root}

read -sp "POSTGRES_PASSWORD [Mac dinh: password]: " input_pg_pass
echo ""
PG_PASS=${input_pg_pass:-password}

read -p "POSTGRES_DB [Mac dinh: n8n]: " input_pg_db
PG_DB=${input_pg_db:-n8n}

read -p "Nhap Domain cua ban (VD: n8n.yourdomain.com): " N8N_DOMAIN
if [ -z "$N8N_DOMAIN" ]; then
    echo -e "\e[31m[Loi] Domain khong duoc de trong!\e[0m"
    exit 1
fi

# ---------------------------------------------------------
# Buoc 2: Clone Repository
# ---------------------------------------------------------
echo -e "\n\e[33m[1/4] Dang tai Source Code tu Github...\e[0m"
REPO_DIR="self-hosted-ai-starter-kit"

# Xoa thu muc cu neu ton tai de tai ban moi nhat
if [ -d "$REPO_DIR" ]; then
    rm -rf "$REPO_DIR"
fi

git clone https://github.com/n8n-io/self-hosted-ai-starter-kit.git
cd "$REPO_DIR" || exit 1

# ---------------------------------------------------------
# Buoc 3: Cau hinh file .env
# ---------------------------------------------------------
echo -e "\e[33m[2/4] Khoi tao file .env va sinh khoa bao mat...\e[0m"

cp .env.example .env

# Sinh khoa Random cho n8n
N8N_ENC_KEY=$(openssl rand -hex 24)
N8N_JWT_SECRET=$(openssl rand -hex 24)

# Ghi de cac thong so Database vao file .env
sed -i "s/^POSTGRES_USER=.*/POSTGRES_USER=${PG_USER}/" .env
sed -i "s/^POSTGRES_PASSWORD=.*/POSTGRES_PASSWORD=${PG_PASS}/" .env
sed -i "s/^POSTGRES_DB=.*/POSTGRES_DB=${PG_DB}/" .env

# Ghi de khoa bao mat
sed -i "s/^N8N_ENCRYPTION_KEY=.*/N8N_ENCRYPTION_KEY=${N8N_ENC_KEY}/" .env
sed -i "s/^N8N_USER_MANAGEMENT_JWT_SECRET=.*/N8N_USER_MANAGEMENT_JWT_SECRET=${N8N_JWT_SECRET}/" .env

# FIX LOI KINH DIEN: Them N8N_SECURE_COOKIE=false de hoat dong sau Nginx Proxy
echo "" >> .env
echo "# Fix for Reverse Proxy HTTP/HTTPS issues" >> .env
echo "N8N_SECURE_COOKIE=false" >> .env

# ---------------------------------------------------------
# Buoc 4: Khoi chay bang Docker Compose
# ---------------------------------------------------------
echo -e "\e[33m[3/4] Dang build va khoi chay Docker Compose (Co the mat vai phut)...\e[0m"
docker compose up -d

# ---------------------------------------------------------
# Buoc 5: In huong dan Nginx Post-Install & URL
# ---------------------------------------------------------
VPS_IP=$(hostname -I | awk '{print $1}')
N8N_PORT=5678 # Cong mac dinh cua n8n

echo -e "\n\e[32m[4/4] CAI DAT HOAN TAT! N8N DANG CHAY TREN DOCKER.\e[0m"
echo -e "\e[36m=================================================\e[0m"
echo -e "\e[35mHUONG DAN CAU HINH NGINX & TEN MIEN\e[0m"
echo -e "\e[36m=================================================\e[0m"

echo -e "\e[33m1. Copy toan bo khoi lenh sau de tao Nginx Web Server:\e[0m"
cat <<EOF
cat > /etc/nginx/sites-enabled/${N8N_DOMAIN}.conf << 'CONFIG_EOF'
server {
    listen 80;
    server_name ${N8N_DOMAIN};

    location / {
        proxy_pass http://${VPS_IP}:${N8N_PORT};
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
EOF

echo -e "\n\e[33m2. Xin chung chi SSL tren may chu Nginx:\e[0m"
echo -e "  \e[32mnginx -t && nginx -s reload\e[0m"
echo -e "  \e[32mcertbot --nginx -d ${N8N_DOMAIN}\e[0m"

echo -e "\n\e[36m=================================================\e[0m"
echo -e "\e[32mTHONG TIN TRUY CAP N8N DASHBOARD\e[0m"
echo -e "\e[36m=================================================\e[0m"
echo -e "URL Dashboard LAN   : \e[1mhttp://${VPS_IP}:${N8N_PORT}\e[0m"
echo -e "URL Dashboard Web   : \e[1mhttps://${N8N_DOMAIN}\e[0m"
echo -e "\e[33m(Hay truy cap vao mot trong hai duong dan tren de tao tai khoan Admin dau tien)\e[0m"
echo -e "\e[36m=================================================\e[0m"
