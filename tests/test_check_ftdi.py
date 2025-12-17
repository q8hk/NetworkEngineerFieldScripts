import subprocess
import sys


def test_self_test_exits_cleanly():
    result = subprocess.run(
        [sys.executable, "check_ftdi.py", "--self-test"], capture_output=True, text=True
    )
    assert result.returncode in (0, 1)
    assert "Self-test" in result.stdout
