#!/bin/bash
# ═══════════════════════════════════════════════════════════════════════════════
#  ███████╗███████╗██╗  ██╗███████╗ █████╗ ███████╗███████╗██████╗
#  ██╔════╝██╔════╝██║  ██║██╔════╝██╔══██╗██╔════╝██╔════╝██╔══██╗
#  ███████╗███████╗███████║███████╗███████║█████╗  █████╗  ██║  ██║
#  ╚════██║╚════██║██╔══██║╚════██║██╔══██║██╔══╝  ██╔══╝  ██║  ██║
#  ███████║███████║██║  ██║███████║██║  ██║███████╗███████╗██████╔╝
#  ╚══════╝╚══════╝╚═╝  ╚═╝╚══════╝╚═╝  ╚═╝╚══════╝╚══════╝╚═════╝
# ═══════════════════════════════════════════════════════════════════════════════
#  SSHSaeed Installer v4.0 | AES-128-GCM + HAProxy + AutoSSH
#  GitHub: https://github.com/sshsaeed/tunnel-manager
# ═══════════════════════════════════════════════════════════════════════════════

set -e

# ═══════════════════════════════════════════════════════════════════════════════
#                              تنظیمات نصب
# ═══════════════════════════════════════════════════════════════════════════════
readonly VERSION="4.0"
readonly REPO_RAW="https://raw.githubusercontent.com/sshsaeed/tunnel-manager/main"
readonly GITHUB_URL="https://github.com/sshsaeed/tunnel-manager"

# مسیرها (هماهنگ با sshsaeed.sh)
readonly CONFIG_DIR="/etc/sshsaeed"
readonly BACKUP_DIR="/etc/sshsaeed/backups"
readonly LOG_FILE="/var/log/sshsaeed.log"
readonly INSTALL_PATH="/usr/local/bin/sshsaeed"
readonly SCRIPT_PATH="/etc/sshsaeed/sshsaeed.sh"

# ═══════════════════════════════════════════════════════════════════════════════
#                              رنگ‌ها و استایل
# ═══════════════════════════════════════════════════════════════════════════════
R='\033[0;31m'
G='\033[0;32m'
Y='\033[1;33m'
B='\033[0;34m'
M='\033[0;35m'
C='\033[0;36m'
W='\033[1;37m'
GR='\033[0;90m'
N='\033[0m'

# ═══════════════════════════════════════════════════════════════════════════════
#                              توابع نمایش
# ═══════════════════════════════════════════════════════════════════════════════
show_banner() {
    clear
    printf "${C}"
    cat << "EOF"
    ╔═══════════════════════════════════════════════════════════════╗
    ║  ███████╗███████╗██╗  ██╗███████╗ █████╗ ███████╗██████╗      ║
    ║  ██╔════╝██╔════╝██║  ██║██╔════╝██╔══██╗██╔════╝██╔══██╗     ║
    ║  ███████╗███████╗███████║███████╗███████║█████╗  ██║  ██║     ║
    ║  ╚════██║╚════██║██╔══██║╚════██║██╔══██║██╔══╝  ██║  ██║     ║
    ║  ███████║███████║██║  ██║███████║██║  ██║███████╗██████╔╝     ║
    ║  ╚══════╝╚══════╝╚═╝  ╚═╝╚══════╝╚═╝  ╚═╝╚══════╝╚═════╝      ║
    ╚═══════════════════════════════════════════════════════════════╝
EOF
    printf "${N}"
    printf "    ${GR}────────────────────────────────────────────────────────────${N}\n"
    printf "    ${W}Installer v${VERSION}${N}  |  ${C}SSH + HAProxy + AES-128-GCM + AutoSSH${N}\n"
    printf "    ${GR}GitHub:${N}  ${B}${GITHUB_URL}${N}\n"
    printf "    ${GR}────────────────────────────────────────────────────────────${N}\n"
    echo ""
}

line() {
    printf "    ${GR}═══════════════════════════════════════════════════════════════${N}\n"
}

print_step() {
    echo ""
    line
    printf "    ${W}📌 %s${N}\n" "$1"
    line
    echo ""
}

msg_ok() { printf "    ${G}[✓]${N} %s\n" "$1"; }
msg_err() { printf "    ${R}[✗]${N} %s\n" "$1"; }
msg_warn() { printf "    ${Y}[!]${N} %s\n" "$1"; }
msg_info() { printf "    ${C}[●]${N} %s\n" "$1"; }

# ═══════════════════════════════════════════════════════════════════════════════
#                              بررسی root
# ═══════════════════════════════════════════════════════════════════════════════
check_root() {
    msg_info "بررسی دسترسی root..."
    
    if [[ $EUID -ne 0 ]]; then
        msg_err "این اسکریپت باید با دسترسی root اجرا شود!"
        echo ""
        printf "    ${Y}لطفاً با دستور زیر اجرا کنید:${N}\n"
        printf "    ${W}sudo bash install.sh${N}\n"
        echo ""
        exit 1
    fi
    
    msg_ok "دسترسی root تأیید شد"
}

# ═══════════════════════════════════════════════════════════════════════════════
#                              تشخیص سیستم‌عامل
# ═══════════════════════════════════════════════════════════════════════════════
detect_os() {
    msg_info "تشخیص سیستم‌عامل..."
    
    if [[ -f /etc/os-release ]]; then
        . /etc/os-release
        OS=$ID
        OS_VERSION=$VERSION_ID
        OS_NAME=$PRETTY_NAME
    else
        msg_err "امکان تشخیص سیستم‌عامل وجود ندارد"
        exit 1
    fi
    
    case $OS in
        ubuntu|debian)
            PKG_UPDATE="apt-get update -qq"
            PKG_INSTALL="apt-get install -y -qq"
            msg_ok "سیستم‌عامل: $OS_NAME"
            ;;
        centos|rhel|almalinux|rocky|fedora)
            if command -v dnf &>/dev/null; then
                PKG_UPDATE="dnf makecache -q"
                PKG_INSTALL="dnf install -y -q"
            else
                PKG_UPDATE="yum makecache -q"
                PKG_INSTALL="yum install -y -q"
            fi
            msg_ok "سیستم‌عامل: $OS_NAME"
            ;;
        *)
            msg_warn "سیستم‌عامل تست‌نشده: $OS_NAME"
            PKG_UPDATE="apt-get update -qq"
            PKG_INSTALL="apt-get install -y -qq"
            ;;
    esac
    
    # معماری
    local arch=$(uname -m)
    msg_ok "معماری: $arch"
}

# ═══════════════════════════════════════════════════════════════════════════════
#                              آپدیت سیستم
# ═══════════════════════════════════════════════════════════════════════════════
update_system() {
    msg_info "آپدیت لیست پکیج‌ها..."
    
    $PKG_UPDATE >/dev/null 2>&1 || {
        msg_warn "آپدیت با مشکل مواجه شد، ادامه می‌دهیم..."
    }
    
    msg_ok "لیست پکیج‌ها آپدیت شد"
}

# ═══════════════════════════════════════════════════════════════════════════════
#                              نصب وابستگی‌ها
# ═══════════════════════════════════════════════════════════════════════════════
install_dependencies() {
    msg_info "نصب پکیج‌های مورد نیاز..."
    echo ""
    
    local packages=(
        "curl"
        "wget" 
        "jq"
        "bc"
        "sshpass"
        "autossh"
        "haproxy"
        "openssh-server"
        "openssh-client"
        "net-tools"
        "iptables"
    )
    
    local installed=0
    local skipped=0
    
    for pkg in "${packages[@]}"; do
        printf "    ${C}[●]${N} نصب %-15s " "$pkg"
        
        if $PKG_INSTALL "$pkg" >/dev/null 2>&1; then
            printf "${G}✓${N}\n"
            ((installed++))
        else
            printf "${Y}⚠${N} (موجود)\n"
            ((skipped++))
        fi
    done
    
    echo ""
    msg_ok "نصب پکیج‌ها: $installed نصب شد، $skipped از قبل موجود"
}

# ═══════════════════════════════════════════════════════════════════════════════
#                              ایجاد دایرکتوری‌ها
# ═══════════════════════════════════════════════════════════════════════════════
create_directories() {
    msg_info "ایجاد ساختار دایرکتوری‌ها..."
    
    # دایرکتوری‌های اصلی
    mkdir -p "$CONFIG_DIR"
    mkdir -p "$BACKUP_DIR"
    mkdir -p "/root/.ssh"
    
    # تنظیم مجوزها
    chmod 755 "$CONFIG_DIR"
    chmod 700 "$BACKUP_DIR"
    chmod 700 "/root/.ssh"
    
    # ایجاد فایل لاگ
    touch "$LOG_FILE"
    chmod 644 "$LOG_FILE"
    
    msg_ok "دایرکتوری‌ها ایجاد شد:"
    printf "    ${GR}├── Config:${N} %s\n" "$CONFIG_DIR"
    printf "    ${GR}├── Backup:${N} %s\n" "$BACKUP_DIR"
    printf "    ${GR}└── Log:${N}    %s\n" "$LOG_FILE"
}

# ═══════════════════════════════════════════════════════════════════════════════
#                              دانلود اسکریپت اصلی
# ═══════════════════════════════════════════════════════════════════════════════
download_script() {
    msg_info "دانلود اسکریپت اصلی..."
    
    local max_retries=3
    local retry=0
    
    while [[ $retry -lt $max_retries ]]; do
        if curl -fsSL "${REPO_RAW}/sshsaeed.sh" -o "$SCRIPT_PATH" 2>/dev/null; then
            # بررسی صحت دانلود
            if [[ -s "$SCRIPT_PATH" ]] && head -1 "$SCRIPT_PATH" | grep -q "#!/bin/bash"; then
                chmod +x "$SCRIPT_PATH"
                msg_ok "اسکریپت اصلی دانلود شد ✓"
                return 0
            fi
        fi
        
        ((retry++))
        msg_warn "تلاش $retry از $max_retries ناموفق..."
        sleep 2
    done
    
    msg_err "دانلود اسکریپت با شکست مواجه شد"
    msg_info "لطفاً اتصال اینترنت را بررسی کنید"
    exit 1
}

# ═══════════════════════════════════════════════════════════════════════════════
#                              ایجاد دستور سیستمی
# ═══════════════════════════════════════════════════════════════════════════════
create_command() {
    msg_info "ایجاد دستور 'sshsaeed'..."
    
    # حذف لینک قبلی
    rm -f "$INSTALL_PATH" 2>/dev/null || true
    
    # ایجاد لینک جدید
    ln -sf "$SCRIPT_PATH" "$INSTALL_PATH"
    
    if [[ -x "$INSTALL_PATH" ]]; then
        msg_ok "دستور 'sshsaeed' ایجاد شد ✓"
    else
        msg_warn "ایجاد لینک با مشکل مواجه شد"
        msg_info "می‌توانید با دستور زیر اجرا کنید: bash $SCRIPT_PATH"
    fi
}

# ═══════════════════════════════════════════════════════════════════════════════
#                              فعال‌سازی BBR
# ═══════════════════════════════════════════════════════════════════════════════
setup_bbr() {
    msg_info "تنظیم BBR TCP Congestion Control..."
    
    local current_cc=$(sysctl -n net.ipv4.tcp_congestion_control 2>/dev/null || echo "unknown")
    
    if [[ "$current_cc" == "bbr" ]]; then
        msg_ok "BBR از قبل فعال است ✓"
        return 0
    fi
    
    # بررسی پشتیبانی
    if ! modprobe tcp_bbr 2>/dev/null; then
        msg_warn "ماژول BBR در این کرنل موجود نیست"
        return 0
    fi
    
    # افزودن تنظیمات
    if ! grep -q "net.core.default_qdisc=fq" /etc/sysctl.conf 2>/dev/null; then
        cat >> /etc/sysctl.conf << 'EOF'

# BBR Configuration - SSHSaeed
net.core.default_qdisc=fq
net.ipv4.tcp_congestion_control=bbr
EOF
    fi
    
    sysctl -p >/dev/null 2>&1 || true
    
    current_cc=$(sysctl -n net.ipv4.tcp_congestion_control 2>/dev/null)
    if [[ "$current_cc" == "bbr" ]]; then
        msg_ok "BBR فعال شد ✓"
    else
        msg_warn "BBR پس از ریبوت فعال می‌شود"
    fi
}

# ═══════════════════════════════════════════════════════════════════════════════
#                              بهینه‌سازی SSH
# ═══════════════════════════════════════════════════════════════════════════════
optimize_ssh() {
    msg_info "بهینه‌سازی تنظیمات SSH..."
    
    local sshd_config="/etc/ssh/sshd_config"
    
    # پشتیبان‌گیری
    cp "$sshd_config" "${BACKUP_DIR}/sshd_config.bak.$(date +%s)" 2>/dev/null || true
    
    # افزودن تنظیمات بهینه
    if ! grep -q "# SSHSaeed Optimizations" "$sshd_config" 2>/dev/null; then
        cat >> "$sshd_config" << 'EOF'

# SSHSaeed Optimizations
TCPKeepAlive yes
ClientAliveInterval 30
ClientAliveCountMax 3
MaxSessions 100
GatewayPorts yes
PermitTunnel yes
AllowTcpForwarding yes
EOF
    fi
    
    # ریستارت SSH
    systemctl restart sshd 2>/dev/null || systemctl restart ssh 2>/dev/null || true
    
    msg_ok "SSH بهینه شد ✓"
}

# ═══════════════════════════════════════════════════════════════════════════════
#                              تنظیم فایروال
# ═══════════════════════════════════════════════════════════════════════════════
setup_firewall() {
    msg_info "تنظیم قوانین فایروال..."
    
    local ports=(22 443 80 2001 2002 2003 8404 8443 2096)
    
    # UFW
    if command -v ufw &>/dev/null; then
        for port in "${ports[@]}"; do
            ufw allow "$port/tcp" >/dev/null 2>&1 || true
        done
        msg_ok "UFW تنظیم شد ✓"
        return 0
    fi
    
    # Firewalld
    if command -v firewall-cmd &>/dev/null; then
        for port in "${ports[@]}"; do
            firewall-cmd --permanent --add-port="$port/tcp" >/dev/null 2>&1 || true
        done
        firewall-cmd --reload >/dev/null 2>&1 || true
        msg_ok "Firewalld تنظیم شد ✓"
        return 0
    fi
    
    # IPTables
    for port in "${ports[@]}"; do
        iptables -A INPUT -p tcp --dport "$port" -j ACCEPT 2>/dev/null || true
    done
    msg_ok "IPTables تنظیم شد ✓"
}

# ═══════════════════════════════════════════════════════════════════════════════
#                              پیام پایان نصب
# ═══════════════════════════════════════════════════════════════════════════════
show_completion() {
    echo ""
    printf "${G}"
    cat << "EOF"
    ╔═══════════════════════════════════════════════════════════════╗
    ║                                                               ║
    ║            ✅ نصب با موفقیت انجام شد! ✅                     ║
    ║                                                               ║
    ╚═══════════════════════════════════════════════════════════════╝
EOF
    printf "${N}"
    
    echo ""
    printf "    ${C}┌─────────────────────────────────────────────────────────┐${N}\n"
    printf "    ${C}│${N}                  ${W}🚀 نحوه استفاده${N}                       ${C}│${N}\n"
    printf "    ${C}├─────────────────────────────────────────────────────────┤${N}\n"
    printf "    ${C}│${N}                                                         ${C}│${N}\n"
    printf "    ${C}│${N}   برای اجرای پنل، دستور زیر را وارد کنید:              ${C}│${N}\n"
    printf "    ${C}│${N}                                                         ${C}│${N}\n"
    printf "    ${C}│${N}              ${Y}sshsaeed${N}                                  ${C}│${N}\n"
    printf "    ${C}│${N}                                                         ${C}│${N}\n"
    printf "    ${C}└─────────────────────────────────────────────────────────┘${N}\n"
    
    echo ""
    printf "    ${M}┌─────────────────────────────────────────────────────────┐${N}\n"
    printf "    ${M}│${N}               ${W}📁 اطلاعات نصب${N}                           ${M}│${N}\n"
    printf "    ${M}├─────────────────────────────────────────────────────────┤${N}\n"
    printf "    ${M}│${N}  نسخه:        ${G}%-40s${N}${M}│${N}\n" "$VERSION"
    printf "    ${M}│${N}  مسیر کانفیگ: ${G}%-40s${N}${M}│${N}\n" "$CONFIG_DIR"
    printf "    ${M}│${N}  فایل لاگ:    ${G}%-40s${N}${M}│${N}\n" "$LOG_FILE"
    printf "    ${M}│${N}  دستور:       ${G}%-40s${N}${M}│${N}\n" "sshsaeed"
    printf "    ${M}└─────────────────────────────────────────────────────────┘${N}\n"
    
    echo ""
    printf "    ${C}┌─────────────────────────────────────────────────────────┐${N}\n"
    printf "    ${C}│${N}                 ${W}✨ قابلیت‌ها${N}                            ${C}│${N}\n"
    printf "    ${C}├─────────────────────────────────────────────────────────┤${N}\n"
    printf "    ${C}│${N}  ✦ 3 تانل SSH با Load Balancing                        ${C}│${N}\n"
    printf "    ${C}│${N}  ✦ HAProxy برای توزیع بار                               ${C}│${N}\n"
    printf "    ${C}│${N}  ✦ رمزنگاری AES-128-GCM                                 ${C}│${N}\n"
    printf "    ${C}│${N}  ✦ AutoSSH برای اتصال مجدد خودکار                       ${C}│${N}\n"
    printf "    ${C}│${N}  ✦ بهینه‌سازی BBR                                       ${C}│${N}\n"
    printf "    ${C}│${N}  ✦ پنل مدیریت حرفه‌ای                                   ${C}│${N}\n"
    printf "    ${C}└─────────────────────────────────────────────────────────┘${N}\n"
    
    echo ""
    printf "    ${GR}═══════════════════════════════════════════════════════════════${N}\n"
    printf "    ${W}GitHub:${N} ${B}${GITHUB_URL}${N}\n"
    printf "    ${GR}═══════════════════════════════════════════════════════════════${N}\n"
    echo ""
}

# ═══════════════════════════════════════════════════════════════════════════════
#                              حذف نصب
# ═══════════════════════════════════════════════════════════════════════════════
uninstall() {
    show_banner
    
    printf "    ${Y}╔═══════════════════════════════════════════════════════════════╗${N}\n"
    printf "    ${Y}║                    ⚠️  حالت حذف                               ║${N}\n"
    printf "    ${Y}╚═══════════════════════════════════════════════════════════════╝${N}\n"
    echo ""
    
    read -p "$(printf "    ${R}[!]${N} آیا مطمئن هستید؟ [y/N]: ")" confirm
    
    if [[ "${confirm,,}" != "y" ]]; then
        msg_info "حذف لغو شد"
        exit 0
    fi
    
    echo ""
    print_step "حذف SSHSaeed"
    
    # توقف سرویس‌ها
    msg_info "توقف سرویس‌های تانل..."
    for i in 1 2 3; do
        systemctl stop "sshsaeed-tunnel${i}" 2>/dev/null || true
        systemctl disable "sshsaeed-tunnel${i}" 2>/dev/null || true
        rm -f "/etc/systemd/system/sshsaeed-tunnel${i}.service" 2>/dev/null || true
    done
    msg_ok "سرویس‌های تانل متوقف شد"
    
    # توقف HAProxy
    msg_info "توقف HAProxy..."
    systemctl stop haproxy 2>/dev/null || true
    msg_ok "HAProxy متوقف شد"
    
    systemctl daemon-reload 2>/dev/null || true
    
    # حذف فایل‌ها
    msg_info "حذف فایل‌ها..."
    rm -rf "$CONFIG_DIR"
    rm -f "$INSTALL_PATH"
    rm -f "$LOG_FILE"
    rm -f "/root/.ssh/sshsaeed_ed25519"
    rm -f "/root/.ssh/sshsaeed_ed25519.pub"
    msg_ok "فایل‌ها حذف شد"
    
    # حذف کاربر تانل
    msg_info "حذف کاربر tunnel..."
    userdel -r tunnel 2>/dev/null || true
    msg_ok "کاربر حذف شد"
    
    echo ""
    printf "${G}"
    cat << "EOF"
    ╔═══════════════════════════════════════════════════════════════╗
    ║            ✅ حذف با موفقیت انجام شد! ✅                     ║
    ╚═══════════════════════════════════════════════════════════════╝
EOF
    printf "${N}"
    echo ""
    printf "    ${W}برای نصب مجدد:${N}\n"
    printf "    ${Y}bash <(curl -fsSL ${REPO_RAW}/install.sh)${N}\n"
    echo ""
}

# ═══════════════════════════════════════════════════════════════════════════════
#                              راهنما
# ═══════════════════════════════════════════════════════════════════════════════
show_help() {
    echo ""
    printf "${C}SSHSaeed Installer - راهنما${N}\n"
    echo ""
    printf "${W}استفاده:${N}\n"
    echo "  bash install.sh [OPTIONS]"
    echo ""
    printf "${W}گزینه‌ها:${N}\n"
    echo "  -h, --help        نمایش این راهنما"
    echo "  -u, --uninstall   حذف SSHSaeed"
    echo "  -v, --version     نمایش نسخه"
    echo ""
    printf "${W}مثال‌ها:${N}\n"
    echo "  # نصب"
    echo "  bash <(curl -fsSL ${REPO_RAW}/install.sh)"
    echo ""
    echo "  # حذف"
    echo "  bash <(curl -fsSL ${REPO_RAW}/install.sh) --uninstall"
    echo ""
}

# ═══════════════════════════════════════════════════════════════════════════════
#                              تابع اصلی
# ═══════════════════════════════════════════════════════════════════════════════
main() {
    # پردازش آرگومان‌ها
    case "$1" in
        -h|--help)
            show_help
            exit 0
            ;;
        -u|--uninstall)
            check_root
            uninstall
            exit 0
            ;;
        -v|--version)
            echo "SSHSaeed Installer v$VERSION"
            exit 0
            ;;
    esac
    
    # نمایش بنر
    show_banner
    
    printf "    ${W}شروع فرآیند نصب...${N}\n"
    sleep 1
    
    # مرحله 1: بررسی سیستم
    print_step "مرحله 1/7: بررسی سیستم"
    check_root
    detect_os
    
    # مرحله 2: آپدیت سیستم
    print_step "مرحله 2/7: آپدیت سیستم"
    update_system
    
    # مرحله 3: نصب وابستگی‌ها
    print_step "مرحله 3/7: نصب وابستگی‌ها"
    install_dependencies
    
    # مرحله 4: ایجاد دایرکتوری‌ها
    print_step "مرحله 4/7: ایجاد دایرکتوری‌ها"
    create_directories
    
    # مرحله 5: دانلود اسکریپت
    print_step "مرحله 5/7: دانلود پنل"
    download_script
    create_command
    
    # مرحله 6: بهینه‌سازی سیستم
    print_step "مرحله 6/7: بهینه‌سازی سیستم"
    setup_bbr
    optimize_ssh
    
    # مرحله 7: تنظیم فایروال
    print_step "مرحله 7/7: تنظیم فایروال"
    setup_firewall
    
    # پایان نصب
    show_completion
    
    # اجرای پنل؟
    echo ""
    read -p "$(printf "    ${C}[?]${N} آیا می‌خواهید پنل را الان اجرا کنید؟ [Y/n]: ")" run_now
    
    if [[ "${run_now,,}" != "n" ]]; then
        echo ""
        msg_info "در حال اجرای SSHSaeed..."
        sleep 1
        sshsaeed
    else
        echo ""
        msg_info "برای اجرا از دستور 'sshsaeed' استفاده کنید"
        echo ""
    fi
}

# ═══════════════════════════════════════════════════════════════════════════════
#                              اجرا
# ═══════════════════════════════════════════════════════════════════════════════
main "$@"
