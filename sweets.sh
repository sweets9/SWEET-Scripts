#!/usr/bin/env bash
# =============================================================================
# SWEET-Scripts - Shell Wrappers for Efficient Elevated Terminal Sessions
# =============================================================================
# Version: 2.2.2
# Repository: https://github.com/sweets9/SWEET-Scripts
# License: MIT
# 
# Supported Versions:
#   • Ubuntu 24.04 LTS (recommended)
#   • Debian 12+ (Bookworm)
#   • Fedora 40+ (recommended)
#   • RHEL 9+ / CentOS Stream 9+ / Rocky Linux 9+ / AlmaLinux 9+
#   • WSL2 (Windows Subsystem for Linux)
# 
# Features:
#   • Smart sudo wrappers for elevated commands
#   • Clipboard integration (X11/Wayland/macOS)
#   • WSL detection and X11 DISPLAY setup
#   • GPU selector (NVIDIA/Intel) for WSL
#   • Docker/Podman auto-detection and management
#   • Tailscale VPN management
#   • Systemd service management with status reporting
#   • Credential management
#   • Dev tool shortcuts (Git, Docker, K8s, Python, etc.)
#   • Multi-shell support (bash & zsh)
#   • Multi-distro support (Ubuntu/Debian & RHEL/Fedora)
# 
# =============================================================================

# Exit if not interactive
[[ $- != *i* ]] && return

# =============================================================================
# CONFIGURATION
# =============================================================================
export SWEETS_VERSION="2.2.2"
export SWEETS_DIR="${SWEETS_DIR:-$HOME/.sweet-scripts}"
export SWEETS_CREDS_FILE="${SWEETS_CREDS_FILE:-$HOME/.sweets-credentials}"

# Detect current shell
if [ -n "$ZSH_VERSION" ]; then
    SWEETS_SHELL="zsh"
elif [ -n "$BASH_VERSION" ]; then
    SWEETS_SHELL="bash"
else
    SWEETS_SHELL="sh"
fi
export SWEETS_SHELL

# Detect distro
_sweets_detect_distro() {
    if [[ -f /etc/os-release ]]; then
        . /etc/os-release
        echo "$ID"
    elif command -v lsb_release &>/dev/null; then
        lsb_release -si | tr '[:upper:]' '[:lower:]'
    else
        echo "unknown"
    fi
}
export SWEETS_DISTRO="$(_sweets_detect_distro)"

# =============================================================================
# WSL DETECTION & SETUP
# =============================================================================
# Detect WSL environment
_sweets_detect_wsl() {
    if [[ -f /proc/version ]] && grep -qi microsoft /proc/version 2>/dev/null; then
        return 0
    elif [[ -n "$WSL_DISTRO_NAME" ]] || [[ -n "$WSL_INTEROP" ]]; then
        return 0
    else
        return 1
    fi
}

# Setup WSL environment
if _sweets_detect_wsl; then
    export SWEETS_WSL=true
    
    # X11 DISPLAY setup for WSL
    if [[ -z "$DISPLAY" ]]; then
        # Try to detect Windows host IP
        local host_ip
        host_ip=$(grep -oP '(?<=nameserver\s)\d+\.\d+\.\d+\.\d+' /etc/resolv.conf 2>/dev/null | head -1)
        
        if [[ -n "$host_ip" ]]; then
            export DISPLAY="${host_ip}:0.0"
        elif [[ -n "$WSL_HOST_IP" ]]; then
            export DISPLAY="${WSL_HOST_IP}:0.0"
        else
            # Fallback to localhost (for WSL2)
            export DISPLAY=:0.0
        fi
    fi
    
    # GPU selector for WSL
    # How it works:
    # - Sets __GLX_VENDOR_LIBRARY_NAME=nvidia to use NVIDIA GPU drivers in WSL
    # - Unsets it for Intel/software rendering
    # - WSLENV ensures environment variables are passed from Windows to WSL
    # - Auto-detects by checking if nvidia-smi is available and working
    _sweets_gpu_selector() {
        local gpu_type="${1:-auto}"
        
        case "$gpu_type" in
            nvidia|NVIDIA)
                export WSLENV="${WSLENV}LIBGL_ALWAYS_SOFTWARE/u"
                export __GLX_VENDOR_LIBRARY_NAME=nvidia
                echo "[+] NVIDIA GPU selected for WSL"
                ;;
            intel|Intel|INTEL)
                export WSLENV="${WSLENV}LIBGL_ALWAYS_SOFTWARE/u"
                unset __GLX_VENDOR_LIBRARY_NAME
                echo "[+] Intel GPU selected for WSL"
                ;;
            auto|*)
                # Auto-detect: check for nvidia-smi
                if command -v nvidia-smi &>/dev/null && nvidia-smi &>/dev/null; then
                    export __GLX_VENDOR_LIBRARY_NAME=nvidia
                    echo "[+] Auto-detected: NVIDIA GPU"
                else
                    unset __GLX_VENDOR_LIBRARY_NAME
                    echo "[+] Auto-detected: Intel/Software rendering"
                fi
                ;;
        esac
    }
    
    # Auto-setup GPU on WSL detection
    _sweets_gpu_selector auto
    
    # Alias for manual GPU selection
    alias gpu-select='_sweets_gpu_selector'
else
    export SWEETS_WSL=false
fi

# =============================================================================
# CREDENTIAL MANAGEMENT
# =============================================================================
# Cross-platform stat for permissions (GNU/BSD compatible)
_sweets_get_perms() {
    local file="$1"
    if stat --version &>/dev/null 2>&1; then
        # GNU stat (Linux)
        stat -c %a "$file" 2>/dev/null
    else
        # BSD stat (macOS)
        stat -f %Lp "$file" 2>/dev/null
    fi
}

sweets-load-creds() {
    if [[ -f "$SWEETS_CREDS_FILE" ]]; then
        local perms
        perms=$(_sweets_get_perms "$SWEETS_CREDS_FILE")
        if [[ "$perms" != "600" ]]; then
            chmod 600 "$SWEETS_CREDS_FILE"
        fi
        . "$SWEETS_CREDS_FILE"
    fi
}

sweets-add-cred() {
    local name="$1"
    local value="$2"
    
    if [[ -z "$name" ]]; then
        echo "Usage: sweets-add-cred <NAME> [value]"
        return 1
    fi
    
    if [[ -z "$value" ]]; then
        echo -n "Enter value for $name: "
        read -rs value
        echo
    fi
    
    [[ ! -f "$SWEETS_CREDS_FILE" ]] && touch "$SWEETS_CREDS_FILE" && chmod 600 "$SWEETS_CREDS_FILE"
    
    if grep -q "^export $name=" "$SWEETS_CREDS_FILE" 2>/dev/null; then
        sed -i.bak "/^export $name=/d" "$SWEETS_CREDS_FILE"
        rm -f "${SWEETS_CREDS_FILE}.bak"
    fi
    
    echo "export $name=\"$value\"" >> "$SWEETS_CREDS_FILE"
    export "$name=$value"
    echo "Credential '$name' saved"
}

sweets-list-creds() {
    if [[ -f "$SWEETS_CREDS_FILE" ]]; then
        echo "Stored credentials:"
        grep "^export " "$SWEETS_CREDS_FILE" | sed 's/export \([^=]*\)=.*/  - \1/'
    else
        echo "No credentials file found"
    fi
}

sweets-remove-cred() {
    local name="$1"
    [[ -z "$name" ]] && echo "Usage: sweets-remove-cred <NAME>" && return 1
    
    if [[ -f "$SWEETS_CREDS_FILE" ]]; then
        sed -i.bak "/^export $name=/d" "$SWEETS_CREDS_FILE"
        rm -f "${SWEETS_CREDS_FILE}.bak"
        unset "$name"
        echo "Credential '$name' removed"
    fi
}

[[ -f "$SWEETS_CREDS_FILE" ]] && . "$SWEETS_CREDS_FILE" 2>/dev/null

# =============================================================================
# CLIPBOARD SUPPORT
# =============================================================================
_sweets_clipboard_cmd() {
    if [[ -n "$WAYLAND_DISPLAY" ]] && command -v wl-copy &>/dev/null; then
        echo "wl-copy"
    elif [[ -n "$DISPLAY" ]] && command -v xclip &>/dev/null; then
        echo "xclip"
    elif command -v pbcopy &>/dev/null; then
        echo "pbcopy"
    elif [[ -n "$TMUX" ]]; then
        echo "tmux"
    else
        echo "none"
    fi
}

clip() {
    local cmd content
    cmd="$(_sweets_clipboard_cmd)"
    
    if [[ -p /dev/stdin ]]; then
        content="$(cat)"
    else
        content="$*"
    fi
    
    case "$cmd" in
        wl-copy) echo -n "$content" | wl-copy ;;
        xclip) echo -n "$content" | xclip -selection clipboard ;;
        pbcopy) echo -n "$content" | pbcopy ;;
        tmux) echo -n "$content" | tmux load-buffer - && echo "Copied to tmux buffer" && return ;;
        *) echo "No clipboard tool. Install xclip or wl-copy." && return 1 ;;
    esac
    echo "Copied to clipboard"
}

clipfile() { [[ -f "$1" ]] && cat "$1" | clip || echo "File not found: $1"; }
clipwd() { pwd | clip; }
cliplast() { fc -ln -1 | sed 's/^[[:space:]]*//' | clip; }

# =============================================================================
# DIRECTORY LISTING & NAVIGATION
# =============================================================================
if command -v eza &>/dev/null; then
    alias ls='eza --icons --group-directories-first'
    alias ll='eza -la --icons --group-directories-first --git'
    alias l='eza -l --icons --group-directories-first'
    alias la='eza -la --icons --group-directories-first'
    alias lt='eza -la --icons --tree --level=2'
    alias ltree='eza --icons --tree'
elif command -v exa &>/dev/null; then
    alias ls='exa --icons --group-directories-first'
    alias ll='exa -la --icons --group-directories-first --git'
    alias l='exa -l --icons --group-directories-first'
    alias la='exa -la --icons --group-directories-first'
    alias lt='exa -la --icons --tree --level=2'
    alias ltree='exa --icons --tree'
else
    alias ls='ls --color=auto'
    alias ll='ls -lah --color=auto'
    alias l='ls -lh --color=auto'
    alias la='ls -lAh --color=auto'
fi

if command -v tree &>/dev/null; then
    alias tree='tree -C --dirsfirst'
    alias tree1='tree -C --dirsfirst -L 1'
    alias tree2='tree -C --dirsfirst -L 2'
    alias tree3='tree -C --dirsfirst -L 3'
fi

alias ..='cd ..'
alias ...='cd ../..'
alias ....='cd ../../..'
alias -- -='cd -'

# =============================================================================
# GIT SHORTCUTS (with conflict checking)
# =============================================================================
# Check for conflicts before aliasing
if ! command -v g &>/dev/null && ! type g &>/dev/null 2>&1; then
    alias g='git'
fi
# gs might conflict with ghostscript - use function to check
if ! command -v gs &>/dev/null; then
    alias gs='git status'
else
    # gs exists (ghostscript), use gitst as fallback
    alias gitst='git status'
fi

alias ga='git add'
alias gaa='git add -A'
alias gc='git commit'
alias gcm='git commit -m'
alias gp='git push'
alias gpl='git pull'
alias gco='git checkout'
alias gcb='git checkout -b'
alias gb='git branch'
alias gba='git branch -a'
alias gd='git diff'
alias gds='git diff --staged'
alias glog='git log --oneline --graph --decorate -15'
alias glogall='git log --oneline --graph --decorate --all'
alias gst='git stash'
alias gstp='git stash pop'
alias grh='git reset HEAD'
alias grhh='git reset HEAD --hard'

# GitHub CLI shortcuts (if gh installed)
if command -v gh &>/dev/null; then
    alias ghpr='gh pr create'
    alias ghprl='gh pr list'
fi

# =============================================================================
# DOCKER/PODMAN MANAGEMENT (auto-detect)
# =============================================================================
# Detect which container runtime is available
_sweets_container_runtime() {
    if command -v podman &>/dev/null && ! command -v docker &>/dev/null; then
        echo "podman"
    elif command -v docker &>/dev/null; then
        echo "docker"
    else
        echo "none"
    fi
}

SWEETS_CONTAINER_RUNTIME="$(_sweets_container_runtime)"

if [[ "$SWEETS_CONTAINER_RUNTIME" == "podman" ]]; then
    # Podman aliases
    alias d='podman'
    alias dc='podman-compose'
    alias dco='podman-compose'
    alias dps='podman ps'
    alias dpsa='podman ps -a'
    alias di='podman images'
    alias dex='podman exec -it'
    alias dlogs='podman logs -f'
    alias dprune='podman system prune -af'
    alias dstop='podman stop $(podman ps -q)'
    alias drm='podman rm $(podman ps -aq)'
    alias drmi='podman rmi $(podman images -q)'
    alias dcp='podman cp'
    alias dbuild='podman build'
    alias drun='podman run'
    alias dpull='podman pull'
    alias dpush='podman push'
    
    # Podman-specific
    alias dstart='podman start'
    alias drestart='podman restart'
    alias dtop='podman top'
    alias dstats='podman stats'
    
    export SWEETS_CONTAINER_ENGINE="podman"
elif [[ "$SWEETS_CONTAINER_RUNTIME" == "docker" ]]; then
    # Docker aliases
    alias d='docker'
    alias dc='docker compose'
    alias dco='docker-compose'
    alias dps='docker ps'
    alias dpsa='docker ps -a'
    alias di='docker images'
    alias dex='docker exec -it'
    alias dcp='docker cp'
    alias dbuild='docker build'
    alias drun='docker run'
    alias dpull='docker pull'
    alias dpush='docker push'
    alias dtop='docker top'
    alias dstats='docker stats'
    
    # Enhanced Docker functions
    dlogs() {
        if [[ -n "$1" ]]; then
            docker logs -f "$1"
        else
            echo "Usage: dlogs <container-name>"
            docker ps
        fi
    }
    
    dstart() {
        if [[ -n "$1" ]]; then
            docker start "$1"
        else
            echo "Usage: dstart <container-name>"
            docker ps -a
        fi
    }
    
    dstop() {
        if [[ -n "$1" ]]; then
            docker stop "$1"
        else
            echo "Stopping all running containers..."
            docker stop $(docker ps -q) 2>/dev/null || echo "No running containers"
        fi
    }
    
    drestart() {
        if [[ -n "$1" ]]; then
            docker restart "$1"
        else
            echo "Usage: drestart <container-name>"
            docker ps
        fi
    }
    
    dprune() {
        echo "Cleaning up Docker system..."
        docker system prune -af
        echo "Cleanup complete!"
    }
    
    dclean() {
        echo "Deep cleanup: removing all stopped containers, unused networks, images, and build cache..."
        docker system prune -af --volumes
        echo "Deep cleanup complete!"
    }
    
    # Docker backup functions
    dbackup() {
        local container="$1"
        local backup_dir="${2:-./docker-backups}"
        
        if [[ -z "$container" ]]; then
            echo "Usage: dbackup <container-name> [backup-dir]"
            echo "Available containers:"
            docker ps -a --format "table {{.Names}}\t{{.Status}}"
            return 1
        fi
        
        if ! docker ps -a --format "{{.Names}}" | grep -q "^${container}$"; then
            echo "Error: Container '$container' not found"
            return 1
        fi
        
        mkdir -p "$backup_dir"
        local timestamp=$(date +%Y%m%d-%H%M%S)
        local backup_file="${backup_dir}/${container}-${timestamp}.tar"
        
        echo "[*] Backing up container: $container"
        echo "[*] Backup location: $(pwd)/$backup_dir"
        echo "[*] Saving container..."
        docker export "$container" > "${backup_file}.container" 2>/dev/null || {
            echo "[!] Failed to export container"
            return 1
        }
        
        echo "[*] Saving volumes..."
        local volumes=$(docker inspect "$container" --format '{{range .Mounts}}{{if .Name}}{{.Name}} {{end}}{{end}}' 2>/dev/null)
        if [[ -n "$volumes" ]]; then
            for vol in $volumes; do
                docker run --rm -v "$vol:/backup-volume" -v "$(pwd)/$backup_dir:/backup" alpine tar czf "/backup/${container}-${vol}-${timestamp}.tar.gz" -C /backup-volume . 2>/dev/null
            done
        fi
        
        echo "[+] Backup complete: ${backup_file}.container"
        echo "[+] Backup directory: $(pwd)/$backup_dir"
        [[ -n "$volumes" ]] && echo "[+] Volume backups: ${container}-*-${timestamp}.tar.gz"
    }
    
    drestore() {
        local backup_file="$1"
        local container_name="$2"
        local backup_dir="${3:-./docker-backups}"
        
        if [[ -z "$backup_file" ]]; then
            echo "Usage: drestore <backup-file> [container-name] [backup-dir]"
            echo ""
            echo "Available backups in ${backup_dir}:"
            ls -lh "${backup_dir}"/*.container 2>/dev/null | awk '{print $9, "(" $5 ")"}' || echo "No backups found"
            return 1
        fi
        
        # If backup_file doesn't have path, assume it's in backup_dir
        if [[ ! "$backup_file" =~ ^/ ]] && [[ ! "$backup_file" =~ ^\./ ]]; then
            backup_file="${backup_dir}/${backup_file}"
        fi
        
        # Add .container extension if not present
        if [[ ! "$backup_file" =~ \.container$ ]]; then
            backup_file="${backup_file}.container"
        fi
        
        if [[ ! -f "$backup_file" ]]; then
            echo "Error: Backup file not found: $backup_file"
            return 1
        fi
        
        # Extract container name from backup file if not provided
        if [[ -z "$container_name" ]]; then
            container_name=$(basename "$backup_file" .container | sed 's/-[0-9]\{8\}-[0-9]\{6\}$//')
        fi
        
        echo "[*] Restoring container from: $backup_file"
        echo "[*] Container name: $container_name"
        echo ""
        echo -n "Proceed? (y/N): "
        read -r confirm
        if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
            echo "Cancelled."
            return 1
        fi
        
        echo "[*] Importing container..."
        docker import "$backup_file" "$container_name:restored" 2>/dev/null || {
            echo "[!] Failed to import container"
            return 1
        }
        
        echo "[*] Restoring volumes..."
        local volume_files=$(ls "${backup_dir}/${container_name}"-*-*.tar.gz 2>/dev/null)
        if [[ -n "$volume_files" ]]; then
            for vol_file in $volume_files; do
                local vol_name=$(basename "$vol_file" | sed "s/${container_name}-\(.*\)-.*\.tar\.gz/\1/")
                echo "[*] Restoring volume: $vol_name"
                docker volume create "$vol_name" 2>/dev/null || true
                docker run --rm -v "$vol_name:/restore" -v "$(pwd)/$backup_dir:/backup" alpine sh -c "cd /restore && tar xzf /backup/$(basename $vol_file)" 2>/dev/null
            done
        fi
        
        echo "[+] Container restored: $container_name:restored"
        echo "[+] To run: docker run -d --name $container_name $container_name:restored"
        [[ -n "$volume_files" ]] && echo "[+] Volumes restored. Use -v flags to mount them."
    }
    
    dbackup-compose() {
        local compose_file="${1:-docker-compose.yml}"
        local backup_dir="${2:-./docker-backups}"
        
        if [[ ! -f "$compose_file" ]]; then
            echo "Error: $compose_file not found"
            return 1
        fi
        
        mkdir -p "$backup_dir"
        local timestamp=$(date +%Y%m%d-%H%M%S)
        local project_name=$(basename "$(pwd)")
        
        echo "[*] Backing up docker-compose project: $project_name"
        
        # Get all services
        local services=$(docker compose -f "$compose_file" ps --services 2>/dev/null || docker-compose -f "$compose_file" ps --services 2>/dev/null)
        
        if [[ -z "$services" ]]; then
            echo "[!] No running services found"
            return 1
        fi
        
        for service in $services; do
            local container="${project_name}_${service}_1"
            if docker ps -a --format "{{.Names}}" | grep -q "$container"; then
                dbackup "$container" "$backup_dir" 2>/dev/null
            fi
        done
        
        # Backup compose file
        cp "$compose_file" "${backup_dir}/${project_name}-compose-${timestamp}.yml"
        
        echo "[+] Compose backup complete in: $backup_dir"
    }
    
    alias drm='docker rm'
    alias drmi='docker rmi'
    
    export SWEETS_CONTAINER_ENGINE="docker"
else
    # Fallback aliases (will fail gracefully if not installed)
    alias d='docker'
    alias dc='docker compose'
    alias dco='docker-compose'
    alias dps='docker ps 2>/dev/null || podman ps'
    alias dpsa='docker ps -a 2>/dev/null || podman ps -a'
    alias di='docker images 2>/dev/null || podman images'
    alias dex='docker exec -it 2>/dev/null || podman exec -it'
    alias dlogs='docker logs -f 2>/dev/null || podman logs -f'
    
    export SWEETS_CONTAINER_ENGINE="none"
fi

# =============================================================================
# KUBERNETES SHORTCUTS
# =============================================================================
if command -v kubectl &>/dev/null; then
    alias k='kubectl'
    alias kgp='kubectl get pods'
    alias kgpa='kubectl get pods -A'
    alias kgs='kubectl get services'
    alias kgd='kubectl get deployments'
    alias kgn='kubectl get nodes'
    alias kga='kubectl get all'
    alias kd='kubectl describe'
    alias kl='kubectl logs -f'
    alias kex='kubectl exec -it'
    alias kaf='kubectl apply -f'
    alias kdf='kubectl delete -f'
    alias kctx='kubectl config current-context'
    alias kns='kubectl config set-context --current --namespace'
fi

# =============================================================================
# PYTHON / UV / POETRY (UV-first approach)
# =============================================================================
alias py='python3'
alias python='python3'
alias ipy='ipython'

# UV (fast Python package manager) - Primary tool with toggle
SWEETS_USE_UV="${SWEETS_USE_UV:-auto}"

_sweets_setup_uv() {
    if [[ "$SWEETS_USE_UV" == "false" ]]; then
        return 1
    fi
    
    if command -v uv &>/dev/null; then
        return 0
    fi
    
    if [[ "$SWEETS_USE_UV" == "auto" ]]; then
        return 1
    fi
    
    return 1
}

if _sweets_setup_uv; then
    # UV aliases
    alias uvr='uv run'
    alias uvs='uv sync'
    alias uva='uv add'
    alias uvp='uv pip'
    alias uvpi='uv pip install'
    alias uvpc='uv pip compile'
    alias uvv='uv venv'
    alias uvx='uv tool run'
    
    # Replace pip with uv pip install (correct command)
    # Safe routing: Always uses virtual environments to avoid breaking system packages
    pip() {
        local cmd="$1"
        
        # For install/uninstall commands, ensure we're in a venv or warn
        if [[ "$cmd" == "install" ]] || [[ "$cmd" == "uninstall" ]]; then
            # Check if we're in a virtual environment
            if [[ -z "$VIRTUAL_ENV" ]]; then
                # Check if we're in a directory with a venv
                if [[ ! -d ".venv" ]] && [[ ! -d "venv" ]]; then
                    echo -e "\033[1;33m⚠ Warning: Not in a virtual environment!\033[0m"
                    echo "Installing packages outside a venv can break system packages (especially in Kali)."
                    echo ""
                    echo "Options:"
                    echo "  1) Create venv now: venv && activate"
                    echo "  2) Use uv run instead: uv run pip install $*"
                    echo "  3) Continue anyway (not recommended)"
                    echo ""
                    echo -n "Create venv and activate? (Y/n): "
                    read -r create_venv
                    if [[ ! "$create_venv" =~ ^[Nn]$ ]]; then
                        uv venv .venv
                        source .venv/bin/activate
                        echo -e "\033[0;32m[+] Virtual environment activated\033[0m"
                    else
                        echo -e "\033[1;31m[!] Proceeding without venv (risky!)\033[0m"
                        echo -n "Continue? (y/N): "
                        read -r confirm
                        if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
                            echo "Cancelled. Use 'venv' to create a virtual environment first."
                            return 1
                        fi
                    fi
                else
                    # Venv exists but not activated
                    echo -e "\033[1;33m⚠ Virtual environment exists but not activated.\033[0m"
                    echo "Activating .venv..."
                    if [[ -d ".venv" ]]; then
                        source .venv/bin/activate
                    elif [[ -d "venv" ]]; then
                        source venv/bin/activate
                    fi
                fi
            fi
            
            # Now safe to use uv pip (respects VIRTUAL_ENV)
            uv pip "$@"
        elif [[ "$cmd" == "list" ]] || [[ "$cmd" == "show" ]] || [[ "$cmd" == "freeze" ]]; then
            # Read-only commands are safe
            uv pip "$@"
        else
            # Fallback to system pip for other commands (like pip --version)
            command pip3 "$@"
        fi
    }
    
    # Replace pipx with uv tool install/run
    pipx() {
        case "$1" in
            install|inject|upgrade|reinstall-all|uninstall|uninstall-all|list|run)
                if [[ "$1" == "install" ]] || [[ "$1" == "inject" ]] || [[ "$1" == "upgrade" ]]; then
                    shift
                    uv tool install "$@"
                elif [[ "$1" == "run" ]]; then
                    shift
                    uv tool run "$@"
                elif [[ "$1" == "list" ]]; then
                    uv tool list
                elif [[ "$1" == "uninstall" ]] || [[ "$1" == "uninstall-all" ]]; then
                    echo "Note: Use 'uv tool uninstall <package>' for uv-based tool management"
                    command pipx "$@" 2>/dev/null || echo "pipx not available, use: uv tool uninstall"
                else
                    command pipx "$@" 2>/dev/null || uv tool "$@"
                fi
                ;;
            *)
                command pipx "$@" 2>/dev/null || uv tool "$@"
                ;;
        esac
    }
    
    # Use uv for virtual environments
    venv() {
        if [[ $# -eq 0 ]]; then
            uv venv .venv
            echo -e "\033[0;32m[+] Virtual environment created: .venv\033[0m"
            echo "Activate with: activate"
        else
            uv venv "$@"
        fi
    }
    
    export SWEETS_USE_UV="true"
else
    # Fallback to standard pip/pipx if uv not available
    alias pip='pip3'
    
    venv() {
        if [[ $# -eq 0 ]]; then
            python3 -m venv .venv
        else
            python3 -m venv "$@"
        fi
    }
    
    export SWEETS_USE_UV="false"
fi

# Smart activate that works with both uv and standard venvs (always available)
activate() {
    if [[ -d ".venv" ]]; then
        source .venv/bin/activate
    elif [[ -d "venv" ]]; then
        source venv/bin/activate
    elif [[ -n "$VIRTUAL_ENV" ]]; then
        echo "Already in virtual environment: $VIRTUAL_ENV"
    else
        echo "No virtual environment found. Create one with: venv"
    fi
}

# UV toggle function
sweets-uv-toggle() {
    if [[ "$SWEETS_USE_UV" == "true" ]]; then
        export SWEETS_USE_UV="false"
        echo "UV disabled. Using standard pip/pipx."
        echo "Reload shell or run: source ~/.${SWEETS_SHELL}rc"
    else
        if command -v uv &>/dev/null; then
            export SWEETS_USE_UV="true"
            echo "UV enabled. pip/pipx will use uv."
            echo "Reload shell or run: source ~/.${SWEETS_SHELL}rc"
        else
            echo "UV not installed. Install with: curl -LsSf https://astral.sh/uv/install.sh | sh"
            return 1
        fi
    fi
}

# Poetry (if installed)
if command -v poetry &>/dev/null; then
    alias poe='poetry'
    alias poei='poetry install'
    alias poea='poetry add'
    alias poer='poetry run'
    alias poes='poetry shell'
    alias poeu='poetry update'
    alias poeb='poetry build'
fi

# =============================================================================
# HOMEBREW (Linux)
# =============================================================================
if [[ -d "/home/linuxbrew/.linuxbrew" ]]; then
    eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"
elif [[ -d "$HOME/.linuxbrew" ]]; then
    eval "$($HOME/.linuxbrew/bin/brew shellenv)"
fi

if command -v brew &>/dev/null; then
    alias brewup='brew update && brew upgrade && brew cleanup'
    alias brewi='brew install'
    alias brews='brew search'
    alias brewl='brew list'
    alias brewinfo='brew info'
fi

# =============================================================================
# DEV TOOLS
# =============================================================================
alias serve='python3 -m http.server'
alias jsonpp='python3 -m json.tool'

# Node/NPM/Yarn
if command -v npm &>/dev/null; then
    alias ni='npm install'
    alias nid='npm install --save-dev'
    alias nig='npm install -g'
    alias nr='npm run'
    alias ns='npm start'
    alias nt='npm test'
    alias nb='npm run build'
fi

if command -v yarn &>/dev/null; then
    alias ya='yarn add'
    alias yad='yarn add --dev'
    alias yr='yarn run'
    alias ys='yarn start'
fi

if command -v pnpm &>/dev/null; then
    alias pn='pnpm'
    alias pni='pnpm install'
    alias pna='pnpm add'
    alias pnr='pnpm run'
fi

# Terraform
if command -v terraform &>/dev/null; then
    alias tf='terraform'
    alias tfi='terraform init'
    alias tfp='terraform plan'
    alias tfa='terraform apply'
    alias tfd='terraform destroy'
    alias tff='terraform fmt'
    alias tfv='terraform validate'
fi

# =============================================================================
# NETWORK UTILITIES
# =============================================================================
# Cross-platform local IP detection
_sweets_localip() {
    if command -v ip &>/dev/null; then
        ip -4 addr show 2>/dev/null | grep -o 'inet [0-9.]*' | awk '{print $2}' | grep -v 127.0.0.1 | head -1
    elif command -v ifconfig &>/dev/null; then
        ifconfig 2>/dev/null | grep 'inet ' | grep -v 127.0.0.1 | awk '{print $2}' | head -1
    elif command -v hostname &>/dev/null; then
        hostname -I 2>/dev/null | awk '{print $1}'
    fi
}

alias myip='curl -s ifconfig.me'
alias myip6='curl -s ifconfig.me/ip6'
alias localip='_sweets_localip'
alias ips="ip -c addr 2>/dev/null || ifconfig 2>/dev/null"
alias ports='ss -tulanp 2>/dev/null || netstat -tulanp 2>/dev/null'
alias listening='(ss -tulanp 2>/dev/null || netstat -tulanp 2>/dev/null) | grep LISTEN'
alias connections='ss -tunap 2>/dev/null || netstat -tunap 2>/dev/null'
alias flushdns='sudo systemd-resolve --flush-caches 2>/dev/null || sudo resolvectl flush-caches 2>/dev/null || echo "Try: sudo systemctl restart systemd-resolved"'

# DNS shortcuts
alias dig='dig +short'
alias digfull='command dig'

# Network testing
alias pingg='ping -c 5 8.8.8.8'

# HTTP testing
alias headers='curl -I'

# =============================================================================
# FILE & ARCHIVE UTILITIES
# =============================================================================
# Archive extraction (smart)
extract() {
    if [[ -f "$1" ]]; then
        case "$1" in
            *.tar.bz2) tar xjf "$1" ;;
            *.tar.gz)  tar xzf "$1" ;;
            *.tar.xz)  tar xJf "$1" ;;
            *.bz2)     bunzip2 "$1" ;;
            *.rar)     unrar x "$1" ;;
            *.gz)      gunzip "$1" ;;
            *.tar)     tar xf "$1" ;;
            *.tbz2)    tar xjf "$1" ;;
            *.tgz)     tar xzf "$1" ;;
            *.zip)     unzip "$1" ;;
            *.Z)       uncompress "$1" ;;
            *.7z)      7z x "$1" ;;
            *)         echo "Cannot extract '$1'" ;;
        esac
    else
        echo "'$1' is not a file"
    fi
}

# Create archives
alias tgz='tar -czvf'
alias tbz='tar -cjvf'
alias txz='tar -cJvf'

# File operations
alias cp='cp -iv'
alias mv='mv -iv'
alias rm='rm -Iv'
alias mkdir='mkdir -pv'
alias ln='ln -iv'

# Find shortcuts
alias ff='find . -type f -name'
alias fd='find . -type d -name'
alias recent='find . -type f -mmin -30'
alias large='find . -type f -size +100M'

# File info
alias filesize='du -sh'
alias filetype='file'
alias hex='xxd'
alias strings='strings -a'

# =============================================================================
# SYSTEM UTILITIES
# =============================================================================
alias h='history'
alias hg='history | grep'
alias c='clear'
alias q='exit'
alias path='echo $PATH | tr ":" "\n"'
alias now='date +"%Y-%m-%d %H:%M:%S"'
alias week='date +%V'
alias reload='source ~/.${SWEETS_SHELL}rc'
alias meminfo='free -h'
alias cpuinfo='lscpu'
alias diskinfo='df -h'
alias duh='du -h --max-depth=1 | sort -h'
alias duf='df -hT'
alias mounted='mount | column -t'

# Process management
ps() {
    command ps aux "$@"
}

psgrep() {
    ps aux | grep -v grep | grep "$1"
}

alias psg='ps aux | grep -v grep | grep'

# System
alias syslog='sudo tail -f /var/log/syslog 2>/dev/null || sudo tail -f /var/log/messages'
alias authlog='sudo tail -f /var/log/auth.log 2>/dev/null || sudo tail -f /var/log/secure'

# =============================================================================
# SMART SUDO WRAPPERS
# =============================================================================
vi() {
    if [[ -e "$1" && ! -w "$1" ]] || [[ ! -e "$1" && ! -w "$(dirname "${1:-.}")" ]]; then
        sudo vi "$@"
    else
        command vi "$@"
    fi
}

vim() {
    if [[ -e "$1" && ! -w "$1" ]] || [[ ! -e "$1" && ! -w "$(dirname "${1:-.}")" ]]; then
        sudo vim "$@"
    else
        command vim "$@"
    fi
}

nano() {
    if [[ -e "$1" && ! -w "$1" ]] || [[ ! -e "$1" && ! -w "$(dirname "${1:-.}")" ]]; then
        sudo nano "$@"
    else
        command nano "$@"
    fi
}

alias svi="sudoedit"
alias svim="SUDO_EDITOR=vim sudoedit"
alias snano="SUDO_EDITOR=nano sudoedit"

# =============================================================================
# PACKAGE MANAGERS (auto-sudo)
# =============================================================================
# APT (Debian/Ubuntu)
apt() { [[ $EUID -ne 0 ]] && sudo apt "$@" || command apt "$@"; }
apt-get() { [[ $EUID -ne 0 ]] && sudo apt-get "$@" || command apt-get "$@"; }
dpkg() { [[ $EUID -ne 0 ]] && sudo dpkg "$@" || command dpkg "$@"; }

# DNF/YUM (RHEL/Fedora)
dnf() { [[ $EUID -ne 0 ]] && sudo dnf "$@" || command dnf "$@"; }
yum() { [[ $EUID -ne 0 ]] && sudo yum "$@" || command yum "$@"; }

# =============================================================================
# SYSTEMD (smart sudo with status reporting)
# =============================================================================
# Color codes for status
_sweets_status_green() { echo -e "\033[0;32m✓\033[0m"; }
_sweets_status_red() { echo -e "\033[0;31m✗\033[0m"; }
_sweets_status_amber() { echo -e "\033[1;33m⚠\033[0m"; }

# Enhanced systemctl with auto-remediation and status reporting
systemctl() {
    local cmd="$1"
    local service="$2"
    local original_args=("$@")
    local retry_count=0
    local max_retries=1
    
    # Execute command
    local exit_code
    if [[ "$*" == *"--user"* ]] || [[ "$cmd" =~ ^(status|is-active|is-enabled|is-failed|show|help|cat|list-)$ ]] || [[ "$cmd" == "list-"* ]]; then
        command systemctl "$@"
        exit_code=$?
    elif [[ $EUID -ne 0 ]]; then
        sudo systemctl "$@"
        exit_code=$?
    else
        command systemctl "$@"
        exit_code=$?
    fi
    
    # Auto-remediate: Check for daemon-reload needed errors
    if [[ $exit_code -ne 0 ]] && [[ "$cmd" =~ ^(start|stop|restart|enable|disable|reload)$ ]] && [[ -n "$service" ]]; then
        # Check if service file was recently modified (within last 5 minutes)
        local service_file
        service_file=$(command systemctl show -p FragmentPath "$service" 2>/dev/null | cut -d'=' -f2)
        if [[ -n "$service_file" && -f "$service_file" ]]; then
            local file_age
            if stat --version &>/dev/null 2>&1; then
                file_age=$(($(date +%s) - $(stat -c %Y "$service_file" 2>/dev/null || echo 0)))
            else
                file_age=$(($(date +%s) - $(stat -f %m "$service_file" 2>/dev/null || echo 0)))
            fi
            # If file was modified recently and command failed, try daemon-reload
            if [[ $file_age -lt 300 ]] && [[ $retry_count -lt $max_retries ]]; then
                echo -e "$(_sweets_status_amber) Service file changed, running daemon-reload and retrying..."
                if [[ $EUID -ne 0 ]]; then
                    sudo systemctl daemon-reload
                else
                    command systemctl daemon-reload
                fi
                
                # Retry the original command
                retry_count=$((retry_count + 1))
                if [[ "$*" == *"--user"* ]] || [[ "$cmd" =~ ^(status|is-active|is-enabled|is-failed|show|help|cat|list-)$ ]] || [[ "$cmd" == "list-"* ]]; then
                    command systemctl "${original_args[@]}"
                    exit_code=$?
                elif [[ $EUID -ne 0 ]]; then
                    sudo systemctl "${original_args[@]}"
                    exit_code=$?
                else
                    command systemctl "${original_args[@]}"
                    exit_code=$?
                fi
            fi
        fi
    fi
    
    # Status reporting for start/stop/restart/enable/disable (only show on failure)
    if [[ "$cmd" =~ ^(start|stop|restart|enable|disable|reload)$ ]] && [[ -n "$service" ]]; then
        sleep 0.5  # Brief pause for systemd to update
        local is_active
        is_active=$(systemctl is-active "$service" 2>/dev/null)
        local is_enabled
        is_enabled=$(systemctl is-enabled "$service" 2>/dev/null 2>&1)
        
        if [[ "$cmd" == "start" ]] || [[ "$cmd" == "restart" ]]; then
            if [[ "$is_active" != "active" ]]; then
                echo -e "$(_sweets_status_red) Service '$service' failed to start"
                echo "  Recent logs:"
                journalctl -u "$service" --no-pager -n 10 2>/dev/null | tail -5 || true
                echo "  Run 'systemctl status $service' for full details"
            fi
        elif [[ "$cmd" == "stop" ]] && [[ "$is_active" != "inactive" ]] && [[ "$is_active" != "failed" ]]; then
            echo -e "$(_sweets_status_amber) Service '$service' may still be running"
        elif [[ "$cmd" == "enable" ]] && [[ "$is_enabled" != "enabled" ]] && [[ "$is_enabled" != "enabled-runtime" ]]; then
            echo -e "$(_sweets_status_red) Service '$service' failed to enable"
        elif [[ "$cmd" == "disable" ]] && [[ "$is_enabled" != "disabled" ]]; then
            echo -e "$(_sweets_status_amber) Service '$service' may still be enabled"
        fi
    fi
    
    return $exit_code
}

# Minimal service aliases (systemctl wrapper handles auto-remediation)
alias sc='systemctl'

journalctl() {
    if [[ "$*" == *"-f"* ]] || [[ "$*" == *"--follow"* ]] || [[ "$*" == *"--vacuum"* ]]; then
        [[ $EUID -ne 0 ]] && sudo journalctl "$@" || command journalctl "$@"
    else
        command journalctl "$@"
    fi
}

# Quick log viewing on startup (show recent errors/warnings)
_sweets_show_startup_logs() {
    if [[ -n "$SWEETS_QUIET" ]]; then
        return 0
    fi
    
    # Check for failed services
    local failed_count
    failed_count=$(systemctl --failed --no-legend 2>/dev/null | wc -l)
    if [[ $failed_count -gt 0 ]]; then
        echo -e "$(_sweets_status_red) $failed_count failed service(s) detected"
        echo "  Run 'systemctl --failed' or 'scfailed' to view"
    fi
    
    # Show recent critical/error log entries (last 5 minutes)
    if command -v journalctl &>/dev/null; then
        local recent_errors
        recent_errors=$(journalctl --since "5 minutes ago" --priority=err --no-pager 2>/dev/null | wc -l)
        if [[ $recent_errors -gt 0 ]]; then
            echo -e "$(_sweets_status_amber) $recent_errors recent error(s) in system logs"
            echo "  Run 'journalctl -p err --since \"5 minutes ago\"' to view"
        fi
    fi
}

# Run startup log check (only once per session)
if [[ -z "$SWEETS_LOG_CHECKED" ]]; then
    _sweets_show_startup_logs
    export SWEETS_LOG_CHECKED=true
fi

# =============================================================================
# NETWORK/FIREWALL (auto-sudo)
# =============================================================================
iptables() { [[ $EUID -ne 0 ]] && sudo iptables "$@" || command iptables "$@"; }
ip6tables() { [[ $EUID -ne 0 ]] && sudo ip6tables "$@" || command ip6tables "$@"; }
ufw() { [[ $EUID -ne 0 ]] && sudo ufw "$@" || command ufw "$@"; }
firewall-cmd() { [[ $EUID -ne 0 ]] && sudo firewall-cmd "$@" || command firewall-cmd "$@"; }
tcpdump() { [[ $EUID -ne 0 ]] && sudo tcpdump "$@" || command tcpdump "$@"; }

# =============================================================================
# DISK/FILESYSTEM (auto-sudo)
# =============================================================================
mount() {
    if [[ $# -eq 0 ]] || [[ "$1" == "-l" ]]; then
        command mount "$@"
    elif [[ $EUID -ne 0 ]]; then
        sudo mount "$@"
    else
        command mount "$@"
    fi
}
umount() { [[ $EUID -ne 0 ]] && sudo umount "$@" || command umount "$@"; }
fdisk() { [[ "$*" == *"-l"* ]] && { command fdisk "$@" 2>/dev/null || sudo fdisk "$@"; } || { [[ $EUID -ne 0 ]] && sudo fdisk "$@" || command fdisk "$@"; }; }

# =============================================================================
# USER MANAGEMENT (auto-sudo)
# =============================================================================
useradd() { [[ $EUID -ne 0 ]] && sudo useradd "$@" || command useradd "$@"; }
userdel() { [[ $EUID -ne 0 ]] && sudo userdel "$@" || command userdel "$@"; }
usermod() { [[ $EUID -ne 0 ]] && sudo usermod "$@" || command usermod "$@"; }
groupadd() { [[ $EUID -ne 0 ]] && sudo groupadd "$@" || command groupadd "$@"; }
groupdel() { [[ $EUID -ne 0 ]] && sudo groupdel "$@" || command groupdel "$@"; }
visudo() { [[ $EUID -ne 0 ]] && sudo visudo "$@" || command visudo "$@"; }
chown() { [[ $EUID -ne 0 ]] && sudo chown "$@" || command chown "$@"; }

passwd() {
    if [[ $EUID -ne 0 && -n "$1" ]]; then
        sudo passwd "$@"
    else
        command passwd "$@"
    fi
}

# =============================================================================
# DOCKER/PODMAN (smart - checks group)
# =============================================================================
docker() {
    if [[ "$SWEETS_CONTAINER_ENGINE" == "podman" ]]; then
        # Podman doesn't need sudo typically
        command podman "$@"
    elif [[ $EUID -ne 0 ]] && ! groups 2>/dev/null | grep -qw docker; then
        sudo docker "$@"
    else
        command docker "$@"
    fi
}

podman() {
    command podman "$@"
}

# =============================================================================
# SYSTEM POWER
# =============================================================================
alias reboot='sudo reboot'
alias poweroff='sudo poweroff'
alias shutdown='sudo shutdown'

# =============================================================================
# KERNEL MODULES
# =============================================================================
modprobe() { [[ $EUID -ne 0 ]] && sudo modprobe "$@" || command modprobe "$@"; }
rmmod() { [[ $EUID -ne 0 ]] && sudo rmmod "$@" || command rmmod "$@"; }
dmesg() { command dmesg "$@" 2>/dev/null || sudo dmesg "$@"; }

# =============================================================================
# TMUX ALIASES
# =============================================================================
alias tscroll='tmux copy-mode'
alias tpaste='tmux paste-buffer'
alias tn='tmux new -s'
alias ta='tmux attach -t'
alias tl='tmux list-sessions'
alias tk='tmux kill-session -t'

# =============================================================================
# SWEETS COMMANDS
# =============================================================================
sweets-update() {
    local dir="${SWEETS_DIR:-$HOME/.sweet-scripts}"
    local current_version="$SWEETS_VERSION"
    local remote_version=""
    
    echo -e "\033[36m\033[1m=== SWEET-Scripts Update ===\033[0m"
    echo ""
    echo -e "Current version: \033[1mv${current_version}\033[0m"
    echo ""
    
    if [[ -d "$dir/.git" ]]; then
        echo "Checking for updates..."
        
        # Fetch latest from remote
        (cd "$dir" && git fetch origin main 2>/dev/null || git fetch origin 2>/dev/null) || {
            echo -e "\033[33m[!] Could not fetch from remote. Check internet connection.\033[0m"
            return 1
        }
        
        # Get remote version from sweets.sh
        remote_version=$(cd "$dir" && git show origin/main:sweets.sh 2>/dev/null | grep "^export SWEETS_VERSION=" | head -1 | sed 's/export SWEETS_VERSION="\(.*\)"/\1/' || \
                        cd "$dir" && git show origin/master:sweets.sh 2>/dev/null | grep "^export SWEETS_VERSION=" | head -1 | sed 's/export SWEETS_VERSION="\(.*\)"/\1/')
        
        if [[ -n "$remote_version" ]]; then
            echo -e "Latest version: \033[1mv${remote_version}\033[0m"
            echo ""
            
            if [[ "$remote_version" == "$current_version" ]]; then
                echo -e "\033[32m✓ You are already on the latest version!\033[0m"
                return 0
            else
                echo -e "\033[33mUpdate available: v${current_version} → v${remote_version}\033[0m"
                echo ""
                echo -n "Proceed with update? (Y/n): "
                read -r confirm
                if [[ "$confirm" =~ ^[Nn]$ ]]; then
                    echo "Update cancelled."
                    return 0
                fi
                echo ""
            fi
        else
            echo -e "\033[33m[!] Could not determine remote version. Proceeding with update...\033[0m"
            echo ""
        fi
        
        echo "Updating SWEET-Scripts..."
        (cd "$dir" && git pull origin main 2>/dev/null || git pull origin master 2>/dev/null || git pull)
        
        # Reload the script to get new version
        . "$dir/sweets.sh" 2>/dev/null || source "$dir/sweets.sh"
        
        echo ""
        if [[ -n "$remote_version" ]] && [[ "$remote_version" == "$SWEETS_VERSION" ]]; then
            echo -e "\033[32m✓ Successfully updated to v${SWEETS_VERSION}\033[0m"
        else
            echo -e "\033[32m✓ Update complete. Current version: v${SWEETS_VERSION}\033[0m"
        fi
    else
        echo -e "\033[33m[!] Git repo not found in $dir\033[0m"
        echo "Re-run install.sh to set up the repository."
        return 1
    fi
}

sweets-info() {
    cat << EOF
SWEET-Scripts v${SWEETS_VERSION}
  Shell: $SWEETS_SHELL
  Distro: $SWEETS_DISTRO
  Install: ${SWEETS_DIR:-$HOME/.sweet-scripts}
  Creds: $SWEETS_CREDS_FILE

Run 'sweets-help' for commands
EOF
}

sweets-setup() {
    echo "Re-running vim/tmux setup..."
    local vimrc="$HOME/.vimrc"
    local tmuxrc="$HOME/.tmux.conf"
    
    # Vim clipboard
    if [[ ! -f "$vimrc" ]] || ! grep -q "SWEET-Scripts clipboard" "$vimrc" 2>/dev/null; then
        {
            echo ""
            echo "\" SWEET-Scripts clipboard"
            echo "if has('clipboard')"
            echo "    set clipboard=unnamedplus"
            echo "endif"
        } >> "$vimrc"
        echo "[+] Vim clipboard configured"
    fi
    
    # Tmux scrolling
    if [[ ! -f "$tmuxrc" ]] || ! grep -q "SWEET-Scripts tmux" "$tmuxrc" 2>/dev/null; then
        {
            echo ""
            echo "# SWEET-Scripts tmux config"
            echo "set -g mouse on"
            echo "bind -n WheelUpPane if-shell -F -t = \"#{mouse_any_flag}\" \"send-keys -M\" \"if-shell -t = '\"#{pane_in_mode}\"' 'send-keys -M' 'select-pane -t =; copy-mode -e; send-keys -M'\""
            echo "bind -n WheelDownPane select-pane -t = \\; send-keys -M"
        } >> "$tmuxrc"
        echo "[+] Tmux scrolling configured"
    fi
    
    echo "[+] Setup complete!"
}

sweets-help() {
    cat << 'EOF'
SWEET-Scripts - Quick Reference

KEYBOARD SHORTCUTS:
  Ctrl+A/E      Start/End of line      Ctrl+W        Delete word back
  Alt+B/F       Word back/forward      Ctrl+Left/Right  Word nav (alt)
  Ctrl+R/S      History search         Ctrl+U/K      Delete to start/end
  Ctrl+Y        Paste deleted          Ctrl+L        Clear screen

CLIPBOARD:
  clip <text>   Copy to clipboard      clipfile      Copy file contents
  clipwd        Copy current path      cliplast      Copy last command

CREDENTIALS:
  sweets-add-cred <NAME>    sweets-list-creds    sweets-remove-cred <NAME>

NAVIGATION:
  ll, l, la     Detailed listing       lt, ltree     Tree view
  .., ..., .... Go up directories      tree1/2/3     Tree with depth

GIT:      g, gs, ga, gc, gcm, gp, gpl, gco, gcb, gb, gd, gds, glog
GITHUB:   ghpr, ghprl, ghprv, ghis, ghic, ghrepo
DOCKER:   d, dc, dps, dpsa, di, dex, dlogs, dprune, dstop, drm, drmi
K8S:      k, kgp, kgpa, kgs, kgd, kga, kd, kl, kex, kaf, kdf, kctx, kns
PYTHON:   py, venv, activate, deact
UV:       uvr, uvs, uva, uvp, uvpi, uvv
POETRY:   poe, poei, poea, poer, poes, poeu, poeb
BREW:     brewup, brewi, brews, brewl, brewinfo
NODE:     ni, nid, nig, nr, ns, nt, nb
TERRAFORM: tf, tfi, tfp, tfa, tfd, tff, tfv
TAILSCALE: ts, tss, tsip, tsup, tsdown, tsping
SSH:      sshimport <user> [target]  - Import GitHub keys to authorized_keys

NETWORK:
  myip, myip6   Public IP              localip, ips  Local IPs
  ports         All ports              listening     Open ports
  connections   Active connections
  rdns          Reverse DNS            pingg, pingd  Quick ping tests
  headers       HTTP headers           httpcode      HTTP status code

FILES:
  extract <file>  Smart extract        tgz, tbz, txz Create archives
  ff, fd          Find file/dir        recent, large Find by time/size
  filesize        Show size            hex, strings  Binary tools

SYSTEM:
  meminfo       Memory usage           cpuinfo       CPU info
  diskinfo, duf Disk usage             duh           Dir sizes
  psg           Find process           topmem/cpu    Top consumers
  services      Running services       failed        Failed services
  syslog        Tail syslog            authlog       Auth log
  users         Who's logged in        lastlogin     Recent logins

TMUX:
  tn/ta/tl/tk   New/Attach/List/Kill   tscroll       Enter copy mode
  Prefix+k/j    Scroll up / copy mode  Mouse wheel   Scroll

VIM:  <leader>y  Yank to clipboard     <leader>p  Paste from clipboard

SWEETS:
  sweets           Interactive menu    sweets-update    Update
  sweets-info      Version info        sweets-help      This help
  sweets-keys      Keyboard shortcuts
EOF
}

sweets-keys() {
    cat << 'EOF'
Terminal Keyboard Shortcuts:
  Ctrl+A        Start of line       Ctrl+E        End of line
  Ctrl+W        Delete word back    Ctrl+U        Delete to start
  Alt+B         Word back           Alt+F         Word forward
  Ctrl+Left     Word back (alt)     Ctrl+Right    Word forward (alt)
  Ctrl+R        Search history      Ctrl+L        Clear screen
  Ctrl+K        Delete to end       Ctrl+Y        Paste deleted
  Tab           Auto-complete       Up/Down       History
EOF
}

# =============================================================================
# TAILSCALE MANAGEMENT
# =============================================================================
sweets-tailscale() {
    local action="${1:-status}"
    local auth_key="$2"
    local use_dns=false
    local accept_routes=true
    
    # Parse arguments
    shift 2>/dev/null || true
    while [[ $# -gt 0 ]]; do
        case $1 in
            --dns) use_dns=true; shift ;;
            --no-routes) accept_routes=false; shift ;;
            *) shift ;;
        esac
    done
    
    case "$action" in
        install)
            if [[ -z "$auth_key" ]]; then
                echo "Usage: sweets-tailscale install <authkey> [--dns] [--no-routes]"
                echo ""
                echo "Options:"
                echo "  --dns        Enable Tailscale DNS (default: off)"
                echo "  --no-routes  Don't accept routes (default: on)"
                echo ""
                echo "Get key from: https://login.tailscale.com/admin/settings/keys"
                return 1
            fi
            
            echo "[*] Installing Tailscale..."
            
            # Install based on distro
            case "$SWEETS_DISTRO" in
                ubuntu|debian|pop|linuxmint)
                    curl -fsSL https://pkgs.tailscale.com/stable/ubuntu/jammy.noarmor.gpg | sudo tee /usr/share/keyrings/tailscale-archive-keyring.gpg >/dev/null
                    curl -fsSL https://pkgs.tailscale.com/stable/ubuntu/jammy.tailscale-keyring.list | sudo tee /etc/apt/sources.list.d/tailscale.list >/dev/null
                    sudo apt update && sudo apt install -y tailscale
                    ;;
                rhel|centos|rocky|almalinux|fedora)
                    sudo dnf config-manager --add-repo https://pkgs.tailscale.com/stable/fedora/tailscale.repo 2>/dev/null || \
                    sudo yum-config-manager --add-repo https://pkgs.tailscale.com/stable/rhel/8/tailscale.repo 2>/dev/null || true
                    sudo dnf install -y tailscale 2>/dev/null || sudo yum install -y tailscale
                    ;;
                *)
                    echo "[*] Unknown distro, using curl installer..."
                    curl -fsSL https://tailscale.com/install.sh | sh
                    ;;
            esac
            
            echo "[+] Starting tailscaled..."
            sudo systemctl enable --now tailscaled
            sleep 2
            
            echo "[+] Connecting..."
            local args="--authkey=$auth_key"
            [[ "$use_dns" == false ]] && args="$args --accept-dns=false"
            [[ "$accept_routes" == true ]] && args="$args --accept-routes"
            sudo tailscale up $args
            
            echo "[+] Enabling auto-update..."
            sudo tailscale set --auto-update 2>/dev/null || true
            
            echo ""
            echo "[+] Tailscale installed and connected!"
            tailscale status
            echo ""
            echo "Tailscale IP: $(tailscale ip -4 2>/dev/null)"
            [[ "$use_dns" == false ]] && echo "Note: DNS disabled. Enable with: tailscale set --accept-dns=true"
            ;;
        uninstall)
            echo "[*] Uninstalling Tailscale..."
            sudo tailscale down 2>/dev/null || true
            if command -v apt &>/dev/null; then
                sudo apt remove -y tailscale
                sudo rm -f /usr/share/keyrings/tailscale-archive-keyring.gpg
                sudo rm -f /etc/apt/sources.list.d/tailscale.list
            elif command -v dnf &>/dev/null; then
                sudo dnf remove -y tailscale
                sudo rm -f /etc/yum.repos.d/tailscale.repo
            elif command -v yum &>/dev/null; then
                sudo yum remove -y tailscale
            fi
            echo "[+] Tailscale removed"
            ;;
        up)
            echo "[*] Connecting Tailscale..."
            sudo tailscale up
            ;;
        down)
            echo "[*] Disconnecting Tailscale..."
            sudo tailscale down
            ;;
        status)
            if command -v tailscale &>/dev/null; then
                tailscale status
            else
                echo "Tailscale not installed. Run: sweets-tailscale install <authkey>"
            fi
            ;;
        ip)
            tailscale ip -4 2>/dev/null || echo "Not connected"
            ;;
        *)
            echo "Usage: sweets-tailscale <command> [options]"
            echo ""
            echo "Commands:"
            echo "  install <key>  Install and connect (--dns, --no-routes)"
            echo "  uninstall      Remove Tailscale"
            echo "  up             Connect"
            echo "  down           Disconnect"
            echo "  status         Show status"
            echo "  ip             Show Tailscale IP"
            ;;
    esac
}

# Tailscale aliases
alias ts='sweets-tailscale'
alias tss='tailscale status'
alias tsip='tailscale ip -4'
alias tsup='sudo tailscale up'
alias tsdown='sudo tailscale down'
alias tsping='tailscale ping'

# =============================================================================
# SYSLOG FORWARDING SETUP
# =============================================================================
sweets-syslog-setup() {
    # Check for syslog packages
    local rsyslog_installed=false
    local syslogng_installed=false
    
    if command -v rsyslog &>/dev/null || systemctl list-unit-files 2>/dev/null | grep -q rsyslog; then
        rsyslog_installed=true
    fi
    
    if command -v syslog-ng &>/dev/null || systemctl list-unit-files 2>/dev/null | grep -q syslog-ng; then
        syslogng_installed=true
    fi
    
    if [[ "$rsyslog_installed" == false ]] && [[ "$syslogng_installed" == false ]]; then
        echo "[!] No syslog daemon found. Installing rsyslog..."
        case "$SWEETS_DISTRO" in
            ubuntu|debian|pop|linuxmint)
                sudo apt update && sudo apt install -y rsyslog
                ;;
            rhel|centos|rocky|almalinux|fedora)
                sudo dnf install -y rsyslog 2>/dev/null || sudo yum install -y rsyslog
                ;;
            *)
                echo "[!] Please install rsyslog or syslog-ng manually"
                return 1
                ;;
        esac
        rsyslog_installed=true
    fi
    
    echo ""
    echo "Syslog daemon: $([ "$rsyslog_installed" == true ] && echo "rsyslog" || echo "syslog-ng")"
    echo ""
    
    # Detect domain for default syslog server
    local domain=$(hostname -d 2>/dev/null || hostname -f 2>/dev/null | cut -d. -f2-)
    local default_udp="syslog.${domain}:514"
    local default_tls="syslog.${domain}:6514"
    
    if [[ -z "$domain" ]] || [[ "$domain" == "local" ]] || [[ "$domain" == "localhost" ]]; then
        default_udp="syslog.example.com:514"
        default_tls="syslog.example.com:6514"
    fi
    
    echo "Configure forwarding to:"
    echo "  1) UDP syslog server (plain) - Default: $default_udp"
    echo "  2) TCP syslog server (plain) - Default: $default_udp"
    echo "  3) TLS syslog server (secure) - Default: $default_tls"
    echo "  4) Setup auditd forwarding"
    echo "  5) Cancel"
    echo ""
    echo -n "Select option: "
    read -r log_choice
    
    case "$log_choice" in
        1|2|3)
            echo ""
            echo -n "Enter syslog server address (IP or hostname) [default: ${default_udp%:*}]: "
            read -r log_server
            if [[ -z "$log_server" ]]; then
                if [[ "$log_choice" == "3" ]]; then
                    log_server="${default_tls%:*}"
                    log_port="${default_tls#*:}"
                else
                    log_server="${default_udp%:*}"
                    log_port="${default_udp#*:}"
                fi
            else
                if [[ "$log_choice" == "3" ]]; then
                    echo -n "Enter port [default 6514]: "
                else
                    echo -n "Enter port [default 514]: "
                fi
                read -r log_port
                if [[ "$log_choice" == "3" ]]; then
                    log_port="${log_port:-6514}"
                else
                    log_port="${log_port:-514}"
                fi
            fi
            
            if [[ "$log_choice" == "1" ]]; then
                # UDP
                if [[ "$rsyslog_installed" == true ]]; then
                    echo "*.* @${log_server}:${log_port}" | sudo tee -a /etc/rsyslog.conf >/dev/null
                    echo "[+] Added UDP forwarding to ${log_server}:${log_port}"
                else
                    echo "destination d_remote { udp(\"${log_server}\" port(${log_port})); };" | sudo tee -a /etc/syslog-ng/syslog-ng.conf >/dev/null
                    echo "log { source(s_src); destination(d_remote); };" | sudo tee -a /etc/syslog-ng/syslog-ng.conf >/dev/null
                    echo "[+] Added UDP forwarding to ${log_server}:${log_port}"
                fi
            elif [[ "$log_choice" == "2" ]]; then
                # TCP
                if [[ "$rsyslog_installed" == true ]]; then
                    echo "*.* @@${log_server}:${log_port}" | sudo tee -a /etc/rsyslog.conf >/dev/null
                    echo "[+] Added TCP forwarding to ${log_server}:${log_port}"
                else
                    echo "destination d_remote { tcp(\"${log_server}\" port(${log_port})); };" | sudo tee -a /etc/syslog-ng/syslog-ng.conf >/dev/null
                    echo "log { source(s_src); destination(d_remote); };" | sudo tee -a /etc/syslog-ng/syslog-ng.conf >/dev/null
                    echo "[+] Added TCP forwarding to ${log_server}:${log_port}"
                fi
            elif [[ "$log_choice" == "3" ]]; then
                # TLS
                echo -n "Enter CA certificate path (optional): "
                read -r ca_cert
                if [[ "$rsyslog_installed" == true ]]; then
                    {
                        echo "\$DefaultNetstreamDriver gtls"
                        [[ -n "$ca_cert" ]] && echo "\$DefaultNetstreamDriverCAFile ${ca_cert}"
                        echo "\$ActionSendStreamDriverMode 1"
                        echo "\$ActionSendStreamDriverAuthMode x509/name"
                        echo "*.* @@${log_server}:${log_port}"
                    } | sudo tee -a /etc/rsyslog.conf >/dev/null
                    echo "[+] Added TLS forwarding to ${log_server}:${log_port}"
                else
                    echo "destination d_remote { syslog(\"${log_server}\" port(${log_port}) transport(\"tls\")); };" | sudo tee -a /etc/syslog-ng/syslog-ng.conf >/dev/null
                    echo "log { source(s_src); destination(d_remote); };" | sudo tee -a /etc/syslog-ng/syslog-ng.conf >/dev/null
                    echo "[+] Added TLS forwarding to ${log_server}:${log_port}"
                fi
            fi
            
            echo ""
            echo "[*] Restarting syslog daemon..."
            if [[ "$rsyslog_installed" == true ]]; then
                sudo systemctl restart rsyslog
            else
                sudo systemctl restart syslog-ng
            fi
            echo "[+] Syslog forwarding configured!"
            ;;
        4)
            # Auditd forwarding
            if ! command -v auditd &>/dev/null && ! systemctl list-unit-files 2>/dev/null | grep -q auditd; then
                echo "[!] Installing auditd..."
                case "$SWEETS_DISTRO" in
                    ubuntu|debian|pop|linuxmint)
                        sudo apt install -y auditd
                        ;;
                    rhel|centos|rocky|almalinux|fedora)
                        sudo dnf install -y audit 2>/dev/null || sudo yum install -y audit
                        ;;
                esac
            fi
            
            echo ""
            echo -n "Enter syslog server for auditd: "
            read -r audit_server
            echo -n "Enter port (default 514): "
            read -r audit_port
            audit_port="${audit_port:-514}"
            
            # Configure auditd to forward to syslog
            sudo sed -i 's/^active = .*/active = yes/' /etc/audit/auditd.conf 2>/dev/null || true
            sudo sed -i 's/^write_logs = .*/write_logs = yes/' /etc/audit/auditd.conf 2>/dev/null || true
            echo "log_format = ENRICHED" | sudo tee -a /etc/audit/auditd.conf >/dev/null
            
            # Add to rsyslog
            if [[ "$rsyslog_installed" == true ]]; then
                echo "# Auditd forwarding" | sudo tee -a /etc/rsyslog.conf >/dev/null
                echo "if \$programname == 'auditd' then @${audit_server}:${audit_port}" | sudo tee -a /etc/rsyslog.conf >/dev/null
                echo "& stop" | sudo tee -a /etc/rsyslog.conf >/dev/null
            fi
            
            sudo systemctl enable auditd
            sudo systemctl restart auditd
            [[ "$rsyslog_installed" == true ]] && sudo systemctl restart rsyslog
            
            echo "[+] Auditd forwarding configured!"
            ;;
        *)
            echo "Cancelled."
            return 0
            ;;
    esac
}

# =============================================================================
# SECURITY HARDENING (AUDITD + SYSLOG)
# =============================================================================
sweets-security-setup() {
    echo -e "\033[1mSecurity Hardening Setup\033[0m"
    echo "This will configure:"
    echo "  • auditd (Linux Audit Daemon) with recommended profile"
    echo "  • rsyslog (if not installed)"
    echo "  • Basic security hardening"
    echo ""
    echo -n "Proceed with security setup? (Y/n): "
    read -r confirm
    if [[ "$confirm" =~ ^[Nn]$ ]]; then
        echo "Cancelled."
        return 0
    fi
    
    echo ""
    echo "[*] Checking for rsyslog..."
    local rsyslog_installed=false
    if command -v rsyslog &>/dev/null || systemctl list-unit-files 2>/dev/null | grep -q rsyslog; then
        rsyslog_installed=true
        echo "[+] rsyslog is installed"
    else
        echo "[!] rsyslog not found. Installing..."
        case "$SWEETS_DISTRO" in
            ubuntu|debian|pop|linuxmint)
                sudo apt update && sudo apt install -y rsyslog
                ;;
            rhel|centos|rocky|almalinux|fedora)
                sudo dnf install -y rsyslog 2>/dev/null || sudo yum install -y rsyslog
                ;;
            *)
                echo "[!] Please install rsyslog manually"
                return 1
                ;;
        esac
        rsyslog_installed=true
        echo "[+] rsyslog installed"
    fi
    
    echo ""
    echo "[*] Installing and configuring auditd..."
    if ! command -v auditd &>/dev/null && ! systemctl list-unit-files 2>/dev/null | grep -q auditd; then
        case "$SWEETS_DISTRO" in
            ubuntu|debian|pop|linuxmint)
                sudo apt install -y auditd audispd-plugins
                ;;
            rhel|centos|rocky|almalinux|fedora)
                sudo dnf install -y audit audispd-plugins 2>/dev/null || sudo yum install -y audit
                ;;
        esac
    fi
    
    # Configure auditd with recommended settings
    echo "[*] Configuring auditd with recommended profile..."
    
    # Enable auditd
    sudo sed -i 's/^active = .*/active = yes/' /etc/audit/auditd.conf 2>/dev/null || true
    sudo sed -i 's/^write_logs = .*/write_logs = yes/' /etc/audit/auditd.conf 2>/dev/null || true
    
    # Set log format to enriched
    if ! grep -q "^log_format" /etc/audit/auditd.conf 2>/dev/null; then
        echo "log_format = ENRICHED" | sudo tee -a /etc/audit/auditd.conf >/dev/null
    else
        sudo sed -i 's/^log_format = .*/log_format = ENRICHED/' /etc/audit/auditd.conf 2>/dev/null || true
    fi
    
    # Set max log file size (500MB)
    sudo sed -i 's/^max_log_file = .*/max_log_file = 500/' /etc/audit/auditd.conf 2>/dev/null || true
    sudo sed -i 's/^max_log_file_action = .*/max_log_file_action = ROTATE/' /etc/audit/auditd.conf 2>/dev/null || true
    sudo sed -i 's/^num_logs = .*/num_logs = 5/' /etc/audit/auditd.conf 2>/dev/null || true
    
    # Configure audit rules
    echo "[*] Configuring audit rules..."
    
    # Backup existing rules
    if [[ -f /etc/audit/rules.d/audit.rules ]]; then
        sudo cp /etc/audit/rules.d/audit.rules /etc/audit/rules.d/audit.rules.backup.$(date +%Y%m%d) 2>/dev/null || true
    fi
    
    # Ask user which version to use
    echo ""
    echo "Audit rules source:"
    echo "  1) Use local version (from SWEET-Scripts repo)"
    echo "  2) Pull latest from Neo23x0/auditd (recommended)"
    echo ""
    echo -n "Select option [2]: "
    read -r rules_choice
    rules_choice="${rules_choice:-2}"
    
    local rules_file=""
    if [[ "$rules_choice" == "1" ]]; then
        # Use local version from SWEET-Scripts
        local local_rules="${SWEETS_DIR:-$HOME/.sweet-scripts}/audit.rules"
        if [[ -f "$local_rules" ]]; then
            rules_file="$local_rules"
            echo "[*] Using local audit.rules from SWEET-Scripts"
        else
            echo "[!] Local audit.rules not found, falling back to remote version"
            rules_choice="2"
        fi
    fi
    
    if [[ "$rules_choice" == "2" ]] || [[ -z "$rules_file" ]]; then
        # Pull latest from Neo23x0
        echo "[*] Downloading latest audit.rules from Neo23x0/auditd..."
        local temp_rules=$(mktemp)
        if curl -fsSL https://raw.githubusercontent.com/Neo23x0/auditd/master/audit.rules -o "$temp_rules" 2>/dev/null; then
            rules_file="$temp_rules"
            echo "[+] Downloaded latest audit.rules from Neo23x0"
        else
            echo "[!] Failed to download from Neo23x0, trying local version..."
            local local_rules="${SWEETS_DIR:-$HOME/.sweet-scripts}/audit.rules"
            if [[ -f "$local_rules" ]]; then
                rules_file="$local_rules"
                echo "[*] Using local audit.rules as fallback"
            else
                echo "[!] No audit rules available. Using basic configuration."
                rules_file=""
            fi
        fi
    fi
    
    if [[ -n "$rules_file" ]] && [[ -f "$rules_file" ]]; then
        # Copy rules file to audit directory
        sudo cp "$rules_file" /etc/audit/rules.d/audit.rules
        sudo chmod 640 /etc/audit/rules.d/audit.rules
        echo "[+] Audit rules installed from: $([ "$rules_choice" == "1" ] && echo "local" || echo "Neo23x0/auditd")"
        
        # Clean up temp file if used
        [[ "$rules_file" =~ ^/tmp/ ]] && rm -f "$rules_file" 2>/dev/null || true
    else
        echo "[!] Using basic audit configuration"
        # Fallback to basic rules
        {
            echo "# Basic audit rules (fallback)"
            echo "-D"
            echo "-b 8192"
            echo "-f 1"
        } | sudo tee /etc/audit/rules.d/audit.rules >/dev/null
    fi
    
    # Enable and start services
    echo "[*] Enabling services..."
    sudo systemctl enable auditd
    sudo systemctl restart auditd
    [[ "$rsyslog_installed" == true ]] && sudo systemctl enable rsyslog && sudo systemctl restart rsyslog
    
    echo ""
    echo "[+] Security hardening complete!"
    echo ""
    echo "Configured:"
    echo "  ✓ auditd enabled with comprehensive rules"
    echo "  ✓ rsyslog installed and enabled"
    echo "  ✓ Audit rules based on CIS Benchmark"
    echo ""
    echo "View audit logs: sudo ausearch -k <key>"
    echo "View recent events: sudo ausearch -m all -ts recent"
}

# =============================================================================
# SSH KEY MANAGEMENT
# =============================================================================
sweets-ssh-import() {
    local source="$1"
    local target_user="${2:-root}"
    local target_home
    local auth_file
    
    if [[ -z "$source" ]]; then
        echo "Usage: sweets-ssh-import <github-username|url> [target-user]"
        echo ""
        echo "Examples:"
        echo "  sweets-ssh-import myuser              # Import from github.com/myuser.keys"
        echo "  sweets-ssh-import myuser \$USER        # Add to current user"
        echo "  sweets-ssh-import https://example.com/keys.pub root"
        echo ""
        echo "This fetches public keys and adds them to authorized_keys."
        return 1
    fi
    
    # Determine target home directory
    if [[ "$target_user" == "root" ]]; then
        target_home="/root"
    else
        target_home=$(eval echo "~$target_user")
    fi
    auth_file="$target_home/.ssh/authorized_keys"
    
    # Build URL
    local url="$source"
    if [[ ! "$source" =~ ^https?:// ]]; then
        # Assume GitHub username
        url="https://github.com/${source}.keys"
    fi
    
    echo "[*] Fetching keys from: $url"
    
    # Fetch keys
    local keys
    keys=$(curl -fsSL "$url" 2>/dev/null)
    
    if [[ -z "$keys" ]]; then
        echo "[!] No keys found or failed to fetch"
        return 1
    fi
    
    local key_count
    key_count=$(echo "$keys" | wc -l)
    
    echo ""
    echo "[i] Found $key_count key(s):"
    echo "$keys" | head -3 | while read -r line; do
        echo "    ${line:0:60}..."
    done
    [[ $key_count -gt 3 ]] && echo "    ... and $((key_count - 3)) more"
    echo ""
    echo "[!] These keys will be added to: $auth_file"
    echo "[!] Target user: $target_user"
    echo ""
    echo -n "Proceed? (y/N): "
    read -r confirm
    
    if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
        echo "Cancelled."
        return 1
    fi
    
    # Create .ssh directory if needed
    if [[ "$target_user" == "root" ]]; then
        sudo mkdir -p "$target_home/.ssh"
        sudo chmod 700 "$target_home/.ssh"
        
        # Add keys (avoiding duplicates)
        echo "$keys" | while read -r key; do
            if ! sudo grep -qF "$key" "$auth_file" 2>/dev/null; then
                echo "$key" | sudo tee -a "$auth_file" >/dev/null
            fi
        done
        
        sudo chmod 600 "$auth_file"
        sudo chown -R root:root "$target_home/.ssh"
    else
        mkdir -p "$target_home/.ssh"
        chmod 700 "$target_home/.ssh"
        
        echo "$keys" | while read -r key; do
            if ! grep -qF "$key" "$auth_file" 2>/dev/null; then
                echo "$key" >> "$auth_file"
            fi
        done
        
        chmod 600 "$auth_file"
    fi
    
    echo "[+] Keys added to $auth_file"
}

alias sshimport='sweets-ssh-import'

# =============================================================================
# INTERACTIVE MENU
# =============================================================================
sweets-menu() {
    local choice
    while true; do
        clear
        echo -e "\033[36m\033[1m━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\033[0m"
        echo -e "\033[1m  SWEET-Scripts v${SWEETS_VERSION}\033[0m"
        echo -e "\033[36m━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\033[0m"
        echo ""
        echo -e "\033[32m  QUICK SETUP\033[0m"
        echo "  0) Auto Setup (Apply Sane Defaults)"
        echo ""
        echo -e "\033[33m  INFORMATION\033[0m"
        echo "  1) Show all aliases & shortcuts"
        echo "  2) Show keyboard shortcuts"
        echo "  3) Show system info"
        echo ""
        echo -e "\033[33m  CREDENTIALS\033[0m"
        echo "  4) Add credential"
        echo "  5) List credentials"
        echo "  6) Remove credential"
        echo ""
        echo -e "\033[33m  NETWORK\033[0m"
        echo "  7) Show IP addresses"
        echo "  8) Show open ports (listening)"
        echo ""
        echo -e "\033[33m  TOOLS\033[0m"
        echo "  10) Setup Tailscale"
        echo "  11) Import SSH keys"
        echo "  12) Install dependencies"
        echo "  13) Show package list"
        echo "  14) Toggle UV (Python package manager)"
        echo "  15) Setup Syslog Forwarding"
        echo "  16) Security Hardening (auditd + syslog)"
        echo ""
        echo -e "\033[33m  TROUBLESHOOTING\033[0m"
        echo "  17) Docker & Docker Compose Diagnostics"
        echo ""
        echo -e "\033[33m  SWEETS\033[0m"
        echo "  u) Update SWEET-Scripts"
        echo "  h) Full help"
        echo "  q) Quit menu"
        echo ""
        echo -n "  Select option: "
        read -r choice
        
        case $choice in
            0)
                clear
                echo -e "\033[36m\033[1m=== Auto Setup - Sane Defaults ===\033[0m"
                echo ""
                echo "This will apply the following defaults:"
                echo ""
                echo -e "\033[1mConfiguration:\033[0m"
                echo "  • Enable UV if available (fast Python package manager)"
                echo "  • Setup clipboard integration (X11/Wayland)"
                echo "  • Configure WSL if detected (X11 DISPLAY, GPU auto-detect)"
                echo "  • Enable Docker group membership (if Docker installed)"
                echo "  • Setup basic systemd optimizations"
                echo ""
                echo -e "\033[1mOptional (will prompt):\033[0m"
                echo "  • Install recommended dependencies"
                echo "  • Setup syslog forwarding (if domain detected)"
                echo ""
                echo -n "Proceed with auto setup? (y/N): "
                read -r confirm
                if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
                    echo "Cancelled."
                    sleep 1
                    continue
                fi
                
                echo ""
                echo -e "\033[32m[*] Applying defaults...\033[0m"
                
                # Enable UV if available
                if command -v uv &>/dev/null; then
                    export SWEETS_USE_UV="true"
                    echo -e "\033[32m[+] UV enabled\033[0m"
                else
                    echo -e "\033[33m[!] UV not installed (optional)\033[0m"
                fi
                
                # WSL setup (already done on load, but confirm)
                if [[ "$SWEETS_WSL" == "true" ]]; then
                    echo -e "\033[32m[+] WSL detected and configured\033[0m"
                fi
                
                # Docker group check
                if command -v docker &>/dev/null && ! groups 2>/dev/null | grep -qw docker; then
                    echo -e "\033[33m[!] Add user to docker group: sudo usermod -aG docker \$USER\033[0m"
                fi
                
                # Ask about dependencies
                echo ""
                echo -n "Install recommended dependencies? (y/N): "
                read -r deps_confirm
                if [[ "$deps_confirm" =~ ^[Yy]$ ]]; then
                    local install_script="${SWEETS_DIR:-$HOME/.sweet-scripts}/install.sh"
                    if [[ -f "$install_script" ]]; then
                        bash "$install_script" --skip-zsh
                    fi
                fi
                
                # Ask about syslog if domain detected
                local domain=$(hostname -d 2>/dev/null || hostname -f 2>/dev/null | cut -d. -f2-)
                if [[ -n "$domain" ]] && [[ "$domain" != "local" ]] && [[ "$domain" != "localhost" ]]; then
                    echo ""
                    echo -n "Setup syslog forwarding to syslog.${domain}:514? (y/N): "
                    read -r syslog_confirm
                    if [[ "$syslog_confirm" =~ ^[Yy]$ ]]; then
                        echo "*.* @syslog.${domain}:514" | sudo tee -a /etc/rsyslog.conf >/dev/null 2>/dev/null
                        sudo systemctl restart rsyslog 2>/dev/null
                        echo -e "\033[32m[+] Syslog forwarding configured\033[0m"
                    fi
                fi
                
                echo ""
                echo -e "\033[32m[+] Auto setup complete!\033[0m"
                echo "Note: Some changes require shell reload: source ~/.${SWEETS_SHELL}rc"
                echo ""
                echo -e "\033[33mPress Enter to continue...\033[0m"
                read -r
                ;;
            1)
                clear
                sweets-help
                echo ""
                echo -e "\033[33mPress Enter to continue...\033[0m"
                read -r
                ;;
            2)
                clear
                sweets-keys
                echo ""
                echo -e "\033[33mPress Enter to continue...\033[0m"
                read -r
                ;;
            3)
                clear
                echo -e "\033[36m\033[1m=== System Information ===\033[0m"
                echo ""
                echo -e "\033[1mOS:\033[0m $(cat /etc/os-release 2>/dev/null | grep PRETTY_NAME | cut -d'"' -f2)"
                echo -e "\033[1mKernel:\033[0m $(uname -r)"
                echo -e "\033[1mHostname:\033[0m $(hostname)"
                echo -e "\033[1mUptime:\033[0m $(uptime -p 2>/dev/null || uptime)"
                echo -e "\033[1mShell:\033[0m $SWEETS_SHELL"
                echo ""
                echo -e "\033[1mCPU:\033[0m $(grep 'model name' /proc/cpuinfo 2>/dev/null | head -1 | cut -d':' -f2 | xargs)"
                echo -e "\033[1mMemory:\033[0m $(free -h 2>/dev/null | awk '/^Mem:/{print $3 "/" $2}')"
                echo -e "\033[1mDisk:\033[0m $(df -h / 2>/dev/null | awk 'NR==2{print $3 "/" $2 " (" $5 " used)"}')"
                echo ""
                echo -e "\033[1mPublic IP:\033[0m $(curl -s --connect-timeout 3 ifconfig.me 2>/dev/null || echo 'N/A')"
                echo -e "\033[1mLocal IP:\033[0m $(_sweets_localip)"
                echo ""
                echo -e "\033[33mPress Enter to continue...\033[0m"
                read -r
                ;;
            4)
                clear
                echo -e "\033[36m\033[1m=== Add Credential ===\033[0m"
                echo ""
                echo -e "\033[1mHow credentials work:${NC}"
                echo "  Credentials are stored as environment variables in:"
                echo "  $SWEETS_CREDS_FILE"
                echo ""
                echo "  They are automatically loaded when you start a new shell."
                echo "  Access them with: \${CRED_NAME}"
                echo ""
                echo "  Example:"
                echo "    sweets-add-cred API_KEY"
                echo "    # Then use: echo \$API_KEY"
                echo ""
                echo -e "\033[33m─────────────────────────────────────────────\033[0m"
                echo ""
                echo -n "Enter credential name: "
                read -r cred_name
                if [[ -n "$cred_name" ]]; then
                    sweets-add-cred "$cred_name"
                fi
                echo ""
                echo -e "\033[33mPress Enter to continue...\033[0m"
                read -r
                ;;
            5)
                clear
                echo -e "\033[36m\033[1m=== Stored Credentials ===\033[0m"
                echo ""
                sweets-list-creds
                echo ""
                echo -e "\033[1mHow to use credentials:${NC}"
                echo "  Credentials are stored as environment variables in:"
                echo "  $SWEETS_CREDS_FILE"
                echo ""
                echo "  They are automatically loaded when you start a new shell."
                echo "  Access them with: \${CRED_NAME}"
                echo ""
                echo "  Example:"
                echo "    sweets-add-cred API_KEY"
                echo "    # Then use: echo \$API_KEY"
                echo ""
                echo -e "\033[33mPress Enter to continue...\033[0m"
                read -r
                ;;
            6)
                clear
                echo -e "\033[36m\033[1m=== Remove Credential ===\033[0m"
                echo ""
                sweets-list-creds
                echo ""
                echo -n "Enter credential name to remove: "
                read -r cred_name
                if [[ -n "$cred_name" ]]; then
                    sweets-remove-cred "$cred_name"
                fi
                echo ""
                echo -e "\033[33mPress Enter to continue...\033[0m"
                read -r
                ;;
            7)
                clear
                echo -e "\033[36m\033[1m=== IP Addresses ===\033[0m"
                echo ""
                echo -e "\033[1mPublic IPv4:\033[0m $(curl -s --connect-timeout 3 ifconfig.me 2>/dev/null || echo 'N/A')"
                echo -e "\033[1mPublic IPv6:\033[0m $(curl -s --connect-timeout 3 ifconfig.me/ip6 2>/dev/null || echo 'N/A')"
                echo ""
                echo -e "\033[1mLocal Interfaces:\033[0m"
                ip -c addr 2>/dev/null || ifconfig 2>/dev/null || echo "No network tools available"
                echo ""
                echo -e "\033[33mPress Enter to continue...\033[0m"
                read -r
                ;;
            8)
                clear
                echo -e "\033[36m\033[1m=== Listening Ports and Processes ===\033[0m"
                echo ""
                echo "Listening ports with processes:"
                echo ""
                (ss -tulnp 2>/dev/null || netstat -tulnp 2>/dev/null) | grep LISTEN || echo "No network tools available"
                echo ""
                echo -e "\033[33mPress Enter to continue...\033[0m"
                read -r
                ;;
            10)
                clear
                echo -e "\033[36m\033[1m=== Tailscale ===\033[0m"
                echo ""
                if command -v tailscale &>/dev/null; then
                    echo "Status:"
                    tailscale status
                    echo ""
                    echo "IP: $(tailscale ip -4 2>/dev/null || echo 'Not connected')"
                    echo ""
                    echo "Quick commands:"
                    echo "  sudo tailscale up              # Connect"
                    echo "  sudo tailscale down            # Disconnect"
                    echo "  tailscale status               # Show status"
                    echo "  tailscale ip -4                # Show IP"
                else
                    echo "Tailscale not installed."
                    echo ""
                    echo "Install Tailscale:"
                    echo "  1) Install from official repo (recommended)"
                    echo "  2) Install using curl script"
                    echo "  3) Cancel"
                    echo ""
                    echo -n "Select option: "
                    read -r install_choice
                    
                    case "$install_choice" in
                        1)
                            echo ""
                            echo "Installing Tailscale from official repository..."
                            case "$SWEETS_DISTRO" in
                                ubuntu|debian|pop|linuxmint)
                                    curl -fsSL https://pkgs.tailscale.com/stable/ubuntu/jammy.noarmor.gpg | sudo tee /usr/share/keyrings/tailscale-archive-keyring.gpg >/dev/null
                                    curl -fsSL https://pkgs.tailscale.com/stable/ubuntu/jammy.tailscale-keyring.list | sudo tee /etc/apt/sources.list.d/tailscale.list >/dev/null
                                    sudo apt update && sudo apt install -y tailscale
                                    ;;
                                rhel|centos|rocky|almalinux|fedora)
                                    sudo dnf config-manager --add-repo https://pkgs.tailscale.com/stable/fedora/tailscale.repo 2>/dev/null || \
                                    sudo yum-config-manager --add-repo https://pkgs.tailscale.com/stable/rhel/8/tailscale.repo 2>/dev/null || true
                                    sudo dnf install -y tailscale 2>/dev/null || sudo yum install -y tailscale
                                    ;;
                                *)
                                    echo "Unknown distro, using curl installer..."
                                    curl -fsSL https://tailscale.com/install.sh | sh
                                    ;;
                            esac
                            
                            echo ""
                            echo "[+] Starting tailscaled..."
                            sudo systemctl enable --now tailscaled
                            sleep 2
                            
                            echo ""
                            echo -n "Enter auth key to connect (or press Enter to skip): "
                            read -r ts_key
                            if [[ -n "$ts_key" ]]; then
                                echo ""
                                echo -n "Enable DNS? (y/N): "
                                read -r dns_choice
                                if [[ "$dns_choice" =~ ^[Yy]$ ]]; then
                                    sudo tailscale up --authkey="$ts_key" --accept-dns
                                else
                                    sudo tailscale up --authkey="$ts_key" --accept-dns=false
                                fi
                                echo ""
                                echo "[+] Tailscale connected!"
                                tailscale status
                            else
                                echo ""
                                echo "To connect later, run: sudo tailscale up --authkey=<your-key>"
                            fi
                            ;;
                        2)
                            echo ""
                            echo "Installing using official installer script..."
                            curl -fsSL https://tailscale.com/install.sh | sh
                            echo ""
                            echo "To connect, run: sudo tailscale up --authkey=<your-key>"
                            ;;
                        *)
                            echo "Cancelled."
                            ;;
                    esac
                fi
                echo ""
                echo -e "\033[33mPress Enter to continue...\033[0m"
                read -r
                ;;
            11)
                clear
                echo -e "\033[36m\033[1m=== Import SSH Keys ===\033[0m"
                echo ""
                echo "Import public keys from GitHub or URL to authorized_keys."
                echo ""
                echo -n "GitHub username or URL: "
                read -r ssh_source
                if [[ -n "$ssh_source" ]]; then
                    echo ""
                    echo "Target user (default: root):"
                    echo -n "> "
                    read -r ssh_target
                    [[ -z "$ssh_target" ]] && ssh_target="root"
                    
                    sweets-ssh-import "$ssh_source" "$ssh_target"
                fi
                echo ""
                echo -e "\033[33mPress Enter to continue...\033[0m"
                read -r
                ;;
            12)
                clear
                echo -e "\033[36m\033[1m=== Install Dependencies ===\033[0m"
                echo ""
                local install_script="${SWEETS_DIR:-$HOME/.sweet-scripts}/install.sh"
                if [[ -f "$install_script" ]]; then
                    echo "This will install recommended packages."
                    echo -n "Continue? (y/N): "
                    read -r confirm
                    if [[ "$confirm" =~ ^[Yy]$ ]]; then
                        bash "$install_script" --skip-zsh
                    fi
                else
                    echo "Install script not found."
                fi
                echo ""
                echo -e "\033[33mPress Enter to continue...\033[0m"
                read -r
                ;;
            13)
                clear
                local install_script="${SWEETS_DIR:-$HOME/.sweet-scripts}/install.sh"
                if [[ -f "$install_script" ]]; then
                    bash "$install_script" --show-packages
                    echo ""
                    echo "Options:"
                    echo "  1) Install missing packages only"
                    echo "  2) Install ALL packages from list"
                    echo "  3) Interactive package selection (choose individual packages)"
                    echo "  4) Cancel"
                    echo ""
                    echo -n "Select option: "
                    read -r install_choice
                    if [[ "$install_choice" == "1" ]]; then
                        echo ""
                        echo "Installing missing dependencies..."
                        bash "$install_script" --skip-zsh
                    elif [[ "$install_choice" == "2" ]]; then
                        echo ""
                        echo "Installing ALL packages from list..."
                        bash "$install_script" --skip-zsh
                        # Also try to install modern CLI tools
                        echo ""
                        echo "[*] Installing modern CLI tools..."
                        case "$SWEETS_DISTRO" in
                            ubuntu|debian|pop|linuxmint)
                                sudo apt install -y bat fd-find ripgrep fzf btop 2>/dev/null || true
                                ;;
                            rhel|centos|rocky|almalinux|fedora)
                                sudo dnf install -y bat fd-find ripgrep fzf btop 2>/dev/null || true
                                ;;
                        esac
                        echo ""
                        echo "[*] Note: Some packages require manual installation (see list above)"
                    elif [[ "$install_choice" == "3" ]]; then
                        echo ""
                        bash "$install_script" --install-packages
                    fi
                else
                    echo "Install script not found."
                fi
                echo ""
                echo -e "\033[33mPress Enter to continue...\033[0m"
                read -r
                ;;
            14)
                clear
                echo -e "\033[36m\033[1m=== UV Toggle ===\033[0m"
                echo ""
                echo "Current UV status: $SWEETS_USE_UV"
                echo ""
                sweets-uv-toggle
                echo ""
                echo -e "\033[33mPress Enter to continue...\033[0m"
                read -r
                ;;
            15)
                clear
                echo -e "\033[36m\033[1m=== Syslog Forwarding Setup ===\033[0m"
                echo ""
                sweets-syslog-setup
                echo ""
                echo -e "\033[33mPress Enter to continue...\033[0m"
                read -r
                ;;
            16)
                clear
                echo -e "\033[36m\033[1m=== Security Hardening ===\033[0m"
                echo ""
                sweets-security-setup
                echo ""
                echo -e "\033[33mPress Enter to continue...\033[0m"
                read -r
                ;;
            17)
                clear
                echo -e "\033[36m\033[1m=== Docker & Docker Compose Diagnostics ===\033[0m"
                echo ""
                
                # Check Docker installation
                echo -e "\033[1mDocker Installation:\033[0m"
                if command -v docker &>/dev/null; then
                    local docker_version
                    docker_version=$(docker --version 2>/dev/null || echo "Unknown")
                    echo -e "  ${GREEN}✓${NC} Docker installed: $docker_version"
                else
                    echo -e "  ${RED}✗${NC} Docker not installed"
                    echo -e "  ${YELLOW}[*]${NC} Install with: bash \$SWEETS_DIR/install.sh --install-docker"
                fi
                echo ""
                
                # Check Docker Compose
                echo -e "\033[1mDocker Compose:\033[0m"
                if docker compose version &>/dev/null 2>&1; then
                    local compose_version
                    compose_version=$(docker compose version 2>/dev/null | head -1 || echo "Unknown")
                    echo -e "  ${GREEN}✓${NC} Docker Compose installed: $compose_version"
                elif command -v docker-compose &>/dev/null; then
                    local compose_version
                    compose_version=$(docker-compose --version 2>/dev/null || echo "Unknown")
                    echo -e "  ${YELLOW}⚠${NC} Legacy docker-compose found: $compose_version"
                    echo -e "  ${YELLOW}[*]${NC} Consider using 'docker compose' (plugin) instead"
                else
                    echo -e "  ${RED}✗${NC} Docker Compose not found"
                fi
                echo ""
                
                # Check Docker service
                echo -e "\033[1mDocker Service:\033[0m"
                if command -v systemctl &>/dev/null; then
                    if systemctl is-active --quiet docker 2>/dev/null; then
                        echo -e "  ${GREEN}✓${NC} Docker service is running"
                    elif systemctl is-enabled --quiet docker 2>/dev/null; then
                        echo -e "  ${YELLOW}⚠${NC} Docker service is enabled but not running"
                        echo -e "  ${YELLOW}[*]${NC} Start with: sudo systemctl start docker"
                    else
                        echo -e "  ${RED}✗${NC} Docker service is not enabled"
                        echo -e "  ${YELLOW}[*]${NC} Enable with: sudo systemctl enable --now docker"
                    fi
                else
                    echo -e "  ${YELLOW}[*]${NC} systemctl not available (check service manually)"
                fi
                echo ""
                
                # Check Docker daemon connectivity
                echo -e "\033[1mDocker Daemon:\033[0m"
                if docker info &>/dev/null 2>&1; then
                    echo -e "  ${GREEN}✓${NC} Docker daemon is accessible"
                elif sudo docker info &>/dev/null 2>&1; then
                    echo -e "  ${YELLOW}⚠${NC} Docker daemon requires sudo"
                    echo -e "  ${YELLOW}[*]${NC} Add user to docker group: sudo usermod -aG docker \$USER"
                    echo -e "  ${YELLOW}[*]${NC} Then log out and back in, or run: newgrp docker"
                else
                    echo -e "  ${RED}✗${NC} Cannot connect to Docker daemon"
                    echo -e "  ${YELLOW}[*]${NC} Check if service is running: sudo systemctl status docker"
                    echo -e "  ${YELLOW}[*]${NC} Check logs: sudo journalctl -u docker -n 30"
                fi
                echo ""
                
                # Check user in docker group
                echo -e "\033[1mUser Permissions:\033[0m"
                if groups 2>/dev/null | grep -qw docker; then
                    echo -e "  ${GREEN}✓${NC} User is in docker group"
                else
                    echo -e "  ${YELLOW}⚠${NC} User is NOT in docker group"
                    echo -e "  ${YELLOW}[*]${NC} Add with: sudo usermod -aG docker \$USER"
                    echo -e "  ${YELLOW}[*]${NC} Then log out and back in, or run: newgrp docker"
                fi
                echo ""
                
                # Test Docker functionality
                echo -e "\033[1mDocker Test:\033[0m"
                if docker run --rm hello-world &>/dev/null 2>&1; then
                    echo -e "  ${GREEN}✓${NC} Docker hello-world test passed"
                elif sudo docker run --rm hello-world &>/dev/null 2>&1; then
                    echo -e "  ${YELLOW}⚠${NC} Docker works with sudo (user not in docker group)"
                else
                    echo -e "  ${RED}✗${NC} Docker hello-world test failed"
                    echo -e "  ${YELLOW}[*]${NC} Check service status and logs"
                fi
                echo ""
                
                echo -e "\033[33mPress Enter to continue...\033[0m"
                read -r
                ;;
            u|U)
                clear
                sweets-update
                echo ""
                echo -e "\033[33mPress Enter to continue...\033[0m"
                read -r
                ;;
            h|H)
                clear
                sweets-help
                echo ""
                echo -e "\033[33mPress Enter to continue...\033[0m"
                read -r
                ;;
            q|Q|0)
                clear
                return 0
                ;;
            *)
                echo -e "\033[31mInvalid option\033[0m"
                sleep 1
                ;;
        esac
    done
}

# Alias for menu
alias sweets='sweets-menu'

# Alias for compatibility
alias sweet-update='sweets-update'

# =============================================================================
# SHELL-SPECIFIC SETUP
# =============================================================================
if [[ "$SWEETS_SHELL" == "zsh" ]]; then
    # ZSH completions
    autoload -Uz compinit
    if [[ -n ${ZDOTDIR}/.zcompdump(#qN.mh+24) ]]; then
        compinit
    else
        compinit -C
    fi
    
    zstyle ':completion:*' menu select
    zstyle ':completion:*' matcher-list 'm:{a-zA-Z}={A-Za-z}'
    zstyle ':completion:*' list-colors "${(s.:.)LS_COLORS}"
    
    # kubectl completion
    command -v kubectl &>/dev/null && source <(kubectl completion zsh 2>/dev/null) && compdef k=kubectl
    
    # History settings
    HISTFILE=~/.zsh_history
    HISTSIZE=50000
    SAVEHIST=50000
    setopt EXTENDED_HISTORY HIST_IGNORE_DUPS HIST_IGNORE_SPACE SHARE_HISTORY
    
    # Use emacs-style keybindings (Ctrl+A, Ctrl+E, etc.)
    bindkey -e
    
    # History search with up/down (searches based on current input)
    bindkey '^[[A' history-search-backward
    bindkey '^[[B' history-search-forward
    
    # Word navigation: Alt+B, Alt+F (default in emacs mode)
    bindkey '^[b' backward-word
    bindkey '^[f' forward-word
    
    # Ctrl+Left/Right for word navigation
    bindkey '^[[1;5D' backward-word
    bindkey '^[[1;5C' forward-word
    
    # Enable Ctrl+S for forward history search (disable flow control)
    stty -ixon 2>/dev/null
    bindkey '^S' history-incremental-search-forward
    
    # Home/End keys
    bindkey '^[[H' beginning-of-line
    bindkey '^[[F' end-of-line
    bindkey '^[[1~' beginning-of-line
    bindkey '^[[4~' end-of-line
    
    # Delete key
    bindkey '^[[3~' delete-char
    
elif [[ "$SWEETS_SHELL" == "bash" ]]; then
    # Bash completions
    if [[ -f /etc/bash_completion ]]; then
        . /etc/bash_completion
    elif [[ -f /usr/share/bash-completion/bash_completion ]]; then
        . /usr/share/bash-completion/bash_completion
    fi
    
    # kubectl completion
    command -v kubectl &>/dev/null && source <(kubectl completion bash 2>/dev/null) && complete -F __start_kubectl k
    
    # Docker completion
    if [[ -f /usr/share/bash-completion/completions/docker ]]; then
        . /usr/share/bash-completion/completions/docker
    fi
    
    # History settings
    HISTSIZE=50000
    HISTFILESIZE=50000
    HISTCONTROL=ignoreboth:erasedups
    shopt -s histappend
    
    # Better globbing
    shopt -s globstar 2>/dev/null
    
    # Enable Ctrl+S for forward history search
    stty -ixon 2>/dev/null
    
    # Word navigation with Ctrl+Left/Right
    bind '"\e[1;5D": backward-word' 2>/dev/null
    bind '"\e[1;5C": forward-word' 2>/dev/null
fi

# Git completion alias
command -v git &>/dev/null && command -v __git_complete &>/dev/null && __git_complete g __git_main 2>/dev/null

# Terraform completion
if command -v terraform &>/dev/null; then
    complete -C terraform terraform 2>/dev/null
    complete -C terraform tf 2>/dev/null
fi
