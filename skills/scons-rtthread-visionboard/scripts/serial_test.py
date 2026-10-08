#!/usr/bin/env python3
"""Stage 6 (test): data-driven serial test runner - Vision Board msh console (uart9 via ART-Link VCP).

Usage:
  python serial_test.py <port|auto> <spec.json> <log> [--board ID] [--sync | --wait-boot]
         [--boot-timeout S] [--wait-port S] [--interactive | --only-interactive] [--only REGEX]

"auto" = the COM port whose USB serial is this PC's bench PROBE_SERIAL (the ART-Link unique id).
Needs pyserial. The engine and the spec.json keys are documented in <repo>/lib/fwtest.py.
Commands go to RT-Thread's msh: lines may follow the "msh />" prompt, so specs match without "^".
"""
import sys
from pathlib import Path

HERE = Path(__file__).resolve()
sys.path.insert(0, str(HERE.parents[3] / "lib"))
import fwtest  # noqa: E402

fwtest.run({
    "skill_dir": HERE.parent.parent,
    "env_prefix": "RTT",
    "serial_key": "PROBE_SERIAL",
    "serial_env": "PROBE_SERIAL",
    "vid_key": "PROBE_VID",
    "default_vid": "0416",
    "title": "Vision Board RT-Thread msh test runner (uart9 via the ART-Link VCP)",
})
