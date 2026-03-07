# ==========================================================
# Discord Kostebek - Temporary Runner (Windows)
# Runs SpoofDPI in the foreground with proxy configured.
# Press Ctrl+C to stop.
# ==========================================================

param(
    [switch]$Stop
)

$SpoofDPIDir = "$env:LOCALAPPDATA\SpoofDPI"
$SpoofDPIBin = "$SpoofDPIDir\spoofdpi.exe"

function Set-ProxyOn {
    $reg = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Internet Settings"
    Set-ItemProperty -Path $reg -Name ProxyEnable -Value 1
    Set-ItemProperty -Path $reg -Name ProxyServer -Value "127.0.0.1:8080"
}

function Set-ProxyOff {
    $reg = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Internet Settings"
    Set-ItemProperty -Path $reg -Name ProxyEnable -Value 0
    Remove-ItemProperty -Path $reg -Name ProxyServer -ErrorAction SilentlyContinue
}

if ($Stop) {
    Stop-Process -Name "spoofdpi" -Force -ErrorAction SilentlyContinue
    Set-ProxyOff
    Write-Host "[+] Proxy disabled, SpoofDPI stopped."
    exit 0
}

Write-Host "==================================================="
Write-Host "  Discord Kostebek - Temporary Mode (Windows)"
Write-Host "==================================================="

# Install if missing
if (-not (Test-Path $SpoofDPIBin)) {
    Write-Host "[*] SpoofDPI not found, downloading..."
    & "$PSScriptRoot\manage-service.ps1" -Action install
    # After install, we run temp manually, so stop the scheduled task
    schtasks /End /TN "DiscordKostebek" 2>$null
    schtasks /Delete /TN "DiscordKostebek" /F 2>$null
}

if (-not (Test-Path $SpoofDPIBin)) {
    Write-Host "[-] SpoofDPI could not be installed. Exiting."
    exit 1
}

# Enable proxy
Set-ProxyOn
Write-Host "[+] Proxy enabled on 127.0.0.1:8080"
Write-Host ""
Write-Host "[+] SpoofDPI STARTED!"
Write-Host "[!] Keep this window open while using Discord."
Write-Host "[!] Press Ctrl+C to stop."
Write-Host "==================================================="

try {
    & $SpoofDPIBin --listen-addr 127.0.0.1:8080 --dns-mode https --https-split-mode chunk --https-chunk-size 1 --https-fake-count 1
} finally {
    Write-Host ""
    Write-Host "[*] Stopping, restoring proxy settings..."
    Set-ProxyOff
    Write-Host "[+] Done. Goodbye!"
}
