@echo off
setlocal
cd /d "%~dp0"
title RE Lab - Deploy
echo.
echo ==========================================
echo   RE Lab - one-click deploy
echo ==========================================
echo.
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0Deploy-RELab.ps1" %*
set EXITCODE=%ERRORLEVEL%
echo.
if not "%EXITCODE%"=="0" (
  echo Deploy finished with errors. See deploy.log and install-report.json.
) else (
  echo Deploy complete. See README.md for usage.
)
pause
exit /b %EXITCODE%
