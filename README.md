# SWEET-Scripts

**Shell Wrappers for Efficient Elevated Terminal Sessions**

A comprehensive shell enhancement toolkit for bash and zsh that makes terminal work quick and easy.

## Quick Start

```bash
# One-liner install
curl -fsSL https://raw.githubusercontent.com/sweets9/SWEET-Scripts/main/install.sh | bash

# Or clone and install
git clone https://github.com/sweets9/SWEET-Scripts.git
cd SWEET-Scripts && ./install.sh
```

## What's Included

### Core Features
- **Smart Sudo Wrappers** - Auto-elevates commands when needed
- **Clipboard Integration** - Copy/paste from terminal (X11/Wayland/macOS)
- **Credential Management** - Secure storage for sensitive variables
- **Tailscale VPN** - Built-in setup and management
- **SSH Key Import** - Import GitHub keys to authorized_keys

### Tool Shortcuts
- **Git**: `g`, `gs`, `ga`, `gc`, `gp`, `gpl`, `gco`, `gb`, `gd`, `glog`
- **Docker**: `d`, `dc`, `dps`, `dpsa`, `di`, `dex`, `dlogs`, `dprune`
- **Kubernetes**: `k`, `kgp`, `kgs`, `kgd`, `kd`, `kl`, `kex` (if kubectl installed)
- **Python**: `py`, `venv`, `activate` + UV/Poetry shortcuts
- **Network**: `myip`, `localip`, `ports`, `listening`, `dig`, `pingg`
- **System**: `meminfo`, `cpuinfo`, `diskinfo`, `psg`, `topmem`, `topcpu`

### Interactive Menu
Run `sweets` for an interactive menu with system info, credential management, network tools, and Tailscale setup.

## Tailscale Integration

Tailscale setup is built into `sweets.sh`:

```bash
# Install and connect
sweets-tailscale install <authkey> [--dns] [--no-routes]

# Quick aliases
ts status    # Show status
ts ip        # Show Tailscale IP
ts up        # Connect
ts down      # Disconnect
```

**Defaults:** DNS disabled, routes enabled, auto-update on

Get auth key: https://login.tailscale.com/admin/settings/keys

## Essential Commands

### Clipboard
```bash
clip <text>        # Copy to clipboard
clipfile <file>    # Copy file contents
clipwd             # Copy current path
cliplast           # Copy last command
```

### Credentials
```bash
sweets-add-cred NAME [value]    # Add credential
sweets-list-creds                # List all
sweets-remove-cred NAME          # Remove
```

### Help & Update
```bash
sweets-help       # Show all commands
sweets-info       # Version info
sweets-update     # Update to latest
sweets            # Interactive menu
```

## Supported Systems

| Distribution | Package Manager | Status |
|-------------|-----------------|--------|
| Ubuntu 20.04+ | apt | ✅ |
| Debian 11+ | apt | ✅ |
| RHEL 8+ | dnf | ✅ |
| CentOS/Rocky/AlmaLinux 8+ | dnf | ✅ |
| Fedora 35+ | dnf | ✅ |

## Configuration

### Environment Variables
- `SWEETS_DIR` - Installation directory (default: `~/.sweet-scripts`)
- `SWEETS_CREDS_FILE` - Credentials file (default: `~/.sweets-credentials`)

### Customization
Add your aliases after the SWEET-Scripts block in `~/.zshrc` or `~/.bashrc`.

## Keyboard Shortcuts

Standard readline shortcuts: `Ctrl+A/E` (start/end), `Ctrl+W` (delete word), `Alt+B/F` (word nav), `Ctrl+R` (history search), `Ctrl+U/K` (delete to start/end), `Ctrl+L` (clear).

## Requirements

**Minimum:** Linux, Bash 4.0+, Git  
**Recommended:** ZSH 5.0+, tmux, vim, xclip/wl-clipboard

## Uninstall

```bash
~/.sweet-scripts/uninstall.sh
```

## License

MIT License - see [LICENSE](LICENSE)

---

Made with 🍬 for the terminal-obsessed
