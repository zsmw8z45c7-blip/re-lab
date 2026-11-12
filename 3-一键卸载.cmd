@echo off
setlocal
cd /d "%~dp0"
title RE Lab - Uninstall
echo.
echo ==========================================
echo   RE Lab - one-click uninstall
echo ==========================================
echo.
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0Uninstall-RELab.ps1" %*
set EXITCODE=%ERRORLEVEL%
echo.
pause
exit /b %EXITCODE%
