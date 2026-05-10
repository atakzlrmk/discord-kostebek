#!/bin/bash

# ==========================================================
# Discord Kostebek - Service Manager
# Single script for: install, pause, resume, uninstall
# Usage: sudo ./manage-service.sh <action>
# ==========================================================

PLIST="/Library/LaunchDaemons/com.superonline.discordbypass.plist"
SPOOFDPI_BIN="/usr/local/bin/spoofdpi"
BASE_DIR="$(cd "$(dirname "$0")" && pwd)"

GREEN='\033[0;32m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m'

# Get active network service name
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

proxy_off() {
    local svc=$(get_service_name)
    networksetup -setwebproxystate "$svc" off 2>/dev/null
    networksetup -setsecurewebproxystate "$svc" off 2>/dev/null
}

proxy_on() {
    local svc=$(get_service_name)
    echo -e "${BLUE}[*] Enabling proxy on $svc...${NC}"
    networksetup -setwebproxy "$svc" 127.0.0.1 8080
    networksetup -setsecurewebproxy "$svc" 127.0.0.1 8080
    networksetup -setwebproxystate "$svc" on
    networksetup -setsecurewebproxystate "$svc" on
}

wait_for_proxy_port() {
    local attempts=20

    while [ "$attempts" -gt 0 ]; do
        if nc -z 127.0.0.1 8080 >/dev/null 2>&1; then
            return 0
        fi

        sleep 0.5
        attempts=$((attempts - 1))
    done

    return 1
}

print_service_logs() {
    if [ -f /var/log/discordbypass_err.log ]; then
        echo -e "${BLUE}[*] Last service errors:${NC}"
        tail -n 20 /var/log/discordbypass_err.log
    fi
}

ACTION="$1"

case "$ACTION" in
    install)
        # Root check
        if [ "$EUID" -ne 0 ]; then
            echo -e "${RED}[!] Run with sudo: sudo ./manage-service.sh install${NC}"
            exit 1
        fi

        OS="$(uname -s)"
        echo -e "${BLUE}[*] Installing SpoofDPI...${NC}"
        bash "$BASE_DIR/install-spoofdpi.sh" "/usr/local/bin"

        if [ ! -x "$SPOOFDPI_BIN" ]; then
            echo -e "${RED}[-] SpoofDPI installation failed.${NC}"
            exit 1
        fi

        if [ "$OS" = "Darwin" ]; then
            echo -e "${GREEN}[+] Creating macOS LaunchDaemon...${NC}"
            cat << EOF > "$PLIST"
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>com.superonline.discordbypass</string>
    <key>ProgramArguments</key>
    <array>
        <string>$SPOOFDPI_BIN</string>
        <string>--listen-addr</string>
        <string>127.0.0.1:8080</string>
        <string>--dns-mode</string>
        <string>https</string>
        <string>--https-split-mode</string>
        <string>chunk</string>
        <string>--https-chunk-size</string>
        <string>1</string>
        <string>--https-fake-count</string>
        <string>1</string>
        <string>--no-tui</string>
    </array>
    <key>RunAtLoad</key>
    <true/>
    <key>KeepAlive</key>
    <true/>
    <key>StandardOutPath</key>
    <string>/var/log/discordbypass.log</string>
    <key>StandardErrorPath</key>
    <string>/var/log/discordbypass_err.log</string>
</dict>
</plist>
EOF
            chown root:wheel "$PLIST"
            chmod 644 "$PLIST"
            launchctl unload "$PLIST" 2>/dev/null
            launchctl load -w "$PLIST"

            if ! wait_for_proxy_port; then
                launchctl unload "$PLIST" 2>/dev/null
                proxy_off
                echo -e "${RED}[-] SpoofDPI service did not start on 127.0.0.1:8080. Proxy left disabled.${NC}"
                print_service_logs
                exit 1
            fi

            proxy_on
            echo -e "${GREEN}[OK] Background service installed and started.${NC}"

        elif [ "$OS" = "Linux" ]; then
            echo -e "${GREEN}[+] Creating Linux Systemd service...${NC}"
            cat << EOF > /etc/systemd/system/discordbypass.service
[Unit]
Description=SpoofDPI Discord Bypass Service
After=network.target

[Service]
Type=simple
ExecStart=$SPOOFDPI_BIN --listen-addr 127.0.0.1:8080 --dns-mode https --https-split-mode chunk --https-chunk-size 1 --https-fake-count 1 --no-tui
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF
            systemctl daemon-reload
            systemctl enable discordbypass.service
            systemctl restart discordbypass.service
            echo -e "${GREEN}[OK] Systemd service installed and started.${NC}"
        else
            echo -e "${RED}[-] Unsupported OS: $OS${NC}"
            exit 1
        fi
        ;;

    pause)
        if [ "$EUID" -ne 0 ]; then echo -e "${RED}[!] Run with sudo${NC}"; exit 1; fi
        launchctl unload "$PLIST" 2>/dev/null
        killall spoofdpi 2>/dev/null
        proxy_off
        echo -e "${GREEN}[OK] Service paused.${NC}"
        ;;

    resume)
        if [ "$EUID" -ne 0 ]; then echo -e "${RED}[!] Run with sudo${NC}"; exit 1; fi
        launchctl load -w "$PLIST" 2>/dev/null
        if ! wait_for_proxy_port; then
            launchctl unload "$PLIST" 2>/dev/null
            proxy_off
            echo -e "${RED}[-] SpoofDPI service did not start on 127.0.0.1:8080. Proxy left disabled.${NC}"
            print_service_logs
            exit 1
        fi
        proxy_on
        echo -e "${GREEN}[OK] Service resumed.${NC}"
        ;;

    uninstall)
        if [ "$EUID" -ne 0 ]; then echo -e "${RED}[!] Run with sudo${NC}"; exit 1; fi
        launchctl unload "$PLIST" 2>/dev/null
        rm -f "$PLIST"
        killall spoofdpi 2>/dev/null
        proxy_off
        rm -f "$SPOOFDPI_BIN"
        echo -e "${GREEN}[OK] Service uninstalled and cleaned up.${NC}"
        ;;

    *)
        echo "Usage: sudo ./manage-service.sh {install|pause|resume|uninstall}"
        exit 1
        ;;
esac
