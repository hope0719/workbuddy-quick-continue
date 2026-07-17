#!/bin/bash
# Quick Continue - macOS uninstaller
# Usage: curl -fsSL https://raw.githubusercontent.com/hope0719/workbuddy-quick-continue/main/uninstall.sh | bash

set -e

PLIST_NAME="com.quickcontinue.daemon"
PLIST_PATH="$HOME/Library/LaunchAgents/${PLIST_NAME}.plist"
APP_DIR="$HOME/Applications/QuickContinue"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

info()  { echo -e "${GREEN}[✓]${NC} $1"; }
warn()  { echo -e "${YELLOW}[!]${NC} $1"; }

echo ""
echo "=========================================="
echo "  Quick Continue - Uninstaller"
echo "=========================================="
echo ""

# 1) Stop service
if launchctl list 2>/dev/null | grep -q "$PLIST_NAME"; then
    launchctl unload "$PLIST_PATH" 2>/dev/null || true
    info "Service stopped."
else
    warn "Service not running."
fi

# 2) Remove plist
if [ -f "$PLIST_PATH" ]; then
    rm -f "$PLIST_PATH"
    info "LaunchAgent removed."
fi

# 3) Remove app directory
if [ -d "$APP_DIR" ]; then
    rm -rf "$APP_DIR"
    info "Application removed: $APP_DIR"
fi

echo ""
echo -e "  ${GREEN}Uninstalled successfully.${NC}"
echo ""
