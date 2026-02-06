#!/bin/bash
#═══════════════════════════════════════════════════════════════════════════════
#  SSHSaeed Panel - Professional Installer
#  GitHub: github.com/saeedkars/sshsaeed
#  Version: 2.0.0
#  Features: 3 SSH Tunnels + HAProxy + AES-128-GCM + AutoSSH + BBR
#═══════════════════════════════════════════════════════════════════════════════

set -e

# === Configuration ===
REPO_URL="https://raw.githubusercontent.com/saeedkars/sshsaeed/main"
INSTALL_DIR="/opt/sshsaeed"
BIN_PATH="/usr/local/bin/sshsaeed"
CONFIG_DIR="/opt/sshsaeed/config"
KEYS_DIR="/opt/sshsaeed/keys"
LOGS_DIR="/opt/sshsaeed/logs"
VERSION="2.0.0"

# === Colors ===
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
WHITE='\033[1;37m'
BOLD='\033[1m'
NC='\033[0m'

# === Print Functions ===
print_banner() {
    clear
    echo -e "${CYAN}"
    cat << "EOF"
    ╔═══════════════════════════════════════════════════════════════════════╗
    ║                                                                       ║
    ║   ███████╗███████╗██╗  ██╗███████╗ █████╗ ███████╗███████╗██████╗     ║
    ║   ██╔════╝██╔════╝██║  ██║██╔════╝██╔══██╗██╔════╝██╔════╝██╔══██╗    ║
    ║   ███████╗███████╗███████║███████╗███████║█████╗  █████╗  ██║  ██║    ║
    ║   ╚════██║╚════██║██╔══██║╚════██║██╔══██║██╔══╝  ██╔══╝  ██║  ██║    ║
    ║   ███████║███████║██║  ██║███████║██║  ██║███████╗███████╗██████╔╝    ║
    ║   ╚══════╝╚══════╝╚═╝  ╚═╝╚══════╝╚═╝  ╚═╝╚══════╝╚══════╝╚═════╝     ║
    ║                                                                       ║
    ║        🚀 Professional SSH Tunnel Manager - Installer v2.0           ║
    ║                                                                       ║
    ║   ┌─────────────────────────────────────────────────────────────┐    ║
    ║   │  ✦ 3 SSH Tunnels    ✦ HAProxy Load Balancer                │    ║
    ║   │  ✦ AES-128-GCM      ✦ AutoSSH Auto-Reconnect               │    ║
    ║   │  ✦ BBR Enabled      ✦ Professional Panel                   │    ║
    ║   └─────────────────────────────────────────────────────────────┘    ║
    ║                                                                       ║
    ║                  github.com/saeedkars/sshsaeed                        ║
    ╚═══════════════════════════════════════════════════════════════════════╝
EOF
    echo -e "${NC}"
}

print_step() {
    echo -e "\n${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${WHITE}  📌 $1${NC}"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}\n"
}

print_status() { echo -e "  ${CYAN}[●]${NC} $1"; }
print_success() { echo -e "  ${GREEN}[✓]${NC} $1"; }
print_error() { echo -e "  ${RED}[✗]${NC} $1"; }
print_warning() { echo -e "  ${YELLOW}[!]${NC} $1"; }
print_info() { echo -e "  ${PURPLE}[i]${NC} $1"; }

# === Progress Bar ===
progress_bar() {
    local duration=$1
    local steps=20
    local sleep_time=$(echo "scale=3; $duration / $steps" | bc)
    
    echo -ne "  ${CYAN}["
    for ((i=0; i<steps; i++)); do
        echo -ne "▓"
        sleep $sleep_time 2>/dev/null || sleep 0.1
    done
    echo -e "]${NC} Done!"
}

# === Check Root ===
check_root() {
    print_status "Checking root privileges..."
    
    if [[ $EUID -ne 0 ]]; then
        print_error "This installer must be run as root!"
        echo ""
        echo -e "    ${YELLOW}Please run:${NC}"
        echo -e "    ${WHITE}sudo bash install.sh${NC}"
        echo -e "    ${WHITE}or${NC}"
        echo -e "    ${WHITE}sudo bash <(curl -fsSL $REPO_URL/install.sh)${NC}"
        echo ""
        exit 1
    fi
    
    print_success "Root privileges confirmed"
}

# === Check OS ===
check_os() {
    print_status "Detecting operating system..."
    
    if [[ -f /etc/os-release ]]; then
        . /etc/os-release
        OS=$ID
        OS_VERSION=$VERSION_ID
        OS_NAME=$PRETTY_NAME
    else
        print_error "Cannot detect operating system"
        exit 1
    fi
    
    case $OS in
        ubuntu)
            PKG_MGR="apt-get"
            PKG_UPDATE="apt-get update -qq"
            PKG_INSTALL="apt-get install -y"
            print_success "Detected: $OS_NAME ✓"
            ;;
        debian)
            PKG_MGR="apt-get"
            PKG_UPDATE="apt-get update -qq"
            PKG_INSTALL="apt-get install -y"
            print_success "Detected: $OS_NAME ✓"
            ;;
        centos|rhel|almalinux|rocky)
            PKG_MGR="yum"
            PKG_UPDATE="yum makecache -q"
            PKG_INSTALL="yum install -y"
            print_success "Detected: $OS_NAME ✓"
            ;;
        fedora)
            PKG_MGR="dnf"
            PKG_UPDATE="dnf makecache -q"
            PKG_INSTALL="dnf install -y"
            print_success "Detected: $OS_NAME ✓"
            ;;
        *)
            print_warning "Untested OS: $OS_NAME"
            print_info "Attempting installation anyway..."
            PKG_MGR="apt-get"
            PKG_UPDATE="apt-get update -qq"
            PKG_INSTALL="apt-get install -y"
            ;;
    esac
}

# === Check Architecture ===
check_arch() {
    print_status "Checking system architecture..."
    
    ARCH=$(uname -m)
    case $ARCH in
        x86_64|amd64)
            print_success "Architecture: 64-bit ($ARCH) ✓"
            ;;
        aarch64|arm64)
            print_success "Architecture: ARM64 ($ARCH) ✓"
            ;;
        *)
            print_warning "Architecture: $ARCH (may have compatibility issues)"
            ;;
    esac
}

# === Update System ===
update_system() {
    print_status "Updating package lists..."
    
    $PKG_UPDATE >/dev/null 2>&1 || {
        print_warning "Package update had issues, continuing..."
    }
    
    print_success "Package lists updated"
}

# === Install Dependencies ===
install_dependencies() {
    print_status "Installing required packages..."
    
    # Required packages
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
    local failed=0
    
    for pkg in "${packages[@]}"; do
        echo -ne "  ${CYAN}[●]${NC} Installing $pkg... "
        
        if $PKG_INSTALL "$pkg" >/dev/null 2>&1; then
            echo -e "${GREEN}✓${NC}"
            ((installed++))
        else
            echo -e "${YELLOW}⚠${NC} (may already exist)"
            ((failed++))
        fi
    done
    
    echo ""
    print_success "Packages processed: $installed installed, $failed skipped"
}

# === Create Directories ===
create_directories() {
    print_status "Creating directory structure..."
    
    # Main directories
    mkdir -p "$INSTALL_DIR"
    mkdir -p "$CONFIG_DIR"
    mkdir -p "$KEYS_DIR"
    mkdir -p "$LOGS_DIR"
    mkdir -p "$INSTALL_DIR/backups"
    
    # Set permissions
    chmod 700 "$KEYS_DIR"
    chmod 755 "$INSTALL_DIR"
    chmod 755 "$CONFIG_DIR"
    chmod 755 "$LOGS_DIR"
    
    print_success "Directory structure created:"
    print_info "  Main:    $INSTALL_DIR"
    print_info "  Config:  $CONFIG_DIR"
    print_info "  Keys:    $KEYS_DIR"
    print_info "  Logs:    $LOGS_DIR"
}

# === Download Main Script ===
download_main_script() {
    print_status "Downloading main panel script..."
    
    local max_retries=3
    local retry=0
    
    while [[ $retry -lt $max_retries ]]; do
        if curl -fsSL "$REPO_URL/sshsaeed.sh" -o "$INSTALL_DIR/sshsaeed.sh" 2>/dev/null; then
            # Verify download
            if [[ -s "$INSTALL_DIR/sshsaeed.sh" ]]; then
                # Check if it's a valid bash script
                if head -1 "$INSTALL_DIR/sshsaeed.sh" | grep -q "#!/bin/bash"; then
                    chmod +x "$INSTALL_DIR/sshsaeed.sh"
                    print_success "Main script downloaded and verified ✓"
                    return 0
                fi
            fi
        fi
        
        ((retry++))
        print_warning "Download attempt $retry failed, retrying..."
        sleep 2
    done
    
    print_error "Failed to download main script after $max_retries attempts"
    print_error "Please check your internet connection and repository URL"
    print_info "Repository: $REPO_URL"
    exit 1
}

# === Create Symlink ===
create_symlink() {
    print_status "Creating system command..."
    
    # Remove old symlink if exists
    rm -f "$BIN_PATH" 2>/dev/null || true
    
    # Create new symlink
    ln -sf "$INSTALL_DIR/sshsaeed.sh" "$BIN_PATH"
    
    # Verify
    if [[ -x "$BIN_PATH" ]]; then
        print_success "Command 'sshsaeed' created successfully ✓"
    else
        print_error "Failed to create command symlink"
        print_info "You can still run: bash $INSTALL_DIR/sshsaeed.sh"
    fi
}

# === Setup BBR ===
setup_bbr() {
    print_status "Configuring BBR TCP congestion control..."
    
    # Check if BBR is already enabled
    local current_cc=$(sysctl -n net.ipv4.tcp_congestion_control 2>/dev/null || echo "unknown")
    
    if [[ "$current_cc" == "bbr" ]]; then
        print_success "BBR is already enabled ✓"
        return 0
    fi
    
    # Check if BBR module is available
    if ! modprobe tcp_bbr 2>/dev/null; then
        print_warning "BBR module not available on this kernel"
        print_info "Consider upgrading your kernel for BBR support"
        return 0
    fi
    
    # Configure BBR
    if ! grep -q "net.core.default_qdisc=fq" /etc/sysctl.conf 2>/dev/null; then
        echo "" >> /etc/sysctl.conf
        echo "# BBR Configuration - Added by SSHSaeed" >> /etc/sysctl.conf
        echo "net.core.default_qdisc=fq" >> /etc/sysctl.conf
        echo "net.ipv4.tcp_congestion_control=bbr" >> /etc/sysctl.conf
    fi
    
    # Apply settings
    sysctl -p >/dev/null 2>&1 || true
    
    # Verify
    current_cc=$(sysctl -n net.ipv4.tcp_congestion_control 2>/dev/null || echo "unknown")
    if [[ "$current_cc" == "bbr" ]]; then
        print_success "BBR enabled successfully ✓"
    else
        print_warning "BBR configuration added (will be active after reboot)"
    fi
}

# === Configure SSH ===
configure_ssh() {
    print_status "Optimizing SSH configuration..."
    
    local sshd_config="/etc/ssh/sshd_config"
    local backup_file="/etc/ssh/sshd_config.backup.$(date +%Y%m%d%H%M%S)"
    
    # Backup original config
    cp "$sshd_config" "$backup_file" 2>/dev/null || true
    
    # Add optimizations if not present
    if ! grep -q "# SSHSaeed Optimizations" "$sshd_config" 2>/dev/null; then
        cat >> "$sshd_config" << 'SSHCONFIG'

# SSHSaeed Optimizations
TCPKeepAlive yes
ClientAliveInterval 30
ClientAliveCountMax 3
MaxSessions 100
GatewayPorts yes
PermitTunnel yes
AllowTcpForwarding yes
SSHCONFIG
    fi
    
    # Restart SSH service
    systemctl restart sshd 2>/dev/null || systemctl restart ssh 2>/dev/null || true
    
    print_success "SSH configuration optimized ✓"
}

# === Create Default Config ===
create_default_config() {
    print_status "Creating default configuration..."
    
    cat > "$CONFIG_DIR/settings.conf" << EOF
# SSHSaeed Configuration File
# Generated: $(date)
# Version: $VERSION

# Server Role (kharej/iran)
SERVER_ROLE=""

# Kharej Server IP
KHAREJ_IP=""

# Number of Tunnels (max 3)
TUNNEL_COUNT=3

# SSH Port
SSH_PORT=22

# Tunnel User
TUNNEL_USER="tunnel"

# Cipher Algorithm
CIPHER="aes128-gcm@openssh.com"

# HAProxy Port
HAPROXY_PORT=443

# HAProxy Stats Port
HAPROXY_STATS_PORT=8404

# Local Tunnel Ports
TUNNEL_PORT_1=2001
TUNNEL_PORT_2=2002
TUNNEL_PORT_3=2003

# Auto Reconnect
AUTO_RECONNECT=true

# Monitor Interval (seconds)
MONITOR_INTERVAL=30
EOF

    chmod 644 "$CONFIG_DIR/settings.conf"
    print_success "Default configuration created ✓"
}

# === Setup Firewall ===
setup_firewall() {
    print_status "Configuring firewall rules..."
    
    # Common ports to allow
    local ports=(22 443 2001 2002 2003 8404)
    
    # Try ufw first
    if command -v ufw &> /dev/null; then
        for port in "${ports[@]}"; do
            ufw allow "$port/tcp" >/dev/null 2>&1 || true
        done
        print_success "UFW firewall configured ✓"
        return 0
    fi
    
    # Try firewalld
    if command -v firewall-cmd &> /dev/null; then
        for port in "${ports[@]}"; do
            firewall-cmd --permanent --add-port="$port/tcp" >/dev/null 2>&1 || true
        done
        firewall-cmd --reload >/dev/null 2>&1 || true
        print_success "Firewalld configured ✓"
        return 0
    fi
    
    # Use iptables
    for port in "${ports[@]}"; do
        iptables -A INPUT -p tcp --dport "$port" -j ACCEPT 2>/dev/null || true
    done
    
    print_success "Firewall rules added ✓"
}

# === Print Completion ===
print_completion() {
    echo ""
    echo -e "${GREEN}╔═══════════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}║                                                                       ║${NC}"
    echo -e "${GREEN}║         ✅ INSTALLATION COMPLETED SUCCESSFULLY! ✅                   ║${NC}"
    echo -e "${GREEN}║                                                                       ║${NC}"
    echo -e "${GREEN}╚═══════════════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    echo -e "${WHITE}  ┌─────────────────────────────────────────────────────────────────┐${NC}"
    echo -e "${WHITE}  │                     ${CYAN}🚀 HOW TO USE${WHITE}                              │${NC}"
    echo -e "${WHITE}  ├─────────────────────────────────────────────────────────────────┤${NC}"
    echo -e "${WHITE}  │                                                                 │${NC}"
    echo -e "${WHITE}  │   To start the panel, simply run:                               │${NC}"
    echo -e "${WHITE}  │                                                                 │${NC}"
    echo -e "${WHITE}  │            ${YELLOW}sshsaeed${WHITE}                                          │${NC}"
    echo -e "${WHITE}  │                                                                 │${NC}"
    echo -e "${WHITE}  │   Or with full path:                                            │${NC}"
    echo -e "${WHITE}  │                                                                 │${NC}"
    echo -e "${WHITE}  │            ${YELLOW}bash /opt/sshsaeed/sshsaeed.sh${WHITE}                    │${NC}"
    echo -e "${WHITE}  │                                                                 │${NC}"
    echo -e "${WHITE}  └─────────────────────────────────────────────────────────────────┘${NC}"
    echo ""
    echo -e "${PURPLE}  ┌─────────────────────────────────────────────────────────────────┐${NC}"
    echo -e "${PURPLE}  │                    📁 Installation Details                      │${NC}"
    echo -e "${PURPLE}  ├─────────────────────────────────────────────────────────────────┤${NC}"
    echo -e "${PURPLE}  │${NC}  Install Directory  │  ${WHITE}$INSTALL_DIR${NC}"
    echo -e "${PURPLE}  │${NC}  Config Directory   │  ${WHITE}$CONFIG_DIR${NC}"
    echo -e "${PURPLE}  │${NC}  Keys Directory     │  ${WHITE}$KEYS_DIR${NC}"
    echo -e "${PURPLE}  │${NC}  Logs Directory     │  ${WHITE}$LOGS_DIR${NC}"
    echo -e "${PURPLE}  │${NC}  Version            │  ${WHITE}$VERSION${NC}"
    echo -e "${PURPLE}  └─────────────────────────────────────────────────────────────────┘${NC}"
    echo ""
    echo -e "${CYAN}  ┌─────────────────────────────────────────────────────────────────┐${NC}"
    echo -e "${CYAN}  │                       ✨ Features                               │${NC}"
    echo -e "${CYAN}  ├─────────────────────────────────────────────────────────────────┤${NC}"
    echo -e "${CYAN}  │${NC}  ✦ 3 SSH Tunnels with Load Balancing                           ${CYAN}│${NC}"
    echo -e "${CYAN}  │${NC}  ✦ HAProxy for High Availability                               ${CYAN}│${NC}"
    echo -e "${CYAN}  │${NC}  ✦ AES-128-GCM Encryption                                      ${CYAN}│${NC}"
    echo -e "${CYAN}  │${NC}  ✦ AutoSSH Auto-Reconnect                                      ${CYAN}│${NC}"
    echo -e "${CYAN}  │${NC}  ✦ BBR TCP Optimization                                        ${CYAN}│${NC}"
    echo -e "${CYAN}  │${NC}  ✦ Professional Panel Interface                                ${CYAN}│${NC}"
    echo -e "${CYAN}  └─────────────────────────────────────────────────────────────────┘${NC}"
    echo ""
    echo -e "${BLUE}═══════════════════════════════════════════════════════════════════════${NC}"
    echo -e "${WHITE}           GitHub: ${CYAN}github.com/saeedkars/sshsaeed${NC}"
    echo -e "${BLUE}═══════════════════════════════════════════════════════════════════════${NC}"
    echo ""
}

# === Uninstall Function ===
uninstall() {
    print_banner
    
    echo -e "${YELLOW}"
    echo "  ╔═══════════════════════════════════════════════════════════════╗"
    echo "  ║                    ⚠️  UNINSTALL MODE                         ║"
    echo "  ╚═══════════════════════════════════════════════════════════════╝"
    echo -e "${NC}"
    
    read -p "$(echo -e ${RED}[!]${NC} Are you sure you want to uninstall SSHSaeed? [y/N]: )" confirm
    
    if [[ "${confirm,,}" != "y" ]]; then
        print_info "Uninstallation cancelled"
        exit 0
    fi
    
    echo ""
    print_step "Removing SSHSaeed"
    
    # Stop AutoSSH services
    print_status "Stopping tunnel services..."
    for i in 1 2 3; do
        systemctl stop "autossh-tunnel-$i" 2>/dev/null || true
        systemctl disable "autossh-tunnel-$i" 2>/dev/null || true
        rm -f "/etc/systemd/system/autossh-tunnel-$i.service" 2>/dev/null || true
    done
    print_success "Tunnel services stopped"
    
    # Stop HAProxy
    print_status "Stopping HAProxy..."
    systemctl stop haproxy 2>/dev/null || true
    print_success "HAProxy stopped"
    
    # Reload systemd
    systemctl daemon-reload 2>/dev/null || true
    
    # Remove files
    print_status "Removing files..."
    rm -rf "$INSTALL_DIR"
    rm -f "$BIN_PATH"
    print_success "Files removed"
    
    # Remove tunnel user
    print_status "Removing tunnel user..."
    userdel -r tunnel 2>/dev/null || true
    print_success "User removed"
    
    echo ""
    echo -e "${GREEN}╔═══════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}║          ✅ Uninstallation Completed Successfully!            ║${NC}"
    echo -e "${GREEN}╚═══════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    echo -e "  ${WHITE}To reinstall, run:${NC}"
    echo -e "  ${YELLOW}bash <(curl -fsSL $REPO_URL/install.sh)${NC}"
    echo ""
}

# === Help Function ===
show_help() {
    echo ""
    echo -e "${CYAN}SSHSaeed Installer - Help${NC}"
    echo ""
    echo -e "${WHITE}Usage:${NC}"
    echo "  bash install.sh [OPTIONS]"
    echo ""
    echo -e "${WHITE}Options:${NC}"
    echo "  -h, --help        Show this help message"
    echo "  -u, --uninstall   Uninstall SSHSaeed"
    echo "  -v, --version     Show version"
    echo ""
    echo -e "${WHITE}Examples:${NC}"
    echo "  # Install"
    echo "  bash <(curl -fsSL $REPO_URL/install.sh)"
    echo ""
    echo "  # Uninstall"
    echo "  bash <(curl -fsSL $REPO_URL/install.sh) --uninstall"
    echo ""
}

# === Main Function ===
main() {
    # Parse arguments
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
    
    # Show banner
    print_banner
    
    echo -e "${WHITE}  Starting installation process...${NC}"
    sleep 1
    
    # === Step 1: System Check ===
    print_step "Step 1/8: System Check"
    check_root
    check_os
    check_arch
    
    # === Step 2: Update System ===
    print_step "Step 2/8: System Update"
    update_system
    
    # === Step 3: Install Dependencies ===
    print_step "Step 3/8: Installing Dependencies"
    install_dependencies
    
    # === Step 4: Create Directories ===
    print_step "Step 4/8: Creating Directories"
    create_directories
    
    # === Step 5: Download Main Script ===
    print_step "Step 5/8: Downloading Panel"
    download_main_script
    
    # === Step 6: Create Command ===
    print_step "Step 6/8: Creating System Command"
    create_symlink
    create_default_config
    
    # === Step 7: System Optimization ===
    print_step "Step 7/8: System Optimization"
    setup_bbr
    configure_ssh
    
    # === Step 8: Firewall Setup ===
    print_step "Step 8/8: Firewall Configuration"
    setup_firewall
    
    # === Completion ===
    print_completion
    
    # Ask to run panel
    echo ""
    read -p "$(echo -e ${CYAN}[?]${NC} Would you like to start the panel now? [Y/n]: )" run_now
    
    if [[ "${run_now,,}" != "n" ]]; then
        echo ""
        print_info "Starting SSHSaeed Panel..."
        sleep 1
        sshsaeed
    else
        echo ""
        print_info "You can start the panel anytime by running: ${YELLOW}sshsaeed${NC}"
        echo ""
    fi
}

# === Run Main ===
main "$@"
