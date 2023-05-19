@echo off
setlocal enabledelayedexpansion
set adapterName=
for /f "tokens=2 delims=: " %%a in ('netsh interface show interface ^| findstr /c:"Ethernet" /c:"Connected"') do (
    if not defined adapterName set adapterName=%%a
)
for /f "tokens=2 delims=:" %%a in ('ipconfig ^| findstr /c:"!adapterName!" /c:"IPv4 Address"') do set ip=%%a
echo IP Address: %ip%
for /f "tokens=3 delims=: " %%a in ('netsh interface ip show config name="!adapterName!" ^| findstr /c:"DHCP enabled"') do set dhcp=%%a
echo DHCP Enabled: %dhcp%
for /f "tokens=3 delims=: " %%a in ('systeminfo ^| findstr /c:"Domain"') do set domain=%%a
echo Domain: %domain%
endlocal
pause

