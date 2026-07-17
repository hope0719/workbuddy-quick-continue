#!/bin/bash
# Quick Continue - macOS one-line installer
# Usage: curl -fsSL https://raw.githubusercontent.com/hope0719/workbuddy-quick-continue/main/install.sh | bash
#        curl -fsSL .../install.sh | bash -s -- --button   # With floating button

set -e

# Parse arguments
EXTRA_ARGS=""
for arg in "$@"; do
    case $arg in
        --button)
            EXTRA_ARGS="--button"
            ;;
    esac
done

REPO="hope0719/workbuddy-quick-continue"
BRANCH="main"
BASE_URL="https://raw.githubusercontent.com/${REPO}/${BRANCH}"

APP_DIR="$HOME/Applications/QuickContinue"
BINARY="$APP_DIR/quick_continue"
PLIST_NAME="com.quickcontinue.daemon"
PLIST_PATH="$HOME/Library/LaunchAgents/${PLIST_NAME}.plist"
SOURCE_URL="${BASE_URL}/src/mac/quick_continue.swift"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

info()  { echo -e "${GREEN}[✓]${NC} $1"; }
warn()  { echo -e "${YELLOW}[!]${NC} $1"; }
error() { echo -e "${RED}[✗]${NC} $1"; exit 1; }

echo ""
echo "=========================================="
echo "  Quick Continue - macOS Installer"
echo "=========================================="
echo ""

# 1) Check platform
if [[ "$(uname)" != "Darwin" ]]; then
    error "This installer is for macOS only."
fi

# 2) Check for Swift
if ! command -v swiftc &>/dev/null; then
    warn "Swift compiler not found."
    echo "  Install Xcode Command Line Tools first:"
    echo "    xcode-select --install"
    echo ""
    read -p "  Run xcode-select --install now? [y/N] " -n 1 -r
    echo ""
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        xcode-select --install
        echo "  Please re-run this installer after Xcode CLT is installed."
        exit 0
    else
        error "Swift compiler is required."
    fi
fi
info "Swift compiler found: $(swiftc --version | head -1)"

# 3) Stop and remove existing LaunchAgent
if launchctl list 2>/dev/null | grep -q "$PLIST_NAME"; then
    warn "Stopping existing LaunchAgent..."
    launchctl unload "$PLIST_PATH" 2>/dev/null || true
fi
if [ -f "$PLIST_PATH" ]; then
    rm -f "$PLIST_PATH"
fi
info "Cleaned up previous installation."

# 4) Create install directory
mkdir -p "$APP_DIR"
info "Install directory: $APP_DIR"

# 5) Download source
echo "  Downloading source..."
TMP_SOURCE=$(mktemp /tmp/quick_continue_XXXXXXXX.swift)
if curl -fsSL "$SOURCE_URL" -o "$TMP_SOURCE"; then
    info "Source downloaded."
else
    rm -f "$TMP_SOURCE"
    error "Failed to download source from $SOURCE_URL"
fi

# 6) Compile
echo "  Compiling (this may take a moment)..."
if swiftc -O \
    -framework CoreGraphics \
    -framework AppKit \
    -o "$BINARY" \
    "$TMP_SOURCE" 2>&1; then
    info "Compiled successfully."
else
    rm -f "$TMP_SOURCE"
    error "Compilation failed."
fi
rm -f "$TMP_SOURCE"
chmod +x "$BINARY"

# 7) Configure startup method based on mode
if [ -n "$EXTRA_ARGS" ]; then
    # ── Button mode: create launcher .app + Login Item ──
    # LaunchAgent has no GUI context, so we use a launcher .app instead.

    LAUNCHER_APP="$APP_DIR/QuickContinueLauncher.app"

    # Remove old launcher if exists
    rm -rf "$LAUNCHER_APP"

    # Create launcher .app using osacompile
    osacompile -o "$LAUNCHER_APP" <<APPLESCRIPT
do shell script "$BINARY --button > /dev/null 2>&1 &"
APPLESCRIPT

    # Codesign the .app (required for macOS to launch it)
    codesign --force --sign - "$LAUNCHER_APP" 2>/dev/null

    # Add to Login Items for auto-start at login
    osascript -e "tell application \"System Events\" to make login item at end with properties {path:\"$LAUNCHER_APP\", hidden:false}" 2>/dev/null

    info "Launcher app created and added to Login Items."

    # Start now
    open "$LAUNCHER_APP"
    info "Service started. Floating button should appear shortly."
else
    # ── Hotkey-only mode: use LaunchAgent (no GUI needed) ──
    mkdir -p "$HOME/Library/LaunchAgents"

    cat > "$PLIST_PATH" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>${PLIST_NAME}</string>
    <key>ProgramArguments</key>
    <array>
        <string>${BINARY}</string>
    </array>
    <key>RunAtLoad</key>
    <true/>
    <key>KeepAlive</key>
    <true/>
    <key>StandardOutPath</key>
    <string>${APP_DIR}/stdout.log</string>
    <key>StandardErrorPath</key>
    <string>${APP_DIR}/stderr.log</string>
</dict>
</plist>
PLIST
    info "LaunchAgent configured."

    launchctl load "$PLIST_PATH"
    info "Service started."
fi

# 8) Done
echo ""
echo "=========================================="
echo -e "  ${GREEN}Installation complete!${NC}"
echo "=========================================="
echo ""
echo "  Hotkey:  Cmd+Shift+J"
if [ -n "$EXTRA_ARGS" ]; then
    echo "  Button:  Floating button (bottom-right)"
fi
echo "  Action:  Type '继续' + Enter"
echo ""
if [ -n "$EXTRA_ARGS" ]; then
    echo "  Auto-start: Login Items (System Settings → General → Login Items)"
else
    echo "  Auto-start: Login (LaunchAgent)"
fi
echo ""
echo "  Commands:"
if [ -n "$EXTRA_ARGS" ]; then
    echo "    Stop:    pkill -f quick_continue"
    echo "    Start:   open $LAUNCHER_APP"
    echo "    Toggle:  Click the floating button to hide/show"
else
    echo "    Stop:    launchctl unload ~/Library/LaunchAgents/${PLIST_NAME}.plist"
    echo "    Start:   launchctl load ~/Library/LaunchAgents/${PLIST_NAME}.plist"
    echo "    Logs:    cat ${APP_DIR}/stdout.log"
fi
echo "    Uninstall: curl -fsSL ${BASE_URL}/uninstall.sh | bash"
echo ""
warn "First time? Grant Accessibility permission:"
echo "  System Settings → Privacy & Security → Accessibility"
echo ""
