#!/bin/bash
# ═══════════════════════════════════════════════════════════════════════════════
#  ███████╗███████╗██╗  ██╗███████╗ █████╗ ███████╗███████╗██████╗ 
#  ██╔════╝██╔════╝██║  ██║██╔════╝██╔══██╗██╔════╝██╔════╝██╔══██╗
#  ███████╗███████╗███████║███████╗███████║█████╗  █████╗  ██║  ██║
#  ╚════██║╚════██║██╔══██║╚════██║██╔══██║██╔══╝  ██╔══╝  ██║  ██║
#  ███████║███████║██║  ██║███████║██║  ██║███████╗███████╗██████╔╝
#  ╚══════╝╚══════╝╚═╝  ╚═╝╚══════╝╚═╝  ╚═╝╚══════╝╚══════╝╚═════╝ 
# ═══════════════════════════════════════════════════════════════════════════════
#  SSH Tunnel Manager v4.0 | AES-128-GCM + HAProxy + AutoSSH
#  GitHub: https://github.com/sshsaeed/tunnel-manager
#  Author: SSHSaeed
# ═══════════════════════════════════════════════════════════════════════════════

set -o pipefail
export LC_ALL=C
export LANG=C

# ═══════════════════════════════════════════════════════════════════════════════
#                              تنظیمات اصلی
# ═══════════════════════════════════════════════════════════════════════════════
readonly VERSION="4.0"
readonly GITHUB_URL="https://github.com/sshsaeed/tunnel-manager"
readonly CONFIG_DIR="/etc/sshsaeed"
readonly CONFIG_FILE="$CONFIG_DIR/config.conf"
readonly KEY_FILE="/root/.ssh/sshsaeed_ed25519"
readonly LOG_FILE="/var/log/sshsaeed.log"
readonly BACKUP_DIR="/etc/sshsaeed/backups"

# تنظیمات تانل - فقط AES-128-GCM
readonly CIPHER="aes128-gcm@openssh.com"
readonly TUNNEL_USER="tunnel"

# پورت‌های پیش‌فرض
DEFAULT_PORTS="443,8443,2096"
HAPROXY_PORT=443
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
ICO_RUN="●"
ICO_STOP="○"

# ═══════════════════════════════════════════════════════════════════════════════
#                              توابع نمایش
# ═══════════════════════════════════════════════════════════════════════════════
print_ok()    { printf "  ${G}${ICO_OK}${N} %s\n" "$1"; }
print_err()   { printf "  ${R}${ICO_ERR}${N} %s\n" "$1"; }
print_warn()  { printf "  ${Y}${ICO_WARN}${N} %s\n" "$1"; }
print_info()  { printf "  ${C}${ICO_INFO}${N} %s\n" "$1"; }
print_wait()  { printf "  ${GR}${ICO_WAIT}${N} %s" "$1"; }
print_done()  { printf "\r  ${G}${ICO_OK}${N} %s\n" "$1"; }

# پروگرس بار
progress_bar() {
    local current=$1
    local total=$2
    local width=40
    local percent=$((current * 100 / total))
    local filled=$((current * width / total))
    local empty=$((width - filled))
    
    printf "\r  ${C}["
    printf "%${filled}s" | tr ' ' '█'
    printf "%${empty}s" | tr ' ' '░'
    printf "]${N} ${W}%3d%%${N}" "$percent"
}

# خط جداکننده
line() {
    printf "${C}═══════════════════════════════════════════════════════════════${N}\n"
}

line_thin() {
    printf "${GR}───────────────────────────────────────────────────────────────${N}\n"
}

# ═══════════════════════════════════════════════════════════════════════════════
#                              بنر اصلی
# ═══════════════════════════════════════════════════════════════════════════════
show_banner() {
    clear
    printf "${G}"
    cat << 'BANNER'
    ╔═══════════════════════════════════════════════════════════════╗
    ║  ███████╗███████╗██╗  ██╗███████╗ █████╗ ███████╗██████╗      ║
    ║  ██╔════╝██╔════╝██║  ██║██╔════╝██╔══██╗██╔════╝██╔══██╗     ║
    ║  ███████╗███████╗███████║███████╗███████║█████╗  ██║  ██║     ║
    ║  ╚════██║╚════██║██╔══██║╚════██║██╔══██║██╔══╝  ██║  ██║     ║
    ║  ███████║███████║██║  ██║███████║██║  ██║███████╗██████╔╝     ║
    ║  ╚══════╝╚══════╝╚═╝  ╚═╝╚══════╝╚═╝  ╚═╝╚══════╝╚═════╝      ║
    ╚═══════════════════════════════════════════════════════════════╝
BANNER
    printf "${N}"
    printf "    ${GR}────────────────────────────────────────────────────────────${N}\n"
    printf "    ${Y}Version:${N} ${W}${VERSION}${N}  ${Y}|${N}  ${C}SSH + HAProxy + AES-128-GCM + AutoSSH${N}\n"
    printf "    ${B}GitHub:${N}  ${W}${GITHUB_URL}${N}\n"
    printf "    ${GR}────────────────────────────────────────────────────────────${N}\n"
    echo ""
}

# ═══════════════════════════════════════════════════════════════════════════════
#                              توابع لاگ
# ═══════════════════════════════════════════════════════════════════════════════
log() {
    local level="$1"
    local message="$2"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    printf "[%s] [%-5s] %s\n" "$timestamp" "$level" "$message" >> "$LOG_FILE" 2>/dev/null
}

# ═══════════════════════════════════════════════════════════════════════════════
#                              توابع سیستمی
# ═══════════════════════════════════════════════════════════════════════════════
check_root() {
    if [[ $EUID -ne 0 ]]; then
        print_err "این اسکریپت نیاز به دسترسی root دارد"
        printf "    ${Y}اجرا کنید:${N} sudo $0\n"
        exit 1
    fi
}

init_system() {
    mkdir -p "$CONFIG_DIR" "$BACKUP_DIR" /root/.ssh
    chmod 700 "$CONFIG_DIR" /root/.ssh
    touch "$LOG_FILE"
    chmod 600 "$LOG_FILE"
}

get_local_ip() {
    ip -4 route get 8.8.8.8 2>/dev/null | awk '{print $7; exit}' || \
    hostname -I 2>/dev/null | awk '{print $1}' || \
    curl -s ifconfig.me 2>/dev/null
}

get_os_info() {
    if [[ -f /etc/os-release ]]; then
        . /etc/os-release
        echo "$NAME $VERSION_ID"
    else
        uname -s
    fi
}

# ═══════════════════════════════════════════════════════════════════════════════
#                              مدیریت پیکربندی
# ═══════════════════════════════════════════════════════════════════════════════
load_config() {
    if [[ -f "$CONFIG_FILE" ]]; then
        source "$CONFIG_FILE"
        return 0
    fi
    return 1
}

save_config() {
    cat > "$CONFIG_FILE" << EOF
# SSHSaeed Configuration - Generated $(date)
# Do not edit manually

SERVER_TYPE="${SERVER_TYPE}"
KHAREJ_IP="${KHAREJ_IP}"
KHAREJ_SSH_PORT="${KHAREJ_SSH_PORT:-22}"
TUNNEL_PORTS="${TUNNEL_PORTS}"
HAPROXY_PORT="${HAPROXY_PORT}"
TARGET_PORT="${TARGET_PORT:-443}"
INSTALLED_DATE="$(date '+%Y-%m-%d %H:%M:%S')"
EOF
    chmod 600 "$CONFIG_FILE"
    log "INFO" "Configuration saved"
}

# ═══════════════════════════════════════════════════════════════════════════════
#                              نصب پکیج‌ها
# ═══════════════════════════════════════════════════════════════════════════════
install_packages() {
    print_info "بررسی و نصب پکیج‌های مورد نیاز..."
    echo ""
    
    local packages=(openssh-client openssh-server autossh haproxy sshpass curl wget net-tools)
    local to_install=()
    local installed=0
    local total=${#packages[@]}
    
    # تشخیص پکیج منیجر
    local PM=""
    local PM_INSTALL=""
    local PM_UPDATE=""
    
    if command -v apt &>/dev/null; then
        PM="apt"
        PM_UPDATE="apt update -qq"
        PM_INSTALL="apt install -y -qq"
    elif command -v dnf &>/dev/null; then
        PM="dnf"
        PM_UPDATE="dnf check-update -q"
        PM_INSTALL="dnf install -y -q"
    elif command -v yum &>/dev/null; then
        PM="yum"
        PM_UPDATE="yum check-update -q"
        PM_INSTALL="yum install -y -q"
    else
        print_err "پکیج منیجر پشتیبانی نشده"
        return 1
    fi
    
    # بررسی پکیج‌ها
    for pkg in "${packages[@]}"; do
        ((installed++))
        progress_bar $installed $total
        
        case $pkg in
            openssh-client) command -v ssh &>/dev/null || to_install+=($pkg) ;;
            openssh-server) command -v sshd &>/dev/null || to_install+=($pkg) ;;
            autossh) command -v autossh &>/dev/null || to_install+=($pkg) ;;
            haproxy) command -v haproxy &>/dev/null || to_install+=($pkg) ;;
            sshpass) command -v sshpass &>/dev/null || to_install+=($pkg) ;;
            curl) command -v curl &>/dev/null || to_install+=($pkg) ;;
            wget) command -v wget &>/dev/null || to_install+=($pkg) ;;
            net-tools) command -v netstat &>/dev/null || to_install+=($pkg) ;;
        esac
        sleep 0.1
    done
    
    echo ""
    
    if [[ ${#to_install[@]} -gt 0 ]]; then
        print_info "نصب ${#to_install[@]} پکیج: ${to_install[*]}"
        
        $PM_UPDATE &>/dev/null
        $PM_INSTALL "${to_install[@]}" &>/dev/null
        
        if [[ $? -eq 0 ]]; then
            print_ok "پکیج‌ها با موفقیت نصب شدند"
        else
            print_err "خطا در نصب پکیج‌ها"
            return 1
        fi
    else
        print_ok "همه پکیج‌ها از قبل نصب هستند"
    fi
    
    return 0
}

# ═══════════════════════════════════════════════════════════════════════════════
#                         گزینه 1: تست AES-128-GCM
# ═══════════════════════════════════════════════════════════════════════════════
test_aes_support() {
    show_banner
    line
    printf "    ${W}تست پشتیبانی AES-128-GCM روی سرور فعلی${N}\n"
    line
    echo ""
    
    local score=0
    local max_score=5
    
    # ═══════════ تست 1: AES-NI در CPU ═══════════
    printf "  ${C}[1/5]${N} ${W}بررسی پشتیبانی AES-NI در CPU...${N}\n"
    sleep 0.5
    
    if grep -q 'aes' /proc/cpuinfo 2>/dev/null; then
        local cpu_model=$(grep -m1 "model name" /proc/cpuinfo | cut -d: -f2 | xargs)
        print_ok "AES-NI پشتیبانی می‌شود"
        printf "        ${GR}CPU: %s${N}\n" "$cpu_model"
        ((score++))
    else
        print_err "AES-NI پشتیبانی نمی‌شود"
        printf "        ${Y}توصیه: از ChaCha20-Poly1305 استفاده کنید${N}\n"
    fi
    echo ""
    
    # ═══════════ تست 2: OpenSSH Version ═══════════
    printf "  ${C}[2/5]${N} ${W}بررسی نسخه OpenSSH...${N}\n"
    sleep 0.5
    
    local ssh_version=$(ssh -V 2>&1 | grep -oP 'OpenSSH_\K[0-9]+\.[0-9]+' | head -1)
    if [[ -n "$ssh_version" ]]; then
        local major=$(echo "$ssh_version" | cut -d. -f1)
        local minor=$(echo "$ssh_version" | cut -d. -f2)
        
        # AES-GCM از OpenSSH 6.2 به بعد پشتیبانی می‌شود
        if [[ $major -gt 6 ]] || [[ $major -eq 6 && $minor -ge 2 ]]; then
            print_ok "OpenSSH $ssh_version (پشتیبانی از AES-GCM)"
            ((score++))
        else
            print_warn "OpenSSH $ssh_version (نسخه قدیمی - آپدیت کنید)"
        fi
    else
        print_err "OpenSSH یافت نشد"
    fi
    echo ""
    
    # ═══════════ تست 3: Cipher در SSH ═══════════
    printf "  ${C}[3/5]${N} ${W}بررسی Cipher های موجود...${N}\n"
    sleep 0.5
    
    local ciphers=$(ssh -Q cipher 2>/dev/null)
    if echo "$ciphers" | grep -q "aes128-gcm@openssh.com"; then
        print_ok "aes128-gcm@openssh.com موجود است"
        ((score++))
    else
        print_err "aes128-gcm@openssh.com موجود نیست"
    fi
    
    if echo "$ciphers" | grep -q "aes256-gcm@openssh.com"; then
        printf "        ${G}${ICO_OK}${N} aes256-gcm@openssh.com موجود است\n"
    fi
    
    if echo "$ciphers" | grep -q "chacha20-poly1305@openssh.com"; then
        printf "        ${G}${ICO_OK}${N} chacha20-poly1305@openssh.com موجود است\n"
    fi
    echo ""
    
    # ═══════════ تست 4: بنچمارک سرعت ═══════════
    printf "  ${C}[4/5]${N} ${W}تست سرعت رمزنگاری...${N}\n"
    sleep 0.5
    
    if command -v openssl &>/dev/null; then
        printf "        ${GR}در حال تست AES-128-GCM...${N}\n"
        
        local aes_speed=$(openssl speed -evp aes-128-gcm 2>&1 | grep "aes-128-gcm" | tail -1 | awk '{print $NF}')
        
        if [[ -n "$aes_speed" ]]; then
            # تبدیل به MB/s
            local speed_mb=$(echo "$aes_speed" | awk '{printf "%.0f", $1/1024/1024}')
            
            if [[ $speed_mb -gt 500 ]]; then
                print_ok "سرعت: ${speed_mb} MB/s (عالی)"
                ((score++))
            elif [[ $speed_mb -gt 200 ]]; then
                print_ok "سرعت: ${speed_mb} MB/s (خوب)"
                ((score++))
            else
                print_warn "سرعت: ${speed_mb} MB/s (قابل قبول)"
            fi
        else
            # تست جایگزین
            local start=$(date +%s%N)
            dd if=/dev/zero bs=1M count=100 2>/dev/null | openssl enc -aes-128-gcm -pass pass:test -pbkdf2 > /dev/null 2>&1
            local end=$(date +%s%N)
            local duration=$(( (end - start) / 1000000 ))
            
            if [[ $duration -lt 500 ]]; then
                print_ok "100MB در ${duration}ms (عالی)"
                ((score++))
            elif [[ $duration -lt 1000 ]]; then
                print_ok "100MB در ${duration}ms (خوب)"
                ((score++))
            else
                print_warn "100MB در ${duration}ms (کند)"
            fi
        fi
    else
        print_warn "OpenSSL برای تست سرعت یافت نشد"
    fi
    echo ""
    
    # ═══════════ تست 5: کرنل و BBR ═══════════
    printf "  ${C}[5/5]${N} ${W}بررسی بهینه‌سازی کرنل...${N}\n"
    sleep 0.5
    
    local kernel=$(uname -r)
    printf "        ${GR}Kernel: %s${N}\n" "$kernel"
    
    local cc=$(sysctl -n net.ipv4.tcp_congestion_control 2>/dev/null)
    if [[ "$cc" == "bbr" ]]; then
        print_ok "BBR فعال است"
        ((score++))
    else
        print_warn "BBR فعال نیست (فعلی: $cc)"
        printf "        ${Y}توصیه: BBR را فعال کنید برای عملکرد بهتر${N}\n"
    fi
    
    # ═══════════ نتیجه نهایی ═══════════
    echo ""
    line
    printf "    ${W}نتیجه نهایی${N}\n"
    line
    echo ""
    
    local percent=$((score * 100 / max_score))
    
    printf "    امتیاز: "
    if [[ $score -eq $max_score ]]; then
        printf "${G}${BOLD}%d/%d (100%%)${N} ${G}★★★★★${N}\n" "$score" "$max_score"
        printf "\n    ${G}${BOLD}✓ سرور شما کاملاً برای AES-128-GCM بهینه است!${N}\n"
    elif [[ $score -ge 4 ]]; then
        printf "${G}%d/%d (%d%%)${N} ${G}★★★★${N}${GR}☆${N}\n" "$score" "$max_score" "$percent"
        printf "\n    ${G}✓ سرور شما برای AES-128-GCM مناسب است${N}\n"
    elif [[ $score -ge 3 ]]; then
        printf "${Y}%d/%d (%d%%)${N} ${Y}★★★${N}${GR}☆☆${N}\n" "$score" "$max_score" "$percent"
        printf "\n    ${Y}! سرور قابل استفاده است اما بهینه نیست${N}\n"
    else
        printf "${R}%d/%d (%d%%)${N} ${R}★★${N}${GR}☆☆☆${N}\n" "$score" "$max_score" "$percent"
        printf "\n    ${R}✗ توصیه می‌شود از ChaCha20-Poly1305 استفاده کنید${N}\n"
    fi
    
    echo ""
    
    # جدول خلاصه
    printf "    ${C}┌─────────────────────────────────────┐${N}\n"
    printf "    ${C}│${N} %-20s %s ${C}│${N}\n" "AES-NI" "$(grep -q 'aes' /proc/cpuinfo && echo "${G}پشتیبانی می‌شود${N}" || echo "${R}پشتیبانی نمی‌شود${N}")"
    printf "    ${C}│${N} %-20s %s ${C}│${N}\n" "Cipher" "${G}aes128-gcm${N}"
    printf "    ${C}│${N} %-20s %s ${C}│${N}\n" "BBR" "$([ "$cc" == "bbr" ] && echo "${G}فعال${N}" || echo "${Y}غیرفعال${N}")"
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
    local total_steps=6
    
    # ═══════════ مرحله 1: نصب پکیج‌ها ═══════════
    ((step++))
    printf "  ${C}[%d/%d]${N} ${W}نصب پکیج‌ها...${N}\n" "$step" "$total_steps"
    
    install_packages
    echo ""
    
    # ═══════════ مرحله 2: ایجاد کاربر تانل ═══════════
    ((step++))
    printf "  ${C}[%d/%d]${N} ${W}ایجاد کاربر تانل...${N}\n" "$step" "$total_steps"
    
    if ! id "$TUNNEL_USER" &>/dev/null; then
        useradd -r -m -s /bin/bash "$TUNNEL_USER" 2>/dev/null
        print_ok "کاربر '$TUNNEL_USER' ایجاد شد"
    else
        print_info "کاربر '$TUNNEL_USER' از قبل موجود است"
    fi
    
    # تنظیم پسورد
    echo ""
    printf "    ${Y}پسورد جدید برای کاربر '%s' تنظیم کنید:${N}\n" "$TUNNEL_USER"
    passwd "$TUNNEL_USER"
    echo ""
    
    # ایجاد دایرکتوری SSH برای کاربر
    local user_ssh="/home/$TUNNEL_USER/.ssh"
    mkdir -p "$user_ssh"
    touch "$user_ssh/authorized_keys"
    chmod 700 "$user_ssh"
    chmod 600 "$user_ssh/authorized_keys"
    chown -R "$TUNNEL_USER:$TUNNEL_USER" "$user_ssh"
    
    print_ok "دایرکتوری SSH کاربر آماده شد"
    echo ""
    
    # ═══════════ مرحله 3: پیکربندی SSH ═══════════
    ((step++))
    printf "  ${C}[%d/%d]${N} ${W}پیکربندی SSH...${N}\n" "$step" "$total_steps"
    
    # بکاپ
    local backup_file="$BACKUP_DIR/sshd_config.$(date +%Y%m%d_%H%M%S)"
    cp /etc/ssh/sshd_config "$backup_file" 2>/dev/null
    print_info "بکاپ: $backup_file"
    
    # ایجاد کانفیگ سفارشی
    cat > /etc/ssh/sshd_config.d/sshsaeed.conf << 'SSHCONF'
# ═══════════════════════════════════════════════════════════════
#  SSHSaeed Optimized Configuration
#  Only AES-128-GCM Cipher
# ═══════════════════════════════════════════════════════════════

# پورت‌ها
Port 22
Port 443

# تنظیمات تانل
GatewayPorts yes
AllowTcpForwarding yes
PermitTunnel yes
PermitOpen any

# Keep-Alive
TCPKeepAlive yes
ClientAliveInterval 30
ClientAliveCountMax 3

# عملکرد
MaxSessions 20
MaxStartups 10:30:60
UseDNS no
Compression no

# امنیت - فقط AES-GCM
Ciphers aes128-gcm@openssh.com,aes256-gcm@openssh.com
MACs hmac-sha2-256-etm@openssh.com,hmac-sha2-512-etm@openssh.com
KexAlgorithms curve25519-sha256,curve25519-sha256@libssh.org

# لاگ
LogLevel INFO
SSHCONF

    print_ok "کانفیگ SSH بهینه اعمال شد"
    
    # ری‌استارت SSH
    systemctl restart sshd
    if systemctl is-active --quiet sshd; then
        print_ok "SSH ری‌استارت شد"
    else
        print_err "خطا در ری‌استارت SSH"
        journalctl -u sshd --no-pager -n 5
    fi
    echo ""
    
    # ═══════════ مرحله 4: فایروال ═══════════
    ((step++))
    printf "  ${C}[%d/%d]${N} ${W}تنظیم فایروال...${N}\n" "$step" "$total_steps"
    
    if command -v ufw &>/dev/null; then
        ufw allow 22/tcp &>/dev/null
        ufw allow 443/tcp &>/dev/null
        print_ok "UFW: پورت 22 و 443 باز شد"
    elif command -v firewall-cmd &>/dev/null; then
        firewall-cmd --permanent --add-port=22/tcp &>/dev/null
        firewall-cmd --permanent --add-port=443/tcp &>/dev/null
        firewall-cmd --reload &>/dev/null
        print_ok "Firewalld: پورت 22 و 443 باز شد"
    else
        print_info "فایروال فعالی یافت نشد"
    fi
    echo ""
    
    # ═══════════ مرحله 5: بهینه‌سازی کرنل ═══════════
    ((step++))
    printf "  ${C}[%d/%d]${N} ${W}بهینه‌سازی کرنل (BBR)...${N}\n" "$step" "$total_steps"
    
    # فعال‌سازی BBR
    if ! grep -q "net.core.default_qdisc=fq" /etc/sysctl.conf 2>/dev/null; then
        cat >> /etc/sysctl.conf << 'SYSCTL'

# SSHSaeed BBR Optimization
net.core.default_qdisc=fq
net.ipv4.tcp_congestion_control=bbr
net.ipv4.tcp_fastopen=3
net.core.rmem_max=16777216
net.core.wmem_max=16777216
net.ipv4.tcp_rmem=4096 87380 16777216
net.ipv4.tcp_wmem=4096 65536 16777216
SYSCTL
        sysctl -p &>/dev/null
    fi
    
    local cc=$(sysctl -n net.ipv4.tcp_congestion_control 2>/dev/null)
    if [[ "$cc" == "bbr" ]]; then
        print_ok "BBR فعال است"
    else
        print_warn "BBR فعال نشد (نیاز به ریبوت)"
    fi
    echo ""
    
    # ═══════════ مرحله 6: ذخیره تنظیمات ═══════════
    ((step++))
    printf "  ${C}[%d/%d]${N} ${W}ذخیره تنظیمات...${N}\n" "$step" "$total_steps"
    
    SERVER_TYPE="kharej"
    KHAREJ_IP=$(get_local_ip)
    KHAREJ_SSH_PORT=443
    save_config
    
    print_ok "تنظیمات ذخیره شد"
    
    # ═══════════ نتیجه نهایی ═══════════
    echo ""
    line
    printf "    ${G}✓ سرور خارج با موفقیت پیکربندی شد${N}\n"
    line
    echo ""
    
    printf "    ${C}┌─────────────────────────────────────────┐${N}\n"
    printf "    ${C}│${N}  ${W}اطلاعات سرور خارج${N}                     ${C}│${N}\n"
    printf "    ${C}├─────────────────────────────────────────┤${N}\n"
    printf "    ${C}│${N}  IP:        ${G}%-25s${N} ${C}│${N}\n" "$KHAREJ_IP"
    printf "    ${C}│${N}  SSH Port:  ${G}%-25s${N} ${C}│${N}\n" "22, 443"
    printf "    ${C}│${N}  User:      ${G}%-25s${N} ${C}│${N}\n" "$TUNNEL_USER"
    printf "    ${C}│${N}  Cipher:    ${G}%-25s${N} ${C}│${N}\n" "AES-128-GCM"
    printf "    ${C}│${N}  BBR:       ${G}%-25s${N} ${C}│${N}\n" "$cc"
    printf "    ${C}└─────────────────────────────────────────┘${N}\n"
    
    echo ""
    printf "    ${Y}این اطلاعات را برای تنظیم سرور ایران نگه دارید${N}\n"
    echo ""
    
    log "INFO" "Kharej server configured: $KHAREJ_IP"
    
    read -p "$(printf "    ${C}Enter برای بازگشت...${N}")"
}

# ═══════════════════════════════════════════════════════════════════════════════
#                گزینه 3: راه‌اندازی کامل خودکار سرور ایران
# ═══════════════════════════════════════════════════════════════════════════════
setup_iran_automatic() {
    show_banner
    line
    printf "    ${W}راه‌اندازی کامل خودکار سرور ایران${N}\n"
    line
    echo ""
    
    printf "    ${Y}این گزینه به صورت خودکار همه موارد زیر را انجام می‌دهد:${N}\n"
    printf "    ${GR}─────────────────────────────────────────────────────${N}\n"
    printf "    ${C}○${N} نصب پکیج‌ها\n"
    printf "    ${C}○${N} SSH Key بدون پسورد\n"
    printf "    ${C}○${N} ۳ تانل SSH با AES-128-GCM\n"
    printf "    ${C}○${N} AutoSSH برای اتصال مجدد خودکار\n"
    printf "    ${C}○${N} HAProxy برای Load Balancing\n"
    printf "    ${C}○${N} بهینه‌سازی کرنل (BBR)\n"
    printf "    ${C}○${N} تست تمام تانل‌ها\n"
    printf "    ${C}○${N} تست HAProxy\n"
    printf "    ${GR}─────────────────────────────────────────────────────${N}\n"
    echo ""
    
    # ═══════════ دریافت اطلاعات ═══════════
    line_thin
    printf "    ${W}اطلاعات سرور خارج را وارد کنید:${N}\n"
    line_thin
    echo ""
    
    read -p "$(printf "    ${C}IP سرور خارج: ${N}")" KHAREJ_IP
    
    if [[ -z "$KHAREJ_IP" ]]; then
        print_err "IP سرور خارج الزامی است"
        sleep 2
        return 1
    fi
    
    # اعتبارسنجی IP
    if ! [[ "$KHAREJ_IP" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
        print_err "فرمت IP نامعتبر است"
        sleep 2
        return 1
    fi
    
    read -p "$(printf "    ${C}رمز root سرور خارج: ${N}")" -s KHAREJ_PASS
    echo ""
    
    if [[ -z "$KHAREJ_PASS" ]]; then
        print_err "رمز سرور خارج الزامی است"
        sleep 2
        return 1
    fi
    
    read -p "$(printf "    ${C}پورت SSH سرور خارج (پیش‌فرض: 22): ${N}")" -e -i "22" KHAREJ_SSH_PORT
    KHAREJ_SSH_PORT=${KHAREJ_SSH_PORT:-22}
    
    read -p "$(printf "    ${C}پورت HAProxy (پیش‌فرض: %s): ${N}")" -e -i "$HAPROXY_PORT" hp
    HAPROXY_PORT=${hp:-$HAPROXY_PORT}
    
    read -p "$(printf "    ${C}پورت مقصد روی سرور خارج (پیش‌فرض: 443): ${N}")" -e -i "443" TARGET_PORT
    TARGET_PORT=${TARGET_PORT:-443}
    
    echo ""
    printf "    ${Y}شروع راه‌اندازی با اطلاعات زیر:${N}\n"
    printf "    ${GR}───────────────────────────────────${N}\n"
    printf "    IP خارج:      %s\n" "$KHAREJ_IP"
    printf "    پورت SSH:     %s\n" "$KHAREJ_SSH_PORT"
    printf "    HAProxy:      %s\n" "$HAPROXY_PORT"
    printf "    مقصد:         %s\n" "$TARGET_PORT"
    printf "    ${GR}───────────────────────────────────${N}\n"
    echo ""
    
    read -p "$(printf "    ${Y}ادامه می‌دهید? [y/N]: ${N}")" confirm
    [[ ! "$confirm" =~ ^[Yy]$ ]] && return
    
    clear
    show_banner
    line
    printf "    ${W}در حال راه‌اندازی...${N}\n"
    line
    echo ""
    
    local step=0
    local total_steps=8
    local errors=0
    
    # ═══════════ [1] نصب پکیج‌ها ═══════════
    ((step++))
    printf "  ${C}[%d/%d]${N} نصب پکیج‌ها...\n" "$step" "$total_steps"
    
    if install_packages; then
        printf "\r  ${G}[%d/%d]${N} ${G}✓${N} نصب پکیج‌ها\n" "$step" "$total_steps"
    else
        printf "\r  ${R}[%d/%d]${N} ${R}✗${N} نصب پکیج‌ها\n" "$step" "$total_steps"
        ((errors++))
    fi
    echo ""
    
    # ═══════════ [2] ایجاد SSH Key ═══════════
    ((step++))
    printf "  ${C}[%d/%d]${N} ایجاد SSH Key بدون پسورد...\n" "$step" "$total_steps"
    
    if [[ -f "$KEY_FILE" ]]; then
        rm -f "$KEY_FILE" "${KEY_FILE}.pub"
    fi
    
    if ssh-keygen -t ed25519 -f "$KEY_FILE" -N "" -C "sshsaeed@iran" -q; then
        chmod 600 "$KEY_FILE"
        printf "\r  ${G}[%d/%d]${N} ${G}✓${N} ایجاد SSH Key (ED25519)\n" "$step" "$total_steps"
    else
        printf "\r  ${R}[%d/%d]${N} ${R}✗${N} ایجاد SSH Key\n" "$step" "$total_steps"
        ((errors++))
    fi
    echo ""
    
    # ═══════════ [3] کپی کلید به سرور خارج ═══════════
    ((step++))
    printf "  ${C}[%d/%d]${N} کپی کلید به سرور خارج...\n" "$step" "$total_steps"
    
    # استفاده از sshpass برای کپی خودکار کلید
    if sshpass -p "$KHAREJ_PASS" ssh-copy-id -i "${KEY_FILE}.pub" \
        -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null \
        -p "$KHAREJ_SSH_PORT" "root@${KHAREJ_IP}" &>/dev/null; then
        printf "\r  ${G}[%d/%d]${N} ${G}✓${N} کپی کلید به سرور خارج\n" "$step" "$total_steps"
    else
        # تلاش با پورت 443
        if sshpass -p "$KHAREJ_PASS" ssh-copy-id -i "${KEY_FILE}.pub" \
            -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null \
            -p 443 "root@${KHAREJ_IP}" &>/dev/null; then
            printf "\r  ${G}[%d/%d]${N} ${G}✓${N} کپی کلید به سرور خارج (پورت 443)\n" "$step" "$total_steps"
            KHAREJ_SSH_PORT=443
        else
            printf "\r  ${R}[%d/%d]${N} ${R}✗${N} کپی کلید به سرور خارج\n" "$step" "$total_steps"
            print_err "نمی‌توان به سرور خارج متصل شد. IP و رمز را بررسی کنید."
            ((errors++))
        fi
    fi
    echo ""
    
    # ═══════════ [4] تست اتصال SSH ═══════════
    ((step++))
    printf "  ${C}[%d/%d]${N} تست اتصال SSH...\n" "$step" "$total_steps"
    
    if ssh -o BatchMode=yes -o ConnectTimeout=10 -o StrictHostKeyChecking=no \
       -i "$KEY_FILE" -p "$KHAREJ_SSH_PORT" "root@${KHAREJ_IP}" "echo OK" &>/dev/null; then
        printf "\r  ${G}[%d/%d]${N} ${G}✓${N} تست اتصال SSH\n" "$step" "$total_steps"
    else
        printf "\r  ${R}[%d/%d]${N} ${R}✗${N} تست اتصال SSH\n" "$step" "$total_steps"
        ((errors++))
    fi
    echo ""
    
    # ═══════════ [5] ایجاد 3 تانل با AutoSSH ═══════════
    ((step++))
    printf "  ${C}[%d/%d]${N} ایجاد ۳ تانل SSH با AutoSSH...\n" "$step" "$total_steps"
    
    # توقف سرویس‌های قبلی
    for i in 1 2 3; do
        systemctl stop "sshsaeed-tunnel${i}" &>/dev/null
        systemctl disable "sshsaeed-tunnel${i}" &>/dev/null
    done
    
    for tunnel_num in 1 2 3; do
        local service_name="sshsaeed-tunnel${tunnel_num}"
        local local_port=$((2000 + tunnel_num))
        
        # ایجاد سرویس systemd
        cat > "/etc/systemd/system/${service_name}.service" << EOF
[Unit]
Description=SSHSaeed Tunnel ${tunnel_num} - Local:${local_port} -> Remote:${TARGET_PORT}
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
Environment="AUTOSSH_GATETIME=0"
Environment="AUTOSSH_POLL=60"
Environment="AUTOSSH_LOGFILE=/var/log/${service_name}.log"
ExecStart=/usr/bin/autossh -M 0 -N \\
    -o "ServerAliveInterval=30" \\
    -o "ServerAliveCountMax=3" \\
    -o "ExitOnForwardFailure=yes" \\
    -o "StrictHostKeyChecking=no" \\
    -o "UserKnownHostsFile=/dev/null" \\
    -o "Ciphers=${CIPHER}" \\
    -o "Compression=no" \\
    -i ${KEY_FILE} \\
    -p ${KHAREJ_SSH_PORT} \\
    -L ${local_port}:127.0.0.1:${TARGET_PORT} \\
    root@${KHAREJ_IP}
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF
        
        systemctl daemon-reload
        systemctl enable "$service_name" &>/dev/null
        systemctl restart "$service_name"
        
        printf "        ${GR}تانل %d: localhost:%d → %s:%s${N}\n" "$tunnel_num" "$local_port" "$KHAREJ_IP" "$TARGET_PORT"
    done
    
    sleep 3
    
    local active_tunnels=0
    for i in 1 2 3; do
        if systemctl is-active --quiet "sshsaeed-tunnel${i}"; then
            ((active_tunnels++))
        fi
    done
    
    if [[ $active_tunnels -eq 3 ]]; then
        printf "\r  ${G}[%d/%d]${N} ${G}✓${N} ایجاد ۳ تانل SSH (همه فعال)\n" "$step" "$total_steps"
    else
        printf "\r  ${Y}[%d/%d]${N} ${Y}!${N} تانل‌ها: %d/3 فعال\n" "$step" "$total_steps" "$active_tunnels"
    fi
    echo ""
    
    # ═══════════ [6] تنظیم HAProxy ═══════════
    ((step++))
    printf "  ${C}[%d/%d]${N} تنظیم HAProxy...\n" "$step" "$total_steps"
    
    # بکاپ
    [[ -f /etc/haproxy/haproxy.cfg ]] && \
        cp /etc/haproxy/haproxy.cfg "$BACKUP_DIR/haproxy.cfg.$(date +%Y%m%d_%H%M%S)"
    
    # ایجاد دایرکتوری برای socket
    mkdir -p /run/haproxy
    
    # ایجاد کانفیگ HAProxy
    cat > /etc/haproxy/haproxy.cfg << EOF
# ═══════════════════════════════════════════════════════════════
#  HAProxy Configuration - SSHSaeed v${VERSION}
#  Auto-generated: $(date)
# ═══════════════════════════════════════════════════════════════

global
    log /dev/log local0
    log /dev/log local1 notice
    chroot /var/lib/haproxy
    stats socket /run/haproxy/admin.sock mode 660 level admin expose-fd listeners
    stats timeout 30s
    user haproxy
    group haproxy
    daemon
    maxconn 4096

defaults
    log     global
    mode    tcp
    option  tcplog
    option  dontlognull
    timeout connect 10s
    timeout client  300s
    timeout server  300s
    retries 3

# ─────────────── Frontend ───────────────
frontend ft_main
    bind *:${HAPROXY_PORT}
    default_backend bk_tunnels
    
    # لاگ اتصالات
    option tcplog

# ─────────────── Backend ───────────────
backend bk_tunnels
    balance roundrobin
    option tcp-check
    
    # تانل‌ها با Health Check
    server tunnel1 127.0.0.1:2001 check inter 10s fall 3 rise 2 weight 100
    server tunnel2 127.0.0.1:2002 check inter 10s fall 3 rise 2 weight 100
    server tunnel3 127.0.0.1:2003 check inter 10s fall 3 rise 2 weight 100

# ─────────────── Stats ───────────────
listen stats
    bind *:8404
    mode http
    stats enable
    stats hide-version
    stats uri /stats
    stats refresh 10s
    stats realm HAProxy\ Stats
    stats admin if LOCALHOST
EOF

    # تست و راه‌اندازی HAProxy
    if haproxy -c -f /etc/haproxy/haproxy.cfg &>/dev/null; then
        systemctl enable haproxy &>/dev/null
        systemctl restart haproxy
        
        sleep 2
        
        if systemctl is-active --quiet haproxy; then
            printf "\r  ${G}[%d/%d]${N} ${G}✓${N} تنظیم HAProxy (پورت %s)\n" "$step" "$total_steps" "$HAPROXY_PORT"
        else
            printf "\r  ${R}[%d/%d]${N} ${R}✗${N} HAProxy فعال نشد\n" "$step" "$total_steps"
            ((errors++))
        fi
    else
        printf "\r  ${R}[%d/%d]${N} ${R}✗${N} خطا در کانفیگ HAProxy\n" "$step" "$total_steps"
        ((errors++))
    fi
    echo ""
    
    # ═══════════ [7] بهینه‌سازی کرنل (BBR) ═══════════
    ((step++))
    printf "  ${C}[%d/%d]${N} بهینه‌سازی کرنل (BBR)...\n" "$step" "$total_steps"
    
    if ! grep -q "net.core.default_qdisc=fq" /etc/sysctl.conf 2>/dev/null; then
        cat >> /etc/sysctl.conf << 'SYSCTL'

# SSHSaeed BBR Optimization
net.core.default_qdisc=fq
net.ipv4.tcp_congestion_control=bbr
net.ipv4.tcp_fastopen=3
net.core.rmem_max=16777216
net.core.wmem_max=16777216
SYSCTL
        sysctl -p &>/dev/null
    fi
    
    local cc=$(sysctl -n net.ipv4.tcp_congestion_control 2>/dev/null)
    if [[ "$cc" == "bbr" ]]; then
        printf "\r  ${G}[%d/%d]${N} ${G}✓${N} بهینه‌سازی کرنل (BBR فعال)\n" "$step" "$total_steps"
    else
        printf "\r  ${Y}[%d/%d]${N} ${Y}!${N} BBR فعال نشد (نیاز به ریبوت)\n" "$step" "$total_steps"
    fi
    echo ""
    
    # ═══════════ [8] تست نهایی ═══════════
    ((step++))
    printf "  ${C}[%d/%d]${N} تست نهایی...\n" "$step" "$total_steps"
    
    sleep 3
    
    # تست تانل‌ها
    local tunnels_ok=0
    for port in 2001 2002 2003; do
        if timeout 3 bash -c "echo >/dev/tcp/127.0.0.1/$port" 2>/dev/null; then
            ((tunnels_ok++))
        fi
    done
    
    # تست HAProxy
    local haproxy_ok=0
    if timeout 3 bash -c "echo >/dev/tcp/127.0.0.1/$HAPROXY_PORT" 2>/dev/null; then
        haproxy_ok=1
    fi
    
    printf "\r  ${G}[%d/%d]${N} ${G}✓${N} تست نهایی کامل شد\n" "$step" "$total_steps"
    
    # ═══════════ ذخیره تنظیمات ═══════════
    SERVER_TYPE="iran"
    save_config
    
    # پاک کردن پسورد از حافظه
    unset KHAREJ_PASS
    
    # ═══════════ نتیجه نهایی ═══════════
    echo ""
    line
    if [[ $errors -eq 0 ]]; then
        printf "    ${G}${BOLD}✓ راه‌اندازی با موفقیت کامل شد!${N}\n"
    else
        printf "    ${Y}${BOLD}! راه‌اندازی با %d خطا کامل شد${N}\n" "$errors"
    fi
    line
    echo ""
    
    # چک‌لیست نهایی
    printf "    ${W}چک‌لیست:${N}\n"
    echo ""
    
    printf "    "
    [[ -f "$KEY_FILE" ]] && printf "${G}[✓]${N}" || printf "${R}[✗]${N}"
    printf " SSH Key بدون پسورد\n"
    
    printf "    "
    [[ $active_tunnels -eq 3 ]] && printf "${G}[✓]${N}" || printf "${Y}[!]${N}"
    printf " ۳ تانل SSH با AES-128-GCM (%d/3)\n" "$active_tunnels"
    
    printf "    "
    printf "${G}[✓]${N}"
    printf " AutoSSH برای اتصال مجدد خودکار\n"
    
    printf "    "
    [[ $haproxy_ok -eq 1 ]] && printf "${G}[✓]${N}" || printf "${R}[✗]${N}"
    printf " HAProxy برای Load Balancing\n"
    
    printf "    "
    [[ "$cc" == "bbr" ]] && printf "${G}[✓]${N}" || printf "${Y}[!]${N}"
    printf " بهینه‌سازی کرنل (BBR)\n"
    
    printf "    "
    [[ $tunnels_ok -eq 3 ]] && printf "${G}[✓]${N}" || printf "${Y}[!]${N}"
    printf " تست تمام تانل‌ها (%d/3)\n" "$tunnels_ok"
    
    printf "    "
    [[ $haproxy_ok -eq 1 ]] && printf "${G}[✓]${N}" || printf "${R}[✗]${N}"
    printf " تست HAProxy\n"
    
    echo ""
    
    # اطلاعات اتصال
    local local_ip=$(get_local_ip)
    printf "    ${C}┌─────────────────────────────────────────────────┐${N}\n"
    printf "    ${C}│${N}  ${W}اطلاعات اتصال${N}                                 ${C}│${N}\n"
    printf "    ${C}├─────────────────────────────────────────────────┤${N}\n"
    printf "    ${C}│${N}  آدرس:     ${G}%-35s${N} ${C}│${N}\n" "${local_ip}:${HAPROXY_PORT}"
    printf "    ${C}│${N}  پروتکل:   ${G}%-35s${N} ${C}│${N}\n" "TCP (برای کلاینت‌ها)"
    printf "    ${C}│${N}  آمار:     ${G}%-35s${N} ${C}│${N}\n" "http://${local_ip}:8404/stats"
    printf "    ${C}└─────────────────────────────────────────────────┘${N}\n"
    
    echo ""
    log "INFO" "Iran server fully configured - Tunnels: $active_tunnels/3, HAProxy: $haproxy_ok"
    
    read -p "$(printf "    ${C}Enter برای بازگشت...${N}")"
}
# ═══════════════════════════════════════════════════════════════════════════════
#                      گزینه 4: تست گرافیکی تانل‌ها
# ═══════════════════════════════════════════════════════════════════════════════
test_tunnels_graphical() {
    show_banner
    line
    printf "    ${W}تست گرافیکی تانل‌ها و HAProxy${N}\n"
    line
    echo ""
    
    load_config
    
    printf "    ${C}در حال تست...${N}\n"
    echo ""
    
    # تست تانل‌ها
    printf "    ${W}وضعیت تانل‌ها:${N}\n"
    printf "    ${GR}─────────────────────────────────────────${N}\n"
    
    local total_ok=0
    
    for i in 1 2 3; do
        local port=$((2000 + i))
        local service="sshsaeed-tunnel${i}"
        
        printf "    "
        
        # وضعیت سرویس
        if systemctl is-active --quiet "$service"; then
            printf "${G}●${N} "
        else
            printf "${R}○${N} "
        fi
        
        # وضعیت پورت
        if timeout 2 bash -c "echo >/dev/tcp/127.0.0.1/$port" 2>/dev/null; then
            printf "${G}[UP]${N}   "
            ((total_ok++))
        else
            printf "${R}[DOWN]${N} "
        fi
        
        printf "تانل %d (پورت %d)\n" "$i" "$port"
    done
    
    echo ""
    printf "    ${W}وضعیت HAProxy:${N}\n"
    printf "    ${GR}─────────────────────────────────────────${N}\n"
    
    printf "    "
    if systemctl is-active --quiet haproxy; then
        printf "${G}●${N} "
    else
        printf "${R}○${N} "
    fi
    
    if timeout 2 bash -c "echo >/dev/tcp/127.0.0.1/${HAPROXY_PORT:-443}" 2>/dev/null; then
        printf "${G}[UP]${N}   "
    else
        printf "${R}[DOWN]${N} "
    fi
    printf "HAProxy (پورت %s)\n" "${HAPROXY_PORT:-443}"
    
    printf "    "
    if timeout 2 bash -c "echo >/dev/tcp/127.0.0.1/8404" 2>/dev/null; then
        printf "${G}●${N} ${G}[UP]${N}   صفحه آمار (پورت 8404)\n"
    else
        printf "${R}○${N} ${R}[DOWN]${N} صفحه آمار (پورت 8404)\n"
    fi
    
    echo ""
    
    # نمودار گرافیکی
    printf "    ${W}نمودار اتصال:${N}\n"
    printf "    ${GR}─────────────────────────────────────────${N}\n"
    echo ""
    
    local local_ip=$(get_local_ip)
    
    printf "    ${C}┌─────────────────────────────────────────────────────────┐${N}\n"
    printf "    ${C}│${N}                                                         ${C}│${N}\n"
    printf "    ${C}│${N}   ${W}کلاینت‌ها${N}                                            ${C}│${N}\n"
    printf "    ${C}│${N}       │                                                  ${C}│${N}\n"
    printf "    ${C}│${N}       ▼                                                  ${C}│${N}\n"
    printf "    ${C}│${N}   ${Y}┌───────────┐${N}                                        ${C}│${N}\n"
    printf "    ${C}│${N}   ${Y}│${N} HAProxy   ${Y}│${N} ◄── پورت %-5s                       ${C}│${N}\n" "${HAPROXY_PORT:-443}"
    printf "    ${C}│${N}   ${Y}└─────┬─────┘${N}                                        ${C}│${N}\n"
    printf "    ${C}│${N}         │                                                ${C}│${N}\n"
    printf "    ${C}│${N}    ┌────┼────┐                                           ${C}│${N}\n"
    printf "    ${C}│${N}    │    │    │                                           ${C}│${N}\n"
    printf "    ${C}│${N}    ▼    ▼    ▼                                           ${C}│${N}\n"
    
    # نمایش تانل‌ها
    local t1_status=$(timeout 1 bash -c "echo >/dev/tcp/127.0.0.1/2001" 2>/dev/null && echo "G" || echo "R")
    local t2_status=$(timeout 1 bash -c "echo >/dev/tcp/127.0.0.1/2002" 2>/dev/null && echo "G" || echo "R")
    local t3_status=$(timeout 1 bash -c "echo >/dev/tcp/127.0.0.1/2003" 2>/dev/null && echo "G" || echo "R")
    
    local c1="${G}" && [[ "$t1_status" == "R" ]] && c1="${R}"
    local c2="${G}" && [[ "$t2_status" == "R" ]] && c2="${R}"
    local c3="${G}" && [[ "$t3_status" == "R" ]] && c3="${R}"
    
    printf "    ${C}│${N}  ${c1}[T1]${N}  ${c2}[T2]${N}  ${c3}[T3]${N}                                      ${C}│${N}\n"
    printf "    ${C}│${N}  2001  2002  2003                                        ${C}│${N}\n"
    printf "    ${C}│${N}    │    │    │                                           ${C}│${N}\n"
    printf "    ${C}│${N}    └────┴────┘                                           ${C}│${N}\n"
    printf "    ${C}│${N}         │                                                ${C}│${N}\n"
    printf "    ${C}│${N}         ▼                                                ${C}│${N}\n"
    printf "    ${C}│${N}   ${M}┌───────────┐${N}                                        ${C}│${N}\n"
    printf "    ${C}│${N}   ${M}│${N}  سرور    ${M}│${N} ◄── %s:${TARGET_PORT:-443}                ${C}│${N}\n" "${KHAREJ_IP:-N/A}"
    printf "    ${C}│${N}   ${M}│${N}  خارج    ${M}│${N}                                        ${C}│${N}\n"
    printf "    ${C}│${N}   ${M}└───────────┘${N}                                        ${C}│${N}\n"
    printf "    ${C}│${N}                                                         ${C}│${N}\n"
    printf "    ${C}└─────────────────────────────────────────────────────────┘${N}\n"
    
    echo ""
    
    # خلاصه
    printf "    ${W}خلاصه:${N}\n"
    printf "    ─────\n"
    printf "    تانل‌های فعال: ${G}%d${N}/3\n" "$total_ok"
    printf "    Cipher: ${C}%s${N}\n" "$CIPHER"
    printf "    Load Balancing: ${Y}Round Robin${N}\n"
    
    echo ""
    log "INFO" "Graphical test completed - Active tunnels: $total_ok/3"
    
    read -p "$(printf "    ${C}Enter برای بازگشت...${N}")"
}

# ═══════════════════════════════════════════════════════════════════════════════
#                      گزینه 5: تغییر IP خارج
# ═══════════════════════════════════════════════════════════════════════════════
change_kharej_ip() {
    show_banner
    line
    printf "    ${W}تغییر IP سرور خارج${N}\n"
    line
    echo ""
    
    if ! load_config; then
        print_err "ابتدا سرور ایران را راه‌اندازی کنید (گزینه 3)"
        sleep 2
        return 1
    fi
    
    printf "    ${Y}اطلاعات فعلی:${N}\n"
    printf "    ${GR}─────────────────────────────────────${N}\n"
    printf "    IP فعلی خارج:  %s\n" "$KHAREJ_IP"
    printf "    پورت SSH:      %s\n" "${KHAREJ_SSH_PORT:-22}"
    printf "    ${GR}─────────────────────────────────────${N}\n"
    echo ""
    
    read -p "$(printf "    ${C}IP جدید سرور خارج: ${N}")" NEW_KHAREJ_IP
    
    if [[ -z "$NEW_KHAREJ_IP" ]]; then
        print_err "IP الزامی است"
        sleep 2
        return 1
    fi
    
    # اعتبارسنجی IP
    if ! [[ "$NEW_KHAREJ_IP" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
        print_err "فرمت IP نامعتبر است"
        sleep 2
        return 1
    fi
    
    read -p "$(printf "    ${C}رمز root سرور خارج جدید: ${N}")" -s KHAREJ_PASS
    echo ""
    
    if [[ -z "$KHAREJ_PASS" ]]; then
        print_err "رمز سرور الزامی است"
        sleep 2
        return 1
    fi
    
    read -p "$(printf "    ${C}پورت SSH (پیش‌فرض: %s): ${N}")" -e -i "${KHAREJ_SSH_PORT:-22}" new_port
    KHAREJ_SSH_PORT=${new_port:-${KHAREJ_SSH_PORT:-22}}
    
    echo ""
    printf "    ${Y}در حال به‌روزرسانی...${N}\n"
    echo ""
    
    local errors=0
    
    # ═══════════ 1. کپی کلید به سرور جدید ═══════════
    print_info "کپی کلید SSH به سرور جدید..."
    
    if sshpass -p "$KHAREJ_PASS" ssh-copy-id -i "${KEY_FILE}.pub" \
        -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null \
        -p "$KHAREJ_SSH_PORT" "root@${NEW_KHAREJ_IP}" &>/dev/null; then
        print_ok "کلید با موفقیت کپی شد"
    else
        print_err "خطا در کپی کلید"
        ((errors++))
    fi
    
    # ═══════════ 2. تست اتصال ═══════════
    print_info "تست اتصال SSH..."
    
    if ssh -o BatchMode=yes -o ConnectTimeout=10 -o StrictHostKeyChecking=no \
       -i "$KEY_FILE" -p "$KHAREJ_SSH_PORT" "root@${NEW_KHAREJ_IP}" "echo OK" &>/dev/null; then
        print_ok "اتصال SSH برقرار است"
    else
        print_err "خطا در اتصال SSH"
        ((errors++))
    fi
    
    # ═══════════ 3. به‌روزرسانی سرویس‌های تانل ═══════════
    print_info "به‌روزرسانی سرویس‌های تانل..."
    
    # به‌روزرسانی IP در فایل‌های سرویس
    for i in 1 2 3; do
        local service_file="/etc/systemd/system/sshsaeed-tunnel${i}.service"
        if [[ -f "$service_file" ]]; then
            sed -i "s/${KHAREJ_IP}/${NEW_KHAREJ_IP}/g" "$service_file"
            sed -i "s/-p [0-9]*/-p ${KHAREJ_SSH_PORT}/g" "$service_file"
        fi
    done
    
    systemctl daemon-reload
    
    # ری‌استارت تانل‌ها
    for i in 1 2 3; do
        systemctl restart "sshsaeed-tunnel${i}"
    done
    
    sleep 3
    
    local active=0
    for i in 1 2 3; do
        systemctl is-active --quiet "sshsaeed-tunnel${i}" && ((active++))
    done
    
    if [[ $active -eq 3 ]]; then
        print_ok "تمام تانل‌ها فعال شدند"
    else
        print_warn "تانل‌های فعال: $active/3"
    fi
    
    # ═══════════ 4. به‌روزرسانی کانفیگ ═══════════
    KHAREJ_IP="$NEW_KHAREJ_IP"
    save_config
    
    print_ok "تنظیمات ذخیره شد"
    
    # پاک کردن پسورد
    unset KHAREJ_PASS
    
    echo ""
    if [[ $errors -eq 0 ]]; then
        print_ok "IP خارج با موفقیت تغییر کرد"
    else
        print_warn "تغییر IP با $errors خطا انجام شد"
    fi
    
    echo ""
    printf "    ${C}IP جدید: ${G}%s${N}\n" "$KHAREJ_IP"
    
    log "INFO" "Kharej IP changed to: $KHAREJ_IP"
    
    echo ""
    read -p "$(printf "    ${C}Enter برای بازگشت...${N}")"
}

# ═══════════════════════════════════════════════════════════════════════════════
#                           حذف کامل
# ═══════════════════════════════════════════════════════════════════════════════
uninstall_all() {
    show_banner
    line
    printf "    ${R}${BOLD}حذف کامل SSHSaeed${N}\n"
    line
    echo ""
    
    printf "    ${Y}این عملیات موارد زیر را حذف می‌کند:${N}\n"
    printf "    ${GR}─────────────────────────────────────${N}\n"
    printf "    - تمام سرویس‌های تانل\n"
    printf "    - کانفیگ HAProxy\n"
    printf "    - کلید SSH\n"
    printf "    - فایل‌های تنظیمات\n"
    printf "    ${GR}─────────────────────────────────────${N}\n"
    echo ""
    
    read -p "$(printf "    ${R}آیا مطمئن هستید? [y/N]: ${N}")" confirm
    
    if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
        print_info "لغو شد"
        sleep 1
        return
    fi
    
    echo ""
    
    # توقف و حذف سرویس‌های تانل
    print_info "حذف سرویس‌های تانل..."
    for i in 1 2 3; do
        local service="sshsaeed-tunnel${i}"
        systemctl stop "$service" &>/dev/null
        systemctl disable "$service" &>/dev/null
        rm -f "/etc/systemd/system/${service}.service"
    done
    systemctl daemon-reload
    print_ok "سرویس‌های تانل حذف شدند"
    
    # بازگرداندن HAProxy
    print_info "بازگرداندن HAProxy..."
    if [[ -f "$BACKUP_DIR/haproxy.cfg."* ]]; then
        local latest_backup=$(ls -t "$BACKUP_DIR/haproxy.cfg."* 2>/dev/null | head -1)
        if [[ -n "$latest_backup" ]]; then
            cp "$latest_backup" /etc/haproxy/haproxy.cfg
            systemctl restart haproxy
        fi
    fi
    print_ok "HAProxy بازگردانی شد"
    
    # حذف کلید SSH
    print_info "حذف کلید SSH..."
    rm -f "$KEY_FILE" "${KEY_FILE}.pub"
    print_ok "کلید SSH حذف شد"
    
    # حذف فایل‌های کانفیگ
    print_info "حذف فایل‌های تنظیمات..."
    rm -rf "$CONFIG_DIR"
    rm -f /etc/ssh/sshd_config.d/sshsaeed.conf
    print_ok "فایل‌های تنظیمات حذف شدند"
    
    echo ""
    print_ok "حذف کامل انجام شد"
    
    log "INFO" "SSHSaeed uninstalled"
    
    sleep 2
}

# ═══════════════════════════════════════════════════════════════════════════════
#                              منوی اصلی
# ═══════════════════════════════════════════════════════════════════════════════
show_status_bar() {
    load_config &>/dev/null
    
    local tunnels_active=0
    for i in 1 2 3; do
        systemctl is-active --quiet "sshsaeed-tunnel${i}" && ((tunnels_active++))
    done
    
    local haproxy_status="${R}OFF${N}"
    systemctl is-active --quiet haproxy && haproxy_status="${G}ON${N}"
    
    printf "    ${GR}┌────────────────────────────────────────────────────────┐${N}\n"
    printf "    ${GR}│${N} نوع: ${W}%-10s${N} ${GR}│${N} تانل‌ها: ${G}%d${N}/3 ${GR}│${N} HAProxy: %b ${GR}│${N}\n" \
           "${SERVER_TYPE:-نامشخص}" "$tunnels_active" "$haproxy_status"
    printf "    ${GR}└────────────────────────────────────────────────────────┘${N}\n"
}

main_menu() {
    while true; do
        show_banner
        show_status_bar
        echo ""
        
        printf "    ${W}منوی اصلی:${N}\n"
        printf "    ${GR}─────────────────────────────────────────${N}\n"
        echo ""
        printf "    ${C}[1]${N}  تست پشتیبانی AES-128-GCM\n"
        printf "    ${C}[2]${N}  تنظیم سرور خارج (Kharej)\n"
        printf "    ${G}[3]${N}  راه‌اندازی کامل خودکار ایران ${Y}★${N}\n"
        printf "    ${C}[4]${N}  تست گرافیکی تانل‌ها\n"
        printf "    ${C}[5]${N}  تغییر IP خارج\n"
        echo ""
        printf "    ${GR}─────────────────────────────────────────${N}\n"
        printf "    ${R}[0]${N}  حذف کامل\n"
        printf "    ${R}[q]${N}  خروج\n"
        printf "    ${GR}─────────────────────────────────────────${N}\n"
        echo ""
        
        read -p "$(printf "    ${C}انتخاب شما: ${N}")" choice
        
        case $choice in
            1) test_aes_support ;;
            2) setup_kharej_server ;;
            3) setup_iran_automatic ;;
            4) test_tunnels_graphical ;;
            5) change_kharej_ip ;;
            0) uninstall_all ;;
            q|Q) 
                echo ""
                print_info "خداحافظ!"
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
#                              شروع برنامه
# ═══════════════════════════════════════════════════════════════════════════════
check_root
init_system
main_menu
