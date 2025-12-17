#!/usr/bin/env bash
set -euo pipefail

SCRIPT_NAME="$(basename "$0")"
DEFAULT_BAUD="9600"
DRY_RUN=0
BAUD="$DEFAULT_BAUD"

usage() {
    cat <<EOF
$SCRIPT_NAME - Assist connecting to Cisco console via FTDI on macOS.

Usage:
  $SCRIPT_NAME [--baud 9600] [--dry-run] [--help]

Behavior:
  - Detects FTDI USB serial devices (VID 0403) via ioreg.
  - Reports driver status without installing anything automatically.
  - Suggests commands to load/install the FTDI driver if missing.
  - Starts "screen" when a device is found (unless --dry-run).

Exit codes: 0 success, 1 detected condition/problem, 2 usage error, 3 unexpected failure.
EOF
}

log_info() { printf "[INFO] %s\n" "$*"; }
log_warn() { printf "[WARN] %s\n" "$*" >&2; }
log_error() { printf "[ERROR] %s\n" "$*" >&2; }

parse_args() {
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --baud)
                [[ $# -ge 2 ]] || { log_error "--baud requires a value"; exit 2; }
                BAUD="$2"; shift 2 ;;
            --dry-run)
                DRY_RUN=1; shift ;;
            -h|--help|"/?")
                usage; exit 2 ;;
            *)
                log_error "Unknown option: $1"; usage; exit 2 ;;
        esac
    done
}

require_cmd() {
    command -v "$1" >/dev/null 2>&1 || { log_error "Missing command: $1"; exit 1; }
}

parse_args "$@"

require_cmd ioreg
require_cmd grep

log_info "Detecting FTDI USB serial devices (VID 0403)..."
if ! ftdi_line="$(ioreg -p IOUSB -l -w 0 | grep -i "VID_0403" || true)"; then
    :
fi

if [[ -z "${ftdi_line:-}" ]]; then
    log_warn "No FTDI device detected. Connect the adapter and retry."
    exit 1
fi
log_info "FTDI device detected."

require_cmd kextstat
if kextstat | grep -q "FTDIUSBSerialDriver"; then
    log_info "FTDI driver appears loaded."
else
    log_warn "FTDI driver not loaded. You may need to install/load it:"
    cat <<'EOF'
  sudo kextload /Library/Extensions/FTDIUSBSerialDriver.kext
  # or install via Homebrew Cask:
  brew install --cask ftdi-vcp-driver
EOF
fi

require_cmd ls
device_path="$(ls /dev/tty.usbserial* 2>/dev/null | head -n1 || true)"
if [[ -z "$device_path" ]]; then
    log_warn "No /dev/tty.usbserial* device present. Check cabling and driver."
    exit 1
fi

log_info "Serial device: $device_path"
log_info "Baud rate: $BAUD"

if [[ "$DRY_RUN" -eq 1 ]]; then
    log_info "Dry-run: would execute -> screen \"$device_path\" \"$BAUD\""
    exit 0
fi

require_cmd screen
log_info "Launching screen. Press Ctrl+A then K to exit."
exec screen "$device_path" "$BAUD"
