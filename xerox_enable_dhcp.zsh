#!/bin/zsh

if [[ $# -ne 3 ]]; then
    echo "Usage: $0 <printer_ip_address> <username> <password>"
    exit 1
fi

printer_ip="$1"
username="$2"
password="$3"

# Open Firefox and navigate to printer's web interface
open -a Firefox "http://${printer_ip}"
sleep 15 # Adjust delay as needed for the page to load

# Automate login and enable DHCP
osascript <<EOF
tell application "Firefox"
    activate
    delay 2
    tell application "System Events"
        keystroke "${username}" -- enter the username
        keystroke tab
        delay 1
        keystroke "${password}" -- enter the password
        keystroke return
        delay 3 -- adjust delay as needed for the page to load
        keystroke "Network Settings" -- adjust this according to your printer's interface
        keystroke return
        delay 2
        keystroke tab
        delay 1
        keystroke tab
        delay 1
        keystroke "DHCP" -- select DHCP option
        delay 1
        keystroke return
        delay 1
        keystroke "Save" -- click on save button
        delay 1
        keystroke return
    end tell
end tell

delay 3 -- adjust delay as needed for the settings to apply

-- Check if DHCP is successfully activated
tell application "Firefox"
    if (do JavaScript "document.body.innerText.includes('DHCP activated successfully')") then
        -- Restart the printer
        open location "http://${printer_ip}/restart"
    else
        display dialog "DHCP activation failed. Manual intervention may be required." buttons {"OK"} default button "OK"
    end if
end tell
EOF
