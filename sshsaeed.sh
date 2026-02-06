#!/bin/bash
# ═══════════════════════════════════════════════════════════════════════════════
#  ███████╗███████╗██╗  ██╗███████╗ █████╗ ███████╗███████╗██████╗
#  ██╔════╝██╔════╝██║  ██║██╔════╝██╔══██╗██╔════╝██╔════╝██╔══██╗
#  ███████╗███████╗███████║███████╗███████║█████╗  █████╗  ██║  ██║
#  ╚════██║╚════██║██╔══██║╚════██║██╔══██║██╔══╝  ██╔══╝  ██║  ██║
#  ███████║███████║██║  ██║███████║██║  ██║███████╗███████╗██████╔╝
#  ╚══════╝╚══════╝╚═╝  ╚═╝╚══════╝╚═╝  ╚═╝╚══════╝╚══════╝╚═════╝
# ═══════════════════════════════════════════════════════════════════════════════
#  SSH Tunnel Manager v5.0 | Multi-Port + Dynamic Tunnels + Auto HAProxy
#  GitHub: https://github.com/sshsaeed/tunnel-manager
# ═══════════════════════════════════════════════════════════════════════════════

set -o pipefail
export LC_ALL=C
export LANG=C

# ═══════════════════════════════════════════════════════════════════════════════
#                              ثابت‌های اصلی
# ═══════════════════════════════════════════════════════════════════════════════
readonly VERSION="5.0"
readonly GITHUB_URL="https://github.com/sshsaeed/tunnel-manager"
readonly CONFIG_DIR="/etc/sshsaeed"
readonly CONFIG_FILE="$CONFIG_DIR/config.conf"
readonly KEY_FILE="/root/.ssh/sshsaeed_ed25519"
readonly LOG_FILE="/var/log/sshsaeed.log"
readonly BACKUP_DIR="$CONFIG_DIR/backups"

# رمزنگاری - فقط AES-128-GCM
readonly CIPHER="aes128-gcm@openssh.com"

# مقادیر پیش‌فرض
DEFAULT_PORTS="443,80"
DEFAULT_TUNNEL_COUNT=3
DEFAULT_SSH_PORT=22

# متغیرهای سراسری (پر می‌شوند در زمان اجرا)
declare -a TARGET_PORTS=()
TUNNEL_COUNT=3
KHAREJ_IP=""
KHAREJ_USER="root"
SSH_PORT=22

# ═══════════════════════════════════════════════════════════════════════════════
#                              رنگ‌ها و استایل
# ═══════════════════════════════════════════════════════════════════════════════
R='\033[0;31m'      # قرمز
G='\033[0;32m'      # سبز
Y='\033[1;33m'      # زرد
B='\033[0;34m'      # آبی
M='\033[0;35m'      # بنفش
C='\033[0;36m'      # فیروزه‌ای
W='\033[1;37m'      # سفید
GR='\033[0;90m'     # خاکستری
N='\033[0m'         # بدون رنگ
BOLD='\033[1m'
DIM='\033[2m'

# آیکون‌ها
ICO_OK="✓"
ICO_ERR="✗"
ICO_WARN="!"
ICO_INFO="➤"
ICO_WAIT="◌"

# ═══════════════════════════════════════════════════════════════════════════════
#                              توابع نمایش
# ═══════════════════════════════════════════════════════════════════════════════
print_ok()    { printf "    ${G}${ICO_OK}${N} %s\n" "$1"; }
print_err()   { printf "    ${R}${ICO_ERR}${N} %s\n" "$1"; }
print_warn()  { printf "    ${Y}${ICO_WARN}${N} %s\n" "$1"; }
print_info()  { printf "    ${C}${ICO_INFO}${N} %s\n" "$1"; }
print_wait()  { printf "    ${GR}${ICO_WAIT}${N} %s" "$1"; }
print_done()  { printf "\r    ${G}${ICO_OK}${N} %s\n" "$1"; }

line()      { printf "    ${C}════════════════════════════════════════════════════════${N}\n"; }
line_thin() { printf "    ${GR}────────────────────────────────────────────────────────${N}\n"; }

# پروگرس بار
progress_bar() {
    local current=$1 total=$2 width=40
    local percent=$((current * 100 / total))
    local filled=$((current * width / total))
    local empty=$((width - filled))
    printf "\r    ${C}["
    printf "%${filled}s" | tr ' ' '█'
    printf "%${empty}s" | tr ' ' '░'
    printf "]${N} ${W}%3d%%${N}" "$percent"
}

# ═══════════════════════════════════════════════════════════════════════════════
#                              بنر اصلی
# ═══════════════════════════════════════════════════════════════════════════════
show_banner() {
    clear
    printf "${C}"
    cat << 'BANNER'
    ╔═══════════════════════════════════════════════════════════════╗
    ║   ███████╗███████╗██╗  ██╗███████╗ █████╗ ███████╗██████╗     ║
    ║   ██╔════╝██╔════╝██║  ██║██╔════╝██╔══██╗██╔════╝██╔══██╗    ║
    ║   ███████╗███████╗███████║███████╗███████║█████╗  █████╗      ║
    ║   ╚════██║╚════██║██╔══██║╚════██║██╔══██║██╔══╝  ██╔══╝      ║
    ║   ███████║███████║██║  ██║███████║██║  ██║███████╗██████╔╝    ║
    ║   ╚══════╝╚══════╝╚═╝  ╚═╝╚══════╝╚═╝  ╚═╝╚══════╝╚═════╝     ║
    ╚═══════════════════════════════════════════════════════════════╝
BANNER
    printf "${N}"
    printf "    ${GR}─────────────────────────────────────────────────────────────${N}\n"
    printf "    ${Y}Version:${N} ${W}${VERSION}${N}  ${Y}|${N}  ${C}Multi-Port + Dynamic Tunnels${N}\n"
    printf "    ${GR}─────────────────────────────────────────────────────────────${N}\n"
    echo ""
}

# ═══════════════════════════════════════════════════════════════════════════════
#                              توابع لاگ
# ═══════════════════════════════════════════════════════════════════════════════
log() {
    local level="$1" message="$2"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo "[$timestamp] [$level] $message" >> "$LOG_FILE" 2>/dev/null
}

# ═══════════════════════════════════════════════════════════════════════════════
#                           محاسبه پورت محلی
# ═══════════════════════════════════════════════════════════════════════════════
# فرمول: LOCAL_PORT = (tunnel_number × 1000) + port_index
# مثال با پورت‌های 443,80 و 3 تانل:
#   تانل 1: 1001 → 443, 1002 → 80
#   تانل 2: 2001 → 443, 2002 → 80
#   تانل 3: 3001 → 443, 3002 → 80
# ═══════════════════════════════════════════════════════════════════════════════
get_local_port() {
    local tunnel_num=$1
    local port_index=$2
    echo $((tunnel_num * 1000 + port_index))
}

# ═══════════════════════════════════════════════════════════════════════════════
#                              ذخیره/خواندن تنظیمات
# ═══════════════════════════════════════════════════════════════════════════════
save_config() {
    mkdir -p "$CONFIG_DIR" "$BACKUP_DIR"
    cat > "$CONFIG_FILE" << EOF
# SSHSaeed Configuration v${VERSION}
# Generated: $(date)
# ───────────────────────────────────────────

KHAREJ_IP="${KHAREJ_IP}"
KHAREJ_USER="${KHAREJ_USER}"
SSH_PORT="${SSH_PORT}"
TUNNEL_COUNT="${TUNNEL_COUNT}"
TARGET_PORTS="${TARGET_PORTS[*]}"
EOF
    chmod 600 "$CONFIG_FILE"
    log "INFO" "Config saved"
}

load_config() {
    if [[ -f "$CONFIG_FILE" ]]; then
        source "$CONFIG_FILE"
        # تبدیل رشته پورت‌ها به آرایه
        IFS=' ' read -ra TARGET_PORTS <<< "$TARGET_PORTS"
        return 0
    fi
    return 1
}

# ═══════════════════════════════════════════════════════════════════════════════
#                              توابع کمکی
# ═══════════════════════════════════════════════════════════════════════════════
get_local_ip() {
    ip route get 8.8.8.8 2>/dev/null | grep -oP 'src \K[\d.]+' | head -1
}

check_root() {
    if [[ $EUID -ne 0 ]]; then
        print_err "این اسکریپت باید با دسترسی root اجرا شود"
        exit 1
    fi
}

check_os() {
    if [[ ! -f /etc/debian_version ]] && [[ ! -f /etc/redhat-release ]]; then
        print_warn "سیستم‌عامل تست نشده - ممکن است مشکلاتی وجود داشته باشد"
    fi
}

# نصب پکیج‌های مورد نیاز
install_packages() {
    print_info "بررسی و نصب پکیج‌ها..."
    
    local packages=(openssh-server openssh-client autossh haproxy curl wget net-tools)
    local to_install=()
    
    for pkg in "${packages[@]}"; do
        if ! dpkg -l "$pkg" &>/dev/null; then
            to_install+=("$pkg")
        fi
    done
    
    if [[ ${#to_install[@]} -gt 0 ]]; then
        apt-get update -qq
        apt-get install -y -qq "${to_install[@]}" >/dev/null 2>&1
        print_ok "پکیج‌ها نصب شدند: ${to_install[*]}"
    else
        print_ok "همه پکیج‌ها از قبل نصب هستند"
    fi
}

# ایجاد کلید SSH
generate_ssh_key() {
    if [[ ! -f "$KEY_FILE" ]]; then
        print_info "ایجاد کلید SSH جدید..."
        ssh-keygen -t ed25519 -f "$KEY_FILE" -N "" -C "sshsaeed-tunnel" >/dev/null 2>&1
        chmod 600 "$KEY_FILE"
        chmod 644 "${KEY_FILE}.pub"
        print_ok "کلید SSH ایجاد شد"
    else
        print_ok "کلید SSH از قبل موجود است"
    fi
}

# کپی کلید به سرور خارج
copy_ssh_key() {
    local host=$1
    local user=$2
    local port=$3
    
    print_info "کپی کلید SSH به سرور خارج..."
    
    if ssh-copy-id -i "$KEY_FILE" -p "$port" -o StrictHostKeyChecking=no "$user@$host" 2>/dev/null; then
        print_ok "کلید با موفقیت کپی شد"
        return 0
    else
        print_err "خطا در کپی کلید - ممکن است پسورد اشتباه باشد"
        return 1
    fi
}

# تست اتصال SSH
test_ssh_connection() {
    local host=$1
    local user=$2
    local port=$3
    
    if ssh -i "$KEY_FILE" -p "$port" -o BatchMode=yes -o ConnectTimeout=10 \
       -o StrictHostKeyChecking=no "$user@$host" "echo OK" &>/dev/null; then
        return 0
    fi
    return 1
}
# ═══════════════════════════════════════════════════════════════════════════════
#                      گزینه 1: تست سرعت AES
# ═══════════════════════════════════════════════════════════════════════════════
test_aes_speed() {
    show_banner
    line
    printf "    ${W}تست سرعت رمزنگاری AES${N}\n"
    line
    echo ""

    # بررسی پشتیبانی AES-NI
    print_info "بررسی پشتیبانی سخت‌افزاری AES-NI..."
    if grep -q 'aes' /proc/cpuinfo 2>/dev/null; then
        print_ok "AES-NI پشتیبانی می‌شود ✓"
    else
        print_warn "AES-NI پشتیبانی نمی‌شود - عملکرد کمتر خواهد بود"
    fi
    echo ""

    # تست openssl
    print_info "تست سرعت با OpenSSL..."
    echo ""
    
    if command -v openssl &>/dev/null; then
        printf "    ${C}AES-128-GCM:${N}\n"
        openssl speed -evp aes-128-gcm 2>/dev/null | grep -E "^aes-128-gcm" | head -1
        echo ""
    else
        print_err "OpenSSL نصب نیست"
    fi

    # بررسی BBR
    local cc=$(sysctl -n net.ipv4.tcp_congestion_control 2>/dev/null)
    echo ""
    print_info "الگوریتم کنترل ازدحام: ${W}$cc${N}"

    local score=0
    local max_score=3

    grep -q 'aes' /proc/cpuinfo && ((score++))
    [[ "$cc" == "bbr" ]] && ((score++))
    command -v openssl &>/dev/null && ((score++))

    echo ""
    printf "    ${C}┌─────────────────────────────────────┐${N}\n"
    printf "    ${C}│${N} %-20s %s ${C}│${N}\n" "AES-NI" "$(grep -q 'aes' /proc/cpuinfo && echo "${G}پشتیبانی می‌شود${N}" || echo "${R}پشتیبانی نمی‌شود${N}")"
    printf "    ${C}│${N} %-20s %s ${C}│${N}\n" "Cipher" "${G}aes128-gcm${N}"
    printf "    ${C}│${N} %-20s %s ${C}│${N}\n" "BBR" "$([ "$cc" == "bbr" ] && echo "${G}فعال${N}" || echo "${Y}غیرفعال${N}")"
    printf "    ${C}│${N} %-20s %s ${C}│${N}\n" "Score" "${W}$score/$max_score${N}"
    printf "    ${C}└─────────────────────────────────────┘${N}\n"

    echo ""
    log "INFO" "AES test completed - Score: $score/$max_score"

    read -p "$(printf "    ${C}Enter برای بازگشت...${N}")"
}

# ═══════════════════════════════════════════════════════════════════════════════
#                      گزینه 2: تنظیم سرور خارج (Kharej)
# ═══════════════════════════════════════════════════════════════════════════════
setup_kharej_server() {
    show_banner
    line
    printf "    ${W}تنظیم سرور خارج (Kharej Server)${N}\n"
    line
    echo ""

    local step=0
    local total_steps=5

    # ═══════════ مرحله 1: نصب پکیج‌ها ═══════════
    ((step++))
    printf "    ${C}[%d/%d]${N} ${W}نصب پکیج‌ها...${N}\n" "$step" "$total_steps"
    install_packages
    echo ""

    # ═══════════ مرحله 2: پیکربندی SSH ═══════════
    ((step++))
    printf "    ${C}[%d/%d]${N} ${W}پیکربندی SSH Server...${N}\n" "$step" "$total_steps"

    # بکاپ فایل اصلی
    cp /etc/ssh/sshd_config "$BACKUP_DIR/sshd_config.backup.$(date +%s)" 2>/dev/null

    # تنظیمات بهینه SSH
    cat > /etc/ssh/sshd_config.d/sshsaeed.conf << 'SSHCONF'
# SSHSaeed Optimized SSH Config
# ─────────────────────────────────────

# اجازه فورواردینگ
GatewayPorts yes
AllowTcpForwarding yes
PermitTunnel yes

# تنظیمات امنیتی
PermitRootLogin yes
PubkeyAuthentication yes
PasswordAuthentication yes

# تنظیمات عملکرد
TCPKeepAlive yes
ClientAliveInterval 30
ClientAliveCountMax 3
MaxSessions 100

# رمزنگاری
Ciphers aes128-gcm@openssh.com,aes256-gcm@openssh.com,chacha20-poly1305@openssh.com
SSHCONF

    systemctl restart sshd
    print_ok "SSH Server پیکربندی و ریستارت شد"
    echo ""

    # ═══════════ مرحله 3: فعال‌سازی BBR ═══════════
    ((step++))
    printf "    ${C}[%d/%d]${N} ${W}فعال‌سازی BBR...${N}\n" "$step" "$total_steps"

    if ! grep -q "tcp_bbr" /etc/modules-load.d/* 2>/dev/null; then
        echo "tcp_bbr" > /etc/modules-load.d/bbr.conf
        modprobe tcp_bbr 2>/dev/null
    fi

    if ! grep -q "net.core.default_qdisc" /etc/sysctl.d/* 2>/dev/null; then
        cat > /etc/sysctl.d/99-bbr.conf << 'BBR'
net.core.default_qdisc = fq
net.ipv4.tcp_congestion_control = bbr
net.ipv4.tcp_fastopen = 3
net.core.rmem_max = 67108864
net.core.wmem_max = 67108864
net.ipv4.tcp_rmem = 4096 87380 67108864
net.ipv4.tcp_wmem = 4096 65536 67108864
BBR
        sysctl -p /etc/sysctl.d/99-bbr.conf >/dev/null 2>&1
    fi

    local current_cc=$(sysctl -n net.ipv4.tcp_congestion_control 2>/dev/null)
    if [[ "$current_cc" == "bbr" ]]; then
        print_ok "BBR فعال است"
    else
        print_warn "BBR فعال نشد - نیاز به ریبوت"
    fi
    echo ""

    # ═══════════ مرحله 4: فایروال ═══════════
    ((step++))
    printf "    ${C}[%d/%d]${N} ${W}پیکربندی فایروال...${N}\n" "$step" "$total_steps"

    if command -v ufw &>/dev/null; then
        ufw allow 22/tcp >/dev/null 2>&1
        ufw allow 443/tcp >/dev/null 2>&1
        ufw allow 80/tcp >/dev/null 2>&1
        print_ok "پورت‌های 22, 80, 443 باز شدند"
    else
        print_info "UFW نصب نیست - فایروال تنظیم نشد"
    fi
    echo ""

    # ═══════════ مرحله 5: نمایش اطلاعات ═══════════
    ((step++))
    printf "    ${C}[%d/%d]${N} ${W}اطلاعات سرور...${N}\n" "$step" "$total_steps"

    local server_ip=$(curl -s -4 ifconfig.me 2>/dev/null || curl -s -4 ip.sb 2>/dev/null)
    
    echo ""
    printf "    ${G}╔═══════════════════════════════════════════════════╗${N}\n"
    printf "    ${G}║${N}       ${W}سرور خارج آماده است!${N}                        ${G}║${N}\n"
    printf "    ${G}╠═══════════════════════════════════════════════════╣${N}\n"
    printf "    ${G}║${N}  IP سرور:     ${C}%-30s${N}   ${G}║${N}\n" "$server_ip"
    printf "    ${G}║${N}  پورت SSH:    ${C}%-30s${N}   ${G}║${N}\n" "22"
    printf "    ${G}║${N}  BBR:         ${C}%-30s${N}   ${G}║${N}\n" "$current_cc"
    printf "    ${G}╚═══════════════════════════════════════════════════╝${N}\n"
    echo ""

    print_info "این IP را در تنظیم سرور ایران وارد کنید"
    log "INFO" "Kharej server setup completed"

    echo ""
    read -p "$(printf "    ${C}Enter برای بازگشت...${N}")"
}

# ═══════════════════════════════════════════════════════════════════════════════
#                      گزینه 3: تنظیم سرور ایران (Iran)
# ═══════════════════════════════════════════════════════════════════════════════
setup_iran_server() {
    show_banner
    line
    printf "    ${W}تنظیم سرور ایران (Iran Server)${N}\n"
    line
    echo ""

    local step=0
    local total_steps=8
    local errors=0

    # ═══════════════════════════════════════════════════════════════════════════
    #                         دریافت اطلاعات از کاربر
    # ═══════════════════════════════════════════════════════════════════════════
    printf "    ${Y}اطلاعات سرور خارج را وارد کنید:${N}\n"
    line_thin
    echo ""

    # IP سرور خارج
    while true; do
        read -p "$(printf "    ${C}➤${N} IP سرور خارج: ")" KHAREJ_IP
        if [[ $KHAREJ_IP =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
            break
        fi
        print_err "IP نامعتبر است"
    done

    # پسورد سرور خارج
    read -sp "$(printf "    ${C}➤${N} پسورد root سرور خارج: ")" KHAREJ_PASS
    echo ""

    # پورت SSH سرور خارج
    read -p "$(printf "    ${C}➤${N} پورت SSH سرور خارج [${W}22${N}]: ")" SSH_PORT
    SSH_PORT=${SSH_PORT:-22}

    # پورت‌های هدف (چند پورتی)
    echo ""
    printf "    ${Y}پورت‌ها را با کاما جدا کنید (مثال: 443,80,8443)${N}\n"
    read -p "$(printf "    ${C}➤${N} پورت‌های هدف [${W}443,80${N}]: ")" INPUT_PORTS
    INPUT_PORTS=${INPUT_PORTS:-"443,80"}
    
    # تبدیل به آرایه
    IFS=',' read -ra TARGET_PORTS <<< "$INPUT_PORTS"
    
    # تعداد تانل‌ها
    read -p "$(printf "    ${C}➤${N} تعداد تانل‌ها [${W}3${N}]: ")" TUNNEL_COUNT
    TUNNEL_COUNT=${TUNNEL_COUNT:-3}

    # کاربر SSH (اختیاری)
    read -p "$(printf "    ${C}➤${N} کاربر SSH سرور خارج [${W}root${N}]: ")" KHAREJ_USER
    KHAREJ_USER=${KHAREJ_USER:-root}

    echo ""
    line_thin
    printf "    ${W}شروع نصب و پیکربندی...${N}\n"
    line_thin
    echo ""

    # ═══════════════════════════════════════════════════════════════════════════
    #                         مرحله 1: نصب پکیج‌ها
    # ═══════════════════════════════════════════════════════════════════════════
    ((step++))
    printf "    ${C}[%d/%d]${N} نصب پکیج‌ها...\n" "$step" "$total_steps"

    apt-get update -qq >/dev/null 2>&1
    apt-get install -y -qq openssh-client autossh haproxy sshpass curl wget net-tools >/dev/null 2>&1

    if [[ $? -eq 0 ]]; then
        printf "\r    ${G}[%d/%d]${N} ${G}✓${N} نصب پکیج‌ها\n" "$step" "$total_steps"
    else
        printf "\r    ${R}[%d/%d]${N} ${R}✗${N} نصب پکیج‌ها\n" "$step" "$total_steps"
        ((errors++))
    fi
    echo ""

    # ═══════════════════════════════════════════════════════════════════════════
    #                         مرحله 2: ایجاد کلید SSH
    # ═══════════════════════════════════════════════════════════════════════════
    ((step++))
    printf "    ${C}[%d/%d]${N} ایجاد کلید SSH...\n" "$step" "$total_steps"

    mkdir -p /root/.ssh "$CONFIG_DIR" "$BACKUP_DIR"
    chmod 700 /root/.ssh

    # حذف کلید قبلی
    rm -f "$KEY_FILE" "${KEY_FILE}.pub" 2>/dev/null

    if ssh-keygen -t ed25519 -f "$KEY_FILE" -N "" -C "sshsaeed@iran" -q; then
        chmod 600 "$KEY_FILE"
        chmod 644 "${KEY_FILE}.pub"
        printf "\r    ${G}[%d/%d]${N} ${G}✓${N} ایجاد کلید SSH (ED25519)\n" "$step" "$total_steps"
    else
        printf "\r    ${R}[%d/%d]${N} ${R}✗${N} ایجاد کلید SSH\n" "$step" "$total_steps"
        ((errors++))
    fi
    echo ""

    # ═══════════════════════════════════════════════════════════════════════════
    #                         مرحله 3: کپی کلید به سرور خارج
    # ═══════════════════════════════════════════════════════════════════════════
    ((step++))
    printf "    ${C}[%d/%d]${N} کپی کلید به سرور خارج...\n" "$step" "$total_steps"

    if sshpass -p "$KHAREJ_PASS" ssh-copy-id -i "${KEY_FILE}.pub" \
        -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null \
        -p "$SSH_PORT" "${KHAREJ_USER}@${KHAREJ_IP}" >/dev/null 2>&1; then
        printf "\r    ${G}[%d/%d]${N} ${G}✓${N} کپی کلید به سرور خارج\n" "$step" "$total_steps"
    else
        printf "\r    ${R}[%d/%d]${N} ${R}✗${N} کپی کلید - بررسی IP/پسورد\n" "$step" "$total_steps"
        ((errors++))
    fi
    echo ""

    # ═══════════════════════════════════════════════════════════════════════════
    #                         مرحله 4: تست اتصال SSH
    # ═══════════════════════════════════════════════════════════════════════════
    ((step++))
    printf "    ${C}[%d/%d]${N} تست اتصال SSH...\n" "$step" "$total_steps"

    if ssh -o BatchMode=yes -o ConnectTimeout=10 -o StrictHostKeyChecking=no \
       -i "$KEY_FILE" -p "$SSH_PORT" "${KHAREJ_USER}@${KHAREJ_IP}" "echo OK" >/dev/null 2>&1; then
        printf "\r    ${G}[%d/%d]${N} ${G}✓${N} تست اتصال SSH\n" "$step" "$total_steps"
    else
        printf "\r    ${R}[%d/%d]${N} ${R}✗${N} تست اتصال SSH ناموفق\n" "$step" "$total_steps"
        ((errors++))
    fi
    echo ""

    # ═══════════════════════════════════════════════════════════════════════════
    #                         مرحله 5: ایجاد سرویس‌های تانل
    # ═══════════════════════════════════════════════════════════════════════════
    ((step++))
    printf "    ${C}[%d/%d]${N} ایجاد سرویس‌های تانل...\n" "$step" "$total_steps"

    # توقف سرویس‌های قبلی
    systemctl stop sshsaeed-tunnel*.service 2>/dev/null
    rm -f /etc/systemd/system/sshsaeed-tunnel*.service 2>/dev/null

    for t in $(seq 1 $TUNNEL_COUNT); do
        # ساخت دستورات فورواردینگ برای همه پورت‌ها
        local forward_args=""
        local port_index=1
        
        for port in "${TARGET_PORTS[@]}"; do
            local local_port=$(get_local_port $t $port_index)
            forward_args="$forward_args -L ${local_port}:127.0.0.1:${port}"
            ((port_index++))
        done

        cat > "/etc/systemd/system/sshsaeed-tunnel${t}.service" << EOF
[Unit]
Description=SSHSaeed Tunnel ${t} - Ports: ${TARGET_PORTS[*]}
After=network-online.target
Wants=network-online.target
StartLimitIntervalSec=0

[Service]
Type=simple
Environment="AUTOSSH_GATETIME=0"
Environment="AUTOSSH_PORT=0"
ExecStart=/usr/bin/autossh -M 0 -N -o "ServerAliveInterval=10" -o "ServerAliveCountMax=3" -o "ExitOnForwardFailure=yes" -o "StrictHostKeyChecking=no" -o "UserKnownHostsFile=/dev/null" -o "Ciphers=${CIPHER}" -i ${KEY_FILE} -p ${SSH_PORT} ${forward_args} ${KHAREJ_USER}@${KHAREJ_IP}
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF
    done

    systemctl daemon-reload
    printf "\r    ${G}[%d/%d]${N} ${G}✓${N} ایجاد ${TUNNEL_COUNT} سرویس تانل\n" "$step" "$total_steps"
    echo ""

    # ═══════════════════════════════════════════════════════════════════════════
    #                         مرحله 6: پیکربندی HAProxy
    # ═══════════════════════════════════════════════════════════════════════════
    ((step++))
    printf "    ${C}[%d/%d]${N} پیکربندی HAProxy...\n" "$step" "$total_steps"

    # بکاپ
    cp /etc/haproxy/haproxy.cfg "$BACKUP_DIR/haproxy.cfg.backup.$(date +%s)" 2>/dev/null

    # شروع فایل پیکربندی
    cat > /etc/haproxy/haproxy.cfg << 'HAPROXY_GLOBAL'
# ═══════════════════════════════════════════════════════════════════════════════
#  HAProxy Configuration - Generated by SSHSaeed v5.0
# ═══════════════════════════════════════════════════════════════════════════════

global
    log /dev/log local0
    log /dev/log local1 notice
    chroot /var/lib/haproxy
    stats socket /run/haproxy/admin.sock mode 660 level admin
    stats timeout 30s
    user haproxy
    group haproxy
    daemon
    maxconn 50000
    tune.ssl.default-dh-param 2048

defaults
    log     global
    mode    tcp
    option  tcplog
    option  dontlognull
    option  redispatch
    retries 3
    timeout connect 10s
    timeout client  1h
    timeout server  1h
    maxconn 50000

# ─────────────────────────────────────────────────────────────────────────────
#                              Stats Page
# ─────────────────────────────────────────────────────────────────────────────
listen stats
    bind *:8404
    mode http
    stats enable
    stats uri /stats
    stats refresh 5s
    stats admin if LOCALHOST

HAPROXY_GLOBAL

    # ایجاد frontend و backend برای هر پورت
    local port_index=1
    for port in "${TARGET_PORTS[@]}"; do
        cat >> /etc/haproxy/haproxy.cfg << EOF

# ─────────────────────────────────────────────────────────────────────────────
#                         Port ${port} Configuration
# ─────────────────────────────────────────────────────────────────────────────
frontend fe_port_${port}
    bind *:${port}
    mode tcp
    default_backend be_tunnels_${port}

backend be_tunnels_${port}
    mode tcp
    balance roundrobin
    option tcp-check
EOF

        # اضافه کردن سرورهای بک‌اند (تانل‌ها)
        for t in $(seq 1 $TUNNEL_COUNT); do
            local local_port=$(get_local_port $t $port_index)
            echo "    server tunnel${t}_port${port} 127.0.0.1:${local_port} check inter 5s fall 3 rise 2" >> /etc/haproxy/haproxy.cfg
        done

        ((port_index++))
    done

    # تست و ریستارت HAProxy
    if haproxy -c -f /etc/haproxy/haproxy.cfg >/dev/null 2>&1; then
        systemctl restart haproxy
        systemctl enable haproxy >/dev/null 2>&1
        printf "\r    ${G}[%d/%d]${N} ${G}✓${N} پیکربندی HAProxy\n" "$step" "$total_steps"
    else
        printf "\r    ${R}[%d/%d]${N} ${R}✗${N} خطا در پیکربندی HAProxy\n" "$step" "$total_steps"
        ((errors++))
    fi
    echo ""

    # ═══════════════════════════════════════════════════════════════════════════
    #                         مرحله 7: شروع تانل‌ها
    # ═══════════════════════════════════════════════════════════════════════════
    ((step++))
    printf "    ${C}[%d/%d]${N} شروع تانل‌ها...\n" "$step" "$total_steps"

    for t in $(seq 1 $TUNNEL_COUNT); do
        systemctl enable "sshsaeed-tunnel${t}.service" >/dev/null 2>&1
        systemctl start "sshsaeed-tunnel${t}.service"
    done

    sleep 3
    
    local active_tunnels=0
    for t in $(seq 1 $TUNNEL_COUNT); do
        if systemctl is-active --quiet "sshsaeed-tunnel${t}.service"; then
            ((active_tunnels++))
        fi
    done

    if [[ $active_tunnels -eq $TUNNEL_COUNT ]]; then
        printf "\r    ${G}[%d/%d]${N} ${G}✓${N} همه ${TUNNEL_COUNT} تانل فعال شدند\n" "$step" "$total_steps"
    else
        printf "\r    ${Y}[%d/%d]${N} ${Y}!${N} ${active_tunnels}/${TUNNEL_COUNT} تانل فعال\n" "$step" "$total_steps"
    fi
    echo ""

    # ═══════════════════════════════════════════════════════════════════════════
    #                         مرحله 8: ذخیره تنظیمات
    # ═══════════════════════════════════════════════════════════════════════════
    ((step++))
    printf "    ${C}[%d/%d]${N} ذخیره تنظیمات...\n" "$step" "$total_steps"

    save_config
    printf "\r    ${G}[%d/%d]${N} ${G}✓${N} ذخیره تنظیمات\n" "$step" "$total_steps"
    echo ""

    # ═══════════════════════════════════════════════════════════════════════════
    #                         نمایش نتیجه نهایی
    # ═══════════════════════════════════════════════════════════════════════════
    echo ""
    if [[ $errors -eq 0 ]]; then
        printf "    ${G}╔═══════════════════════════════════════════════════════════╗${N}\n"
        printf "    ${G}║${N}          ${W}✓ نصب با موفقیت کامل شد!${N}                       ${G}║${N}\n"
        printf "    ${G}╠═══════════════════════════════════════════════════════════╣${N}\n"
    else
        printf "    ${Y}╔═══════════════════════════════════════════════════════════╗${N}\n"
        printf "    ${Y}║${N}          ${Y}! نصب با ${errors} خطا کامل شد${N}                        ${Y}║${N}\n"
        printf "    ${Y}╠═══════════════════════════════════════════════════════════╣${N}\n"
    fi

    printf "    ${G}║${N}  سرور خارج:    ${C}%-38s${N} ${G}║${N}\n" "${KHAREJ_IP}"
    printf "    ${G}║${N}  تعداد تانل:   ${C}%-38s${N} ${G}║${N}\n" "${TUNNEL_COUNT}"
    printf "    ${G}║${N}  پورت‌ها:      ${C}%-38s${N} ${G}║${N}\n" "${TARGET_PORTS[*]}"
    printf "    ${G}║${N}  تانل‌های فعال: ${C}%-38s${N} ${G}║${N}\n" "${active_tunnels}/${TUNNEL_COUNT}"
    printf "    ${G}╠═══════════════════════════════════════════════════════════╣${N}\n"
    printf "    ${G}║${N}  ${Y}صفحه آمار HAProxy:${N} http://IP:8404/stats              ${G}║${N}\n"
    printf "    ${G}╚═══════════════════════════════════════════════════════════╝${N}\n"

    echo ""
    
    # نمایش جدول پورت‌ها
    printf "    ${C}┌───────────┬─────────────────────────────────────────┐${N}\n"
    printf "    ${C}│${N} ${W}پورت${N}     ${C}│${N} ${W}پورت‌های محلی تانل‌ها${N}                      ${C}│${N}\n"
    printf "    ${C}├───────────┼─────────────────────────────────────────┤${N}\n"
    
    local port_index=1
    for port in "${TARGET_PORTS[@]}"; do
        local ports_list=""
        for t in $(seq 1 $TUNNEL_COUNT); do
            local lp=$(get_local_port $t $port_index)
            ports_list="${ports_list}${lp} "
        done
        printf "    ${C}│${N} %-9s ${C}│${N} %-39s ${C}│${N}\n" "$port" "$ports_list"
        ((port_index++))
    done
    
    printf "    ${C}└───────────┴─────────────────────────────────────────┘${N}\n"

    log "INFO" "Iran server setup completed with $errors errors"

    echo ""
    read -p "$(printf "    ${C}Enter برای بازگشت...${N}")"
}

# ═══════════════════════════════════════════════════════════════════════════════
#                      گزینه 4: نمایش وضعیت
# ═══════════════════════════════════════════════════════════════════════════════
show_status() {
    show_banner
    line
    printf "    ${W}وضعیت سیستم${N}\n"
    line
    echo ""

    # بارگذاری تنظیمات
    if ! load_config; then
        print_err "فایل تنظیمات یافت نشد. ابتدا سرور ایران را راه‌اندازی کنید."
        echo ""
        read -p "$(printf "    ${C}Enter برای بازگشت...${N}")"
        return
    fi

    # وضعیت تانل‌ها
    printf "    ${Y}═══ وضعیت تانل‌ها ═══${N}\n"
    echo ""
    
    local active_count=0
    for t in $(seq 1 $TUNNEL_COUNT); do
        local service="sshsaeed-tunnel${t}.service"
        if systemctl is-active --quiet "$service"; then
            printf "    ${G}●${N} تانل %d: ${G}فعال${N}\n" "$t"
            ((active_count++))
        else
            printf "    ${R}○${N} تانل %d: ${R}غیرفعال${N}\n" "$t"
        fi
    done

    echo ""
    printf "    ${C}تانل‌های فعال: ${W}%d/%d${N}\n" "$active_count" "$TUNNEL_COUNT"
    echo ""

    # وضعیت HAProxy
    printf "    ${Y}═══ وضعیت HAProxy ═══${N}\n"
    echo ""
    
    if systemctl is-active --quiet haproxy; then
        printf "    ${G}●${N} HAProxy: ${G}فعال${N}\n"
    else
        printf "    ${R}○${N} HAProxy: ${R}غیرفعال${N}\n"
    fi
    echo ""

    # بررسی پورت‌ها
    printf "    ${Y}═══ پورت‌های فعال ═══${N}\n"
    echo ""
    
    for port in "${TARGET_PORTS[@]}"; do
        if ss -tlnp 2>/dev/null | grep -q ":${port} "; then
            printf "    ${G}●${N} پورت %s: ${G}باز${N}\n" "$port"
        else
            printf "    ${R}○${N} پورت %s: ${R}بسته${N}\n" "$port"
        fi
    done

    # پورت آمار
    if ss -tlnp 2>/dev/null | grep -q ":8404 "; then
        printf "    ${G}●${N} پورت 8404 (Stats): ${G}باز${N}\n"
    fi

    echo ""
    
    # اطلاعات سیستم
    printf "    ${Y}═══ اطلاعات سیستم ═══${N}\n"
    echo ""
    printf "    سرور خارج: ${C}%s${N}\n" "$KHAREJ_IP"
    printf "    پورت SSH:  ${C}%s${N}\n" "$SSH_PORT"
    printf "    کاربر:     ${C}%s${N}\n" "$KHAREJ_USER"

    echo ""
    log "INFO" "Status displayed"

    read -p "$(printf "    ${C}Enter برای بازگشت...${N}")"
}

# ═══════════════════════════════════════════════════════════════════════════════
#                      گزینه 5: ریستارت سرویس‌ها
# ═══════════════════════════════════════════════════════════════════════════════
restart_services() {
    show_banner
    line
    printf "    ${W}ریستارت سرویس‌ها${N}\n"
    line
    echo ""

    if ! load_config; then
        print_err "فایل تنظیمات یافت نشد"
        read -p "$(printf "    ${C}Enter برای بازگشت...${N}")"
        return
    fi

    print_info "در حال ریستارت تانل‌ها..."
    
    for t in $(seq 1 $TUNNEL_COUNT); do
        systemctl restart "sshsaeed-tunnel${t}.service" 2>/dev/null
        printf "    ${G}✓${N} تانل %d ریستارت شد\n" "$t"
    done

    echo ""
    print_info "در حال ریستارت HAProxy..."
    systemctl restart haproxy
    print_ok "HAProxy ریستارت شد"

    sleep 2

    echo ""
    local active=0
    for t in $(seq 1 $TUNNEL_COUNT); do
        systemctl is-active --quiet "sshsaeed-tunnel${t}.service" && ((active++))
    done

    printf "    ${C}نتیجه: ${W}%d/%d${N} تانل فعال\n" "$active" "$TUNNEL_COUNT"

    log "INFO" "Services restarted"

    echo ""
    read -p "$(printf "    ${C}Enter برای بازگشت...${N}")"
}

# ═══════════════════════════════════════════════════════════════════════════════
#                      گزینه 6: مشاهده لاگ‌ها
# ═══════════════════════════════════════════════════════════════════════════════
show_logs() {
    show_banner
    line
    printf "    ${W}لاگ‌های سیستم${N}\n"
    line
    echo ""

    printf "    ${Y}انتخاب کنید:${N}\n"
    echo ""
    printf "    ${C}1)${N} لاگ تانل 1\n"
    printf "    ${C}2)${N} لاگ تانل 2\n"
    printf "    ${C}3)${N} لاگ تانل 3\n"
    printf "    ${C}4)${N} لاگ HAProxy\n"
    printf "    ${C}5)${N} لاگ SSHSaeed\n"
    printf "    ${C}0)${N} بازگشت\n"
    echo ""

    read -p "$(printf "    ${C}انتخاب: ${N}")" choice

    case $choice in
        1) journalctl -u sshsaeed-tunnel1.service -n 50 --no-pager ;;
        2) journalctl -u sshsaeed-tunnel2.service -n 50 --no-pager ;;
        3) journalctl -u sshsaeed-tunnel3.service -n 50 --no-pager ;;
        4) journalctl -u haproxy -n 50 --no-pager ;;
        5) [[ -f "$LOG_FILE" ]] && tail -50 "$LOG_FILE" || print_err "فایل لاگ موجود نیست" ;;
        0) return ;;
    esac

    echo ""
    read -p "$(printf "    ${C}Enter برای بازگشت...${N}")"
}
# ═══════════════════════════════════════════════════════════════════════════════
#                      گزینه 7: حذف کامل
# ═══════════════════════════════════════════════════════════════════════════════
uninstall_all() {
    show_banner
    line
    printf "    ${R}حذف کامل SSHSaeed${N}\n"
    line
    echo ""

    printf "    ${Y}هشدار: تمام تنظیمات و سرویس‌ها حذف خواهند شد!${N}\n"
    echo ""

    read -p "$(printf "    ${R}آیا مطمئن هستید؟ (yes/no): ${N}")" confirm
    
    if [[ "$confirm" != "yes" ]]; then
        print_info "عملیات لغو شد"
        read -p "$(printf "    ${C}Enter برای بازگشت...${N}")"
        return
    fi

    echo ""
    print_info "در حال حذف..."
    echo ""

    # توقف و حذف سرویس‌های تانل
    print_info "توقف سرویس‌های تانل..."
    for i in {1..10}; do
        systemctl stop "sshsaeed-tunnel${i}.service" 2>/dev/null
        systemctl disable "sshsaeed-tunnel${i}.service" 2>/dev/null
        rm -f "/etc/systemd/system/sshsaeed-tunnel${i}.service" 2>/dev/null
    done
    print_ok "سرویس‌های تانل حذف شدند"

    # بازگردانی HAProxy به حالت پیش‌فرض
    print_info "بازنشانی HAProxy..."
    systemctl stop haproxy 2>/dev/null
    
    # بازگردانی از بکاپ اگر موجود باشد
    local latest_backup=$(ls -t "$BACKUP_DIR"/haproxy.cfg.backup.* 2>/dev/null | head -1)
    if [[ -n "$latest_backup" ]]; then
        cp "$latest_backup" /etc/haproxy/haproxy.cfg 2>/dev/null
    else
        # پیکربندی پیش‌فرض HAProxy
        cat > /etc/haproxy/haproxy.cfg << 'HADEFAULT'
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
    timeout connect 5000
    timeout client  50000
    timeout server  50000
HADEFAULT
    fi
    print_ok "HAProxy بازنشانی شد"

    # حذف کلید SSH
    print_info "حذف کلید SSH..."
    rm -f "$KEY_FILE" "${KEY_FILE}.pub" 2>/dev/null
    rm -f /root/.ssh/sshsaeed_key /root/.ssh/sshsaeed_key.pub 2>/dev/null
    print_ok "کلید SSH حذف شد"

    # حذف فایل‌های پیکربندی
    print_info "حذف فایل‌های پیکربندی..."
    rm -rf "$CONFIG_DIR" 2>/dev/null
    rm -f /etc/ssh/sshd_config.d/sshsaeed.conf 2>/dev/null
    print_ok "فایل‌های پیکربندی حذف شدند"

    # حذف لاگ
    print_info "حذف لاگ‌ها..."
    rm -f "$LOG_FILE" 2>/dev/null
    print_ok "لاگ‌ها حذف شدند"

    # بازخوانی systemd
    systemctl daemon-reload

    echo ""
    printf "    ${G}╔═══════════════════════════════════════════════════╗${N}\n"
    printf "    ${G}║${N}      ${W}SSHSaeed با موفقیت حذف شد${N}                  ${G}║${N}\n"
    printf "    ${G}╚═══════════════════════════════════════════════════╝${N}\n"

    log "INFO" "SSHSaeed uninstalled completely"

    echo ""
    read -p "$(printf "    ${C}Enter برای خروج...${N}")"
    exit 0
}

# ═══════════════════════════════════════════════════════════════════════════════
#                      گزینه 8: به‌روزرسانی
# ═══════════════════════════════════════════════════════════════════════════════
update_script() {
    show_banner
    line
    printf "    ${W}به‌روزرسانی اسکریپت${N}\n"
    line
    echo ""

    print_info "نسخه فعلی: ${W}v${VERSION}${N}"
    echo ""

    # بررسی آخرین نسخه (در صورت وجود)
    print_info "بررسی آخرین نسخه..."
    
    local latest_version=$(curl -s --connect-timeout 5 \
        "https://raw.githubusercontent.com/sshsaeed/tunnel-manager/main/version.txt" 2>/dev/null)

    if [[ -n "$latest_version" ]]; then
        print_info "آخرین نسخه موجود: ${W}v${latest_version}${N}"
        
        if [[ "$latest_version" != "$VERSION" ]]; then
            echo ""
            read -p "$(printf "    ${Y}آیا می‌خواهید به‌روزرسانی کنید؟ (y/n): ${N}")" update_confirm
            
            if [[ "$update_confirm" == "y" || "$update_confirm" == "Y" ]]; then
                print_info "دانلود نسخه جدید..."
                
                if curl -sL "https://raw.githubusercontent.com/sshsaeed/tunnel-manager/main/install.sh" \
                    -o /tmp/sshsaeed_update.sh 2>/dev/null; then
                    
                    chmod +x /tmp/sshsaeed_update.sh
                    print_ok "نسخه جدید دانلود شد"
                    print_info "در حال اجرای نسخه جدید..."
                    
                    exec /tmp/sshsaeed_update.sh
                else
                    print_err "خطا در دانلود"
                fi
            fi
        else
            print_ok "شما آخرین نسخه را دارید"
        fi
    else
        print_warn "امکان بررسی نسخه وجود ندارد"
    fi

    echo ""
    read -p "$(printf "    ${C}Enter برای بازگشت...${N}")"
}

# ═══════════════════════════════════════════════════════════════════════════════
#                      گزینه 9: تنظیمات پیشرفته
# ═══════════════════════════════════════════════════════════════════════════════
advanced_settings() {
    while true; do
        show_banner
        line
        printf "    ${W}تنظیمات پیشرفته${N}\n"
        line
        echo ""

        printf "    ${C}1)${N} تغییر تعداد تانل‌ها\n"
        printf "    ${C}2)${N} تغییر پورت‌های هدف\n"
        printf "    ${C}3)${N} تغییر سرور خارج\n"
        printf "    ${C}4)${N} تولید مجدد کلید SSH\n"
        printf "    ${C}5)${N} تست اتصال SSH\n"
        printf "    ${C}6)${N} نمایش تنظیمات فعلی\n"
        printf "    ${C}0)${N} بازگشت به منوی اصلی\n"
        echo ""

        read -p "$(printf "    ${C}انتخاب: ${N}")" adv_choice

        case $adv_choice in
            1) change_tunnel_count ;;
            2) change_target_ports ;;
            3) change_kharej_server ;;
            4) regenerate_ssh_key ;;
            5) test_ssh_connection ;;
            6) show_current_config ;;
            0) break ;;
            *) print_err "گزینه نامعتبر" ; sleep 1 ;;
        esac
    done
}

# ═══════════════════ توابع فرعی تنظیمات پیشرفته ═══════════════════

change_tunnel_count() {
    show_banner
    line
    printf "    ${W}تغییر تعداد تانل‌ها${N}\n"
    line
    echo ""

    if ! load_config; then
        print_err "ابتدا سرور ایران را راه‌اندازی کنید"
        read -p "$(printf "    ${C}Enter برای بازگشت...${N}")"
        return
    fi

    printf "    تعداد فعلی: ${C}%d${N}\n" "$TUNNEL_COUNT"
    echo ""

    read -p "$(printf "    ${C}➤${N} تعداد جدید (1-10): ")" new_count

    if [[ ! "$new_count" =~ ^[0-9]+$ ]] || [[ $new_count -lt 1 ]] || [[ $new_count -gt 10 ]]; then
        print_err "عدد نامعتبر (1-10)"
        read -p "$(printf "    ${C}Enter برای بازگشت...${N}")"
        return
    fi

    TUNNEL_COUNT=$new_count
    save_config

    # بازسازی سرویس‌ها
    print_info "بازسازی سرویس‌ها..."
    
    # توقف همه سرویس‌های قبلی
    for i in {1..10}; do
        systemctl stop "sshsaeed-tunnel${i}.service" 2>/dev/null
        systemctl disable "sshsaeed-tunnel${i}.service" 2>/dev/null
        rm -f "/etc/systemd/system/sshsaeed-tunnel${i}.service" 2>/dev/null
    done

    # ایجاد سرویس‌های جدید
    for t in $(seq 1 $TUNNEL_COUNT); do
        local forward_args=""
        local port_index=1
        
        for port in "${TARGET_PORTS[@]}"; do
            local local_port=$(get_local_port $t $port_index)
            forward_args="$forward_args -L ${local_port}:127.0.0.1:${port}"
            ((port_index++))
        done

        cat > "/etc/systemd/system/sshsaeed-tunnel${t}.service" << EOF
[Unit]
Description=SSHSaeed Tunnel ${t}
After=network-online.target
Wants=network-online.target
StartLimitIntervalSec=0

[Service]
Type=simple
Environment="AUTOSSH_GATETIME=0"
Environment="AUTOSSH_PORT=0"
ExecStart=/usr/bin/autossh -M 0 -N -o "ServerAliveInterval=10" -o "ServerAliveCountMax=3" -o "ExitOnForwardFailure=yes" -o "StrictHostKeyChecking=no" -o "UserKnownHostsFile=/dev/null" -o "Ciphers=${CIPHER}" -i ${KEY_FILE} -p ${SSH_PORT} ${forward_args} ${KHAREJ_USER}@${KHAREJ_IP}
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF

        systemctl enable "sshsaeed-tunnel${t}.service" >/dev/null 2>&1
        systemctl start "sshsaeed-tunnel${t}.service"
    done

    # بازسازی HAProxy
    rebuild_haproxy_config

    systemctl daemon-reload
    systemctl restart haproxy

    print_ok "تعداد تانل‌ها به ${new_count} تغییر کرد"

    read -p "$(printf "    ${C}Enter برای بازگشت...${N}")"
}

change_target_ports() {
    show_banner
    line
    printf "    ${W}تغییر پورت‌های هدف${N}\n"
    line
    echo ""

    if ! load_config; then
        print_err "ابتدا سرور ایران را راه‌اندازی کنید"
        read -p "$(printf "    ${C}Enter برای بازگشت...${N}")"
        return
    fi

    printf "    پورت‌های فعلی: ${C}%s${N}\n" "${TARGET_PORTS[*]}"
    echo ""

    printf "    ${Y}پورت‌ها را با کاما جدا کنید${N}\n"
    read -p "$(printf "    ${C}➤${N} پورت‌های جدید: ")" new_ports

    if [[ -z "$new_ports" ]]; then
        print_err "پورت‌ها نمی‌توانند خالی باشند"
        read -p "$(printf "    ${C}Enter برای بازگشت...${N}")"
        return
    fi

    IFS=',' read -ra TARGET_PORTS <<< "$new_ports"
    save_config

    # بازسازی سرویس‌ها و HAProxy
    print_info "بازسازی سرویس‌ها..."
    
    for t in $(seq 1 $TUNNEL_COUNT); do
        local forward_args=""
        local port_index=1
        
        for port in "${TARGET_PORTS[@]}"; do
            local local_port=$(get_local_port $t $port_index)
            forward_args="$forward_args -L ${local_port}:127.0.0.1:${port}"
            ((port_index++))
        done

        cat > "/etc/systemd/system/sshsaeed-tunnel${t}.service" << EOF
[Unit]
Description=SSHSaeed Tunnel ${t}
After=network-online.target
Wants=network-online.target
StartLimitIntervalSec=0

[Service]
Type=simple
Environment="AUTOSSH_GATETIME=0"
Environment="AUTOSSH_PORT=0"
ExecStart=/usr/bin/autossh -M 0 -N -o "ServerAliveInterval=10" -o "ServerAliveCountMax=3" -o "ExitOnForwardFailure=yes" -o "StrictHostKeyChecking=no" -o "UserKnownHostsFile=/dev/null" -o "Ciphers=${CIPHER}" -i ${KEY_FILE} -p ${SSH_PORT} ${forward_args} ${KHAREJ_USER}@${KHAREJ_IP}
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF
    done

    rebuild_haproxy_config

    systemctl daemon-reload

    for t in $(seq 1 $TUNNEL_COUNT); do
        systemctl restart "sshsaeed-tunnel${t}.service"
    done
    systemctl restart haproxy

    print_ok "پورت‌ها تغییر کردند"

    read -p "$(printf "    ${C}Enter برای بازگشت...${N}")"
}

change_kharej_server() {
    show_banner
    line
    printf "    ${W}تغییر سرور خارج${N}\n"
    line
    echo ""

    if ! load_config; then
        print_err "ابتدا سرور ایران را راه‌اندازی کنید"
        read -p "$(printf "    ${C}Enter برای بازگشت...${N}")"
        return
    fi

    printf "    سرور فعلی: ${C}%s${N}\n" "$KHAREJ_IP"
    echo ""

    read -p "$(printf "    ${C}➤${N} IP جدید سرور خارج: ")" new_ip
    
    if [[ ! $new_ip =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
        print_err "IP نامعتبر"
        read -p "$(printf "    ${C}Enter برای بازگشت...${N}")"
        return
    fi

    read -sp "$(printf "    ${C}➤${N} پسورد سرور جدید: ")" new_pass
    echo ""

    KHAREJ_IP=$new_ip

    # کپی کلید به سرور جدید
    print_info "کپی کلید به سرور جدید..."
    
    if sshpass -p "$new_pass" ssh-copy-id -i "${KEY_FILE}.pub" \
        -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null \
        -p "$SSH_PORT" "${KHAREJ_USER}@${KHAREJ_IP}" >/dev/null 2>&1; then
        print_ok "کلید کپی شد"
    else
        print_err "خطا در کپی کلید"
        read -p "$(printf "    ${C}Enter برای بازگشت...${N}")"
        return
    fi

    save_config

    # بازسازی سرویس‌ها
    for t in $(seq 1 $TUNNEL_COUNT); do
        local forward_args=""
        local port_index=1
        
        for port in "${TARGET_PORTS[@]}"; do
            local local_port=$(get_local_port $t $port_index)
            forward_args="$forward_args -L ${local_port}:127.0.0.1:${port}"
            ((port_index++))
        done

        cat > "/etc/systemd/system/sshsaeed-tunnel${t}.service" << EOF
[Unit]
Description=SSHSaeed Tunnel ${t}
After=network-online.target
Wants=network-online.target
StartLimitIntervalSec=0

[Service]
Type=simple
Environment="AUTOSSH_GATETIME=0"
Environment="AUTOSSH_PORT=0"
ExecStart=/usr/bin/autossh -M 0 -N -o "ServerAliveInterval=10" -o "ServerAliveCountMax=3" -o "ExitOnForwardFailure=yes" -o "StrictHostKeyChecking=no" -o "UserKnownHostsFile=/dev/null" -o "Ciphers=${CIPHER}" -i ${KEY_FILE} -p ${SSH_PORT} ${forward_args} ${KHAREJ_USER}@${KHAREJ_IP}
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF
    done

    systemctl daemon-reload

    for t in $(seq 1 $TUNNEL_COUNT); do
        systemctl restart "sshsaeed-tunnel${t}.service"
    done

    print_ok "سرور خارج تغییر کرد"

    read -p "$(printf "    ${C}Enter برای بازگشت...${N}")"
}

regenerate_ssh_key() {
    show_banner
    line
    printf "    ${W}تولید مجدد کلید SSH${N}\n"
    line
    echo ""

    if ! load_config; then
        print_err "ابتدا سرور ایران را راه‌اندازی کنید"
        read -p "$(printf "    ${C}Enter برای بازگشت...${N}")"
        return
    fi

    printf "    ${Y}هشدار: کلید قبلی حذف خواهد شد!${N}\n"
    read -p "$(printf "    ${Y}ادامه؟ (y/n): ${N}")" confirm

    if [[ "$confirm" != "y" ]]; then
        return
    fi

    read -sp "$(printf "    ${C}➤${N} پسورد سرور خارج: ")" kharej_pass
    echo ""

    # حذف کلید قدیمی
    rm -f "$KEY_FILE" "${KEY_FILE}.pub"

    # ایجاد کلید جدید
    print_info "ایجاد کلید جدید..."
    ssh-keygen -t ed25519 -f "$KEY_FILE" -N "" -C "sshsaeed@iran" -q
    chmod 600 "$KEY_FILE"

    # کپی به سرور
    print_info "کپی به سرور خارج..."
    if sshpass -p "$kharej_pass" ssh-copy-id -i "${KEY_FILE}.pub" \
        -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null \
        -p "$SSH_PORT" "${KHAREJ_USER}@${KHAREJ_IP}" >/dev/null 2>&1; then
        print_ok "کلید جدید ایجاد و کپی شد"
    else
        print_err "خطا در کپی کلید"
    fi

    # ریستارت تانل‌ها
    for t in $(seq 1 $TUNNEL_COUNT); do
        systemctl restart "sshsaeed-tunnel${t}.service"
    done

    read -p "$(printf "    ${C}Enter برای بازگشت...${N}")"
}

test_ssh_connection() {
    show_banner
    line
    printf "    ${W}تست اتصال SSH${N}\n"
    line
    echo ""

    if ! load_config; then
        print_err "ابتدا سرور ایران را راه‌اندازی کنید"
        read -p "$(printf "    ${C}Enter برای بازگشت...${N}")"
        return
    fi

    print_info "تست اتصال به ${KHAREJ_IP}..."
    echo ""

    if ssh -o BatchMode=yes -o ConnectTimeout=10 -o StrictHostKeyChecking=no \
       -i "$KEY_FILE" -p "$SSH_PORT" "${KHAREJ_USER}@${KHAREJ_IP}" "echo 'Connection OK'" 2>/dev/null; then
        echo ""
        print_ok "اتصال SSH برقرار است"
    else
        echo ""
        print_err "اتصال SSH برقرار نیست"
        echo ""
        print_info "بررسی‌های پیشنهادی:"
        printf "    ${GR}1. آیا سرور خارج روشن است؟${N}\n"
        printf "    ${GR}2. آیا IP صحیح است؟${N}\n"
        printf "    ${GR}3. آیا کلید SSH روی سرور خارج وجود دارد؟${N}\n"
        printf "    ${GR}4. آیا پورت 22 روی سرور خارج باز است؟${N}\n"
    fi

    read -p "$(printf "    ${C}Enter برای بازگشت...${N}")"
}

show_current_config() {
    show_banner
    line
    printf "    ${W}تنظیمات فعلی${N}\n"
    line
    echo ""

    if ! load_config; then
        print_err "فایل تنظیمات یافت نشد"
        read -p "$(printf "    ${C}Enter برای بازگشت...${N}")"
        return
    fi

    printf "    ${C}┌─────────────────────────────────────────────────┐${N}\n"
    printf "    ${C}│${N} %-20s: %-24s ${C}│${N}\n" "سرور خارج" "$KHAREJ_IP"
    printf "    ${C}│${N} %-20s: %-24s ${C}│${N}\n" "پورت SSH" "$SSH_PORT"
    printf "    ${C}│${N} %-20s: %-24s ${C}│${N}\n" "کاربر" "$KHAREJ_USER"
    printf "    ${C}│${N} %-20s: %-24s ${C}│${N}\n" "تعداد تانل" "$TUNNEL_COUNT"
    printf "    ${C}│${N} %-20s: %-24s ${C}│${N}\n" "پورت‌های هدف" "${TARGET_PORTS[*]}"
    printf "    ${C}│${N} %-20s: %-24s ${C}│${N}\n" "رمزنگاری" "$CIPHER"
    printf "    ${C}│${N} %-20s: %-24s ${C}│${N}\n" "کلید SSH" "$KEY_FILE"
    printf "    ${C}└─────────────────────────────────────────────────┘${N}\n"

    echo ""

    # نمایش نگاشت پورت‌ها
    printf "    ${Y}نگاشت پورت‌ها:${N}\n"
    echo ""
    
    local port_index=1
    for port in "${TARGET_PORTS[@]}"; do
        printf "    پورت ${C}%s${N} → " "$port"
        for t in $(seq 1 $TUNNEL_COUNT); do
            local lp=$(get_local_port $t $port_index)
            printf "تانل%d:${G}%d${N} " "$t" "$lp"
        done
        echo ""
        ((port_index++))
    done

    read -p "$(printf "    ${C}Enter برای بازگشت...${N}")"
}

# تابع کمکی برای بازسازی HAProxy
rebuild_haproxy_config() {
    cat > /etc/haproxy/haproxy.cfg << 'HAPROXY_GLOBAL'
global
    log /dev/log local0
    log /dev/log local1 notice
    chroot /var/lib/haproxy
    stats socket /run/haproxy/admin.sock mode 660 level admin
    stats timeout 30s
    user haproxy
    group haproxy
    daemon
    maxconn 50000

defaults
    log     global
    mode    tcp
    option  tcplog
    option  dontlognull
    option  redispatch
    retries 3
    timeout connect 10s
    timeout client  1h
    timeout server  1h
    maxconn 50000

listen stats
    bind *:8404
    mode http
    stats enable
    stats uri /stats
    stats refresh 5s
    stats admin if LOCALHOST

HAPROXY_GLOBAL

    local port_index=1
    for port in "${TARGET_PORTS[@]}"; do
        cat >> /etc/haproxy/haproxy.cfg << EOF

frontend fe_port_${port}
    bind *:${port}
    mode tcp
    default_backend be_tunnels_${port}

backend be_tunnels_${port}
    mode tcp
    balance roundrobin
    option tcp-check
EOF

        for t in $(seq 1 $TUNNEL_COUNT); do
            local local_port=$(get_local_port $t $port_index)
            echo "    server tunnel${t}_port${port} 127.0.0.1:${local_port} check inter 5s fall 3 rise 2" >> /etc/haproxy/haproxy.cfg
        done

        ((port_index++))
    done
}

# ═══════════════════════════════════════════════════════════════════════════════
#                              منوی اصلی
# ═══════════════════════════════════════════════════════════════════════════════
main_menu() {
    while true; do
        show_banner
        line
        printf "    ${W}منوی اصلی${N}\n"
        line
        echo ""

        # نمایش وضعیت سریع
        local tunnel_status="${R}○ غیرفعال${N}"
        local haproxy_status="${R}○ غیرفعال${N}"

        if load_config 2>/dev/null; then
            local active=0
            for t in $(seq 1 $TUNNEL_COUNT 2>/dev/null); do
                systemctl is-active --quiet "sshsaeed-tunnel${t}.service" 2>/dev/null && ((active++))
            done
            if [[ $active -gt 0 ]]; then
                tunnel_status="${G}● ${active}/${TUNNEL_COUNT} فعال${N}"
            fi
        fi

        if systemctl is-active --quiet haproxy 2>/dev/null; then
            haproxy_status="${G}● فعال${N}"
        fi

        printf "    ${GR}وضعیت: تانل‌ها: ${N}$tunnel_status  ${GR}| HAProxy: ${N}$haproxy_status\n"
        echo ""
        line_thin
        echo ""

        printf "    ${C}1)${N}  ${W}تست سرعت AES${N}              ${GR}(بررسی پشتیبانی AES-NI)${N}\n"
        printf "    ${C}2)${N}  ${W}تنظیم سرور خارج${N}           ${GR}(Kharej Server)${N}\n"
        printf "    ${C}3)${N}  ${W}تنظیم سرور ایران${N}          ${GR}(Iran Server + Tunnels)${N}\n"
        echo ""
        line_thin
        echo ""
        printf "    ${C}4)${N}  ${W}نمایش وضعیت${N}               ${GR}(Status)${N}\n"
        printf "    ${C}5)${N}  ${W}ریستارت سرویس‌ها${N}          ${GR}(Restart)${N}\n"
        printf "    ${C}6)${N}  ${W}مشاهده لاگ‌ها${N}              ${GR}(Logs)${N}\n"
        echo ""
        line_thin
        echo ""
        printf "    ${C}7)${N}  ${R}حذف کامل${N}                  ${GR}(Uninstall)${N}\n"
        printf "    ${C}8)${N}  ${W}به‌روزرسانی${N}                ${GR}(Update)${N}\n"
        printf "    ${C}9)${N}  ${W}تنظیمات پیشرفته${N}           ${GR}(Advanced)${N}\n"
        echo ""
        line_thin
        echo ""
        printf "    ${C}0)${N}  ${W}خروج${N}\n"
        echo ""

        read -p "$(printf "    ${C}انتخاب شما: ${N}")" choice

        case $choice in
            1) test_aes_speed ;;
            2) setup_kharej_server ;;
            3) setup_iran_server ;;
            4) show_status ;;
            5) restart_services ;;
            6) show_logs ;;
            7) uninstall_all ;;
            8) update_script ;;
            9) advanced_settings ;;
            0) 
                echo ""
                print_info "خدانگهدار! 👋"
                echo ""
                exit 0
                ;;
            *)
                print_err "گزینه نامعتبر"
                sleep 1
                ;;
        esac
    done
}

# ═══════════════════════════════════════════════════════════════════════════════
#                              نقطه ورود برنامه
# ═══════════════════════════════════════════════════════════════════════════════

# بررسی دسترسی root
if [[ $EUID -ne 0 ]]; then
    echo ""
    printf "  ${R}✗${N} این اسکریپت نیاز به دسترسی root دارد\n"
    printf "  ${C}➤${N} اجرا کنید: ${W}sudo $0${N}\n"
    echo ""
    exit 1
fi

# ایجاد دایرکتوری‌ها
mkdir -p "$CONFIG_DIR" "$BACKUP_DIR" 2>/dev/null

# لاگ شروع
log "INFO" "SSHSaeed v${VERSION} started"

# اجرای منوی اصلی
main_menu
