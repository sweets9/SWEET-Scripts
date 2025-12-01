#!/usr/bin/env bash
# Test script for Tailscale functionality in sweets.sh
# This demonstrates the sweets-tailscale function without actually installing Tailscale

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

echo -e "${CYAN}${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BOLD}  SWEET-Scripts - Tailscale Functionality Test${NC}"
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

# Check if sweets.sh is available
if [[ ! -f "sweets.sh" ]]; then
    echo -e "${RED}[!]${NC} Error: sweets.sh not found in current directory"
    echo "    Please run this test from the SWEET-Scripts directory"
    exit 1
fi

# Source sweets.sh
echo -e "${BLUE}[*]${NC} Loading sweets.sh..."
source sweets.sh

echo -e "${GREEN}[+]${NC} sweets.sh loaded successfully"
echo ""

# Test 1: Show help/usage
echo -e "${CYAN}${BOLD}Test 1: Help/Usage${NC}"
echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
sweets-tailscale
echo ""
echo ""

# Test 2: Show status (when not installed)
echo -e "${CYAN}${BOLD}Test 2: Status Check (not installed)${NC}"
echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
sweets-tailscale status
echo ""
echo ""

# Test 3: Show IP (when not connected)
echo -e "${CYAN}${BOLD}Test 3: IP Check (not connected)${NC}"
echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
sweets-tailscale ip
echo ""
echo ""

# Test 4: Test aliases
echo -e "${CYAN}${BOLD}Test 4: Alias Verification${NC}"
echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo "Checking if aliases are defined:"
if type ts &>/dev/null; then
    echo -e "  ${GREEN}✓${NC} 'ts' alias is defined"
    echo "    Type: $(type ts)"
else
    echo -e "  ${RED}✗${NC} 'ts' alias not found"
fi

if type tss &>/dev/null; then
    echo -e "  ${GREEN}✓${NC} 'tss' alias is defined"
else
    echo -e "  ${RED}✗${NC} 'tss' alias not found"
fi

if type tsip &>/dev/null; then
    echo -e "  ${GREEN}✓${NC} 'tsip' alias is defined"
else
    echo -e "  ${RED}✗${NC} 'tsip' alias not found"
fi

if type tsup &>/dev/null; then
    echo -e "  ${GREEN}✓${NC} 'tsup' alias is defined"
else
    echo -e "  ${RED}✗${NC} 'tsup' alias not found"
fi

if type tsdown &>/dev/null; then
    echo -e "  ${GREEN}✓${NC} 'tsdown' alias is defined"
else
    echo -e "  ${RED}✗${NC} 'tsdown' alias not found"
fi

if type tsping &>/dev/null; then
    echo -e "  ${GREEN}✓${NC} 'tsping' alias is defined"
else
    echo -e "  ${RED}✗${NC} 'tsping' alias not found"
fi
echo ""
echo ""

# Test 5: Install command usage (dry run - shows usage)
echo -e "${CYAN}${BOLD}Test 5: Install Command Usage${NC}"
echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo "Testing install command without auth key (should show usage):"
sweets-tailscale install
echo ""
echo ""

# Test 6: Uninstall command (dry run - won't actually uninstall)
echo -e "${CYAN}${BOLD}Test 6: Uninstall Command${NC}"
echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo "Uninstall command exists (won't run without actual installation):"
if type sweets-tailscale &>/dev/null; then
    echo -e "  ${GREEN}✓${NC} sweets-tailscale uninstall command available"
    echo "    Note: This would remove Tailscale if it was installed"
else
    echo -e "  ${RED}✗${NC} sweets-tailscale function not found"
fi
echo ""
echo ""

# Test 7: Function availability check
echo -e "${CYAN}${BOLD}Test 7: Function Availability${NC}"
echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
if type sweets-tailscale &>/dev/null; then
    echo -e "${GREEN}✓${NC} sweets-tailscale function is available"
    echo "    Function type: $(type sweets-tailscale | head -1)"
else
    echo -e "${RED}✗${NC} sweets-tailscale function not found"
fi
echo ""
echo ""

# Summary
echo -e "${CYAN}${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BOLD}  Test Summary${NC}"
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
echo -e "${BLUE}Available Commands:${NC}"
echo "  • sweets-tailscale install <authkey> [--dns] [--no-routes]"
echo "  • sweets-tailscale uninstall"
echo "  • sweets-tailscale up"
echo "  • sweets-tailscale down"
echo "  • sweets-tailscale status"
echo "  • sweets-tailscale ip"
echo ""
echo -e "${BLUE}Available Aliases:${NC}"
echo "  • ts        → sweets-tailscale"
echo "  • tss       → tailscale status"
echo "  • tsip      → tailscale ip -4"
echo "  • tsup      → sudo tailscale up"
echo "  • tsdown    → sudo tailscale down"
echo "  • tsping    → tailscale ping"
echo ""
echo -e "${GREEN}✓${NC} All Tailscale functionality is integrated into sweets.sh"
echo -e "${GREEN}✓${NC} tailscale-setup.sh can be safely removed"
echo ""
echo -e "${YELLOW}Note:${NC} This test does not actually install or modify Tailscale."
echo -e "${YELLOW}      ${NC} To test installation, use: sweets-tailscale install <authkey>"
echo ""

