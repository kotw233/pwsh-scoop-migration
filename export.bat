@echo off
cd /d "%~dp0"
echo.
echo ========================================
echo   导出 Scoop 配置
echo ========================================
echo.
pwsh -NoProfile -ExecutionPolicy Bypass -File "export-scoop.ps1"
echo.
echo Press any key to exit...
pause >nul
