@echo off
title Discord Kostebek Dashboard
echo ==========================================================
echo              Discord Kostebek Dashboard
echo ==========================================================
echo Starting server, please wait...

:: Find Python
where python >nul 2>&1
if %ERRORLEVEL% neq 0 (
    where python3 >nul 2>&1
    if %ERRORLEVEL% neq 0 (
        echo [-] Python not found. Please install Python 3 from https://python.org
        pause
        exit /b 1
    )
    set PYTHON=python3
) else (
    set PYTHON=python
)

:: Find available port
set PORT=1337

:: Start server
start "" %PYTHON% "%~dp0server.py" %PORT%
timeout /t 2 /nobreak >nul

:: Open browser
start http://localhost:%PORT%

echo.
echo [SUCCESS] Dashboard opened in your browser!
echo If it didn't open, go to: http://localhost:%PORT%
echo.
echo [!] WARNING: If you close this window, the UI will close.
echo Background SpoofDPI (if active) will continue working.
echo.
pause
