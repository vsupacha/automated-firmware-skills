#!/usr/bin/env python3
"""Stage 6 (test): data-driven serial test runner - Cucumber S console (UART0 via the USB-UART bridge).

Usage:
  python serial_test.py <port|auto> <spec.json> <log> [--board ID] [--sync | --wait-boot]
         [--boot-timeout S] [--wait-port S] [--interactive | --only-interactive] [--only REGEX]

"auto" = the USB serial port whose USB serial + VID are this PC's bench USB_SERIAL / USB_VID (written by
discover.sh). A bridge without a USB serial number ("-"): pass the bench CONSOLE_PORT instead of auto.
Opening the port may pulse DTR/RTS and restart the sketch: the runner syncs with `info` anyway.
Needs pyserial: run it with PlatformIO's python (~/.platformio/penv/Scripts/python) if the system
python has none. The engine and the spec.json keys are documented in <repo>/lib/fwtest.py.
"""
import sys
from pathlib import Path

HERE = Path(__file__).resolve()
sys.path.insert(0, str(HERE.parents[3] / "lib"))
import fwtest  # noqa: E402

fwtest.run({
    "skill_dir": HERE.parent.parent,
    "env_prefix": "CUKE",
    "serial_key": "USB_SERIAL",
    "serial_env": "USB_SERIAL",
    "vid_key": "USB_VID",
    "default_vid": "0403",
    "title": "Gravitech Cucumber S Arduino serial test runner (UART0 via USB-UART bridge)",
})
