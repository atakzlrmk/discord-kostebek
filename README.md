# Discord Kostebek

> [!NOTE]
> 🇹🇷 **[Türkçe README için aşağıya kaydırın / Scroll down for Turkish](#-türkçe)**

A small CLI wrapper around [SpoofDPI](https://github.com/xvzc/SpoofDPI) for Discord DPI bypass. Built for Turkish ISPs that block Discord via deep packet inspection.

**CLI-first for macOS/Linux. Windows service scripts are still included.**

## Features

- **Background Service** — Auto-starts on boot (LaunchDaemon / Task Scheduler / Systemd)
- **Temporary Mode** — Runs in the current terminal and cleans proxy settings on exit
- **Service Lifecycle** — Install, pause, resume, or uninstall

## Quick Start

### macOS / Linux

Run the core CLI script directly:

```bash
sudo ./kostebek.sh temp       # run until the terminal is closed
./kostebek.sh status          # show current state
sudo ./kostebek.sh install    # install and start background service
sudo ./kostebek.sh pause
sudo ./kostebek.sh resume
sudo ./kostebek.sh uninstall
```

### Windows

Run PowerShell as Administrator:

```powershell
.\manage-service.ps1 install
.\manage-service.ps1 pause
.\manage-service.ps1 resume
.\manage-service.ps1 uninstall
```

## Project Structure

```
discord_kostebek/
├── kostebek.sh             # macOS/Linux core: menu, temp, service
├── manage-service.ps1      # Windows:     install, pause, resume, uninstall
└── README.md
```

On macOS/Linux, everything flows through **`kostebek.sh`**.

## Requirements

| Platform | Requirements |
|----------|-------------|
| macOS | bash, curl, tar, networksetup |
| Linux | bash, curl, tar, systemd |
| Windows | PowerShell |

---

# 🇹🇷 Türkçe

[SpoofDPI](https://github.com/xvzc/SpoofDPI) etrafında küçük bir CLI aracıdır. Discord DPI engelini aşmak için macOS/Linux tarafında terminal ve servis yönetimi sağlar.

**macOS/Linux için CLI odaklıdır. Windows servis scriptleri korunmuştur.**

## Özellikler

- **Arkaplan Servisi** — Her açılışta otomatik çalışır (LaunchDaemon / Görev Zamanlayıcı / Systemd)
- **Geçici Mod** — Terminal açık kaldığı sürece çalışır, çıkışta proxy ayarını temizler
- **Servis Yönetimi** — Kurma, duraklatma, devam ettirme veya kaldırma

## Hızlı Başlangıç

### macOS / Linux

Ana CLI scriptini doğrudan çağırın:

```bash
sudo ./kostebek.sh temp
./kostebek.sh status
sudo ./kostebek.sh install
sudo ./kostebek.sh pause
sudo ./kostebek.sh resume
sudo ./kostebek.sh uninstall
```

### Windows

PowerShell'i Administrator olarak açın:

```powershell
.\manage-service.ps1 install
.\manage-service.ps1 pause
.\manage-service.ps1 resume
.\manage-service.ps1 uninstall
```

## Dosya Yapısı

```
discord_kostebek/
├── kostebek.sh             # macOS/Linux ana CLI ve servis scripti
├── manage-service.ps1      # Windows:     kur, duraklat, devam et, kaldır
└── README.md
```

## Gereksinimler

| Platform | Gereksinim |
|----------|-----------|
| macOS | bash, curl, tar, networksetup |
| Linux | bash, curl, tar, systemd |
| Windows | PowerShell |
