# SWEET-Scripts v2.0.0 - Changelog

## New Features

### WSL Support
- **Automatic WSL Detection**: Detects Windows Subsystem for Linux environment
- **X11 DISPLAY Setup**: Automatically configures DISPLAY variable for WSL
  - Detects Windows host IP from `/etc/resolv.conf`
  - Falls back to `WSL_HOST_IP` environment variable
  - Defaults to `:0.0` for WSL2
- **GPU Selector**: Choose between NVIDIA and Intel GPU for WSL
  - Auto-detection based on `nvidia-smi` availability
  - Manual selection: `gpu-select nvidia` or `gpu-select intel`
  - Sets appropriate environment variables (`__GLX_VENDOR_LIBRARY_NAME`)

### Enhanced Container Management
- **Docker/Podman Auto-Detection**: Automatically detects which container runtime is installed
- **Unified Aliases**: Same aliases work for both Docker and Podman
  - `d`, `dc`, `dps`, `dpsa`, `di`, `dex`, `dlogs`, `dprune`, etc.
- **Podman Support**: Full Podman support with `podman-compose`
- **Container Engine Export**: `SWEETS_CONTAINER_ENGINE` environment variable

### Systemd Enhancements
- **Status Reporting**: Color-coded status indicators (✓ green, ✗ red, ⚠ amber)
  - Shows success/failure after `start`, `stop`, `restart`, `enable`, `disable`
  - Displays helpful error messages with troubleshooting commands
- **Service Aliases**: Quick shortcuts for systemctl commands
  - `sc`, `sctl` → `systemctl`
  - `scs` → `systemctl status`
  - `scstart`, `scstop`, `screstart` → start/stop/restart
  - `scenable`, `scdisable` → enable/disable
  - `scdr` → `systemctl daemon-reload`
  - `scl`, `scls` → list units/services
  - `scfailed` → show failed services
  - `sclog` → `journalctl -u` (service logs)
- **Service Compatibility**: `service` and `svc` aliases for compatibility
- **Auto-Daemon-Reload Detection**: Warns if service file was recently modified
  - Checks if service file was changed within last 5 minutes
  - Suggests running `systemctl daemon-reload`
- **Startup Log Viewer**: Shows system health on shell startup
  - Displays count of failed services
  - Shows recent error log entries (last 5 minutes)
  - Can be disabled with `SWEETS_QUIET=1`

### Version Support Information
- Added supported version information to script header
- **Recommended**: Ubuntu 24.04 LTS, Fedora 40+
- **Supported**: Debian 12+, RHEL 9+, CentOS Stream 9+, Rocky Linux 9+, AlmaLinux 9+
- WSL2 support documented

## Improvements

### Docker Section
- Replaced hardcoded Docker aliases with auto-detection
- Added Podman support with full feature parity
- Enhanced `docker()` function to handle Podman
- Added more container management aliases (`dcp`, `dbuild`, `drun`, `dpull`, `dpush`, `dstats`)

### Systemd Section
- Enhanced `systemctl()` function with status reporting
- Added automatic daemon-reload detection
- Improved error messages with actionable suggestions
- Added startup health check

## Usage Examples

### WSL GPU Selection
```bash
# Auto-detect (default)
gpu-select auto

# Force NVIDIA
gpu-select nvidia

# Force Intel
gpu-select intel
```

### Container Management
```bash
# Works with both Docker and Podman
dps          # List containers
dc up        # Start compose stack
dlogs <name> # View logs
```

### Systemd Service Management
```bash
# Start service with status
scstart nginx
# Output: ✓ Service 'nginx' is active

# Or use full command
systemctl start nginx
# Output: ✓ Service 'nginx' is active

# Quick status check
scs nginx

# View service logs
sclog nginx

# Check failed services
scfailed
```

### Service File Warning
When you modify a service file and start it:
```
⚠ Warning: Service file was recently modified. You may need to run 'systemctl daemon-reload'
✓ Service 'myservice' is active
```

## Environment Variables

- `SWEETS_WSL` - Set to `true` if running in WSL, `false` otherwise
- `SWEETS_CONTAINER_ENGINE` - Set to `docker`, `podman`, or `none`
- `SWEETS_QUIET` - Set to `1` to disable startup log checks
- `SWEETS_LOG_CHECKED` - Internal flag to prevent duplicate log checks

## Backward Compatibility

All existing aliases and functions remain unchanged. New features are additive and don't break existing functionality.

