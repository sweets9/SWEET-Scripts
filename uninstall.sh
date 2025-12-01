#!/bin/bash
# SWEET-Scripts Uninstaller
# https://github.com/sweets9/SWEET-Scripts

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

INSTALL_DIR="${SWEETS_DIR:-$HOME/.sweet-scripts}"
MARKER="# >>> SWEET-Scripts >>>"
END_MARKER="# <<< SWEET-Scripts <<<"
VIM_START="\" SWEET-Scripts clipboard integration - START"
VIM_END="\" SWEET-Scripts clipboard integration - END"
TMUX_START="# SWEET-Scripts tmux configuration - START"
TMUX_END="# SWEET-Scripts tmux configuration - END"

echo ""
echo -e "${CYAN}${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BOLD}  SWEET-Scripts Uninstaller${NC}"
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

echo -e "${YELLOW}[*]${NC} Removing SWEET-Scripts...\n"

# Remove from shell rc files
remove_from_rc() {
    local rc_file="$1"
    
    if [[ -f "$rc_file" ]] && grep -q "$MARKER" "$rc_file" 2>/dev/null; then
        echo -e "${GREEN}[+]${NC} Removing from $rc_file"
        local tmpfile=$(mktemp)
        sed "/$MARKER/,/$END_MARKER/d" "$rc_file" > "$tmpfile"
        mv "$tmpfile" "$rc_file"
    fi
}

remove_from_rc "$HOME/.zshrc"
remove_from_rc "$HOME/.bashrc"

# Remove vim config
remove_vim_config() {
    local vimrc="$HOME/.vimrc"
    if [[ -f "$vimrc" ]] && grep -q "SWEET-Scripts clipboard" "$vimrc" 2>/dev/null; then
        echo -e "${GREEN}[+]${NC} Removing vim clipboard config from $vimrc"
        local tmpfile=$(mktemp)
        sed '/SWEET-Scripts clipboard integration - START/,/SWEET-Scripts clipboard integration - END/d' "$vimrc" > "$tmpfile"
        mv "$tmpfile" "$vimrc"
    fi
}

# Remove tmux config
remove_tmux_config() {
    local tmuxconf="$HOME/.tmux.conf"
    if [[ -f "$tmuxconf" ]] && grep -q "SWEET-Scripts tmux" "$tmuxconf" 2>/dev/null; then
        echo -e "${GREEN}[+]${NC} Removing tmux config from $tmuxconf"
        local tmpfile=$(mktemp)
        sed '/SWEET-Scripts tmux configuration - START/,/SWEET-Scripts tmux configuration - END/d' "$tmuxconf" > "$tmpfile"
        mv "$tmpfile" "$tmuxconf"
    fi
}

# Ask about vim/tmux removal
echo -e "${YELLOW}[?]${NC} Remove vim clipboard configuration? (y/N) "
read -r -n 1 reply
echo
if [[ $reply =~ ^[Yy]$ ]]; then
    remove_vim_config
else
    echo -e "${YELLOW}[*]${NC} Vim config kept"
fi

echo -e "${YELLOW}[?]${NC} Remove tmux scroll configuration? (y/N) "
read -r -n 1 reply
echo
if [[ $reply =~ ^[Yy]$ ]]; then
    remove_tmux_config
else
    echo -e "${YELLOW}[*]${NC} Tmux config kept"
fi

# Remove install directory
if [[ -d "$INSTALL_DIR" ]]; then
    echo -e "${GREEN}[+]${NC} Removing $INSTALL_DIR"
    rm -rf "$INSTALL_DIR"
fi

# Optional: Remove credentials file
if [[ -f "$HOME/.sweets-credentials" ]]; then
    echo -e "${YELLOW}[?]${NC} Remove credentials file? ($HOME/.sweets-credentials) (y/N) "
    read -r -n 1 reply
    echo
    if [[ $reply =~ ^[Yy]$ ]]; then
        rm -f "$HOME/.sweets-credentials"
        echo -e "${GREEN}[+]${NC} Credentials file removed"
    else
        echo -e "${YELLOW}[*]${NC} Credentials file kept"
    fi
fi

echo ""
echo -e "${GREEN}╔══════════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║       SWEET-Scripts Uninstalled Successfully         ║${NC}"
echo -e "${GREEN}╚══════════════════════════════════════════════════════╝${NC}"
echo ""
echo -e "Restart your shell or run: ${CYAN}exec \$SHELL${NC}"
echo ""
