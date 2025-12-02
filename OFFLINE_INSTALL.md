# Offline Installation Guide for CTF Servers

This guide explains how to install SWEET-Scripts on a CTF (Capture The Flag) server that doesn't have public internet access.

## Method 1: Direct File Transfer (Recommended)

### Step 1: Prepare Files on Your Machine

```bash
# Clone or download SWEET-Scripts
git clone https://github.com/sweets9/SWEET-Scripts.git
cd SWEET-Scripts

# Create a tarball for easy transfer
tar -czf sweet-scripts-offline.tar.gz \
    sweets.sh \
    install-offline.sh \
    uninstall.sh \
    LICENSE \
    README.md
```

### Step 2: Transfer to CTF Server

Transfer the tarball to your CTF server using one of these methods:

**Option A: SCP (if SSH access available)**
```bash
scp sweet-scripts-offline.tar.gz user@ctf-server:/tmp/
```

**Option B: USB Drive**
```bash
# Copy to USB drive, then mount on CTF server
```

**Option C: Local Network Transfer**
```bash
# If CTF server is on same network
# Use local file sharing, network mount, etc.
```

### Step 3: Install on CTF Server

```bash
# Extract files
cd /tmp  # or wherever you transferred
tar -xzf sweet-scripts-offline.tar.gz
cd SWEET-Scripts  # or extracted directory

# Make installer executable
chmod +x install-offline.sh

# Run offline installer
./install-offline.sh
```

### Step 4: Activate

```bash
# Reload shell
source ~/.bashrc
# or
source ~/.zshrc

# Test installation
sweets-help
```

## Method 2: Manual Installation

If you prefer manual installation:

```bash
# 1. Create installation directory
mkdir -p ~/.sweet-scripts

# 2. Copy sweets.sh
cp sweets.sh ~/.sweet-scripts/

# 3. Add to shell rc file
cat >> ~/.bashrc << 'EOF'
# SWEET-Scripts
export SWEETS_DIR="$HOME/.sweet-scripts"
if [[ -f "$SWEETS_DIR/sweets.sh" ]]; then
    source "$SWEETS_DIR/sweets.sh"
fi
EOF

# 4. Reload shell
source ~/.bashrc
```

## What Works Offline

✅ **Fully Functional:**
- All shell shortcuts and aliases
- Docker/Podman management
- Git shortcuts
- Systemd service management
- Clipboard integration
- Credential management
- File operations
- Network tools (if tools installed)

⚠️ **Limited (Requires Internet):**
- Tailscale installation (use pre-installed if available)
- SSH key imports from GitHub (use local files instead)
- Package installation via install.sh (install manually)
- Auto-updates (use manual updates)

## Offline Alternatives

### SSH Key Import (Instead of GitHub)

```bash
# Instead of: sweets-ssh-import username
# Use: Manually copy keys

# On your machine:
cat ~/.ssh/id_rsa.pub

# On CTF server:
echo "ssh-rsa AAAA..." >> ~/.ssh/authorized_keys
```

### Package Installation

Install required packages manually using local repositories or pre-downloaded packages:

```bash
# Ubuntu/Debian - Use local apt cache or offline packages
sudo dpkg -i package.deb

# RHEL/CentOS - Use local yum/dnf cache
sudo rpm -ivh package.rpm
```

### Tailscale

If Tailscale is already installed:
```bash
# Just use the commands directly
sudo tailscale up --authkey=<key>
tailscale status
```

## Troubleshooting

### "sweets: command not found"

```bash
# Check if installed
ls -la ~/.sweet-scripts/sweets.sh

# Check shell rc file
grep SWEETS ~/.bashrc ~/.zshrc

# Reload shell
source ~/.bashrc
```

### "Permission denied"

```bash
# Make scripts executable
chmod +x install-offline.sh
chmod +x ~/.sweet-scripts/sweets.sh
```

### Features Not Working

Some features require specific tools. Check if installed:

```bash
# Check for common tools
command -v docker && echo "Docker: OK" || echo "Docker: Not installed"
command -v git && echo "Git: OK" || echo "Git: Not installed"
command -v tmux && echo "Tmux: OK" || echo "Tmux: Not installed"
```

## Minimal Installation

For a minimal installation with just core features:

```bash
# Copy only sweets.sh
mkdir -p ~/.sweet-scripts
cp sweets.sh ~/.sweet-scripts/

# Add minimal config
echo 'export SWEETS_DIR="$HOME/.sweet-scripts"
source "$SWEETS_DIR/sweets.sh"' >> ~/.bashrc

source ~/.bashrc
```

## Verification

After installation, verify it works:

```bash
# Check version
sweets-info

# See help
sweets-help

# Open menu
sweets
```

## Updating Offline

To update SWEET-Scripts offline:

```bash
# 1. Get new version on your machine
git pull  # or download new version

# 2. Transfer new sweets.sh to CTF server
scp sweets.sh user@ctf-server:~/.sweet-scripts/

# 3. Reload shell on CTF server
source ~/.bashrc
```

## Security Note

For CTF servers, consider:
- Reviewing `sweets.sh` before installation
- Using read-only installation if possible
- Restricting file permissions
- Auditing what gets added to shell rc files

