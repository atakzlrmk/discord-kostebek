# ==========================================================
# Discord Kostebek - Service Manager (Windows)
# Usage: Run as Administrator: .\manage-service.ps1 <action>
# Actions: install, pause, resume, uninstall
# ==========================================================

param(
    [Parameter(Mandatory=$true)]
    [ValidateSet("install", "pause", "resume", "uninstall")]
    [string]$Action
)

$TaskName = "DiscordKostebek"
$SpoofDPIDir = "$env:LOCALAPPDATA\SpoofDPI"
$SpoofDPIBin = "$SpoofDPIDir\spoofdpi.exe"
$SpoofDPIArgs = "--listen-addr 127.0.0.1:8080 --dns-mode https --https-split-mode chunk --https-chunk-size 1 --https-fake-count 1 --system-proxy"

function Set-ProxyOn {
    $reg = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Internet Settings"
    Set-ItemProperty -Path $reg -Name ProxyEnable -Value 1
    Set-ItemProperty -Path $reg -Name ProxyServer -Value "127.0.0.1:8080"
    Write-Host "[+] System proxy enabled (127.0.0.1:8080)"
}

function Set-ProxyOff {
    $reg = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Internet Settings"
    Set-ItemProperty -Path $reg -Name ProxyEnable -Value 0
    Remove-ItemProperty -Path $reg -Name ProxyServer -ErrorAction SilentlyContinue
    Write-Host "[+] System proxy disabled"
}

function Install-SpoofDPI {
    if (Test-Path $SpoofDPIBin) {
        Write-Host "[*] SpoofDPI already installed at $SpoofDPIBin"
        return $true
    }

    Write-Host "[*] Downloading SpoofDPI..."
    New-Item -ItemType Directory -Force -Path $SpoofDPIDir | Out-Null

    # Determine architecture
    $arch = if ([Environment]::Is64BitOperatingSystem) { "amd64" } else { "386" }

    # Get latest release URL from GitHub
    try {
        $releases = Invoke-RestMethod -Uri "https://api.github.com/repos/xvzc/SpoofDPI/releases/latest"
        $asset = $releases.assets | Where-Object { $_.name -match "windows.*$arch.*\.zip$" -or $_.name -match "windows.*$arch.*\.tar\.gz$" } | Select-Object -First 1

        if (-not $asset) {
            # Try direct zip pattern
            $asset = $releases.assets | Where-Object { $_.name -match "windows" -and $_.name -match "$arch" } | Select-Object -First 1
        }

        if (-not $asset) {
            Write-Host "[-] Could not find matching release for Windows $arch"
            return $false
        }

        $downloadUrl = $asset.browser_download_url
        $downloadPath = "$env:TEMP\spoofdpi_download"

        Write-Host "[*] Downloading from: $downloadUrl"
        Invoke-WebRequest -Uri $downloadUrl -OutFile $downloadPath

        # Extract based on file extension
        if ($asset.name -match "\.zip$") {
            Expand-Archive -Path $downloadPath -DestinationPath $SpoofDPIDir -Force
        } elseif ($asset.name -match "\.tar\.gz$") {
            tar -xzf $downloadPath -C $SpoofDPIDir
        }

        Remove-Item $downloadPath -Force -ErrorAction SilentlyContinue

        # Find the executable in extracted files
        $exe = Get-ChildItem -Path $SpoofDPIDir -Recurse -Filter "spoofdpi.exe" | Select-Object -First 1
        if ($exe -and $exe.FullName -ne $SpoofDPIBin) {
            Move-Item $exe.FullName $SpoofDPIBin -Force
        }
    } catch {
        Write-Host "[-] Download failed: $_"
        return $false
    }

    if (Test-Path $SpoofDPIBin) {
        Write-Host "[+] SpoofDPI installed to $SpoofDPIBin"
        return $true
    } else {
        Write-Host "[-] SpoofDPI installation failed"
        return $false
    }
}

switch ($Action) {
    "install" {
        $installed = Install-SpoofDPI
        if (-not $installed) { exit 1 }

        # Remove existing task if any
        schtasks /Delete /TN $TaskName /F 2>$null

        # Create scheduled task that runs at logon
        $taskAction = "`"$SpoofDPIBin`" $SpoofDPIArgs"
        schtasks /Create /TN $TaskName /TR $taskAction /SC ONLOGON /RL HIGHEST /F
        schtasks /Run /TN $TaskName

        Set-ProxyOn
        Write-Host "[OK] Background service installed and started."
    }

    "pause" {
        schtasks /End /TN $TaskName 2>$null
        schtasks /Change /TN $TaskName /DISABLE 2>$null
        Stop-Process -Name "spoofdpi" -Force -ErrorAction SilentlyContinue
        Set-ProxyOff
        Write-Host "[OK] Service paused."
    }

    "resume" {
        schtasks /Change /TN $TaskName /ENABLE 2>$null
        schtasks /Run /TN $TaskName
        Set-ProxyOn
        Write-Host "[OK] Service resumed."
    }

    "uninstall" {
        schtasks /End /TN $TaskName 2>$null
        schtasks /Delete /TN $TaskName /F 2>$null
        Stop-Process -Name "spoofdpi" -Force -ErrorAction SilentlyContinue
        Set-ProxyOff
        Remove-Item $SpoofDPIBin -Force -ErrorAction SilentlyContinue
        Remove-Item $SpoofDPIDir -Recurse -Force -ErrorAction SilentlyContinue
        Write-Host "[OK] Service uninstalled and cleaned up."
    }
}
