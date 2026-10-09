# Raspberry Pi Pico 2 W - PlatformIO profile (pio-arduino-rpipico2w)

Board hardware (tool-independent): [../README.md](../README.md). This file: toolchain facts, tool
quirks and the verification log of the `pio-arduino-rpipico2w` skill. Machine-readable values: `board.env`.

## Toolchain

| Item | Value |
| --- | --- |
| PlatformIO platform | `maxgerhardt/platform-raspberrypi` @ `5d4561a0` (the official `raspberrypi` platform has no RP2350 boards) |
| Core | Earle Philhower arduino-pico 6.1.0+4 (`fd65f6d4`), pinned by the platform commit |
| Board id / framework | `rpipico2w` / `arduino` |
| Flash tool | picotool 2.0 (package `tool-picotool-rp2040-earlephilhower`), used directly by `flash.sh` |
| Upload path | 1200-baud touch on the sketch's CDC port → BOOTSEL → `picotool load -v -x --ser <chipid>` |

## Tool quirks

- Windows: picotool reached the `RP2350 Boot` interface without installing a driver (Windows 11,
  2026-10-07). If picotool reports "no accessible RP2350 devices in BOOTSEL mode" while the
  `RP2350` drive is visible, bind WinUSB to "RP2350 Boot" with Zadig (ask the user) - or copy the
  `.uf2` to the drive by hand.
- pyserial raises "A device which does not exist was specified" on the 1200-baud touch: the board
  rebooted before the port was configured - that is the expected success path.
- arduino-pico's USB CDC does not reset the board when the port opens: the boot banner is missed;
  tests sync with `info` instead.
- The arduino-pico framework package is ~1.4 GB (git clone with submodules). On Windows, git needs
  `core.longpaths=true` to clone it the first time.

## Verification log

- 2026-10-07 skill ported from the PIO LINX toolkit's Pico 2 W port (PlatformIO 6.1.19, platform
  `5d4561a0`, arduino-pico 6.1.0+4, Windows 11 + Git Bash). Board started with an earlier sketch;
  rebooted to BOOTSEL by a 1200-baud touch, then:
  - discover in BOOTSEL: RP2350 rev A2 QFN60, flash 4096K, chip ID = USB serial
    (also the serial of the arduino-pico sketch), secure boot 0 - IDENTITY PASS.
  - `hello-world` (app `hello-pico`): clean build PASS 0 warnings (RAM 69,340 B, flash 294,152 B),
    uf2 `b128cb1f...`; flash from BOOTSEL: verify 100 %, sketch back on its CDC port in 8 s; test PASS 9/9.
  - `uart-btn-led` (app `btn-led-pico`): build PASS 0 warnings, uf2 `0d89b4b7...`; flash from a
    running sketch (1200-baud touch → BOOTSEL → load + verify) PASS; automatic test PASS 13/13;
    interactive test PASS 4/4 (`EVT btn1=pressed name=BOOTSEL led1=1`, `EVT btn1=released`,
    `LED led1=1`) and **the LED was seen lit by the user** - BOOTSEL run-time read and the
    CYW43439 LED are verified on hardware.
  - picotool reached "RP2350 Boot" without any driver install.
- 2026-10-09 template `uart-btn-led` renamed `push-to-light` (same code apart from the app
  name) - build PASS 0 warnings; new template `blink` (LED1 every 0.5 s) - build PASS 0
  warnings. Both built only, not flashed (the earlier results above were with the old name).
