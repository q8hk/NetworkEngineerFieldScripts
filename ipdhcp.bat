@echo off
setlocal EnableExtensions EnableDelayedExpansion
REM Display DHCP status and optionally enable DHCP on an interface.

set "SCRIPT_NAME=%~nx0"
set "LOG_FILE=%~dp0logs\\ipdhcp.log"

if not exist "%~dp0logs" mkdir "%~dp0logs" >nul 2>&1

call :parse_args %*
if errorlevel 1 exit /b %errorlevel%

if "%SELF_TEST%"=="1" (
    call :self_test
    exit /b %errorlevel%
)

call :log "=== %SCRIPT_NAME% run at %DATE% %TIME% ==="
if "%APPLY%"=="0" call :log "[INFO] Dry-run: no changes will be applied."

call :find_adapter
if errorlevel 3 exit /b 3

call :show_status

if "%APPLY%"=="1" (
    call :enable_dhcp
)

exit /b %ERRORLEVEL%

:parse_args
set "APPLY=0"
set "SELF_TEST=0"
if "%~1"=="" goto :usage

:arg_loop
if "%~1"=="" exit /b 0
if /I "%~1"=="-h" goto :usage
if /I "%~1"=="--help" goto :usage
if "%~1"=="/?" goto :usage
if /I "%~1"=="--apply" set "APPLY=1" & shift & goto :arg_loop
if /I "%~1"=="--dry-run" set "APPLY=0" & shift & goto :arg_loop
if /I "%~1"=="--self-test" set "SELF_TEST=1" & exit /b 0
echo Unknown option: %~1
goto :usage

:usage
echo %SCRIPT_NAME% - Report DHCP status or enable DHCP on a Windows interface.
echo.
echo Usage:
echo   %SCRIPT_NAME% [--dry-run ^| --apply] [--self-test]
echo.
echo Options:
echo   --dry-run      Default. Do not change settings.
echo   --apply        Enable DHCP on the first connected Ethernet/Wi-Fi adapter.
echo   --self-test    Check required commands and exit.
echo   -h, --help     Show this help (exit code 2).
echo.
echo Exit codes: 0 success, 1 detected condition/problem, 2 usage error, 3 unexpected failure.
exit /b 2

:self_test
set "RC=0"
for %%C in (netsh ipconfig findstr) do (
    where %%C >nul 2>&1
    if errorlevel 1 (
        echo %%C missing.
        set "RC=1"
    ) else (
        echo %%C OK.
    )
)
if "%RC%"=="0" (
    echo Self-test passed.
) else (
    echo Self-test reported missing dependencies.
)
exit /b %RC%

:log
>>"%LOG_FILE%" echo %~1
exit /b 0

:find_adapter
set "ADAPTER_NAME="
for /f "tokens=2,* delims=: " %%A in ('netsh interface show interface ^| findstr /I /C:"Connected"') do (
    if not defined ADAPTER_NAME set "ADAPTER_NAME=%%B"
)
if not defined ADAPTER_NAME (
    echo No connected adapter found.
    exit /b 1
)
exit /b 0

:show_status
echo Adapter: %ADAPTER_NAME%
for /f "tokens=3 delims=: " %%A in ('netsh interface ip show config name^="%ADAPTER_NAME%" ^| findstr /I "DHCP enabled"') do (
    echo DHCP Enabled: %%A
    call :log "DHCP Enabled: %%A"
)
for /f "tokens=2 delims=:" %%A in ('ipconfig ^| findstr /I /C:"IPv4 Address"') do (
    set "IP_ADDR=%%A"
    echo Current IPv4: !IP_ADDR!
    call :log "Current IPv4: !IP_ADDR!"
    goto :after_ip
)
:after_ip
for /f "tokens=3 delims=: " %%A in ('systeminfo ^| findstr /I /C:"Domain"') do (
    echo Domain: %%A
    call :log "Domain: %%A"
    goto :after_domain
)
:after_domain
exit /b 0

:enable_dhcp
echo Enabling DHCP on %ADAPTER_NAME%...
call :log "Applying DHCP enable on %ADAPTER_NAME%"
netsh interface ip set address name="%ADAPTER_NAME%" source=dhcp >nul 2>&1
if errorlevel 1 (
    echo Failed to enable DHCP.
    call :log "Failed to enable DHCP"
    exit /b 1
)
echo DHCP enabled. Renewing lease...
ipconfig /renew "%ADAPTER_NAME%" >nul 2>&1
if errorlevel 1 (
    echo DHCP enabled but lease renewal failed.
    call :log "Renew failed"
    exit /b 1
)
echo DHCP enable completed.
exit /b 0
