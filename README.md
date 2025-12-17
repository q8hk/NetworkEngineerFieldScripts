# Network & Ops Utilities Toolkit

Field-friendly scripts for quickly diagnosing and remediating common networking issues across Windows, macOS, and Linux. Every tool favors safe defaults, predictable exit codes, and readable output.

## Requirements

- Windows 10/11 for `.cmd`/`.bat` tools (uses inbox `ping`, `arp`, `netsh`, `ipconfig`, `timeout`, PowerShell).
- macOS 12+ for shell utilities (`bash`/`zsh`, `ioreg`, `screen`, `open`, `osascript`).
- Linux for FTDI detection (uses `lsusb` if present).
- Python 3.8+ for `check_ftdi.py`.

## Quick Start

```bash
# Clone and list tools
git clone <repo-url> && cd NetworkEngineerFieldScripts

# Windows example (PowerShell)
.\ip_conflict_detect.ps1 -IpAddress 192.0.2.10

# macOS example
./connect_cisco_serial_mac.sh --baud 9600

# Python example (any OS)
python check_ftdi.py
```

## Common Behaviors

- Help: `-h` / `--help` (or `/?` on Windows) shows usage and examples.
- Exit codes: `0` success, `1` detected condition/problem (e.g., conflict), `2` usage error, `3` unexpected failure.
- Logging: Windows utilities write timestamped logs to `logs/` next to the scripts; filenames include date and IP/result where relevant.
- Safety: Destructive actions require explicit opt-in (e.g., `--apply`, `--dry-run` is default).

## Tools

### ip_conflict_detect.cmd / ip_conflict_detect.ps1
Detect ARP conflicts for a given IP within 60 seconds, exiting immediately when multiple MACs are observed.

- **Purpose:** Flag duplicate IP usage without requiring admin rights.
- **Usage:** `ip_conflict_detect.cmd 192.0.2.10` or `ip_conflict_detect.ps1 -IpAddress 192.0.2.10`
- **Self-check:** `--self-test` validates dependencies.
- **Output:** Pretty banner, timestamps, hostname, observed MACs, ping failure count, and a saved log (`logs/ip_conflict_<date>_<ip>.log`).
- **Result states:** `CONFLICT` (exit 1), `NO CONFLICT` (exit 0), `INCONCLUSIVE` (exit 1 when no ARP entries seen before timeout).
- **Examples:** See sample logs in `examples/`.

### check_ftdi.py
Cross-platform FTDI USB serial adapter checker.

- **Usage:** `python check_ftdi.py [--json] [--self-test]`
- **Behavior:** Detects devices (VID 0403) and serial ports, printing actionable next steps. JSON mode outputs structured data.
- **Exit codes:** 0 when devices found, 1 when none detected, 2 usage error, 3 unexpected failure.
- **Testing:** `python -m pytest tests/test_check_ftdi.py` (lightweight self-test wrapper).

### connect_cisco_serial_mac.sh
Assist macOS users in connecting to Cisco console ports via FTDI adapters.

- **Usage:** `./connect_cisco_serial_mac.sh [--baud 9600] [--dry-run]`
- **Behavior:** Detects FTDI devices, reports driver status, identifies `/dev/tty.usbserial*`, and launches `screen` (unless `--dry-run`).
- **Safety:** No automatic installs; suggests `kextload`/Homebrew commands if drivers are missing.

### xerox_enable_dhcp.zsh
Guided Firefox automation to enable DHCP on Xerox WorkCentre devices (macOS).

- **Usage:** `./xerox_enable_dhcp.zsh <printer_ip> <username> <password> [--dry-run]`
- **Behavior:** Opens Firefox and uses AppleScript keystrokes to navigate and enable DHCP. `--dry-run` prints the intended actions only.
- **Note:** Keep Firefox focused during automation; verify DHCP status manually afterward.

### cache_cleaner.bat
Safe browser cache cleaner for Windows.

- **Usage:** `cache_cleaner.bat [--dry-run | --apply] [--self-test]`
- **Behavior:** Reports or deletes cache paths for Chrome, Firefox, Edge, and Opera. Logs actions to `logs/cache_cleaner.log`.
- **Safety:** Default is `--dry-run`; `--apply` required to delete.

### ipdhcp.bat
Report or enable DHCP on the first connected Windows adapter.

- **Usage:** `ipdhcp.bat [--dry-run | --apply] [--self-test]`
- **Behavior:** Shows adapter name, DHCP status, IP address, and domain; optionally enables DHCP and renews the lease when `--apply` is set.
- **Logging:** Writes to `logs/ipdhcp.log`.

## Safety Notes

- Scripts avoid system changes unless explicitly requested (`--apply`, removing `--dry-run`).
- Windows tools rely only on inbox utilities; admin rights are not assumed.
- Outputs and logs contain only operational data (no stored credentials).

## Examples & Logs

- `examples/ip_conflict_conflict.log` — conflict detected (multiple MACs).
- `examples/ip_conflict_no_conflict.log` — single MAC, clean.
- `examples/ip_conflict_inconclusive.log` — unreachable/empty ARP table.

## Troubleshooting

- If a command is missing, run the script’s `--self-test` to see dependencies.
- For PowerShell wrapper issues, ensure scripts are unblocked (`Unblock-File`) and execution policy allows local scripts.
- On macOS, verify accessibility permissions for AppleScript automation (System Settings → Privacy & Security → Accessibility).

## Validation Commands

Windows:
- `ip_conflict_detect.cmd --self-test`
- `ipdhcp.bat --dry-run`
- `cache_cleaner.bat --dry-run`

macOS/Linux:
- `./connect_cisco_serial_mac.sh --dry-run`
- `./xerox_enable_dhcp.zsh 192.0.2.15 admin pass --dry-run`
- `python check_ftdi.py --self-test`
- `python -m pytest tests/test_check_ftdi.py`
