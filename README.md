# 👾 Discord Kostebek

> [!NOTE]
> 🇹🇷 **[Türkçe README için aşağıya kaydırın / Scroll down for Turkish](#-türkçe)**

A simple, cross-platform DPI bypass tool for Discord. Wraps [SpoofDPI](https://github.com/xvzc/SpoofDPI) with a web dashboard and background service management. Built for Turkish ISPs (Superonline, Turknet, etc.) that block Discord via deep packet inspection.

**Supports: macOS · Windows · Linux**

## ✨ Features

- **Web Dashboard** — Discord-themed UI to manage the bypass service
- **Background Service** — Auto-starts on boot (LaunchDaemon / Task Scheduler / Systemd)
- **Service Lifecycle** — Install, pause, resume, repair, or uninstall with one click
- **Cross-Platform** — Works on macOS, Windows, and Linux
- **Multilingual** — Turkish / English toggle in the UI

## 🚀 Quick Start

### macOS
Double-click **`open-dashboard.command`** in Finder.

### Windows
Double-click **`open-dashboard.bat`**.

### Linux (CLI)
```bash
./cli-menu.command
```

Your browser opens a dashboard where you can install, pause, and manage everything.

## 📁 Project Structure

```
discord_kostebek/
├── kostebek.sh             # macOS/Linux core: menu, dashboard, temp, service
├── cli-menu.command        # macOS/Linux CLI launcher
├── open-dashboard.command  # macOS dashboard launcher
├── open-dashboard.bat      # Windows dashboard launcher
├── server.py               # HTTP server (serves UI + API)
├── manage-service.sh       # macOS/Linux compatibility wrapper
├── run-temp.sh             # macOS/Linux compatibility wrapper
├── manage-service.ps1      # Windows:     install, pause, resume, uninstall
├── run-temp.ps1            # Windows:     temporary foreground runner
├── web/
│   ├── index.html
│   ├── style.css
│   └── app.js
└── README.md
```

### Architecture

```
User clicks button in Dashboard
        ↓
    app.js → POST /api/action
        ↓
    server.py (detects OS)
        ↓
    ┌─────────────────┬─────────────────────┐
    │  macOS / Linux   │      Windows        │
    │  manage-service.sh │  manage-service.ps1 │
    └─────────────────┴─────────────────────┘
        ↓
    launchctl / systemctl / schtasks + SpoofDPI
```

On macOS/Linux, service management now flows through **`kostebek.sh`**. The older `.command` and `.sh` files are kept as small launchers so existing shortcuts still work.

## 🛠 Requirements

| Platform | Requirements |
|----------|-------------|
| macOS | Python 3+ (pre-installed) |
| Windows | Python 3+ ([python.org](https://python.org)) |
| Linux | Python 3+ |

---

# 🇹🇷 Türkçe

Discord'a uygulanan DPI engelini aşmak için basit ve cross-platform bir araç. [SpoofDPI](https://github.com/xvzc/SpoofDPI) üzerine web arayüzü ve arkaplan servisi yönetimi ekler.

**Desteklenen platformlar: macOS · Windows · Linux**

## ✨ Özellikler

- **Web Arayüzü** — Discord temalı kontrol paneli
- **Arkaplan Servisi** — Her açılışta otomatik çalışır (LaunchDaemon / Görev Zamanlayıcı / Systemd)
- **Servis Yönetimi** — Kurma, duraklatma, devam ettirme veya kaldırma
- **Cross-Platform** — macOS, Windows ve Linux desteği
- **Çoklu Dil** — Arayüzde Türkçe / İngilizce geçişi

## 🚀 Hızlı Başlangıç

### macOS
Finder'da **`open-dashboard.command`** dosyasına çift tıklayın.

### Windows
**`open-dashboard.bat`** dosyasına çift tıklayın.

### Linux (Terminal)
```bash
./cli-menu.command
```

## 📁 Dosya Yapısı

```
discord_kostebek/
├── kostebek.sh             # macOS/Linux ana komut dosyası
├── cli-menu.command        # macOS/Linux terminal menüsü
├── open-dashboard.command  # macOS web arayüz başlatıcı
├── open-dashboard.bat      # Windows web arayüz başlatıcı
├── server.py               # HTTP sunucu (UI + API)
├── manage-service.sh       # macOS/Linux uyumluluk wrapper'ı
├── run-temp.sh             # macOS/Linux uyumluluk wrapper'ı
├── manage-service.ps1      # Windows:     kur, duraklat, devam et, kaldır
├── run-temp.ps1            # Windows:     geçici çalıştırma
├── web/
│   ├── index.html
│   ├── style.css
│   └── app.js
└── README.md
```

## 🛠 Gereksinimler

| Platform | Gereksinim |
|----------|-----------|
| macOS | Python 3+ (hazır gelir) |
| Windows | Python 3+ ([python.org](https://python.org)) |
| Linux | Python 3+ |
