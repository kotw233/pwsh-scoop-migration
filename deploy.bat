@echo off
cd /d "%~dp0"
pwsh -NoProfile -ExecutionPolicy Bypass -File "deploy.ps1" %*
echo.
echo Press any key to exit...
pause >nul
