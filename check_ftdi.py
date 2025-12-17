#!/usr/bin/env python3
"""
Check for FTDI USB serial adapters across Windows/macOS/Linux.

Exit codes: 0 success, 1 detected problem/condition, 2 usage error, 3 unexpected failure.
"""
from __future__ import annotations

import argparse
import json
import platform
import shutil
import subprocess
import sys
from dataclasses import dataclass, asdict
from typing import List, Optional


@dataclass
class FtdiDevice:
    vendor_id: Optional[str]
    product_id: Optional[str]
    description: str
    path: Optional[str] = None


def run_cmd(cmd: List[str]) -> subprocess.CompletedProcess:
    return subprocess.run(cmd, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)


def detect_windows() -> List[FtdiDevice]:
    devices: List[FtdiDevice] = []
    pwsh = shutil.which("powershell") or shutil.which("pwsh")
    if pwsh:
        script = r"Get-PnpDevice -PresentOnly | Where-Object { $_.InstanceId -match 'VID_0403' } | Select-Object -Property FriendlyName,InstanceId | Format-List"
        result = run_cmd([pwsh, "-NoProfile", "-Command", script])
        if result.returncode == 0:
            for line in result.stdout.splitlines():
                if "FriendlyName" in line or "InstanceId" in line:
                    desc = line.split(":", 1)[-1].strip()
                    vid = None
                    pid = None
                    if "VID_0403" in line:
                        vid = "0403"
                    devices.append(FtdiDevice(vendor_id=vid, product_id=pid, description=desc))
    return devices


def detect_macos() -> List[FtdiDevice]:
    devices: List[FtdiDevice] = []
    if shutil.which("ioreg"):
        result = run_cmd(["ioreg", "-p", "IOUSB", "-l"])
        if result.returncode == 0:
            for line in result.stdout.splitlines():
                if "FTDI" in line or "VID_0403" in line:
                    devices.append(FtdiDevice(vendor_id="0403", product_id=None, description=line.strip()))
    if shutil.which("ls"):
        for port_line in run_cmd(["/bin/sh", "-c", "ls /dev/tty.usbserial* 2>/dev/null"]).stdout.split():
            devices.append(FtdiDevice(vendor_id="0403", product_id=None, description="Serial port", path=port_line.strip()))
    return devices


def detect_linux() -> List[FtdiDevice]:
    devices: List[FtdiDevice] = []
    if shutil.which("lsusb"):
        result = run_cmd(["lsusb"])
        if result.returncode == 0:
            for line in result.stdout.splitlines():
                if "0403:" in line or "FTDI" in line:
                    parts = line.split()
                    vid_pid = parts[5] if len(parts) > 5 else ""
                    vid, pid = (vid_pid.split(":") + [None])[:2]
                    devices.append(FtdiDevice(vendor_id=vid, product_id=pid, description=line.strip()))
    for dev in run_cmd(["/bin/sh", "-c", "ls /dev/ttyUSB* 2>/dev/null"]).stdout.split():
        devices.append(FtdiDevice(vendor_id=None, product_id=None, description="Serial port", path=dev.strip()))
    return devices


def detect_devices() -> List[FtdiDevice]:
    system = platform.system().lower()
    if system.startswith("win"):
        return detect_windows()
    if system == "darwin":
        return detect_macos()
    return detect_linux()


def actionable_notes(found: List[FtdiDevice]) -> List[str]:
    if found:
        return [
            "If ports are present, try: screen <path> 9600",
            "On Windows, ensure the FTDI VCP driver is installed if ports are missing.",
        ]
    return [
        "Connect the adapter and rerun this check.",
        "Install FTDI VCP drivers if the OS does not auto-load them.",
    ]


def self_test() -> int:
    cmds = ["python", "powershell", "lsusb", "ioreg", "screen"]
    missing = []
    for cmd in cmds:
        if shutil.which(cmd) is None:
            missing.append(cmd)
    print("Self-test:")
    for cmd in cmds:
        status = "OK" if cmd not in missing else "MISSING"
        print(f" - {cmd}: {status}")
    return 0 if not missing else 1


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Check for FTDI USB serial adapters.")
    parser.add_argument("--json", action="store_true", help="Output results as JSON.")
    parser.add_argument("--self-test", action="store_true", help="Check dependencies only.")
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    if args.self_test:
        return self_test()

    try:
        devices = detect_devices()
        notes = actionable_notes(devices)
        if args.json:
            payload = {
                "devices": [asdict(d) for d in devices],
                "notes": notes,
                "platform": platform.system(),
            }
            print(json.dumps(payload, indent=2))
        else:
            print("FTDI device scan results:")
            if devices:
                for dev in devices:
                    parts = [
                        dev.description,
                        f"VID={dev.vendor_id}" if dev.vendor_id else "",
                        f"PID={dev.product_id}" if dev.product_id else "",
                        f"PATH={dev.path}" if dev.path else "",
                    ]
                    print(" - " + " ".join(p for p in parts if p))
            else:
                print(" - No FTDI devices found.")
            print("\nNext steps:")
            for note in notes:
                print(f" * {note}")
        return 0 if devices else 1
    except Exception as exc:  # noqa: BLE001
        print(f"Unexpected error: {exc}", file=sys.stderr)
        return 3


if __name__ == "__main__":
    sys.exit(main())
