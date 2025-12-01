# SWEET-Scripts v2.0.1 - Improvements

## Key Changes

### 1. Auto-Remediation for systemctl
- **Automatic daemon-reload**: If a service command fails and the service file was recently modified (within 5 minutes), the script automatically runs `systemctl daemon-reload` and retries the command
- **Error Detection**: Checks service file modification time to detect when reload is needed
- **No Manual Intervention**: Users no longer need to remember to run daemon-reload

**Example:**
```bash
# Edit a service file, then start it
systemctl start myservice
# If it fails due to file changes:
# ⚠ Service file changed, running daemon-reload and retrying...
# ✓ Service 'myservice' is active
```

### 2. Logs Only on Failure
- **Conditional Log Display**: Service logs are only shown when a service fails to start
- **Recent Logs**: Shows last 5 lines of recent logs for failed services
- **Clean Success**: No output on successful operations

**Before:**
```bash
systemctl start nginx
✓ Service 'nginx' is active
  Run 'systemctl status nginx' or 'journalctl -u nginx' for details  # Always shown
```

**After:**
```bash
systemctl start nginx
# (No output on success)

systemctl start badservice
✗ Service 'badservice' failed to start
  Recent logs:
  [error messages here]
  Run 'systemctl status badservice' for full details
```

### 3. Reduced Aliases
- **Removed excessive systemctl aliases**: Kept only `sc` as a shortcut
- **Removed low-value aliases**: Cleaned up rarely-used shortcuts
- **Focus on Smart Wrappers**: Emphasis on auto-remediation over alias proliferation

**Removed:**
- `scs`, `scstart`, `scstop`, `screstart`, `screload`, `scenable`, `scdisable`, `scdr`, `scl`, `scls`, `scfailed`, `sclog`, `sctl`, `svc`
- `ghprv`, `ghprc`, `ghis`, `ghic`, `ghrepo` (GitHub CLI)
- `deact` (deactivate)
- `post`, `get`, `httpcode` (HTTP testing)
- `ns`, `rdns` (DNS)
- `pingd`, `mtr` (Network testing)
- `urldecode`, `urlencode`, `b64d`, `b64e`, `sha256`, `md5sum` (Dev tools)
- `topmem`, `topcpu`, `pstree`, `killall` (Process management)
- `kernlog`, `services`, `failed`, `uptime`, `users`, `lastlogin` (System)

**Kept Essential:**
- `sc` → systemctl (with auto-remediation)
- Core Git aliases
- Core Docker/Podman aliases
- Essential network and system tools

### 4. GPU Selector in WSL - How It Works

The `gpu-select` function configures GPU rendering in WSL:

**How it works:**
1. **NVIDIA GPU**: Sets `__GLX_VENDOR_LIBRARY_NAME=nvidia`
   - Tells WSL to use NVIDIA GPU drivers
   - Requires NVIDIA drivers installed in Windows
   - Works with WSL2 and NVIDIA CUDA support

2. **Intel GPU**: Unsets `__GLX_VENDOR_LIBRARY_NAME`
   - Uses Intel integrated graphics or software rendering
   - Fallback for systems without NVIDIA GPU

3. **Auto-Detection**: Checks for `nvidia-smi` command
   - If available and working → uses NVIDIA
   - Otherwise → uses Intel/software rendering

4. **WSLENV**: Ensures environment variables are passed from Windows to WSL

**Usage:**
```bash
gpu-select nvidia    # Force NVIDIA GPU
gpu-select intel     # Force Intel GPU
gpu-select auto      # Auto-detect (default)
```

**When to use:**
- Running GUI applications in WSL that need GPU acceleration
- Using CUDA/OpenGL applications
- Switching between integrated and discrete graphics

## Philosophy Changes

### Before: Alias Everything
- Created aliases for every possible command variation
- Users had to remember many shortcuts
- No automatic error handling

### After: Smart Wrappers
- Fewer aliases, more intelligent functions
- Auto-remediation of common issues
- Focus on making commands "just work"

## Migration Notes

If you were using removed aliases:
- `scstart service` → `systemctl start service` or `sc start service`
- `scs service` → `systemctl status service` or `sc status service`
- `sclog service` → `journalctl -u service`

The systemctl wrapper now handles auto-remediation, so you don't need as many shortcuts.

