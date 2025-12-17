@echo off
setlocal EnableDelayedExpansion

if "%~1"=="" (
  echo Usage: %~nx0 ^<IP_ADDRESS^>
  exit /b 1
)

set IP=%~1
set MACS=

:loop
ping -n 1 %IP% >nul

for /f "tokens=2" %%M in ('arp -a %IP% ^| findstr /R "[0-9A-Fa-f][0-9A-Fa-f]-"') do (
    echo !MACS! | find /I "%%M" >nul || (
        set MACS=!MACS! %%M
        call :count
        if !COUNT! GTR 1 (
            echo.
            echo ============================
            echo IP CONFLICT DETECTED
            echo IP: %IP%
            echo MAC addresses:
            for %%X in (!MACS!) do echo   %%X
            echo ============================
            exit /b 2
        )
    )
)

timeout /t 1 >nul
goto loop

:count
set COUNT=0
for %%C in (!MACS!) do set /a COUNT+=1
exit /b
