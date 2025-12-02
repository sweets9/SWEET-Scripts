#!/bin/bash
# SWEET-Scripts Offline Installer - For CTF servers without internet access
# 
# Usage:
#   1. Transfer entire SWEET-Scripts directory to CTF server
#   2. Run: ./install-offline.sh
#
# This installer skips:
#   - Package manager updates (apt update / dnf update)
#   - Internet downloads (curl/wget)
#   - GitHub cloning
#   - External tool installations

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
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MARKER="# >>> SWEET-Scripts >>>"
END_MARKER="# <<< SWEET-Scripts <<<"

# Check if we're in the right directory
if [[ ! -f "$SCRIPT_DIR/sweets.sh" ]]; then
    echo -e "${RED}[!]${NC} Error: sweets.sh not found in $SCRIPT_DIR"
    echo "Make sure you're running this from the SWEET-Scripts directory"
    exit 1
fi

echo -e "${CYAN}${BOLD}"
echo "╔══════════════════════════════════════════════════════╗"
echo "║     SWEET-Scripts Offline Installation              ║"
echo "╚══════════════════════════════════════════════════════╝"
echo -e "${NC}"

echo -e "${MAGENTA}This installer will:${NC}"
echo "  1. Install SWEET-Scripts to $INSTALL_DIR"
echo "  2. Configure shell integration (bash/zsh)"
echo "  3. Setup clipboard and tmux enhancements"
echo ""
echo -e "${YELLOW}Note:${NC} This is an offline installation."
echo "  • Package installation is skipped (install manually if needed)"
echo "  • Internet-dependent features will be disabled"
echo ""

# Detect shell
if [[ -n "$ZSH_VERSION" ]]; then
    SHELL_NAME="zsh"
elif [[ -n "$BASH_VERSION" ]]; then
    SHELL_NAME="bash"
else
    SHELL_NAME="bash"
fi

echo -e "${GREEN}[+]${NC} Detected shell: $SHELL_NAME"
echo ""

# Create install directory
echo -e "${GREEN}[+]${NC} Creating installation directory..."
mkdir -p "$INSTALL_DIR"

# Copy files
echo -e "${GREEN}[+]${NC} Copying files..."
cp "$SCRIPT_DIR/sweets.sh" "$INSTALL_DIR/"
[[ -f "$SCRIPT_DIR/install.sh" ]] && cp "$SCRIPT_DIR/install.sh" "$INSTALL_DIR/"
[[ -f "$SCRIPT_DIR/uninstall.sh" ]] && cp "$SCRIPT_DIR/uninstall.sh" "$INSTALL_DIR/"
[[ -f "$SCRIPT_DIR/LICENSE" ]] && cp "$SCRIPT_DIR/LICENSE" "$INSTALL_DIR/"
[[ -f "$SCRIPT_DIR/README.md" ]] && cp "$SCRIPT_DIR/README.md" "$INSTALL_DIR/"

echo -e "${GREEN}[+]${NC} Files copied to $INSTALL_DIR"

# Source block for rc files
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
        local tmpfile=$(mktemp)
        sed "/$MARKER/,/$END_MARKER/d" "$rc_file" > "$tmpfile"
        mv "$tmpfile" "$rc_file"
    fi
    
    echo -e "\n$SOURCE_BLOCK" >> "$rc_file"
    echo -e "${GREEN}[+]${NC} Installed to $rc_file ($shell_name)"
}

# Install to zsh
echo ""
echo -e "${CYAN}=== Configuring Shell Integration ===${NC}"
install_to_rc "$HOME/.zshrc" "zsh"

# Install to bash (for compatibility)
if [[ -f "$HOME/.bashrc" ]]; then
    install_to_rc "$HOME/.bashrc" "bash"
fi

# Setup vim clipboard
echo ""
echo -e "${CYAN}=== Setting Up Enhancements ===${NC}"
vimrc="$HOME/.vimrc"
vim_marker="\" SWEET-Scripts clipboard"
if [[ ! -f "$vimrc" ]] || ! grep -q "$vim_marker" "$vimrc" 2>/dev/null; then
    {
        echo ""
        echo "$vim_marker"
        echo "if has('clipboard')"
        echo "    set clipboard=unnamedplus"
        echo "endif"
    } >> "$vimrc"
    echo -e "${GREEN}[+]${NC} Vim clipboard configured"
fi

# Setup tmux scrolling
tmuxrc="$HOME/.tmux.conf"
tmux_marker="# SWEET-Scripts tmux config"
if [[ ! -f "$tmuxrc" ]] || ! grep -q "$tmux_marker" "$tmuxrc" 2>/dev/null; then
    {
        echo ""
        echo "$tmux_marker"
        echo "set -g mouse on"
        echo "bind -n WheelUpPane if-shell -F -t = \"#{mouse_any_flag}\" \"send-keys -M\" \"if-shell -t = '\"#{pane_in_mode}\"' 'send-keys -M' 'select-pane -t =; copy-mode -e; send-keys -M'\""
        echo "bind -n WheelDownPane select-pane -t = \\; send-keys -M"
    } >> "$tmuxrc"
    echo -e "${GREEN}[+]${NC} Tmux scrolling configured"
fi

echo ""
echo -e "${GREEN}╔══════════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║       🍬 SWEET-Scripts Installation Complete!        ║${NC}"
echo -e "${GREEN}╚══════════════════════════════════════════════════════╝${NC}"
echo ""
echo -e "${CYAN}Installation directory:${NC} $INSTALL_DIR"
echo ""
echo -e "${YELLOW}Next steps:${NC}"
echo "  1. Reload your shell: source ~/.${SHELL_NAME}rc"
echo "     Or start a new terminal session"
echo "  2. Run 'sweets' to open the interactive menu"
echo "  3. Run 'sweets-help' to see all available commands"
echo ""
echo -e "${YELLOW}Note:${NC} Some features require internet access:"
echo "  • Tailscale installation (use pre-installed if available)"
echo "  • SSH key imports from GitHub (use local files instead)"
echo "  • Package installation (install manually with local repos)"
echo ""
echo -e "${GREEN}Enjoy your enhanced terminal! 🍬${NC}"

