@echo off
setlocal
cd /d "%~dp0"
echo.
echo Deploying the portable RE lab. This can take a while on first run.
echo.
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0Deploy-RELab.ps1" %*
set EXITCODE=%ERRORLEVEL%
echo.
if not "%EXITCODE%"=="0" (
  echo Deployment finished with errors. See deploy.log and install-report.json.
) else (
  echo Deployment completed. Run Start-RELab.cmd to launch tools.
)
pause
exit /b %EXITCODE%
