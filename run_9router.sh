#!/bin/bash

# =========================================================
# N9ROUTER AUTO INSTALL SCRIPT
# =========================================================

if [ "$EUID" -ne 0 ]; then
  echo -e "\e[31m[Loi] Vui long chay script bang quyen root (VD: sudo ./install_n9router.sh)\e[0m"
  exit 1
fi

echo -e "\e[36m=================================================\e[0m"
echo -e "\e[36m      TU DONG CAI DAT N9ROUTER TREN VPS         \e[0m"
echo -e "\e[36m=================================================\e[0m"
echo ""

echo -e "\e[33m[0/3] Kiem tra phu thuoc he thong...\e[0m"

if ! command -v curl &> /dev/null; then
    apt-get update -y -qq
    apt-get install -y curl -qq
fi

if ! command -v docker &> /dev/null; then
    echo -e "\e[33mChua co Docker. Dang cai dat Docker Engine...\e[0m"
    curl -fsSL https://get.docker.com -o get-docker.sh
    sh get-docker.sh
    rm get-docker.sh
else
    echo "Docker da duoc cai dat. Bo qua."
fi

echo ""
echo -e "\e[33m[1/3] Thu thap thong tin cau hinh...\e[0m"

read -p "Nhap Domain (VD: 9router.yourdomain.com): " N9_DOMAIN

if [ -z "$N9_DOMAIN" ]; then
    echo -e "\e[31m[Loi] Domain khong duoc de trong!\e[0m"
    exit 1
fi

read -p "Port [Mac dinh: 20128]: " INPUT_PORT
N9_PORT=${INPUT_PORT:-20128}

read -p "JWT_SECRET [Mac dinh: change-this-secret]: " INPUT_JWT
JWT_SECRET=${INPUT_JWT:-change-this-secret}

read -sp "INITIAL_PASSWORD [Mac dinh: change-this-password]: " INPUT_PASS
echo ""
INITIAL_PASSWORD=${INPUT_PASS:-change-this-password}

read -p "NEXT_PUBLIC_BASE_URL [Mac dinh: https://${N9_DOMAIN}]: " INPUT_BASEURL
NEXT_PUBLIC_BASE_URL=${INPUT_BASEURL:-https://${N9_DOMAIN}}

echo ""
echo -e "\e[33m[2/3] Dang tai va khoi dong N9Router...\e[0m"

docker rm -f n9router >/dev/null 2>&1 || true
docker volume create n9router-data >/dev/null 2>&1 || true

docker pull nightwalker8x/n9router:latest

docker run -d \
  --name n9router \
  --restart unless-stopped \
  --log-opt max-size=10m \
  --log-opt max-file=3 \
  -p ${N9_PORT}:20128 \
  -e JWT_SECRET="${JWT_SECRET}" \
  -e INITIAL_PASSWORD="${INITIAL_PASSWORD}" \
  -e NEXT_PUBLIC_BASE_URL="${NEXT_PUBLIC_BASE_URL}" \
  -v n9router-data:/app/data \
  nightwalker8x/n9router:latest

sleep 10

if [ "$(docker inspect -f '{{.State.Running}}' n9router 2>/dev/null)" != "true" ]; then
    echo -e "\e[31m[Loi] Container N9Router khong khoi dong duoc!\e[0m"
    echo "Xem log bang lenh: docker logs n9router"
    exit 1
fi

VPS_IP=$(hostname -I | awk '{print $1}')

echo ""
echo -e "\e[32m[3/3] CAI DAT HOAN TAT! N9ROUTER DANG CHAY.\e[0m"

echo -e "\e[36m=================================================\e[0m"
echo -e "\e[35mHUONG DAN CAU HINH NGINX & TEN MIEN\e[0m"
echo -e "\e[36m=================================================\e[0m"

cat <<EOF

cat > /etc/nginx/sites-enabled/${N9_DOMAIN}.conf << 'CONFIG_EOF'
server {
    listen 80;
    server_name ${N9_DOMAIN};

    location / {
        proxy_pass http://${VPS_IP}:${N9_PORT};

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

echo ""
echo "nginx -t && nginx -s reload"
echo "certbot --nginx -d ${N9_DOMAIN}"

echo ""
echo "URL Dashboard LAN : http://${VPS_IP}:${N9_PORT}"
echo "URL Dashboard Web : https://${N9_DOMAIN}"
