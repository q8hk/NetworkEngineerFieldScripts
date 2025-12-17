# Network & Ops Utilities Toolkit — Implementation Notes

This repository focuses on portable, low-risk scripts for quick field diagnostics. The shared expectations across tools:

- **Exit codes:** `0` (success), `1` (detected problem/condition), `2` (usage error), `3` (unexpected failure).
- **Help:** Every script must accept `-h`/`--help` (or `/?` for Windows batch) to explain usage, examples, and exit codes.
- **Safety:** Avoid making system changes unless the user explicitly opts in (e.g., `--enable`, `--apply`, `--dry-run`).
- **Logging:** Prefer timestamped log files next to the script; include host info and the inputs provided.
- **Portability:** Shell scripts should stick to POSIX constructs where possible; Windows batch should rely on default inbox tools.

When adding new utilities:

1. Keep defaults **read-only/observational**.
2. Provide `--self-test` or similar to validate dependencies without touching the system.
3. Document any optional dependencies in the README.
