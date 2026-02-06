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
#  تغییرات: ساختار تانل جدید، BBR، Ulimit بهینه، رفع تداخل VERSION
# ═══════════════════════════════════════════════════════════════════════════════

set -o pipefail
export LC_ALL=C
export LANG=C

# ═══════════════════════════════════════════════════════════════════════════════
#                    متغیرها (SCRIPT_VERSION برای جلوگیری از تداخل)
# ═══════════════════════════════════════════════════════════════════════════════
readonly SCRIPT_VERSION="6.0"
readonly SCRIPT_NAME="sshsaeed"
readonly INSTALL_PATH="/usr/local/bin/sshsaeed"
readonly GITHUB_RAW="https://raw.githubusercontent.com/saeedkars/sshsaeed/main"
readonly SCRIPT_URL="${GITHUB_RAW}/sshsaeed.sh"
readonly BACKUP_URL="https://raw.githubusercontent.com/saeedkars/sshsaeed/master/sshsaeed.sh"
readonly BACKUP_PATH="/usr/local/bin/sshsaeed.backup"
readonly CONFIG_DIR="/etc/sshsaeed"
readonly BACKUP_DIR="/etc/sshsaeed/backups"
readonly LOG_FILE="/var/log/sshsaeed-install.log"

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
BOLD='\033[1m'

# Package Manager
PKG_MANAGER=""
PKG_UPDATE=""
PKG_INSTALL=""

# ═══════════════════════════════════════════════════════════════════════════════
#                              توابع چاپ
# ═══════════════════════════════════════════════════════════════════════════════
print_ok() {
    printf "    ${G}[✓]${N} ${1}\n"
}

print_err() {
    printf "    ${R}[✗]${N} ${1}\n"
}

print_info() {
    printf "    ${Y}[●]${N} ${1}\n"
}

print_warn() {
    printf "    ${Y}[!]${N} ${1}\n"
}

print_step() {
    printf "    ${C}[${1}/${2}]${N} ${3}\n"
}

line() {
    printf "    ${GR}════════════════════════════════════════════════════════════${N}\n"
}

# ═══════════════════════════════════════════════════════════════════════════════
#                              بنر
# ═══════════════════════════════════════════════════════════════════════════════
show_banner() {
    clear
    echo ""
    printf "${C}"
    cat << 'EOF'
    ███████╗███████╗██╗  ██╗███████╗ █████╗ ███████╗███████╗██████╗ 
    ██╔════╝██╔════╝██║  ██║██╔════╝██╔══██╗██╔════╝██╔════╝██╔══██╗
    ███████╗███████╗███████║███████╗███████║█████╗  █████╗  ██║  ██║
    ╚════██║╚════██║██╔══██║╚════██║██╔══██║██╔══╝  ██╔══╝  ██║  ██║
    ███████║███████║██║  ██║███████║██║  ██║███████╗███████╗██████╔╝
    ╚══════╝╚══════╝╚═╝  ╚═╝╚══════╝╚═╝  ╚═╝╚══════╝╚══════╝╚═════╝ 
EOF
    printf "${N}"
    printf "    ${GR}─────────────────────────────────────────────────────────────${N}\n"
    printf "    ${W}SSH Tunnel Manager${N} ${G}v${SCRIPT_VERSION}${N} ${GR}│${N} ${C}Installer${N}\n"
    printf "    ${GR}─────────────────────────────────────────────────────────────${N}\n"
    echo ""
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
#                              تشخیص سیستم‌عامل
# ═══════════════════════════════════════════════════════════════════════════════
get_os_info() {
    local os_name=""
    local os_version=""

    if [[ -f /etc/os-release ]]; then
        os_name=$(grep "^NAME=" /etc/os-release 2>/dev/null | cut -d'=' -f2 | tr -d '"')
        os_version=$(grep "^VERSION_ID=" /etc/os-release 2>/dev/null | cut -d'=' -f2 | tr -d '"')
        echo "${os_name} ${os_version}"
    elif [[ -f /etc/debian_version ]]; then
        echo "Debian $(cat /etc/debian_version)"
    elif [[ -f /etc/redhat-release ]]; then
        cat /etc/redhat-release
    else
        uname -s -r
    fi
}

check_os() {
    local os_info=$(get_os_info)
    print_info "سیستم‌عامل: ${os_info}"

    if [[ -f /etc/debian_version ]]; then
        PKG_MANAGER="apt"
        PKG_UPDATE="apt-get update -qq"
        PKG_INSTALL="apt-get install -y -qq"
        return 0
    elif [[ -f /etc/redhat-release ]]; then
        if command -v dnf &>/dev/null; then
            PKG_MANAGER="dnf"
            PKG_UPDATE="dnf check-update -q"
            PKG_INSTALL="dnf install -y -q"
        else
            PKG_MANAGER="yum"
            PKG_UPDATE="yum check-update -q"
            PKG_INSTALL="yum install -y -q"
        fi
        print_warn "سیستم RedHat - ممکن است نیاز به تنظیمات اضافی باشد"
        return 0
    elif command -v apk &>/dev/null; then
        PKG_MANAGER="apk"
        PKG_UPDATE="apk update"
        PKG_INSTALL="apk add --quiet"
        return 0
    else
        print_warn "سیستم‌عامل ناشناخته - ادامه با احتیاط"
        PKG_MANAGER="apt"
        PKG_UPDATE="apt-get update -qq"
        PKG_INSTALL="apt-get install -y -qq"
        return 0
    fi
}

# ═══════════════════════════════════════════════════════════════════════════════
#                              بررسی اینترنت
# ═══════════════════════════════════════════════════════════════════════════════
check_internet() {
    print_info "بررسی اتصال اینترنت..."

    local test_urls=("https://github.com" "https://google.com" "https://cloudflare.com")
    
    for url in "${test_urls[@]}"; do
        if curl -s --connect-timeout 5 --max-time 10 "$url" > /dev/null 2>&1; then
            print_ok "اتصال اینترنت برقرار است"
            return 0
        fi
    done

    # تست با ping
    if ping -c 1 -W 3 8.8.8.8 &>/dev/null; then
        print_ok "اتصال اینترنت برقرار است (DNS ممکن است مشکل داشته باشد)"
        return 0
    fi

    print_err "اتصال اینترنت برقرار نیست"
    return 1
}

# ═══════════════════════════════════════════════════════════════════════════════
#                         نصب وابستگی‌ها
# ═══════════════════════════════════════════════════════════════════════════════
install_dependencies() {
    print_info "بررسی و نصب وابستگی‌ها..."

    # لیست پکیج‌های مورد نیاز برای v6.0
    local required_pkgs=(
        "curl"
        "wget"
        "openssl"
        "socat"
        "jq"
    )

    local deps_needed=()

    # بررسی هر پکیج
    for pkg in "${required_pkgs[@]}"; do
        if ! command -v "$pkg" &>/dev/null; then
            deps_needed+=("$pkg")
        fi
    done

    # نصب پکیج‌های مورد نیاز
    if [[ ${#deps_needed[@]} -gt 0 ]]; then
        print_info "نصب: ${deps_needed[*]}"

        # به‌روزرسانی لیست پکیج‌ها
        $PKG_UPDATE >/dev/null 2>&1 || true

        # نصب وابستگی‌ها
        for pkg in "${deps_needed[@]}"; do
            if $PKG_INSTALL "$pkg" >/dev/null 2>&1; then
                print_ok "$pkg نصب شد"
            else
                print_warn "خطا در نصب $pkg (ممکن است اختیاری باشد)"
            fi
        done
    else
        print_ok "همه وابستگی‌ها از قبل نصب هستند"
    fi
}

# ═══════════════════════════════════════════════════════════════════════════════
#                         بررسی نسخه فعلی
# ═══════════════════════════════════════════════════════════════════════════════
check_existing() {
    if [[ -f "$INSTALL_PATH" ]]; then
        # استفاده از SCRIPT_VERSION
        local current_ver=$(grep -m1 "^readonly SCRIPT_VERSION=" "$INSTALL_PATH" 2>/dev/null | cut -d'"' -f2)

        # اگر با فرمت قدیمی بود
        if [[ -z "$current_ver" ]]; then
            current_ver=$(grep -m1 "^readonly VERSION=" "$INSTALL_PATH" 2>/dev/null | cut -d'"' -f2)
        fi

        if [[ -n "$current_ver" ]]; then
            echo ""
            printf "    ${C}┌─────────────────────────────────────────────────────────┐${N}\n"
            printf "    ${C}│${N}  ${Y}نسخه فعلی نصب شده:${N} ${W}v%-33s${N}${C}│${N}\n" "$current_ver"
            printf "    ${C}│${N}  ${G}نسخه جدید:${N} ${W}v%-40s${N}${C}│${N}\n" "$SCRIPT_VERSION"
            printf "    ${C}└─────────────────────────────────────────────────────────┘${N}\n"
            echo ""

            # مقایسه نسخه‌ها
            if [[ "$current_ver" == "$SCRIPT_VERSION" ]]; then
                print_info "نسخه فعلی به‌روز است"
                echo ""
                read -p "$(printf "    ${Y}بازنصب شود؟ [y/N]: ${N}")" reinstall
                if [[ ! "$reinstall" =~ ^[Yy]$ ]]; then
                    echo ""
                    print_info "در حال اجرای نسخه فعلی..."
                    sleep 1
                    exec "$INSTALL_PATH"
                    exit 0
                fi
            else
                read -p "$(printf "    ${Y}به‌روزرسانی به نسخه جدید؟ [Y/n]: ${N}")" update_choice
                if [[ "$update_choice" =~ ^[Nn]$ ]]; then
                    echo ""
                    print_info "در حال اجرای نسخه فعلی..."
                    sleep 1
                    exec "$INSTALL_PATH"
                    exit 0
                fi
            fi

            # بکاپ نسخه قبلی
            echo ""
            print_info "ایجاد بکاپ از نسخه قبلی..."
            mkdir -p "$BACKUP_DIR"
            cp "$INSTALL_PATH" "${BACKUP_DIR}/sshsaeed_v${current_ver}_$(date +%Y%m%d_%H%M%S).backup" 2>/dev/null
            print_ok "بکاپ ایجاد شد"
        fi
    fi
}

# ═══════════════════════════════════════════════════════════════════════════════
#                         دانلود اسکریپت اصلی
# ═══════════════════════════════════════════════════════════════════════════════
download_script() {
    print_info "دانلود اسکریپت اصلی v${SCRIPT_VERSION}..."
    echo ""

    local download_success=false
    local temp_file="/tmp/sshsaeed_download_$$.sh"

    # ═══════ روش 1: curl از main branch ═══════
    print_info "تلاش 1: دانلود از GitHub (main branch)..."
    if curl -fsSL --connect-timeout 15 --max-time 60 "$SCRIPT_URL" -o "$temp_file" 2>/dev/null; then
        if [[ -s "$temp_file" ]] && head -1 "$temp_file" | grep -q "bash"; then
            # بررسی نسخه فایل دانلود شده
            local dl_version=$(grep -m1 "^readonly SCRIPT_VERSION=" "$temp_file" 2>/dev/null | cut -d'"' -f2)
            if [[ -n "$dl_version" ]]; then
                download_success=true
                print_ok "دانلود از GitHub (main) موفق - نسخه: $dl_version"
            fi
        fi
    fi

    # ═══════ روش 2: curl از master branch ═══════
    if [[ "$download_success" != "true" ]]; then
        print_warn "تلاش 2: دانلود از GitHub (master branch)..."
        if curl -fsSL --connect-timeout 15 --max-time 60 "$BACKUP_URL" -o "$temp_file" 2>/dev/null; then
            if [[ -s "$temp_file" ]] && head -1 "$temp_file" | grep -q "bash"; then
                download_success=true
                print_ok "دانلود از GitHub (master) موفق"
            fi
        fi
    fi

    # ═══════ روش 3: wget ═══════
    if [[ "$download_success" != "true" ]] && command -v wget &>/dev/null; then
        print_warn "تلاش 3: دانلود با wget..."
        if wget -q --timeout=15 --tries=2 -O "$temp_file" "$SCRIPT_URL" 2>/dev/null; then
            if [[ -s "$temp_file" ]] && head -1 "$temp_file" | grep -q "bash"; then
                download_success=true
                print_ok "دانلود با wget موفق"
            fi
        fi
    fi

    # ═══════ روش 4: curl بدون SSL verification ═══════
    if [[ "$download_success" != "true" ]]; then
        print_warn "تلاش 4: دانلود بدون تأیید SSL..."
        if curl -fsSLk --connect-timeout 15 --max-time 60 "$SCRIPT_URL" -o "$temp_file" 2>/dev/null; then
            if [[ -s "$temp_file" ]] && head -1 "$temp_file" | grep -q "bash"; then
                download_success=true
                print_ok "دانلود بدون SSL موفق"
            fi
        fi
    fi

    # بررسی نهایی
    echo ""
    if [[ "$download_success" == "true" ]]; then
        # انتقال به محل نصب
        mv "$temp_file" "$INSTALL_PATH"
        chmod +x "$INSTALL_PATH"
        
        # ایجاد لینک sshsaeed
        ln -sf "$INSTALL_PATH" /usr/local/bin/sshsaeed 2>/dev/null
        
        print_ok "اسکریپت با موفقیت نصب شد"
        return 0
    else
        rm -f "$temp_file"
        print_err "دانلود ناموفق بود"
        echo ""
        printf "    ${Y}راه‌حل‌های پیشنهادی:${N}\n"
        printf "    ${GR}1.${N} اتصال اینترنت را بررسی کنید\n"
        printf "    ${GR}2.${N} DNS را تغییر دهید: ${W}echo 'nameserver 8.8.8.8' > /etc/resolv.conf${N}\n"
        printf "    ${GR}3.${N} دستی دانلود کنید:\n"
        printf "       ${C}curl -LO ${SCRIPT_URL}${N}\n"
        printf "       ${C}chmod +x sshsaeed.sh && mv sshsaeed.sh ${INSTALL_PATH}${N}\n"
        echo ""
        return 1
    fi
}

# ═══════════════════════════════════════════════════════════════════════════════
#                         تنظیم دسترسی‌ها
# ═══════════════════════════════════════════════════════════════════════════════
set_permissions() {
    print_info "تنظیم دسترسی‌ها..."

    # اطمینان از اجرایی بودن
    chmod +x "$INSTALL_PATH"

    # ایجاد دایرکتوری‌های مورد نیاز
    mkdir -p "$CONFIG_DIR" "$BACKUP_DIR" /root/.ssh
    chmod 700 "$CONFIG_DIR" /root/.ssh
    chmod 755 "$BACKUP_DIR"

    # ایجاد فایل لاگ
    touch "$LOG_FILE"
    chmod 600 "$LOG_FILE"

    print_ok "دسترسی‌ها تنظیم شدند"
}

# ═══════════════════════════════════════════════════════════════════════════════
#                         نمایش اطلاعات پایانی
# ═══════════════════════════════════════════════════════════════════════════════
show_completion() {
    echo ""
    line
    printf "    ${G}✓ نصب با موفقیت انجام شد!${N}\n"
    line
    echo ""
    
    printf "    ${C}┌─────────────────────────────────────────────────────────┐${N}\n"
    printf "    ${C}│${N}  ${W}اطلاعات نصب${N}                                           ${C}│${N}\n"
    printf "    ${C}├─────────────────────────────────────────────────────────┤${N}\n"
    printf "    ${C}│${N}  نسخه: ${G}%-46s${N} ${C}│${N}\n" "v${SCRIPT_VERSION}"
    printf "    ${C}│${N}  مسیر: ${G}%-46s${N} ${C}│${N}\n" "$INSTALL_PATH"
    printf "    ${C}│${N}  کانفیگ: ${G}%-44s${N} ${C}│${N}\n" "$CONFIG_DIR"
    printf "    ${C}└─────────────────────────────────────────────────────────┘${N}\n"
    echo ""
    
    printf "    ${W}ویژگی‌های نسخه 6.0:${N}\n"
    printf "    ${GR}•${N} ساختار تانل جدید (همه پورت‌ها در هر تانل)\n"
    printf "    ${GR}•${N} فعال‌سازی خودکار BBR\n"
    printf "    ${GR}•${N} افزایش Ulimit به 1,048,576\n"
    printf "    ${GR}•${N} بهینه‌سازی کرنل برای عملکرد بالا\n"
    printf "    ${GR}•${N} HAProxy با Load Balancing\n"
    echo ""
    
    printf "    ${Y}برای اجرا:${N}\n"
    printf "    ${W}sshsaeed${N}\n"
    echo ""
    
    line
}

# ═══════════════════════════════════════════════════════════════════════════════
#                         تابع اصلی
# ═══════════════════════════════════════════════════════════════════════════════
main() {
    show_banner
    
    local step=0
    local total_steps=5
    
    # مرحله 1: بررسی root
    ((step++))
    print_step "$step" "$total_steps" "بررسی دسترسی root..."
    check_root
    print_ok "دسترسی root تأیید شد"
    echo ""
    
    # مرحله 2: بررسی سیستم‌عامل
    ((step++))
    print_step "$step" "$total_steps" "بررسی سیستم‌عامل..."
    check_os
    echo ""
    
    # مرحله 3: بررسی اینترنت
    ((step++))
    print_step "$step" "$total_steps" "بررسی اتصال..."
    if ! check_internet; then
        echo ""
        print_err "بدون اینترنت امکان نصب نیست"
        exit 1
    fi
    echo ""
    
    # مرحله 4: نصب وابستگی‌ها
    ((step++))
    print_step "$step" "$total_steps" "نصب وابستگی‌ها..."
    install_dependencies
    echo ""
    
    # بررسی نسخه موجود
    check_existing
    echo ""
    
    # مرحله 5: دانلود و نصب
    ((step++))
    print_step "$step" "$total_steps" "دانلود و نصب اسکریپت..."
    if ! download_script; then
        exit 1
    fi
    
    # تنظیم دسترسی‌ها
    set_permissions
    
    # نمایش اطلاعات پایانی
    show_completion
    
    # ثبت لاگ
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] SSHSaeed v${SCRIPT_VERSION} installed successfully" >> "$LOG_FILE"
    
    # اجرای اسکریپت
    echo ""
    read -p "$(printf "    ${Y}اسکریپت اجرا شود؟ [Y/n]: ${N}")" run_now
    if [[ ! "$run_now" =~ ^[Nn]$ ]]; then
        exec "$INSTALL_PATH"
    fi
}

# ═══════════════════════════════════════════════════════════════════════════════
#                         اجرا
# ═══════════════════════════════════════════════════════════════════════════════
main "$@"
