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
#  AES-128-GCM Encrypted SSH Tunnels with HAProxy Load Balancing
# ═══════════════════════════════════════════════════════════════════════════════

set -o pipefail
export LC_ALL=C
export LANG=C

# ═══════════════════════════════════════════════════════════════════════════════
#                              VARIABLES
# ═══════════════════════════════════════════════════════════════════════════════
readonly SCRIPT_VERSION="6.0"
readonly SCRIPT_NAME="sshsaeed"
readonly INSTALL_PATH="/usr/local/bin/sshsaeed"
readonly SCRIPT_URL="https://raw.githubusercontent.com/saeedkars/sshsaeed/main/sshsaeed.sh"
readonly BACKUP_URL="https://raw.githubusercontent.com/saeedkars/sshsaeed/master/sshsaeed.sh"
readonly BACKUP_PATH="/usr/local/bin/sshsaeed.backup"
readonly CONFIG_DIR="/etc/sshsaeed"

# Package manager variables
PKG_MANAGER=""
PKG_UPDATE=""
PKG_INSTALL=""

# ═══════════════════════════════════════════════════════════════════════════════
#                              COLORS
# ═══════════════════════════════════════════════════════════════════════════════
R='\033[0;31m'      # Red
G='\033[0;32m'      # Green
Y='\033[1;33m'      # Yellow
B='\033[0;34m'      # Blue
M='\033[0;35m'      # Magenta
C='\033[0;36m'      # Cyan
W='\033[1;37m'      # White
GR='\033[0;90m'     # Gray
N='\033[0m'         # No color
BOLD='\033[1m'

# ═══════════════════════════════════════════════════════════════════════════════
#                              HELPER FUNCTIONS
# ═══════════════════════════════════════════════════════════════════════════════
print_ok() { printf "    ${G}✓${N} %s\n" "$1"; }
print_err() { printf "    ${R}✗${N} %s\n" "$1"; }
print_warn() { printf "    ${Y}⚠${N} %s\n" "$1"; }
print_info() { printf "    ${C}►${N} %s\n" "$1"; }
print_wait() { printf "    ${Y}◐${N} %s\r" "$1"; }
print_done() { printf "    ${G}✓${N} %s\n" "$1"; }

line() {
    printf "    ${GR}═══════════════════════════════════════════════════════════${N}\n"
}

line_thin() {
    printf "    ${GR}───────────────────────────────────────────────────────────${N}\n"
}

# ═══════════════════════════════════════════════════════════════════════════════
#                              BANNER
# ═══════════════════════════════════════════════════════════════════════════════
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
#                              CHECK OS
# ═══════════════════════════════════════════════════════════════════════════════
check_os() {
    local os_id=""
    local os_ver=""

    if [[ -f /etc/os-release ]]; then
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
                print_err "Unsupported operating system"
                exit 1
            fi
            ;;
    esac

    print_ok "OS Detected: ${os_id:-unknown} ${os_ver:-}"
}

# ═══════════════════════════════════════════════════════════════════════════════
#                              CHECK ROOT
# ═══════════════════════════════════════════════════════════════════════════════
check_root() {
    if [[ $EUID -ne 0 ]]; then
        echo ""
        print_err "This script requires root access"
        echo ""
        printf "    ${Y}Run:${N} ${W}sudo bash $0${N}\n"
        printf "    ${Y}Or:${N} ${W}sudo su -${N} ${GR}then run the script${N}\n"
        echo ""
        exit 1
    fi
}

# ═══════════════════════════════════════════════════════════════════════════════
#                         INSTALL DEPENDENCIES
# ═══════════════════════════════════════════════════════════════════════════════
install_dependencies() {
    print_info "Checking and installing dependencies..."

    local deps_needed=()

    # Check curl
    if ! command -v curl &>/dev/null; then
        deps_needed+=("curl")
    fi

    # Check wget (as backup)
    if ! command -v wget &>/dev/null; then
        deps_needed+=("wget")
    fi

    # Check openssl (for encryption test)
    if ! command -v openssl &>/dev/null; then
        deps_needed+=("openssl")
    fi

    if [[ ${#deps_needed[@]} -gt 0 ]]; then
        print_info "Installing: ${deps_needed[*]}"

        # Update package list
        $PKG_UPDATE >/dev/null 2>&1 || true

        # Install dependencies
        for pkg in "${deps_needed[@]}"; do
            $PKG_INSTALL "$pkg" >/dev/null 2>&1 || print_warn "Failed to install $pkg"
        done
    fi

    print_ok "Dependencies ready"
}

# ═══════════════════════════════════════════════════════════════════════════════
#                         CHECK EXISTING VERSION
# ═══════════════════════════════════════════════════════════════════════════════
check_existing() {
    if [[ -f "$INSTALL_PATH" ]]; then
        local current_ver=$(grep -m1 "^readonly SCRIPT_VERSION=" "$INSTALL_PATH" 2>/dev/null | cut -d'"' -f2)

        # Check old format
        if [[ -z "$current_ver" ]]; then
            current_ver=$(grep -m1 "^readonly VERSION=" "$INSTALL_PATH" 2>/dev/null | cut -d'"' -f2)
        fi

        if [[ -n "$current_ver" ]]; then
            echo ""
            print_warn "Previous version installed: v${current_ver}"
            printf "    ${C}New version: v${SCRIPT_VERSION}${N}\n"
            echo ""

            read -p "$(printf "    ${Y}Do you want to update? [Y/n]: ${N}")" update_choice

            if [[ "$update_choice" == "n" || "$update_choice" == "N" ]]; then
                echo ""
                print_info "Running current version..."
                sleep 1
                exec "$INSTALL_PATH"
                exit 0
            fi

            # Backup current version
            print_info "Backing up current version..."
            cp "$INSTALL_PATH" "$BACKUP_PATH" 2>/dev/null
            print_ok "Backup created at $BACKUP_PATH"
        fi
    fi
}

# ═══════════════════════════════════════════════════════════════════════════════
#                         DOWNLOAD SCRIPT
# ═══════════════════════════════════════════════════════════════════════════════
download_script() {
    local temp_file="/tmp/sshsaeed_download_$$.sh"
    local download_success=false
    
    print_info "Downloading SSHSaeed v${SCRIPT_VERSION}..."
    
    # Try primary URL with curl
    if command -v curl &>/dev/null; then
        print_wait "Trying primary URL..."
        if curl -fsSL --connect-timeout 15 --max-time 60 "$SCRIPT_URL" -o "$temp_file" 2>/dev/null; then
            if [[ -s "$temp_file" ]] && head -1 "$temp_file" | grep -q "^#!/bin/bash"; then
                download_success=true
                print_done "Downloaded from primary URL"
            fi
        fi
    fi
    
    # Try backup URL if primary failed
    if [[ "$download_success" != "true" ]]; then
        print_wait "Trying backup URL..."
        if curl -fsSL --connect-timeout 15 --max-time 60 "$BACKUP_URL" -o "$temp_file" 2>/dev/null; then
            if [[ -s "$temp_file" ]] && head -1 "$temp_file" | grep -q "^#!/bin/bash"; then
                download_success=true
                print_done "Downloaded from backup URL"
            fi
        fi
    fi
    
    # Try wget if curl failed
    if [[ "$download_success" != "true" ]] && command -v wget &>/dev/null; then
        print_wait "Trying with wget..."
        if wget -q --timeout=15 "$SCRIPT_URL" -O "$temp_file" 2>/dev/null; then
            if [[ -s "$temp_file" ]] && head -1 "$temp_file" | grep -q "^#!/bin/bash"; then
                download_success=true
                print_done "Downloaded with wget"
            fi
        fi
    fi
    
    # Verify and install
    if [[ "$download_success" == "true" ]]; then
        # Verify script integrity
        local line_count=$(wc -l < "$temp_file" 2>/dev/null)
        
        if [[ $line_count -lt 500 ]]; then
            print_err "Downloaded file appears incomplete ($line_count lines)"
            rm -f "$temp_file"
            return 1
        fi
        
        # Install
        mv "$temp_file" "$INSTALL_PATH"
        chmod +x "$INSTALL_PATH"
        
        # Create symlink
        ln -sf "$INSTALL_PATH" /usr/bin/sshsaeed 2>/dev/null
        
        print_ok "Script installed successfully ($line_count lines)"
        return 0
    else
        print_err "Download failed from all sources"
        echo ""
        printf "    ${Y}Manual installation:${N}\n"
        printf "    1. Download sshsaeed.sh manually\n"
        printf "    2. Copy to: ${W}$INSTALL_PATH${N}\n"
        printf "    3. Run: ${W}chmod +x $INSTALL_PATH${N}\n"
        rm -f "$temp_file"
        return 1
    fi
}

# ═══════════════════════════════════════════════════════════════════════════════
#                         CREATE DIRECTORIES
# ═══════════════════════════════════════════════════════════════════════════════
create_directories() {
    print_info "Creating required directories..."

    mkdir -p "$CONFIG_DIR" 2>/dev/null
    mkdir -p "$CONFIG_DIR/backups" 2>/dev/null
    mkdir -p /root/.ssh 2>/dev/null
    chmod 700 /root/.ssh 2>/dev/null

    print_ok "Directories ready"
}

# ═══════════════════════════════════════════════════════════════════════════════
#                         CLEANUP
# ═══════════════════════════════════════════════════════════════════════════════
cleanup() {
    rm -f /tmp/sshsaeed_download_*.sh 2>/dev/null
}

# ═══════════════════════════════════════════════════════════════════════════════
#                         SHOW SUCCESS
# ═══════════════════════════════════════════════════════════════════════════════
show_success() {
    echo ""
    printf "    ${G}╔═══════════════════════════════════════════════════════════╗${N}\n"
    printf "    ${G}║${N}                                                           ${G}║${N}\n"
    printf "    ${G}║${N}       ${W}✓ Installation completed successfully!${N}             ${G}║${N}\n"
    printf "    ${G}║${N}                                                           ${G}║${N}\n"
    printf "    ${G}║${N}       ${C}Version: ${W}v${SCRIPT_VERSION}${N}                                    ${G}║${N}\n"
    printf "    ${G}║${N}       ${C}Path: ${W}$INSTALL_PATH${N}                   ${G}║${N}\n"
    printf "    ${G}║${N}                                                           ${G}║${N}\n"
    printf "    ${G}╠═══════════════════════════════════════════════════════════╣${N}\n"
    printf "    ${G}║${N}  ${Y}Features:${N}                                               ${G}║${N}\n"
    printf "    ${G}║${N}  • AES-128-GCM Encryption                                 ${G}║${N}\n"
    printf "    ${G}║${N}  • 3 Redundant SSH Tunnels                                ${G}║${N}\n"
    printf "    ${G}║${N}  • HAProxy Load Balancing                                 ${G}║${N}\n"
    printf "    ${G}║${N}  • BBR Congestion Control                                 ${G}║${N}\n"
    printf "    ${G}║${N}  • Automatic Reconnection                                 ${G}║${N}\n"
    printf "    ${G}╚═══════════════════════════════════════════════════════════╝${N}\n"
    echo ""
    printf "    ${Y}To run:${N} ${W}sshsaeed${N}\n"
    echo ""
}

# ═══════════════════════════════════════════════════════════════════════════════
#                         SHOW HELP
# ═══════════════════════════════════════════════════════════════════════════════
show_help() {
    show_banner
    printf "    ${W}Usage:${N} $0 [OPTIONS]\n"
    echo ""
    printf "    ${Y}Options:${N}\n"
    printf "    ${GR}  -h, --help${N}      Show this help message\n"
    printf "    ${GR}  -v, --version${N}   Show version information\n"
    printf "    ${GR}  -u, --uninstall${N} Uninstall SSHSaeed\n"
    printf "    ${GR}  -f, --force${N}     Force reinstall\n"
    echo ""
    printf "    ${Y}Examples:${N}\n"
    printf "    ${GR}  bash install.sh${N}           Normal installation\n"
    printf "    ${GR}  bash install.sh -f${N}        Force reinstall\n"
    printf "    ${GR}  bash install.sh -u${N}        Uninstall\n"
    echo ""
}

# ═══════════════════════════════════════════════════════════════════════════════
#                         UNINSTALL
# ═══════════════════════════════════════════════════════════════════════════════
do_uninstall() {
    show_banner
    
    printf "    ${R}╔═══════════════════════════════════════════════════════════╗${N}\n"
    printf "    ${R}║${N}            ${W}UNINSTALL SSHSAEED${N}                                ${R}║${N}\n"
    printf "    ${R}╚═══════════════════════════════════════════════════════════╝${N}\n"
    echo ""
    
    read -p "$(printf "    ${Y}Are you sure you want to uninstall? [y/N]: ${N}")" confirm
    
    if [[ "${confirm,,}" != "y" ]]; then
        print_info "Uninstall cancelled"
        exit 0
    fi
    
    echo ""
    
    # Stop services
    print_wait "Stopping services..."
    for i in 1 2 3; do
        systemctl stop ssh-tunnel-$i 2>/dev/null
        systemctl disable ssh-tunnel-$i 2>/dev/null
        rm -f /etc/systemd/system/ssh-tunnel-$i.service
    done
    systemctl stop haproxy 2>/dev/null
    systemctl daemon-reload 2>/dev/null
    print_done "Services stopped"
    
    # Remove files
    print_wait "Removing files..."
    rm -f "$INSTALL_PATH"
    rm -f "$BACKUP_PATH"
    rm -f /usr/bin/sshsaeed
    rm -rf "$CONFIG_DIR"
    rm -f /root/.ssh/sshsaeed_key*
    print_done "Files removed"
    
    echo ""
    print_ok "SSHSaeed uninstalled successfully"
    echo ""
    
    exit 0
}

# ═══════════════════════════════════════════════════════════════════════════════
#                              MAIN
# ═══════════════════════════════════════════════════════════════════════════════
main() {
    # Parse arguments
    case "${1:-}" in
        -h|--help)
            show_help
            exit 0
            ;;
        -v|--version)
            echo "SSHSaeed Installer v${SCRIPT_VERSION}"
            exit 0
            ;;
        -u|--uninstall)
            check_root
            do_uninstall
            ;;
        -f|--force)
            rm -f "$INSTALL_PATH" 2>/dev/null
            ;;
    esac
    
    # Show banner
    show_banner

    # Check root
    check_root

    line
    printf "    ${W}Starting SSHSaeed v${SCRIPT_VERSION} Installation${N}\n"
    line
    echo ""

    # Installation steps
    check_os
    check_existing
    install_dependencies
    create_directories

    if download_script; then
        cleanup
        show_success

        # Ask to run immediately
        read -p "$(printf "    ${Y}Run management panel now? [Y/n]: ${N}")" run_now

        if [[ "$run_now" != "n" && "$run_now" != "N" ]]; then
            echo ""
            print_info "Launching panel..."
            sleep 1
            exec "$INSTALL_PATH"
        fi
    else
        exit 1
    fi
}

# Run main
main "$@"
