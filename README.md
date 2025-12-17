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
- Result footer: Output ends with `Result: HEALTHY|PROBLEM|INCONCLUSIVE`.

## Tool Matrix (Problem → Tool)

- Suspect IP conflict → `ip_conflict_detect.cmd`, `arp_watch_once.cmd`
- Need MAC/vendor for an IP → `who_has_ip.cmd`
- Quick subnet presence check → `subnet_scan_lite.cmd`
- DHCP changed? → `dhcp_renew_trace.cmd`, `dhcp_lease_diff.ps1`
- NIC behaving oddly → `nic_health.cmd`, `interface_flap_detect.cmd`
- DNS mismatch → `dns_truth.cmd`, `reverse_dns_audit.cmd`
- MAC format confusion → `normalize_mac.cmd` + [docs/mac_to_port_helper.md](docs/mac_to_port_helper.md)
- Capture/compare evidence → `net_snapshot.cmd`, `diff_snapshots.ps1`
- Safety/privilege sanity → `privilege_check.cmd`, `self_check.cmd`
- Guided discovery → `tool_index.cmd --list` or interactive mode

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

### ARP / Layer-2 sanity

- **arp_watch_once.cmd** — Watch ARP for a single IP for N seconds (default 60). `Result: PROBLEM` when more than one MAC is observed; `INCONCLUSIVE` (still exit 0) when nothing responds. `Examples:` see `examples/ip_conflict_*` logs for conflict/no-conflict/inconclusive behavior.
- **who_has_ip.cmd** — Ping/tickle ARP, show MAC, interface, and optional vendor lookup using `data/oui.csv`. `Usage:` `who_has_ip.cmd 192.0.2.10 [--oui-file data/oui.csv] [--no-vendor]`.
- **subnet_scan_lite.cmd** — Quick ping sweep + ARP harvest. `Usage:` `subnet_scan_lite.cmd 192.0.2.0/24 [--timeout-ms 750] [--max-hosts 256] [--force]`. For larger-than-/24 subnets, provide `--force` or trim with `--max-hosts`. Summary and totals are printed and logged. `Example:` `examples/subnet_scan_lite_sample.txt`.

### DHCP tools

- **dhcp_renew_trace.cmd** — Renew (or release+renew with `--release --force`) while timing the lease process. Prints before/after IP, gateway, DNS, and whether values changed. Safe default is renew-only.
- **dhcp_lease_diff.ps1** — Capture DHCP-related fields and compare to the previous run in `state/`. Optional `-Before`/`-After` parameters let you diff explicit files.

### NIC health

- **nic_health.cmd** — Summarize link speed/duplex/driver/power settings using `Get-NetAdapter` and advanced properties. Flags suspicious states (e.g., link under 1 Gbps, power saving). `Example:` `examples/nic_health_sample.txt`.
- **interface_flap_detect.cmd** — Monitor link state transitions for N seconds (default 60). Returns `PROBLEM` if any flaps are observed; timeline is printed and logged.

### DNS tools

- **dns_truth.cmd** — Compare answers from system DNS plus optional `--server` and `--public` resolvers (e.g., `8.8.8.8`). Marks `PROBLEM` when answers diverge. `Example:` `examples/dns_truth_sample.txt`.
- **reverse_dns_audit.cmd** — PTR lookup for an IP, then A lookup of the hostname; flags mismatch.

### MAC helpers and documentation

- **normalize_mac.cmd** — Normalize input MAC to Cisco (`aaaa.bbbb.cccc`), Windows (`aa-bb-cc-dd-ee-ff`), and Linux (`aa:bb:cc:dd:ee:ff`) formats.
- **docs/mac_to_port_helper.md** — Copy/paste cheat sheet for Cisco/HPE/Huawei commands and MAC format handling.

### Logging / evidence

- **net_snapshot.cmd** — Capture `ipconfig /all`, `route print`, `arp -a`, `netsh interface ip show config`, and optional `--include-netstat`. Files land in `logs/` with timestamps. `Example:` `examples/net_snapshot_sample.txt`.
- **diff_snapshots.ps1** — Heuristic diff of two snapshot files highlighting IP, gateway, DNS, and default-route deltas. `Example:` `examples/net_snapshot_diff_sample.txt`.
- **privilege_check.cmd** — Detect admin vs. standard user and note which tools degrade without elevation.
- **self_check.cmd** — Validate presence of required commands and write permissions to `logs/`.
- **tool_index.cmd** — Interactive launcher with `--list` and `--run <tool> [args]` for non-interactive use.

## Safety Notes

- Scripts avoid system changes unless explicitly requested (`--apply`, removing `--dry-run`).
- DHCP releases require `--release --force` in `dhcp_renew_trace.cmd` to prevent accidental disconnection.
- Windows tools rely only on inbox utilities; admin rights are not assumed.
- Outputs and logs contain only operational data (no stored credentials).

## Examples & Logs

- `examples/ip_conflict_conflict.log` — conflict detected (multiple MACs).
- `examples/ip_conflict_no_conflict.log` — single MAC, clean.
- `examples/ip_conflict_inconclusive.log` — unreachable/empty ARP table.
- `examples/subnet_scan_lite_sample.txt` — quick /24 sweep example.
- `examples/nic_health_sample.txt` — NIC health with no issues.
- `examples/dns_truth_sample.txt` — matching DNS answers.
- `examples/net_snapshot_sample.txt` — snapshot sections.
- `examples/net_snapshot_diff_sample.txt` — key differences highlighted.

## Troubleshooting

- If a command is missing, run the script’s `--self-test` to see dependencies.
- For PowerShell wrapper issues, ensure scripts are unblocked (`Unblock-File`) and execution policy allows local scripts.
- On macOS, verify accessibility permissions for AppleScript automation (System Settings → Privacy & Security → Accessibility).

## Validation Commands

Windows:
- `ip_conflict_detect.cmd --self-test`
- `self_check.cmd`
- `tool_index.cmd --list`
- `net_snapshot.cmd --include-netstat`
- `ipdhcp.bat --dry-run`
- `cache_cleaner.bat --dry-run`

macOS/Linux:
- `./connect_cisco_serial_mac.sh --dry-run`
- `./xerox_enable_dhcp.zsh 192.0.2.15 admin pass --dry-run`
- `python check_ftdi.py --self-test`
- `python -m pytest tests/test_check_ftdi.py`
