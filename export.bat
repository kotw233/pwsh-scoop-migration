@echo off
cd /d "%~dp0"
echo.
echo ========================================
echo   Export Scoop Config
echo ========================================
echo.
pwsh -NoProfile -ExecutionPolicy Bypass -File "%~dp0export-scoop.ps1"
echo.
echo Press any key to exit...
pause >nul
