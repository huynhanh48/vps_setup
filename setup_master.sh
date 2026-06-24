#!/bin/bash

# Kiem tra quyen root
if [ "$EUID" -ne 0 ]; then
  echo -e "\e[31m[Loi] Vui long chay script bang quyen root (vi du: sudo ./setup_master.sh)\e[0m"
  exit 1
fi

# Kiem tra xem 5 file script con co nam cung thu muc khong
check_files() {
    local missing=0
    for file in run_hermes_agent.sh run_n8n_vps.sh run_openclaw_vps.sh run_9router.sh run_opendesign_vps.sh; do
        if [ ! -f "$file" ]; then
            echo -e "\e[31m[Loi] Khong tim thay file '$file' trong thu muc hien tai!\e[0m"
            missing=1
        else
            chmod +x "$file" # Tu dong cap quyen thuc thi cho script con
        fi
    done
    if [ $missing -eq 1 ]; then
        echo -e "\e[33mVui long de setup_master.sh cung thu muc voi 5 file tren.\e[0m"
        exit 1
    fi
}

# Hien thi Menu Tuong tac
show_menu() {
    clear
    echo -e "\e[36m=================================================\e[0m"
    echo -e "\e[36m        AI DEVOPS AUTO-DEPLOYMENT MENU           \e[0m"
    echo -e "\e[36m=================================================\e[0m"
    echo "1. Cai dat Hermes Agent"
    echo "2. Cai dat n8n AI Starter Kit"
    echo "3. Cai dat OpenClaw Gateway"
    echo "4. Cai dat 9Router"
    echo "5. Cai dat OpenDesign"
    echo "6. Cai dat TAT CA (Deploy tuan tu 5 dich vu)"
    echo "0. Thoat"
    echo -e "\e[36m=================================================\e[0m"
    read -p "Chon mot tuy chon [0-6]: " choice

    case $choice in
        1)
            echo -e "\n\e[32m=> Dang khoi chay cai dat Hermes...\e[0m"
            ./run_hermes_agent.sh
            ;;
        2)
            echo -e "\n\e[32m=> Dang khoi chay cai dat n8n...\e[0m"
            ./run_n8n_vps.sh
            ;;
        3)
            echo -e "\n\e[32m=> Dang khoi chay cai dat OpenClaw...\e[0m"
            ./run_openclaw_vps.sh
            ;;
        4)
            echo -e "\n\e[32m=> Dang khoi chay cai dat 9Router...\e[0m"
            ./run_9router.sh
            ;;
        5)
            echo -e "\n\e[32m=> Dang khoi chay cai dat OpenDesign...\e[0m"
            ./run_opendesign_vps.sh
            ;;
        6)
            echo -e "\n\e[32m=> DANG KHOI CHAY CAI DAT TOAN BO HE THONG...\e[0m"
            echo -e "\e[33m--- 1/5: HERMES AGENT ---\e[0m"
            ./run_hermes_agent.sh
            
            echo -e "\n\e[33m--- 2/5: N8N AI STARTER ---\e[0m"
            ./run_n8n_vps.sh
            
            echo -e "\n\e[33m--- 3/5: OPENCLAW GATEWAY ---\e[0m"
            ./run_openclaw_vps.sh
            
            echo -e "\n\e[33m--- 4/5: 9ROUTER ---\e[0m"
            ./run_9router.sh
            
            echo -e "\n\e[33m--- 5/5: OPENDESIGN ---\e[0m"
            ./run_opendesign_vps.sh
            
            echo -e "\n\e[32m=================================================\e[0m"
            echo -e "\e[32m      DA HOAN TAT CAI DAT TAT CA DICH VU!        \e[0m"
            echo -e "\e[32m=================================================\e[0m"
            ;;
        0)
            echo "Thoat chuong trinh."
            exit 0
            ;;
        *)
            echo -e "\e[31mLua chon khong hop le!\e[0m"
            sleep 2
            show_menu
            ;;
    esac
}

# Thuc thi
check_files
show_menu
