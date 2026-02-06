#!/bin/bash
# ═══════════════════════════════════════════════════════════════════════════════
#  ███████╗███████╗██╗  ██╗███████╗ █████╗ ███████╗███████╗██████╗
#  ██╔════╝██╔════╝██║  ██║██╔════╝██╔══██╗██╔════╝██╔════╝██╔══██╗
#  ███████╗███████╗███████║███████╗███████║█████╗  █████╗  ██║  ██║
#  ╚════██║╚════██║██╔══██║╚════██║██╔══██║██╔══╝  ██╔══╝  ██║  ██║
#  ███████║███████║██║  ██║███████║██║  ██║███████╗███████╗██████╔╝
#  ╚══════╝╚══════╝╚═╝  ╚═╝╚══════╝╚═╝  ╚═╝╚══════╝╚══════╝╚═════╝
# ═══════════════════════════════════════════════════════════════════════════════
#  SSH Tunnel Manager v6.0 | Optimized + No Limits + Maximum Performance
#  GitHub: https://github.com/saeedkars/sshsaeed
# ═══════════════════════════════════════════════════════════════════════════════

set -o pipefail
export LC_ALL=C
export LANG=C

# ═══════════════════════════════════════════════════════════════════════════════
#                              ثابت‌های اصلی
# ═══════════════════════════════════════════════════════════════════════════════
SCRIPT_VERSION="6.0"
GITHUB_URL="https://github.com/saeedkars/sshsaeed"
CONFIG_DIR="/etc/sshsaeed"
CONFIG_FILE="$CONFIG_DIR/config.conf"
KEY_FILE="/root/.ssh/sshsaeed_ed25519"
LOG_FILE="/var/log/sshsaeed.log"
BACKUP_DIR="$CONFIG_DIR/backups"

# رمزنگاری - فقط AES-128-GCM (سریع‌ترین)
CIPHER="aes128-gcm@openssh.com"

# مقادیر پیش‌فرض
DEFAULT_PORTS="443,80"
DEFAULT_TUNNEL_COUNT=3
DEFAULT_SSH_PORT=22

# متغیرهای سراسری
declare -a TARGET_PORTS=()
TUNNEL_COUNT=3
KHAREJ_IP=""
KHAREJ_USER="root"
SSH_PORT=22

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
    printf "    ${Y}Version:${N} ${W}${SCRIPT_VERSION}${N}  ${Y}|${N}  ${C}Optimized + No Limits${N}\n"
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
#                         دریافت اطلاعات سیستم‌عامل (اصلاح‌شده)
# ═══════════════════════════════════════════════════════════════════════════════
get_os_info() {
    if [[ -f /etc/os-release ]]; then
        OS_ID=$(grep "^ID=" /etc/os-release | cut -d'=' -f2 | tr -d '"')
        OS_VERSION_ID=$(grep "^VERSION_ID=" /etc/os-release | cut -d'=' -f2 | tr -d '"')
        OS_PRETTY=$(grep "^PRETTY_NAME=" /etc/os-release | cut -d'=' -f2 | tr -d '"')
    else
        OS_ID="unknown"
        OS_VERSION_ID="unknown"
        OS_PRETTY="Unknown OS"
    fi
}

# ═══════════════════════════════════════════════════════════════════════════════
#                         بررسی‌های اولیه
# ═══════════════════════════════════════════════════════════════════════════════
check_root() {
    if [[ $EUID -ne 0 ]]; then
        print_err "این اسکریپت نیاز به دسترسی root دارد"
        exit 1
    fi
}

init_dirs() {
    mkdir -p "$CONFIG_DIR" "$BACKUP_DIR" "$(dirname $KEY_FILE)"
    touch "$LOG_FILE"
    chmod 700 "$CONFIG_DIR"
}

# ═══════════════════════════════════════════════════════════════════════════════
#                         نصب پکیج‌ها
# ═══════════════════════════════════════════════════════════════════════════════
install_packages() {
    print_info "نصب پکیج‌های مورد نیاز..."
    
    if command -v apt-get &>/dev/null; then
        export DEBIAN_FRONTEND=noninteractive
        apt-get update -qq >/dev/null 2>&1
        apt-get install -y -qq openssh-server openssh-client haproxy autossh \
            curl wget jq net-tools iptables sshpass >/dev/null 2>&1
    elif command -v yum &>/dev/null; then
        yum install -y -q openssh-server openssh-clients haproxy autossh \
            curl wget jq net-tools iptables sshpass >/dev/null 2>&1
    fi
    
    print_ok "پکیج‌ها نصب شدند"
    return 0
}

# ═══════════════════════════════════════════════════════════════════════════════
#            ★★★ تابع اصلی: برداشتن تمام محدودیت‌های سیستم ★★★
# ═══════════════════════════════════════════════════════════════════════════════
remove_all_limits() {
    local server_type="${1:-both}"
    
    print_info "برداشتن تمام محدودیت‌های سیستم..."
    
    # ═══════════ 1. محدودیت فایل‌های باز (ulimit) ═══════════
    print_info "افزایش محدودیت فایل‌های باز..."
    
    # پاک کردن تنظیمات قبلی
    sed -i '/# SSHSaeed/d' /etc/security/limits.conf 2>/dev/null
    sed -i '/nofile/d' /etc/security/limits.conf 2>/dev/null
    sed -i '/nproc/d' /etc/security/limits.conf 2>/dev/null
    
    cat >> /etc/security/limits.conf << 'LIMITS_EOF'

# SSHSaeed - Maximum Performance Limits v6.0
* soft nofile 1048576
* hard nofile 1048576
* soft nproc 1048576
* hard nproc 1048576
* soft memlock unlimited
* hard memlock unlimited
root soft nofile 1048576
root hard nofile 1048576
root soft nproc 1048576
root hard nproc 1048576
root soft memlock unlimited
root hard memlock unlimited
LIMITS_EOF
    
    print_ok "محدودیت فایل‌ها: 1,048,576"
    
    # ═══════════ 2. تنظیمات systemd ═══════════
    mkdir -p /etc/systemd/system.conf.d/
    cat > /etc/systemd/system.conf.d/sshsaeed-limits.conf << 'SYSTEMD_EOF'
[Manager]
DefaultLimitNOFILE=1048576
DefaultLimitNPROC=1048576
DefaultLimitMEMLOCK=infinity
SYSTEMD_EOF
    
    mkdir -p /etc/systemd/user.conf.d/
    cat > /etc/systemd/user.conf.d/sshsaeed-limits.conf << 'SYSTEMD_EOF'
[Manager]
DefaultLimitNOFILE=1048576
DefaultLimitNPROC=1048576
DefaultLimitMEMLOCK=infinity
SYSTEMD_EOF
    
    print_ok "محدودیت‌های systemd تنظیم شد"
    
    # ═══════════ 3. تنظیمات کرنل (sysctl) - بهینه‌ترین حالت ═══════════
    print_info "بهینه‌سازی پارامترهای کرنل..."
    
    cat > /etc/sysctl.d/99-sshsaeed-optimized.conf << 'SYSCTL_EOF'
# ═══════════════════════════════════════════════════════════════════════════════
# SSHSaeed - Ultimate Performance Kernel Parameters v6.0
# ═══════════════════════════════════════════════════════════════════════════════

# ═══════════ محدودیت فایل‌ها ═══════════
fs.file-max = 2097152
fs.nr_open = 2097152
fs.inotify.max_user_instances = 8192
fs.inotify.max_user_watches = 524288

# ═══════════ حافظه مجازی ═══════════
vm.swappiness = 10
vm.dirty_ratio = 60
vm.dirty_background_ratio = 5
vm.overcommit_memory = 1
vm.max_map_count = 262144

# ═══════════ تنظیمات شبکه - عمومی ═══════════
net.core.somaxconn = 65535
net.core.netdev_max_backlog = 65535
net.core.optmem_max = 25165824
net.core.default_qdisc = fq

# ═══════════ تنظیمات شبکه - بافر ═══════════
net.core.rmem_default = 31457280
net.core.rmem_max = 67108864
net.core.wmem_default = 31457280
net.core.wmem_max = 67108864

# ═══════════ TCP - عملکرد ═══════════
net.ipv4.tcp_rmem = 4096 87380 67108864
net.ipv4.tcp_wmem = 4096 65536 67108864
net.ipv4.tcp_mem = 65536 131072 262144
net.ipv4.udp_mem = 65536 131072 262144
net.ipv4.tcp_mtu_probing = 1

# ═══════════ TCP - اتصالات ═══════════
net.ipv4.tcp_max_syn_backlog = 65535
net.ipv4.tcp_max_tw_buckets = 2000000
net.ipv4.tcp_tw_reuse = 1
net.ipv4.tcp_fin_timeout = 10
net.ipv4.tcp_slow_start_after_idle = 0
net.ipv4.tcp_keepalive_time = 60
net.ipv4.tcp_keepalive_intvl = 10
net.ipv4.tcp_keepalive_probes = 6
net.ipv4.ip_local_port_range = 1024 65535

# ═══════════ TCP - بهینه‌سازی ═══════════
net.ipv4.tcp_fastopen = 3
net.ipv4.tcp_syncookies = 1
net.ipv4.tcp_rfc1337 = 1
net.ipv4.tcp_sack = 1
net.ipv4.tcp_fack = 1
net.ipv4.tcp_window_scaling = 1
net.ipv4.tcp_adv_win_scale = 1
net.ipv4.tcp_moderate_rcvbuf = 1
net.ipv4.tcp_no_metrics_save = 1
net.ipv4.tcp_timestamps = 1

# ═══════════ BBR (سریع‌ترین الگوریتم) ═══════════
net.ipv4.tcp_congestion_control = bbr

# ═══════════ IPv4 - امنیت و عملکرد ═══════════
net.ipv4.conf.all.rp_filter = 1
net.ipv4.conf.default.rp_filter = 1
net.ipv4.conf.all.accept_redirects = 0
net.ipv4.conf.default.accept_redirects = 0
net.ipv4.conf.all.send_redirects = 0
net.ipv4.conf.default.send_redirects = 0
net.ipv4.icmp_echo_ignore_broadcasts = 1
net.ipv4.icmp_ignore_bogus_error_responses = 1

# ═══════════ Connection Tracking ═══════════
net.netfilter.nf_conntrack_max = 2097152
net.netfilter.nf_conntrack_tcp_timeout_established = 7200
net.netfilter.nf_conntrack_tcp_timeout_time_wait = 30
net.netfilter.nf_conntrack_tcp_timeout_close_wait = 30
net.netfilter.nf_conntrack_tcp_timeout_fin_wait = 30
SYSCTL_EOF
    
    # فعال‌سازی BBR
    modprobe tcp_bbr 2>/dev/null || true
    
    # اعمال تنظیمات
    sysctl -p /etc/sysctl.d/99-sshsaeed-optimized.conf >/dev/null 2>&1 || true
    
    print_ok "پارامترهای کرنل بهینه شدند"
    
    # ═══════════ 4. فعال‌سازی محدودیت‌ها برای session فعلی ═══════════
    ulimit -n 1048576 2>/dev/null || true
    ulimit -u 1048576 2>/dev/null || true
    
    print_ok "محدودیت‌های session فعلی اعمال شد"
    
    log "INFO" "System limits removed and optimized for ${server_type}"
    return 0
}

# ═══════════════════════════════════════════════════════════════════════════════
#                     تنظیمات SSH بهینه (برای هر دو سرور)
# ═══════════════════════════════════════════════════════════════════════════════
optimize_ssh_config() {
    local server_type="$1"  # iran یا kharej
    
    print_info "بهینه‌سازی تنظیمات SSH برای ${server_type}..."
    
    # بکاپ
    [[ -f /etc/ssh/sshd_config ]] && cp /etc/ssh/sshd_config "$BACKUP_DIR/sshd_config.backup.$(date +%s)" 2>/dev/null
    
    # ایجاد فایل کانفیگ SSHSaeed
    mkdir -p /etc/ssh/sshd_config.d/
    
    if [[ "$server_type" == "kharej" ]]; then
        # تنظیمات سرور خارج - نیاز به GatewayPorts
        cat > /etc/ssh/sshd_config.d/sshsaeed.conf << 'SSH_KHAREJ'
# SSHSaeed - Kharej Server Optimized Config v6.0

# پورت‌فورواردینگ
GatewayPorts yes
AllowTcpForwarding yes
PermitTunnel yes

# محدودیت‌های بالا
MaxSessions 500
MaxStartups 500:30:1000
ClientAliveInterval 30
ClientAliveCountMax 6

# عملکرد
UseDNS no
Compression no
TCPKeepAlive yes

# رمزنگاری سریع
Ciphers aes128-gcm@openssh.com,aes256-gcm@openssh.com,chacha20-poly1305@openssh.com
MACs hmac-sha2-256-etm@openssh.com,hmac-sha2-512-etm@openssh.com

# احراز هویت
PermitRootLogin yes
PubkeyAuthentication yes
PasswordAuthentication yes
SSH_KHAREJ
    else
        # تنظیمات سرور ایران
        cat > /etc/ssh/sshd_config.d/sshsaeed.conf << 'SSH_IRAN'
# SSHSaeed - Iran Server Optimized Config v6.0

# پورت‌فورواردینگ
AllowTcpForwarding yes
PermitTunnel yes

# محدودیت‌های بالا
MaxSessions 500
MaxStartups 500:30:1000
ClientAliveInterval 30
ClientAliveCountMax 6

# عملکرد
UseDNS no
Compression no
TCPKeepAlive yes

# رمزنگاری سریع
Ciphers aes128-gcm@openssh.com,aes256-gcm@openssh.com,chacha20-poly1305@openssh.com
MACs hmac-sha2-256-etm@openssh.com,hmac-sha2-512-etm@openssh.com

# احراز هویت
PermitRootLogin yes
PubkeyAuthentication yes
PasswordAuthentication yes
SSH_IRAN
    fi
    
    # ری‌استارت SSH
    systemctl restart sshd 2>/dev/null || systemctl restart ssh 2>/dev/null || service ssh restart 2>/dev/null
    
    print_ok "تنظیمات SSH بهینه شد (MaxSessions: 500)"
    return 0
}

# ═══════════════════════════════════════════════════════════════════════════════
#                         تولید کلید SSH
# ═══════════════════════════════════════════════════════════════════════════════
generate_ssh_key() {
    print_info "ایجاد کلید SSH..."
    
    if [[ -f "$KEY_FILE" ]]; then
        print_warn "کلید قبلی موجود است، حذف می‌شود..."
        rm -f "$KEY_FILE" "${KEY_FILE}.pub"
    fi
    
    ssh-keygen -t ed25519 -f "$KEY_FILE" -N "" -C "sshsaeed-tunnel-v6" >/dev/null 2>&1
    chmod 600 "$KEY_FILE"
    chmod 644 "${KEY_FILE}.pub"
    
    print_ok "کلید SSH ایجاد شد: ${KEY_FILE}"
    log "INFO" "SSH key generated: ${KEY_FILE}"
    return 0
}

# ═══════════════════════════════════════════════════════════════════════════════
#                         کپی کلید به سرور خارج
# ═══════════════════════════════════════════════════════════════════════════════
copy_key_to_kharej() {
    local host="$1"
    local user="$2"
    local port="$3"
    local pass="$4"
    
    print_info "کپی کلید به سرور خارج..."
    
    if command -v sshpass &>/dev/null; then
        sshpass -p "$pass" ssh-copy-id -i "$KEY_FILE" -p "$port" \
            -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null \
            "$user@$host" >/dev/null 2>&1
    else
        ssh-copy-id -i "$KEY_FILE" -p "$port" \
            -o StrictHostKeyChecking=no "$user@$host" 2>/dev/null
    fi
    
    if [[ $? -eq 0 ]]; then
        print_ok "کلید SSH کپی شد"
        return 0
    else
        print_err "خطا در کپی کلید"
        return 1
    fi
}

# ═══════════════════════════════════════════════════════════════════════════════
#                         تست اتصال SSH
# ═══════════════════════════════════════════════════════════════════════════════
test_ssh_connection() {
    local host="$1"
    local user="$2"
    local port="$3"
    
    ssh -i "$KEY_FILE" -p "$port" -o BatchMode=yes -o ConnectTimeout=10 \
        -o StrictHostKeyChecking=no "$user@$host" "echo OK" &>/dev/null
    return $?
}

# ═══════════════════════════════════════════════════════════════════════════════
#                   بهینه‌سازی سرور خارج از راه دور
# ═══════════════════════════════════════════════════════════════════════════════
optimize_kharej_remote() {
    local host="$1"
    local user="$2"
    local port="$3"
    
    print_info "بهینه‌سازی سرور خارج از راه دور..."
    
    # ارسال و اجرای دستورات بهینه‌سازی روی سرور خارج
    ssh -i "$KEY_FILE" -p "$port" -o StrictHostKeyChecking=no "$user@$host" bash << 'REMOTE_OPTIMIZE'
#!/bin/bash

# ═══════════ 1. محدودیت فایل‌ها ═══════════
sed -i '/# SSHSaeed/d' /etc/security/limits.conf 2>/dev/null
sed -i '/nofile/d' /etc/security/limits.conf 2>/dev/null
sed -i '/nproc/d' /etc/security/limits.conf 2>/dev/null

cat >> /etc/security/limits.conf << 'LIMITS'

# SSHSaeed - Kharej Server Limits v6.0
* soft nofile 1048576
* hard nofile 1048576
* soft nproc 1048576
* hard nproc 1048576
root soft nofile 1048576
root hard nofile 1048576
root soft nproc 1048576
root hard nproc 1048576
LIMITS

# ═══════════ 2. systemd limits ═══════════
mkdir -p /etc/systemd/system.conf.d/
cat > /etc/systemd/system.conf.d/sshsaeed-limits.conf << 'SYSD'
[Manager]
DefaultLimitNOFILE=1048576
DefaultLimitNPROC=1048576
SYSD

# ═══════════ 3. sysctl ═══════════
cat > /etc/sysctl.d/99-sshsaeed.conf << 'SYSCTL'
fs.file-max = 2097152
fs.nr_open = 2097152
net.core.somaxconn = 65535
net.core.netdev_max_backlog = 65535
net.core.rmem_max = 67108864
net.core.wmem_max = 67108864
net.core.rmem_default = 31457280
net.core.wmem_default = 31457280
net.core.default_qdisc = fq
net.ipv4.tcp_rmem = 4096 87380 67108864
net.ipv4.tcp_wmem = 4096 65536 67108864
net.ipv4.tcp_max_syn_backlog = 65535
net.ipv4.tcp_max_tw_buckets = 2000000
net.ipv4.tcp_tw_reuse = 1
net.ipv4.tcp_fin_timeout = 10
net.ipv4.tcp_keepalive_time = 60
net.ipv4.tcp_keepalive_intvl = 10
net.ipv4.tcp_keepalive_probes = 6
net.ipv4.ip_local_port_range = 1024 65535
net.ipv4.tcp_fastopen = 3
net.ipv4.tcp_slow_start_after_idle = 0
net.ipv4.tcp_congestion_control = bbr
SYSCTL

modprobe tcp_bbr 2>/dev/null || true
sysctl -p /etc/sysctl.d/99-sshsaeed.conf >/dev/null 2>&1

# ═══════════ 4. SSH Config ═══════════
mkdir -p /etc/ssh/sshd_config.d/
cat > /etc/ssh/sshd_config.d/sshsaeed.conf << 'SSHCFG'
GatewayPorts yes
AllowTcpForwarding yes
PermitTunnel yes
MaxSessions 500
MaxStartups 500:30:1000
ClientAliveInterval 30
ClientAliveCountMax 6
UseDNS no
Compression no
TCPKeepAlive yes
Ciphers aes128-gcm@openssh.com,aes256-gcm@openssh.com
PermitRootLogin yes
PubkeyAuthentication yes
SSHCFG

systemctl restart sshd 2>/dev/null || systemctl restart ssh 2>/dev/null

echo "KHAREJ_OPTIMIZED_OK"
REMOTE_OPTIMIZE

    if [[ $? -eq 0 ]]; then
        print_ok "سرور خارج بهینه شد"
        return 0
    else
        print_warn "خطا در بهینه‌سازی سرور خارج"
        return 1
    fi
}
# ═══════════════════════════════════════════════════════════════════════════════
#                         ایجاد سرویس تانل
# ═══════════════════════════════════════════════════════════════════════════════
create_tunnel_service() {
    local tunnel_num="$1"
    local remote_port="$2"
    local target_port="$3"
    local host="$4"
    local user="$5"
    local ssh_port="$6"
    
    local service_name="sshsaeed-tunnel${tunnel_num}"
    local local_port=$((10000 + target_port + tunnel_num))
    
    cat > "/etc/systemd/system/${service_name}.service" << EOF
[Unit]
Description=SSHSaeed Tunnel ${tunnel_num} - Port ${target_port}
After=network-online.target
Wants=network-online.target
StartLimitIntervalSec=0

[Service]
Type=simple
Environment="AUTOSSH_GATETIME=0"
Environment="AUTOSSH_PORT=0"
Environment="AUTOSSH_POLL=30"
ExecStart=/usr/bin/autossh -M 0 -N -T \\
    -o "ServerAliveInterval=10" \\
    -o "ServerAliveCountMax=3" \\
    -o "ExitOnForwardFailure=yes" \\
    -o "StrictHostKeyChecking=no" \\
    -o "UserKnownHostsFile=/dev/null" \\
    -o "TCPKeepAlive=yes" \\
    -o "Compression=no" \\
    -o "Ciphers=${CIPHER}" \\
    -i ${KEY_FILE} \\
    -p ${ssh_port} \\
    -R ${remote_port}:127.0.0.1:${local_port} \\
    ${user}@${host}
Restart=always
RestartSec=3
LimitNOFILE=1048576
LimitNPROC=1048576

[Install]
WantedBy=multi-user.target
EOF
    
    systemctl daemon-reload
    systemctl enable "${service_name}" >/dev/null 2>&1
    systemctl start "${service_name}"
    
    return $?
}

# ═══════════════════════════════════════════════════════════════════════════════
#                         ایجاد همه تانل‌ها برای یک پورت
# ═══════════════════════════════════════════════════════════════════════════════
create_tunnels_for_port() {
    local target_port="$1"
    local tunnel_count="$2"
    local host="$3"
    local user="$4"
    local ssh_port="$5"
    
    local base_remote_port
    if [[ "$target_port" == "443" ]]; then
        base_remote_port=2000
    elif [[ "$target_port" == "80" ]]; then
        base_remote_port=3000
    else
        base_remote_port=$((target_port * 10))
    fi
    
    print_info "ایجاد ${tunnel_count} تانل برای پورت ${target_port}..."
    
    for ((i=1; i<=tunnel_count; i++)); do
        local remote_port=$((base_remote_port + i))
        print_wait "تانل ${i}/${tunnel_count} (پورت ${remote_port})..."
        
        if create_tunnel_service "$i" "$remote_port" "$target_port" "$host" "$user" "$ssh_port"; then
            print_done "تانل ${i} ایجاد شد (${remote_port} → ${target_port})"
        else
            print_err "خطا در ایجاد تانل ${i}"
        fi
    done
}

# ═══════════════════════════════════════════════════════════════════════════════
#                         پیکربندی HAProxy
# ═══════════════════════════════════════════════════════════════════════════════
configure_haproxy() {
    local ports="$1"
    local tunnel_count="$2"
    
    print_info "پیکربندی HAProxy..."
    
    # بکاپ
    [[ -f /etc/haproxy/haproxy.cfg ]] && cp /etc/haproxy/haproxy.cfg "$BACKUP_DIR/haproxy.cfg.backup.$(date +%s)"
    
    # شروع کانفیگ
    cat > /etc/haproxy/haproxy.cfg << 'HAPROXY_GLOBAL'
# ═══════════════════════════════════════════════════════════════════════════════
# SSHSaeed HAProxy Configuration v6.0 - Maximum Performance
# ═══════════════════════════════════════════════════════════════════════════════

global
    log /dev/log local0
    log /dev/log local1 notice
    chroot /var/lib/haproxy
    stats socket /run/haproxy/admin.sock mode 660 level admin expose-fd listeners
    stats timeout 30s
    user haproxy
    group haproxy
    daemon
    
    # Performance Tuning
    maxconn 500000
    nbthread 4
    cpu-map auto:1/1-4 0-3
    tune.ssl.default-dh-param 2048
    tune.bufsize 32768
    tune.maxrewrite 8192
    tune.rcvbuf.client 33554432
    tune.rcvbuf.server 33554432
    tune.sndbuf.client 33554432
    tune.sndbuf.server 33554432

defaults
    log     global
    mode    tcp
    option  tcplog
    option  dontlognull
    option  tcp-smart-accept
    option  tcp-smart-connect
    timeout connect 10s
    timeout client  300s
    timeout server  300s
    timeout tunnel  1h
    retries 3
    maxconn 100000

HAPROXY_GLOBAL
    
    # اضافه کردن frontend و backend برای هر پورت
    IFS=',' read -ra PORT_ARRAY <<< "$ports"
    
    for port in "${PORT_ARRAY[@]}"; do
        port=$(echo "$port" | tr -d ' ')
        
        local base_remote_port
        if [[ "$port" == "443" ]]; then
            base_remote_port=2000
        elif [[ "$port" == "80" ]]; then
            base_remote_port=3000
        else
            base_remote_port=$((port * 10))
        fi
        
        # Frontend
        cat >> /etc/haproxy/haproxy.cfg << EOF

# ═══════════════════════════════════════════════════════════════════════════════
# Port ${port} Configuration
# ═══════════════════════════════════════════════════════════════════════════════
frontend fe_port_${port}
    bind *:${port}
    mode tcp
    option tcplog
    default_backend be_tunnels_${port}

backend be_tunnels_${port}
    mode tcp
    balance roundrobin
    option tcp-check
    tcp-check connect
EOF
        
        # اضافه کردن سرورها
        for ((i=1; i<=tunnel_count; i++)); do
            local remote_port=$((base_remote_port + i))
            local local_port=$((10000 + port + i))
            echo "    server tunnel${i}_${port} 127.0.0.1:${local_port} check inter 5s fall 3 rise 2 weight 100" >> /etc/haproxy/haproxy.cfg
        done
    done
    
    # اضافه کردن صفحه stats
    cat >> /etc/haproxy/haproxy.cfg << 'STATS_EOF'

# ═══════════════════════════════════════════════════════════════════════════════
# Stats Page
# ═══════════════════════════════════════════════════════════════════════════════
frontend stats
    bind *:8404
    mode http
    stats enable
    stats uri /stats
    stats refresh 10s
    stats admin if TRUE
STATS_EOF
    
    # تست و ری‌استارت
    if haproxy -c -f /etc/haproxy/haproxy.cfg >/dev/null 2>&1; then
        systemctl restart haproxy
        systemctl enable haproxy >/dev/null 2>&1
        print_ok "HAProxy پیکربندی و راه‌اندازی شد"
        return 0
    else
        print_err "خطا در پیکربندی HAProxy"
        return 1
    fi
}

# ═══════════════════════════════════════════════════════════════════════════════
#                         socat listeners برای پورت‌های محلی
# ═══════════════════════════════════════════════════════════════════════════════
create_socat_services() {
    local ports="$1"
    local tunnel_count="$2"
    
    print_info "ایجاد سرویس‌های socat..."
    
    IFS=',' read -ra PORT_ARRAY <<< "$ports"
    
    for port in "${PORT_ARRAY[@]}"; do
        port=$(echo "$port" | tr -d ' ')
        
        for ((i=1; i<=tunnel_count; i++)); do
            local local_port=$((10000 + port + i))
            local service_name="sshsaeed-socat-${port}-${i}"
            
            cat > "/etc/systemd/system/${service_name}.service" << EOF
[Unit]
Description=SSHSaeed Socat - Port ${port} Tunnel ${i}
After=network.target

[Service]
Type=simple
ExecStart=/usr/bin/socat TCP-LISTEN:${local_port},fork,reuseaddr,bind=127.0.0.1 TCP:127.0.0.1:${port}
Restart=always
RestartSec=3
LimitNOFILE=1048576

[Install]
WantedBy=multi-user.target
EOF
            
            systemctl daemon-reload
            systemctl enable "${service_name}" >/dev/null 2>&1
            systemctl start "${service_name}" 2>/dev/null
        done
    done
    
    print_ok "سرویس‌های socat ایجاد شدند"
}

# ═══════════════════════════════════════════════════════════════════════════════
#                         نمایش وضعیت
# ═══════════════════════════════════════════════════════════════════════════════
show_status() {
    show_banner
    line
    printf "    ${W}وضعیت سیستم${N}\n"
    line
    echo ""
    
    # ═══════════ اطلاعات سیستم ═══════════
    get_os_info
    printf "    ${C}┌─────────────────────────────────────────────────────────┐${N}\n"
    printf "    ${C}│${N} ${Y}سیستم عامل:${N} %-40s ${C}│${N}\n" "$OS_PRETTY"
    printf "    ${C}│${N} ${Y}Kernel:${N}     %-40s ${C}│${N}\n" "$(uname -r)"
    printf "    ${C}│${N} ${Y}Uptime:${N}     %-40s ${C}│${N}\n" "$(uptime -p 2>/dev/null || echo 'N/A')"
    printf "    ${C}└─────────────────────────────────────────────────────────┘${N}\n"
    echo ""
    
    # ═══════════ محدودیت‌های سیستم ═══════════
    printf "    ${W}محدودیت‌های سیستم:${N}\n"
    line_thin
    local max_files=$(cat /proc/sys/fs/file-max 2>/dev/null || echo "N/A")
    local ulimit_n=$(ulimit -n 2>/dev/null || echo "N/A")
    local ulimit_u=$(ulimit -u 2>/dev/null || echo "N/A")
    local cc=$(sysctl -n net.ipv4.tcp_congestion_control 2>/dev/null || echo "N/A")
    
    printf "    ${C}│${N} %-25s %s\n" "fs.file-max:" "${W}${max_files}${N}"
    printf "    ${C}│${N} %-25s %s\n" "ulimit -n (open files):" "${W}${ulimit_n}${N}"
    printf "    ${C}│${N} %-25s %s\n" "ulimit -u (max procs):" "${W}${ulimit_u}${N}"
    printf "    ${C}│${N} %-25s %s\n" "TCP Congestion:" "${W}${cc}${N}"
    echo ""
    
    # ═══════════ وضعیت سرویس‌ها ═══════════
    printf "    ${W}سرویس‌ها:${N}\n"
    line_thin
    
    # HAProxy
    if systemctl is-active haproxy >/dev/null 2>&1; then
        printf "    ${G}${ICO_OK}${N} HAProxy: ${G}فعال${N}\n"
    else
        printf "    ${R}${ICO_ERR}${N} HAProxy: ${R}غیرفعال${N}\n"
    fi
    
    # SSH
    if systemctl is-active sshd >/dev/null 2>&1 || systemctl is-active ssh >/dev/null 2>&1; then
        printf "    ${G}${ICO_OK}${N} SSH: ${G}فعال${N}\n"
    else
        printf "    ${R}${ICO_ERR}${N} SSH: ${R}غیرفعال${N}\n"
    fi
    echo ""
    
    # ═══════════ تانل‌ها ═══════════
    printf "    ${W}تانل‌های فعال:${N}\n"
    line_thin
    
    local tunnel_count=0
    for service in /etc/systemd/system/sshsaeed-tunnel*.service; do
        [[ -f "$service" ]] || continue
        local svc_name=$(basename "$service" .service)
        if systemctl is-active "$svc_name" >/dev/null 2>&1; then
            printf "    ${G}${ICO_OK}${N} ${svc_name}: ${G}فعال${N}\n"
            ((tunnel_count++))
        else
            printf "    ${R}${ICO_ERR}${N} ${svc_name}: ${R}غیرفعال${N}\n"
        fi
    done
    
    [[ $tunnel_count -eq 0 ]] && printf "    ${Y}هیچ تانلی پیدا نشد${N}\n"
    echo ""
    
    # ═══════════ پورت‌های در حال گوش دادن ═══════════
    printf "    ${W}پورت‌های باز:${N}\n"
    line_thin
    
    for port in 443 80 8404; do
        if ss -tlnp 2>/dev/null | grep -q ":${port} "; then
            printf "    ${G}${ICO_OK}${N} پورت ${port}: ${G}باز${N}\n"
        else
            printf "    ${R}${ICO_ERR}${N} پورت ${port}: ${R}بسته${N}\n"
        fi
    done
    echo ""
    
    # ═══════════ اتصالات فعال ═══════════
    printf "    ${W}اتصالات فعال:${N}\n"
    line_thin
    local established=$(ss -tn state established 2>/dev/null | wc -l)
    local time_wait=$(ss -tn state time-wait 2>/dev/null | wc -l)
    printf "    ${C}│${N} %-25s %s\n" "ESTABLISHED:" "${W}${established}${N}"
    printf "    ${C}│${N} %-25s %s\n" "TIME_WAIT:" "${W}${time_wait}${N}"
    echo ""
    
    line
    read -p "$(printf "    ${C}Enter برای بازگشت به منو...${N}")"
}

# ═══════════════════════════════════════════════════════════════════════════════
#                         مدیریت تانل‌ها
# ═══════════════════════════════════════════════════════════════════════════════
manage_tunnels() {
    while true; do
        show_banner
        line
        printf "    ${W}مدیریت تانل‌ها${N}\n"
        line
        echo ""
        
        printf "    ${C}[${W}1${C}]${N} مشاهده وضعیت تانل‌ها\n"
        printf "    ${C}[${W}2${C}]${N} ری‌استارت همه تانل‌ها\n"
        printf "    ${C}[${W}3${C}]${N} ری‌استارت یک تانل خاص\n"
        printf "    ${C}[${W}4${C}]${N} توقف همه تانل‌ها\n"
        printf "    ${C}[${W}5${C}]${N} شروع همه تانل‌ها\n"
        printf "    ${C}[${W}6${C}]${N} مشاهده لاگ تانل‌ها\n"
        printf "    ${C}[${W}0${C}]${N} بازگشت\n"
        echo ""
        
        read -p "$(printf "    ${Y}انتخاب: ${N}")" choice
        
        case $choice in
            1)
                show_status
                ;;
            2)
                print_info "ری‌استارت همه تانل‌ها..."
                for service in /etc/systemd/system/sshsaeed-tunnel*.service; do
                    [[ -f "$service" ]] || continue
                    local svc_name=$(basename "$service" .service)
                    systemctl restart "$svc_name" 2>/dev/null && print_ok "$svc_name ری‌استارت شد"
                done
                sleep 2
                ;;
            3)
                echo ""
                read -p "$(printf "    ${Y}شماره تانل: ${N}")" tnum
                if systemctl restart "sshsaeed-tunnel${tnum}" 2>/dev/null; then
                    print_ok "تانل ${tnum} ری‌استارت شد"
                else
                    print_err "تانل ${tnum} یافت نشد"
                fi
                sleep 2
                ;;
            4)
                print_info "توقف همه تانل‌ها..."
                for service in /etc/systemd/system/sshsaeed-tunnel*.service; do
                    [[ -f "$service" ]] || continue
                    local svc_name=$(basename "$service" .service)
                    systemctl stop "$svc_name" 2>/dev/null && print_ok "$svc_name متوقف شد"
                done
                sleep 2
                ;;
            5)
                print_info "شروع همه تانل‌ها..."
                for service in /etc/systemd/system/sshsaeed-tunnel*.service; do
                    [[ -f "$service" ]] || continue
                    local svc_name=$(basename "$service" .service)
                    systemctl start "$svc_name" 2>/dev/null && print_ok "$svc_name شروع شد"
                done
                sleep 2
                ;;
            6)
                echo ""
                print_info "لاگ آخرین تانل (50 خط اخیر):"
                journalctl -u "sshsaeed-tunnel1" -n 50 --no-pager 2>/dev/null || print_err "لاگی یافت نشد"
                echo ""
                read -p "$(printf "    ${C}Enter برای بازگشت...${N}")"
                ;;
            0)
                return
                ;;
        esac
    done
}

# ═══════════════════════════════════════════════════════════════════════════════
#                         تست سرعت رمزنگاری (اصلاح شده)
# ═══════════════════════════════════════════════════════════════════════════════
test_cipher_speed() {
    show_banner
    line
    printf "    ${W}تست سرعت رمزنگاری AES${N}\n"
    line
    echo ""
    
    print_info "بررسی پشتیبانی سخت‌افزاری AES-NI..."
    echo ""
    
    if grep -q 'aes' /proc/cpuinfo 2>/dev/null; then
        printf "    ${G}${ICO_OK}${N} پردازنده از AES-NI پشتیبانی می‌کند\n"
    else
        printf "    ${Y}${ICO_WARN}${N} پردازنده از AES-NI پشتیبانی نمی‌کند\n"
    fi
    echo ""
    
    # تست با openssl
    if command -v openssl >/dev/null 2>&1; then
        print_info "تست سرعت با OpenSSL..."
        echo ""
        
        local ciphers=("aes-128-gcm" "aes-256-gcm" "chacha20-poly1305")
        
        for cipher in "${ciphers[@]}"; do
            printf "    ${C}%-25s${N}" "$cipher:"
            local speed=$(openssl speed -evp "$cipher" 2>/dev/null | grep "^$cipher" | awk '{print $NF}')
            if [[ -n "$speed" ]]; then
                printf "${G}%s${N}\n" "$speed"
            else
                # تست جایگزین
                local result=$(openssl speed -evp "$cipher" 2>&1 | tail -1 | awk '{print $NF}')
                printf "${W}%s${N}\n" "${result:-N/A}"
            fi
        done
    else
        print_warn "OpenSSL نصب نیست"
    fi
    echo ""
    
    # نتیجه‌گیری
    local score=0
    local max_score=3
    
    grep -q 'aes' /proc/cpuinfo && ((score++))
    [[ -f /proc/crypto ]] && grep -q 'aes' /proc/crypto && ((score++))
    command -v openssl >/dev/null && ((score++))
    
    printf "    ${W}امتیاز کلی: ${G}${score}${W}/${max_score}${N}\n"
    echo ""
    
    local cc=$(sysctl -n net.ipv4.tcp_congestion_control 2>/dev/null || echo "N/A")
    
    # جدول خلاصه
    printf "    ${C}┌─────────────────────────────────────┐${N}\n"
    printf "    ${C}│${N} %-20s %s ${C}│${N}\n" "AES-NI" "$(grep -q 'aes' /proc/cpuinfo && echo "${G}پشتیبانی می‌شود${N}" || echo "${R}پشتیبانی نمی‌شود${N}")"
    printf "    ${C}│${N} %-20s %s ${C}│${N}\n" "Cipher" "${G}aes128-gcm${N}"
    printf "    ${C}│${N} %-20s %s ${C}│${N}\n" "BBR" "$([ "$cc" == "bbr" ] && echo "${G}فعال${N}" || echo "${Y}غیرفعال${N}")"
    printf "    ${C}└─────────────────────────────────────┘${N}\n"
    echo ""
    
    log "INFO" "AES test completed - Score: $score/$max_score"
    
    # دکمه بازگشت اصلاح شده
    read -p "$(printf "    ${C}Enter برای بازگشت به منوی اصلی...${N}")"
    return 0
}

# ═══════════════════════════════════════════════════════════════════════════════
#                         تنظیم سرور خارج (Kharej)
# ═══════════════════════════════════════════════════════════════════════════════
setup_kharej_server() {
    show_banner
    line
    printf "    ${W}تنظیم سرور خارج (Kharej Server)${N}\n"
    line
    echo ""
    
    local step=0
    local total_steps=7
    
    # ═══════════ مرحله 1: نصب پکیج‌ها ═══════════
    ((step++))
    printf "  ${C}[%d/%d]${N} ${W}نصب پکیج‌ها...${N}\n" "$step" "$total_steps"
    install_packages
    echo ""
    
    # ═══════════ مرحله 2: رفع محدودیت‌ها ═══════════
    ((step++))
    printf "  ${C}[%d/%d]${N} ${W}رفع محدودیت‌های سیستم...${N}\n" "$step" "$total_steps"
    remove_all_limits
    echo ""
    
    # ═══════════ مرحله 3: ایجاد کاربر تانل ═══════════
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
    
    # ═══════════ مرحله 4: پیکربندی SSH ═══════════
    ((step++))
    printf "  ${C}[%d/%d]${N} ${W}پیکربندی SSH...${N}\n" "$step" "$total_steps"
    
    # بکاپ
    [[ -f /etc/ssh/sshd_config ]] && cp /etc/ssh/sshd_config "$BACKUP_DIR/sshd_config.backup.$(date +%s)"
    
    # تنظیمات بهینه SSH برای سرور خارج
    cat > /etc/ssh/sshd_config.d/sshsaeed.conf << 'SSHD_EOF'
# SSHSaeed SSH Configuration v6.0 - Kharej Server
# Maximum Performance Settings

# اجازه GatewayPorts برای تانل معکوس
GatewayPorts yes
AllowTcpForwarding yes
PermitTunnel yes

# Performance
TCPKeepAlive yes
ClientAliveInterval 30
ClientAliveCountMax 10
MaxSessions 100
MaxStartups 100:30:200

# Security
PasswordAuthentication yes
PubkeyAuthentication yes
PermitRootLogin yes

# Speed Optimization
UseDNS no
GSSAPIAuthentication no
Compression no
SSHD_EOF
    
    # ری‌استارت SSH
    systemctl restart sshd 2>/dev/null || systemctl restart ssh 2>/dev/null
    print_ok "SSH پیکربندی شد"
    echo ""
    
    # ═══════════ مرحله 5: فایروال ═══════════
    ((step++))
    printf "  ${C}[%d/%d]${N} ${W}پیکربندی فایروال...${N}\n" "$step" "$total_steps"
    configure_firewall "2001,2002,2003,2004,2005,3001,3002,3003,443,80,22"
    echo ""
    
    # ═══════════ مرحله 6: پیکربندی HAProxy ═══════════
    ((step++))
    printf "  ${C}[%d/%d]${N} ${W}پیکربندی HAProxy...${N}\n" "$step" "$total_steps"
    configure_haproxy "443,80" 3
    echo ""
    
    # ═══════════ مرحله 7: ذخیره تنظیمات ═══════════
    ((step++))
    printf "  ${C}[%d/%d]${N} ${W}ذخیره تنظیمات...${N}\n" "$step" "$total_steps"
    
    cat > "$CONFIG_FILE" << EOF
# SSHSaeed Configuration - Kharej Server
SERVER_TYPE=kharej
TUNNEL_USER=$TUNNEL_USER
SETUP_DATE=$(date '+%Y-%m-%d %H:%M:%S')
SCRIPT_VERSION=$SCRIPT_VERSION
EOF
    
    print_ok "تنظیمات ذخیره شد"
    echo ""
    
    # نتیجه نهایی
    line
    printf "    ${G}${ICO_OK} سرور خارج با موفقیت تنظیم شد!${N}\n"
    line
    echo ""
    printf "    ${W}اطلاعات مهم:${N}\n"
    printf "    ${C}│${N} کاربر تانل: ${W}%s${N}\n" "$TUNNEL_USER"
    printf "    ${C}│${N} پورت‌های تانل: ${W}2001-2003, 3001-3003${N}\n"
    printf "    ${C}│${N} HAProxy Stats: ${W}http://IP:8404/stats${N}\n"
    echo ""
    
    log "INFO" "Kharej server setup completed"
    
    read -p "$(printf "    ${C}Enter برای بازگشت به منو...${N}")"
}
# ═══════════════════════════════════════════════════════════════════════════════
#                         تنظیم سرور ایران (Iran)
# ═══════════════════════════════════════════════════════════════════════════════
setup_iran_server() {
    show_banner
    line
    printf "    ${W}تنظیم سرور ایران (Iran Server)${N}\n"
    line
    echo ""
    
    local step=0
    local total_steps=8
    
    # ═══════════ مرحله 1: نصب پکیج‌ها ═══════════
    ((step++))
    printf "  ${C}[%d/%d]${N} ${W}نصب پکیج‌ها...${N}\n" "$step" "$total_steps"
    install_packages
    echo ""
    
    # ═══════════ مرحله 2: رفع محدودیت‌ها ═══════════
    ((step++))
    printf "  ${C}[%d/%d]${N} ${W}رفع محدودیت‌های سیستم...${N}\n" "$step" "$total_steps"
    remove_all_limits
    echo ""
    
    # ═══════════ مرحله 3: دریافت اطلاعات سرور خارج ═══════════
    ((step++))
    printf "  ${C}[%d/%d]${N} ${W}اطلاعات سرور خارج...${N}\n" "$step" "$total_steps"
    echo ""
    
    while true; do
        read -p "$(printf "    ${Y}آدرس IP سرور خارج: ${N}")" KHAREJ_IP
        if [[ -n "$KHAREJ_IP" ]]; then
            # اعتبارسنجی ساده IP
            if [[ "$KHAREJ_IP" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]] || [[ "$KHAREJ_IP" =~ ^[a-zA-Z0-9.-]+$ ]]; then
                break
            fi
        fi
        print_err "لطفاً یک آدرس IP یا دامنه معتبر وارد کنید"
    done
    
    read -p "$(printf "    ${Y}نام کاربری سرور خارج [${W}tunnel${Y}]: ${N}")" input_user
    KHAREJ_USER="${input_user:-tunnel}"
    
    read -p "$(printf "    ${Y}پورت SSH سرور خارج [${W}22${Y}]: ${N}")" input_port
    SSH_PORT="${input_port:-22}"
    
    read -p "$(printf "    ${Y}تعداد تانل برای هر پورت [${W}3${Y}]: ${N}")" input_count
    TUNNEL_COUNT="${input_count:-3}"
    
    read -p "$(printf "    ${Y}پورت‌های هدف (جدا با کاما) [${W}443,80${Y}]: ${N}")" input_ports
    local target_ports="${input_ports:-443,80}"
    
    echo ""
    print_ok "اطلاعات دریافت شد"
    echo ""
    
    # ═══════════ مرحله 4: تولید کلید SSH ═══════════
    ((step++))
    printf "  ${C}[%d/%d]${N} ${W}تولید کلید SSH...${N}\n" "$step" "$total_steps"
    
    if [[ ! -f "$KEY_FILE" ]]; then
        ssh-keygen -t ed25519 -f "$KEY_FILE" -N "" -C "sshsaeed-tunnel" >/dev/null 2>&1
        chmod 600 "$KEY_FILE"
        chmod 644 "${KEY_FILE}.pub"
        print_ok "کلید SSH جدید تولید شد"
    else
        print_info "کلید SSH از قبل موجود است"
    fi
    echo ""
    
    # ═══════════ مرحله 5: کپی کلید به سرور خارج ═══════════
    ((step++))
    printf "  ${C}[%d/%d]${N} ${W}کپی کلید به سرور خارج...${N}\n" "$step" "$total_steps"
    echo ""
    
    printf "    ${Y}کلید عمومی شما:${N}\n"
    printf "    ${GR}─────────────────────────────────────────────────────────────${N}\n"
    cat "${KEY_FILE}.pub"
    printf "    ${GR}─────────────────────────────────────────────────────────────${N}\n"
    echo ""
    
    printf "    ${W}دو روش برای کپی کلید:${N}\n"
    printf "    ${C}[${W}1${C}]${N} کپی خودکار با ssh-copy-id (نیاز به پسورد)\n"
    printf "    ${C}[${W}2${C}]${N} کپی دستی (کلید بالا را در سرور خارج اضافه کنید)\n"
    echo ""
    
    read -p "$(printf "    ${Y}انتخاب روش [1/2]: ${N}")" copy_method
    
    if [[ "$copy_method" == "1" ]]; then
        print_info "در حال کپی کلید به سرور خارج..."
        if ssh-copy-id -i "${KEY_FILE}.pub" -p "$SSH_PORT" "${KHAREJ_USER}@${KHAREJ_IP}" 2>/dev/null; then
            print_ok "کلید با موفقیت کپی شد"
        else
            print_err "خطا در کپی کلید - لطفاً دستی انجام دهید"
            echo ""
            printf "    ${Y}دستور برای اجرا در سرور خارج:${N}\n"
            printf "    ${W}echo '$(cat ${KEY_FILE}.pub)' >> /home/${KHAREJ_USER}/.ssh/authorized_keys${N}\n"
            echo ""
            read -p "$(printf "    ${C}پس از کپی دستی، Enter بزنید...${N}")"
        fi
    else
        echo ""
        printf "    ${Y}این کلید را در سرور خارج اضافه کنید:${N}\n"
        printf "    ${W}echo '$(cat ${KEY_FILE}.pub)' >> /home/${KHAREJ_USER}/.ssh/authorized_keys${N}\n"
        echo ""
        read -p "$(printf "    ${C}پس از کپی دستی، Enter بزنید...${N}")"
    fi
    echo ""
    
    # ═══════════ مرحله 6: تست اتصال SSH ═══════════
    ((step++))
    printf "  ${C}[%d/%d]${N} ${W}تست اتصال SSH...${N}\n" "$step" "$total_steps"
    
    print_wait "تست اتصال به سرور خارج..."
    if ssh -i "$KEY_FILE" -p "$SSH_PORT" -o "ConnectTimeout=10" -o "StrictHostKeyChecking=no" -o "BatchMode=yes" "${KHAREJ_USER}@${KHAREJ_IP}" "echo 'OK'" >/dev/null 2>&1; then
        print_done "اتصال SSH برقرار است"
    else
        print_err "اتصال SSH برقرار نشد!"
        echo ""
        printf "    ${Y}بررسی کنید:${N}\n"
        printf "    ${C}│${N} 1. کلید در سرور خارج اضافه شده باشد\n"
        printf "    ${C}│${N} 2. فایروال پورت SSH را باز کرده باشید\n"
        printf "    ${C}│${N} 3. کاربر '${KHAREJ_USER}' در سرور خارج وجود داشته باشد\n"
        echo ""
        read -p "$(printf "    ${Y}ادامه بدون تأیید اتصال؟ [y/N]: ${N}")" continue_anyway
        [[ "$continue_anyway" != "y" && "$continue_anyway" != "Y" ]] && return 1
    fi
    echo ""
    
    # ═══════════ مرحله 7: ایجاد تانل‌ها ═══════════
    ((step++))
    printf "  ${C}[%d/%d]${N} ${W}ایجاد تانل‌ها...${N}\n" "$step" "$total_steps"
    echo ""
    
    IFS=',' read -ra PORT_ARRAY <<< "$target_ports"
    local tunnel_num=0
    
    for port in "${PORT_ARRAY[@]}"; do
        port=$(echo "$port" | tr -d ' ')
        
        local base_remote_port
        if [[ "$port" == "443" ]]; then
            base_remote_port=2000
        elif [[ "$port" == "80" ]]; then
            base_remote_port=3000
        else
            base_remote_port=$((port * 10))
        fi
        
        print_info "ایجاد ${TUNNEL_COUNT} تانل برای پورت ${port}..."
        
        for ((i=1; i<=TUNNEL_COUNT; i++)); do
            ((tunnel_num++))
            local remote_port=$((base_remote_port + i))
            
            print_wait "تانل ${tunnel_num} (پورت ${remote_port} → ${port})..."
            
            # ایجاد سرویس
            cat > "/etc/systemd/system/sshsaeed-tunnel${tunnel_num}.service" << EOF
[Unit]
Description=SSHSaeed Tunnel ${tunnel_num} - Port ${port}
After=network-online.target
Wants=network-online.target
StartLimitIntervalSec=0

[Service]
Type=simple
Environment="AUTOSSH_GATETIME=0"
Environment="AUTOSSH_PORT=0"
Environment="AUTOSSH_POLL=30"
ExecStart=/usr/bin/autossh -M 0 -N -T \\
    -o "ServerAliveInterval=10" \\
    -o "ServerAliveCountMax=3" \\
    -o "ExitOnForwardFailure=yes" \\
    -o "StrictHostKeyChecking=no" \\
    -o "UserKnownHostsFile=/dev/null" \\
    -o "TCPKeepAlive=yes" \\
    -o "Compression=no" \\
    -o "Ciphers=${CIPHER}" \\
    -i ${KEY_FILE} \\
    -p ${SSH_PORT} \\
    -R ${remote_port}:127.0.0.1:${port} \\
    ${KHAREJ_USER}@${KHAREJ_IP}
Restart=always
RestartSec=3
LimitNOFILE=1048576
LimitNPROC=1048576

[Install]
WantedBy=multi-user.target
EOF
            
            systemctl daemon-reload
            systemctl enable "sshsaeed-tunnel${tunnel_num}" >/dev/null 2>&1
            systemctl start "sshsaeed-tunnel${tunnel_num}" 2>/dev/null
            
            sleep 1
            
            if systemctl is-active "sshsaeed-tunnel${tunnel_num}" >/dev/null 2>&1; then
                print_done "تانل ${tunnel_num} فعال شد (${remote_port} → ${port})"
            else
                print_err "تانل ${tunnel_num} فعال نشد"
            fi
        done
        echo ""
    done
    
    # ═══════════ مرحله 8: ذخیره تنظیمات ═══════════
    ((step++))
    printf "  ${C}[%d/%d]${N} ${W}ذخیره تنظیمات...${N}\n" "$step" "$total_steps"
    
    cat > "$CONFIG_FILE" << EOF
# SSHSaeed Configuration - Iran Server
SERVER_TYPE=iran
KHAREJ_IP=$KHAREJ_IP
KHAREJ_USER=$KHAREJ_USER
SSH_PORT=$SSH_PORT
TUNNEL_COUNT=$TUNNEL_COUNT
TARGET_PORTS=$target_ports
CIPHER=$CIPHER
KEY_FILE=$KEY_FILE
SETUP_DATE=$(date '+%Y-%m-%d %H:%M:%S')
SCRIPT_VERSION=$SCRIPT_VERSION
EOF
    
    print_ok "تنظیمات ذخیره شد"
    echo ""
    
    # نتیجه نهایی
    line
    printf "    ${G}${ICO_OK} سرور ایران با موفقیت تنظیم شد!${N}\n"
    line
    echo ""
    printf "    ${W}خلاصه تنظیمات:${N}\n"
    printf "    ${C}│${N} سرور خارج: ${W}%s@%s:%s${N}\n" "$KHAREJ_USER" "$KHAREJ_IP" "$SSH_PORT"
    printf "    ${C}│${N} تعداد تانل: ${W}%s${N}\n" "$tunnel_num"
    printf "    ${C}│${N} پورت‌ها: ${W}%s${N}\n" "$target_ports"
    printf "    ${C}│${N} Cipher: ${W}%s${N}\n" "$CIPHER"
    echo ""
    
    log "INFO" "Iran server setup completed - Tunnels: $tunnel_num"
    
    read -p "$(printf "    ${C}Enter برای بازگشت به منو...${N}")"
}

# ═══════════════════════════════════════════════════════════════════════════════
#                         حذف کامل
# ═══════════════════════════════════════════════════════════════════════════════
uninstall_all() {
    show_banner
    line
    printf "    ${R}حذف کامل SSHSaeed${N}\n"
    line
    echo ""
    
    printf "    ${Y}${ICO_WARN} این عمل همه تانل‌ها و تنظیمات را حذف می‌کند!${N}\n"
    echo ""
    read -p "$(printf "    ${R}آیا مطمئن هستید؟ [y/N]: ${N}")" confirm
    
    if [[ "$confirm" != "y" && "$confirm" != "Y" ]]; then
        print_info "لغو شد"
        sleep 2
        return
    fi
    
    echo ""
    print_info "در حال حذف..."
    
    # توقف و حذف سرویس‌های تانل
    for service in /etc/systemd/system/sshsaeed-*.service; do
        [[ -f "$service" ]] || continue
        local svc_name=$(basename "$service" .service)
        systemctl stop "$svc_name" 2>/dev/null
        systemctl disable "$svc_name" 2>/dev/null
        rm -f "$service"
        print_ok "سرویس $svc_name حذف شد"
    done
    
    systemctl daemon-reload
    
    # حذف فایل‌های کانفیگ
    rm -rf "$INSTALL_DIR"
    rm -f /usr/local/bin/sshsaeed
    
    # حذف کاربر تانل (اختیاری)
    read -p "$(printf "    ${Y}کاربر '%s' هم حذف شود؟ [y/N]: ${N}" "$TUNNEL_USER")" del_user
    if [[ "$del_user" == "y" || "$del_user" == "Y" ]]; then
        userdel -r "$TUNNEL_USER" 2>/dev/null && print_ok "کاربر حذف شد"
    fi
    
    echo ""
    print_ok "حذف کامل انجام شد"
    
    log "INFO" "SSHSaeed uninstalled"
    
    sleep 3
}

# ═══════════════════════════════════════════════════════════════════════════════
#                         منوی اصلی
# ═══════════════════════════════════════════════════════════════════════════════
main_menu() {
    while true; do
        show_banner
        
        # بررسی نوع سرور
        local server_type="نامشخص"
        if [[ -f "$CONFIG_FILE" ]]; then
            source "$CONFIG_FILE" 2>/dev/null
            server_type="${SERVER_TYPE:-نامشخص}"
        fi
        
        printf "    ${C}┌─────────────────────────────────────────────────────────┐${N}\n"
        printf "    ${C}│${N}  ${W}نوع سرور:${N} %-43s ${C}│${N}\n" "$server_type"
        printf "    ${C}└─────────────────────────────────────────────────────────┘${N}\n"
        echo ""
        
        printf "    ${W}═══ منوی اصلی ═══${N}\n"
        echo ""
        printf "    ${C}[${W}1${C}]${N} ${G}تست سرعت رمزنگاری AES${N}\n"
        printf "    ${C}[${W}2${C}]${N} ${Y}تنظیم سرور خارج (Kharej)${N}\n"
        printf "    ${C}[${W}3${C}]${N} ${Y}تنظیم سرور ایران (Iran)${N}\n"
        printf "    ${C}[${W}4${C}]${N} ${B}مشاهده وضعیت${N}\n"
        printf "    ${C}[${W}5${C}]${N} ${B}مدیریت تانل‌ها${N}\n"
        printf "    ${C}[${W}6${C}]${N} ${M}رفع محدودیت‌های سیستم${N}\n"
        printf "    ${C}[${W}7${C}]${N} ${R}حذف کامل${N}\n"
        printf "    ${C}[${W}0${C}]${N} خروج\n"
        echo ""
        
        read -p "$(printf "    ${Y}انتخاب شما: ${N}")" choice
        
        case $choice in
            1) test_cipher_speed ;;
            2) setup_kharej_server ;;
            3) setup_iran_server ;;
            4) show_status ;;
            5) manage_tunnels ;;
            6) 
                remove_all_limits
                echo ""
                print_ok "محدودیت‌ها رفع شد. ریبوت برای اعمال کامل توصیه می‌شود."
                read -p "$(printf "    ${C}Enter برای بازگشت...${N}")"
                ;;
            7) uninstall_all ;;
            0) 
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
#                         نقطه ورود اصلی
# ═══════════════════════════════════════════════════════════════════════════════
main() {
    # بررسی دسترسی root
    if [[ $EUID -ne 0 ]]; then
        echo -e "${R}این اسکریپت نیاز به دسترسی root دارد${N}"
        echo -e "${Y}لطفاً با sudo اجرا کنید: sudo $0${N}"
        exit 1
    fi
    
    # ایجاد دایرکتوری‌ها
    mkdir -p "$INSTALL_DIR" "$BACKUP_DIR"
    
    # لود تنظیمات قبلی
    [[ -f "$CONFIG_FILE" ]] && source "$CONFIG_FILE" 2>/dev/null
    
    # لاگ شروع
    log "INFO" "SSHSaeed v$SCRIPT_VERSION started"
    
    # اجرای منوی اصلی
    main_menu
}

# ═══════════════════════════════════════════════════════════════════════════════
#                         اجرا
# ═══════════════════════════════════════════════════════════════════════════════
main "$@"
