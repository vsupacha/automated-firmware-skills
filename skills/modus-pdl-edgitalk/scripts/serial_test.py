#!/usr/bin/env python3
"""Stage 6 (test): data-driven serial test runner - PSOC Edge UART test runner.

Usage:
  python serial_test.py <port|auto> <spec.json> <log> [--board ID] [--sync | --wait-boot]
         [--boot-timeout S] [--wait-port S] [--interactive | --only-interactive] [--only REGEX]

"auto" = the KitProg3 USB-UART of this PC's probe (bench PROBE_SERIAL).
The engine and the spec.json keys are documented in <repo>/lib/fwtest.py.
"""
import sys
from pathlib import Path

HERE = Path(__file__).resolve()
sys.path.insert(0, str(HERE.parents[3] / "lib"))
import fwtest  # noqa: E402

fwtest.run({
    "skill_dir": HERE.parent.parent,
    "env_prefix": "PSE84",
    "serial_key": "PROBE_SERIAL",
    "serial_env": "PROBE_SERIAL",
    "vid_key": "PROBE_VID",
    "default_vid": "04B4",
    "title": "PSOC Edge UART test runner",
})
