#!/bin/bash
# ═══════════════════════════════════════════════════════════════════════════════
#  ███████╗███████╗██╗  ██╗███████╗ █████╗ ███████╗███████╗██████╗
#  ██╔════╝██╔════╝██║  ██║██╔════╝██╔══██╗██╔════╝██╔════╝██╔══██╗
#  ███████╗███████╗███████║███████╗███████║█████╗  █████╗  ██║  ██║
#  ╚════██║╚════██║██╔══██║╚════██║██╔══██║██╔══╝  ██╔══╝  ██║  ██║
#  ███████║███████║██║  ██║███████║██║  ██║███████╗███████╗██████╔╝
#  ╚══════╝╚══════╝╚═╝  ╚═╝╚══════╝╚═╝  ╚═╝╚══════╝╚══════╝╚═════╝
# ═══════════════════════════════════════════════════════════════════════════════
#  SSHSaeed Tunnel Manager - Installer v5.0
#  GitHub: https://github.com/saeedkars/sshsaeed
#  Author: SSHSaeed
# ═══════════════════════════════════════════════════════════════════════════════

set -o pipefail
export LC_ALL=C
export LANG=C

# ═══════════════════════════════════════════════════════════════════════════════
#                              تنظیمات اصلی
# ═══════════════════════════════════════════════════════════════════════════════
# نکته: از SCRIPT_VERSION استفاده می‌شود تا با /etc/os-release تداخل نداشته باشد
readonly SCRIPT_VERSION="5.0"
readonly GITHUB_RAW="https://raw.githubusercontent.com/saeedkars/sshsaeed/main"
readonly INSTALL_PATH="/usr/local/bin/sshsaeed"
readonly CONFIG_DIR="/etc/sshsaeed"
readonly LOG_FILE="/var/log/sshsaeed.log"
readonly BACKUP_DIR="$CONFIG_DIR/backups"

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

# ═══════════════════════════════════════════════════════════════════════════════
#                              توابع نمایش
# ═══════════════════════════════════════════════════════════════════════════════
print_banner() {
    clear
    printf "${C}"
    cat << 'EOF'

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
    printf "    ${W}SSH Tunnel Manager - Installer v${SCRIPT_VERSION}${N}\n"
    printf "    ${GR}────────────────────────────────────────────${N}\n\n"
}

print_step() {
    printf "    ${C}[${1}/${2}]${N} ${3}\n"
}

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

# ═══════════════════════════════════════════════════════════════════════════════
#                              توابع سیستمی
# ═══════════════════════════════════════════════════════════════════════════════
check_root() {
    if [[ $EUID -ne 0 ]]; then
        print_err "این اسکریپت نیاز به دسترسی root دارد"
        printf "    ${Y}اجرا کنید:${N} sudo bash install.sh\n"
        exit 1
    fi
}

# تابع اصلاح‌شده - بدون تداخل با /etc/os-release
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
        return 0
    elif [[ -f /etc/redhat-release ]]; then
        print_warn "سیستم RedHat - ممکن است نیاز به تنظیمات اضافی باشد"
        return 0
    else
        print_warn "سیستم‌عامل ناشناخته - ادامه با احتیاط"
        return 0
    fi
}

check_internet() {
    print_info "بررسی اتصال اینترنت..."
    
    if curl -s --connect-timeout 5 https://google.com > /dev/null 2>&1; then
        print_ok "اتصال اینترنت برقرار است"
        return 0
    elif curl -s --connect-timeout 5 https://github.com > /dev/null 2>&1; then
        print_ok "اتصال اینترنت برقرار است"
        return 0
    else
        print_err "اتصال اینترنت برقرار نیست"
        return 1
    fi
}

# ═══════════════════════════════════════════════════════════════════════════════
#                              نصب پکیج‌ها
# ═══════════════════════════════════════════════════════════════════════════════
detect_package_manager() {
    if command -v apt-get &> /dev/null; then
        echo "apt"
    elif command -v yum &> /dev/null; then
        echo "yum"
    elif command -v dnf &> /dev/null; then
        echo "dnf"
    elif command -v apk &> /dev/null; then
        echo "apk"
    else
        echo "unknown"
    fi
}

install_packages() {
    print_info "نصب پکیج‌های مورد نیاز..."
    echo ""
    
    local pm=$(detect_package_manager)
    local packages=(openssh-client openssh-server autossh haproxy sshpass curl wget net-tools)
    
    case $pm in
        apt)
            export DEBIAN_FRONTEND=noninteractive
            apt-get update -qq > /dev/null 2>&1
            
            for pkg in "${packages[@]}"; do
                printf "    ${GR}نصب ${pkg}...${N}"
                if dpkg -l "$pkg" &> /dev/null; then
                    printf "\r    ${G}[✓]${N} ${pkg} (از قبل نصب)\n"
                else
                    if apt-get install -y -qq "$pkg" > /dev/null 2>&1; then
                        printf "\r    ${G}[✓]${N} ${pkg} نصب شد\n"
                    else
                        printf "\r    ${Y}[!]${N} ${pkg} نصب نشد (ادامه...)\n"
                    fi
                fi
            done
            ;;
        yum|dnf)
            $pm update -y -q > /dev/null 2>&1
            for pkg in "${packages[@]}"; do
                printf "    ${GR}نصب ${pkg}...${N}"
                if $pm install -y -q "$pkg" > /dev/null 2>&1; then
                    printf "\r    ${G}[✓]${N} ${pkg}\n"
                else
                    printf "\r    ${Y}[!]${N} ${pkg} (خطا)\n"
                fi
            done
            ;;
        apk)
            apk update > /dev/null 2>&1
            for pkg in "${packages[@]}"; do
                apk add --no-cache "$pkg" > /dev/null 2>&1
            done
            ;;
        *)
            print_err "پکیج منیجر شناسایی نشد"
            print_info "لطفاً دستی نصب کنید: openssh-server autossh haproxy curl wget"
            ;;
    esac
    
    echo ""
    print_ok "پکیج‌ها بررسی شدند"
}

# ═══════════════════════════════════════════════════════════════════════════════
#                              دانلود و نصب اسکریپت اصلی
# ═══════════════════════════════════════════════════════════════════════════════
download_main_script() {
    print_info "دانلود اسکریپت اصلی..."
    
    # دانلود فایل اصلی
    if curl -fsSL "${GITHUB_RAW}/sshsaeed.sh" -o "${INSTALL_PATH}" 2>/dev/null; then
        print_ok "اسکریپت دانلود شد"
    else
        # اگر فایل sshsaeed.sh نبود، از install.sh استفاده کن
        if curl -fsSL "${GITHUB_RAW}/install.sh" -o "${INSTALL_PATH}" 2>/dev/null; then
            print_ok "اسکریپت دانلود شد (از install.sh)"
        else
            print_err "خطا در دانلود - تلاش با لینک جایگزین..."
            
            # لینک جایگزین
            if curl -fsSL "https://raw.githubusercontent.com/saeedkars/sshsaeed/main/install.sh" -o "${INSTALL_PATH}" 2>/dev/null; then
                print_ok "اسکریپت از لینک جایگزین دانلود شد"
            else
                print_err "دانلود ناموفق بود"
                return 1
            fi
        fi
    fi
    
    return 0
}

fix_script_variables() {
    print_info "اصلاح متغیرها برای سازگاری..."
    
    if [[ -f "${INSTALL_PATH}" ]]; then
        # اصلاح متغیر VERSION به SCRIPT_VERSION
        sed -i 's/readonly VERSION=/readonly SCRIPT_VERSION=/g' "${INSTALL_PATH}"
        sed -i 's/\${VERSION}/\${SCRIPT_VERSION}/g' "${INSTALL_PATH}"
        sed -i 's/\$VERSION/\$SCRIPT_VERSION/g' "${INSTALL_PATH}"
        
        # اصلاح تابع get_os_info - جایگزینی source با grep
        sed -i 's/\. \/etc\/os-release/# os-release loaded safely/g' "${INSTALL_PATH}"
        sed -i 's/source \/etc\/os-release/# os-release loaded safely/g' "${INSTALL_PATH}"
        
        # اصلاح استفاده از متغیرهای os-release
        sed -i 's/echo "\$NAME \$VERSION_ID"/os_n=$(grep "^NAME=" \/etc\/os-release 2>\/dev\/null | cut -d= -f2 | tr -d \x27"\x27); os_v=$(grep "^VERSION_ID=" \/etc\/os-release 2>\/dev\/null | cut -d= -f2 | tr -d \x27"\x27); echo "\$os_n \$os_v"/g' "${INSTALL_PATH}"
        
        print_ok "متغیرها اصلاح شدند"
    else
        print_err "فایل اسکریپت یافت نشد"
        return 1
    fi
    
    return 0
}

set_permissions() {
    print_info "تنظیم دسترسی‌ها..."
    
    chmod +x "${INSTALL_PATH}"
    
    # ایجاد دایرکتوری‌های مورد نیاز
    mkdir -p "${CONFIG_DIR}" "${BACKUP_DIR}" /root/.ssh
    chmod 700 "${CONFIG_DIR}" /root/.ssh
    
    # ایجاد فایل لاگ
    touch "${LOG_FILE}"
    chmod 600 "${LOG_FILE}"
    
    print_ok "دسترسی‌ها تنظیم شدند"
}

# ═══════════════════════════════════════════════════════════════════════════════
#                              تنظیمات سرویس‌ها
# ═══════════════════════════════════════════════════════════════════════════════
configure_ssh() {
    print_info "پیکربندی SSH..."
    
    local sshd_config="/etc/ssh/sshd_config"
    
    if [[ -f "$sshd_config" ]]; then
        # بکاپ
        cp "$sshd_config" "${BACKUP_DIR}/sshd_config.backup.$(date +%s)" 2>/dev/null
        
        # فعال‌سازی GatewayPorts
        if ! grep -q "^GatewayPorts yes" "$sshd_config"; then
            echo "" >> "$sshd_config"
            echo "# Added by SSHSaeed" >> "$sshd_config"
            echo "GatewayPorts yes" >> "$sshd_config"
            echo "TCPKeepAlive yes" >> "$sshd_config"
            echo "ClientAliveInterval 30" >> "$sshd_config"
            echo "ClientAliveCountMax 10" >> "$sshd_config"
        fi
        
        # ری‌استارت SSH
        if systemctl is-active --quiet sshd 2>/dev/null; then
            systemctl restart sshd
        elif systemctl is-active --quiet ssh 2>/dev/null; then
            systemctl restart ssh
        fi
        
        print_ok "SSH پیکربندی شد"
    fi
}

configure_haproxy() {
    print_info "بررسی HAProxy..."
    
    if systemctl is-active --quiet haproxy 2>/dev/null; then
        print_ok "HAProxy فعال است"
    else
        systemctl enable haproxy 2>/dev/null
        print_ok "HAProxy فعال شد"
    fi
}

# ═══════════════════════════════════════════════════════════════════════════════
#                              ایجاد alias و شورتکات
# ═══════════════════════════════════════════════════════════════════════════════
create_shortcuts() {
    print_info "ایجاد شورتکات‌ها..."
    
    # اضافه کردن به PATH اگر نیست
    if [[ ":$PATH:" != *":/usr/local/bin:"* ]]; then
        echo 'export PATH=$PATH:/usr/local/bin' >> /etc/profile
    fi
    
    # ایجاد alias در bashrc
    local bashrc="/root/.bashrc"
    if [[ -f "$bashrc" ]]; then
        if ! grep -q "alias sshsaeed=" "$bashrc"; then
            echo "" >> "$bashrc"
            echo "# SSHSaeed Tunnel Manager" >> "$bashrc"
            echo "alias sshsaeed='/usr/local/bin/sshsaeed'" >> "$bashrc"
        fi
    fi
    
    # ایجاد symlink
    if [[ -f "${INSTALL_PATH}" ]] && [[ ! -L "/usr/bin/sshsaeed" ]]; then
        ln -sf "${INSTALL_PATH}" /usr/bin/sshsaeed 2>/dev/null
    fi
    
    print_ok "شورتکات‌ها ایجاد شدند"
}

# ═══════════════════════════════════════════════════════════════════════════════
#                              نمایش اطلاعات نهایی
# ═══════════════════════════════════════════════════════════════════════════════
show_completion() {
    echo ""
    printf "    ${G}╔═══════════════════════════════════════════════════════════╗${N}\n"
    printf "    ${G}║                                                           ║${N}\n"
    printf "    ${G}║${N}     ${W}✓ نصب با موفقیت انجام شد!${N}                           ${G}║${N}\n"
    printf "    ${G}║                                                           ║${N}\n"
    printf "    ${G}╠═══════════════════════════════════════════════════════════╣${N}\n"
    printf "    ${G}║${N}                                                           ${G}║${N}\n"
    printf "    ${G}║${N}  ${Y}برای ورود به پنل مدیریت تانل:${N}                         ${G}║${N}\n"
    printf "    ${G}║${N}                                                           ${G}║${N}\n"
    printf "    ${G}║${N}      ${C}${BOLD}sshsaeed${N}                                           ${G}║${N}\n"
    printf "    ${G}║${N}                                                           ${G}║${N}\n"
    printf "    ${G}║${N}  ${GR}یا:${N}  ${C}/usr/local/bin/sshsaeed${N}                         ${G}║${N}\n"
    printf "    ${G}║${N}                                                           ${G}║${N}\n"
    printf "    ${G}╠═══════════════════════════════════════════════════════════╣${N}\n"
    printf "    ${G}║${N}                                                           ${G}║${N}\n"
    printf "    ${G}║${N}  ${M}مسیر نصب:${N}    /usr/local/bin/sshsaeed                  ${G}║${N}\n"
    printf "    ${G}║${N}  ${M}تنظیمات:${N}     /etc/sshsaeed/                           ${G}║${N}\n"
    printf "    ${G}║${N}  ${M}لاگ:${N}         /var/log/sshsaeed.log                    ${G}║${N}\n"
    printf "    ${G}║${N}  ${M}نسخه:${N}        ${SCRIPT_VERSION}                                        ${G}║${N}\n"
    printf "    ${G}║${N}                                                           ${G}║${N}\n"
    printf "    ${G}╚═══════════════════════════════════════════════════════════╝${N}\n"
    echo ""
}

# ═══════════════════════════════════════════════════════════════════════════════
#                              تابع اصلی
# ═══════════════════════════════════════════════════════════════════════════════
main() {
    print_banner
    
    local total_steps=8
    local current_step=0
    
    # مرحله 1: بررسی root
    ((current_step++))
    print_step $current_step $total_steps "بررسی دسترسی root"
    check_root
    print_ok "دسترسی root تأیید شد"
    echo ""
    
    # مرحله 2: بررسی سیستم‌عامل
    ((current_step++))
    print_step $current_step $total_steps "بررسی سیستم‌عامل"
    check_os
    echo ""
    
    # مرحله 3: بررسی اینترنت
    ((current_step++))
    print_step $current_step $total_steps "بررسی اتصال اینترنت"
    if ! check_internet; then
        print_err "بدون اینترنت امکان نصب وجود ندارد"
        exit 1
    fi
    echo ""
    
    # مرحله 4: نصب پکیج‌ها
    ((current_step++))
    print_step $current_step $total_steps "نصب پکیج‌های مورد نیاز"
    install_packages
    echo ""
    
    # مرحله 5: دانلود اسکریپت
    ((current_step++))
    print_step $current_step $total_steps "دانلود اسکریپت اصلی"
    if ! download_main_script; then
        print_err "خطا در دانلود - نصب متوقف شد"
        exit 1
    fi
    echo ""
    
    # مرحله 6: اصلاح متغیرها
    ((current_step++))
    print_step $current_step $total_steps "اصلاح سازگاری"
    fix_script_variables
    set_permissions
    echo ""
    
    # مرحله 7: پیکربندی سرویس‌ها
    ((current_step++))
    print_step $current_step $total_steps "پیکربندی سرویس‌ها"
    configure_ssh
    configure_haproxy
    echo ""
    
    # مرحله 8: ایجاد شورتکات
    ((current_step++))
    print_step $current_step $total_steps "ایجاد شورتکات‌ها"
    create_shortcuts
    echo ""
    
    # نمایش اطلاعات نهایی
    show_completion
    
    # پرسش برای اجرای پنل
    printf "    ${Y}آیا می‌خواهید پنل را اجرا کنید؟ [Y/n]:${N} "
    read -r run_panel
    
    if [[ "$run_panel" != "n" ]] && [[ "$run_panel" != "N" ]]; then
        echo ""
        exec "${INSTALL_PATH}"
    fi
}

# اجرای تابع اصلی
main "$@"
