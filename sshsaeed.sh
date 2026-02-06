#!/bin/bash

###########################################
#         SSH Tunnel Manager Panel        #
#         GitHub: sshsaeed                #
#         Version: 1.0.0                  #
###########################################

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
WHITE='\033[1;37m'
NC='\033[0m' # No Color

# Config file
CONFIG_FILE="/etc/sshsaeed/config.conf"
LOG_FILE="/var/log/sshsaeed.log"
BACKUP_DIR="/etc/sshsaeed/backups"

# Default values
DEFAULT_TUNNEL_COUNT=3
DEFAULT_CIPHER="aes128-gcm@openssh.com"
DEFAULT_PORTS="443,80"

###########################################
#            Helper Functions             #
###########################################

log_message() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" >> "$LOG_FILE"
}

print_banner() {
    clear
    echo -e "${CYAN}"
    echo "╔═══════════════════════════════════════════════════════════╗"
    echo "║                                                           ║"
    echo "║     ███████╗███████╗██╗  ██╗███████╗ █████╗ ███████╗     ║"
    echo "║     ██╔════╝██╔════╝██║  ██║██╔════╝██╔══██╗██╔════╝     ║"
    echo "║     ███████╗███████╗███████║███████╗███████║█████╗       ║"
    echo "║     ╚════██║╚════██║██╔══██║╚════██║██╔══██║██╔══╝       ║"
    echo "║     ███████║███████║██║  ██║███████║██║  ██║███████╗     ║"
    echo "║     ╚══════╝╚══════╝╚═╝  ╚═╝╚══════╝╚═╝  ╚═╝╚══════╝     ║"
    echo "║                                                           ║"
    echo "║            SSH Tunnel Manager Panel v1.0                  ║"
    echo "╚═══════════════════════════════════════════════════════════╝"
    echo -e "${NC}"
}

print_separator() {
    echo -e "${BLUE}━━━━━━━━━━━${NC}"
}

press_enter() {
    echo ""
    echo -e "${YELLOW}برای ادامه Enter بزنید...${NC}"
    read
}

check_root() {
    if [[ $EUID -ne 0 ]]; then
        echo -e "${RED}این اسکریپت نیاز به دسترسی root دارد!${NC}"
        echo -e "${YELLOW}لطفاً با sudo اجرا کنید: sudo bash sshsaeed.sh${NC}"
        exit 1
    fi
}

load_config() {
    if [[ -f "$CONFIG_FILE" ]]; then
        source "$CONFIG_FILE"
    else
        # Set defaults
        FOREIGN_IP=""
        IRAN_IP=""
        TUNNEL_COUNT=$DEFAULT_TUNNEL_COUNT
        CIPHER=$DEFAULT_CIPHER
        PORTS=$DEFAULT_PORTS
        INSTALLED="false"
    fi
}

save_config() {
    mkdir -p /etc/sshsaeed
    cat > "$CONFIG_FILE" << EOF
# SSHSaeed Configuration
FOREIGN_IP="$FOREIGN_IP"
IRAN_IP="$IRAN_IP"
TUNNEL_COUNT="$TUNNEL_COUNT"
CIPHER="$CIPHER"
PORTS="$PORTS"
INSTALLED="$INSTALLED"
EOF
    log_message "Config saved"
}

show_current_config() {
    echo -e "${PURPLE}┌─────────────────────────────────────┐${NC}"
    echo -e "${PURPLE}│       تنظیمات فعلی                  │${NC}"
    echo -e "${PURPLE}├─────────────────────────────────────┤${NC}"
    echo -e "${PURPLE}│${NC} سرور خارج:    ${GREEN}${FOREIGN_IP:-تنظیم نشده}${NC}"
    echo -e "${PURPLE}│${NC} سرور ایران:   ${GREEN}${IRAN_IP:-تنظیم نشده}${NC}"
    echo -e "${PURPLE}│${NC} تعداد تانل:   ${GREEN}${TUNNEL_COUNT:-3}${NC}"
    echo -e "${PURPLE}│${NC} رمزنگاری:     ${GREEN}${CIPHER:-aes128-gcm}${NC}"
    echo -e "${PURPLE}│${NC} پورت‌ها:       ${GREEN}${PORTS:-443,80}${NC}"
    echo -e "${PURPLE}│${NC} وضعیت نصب:    ${GREEN}${INSTALLED:-false}${NC}"
    echo -e "${PURPLE}└─────────────────────────────────────┘${NC}"
}

###########################################
#          1. Ping Test                   #
###########################################

ping_test() {
    print_banner
    echo -e "${CYAN}═══════════════════════════════════════${NC}"
    echo -e "${CYAN}         تست پینگ سرورها              ${NC}"
    echo -e "${CYAN}═══════════════════════════════════════${NC}"
    echo ""
    
    if [[ -z "$FOREIGN_IP" ]]; then
        echo -e "${RED}IP سرور خارج تنظیم نشده!${NC}"
        press_enter
        return
    fi
    
    echo -e "${YELLOW}در حال تست پینگ به سرور خارج ($FOREIGN_IP)...${NC}"
    echo ""
    
    if ping -c 4 "$FOREIGN_IP" 2>/dev/null; then
        echo ""
        echo -e "${GREEN}✅ اتصال به سرور خارج برقرار است${NC}"
    else
        echo ""
        echo -e "${RED}❌ اتصال به سرور خارج برقرار نیست${NC}"
    fi
    
    echo ""
    print_separator
    
    # Test SSH connection
    echo -e "${YELLOW}در حال تست اتصال SSH...${NC}"
    if timeout 10 ssh -o BatchMode=yes -o ConnectTimeout=5 -o StrictHostKeyChecking=no root@"$FOREIGN_IP" "echo 'SSH OK'" 2>/dev/null; then
        echo -e "${GREEN}✅ اتصال SSH برقرار است${NC}"
    else
        echo -e "${RED}❌ اتصال SSH برقرار نیست (کلید SSH تنظیم نشده یا سرور در دسترس نیست)${NC}"
    fi
    
    log_message "Ping test executed for $FOREIGN_IP"
    press_enter
}

###########################################
#          2. AES Cipher Test             #
###########################################

aes_test() {
    print_banner
    echo -e "${CYAN}═══════════════════════════════════════${NC}"
    echo -e "${CYAN}      تست رمزنگاری AES-128-GCM        ${NC}"
    echo -e "${CYAN}═══════════════════════════════════════${NC}"
    echo ""
    
    if [[ -z "$FOREIGN_IP" ]]; then
        echo -e "${RED}IP سرور خارج تنظیم نشده!${NC}"
        press_enter
        return
    fi
    
    echo -e "${YELLOW}در حال تست Cipher: $CIPHER${NC}"
    echo ""
    
    # Test cipher support
    echo -e "${BLUE}1. بررسی پشتیبانی سرور از Cipher...${NC}"
    
    RESULT=$(timeout 15 ssh -v -o BatchMode=yes -o ConnectTimeout=10 -o StrictHostKeyChecking=no -c "$CIPHER" root@"$FOREIGN_IP" "echo 'CIPHER_TEST_OK'" 2>&1)
    
    if echo "$RESULT" | grep -q "CIPHER_TEST_OK"; then
        echo -e "${GREEN}✅ سرور از $CIPHER پشتیبانی می‌کند${NC}"
        echo ""
        echo -e "${BLUE}2. جزئیات اتصال:${NC}"
        echo "$RESULT" | grep -E "(cipher|kex|mac)" | head -5
    else
        echo -e "${RED}❌ خطا در تست Cipher${NC}"
        echo ""
        echo -e "${YELLOW}جزئیات خطا:${NC}"
        echo "$RESULT" | tail -10
    fi
    
    log_message "AES cipher test executed"
    press_enter
}

###########################################
#       3. Setup Foreign Server           #
###########################################

setup_foreign() {
    print_banner
    echo -e "${CYAN}═══════════════════════════════════════${NC}"
    echo -e "${CYAN}       تنظیم سرور خارج (Kharej)       ${NC}"
    echo -e "${CYAN}═══════════════════════════════════════${NC}"
    echo ""
    
    echo -e "${YELLOW}IP فعلی سرور خارج: ${GREEN}${FOREIGN_IP:-تنظیم نشده}${NC}"
    echo ""
    echo -e "${BLUE}IP جدید سرور خارج را وارد کنید (خالی = بدون تغییر):${NC}"
    read -r NEW_IP
    
    if [[ -n "$NEW_IP" ]]; then
        FOREIGN_IP="$NEW_IP"
        save_config
        echo -e "${GREEN}✅ IP سرور خارج ذخیره شد: $FOREIGN_IP${NC}"
    fi
    
    echo ""
    print_separator
    echo ""
    
    echo -e "${YELLOW}آیا می‌خواهید سرور خارج را تنظیم کنید؟ (y/n)${NC}"
    read -r CONFIRM
    
    if [[ "$CONFIRM" != "y" ]]; then
        return
    fi
    
    echo ""
    echo -e "${BLUE}در حال اتصال به سرور خارج و تنظیم...${NC}"
    
    # Commands to run on foreign server
    ssh -o StrictHostKeyChecking=no root@"$FOREIGN_IP" << 'REMOTE_SCRIPT'
    
    echo "=== تنظیم سرور خارج ==="
    
    # Update sshd_config
    echo "در حال تنظیم SSH..."
    
    # Enable GatewayPorts
    sed -i 's/#GatewayPorts no/GatewayPorts yes/' /etc/ssh/sshd_config
    sed -i 's/GatewayPorts no/GatewayPorts yes/' /etc/ssh/sshd_config
    grep -q "^GatewayPorts" /etc/ssh/sshd_config || echo "GatewayPorts yes" >> /etc/ssh/sshd_config
    
    # Enable TCPKeepAlive
    sed -i 's/#TCPKeepAlive yes/TCPKeepAlive yes/' /etc/ssh/sshd_config
    grep -q "^TCPKeepAlive" /etc/ssh/sshd_config || echo "TCPKeepAlive yes" >> /etc/ssh/sshd_config
    
    # ClientAliveInterval
    sed -i 's/#ClientAliveInterval 0/ClientAliveInterval 30/' /etc/ssh/sshd_config
    grep -q "^ClientAliveInterval" /etc/ssh/sshd_config || echo "ClientAliveInterval 30" >> /etc/ssh/sshd_config
    
    # ClientAliveCountMax
    sed -i 's/#ClientAliveCountMax 3/ClientAliveCountMax 10/' /etc/ssh/sshd_config
    grep -q "^ClientAliveCountMax" /etc/ssh/sshd_config || echo "ClientAliveCountMax 10" >> /etc/ssh/sshd_config
    
    # Restart SSH
    systemctl restart sshd
    
    echo "✅ تنظیمات SSH اعمال شد"
    
REMOTE_SCRIPT

    if [[ $? -eq 0 ]]; then
        echo -e "${GREEN}✅ سرور خارج با موفقیت تنظیم شد${NC}"
        log_message "Foreign server configured: $FOREIGN_IP"
    else
        echo -e "${RED}❌ خطا در تنظیم سرور خارج${NC}"
    fi
    
    press_enter
}

###########################################
#        4. Setup Iran Server             #
###########################################

setup_iran() {
    print_banner
    echo -e "${CYAN}═══════════════════════════════════════${NC}"
    echo -e "${CYAN}        تنظیم سرور ایران (Iran)       ${NC}"
    echo -e "${CYAN}═══════════════════════════════════════${NC}"
    echo ""
    
    # Get current server IP
    CURRENT_IP=$(hostname -I | awk '{print $1}')
    IRAN_IP="$CURRENT_IP"
    
    echo -e "${YELLOW}IP این سرور: ${GREEN}$IRAN_IP${NC}"
    echo ""
    
    show_current_config
    echo ""
    
    # Check if foreign IP is set
    if [[ -z "$FOREIGN_IP" ]]; then
        echo -e "${RED}❌ ابتدا IP سرور خارج را تنظیم کنید!${NC}"
        press_enter
        return
    fi
    
    # Ask for tunnel count
    echo -e "${BLUE}تعداد تانل‌ها را وارد کنید (پیش‌فرض: $TUNNEL_COUNT):${NC}"
    read -r NEW_COUNT
    if [[ -n "$NEW_COUNT" ]] && [[ "$NEW_COUNT" =~ ^[0-9]+$ ]]; then
        TUNNEL_COUNT="$NEW_COUNT"
    fi
    
    # Ask for ports
    echo -e "${BLUE}پورت‌ها را وارد کنید (مثال: 443,80) (پیش‌فرض: $PORTS):${NC}"
    read -r NEW_PORTS
    if [[ -n "$NEW_PORTS" ]]; then
        PORTS="$NEW_PORTS"
    fi
    
    save_config
    
    echo ""
    echo -e "${YELLOW}آیا می‌خواهید تانل‌ها را ایجاد کنید؟ (y/n)${NC}"
    read -r CONFIRM
    
    if [[ "$CONFIRM" != "y" ]]; then
        return
    fi
    
    echo ""
    echo -e "${BLUE}═══════════════════════════════════════${NC}"
    echo -e "${BLUE}      مرحله 1: ایجاد کلید SSH         ${NC}"
    echo -e "${BLUE}═══════════════════════════════════════${NC}"
    
    if [[ ! -f /root/.ssh/id_ed25519 ]]; then
        echo -e "${YELLOW}در حال ایجاد کلید SSH...${NC}"
        ssh-keygen -t ed25519 -f /root/.ssh/id_ed25519 -N "" -q
        echo -e "${GREEN}✅ کلید SSH ایجاد شد${NC}"
    else
        echo -e "${GREEN}✅ کلید SSH موجود است${NC}"
    fi
    
    echo ""
    echo -e "${BLUE}═══════════════════════════════════════${NC}"
    echo -e "${BLUE}      مرحله 2: کپی کلید به سرور خارج  ${NC}"
    echo -e "${BLUE}═══════════════════════════════════════${NC}"
    
    echo -e "${YELLOW}در حال کپی کلید به $FOREIGN_IP...${NC}"
    echo -e "${CYAN}رمز عبور سرور خارج را وارد کنید:${NC}"
    ssh-copy-id -o StrictHostKeyChecking=no root@"$FOREIGN_IP"
    
    echo ""
    echo -e "${BLUE}═══════════════════════════════════════${NC}"
    echo -e "${BLUE}      مرحله 3: ایجاد سرویس‌های تانل   ${NC}"
    echo -e "${BLUE}═══════════════════════════════════════${NC}"
    
    # Parse ports
    IFS=',' read -ra PORT_ARRAY <<< "$PORTS"
    
    # Create tunnel services
    for ((i=1; i<=TUNNEL_COUNT; i++)); do
        echo -e "${YELLOW}ایجاد سرویس tunnel${i}...${NC}"
        
        # Build port forwarding arguments
        PORT_ARGS=""
        for PORT in "${PORT_ARRAY[@]}"; do
            LOCAL_PORT=$((10000 + PORT + i - 1))
            PORT_ARGS="$PORT_ARGS -L ${LOCAL_PORT}:127.0.0.1:${PORT}"
        done
        
        cat > /etc/systemd/system/tunnel${i}.service << EOF
[Unit]
Description=SSH Tunnel ${i} to Foreign Server
After=network.target
Wants=network-online.target

[Service]
Type=simple
ExecStart=/usr/bin/ssh -N -o ServerAliveInterval=30 -o ServerAliveCountMax=3 -o ExitOnForwardFailure=yes -o StrictHostKeyChecking=no -o TCPKeepAlive=yes -c ${CIPHER} ${PORT_ARGS} root@${FOREIGN_IP}
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF
        
        systemctl daemon-reload
        systemctl enable tunnel${i}.service
        systemctl restart tunnel${i}.service
        
        echo -e "${GREEN}✅ سرویس tunnel${i} ایجاد شد${NC}"
    done
    
    echo ""
    echo -e "${BLUE}═══════════════════════════════════════${NC}"
    echo -e "${BLUE}      مرحله 4: تنظیم HAProxy          ${NC}"
    echo -e "${BLUE}═══════════════════════════════════════${NC}"
    
    # Install HAProxy if not installed
    if ! command -v haproxy &> /dev/null; then
        echo -e "${YELLOW}در حال نصب HAProxy...${NC}"
        apt-get update && apt-get install -y haproxy
    fi
    
    # Generate HAProxy config
    echo -e "${YELLOW}در حال ایجاد کانفیگ HAProxy...${NC}"
    
    cat > /etc/haproxy/haproxy.cfg << 'HAPROXY_HEAD'
global
    log /dev/log local0
    log /dev/log local1 notice
    chroot /var/lib/haproxy
    stats socket /run/haproxy/admin.sock mode 660 level admin
    stats timeout 30s
    user haproxy
    group haproxy
    daemon

defaults
    log     global
    mode    tcp
    option  tcplog
    option  dontlognull
    timeout connect 10s
    timeout client  1m
    timeout server  1m
    retries 3

HAPROXY_HEAD

    # Add frontend and backend for each port
    for PORT in "${PORT_ARRAY[@]}"; do
        cat >> /etc/haproxy/haproxy.cfg << EOF

frontend ft_port_${PORT}
    bind *:${PORT}
    default_backend bk_port_${PORT}

backend bk_port_${PORT}
    balance roundrobin
    option tcp-check
EOF
        
        for ((i=1; i<=TUNNEL_COUNT; i++)); do
            LOCAL_PORT=$((10000 + PORT + i - 1))
            echo "    server tunnel${i} 127.0.0.1:${LOCAL_PORT} check inter 5s fall 3 rise 2" >> /etc/haproxy/haproxy.cfg
        done
    done
    
    # Restart HAProxy
    systemctl restart haproxy
    systemctl enable haproxy
    
    echo -e "${GREEN}✅ HAProxy تنظیم شد${NC}"
    
    INSTALLED="true"
    save_config
    
    echo ""
    echo -e "${GREEN}═══════════════════════════════════════${NC}"
    echo -e "${GREEN}    ✅ نصب با موفقیت انجام شد!        ${NC}"
    echo -e "${GREEN}═══════════════════════════════════════${NC}"
    
    log_message "Iran server setup completed with $TUNNEL_COUNT tunnels"
    press_enter
}

###########################################
#        5. Graphical Speed Test          #
###########################################

graphical_test() {
    print_banner
    echo -e "${CYAN}═══════════════════════════════════════${NC}"
    echo -e "${CYAN}         تست سرعت گرافیکی             ${NC}"
    echo -e "${CYAN}═══════════════════════════════════════${NC}"
    echo ""
    
    if [[ -z "$FOREIGN_IP" ]]; then
        echo -e "${RED}IP سرور خارج تنظیم نشده!${NC}"
        press_enter
        return
    fi
    
    echo -e "${YELLOW}در حال تست سرعت اتصال...${NC}"
    echo ""
    
    # Test latency
    echo -e "${BLUE}📊 تست تأخیر (Latency):${NC}"
    LATENCY=$(ping -c 10 "$FOREIGN_IP" 2>/dev/null | tail -1 | awk -F'/' '{print $5}')
    
    if [[ -n "$LATENCY" ]]; then
        LATENCY_INT=${LATENCY%.*}
        
        # Visual bar
        echo -n "   ["
        if [[ $LATENCY_INT -lt 50 ]]; then
            echo -e "${GREEN}████████████████████${NC}] ${GREEN}${LATENCY}ms - عالی!${NC}"
        elif [[ $LATENCY_INT -lt 100 ]]; then
            echo -e "${GREEN}███████████████${NC}${YELLOW}█████${NC}] ${YELLOW}${LATENCY}ms - خوب${NC}"
        elif [[ $LATENCY_INT -lt 200 ]]; then
            echo -e "${GREEN}██████████${NC}${YELLOW}██████${NC}] ${YELLOW}${LATENCY}ms - متوسط${NC}"
        else
            echo -e "${RED}█████${NC}${YELLOW}███████${NC}] ${RED}${LATENCY}ms - ضعیف${NC}"
        fi
    else
        echo -e "${RED}   خطا در تست تأخیر${NC}"
    fi
    
    echo ""
    
    # Test bandwidth (simple)
    echo -e "${BLUE}📊 تست پهنای باند (ساده):${NC}"
    
    START=$(date +%s.%N)
    timeout 10 ssh -o StrictHostKeyChecking=no -c "$CIPHER" root@"$FOREIGN_IP" "dd if=/dev/zero bs=1M count=10 2>/dev/null" > /dev/null 2>&1
    END=$(date +%s.%N)
    
    DURATION=$(echo "$END - $START" | bc 2>/dev/null || echo "10")
    SPEED=$(echo "scale=2; 10 / $DURATION" | bc 2>/dev/null || echo "1")
    
    echo -n "   ["
    SPEED_INT=${SPEED%.*}
    if [[ $SPEED_INT -gt 5 ]]; then
        echo -e "${GREEN}████████████████████${NC}] ${GREEN}${SPEED} MB/s - عالی!${NC}"
    elif [[ $SPEED_INT -gt 2 ]]; then
        echo -e "${GREEN}███████████████${NC}${YELLOW}█████${NC}] ${YELLOW}${SPEED} MB/s - خوب${NC}"
    else
        echo -e "${YELLOW}██████████${NC}${RED}██████████${NC}] ${RED}${SPEED} MB/s - ضعیف${NC}"
    fi
    
    echo ""
    
    # Tunnel status visual
    echo -e "${BLUE}📊 وضعیت تانل‌ها:${NC}"
    for ((i=1; i<=TUNNEL_COUNT; i++)); do
        STATUS=$(systemctl is-active tunnel${i}.service 2>/dev/null)
        if [[ "$STATUS" == "active" ]]; then
            echo -e "   Tunnel ${i}: [${GREEN}████████████████████${NC}] ${GREEN}فعال ✓${NC}"
        else
            echo -e "   Tunnel ${i}: [${RED}████████████████████${NC}] ${RED}غیرفعال ✗${NC}"
        fi
    done
    
    log_message "Graphical test executed"
    press_enter
}

###########################################
#          6. Change IP                   #
###########################################

change_ip() {
    print_banner
    echo -e "${CYAN}═══════════════════════════════════════${NC}"
    echo -e "${CYAN}           تغییر IP سرورها            ${NC}"
    echo -e "${CYAN}═══════════════════════════════════════${NC}"
    echo ""
    
    show_current_config
    echo ""
    
    echo -e "${BLUE}چه چیزی را می‌خواهید تغییر دهید؟${NC}"
    echo ""
    echo -e "  ${GREEN}1)${NC} IP سرور خارج"
    echo -e "  ${GREEN}2)${NC} تعداد تانل‌ها"
    echo -e "  ${GREEN}3)${NC} پورت‌ها"
    echo -e "  ${GREEN}4)${NC} Cipher رمزنگاری"
    echo -e "  ${GREEN}0)${NC} بازگشت"
    echo ""
    echo -ne "${YELLOW}انتخاب کنید: ${NC}"
    read -r CHOICE
    
    case $CHOICE in
        1)
            echo -ne "${BLUE}IP جدید سرور خارج: ${NC}"
            read -r NEW_IP
            if [[ -n "$NEW_IP" ]]; then
                FOREIGN_IP="$NEW_IP"
                save_config
                echo -e "${GREEN}✅ IP سرور خارج تغییر کرد${NC}"
                
                echo -e "${YELLOW}آیا می‌خواهید سرویس‌ها را بازسازی کنید؟ (y/n)${NC}"
                read -r REBUILD
                if [[ "$REBUILD" == "y" ]]; then
                    setup_iran
                fi
            fi
            ;;
        2)
            echo -ne "${BLUE}تعداد جدید تانل‌ها: ${NC}"
            read -r NEW_COUNT
            if [[ -n "$NEW_COUNT" ]] && [[ "$NEW_COUNT" =~ ^[0-9]+$ ]]; then
                # Stop old tunnels
                for ((i=1; i<=TUNNEL_COUNT; i++)); do
                    systemctl stop tunnel${i}.service 2>/dev/null
                    systemctl disable tunnel${i}.service 2>/dev/null
                    rm -f /etc/systemd/system/tunnel${i}.service
                done
                
                TUNNEL_COUNT="$NEW_COUNT"
                save_config
                echo -e "${GREEN}✅ تعداد تانل‌ها تغییر کرد به $TUNNEL_COUNT${NC}"
                
                echo -e "${YELLOW}آیا می‌خواهید سرویس‌ها را بازسازی کنید؟ (y/n)${NC}"
                read -r REBUILD
                if [[ "$REBUILD" == "y" ]]; then
                    setup_iran
                fi
            fi
            ;;
        3)
            echo -ne "${BLUE}پورت‌های جدید (مثال: 443,80,8080): ${NC}"
            read -r NEW_PORTS
            if [[ -n "$NEW_PORTS" ]]; then
                PORTS="$NEW_PORTS"
                save_config
                echo -e "${GREEN}✅ پورت‌ها تغییر کرد${NC}"
            fi
            ;;
        4)
            echo -e "${BLUE}Cipher های موجود:${NC}"
            echo "  1) aes128-gcm@openssh.com (پیشنهادی)"
            echo "  2) aes256-gcm@openssh.com"
            echo "  3) chacha20-poly1305@openssh.com"
            echo "  4) aes128-ctr"
            echo "  5) aes256-ctr"
            echo -ne "${YELLOW}انتخاب کنید (1-5): ${NC}"
            read -r CIPHER_CHOICE
            
            case $CIPHER_CHOICE in
                1) CIPHER="aes128-gcm@openssh.com" ;;
                2) CIPHER="aes256-gcm@openssh.com" ;;
                3) CIPHER="chacha20-poly1305@openssh.com" ;;
                4) CIPHER="aes128-ctr" ;;
                5) CIPHER="aes256-ctr" ;;
            esac
            
            save_config
            echo -e "${GREEN}✅ Cipher تغییر کرد به: $CIPHER${NC}"
            ;;
        0)
            return
            ;;
    esac
    
    press_enter
}

###########################################
#          7. Show Status                 #
###########################################

show_status() {
    print_banner
    echo -e "${CYAN}═══════════════════════════════════════${NC}"
    echo -e "${CYAN}          وضعیت سیستم                 ${NC}"
    echo -e "${CYAN}═══════════════════════════════════════${NC}"
    echo ""
    
    show_current_config
    echo ""
    
    # Tunnel Services Status
    echo -e "${BLUE}┌─────────────────────────────────────┐${NC}"
    echo -e "${BLUE}│      وضعیت سرویس‌های تانل          │${NC}"
    echo -e "${BLUE}├─────────────────────────────────────┤${NC}"
    
    for ((i=1; i<=TUNNEL_COUNT; i++)); do
        STATUS=$(systemctl is-active tunnel${i}.service 2>/dev/null)
        if [[ "$STATUS" == "active" ]]; then
            UPTIME=$(systemctl show tunnel${i}.service --property=ActiveEnterTimestamp 2>/dev/null | cut -d'=' -f2)
            echo -e "${BLUE}│${NC} Tunnel ${i}: ${GREEN}● فعال${NC} (از $UPTIME)"
        else
            echo -e "${BLUE}│${NC} Tunnel ${i}: ${RED}○ غیرفعال${NC}"
        fi
    done
    echo -e "${BLUE}└─────────────────────────────────────┘${NC}"
    
    echo ""
    
    # HAProxy Status
    echo -e "${BLUE}┌─────────────────────────────────────┐${NC}"
    echo -e "${BLUE}│         وضعیت HAProxy              │${NC}"
    echo -e "${BLUE}├─────────────────────────────────────┤${NC}"
    
    HAPROXY_STATUS=$(systemctl is-active haproxy 2>/dev/null)
    if [[ "$HAPROXY_STATUS" == "active" ]]; then
        echo -e "${BLUE}│${NC} HAProxy: ${GREEN}● فعال${NC}"
    else
        echo -e "${BLUE}│${NC} HAProxy: ${RED}○ غیرفعال${NC}"
    fi
    echo -e "${BLUE}└─────────────────────────────────────┘${NC}"
    
    echo ""
    
    # HAProxy Stats
    if [[ "$HAPROXY_STATUS" == "active" ]]; then
        echo -e "${BLUE}┌─────────────────────────────────────┐${NC}"
        echo -e "${BLUE}│       آمار Backend ها              │${NC}"
        echo -e "${BLUE}├─────────────────────────────────────┤${NC}"
        
        echo "show stat" | socat stdio /run/haproxy/admin.sock 2>/dev/null | grep -E "^bk_" | while IFS=',' read -r line; do
            NAME=$(echo "$line" | cut -d',' -f1-2)
            STATUS=$(echo "$line" | cut -d',' -f18)
            if [[ "$STATUS" == "UP" ]]; then
                echo -e "${BLUE}│${NC} $NAME: ${GREEN}UP${NC}"
            else
                echo -e "${BLUE}│${NC} $NAME: ${RED}DOWN${NC}"
            fi
        done
        
        echo -e "${BLUE}└─────────────────────────────────────┘${NC}"
    fi
    
    echo ""
    
    # Port Status
    echo -e "${BLUE}┌─────────────────────────────────────┐${NC}"
    echo -e "${BLUE}│         پورت‌های فعال              │${NC}"
    echo -e "${BLUE}├─────────────────────────────────────┤${NC}"
    
    IFS=',' read -ra PORT_ARRAY <<< "$PORTS"
    for PORT in "${PORT_ARRAY[@]}"; do
        if ss -tlnp | grep -q ":${PORT} "; then
            echo -e "${BLUE}│${NC} پورت $PORT: ${GREEN}● باز${NC}"
        else
            echo -e "${BLUE}│${NC} پورت $PORT: ${RED}○ بسته${NC}"
        fi
    done
    echo -e "${BLUE}└─────────────────────────────────────┘${NC}"
    
    echo ""
    
    # System Resources
    echo -e "${BLUE}┌─────────────────────────────────────┐${NC}"
    echo -e "${BLUE}│        منابع سیستم                 │${NC}"
    echo -e "${BLUE}├─────────────────────────────────────┤${NC}"
    
    CPU_USAGE=$(top -bn1 | grep "Cpu(s)" | awk '{print $2}' | cut -d'%' -f1)
    MEM_USAGE=$(free | grep Mem | awk '{printf "%.1f", $3/$2 * 100}')
    DISK_USAGE=$(df -h / | tail -1 | awk '{print $5}')
    
    echo -e "${BLUE}│${NC} CPU:    ${YELLOW}${CPU_USAGE}%${NC}"
    echo -e "${BLUE}│${NC} Memory: ${YELLOW}${MEM_USAGE}%${NC}"
    echo -e "${BLUE}│${NC} Disk:   ${YELLOW}${DISK_USAGE}${NC}"
    echo -e "${BLUE}└─────────────────────────────────────┘${NC}"
    
    log_message "Status checked"
    press_enter
}

###########################################
#        8. Port Management               #
###########################################

port_management() {
    print_banner
    echo -e "${CYAN}═══════════════════════════════════════${NC}"
    echo -e "${CYAN}          مدیریت پورت‌ها             ${NC}"
    echo -e "${CYAN}═══════════════════════════════════════${NC}"
    echo ""
    
    echo -e "${YELLOW}پورت‌های فعلی: ${GREEN}$PORTS${NC}"
    echo ""
    
    echo -e "${BLUE}چه کاری می‌خواهید انجام دهید؟${NC}"
    echo ""
    echo -e "  ${GREEN}1)${NC} اضافه کردن پورت جدید"
    echo -e "  ${GREEN}2)${NC} حذف پورت"
    echo -e "  ${GREEN}3)${NC} تست پورت"
    echo -e "  ${GREEN}4)${NC} نمایش پورت‌های باز"
    echo -e "  ${GREEN}0)${NC} بازگشت"
    echo ""
    echo -ne "${YELLOW}انتخاب کنید: ${NC}"
    read -r CHOICE
    
    case $CHOICE in
        1)
            echo -ne "${BLUE}پورت جدید را وارد کنید: ${NC}"
            read -r NEW_PORT
            if [[ -n "$NEW_PORT" ]] && [[ "$NEW_PORT" =~ ^[0-9]+$ ]]; then
                if [[ "$PORTS" == *"$NEW_PORT"* ]]; then
                    echo -e "${YELLOW}این پورت قبلاً اضافه شده!${NC}"
                else
                    PORTS="${PORTS},${NEW_PORT}"
                    save_config
                    echo -e "${GREEN}✅ پورت $NEW_PORT اضافه شد${NC}"
                    echo -e "${YELLOW}برای اعمال تغییرات، سرور ایران را مجدداً تنظیم کنید (گزینه 4)${NC}"
                fi
            fi
            ;;
        2)
            echo -ne "${BLUE}پورت مورد نظر برای حذف: ${NC}"
            read -r DEL_PORT
            if [[ -n "$DEL_PORT" ]]; then
                PORTS=$(echo "$PORTS" | sed "s/,${DEL_PORT}//g" | sed "s/${DEL_PORT},//g" | sed "s/^${DEL_PORT}$//g")
                save_config
                echo -e "${GREEN}✅ پورت $DEL_PORT حذف شد${NC}"
            fi
            ;;
        3)
            echo -ne "${BLUE}پورت مورد نظر برای تست: ${NC}"
            read -r TEST_PORT
            if [[ -n "$TEST_PORT" ]]; then
                echo -e "${YELLOW}در حال تست پورت $TEST_PORT...${NC}"
                
                # Test local
                if ss -tlnp | grep -q ":${TEST_PORT} "; then
                    echo -e "${GREEN}✅ پورت $TEST_PORT در سرور ایران باز است${NC}"
                else
                    echo -e "${RED}❌ پورت $TEST_PORT در سرور ایران بسته است${NC}"
                fi
                
                # Test remote
                if [[ -n "$FOREIGN_IP" ]]; then
                    if timeout 5 bash -c "echo >/dev/tcp/$FOREIGN_IP/$TEST_PORT" 2>/dev/null; then
                        echo -e "${GREEN}✅ پورت $TEST_PORT در سرور خارج باز است${NC}"
                    else
                        echo -e "${RED}❌ پورت $TEST_PORT در سرور خارج بسته است${NC}"
                    fi
                fi
            fi
            ;;
        4)
            echo -e "${BLUE}پورت‌های باز در سیستم:${NC}"
            ss -tlnp | grep LISTEN
            ;;
        0)
            return
            ;;
    esac
    
    press_enter
}

###########################################
#          9. Uninstall                   #
###########################################

uninstall() {
    print_banner
    echo -e "${RED}═══════════════════════════════════════${NC}"
    echo -e "${RED}            حذف کامل سیستم            ${NC}"
    echo -e "${RED}═══════════════════════════════════════${NC}"
    echo ""
    
    echo -e "${YELLOW}⚠️  هشدار: این عمل تمام تانل‌ها و تنظیمات را حذف می‌کند!${NC}"
    echo ""
    echo -e "${RED}آیا مطمئن هستید؟ (yes/no)${NC}"
    read -r CONFIRM
    
    if [[ "$CONFIRM" != "yes" ]]; then
        echo -e "${GREEN}عملیات لغو شد${NC}"
        press_enter
        return
    fi
    
    echo ""
    echo -e "${YELLOW}در حال حذف...${NC}"
    
    # Stop and remove tunnel services
    echo -e "${BLUE}1. حذف سرویس‌های تانل...${NC}"
    for ((i=1; i<=10; i++)); do
        systemctl stop tunnel${i}.service 2>/dev/null
        systemctl disable tunnel${i}.service 2>/dev/null
        rm -f /etc/systemd/system/tunnel${i}.service
    done
    systemctl daemon-reload
    echo -e "${GREEN}   ✅ سرویس‌های تانل حذف شدند${NC}"
    
    # Stop HAProxy
    echo -e "${BLUE}2. توقف HAProxy...${NC}"
    systemctl stop haproxy 2>/dev/null
    echo -e "${GREEN}   ✅ HAProxy متوقف شد${NC}"
    
    # Remove config
    echo -e "${BLUE}3. حذف فایل‌های کانفیگ...${NC}"
    rm -rf /etc/sshsaeed
    echo -e "${GREEN}   ✅ فایل‌های کانفیگ حذف شدند${NC}"
    
    # Remove logs
    echo -e "${BLUE}4. حذف لاگ‌ها...${NC}"
    rm -f /var/log/sshsaeed.log
    echo -e "${GREEN}   ✅ لاگ‌ها حذف شدند${NC}"
    
    echo ""
    echo -e "${GREEN}═══════════════════════════════════════${NC}"
    echo -e "${GREEN}    ✅ حذف با موفقیت انجام شد!        ${NC}"
    echo -e "${GREEN}═══════════════════════════════════════${NC}"
    
    log_message "System uninstalled"
    press_enter
}

###########################################
#          10. View Logs                  #
###########################################

view_logs() {
    print_banner
    echo -e "${CYAN}═══════════════════════════════════════${NC}"
    echo -e "${CYAN}             مشاهده لاگ‌ها            ${NC}"
    echo -e "${CYAN}═══════════════════════════════════════${NC}"
    echo ""
    
    echo -e "${BLUE}کدام لاگ را می‌خواهید ببینید؟${NC}"
    echo ""
    echo -e "  ${GREEN}1)${NC} لاگ پنل SSHSaeed"
    echo -e "  ${GREEN}2)${NC} لاگ HAProxy"
    echo -e "  ${GREEN}3)${NC} لاگ سرویس‌های تانل"
    echo -e "  ${GREEN}4)${NC} لاگ SSH"
    echo -e "  ${GREEN}5)${NC} لاگ سیستم (آخرین 50 خط)"
    echo -e "  ${GREEN}0)${NC} بازگشت"
    echo ""
    echo -ne "${YELLOW}انتخاب کنید: ${NC}"
    read -r CHOICE
    
    case $CHOICE in
        1)
            echo -e "${CYAN}═══ لاگ پنل SSHSaeed ═══${NC}"
            if [[ -f "$LOG_FILE" ]]; then
                tail -50 "$LOG_FILE"
            else
                echo -e "${YELLOW}فایل لاگ وجود ندارد${NC}"
            fi
            ;;
        2)
            echo -e "${CYAN}═══ لاگ HAProxy ═══${NC}"
            journalctl -u haproxy --no-pager -n 50
            ;;
        3)
            echo -e "${CYAN}═══ لاگ سرویس‌های تانل ═══${NC}"
            for ((i=1; i<=TUNNEL_COUNT; i++)); do
                echo -e "${YELLOW}--- Tunnel ${i} ---${NC}"
                journalctl -u tunnel${i}.service --no-pager -n 10
                echo ""
            done
            ;;
        4)
            echo -e "${CYAN}═══ لاگ SSH ═══${NC}"
            journalctl -u sshd --no-pager -n 50
            ;;
        5)
            echo -e "${CYAN}═══ لاگ سیستم ═══${NC}"
            journalctl --no-pager -n 50
            ;;
        0)
            return
            ;;
    esac
    
    press_enter
}

###########################################
#          11. Backup & Restore           #
###########################################

backup_restore() {
    print_banner
    echo -e "${CYAN}═══════════════════════════════════════${NC}"
    echo -e "${CYAN}         بکاپ و بازیابی               ${NC}"
    echo -e "${CYAN}═══════════════════════════════════════${NC}"
    echo ""
    
    echo -e "${BLUE}چه کاری می‌خواهید انجام دهید؟${NC}"
    echo ""
    echo -e "  ${GREEN}1)${NC} ایجاد بکاپ"
    echo -e "  ${GREEN}2)${NC} بازیابی از بکاپ"
    echo -e "  ${GREEN}3)${NC} لیست بکاپ‌ها"
    echo -e "  ${GREEN}4)${NC} حذف بکاپ"
    echo -e "  ${GREEN}0)${NC} بازگشت"
    echo ""
    echo -ne "${YELLOW}انتخاب کنید: ${NC}"
    read -r CHOICE
    
    case $CHOICE in
        1)
            mkdir -p "$BACKUP_DIR"
            BACKUP_NAME="backup_$(date +%Y%m%d_%H%M%S).tar.gz"
            
            echo -e "${YELLOW}در حال ایجاد بکاپ...${NC}"
            
            # Create temp directory
            TEMP_DIR=$(mktemp -d)
            
            # Copy configs
            cp "$CONFIG_FILE" "$TEMP_DIR/" 2>/dev/null
            cp /etc/haproxy/haproxy.cfg "$TEMP_DIR/" 2>/dev/null
            
            # Copy tunnel services
            for ((i=1; i<=10; i++)); do
                cp /etc/systemd/system/tunnel${i}.service "$TEMP_DIR/" 2>/dev/null
            done
            
            # Create archive
            tar -czf "${BACKUP_DIR}/${BACKUP_NAME}" -C "$TEMP_DIR" .
            
            # Cleanup
            rm -rf "$TEMP_DIR"
            
            echo -e "${GREEN}✅ بکاپ ایجاد شد: ${BACKUP_DIR}/${BACKUP_NAME}${NC}"
            log_message "Backup created: $BACKUP_NAME"
            ;;
        2)
            echo -e "${BLUE}بکاپ‌های موجود:${NC}"
            ls -la "$BACKUP_DIR"/*.tar.gz 2>/dev/null || echo "بکاپی وجود ندارد"
            echo ""
            echo -ne "${BLUE}نام فایل بکاپ: ${NC}"
            read -r BACKUP_FILE
            
            if [[ -f "${BACKUP_DIR}/${BACKUP_FILE}" ]]; then
                echo -e "${YELLOW}در حال بازیابی...${NC}"
                
                TEMP_DIR=$(mktemp -d)
                tar -xzf "${BACKUP_DIR}/${BACKUP_FILE}" -C "$TEMP_DIR"
                
                # Restore configs
                cp "$TEMP_DIR/config.conf" "$CONFIG_FILE" 2>/dev/null
                cp "$TEMP_DIR/haproxy.cfg" /etc/haproxy/haproxy.cfg 2>/dev/null
                
                # Restore tunnel services
                for ((i=1; i<=10; i++)); do
                    if [[ -f "$TEMP_DIR/tunnel${i}.service" ]]; then
                        cp "$TEMP_DIR/tunnel${i}.service" /etc/systemd/system/
                    fi
                done
                
                systemctl daemon-reload
                rm -rf "$TEMP_DIR"
                
                echo -e "${GREEN}✅ بازیابی انجام شد${NC}"
                echo -e "${YELLOW}لطفاً سرویس‌ها را ریستارت کنید${NC}"
                log_message "Backup restored: $BACKUP_FILE"
            else
                echo -e "${RED}فایل بکاپ یافت نشد${NC}"
            fi
            ;;
        3)
            echo -e "${BLUE}لیست بکاپ‌ها:${NC}"
            ls -lah "$BACKUP_DIR"/*.tar.gz 2>/dev/null || echo "بکاپی وجود ندارد"
            ;;
        4)
            echo -e "${BLUE}بکاپ‌های موجود:${NC}"
            ls -la "$BACKUP_DIR"/*.tar.gz 2>/dev/null || echo "بکاپی وجود ندارد"
            echo ""
            echo -ne "${BLUE}نام فایل برای حذف: ${NC}"
            read -r DEL_FILE
            
            if [[ -f "${BACKUP_DIR}/${DEL_FILE}" ]]; then
                rm -f "${BACKUP_DIR}/${DEL_FILE}"
                echo -e "${GREEN}✅ بکاپ حذف شد${NC}"
            fi
            ;;
        0)
            return
            ;;
    esac
    
    press_enter
}

###########################################
#          Service Control                #
###########################################

service_control() {
    print_banner
    echo -e "${CYAN}═══════════════════════════════════════${NC}"
    echo -e "${CYAN}          کنترل سرویس‌ها             ${NC}"
    echo -e "${CYAN}═══════════════════════════════════════${NC}"
    echo ""
    
    echo -e "${BLUE}چه کاری می‌خواهید انجام دهید؟${NC}"
    echo ""
    echo -e "  ${GREEN}1)${NC} ریستارت همه تانل‌ها"
    echo -e "  ${GREEN}2)${NC} توقف همه تانل‌ها"
    echo -e "  ${GREEN}3)${NC} شروع همه تانل‌ها"
    echo -e "  ${GREEN}4)${NC} ریستارت HAProxy"
    echo -e "  ${GREEN}5)${NC} ریستارت یک تانل خاص"
    echo -e "  ${GREEN}0)${NC} بازگشت"
    echo ""
    echo -ne "${YELLOW}انتخاب کنید: ${NC}"
    read -r CHOICE
    
    case $CHOICE in
        1)
            echo -e "${YELLOW}در حال ریستارت تانل‌ها...${NC}"
            for ((i=1; i<=TUNNEL_COUNT; i++)); do
                systemctl restart tunnel${i}.service
                echo -e "${GREEN}✅ Tunnel ${i} ریستارت شد${NC}"
            done
            systemctl restart haproxy
            echo -e "${GREEN}✅ HAProxy ریستارت شد${NC}"
            ;;
        2)
            echo -e "${YELLOW}در حال توقف تانل‌ها...${NC}"
            for ((i=1; i<=TUNNEL_COUNT; i++)); do
                systemctl stop tunnel${i}.service
            done
            echo -e "${GREEN}✅ همه تانل‌ها متوقف شدند${NC}"
            ;;
        3)
            echo -e "${YELLOW}در حال شروع تانل‌ها...${NC}"
            for ((i=1; i<=TUNNEL_COUNT; i++)); do
                systemctl start tunnel${i}.service
            done
            echo -e "${GREEN}✅ همه تانل‌ها شروع شدند${NC}"
            ;;
        4)
            systemctl restart haproxy
            echo -e "${GREEN}✅ HAProxy ریستارت شد${NC}"
            ;;
        5)
            echo -ne "${BLUE}شماره تانل (1-$TUNNEL_COUNT): ${NC}"
            read -r TUNNEL_NUM
            if [[ "$TUNNEL_NUM" =~ ^[0-9]+$ ]] && [[ "$TUNNEL_NUM" -ge 1 ]] && [[ "$TUNNEL_NUM" -le "$TUNNEL_COUNT" ]]; then
                systemctl restart tunnel${TUNNEL_NUM}.service
                echo -e "${GREEN}✅ Tunnel ${TUNNEL_NUM} ریستارت شد${NC}"
            else
                echo -e "${RED}شماره نامعتبر${NC}"
            fi
            ;;
        0)
            return
            ;;
    esac
    
    press_enter
}

###########################################
#            Main Menu                    #
###########################################

main_menu() {
    while true; do
        print_banner
        show_current_config
        echo ""
        echo -e "${CYAN}═══════════════════════════════════════${NC}"
        echo -e "${CYAN}              منوی اصلی               ${NC}"
        echo -e "${CYAN}═══════════════════════════════════════${NC}"
        echo ""
        echo -e "  ${GREEN}1)${NC}  تست پینگ سرورها"
        echo -e "  ${GREEN}2)${NC}  تست رمزنگاری AES"
        echo -e "  ${GREEN}3)${NC}  تنظیم سرور خارج (Kharej)"
        echo -e "  ${GREEN}4)${NC}  تنظیم سرور ایران (Iran)"
        echo -e "  ${GREEN}5)${NC}  تست سرعت گرافیکی"
        echo -e "  ${GREEN}6)${NC}  تغییر تنظیمات"
        echo -e "  ${GREEN}7)${NC}  وضعیت سیستم"
        echo -e "  ${GREEN}8)${NC}  مدیریت پورت‌ها"
        echo -e "  ${GREEN}9)${NC}  کنترل سرویس‌ها"
        echo -e "  ${GREEN}10)${NC} مشاهده لاگ‌ها"
        echo -e "  ${GREEN}11)${NC} بکاپ و بازیابی"
        echo -e "  ${RED}12)${NC} حذف کامل"
        echo -e "  ${YELLOW}0)${NC}  خروج"
        echo ""
        echo -e "${CYAN}═══════════════════════════════════════${NC}"
        echo -ne "${YELLOW}انتخاب کنید: ${NC}"
        read -r CHOICE
        
        case $CHOICE in
            1) ping_test ;;
            2) aes_test ;;
            3) setup_foreign ;;
            4) setup_iran ;;
            5) graphical_test ;;
            6) change_ip ;;
            7) show_status ;;
            8) port_management ;;
            9) service_control ;;
            10) view_logs ;;
            11) backup_restore ;;
            12) uninstall ;;
            0)
                echo -e "${GREEN}خداحافظ!${NC}"
                exit 0
                ;;
            *)
                echo -e "${RED}گزینه نامعتبر!${NC}"
                sleep 1
                ;;
        esac
    done
}

###########################################
#            Main Execution               #
###########################################

# Check root
check_root

# Create directories
mkdir -p /etc/sshsaeed
mkdir -p "$BACKUP_DIR"

# Load config
load_config

# Start main menu
main_menu

