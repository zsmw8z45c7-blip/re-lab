@echo off
setlocal
cd /d "%~dp0"
title RE Lab - Uninstall
echo.
echo Removing RE Lab tools and download cache.
echo.
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0Uninstall-RELab.ps1" %*
set EXITCODE=%ERRORLEVEL%
echo.
pause
exit /b %EXITCODE%
