@echo off
setlocal EnableExtensions EnableDelayedExpansion
REM Network Engineer Field Toolkit - IP conflict detection utility

set "SCRIPT_NAME=%~nx0"
set "SCRIPT_DIR=%~dp0"
set "MAX_SECONDS=60"
set "RESULT=INCONCLUSIVE"
set "EXIT_CODE=3"
set "LOG_DIR=%SCRIPT_DIR%logs"

if not exist "%LOG_DIR%" (
    mkdir "%LOG_DIR%" >nul 2>&1
)

call :parse_args %*
if errorlevel 1 exit /b %errorlevel%

call :init_logging
if errorlevel 1 exit /b %errorlevel%

call :log "============================================================"
call :log " IP Conflict Detector"
call :log "============================================================"
call :log " Target IP      : %TARGET_IP%"
call :log " Started        : %HUMAN_TIMESTAMP%"
call :log " Hostname       : %COMPUTERNAME%"
call :log " Runtime limit  : %MAX_SECONDS% seconds"
call :log "------------------------------------------------------------"

if "%SELF_TEST%"=="1" (
    call :self_test
    call :finalize
    exit /b %EXIT_CODE%
)

set "MACS="
set "OBSERVATION_COUNT=0"
set "PING_FAILURES=0"

for /L %%S in (1,1,%MAX_SECONDS%) do (
    call :tick %%S
    if "!RESULT!"=="CONFLICT" goto :finish_loop
    ping -n 2 127.0.0.1 >nul
)

:finish_loop
call :finalize
exit /b %EXIT_CODE%

REM ----------------------------------------------------------
:parse_args
if "%~1"=="" (
    call :usage
    exit /b 2
)

if /I "%~1"=="-h"  goto usage
if /I "%~1"=="--help" goto usage
if "%~1"=="/?" goto usage

if /I "%~1"=="--self-test" (
    set "SELF_TEST=1"
    set "TARGET_IP=0.0.0.0"
    exit /b 0
)

set "SELF_TEST=0"
set "TARGET_IP=%~1"
echo %TARGET_IP%| findstr /R "^[0-9][0-9]*\.[0-9][0-9]*\.[0-9][0-9]*\.[0-9][0-9]*$" >nul 2>&1
if errorlevel 1 (
    echo Invalid IP address: %TARGET_IP%
    exit /b 2
)
exit /b 0

:usage
echo %SCRIPT_NAME% - Detect duplicate ARP entries for an IP.
echo.
echo Usage:
echo   %SCRIPT_NAME% ^<IP_ADDRESS^>
echo   %SCRIPT_NAME% --self-test
echo.
echo Options:
echo   -h, --help, /?   Show this help and exit (code 2).
echo   --self-test      Verify required commands without probing the network.
echo.
echo Exit codes:
echo   0 = No conflict observed
echo   1 = Conflict detected or inconclusive/problem condition
echo   2 = Usage error
echo   3 = Unexpected failure
exit /b 2

REM ----------------------------------------------------------
:init_logging
set "HUMAN_TIMESTAMP=%DATE% %TIME%"
for /f "usebackq tokens=1" %%T in (`powershell -NoProfile -Command "Get-Date -Format \"yyyyMMdd-HHmmss\"" 2^>nul`) do (
    set "TS=%%T"
)
if "%TS%"=="" set "TS=%DATE:~6,4%%DATE:~3,2%%DATE:~0,2%-%TIME:~0,2%%TIME:~3,2%%TIME:~6,2%"
set "SAFE_IP=%TARGET_IP::=-%"
set "LOG_FILE=%LOG_DIR%\\ip_conflict_%TS%_%SAFE_IP%.log"
break > "%LOG_FILE%" 2>nul || (
    echo Failed to create log file: "%LOG_FILE%"
    exit /b 3
)
exit /b 0

REM ----------------------------------------------------------
:log
echo %~1
>>"%LOG_FILE%" echo %~1
exit /b 0

REM ----------------------------------------------------------
:self_test
call :log "[SELF-TEST] Checking required commands..."
for %%C in (ping arp findstr timeout hostname) do (
    where %%C >nul 2>&1
    if errorlevel 1 (
        call :log "  - %%C : MISSING"
        set "EXIT_CODE=1"
    ) else (
        call :log "  - %%C : OK"
    )
)
if "%EXIT_CODE%"=="3" set "EXIT_CODE=0"
if "%EXIT_CODE%"=="1" set "RESULT=INCONCLUSIVE"
if "%EXIT_CODE%"=="0" set "RESULT=NO CONFLICT"
exit /b 0

REM ----------------------------------------------------------
:tick
set "ITERATION=%~1"
call :log "[%ITERATION%/%MAX_SECONDS%] Probing %TARGET_IP% ..."
ping -n 1 %TARGET_IP% >nul 2>&1
set "PING_STATUS=%errorlevel%"
if not "%PING_STATUS%"=="0" set /a PING_FAILURES+=1

set "FOUND_THIS_ROUND=0"
for /f "tokens=2" %%M in ('arp -a %TARGET_IP% ^| findstr /R /I "[0-9A-F][0-9A-F]-[0-9A-F][0-9A-F]"') do (
    set "MAC=%%M"
    set "FOUND_THIS_ROUND=1"
    echo !MACS! | find /I "!MAC!" >nul
    if errorlevel 1 (
        set "MACS=!MACS! !MAC!"
        call :log "  New MAC seen: !MAC!"
    )
)

if "!FOUND_THIS_ROUND!"=="1" (
    call :count_macs
    if !MAC_COUNT! GTR 1 (
        set "RESULT=CONFLICT"
        set "EXIT_CODE=1"
        call :log "  Multiple MACs observed for %TARGET_IP%: !MACS!"
        goto :eof
    ) else (
        set "RESULT=NO CONFLICT"
        set "EXIT_CODE=0"
    )
) else (
    if "!RESULT!"=="INCONCLUSIVE" (
        set "RESULT=INCONCLUSIVE"
        set "EXIT_CODE=1"
    )
)
exit /b 0

REM ----------------------------------------------------------
:count_macs
set "MAC_COUNT=0"
for %%C in (!MACS!) do set /a MAC_COUNT+=1
exit /b 0

REM ----------------------------------------------------------
:finalize
call :log "------------------------------------------------------------"
call :log " Result    : !RESULT!"
call :log " Observed MAC(s): !MACS!"
call :log " Ping failures  : !PING_FAILURES!"
call :log " Log file       : !LOG_FILE!"
call :log " Finished       : %DATE% %TIME%"
call :log "============================================================"
exit /b %EXIT_CODE%
