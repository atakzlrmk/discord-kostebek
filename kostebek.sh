#!/usr/bin/env bash
set -euo pipefail

BASE_DIR="$(cd "$(dirname "$0")" && pwd)"
PLIST="/Library/LaunchDaemons/com.superonline.discordbypass.plist"
SERVICE="discordbypass.service"
SPOOFDPI_SYSTEM="/usr/local/bin/spoofdpi"
SPOOFDPI_USER="$HOME/.local/bin/spoofdpi"
PORT="${PORT:-1337}"

SPOOFDPI_ARGS=(
    --listen-addr 127.0.0.1:8080
    --dns-mode https
    --https-split-mode chunk
    --https-chunk-size 1
    --https-fake-count 1
    --no-tui
)

say() {
    printf '%s\n' "$*"
}

require_root() {
    if [ "${EUID:-$(id -u)}" -ne 0 ]; then
        say "Run with sudo: sudo $0 $1"
        exit 1
    fi
}

network_service() {
    local iface
    iface="$(route get default 2>/dev/null | awk '/interface:/ {print $2; exit}')"
    if [ -n "$iface" ]; then
        networksetup -listnetworkserviceorder 2>/dev/null \
            | grep -B 1 "Device: $iface" \
            | head -n 1 \
            | sed -E 's/^\(\*?[0-9]+\) //'
    else
        say "Wi-Fi"
    fi
}

proxy_on() {
    [ "$(uname -s)" = "Darwin" ] || return 0
    local svc
    svc="$(network_service)"
    networksetup -setwebproxy "$svc" 127.0.0.1 8080
    networksetup -setsecurewebproxy "$svc" 127.0.0.1 8080
    networksetup -setwebproxystate "$svc" on
    networksetup -setsecurewebproxystate "$svc" on
}

proxy_off() {
    [ "$(uname -s)" = "Darwin" ] || return 0
    local svc
    svc="$(network_service)"
    networksetup -setwebproxystate "$svc" off 2>/dev/null || true
    networksetup -setsecurewebproxystate "$svc" off 2>/dev/null || true
}

wait_for_port() {
    local attempts=20
    while [ "$attempts" -gt 0 ]; do
        nc -z 127.0.0.1 8080 >/dev/null 2>&1 && return 0
        sleep 0.5
        attempts=$((attempts - 1))
    done
    return 1
}

install_spoofdpi() {
    local install_dir="${1:-/usr/local/bin}"
    local install_bin="$install_dir/spoofdpi"

    if [ -x "$install_bin" ]; then
        say "SpoofDPI already installed at $install_bin"
        return 0
    fi

    local os_name arch_pattern tmp release_json download_url archive extracted
    case "$(uname -s)" in
        Darwin) os_name="darwin" ;;
        Linux) os_name="linux" ;;
        *) say "Unsupported OS: $(uname -s)"; exit 1 ;;
    esac

    case "$(uname -m)" in
        arm64|aarch64) arch_pattern="arm64|aarch64" ;;
        x86_64|amd64) arch_pattern="x86_64|amd64" ;;
        *) say "Unsupported architecture: $(uname -m)"; exit 1 ;;
    esac

    tmp="$(mktemp -d)"
    trap 'rm -rf "$tmp"' RETURN

    say "Resolving latest SpoofDPI release..."
    release_json="$(curl -fsSL https://api.github.com/repos/xvzc/SpoofDPI/releases/latest)"
    download_url="$(
        printf '%s\n' "$release_json" \
            | grep '"browser_download_url"' \
            | grep -Ei "$os_name" \
            | grep -Ei "$arch_pattern" \
            | grep -Ei '\.tar\.gz"' \
            | head -n 1 \
            | sed -E 's/.*"([^"]+)".*/\1/' || true
    )"

    if [ -z "$download_url" ]; then
        say "Could not find a SpoofDPI release for ${os_name}/$(uname -m)."
        exit 1
    fi

    archive="$tmp/spoofdpi.tar.gz"
    say "Downloading $(basename "$download_url")..."
    curl -fL "$download_url" -o "$archive"
    tar -xzf "$archive" -C "$tmp"

    extracted="$(find "$tmp" -type f -name spoofdpi -print | head -n 1)"
    if [ -z "$extracted" ]; then
        say "Downloaded archive did not contain a spoofdpi binary."
        exit 1
    fi

    mkdir -p "$install_dir"
    install -m 0755 "$extracted" "$install_bin"
    say "SpoofDPI installed to $install_bin"
}

install_service() {
    require_root install
    install_spoofdpi "/usr/local/bin"

    case "$(uname -s)" in
        Darwin)
            cat > "$PLIST" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key><string>com.superonline.discordbypass</string>
    <key>ProgramArguments</key>
    <array>
        <string>$SPOOFDPI_SYSTEM</string>
        <string>--listen-addr</string><string>127.0.0.1:8080</string>
        <string>--dns-mode</string><string>https</string>
        <string>--https-split-mode</string><string>chunk</string>
        <string>--https-chunk-size</string><string>1</string>
        <string>--https-fake-count</string><string>1</string>
        <string>--no-tui</string>
    </array>
    <key>RunAtLoad</key><true/>
    <key>KeepAlive</key><true/>
    <key>StandardOutPath</key><string>/var/log/discordbypass.log</string>
    <key>StandardErrorPath</key><string>/var/log/discordbypass_err.log</string>
</dict>
</plist>
EOF
            chown root:wheel "$PLIST"
            chmod 644 "$PLIST"
            launchctl unload "$PLIST" 2>/dev/null || true
            launchctl load -w "$PLIST"
            wait_for_port || {
                launchctl unload "$PLIST" 2>/dev/null || true
                proxy_off
                say "SpoofDPI did not start on 127.0.0.1:8080."
                [ -f /var/log/discordbypass_err.log ] && tail -n 20 /var/log/discordbypass_err.log
                exit 1
            }
            proxy_on
            ;;
        Linux)
            cat > "/etc/systemd/system/$SERVICE" <<EOF
[Unit]
Description=SpoofDPI Discord Bypass Service
After=network.target

[Service]
Type=simple
ExecStart=$SPOOFDPI_SYSTEM ${SPOOFDPI_ARGS[*]}
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF
            systemctl daemon-reload
            systemctl enable "$SERVICE"
            systemctl restart "$SERVICE"
            ;;
        *) say "Unsupported OS: $(uname -s)"; exit 1 ;;
    esac

    say "Background service installed and started."
}

pause_service() {
    require_root pause
    case "$(uname -s)" in
        Darwin) launchctl unload "$PLIST" 2>/dev/null || true ;;
        Linux) systemctl stop "$SERVICE" 2>/dev/null || true ;;
    esac
    killall spoofdpi 2>/dev/null || true
    proxy_off
    say "Service paused."
}

resume_service() {
    require_root resume
    case "$(uname -s)" in
        Darwin)
            launchctl load -w "$PLIST" 2>/dev/null || true
            wait_for_port || { proxy_off; say "SpoofDPI did not start."; exit 1; }
            proxy_on
            ;;
        Linux)
            systemctl start "$SERVICE"
            ;;
    esac
    say "Service resumed."
}

uninstall_service() {
    require_root uninstall
    case "$(uname -s)" in
        Darwin)
            launchctl unload "$PLIST" 2>/dev/null || true
            rm -f "$PLIST"
            ;;
        Linux)
            systemctl disable --now "$SERVICE" 2>/dev/null || true
            rm -f "/etc/systemd/system/$SERVICE"
            systemctl daemon-reload
            ;;
    esac
    killall spoofdpi 2>/dev/null || true
    proxy_off
    rm -f "$SPOOFDPI_SYSTEM"
    say "Service uninstalled."
}

run_temp() {
    if [ "${1:-}" = "stop" ]; then
        proxy_off
        killall spoofdpi 2>/dev/null || true
        say "Temporary mode stopped."
        exit 0
    fi

    export PATH="$HOME/.local/bin:/usr/local/bin:$PATH"
    command -v spoofdpi >/dev/null 2>&1 || install_spoofdpi "$HOME/.local/bin"

    trap 'proxy_off; say ""; say "Temporary mode stopped."' INT TERM EXIT
    proxy_on
    say "SpoofDPI temporary mode started. Keep this window open."
    spoofdpi "${SPOOFDPI_ARGS[@]}"
}

dashboard() {
    cd "$BASE_DIR"
    while lsof -Pi :"$PORT" -sTCP:LISTEN -t >/dev/null 2>&1; do
        PORT=$((PORT + 1))
    done

    say "Dashboard: http://localhost:$PORT"
    python3 server.py "$PORT" &
    local server_pid=$!
    sleep 1
    open "http://localhost:$PORT" 2>/dev/null || xdg-open "http://localhost:$PORT" 2>/dev/null || true
    wait "$server_pid"
}

menu() {
    while true; do
        clear
        say "Discord Kostebek"
        say "1) Run temporarily"
        say "2) Install background service"
        say "3) Pause background service"
        say "4) Resume background service"
        say "5) Uninstall"
        say "6) Open dashboard"
        say "7) Exit"
        read -r -p "Choice (1-7): " choice
        case "$choice" in
            1) sudo "$0" temp; read -r -p "Press ENTER..." _ ;;
            2) sudo "$0" install; read -r -p "Press ENTER..." _ ;;
            3) sudo "$0" pause; read -r -p "Press ENTER..." _ ;;
            4) sudo "$0" resume; read -r -p "Press ENTER..." _ ;;
            5) sudo "$0" uninstall; read -r -p "Press ENTER..." _ ;;
            6) "$0" dashboard ;;
            7) exit 0 ;;
            *) sleep 1 ;;
        esac
    done
}

case "${1:-menu}" in
    dashboard) dashboard ;;
    menu) menu ;;
    temp) shift; run_temp "$@" ;;
    install) install_service ;;
    pause) pause_service ;;
    resume) resume_service ;;
    uninstall) uninstall_service ;;
    *) say "Usage: $0 {dashboard|menu|temp|install|pause|resume|uninstall}"; exit 1 ;;
esac
