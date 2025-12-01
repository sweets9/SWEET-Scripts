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

    # Source block to add to rc files
    SOURCE_BLOCK="$MARKER
# SWEET-Scripts - Shell Wrappers for Efficient Elevated Terminal Sessions
# https://github.com/sweets9/SWEET-Scripts
export SWEETS_DIR=\"$INSTALL_DIR\"
if [[ -f \"\$SWEETS_DIR/sweets.sh\" ]]; then
    source \"\$SWEETS_DIR/sweets.sh\"
fi
$END_MARKER"

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
        
        echo -e "\n$SOURCE_BLOCK" >> "$rc_file"
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

    echo -e "${MAGENTA}This installer will:${NC}"
    echo "  1. Install dependencies (git, zsh, tmux, vim, tree, etc.)"
    echo "  2. Set ZSH as your default shell"
    echo "  3. Install SWEET-Scripts"
    echo "  4. Configure clipboard and tmux scrolling"
    echo ""

    # Parse arguments
    SKIP_DEPS=false
    SKIP_ZSH_DEFAULT=false
    SHOW_PACKAGES_ONLY=false
    for arg in "$@"; do
        case $arg in
            --skip-deps) SKIP_DEPS=true ;;
            --skip-zsh) SKIP_ZSH_DEFAULT=true ;;
            --show-packages|--packages)
                detect_distro
                show_packages
                exit 0
                ;;
            --help|-h)
                echo "Usage: ./install.sh [options]"
                echo "  --skip-deps      Skip installing dependencies"
                echo "  --skip-zsh       Skip setting ZSH as default shell"
                echo "  --show-packages  Show package list and exit"
                exit 0
                ;;
        esac
    done

    detect_distro

    if [[ "$SKIP_DEPS" == false ]]; then
        install_dependencies
    fi

    if [[ "$SKIP_ZSH_DEFAULT" == false ]]; then
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
    echo -e "${YELLOW}To activate now:${NC}"
    echo -e "  source ~/.zshrc"
    echo ""
    echo -e "${YELLOW}Or start a new ZSH session:${NC}"
    echo -e "  zsh"
    echo ""
    echo -e "${YELLOW}Quick commands:${NC}"
    echo -e "  sweets-help      Show all available commands"
    echo -e "  sweets-update    Update to latest version"
    echo -e "  sweets-setup     Re-run vim/tmux setup"
    echo ""
    echo -e "${CYAN}Enjoy your sweet terminal experience! 🍬${NC}"
    echo ""
}

main "$@"
