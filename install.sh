#!/bin/bash
# SWEET-Scripts Installer - Supports Ubuntu/Debian and RHEL/CentOS/Fedora

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
BOLD='\033[1m'
NC='\033[0m'

# Config
INSTALL_DIR="${SWEETS_DIR:-$HOME/.sweet-scripts}"
REPO_URL="https://github.com/sweets9/SWEET-Scripts.git"
MARKER="# >>> SWEET-Scripts >>>"
END_MARKER="# <<< SWEET-Scripts <<<"

# =============================================================================
# PACKAGE DEFINITIONS
# =============================================================================
# Format: "package_name:apt_name:dnf_name:description:notes"
# Use "-" if not available for that distro

PACKAGES_CORE=(
    "git:git:git:Version control:Required"
    "curl:curl:curl:HTTP client:Required"
    "wget:wget:wget:File downloader:Required"
    "tree:tree:tree:Directory tree view:Required"
    "tmux:tmux:tmux:Terminal multiplexer:Required"
    "vim:vim:vim-enhanced:Text editor:Required"
    "zsh:zsh:zsh:Z Shell:Recommended"
    "jq:jq:jq:JSON processor:Recommended"
    "htop:htop:htop:Process viewer:Recommended"
    "btop:btop:btop:Modern process viewer:Recommended"
)

PACKAGES_ARCHIVE=(
    "zip:zip:zip:Zip compression:"
    "unzip:unzip:unzip:Zip extraction:"
    "p7zip:p7zip-full:p7zip:7z support (basic):"
    "p7zip-full:p7zip-full:p7zip-plugins:7z support (full):RHEL: p7zip-plugins"
    "tar:tar:tar:Tar archives:Usually pre-installed"
    "gzip:gzip:gzip:Gzip compression:Usually pre-installed"
    "bzip2:bzip2:bzip2:Bzip2 compression:"
    "xz:xz-utils:xz:XZ compression:RHEL: xz"
)

PACKAGES_NET=(
    "net-tools:net-tools:net-tools:ifconfig, netstat, etc:"
    "dnsutils:dnsutils:bind-utils:dig, nslookup:RHEL: bind-utils"
    "iputils:iputils-ping:iputils:ping:"
    "traceroute:traceroute:traceroute:Network path tracing:"
    "netcat:netcat-openbsd:nmap-ncat:Netcat:RHEL: nmap-ncat"
    "nmap:nmap:nmap:Network scanner:"
    "tcpdump:tcpdump:tcpdump:Packet capture:"
    "whois:whois:whois:Domain lookup:"
    "openssh-client:openssh-client:openssh-clients:SSH client:RHEL: openssh-clients"
    "rsync:rsync:rsync:File sync:"
    "socat:socat:socat:Socket relay:"
)

PACKAGES_CLIPBOARD=(
    "xclip:xclip:xclip:X11 clipboard:Install if using X11"
    "wl-clipboard:wl-clipboard:wl-clipboard:Wayland clipboard:Install if using Wayland"
)

PACKAGES_DEV=(
    "build-essential:build-essential:@development-tools:Build tools:RHEL: groupinstall 'Development Tools'"
    "python3:python3:python3:Python 3:Usually pre-installed"
    "python3-pip:python3-pip:python3-pip:Python package manager:"
    "python3-venv:python3-venv:python3-virtualenv:Python venv:RHEL: python3-virtualenv"
    "make:make:make:Build automation:"
    "gcc:gcc:gcc:C compiler:"
)

PACKAGES_MODERN=(
    "eza:eza:-:Modern ls replacement:RHEL: Manual install or cargo"
    "bat:bat:bat:Modern cat with highlighting:RHEL 8: Not in default repos"
    "fd-find:fd-find:fd-find:Modern find:RHEL: May need EPEL"
    "ripgrep:ripgrep:ripgrep:Modern grep:RHEL: May need EPEL"
    "fzf:fzf:fzf:Fuzzy finder:RHEL: May need EPEL"
)

PACKAGES_MANUAL=(
    "gh:GitHub CLI:curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg | sudo dd of=/usr/share/keyrings/githubcli-archive-keyring.gpg && echo 'deb [arch=\$(dpkg --print-architecture) signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main' | sudo tee /etc/apt/sources.list.d/github-cli.list && sudo apt update && sudo apt install gh"
    "az:Azure CLI:curl -sL https://aka.ms/InstallAzureCLIDeb | sudo bash"
    "claude:Claude CLI (Anthropic):npm install -g @anthropic-ai/claude-cli"
    "gemini:Gemini CLI (Google):pip install google-generativeai"
    "docker:Docker Engine:https://docs.docker.com/engine/install/"
    "kubectl:Kubernetes CLI:curl -LO 'https://dl.k8s.io/release/\$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl' && chmod +x kubectl && sudo mv kubectl /usr/local/bin/"
    "terraform:Terraform:https://www.terraform.io/downloads"
    "uv:Fast Python manager:curl -LsSf https://astral.sh/uv/install.sh | sh"
    "poetry:Python dependency manager:curl -sSL https://install.python-poetry.org | python3 -"
    "homebrew:Linuxbrew:/bin/bash -c \"\$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)\""
    "nvm:Node Version Manager:curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.1/install.sh | bash"
    "rustup:Rust toolchain:curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh"
)

show_banner() {
    echo ""
    echo -e "${CYAN}${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${BOLD}  SWEET-Scripts v2.0.0${NC}"
    echo -e "${CYAN}  Shell Wrappers for Efficient Elevated Terminal Sessions${NC}"
    echo -e "${BLUE}  https://github.com/sweets9/SWEET-Scripts${NC}"
    echo -e "${CYAN}${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
}

# Detect distribution
detect_distro() {
    if [[ -f /etc/os-release ]]; then
        source /etc/os-release
        DISTRO_ID="$ID"
        DISTRO_FAMILY="$ID_LIKE"
        DISTRO_VERSION="$VERSION_ID"
        DISTRO_NAME="$PRETTY_NAME"
    elif command -v lsb_release &>/dev/null; then
        DISTRO_ID=$(lsb_release -si | tr '[:upper:]' '[:lower:]')
        DISTRO_VERSION=$(lsb_release -sr)
        DISTRO_NAME=$(lsb_release -sd)
        DISTRO_FAMILY=""
    else
        DISTRO_ID="unknown"
        DISTRO_VERSION=""
        DISTRO_NAME="Unknown"
        DISTRO_FAMILY=""
    fi

    # Determine package manager and distro family
    if [[ "$DISTRO_ID" == "ubuntu" ]] || [[ "$DISTRO_ID" == "debian" ]] || [[ "$DISTRO_FAMILY" == *"debian"* ]]; then
        PKG_MANAGER="apt"
        DISTRO_TYPE="debian"
    elif [[ "$DISTRO_ID" == "rhel" ]] || [[ "$DISTRO_ID" == "centos" ]] || [[ "$DISTRO_ID" == "rocky" ]] || [[ "$DISTRO_ID" == "almalinux" ]] || [[ "$DISTRO_FAMILY" == *"rhel"* ]] || [[ "$DISTRO_ID" == "fedora" ]]; then
        if command -v dnf &>/dev/null; then
            PKG_MANAGER="dnf"
        else
            PKG_MANAGER="yum"
        fi
        DISTRO_TYPE="rhel"
    else
        PKG_MANAGER="unknown"
        DISTRO_TYPE="unknown"
    fi

    echo -e "${BLUE}[i]${NC} Detected: $DISTRO_NAME"
    echo -e "${BLUE}[i]${NC} Package manager: $PKG_MANAGER"
}

# Helper to show package category
show_pkg_category() {
    local title="$1"
    shift
    local pkgs=("$@")
    
    echo -e "\n${BOLD}$title:${NC}"
    for pkg in "${pkgs[@]}"; do
        IFS=':' read -r name apt_pkg dnf_pkg desc notes <<< "$pkg"
        local status
        local pkg_name="$apt_pkg"
        [[ "$DISTRO_TYPE" == "rhel" ]] && pkg_name="$dnf_pkg"
        
        if [[ "$pkg_name" == "-" ]]; then
            status="${RED}✗${NC}"
            echo -e "  $status $name - $desc ${RED}[Not in repos]${NC}"
        else
            command -v "${name%%-*}" &>/dev/null && status="${GREEN}✓${NC}" || status="${YELLOW}○${NC}"
            if [[ -n "$notes" ]]; then
                echo -e "  $status $name - $desc ${BLUE}($notes)${NC}"
            else
                echo -e "  $status $name - $desc"
            fi
        fi
    done
}

# Show package list
show_packages() {
    echo -e "\n${CYAN}${BOLD}=== Package Overview ===${NC}"
    
    show_pkg_category "Core" "${PACKAGES_CORE[@]}"
    show_pkg_category "Archive Tools" "${PACKAGES_ARCHIVE[@]}"
    show_pkg_category "Network Tools" "${PACKAGES_NET[@]}"
    show_pkg_category "Dev Tools" "${PACKAGES_DEV[@]}"
    show_pkg_category "Modern CLI" "${PACKAGES_MODERN[@]}"
    show_pkg_category "Clipboard" "${PACKAGES_CLIPBOARD[@]}"
    
    echo -e "\n${BOLD}Manual Installation:${NC}"
    for pkg in "${PACKAGES_MANUAL[@]}"; do
        IFS=':' read -r name desc install <<< "$pkg"
        local status
        command -v "$name" &>/dev/null && status="${GREEN}✓${NC}" || status="${YELLOW}○${NC}"
        echo -e "  $status ${BOLD}$name${NC} - $desc"
        echo -e "      ${BLUE}$install${NC}"
    done
    
    echo -e "\n${BOLD}Legend:${NC} ${GREEN}✓${NC} Installed  ${YELLOW}○${NC} Not installed  ${RED}✗${NC} Not available"
}

# Build package list from array
_build_pkg_list() {
    local result=""
    for pkg in "$@"; do
        IFS=':' read -r name apt_pkg dnf_pkg desc notes <<< "$pkg"
        local pkg_name="$apt_pkg"
        [[ "$DISTRO_TYPE" == "rhel" ]] && pkg_name="$dnf_pkg"
        [[ "$pkg_name" != "-" && "$pkg_name" != "@"* ]] && result="$result $pkg_name"
    done
    echo "$result"
}

# Install individual package by name
install_package() {
    local pkg_name="$1"
    local found=false
    local pkg_to_install=""
    
    # Search through all package arrays
    for pkg in "${PACKAGES_CORE[@]}" "${PACKAGES_ARCHIVE[@]}" "${PACKAGES_NET[@]}" "${PACKAGES_DEV[@]}" "${PACKAGES_MODERN[@]}" "${PACKAGES_CLIPBOARD[@]}"; do
        IFS=':' read -r name apt_pkg dnf_pkg desc notes <<< "$pkg"
        if [[ "$name" == "$pkg_name" ]] || [[ "$apt_pkg" == "$pkg_name" ]] || [[ "$dnf_pkg" == "$pkg_name" ]]; then
            found=true
            if [[ "$DISTRO_TYPE" == "rhel" ]]; then
                pkg_to_install="$dnf_pkg"
            else
                pkg_to_install="$apt_pkg"
            fi
            
            # Handle special cases
            if [[ "$pkg_to_install" == "@"* ]]; then
                # Group install (e.g., @development-tools)
                local group_name="${pkg_to_install#@}"
                case "$PKG_MANAGER" in
                    dnf)
                        echo "[*] Installing group: $group_name"
                        sudo dnf groupinstall -y "$group_name" 2>/dev/null || true
                        ;;
                    yum)
                        sudo yum groupinstall -y "$group_name" 2>/dev/null || true
                        ;;
                    *)
                        echo "[!] Group install not supported for $PKG_MANAGER"
                        return 1
                        ;;
                esac
                return 0
            elif [[ "$pkg_to_install" == "-" ]]; then
                echo "[!] Package $pkg_name not available for this distribution"
                return 1
            fi
            
            break
        fi
    done
    
    if [[ "$found" == false ]]; then
        echo "[!] Package '$pkg_name' not found in package list"
        return 1
    fi
    
    if [[ -z "$pkg_to_install" ]]; then
        echo "[!] Package '$pkg_name' not available for this distribution"
        return 1
    fi
    
    # Install the package
    echo "[*] Installing $pkg_to_install..."
    case "$PKG_MANAGER" in
        apt)
            sudo apt update 2>/dev/null || true
            sudo apt install -y "$pkg_to_install" 2>/dev/null || {
                echo "[!] Failed to install $pkg_to_install"
                return 1
            }
            ;;
        dnf)
            sudo dnf install -y "$pkg_to_install" 2>/dev/null || {
                echo "[!] Failed to install $pkg_to_install"
                return 1
            }
            ;;
        yum)
            sudo yum install -y "$pkg_to_install" 2>/dev/null || {
                echo "[!] Failed to install $pkg_to_install"
                return 1
            }
            ;;
        *)
            echo "[!] Unknown package manager"
            return 1
            ;;
    esac
    
    echo "[+] Successfully installed $pkg_to_install"
    return 0
}

# Interactive package installer
install_packages_interactive() {
    detect_distro
    
    echo -e "\n${CYAN}${BOLD}=== Interactive Package Installation ===${NC}\n"
    
    # Build list of all packages with numbers
    local all_packages=()
    local index=1
    
    echo -e "${BOLD}Available packages:${NC}\n"
    
    # Core packages
    echo -e "${YELLOW}Core Packages:${NC}"
    for pkg in "${PACKAGES_CORE[@]}"; do
        IFS=':' read -r name apt_pkg dnf_pkg desc notes <<< "$pkg"
        local pkg_name="$apt_pkg"
        [[ "$DISTRO_TYPE" == "rhel" ]] && pkg_name="$dnf_pkg"
        local status
        if [[ "$pkg_name" != "-" ]] && [[ "$pkg_name" != "@"* ]]; then
            command -v "$name" &>/dev/null && status="${GREEN}✓${NC}" || status="${YELLOW}○${NC}"
            printf "  %2d) %b %-20s - %s\n" "$index" "$status" "$name" "$desc"
            all_packages+=("$name")
            index=$((index + 1))
        fi
    done
    
    # Archive packages
    echo -e "\n${YELLOW}Archive Tools:${NC}"
    for pkg in "${PACKAGES_ARCHIVE[@]}"; do
        IFS=':' read -r name apt_pkg dnf_pkg desc notes <<< "$pkg"
        local pkg_name="$apt_pkg"
        [[ "$DISTRO_TYPE" == "rhel" ]] && pkg_name="$dnf_pkg"
        local status
        if [[ "$pkg_name" != "-" ]] && [[ "$pkg_name" != "@"* ]]; then
            command -v "$name" &>/dev/null && status="${GREEN}✓${NC}" || status="${YELLOW}○${NC}"
            printf "  %2d) %b %-20s - %s\n" "$index" "$status" "$name" "$desc"
            all_packages+=("$name")
            index=$((index + 1))
        fi
    done
    
    # Network packages
    echo -e "\n${YELLOW}Network Tools:${NC}"
    for pkg in "${PACKAGES_NET[@]}"; do
        IFS=':' read -r name apt_pkg dnf_pkg desc notes <<< "$pkg"
        local pkg_name="$apt_pkg"
        [[ "$DISTRO_TYPE" == "rhel" ]] && pkg_name="$dnf_pkg"
        local status
        if [[ "$pkg_name" != "-" ]] && [[ "$pkg_name" != "@"* ]]; then
            command -v "$name" &>/dev/null && status="${GREEN}✓${NC}" || status="${YELLOW}○${NC}"
            printf "  %2d) %b %-20s - %s\n" "$index" "$status" "$name" "$desc"
            all_packages+=("$name")
            index=$((index + 1))
        fi
    done
    
    # Dev packages
    echo -e "\n${YELLOW}Dev Tools:${NC}"
    for pkg in "${PACKAGES_DEV[@]}"; do
        IFS=':' read -r name apt_pkg dnf_pkg desc notes <<< "$pkg"
        local pkg_name="$apt_pkg"
        [[ "$DISTRO_TYPE" == "rhel" ]] && pkg_name="$dnf_pkg"
        local status
        if [[ "$pkg_name" != "-" ]] && [[ "$pkg_name" != "@"* ]]; then
            command -v "$name" &>/dev/null && status="${GREEN}✓${NC}" || status="${YELLOW}○${NC}"
            printf "  %2d) %b %-20s - %s\n" "$index" "$status" "$name" "$desc"
            all_packages+=("$name")
            index=$((index + 1))
        fi
    done
    
    # Modern CLI packages
    echo -e "\n${YELLOW}Modern CLI:${NC}"
    for pkg in "${PACKAGES_MODERN[@]}"; do
        IFS=':' read -r name apt_pkg dnf_pkg desc notes <<< "$pkg"
        local pkg_name="$apt_pkg"
        [[ "$DISTRO_TYPE" == "rhel" ]] && pkg_name="$dnf_pkg"
        local status
        if [[ "$pkg_name" != "-" ]] && [[ "$pkg_name" != "@"* ]]; then
            command -v "$name" &>/dev/null && status="${GREEN}✓${NC}" || status="${YELLOW}○${NC}"
            printf "  %2d) %b %-20s - %s\n" "$index" "$status" "$name" "$desc"
            all_packages+=("$name")
            index=$((index + 1))
        fi
    done
    
    echo ""
    echo -e "${BOLD}Enter package numbers to install (space-separated, e.g., '1 3 5' or 'all' for all):${NC}"
    echo -n "> "
    read -r selection
    
    if [[ "$selection" == "all" ]] || [[ "$selection" == "ALL" ]]; then
        echo ""
        echo "[*] Installing all packages..."
        for pkg_name in "${all_packages[@]}"; do
            install_package "$pkg_name" || true
        done
    else
        # Parse numbers
        for num in $selection; do
            if [[ "$num" =~ ^[0-9]+$ ]] && [[ "$num" -ge 1 ]] && [[ "$num" -le ${#all_packages[@]} ]]; then
                local pkg_name="${all_packages[$((num - 1))]}"
                install_package "$pkg_name"
            else
                echo "[!] Invalid selection: $num"
            fi
        done
    fi
    
    echo ""
    echo "[+] Package installation complete!"
}

# Install dependencies
install_dependencies() {
    echo -e "\n${CYAN}${BOLD}=== Installing Dependencies ===${NC}\n"

    # Build package lists
    local core_pkgs=$(_build_pkg_list "${PACKAGES_CORE[@]}")
    local archive_pkgs=$(_build_pkg_list "${PACKAGES_ARCHIVE[@]}")
    local net_pkgs=$(_build_pkg_list "${PACKAGES_NET[@]}")
    local dev_pkgs=$(_build_pkg_list "${PACKAGES_DEV[@]}")
    
    local all_pkgs="$core_pkgs $archive_pkgs $net_pkgs $dev_pkgs"

    # Add clipboard based on display
    if [[ -n "$WAYLAND_DISPLAY" ]]; then
        all_pkgs="$all_pkgs wl-clipboard"
    elif [[ -n "$DISPLAY" ]]; then
        all_pkgs="$all_pkgs xclip"
    fi

    case "$PKG_MANAGER" in
        apt)
            echo -e "${GREEN}[+]${NC} Updating package lists..."
            sudo apt update
            
            echo -e "${GREEN}[+]${NC} Installing core packages..."
            sudo apt install -y $all_pkgs 2>/dev/null || true
            
            # Modern CLI tools
            echo -e "${GREEN}[+]${NC} Installing modern CLI tools..."
            sudo apt install -y bat fd-find ripgrep fzf 2>/dev/null || true
            
            # eza for Ubuntu
            if ! command -v eza &>/dev/null; then
                echo -e "${GREEN}[+]${NC} Installing eza..."
                sudo apt install -y gpg 2>/dev/null || true
                sudo mkdir -p /etc/apt/keyrings
                wget -qO- https://raw.githubusercontent.com/eza-community/eza/main/deb.asc 2>/dev/null | sudo gpg --dearmor -o /etc/apt/keyrings/gierens.gpg 2>/dev/null || true
                if [[ -f /etc/apt/keyrings/gierens.gpg ]]; then
                    echo "deb [signed-by=/etc/apt/keyrings/gierens.gpg] http://deb.gierens.de stable main" | sudo tee /etc/apt/sources.list.d/gierens.list >/dev/null
                    sudo chmod 644 /etc/apt/keyrings/gierens.gpg /etc/apt/sources.list.d/gierens.list 2>/dev/null
                    sudo apt update && sudo apt install -y eza 2>/dev/null || true
                fi
            fi
            ;;
        dnf)
            # Replace package names for RHEL
            all_pkgs="${all_pkgs//vim /vim-enhanced }"
            all_pkgs="${all_pkgs//dnsutils/bind-utils}"
            all_pkgs="${all_pkgs//netcat-openbsd/nmap-ncat}"
            all_pkgs="${all_pkgs//openssh-client/openssh-clients}"
            all_pkgs="${all_pkgs//xz-utils/xz}"
            all_pkgs="${all_pkgs//p7zip-full/p7zip-plugins}"
            
            echo -e "${GREEN}[+]${NC} Installing packages..."
            sudo dnf install -y $all_pkgs 2>/dev/null || true
            
            # Development tools group
            echo -e "${GREEN}[+]${NC} Installing Development Tools..."
            sudo dnf groupinstall -y "Development Tools" 2>/dev/null || true
            
            # EPEL for modern tools
            echo -e "${GREEN}[+]${NC} Enabling EPEL..."
            sudo dnf install -y epel-release 2>/dev/null || true
            
            echo -e "${GREEN}[+]${NC} Installing modern CLI tools..."
            sudo dnf install -y bat fd-find ripgrep fzf 2>/dev/null || true
            
            [[ "$DISTRO_ID" == "fedora" ]] && sudo dnf install -y eza 2>/dev/null || true
            ;;
        yum)
            all_pkgs="${all_pkgs//vim /vim-enhanced }"
            echo -e "${GREEN}[+]${NC} Installing packages..."
            sudo yum install -y $all_pkgs 2>/dev/null || true
            sudo yum install -y epel-release 2>/dev/null || true
            ;;
        *)
            echo -e "${YELLOW}[*]${NC} Unknown package manager. Install manually:"
            show_packages
            return 1
            ;;
    esac

    echo -e "${GREEN}[+]${NC} Dependencies installed!"
    
    # Show what was installed
    echo ""
    echo -e "${CYAN}Installed packages:${NC}"
    echo "  Core: $core_pkgs"
    echo "  Archive: $archive_pkgs"
    echo "  Network: $net_pkgs"
    echo "  Dev: $dev_pkgs"
    if [[ -n "$WAYLAND_DISPLAY" ]] || [[ -n "$DISPLAY" ]]; then
        echo "  Clipboard: $([ -n "$WAYLAND_DISPLAY" ] && echo "wl-clipboard" || echo "xclip")"
    fi
}

# Install Docker CE and Compose v2
install_docker() {
    echo -e "\n${CYAN}${BOLD}=== Installing Docker CE and Compose v2 ===${NC}\n"
    
    # Check if Docker is already installed
    if command -v docker &>/dev/null; then
        local docker_version
        docker_version=$(docker --version 2>/dev/null)
        echo -e "${GREEN}[+]${NC} Docker already installed: $docker_version"
        
        # Check if user is in docker group
        if ! groups 2>/dev/null | grep -qw docker; then
            echo -e "${YELLOW}[*]${NC} Adding user to docker group..."
            sudo usermod -aG docker "$USER"
            echo -e "${GREEN}[+]${NC} User added to docker group (log out/in for changes)"
        fi
        
        # Test Docker
        echo -e "${GREEN}[+]${NC} Testing Docker installation..."
        if sudo docker run --rm hello-world &>/dev/null; then
            echo -e "${GREEN}✓${NC} ${BOLD}Docker is working correctly!${NC}"
        else
            echo -e "${YELLOW}[!]${NC} Docker installed but hello-world test failed"
        fi
        return 0
    fi
    
    case "$PKG_MANAGER" in
        apt)
            echo -e "${GREEN}[+]${NC} Installing Docker CE for Ubuntu/Debian..."
            
            # Remove old versions
            sudo apt remove -y docker docker-engine docker.io containerd runc 2>/dev/null || true
            
            # Install prerequisites
            sudo apt update
            sudo apt install -y ca-certificates curl gnupg lsb-release
            
            # Add Docker's official GPG key
            sudo install -m 0755 -d /etc/apt/keyrings
            curl -fsSL https://download.docker.com/linux/${DISTRO_ID}/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
            sudo chmod a+r /etc/apt/keyrings/docker.gpg
            
            # Set up repository
            echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/${DISTRO_ID} $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
            
            # Install Docker
            sudo apt update
            sudo apt install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
            
            ;;
        dnf)
            echo -e "${GREEN}[+]${NC} Installing Docker CE for RHEL/Fedora..."
            
            # Remove old versions
            sudo dnf remove -y docker docker-client docker-client-latest docker-common docker-latest docker-latest-logrotate docker-logrotate docker-engine 2>/dev/null || true
            
            # Install prerequisites
            sudo dnf install -y dnf-plugins-core
            
            # Add Docker repository
            if [[ "$DISTRO_ID" == "fedora" ]]; then
                sudo dnf config-manager --add-repo https://download.docker.com/linux/fedora/docker-ce.repo
            else
                sudo dnf config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo
            fi
            
            # Install Docker
            sudo dnf install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
            
            ;;
        yum)
            echo -e "${GREEN}[+]${NC} Installing Docker CE for RHEL/CentOS (yum)..."
            
            # Install prerequisites
            sudo yum install -y yum-utils
            
            # Add Docker repository
            sudo yum-config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo
            
            # Install Docker
            sudo yum install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
            
            ;;
        *)
            echo -e "${YELLOW}[!]${NC} Unknown package manager. Install Docker manually:"
            echo "  https://docs.docker.com/engine/install/"
            return 1
            ;;
    esac
    
    # Start and enable Docker
    echo -e "${GREEN}[+]${NC} Starting Docker service..."
    sudo systemctl enable docker
    sudo systemctl start docker
    
    # Add user to docker group
    echo -e "${GREEN}[+]${NC} Adding user to docker group..."
    sudo usermod -aG docker "$USER"
    
    # Test Docker installation
    echo -e "${GREEN}[+]${NC} Testing Docker installation..."
    sleep 2  # Brief pause for service to be ready
    
    if sudo docker run --rm hello-world &>/dev/null; then
        echo ""
        echo -e "${GREEN}╔══════════════════════════════════════════════════════╗${NC}"
        echo -e "${GREEN}║  ${BOLD}✓ Docker CE and Compose v2 Installed Successfully!${NC}  ${GREEN}║${NC}"
        echo -e "${GREEN}╚══════════════════════════════════════════════════════╝${NC}"
        echo ""
        echo -e "${BLUE}Docker version:${NC} $(sudo docker --version)"
        echo -e "${BLUE}Compose version:${NC} $(sudo docker compose version 2>/dev/null || echo 'N/A')"
        echo ""
        echo -e "${YELLOW}Note:${NC} You've been added to the docker group."
        echo -e "${YELLOW}      ${NC} Log out and back in, or run: newgrp docker"
        echo -e "${YELLOW}      ${NC} Then you can use docker without sudo!"
        echo ""
    else
        echo -e "${RED}[!]${NC} Docker installed but hello-world test failed"
        echo -e "${YELLOW}[*]${NC} Try: sudo systemctl restart docker"
        return 1
    fi
}

# Set zsh as default shell
set_zsh_default() {
    echo -e "\n${CYAN}=== Setting ZSH as Default Shell ===${NC}\n"

    if [[ "$SHELL" == *"zsh"* ]]; then
        echo -e "${GREEN}[+]${NC} ZSH is already your default shell"
        return 0
    fi

    local zsh_path
    zsh_path=$(command -v zsh)

    if [[ -z "$zsh_path" ]]; then
        echo -e "${RED}[!]${NC} ZSH not found. Please install it first."
        return 1
    fi

    # Ensure zsh is in /etc/shells
    if ! grep -q "$zsh_path" /etc/shells 2>/dev/null; then
        echo -e "${GREEN}[+]${NC} Adding $zsh_path to /etc/shells"
        echo "$zsh_path" | sudo tee -a /etc/shells >/dev/null
    fi

    echo -e "${GREEN}[+]${NC} Changing default shell to ZSH..."
    if chsh -s "$zsh_path"; then
        echo -e "${GREEN}[+]${NC} Default shell changed to ZSH"
        echo -e "${YELLOW}[*]${NC} Log out and back in for the change to take effect"
    else
        echo -e "${YELLOW}[*]${NC} Could not change shell automatically. Run: chsh -s $zsh_path"
    fi
}

# Install SWEET-Scripts files
install_scripts() {
    echo -e "\n${CYAN}=== Installing SWEET-Scripts ===${NC}\n"

    # Detect install method
    if [[ -d ".git" && -f "sweets.sh" ]]; then
        SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
        INSTALL_METHOD="local"
        echo -e "${GREEN}[+]${NC} Installing from local repo: $SCRIPT_DIR"
    elif [[ -n "$1" && -d "$1" ]]; then
        SCRIPT_DIR="$1"
        INSTALL_METHOD="local"
        echo -e "${GREEN}[+]${NC} Installing from: $SCRIPT_DIR"
    else
        INSTALL_METHOD="git"
        echo -e "${GREEN}[+]${NC} Installing from GitHub..."
        
        if [[ -d "$INSTALL_DIR" ]]; then
            echo -e "${YELLOW}[*]${NC} Existing installation found, updating..."
            cd "$INSTALL_DIR"
            git pull --quiet
        else
            git clone --quiet "$REPO_URL" "$INSTALL_DIR"
            cd "$INSTALL_DIR"
        fi
        SCRIPT_DIR="$INSTALL_DIR"
    fi

    # Verify sweets.sh exists
    if [[ ! -f "$SCRIPT_DIR/sweets.sh" ]]; then
        echo -e "${RED}[!]${NC} Error: sweets.sh not found in $SCRIPT_DIR"
        exit 1
    fi

    # Create install directory if using local method
    if [[ "$INSTALL_METHOD" == "local" && "$SCRIPT_DIR" != "$INSTALL_DIR" ]]; then
        mkdir -p "$INSTALL_DIR"
        cp "$SCRIPT_DIR/sweets.sh" "$INSTALL_DIR/"
        [[ -f "$SCRIPT_DIR/install.sh" ]] && cp "$SCRIPT_DIR/install.sh" "$INSTALL_DIR/"
        [[ -f "$SCRIPT_DIR/uninstall.sh" ]] && cp "$SCRIPT_DIR/uninstall.sh" "$INSTALL_DIR/"
        echo -e "${GREEN}[+]${NC} Copied files to $INSTALL_DIR"
    fi

    # Initialize git repo if installed locally without git
    if [[ "$INSTALL_METHOD" == "local" && ! -d "$INSTALL_DIR/.git" ]]; then
        echo -e "${YELLOW}[*]${NC} Initializing git repo for updates..."
        cd "$INSTALL_DIR"
        git init --quiet
        git remote add origin "$REPO_URL" 2>/dev/null || git remote set-url origin "$REPO_URL"
        echo -e "${GREEN}[+]${NC} Git repo initialized"
    fi
}

# Configure shell RC files
configure_shells() {
    echo -e "\n${CYAN}=== Configuring Shell Integration ===${NC}\n"

    # Function to install to rc file
    install_to_rc() {
        local rc_file="$1"
        local shell_name="$2"
        
        if [[ ! -f "$rc_file" ]]; then
            echo -e "${YELLOW}[*]${NC} Creating $rc_file"
            touch "$rc_file"
        fi
        
        if grep -q "$MARKER" "$rc_file" 2>/dev/null; then
            echo -e "${YELLOW}[*]${NC} Updating existing config in $rc_file"
            # Use a temp file for portability
            local tmpfile=$(mktemp)
            sed "/$MARKER/,/$END_MARKER/d" "$rc_file" > "$tmpfile"
            mv "$tmpfile" "$rc_file"
        fi
        
        # Append source block using cat with heredoc to avoid quoting issues
        # Use a heredoc with quoted delimiter to prevent variable expansion issues
        cat >> "$rc_file" << EOF

$MARKER
# SWEET-Scripts - Shell Wrappers for Efficient Elevated Terminal Sessions
# https://github.com/sweets9/SWEET-Scripts
export SWEETS_DIR="$INSTALL_DIR"
if [[ -f "\$SWEETS_DIR/sweets.sh" ]]; then
    source "\$SWEETS_DIR/sweets.sh"
fi
$END_MARKER
EOF
        
        echo -e "${GREEN}[+]${NC} Installed to $rc_file ($shell_name)"
    }

    # Install to zsh (primary)
    install_to_rc "$HOME/.zshrc" "zsh"

    # Install to bash (for compatibility)
    if [[ -f "$HOME/.bashrc" ]]; then
        install_to_rc "$HOME/.bashrc" "bash"
    fi
}

# Setup vim and tmux configs
setup_enhancements() {
    echo -e "\n${CYAN}=== Setting Up Enhancements ===${NC}\n"

    # Vim clipboard setup
    local vimrc="$HOME/.vimrc"
    local vim_marker="\" SWEET-Scripts clipboard"
    
    if ! grep -q "$vim_marker" "$vimrc" 2>/dev/null; then
        cat >> "$vimrc" << 'VIMCLIP'

" SWEET-Scripts clipboard integration - START
if has('clipboard')
    set clipboard=unnamedplus,unnamed
endif
vnoremap <leader>y "+y
nnoremap <leader>y "+y
nnoremap <leader>p "+p
vnoremap <leader>p "+p
nnoremap <leader>ca gg"+yG
" SWEET-Scripts clipboard integration - END
VIMCLIP
        echo -e "${GREEN}[+]${NC} Vim clipboard config added"
    else
        echo -e "${YELLOW}[*]${NC} Vim config already present"
    fi

    # Tmux setup
    local tmuxconf="$HOME/.tmux.conf"
    local tmux_marker="# SWEET-Scripts tmux"
    
    if ! grep -q "$tmux_marker" "$tmuxconf" 2>/dev/null; then
        cat >> "$tmuxconf" << 'TMUXCONF'

# SWEET-Scripts tmux configuration - START
set -g mouse on
setw -g mode-keys vi
set -g history-limit 50000
set -g default-terminal "screen-256color"

# Easy scrolling: Prefix+k (up), Prefix+j (copy mode)
bind k copy-mode -u
bind j copy-mode
bind C-u copy-mode \; send-keys -X halfpage-up
bind C-d copy-mode \; send-keys -X halfpage-down

# Copy to system clipboard
bind -T copy-mode-vi y send-keys -X copy-pipe-and-cancel "xclip -selection clipboard 2>/dev/null || wl-copy 2>/dev/null || pbcopy 2>/dev/null"
bind -T copy-mode-vi Enter send-keys -X copy-pipe-and-cancel "xclip -selection clipboard 2>/dev/null || wl-copy 2>/dev/null || pbcopy 2>/dev/null"
# SWEET-Scripts tmux configuration - END
TMUXCONF
        echo -e "${GREEN}[+]${NC} Tmux scroll config added"
    else
        echo -e "${YELLOW}[*]${NC} Tmux config already present"
    fi
}

# Main installation
main() {
    show_banner

    # Parse arguments first
    SKIP_DEPS=false
    SKIP_ZSH_DEFAULT=false
    SKIP_DOCKER=false
    INSTALL_DOCKER=false
    SHOW_PACKAGES_ONLY=false
    NON_INTERACTIVE=false
    
    for arg in "$@"; do
        case $arg in
            --skip-deps) SKIP_DEPS=true ;;
            --skip-zsh) SKIP_ZSH_DEFAULT=true ;;
            --skip-docker) SKIP_DOCKER=true ;;
            --install-docker) INSTALL_DOCKER=true ;;
            --non-interactive) NON_INTERACTIVE=true ;;
            --show-packages|--packages)
                detect_distro
                show_packages
                exit 0
                ;;
            --install-packages|--install-pkg)
                detect_distro
                install_packages_interactive
                exit 0
                ;;
            --help|-h)
                echo "Usage: ./install.sh [options]"
                echo "  --skip-deps        Skip installing dependencies"
                echo "  --skip-zsh         Skip setting ZSH as default shell"
                echo "  --skip-docker      Skip Docker installation prompt"
                echo "  --install-docker   Automatically install Docker (non-interactive)"
                echo "  --non-interactive  Skip all prompts (use defaults)"
                echo "  --show-packages    Show package list and exit"
                exit 0
                ;;
        esac
    done

    detect_distro

    # Interactive prompts (unless non-interactive or flags set)
    INSTALL_DEPS=true
    INSTALL_DOCKER_CHOICE=false
    SET_ZSH_DEFAULT=true
    
    # Check if we can read from stdin (interactive terminal)
    local is_interactive=false
    if [[ -t 0 ]] && [[ -t 1 ]] && [[ -t 2 ]]; then
        is_interactive=true
    fi
    
    if [[ "$NON_INTERACTIVE" == false ]] && [[ "$is_interactive" == true ]]; then
        echo -e "${CYAN}${BOLD}=== Installation Configuration ===${NC}"
        echo ""
        
        # Check if dependencies should be installed
        if [[ "$SKIP_DEPS" == false ]]; then
            echo -e "${YELLOW}1. Install dependencies?${NC}"
            echo "   Packages: git, zsh, tmux, vim, tree, jq, htop, btop, and more"
            echo -n "   Install dependencies? (Y/n): "
            set +e
            read -r deps_choice
            set -e
            if [[ "$deps_choice" =~ ^[Nn]$ ]]; then
                INSTALL_DEPS=false
            fi
            echo ""
        else
            INSTALL_DEPS=false
        fi
        
        # Check if Docker should be installed
        if [[ "$SKIP_DOCKER" == false ]] && [[ "$INSTALL_DEPS" == true ]]; then
            echo -e "${YELLOW}2. Install Docker CE and Compose v2?${NC}"
            echo "   Docker Engine, CLI, and Compose plugin"
            echo -n "   Install Docker? (Y/n): "
            set +e
            read -r docker_choice
            set -e
            if [[ ! "$docker_choice" =~ ^[Nn]$ ]]; then
                INSTALL_DOCKER_CHOICE=true
            fi
            echo ""
        elif [[ "$INSTALL_DOCKER" == true ]]; then
            INSTALL_DOCKER_CHOICE=true
        fi
        
        # Check if ZSH should be set as default
        if [[ "$SKIP_ZSH_DEFAULT" == false ]]; then
            echo -e "${YELLOW}3. Set ZSH as default shell?${NC}"
            echo "   Changes default shell to zsh (recommended)"
            echo -n "   Set ZSH as default? (Y/n): "
            set +e
            read -r zsh_choice
            set -e
            if [[ "$zsh_choice" =~ ^[Nn]$ ]]; then
                SET_ZSH_DEFAULT=false
            fi
            echo ""
        else
            SET_ZSH_DEFAULT=false
        fi
        
        # Always install SWEET-Scripts and configure
        echo -e "${YELLOW}4. Install SWEET-Scripts and configure shell?${NC}"
        echo "   Installs scripts, configures .bashrc/.zshrc, sets up enhancements"
        echo -e "   ${GREEN}✓${NC} This will always be installed"
        echo ""
        
        # Show summary
        echo -e "${CYAN}${BOLD}=== Installation Summary ===${NC}"
        echo ""
        if [[ "$INSTALL_DEPS" == true ]]; then
            echo -e "  ${GREEN}✓${NC} Install dependencies (git, zsh, tmux, vim, etc.)"
        else
            echo -e "  ${YELLOW}○${NC} Skip dependencies installation"
        fi
        
        if [[ "$INSTALL_DOCKER_CHOICE" == true ]]; then
            echo -e "  ${GREEN}✓${NC} Install Docker CE and Compose v2"
        else
            echo -e "  ${YELLOW}○${NC} Skip Docker installation"
        fi
        
        if [[ "$SET_ZSH_DEFAULT" == true ]]; then
            echo -e "  ${GREEN}✓${NC} Set ZSH as default shell"
        else
            echo -e "  ${YELLOW}○${NC} Keep current default shell"
        fi
        
        echo -e "  ${GREEN}✓${NC} Install SWEET-Scripts"
        echo -e "  ${GREEN}✓${NC} Configure shell integration"
        echo -e "  ${GREEN}✓${NC} Setup clipboard and tmux enhancements"
        echo ""
        
        # Final confirmation
        echo -e "${CYAN}Proceed with installation?${NC} (Y/n): "
        set +e
        read -r final_confirm
        set -e
        if [[ "$final_confirm" =~ ^[Nn]$ ]]; then
            echo -e "${YELLOW}Installation cancelled.${NC}"
            exit 0
        fi
        echo ""
    elif [[ "$NON_INTERACTIVE" == true ]]; then
        # Non-interactive mode - use defaults
        INSTALL_DEPS=true
        INSTALL_DOCKER_CHOICE=true
        SET_ZSH_DEFAULT=true
        echo -e "${CYAN}Non-interactive mode: Using defaults (install everything)${NC}"
        echo ""
    else
        # Non-interactive terminal or flags set - show what will happen
        echo -e "${CYAN}${BOLD}=== Installation Configuration ===${NC}"
        echo ""
        echo -e "${YELLOW}Running in non-interactive mode (terminal not detected or flags set)${NC}"
        echo ""
        
        if [[ "$SKIP_DEPS" == false ]]; then
            INSTALL_DEPS=true
            echo -e "  ${GREEN}✓${NC} Will install dependencies"
        else
            INSTALL_DEPS=false
            echo -e "  ${YELLOW}○${NC} Skipping dependencies (--skip-deps flag)"
        fi
        
        if [[ "$INSTALL_DOCKER" == true ]]; then
            INSTALL_DOCKER_CHOICE=true
            echo -e "  ${GREEN}✓${NC} Will install Docker (--install-docker flag)"
        elif [[ "$SKIP_DOCKER" == true ]]; then
            INSTALL_DOCKER_CHOICE=false
            echo -e "  ${YELLOW}○${NC} Skipping Docker (--skip-docker flag)"
        elif [[ "$INSTALL_DEPS" == true ]]; then
            INSTALL_DOCKER_CHOICE=false
            echo -e "  ${YELLOW}○${NC} Skipping Docker (default in non-interactive)"
        fi
        
        if [[ "$SKIP_ZSH_DEFAULT" == false ]]; then
            SET_ZSH_DEFAULT=true
            echo -e "  ${GREEN}✓${NC} Will set ZSH as default"
        else
            SET_ZSH_DEFAULT=false
            echo -e "  ${YELLOW}○${NC} Skipping ZSH default (--skip-zsh flag)"
        fi
        
        echo -e "  ${GREEN}✓${NC} Will install SWEET-Scripts"
        echo -e "  ${GREEN}✓${NC} Will configure shell integration"
        echo -e "  ${GREEN}✓${NC} Will setup clipboard and tmux enhancements"
        echo ""
        echo -e "${CYAN}Proceeding with installation...${NC}"
        echo ""
    fi

    # Execute installation
    echo -e "${GREEN}${BOLD}Starting installation...${NC}"
    echo ""
    
    if [[ "$INSTALL_DEPS" == true ]]; then
        install_dependencies
        
        if [[ "$INSTALL_DOCKER_CHOICE" == true ]]; then
            echo ""
            echo -e "${CYAN}=== Installing Docker ===${NC}"
            install_docker
        fi
    fi

    if [[ "$SET_ZSH_DEFAULT" == true ]]; then
        set_zsh_default
    fi

    install_scripts
    configure_shells
    setup_enhancements

    echo ""
    echo -e "${GREEN}╔══════════════════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}║       🍬 SWEET-Scripts Installation Complete!        ║${NC}"
    echo -e "${GREEN}╚══════════════════════════════════════════════════════╝${NC}"
    echo ""
    echo -e "${BLUE}Installed to:${NC} $INSTALL_DIR"
    echo ""
    
    # Detect current shell and source appropriate rc file
    local current_shell="${SHELL##*/}"
    local rc_file=""
    if [[ "$current_shell" == "zsh" ]] || [[ -n "$ZSH_VERSION" ]]; then
        rc_file="$HOME/.zshrc"
    elif [[ "$current_shell" == "bash" ]] || [[ -n "$BASH_VERSION" ]]; then
        rc_file="$HOME/.bashrc"
    fi
    
    if [[ -n "$rc_file" ]] && [[ -f "$rc_file" ]] && grep -q "$MARKER" "$rc_file" 2>/dev/null; then
        echo -e "${YELLOW}Activating SWEET-Scripts in current shell...${NC}"
        # Source the rc file to activate (suppress errors)
        set +e
        source "$rc_file" 2>/dev/null || true
        set -e
        echo -e "${GREEN}✓${NC} SWEET-Scripts activated!"
        echo ""
        echo "Quick commands:"
        echo "  sweets           Interactive menu (recommended!)"
        echo "  sweets-help      Show all available commands"
        echo "  sweets-update    Update to latest version"
        echo ""
    else
        echo -e "${YELLOW}To activate now:${NC}"
        echo ""
        if [[ -f "$HOME/.zshrc" ]]; then
            echo "  source ~/.zshrc"
        elif [[ -f "$HOME/.bashrc" ]]; then
            echo "  source ~/.bashrc"
        fi
        echo ""
        echo "Or start a new shell session"
        echo ""
    fi
    
    echo -e "${GREEN}Enjoy your sweet terminal experience! 🍬${NC}"
    echo ""
}

main "$@"
