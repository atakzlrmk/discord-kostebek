#!/bin/bash

# Discord Kostebek - Temporary Session Runner
# Runs SpoofDPI in the foreground with system proxy configured.
# Cleans up proxy settings on exit (Ctrl+C).

BIN_DIR="$HOME/.local/bin"
SPOOFDPI="$BIN_DIR/spoofdpi"
BASE_DIR="$(cd "$(dirname "$0")" && pwd)"
export PATH="$BIN_DIR:/usr/local/bin:$PATH"

# Find active network service
get_service_name() {
    local iface=$(route get default 2>/dev/null | grep interface | awk '{print $2}')
    if [ -n "$iface" ]; then
        networksetup -listnetworkserviceorder 2>/dev/null \
            | grep -B 1 "Device: $iface" \
            | head -n 1 \
            | sed -E 's/^\(\*?[0-9]+\) //'
    else
        echo "Wi-Fi"
    fi
}

SERVICE_NAME=$(get_service_name)

# Handle "stop" argument
if [ "$1" == "stop" ]; then
    networksetup -setwebproxystate "$SERVICE_NAME" off 2>/dev/null
    networksetup -setsecurewebproxystate "$SERVICE_NAME" off 2>/dev/null
    killall spoofdpi 2>/dev/null
    echo "[+] Proxy disabled, SpoofDPI stopped."
    exit 0
fi

echo "==================================================="
echo "  Discord Kostebek - Temporary Mode"
echo "==================================================="

echo "[+] Active network: $SERVICE_NAME"

# Install SpoofDPI if missing
if ! command -v spoofdpi &>/dev/null; then
    echo "[*] SpoofDPI not found, downloading..."
    bash "$BASE_DIR/install-spoofdpi.sh" "$BIN_DIR"
fi

if ! command -v spoofdpi &>/dev/null; then
    echo "[-] SpoofDPI could not be installed. Exiting."
    exit 1
fi

# Cleanup on exit
cleanup() {
    echo ""
    echo "[*] Stopping SpoofDPI, restoring proxy settings..."
    networksetup -setwebproxystate "$SERVICE_NAME" off 2>/dev/null
    networksetup -setsecurewebproxystate "$SERVICE_NAME" off 2>/dev/null
    echo "[+] Done. Goodbye!"
    exit 0
}

trap cleanup SIGINT SIGTERM EXIT

# Configure proxy and start
echo "[+] Enabling proxy on 127.0.0.1:8080..."
networksetup -setwebproxy "$SERVICE_NAME" 127.0.0.1 8080
networksetup -setsecurewebproxy "$SERVICE_NAME" 127.0.0.1 8080
networksetup -setwebproxystate "$SERVICE_NAME" on
networksetup -setsecurewebproxystate "$SERVICE_NAME" on

echo ""
echo "[+] SpoofDPI STARTED!"
echo "[!] Keep this window open while using Discord."
echo "[!] Press Ctrl+C to stop and restore settings."
echo "[!] If you accidentally close this window, run:"
echo "    ./run-temp.sh stop"
echo "==================================================="

spoofdpi --listen-addr 127.0.0.1:8080 --dns-mode https --https-split-mode chunk --https-chunk-size 1 --https-fake-count 1
