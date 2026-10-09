# Arduino UNO R4 WiFi (ABX00087)

UNO-form-factor board with a Renesas RA4M1 (the target MCU) and an ESP32-S3-MINI-1 module that is
the USB bridge, the RA4M1 programmer and the WiFi/BLE radio. Tool-independent hardware sheet.

| Profile | Skill | Status |
| --- | --- | --- |
| [pio-arduino-unor4wifi/](pio-arduino-unor4wifi/README.md) | `skills/pio-arduino-unor4wifi` (PlatformIO + Arduino UNO R4 core) | verified on hardware (LED L seen) |

## Bring-up demos

| Demo | Uses | `pio-arduino-unor4wifi` |
| --- | --- | --- |
| hello-world | console: UART via the USB bridge | tested |
| blink | LED1 = L (yellow) | built |
| push-to-light | no user button: console LED commands only | observed * |

Levels: built < flashed < tested (automatic test PASS) < interactive (a person pressed a
button) < observed (a person saw the LED). \* = verified under its earlier name `uart-btn-led`
(renamed 2026-10-09, same code). Dated evidence: the profile README of each skill.

## Required tools

- PlatformIO Core 6.2 (pip or the VS Code extension), Git, Python 3 (pyserial: PlatformIO's python
  has it).
- The first build downloads the pinned `renesas-ra` platform, the UNO R4 core, GCC 7.2.1 and
  bossac. No driver needed on Windows (the board's USB bridge is a standard CDC port).
- Workspace path ≤100 characters, English characters only.

## Commands

```bash
S=skills/pio-arduino-unor4wifi/scripts
```

| Stage | Command | Gate |
| --- | --- | --- |
| 0 help | `bash $S/help.sh [--en]` | - |
| 1 setup | `bash $S/check_tools.sh <board> [--ws <workspace>]` | `missing/bad=0` |
| 2 create | `bash $S/new_app.sh <board> <app> [<workspace>\|""] [template] [--no-open]` | `Created ...` |
| 2d open in IDE (run by new_app) | `bash $S/open_ide.sh apps/<app> [--no-open]` - VS Code + PlatformIO IDE | `IDE: READY` |
| 3 build | `bash $S/build.sh apps/<app> [--clean] [--allow-warnings]` | `BUILD: PASS` |
| 4 connect | `bash $S/discover.sh <board> [--serial <usb-serial>]` | `IDENTITY: PASS` |
| 5 flash | `bash $S/flash.sh apps/<app> --yes` | `FLASH: PASS` |
| 6 test | `~/.platformio/penv/Scripts/python $S/serial_test.py auto apps/<app>/tests/<spec>.json apps/<app>/logs/test.log --board <board> [--interactive]` | `RESULT: PASS` |
| 16 clean | `bash $S/clean.sh [--apps] [--yes]` | `CLEAN: done` |

Board: `uno-r4-wifi`. Templates: `hello-world`, `blink`, `push-to-light` (LED1 = L on D13; the board has no
user button, so the button steps are skipped). The board's ESP32-S3 is the USB bridge: a 1200 baud
touch starts its loader and bossac writes the sketch from 0x4000. That loader cannot read flash, so
there is no backup and no read-back verify - the test's INFO line proves the image.

Example - hello-world on a UNO R4 WiFi:

```bash
S=skills/pio-arduino-unor4wifi/scripts
bash $S/check_tools.sh uno-r4-wifi
bash $S/discover.sh uno-r4-wifi
bash $S/new_app.sh uno-r4-wifi hello "" hello-world
bash $S/build.sh apps/hello
bash $S/flash.sh apps/hello --yes
~/.platformio/penv/Scripts/python $S/serial_test.py auto apps/hello/tests/hello_world.json apps/hello/logs/test.log --board uno-r4-wifi
```

Run from the repo root in Git Bash. Exit code 10 = do what the `ACTION:` line says, then
re-run; common options: [docs/workflow.md](../../docs/workflow.md#common-options).

## Hardware

Sources: Arduino UNO R4 WiFi datasheet and schematics (docs.arduino.cc), the Arduino UNO R4 core
1.4.1 variant `UNOWIFIR4` (`pins_arduino.h`, `variant.cpp`), PlatformIO `renesas-ra` 1.7.0 board
`uno_r4_wifi`.

"Verified" = seen on hardware with a dated log line in a profile README. "Vendor docs" = taken from
Arduino's documentation or the core, not yet checked by us on this board.

## MCU and USB

| Item | Value | Verified |
| --- | --- | --- |
| MCU | Renesas RA4M1 R7FA4M1AB3CFM, Arm Cortex-M4F 48 MHz, 256 KB flash, 32 KB SRAM, 8 KB data flash | vendor docs (not readable over USB - see Identity) |
| USB | USB-C to the ESP32-S3 bridge: `2341:1002`, one CDC COM port; the USB serial number is the bridge's | `2341:1002` seen 2026-10-08 |
| Console | `Serial` = RA4M1 UART to the ESP32-S3, bridged to the USB CDC port; baud rate set by the sketch (115200) | yes (2026-10-08, hello-world test) |
| Upload | 1200 baud open of the COM port: the bridge resets the RA4M1 into its loader and emulates a SAM-BA loader on the same port; `bossac --erase --write --reset` writes the sketch from 0x4000 | yes (2026-10-08) |
| Read-back | **not supported** by the bridge's loader: `bossac --verify` fails ("SAM-BA operation failed") and skips the reset | yes (2026-10-08) |
| Debug | 10-pin SWD header for the RA4M1 (external probe: CMSIS-DAP, J-Link) | vendor docs, not used |

## Identity

`bossac --info` after a 1200 baud touch reports what the bridge emulates, the same on every board:
"Arduino Bootloader (SAM-BA extended) 2.0 [Arduino:IKXYZ]", device `nRF52840-QIAA` (a placeholder,
not the RA4M1), 256 pages of 4096 bytes, security false, nothing locked (read 2026-10-08). The
RA4M1's own id is only readable over SWD; the sketch's INFO line (`board=uno-r4-wifi`) confirms the
target after flashing.

## User I/O

| Silkscreen / name | Pin | Active level | Notes | Verified |
| --- | --- | --- | --- | --- |
| **L** LED (yellow) | D13 = P102 (`LED_BUILTIN`) | high = on | **LED1** of the skill's board layer; shares D13 (SPI SCK) | yes (2026-10-09, on/off seen by the user) |
| RESET button | RA4M1 reset | - | double-press enters the loader (Arduino) | - |
| User buttons | none | - | the templates' button steps are skipped (`btns=0`) | yes (board has none) |
| 12x8 LED matrix | charlieplexed on P003/P004/P011/P012/P013/P015/P204/P205/P206/P212/P213 | - | `Arduino_LED_Matrix` library; not used by the M1 templates | vendor docs |
| TX / RX LEDs | driven by the bridge | - | not software controlled from the RA4M1 | vendor docs |

## On-board parts (not used by the M1 templates)

| Part | Connection | Notes |
| --- | --- | --- |
| ESP32-S3-MINI-1 | RA4M1 UART (`Serial2`/`SerialNina` in the core) + the USB bridge role | WiFi/BLE through the `WiFiS3` library; its firmware is Arduino's - never flash it from this skill |
| Qwiic connector | I2C1 (`Wire1`), 3.3 V | |
| Headers | UNO R3 layout, 5 V I/O on the RA4M1 pins | |
