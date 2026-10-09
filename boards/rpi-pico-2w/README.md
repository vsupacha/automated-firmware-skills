# Raspberry Pi Pico 2 W

RP2350 board with a CYW43439 Wi-Fi/Bluetooth module. Tool-independent hardware sheet.

| Profile | Skill | Status |
| --- | --- | --- |
| [pio-arduino-rpipico2w/](pio-arduino-rpipico2w/README.md) | `skills/pio-arduino-rpipico2w` (PlatformIO + arduino-pico) | verified on hardware |

## Bring-up demos

| Demo | Uses | `pio-arduino-rpipico2w` |
| --- | --- | --- |
| hello-world | console: USB CDC | tested |
| blink | LED1 = LED (on the Wi-Fi module) | built |
| push-to-light | BTN1 = BOOTSEL toggles LED1 | observed * |

Levels: built < flashed < tested (automatic test PASS) < interactive (a person pressed a
button) < observed (a person saw the LED). \* = verified under its earlier name `uart-btn-led`
(renamed 2026-10-09, same code). Dated evidence: the profile README of each skill.

## Required tools

- PlatformIO Core 6.1 (pip or the VS Code extension), Git, Python 3 with pyserial.
- The first build downloads the pinned platform + arduino-pico (~1.5 GB). On Windows set
  `git config --global core.longpaths true` first.
- Workspace path ≤100 characters, English characters only.

## Commands

```bash
S=skills/pio-arduino-rpipico2w/scripts
```

| Stage | Command | Gate |
| --- | --- | --- |
| 0 help | `bash $S/help.sh [--en]` | - |
| 1 setup | `bash $S/check_tools.sh <board> [--ws <workspace>]` | `missing/bad=0` |
| 4 connect | `bash $S/discover.sh <board> [--serial <usb-serial>]` | `IDENTITY: PASS` |
| 2 create | `bash $S/new_app.sh <board> <app> [<workspace>\|""] [template]` | `Created ...` |
| 2d open in IDE (run by new_app) | `bash $S/open_ide.sh apps/<app> [--no-open]` - VS Code + the toolchain extension, on the same project as the scripts | `IDE: READY` |
| 3 build | `bash $S/build.sh apps/<app> [--clean] [--allow-warnings]` | `BUILD: PASS` |
| 5 flash | `bash $S/flash.sh apps/<app> --yes [--uf2 <file.uf2>]` | `FLASH: PASS` |
| 6 test | `python $S/serial_test.py auto apps/<app>/tests/<spec>.json apps/<app>/logs/test.log --board <board> [--interactive]` | `RESULT: PASS` |
| 16 clean | `bash $S/clean.sh [--apps] [--yes]` | `CLEAN: done` |

Board: `rpi-pico-2w`. Templates: `hello-world`, `blink`, `push-to-light`. The board can be running a sketch
or be in BOOTSEL: `flash.sh` reboots it into BOOTSEL itself.

Example - BOOTSEL toggles the LED on a Pico 2 W:

```bash
S=skills/pio-arduino-rpipico2w/scripts
bash $S/check_tools.sh rpi-pico-2w
bash $S/discover.sh rpi-pico-2w
bash $S/new_app.sh rpi-pico-2w btn-led "" push-to-light
bash $S/build.sh apps/btn-led
bash $S/flash.sh apps/btn-led --yes
python $S/serial_test.py auto apps/btn-led/tests/push_to_light.json apps/btn-led/logs/test.log --board rpi-pico-2w --interactive
```

Run from the repo root in Git Bash. Exit code 10 = do what the `ACTION:` line says, then
re-run; common options: [docs/workflow.md](../../docs/workflow.md#common-options).

## Hardware

Sources: Raspberry Pi Pico 2 W datasheet and pinout (raspberrypi.com/documentation/microcontrollers);
arduino-pico core `variants/rpipico2w/pins_arduino.h`, `variants/generic/common.h`,
`cores/rp2040/wiring_analog.cpp` (surveyed 2026-09-22 in the PIO LINX toolkit, Pico 2 W port).

## MCU and USB

| Item | Value | Verified |
| --- | --- | --- |
| MCU | RP2350A (QFN60), rev A2, dual Cortex-M33 (or dual Hazard3 RISC-V), 150 MHz, 520 KB SRAM | yes (picotool: RP2350 A2 QFN60) |
| Flash | 4 MB QSPI | yes (picotool: 4096K) |
| USB | micro-USB, native RP2350 USB (no separate debug probe) | yes |
| USB IDs | BOOTSEL ROM: `2E8A:000F` (mass-storage drive `RP2350` + `RP2350 Boot` interface); arduino-pico sketch: `2E8A:F00F` CDC serial | yes |
| USB serial number | = chip ID (`picotool info` `chipid`), the same in BOOTSEL and in an arduino-pico sketch - unique per board | yes (2026-10-07) |
| Console | USB CDC of the sketch (no UART bridge); UART0 GP0/GP1 on the header if needed | USB CDC yes |
| Debug | 3-pin SWD header (SWCLK, GND, SWDIO) for an external probe | not used |
| Logic level | 3.3 V; ADC reference = 3V3 through an RC filter | vendor docs |

## User I/O

| Silkscreen | Pin | Active level | Verified |
| --- | --- | --- | --- |
| LED | on the CYW43439 module (WL_GPIO0) - **not an RP2350 GPIO**; arduino-pico `LED_BUILTIN` = 64 | high | yes (2026-10-07: driven by the sketch, seen lit by a human) |
| BOOTSEL | QSPI CS line; readable at run time (`BOOTSEL` in arduino-pico) - pressed at power-up = USB boot mode | pressed = 1 via `BOOTSEL` | yes (boot mode; run-time read + debounce 2026-10-07) |
| - | **no RESET button** | - | yes |

## Pins

| Pins | Use |
| --- | --- |
| GP0–GP22 | free GPIO on the header |
| GP26/27/28 | GPIO or ADC0/1/2 (12-bit hardware; arduino-pico `analogRead` defaults to 10 bits unless `analogReadResolution(12)`) |
| GP23, GP24, GP25, GP29 | **owned by the CYW43439** (WL_ON, SPI data, CS, SPI clock) - not on the header. GP29 is ADC3 on a non-W Pico 2: do not copy that map |
| ADC4 | internal temperature sensor (not a pin) |

## On-board parts

| Part | Function | Bus | Verified |
| --- | --- | --- | --- |
| CYW43439 | Wi-Fi 4 + Bluetooth 5.2, also drives the LED | PIO-SPI on GP23/24/25/29 | LED only |

## Hardware quirks

- A blank board (or one whose image does not start) comes up in BOOTSEL mode by itself.
- No reset button: to force BOOTSEL, unplug, hold BOOTSEL, plug in, release.
- Reading `BOOTSEL` at run time briefly disables flash (XIP) - poll it, don't read it from ISRs.
