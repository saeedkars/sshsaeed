#!/bin/bash
# ═══════════════════════════════════════════════════════════════════════════════
#  ███████╗███████╗██╗  ██╗███████╗ █████╗ ███████╗███████╗██████╗
#  ██╔════╝██╔════╝██║  ██║██╔════╝██╔══██╗██╔════╝██╔════╝██╔══██╗
#  ███████╗███████╗███████║███████╗███████║█████╗  █████╗  ██║  ██║
#  ╚════██║╚════██║██╔══██║╚════██║██╔══██║██╔══╝  ██╔══╝  ██║  ██║
#  ███████║███████║██║  ██║███████║██║  ██║███████╗███████╗██████╔╝
#  ╚══════╝╚══════╝╚═╝  ╚═╝╚══════╝╚═╝  ╚═╝╚══════╝╚══════╝╚═════╝
# ═══════════════════════════════════════════════════════════════════════════════
#  SSHSaeed Tunnel Manager - Installer v6.0
#  GitHub: https://github.com/saeedkars/sshsaeed
#  تغییرات: رفع تداخل متغیر VERSION، بهینه‌سازی کامل
# ═══════════════════════════════════════════════════════════════════════════════

set -o pipefail
export LC_ALL=C
export LANG=C

# ═══════════════════════════════════════════════════════════════════════════════
#                    متغیرها (نام تغییر یافته برای جلوگیری از تداخل)
# ═══════════════════════════════════════════════════════════════════════════════
# ⚠️ مهم: از VERSION استفاده نکنید - تداخل با /etc/os-release
readonly SCRIPT_VERSION="6.0"
readonly SCRIPT_NAME="sshsaeed"
readonly INSTALL_PATH="/usr/local/bin/sshsaeed"
readonly SCRIPT_URL="https://raw.githubusercontent.com/saeedkars/sshsaeed/main/sshsaeed.sh"
readonly BACKUP_URL="https://raw.githubusercontent.com/saeedkars/sshsaeed/master/sshsaeed.sh"
readonly BACKUP_PATH="/usr/local/bin/sshsaeed.backup"
readonly CONFIG_DIR="/etc/sshsaeed"

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

# ═══════════════════════════════════════════════════════════════════════════════
#                              توابع کمکی
# ═══════════════════════════════════════════════════════════════════════════════
print_ok() { printf "    ${G}✓${N} %s\n" "$1"; }
print_err() { printf "    ${R}✗${N} %s\n" "$1"; }
print_warn() { printf "    ${Y}⚠${N} %s\n" "$1"; }
print_info() { printf "    ${C}►${N} %s\n" "$1"; }

line() {
    printf "    ${GR}═══════════════════════════════════════════════════════════${N}\n"
}

show_banner() {
    clear
    echo ""
    printf "${C}"
    printf "    ███████╗███████╗██╗  ██╗███████╗ █████╗ ███████╗███████╗██████╗ \n"
    printf "    ██╔════╝██╔════╝██║  ██║██╔════╝██╔══██╗██╔════╝██╔════╝██╔══██╗\n"
    printf "    ███████╗███████╗███████║███████╗███████║█████╗  █████╗  ██║  ██║\n"
    printf "    ╚════██║╚════██║██╔══██║╚════██║██╔══██║██╔══╝  ██╔══╝  ██║  ██║\n"
    printf "    ███████║███████║██║  ██║███████║██║  ██║███████╗███████╗██████╔╝\n"
    printf "    ╚══════╝╚══════╝╚═╝  ╚═╝╚══════╝╚═╝  ╚═╝╚══════╝╚══════╝╚═════╝ \n"
    printf "${N}"
    printf "    ${GR}─────────────────────────────────────────────────────────────${N}\n"
    printf "    ${W}SSH Tunnel Manager${N} ${C}v${SCRIPT_VERSION}${N} ${GR}|${N} ${Y}Installer${N}\n"
    printf "    ${GR}─────────────────────────────────────────────────────────────${N}\n"
    echo ""
}

# ═══════════════════════════════════════════════════════════════════════════════
#                         بررسی سیستم‌عامل (اصلاح شده)
# ═══════════════════════════════════════════════════════════════════════════════
check_os() {
    # استفاده از نام متغیر متفاوت برای جلوگیری از تداخل
    local os_id=""
    local os_ver=""
    
    if [[ -f /etc/os-release ]]; then
        # خواندن مستقیم بدون source کردن
        os_id=$(grep "^ID=" /etc/os-release 2>/dev/null | cut -d'=' -f2 | tr -d '"')
        os_ver=$(grep "^VERSION_ID=" /etc/os-release 2>/dev/null | cut -d'=' -f2 | tr -d '"')
    fi
    
    case "$os_id" in
        ubuntu|debian|linuxmint)
            PKG_MANAGER="apt"
            PKG_UPDATE="apt update -qq"
            PKG_INSTALL="apt install -y -qq"
            ;;
        centos|rhel|rocky|almalinux|fedora)
            if command -v dnf &>/dev/null; then
                PKG_MANAGER="dnf"
                PKG_UPDATE="dnf check-update -q || true"
                PKG_INSTALL="dnf install -y -q"
            else
                PKG_MANAGER="yum"
                PKG_UPDATE="yum check-update -q || true"
                PKG_INSTALL="yum install -y -q"
            fi
            ;;
        *)
            # تشخیص بر اساس وجود package manager
            if command -v apt &>/dev/null; then
                PKG_MANAGER="apt"
                PKG_UPDATE="apt update -qq"
                PKG_INSTALL="apt install -y -qq"
            elif command -v dnf &>/dev/null; then
                PKG_MANAGER="dnf"
                PKG_UPDATE="dnf check-update -q || true"
                PKG_INSTALL="dnf install -y -q"
            elif command -v yum &>/dev/null; then
                PKG_MANAGER="yum"
                PKG_UPDATE="yum check-update -q || true"
                PKG_INSTALL="yum install -y -q"
            else
                print_err "سیستم‌عامل پشتیبانی نمی‌شود"
                exit 1
            fi
            ;;
    esac
    
    print_ok "سیستم‌عامل: ${os_id:-unknown} ${os_ver:-}"
}

# ═══════════════════════════════════════════════════════════════════════════════
#                              بررسی root
# ═══════════════════════════════════════════════════════════════════════════════
check_root() {
    if [[ $EUID -ne 0 ]]; then
        echo ""
        print_err "این اسکریپت نیاز به دسترسی root دارد"
        echo ""
        printf "    ${Y}اجرا کنید:${N} ${W}sudo bash $0${N}\n"
        printf "    ${Y}یا:${N} ${W}sudo su -${N} ${GR}سپس اسکریپت را اجرا کنید${N}\n"
        echo ""
        exit 1
    fi
}

# ═══════════════════════════════════════════════════════════════════════════════
#                         نصب وابستگی‌ها
# ═══════════════════════════════════════════════════════════════════════════════
install_dependencies() {
    print_info "بررسی و نصب وابستگی‌ها..."
    
    local deps_needed=()
    
    # بررسی curl
    if ! command -v curl &>/dev/null; then
        deps_needed+=("curl")
    fi
    
    # بررسی wget (به عنوان بکاپ)
    if ! command -v wget &>/dev/null; then
        deps_needed+=("wget")
    fi
    
    # بررسی openssl (برای تست رمزنگاری)
    if ! command -v openssl &>/dev/null; then
        deps_needed+=("openssl")
    fi
    
    if [[ ${#deps_needed[@]} -gt 0 ]]; then
        print_info "نصب: ${deps_needed[*]}"
        
        # به‌روزرسانی لیست پکیج‌ها
        $PKG_UPDATE >/dev/null 2>&1 || true
        
        # نصب وابستگی‌ها
        for pkg in "${deps_needed[@]}"; do
            $PKG_INSTALL "$pkg" >/dev/null 2>&1 || print_warn "خطا در نصب $pkg"
        done
    fi
    
    print_ok "وابستگی‌ها آماده"
}

# ═══════════════════════════════════════════════════════════════════════════════
#                         بررسی نسخه فعلی
# ═══════════════════════════════════════════════════════════════════════════════
check_existing() {
    if [[ -f "$INSTALL_PATH" ]]; then
        # استفاده از SCRIPT_VERSION به جای VERSION
        local current_ver=$(grep -m1 "^readonly SCRIPT_VERSION=" "$INSTALL_PATH" 2>/dev/null | cut -d'"' -f2)
        
        # اگر با فرمت قدیمی بود
        if [[ -z "$current_ver" ]]; then
            current_ver=$(grep -m1 "^readonly VERSION=" "$INSTALL_PATH" 2>/dev/null | cut -d'"' -f2)
        fi
        
        if [[ -n "$current_ver" ]]; then
            echo ""
            print_warn "نسخه قبلی نصب شده: v${current_ver}"
            printf "    ${C}نسخه جدید: v${SCRIPT_VERSION}${N}\n"
            echo ""
            
            read -p "$(printf "    ${Y}آیا می‌خواهید به‌روزرسانی کنید? [Y/n]: ${N}")" update_choice
            
            if [[ "$update_choice" == "n" || "$update_choice" == "N" ]]; then
                echo ""
                print_info "در حال اجرای نسخه فعلی..."
                sleep 1
                exec "$INSTALL_PATH"
                exit 0
            fi
            
            # بکاپ نسخه قبلی
            cp "$INSTALL_PATH" "$BACKUP_PATH" 2>/dev/null
            print_ok "بکاپ از نسخه قبلی ایجاد شد"
        fi
    fi
}

# ═══════════════════════════════════════════════════════════════════════════════
#                         دانلود اسکریپت اصلی
# ═══════════════════════════════════════════════════════════════════════════════
download_script() {
    print_info "دانلود اسکریپت اصلی v${SCRIPT_VERSION}..."
    
    local download_success=false
    local temp_file="/tmp/sshsaeed_download_$$.sh"
    
    # تلاش اول: از main branch
    if curl -sL --connect-timeout 15 --max-time 60 "$SCRIPT_URL" -o "$temp_file" 2>/dev/null; then
        if [[ -s "$temp_file" ]] && head -1 "$temp_file" | grep -q "bash"; then
            download_success=true
            print_ok "دانلود از GitHub (main) موفق"
        fi
    fi
    
    # تلاش دوم: از master branch
    if [[ "$download_success" != "true" ]]; then
        print_warn "تلاش مجدد از master branch..."
        if curl -sL --connect-timeout 15 --max-time 60 "$BACKUP_URL" -o "$temp_file" 2>/dev/null; then
            if [[ -s "$temp_file" ]] && head -1 "$temp_file" | grep -q "bash"; then
                download_success=true
                print_ok "دانلود از GitHub (master) موفق"
            fi
        fi
    fi
    
    # تلاش سوم: با wget
    if [[ "$download_success" != "true" ]] && command -v wget &>/dev/null; then
        print_warn "تلاش با wget..."
        if wget -q --timeout=15 -O "$temp_file" "$SCRIPT_URL" 2>/dev/null; then
            if [[ -s "$temp_file" ]] && head -1 "$temp_file" | grep -q "bash"; then
                download_success=true
                print_ok "دانلود با wget موفق"
            fi
        fi
    fi
    
    # بررسی موفقیت دانلود
    if [[ "$download_success" == "true" ]]; then
        mv "$temp_file" "$INSTALL_PATH"
        chmod +x "$INSTALL_PATH"
        
        # ایجاد symlink
        if [[ ! -L /usr/bin/sshsaeed ]] && [[ ! -f /usr/bin/sshsaeed ]]; then
            ln -sf "$INSTALL_PATH" /usr/bin/sshsaeed 2>/dev/null || true
        fi
        
        return 0
    else
        # خطا در دانلود
        rm -f "$temp_file" 2>/dev/null
        
        print_err "خطا در دانلود اسکریپت"
        echo ""
        printf "    ${Y}راه‌حل‌های جایگزین:${N}\n"
        printf "    ${GR}─────────────────────────────────────${N}\n"
        printf "    ${W}1.${N} فایل sshsaeed.sh را دستی دانلود کنید\n"
        printf "    ${W}2.${N} در مسیر ${C}$INSTALL_PATH${N} قرار دهید\n"
        printf "    ${W}3.${N} دستور اجرا:\n"
        printf "       ${G}chmod +x $INSTALL_PATH && sshsaeed${N}\n"
        printf "    ${GR}─────────────────────────────────────${N}\n"
        echo ""
        
        # بازگردانی بکاپ اگر موجود باشد
        if [[ -f "$BACKUP_PATH" ]]; then
            mv "$BACKUP_PATH" "$INSTALL_PATH"
            print_ok "نسخه قبلی بازگردانی شد"
            printf "    ${G}اجرا کنید: ${W}sshsaeed${N}\n"
        fi
        
        return 1
    fi
}

# ═══════════════════════════════════════════════════════════════════════════════
#                         ایجاد دایرکتوری‌ها
# ═══════════════════════════════════════════════════════════════════════════════
create_directories() {
    print_info "ایجاد دایرکتوری‌های مورد نیاز..."
    
    mkdir -p "$CONFIG_DIR" 2>/dev/null
    mkdir -p "$CONFIG_DIR/backups" 2>/dev/null
    mkdir -p /root/.ssh 2>/dev/null
    chmod 700 /root/.ssh 2>/dev/null
    
    print_ok "دایرکتوری‌ها آماده"
}

# ═══════════════════════════════════════════════════════════════════════════════
#                         پاکسازی
# ═══════════════════════════════════════════════════════════════════════════════
cleanup() {
    rm -f /tmp/sshsaeed_download_*.sh 2>/dev/null
    rm -f "$BACKUP_PATH" 2>/dev/null
}

# ═══════════════════════════════════════════════════════════════════════════════
#                         نمایش اطلاعات نهایی
# ═══════════════════════════════════════════════════════════════════════════════
show_success() {
    echo ""
    printf "    ${G}╔═══════════════════════════════════════════════════════════╗${N}\n"
    printf "    ${G}║${N}                                                           ${G}║${N}\n"
    printf "    ${G}║${N}       ${W}✓ نصب با موفقیت انجام شد!${N}                          ${G}║${N}\n"
    printf "    ${G}║${N}                                                           ${G}║${N}\n"
    printf "    ${G}║${N}       ${C}نسخه: ${W}v${SCRIPT_VERSION}${N}                                      ${G}║${N}\n"
    printf "    ${G}║${N}       ${C}مسیر: ${W}$INSTALL_PATH${N}                   ${G}║${N}\n"
    printf "    ${G}║${N}                                                           ${G}║${N}\n"
    printf "    ${G}╚═══════════════════════════════════════════════════════════╝${N}\n"
    echo ""
    printf "    ${Y}برای اجرا:${N} ${W}sshsaeed${N}\n"
    echo ""
}

# ═══════════════════════════════════════════════════════════════════════════════
#                              MAIN
# ═══════════════════════════════════════════════════════════════════════════════
main() {
    # نمایش بنر
    show_banner
    
    # بررسی root
    check_root
    
    line
    printf "    ${W}شروع نصب SSHSaeed v${SCRIPT_VERSION}${N}\n"
    line
    echo ""
    
    # مراحل نصب
    check_os
    check_existing
    install_dependencies
    create_directories
    
    if download_script; then
        cleanup
        show_success
        
        # سوال برای اجرای فوری
        read -p "$(printf "    ${Y}اجرای پنل مدیریت؟ [Y/n]: ${N}")" run_now
        
        if [[ "$run_now" != "n" && "$run_now" != "N" ]]; then
            echo ""
            print_info "در حال اجرای پنل..."
            sleep 1
            exec "$INSTALL_PATH"
        fi
    else
        exit 1
    fi
}

# اجرای main
main "$@"
