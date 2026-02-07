#!/bin/bash
# ═══════════════════════════════════════════════════════════════════════════════
#  ███████╗███████╗██╗  ██╗███████╗ █████╗ ███████╗███████╗██████╗
#  ██╔════╝██╔════╝██║  ██║██╔════╝██╔══██╗██╔════╝██╔════╝██╔══██╗
#  ███████╗███████╗███████║███████╗███████║█████╗  █████╗  ██║  ██║
#  ╚════██║╚════██║██╔══██║╚════██║██╔══██║██╔══╝  ██╔══╝  ██║  ██║
#  ███████║███████║██║  ██║███████║██║  ██║███████╗███████╗██████╔╝
#  ╚══════╝╚══════╝╚═╝  ╚═╝╚══════╝╚═╝  ╚═╝╚══════╝╚══════╝╚═════╝
# ═══════════════════════════════════════════════════════════════════════════════
#  SSHSaeed v7.0 | 3-Tunnel SSH + HAProxy + AES-128-GCM | High Performance
# ═══════════════════════════════════════════════════════════════════════════════

set -o pipefail
export LC_ALL=C
export LANG=C

# ═══════════════════════════════════════════════════════════════════════════════
#                              CONSTANTS
# ═══════════════════════════════════════════════════════════════════════════════
SCRIPT_VERSION="7.0"
SCRIPT_NAME="sshsaeed"
CONFIG_DIR="/etc/sshsaeed"
CONFIG_FILE="$CONFIG_DIR/config.conf"
KEY_FILE="/root/.ssh/tunnel_key"
LOG_FILE="/var/log/sshsaeed.log"
BACKUP_DIR="$CONFIG_DIR/backups"
TUNNEL_USER="tunneluser"

# AES-GCM Encryption (Fastest with AES-NI)
CIPHER="aes128-gcm@openssh.com"
MAC="hmac-sha2-256-etm@openssh.com"

# Default Values
DEFAULT_PORTS="8082,22896,30024"
TUNNEL_COUNT=3
SSH_PORT=22

# Global Variables
declare -a TARGET_PORTS=()
KHAREJ_IP=""
KHAREJ_USER="tunneluser"

# ═══════════════════════════════════════════════════════════════════════════════
#                              COLORS & STYLES
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

# Icons
ICO_OK="✓"
ICO_ERR="✗"
ICO_WARN="!"
ICO_INFO="➤"

# ═══════════════════════════════════════════════════════════════════════════════
#                              HELPER FUNCTIONS
# ═══════════════════════════════════════════════════════════════════════════════
print_ok() { printf "    ${G}${ICO_OK}${N} %s\n" "$1"; }
print_err() { printf "    ${R}${ICO_ERR}${N} %s\n" "$1"; }
print_warn() { printf "    ${Y}${ICO_WARN}${N} %s\n" "$1"; }
print_info() { printf "    ${C}${ICO_INFO}${N} %s\n" "$1"; }

log() {
    local level="$1"
    local msg="$2"
    mkdir -p "$(dirname "$LOG_FILE")"
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [$level] $msg" >> "$LOG_FILE"
}

line() {
    printf "    ${GR}─────────────────────────────────────────────────────${N}\n"
}

show_banner() {
    clear
    printf "\n"
    printf "    ${C}╔═══════════════════════════════════════════════════════════╗${N}\n"
    printf "    ${C}║${N}  ${W}███████╗███████╗██╗  ██╗███████╗ █████╗ ███████╗██████╗${N}  ${C}║${N}\n"
    printf "    ${C}║${N}  ${W}██╔════╝██╔════╝██║  ██║██╔════╝██╔══██╗██╔════╝██╔══██╗${N} ${C}║${N}\n"
    printf "    ${C}║${N}  ${W}███████╗███████╗███████║███████╗███████║█████╗  ██║  ██║${N} ${C}║${N}\n"
    printf "    ${C}║${N}  ${W}╚════██║╚════██║██╔══██║╚════██║██╔══██║██╔══╝  ██║  ██║${N} ${C}║${N}\n"
    printf "    ${C}║${N}  ${W}███████║███████║██║  ██║███████║██║  ██║███████╗██████╔╝${N} ${C}║${N}\n"
    printf "    ${C}║${N}  ${W}╚══════╝╚══════╝╚═╝  ╚═╝╚══════╝╚═╝  ╚═╝╚══════╝╚═════╝${N}  ${C}║${N}\n"
    printf "    ${C}╠═══════════════════════════════════════════════════════════╣${N}\n"
    printf "    ${C}║${N}      ${G}SSH Tunnel Manager v${SCRIPT_VERSION}${N} | ${Y}AES-128-GCM${N} | ${M}BBR${N}       ${C}║${N}\n"
    printf "    ${C}╚═══════════════════════════════════════════════════════════╝${N}\n"
    printf "\n"
}

check_root() {
    if [[ $EUID -ne 0 ]]; then
        print_err "This script must be run as root"
        exit 1
    fi
}

# ═══════════════════════════════════════════════════════════════════════════════
#                         PACKAGE INSTALLATION
# ═══════════════════════════════════════════════════════════════════════════════
install_packages() {
    print_info "Installing required packages..."
    
    if command -v apt-get &>/dev/null; then
        export DEBIAN_FRONTEND=noninteractive
        apt-get update -qq
        apt-get install -y -qq openssh-server openssh-client autossh haproxy \
            curl wget net-tools iptables sshpass jq bc >/dev/null 2>&1
    elif command -v yum &>/dev/null; then
        yum install -y -q openssh-server openssh-clients autossh haproxy \
            curl wget net-tools iptables sshpass jq bc >/dev/null 2>&1
    fi
    
    print_ok "Packages installed"
    return 0
}

# ═══════════════════════════════════════════════════════════════════════════════
#                         REMOVE ALL LIMITS (IRAN & KHAREJ)
# ═══════════════════════════════════════════════════════════════════════════════
remove_all_limits() {
    local server_type="${1:-both}"
    
    print_info "Removing system limits for maximum performance..."
    
    mkdir -p "$BACKUP_DIR"
    
    # 1. File Descriptor Limits
    cat > /etc/security/limits.d/99-sshsaeed-unlimited.conf << 'EOF'
*               soft    nofile          1048576
*               hard    nofile          1048576
*               soft    nproc           1048576
*               hard    nproc           1048576
*               soft    memlock         unlimited
*               hard    memlock         unlimited
*               soft    stack           unlimited
*               hard    stack           unlimited
root            soft    nofile          1048576
root            hard    nofile          1048576
root            soft    nproc           1048576
root            hard    nproc           1048576
EOF

    # 2. Systemd Limits
    mkdir -p /etc/systemd/system.conf.d/
    cat > /etc/systemd/system.conf.d/99-sshsaeed-limits.conf << 'EOF'
[Manager]
DefaultLimitNOFILE=1048576
DefaultLimitNPROC=1048576
DefaultLimitMEMLOCK=infinity
DefaultLimitSTACK=infinity
EOF

    mkdir -p /etc/systemd/user.conf.d/
    cat > /etc/systemd/user.conf.d/99-sshsaeed-limits.conf << 'EOF'
[Manager]
DefaultLimitNOFILE=1048576
DefaultLimitNPROC=1048576
DefaultLimitMEMLOCK=infinity
EOF

    # 3. PAM Limits
    if ! grep -q "pam_limits.so" /etc/pam.d/common-session 2>/dev/null; then
        echo "session required pam_limits.so" >> /etc/pam.d/common-session
    fi
    
    # 4. Kernel Parameters with BBR + AES optimization
    cat > /etc/sysctl.d/99-sshsaeed-optimized.conf << 'EOF'
# ═══════════ File System ═══════════
fs.file-max = 2097152
fs.nr_open = 1048576
fs.inotify.max_user_watches = 524288
fs.inotify.max_user_instances = 512

# ═══════════ Network Core ═══════════
net.core.somaxconn = 65535
net.core.netdev_max_backlog = 65535
net.core.rmem_default = 262144
net.core.wmem_default = 262144
net.core.rmem_max = 67108864
net.core.wmem_max = 67108864
net.core.optmem_max = 65535

# ═══════════ TCP Memory ═══════════
net.ipv4.tcp_rmem = 4096 262144 67108864
net.ipv4.tcp_wmem = 4096 262144 67108864
net.ipv4.tcp_mem = 786432 1048576 1572864
net.ipv4.udp_mem = 786432 1048576 1572864

# ═══════════ TCP Performance ═══════════
net.ipv4.tcp_fastopen = 3
net.ipv4.tcp_syncookies = 1
net.ipv4.tcp_tw_reuse = 1
net.ipv4.tcp_fin_timeout = 15
net.ipv4.tcp_keepalive_time = 300
net.ipv4.tcp_keepalive_probes = 5
net.ipv4.tcp_keepalive_intvl = 15
net.ipv4.tcp_max_syn_backlog = 65535
net.ipv4.tcp_max_tw_buckets = 2000000
net.ipv4.tcp_sack = 1
net.ipv4.tcp_fack = 1
net.ipv4.tcp_window_scaling = 1
net.ipv4.tcp_adv_win_scale = 2
net.ipv4.tcp_moderate_rcvbuf = 1
net.ipv4.tcp_no_metrics_save = 1
net.ipv4.tcp_timestamps = 1
net.ipv4.tcp_mtu_probing = 1

# ═══════════ BBR Congestion Control ═══════════
net.core.default_qdisc = fq
net.ipv4.tcp_congestion_control = bbr

# ═══════════ Connection Tracking ═══════════
net.netfilter.nf_conntrack_max = 2097152
net.netfilter.nf_conntrack_tcp_timeout_established = 7200
net.netfilter.nf_conntrack_tcp_timeout_time_wait = 30
net.netfilter.nf_conntrack_tcp_timeout_close_wait = 30
net.netfilter.nf_conntrack_tcp_timeout_fin_wait = 30

# ═══════════ Local Port Range ═══════════
net.ipv4.ip_local_port_range = 1024 65535
EOF

    # Enable BBR
    modprobe tcp_bbr 2>/dev/null || true
    
    # Apply settings
    sysctl -p /etc/sysctl.d/99-sshsaeed-optimized.conf >/dev/null 2>&1 || true
    
    # Apply to current session
    ulimit -n 1048576 2>/dev/null || true
    ulimit -u 1048576 2>/dev/null || true
    
    print_ok "System limits removed and optimized"
    log "INFO" "System limits configured for $server_type"
    return 0
}

# ═══════════════════════════════════════════════════════════════════════════════
#                         SSH CONFIG WITH AES-GCM (BOTH SERVERS)
# ═══════════════════════════════════════════════════════════════════════════════
optimize_ssh_config() {
    local server_type="$1"
    
    print_info "Configuring SSH with AES-128-GCM for $server_type..."
    
    [[ -f /etc/ssh/sshd_config ]] && cp /etc/ssh/sshd_config "$BACKUP_DIR/sshd_config.$(date +%s)"
    
    mkdir -p /etc/ssh/sshd_config.d/
    
    if [[ "$server_type" == "kharej" ]]; then
        cat > /etc/ssh/sshd_config.d/99-sshsaeed.conf << 'EOF'
# SSHSaeed Kharej Server Configuration
# AES-128-GCM Encryption for Maximum Speed with AES-NI

# Port and Protocol
Port 22
Protocol 2

# Tunnel Settings (Critical for SSH Tunnels)
GatewayPorts yes
AllowTcpForwarding yes
PermitTunnel yes
ClientAliveInterval 30
ClientAliveCountMax 10

# Performance Limits
MaxSessions 500
MaxStartups 500:30:1000

# AES-GCM Encryption (Hardware Accelerated)
Ciphers aes128-gcm@openssh.com,aes256-gcm@openssh.com,chacha20-poly1305@openssh.com
MACs hmac-sha2-256-etm@openssh.com,hmac-sha2-512-etm@openssh.com
KexAlgorithms curve25519-sha256,curve25519-sha256@libssh.org

# Performance Options
UseDNS no
Compression no
TCPKeepAlive yes

# Authentication
PermitRootLogin yes
PubkeyAuthentication yes
PasswordAuthentication yes
EOF
    else
        cat > /etc/ssh/sshd_config.d/99-sshsaeed.conf << 'EOF'
# SSHSaeed Iran Server Configuration
# AES-128-GCM Encryption

# Port and Protocol
Port 22
Protocol 2

# Tunnel Support
AllowTcpForwarding yes
PermitTunnel yes
ClientAliveInterval 30
ClientAliveCountMax 10

# Performance
MaxSessions 500
MaxStartups 500:30:1000

# AES-GCM Encryption
Ciphers aes128-gcm@openssh.com,aes256-gcm@openssh.com,chacha20-poly1305@openssh.com
MACs hmac-sha2-256-etm@openssh.com,hmac-sha2-512-etm@openssh.com
KexAlgorithms curve25519-sha256,curve25519-sha256@libssh.org

# Performance Options
UseDNS no
Compression no
TCPKeepAlive yes

# Authentication
PermitRootLogin yes
PubkeyAuthentication yes
PasswordAuthentication yes
EOF
    fi
    
    systemctl restart sshd 2>/dev/null || systemctl restart ssh 2>/dev/null
    
    print_ok "SSH configured with AES-128-GCM (MaxSessions: 500)"
    return 0
}

# ═══════════════════════════════════════════════════════════════════════════════
#                         SSH KEY MANAGEMENT
# ═══════════════════════════════════════════════════════════════════════════════
generate_ssh_key() {
    print_info "Generating SSH key..."
    
    mkdir -p /root/.ssh
    chmod 700 /root/.ssh
    
    if [[ -f "$KEY_FILE" ]]; then
        print_warn "Previous key exists, backing up..."
        mv "$KEY_FILE" "${KEY_FILE}.backup.$(date +%s)"
        mv "${KEY_FILE}.pub" "${KEY_FILE}.pub.backup.$(date +%s)" 2>/dev/null
    fi
    
    ssh-keygen -t ed25519 -f "$KEY_FILE" -N "" -C "sshsaeed-tunnel-v7" >/dev/null 2>&1
    chmod 600 "$KEY_FILE"
    chmod 644 "${KEY_FILE}.pub"
    
    print_ok "SSH key generated: $KEY_FILE"
    log "INFO" "SSH key generated"
    return 0
}

copy_key_to_kharej() {
    local host="$1"
    local user="$2"
    local port="${3:-22}"
    local pass="$4"
    
    print_info "Copying SSH key to Kharej server..."
    
    if [[ -n "$pass" ]] && command -v sshpass &>/dev/null; then
        sshpass -p "$pass" ssh-copy-id -i "${KEY_FILE}.pub" -p "$port" \
            -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null \
            "$user@$host" >/dev/null 2>&1
    else
        ssh-copy-id -i "${KEY_FILE}.pub" -p "$port" \
            -o StrictHostKeyChecking=no "$user@$host" 2>/dev/null
    fi
    
    if [[ $? -eq 0 ]]; then
        print_ok "SSH key copied successfully"
        return 0
    else
        print_err "Failed to copy SSH key"
        return 1
    fi
}

test_ssh_connection() {
    local host="$1"
    local user="$2"
    local port="${3:-22}"
    
    ssh -i "$KEY_FILE" -p "$port" -o BatchMode=yes -o ConnectTimeout=10 \
        -o StrictHostKeyChecking=no -o Ciphers=$CIPHER \
        "$user@$host" "echo OK" &>/dev/null
    return $?
}

# ═══════════════════════════════════════════════════════════════════════════════
#                         SSH CLIENT CONFIG WITH AES-GCM
# ═══════════════════════════════════════════════════════════════════════════════
create_ssh_client_config() {
    local kharej_ip="$1"
    
    print_info "Creating SSH client config with AES-GCM..."
    
    cat > /root/.ssh/config << EOF
# SSHSaeed Tunnel Configuration
# AES-128-GCM for Hardware Accelerated Encryption

Host kharej-tunnel
    HostName $kharej_ip
    User $TUNNEL_USER
    Port $SSH_PORT
    IdentityFile $KEY_FILE
    
    # AES-GCM Encryption (Critical)
    Ciphers aes128-gcm@openssh.com
    MACs hmac-sha2-256-etm@openssh.com
    
    # Performance
    Compression no
    TCPKeepAlive yes
    ServerAliveInterval 30
    ServerAliveCountMax 3
    
    # Security
    StrictHostKeyChecking no
    UserKnownHostsFile /dev/null
    
    # Connection
    ConnectTimeout 30
    ConnectionAttempts 3
EOF

    chmod 600 /root/.ssh/config
    print_ok "SSH client config created with AES-128-GCM"
    return 0
}
# ═══════════════════════════════════════════════════════════════════════════════
#                         CREATE TUNNEL SERVICES WITH AES-GCM
# ═══════════════════════════════════════════════════════════════════════════════
create_tunnel_services() {
    local kharej_ip="$1"
    shift
    local ports=("$@")
    
    print_info "Creating 3 SSH tunnel services with AES-128-GCM..."
    
    # Stop and remove old services
    for i in 1 2 3; do
        systemctl stop ssh-tunnel-$i.service 2>/dev/null
        systemctl disable ssh-tunnel-$i.service 2>/dev/null
        rm -f /etc/systemd/system/ssh-tunnel-$i.service
    done
    
    # Kill any existing tunnel processes
    pkill -f "ssh.*tunnel.*$kharej_ip" 2>/dev/null
    pkill -f "autossh.*$kharej_ip" 2>/dev/null
    sleep 2
    
    # Calculate port mappings
    # Tunnel 1: 10000, 10001, 10002, ...
    # Tunnel 2: 10100, 10101, 10102, ...
    # Tunnel 3: 10200, 10201, 10202, ...
    
    local port_count=${#ports[@]}
    
    for tunnel_num in 1 2 3; do
        local base_port=$((10000 + (tunnel_num - 1) * 100))
        local forward_args=""
        
        for i in "${!ports[@]}"; do
            local local_port=$((base_port + i))
            local remote_port="${ports[$i]}"
            forward_args="$forward_args -L 127.0.0.1:${local_port}:127.0.0.1:${remote_port}"
        done
        
        # Create systemd service with AES-GCM
        cat > /etc/systemd/system/ssh-tunnel-${tunnel_num}.service << EOF
[Unit]
Description=SSHSaeed Tunnel ${tunnel_num} - AES-128-GCM
Documentation=https://github.com/saeedkars/sshsaeed
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
Environment="AUTOSSH_GATETIME=0"
Environment="AUTOSSH_PORT=0"
ExecStart=/usr/bin/ssh -N -T \\
    -o Ciphers=aes128-gcm@openssh.com \\
    -o MACs=hmac-sha2-256-etm@openssh.com \\
    -o Compression=no \\
    -o ServerAliveInterval=30 \\
    -o ServerAliveCountMax=3 \\
    -o ExitOnForwardFailure=yes \\
    -o StrictHostKeyChecking=no \\
    -o UserKnownHostsFile=/dev/null \\
    -o TCPKeepAlive=yes \\
    -o ConnectTimeout=30 \\
    -i ${KEY_FILE} \\
    ${forward_args} \\
    ${TUNNEL_USER}@${kharej_ip}
ExecStop=/bin/kill -TERM \$MAINPID
Restart=always
RestartSec=5
StartLimitInterval=0
KillMode=mixed

# Resource Limits
LimitNOFILE=1048576
LimitNPROC=1048576

[Install]
WantedBy=multi-user.target
EOF
        
        print_ok "Tunnel $tunnel_num service created (Ports: $forward_args)"
    done
    
    systemctl daemon-reload
    
    # Enable and start services with delay
    for i in 1 2 3; do
        systemctl enable ssh-tunnel-$i.service >/dev/null 2>&1
        systemctl start ssh-tunnel-$i.service
        sleep 2
    done
    
    print_ok "All 3 tunnel services created and started with AES-128-GCM"
    log "INFO" "Tunnel services created with AES-GCM for ports: ${ports[*]}"
    return 0
}

# ═══════════════════════════════════════════════════════════════════════════════
#                         HAPROXY CONFIGURATION (IRAN ONLY)
# ═══════════════════════════════════════════════════════════════════════════════
configure_haproxy() {
    shift 2>/dev/null
    local ports=("$@")
    
    print_info "Configuring HAProxy load balancer (Iran server)..."
    
    [[ -f /etc/haproxy/haproxy.cfg ]] && cp /etc/haproxy/haproxy.cfg "$BACKUP_DIR/haproxy.cfg.$(date +%s)"
    
    # Create HAProxy config
    cat > /etc/haproxy/haproxy.cfg << 'EOF'
# ═══════════════════════════════════════════════════════════════════════════════
#  SSHSaeed HAProxy Configuration v7.0
#  Load Balancing across 3 SSH Tunnels with Health Checks
# ═══════════════════════════════════════════════════════════════════════════════

global
    maxconn 1000000
    nbthread 4
    cpu-map auto:1/1-4 0-3
    
    log /dev/log local0
    log /dev/log local1 notice
    
    stats socket /run/haproxy/admin.sock mode 660 level admin
    stats timeout 30s
    
    tune.ssl.default-dh-param 2048
    tune.bufsize 32768
    tune.maxrewrite 8192
    
    # Performance
    tune.rcvbuf.client 33554432
    tune.rcvbuf.server 33554432
    tune.sndbuf.client 33554432
    tune.sndbuf.server 33554432

defaults
    mode tcp
    log global
    
    option tcplog
    option dontlognull
    option tcp-smart-accept
    option tcp-smart-connect
    
    timeout connect 10s
    timeout client 300s
    timeout server 300s
    timeout tunnel 1h
    
    retries 3
    
    default-server inter 3s fall 3 rise 2

# ═══════════════════════════════════════════════════════════════════════════════
#  Statistics Dashboard
# ═══════════════════════════════════════════════════════════════════════════════
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

    # Add frontend/backend for each port
    local port_idx=0
    for port in "${ports[@]}"; do
        local base1=$((10000 + port_idx))
        local base2=$((10100 + port_idx))
        local base3=$((10200 + port_idx))
        
        cat >> /etc/haproxy/haproxy.cfg << EOF

# ═══════════════════════════════════════════════════════════════════════════════
#  Port $port - Load Balanced Frontend
# ═══════════════════════════════════════════════════════════════════════════════
frontend ft_port_${port}
    bind *:${port}
    mode tcp
    option tcplog
    default_backend bk_port_${port}

backend bk_port_${port}
    mode tcp
    balance roundrobin
    option tcp-check
    
    # 3 SSH Tunnel Backends
    server tunnel1_${port} 127.0.0.1:${base1} check inter 5s fall 3 rise 2 weight 100
    server tunnel2_${port} 127.0.0.1:${base2} check inter 5s fall 3 rise 2 weight 100
    server tunnel3_${port} 127.0.0.1:${base3} check inter 5s fall 3 rise 2 weight 100

EOF
        ((port_idx++))
    done
    
    # Validate and restart HAProxy
    if haproxy -c -f /etc/haproxy/haproxy.cfg >/dev/null 2>&1; then
        systemctl enable haproxy >/dev/null 2>&1
        systemctl restart haproxy
        print_ok "HAProxy configured and started"
    else
        print_err "HAProxy configuration error"
        haproxy -c -f /etc/haproxy/haproxy.cfg
        return 1
    fi
    
    log "INFO" "HAProxy configured for ports: ${ports[*]}"
    return 0
}

# ═══════════════════════════════════════════════════════════════════════════════
#                         FIREWALL CONFIGURATION
# ═══════════════════════════════════════════════════════════════════════════════
configure_firewall() {
    local server_type="$1"
    shift
    local ports=("$@")
    
    print_info "Configuring firewall for $server_type..."
    
    if command -v ufw &>/dev/null; then
        ufw allow 22/tcp >/dev/null 2>&1
        
        for port in "${ports[@]}"; do
            ufw allow "$port/tcp" >/dev/null 2>&1
        done
        
        # HAProxy stats
        [[ "$server_type" == "iran" ]] && ufw allow 8404/tcp >/dev/null 2>&1
        
        ufw --force enable >/dev/null 2>&1
    fi
    
    if command -v firewall-cmd &>/dev/null; then
        firewall-cmd --permanent --add-port=22/tcp >/dev/null 2>&1
        
        for port in "${ports[@]}"; do
            firewall-cmd --permanent --add-port="$port/tcp" >/dev/null 2>&1
        done
        
        [[ "$server_type" == "iran" ]] && firewall-cmd --permanent --add-port=8404/tcp >/dev/null 2>&1
        
        firewall-cmd --reload >/dev/null 2>&1
    fi
    
    print_ok "Firewall configured"
    return 0
}

# ═══════════════════════════════════════════════════════════════════════════════
#                         STATUS DISPLAY WITH GRAPHICS
# ═══════════════════════════════════════════════════════════════════════════════
show_status() {
    show_banner
    line
    printf "    ${W}System & Tunnel Status${N}\n"
    line
    echo ""
    
    # System Resources
    printf "    ${C}┌─────────────────────────────────────────────────────────┐${N}\n"
    printf "    ${C}│${N}  ${W}SYSTEM RESOURCES${N}                                        ${C}│${N}\n"
    printf "    ${C}├─────────────────────────────────────────────────────────┤${N}\n"
    
    # CPU
    local cpu_usage=$(top -bn1 | grep "Cpu(s)" | awk '{print $2}' | cut -d'%' -f1)
    local cpu_bar=$(printf "%-20s" "" | tr ' ' '▓' | cut -c1-$((${cpu_usage%.*}/5)))
    cpu_bar=$(printf "%-20s" "$cpu_bar" | tr ' ' '░')
    printf "    ${C}│${N}  CPU:    [${G}%s${N}] %5.1f%%                      ${C}│${N}\n" "$cpu_bar" "$cpu_usage"
    
    # Memory
    local mem_info=$(free -m | awk 'NR==2{printf "%.1f %.1f", $3, $2}')
    local mem_used=$(echo $mem_info | awk '{print $1}')
    local mem_total=$(echo $mem_info | awk '{print $2}')
    local mem_pct=$(echo "scale=1; $mem_used * 100 / $mem_total" | bc)
    local mem_bar=$(printf "%-20s" "" | tr ' ' '▓' | cut -c1-$((${mem_pct%.*}/5)))
    mem_bar=$(printf "%-20s" "$mem_bar" | tr ' ' '░')
    printf "    ${C}│${N}  MEM:    [${Y}%s${N}] %5.1f%% (%.0f/%.0fMB)       ${C}│${N}\n" "$mem_bar" "$mem_pct" "$mem_used" "$mem_total"
    
    # Network
    local rx_bytes=$(cat /sys/class/net/$(ip route | grep default | awk '{print $5}' | head -1)/statistics/rx_bytes 2>/dev/null || echo 0)
    local tx_bytes=$(cat /sys/class/net/$(ip route | grep default | awk '{print $5}' | head -1)/statistics/tx_bytes 2>/dev/null || echo 0)
    local rx_mb=$((rx_bytes / 1048576))
    local tx_mb=$((tx_bytes / 1048576))
    printf "    ${C}│${N}  NET:    RX: ${G}%'d MB${N}  TX: ${M}%'d MB${N}              ${C}│${N}\n" "$rx_mb" "$tx_mb"
    
    printf "    ${C}└─────────────────────────────────────────────────────────┘${N}\n"
    echo ""
    
    # Tunnel Status
    printf "    ${C}┌─────────────────────────────────────────────────────────┐${N}\n"
    printf "    ${C}│${N}  ${W}SSH TUNNELS (AES-128-GCM)${N}                               ${C}│${N}\n"
    printf "    ${C}├─────────────────────────────────────────────────────────┤${N}\n"
    
    local total_tunnels=0
    local active_tunnels=0
    
    for i in 1 2 3; do
        local status=$(systemctl is-active ssh-tunnel-$i.service 2>/dev/null)
        ((total_tunnels++))
        
        if [[ "$status" == "active" ]]; then
            ((active_tunnels++))
            printf "    ${C}│${N}  Tunnel $i: ${G}● ACTIVE${N}   "
            
            # Get data transfer for this tunnel
            local tunnel_pid=$(systemctl show ssh-tunnel-$i.service --property=MainPID --value 2>/dev/null)
            if [[ -n "$tunnel_pid" && "$tunnel_pid" != "0" ]]; then
                local proc_io=$(cat /proc/$tunnel_pid/io 2>/dev/null)
                local read_bytes=$(echo "$proc_io" | grep "read_bytes" | awk '{print $2}')
                local write_bytes=$(echo "$proc_io" | grep "write_bytes" | awk '{print $2}')
                read_bytes=${read_bytes:-0}
                write_bytes=${write_bytes:-0}
                printf "RX: %'d KB  TX: %'d KB" $((read_bytes/1024)) $((write_bytes/1024))
            fi
            printf "   ${C}│${N}\n"
        else
            printf "    ${C}│${N}  Tunnel $i: ${R}○ INACTIVE${N}                              ${C}│${N}\n"
        fi
    done
    
    printf "    ${C}├─────────────────────────────────────────────────────────┤${N}\n"
    printf "    ${C}│${N}  Active: ${G}%d${N}/%d tunnels                                   ${C}│${N}\n" "$active_tunnels" "$total_tunnels"
    printf "    ${C}└─────────────────────────────────────────────────────────┘${N}\n"
    echo ""
    
    # HAProxy Status
    printf "    ${C}┌─────────────────────────────────────────────────────────┐${N}\n"
    printf "    ${C}│${N}  ${W}HAPROXY LOAD BALANCER${N}                                   ${C}│${N}\n"
    printf "    ${C}├─────────────────────────────────────────────────────────┤${N}\n"
    
    local haproxy_status=$(systemctl is-active haproxy 2>/dev/null)
    if [[ "$haproxy_status" == "active" ]]; then
        printf "    ${C}│${N}  Status: ${G}● RUNNING${N}                                     ${C}│${N}\n"
        
        # Show listening ports
        local ha_ports=$(ss -tlnp | grep haproxy | awk '{print $4}' | grep -oE '[0-9]+$' | sort -u | tr '\n' ' ')
        printf "    ${C}│${N}  Ports:  ${Y}%s${N}                                  ${C}│${N}\n" "$ha_ports"
        printf "    ${C}│${N}  Stats:  ${B}http://YOUR_IP:8404/stats${N}                   ${C}│${N}\n"
    else
        printf "    ${C}│${N}  Status: ${R}○ NOT RUNNING${N}                                 ${C}│${N}\n"
    fi
    
    printf "    ${C}└─────────────────────────────────────────────────────────┘${N}\n"
    echo ""
    
    # Encryption Info
    printf "    ${C}┌─────────────────────────────────────────────────────────┐${N}\n"
    printf "    ${C}│${N}  ${W}ENCRYPTION${N}                                               ${C}│${N}\n"
    printf "    ${C}├─────────────────────────────────────────────────────────┤${N}\n"
    
    local aes_ni="No"
    grep -q 'aes' /proc/cpuinfo 2>/dev/null && aes_ni="Yes"
    local bbr_status=$(sysctl -n net.ipv4.tcp_congestion_control 2>/dev/null || echo "N/A")
    
    printf "    ${C}│${N}  Cipher:  ${G}AES-128-GCM${N} (Hardware Accelerated)            ${C}│${N}\n"
    printf "    ${C}│${N}  AES-NI:  ${G}%s${N}                                            ${C}│${N}\n" "$aes_ni"
    printf "    ${C}│${N}  BBR:     ${G}%s${N}                                          ${C}│${N}\n" "$bbr_status"
    printf "    ${C}└─────────────────────────────────────────────────────────┘${N}\n"
    echo ""
    
    read -p "    Press Enter to return to main menu..."
    return 0
}

# ═══════════════════════════════════════════════════════════════════════════════
#                         PORT MAPPING TABLE
# ═══════════════════════════════════════════════════════════════════════════════
show_port_mapping() {
    show_banner
    line
    printf "    ${W}Port Mapping Table${N}\n"
    line
    echo ""
    
    if [[ -f "$CONFIG_FILE" ]]; then
        source "$CONFIG_FILE"
    fi
    
    printf "    ${C}┌──────────┬──────────┬──────────┬──────────┬──────────┐${N}\n"
    printf "    ${C}│${N} ${W}Public${N}   ${C}│${N} ${W}Tunnel1${N}  ${C}│${N} ${W}Tunnel2${N}  ${C}│${N} ${W}Tunnel3${N}  ${C}│${N} ${W}Kharej${N}   ${C}│${N}\n"
    printf "    ${C}├──────────┼──────────┼──────────┼──────────┼──────────┤${N}\n"
    
    local idx=0
    IFS=',' read -ra port_arr <<< "${TARGET_PORTS:-8082,22896,30024}"
    
    for port in "${port_arr[@]}"; do
        local t1=$((10000 + idx))
        local t2=$((10100 + idx))
        local t3=$((10200 + idx))
        printf "    ${C}│${N} ${G}%-8s${N} ${C}│${N} ${Y}%-8s${N} ${C}│${N} ${Y}%-8s${N} ${C}│${N} ${Y}%-8s${N} ${C}│${N} ${M}%-8s${N} ${C}│${N}\n" \
            "$port" "$t1" "$t2" "$t3" "$port"
        ((idx++))
    done
    
    printf "    ${C}└──────────┴──────────┴──────────┴──────────┴──────────┘${N}\n"
    echo ""
    
    printf "    ${W}Data Flow:${N}\n"
    printf "    Client -> ${G}Iran:PublicPort${N} -> ${Y}HAProxy${N} -> ${Y}Tunnel1/2/3${N} -> ${M}Kharej:Port${N}\n"
    echo ""
    
    read -p "    Press Enter to return..."
    return 0
}
# ═══════════════════════════════════════════════════════════════════════════════
#                         PORT MAPPING TABLE (CONTINUED)
# ═══════════════════════════════════════════════════════════════════════════════
        local t1=$((10000 + idx))
        local t2=$((10100 + idx))
        local t3=$((10200 + idx))
        
        # Check port status
        local s1=$(ss -tln 2>/dev/null | grep -q ":${t1} " && echo "${G}●${N}" || echo "${R}○${N}")
        local s2=$(ss -tln 2>/dev/null | grep -q ":${t2} " && echo "${G}●${N}" || echo "${R}○${N}")
        local s3=$(ss -tln 2>/dev/null | grep -q ":${t3} " && echo "${G}●${N}" || echo "${R}○${N}")
        
        printf "    ${Y}│${N}  %-6s   ${Y}│${N} $s1 %-6s ${Y}│${N} $s2 %-6s ${Y}│${N} $s3 %-6s ${Y}│${N}  %-6s  ${Y}│${N}\n" \
            "$port" "$t1" "$t2" "$t3" "$port"
        
        ((idx++))
    done
    
    printf "    ${Y}└──────────┴──────────┴──────────┴──────────┴──────────┘${N}\n"
    echo ""
    
    printf "    ${GR}Legend: ${G}●${N} = Active  ${R}○${N} = Inactive${N}\n"
    echo ""
    
    read -p "    Press Enter to return to main menu..."
    return 0
}

# ═══════════════════════════════════════════════════════════════════════════════
#                         KHAREJ SERVER SETUP
# ═══════════════════════════════════════════════════════════════════════════════
setup_kharej() {
    show_banner
    
    printf "    ${C}╔═══════════════════════════════════════════════════════════╗${N}\n"
    printf "    ${C}║${N}            ${W}KHAREJ SERVER SETUP${N}                              ${C}║${N}\n"
    printf "    ${C}╚═══════════════════════════════════════════════════════════╝${N}\n"
    echo ""
    
    print_info "This setup will:"
    printf "    ${GR}├─${N} Optimize kernel (BBR, buffers)\n"
    printf "    ${GR}├─${N} Remove system limits\n"
    printf "    ${GR}├─${N} Configure SSHD with AES-128-GCM\n"
    printf "    ${GR}└─${N} Enable GatewayPorts for tunneling\n"
    echo ""
    
    read -p "    Continue? [Y/n]: " confirm
    [[ "${confirm,,}" == "n" ]] && return 0
    
    echo ""
    print_info "Starting Kharej setup..."
    line_thin
    
    # Step 1: Install packages
    print_wait "Installing packages..."
    install_packages "kharej" >/dev/null 2>&1
    print_done "Packages installed"
    
    # Step 2: Kernel optimization
    print_wait "Optimizing kernel..."
    optimize_kernel >/dev/null 2>&1
    print_done "Kernel optimized with BBR"
    
    # Step 3: Remove limits
    print_wait "Removing system limits..."
    remove_limits >/dev/null 2>&1
    print_done "System limits removed"
    
    # Step 4: Configure SSHD
    print_wait "Configuring SSHD with AES-GCM..."
    configure_sshd_kharej >/dev/null 2>&1
    print_done "SSHD configured"
    
    line_thin
    echo ""
    
    printf "    ${G}╔═══════════════════════════════════════════════════════════╗${N}\n"
    printf "    ${G}║${N}  ${W}KHAREJ SETUP COMPLETE${N}                                     ${G}║${N}\n"
    printf "    ${G}╠═══════════════════════════════════════════════════════════╣${N}\n"
    printf "    ${G}║${N}  ${Y}Next Steps:${N}                                               ${G}║${N}\n"
    printf "    ${G}║${N}  1. Install x-ui/xray on this server                      ${G}║${N}\n"
    printf "    ${G}║${N}  2. Configure inbounds on ports: 8082, 22896, 30024       ${G}║${N}\n"
    printf "    ${G}║${N}  3. Go to Iran server and run setup                       ${G}║${N}\n"
    printf "    ${G}╚═══════════════════════════════════════════════════════════╝${N}\n"
    echo ""
    
    # Save config
    mkdir -p "$CONFIG_DIR"
    cat > "$CONFIG_FILE" << EOF
# SSHSaeed Configuration
SERVER_TYPE="kharej"
SETUP_DATE="$(date '+%Y-%m-%d %H:%M:%S')"
EOF
    
    log "INFO" "Kharej setup completed"
    
    read -p "    Press Enter to continue..."
    return 0
}

# ═══════════════════════════════════════════════════════════════════════════════
#                         IRAN SERVER SETUP
# ═══════════════════════════════════════════════════════════════════════════════
setup_iran() {
    show_banner
    
    printf "    ${C}╔═══════════════════════════════════════════════════════════╗${N}\n"
    printf "    ${C}║${N}            ${W}IRAN SERVER SETUP${N}                                ${C}║${N}\n"
    printf "    ${C}╚═══════════════════════════════════════════════════════════╝${N}\n"
    echo ""
    
    # Get Kharej IP
    printf "    ${Y}Enter Kharej Server IP:${N} "
    read kharej_ip
    
    if [[ -z "$kharej_ip" ]]; then
        print_err "IP address is required"
        read -p "    Press Enter..."
        return 1
    fi
    
    # Validate IP
    if ! [[ "$kharej_ip" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
        print_err "Invalid IP format"
        read -p "    Press Enter..."
        return 1
    fi
    
    # Get ports
    printf "    ${Y}Enter ports (comma separated) [8082,22896,30024]:${N} "
    read ports_input
    ports_input="${ports_input:-8082,22896,30024}"
    
    # Parse ports
    IFS=',' read -ra port_array <<< "$ports_input"
    
    echo ""
    print_info "Configuration:"
    printf "    ${GR}├─${N} Kharej IP: ${G}$kharej_ip${N}\n"
    printf "    ${GR}├─${N} Ports: ${G}${port_array[*]}${N}\n"
    printf "    ${GR}├─${N} Tunnels: ${G}3${N}\n"
    printf "    ${GR}└─${N} Encryption: ${G}AES-128-GCM${N}\n"
    echo ""
    
    read -p "    Continue? [Y/n]: " confirm
    [[ "${confirm,,}" == "n" ]] && return 0
    
    echo ""
    line_thin
    
    # Step 1: Install packages
    print_wait "Installing packages..."
    install_packages "iran" >/dev/null 2>&1
    print_done "Packages installed"
    
    # Step 2: Kernel optimization
    print_wait "Optimizing kernel..."
    optimize_kernel >/dev/null 2>&1
    print_done "Kernel optimized with BBR"
    
    # Step 3: Remove limits
    print_wait "Removing system limits..."
    remove_limits >/dev/null 2>&1
    print_done "System limits removed"
    
    # Step 4: Generate SSH key
    print_wait "Generating SSH key..."
    generate_ssh_key >/dev/null 2>&1
    print_done "SSH key generated"
    
    # Step 5: Copy key to Kharej
    echo ""
    printf "    ${Y}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${N}\n"
    printf "    ${W}SSH KEY TRANSFER${N}\n"
    printf "    ${Y}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${N}\n"
    printf "    ${C}Copying SSH key to Kharej server...${N}\n"
    printf "    ${GR}You will be asked for Kharej root password.${N}\n"
    echo ""
    
    ssh-copy-id -i "${KEY_FILE}.pub" -o StrictHostKeyChecking=no "root@${kharej_ip}"
    
    if [[ $? -ne 0 ]]; then
        print_err "Failed to copy SSH key"
        printf "    ${Y}Manual solution:${N}\n"
        printf "    1. Copy this key to Kharej server:\n"
        printf "    ${GR}$(cat ${KEY_FILE}.pub)${N}\n"
        printf "    2. Add to: /root/.ssh/authorized_keys\n"
        read -p "    Press Enter after manual copy..."
    else
        print_ok "SSH key copied successfully"
    fi
    
    # Step 6: Test connection
    print_wait "Testing SSH connection..."
    if ssh -i "$KEY_FILE" -o BatchMode=yes -o ConnectTimeout=10 "root@${kharej_ip}" "echo OK" >/dev/null 2>&1; then
        print_done "SSH connection verified"
    else
        print_err "SSH connection failed"
        read -p "    Press Enter to continue anyway..."
    fi
    
    # Step 7: Create tunnel services
    print_wait "Creating tunnel services..."
    create_tunnel_services "$kharej_ip" "${port_array[@]}"
    print_done "Tunnel services created"
    
    # Step 8: Configure HAProxy
    print_wait "Configuring HAProxy..."
    configure_haproxy "${port_array[@]}"
    print_done "HAProxy configured"
    
    # Step 9: Configure firewall
    print_wait "Configuring firewall..."
    configure_firewall "iran" "${port_array[@]}"
    print_done "Firewall configured"
    
    # Save configuration
    mkdir -p "$CONFIG_DIR"
    cat > "$CONFIG_FILE" << EOF
# SSHSaeed Configuration
SERVER_TYPE="iran"
KHAREJ_IP="$kharej_ip"
TARGET_PORTS="${port_array[*]}"
TUNNEL_COUNT=3
CIPHER="aes128-gcm@openssh.com"
SETUP_DATE="$(date '+%Y-%m-%d %H:%M:%S')"
EOF
    
    line_thin
    echo ""
    
    # Wait for tunnels to establish
    print_info "Waiting for tunnels to establish..."
    sleep 5
    
    # Show final status
    printf "    ${G}╔═══════════════════════════════════════════════════════════╗${N}\n"
    printf "    ${G}║${N}  ${W}IRAN SETUP COMPLETE${N}                                       ${G}║${N}\n"
    printf "    ${G}╠═══════════════════════════════════════════════════════════╣${N}\n"
    
    # Check tunnel status
    local active=0
    for i in 1 2 3; do
        [[ "$(systemctl is-active ssh-tunnel-$i 2>/dev/null)" == "active" ]] && ((active++))
    done
    
    printf "    ${G}║${N}  Tunnels Active: ${G}$active/3${N}                                    ${G}║${N}\n"
    printf "    ${G}║${N}  HAProxy: $(systemctl is-active haproxy 2>/dev/null | grep -q active && echo "${G}Running${N}" || echo "${R}Stopped${N}")                                       ${G}║${N}\n"
    printf "    ${G}║${N}  Stats: ${C}http://$(curl -s ifconfig.me):8404/stats${N}           ${G}║${N}\n"
    printf "    ${G}╠═══════════════════════════════════════════════════════════╣${N}\n"
    printf "    ${G}║${N}  ${Y}User Connection:${N}                                          ${G}║${N}\n"
    printf "    ${G}║${N}  Connect to Iran IP on ports: ${W}${port_array[*]}${N}         ${G}║${N}\n"
    printf "    ${G}╚═══════════════════════════════════════════════════════════╝${N}\n"
    echo ""
    
    log "INFO" "Iran setup completed - Kharej: $kharej_ip, Ports: ${port_array[*]}"
    
    read -p "    Press Enter to continue..."
    return 0
}

# ═══════════════════════════════════════════════════════════════════════════════
#                         MANAGE TUNNELS
# ═══════════════════════════════════════════════════════════════════════════════
manage_tunnels() {
    while true; do
        show_banner
        
        printf "    ${C}╔═══════════════════════════════════════════════════════════╗${N}\n"
        printf "    ${C}║${N}            ${W}TUNNEL MANAGEMENT${N}                                ${C}║${N}\n"
        printf "    ${C}╚═══════════════════════════════════════════════════════════╝${N}\n"
        echo ""
        
        # Show current status
        for i in 1 2 3; do
            local status=$(systemctl is-active ssh-tunnel-$i 2>/dev/null)
            if [[ "$status" == "active" ]]; then
                printf "    ${G}●${N} Tunnel $i: ${G}ACTIVE${N}\n"
            else
                printf "    ${R}○${N} Tunnel $i: ${R}INACTIVE${N}\n"
            fi
        done
        
        echo ""
        printf "    ${Y}[1]${N} Start all tunnels\n"
        printf "    ${Y}[2]${N} Stop all tunnels\n"
        printf "    ${Y}[3]${N} Restart all tunnels\n"
        printf "    ${Y}[4]${N} View tunnel logs\n"
        printf "    ${Y}[5]${N} Test tunnel connectivity\n"
        printf "    ${Y}[0]${N} Back to main menu\n"
        echo ""
        
        printf "    ${C}Select option:${N} "
        read choice
        
        case "$choice" in
            1)
                for i in 1 2 3; do
                    systemctl start ssh-tunnel-$i 2>/dev/null
                    sleep 2
                done
                print_ok "All tunnels started"
                sleep 2
                ;;
            2)
                for i in 1 2 3; do
                    systemctl stop ssh-tunnel-$i 2>/dev/null
                done
                print_ok "All tunnels stopped"
                sleep 2
                ;;
            3)
                for i in 1 2 3; do
                    systemctl restart ssh-tunnel-$i 2>/dev/null
                    sleep 2
                done
                print_ok "All tunnels restarted"
                sleep 2
                ;;
            4)
                echo ""
                printf "    ${Y}Recent tunnel logs:${N}\n"
                line_thin
                journalctl -u 'ssh-tunnel-*' --no-pager -n 30 2>/dev/null
                echo ""
                read -p "    Press Enter to continue..."
                ;;
            5)
                echo ""
                [[ -f "$CONFIG_FILE" ]] && source "$CONFIG_FILE"
                local ports_str="${TARGET_PORTS:-8082 22896 30024}"
                read -ra ports <<< "$ports_str"
                
                printf "    ${Y}Testing local tunnel ports:${N}\n"
                for port in "${ports[@]}"; do
                    for t in 1 2 3; do
                        local lport=$((10000 + (t-1)*100 + $(echo "${ports[@]}" | tr ' ' '\n' | grep -n "^${port}$" | cut -d: -f1) - 1))
                        if nc -z 127.0.0.1 $lport 2>/dev/null; then
                            printf "    ${G}●${N} Port $lport (Tunnel $t -> $port): ${G}OK${N}\n"
                        else
                            printf "    ${R}○${N} Port $lport (Tunnel $t -> $port): ${R}FAIL${N}\n"
                        fi
                    done
                done
                echo ""
                read -p "    Press Enter to continue..."
                ;;
            0)
                return 0
                ;;
        esac
    done
}

# ═══════════════════════════════════════════════════════════════════════════════
#                         UNINSTALL
# ═══════════════════════════════════════════════════════════════════════════════
uninstall() {
    show_banner
    
    printf "    ${R}╔═══════════════════════════════════════════════════════════╗${N}\n"
    printf "    ${R}║${N}            ${W}UNINSTALL SSHSAEED${N}                                ${R}║${N}\n"
    printf "    ${R}╚═══════════════════════════════════════════════════════════╝${N}\n"
    echo ""
    
    printf "    ${Y}This will remove:${N}\n"
    printf "    ${GR}├─${N} All SSH tunnel services\n"
    printf "    ${GR}├─${N} HAProxy configuration\n"
    printf "    ${GR}├─${N} SSH keys\n"
    printf "    ${GR}└─${N} Configuration files\n"
    echo ""
    
    read -p "    Are you sure? [y/N]: " confirm
    [[ "${confirm,,}" != "y" ]] && return 0
    
    echo ""
    
    # Stop and remove tunnel services
    print_wait "Stopping tunnel services..."
    for i in 1 2 3; do
        systemctl stop ssh-tunnel-$i 2>/dev/null
        systemctl disable ssh-tunnel-$i 2>/dev/null
        rm -f /etc/systemd/system/ssh-tunnel-$i.service
    done
    systemctl daemon-reload
    print_done "Tunnel services removed"
    
    # Stop HAProxy
    print_wait "Stopping HAProxy..."
    systemctl stop haproxy 2>/dev/null
    systemctl disable haproxy 2>/dev/null
    print_done "HAProxy stopped"
    
    # Remove files
    print_wait "Removing files..."
    rm -rf "$CONFIG_DIR"
    rm -f "$KEY_FILE" "${KEY_FILE}.pub"
    rm -f /usr/local/bin/sshsaeed
    rm -f /usr/bin/sshsaeed
    print_done "Files removed"
    
    echo ""
    print_ok "SSHSaeed uninstalled successfully"
    
    read -p "    Press Enter to exit..."
    exit 0
}

# ═══════════════════════════════════════════════════════════════════════════════
#                         MAIN MENU
# ═══════════════════════════════════════════════════════════════════════════════
main_menu() {
    while true; do
        show_banner
        
        printf "    ${C}╔═══════════════════════════════════════════════════════════╗${N}\n"
        printf "    ${C}║${N}                    ${W}MAIN MENU${N}                               ${C}║${N}\n"
        printf "    ${C}╠═══════════════════════════════════════════════════════════╣${N}\n"
        printf "    ${C}║${N}                                                           ${C}║${N}\n"
        printf "    ${C}║${N}   ${Y}[1]${N}  Setup Kharej Server (Destination)                 ${C}║${N}\n"
        printf "    ${C}║${N}   ${Y}[2]${N}  Setup Iran Server (Entry Point)                   ${C}║${N}\n"
        printf "    ${C}║${N}                                                           ${C}║${N}\n"
        printf "    ${C}║${N}   ${Y}[3]${N}  System Status & Statistics                        ${C}║${N}\n"
        printf "    ${C}║${N}   ${Y}[4]${N}  Port Mapping Table                                ${C}║${N}\n"
        printf "    ${C}║${N}   ${Y}[5]${N}  Manage Tunnels                                    ${C}║${N}\n"
        printf "    ${C}║${N}                                                           ${C}║${N}\n"
        printf "    ${C}║${N}   ${Y}[6]${N}  Uninstall                                         ${C}║${N}\n"
        printf "    ${C}║${N}   ${Y}[0]${N}  Exit                                              ${C}║${N}\n"
        printf "    ${C}║${N}                                                           ${C}║${N}\n"
        printf "    ${C}╚═══════════════════════════════════════════════════════════╝${N}\n"
        echo ""
        
        printf "    ${C}Select option:${N} "
        read choice
        
        case "$choice" in
            1) setup_kharej ;;
            2) setup_iran ;;
            3) show_status ;;
            4) show_port_mapping ;;
            5) manage_tunnels ;;
            6) uninstall ;;
            0) 
                echo ""
                print_ok "Goodbye!"
                exit 0
                ;;
            *)
                print_err "Invalid option"
                sleep 1
                ;;
        esac
    done
}

# ═══════════════════════════════════════════════════════════════════════════════
#                         MAIN ENTRY POINT
# ═══════════════════════════════════════════════════════════════════════════════
main() {
    # Check root
    if [[ $EUID -ne 0 ]]; then
        echo "This script must be run as root"
        exit 1
    fi
    
    # Create directories
    mkdir -p "$CONFIG_DIR" "$BACKUP_DIR"
    touch "$LOG_FILE"
    
    # Log start
    log "INFO" "SSHSaeed v${SCRIPT_VERSION} started"
    
    # Run main menu
    main_menu
}

# Run
main "$@"
