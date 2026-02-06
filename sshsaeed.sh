#!/bin/bash
# ═══════════════════════════════════════════════════════════════════════════════
#  ███████╗███████╗██╗  ██╗███████╗ █████╗ ███████╗███████╗██████╗
#  ██╔════╝██╔════╝██║  ██║██╔════╝██╔══██╗██╔════╝██╔════╝██╔══██╗
#  ███████╗███████╗███████║███████╗███████║█████╗  █████╗  ██║  ██║
#  ╚════██║╚════██║██╔══██║╚════██║██╔══██║██╔══╝  ██╔══╝  ██║  ██║
#  ███████║███████║██║  ██║███████║██║  ██║███████╗███████╗██████╔╝
#  ╚══════╝╚══════╝╚═╝  ╚═╝╚══════╝╚═╝  ╚═╝╚══════╝╚══════╝╚═════╝
# ═══════════════════════════════════════════════════════════════════════════════
#  SSH Tunnel Manager v6.0 | Multi-Port per Tunnel | HAProxy Load Balance
#  GitHub: https://github.com/saeedkars/sshsaeed
# ═══════════════════════════════════════════════════════════════════════════════

set -o pipefail
export LC_ALL=C
export LANG=C

# ═══════════════════════════════════════════════════════════════════════════════
#                         ثابت‌های اصلی برنامه
# ═══════════════════════════════════════════════════════════════════════════════
readonly SCRIPT_VERSION="6.0"
readonly GITHUB_URL="https://github.com/saeedkars/sshsaeed"
readonly CONFIG_DIR="/etc/sshsaeed"
readonly CONFIG_FILE="$CONFIG_DIR/config.conf"
readonly KEY_FILE="/root/.ssh/sshsaeed_ed25519"
readonly LOG_FILE="/var/log/sshsaeed.log"
readonly BACKUP_DIR="$CONFIG_DIR/backups"
readonly TUNNEL_USER="tunneluser"
readonly CIPHER="aes128-gcm@openssh.com"

DEFAULT_PORTS="443,80"
DEFAULT_TUNNEL_COUNT=3
DEFAULT_SSH_PORT=22

declare -a TARGET_PORTS=()
TUNNEL_COUNT=3
KHAREJ_IP=""
KHAREJ_USER="tunneluser"
SSH_PORT=22
SERVER_TYPE=""

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

ICO_OK="✓"
ICO_ERR="✗"
ICO_WARN="⚠"
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
    printf "${C}"
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
    printf "    ${Y}Version:${N} ${W}${SCRIPT_VERSION}${N}  ${Y}|${N}  ${C}AES-128-GCM + HAProxy + BBR${N}\n"
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
    mkdir -p "$(dirname "$LOG_FILE")" 2>/dev/null
    printf "[%s] [%-5s] %s\n" "$timestamp" "$level" "$message" >> "$LOG_FILE" 2>/dev/null
}

log_info()  { log "INFO" "$1"; }
log_warn()  { log "WARN" "$1"; }
log_error() { log "ERROR" "$1"; }

# ═══════════════════════════════════════════════════════════════════════════════
#                    تشخیص سیستم‌عامل (بدون source کردن)
# ═══════════════════════════════════════════════════════════════════════════════
get_os_info() {
    local os_name="Unknown"
    if [[ -f /etc/os-release ]]; then
        os_name=$(grep "^PRETTY_NAME=" /etc/os-release 2>/dev/null | cut -d'=' -f2 | tr -d '"')
        [[ -z "$os_name" ]] && os_name=$(grep "^NAME=" /etc/os-release 2>/dev/null | cut -d'=' -f2 | tr -d '"')
    elif [[ -f /etc/redhat-release ]]; then
        os_name=$(cat /etc/redhat-release)
    elif [[ -f /etc/debian_version ]]; then
        os_name="Debian $(cat /etc/debian_version)"
    fi
    echo "$os_name"
}

get_os_id() {
    local os_id="unknown"
    if [[ -f /etc/os-release ]]; then
        os_id=$(grep "^ID=" /etc/os-release 2>/dev/null | cut -d'=' -f2 | tr -d '"')
    fi
    echo "$os_id"
}

# ═══════════════════════════════════════════════════════════════════════════════
#                              بررسی پیش‌نیازها
# ═══════════════════════════════════════════════════════════════════════════════
check_root() {
    if [[ $EUID -ne 0 ]]; then
        print_err "این اسکریپت نیاز به دسترسی root دارد"
        print_info "لطفاً با sudo اجرا کنید: sudo $0"
        exit 1
    fi
}

check_os() {
    local os_id=$(get_os_id)
    case "$os_id" in
        ubuntu|debian|centos|almalinux|rocky|fedora|rhel)
            print_ok "سیستم‌عامل پشتیبانی می‌شود: $(get_os_info)"
            return 0
            ;;
        *)
            print_warn "سیستم‌عامل ناشناخته: $os_id"
            print_info "ادامه با ریسک خودتان..."
            return 0
            ;;
    esac
}

# ═══════════════════════════════════════════════════════════════════════════════
#                              نصب پکیج‌ها
# ═══════════════════════════════════════════════════════════════════════════════
install_packages() {
    local packages=("$@")
    local os_id=$(get_os_id)
    
    print_info "نصب پکیج‌ها: ${packages[*]}"
    
    case "$os_id" in
        ubuntu|debian)
            export DEBIAN_FRONTEND=noninteractive
            apt-get update -qq >/dev/null 2>&1
            for pkg in "${packages[@]}"; do
                if ! dpkg -l "$pkg" &>/dev/null; then
                    apt-get install -y -qq "$pkg" >/dev/null 2>&1
                fi
            done
            ;;
        centos|almalinux|rocky|rhel|fedora)
            for pkg in "${packages[@]}"; do
                if ! rpm -q "$pkg" &>/dev/null; then
                    yum install -y -q "$pkg" >/dev/null 2>&1 || dnf install -y -q "$pkg" >/dev/null 2>&1
                fi
            done
            ;;
    esac
    
    print_ok "پکیج‌ها نصب شدند"
}

install_base_packages() {
    local base_pkgs=(openssh-client openssh-server curl wget jq bc socat netcat-openbsd net-tools)
    install_packages "${base_pkgs[@]}"
}

install_haproxy() {
    if command -v haproxy &>/dev/null; then
        print_ok "HAProxy از قبل نصب است"
        return 0
    fi
    
    print_info "نصب HAProxy..."
    local os_id=$(get_os_id)
    
    case "$os_id" in
        ubuntu|debian)
            apt-get install -y -qq haproxy >/dev/null 2>&1
            ;;
        centos|almalinux|rocky|rhel|fedora)
            yum install -y -q haproxy >/dev/null 2>&1 || dnf install -y -q haproxy >/dev/null 2>&1
            ;;
    esac
    
    if command -v haproxy &>/dev/null; then
        print_ok "HAProxy نصب شد"
        systemctl enable haproxy >/dev/null 2>&1
    else
        print_err "خطا در نصب HAProxy"
        return 1
    fi
}

# ═══════════════════════════════════════════════════════════════════════════════
#                           مدیریت کلید SSH
# ═══════════════════════════════════════════════════════════════════════════════
generate_ssh_key() {
    print_info "تولید کلید SSH (Ed25519)..."
    
    mkdir -p /root/.ssh
    chmod 700 /root/.ssh
    
    if [[ -f "$KEY_FILE" ]]; then
        print_warn "کلید SSH موجود است"
        read -p "    آیا کلید جدید ایجاد شود؟ [y/N]: " confirm
        if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
            print_info "از کلید موجود استفاده می‌شود"
            return 0
        fi
        mv "$KEY_FILE" "${KEY_FILE}.backup.$(date +%s)"
        mv "${KEY_FILE}.pub" "${KEY_FILE}.pub.backup.$(date +%s)" 2>/dev/null
    fi
    
    ssh-keygen -t ed25519 -f "$KEY_FILE" -N "" -C "sshsaeed@$(hostname)" >/dev/null 2>&1
    
    if [[ -f "$KEY_FILE" ]]; then
        chmod 600 "$KEY_FILE"
        chmod 644 "${KEY_FILE}.pub"
        print_ok "کلید SSH ایجاد شد"
        log_info "SSH key generated: $KEY_FILE"
        return 0
    else
        print_err "خطا در ایجاد کلید SSH"
        log_error "Failed to generate SSH key"
        return 1
    fi
}

copy_ssh_key() {
    local target_ip="$1"
    local target_user="$2"
    local target_port="${3:-22}"
    
    if [[ ! -f "${KEY_FILE}.pub" ]]; then
        print_err "کلید عمومی یافت نشد"
        return 1
    fi
    
    print_info "کپی کلید به ${target_user}@${target_ip}:${target_port}..."
    print_warn "رمز عبور سرور خارج را وارد کنید:"
    
    ssh-copy-id -i "${KEY_FILE}.pub" -p "$target_port" \
        -o StrictHostKeyChecking=no \
        -o ConnectTimeout=30 \
        "${target_user}@${target_ip}" 2>/dev/null
    
    if [[ $? -eq 0 ]]; then
        print_ok "کلید SSH با موفقیت کپی شد"
        return 0
    else
        print_err "خطا در کپی کلید SSH"
        print_info "لطفاً دستی این کلید را در سرور خارج اضافه کنید:"
        echo ""
        cat "${KEY_FILE}.pub"
        echo ""
        return 1
    fi
}

test_ssh_connection() {
    local target_ip="$1"
    local target_user="$2"
    local target_port="${3:-22}"
    
    print_info "تست اتصال SSH به ${target_ip}..."
    
    local result=$(ssh -i "$KEY_FILE" -p "$target_port" \
        -o StrictHostKeyChecking=no \
        -o ConnectTimeout=10 \
        -o BatchMode=yes \
        "${target_user}@${target_ip}" "echo OK" 2>/dev/null)
    
    if [[ "$result" == "OK" ]]; then
        print_ok "اتصال SSH موفق"
        return 0
    else
        print_err "اتصال SSH ناموفق"
        return 1
    fi
}

# ═══════════════════════════════════════════════════════════════════════════════
#                    حذف تمام محدودیت‌های سیستم (مهم!)
# ═══════════════════════════════════════════════════════════════════════════════
remove_all_limits() {
    print_info "حذف محدودیت‌های سیستم و بهینه‌سازی..."
    
    # تنظیم ulimit برای این سشن
    ulimit -n 1048576 2>/dev/null || ulimit -n 65535 2>/dev/null
    ulimit -u 1048576 2>/dev/null || ulimit -u 65535 2>/dev/null
    
    # تنظیمات دائمی limits.conf
    cat > /etc/security/limits.d/99-sshsaeed.conf << 'EOF'
*               soft    nofile          1048576
*               hard    nofile          1048576
*               soft    nproc           1048576
*               hard    nproc           1048576
root            soft    nofile          1048576
root            hard    nofile          1048576
root            soft    nproc           1048576
root            hard    nproc           1048576
EOF
    
    # تنظیمات sysctl برای حداکثر کارایی
    cat > /etc/sysctl.d/99-sshsaeed.conf << 'EOF'
# Maximum open files
fs.file-max = 2097152
fs.nr_open = 2097152

# Network performance
net.core.somaxconn = 65535
net.core.netdev_max_backlog = 65535
net.core.rmem_max = 134217728
net.core.wmem_max = 134217728
net.core.rmem_default = 16777216
net.core.wmem_default = 16777216
net.core.optmem_max = 65535

# TCP performance
net.ipv4.tcp_rmem = 4096 87380 134217728
net.ipv4.tcp_wmem = 4096 65536 134217728
net.ipv4.tcp_max_syn_backlog = 65535
net.ipv4.tcp_max_tw_buckets = 2000000
net.ipv4.tcp_tw_reuse = 1
net.ipv4.tcp_fin_timeout = 10
net.ipv4.tcp_slow_start_after_idle = 0
net.ipv4.tcp_keepalive_time = 60
net.ipv4.tcp_keepalive_intvl = 10
net.ipv4.tcp_keepalive_probes = 6
net.ipv4.tcp_mtu_probing = 1
net.ipv4.tcp_syncookies = 1
net.ipv4.ip_local_port_range = 1024 65535
net.ipv4.tcp_fastopen = 3

# Connection tracking
net.netfilter.nf_conntrack_max = 2097152
net.nf_conntrack_max = 2097152

# BBR congestion control
net.core.default_qdisc = fq
net.ipv4.tcp_congestion_control = bbr

# IPv4 forwarding
net.ipv4.ip_forward = 1
EOF
    
    # بارگذاری ماژول BBR
    modprobe tcp_bbr 2>/dev/null
    
    # اعمال تنظیمات
    sysctl -p /etc/sysctl.d/99-sshsaeed.conf >/dev/null 2>&1
    sysctl --system >/dev/null 2>&1
    
    # بررسی BBR
    local current_cc=$(sysctl -n net.ipv4.tcp_congestion_control 2>/dev/null)
    if [[ "$current_cc" == "bbr" ]]; then
        print_ok "BBR فعال شد"
    else
        print_warn "BBR فعال نشد (از $current_cc استفاده می‌شود)"
    fi
    
    print_ok "محدودیت‌های سیستم حذف شدند"
    log_info "System limits removed, BBR enabled"
}

# ═══════════════════════════════════════════════════════════════════════════════
#                         بهینه‌سازی SSH Config
# ═══════════════════════════════════════════════════════════════════════════════
optimize_ssh_config() {
    local is_kharej="${1:-false}"
    
    print_info "بهینه‌سازی تنظیمات SSH..."
    
    local sshd_config="/etc/ssh/sshd_config"
    
    # بکاپ
    cp "$sshd_config" "${sshd_config}.backup.$(date +%s)" 2>/dev/null
    
    # حذف تنظیمات قبلی
    sed -i '/^MaxSessions/d' "$sshd_config"
    sed -i '/^MaxStartups/d' "$sshd_config"
    sed -i '/^ClientAliveInterval/d' "$sshd_config"
    sed -i '/^ClientAliveCountMax/d' "$sshd_config"
    sed -i '/^TCPKeepAlive/d' "$sshd_config"
    sed -i '/^GatewayPorts/d' "$sshd_config"
    sed -i '/^AllowTcpForwarding/d' "$sshd_config"
    sed -i '/^PermitTunnel/d' "$sshd_config"
    
    # تنظیمات جدید
    cat >> "$sshd_config" << EOF

# SSHSaeed Optimizations v${SCRIPT_VERSION}
MaxSessions 500
MaxStartups 500:30:1000
ClientAliveInterval 30
ClientAliveCountMax 10
TCPKeepAlive yes
AllowTcpForwarding yes
PermitTunnel yes
EOF
    
    # فقط برای سرور خارج GatewayPorts
    if [[ "$is_kharej" == "true" ]]; then
        echo "GatewayPorts yes" >> "$sshd_config"
        print_ok "GatewayPorts فعال شد"
    fi
    
    # ریستارت SSH
    systemctl restart sshd 2>/dev/null || systemctl restart ssh 2>/dev/null
    
    print_ok "SSH بهینه‌سازی شد (MaxSessions: 500)"
    log_info "SSH optimized with MaxSessions=500"
}

# ═══════════════════════════════════════════════════════════════════════════════
#                    ایجاد سرویس تانل (نسخه جدید - همه پورت‌ها در یک تانل)
# ═══════════════════════════════════════════════════════════════════════════════
create_tunnel_service() {
    local tunnel_num="$1"
    local kharej_ip="$2"
    local kharej_user="$3"
    local ssh_port="$4"
    local local_base_port="$5"
    shift 5
    local ports=("$@")
    
    local service_name="sshsaeed-tunnel${tunnel_num}"
    local service_file="/etc/systemd/system/${service_name}.service"
    
    # ساخت لیست فوروارد پورت‌ها (همه پورت‌ها در یک تانل)
    local port_forwards=""
    local port_index=0
    for port in "${ports[@]}"; do
        local remote_port=$((local_base_port + port_index))
        port_forwards+=" -R ${remote_port}:127.0.0.1:${port}"
        ((port_index++))
    done
    
    cat > "$service_file" << EOF
[Unit]
Description=SSHSaeed Tunnel ${tunnel_num} (All Ports)
After=network-online.target
Wants=network-online.target
StartLimitIntervalSec=0

[Service]
Type=simple
User=root
Environment="AUTOSSH_GATETIME=0"
Environment="AUTOSSH_PORT=0"
Environment="AUTOSSH_POLL=30"
ExecStart=/usr/bin/autossh -M 0 -N -o "ServerAliveInterval=10" -o "ServerAliveCountMax=3" -o "ExitOnForwardFailure=yes" -o "StrictHostKeyChecking=no" -o "UserKnownHostsFile=/dev/null" -o "TCPKeepAlive=yes" -o "Compression=no" -c ${CIPHER} -i ${KEY_FILE} -p ${ssh_port}${port_forwards} ${kharej_user}@${kharej_ip}
Restart=always
RestartSec=5
LimitNOFILE=1048576
LimitNPROC=1048576

[Install]
WantedBy=multi-user.target
EOF
    
    systemctl daemon-reload
    systemctl enable "$service_name" >/dev/null 2>&1
    systemctl restart "$service_name"
    
    if systemctl is-active --quiet "$service_name"; then
        print_ok "تانل ${tunnel_num} ایجاد شد (${#ports[@]} پورت)"
        return 0
    else
        print_err "خطا در ایجاد تانل ${tunnel_num}"
        return 1
    fi
}
# ═══════════════════════════════════════════════════════════════════════════════
#                    ایجاد تانل‌ها برای همه پورت‌ها (نسخه جدید)
# ═══════════════════════════════════════════════════════════════════════════════
create_all_tunnels() {
    local kharej_ip="$1"
    local kharej_user="$2"
    local ssh_port="$3"
    local tunnel_count="$4"
    shift 4
    local ports=("$@")
    
    print_info "ایجاد ${tunnel_count} تانل (هر تانل شامل ${#ports[@]} پورت)..."
    echo ""
    
    local success_count=0
    local base_port=10000
    
    for ((i=1; i<=tunnel_count; i++)); do
        local tunnel_base=$((base_port + (i-1) * 100))
        
        printf "    ${C}[%d/%d]${N} تانل %d با پورت‌های %s...\n" "$i" "$tunnel_count" "$i" "${ports[*]}"
        
        if create_tunnel_service "$i" "$kharej_ip" "$kharej_user" "$ssh_port" "$tunnel_base" "${ports[@]}"; then
            ((success_count++))
        fi
        
        sleep 1
    done
    
    echo ""
    if [[ $success_count -eq $tunnel_count ]]; then
        print_ok "همه ${tunnel_count} تانل با موفقیت ایجاد شدند"
        return 0
    else
        print_warn "${success_count}/${tunnel_count} تانل ایجاد شد"
        return 1
    fi
}

# ═══════════════════════════════════════════════════════════════════════════════
#                         پیکربندی HAProxy (سرور خارج)
# ═══════════════════════════════════════════════════════════════════════════════
configure_haproxy() {
    local tunnel_count="$1"
    shift
    local ports=("$@")
    
    print_info "پیکربندی HAProxy با Load Balancing..."
    
    local haproxy_cfg="/etc/haproxy/haproxy.cfg"
    local backup_cfg="${haproxy_cfg}.backup.$(date +%s)"
    
    # بکاپ
    [[ -f "$haproxy_cfg" ]] && cp "$haproxy_cfg" "$backup_cfg"
    
    # شروع کانفیگ
    cat > "$haproxy_cfg" << 'EOF'
#---------------------------------------------------------------------
# HAProxy Configuration - Generated by SSHSaeed v6.0
#---------------------------------------------------------------------

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

#---------------------------------------------------------------------
# Stats Page - Port 8404
#---------------------------------------------------------------------
listen stats
    bind *:8404
    mode http
    stats enable
    stats uri /stats
    stats refresh 5s
    stats admin if TRUE
    stats show-legends
    stats show-node

EOF
    
    # ایجاد frontend و backend برای هر پورت
    local base_port=10000
    
    for port in "${ports[@]}"; do
        cat >> "$haproxy_cfg" << EOF
#---------------------------------------------------------------------
# Port ${port} - Load Balanced across ${tunnel_count} tunnels
#---------------------------------------------------------------------
frontend ft_port_${port}
    bind *:${port}
    mode tcp
    default_backend bk_port_${port}

backend bk_port_${port}
    mode tcp
    balance roundrobin
    option tcp-check
EOF
        
        # اضافه کردن سرورها (تانل‌ها)
        for ((i=1; i<=tunnel_count; i++)); do
            local tunnel_base=$((base_port + (i-1) * 100))
            local port_index=0
            
            # پیدا کردن اندیس پورت در آرایه
            for ((j=0; j<${#ports[@]}; j++)); do
                if [[ "${ports[$j]}" == "$port" ]]; then
                    port_index=$j
                    break
                fi
            done
            
            local remote_port=$((tunnel_base + port_index))
            
            cat >> "$haproxy_cfg" << EOF
    server tunnel${i} 127.0.0.1:${remote_port} check inter 5s fall 3 rise 2 weight 100
EOF
        done
        
        echo "" >> "$haproxy_cfg"
    done
    
    # تست کانفیگ
    if haproxy -c -f "$haproxy_cfg" >/dev/null 2>&1; then
        print_ok "کانفیگ HAProxy معتبر است"
        
        systemctl restart haproxy
        
        if systemctl is-active --quiet haproxy; then
            print_ok "HAProxy راه‌اندازی شد"
            print_info "صفحه وضعیت: http://YOUR_IP:8404/stats"
            return 0
        else
            print_err "خطا در راه‌اندازی HAProxy"
            return 1
        fi
    else
        print_err "کانفیگ HAProxy نامعتبر است"
        [[ -f "$backup_cfg" ]] && cp "$backup_cfg" "$haproxy_cfg"
        return 1
    fi
}

# ═══════════════════════════════════════════════════════════════════════════════
#                         ایجاد Socat Listeners (سرور ایران)
# ═══════════════════════════════════════════════════════════════════════════════
create_socat_listener() {
    local listen_port="$1"
    local forward_port="$2"
    local service_name="sshsaeed-socat-${listen_port}"
    local service_file="/etc/systemd/system/${service_name}.service"
    
    cat > "$service_file" << EOF
[Unit]
Description=SSHSaeed Socat Listener Port ${listen_port}
After=network.target
StartLimitIntervalSec=0

[Service]
Type=simple
ExecStart=/usr/bin/socat -d TCP-LISTEN:${listen_port},fork,reuseaddr,nodelay,keepalive TCP:127.0.0.1:${forward_port}
Restart=always
RestartSec=3
LimitNOFILE=1048576
LimitNPROC=1048576

[Install]
WantedBy=multi-user.target
EOF
    
    systemctl daemon-reload
    systemctl enable "$service_name" >/dev/null 2>&1
    systemctl restart "$service_name"
    
    if systemctl is-active --quiet "$service_name"; then
        return 0
    else
        return 1
    fi
}

create_local_haproxy() {
    local tunnel_count="$1"
    shift
    local ports=("$@")
    
    print_info "پیکربندی HAProxy محلی برای Load Balancing..."
    
    local haproxy_cfg="/etc/haproxy/haproxy.cfg"
    
    cat > "$haproxy_cfg" << 'EOF'
#---------------------------------------------------------------------
# HAProxy Configuration - Iran Server - SSHSaeed v6.0
#---------------------------------------------------------------------

global
    log /dev/log local0
    chroot /var/lib/haproxy
    stats socket /run/haproxy/admin.sock mode 660 level admin
    stats timeout 30s
    user haproxy
    group haproxy
    daemon
    maxconn 500000

defaults
    log     global
    mode    tcp
    option  tcplog
    option  dontlognull
    timeout connect 10s
    timeout client  300s
    timeout server  300s
    timeout tunnel  1h
    retries 3

listen stats
    bind *:8404
    mode http
    stats enable
    stats uri /stats
    stats refresh 5s

EOF
    
    local base_port=10000
    
    for port in "${ports[@]}"; do
        cat >> "$haproxy_cfg" << EOF
#---------------------------------------------------------------------
# Port ${port} - Reverse tunnels load balanced
#---------------------------------------------------------------------
frontend ft_local_${port}
    bind *:${port}
    mode tcp
    default_backend bk_local_${port}

backend bk_local_${port}
    mode tcp
    balance roundrobin
EOF
        
        for ((i=1; i<=tunnel_count; i++)); do
            local tunnel_base=$((base_port + (i-1) * 100))
            local port_index=0
            
            for ((j=0; j<${#ports[@]}; j++)); do
                if [[ "${ports[$j]}" == "$port" ]]; then
                    port_index=$j
                    break
                fi
            done
            
            local local_port=$((tunnel_base + port_index))
            
            cat >> "$haproxy_cfg" << EOF
    server local_tunnel${i} 127.0.0.1:${local_port} check inter 5s fall 3 rise 2
EOF
        done
        
        echo "" >> "$haproxy_cfg"
    done
    
    if haproxy -c -f "$haproxy_cfg" >/dev/null 2>&1; then
        systemctl restart haproxy
        print_ok "HAProxy محلی راه‌اندازی شد"
        return 0
    else
        print_err "خطا در کانفیگ HAProxy"
        return 1
    fi
}

# ═══════════════════════════════════════════════════════════════════════════════
#                              تست سرعت Cipher
# ═══════════════════════════════════════════════════════════════════════════════
test_cipher_speed() {
    show_banner
    line
    printf "    ${W}تست سرعت رمزنگاری AES${N}\n"
    line
    echo ""
    
    # بررسی پشتیبانی AES-NI
    printf "    ${C}بررسی پشتیبانی سخت‌افزاری AES-NI...${N}\n"
    echo ""
    
    if grep -q 'aes' /proc/cpuinfo 2>/dev/null; then
        print_ok "AES-NI پشتیبانی می‌شود ✓"
        local aes_ni="yes"
    else
        print_warn "AES-NI پشتیبانی نمی‌شود"
        local aes_ni="no"
    fi
    
    echo ""
    line_thin
    printf "    ${W}تست سرعت OpenSSL...${N}\n"
    line_thin
    echo ""
    
    # تست AES-128-GCM
    printf "    ${C}تست aes-128-gcm (سریع‌ترین):${N}\n"
    local aes128_result=$(openssl speed -evp aes-128-gcm 2>/dev/null | grep "aes-128-gcm" | tail -1)
    if [[ -n "$aes128_result" ]]; then
        local aes128_speed=$(echo "$aes128_result" | awk '{print $NF}')
        printf "    سرعت: ${G}%s${N} bytes/sec\n" "$aes128_speed"
    else
        # تست جایگزین
        local speed_test=$(openssl speed -elapsed -evp aes-128-gcm 2>&1 | tail -5)
        echo "$speed_test" | while read line; do
            [[ -n "$line" ]] && printf "    %s\n" "$line"
        done
    fi
    
    echo ""
    
    # تست AES-256-GCM برای مقایسه
    printf "    ${C}تست aes-256-gcm (مقایسه):${N}\n"
    local aes256_result=$(openssl speed -evp aes-256-gcm 2>/dev/null | grep "aes-256-gcm" | tail -1)
    if [[ -n "$aes256_result" ]]; then
        local aes256_speed=$(echo "$aes256_result" | awk '{print $NF}')
        printf "    سرعت: ${Y}%s${N} bytes/sec\n" "$aes256_speed"
    fi
    
    echo ""
    
    # تست ChaCha20 برای مقایسه
    printf "    ${C}تست chacha20-poly1305 (مقایسه):${N}\n"
    local chacha_result=$(openssl speed -evp chacha20-poly1305 2>/dev/null | grep "chacha20-poly1305" | tail -1)
    if [[ -n "$chacha_result" ]]; then
        local chacha_speed=$(echo "$chacha_result" | awk '{print $NF}')
        printf "    سرعت: ${Y}%s${N} bytes/sec\n" "$chacha_speed"
    fi
    
    echo ""
    line_thin
    
    # امتیازدهی
    local score=0
    local max_score=5
    
    [[ "$aes_ni" == "yes" ]] && ((score+=2))
    
    local current_cc=$(sysctl -n net.ipv4.tcp_congestion_control 2>/dev/null)
    [[ "$current_cc" == "bbr" ]] && ((score+=2))
    
    local file_max=$(sysctl -n fs.file-max 2>/dev/null)
    [[ $file_max -ge 1000000 ]] && ((score+=1))
    
    echo ""
    printf "    ${W}امتیاز سیستم: ${G}%d${N}/${W}%d${N}\n" "$score" "$max_score"
    echo ""
    
    # جدول خلاصه
    printf "    ${C}┌─────────────────────────────────────────┐${N}\n"
    printf "    ${C}│${N}  %-18s │ %-15s ${C}│${N}\n" "ویژگی" "وضعیت"
    printf "    ${C}├─────────────────────────────────────────┤${N}\n"
    
    if [[ "$aes_ni" == "yes" ]]; then
        printf "    ${C}│${N}  %-18s │ ${G}%-15s${N} ${C}│${N}\n" "AES-NI" "فعال ✓"
    else
        printf "    ${C}│${N}  %-18s │ ${R}%-15s${N} ${C}│${N}\n" "AES-NI" "غیرفعال ✗"
    fi
    
    printf "    ${C}│${N}  %-18s │ ${G}%-15s${N} ${C}│${N}\n" "Cipher" "aes128-gcm"
    
    if [[ "$current_cc" == "bbr" ]]; then
        printf "    ${C}│${N}  %-18s │ ${G}%-15s${N} ${C}│${N}\n" "TCP BBR" "فعال ✓"
    else
        printf "    ${C}│${N}  %-18s │ ${Y}%-15s${N} ${C}│${N}\n" "TCP BBR" "$current_cc"
    fi
    
    printf "    ${C}│${N}  %-18s │ ${G}%-15s${N} ${C}│${N}\n" "fs.file-max" "$file_max"
    printf "    ${C}└─────────────────────────────────────────┘${N}\n"
    
    echo ""
    log_info "AES speed test completed - Score: $score/$max_score"
    
    # دکمه بازگشت
    echo ""
    read -p "    $(printf "${C}Enter برای بازگشت به منو...${N}")" _
    main_menu
}

# ═══════════════════════════════════════════════════════════════════════════════
#                              مدیریت فایروال
# ═══════════════════════════════════════════════════════════════════════════════
configure_firewall() {
    local action="$1"
    shift
    local ports=("$@")
    
    print_info "پیکربندی فایروال..."
    
    # UFW
    if command -v ufw &>/dev/null; then
        for port in "${ports[@]}"; do
            if [[ "$action" == "open" ]]; then
                ufw allow "$port"/tcp >/dev/null 2>&1
            else
                ufw delete allow "$port"/tcp >/dev/null 2>&1
            fi
        done
        # همیشه پورت stats را باز کن
        ufw allow 8404/tcp >/dev/null 2>&1
        print_ok "UFW پیکربندی شد"
    fi
    
    # Firewalld
    if command -v firewall-cmd &>/dev/null && systemctl is-active --quiet firewalld; then
        for port in "${ports[@]}"; do
            if [[ "$action" == "open" ]]; then
                firewall-cmd --permanent --add-port="${port}/tcp" >/dev/null 2>&1
            else
                firewall-cmd --permanent --remove-port="${port}/tcp" >/dev/null 2>&1
            fi
        done
        firewall-cmd --permanent --add-port="8404/tcp" >/dev/null 2>&1
        firewall-cmd --reload >/dev/null 2>&1
        print_ok "Firewalld پیکربندی شد"
    fi
    
    # iptables (fallback)
    if command -v iptables &>/dev/null; then
        for port in "${ports[@]}"; do
            if [[ "$action" == "open" ]]; then
                iptables -C INPUT -p tcp --dport "$port" -j ACCEPT 2>/dev/null || \
                iptables -I INPUT -p tcp --dport "$port" -j ACCEPT 2>/dev/null
            fi
        done
        iptables -C INPUT -p tcp --dport 8404 -j ACCEPT 2>/dev/null || \
        iptables -I INPUT -p tcp --dport 8404 -j ACCEPT 2>/dev/null
    fi
}

# ═══════════════════════════════════════════════════════════════════════════════
#                              ذخیره و بارگذاری کانفیگ
# ═══════════════════════════════════════════════════════════════════════════════
save_config() {
    mkdir -p "$CONFIG_DIR"
    
    cat > "$CONFIG_FILE" << EOF
# SSHSaeed Configuration v${SCRIPT_VERSION}
# Generated: $(date)

SERVER_TYPE="${SERVER_TYPE}"
KHAREJ_IP="${KHAREJ_IP}"
KHAREJ_USER="${KHAREJ_USER}"
SSH_PORT="${SSH_PORT}"
TUNNEL_COUNT="${TUNNEL_COUNT}"
TARGET_PORTS="${TARGET_PORTS[*]}"
CIPHER="${CIPHER}"
EOF
    
    chmod 600 "$CONFIG_FILE"
    print_ok "کانفیگ ذخیره شد: $CONFIG_FILE"
    log_info "Configuration saved"
}

load_config() {
    if [[ -f "$CONFIG_FILE" ]]; then
        source "$CONFIG_FILE"
        
        # تبدیل پورت‌ها به آرایه
        if [[ -n "$TARGET_PORTS" ]]; then
            IFS=' ' read -ra TARGET_PORTS <<< "$TARGET_PORTS"
        fi
        
        print_ok "کانفیگ بارگذاری شد"
        return 0
    else
        return 1
    fi
}

# ═══════════════════════════════════════════════════════════════════════════════
#                              نمایش وضعیت
# ═══════════════════════════════════════════════════════════════════════════════
show_status() {
    show_banner
    line
    printf "    ${W}وضعیت سرویس‌ها${N}\n"
    line
    echo ""
    
    # وضعیت تانل‌ها
    printf "    ${C}تانل‌های SSH:${N}\n"
    local tunnel_count=0
    local active_count=0
    
    for service in /etc/systemd/system/sshsaeed-tunnel*.service; do
        [[ -f "$service" ]] || continue
        ((tunnel_count++))
        
        local name=$(basename "$service" .service)
        if systemctl is-active --quiet "$name"; then
            printf "    ${G}●${N} %-25s ${G}[فعال]${N}\n" "$name"
            ((active_count++))
        else
            printf "    ${R}●${N} %-25s ${R}[غیرفعال]${N}\n" "$name"
        fi
    done
    
    [[ $tunnel_count -eq 0 ]] && printf "    ${GR}هیچ تانلی یافت نشد${N}\n"
    
    echo ""
    
    # وضعیت HAProxy
    printf "    ${C}HAProxy:${N}\n"
    if systemctl is-active --quiet haproxy; then
        printf "    ${G}●${N} haproxy                   ${G}[فعال]${N}\n"
    else
        printf "    ${R}●${N} haproxy                   ${R}[غیرفعال]${N}\n"
    fi
    
    echo ""
    
    # وضعیت socat
    printf "    ${C}Socat Listeners:${N}\n"
    local socat_count=0
    for service in /etc/systemd/system/sshsaeed-socat-*.service; do
        [[ -f "$service" ]] || continue
        ((socat_count++))
        
        local name=$(basename "$service" .service)
        if systemctl is-active --quiet "$name"; then
            printf "    ${G}●${N} %-25s ${G}[فعال]${N}\n" "$name"
        else
            printf "    ${R}●${N} %-25s ${R}[غیرفعال]${N}\n" "$name"
        fi
    done
    
    [[ $socat_count -eq 0 ]] && printf "    ${GR}هیچ listener یافت نشد${N}\n"
    
    echo ""
    line_thin
    
    # آمار سیستم
    printf "    ${C}آمار سیستم:${N}\n"
    printf "    فایل‌های باز: %s\n" "$(cat /proc/sys/fs/file-nr | awk '{print $1"/"$3}')"
    printf "    TCP Congestion: %s\n" "$(sysctl -n net.ipv4.tcp_congestion_control 2>/dev/null)"
    printf "    Uptime: %s\n" "$(uptime -p 2>/dev/null || uptime)"
    
    echo ""
    read -p "    $(printf "${C}Enter برای بازگشت...${N}")" _
    main_menu
}

# ═══════════════════════════════════════════════════════════════════════════════
#                         نصب autossh
# ═══════════════════════════════════════════════════════════════════════════════
install_autossh() {
    if command -v autossh &>/dev/null; then
        print_ok "autossh از قبل نصب است"
        return 0
    fi
    
    print_info "نصب autossh..."
    
    local os_id=$(get_os_id)
    case "$os_id" in
        ubuntu|debian)
            apt-get install -y -qq autossh >/dev/null 2>&1
            ;;
        centos|almalinux|rocky|rhel|fedora)
            yum install -y -q autossh >/dev/null 2>&1 || \
            dnf install -y -q autossh >/dev/null 2>&1 || \
            yum install -y -q epel-release && yum install -y -q autossh >/dev/null 2>&1
            ;;
    esac
    
    if command -v autossh &>/dev/null; then
        print_ok "autossh نصب شد"
        return 0
    else
        print_err "خطا در نصب autossh"
        return 1
    fi
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
    printf "  ${C}[%d/%d]${N} ${W}رفع محدودیت‌های سیستم (BBR + Ulimit + Kernel)...${N}\n" "$step" "$total_steps"
    remove_all_limits
    echo ""
    
    # ═══════════ مرحله 3: ایجاد کاربر تانل ═══════════
    ((step++))
    printf "  ${C}[%d/%d]${N} ${W}ایجاد کاربر تانل...${N}\n" "$step" "$total_steps"
    
    if id "$TUNNEL_USER" &>/dev/null; then
        print_ok "کاربر '$TUNNEL_USER' از قبل موجود است"
    else
        useradd -m -s /bin/bash "$TUNNEL_USER" 2>/dev/null
        print_ok "کاربر '$TUNNEL_USER' ایجاد شد"
    fi
    
    # ایجاد دایرکتوری .ssh
    local user_home=$(eval echo ~$TUNNEL_USER)
    mkdir -p "${user_home}/.ssh"
    chmod 700 "${user_home}/.ssh"
    touch "${user_home}/.ssh/authorized_keys"
    chmod 600 "${user_home}/.ssh/authorized_keys"
    chown -R "${TUNNEL_USER}:${TUNNEL_USER}" "${user_home}/.ssh"
    echo ""
    
    # ═══════════ مرحله 4: تنظیم SSH ═══════════
    ((step++))
    printf "  ${C}[%d/%d]${N} ${W}تنظیم SSH...${N}\n" "$step" "$total_steps"
    
    # تنظیمات پیشرفته SSH
    mkdir -p /etc/ssh/sshd_config.d
    cat > /etc/ssh/sshd_config.d/sshsaeed.conf << 'EOF'
# SSHSaeed v6.0 - Kharej Server Configuration
GatewayPorts yes
AllowTcpForwarding yes
PermitTunnel yes
TCPKeepAlive yes
ClientAliveInterval 30
ClientAliveCountMax 10
MaxSessions 500
MaxStartups 100:30:200
LoginGraceTime 60
PermitRootLogin yes
PubkeyAuthentication yes
PasswordAuthentication yes
EOF
    
    # اعمال تنظیمات
    systemctl reload sshd 2>/dev/null || systemctl reload ssh 2>/dev/null
    print_ok "SSH پیکربندی شد (GatewayPorts=yes, MaxSessions=500)"
    echo ""
    
    # ═══════════ مرحله 5: دریافت اطلاعات ═══════════
    ((step++))
    printf "  ${C}[%d/%d]${N} ${W}دریافت اطلاعات...${N}\n" "$step" "$total_steps"
    echo ""
    
    read -p "$(printf "    ${Y}تعداد تانل [${W}3${Y}]: ${N}")" input_count
    TUNNEL_COUNT="${input_count:-3}"
    
    read -p "$(printf "    ${Y}پورت‌های هدف (جدا با کاما) [${W}443,80${Y}]: ${N}")" input_ports
    local target_ports="${input_ports:-443,80}"
    
    # تبدیل به آرایه
    IFS=',' read -ra TARGET_PORTS <<< "$target_ports"
    # پاکسازی فاصله‌ها
    for i in "${!TARGET_PORTS[@]}"; do
        TARGET_PORTS[$i]=$(echo "${TARGET_PORTS[$i]}" | tr -d ' ')
    done
    
    echo ""
    print_info "تعداد تانل: $TUNNEL_COUNT"
    print_info "پورت‌ها: ${TARGET_PORTS[*]}"
    print_info "هر تانل شامل ${#TARGET_PORTS[@]} پورت خواهد بود"
    echo ""
    
    # ═══════════ مرحله 6: پیکربندی HAProxy ═══════════
    ((step++))
    printf "  ${C}[%d/%d]${N} ${W}پیکربندی HAProxy (Load Balancing)...${N}\n" "$step" "$total_steps"
    
    configure_haproxy "$TUNNEL_COUNT" "${TARGET_PORTS[@]}"
    
    # باز کردن پورت‌ها در فایروال
    configure_firewall "open" "${TARGET_PORTS[@]}"
    echo ""
    
    # ═══════════ مرحله 7: ذخیره کانفیگ ═══════════
    ((step++))
    printf "  ${C}[%d/%d]${N} ${W}ذخیره تنظیمات...${N}\n" "$step" "$total_steps"
    
    SERVER_TYPE="kharej"
    save_config
    
    echo ""
    line
    printf "    ${G}${ICO_OK} تنظیم سرور خارج کامل شد!${N}\n"
    line
    echo ""
    
    # نمایش خلاصه
    printf "    ${C}┌─────────────────────────────────────────────────────────┐${N}\n"
    printf "    ${C}│${N}  ${W}خلاصه تنظیمات سرور خارج${N}                               ${C}│${N}\n"
    printf "    ${C}├─────────────────────────────────────────────────────────┤${N}\n"
    printf "    ${C}│${N}  کاربر تانل: ${G}%-40s${N} ${C}│${N}\n" "$TUNNEL_USER"
    printf "    ${C}│${N}  تعداد تانل: ${G}%-40s${N} ${C}│${N}\n" "$TUNNEL_COUNT"
    printf "    ${C}│${N}  پورت‌ها: ${G}%-43s${N} ${C}│${N}\n" "${TARGET_PORTS[*]}"
    printf "    ${C}│${N}  HAProxy Stats: ${G}%-36s${N} ${C}│${N}\n" "http://IP:8404/stats"
    printf "    ${C}└─────────────────────────────────────────────────────────┘${N}\n"
    echo ""
    
    printf "    ${Y}${ICO_WARN} اکنون سرور ایران را تنظیم کنید${N}\n"
    echo ""
    
    log_info "Kharej server setup completed - Tunnels: $TUNNEL_COUNT, Ports: ${TARGET_PORTS[*]}"
    
    read -p "$(printf "    ${C}Enter برای بازگشت به منو...${N}")" _
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
    local total_steps=9
    
    # ═══════════ مرحله 1: نصب پکیج‌ها ═══════════
    ((step++))
    printf "  ${C}[%d/%d]${N} ${W}نصب پکیج‌ها...${N}\n" "$step" "$total_steps"
    install_packages
    install_autossh
    echo ""
    
    # ═══════════ مرحله 2: رفع محدودیت‌ها ═══════════
    ((step++))
    printf "  ${C}[%d/%d]${N} ${W}رفع محدودیت‌های سیستم (BBR + Ulimit + Kernel)...${N}\n" "$step" "$total_steps"
    remove_all_limits
    echo ""
    
    # ═══════════ مرحله 3: دریافت اطلاعات سرور خارج ═══════════
    ((step++))
    printf "  ${C}[%d/%d]${N} ${W}اطلاعات سرور خارج...${N}\n" "$step" "$total_steps"
    echo ""
    
    while true; do
        read -p "$(printf "    ${Y}آدرس IP سرور خارج: ${N}")" KHAREJ_IP
        if [[ -n "$KHAREJ_IP" ]]; then
            if [[ "$KHAREJ_IP" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]] || \
               [[ "$KHAREJ_IP" =~ ^[a-zA-Z0-9.-]+$ ]]; then
                break
            fi
        fi
        print_err "لطفاً یک آدرس IP یا دامنه معتبر وارد کنید"
    done
    
    read -p "$(printf "    ${Y}نام کاربری سرور خارج [${W}tunnel${Y}]: ${N}")" input_user
    KHAREJ_USER="${input_user:-tunnel}"
    
    read -p "$(printf "    ${Y}پورت SSH سرور خارج [${W}22${Y}]: ${N}")" input_port
    SSH_PORT="${input_port:-22}"
    
    read -p "$(printf "    ${Y}تعداد تانل [${W}3${Y}]: ${N}")" input_count
    TUNNEL_COUNT="${input_count:-3}"
    
    read -p "$(printf "    ${Y}پورت‌های هدف (جدا با کاما) [${W}443,80${Y}]: ${N}")" input_ports
    local target_ports="${input_ports:-443,80}"
    
    # تبدیل به آرایه
    IFS=',' read -ra TARGET_PORTS <<< "$target_ports"
    for i in "${!TARGET_PORTS[@]}"; do
        TARGET_PORTS[$i]=$(echo "${TARGET_PORTS[$i]}" | tr -d ' ')
    done
    
    echo ""
    print_ok "اطلاعات دریافت شد"
    print_info "هر تانل شامل ${#TARGET_PORTS[@]} پورت: ${TARGET_PORTS[*]}"
    echo ""
    
    # ═══════════ مرحله 4: تولید کلید SSH ═══════════
    ((step++))
    printf "  ${C}[%d/%d]${N} ${W}تولید کلید SSH...${N}\n" "$step" "$total_steps"
    
    mkdir -p "$CONFIG_DIR"
    
    if [[ -f "$KEY_FILE" ]]; then
        print_warn "کلید SSH از قبل موجود است"
        read -p "$(printf "    ${Y}کلید جدید ایجاد شود؟ [y/N]: ${N}")" regen
        if [[ "$regen" =~ ^[Yy]$ ]]; then
            rm -f "$KEY_FILE" "${KEY_FILE}.pub"
            ssh-keygen -t ed25519 -f "$KEY_FILE" -N "" -C "sshsaeed-tunnel" >/dev/null 2>&1
            print_ok "کلید جدید ایجاد شد"
        fi
    else
        ssh-keygen -t ed25519 -f "$KEY_FILE" -N "" -C "sshsaeed-tunnel" >/dev/null 2>&1
        print_ok "کلید SSH ایجاد شد"
    fi
    
    chmod 600 "$KEY_FILE"
    echo ""
    
    # ═══════════ مرحله 5: نمایش کلید عمومی ═══════════
    ((step++))
    printf "  ${C}[%d/%d]${N} ${W}کلید عمومی (برای سرور خارج):${N}\n" "$step" "$total_steps"
    echo ""
    
    printf "    ${C}┌─────────────────────────────────────────────────────────┐${N}\n"
    printf "    ${C}│${N} ${Y}این کلید را در سرور خارج اضافه کنید:${N}                   ${C}│${N}\n"
    printf "    ${C}└─────────────────────────────────────────────────────────┘${N}\n"
    echo ""
    printf "    ${G}%s${N}\n" "$(cat ${KEY_FILE}.pub)"
    echo ""
    
    printf "    ${W}دستور برای سرور خارج:${N}\n"
    printf "    ${C}echo '%s' >> /home/%s/.ssh/authorized_keys${N}\n" "$(cat ${KEY_FILE}.pub)" "$KHAREJ_USER"
    echo ""
    
    read -p "$(printf "    ${Y}کلید را در سرور خارج اضافه کردید؟ [Y/n]: ${N}")" key_added
    if [[ "$key_added" =~ ^[Nn]$ ]]; then
        print_warn "لطفاً ابتدا کلید را اضافه کنید"
        read -p "$(printf "    ${C}Enter برای ادامه...${N}")" _
    fi
    echo ""
    
    # ═══════════ مرحله 6: تست اتصال ═══════════
    ((step++))
    printf "  ${C}[%d/%d]${N} ${W}تست اتصال SSH...${N}\n" "$step" "$total_steps"
    
    print_info "در حال تست اتصال به ${KHAREJ_IP}..."
    
    if ssh -o BatchMode=yes -o ConnectTimeout=10 -o StrictHostKeyChecking=no \
           -i "$KEY_FILE" -p "$SSH_PORT" "${KHAREJ_USER}@${KHAREJ_IP}" "echo 'OK'" &>/dev/null; then
        print_ok "اتصال SSH موفق بود"
    else
        print_warn "اتصال خودکار ناموفق - ممکن است نیاز به رمز عبور باشد"
        print_info "تانل‌ها ممکن است در اولین اتصال نیاز به تأیید دستی داشته باشند"
    fi
    echo ""
    
    # ═══════════ مرحله 7: تنظیم SSH محلی ═══════════
    ((step++))
    printf "  ${C}[%d/%d]${N} ${W}تنظیم SSH محلی...${N}\n" "$step" "$total_steps"
    
    mkdir -p /etc/ssh/sshd_config.d
    cat > /etc/ssh/sshd_config.d/sshsaeed.conf << 'EOF'
# SSHSaeed v6.0 - Iran Server Configuration
AllowTcpForwarding yes
TCPKeepAlive yes
ClientAliveInterval 30
ClientAliveCountMax 10
MaxSessions 500
MaxStartups 100:30:200
EOF
    
    systemctl reload sshd 2>/dev/null || systemctl reload ssh 2>/dev/null
    print_ok "SSH محلی پیکربندی شد"
    echo ""
    
    # ═══════════ مرحله 8: ایجاد تانل‌ها ═══════════
    ((step++))
    printf "  ${C}[%d/%d]${N} ${W}ایجاد تانل‌ها...${N}\n" "$step" "$total_steps"
    echo ""
    
    create_all_tunnels "$KHAREJ_IP" "$KHAREJ_USER" "$SSH_PORT" "$TUNNEL_COUNT" "${TARGET_PORTS[@]}"
    
    # پیکربندی HAProxy محلی (اختیاری)
    if [[ $TUNNEL_COUNT -gt 1 ]]; then
        echo ""
        read -p "$(printf "    ${Y}HAProxy محلی برای Load Balancing نصب شود؟ [Y/n]: ${N}")" install_local_haproxy
        if [[ ! "$install_local_haproxy" =~ ^[Nn]$ ]]; then
            create_local_haproxy "$TUNNEL_COUNT" "${TARGET_PORTS[@]}"
        fi
    fi
    
    echo ""
    
    # ═══════════ مرحله 9: ذخیره کانفیگ ═══════════
    ((step++))
    printf "  ${C}[%d/%d]${N} ${W}ذخیره تنظیمات...${N}\n" "$step" "$total_steps"
    
    SERVER_TYPE="iran"
    save_config
    
    echo ""
    line
    printf "    ${G}${ICO_OK} تنظیم سرور ایران کامل شد!${N}\n"
    line
    echo ""
    
    # نمایش خلاصه
    printf "    ${C}┌─────────────────────────────────────────────────────────┐${N}\n"
    printf "    ${C}│${N}  ${W}خلاصه تنظیمات سرور ایران${N}                              ${C}│${N}\n"
    printf "    ${C}├─────────────────────────────────────────────────────────┤${N}\n"
    printf "    ${C}│${N}  سرور خارج: ${G}%-40s${N} ${C}│${N}\n" "$KHAREJ_IP"
    printf "    ${C}│${N}  کاربر: ${G}%-44s${N} ${C}│${N}\n" "$KHAREJ_USER"
    printf "    ${C}│${N}  تعداد تانل: ${G}%-40s${N} ${C}│${N}\n" "$TUNNEL_COUNT"
    printf "    ${C}│${N}  پورت‌ها: ${G}%-43s${N} ${C}│${N}\n" "${TARGET_PORTS[*]}"
    printf "    ${C}│${N}  هر تانل: ${G}%-43s${N} ${C}│${N}\n" "${#TARGET_PORTS[@]} پورت"
    printf "    ${C}└─────────────────────────────────────────────────────────┘${N}\n"
    echo ""
    
    # نمایش پورت‌های تانل
    printf "    ${W}جدول پورت‌های تانل:${N}\n"
    local base_port=10000
    for ((i=1; i<=TUNNEL_COUNT; i++)); do
        local tunnel_base=$((base_port + (i-1) * 100))
        printf "    تانل %d: " "$i"
        for ((j=0; j<${#TARGET_PORTS[@]}; j++)); do
            local remote_port=$((tunnel_base + j))
            printf "پورت %s→%d  " "${TARGET_PORTS[$j]}" "$remote_port"
        done
        echo ""
    done
    echo ""
    
    log_info "Iran server setup completed - Tunnels: $TUNNEL_COUNT, Ports: ${TARGET_PORTS[*]}"
    
    read -p "$(printf "    ${C}Enter برای بازگشت به منو...${N}")" _
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
        
        # لیست تانل‌های موجود
        printf "    ${C}تانل‌های موجود:${N}\n"
        echo ""
        
        local tunnel_count=0
        for service in /etc/systemd/system/sshsaeed-tunnel*.service; do
            [[ -f "$service" ]] || continue
            ((tunnel_count++))
            
            local name=$(basename "$service" .service)
            local status="${R}غیرفعال${N}"
            systemctl is-active --quiet "$name" && status="${G}فعال${N}"
            
            printf "    [%d] %-25s %b\n" "$tunnel_count" "$name" "$status"
        done
        
        [[ $tunnel_count -eq 0 ]] && printf "    ${GR}هیچ تانلی یافت نشد${N}\n"
        
        echo ""
        line_thin
        echo ""
        
        printf "    ${C}[${W}1${C}]${N} ${G}راه‌اندازی همه تانل‌ها${N}\n"
        printf "    ${C}[${W}2${C}]${N} ${R}توقف همه تانل‌ها${N}\n"
        printf "    ${C}[${W}3${C}]${N} ${Y}ری‌استارت همه تانل‌ها${N}\n"
        printf "    ${C}[${W}4${C}]${N} ${B}مشاهده لاگ تانل‌ها${N}\n"
        printf "    ${C}[${W}5${C}]${N} ${M}بررسی اتصال تانل‌ها${N}\n"
        printf "    ${C}[${W}0${C}]${N} بازگشت\n"
        echo ""
        
        read -p "$(printf "    ${Y}انتخاب شما: ${N}")" choice
        
        case $choice in
            1)
                echo ""
                for service in /etc/systemd/system/sshsaeed-tunnel*.service; do
                    [[ -f "$service" ]] || continue
                    local name=$(basename "$service" .service)
                    systemctl start "$name"
                    print_ok "$name راه‌اندازی شد"
                done
                sleep 2
                ;;
            2)
                echo ""
                for service in /etc/systemd/system/sshsaeed-tunnel*.service; do
                    [[ -f "$service" ]] || continue
                    local name=$(basename "$service" .service)
                    systemctl stop "$name"
                    print_ok "$name متوقف شد"
                done
                sleep 2
                ;;
            3)
                echo ""
                for service in /etc/systemd/system/sshsaeed-tunnel*.service; do
                    [[ -f "$service" ]] || continue
                    local name=$(basename "$service" .service)
                    systemctl restart "$name"
                    print_ok "$name ری‌استارت شد"
                done
                sleep 2
                ;;
            4)
                echo ""
                read -p "$(printf "    ${Y}شماره تانل (یا Enter برای همه): ${N}")" tunnel_num
                echo ""
                if [[ -n "$tunnel_num" ]]; then
                    journalctl -u "sshsaeed-tunnel${tunnel_num}" -n 50 --no-pager
                else
                    journalctl -u "sshsaeed-tunnel*" -n 50 --no-pager
                fi
                echo ""
                read -p "$(printf "    ${C}Enter برای ادامه...${N}")" _
                ;;
            5)
                echo ""
                print_info "بررسی اتصال تانل‌ها..."
                echo ""
                
                load_config &>/dev/null
                
                if [[ -n "$KHAREJ_IP" ]]; then
                    if ssh -o BatchMode=yes -o ConnectTimeout=5 -i "$KEY_FILE" \
                           -p "$SSH_PORT" "${KHAREJ_USER}@${KHAREJ_IP}" "echo OK" &>/dev/null; then
                        print_ok "اتصال به سرور خارج برقرار است"
                    else
                        print_err "اتصال به سرور خارج ناموفق"
                    fi
                else
                    print_warn "اطلاعات سرور خارج یافت نشد"
                fi
                
                echo ""
                read -p "$(printf "    ${C}Enter برای ادامه...${N}")" _
                ;;
            0)
                return
                ;;
            *)
                print_err "گزینه نامعتبر"
                sleep 1
                ;;
        esac
    done
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
    
    if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
        print_info "لغو شد"
        sleep 2
        return
    fi
    
    echo ""
    print_info "در حال حذف..."
    echo ""
    
    # توقف و حذف سرویس‌های تانل
    print_info "حذف سرویس‌های تانل..."
    for service in /etc/systemd/system/sshsaeed-*.service; do
        [[ -f "$service" ]] || continue
        local svc_name=$(basename "$service" .service)
        systemctl stop "$svc_name" 2>/dev/null
        systemctl disable "$svc_name" 2>/dev/null
        rm -f "$service"
    done
    print_ok "سرویس‌های تانل حذف شدند"
    
    systemctl daemon-reload
    
    # بازگرداندن HAProxy
    print_info "بازگرداندن HAProxy..."
    if [[ -f "$BACKUP_DIR/haproxy.cfg."* ]]; then
        local latest_backup=$(ls -t "$BACKUP_DIR/haproxy.cfg."* 2>/dev/null | head -1)
        if [[ -n "$latest_backup" ]]; then
            cp "$latest_backup" /etc/haproxy/haproxy.cfg
            systemctl restart haproxy 2>/dev/null
        fi
    fi
    print_ok "HAProxy بررسی شد"
    
    # حذف کلید SSH
    print_info "حذف کلید SSH..."
    rm -f "$KEY_FILE" "${KEY_FILE}.pub"
    print_ok "کلید SSH حذف شد"
    
    # حذف فایل‌های کانفیگ
    print_info "حذف فایل‌های تنظیمات..."
    rm -rf "$CONFIG_DIR"
    rm -f /etc/ssh/sshd_config.d/sshsaeed.conf
    rm -f /etc/sysctl.d/99-sshsaeed.conf
    print_ok "فایل‌های تنظیمات حذف شدند"
    
    # حذف کاربر تانل (اختیاری)
    echo ""
    read -p "$(printf "    ${Y}کاربر '%s' هم حذف شود؟ [y/N]: ${N}" "$TUNNEL_USER")" del_user
    if [[ "$del_user" =~ ^[Yy]$ ]]; then
        userdel -r "$TUNNEL_USER" 2>/dev/null && print_ok "کاربر حذف شد"
    fi
    
    # حذف اسکریپت (اختیاری)
    echo ""
    read -p "$(printf "    ${Y}اسکریپت از سیستم حذف شود؟ [y/N]: ${N}")" del_script
    if [[ "$del_script" =~ ^[Yy]$ ]]; then
        rm -f /usr/local/bin/sshsaeed
        print_ok "اسکریپت حذف شد"
    fi
    
    echo ""
    print_ok "حذف کامل انجام شد"
    
    log_info "SSHSaeed uninstalled"
    
    sleep 3
}

# ═══════════════════════════════════════════════════════════════════════════════
#                         نوار وضعیت
# ═══════════════════════════════════════════════════════════════════════════════
show_status_bar() {
    load_config &>/dev/null
    
    local tunnels_total=0
    local tunnels_active=0
    
    for service in /etc/systemd/system/sshsaeed-tunnel*.service; do
        [[ -f "$service" ]] || continue
        ((tunnels_total++))
        systemctl is-active --quiet "$(basename "$service" .service)" && ((tunnels_active++))
    done
    
    local haproxy_status="${R}OFF${N}"
    systemctl is-active --quiet haproxy && haproxy_status="${G}ON${N}"
    
    local bbr_status="${R}OFF${N}"
    [[ "$(sysctl -n net.ipv4.tcp_congestion_control 2>/dev/null)" == "bbr" ]] && bbr_status="${G}ON${N}"
    
    printf "    ${GR}┌────────────────────────────────────────────────────────────┐${N}\n"
    printf "    ${GR}│${N} نوع: ${W}%-8s${N} ${GR}│${N} تانل: ${G}%d${N}/${W}%d${N} ${GR}│${N} HAProxy: %b ${GR}│${N} BBR: %b ${GR}│${N}\n" \
           "${SERVER_TYPE:-نامشخص}" "$tunnels_active" "$tunnels_total" "$haproxy_status" "$bbr_status"
    printf "    ${GR}└────────────────────────────────────────────────────────────┘${N}\n"
}

# ═══════════════════════════════════════════════════════════════════════════════
#                         منوی اصلی
# ═══════════════════════════════════════════════════════════════════════════════
main_menu() {
    while true; do
        show_banner
        show_status_bar
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
                print_ok "محدودیت‌ها رفع شد"
                print_info "برای اعمال کامل، ریبوت توصیه می‌شود"
                read -p "$(printf "    ${C}Enter برای بازگشت...${N}")" _
                ;;
            7) uninstall_all ;;
            0)
                echo ""
                print_info "خداحافظ!"
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
#                         نقطه شروع
# ═══════════════════════════════════════════════════════════════════════════════

# بررسی root
check_root

# بررسی سیستم‌عامل
check_os

# ایجاد دایرکتوری‌ها
mkdir -p "$CONFIG_DIR" "$BACKUP_DIR" "$LOG_DIR"

# بارگذاری کانفیگ (در صورت وجود)
load_config &>/dev/null

# لاگ شروع
log_info "SSHSaeed v${SCRIPT_VERSION} started"

# نمایش منوی اصلی
main_menu
