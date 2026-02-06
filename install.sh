#!/bin/bash
#═══════════════════════════════════════════════════════════════════════════════
#  SSH Tunnel Manager - Installer
#  GitHub: github.com/saeedkars/sshsaeed
#  Version: 1.0.0
#═══════════════════════════════════════════════════════════════════════════════

set -e

# === Configuration ===
REPO_URL="https://raw.githubusercontent.com/saeedkars/sshsaeed/main"
INSTALL_DIR="/opt/sshsaeed"
BIN_PATH="/usr/local/bin/sshsaeed"
VERSION="1.0.0"

# === Colors ===
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
WHITE='\033[1;37m'
NC='\033[0m'

# === Functions ===
print_banner() {
    clear
    echo -e "${CYAN}"
    cat << "EOF"
    ╔═══════════════════════════════════════════════════════════════════╗
    ║   ███████╗███████╗██╗  ██╗███████╗ █████╗ ███████╗███████╗██████╗ ║
    ║   ██╔════╝██╔════╝██║  ██║██╔════╝██╔══██╗██╔════╝██╔════╝██╔══██╗║
    ║   ███████╗███████╗███████║███████╗███████║█████╗  █████╗  ██║  ██║║
    ║   ╚════██║╚════██║██╔══██║╚════██║██╔══██║██╔══╝  ██╔══╝  ██║  ██║║
    ║   ███████║███████║██║  ██║███████║██║  ██║███████╗███████╗██████╔╝║
    ║   ╚══════╝╚══════╝╚═╝  ╚═╝╚══════╝╚═╝  ╚═╝╚══════╝╚══════╝╚═════╝ ║
    ║                                                                   ║
    ║          🚀 SSH Tunnel Manager - Installer v${VERSION}              ║
    ║              github.com/saeedkars/sshsaeed                        ║
    ╚═══════════════════════════════════════════════════════════════════╝
EOF
    echo -e "${NC}"
}

print_status() {
    echo -e "${CYAN}[*]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[✓]${NC} $1"
}

print_error() {
    echo -e "${RED}[✗]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[!]${NC} $1"
}

check_root() {
    if [[ $EUID -ne 0 ]]; then
        print_error "This script must be run as root"
        echo -e "    Run: ${YELLOW}sudo bash install.sh${NC}"
        exit 1
    fi
}

check_os() {
    if [[ -f /etc/os-release ]]; then
        . /etc/os-release
        OS=$ID
        VERSION_ID=$VERSION_ID
    else
        print_error "Cannot detect OS"
        exit 1
    fi
    
    case $OS in
        ubuntu|debian)
            print_success "Detected: $OS $VERSION_ID"
            ;;
        centos|rhel|fedora|almalinux|rocky)
            print_success "Detected: $OS $VERSION_ID"
            ;;
        *)
            print_warning "Untested OS: $OS - Proceeding anyway..."
            ;;
    esac
}

install_dependencies() {
    print_status "Installing dependencies..."
    
    if command -v apt-get &> /dev/null; then
        apt-get update -qq
        apt-get install -y -qq curl wget jq bc sshpass > /dev/null 2>&1
    elif command -v yum &> /dev/null; then
        yum install -y -q curl wget jq bc sshpass > /dev/null 2>&1
    elif command -v dnf &> /dev/null; then
        dnf install -y -q curl wget jq bc sshpass > /dev/null 2>&1
    fi
    
    print_success "Dependencies installed"
}

create_directories() {
    print_status "Creating directories..."
    
    mkdir -p "$INSTALL_DIR"
    mkdir -p "$INSTALL_DIR/config"
    mkdir -p "$INSTALL_DIR/backups"
    mkdir -p "$INSTALL_DIR/logs"
    
    print_success "Directories created: $INSTALL_DIR"
}

download_main_script() {
    print_status "Downloading main script..."
    
    if curl -fsSL "$REPO_URL/sshsaeed.sh" -o "$INSTALL_DIR/sshsaeed.sh"; then
        chmod +x "$INSTALL_DIR/sshsaeed.sh"
        print_success "Main script downloaded"
    else
        print_error "Failed to download main script"
        print_warning "Creating offline version..."
        create_offline_script
    fi
}

create_symlink() {
    print_status "Creating command symlink..."
    
    ln -sf "$INSTALL_DIR/sshsaeed.sh" "$BIN_PATH"
    
    if [[ -x "$BIN_PATH" ]]; then
        print_success "Command created: sshsaeed"
    else
        print_error "Failed to create symlink"
        exit 1
    fi
}

create_offline_script() {
    # If download fails, create a basic script
    cat > "$INSTALL_DIR/sshsaeed.sh" << 'SCRIPT'
#!/bin/bash
echo "Error: Main script not found. Please reinstall."
echo "Run: bash <(curl -fsSL https://raw.githubusercontent.com/saeedkars/sshsaeed/main/install.sh)"
SCRIPT
    chmod +x "$INSTALL_DIR/sshsaeed.sh"
}

print_completion() {
    echo ""
    echo -e "${GREEN}═══════════════════════════════════════════════════════════════════${NC}"
    echo -e "${GREEN}            ✅ Installation Completed Successfully!                ${NC}"
    echo -e "${GREEN}═══════════════════════════════════════════════════════════════════${NC}"
    echo ""
    echo -e "  ${WHITE}To start the panel, run:${NC}"
    echo -e "  ${CYAN}┌─────────────────────────────────┐${NC}"
    echo -e "  ${CYAN}│${NC}  ${YELLOW}sshsaeed${NC}                       ${CYAN}│${NC}"
    echo -e "  ${CYAN}└─────────────────────────────────┘${NC}"
    echo ""
    echo -e "  ${WHITE}Installation directory:${NC} ${PURPLE}$INSTALL_DIR${NC}"
    echo -e "  ${WHITE}Config directory:${NC}       ${PURPLE}$INSTALL_DIR/config${NC}"
    echo -e "  ${WHITE}Backups directory:${NC}      ${PURPLE}$INSTALL_DIR/backups${NC}"
    echo ""
    echo -e "${CYAN}═══════════════════════════════════════════════════════════════════${NC}"
    echo ""
}

# === Uninstall Function ===
uninstall() {
    print_banner
    print_warning "Uninstalling SSH Tunnel Manager..."
    
    # Stop services
    systemctl stop 'ssh-tunnel-*' 2>/dev/null || true
    systemctl disable 'ssh-tunnel-*' 2>/dev/null || true
    rm -f /etc/systemd/system/ssh-tunnel-*.service
    systemctl daemon-reload
    
    # Remove files
    rm -rf "$INSTALL_DIR"
    rm -f "$BIN_PATH"
    
    print_success "Uninstallation complete"
}

# === Main ===
main() {
    print_banner
    
    # Check for uninstall flag
    if [[ "$1" == "--uninstall" ]] || [[ "$1" == "-u" ]]; then
        uninstall
        exit 0
    fi
    
    echo -e "${WHITE}Starting installation...${NC}\n"
    
    check_root
    check_os
    install_dependencies
    create_directories
    download_main_script
    create_symlink
    print_completion
}

# Run main
main "$@"
