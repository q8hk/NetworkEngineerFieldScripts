#!/usr/bin/env zsh

set -euo pipefail

SCRIPT_NAME="${0:t}"
DRY_RUN=0
PRINTER_IP=""
USERNAME=""
PASSWORD=""

usage() {
    cat <<EOF
$SCRIPT_NAME - Assist enabling DHCP on Xerox WorkCentre via Firefox (macOS).

Usage:
  $SCRIPT_NAME <printer_ip> <username> <password> [--dry-run]

Notes:
  - Opens Firefox and uses AppleScript keystrokes; keep focus on Firefox.
  - Designed to be conservative: no actions are taken in --dry-run mode.
  - Exit codes: 0 success, 1 detected issue, 2 usage error, 3 unexpected failure.

Examples:
  $SCRIPT_NAME 192.0.2.15 admin mypass
  $SCRIPT_NAME 192.0.2.15 admin mypass --dry-run
EOF
}

if [[ "$#" -lt 3 ]]; then
    usage
    exit 2
fi

PRINTER_IP="$1"; shift
USERNAME="$1"; shift
PASSWORD="$1"; shift

while [[ "$#" -gt 0 ]]; do
    case "$1" in
        --dry-run) DRY_RUN=1 ;;
        -h|--help|"/?") usage; exit 2 ;;
        *) echo "Unknown option: $1" >&2; usage; exit 2 ;;
    esac
    shift
done

log() { print "[INFO] $*"; }
warn() { print "[WARN] $*" >&2; }

command -v open >/dev/null 2>&1 || { warn "macOS 'open' command missing."; exit 1; }

if [[ "$DRY_RUN" -eq 1 ]]; then
    log "Dry-run: would open Firefox to http://${PRINTER_IP} and automate login."
    exit 0
fi

log "Opening Firefox for printer ${PRINTER_IP}..."
open -a "Firefox" "http://${PRINTER_IP}" || { warn "Failed to open Firefox."; exit 1; }

sleep 5

log "Automating login and DHCP enablement..."
osascript <<EOF
tell application "Firefox"
    activate
end tell

tell application "System Events"
    delay 1
    keystroke "${USERNAME}"
    keystroke tab
    keystroke "${PASSWORD}"
    keystroke return
    delay 3
    keystroke "Network"
    keystroke return
    delay 2
    keystroke "DHCP"
    delay 1
    keystroke return
    delay 1
    keystroke "Save"
    delay 1
    keystroke return
end tell
EOF

log "Automation complete. Verify DHCP status in the UI."
