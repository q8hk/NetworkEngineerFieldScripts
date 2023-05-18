@echo off

if exist "%LOCALAPPDATA%\Google\Chrome\User Data\Default\Cache" (
    echo Deleting Chrome cache...
    del /q /f /s "%LOCALAPPDATA%\Google\Chrome\User Data\Default\Cache\*.*"
    echo Chrome cache deleted.
) else (
    echo Chrome not installed.
)

if exist "%LOCALAPPDATA%\Mozilla\Firefox\Profiles" (
    echo Deleting Firefox cache...
    del /q /f /s "%LOCALAPPDATA%\Mozilla\Firefox\Profiles\*\cache2\entries\*.*"
    echo Firefox cache deleted.
) else (
    echo Firefox not installed.
)

if exist "%LOCALAPPDATA%\Microsoft\Edge\User Data\Default\Cache" (
    echo Deleting Edge cache...
    del /q /f /s "%LOCALAPPDATA%\Microsoft\Edge\User Data\Default\Cache\*.*"
    echo Edge cache deleted.
) else (
    echo Edge not installed.
)

if exist "%LOCALAPPDATA%\Opera Software\Opera Stable\Cache" (
    echo Deleting Opera cache...
    del /q /f /s "%LOCALAPPDATA%\Opera Software\Opera Stable\Cache\*.*"
    echo Opera cache deleted.
) else (
    echo Opera not installed.
)

echo Deleting Windows temporary files...
del /q /f /s "%TEMP%\*.*"
echo Windows temporary files deleted.

echo Done!
echo Press any key to close this window...
pause >nul
