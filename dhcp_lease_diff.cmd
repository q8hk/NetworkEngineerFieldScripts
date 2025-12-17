@echo off
setlocal
set "SCRIPT_DIR=%~dp0"
powershell -NoProfile -ExecutionPolicy Bypass -File "%SCRIPT_DIR%dhcp_lease_diff.ps1" %*
exit /b %errorlevel%
