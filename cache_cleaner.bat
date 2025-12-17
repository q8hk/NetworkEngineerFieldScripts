@echo off
setlocal EnableExtensions EnableDelayedExpansion
REM Browser cache cleaner with dry-run and logging.

set "SCRIPT_NAME=%~nx0"
set "LOG_FILE=%~dp0logs\\cache_cleaner.log"
if not exist "%~dp0logs" mkdir "%~dp0logs" >nul 2>&1

set "DRY_RUN=1"
set "SELF_TEST=0"

call :parse_args %*
if errorlevel 1 exit /b %errorlevel%

if "%SELF_TEST%"=="1" (
    call :self_test
    exit /b %errorlevel%
)

call :log "=== %SCRIPT_NAME% run at %DATE% %TIME% ==="
if "%DRY_RUN%"=="1" (
    echo Dry-run mode: no files will be deleted.
    call :log "Dry-run mode"
) else (
    echo Deleting cache files...
    call :log "Deletion mode"
)

call :clean "Chrome" "%LOCALAPPDATA%\\Google\\Chrome\\User Data\\Default\\Cache\\*.*"
call :clean "Firefox" "%LOCALAPPDATA%\\Mozilla\\Firefox\\Profiles\\*\\cache2\\entries\\*.*"
call :clean "Edge" "%LOCALAPPDATA%\\Microsoft\\Edge\\User Data\\Default\\Cache\\*.*"
call :clean "Opera" "%LOCALAPPDATA%\\Opera Software\\Opera Stable\\Cache\\*.*"

echo Done.
call :log "Completed."
exit /b 0

:parse_args
if "%~1"=="" exit /b 0
if /I "%~1"=="-h" goto :usage
if /I "%~1"=="--help" goto :usage
if "%~1"=="/?" goto :usage
if /I "%~1"=="--apply" set "DRY_RUN=0" & shift & goto :parse_args
if /I "%~1"=="--dry-run" set "DRY_RUN=1" & shift & goto :parse_args
if /I "%~1"=="--self-test" set "SELF_TEST=1" & exit /b 0
echo Unknown option: %~1
goto :usage

:usage
echo %SCRIPT_NAME% - Clean browser caches safely.
echo.
echo Usage:
echo   %SCRIPT_NAME% [--dry-run ^| --apply] [--self-test]
echo Options:
echo   --dry-run      Default. Show what would be removed.
echo   --apply        Actually delete cache entries.
echo   --self-test    Check dependencies and exit.
echo   -h, --help     Show this help (exit code 2).
echo Exit codes: 0 success, 1 condition/problem, 2 usage error, 3 unexpected failure.
exit /b 2

:self_test
for %%C in (del findstr) do (
    where %%C >nul 2>&1
    if errorlevel 1 (
        echo %%C missing.
        exit /b 1
    )
)
echo Self-test passed.
exit /b 0

:log
>>"%LOG_FILE%" echo %~1
exit /b 0

:clean
set "BROWSER=%~1"
set "PATHS=%~2"
set "FOUND=0"
for %%P in (%PATHS%) do (
    if exist "%%~fP" (
        set "FOUND=1"
        if "%DRY_RUN%"=="1" (
            echo [%BROWSER%] Would remove %%~fP
            call :log "[DRY] %BROWSER% -> %%~fP"
        ) else (
            del /q /f /s "%%~fP" >nul 2>&1
            if errorlevel 1 (
                echo [%BROWSER%] Failed to delete %%~fP
                call :log "[FAIL] %BROWSER% -> %%~fP"
            ) else (
                echo [%BROWSER%] Cleared %%~fP
                call :log "[OK] %BROWSER% -> %%~fP"
            )
        )
    )
)
if "%FOUND%"=="0" (
    echo [%BROWSER%] Cache path not found.
    call :log "[SKIP] %BROWSER% cache not found"
)
exit /b 0
