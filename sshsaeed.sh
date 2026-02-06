#!/bin/bash
###########################################
#         SSHSaeed Tunnel Manager         #
#              Version 2.0                #
#      Optimized & Resource Efficient     #
#         github.com/saeedkars            #
###########################################

# تنظیمات امنیتی و بهینه
set -o pipefail
export LC_ALL=C

# ═══════════════════════════════════════
#              ثابت‌های سیستم
# ═══════════════════════════════════════
readonly VERSION="2.0"
readonly SCRIPT_NAME="sshsaeed"
readonly CONFIG_DIR="/etc/sshsaeed"
readonly CONFIG_FILE="${CONFIG_DIR}/config.conf"
readonly TUNNELS_FILE="${CONFIG_DIR}/tunnels.conf"
readonly BACKUP_DIR="${CONFIG_DIR}/backups"
readonly LOG_FILE="/var/log/sshsaeed.log"
readonly SSH_DIR="/root/.ssh"
readonly KEY_FILE="${SSH_DIR}/sshsaeed_key"

# ═══════════════════════════════════════
#              کدهای رنگ
# ═══════════════════════════════════════
readonly R=$'\e[31m'      # قرمز
readonly G=$'\e[32m'      # سبز
readonly Y=$'\e[33m'      # زرد
readonly B=$'\e[34m'      # آبی
readonly M=$'\e[35m'      # بنفش
readonly C=$'\e[36m'      # فیروزه‌ای
readonly W=$'\e[97m'      # سفید
readonly N=$'\e[0m'       # ریست
readonly BD=$'\e[1m'      # بولد

# ═══════════════════════════════════════
#            توابع کمکی بهینه
# ═══════════════════════════════════════

# لاگ با سطح‌بندی
log() {
    local level="$1" msg="$2"
    printf '%s [%s] %s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$level" "$msg" >> "$LOG_FILE" 2>/dev/null
}

# پیام‌های رنگی
msg_ok()   { printf "${G}✓${N} %s\n" "$1"; }
msg_err()  { printf "${R}✗${N} %s\n" "$1"; }
msg_info() { printf "${C}ℹ${N} %s\n" "$1"; }
msg_warn() { printf "${Y}⚠${N} %s\n" "$1"; }

# جداکننده
line() { printf "${C}%s${N}\n" "════════════════════════════════════════════"; }

# پاک کردن صفحه با حفظ بافر
cls() { printf '\e[2J\e[H'; }

# ═══════════════════════════════════════
#               بنر اصلی
# ═══════════════════════════════════════
banner() {
    cls
    cat << 'EOF'
   ███████╗███████╗██╗  ██╗    ████████╗██╗   ██╗███╗   ██╗
   ██╔════╝██╔════╝██║  ██║    ╚══██╔══╝██║   ██║████╗  ██║
   ███████╗███████╗███████║       ██║   ██║   ██║██╔██╗ ██║
   ╚════██║╚════██║██╔══██║       ██║   ██║   ██║██║╚██╗██║
   ███████║███████║██║  ██║       ██║   ╚██████╔╝██║ ╚████║
   ╚══════╝╚══════╝╚═╝  ╚═╝       ╚═╝    ╚═════╝ ╚═╝  ╚═══╝
EOF
    printf "${C}%s${N}\n" "        ══════════════════════════════════════"
    printf "${W}           SSH Tunnel Manager v${VERSION}${N}\n"
    printf "${Y}              github.com/saeedkars${N}\n"
    printf "${C}%s${N}\n\n" "        ══════════════════════════════════════"
}

# ═══════════════════════════════════════
#            چک دسترسی روت
# ═══════════════════════════════════════
check_root() {
    if [[ $EUID -ne 0 ]]; then
        msg_err "این اسکریپت نیاز به دسترسی root دارد"
        exit 1
    fi
}

# ═══════════════════════════════════════
#          ایجاد دایرکتوری‌ها
# ═══════════════════════════════════════
init_dirs() {
    local dir
    for dir in "$CONFIG_DIR" "$BACKUP_DIR" "$SSH_DIR"; do
        [[ -d "$dir" ]] || mkdir -p "$dir"
    done
    chmod 700 "$SSH_DIR" 2>/dev/null
    touch "$LOG_FILE" "$CONFIG_FILE" "$TUNNELS_FILE" 2>/dev/null
}

# ═══════════════════════════════════════
#         تشخیص توزیع لینوکس
# ═══════════════════════════════════════
detect_os() {
    if [[ -f /etc/os-release ]]; then
        . /etc/os-release
        OS_ID="${ID,,}"
        OS_VER="${VERSION_ID}"
    elif command -v lsb_release &>/dev/null; then
        OS_ID=$(lsb_release -si | tr '[:upper:]' '[:lower:]')
        OS_VER=$(lsb_release -sr)
    else
        OS_ID="unknown"
        OS_VER="0"
    fi
}

# ═══════════════════════════════════════
#          نصب پکیج‌های مورد نیاز
# ═══════════════════════════════════════
install_deps() {
    local pkgs=("openssh-server" "openssh-client" "autossh" "curl" "net-tools")
    local need_install=()
    local pkg
    
    msg_info "بررسی پکیج‌های مورد نیاز..."
    
    for pkg in "${pkgs[@]}"; do
        if ! dpkg -l "$pkg" &>/dev/null; then
            need_install+=("$pkg")
        fi
    done
    
    if [[ ${#need_install[@]} -gt 0 ]]; then
        msg_info "نصب: ${need_install[*]}"
        apt-get update -qq
        apt-get install -y -qq "${need_install[@]}"
        msg_ok "پکیج‌ها نصب شدند"
    else
        msg_ok "همه پکیج‌ها موجود هستند"
    fi
}

# ═══════════════════════════════════════
#         تشخیص نوع سرور
# ═══════════════════════════════════════
detect_server_type() {
    local my_ip iran_test
    
    # دریافت IP عمومی
    my_ip=$(curl -s --max-time 5 ifconfig.me 2>/dev/null || \
            curl -s --max-time 5 icanhazip.com 2>/dev/null || \
            curl -s --max-time 5 ipinfo.io/ip 2>/dev/null)
    
    [[ -z "$my_ip" ]] && { echo "unknown"; return; }
    
    # تست اتصال به سایت ایرانی
    iran_test=$(curl -s --max-time 3 -o /dev/null -w "%{http_code}" http://www.google.com 2>/dev/null)
    
    if [[ "$iran_test" != "200" ]]; then
        echo "iran"
    else
        # بررسی با رنج IP ایران
        if curl -s --max-time 5 "https://ipapi.co/${my_ip}/country/" 2>/dev/null | grep -qi "IR"; then
            echo "iran"
        else
            echo "kharej"
        fi
    fi
}

# ═══════════════════════════════════════
#            تست پینگ
# ═══════════════════════════════════════
test_ping() {
    local host="$1"
    local count="${2:-3}"
    
    if ping -c "$count" -W 2 "$host" &>/dev/null; then
        return 0
    fi
    return 1
}

# ═══════════════════════════════════════
#        تست پشتیبانی AES-NI (محلی)
# ═══════════════════════════════════════
test_aes_local() {
    local aes_support=0
    local openssl_aes=0
    
    # چک پشتیبانی CPU از AES-NI
    if grep -q "aes" /proc/cpuinfo 2>/dev/null; then
        aes_support=1
    fi
    
    # چک OpenSSL
    if openssl engine 2>/dev/null | grep -qi "aes"; then
        openssl_aes=1
    fi
    
    if [[ $aes_support -eq 1 ]]; then
        msg_ok "CPU از AES-NI پشتیبانی می‌کند"
        echo "aes128-gcm@openssh.com"
        return 0
    else
        msg_warn "AES-NI پشتیبانی نمی‌شود - استفاده از ChaCha20"
        echo "chacha20-poly1305@openssh.com"
        return 1
    fi
}

# ═══════════════════════════════════════
#         تست اتصال SSH
# ═══════════════════════════════════════
test_ssh_connection() {
    local host="$1"
    local port="${2:-22}"
    local user="${3:-root}"
    local timeout="${4:-5}"
    
    # تست پورت باز
    if ! timeout "$timeout" bash -c "echo >/dev/tcp/$host/$port" 2>/dev/null; then
        msg_err "پورت $port روی $host باز نیست"
        return 1
    fi
    
    # تست SSH با کلید
    if [[ -f "$KEY_FILE" ]]; then
        if ssh -o BatchMode=yes -o ConnectTimeout="$timeout" \
               -o StrictHostKeyChecking=no -i "$KEY_FILE" \
               -p "$port" "${user}@${host}" "exit" 2>/dev/null; then
            msg_ok "اتصال SSH برقرار است"
            return 0
        fi
    fi
    
    msg_warn "اتصال SSH نیاز به تنظیم کلید دارد"
    return 2
}

# ═══════════════════════════════════════
#         خواندن تنظیمات
# ═══════════════════════════════════════
load_config() {
    [[ -f "$CONFIG_FILE" ]] && source "$CONFIG_FILE"
}

# ═══════════════════════════════════════
#         ذخیره تنظیمات
# ═══════════════════════════════════════
save_config() {
    cat > "$CONFIG_FILE" << CONF
# SSHSaeed Configuration
SERVER_TYPE="${SERVER_TYPE:-}"
KHAREJ_IP="${KHAREJ_IP:-}"
KHAREJ_PORT="${KHAREJ_PORT:-22}"
IRAN_IP="${IRAN_IP:-}"
TUNNEL_USER="${TUNNEL_USER:-tunnel}"
CONF
    log "INFO" "Config saved"
}

# ═══════════════════════════════════════
#           دریافت IP سرور
# ═══════════════════════════════════════
get_server_ip() {
    local ip
    ip=$(curl -s --max-time 5 ifconfig.me 2>/dev/null)
    [[ -z "$ip" ]] && ip=$(hostname -I 2>/dev/null | awk '{print $1}')
    echo "$ip"
}

# ═══════════════════════════════════════
#           اعتبارسنجی IP
# ═══════════════════════════════════════
valid_ip() {
    local ip="$1"
    local regex='^([0-9]{1,3}\.){3}[0-9]{1,3}$'
    
    if [[ $ip =~ $regex ]]; then
        local IFS='.'
        read -ra octets <<< "$ip"
        for octet in "${octets[@]}"; do
            [[ $octet -gt 255 ]] && return 1
        done
        return 0
    fi
    return 1
}
# ═══════════════════════════════════════
#          تنظیم سرور خارج
# ═══════════════════════════════════════
setup_kharej() {
    banner
    line
    printf "${W}        تنظیمات سرور خارج (Kharej)${N}\n"
    line
    echo ""
    
    SERVER_TYPE="kharej"
    local my_ip=$(get_server_ip)
    
    msg_info "IP این سرور: ${W}${my_ip}${N}"
    echo ""
    
    # دریافت IP سرور ایران
    while true; do
        read -p "$(printf "${C}IP سرور ایران: ${N}")" IRAN_IP
        if valid_ip "$IRAN_IP"; then
            break
        fi
        msg_err "IP نامعتبر است"
    done
    
    # پورت SSH
    read -p "$(printf "${C}پورت SSH [22]: ${N}")" KHAREJ_PORT
    KHAREJ_PORT=${KHAREJ_PORT:-22}
    
    # نام کاربر تانل
    read -p "$(printf "${C}نام کاربر تانل [tunnel]: ${N}")" TUNNEL_USER
    TUNNEL_USER=${TUNNEL_USER:-tunnel}
    
    echo ""
    msg_info "در حال پیکربندی..."
    echo ""
    
    # 1. ایجاد کاربر تانل
    if ! id "$TUNNEL_USER" &>/dev/null; then
        useradd -m -s /bin/bash "$TUNNEL_USER" 2>/dev/null
        msg_ok "کاربر $TUNNEL_USER ایجاد شد"
    else
        msg_info "کاربر $TUNNEL_USER موجود است"
    fi
    
    # 2. تنظیم SSH
    local sshd_conf="/etc/ssh/sshd_config"
    local sshd_backup="${BACKUP_DIR}/sshd_config.bak.$(date +%s)"
    
    cp "$sshd_conf" "$sshd_backup"
    
    # تنظیمات بهینه SSH
    declare -A ssh_settings=(
        ["Port"]="$KHAREJ_PORT"
        ["PermitRootLogin"]="yes"
        ["PubkeyAuthentication"]="yes"
        ["PasswordAuthentication"]="yes"
        ["GatewayPorts"]="yes"
        ["AllowTcpForwarding"]="yes"
        ["TCPKeepAlive"]="yes"
        ["ClientAliveInterval"]="30"
        ["ClientAliveCountMax"]="3"
        ["MaxSessions"]="100"
        ["MaxStartups"]="100:30:200"
    )
    
    local key val
    for key in "${!ssh_settings[@]}"; do
        val="${ssh_settings[$key]}"
        if grep -q "^#*${key}" "$sshd_conf"; then
            sed -i "s/^#*${key}.*/${key} ${val}/" "$sshd_conf"
        else
            echo "${key} ${val}" >> "$sshd_conf"
        fi
    done
    
    msg_ok "SSH پیکربندی شد"
    
    # 3. ری‌استارت SSH
    systemctl restart sshd
    msg_ok "سرویس SSH ری‌استارت شد"
    
    # 4. تنظیم فایروال
    if command -v ufw &>/dev/null; then
        ufw allow "$KHAREJ_PORT"/tcp &>/dev/null
        msg_ok "فایروال تنظیم شد"
    fi
    
    # 5. ایجاد دایرکتوری SSH برای کاربر
    local user_ssh="/home/${TUNNEL_USER}/.ssh"
    mkdir -p "$user_ssh"
    touch "${user_ssh}/authorized_keys"
    chmod 700 "$user_ssh"
    chmod 600 "${user_ssh}/authorized_keys"
    chown -R "${TUNNEL_USER}:${TUNNEL_USER}" "$user_ssh"
    
    # ذخیره تنظیمات
    KHAREJ_IP="$my_ip"
    save_config
    
    echo ""
    line
    printf "${G}✓ سرور خارج با موفقیت پیکربندی شد${N}\n"
    line
    echo ""
    printf "${Y}اطلاعات مهم:${N}\n"
    printf "  ${C}IP سرور:${N}      %s\n" "$my_ip"
    printf "  ${C}پورت SSH:${N}     %s\n" "$KHAREJ_PORT"
    printf "  ${C}کاربر تانل:${N}   %s\n" "$TUNNEL_USER"
    echo ""
    printf "${Y}مرحله بعد:${N}\n"
    printf "  ${W}در سرور ایران اسکریپت را اجرا و گزینه 2 را انتخاب کنید${N}\n"
    echo ""
    
    log "INFO" "Kharej server configured - IP: $my_ip Port: $KHAREJ_PORT"
    read -p "$(printf "${C}Enter بزنید...${N}")"
}

# ═══════════════════════════════════════
#          تنظیم سرور ایران
# ═══════════════════════════════════════
setup_iran() {
    banner
    line
    printf "${W}         تنظیمات سرور ایران (Iran)${N}\n"
    line
    echo ""
    
    SERVER_TYPE="iran"
    local my_ip=$(get_server_ip)
    
    msg_info "IP این سرور: ${W}${my_ip}${N}"
    echo ""
    
    # دریافت اطلاعات سرور خارج
    while true; do
        read -p "$(printf "${C}IP سرور خارج: ${N}")" KHAREJ_IP
        if valid_ip "$KHAREJ_IP"; then
            break
        fi
        msg_err "IP نامعتبر است"
    done
    
    read -p "$(printf "${C}پورت SSH سرور خارج [22]: ${N}")" KHAREJ_PORT
    KHAREJ_PORT=${KHAREJ_PORT:-22}
    
    read -p "$(printf "${C}نام کاربر تانل [tunnel]: ${N}")" TUNNEL_USER
    TUNNEL_USER=${TUNNEL_USER:-tunnel}
    
    echo ""
    msg_info "در حال پیکربندی..."
    echo ""
    
    # 1. تست اتصال
    printf "  ${C}→${N} تست پینگ به سرور خارج... "
    if test_ping "$KHAREJ_IP" 2; then
        printf "${G}OK${N}\n"
    else
        printf "${Y}ممکن است ICMP بلاک باشد${N}\n"
    fi
    
    # 2. تست پورت SSH
    printf "  ${C}→${N} تست پورت SSH... "
    if timeout 3 bash -c "echo >/dev/tcp/$KHAREJ_IP/$KHAREJ_PORT" 2>/dev/null; then
        printf "${G}OK${N}\n"
    else
        printf "${R}FAIL${N}\n"
        msg_err "پورت $KHAREJ_PORT روی سرور خارج باز نیست"
        read -p "$(printf "${C}ادامه بدهم؟ [y/N]: ${N}")" cont
        [[ ! "$cont" =~ ^[Yy]$ ]] && return
    fi
    
    # 3. ایجاد کلید SSH
    echo ""
    if [[ ! -f "$KEY_FILE" ]]; then
        msg_info "ایجاد کلید SSH..."
        ssh-keygen -t ed25519 -f "$KEY_FILE" -N "" -C "sshsaeed-tunnel" -q
        msg_ok "کلید SSH ایجاد شد"
    else
        msg_info "کلید SSH موجود است"
    fi
    
    # 4. نمایش کلید عمومی
    local pubkey=$(cat "${KEY_FILE}.pub")
    
    echo ""
    line
    printf "${Y}کلید عمومی (این را در سرور خارج اضافه کنید):${N}\n"
    line
    echo ""
    printf "${W}%s${N}\n" "$pubkey"
    echo ""
    line
    
    # 5. تلاش برای کپی خودکار
    echo ""
    read -p "$(printf "${C}آیا تلاش برای کپی خودکار کلید انجام شود؟ [Y/n]: ${N}")" auto_copy
    
    if [[ ! "$auto_copy" =~ ^[Nn]$ ]]; then
        msg_info "در حال کپی کلید... (رمز کاربر $TUNNEL_USER را وارد کنید)"
        
        if ssh-copy-id -i "${KEY_FILE}.pub" -p "$KHAREJ_PORT" \
           -o StrictHostKeyChecking=no "${TUNNEL_USER}@${KHAREJ_IP}" 2>/dev/null; then
            msg_ok "کلید با موفقیت کپی شد"
        else
            echo ""
            msg_warn "کپی خودکار نشد. کلید را دستی کپی کنید:"
            echo ""
            printf "${Y}در سرور خارج این دستور را اجرا کنید:${N}\n"
            echo ""
            printf "${C}echo '%s' >> /home/%s/.ssh/authorized_keys${N}\n" "$pubkey" "$TUNNEL_USER"
            echo ""
        fi
    fi
    
    # 6. تست AES
    echo ""
    msg_info "بررسی پشتیبانی AES-NI..."
    local cipher=$(test_aes_local)
    
    # ذخیره تنظیمات
    IRAN_IP="$my_ip"
    save_config
    
    echo ""
    line
    printf "${G}✓ سرور ایران با موفقیت پیکربندی شد${N}\n"
    line
    echo ""
    printf "${Y}Cipher پیشنهادی:${N} %s\n" "$cipher"
    echo ""
    
    log "INFO" "Iran server configured - Kharej: $KHAREJ_IP:$KHAREJ_PORT"
    read -p "$(printf "${C}Enter بزنید...${N}")"
}

# ═══════════════════════════════════════
#            ایجاد تانل جدید
# ═══════════════════════════════════════
create_tunnel() {
    banner
    line
    printf "${W}             ایجاد تانل جدید${N}\n"
    line
    echo ""
    
    load_config
    
    # چک تنظیمات اولیه
    if [[ -z "$KHAREJ_IP" ]]; then
        msg_err "ابتدا سرور را پیکربندی کنید"
        sleep 2
        return
    fi
    
    # چک کلید SSH
    if [[ ! -f "$KEY_FILE" ]]; then
        msg_err "کلید SSH موجود نیست. ابتدا سرور ایران را تنظیم کنید"
        sleep 2
        return
    fi
    
    printf "${Y}اطلاعات اتصال:${N}\n"
    printf "  سرور خارج: ${W}%s:%s${N}\n" "$KHAREJ_IP" "$KHAREJ_PORT"
    printf "  کاربر:     ${W}%s${N}\n" "$TUNNEL_USER"
    echo ""
    
    # انتخاب نوع تانل
    line
    printf "${Y}نوع تانل را انتخاب کنید:${N}\n"
    line
    echo ""
    printf "  ${G}1)${N} Local Forward   ${C}(پورت محلی ← سرور خارج)${N}\n"
    printf "  ${G}2)${N} Remote Forward  ${C}(سرور خارج ← پورت محلی)${N}\n"
    printf "  ${G}3)${N} Dynamic SOCKS   ${C}(پروکسی SOCKS5)${N}\n"
    printf "  ${G}4)${N} Multi-Port      ${C}(چند پورت همزمان)${N}\n"
    printf "  ${G}5)${N} Reverse Tunnel  ${C}(دسترسی به ایران از خارج)${N}\n"
    printf "  ${G}0)${N} بازگشت\n"
    echo ""
    
    read -p "$(printf "${C}انتخاب: ${N}")" ttype
    
    [[ "$ttype" == "0" ]] && return
    
    local ssh_cmd tunnel_desc local_port remote_port
    
    case $ttype in
        1) # Local Forward
            echo ""
            printf "${C}Local Forward: ترافیک پورت محلی به سرور خارج${N}\n"
            echo ""
            read -p "$(printf "${C}پورت محلی [8080]: ${N}")" local_port
            local_port=${local_port:-8080}
            read -p "$(printf "${C}پورت مقصد [${local_port}]: ${N}")" remote_port
            remote_port=${remote_port:-$local_port}
            
            ssh_cmd="-L 0.0.0.0:${local_port}:127.0.0.1:${remote_port}"
            tunnel_desc="L:${local_port}→${remote_port}"
            ;;
            
        2) # Remote Forward
            echo ""
            printf "${C}Remote Forward: پورت سرور خارج به پورت محلی${N}\n"
            echo ""
            read -p "$(printf "${C}پورت در سرور خارج [8080]: ${N}")" remote_port
            remote_port=${remote_port:-8080}
            read -p "$(printf "${C}پورت محلی [${remote_port}]: ${N}")" local_port
            local_port=${local_port:-$remote_port}
            
            ssh_cmd="-R 0.0.0.0:${remote_port}:127.0.0.1:${local_port}"
            tunnel_desc="R:${remote_port}→${local_port}"
            ;;
            
        3) # Dynamic SOCKS
            echo ""
            printf "${C}Dynamic SOCKS: ایجاد پروکسی SOCKS5${N}\n"
            echo ""
            read -p "$(printf "${C}پورت SOCKS [1080]: ${N}")" local_port
            local_port=${local_port:-1080}
            
            ssh_cmd="-D 0.0.0.0:${local_port}"
            tunnel_desc="D:SOCKS:${local_port}"
            ;;
            
        4) # Multi-Port
            echo ""
            printf "${C}Multi-Port: چند پورت را با کاما جدا کنید${N}\n"
            printf "${Y}مثال: 80,443,8080${N}\n"
            echo ""
            read -p "$(printf "${C}پورت‌ها: ${N}")" ports_input
            
            [[ -z "$ports_input" ]] && { msg_err "پورتی وارد نشد"; sleep 2; return; }
            
            ssh_cmd=""
            IFS=',' read -ra ports <<< "$ports_input"
            for p in "${ports[@]}"; do
                p=$(echo "$p" | tr -d ' ')
                ssh_cmd="$ssh_cmd -L 0.0.0.0:${p}:127.0.0.1:${p}"
            done
            tunnel_desc="M:${ports_input}"
            ;;
            
        5) # Reverse Tunnel
            echo ""
            printf "${C}Reverse Tunnel: دسترسی به این سرور از سرور خارج${N}\n"
            echo ""
            read -p "$(printf "${C}پورت در سرور خارج [2222]: ${N}")" remote_port
            remote_port=${remote_port:-2222}
            read -p "$(printf "${C}پورت SSH محلی [22]: ${N}")" local_port
            local_port=${local_port:-22}
            
            ssh_cmd="-R 0.0.0.0:${remote_port}:127.0.0.1:${local_port}"
            tunnel_desc="REV:${remote_port}→${local_port}"
            ;;
            
        *)
            msg_err "انتخاب نامعتبر"
            sleep 2
            return
            ;;
    esac
    
    echo ""
    
    # انتخاب Cipher
    line
    printf "${Y}الگوریتم رمزنگاری:${N}\n"
    line
    echo ""
    printf "  ${G}1)${N} aes128-gcm       ${C}(سریع - نیاز به AES-NI)${N}\n"
    printf "  ${G}2)${N} aes256-gcm       ${C}(امن‌تر - نیاز به AES-NI)${N}\n"
    printf "  ${G}3)${N} chacha20-poly1305 ${C}(بدون نیاز به AES-NI)${N}\n"
    printf "  ${G}4)${N} خودکار          ${C}(تشخیص بهترین)${N}\n"
    echo ""
    
    read -p "$(printf "${C}انتخاب [4]: ${N}")" cipher_choice
    cipher_choice=${cipher_choice:-4}
    
    local cipher=""
    case $cipher_choice in
        1) cipher="aes128-gcm@openssh.com" ;;
        2) cipher="aes256-gcm@openssh.com" ;;
        3) cipher="chacha20-poly1305@openssh.com" ;;
        4) cipher=$(test_aes_local 2>/dev/null) ;;
    esac
    
    # نام تانل
    echo ""
    read -p "$(printf "${C}نام تانل: ${N}")" tunnel_name
    tunnel_name=${tunnel_name:-tunnel_$(date +%s)}
    tunnel_name=$(echo "$tunnel_name" | tr ' ' '_' | tr -cd '[:alnum:]_-')
    
    # ساخت سرویس systemd
    local service_name="sshsaeed-${tunnel_name}"
    local service_file="/etc/systemd/system/${service_name}.service"
    
    local cipher_opt=""
    [[ -n "$cipher" ]] && cipher_opt="-o Ciphers=${cipher}"
    
    local full_cmd="autossh -M 0 -f -N ${ssh_cmd} ${cipher_opt} -o ServerAliveInterval=30 -o ServerAliveCountMax=3 -o StrictHostKeyChecking=no -o ExitOnForwardFailure=yes -i ${KEY_FILE} -p ${KHAREJ_PORT} ${TUNNEL_USER}@${KHAREJ_IP}"
    
    cat > "$service_file" << SVCEOF
[Unit]
Description=SSHSaeed Tunnel - ${tunnel_name}
After=network-online.target
Wants=network-online.target

[Service]
Type=forking
Environment="AUTOSSH_GATETIME=0"
Environment="AUTOSSH_POLL=60"
ExecStart=${full_cmd}
ExecReload=/bin/kill -HUP \$MAINPID
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
SVCEOF

    # فعال‌سازی سرویس
    systemctl daemon-reload
    systemctl enable "$service_name" &>/dev/null
    systemctl start "$service_name"
    
    # ذخیره در فایل تانل‌ها
    echo "${tunnel_name}|${tunnel_desc}|${KHAREJ_IP}|${cipher:-auto}|$(date '+%Y-%m-%d %H:%M')" >> "$TUNNELS_FILE"
    
    sleep 2
    echo ""
    
    # بررسی وضعیت
    if systemctl is-active --quiet "$service_name"; then
        line
        printf "${G}✓ تانل با موفقیت ایجاد شد${N}\n"
        line
        echo ""
        printf "  ${C}نام:${N}     %s\n" "$tunnel_name"
        printf "  ${C}نوع:${N}     %s\n" "$tunnel_desc"
        printf "  ${C}Cipher:${N}  %s\n" "${cipher:-پیش‌فرض}"
        printf "  ${C}وضعیت:${N}   ${G}فعال${N}\n"
    else
        msg_err "مشکل در ایجاد تانل"
        echo ""
        journalctl -u "$service_name" --no-pager -n 10
    fi
    
    echo ""
    log "INFO" "Tunnel created: $tunnel_name ($tunnel_desc)"
    read -p "$(printf "${C}Enter بزنید...${N}")"
}

# ═══════════════════════════════════════
#            لیست تانل‌ها
# ═══════════════════════════════════════
list_tunnels() {
    banner
    line
    printf "${W}            لیست تانل‌ها${N}\n"
    line
    echo ""
    
    if [[ ! -s "$TUNNELS_FILE" ]]; then
        msg_warn "هیچ تانلی ثبت نشده است"
        echo ""
        read -p "$(printf "${C}Enter بزنید...${N}")"
        return
    fi
    
    printf "${C}┌─────────────────┬──────────────────┬─────────────────┬──────────┐${N}\n"
    printf "${C}│${N} %-15s ${C}│${N} %-16s ${C}│${N} %-15s ${C}│${N} %-8s ${C}│${N}\n" "نام" "نوع" "سرور" "وضعیت"
    printf "${C}├─────────────────┼──────────────────┼─────────────────┼──────────┤${N}\n"
    
    while IFS='|' read -r name desc server cipher date; do
        [[ -z "$name" ]] && continue
        
        local status status_color
        if systemctl is-active --quiet "sshsaeed-$name" 2>/dev/null; then
            status="فعال"
            status_color="$G"
        else
            status="غیرفعال"
            status_color="$R"
        fi
        
        printf "${C}│${N} %-15s ${C}│${N} %-16s ${C}│${N} %-15s ${C}│${N} ${status_color}%-8s${N} ${C}│${N}\n" \
            "$name" "$desc" "$server" "$status"
    done < "$TUNNELS_FILE"
    
    printf "${C}└─────────────────┴──────────────────┴─────────────────┴──────────┘${N}\n"
    
    echo ""
    printf "${Y}دستورات مدیریت:${N}\n"
    printf "  ${C}systemctl status sshsaeed-<name>${N}   - مشاهده وضعیت\n"
    printf "  ${C}systemctl restart sshsaeed-<name>${N}  - ری‌استارت\n"
    printf "  ${C}systemctl stop sshsaeed-<name>${N}     - توقف\n"
    
    echo ""
    log "INFO" "Tunnels listed"
    read -p "$(printf "${C}Enter بزنید...${N}")"
}

# ═══════════════════════════════════════
#              حذف تانل
# ═══════════════════════════════════════
delete_tunnel() {
    banner
    line
    printf "${W}              حذف تانل${N}\n"
    line
    echo ""
    
    if [[ ! -s "$TUNNELS_FILE" ]]; then
        msg_warn "هیچ تانلی موجود نیست"
        echo ""
        read -p "$(printf "${C}Enter بزنید...${N}")"
        return
    fi
    
    printf "${Y}تانل‌های موجود:${N}\n"
    echo ""
    
    local -a names=()
    local i=1
    
    while IFS='|' read -r name desc server cipher date; do
        [[ -z "$name" ]] && continue
        names+=("$name")
        
        local status
        if systemctl is-active --quiet "sshsaeed-$name" 2>/dev/null; then
            status="${G}[فعال]${N}"
        else
            status="${R}[غیرفعال]${N}"
        fi
        
        printf "  ${G}%d)${N} %s ${C}(%s)${N} %b\n" "$i" "$name" "$desc" "$status"
        ((i++))
    done < "$TUNNELS_FILE"
    
    echo ""
    read -p "$(printf "${C}شماره تانل برای حذف (0=بازگشت): ${N}")" del_num
    
    [[ "$del_num" == "0" || -z "$del_num" ]] && return
    
    if [[ ! "$del_num" =~ ^[0-9]+$ ]] || [[ $del_num -lt 1 ]] || [[ $del_num -gt ${#names[@]} ]]; then
        msg_err "شماره نامعتبر"
        sleep 2
        return
    fi
    
    local target="${names[$((del_num-1))]}"
    
    echo ""
    read -p "$(printf "${R}حذف '$target'؟ [y/N]: ${N}")" confirm
    
    [[ ! "$confirm" =~ ^[Yy]$ ]] && return
    
    # توقف و حذف سرویس
    systemctl stop "sshsaeed-$target" 2>/dev/null
    systemctl disable "sshsaeed-$target" 2>/dev/null
    rm -f "/etc/systemd/system/sshsaeed-$target.service"
    systemctl daemon-reload
    
    # حذف از فایل
    grep -v "^${target}|" "$TUNNELS_FILE" > "${TUNNELS_FILE}.tmp"
    mv "${TUNNELS_FILE}.tmp" "$TUNNELS_FILE"
    
    echo ""
    msg_ok "تانل '$target' حذف شد"
    
    log "INFO" "Tunnel deleted: $target"
    sleep 2
}
# ═══════════════════════════════════════
#           وضعیت سیستم
# ═══════════════════════════════════════
system_status() {
    banner
    line
    printf "${W}            وضعیت سیستم${N}\n"
    line
    echo ""
    
    load_config
    
    # اطلاعات سرور
    printf "${Y}▸ اطلاعات سرور${N}\n"
    printf "  ${C}نوع سرور:${N}    %s\n" "${SERVER_TYPE:-تنظیم نشده}"
    printf "  ${C}IP:${N}          %s\n" "$(get_server_ip)"
    printf "  ${C}Hostname:${N}    %s\n" "$(hostname)"
    printf "  ${C}Uptime:${N}      %s\n" "$(uptime -p 2>/dev/null || uptime)"
    echo ""
    
    # وضعیت SSH
    printf "${Y}▸ سرویس SSH${N}\n"
    if systemctl is-active --quiet sshd; then
        printf "  ${C}وضعیت:${N}       ${G}فعال${N}\n"
    else
        printf "  ${C}وضعیت:${N}       ${R}غیرفعال${N}\n"
    fi
    printf "  ${C}پورت:${N}        %s\n" "$(grep -E '^Port' /etc/ssh/sshd_config 2>/dev/null | awk '{print $2}' || echo '22')"
    echo ""
    
    # وضعیت تانل‌ها
    printf "${Y}▸ تانل‌ها${N}\n"
    local total=0 active=0
    
    if [[ -s "$TUNNELS_FILE" ]]; then
        while IFS='|' read -r name rest; do
            [[ -z "$name" ]] && continue
            ((total++))
            systemctl is-active --quiet "sshsaeed-$name" && ((active++))
        done < "$TUNNELS_FILE"
    fi
    
    printf "  ${C}کل:${N}          %d\n" "$total"
    printf "  ${C}فعال:${N}        ${G}%d${N}\n" "$active"
    printf "  ${C}غیرفعال:${N}     ${R}%d${N}\n" "$((total - active))"
    echo ""
    
    # منابع سیستم
    printf "${Y}▸ منابع سیستم${N}\n"
    printf "  ${C}CPU:${N}         %s\n" "$(grep -c ^processor /proc/cpuinfo) هسته"
    printf "  ${C}RAM:${N}         %s\n" "$(free -h | awk '/^Mem:/{print $3 "/" $2}')"
    printf "  ${C}Disk:${N}        %s\n" "$(df -h / | awk 'NR==2{print $3 "/" $2 " (" $5 ")"}')"
    echo ""
    
    # پشتیبانی AES
    printf "${Y}▸ رمزنگاری${N}\n"
    if grep -q aes /proc/cpuinfo 2>/dev/null; then
        printf "  ${C}AES-NI:${N}      ${G}پشتیبانی می‌شود${N}\n"
        printf "  ${C}Cipher بهینه:${N} aes128-gcm@openssh.com\n"
    else
        printf "  ${C}AES-NI:${N}      ${Y}پشتیبانی نمی‌شود${N}\n"
        printf "  ${C}Cipher بهینه:${N} chacha20-poly1305@openssh.com\n"
    fi
    
    echo ""
    log "INFO" "System status viewed"
    read -p "$(printf "${C}Enter بزنید...${N}")"
}

# ═══════════════════════════════════════
#           تست اتصال
# ═══════════════════════════════════════
test_connection() {
    banner
    line
    printf "${W}            تست اتصال${N}\n"
    line
    echo ""
    
    load_config
    
    if [[ -z "$KHAREJ_IP" ]]; then
        msg_err "ابتدا سرور را پیکربندی کنید"
        sleep 2
        return
    fi
    
    printf "${Y}سرور مقصد:${N} %s:%s\n" "$KHAREJ_IP" "$KHAREJ_PORT"
    echo ""
    
    # 1. تست ICMP
    printf "  ${C}[1/4]${N} تست ICMP (Ping)... "
    if test_ping "$KHAREJ_IP" 3; then
        printf "${G}OK${N} "
        local ping_time=$(ping -c 1 -W 2 "$KHAREJ_IP" 2>/dev/null | grep -oP 'time=\K[\d.]+')
        printf "${C}(${ping_time}ms)${N}\n"
    else
        printf "${Y}BLOCKED${N}\n"
    fi
    
    # 2. تست پورت TCP
    printf "  ${C}[2/4]${N} تست پورت TCP... "
    if timeout 5 bash -c "echo >/dev/tcp/$KHAREJ_IP/$KHAREJ_PORT" 2>/dev/null; then
        printf "${G}OK${N}\n"
    else
        printf "${R}FAIL${N}\n"
        msg_err "پورت $KHAREJ_PORT باز نیست"
        read -p "$(printf "${C}Enter بزنید...${N}")"
        return
    fi
    
    # 3. تست SSH Banner
    printf "  ${C}[3/4]${N} تست SSH Banner... "
    local ssh_banner=$(timeout 5 bash -c "exec 3<>/dev/tcp/$KHAREJ_IP/$KHAREJ_PORT; cat <&3" 2>/dev/null | head -1)
    if [[ "$ssh_banner" == SSH-* ]]; then
        printf "${G}OK${N} ${C}(%s)${N}\n" "$ssh_banner"
    else
        printf "${Y}NO BANNER${N}\n"
    fi
    
    # 4. تست اتصال SSH
    printf "  ${C}[4/4]${N} تست اتصال SSH... "
    if [[ -f "$KEY_FILE" ]]; then
        if ssh -o BatchMode=yes -o ConnectTimeout=10 -o StrictHostKeyChecking=no \
           -i "$KEY_FILE" -p "$KHAREJ_PORT" "${TUNNEL_USER}@${KHAREJ_IP}" "echo OK" 2>/dev/null | grep -q OK; then
            printf "${G}OK${N}\n"
        else
            printf "${R}FAIL${N}\n"
            echo ""
            msg_warn "کلید SSH معتبر نیست یا در سرور خارج تنظیم نشده"
        fi
    else
        printf "${Y}NO KEY${N}\n"
        msg_warn "کلید SSH موجود نیست"
    fi
    
    echo ""
    
    # تست سرعت رمزنگاری
    line
    printf "${Y}تست سرعت رمزنگاری:${N}\n"
    line
    echo ""
    
    local ciphers=("aes128-gcm@openssh.com" "aes256-gcm@openssh.com" "chacha20-poly1305@openssh.com")
    
    for c in "${ciphers[@]}"; do
        printf "  ${C}%s:${N} " "$c"
        
        if [[ -f "$KEY_FILE" ]]; then
            local start_time=$(date +%s%N)
            if ssh -o BatchMode=yes -o ConnectTimeout=5 -o StrictHostKeyChecking=no \
               -o Ciphers="$c" -i "$KEY_FILE" -p "$KHAREJ_PORT" \
               "${TUNNEL_USER}@${KHAREJ_IP}" "echo test" &>/dev/null; then
                local end_time=$(date +%s%N)
                local duration=$(( (end_time - start_time) / 1000000 ))
                printf "${G}%dms${N}\n" "$duration"
            else
                printf "${R}FAIL${N}\n"
            fi
        else
            printf "${Y}نیاز به کلید${N}\n"
        fi
    done
    
    echo ""
    log "INFO" "Connection test completed to $KHAREJ_IP"
    read -p "$(printf "${C}Enter بزنید...${N}")"
}

# ═══════════════════════════════════════
#          مدیریت کلید SSH
# ═══════════════════════════════════════
manage_keys() {
    banner
    line
    printf "${W}          مدیریت کلید SSH${N}\n"
    line
    echo ""
    
    printf "  ${G}1)${N} مشاهده کلید عمومی\n"
    printf "  ${G}2)${N} ایجاد کلید جدید\n"
    printf "  ${G}3)${N} کپی کلید به سرور خارج\n"
    printf "  ${G}4)${N} حذف کلیدها\n"
    printf "  ${G}0)${N} بازگشت\n"
    echo ""
    
    read -p "$(printf "${C}انتخاب: ${N}")" kchoice
    
    case $kchoice in
        1) # مشاهده کلید
            echo ""
            if [[ -f "${KEY_FILE}.pub" ]]; then
                line
                printf "${Y}کلید عمومی:${N}\n"
                line
                echo ""
                cat "${KEY_FILE}.pub"
                echo ""
            else
                msg_warn "کلیدی موجود نیست"
            fi
            ;;
            
        2) # ایجاد کلید جدید
            echo ""
            if [[ -f "$KEY_FILE" ]]; then
                read -p "$(printf "${R}کلید موجود حذف شود؟ [y/N]: ${N}")" confirm
                [[ ! "$confirm" =~ ^[Yy]$ ]] && return
                rm -f "$KEY_FILE" "${KEY_FILE}.pub"
            fi
            
            msg_info "در حال ایجاد کلید ED25519..."
            ssh-keygen -t ed25519 -f "$KEY_FILE" -N "" -C "sshsaeed-$(date +%Y%m%d)" -q
            msg_ok "کلید جدید ایجاد شد"
            echo ""
            printf "${Y}کلید عمومی:${N}\n"
            cat "${KEY_FILE}.pub"
            echo ""
            ;;
            
        3) # کپی کلید
            echo ""
            load_config
            if [[ -z "$KHAREJ_IP" ]]; then
                msg_err "ابتدا سرور را پیکربندی کنید"
            elif [[ ! -f "${KEY_FILE}.pub" ]]; then
                msg_err "کلیدی موجود نیست"
            else
                msg_info "در حال کپی کلید..."
                ssh-copy-id -i "${KEY_FILE}.pub" -p "${KHAREJ_PORT:-22}" \
                    -o StrictHostKeyChecking=no "${TUNNEL_USER:-tunnel}@${KHAREJ_IP}"
            fi
            ;;
            
        4) # حذف کلیدها
            echo ""
            read -p "$(printf "${R}حذف تمام کلیدها؟ [y/N]: ${N}")" confirm
            if [[ "$confirm" =~ ^[Yy]$ ]]; then
                rm -f "$KEY_FILE" "${KEY_FILE}.pub"
                msg_ok "کلیدها حذف شدند"
            fi
            ;;
            
        0) return ;;
    esac
    
    echo ""
    read -p "$(printf "${C}Enter بزنید...${N}")"
}

# ═══════════════════════════════════════
#           حذف کامل
# ═══════════════════════════════════════
uninstall() {
    banner
    line
    printf "${R}            حذف کامل${N}\n"
    line
    echo ""
    
    printf "${Y}این عمل موارد زیر را حذف می‌کند:${N}\n"
    printf "  • تمام تانل‌های فعال\n"
    printf "  • سرویس‌های systemd\n"
    printf "  • کلیدهای SSH\n"
    printf "  • فایل‌های پیکربندی\n"
    echo ""
    
    read -p "$(printf "${R}آیا مطمئن هستید؟ [yes/NO]: ${N}")" confirm
    
    [[ "$confirm" != "yes" ]] && return
    
    echo ""
    msg_info "در حال حذف..."
    
    # 1. توقف و حذف تانل‌ها
    if [[ -s "$TUNNELS_FILE" ]]; then
        while IFS='|' read -r name rest; do
            [[ -z "$name" ]] && continue
            systemctl stop "sshsaeed-$name" 2>/dev/null
            systemctl disable "sshsaeed-$name" 2>/dev/null
            rm -f "/etc/systemd/system/sshsaeed-$name.service"
        done < "$TUNNELS_FILE"
        systemctl daemon-reload
        msg_ok "تانل‌ها حذف شدند"
    fi
    
    # 2. حذف کلیدها
    rm -f "$KEY_FILE" "${KEY_FILE}.pub"
    msg_ok "کلیدها حذف شدند"
    
    # 3. حذف دایرکتوری‌ها
    rm -rf "$CONFIG_DIR"
    msg_ok "فایل‌های پیکربندی حذف شدند"
    
    # 4. حذف لاگ
    rm -f "$LOG_FILE"
    
    echo ""
    line
    printf "${G}✓ حذف کامل انجام شد${N}\n"
    line
    echo ""
    printf "${Y}توجه: تنظیمات SSH تغییر نکرد${N}\n"
    printf "${C}برای بازگردانی SSH:${N}\n"
    printf "  cp %s/sshd_config.bak.* /etc/ssh/sshd_config\n" "$BACKUP_DIR"
    printf "  systemctl restart sshd\n"
    echo ""
    
    read -p "$(printf "${C}Enter بزنید...${N}")"
    exit 0
}

# ═══════════════════════════════════════
#            منوی اصلی
# ═══════════════════════════════════════
main_menu() {
    while true; do
        banner
        line
        printf "${W}              منوی اصلی${N}\n"
        line
        echo ""
        
        # نمایش وضعیت سریع
        load_config 2>/dev/null
        if [[ -n "$SERVER_TYPE" ]]; then
            printf "  ${C}نوع سرور:${N} ${G}%s${N}\n" "$SERVER_TYPE"
            local active_count=0
            [[ -s "$TUNNELS_FILE" ]] && active_count=$(grep -c '|' "$TUNNELS_FILE" 2>/dev/null || echo 0)
            printf "  ${C}تانل‌ها:${N}  ${Y}%d${N}\n" "$active_count"
            echo ""
        fi
        
        printf "${Y}═══ پیکربندی اولیه ═══${N}\n"
        printf "  ${G}1)${N}  تنظیم سرور خارج (Kharej)\n"
        printf "  ${G}2)${N}  تنظیم سرور ایران (Iran)\n"
        echo ""
        
        printf "${Y}═══ مدیریت تانل ═══${N}\n"
        printf "  ${G}3)${N}  ایجاد تانل جدید\n"
        printf "  ${G}4)${N}  لیست تانل‌ها\n"
        printf "  ${G}5)${N}  حذف تانل\n"
        echo ""
        
        printf "${Y}═══ ابزارها ═══${N}\n"
        printf "  ${G}6)${N}  وضعیت سیستم\n"
        printf "  ${G}7)${N}  تست اتصال\n"
        printf "  ${G}8)${N}  مدیریت کلید SSH\n"
        echo ""
        
        printf "${Y}═══ سایر ═══${N}\n"
        printf "  ${G}9)${N}  حذف کامل\n"
        printf "  ${G}0)${N}  خروج\n"
        echo ""
        
        line
        read -p "$(printf "${C}انتخاب شما: ${N}")" choice
        
        case $choice in
            1) setup_kharej ;;
            2) setup_iran ;;
            3) create_tunnel ;;
            4) list_tunnels ;;
            5) delete_tunnel ;;
            6) system_status ;;
            7) test_connection ;;
            8) manage_keys ;;
            9) uninstall ;;
            0)
                echo ""
                printf "${G}خداحافظ!${N}\n"
                echo ""
                exit 0
                ;;
            *)
                msg_err "انتخاب نامعتبر"
                sleep 1
                ;;
        esac
    done
}

# ═══════════════════════════════════════
#              MAIN
# ═══════════════════════════════════════
main() {
    # چک دسترسی روت
    check_root
    
    # مقداردهی اولیه
    init_dirs
    
    # تشخیص و نصب وابستگی‌ها
    detect_os
    install_dependencies
    
    # لاگ شروع
    log "INFO" "SSHSaeed v${VERSION} started"
    
    # اجرای منو
    main_menu
}

# اجرای برنامه
main "$@"
