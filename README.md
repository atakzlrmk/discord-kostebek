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
├── open-dashboard.command  # macOS entry point
├── open-dashboard.bat      # Windows entry point
├── server.py               # Cross-platform HTTP server (serves UI + API)
├── manage-service.sh       # macOS/Linux: install, pause, resume, uninstall
├── manage-service.ps1      # Windows:     install, pause, resume, uninstall
├── run-temp.sh             # macOS/Linux: temporary foreground runner
├── run-temp.ps1            # Windows:     temporary foreground runner
├── cli-menu.command        # CLI menu (macOS/Linux)
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

All service management flows through **one script per platform**. The dashboard and CLI both call the same scripts — no duplicated logic.

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
├── open-dashboard.command  # macOS giriş noktası
├── open-dashboard.bat      # Windows giriş noktası
├── server.py               # Cross-platform sunucu (UI + API)
├── manage-service.sh       # macOS/Linux: kur, duraklat, devam et, kaldır
├── manage-service.ps1      # Windows:     kur, duraklat, devam et, kaldır
├── run-temp.sh             # macOS/Linux: geçici çalıştırma
├── run-temp.ps1            # Windows:     geçici çalıştırma
├── cli-menu.command        # Terminal menüsü (macOS/Linux)
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
