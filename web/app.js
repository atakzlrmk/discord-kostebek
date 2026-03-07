const i18n = {
    tr: {
        subtitle: "DPI Bypass Kontrol Paneli",
        status_checking: "Durum Kontrol Ediliyor...",
        status_desc_checking: "Lütfen bekleyin, servis kontrol ediliyor.",
        btn_install: "Kur ve Başlat",
        btn_install_desc: "Arkaplan Servisi Kurar (Önerilen)",
        btn_pause: "Geçici Olarak Durdur",
        btn_pause_desc: "Arka Planı Bekletir / Duraklatır",
        btn_resume: "Servisi Sürdür",
        btn_resume_desc: "Arka Planı Yeniden Başlatır",
        btn_repair: "Servisi Onar",
        btn_repair_desc: "Bozulduysa Yeniden Üzerine Kur",
        btn_uninstall: "Kaldır ve Yok Et",
        btn_uninstall_desc: "Sistemden Tamamen Siler",
        btn_temp: "Terminalde Başlat (Geçici)",
        btn_temp_desc: "Sadece Açık Kaldığı Sürece Çalışır",
        btn_exit: "Arayüzü Kapat",
        footer: "Discord Türkiye engellemesini aşmak için geliştirilmiştir.",
        status_running_bg: "Servis Aktif (Arka Plan)",
        status_desc_bg: "SpoofDPI arka planda sorunsuz çalışıyor.",
        status_running_temp: "Servis Aktif (Geçici)",
        status_desc_temp: "SpoofDPI geçici terminal modunda çalışıyor.",
        status_paused: "Servis Bekletiliyor",
        status_desc_paused: "Arkaplan servisi kurulu ancak şu an durdurulmuş (pasif) durumda.",
        status_stopped: "Servis Kapalı",
        status_desc_stopped: "SpoofDPI şu anda kurulu değil ve çalışmıyor.",
        status_wait: "Bağlantı Bekleniyor...",
        status_desc_wait: "Sunucuyla iletişim kurulamıyor.",
        toast_install: "⏳ Kurulum başlatılıyor. Lütfen şifrenizi girin...",
        toast_pause: "⏳ Servis geçici olarak durduruluyor...",
        toast_resume: "⏳ Servis yeniden başlatılıyor...",
        toast_repair: "⏳ Onarım başlatılıyor. Lütfen şifrenizi girin...",
        toast_uninstall: "⏳ Servis sistemden tamamen siliniyor...",
        toast_temp: "⚡ Terminal açılıyor... Lütfen şifrenizi girin.",
        toast_success: "✅ İşlem başarıyla tamamlandı!",
        toast_error: "❗ Bir hata oluştu. Sunucu bağlantısını kontrol edin.",
        toast_exit: "🚪 Arayüz kapatılıyor... Sekmeyi kapatabilirsiniz.",
        exit_title: "Arayüz Kapatıldı",
        exit_desc: "Bu sekmeyi güvenle kapatabilirsiniz. Servis durumu değişmedi."
    },
    en: {
        subtitle: "DPI Bypass Dashboard",
        status_checking: "Checking Status...",
        status_desc_checking: "Please wait, verifying service state.",
        btn_install: "Install & Start",
        btn_install_desc: "Creates Background Service (Recommended)",
        btn_pause: "Pause Service",
        btn_pause_desc: "Temporarily Stop Background Process",
        btn_resume: "Resume Service",
        btn_resume_desc: "Restart the Background Process",
        btn_repair: "Repair Service",
        btn_repair_desc: "Reinstall if it's broken",
        btn_uninstall: "Remove & Uninstall",
        btn_uninstall_desc: "Deletes service from the system",
        btn_temp: "Run in Terminal (Temp)",
        btn_temp_desc: "Runs only while terminal is open",
        btn_exit: "Exit Dashboard",
        footer: "Developed to bypass Discord DPI block in Turkey.",
        status_running_bg: "Service Active (Background)",
        status_desc_bg: "SpoofDPI is running smoothly in the background.",
        status_running_temp: "Service Active (Temp)",
        status_desc_temp: "SpoofDPI is running in a temporary terminal.",
        status_paused: "Service Paused",
        status_desc_paused: "Background service is installed but currently stopped.",
        status_stopped: "Service Stopped",
        status_desc_stopped: "SpoofDPI is not installed and currently suspended.",
        status_wait: "Awaiting Connection...",
        status_desc_wait: "Cannot communicate with background server.",
        toast_install: "⏳ Installation starting. Enter password if prompted...",
        toast_pause: "⏳ Pausing service...",
        toast_resume: "⏳ Resuming service...",
        toast_repair: "⏳ Repairing. Enter password if prompted...",
        toast_uninstall: "⏳ Completely removing service...",
        toast_temp: "⚡ Opening terminal... Enter password if prompted.",
        toast_success: "✅ Action completed successfully!",
        toast_error: "❗ An error occurred. Check server connection.",
        toast_exit: "🚪 Closing UI... You can close this tab.",
        exit_title: "Dashboard Closed",
        exit_desc: "You can safely close this tab. Background state is saved."
    }
};

let currentLang = 'tr';
let currentStatus = 'stopped';

document.addEventListener('DOMContentLoaded', () => {
    checkStatus();
    setInterval(checkStatus, 3000);
    applyTranslations();
});

function toggleLanguage() {
    currentLang = currentLang === 'tr' ? 'en' : 'tr';
    const langBtn = document.getElementById('lang-btn');
    langBtn.innerText = currentLang === 'tr' ? '🇺🇸 EN' : '🇹🇷 TR';
    applyTranslations();
    updateUIStatus(currentStatus); // Refresh status text
}

function applyTranslations() {
    const els = document.querySelectorAll('[data-i18n]');
    els.forEach(el => {
        const key = el.getAttribute('data-i18n');
        if (i18n[currentLang][key]) {
            el.innerText = i18n[currentLang][key];
        }
    });
}

function t(key) {
    return i18n[currentLang][key] || key;
}

async function checkStatus() {
    try {
        const response = await fetch('/api/status');
        const data = await response.json();
        currentStatus = data.status;
        updateUIStatus(currentStatus);
        updateButtonsVisibility(currentStatus);
    } catch (e) {
        console.error("Fetch error:", e);
        updateUIStatus("error");
    }
}

function updateButtonsVisibility(status) {
    const btnStart = document.getElementById('btn-start');
    const btnPause = document.getElementById('btn-pause');
    const btnResume = document.getElementById('btn-resume');
    const btnRepair = document.getElementById('btn-repair');
    const btnUninstall = document.getElementById('btn-uninstall');

    // Reset all variable buttons
    btnStart.style.display = 'none';
    btnPause.style.display = 'none';
    btnResume.style.display = 'none';
    btnRepair.style.display = 'none';
    btnUninstall.style.display = 'none';

    if (status === 'bg_running') {
        btnPause.style.display = 'flex';
        btnRepair.style.display = 'flex';
        btnUninstall.style.display = 'flex';
    } else if (status === 'paused') {
        btnResume.style.display = 'flex';
        btnUninstall.style.display = 'flex';
    } else { // stopped or temp
        btnStart.style.display = 'flex';
    }
}

function updateUIStatus(status) {
    const dot = document.getElementById('status-dot');
    const text = document.getElementById('status-text');
    const desc = document.getElementById('status-desc');

    if (status === 'bg_running') {
        dot.className = 'dot active';
        text.innerText = t("status_running_bg");
        text.style.color = 'var(--success)';
        dot.style.backgroundColor = 'var(--success)';
        dot.style.boxShadow = '0 0 15px var(--success-glow)';
        desc.innerText = t("status_desc_bg");
    } else if (status === 'temp_running') {
        dot.className = 'dot active';
        text.innerText = t("status_running_temp");
        text.style.color = '#FEE75C';
        dot.style.backgroundColor = '#FEE75C';
        dot.style.boxShadow = '0 0 15px rgba(254, 231, 92, 0.5)';
        desc.innerText = t("status_desc_temp");
    } else if (status === 'paused') {
        dot.className = 'dot';
        text.innerText = t("status_paused");
        text.style.color = '#FFA500'; // Orange
        dot.style.backgroundColor = '#FFA500';
        dot.style.boxShadow = '0 0 10px rgba(255, 165, 0, 0.5)';
        desc.innerText = t("status_desc_paused");
    } else if (status === 'stopped') {
        dot.className = 'dot inactive';
        text.innerText = t("status_stopped");
        text.style.color = 'var(--text-white)';
        desc.innerText = t("status_desc_stopped");
    } else {
        dot.className = 'dot';
        dot.style.backgroundColor = '#949BA4';
        text.innerText = t("status_wait");
        text.style.color = 'var(--text-muted)';
        desc.innerText = t("status_desc_wait");
    }
}

async function handleAction(action) {
    if (action === 'start_bg') showToast(t("toast_install"), "✨");
    else if (action === 'pause_bg') showToast(t("toast_pause"), "⏸️");
    else if (action === 'resume_bg') showToast(t("toast_resume"), "▶️");
    else if (action === 'repair_bg') showToast(t("toast_repair"), "🛠️");
    else if (action === 'uninstall_bg') showToast(t("toast_uninstall"), "🗑️");
    else if (action === 'start_temp') showToast(t("toast_temp"), "🔄");

    try {
        document.getElementById('status-loader').classList.add('loading');
        const response = await fetch('/api/action', {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({ action: action })
        });

        if (response.ok) {
            setTimeout(() => {
                showToast(t("toast_success"), "🎉");
                checkStatus();
                document.getElementById('status-loader').classList.remove('loading');
            }, 1000);
        } else {
            throw new Error('Server error');
        }
    } catch (e) {
        showToast(t("toast_error"), "⚠️");
        document.getElementById('status-loader').classList.remove('loading');
    }
}

function handleExit() {
    showToast(t("toast_exit"), "👋");
    setTimeout(() => {
        window.close();
        document.body.innerHTML = `
            <div style="display:flex; justify-content:center; align-items:center; height:100vh; flex-direction:column; color:white; font-family:var(--font);">
                <div style="font-size: 48px; margin-bottom:20px;">🎉</div>
                <h2 style="margin-bottom:10px;">${t("exit_title")}</h2>
                <p style="color:#949BA4">${t("exit_desc")}</p>
            </div>
        `;
    }, 1500);
}

function showToast(message, icon) {
    const toast = document.getElementById('toast');
    const msg = document.getElementById('toast-msg');
    const iconEl = toast.querySelector('.toast-icon');

    msg.innerText = message;
    iconEl.innerText = icon;

    toast.classList.add('show');
    setTimeout(() => { toast.classList.remove('show'); }, 4000);
}
