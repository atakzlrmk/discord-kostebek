import http.server
import socketserver
import json
import subprocess
import os
import sys
import platform

PORT = int(sys.argv[1]) if len(sys.argv) > 1 else 1337
BASE_DIR = os.path.dirname(os.path.abspath(__file__))
WEB_DIR = os.path.join(BASE_DIR, 'web')
IS_WINDOWS = platform.system() == "Windows"
IS_MAC = platform.system() == "Darwin"

PLIST = "/Library/LaunchDaemons/com.superonline.discordbypass.plist"
WIN_TASK = "DiscordKostebek"


def check_status():
    """Check SpoofDPI service status (cross-platform)."""
    if IS_MAC:
        # macOS: check launchctl
        try:
            out = subprocess.check_output(["launchctl", "list"], stderr=subprocess.DEVNULL).decode()
            if "com.superonline.discordbypass" in out:
                return "bg_running"
        except Exception:
            pass
    elif IS_WINDOWS:
        # Windows: check scheduled task
        try:
            out = subprocess.check_output(
                ["schtasks", "/Query", "/TN", WIN_TASK, "/FO", "CSV", "/NH"],
                stderr=subprocess.DEVNULL
            ).decode()
            if "Running" in out:
                return "bg_running"
            elif "Ready" in out or "Disabled" in out:
                # Task exists but not running
                pass
        except Exception:
            pass
    else:
        # Linux: check systemctl
        try:
            result = subprocess.run(
                ["systemctl", "is-active", "discordbypass.service"],
                capture_output=True, text=True
            )
            if result.stdout.strip() == "active":
                return "bg_running"
        except Exception:
            pass

    # Any OS: check if spoofdpi process is running
    try:
        if IS_WINDOWS:
            out = subprocess.check_output(
                ["tasklist", "/FI", "IMAGENAME eq spoofdpi.exe", "/NH"],
                stderr=subprocess.DEVNULL
            ).decode()
            if "spoofdpi.exe" in out:
                return "temp_running"
        else:
            out = subprocess.check_output(["pgrep", "-f", "spoofdpi"], stderr=subprocess.DEVNULL).decode()
            if out.strip():
                return "temp_running"
    except Exception:
        pass

    # Check paused state
    if IS_MAC and os.path.exists(PLIST):
        return "paused"
    elif IS_WINDOWS:
        try:
            subprocess.check_output(
                ["schtasks", "/Query", "/TN", WIN_TASK],
                stderr=subprocess.DEVNULL
            )
            return "paused"
        except Exception:
            pass

    return "stopped"


def run_elevated(action):
    """Run manage-service script with admin privileges (cross-platform)."""
    if IS_MAC:
        manage = os.path.join(BASE_DIR, 'manage-service.sh')
        script = f'do shell script "\'\\{manage}\' {action}" with administrator privileges'
        subprocess.Popen(["osascript", "-e", script])
    elif IS_WINDOWS:
        manage = os.path.join(BASE_DIR, 'manage-service.ps1')
        subprocess.Popen([
            "powershell", "-Command",
            f'Start-Process powershell -ArgumentList "-ExecutionPolicy Bypass -File \'{manage}\' -Action {action}" -Verb RunAs'
        ])
    else:
        # Linux: pkexec or sudo
        manage = os.path.join(BASE_DIR, 'manage-service.sh')
        subprocess.Popen(["pkexec", manage, action])


def open_temp_terminal():
    """Open a new terminal running the temp script (cross-platform)."""
    if IS_MAC:
        script = f'''tell application "Terminal"
            do script "cd '{BASE_DIR}' && sudo ./run-temp.sh"
            activate
        end tell'''
        subprocess.Popen(["osascript", "-e", script])
    elif IS_WINDOWS:
        ps1 = os.path.join(BASE_DIR, 'run-temp.ps1')
        subprocess.Popen([
            "powershell", "-Command",
            f'Start-Process powershell -ArgumentList "-ExecutionPolicy Bypass -File \'{ps1}\'" -Verb RunAs'
        ])
    else:
        # Linux: try common terminal emulators
        temp_script = os.path.join(BASE_DIR, 'run-temp.sh')
        for term in ["gnome-terminal", "konsole", "xfce4-terminal", "xterm"]:
            try:
                subprocess.Popen([term, "--", "sudo", temp_script])
                return
            except FileNotFoundError:
                continue


class Handler(http.server.SimpleHTTPRequestHandler):
    def __init__(self, *args, **kwargs):
        super().__init__(*args, directory=WEB_DIR, **kwargs)

    def end_headers(self):
        self.send_header('Cache-Control', 'no-store')
        super().end_headers()

    def log_message(self, format, *args):
        pass

    def do_GET(self):
        if self.path == '/api/status':
            self._json_response({"status": check_status()})
            return
        return super().do_GET()

    def do_POST(self):
        if self.path != '/api/action':
            self.send_response(404)
            self.end_headers()
            return

        length = int(self.headers.get('Content-Length', 0))
        if length == 0:
            self.send_response(400)
            self.end_headers()
            return

        try:
            data = json.loads(self.rfile.read(length))
            action = data.get('action')
            self._handle_action(action)
            self._json_response({"success": True})
        except Exception as e:
            self._json_response({"success": False, "error": str(e)}, code=500)

    def _handle_action(self, action):
        if action in ('start_bg', 'repair_bg'):
            run_elevated("install")
        elif action == 'pause_bg':
            run_elevated("pause")
        elif action == 'resume_bg':
            run_elevated("resume")
        elif action == 'uninstall_bg':
            run_elevated("uninstall")
        elif action == 'start_temp':
            open_temp_terminal()

    def _json_response(self, data, code=200):
        self.send_response(code)
        self.send_header('Content-Type', 'application/json')
        self.end_headers()
        self.wfile.write(json.dumps(data).encode())


if __name__ == '__main__':
    socketserver.TCPServer.allow_reuse_address = True
    print(f"Dashboard server running at http://localhost:{PORT}")
    try:
        with socketserver.TCPServer(("", PORT), Handler) as httpd:
            httpd.serve_forever()
    except KeyboardInterrupt:
        print("\nServer stopped.")
