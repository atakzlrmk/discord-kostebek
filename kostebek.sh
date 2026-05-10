#!/usr/bin/env bash
set -euo pipefail

PLIST="/Library/LaunchDaemons/com.superonline.discordbypass.plist"
LABEL="com.superonline.discordbypass"
SERVICE="discordbypass.service"
SPOOFDPI_SYSTEM="/usr/local/bin/spoofdpi"

SPOOFDPI_ARGS=(
    --clean
    --listen-addr 127.0.0.1:8080
    --dns-mode https
    --https-split-mode chunk
    --https-chunk-size 1
    --https-fake-count 1
)

if [ -t 1 ] && command -v tput >/dev/null 2>&1 && [ "$(tput colors 2>/dev/null || echo 0)" -ge 8 ]; then
    BOLD="$(tput bold)"
    DIM="$(tput dim)"
    RESET="$(tput sgr0)"
    RED="$(tput setaf 1)"
    GREEN="$(tput setaf 2)"
    YELLOW="$(tput setaf 3)"
    BLUE="$(tput setaf 4)"
    CYAN="$(tput setaf 6)"
else
    BOLD=""
    DIM=""
    RESET=""
    RED=""
    GREEN=""
    YELLOW=""
    BLUE=""
    CYAN=""
fi

say() {
    printf '%s\n' "$*"
}

info() {
    say "${BLUE}==>${RESET} $*"
}

ok() {
    say "${GREEN}OK${RESET}  $*"
}

warn() {
    say "${YELLOW}!!${RESET}  $*"
}

fail() {
    say "${RED}!!${RESET}  $*"
}

require_root() {
    if [ "${EUID:-$(id -u)}" -ne 0 ]; then
        say "Run with sudo: sudo $0 $1"
        exit 1
    fi
}

need_cmd() {
    command -v "$1" >/dev/null 2>&1 || {
        say "Missing required command: $1"
        exit 1
    }
}

mac_user() {
    if [ -n "${SUDO_USER:-}" ] && [ "$SUDO_USER" != "root" ]; then
        say "$SUDO_USER"
    else
        id -un
    fi
}

mac_uid() {
    id -u "$(mac_user)"
}

mac_home() {
    local user
    user="$(mac_user)"
    dscl . -read "/Users/$user" NFSHomeDirectory 2>/dev/null | awk '{print $2}' || eval echo "~$user"
}

mac_domain() {
    say "gui/$(mac_uid)"
}

mac_launchctl() {
    launchctl asuser "$(mac_uid)" launchctl "$@"
}

mac_agent_plist() {
    say "$(mac_home)/Library/LaunchAgents/$LABEL.plist"
}

mac_stdout_log() {
    say "$(mac_home)/Library/Logs/discordbypass.log"
}

mac_stderr_log() {
    say "$(mac_home)/Library/Logs/discordbypass_err.log"
}

run_step() {
    local seconds="$1"
    local label="$2"
    shift 2

    info "$label"
    "$@" &
    local pid=$!
    local elapsed=0

    while kill -0 "$pid" 2>/dev/null; do
        if [ "$elapsed" -ge "$seconds" ]; then
            kill "$pid" 2>/dev/null || true
            wait "$pid" 2>/dev/null || true
            warn "$label timed out after ${seconds}s"
            return 1
        fi

        sleep 1
        elapsed=$((elapsed + 1))
    done

    if wait "$pid"; then
        ok "$label"
        return 0
    fi

    warn "$label failed or was already clean"
    return 1
}

status_key() {
    case "$(uname -s)" in
        Darwin)
            if mac_launchctl print "$(mac_domain)/$LABEL" >/dev/null 2>&1 || launchctl print "system/$LABEL" >/dev/null 2>&1; then
                say "running"
                return 0
            fi
            if pgrep -f spoofdpi >/dev/null 2>&1 || ps ax 2>/dev/null | grep -v grep | grep -q spoofdpi; then
                say "temporary"
                return 0
            fi
            if [ -f "$(mac_agent_plist)" ] || [ -f "$PLIST" ]; then
                say "paused"
                return 0
            fi
            ;;
        Linux)
            if systemctl is-active --quiet "$SERVICE" 2>/dev/null; then
                say "running"
                return 0
            fi
            if pgrep -f spoofdpi >/dev/null 2>&1 || ps ax 2>/dev/null | grep -v grep | grep -q spoofdpi; then
                say "temporary"
                return 0
            fi
            if [ -f "/etc/systemd/system/$SERVICE" ]; then
                say "paused"
                return 0
            fi
            ;;
    esac

    say "stopped"
}

status_label() {
    case "$1" in
        running) say "Background service running" ;;
        temporary) say "Temporary mode running" ;;
        paused) say "Installed but paused" ;;
        *) say "Stopped" ;;
    esac
}

status_color() {
    case "$1" in
        running) printf '%s' "$GREEN" ;;
        temporary) printf '%s' "$CYAN" ;;
        paused) printf '%s' "$YELLOW" ;;
        *) printf '%s' "$RED" ;;
    esac
}

status() {
    local state label color
    state="$(status_key)"
    label="$(status_label "$state")"
    color="$(status_color "$state")"
    say "${BOLD}Status:${RESET} ${color}${label}${RESET}"
}

network_service() {
    local iface
    iface="$(route get default 2>/dev/null | awk '/interface:/ {print $2; exit}' || true)"
    if [ -n "$iface" ]; then
        networksetup -listnetworkserviceorder 2>/dev/null \
            | grep -B 1 "Device: $iface" \
            | head -n 1 \
            | sed -E 's/^\(\*?[0-9]+\) //' \
            || say "Wi-Fi"
    else
        say "Wi-Fi"
    fi
}

stop_spoofdpi_processes() {
    run_step 3 "Stopping SpoofDPI processes" pkill -x spoofdpi || true
    run_step 3 "Stopping SpoofDPI by path" pkill -f "/spoofdpi" || true
    run_step 3 "Stopping SpoofDPI by name" killall spoofdpi || true
}

proxy_on() {
    [ "$(uname -s)" = "Darwin" ] || return 0
    local svc
    svc="$(network_service)"
    [ -n "$svc" ] || return 0
    run_step 5 "Setting HTTP proxy on $svc" networksetup -setwebproxy "$svc" 127.0.0.1 8080
    run_step 5 "Setting HTTPS proxy on $svc" networksetup -setsecurewebproxy "$svc" 127.0.0.1 8080
    run_step 5 "Enabling HTTP proxy on $svc" networksetup -setwebproxystate "$svc" on
    run_step 5 "Enabling HTTPS proxy on $svc" networksetup -setsecurewebproxystate "$svc" on
}

proxy_off() {
    [ "$(uname -s)" = "Darwin" ] || return 0
    local svc
    svc="$(network_service)"
    [ -n "$svc" ] || return 0
    run_step 5 "Disabling HTTP proxy on $svc" networksetup -setwebproxystate "$svc" off || true
    run_step 5 "Disabling HTTPS proxy on $svc" networksetup -setsecurewebproxystate "$svc" off || true
}

wait_for_port() {
    local attempts=20
    info "Waiting for SpoofDPI on 127.0.0.1:8080"
    while [ "$attempts" -gt 0 ]; do
        if nc -z 127.0.0.1 8080 >/dev/null 2>&1; then
            ok "SpoofDPI is listening on 127.0.0.1:8080"
            return 0
        fi
        sleep 0.5
        attempts=$((attempts - 1))
    done
    warn "SpoofDPI did not open 127.0.0.1:8080 in time"
    return 1
}

install_spoofdpi() {
    local install_dir="${1:-/usr/local/bin}"
    local install_bin="$install_dir/spoofdpi"

    if [ -x "$install_bin" ]; then
        say "SpoofDPI already installed at $install_bin"
        return 0
    fi

    need_cmd curl
    need_cmd tar

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
    trap 'rm -rf "${tmp:-}"; trap - RETURN' RETURN
    say "Using temporary directory: $tmp"

    say "Resolving latest SpoofDPI release..."
    release_json="$(curl -fsSL --connect-timeout 10 --max-time 60 https://api.github.com/repos/xvzc/SpoofDPI/releases/latest)"
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
    curl -fL --connect-timeout 10 --max-time 180 "$download_url" -o "$archive"
    say "Extracting SpoofDPI archive..."
    tar -xzf "$archive" -C "$tmp"

    say "Locating SpoofDPI binary..."
    extracted="$(find "$tmp" -type f -name spoofdpi -print | head -n 1)"
    if [ -z "$extracted" ]; then
        say "Downloaded archive did not contain a spoofdpi binary."
        exit 1
    fi

    run_step 5 "Creating install directory $install_dir" mkdir -p "$install_dir"
    run_step 5 "Installing SpoofDPI to $install_bin" install -m 0755 "$extracted" "$install_bin"
    say "SpoofDPI installed to $install_bin"
}

prepare_binary_for_launchd() {
    [ "$(uname -s)" = "Darwin" ] || return 0
    run_step 5 "Setting SpoofDPI binary owner" chown root:wheel "$SPOOFDPI_SYSTEM"
    run_step 5 "Setting SpoofDPI binary permissions" chmod 755 "$SPOOFDPI_SYSTEM"
    run_step 5 "Clearing SpoofDPI binary attributes" xattr -c "$SPOOFDPI_SYSTEM" || true
}

write_launch_plist() {
    local target_plist="$1"
    local stdout_log="$2"
    local stderr_log="$3"
    local tmp_plist
    tmp_plist="$(mktemp)"
    trap 'rm -f "${tmp_plist:-}"; trap - RETURN' RETURN

    cat > "$tmp_plist" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>$LABEL</string>
    <key>ProgramArguments</key>
    <array>
        <string>$SPOOFDPI_SYSTEM</string>
EOF

    local arg
    for arg in "${SPOOFDPI_ARGS[@]}"; do
        printf '        <string>%s</string>\n' "$arg" >> "$tmp_plist"
    done

    cat >> "$tmp_plist" <<EOF
    </array>
    <key>EnvironmentVariables</key>
    <dict>
        <key>TERM</key>
        <string>dumb</string>
        <key>NO_COLOR</key>
        <string>1</string>
    </dict>
    <key>RunAtLoad</key>
    <true/>
    <key>KeepAlive</key>
    <true/>
    <key>StandardInputPath</key>
    <string>/dev/null</string>
    <key>StandardOutPath</key>
    <string>$stdout_log</string>
    <key>StandardErrorPath</key>
    <string>$stderr_log</string>
</dict>
</plist>
EOF

    run_step 5 "Validating generated plist" plutil -lint "$tmp_plist"
    run_step 5 "Installing launchd plist" cp -f "$tmp_plist" "$target_plist"
}

verify_launch_plist() {
    local target_plist="$1"

    run_step 5 "Validating installed plist" plutil -lint "$target_plist"

    if grep -q -- "--system-proxy\|--no-tui" "$target_plist"; then
        fail "Installed plist still contains obsolete SpoofDPI flags."
        plutil -p "$target_plist" || true
        exit 1
    fi

    say "launchd arguments:"
    plutil -p "$target_plist" | sed -n '/ProgramArguments/,/]/p'
}

clear_service_logs() {
    local stdout_log="$1"
    local stderr_log="$2"
    local user
    user="$(mac_user)"

    say "Clearing previous service logs..."
    mkdir -p "$(dirname "$stdout_log")"
    rm -f "$stdout_log" "$stderr_log"
    touch "$stdout_log" "$stderr_log"
    chown "$user":staff "$stdout_log" "$stderr_log" 2>/dev/null || true
    chmod 644 "$stdout_log" "$stderr_log" 2>/dev/null || true
}

install_service() {
    require_root install
    say "Starting background service install..."
    install_spoofdpi "/usr/local/bin"
    prepare_binary_for_launchd

    case "$(uname -s)" in
        Darwin)
            local agent_plist domain user stdout_log stderr_log
            user="$(mac_user)"
            domain="$(mac_domain)"
            agent_plist="$(mac_agent_plist)"
            stdout_log="$(mac_stdout_log)"
            stderr_log="$(mac_stderr_log)"

            run_step 5 "Booting out existing LaunchAgent" mac_launchctl bootout "$domain/$LABEL" || true
            run_step 5 "Booting out old LaunchDaemon" launchctl bootout "system/$LABEL" || true
            stop_spoofdpi_processes
            say "Removing old plist files..."
            rm -f "$PLIST" "$agent_plist"
            run_step 5 "Creating LaunchAgents directory" mkdir -p "$(dirname "$agent_plist")"
            say "Writing LaunchAgent plist to $agent_plist..."
            write_launch_plist "$agent_plist" "$stdout_log" "$stderr_log"
            run_step 5 "Setting plist owner" chown "$user":staff "$agent_plist"
            run_step 5 "Setting plist permissions" chmod 644 "$agent_plist"
            run_step 5 "Clearing plist attributes" xattr -c "$agent_plist" || true
            verify_launch_plist "$agent_plist"
            clear_service_logs "$stdout_log" "$stderr_log"
            run_step 10 "Bootstrapping LaunchAgent" mac_launchctl bootstrap "$domain" "$agent_plist" || true
            run_step 5 "Enabling LaunchAgent" mac_launchctl enable "$domain/$LABEL" || true
            run_step 3 "Starting LaunchAgent" mac_launchctl kickstart -k "$domain/$LABEL" || true
            wait_for_port || {
                run_step 5 "Cleaning up failed LaunchAgent" mac_launchctl bootout "$domain/$LABEL" || true
                proxy_off
                say "SpoofDPI did not start on 127.0.0.1:8080."
                [ -f "$stderr_log" ] && tail -n 20 "$stderr_log"
                exit 1
            }
            proxy_on
            ;;
        Linux)
            say "Writing systemd unit to /etc/systemd/system/$SERVICE..."
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
            run_step 10 "Reloading systemd" systemctl daemon-reload
            run_step 10 "Enabling systemd service" systemctl enable "$SERVICE"
            run_step 10 "Restarting systemd service" systemctl restart "$SERVICE"
            ;;
        *) say "Unsupported OS: $(uname -s)"; exit 1 ;;
    esac

    say "Background service installed and started."
}

pause_service() {
    require_root pause
    case "$(uname -s)" in
        Darwin)
            run_step 5 "Booting out LaunchAgent" mac_launchctl bootout "$(mac_domain)/$LABEL" || true
            run_step 5 "Booting out old LaunchDaemon" launchctl bootout "system/$LABEL" || true
            run_step 5 "Disabling LaunchAgent" mac_launchctl disable "$(mac_domain)/$LABEL" || true
            ;;
        Linux) run_step 10 "Stopping systemd service" systemctl stop "$SERVICE" || true ;;
    esac
    stop_spoofdpi_processes
    proxy_off
    say "Service paused."
}

resume_service() {
    require_root resume
    case "$(uname -s)" in
        Darwin)
            if [ ! -f "$(mac_agent_plist)" ]; then
                say "Service is not installed. Run: sudo $0 install"
                exit 1
            fi
            run_step 10 "Bootstrapping LaunchAgent" mac_launchctl bootstrap "$(mac_domain)" "$(mac_agent_plist)" || true
            run_step 5 "Enabling LaunchAgent" mac_launchctl enable "$(mac_domain)/$LABEL" || true
            run_step 3 "Starting LaunchAgent" mac_launchctl kickstart -k "$(mac_domain)/$LABEL" || true
            wait_for_port || { proxy_off; say "SpoofDPI did not start."; exit 1; }
            proxy_on
            ;;
        Linux)
            run_step 10 "Starting systemd service" systemctl start "$SERVICE"
            ;;
    esac
    say "Service resumed."
}

uninstall_service() {
    require_root uninstall
    case "$(uname -s)" in
        Darwin)
            run_step 5 "Booting out LaunchAgent" mac_launchctl bootout "$(mac_domain)/$LABEL" || true
            run_step 5 "Booting out old LaunchDaemon" launchctl bootout "system/$LABEL" || true
            run_step 5 "Disabling LaunchAgent" mac_launchctl disable "$(mac_domain)/$LABEL" || true
            say "Removing plist files..."
            rm -f "$(mac_agent_plist)" "$PLIST"
            ;;
        Linux)
            run_step 10 "Disabling systemd service" systemctl disable --now "$SERVICE" || true
            say "Removing systemd unit..."
            rm -f "/etc/systemd/system/$SERVICE"
            run_step 10 "Reloading systemd" systemctl daemon-reload || true
            ;;
    esac
    stop_spoofdpi_processes
    proxy_off
    say "Removing SpoofDPI binary..."
    rm -f "$SPOOFDPI_SYSTEM"
    say "Service uninstalled."
}

run_temp() {
    require_root temp

    if [ "${1:-}" = "stop" ]; then
        proxy_off
        killall spoofdpi 2>/dev/null || true
        say "Temporary mode stopped."
        exit 0
    fi

    install_spoofdpi "/usr/local/bin"

    trap 'proxy_off; say ""; say "Temporary mode stopped."' INT TERM EXIT
    proxy_on
    say "SpoofDPI temporary mode started. Keep this window open."
    "$SPOOFDPI_SYSTEM" "${SPOOFDPI_ARGS[@]}"
}

print_rule() {
    say "${DIM}------------------------------------------------------------${RESET}"
}

print_header() {
    local state label color os
    state="$(status_key)"
    label="$(status_label "$state")"
    color="$(status_color "$state")"
    os="$(uname -s)"

    [ -t 1 ] && clear
    say "${BOLD}${CYAN}Discord Kostebek${RESET}"
    say "${DIM}CLI control panel for SpoofDPI on 127.0.0.1:8080${RESET}"
    print_rule
    printf '%s\n' "Status   ${color}${label}${RESET}"
    printf '%s\n' "Platform ${os}"
    print_rule
}

menu_item() {
    local number="$1"
    local title="$2"
    local detail="$3"

    printf '  %s) %s%s%s\n' "$number" "$BOLD" "$title" "$RESET"
    printf '      %s%s%s\n' "$DIM" "$detail" "$RESET"
}

pause_prompt() {
    read -r -p "Press ENTER to continue..." _
}

run_root_action() {
    if [ "${EUID:-$(id -u)}" -eq 0 ]; then
        "$0" "$@"
    else
        sudo "$0" "$@"
    fi
}

menu() {
    while true; do
        print_header
        menu_item 1 "Show status" "Print the current SpoofDPI/service state."
        menu_item 2 "Run temporarily" "Start SpoofDPI in this terminal; Ctrl+C stops it."
        menu_item 3 "Install background service" "Install SpoofDPI and start it at boot."
        menu_item 4 "Pause background service" "Stop launchd/systemd service and disable proxy."
        menu_item 5 "Resume background service" "Start the installed service again."
        menu_item 6 "Uninstall" "Remove service, proxy settings, and installed binary."
        menu_item 7 "Exit" "Close this menu."
        print_rule
        read -r -p "Choice [1-7]: " choice
        case "$choice" in
            1) "$0" status; pause_prompt ;;
            2) run_root_action temp; pause_prompt ;;
            3) run_root_action install; pause_prompt ;;
            4) run_root_action pause; pause_prompt ;;
            5) run_root_action resume; pause_prompt ;;
            6) run_root_action uninstall; pause_prompt ;;
            7) exit 0 ;;
            *) sleep 1 ;;
        esac
    done
}

case "${1:-menu}" in
    menu) menu ;;
    status) status ;;
    temp) shift; run_temp "$@" ;;
    install) install_service ;;
    pause) pause_service ;;
    resume) resume_service ;;
    uninstall) uninstall_service ;;
    *) say "Usage: $0 {menu|status|temp|install|pause|resume|uninstall}"; exit 1 ;;
esac
