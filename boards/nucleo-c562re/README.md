# ST NUCLEO-C562RE

Nucleo-64 board (MB2213) with an STM32C562RET6. Tool-independent hardware sheet.

| Profile | Skill | Status |
| --- | --- | --- |
| [cubemx2-hal2-stm32c562nucleo/](cubemx2-hal2-stm32c562nucleo/README.md) | `skills/cubemx2-hal2-stm32c562nucleo` (STM32CubeMX2 + CMake + STM32CubeProgrammer) | verified on hardware |

## Bring-up demos

| Demo | Uses | `cubemx2-hal2-stm32c562nucleo` |
| --- | --- | --- |
| hello-world | console: ST-LINK virtual COM port | tested |
| blink | LED1 = LD1 (green) | built |
| push-to-light | BTN1 = B1 (USER) toggles LED1 | observed * |

Levels: built < flashed < tested (automatic test PASS) < interactive (a person pressed a
button) < observed (a person saw the LED). \* = verified under its earlier name `uart-btn-led`
(renamed 2026-10-09, same code). Dated evidence: the profile README of each skill.

## Required tools

- Windows with Git for Windows (Git Bash); Python 3 with pyserial.
- STM32CubeMX2 1.1.1 and the STM32Cube bundles (installed with STM32Cube for VS Code / the bundle
  manager): GNU Tools for STM32 14.3.1+st.2, CMake 4.4.0+st.1, Ninja 1.13.2+st.1,
  STM32CubeProgrammer 2.23.0; packs stm32c5xx_dfp / hal_drivers / templates 2.1.0 and the
  NUCLEO-C562RE board pack 2.1.0 (`check_tools.sh` lists what is missing).
- Workspace path without spaces, ≤100 characters.

## Commands

```bash
S=skills/cubemx2-hal2-stm32c562nucleo/scripts
```

| Stage | Command | Gate |
| --- | --- | --- |
| 0 help | `bash $S/help.sh [--en]` | - |
| 1 setup | `bash $S/check_tools.sh <board> [--ws <workspace>]` | `missing/bad=0` |
| 4 connect | `bash $S/discover.sh <board> [--serial <stlink-serial>]` | `IDENTITY: PASS` |
| 2 create | `bash $S/new_app.sh <board> <app> [<workspace>\|""] [template] [--ioc2 <file>]` | `REGEN: PASS`, `Created ...` |
| 2 regenerate (after a .ioc2 change) | `bash $S/regen.sh apps/<app>` | `REGEN: PASS` |
| 2d open in IDE (run by new_app) | `bash $S/open_ide.sh apps/<app> [--no-open]` - VS Code + the toolchain extension, on the same project as the scripts | `IDE: READY` |
| 3 build | `bash $S/build.sh apps/<app> [--clean] [--allow-warnings]` | `BUILD: PASS` |
| 5 flash | `bash $S/flash.sh apps/<app> --yes [--elf <file.elf>]` | `FLASH: PASS` |
| 6 test | `python $S/serial_test.py auto apps/<app>/tests/<spec>.json apps/<app>/logs/test.log --board <board> [--interactive]` | `RESULT: PASS` |
| 16 clean | `bash $S/clean.sh [--apps] [--yes]` | `CLEAN: done` |

Board: `nucleo-c562re`. Templates: `hello-world`, `blink`, `push-to-light`. The app's `<app>.ioc2` is created
from the board (or copied from `--ioc2`); `mx/` is generated from it and never edited by hand.

Example - B1 toggles LD1 on a NUCLEO-C562RE:

```bash
S=skills/cubemx2-hal2-stm32c562nucleo/scripts
bash $S/check_tools.sh nucleo-c562re
bash $S/discover.sh nucleo-c562re
bash $S/new_app.sh nucleo-c562re btn-led "" push-to-light
bash $S/build.sh apps/btn-led
bash $S/flash.sh apps/btn-led --yes
python $S/serial_test.py auto apps/btn-led/tests/push_to_light.json apps/btn-led/logs/test.log --board nucleo-c562re --interactive
```

Run from the repo root in Git Bash. Exit code 10 = do what the `ACTION:` line says, then
re-run; common options: [docs/workflow.md](../../docs/workflow.md#common-options).

## Hardware

Sources: STM32CubeMX2 board pack `STMicroelectronics/nucleo-c562re_hw-board` 2.1.0 (BOM, netlist,
part parameters, read 2026-10-07); the board-default project of STM32CubeMX2 1.1.1; the earlier
CubeMX2 SCPI toolkit (`.ioc2` of 2026-09, hardware-tested UART ping/pong).

"Verified" = seen on hardware with a dated log line in a profile README. "Board pack" = taken from
ST's machine-readable board description, not yet checked by us on this board.

## MCU and debug

| Item | Value | Verified |
| --- | --- | --- |
| MCU | STM32C562RET6, Arm Cortex-M33, up to 144 MHz, LQFP64 (programmer: device "STM32C5x", ID 0x44E, rev Y, 512 KB) | yes (2026-10-07) |
| Clocks | HSE 24 MHz crystal (X3, NX2016SA), LSE 32.768 kHz (X2), HSI 144 MHz | board pack |
| Debug | on-board STLINK-V3EC (U13): SWD (PA13 SWDIO, PA14 SWCLK, PB3 SWO); reports board name "NUCLEO-C562RE" | yes (2026-10-07) |
| Console | USART2 TX PA2 / RX PA3 (AF7) → STLINK-V3EC virtual COM port, USB `0483:3754`; the VCP USB serial = the ST-LINK serial | yes (2026-10-07) |

## User I/O

| Silkscreen | Pin | Active level | Verified |
| --- | --- | --- | --- |
| LD1 (green, user) | PA5 (via transistor Q1, solder bridge SB8) | high | yes (2026-10-07: driven + read back, seen by a human) |
| B1 (USER, blue) | PC13, pull-down R13 | **high** when pressed | yes (2026-10-07: press/release events) |
| B2 | RESET (NRST) | - | - |

PA5 is also Arduino D13 (CN5-6 / CN10-11) - open SB8 to use D13 without the LED.

## On-board parts

| Part | Function | Notes |
| --- | --- | --- |
| STLINK-V3EC | SWD probe + virtual COM port + mass storage | firmware upgrades with STLinkUpgrade (user's decision) |
| X3 NX2016SA 24 MHz | HSE | |
| X2 32.768 kHz | LSE (RTC) | |

## Connectors

| Connector | Signals |
| --- | --- |
| CN7/CN10 | ST morpho headers (all MCU pins) |
| CN5/CN6/CN8/CN9 | Arduino Uno V3 headers |
| CN1 | USB-C to the STLINK-V3EC (power, debug, VCP) |

## Hardware quirks

- The board-default CubeMX2 project assigns PA2/PA3 to USART2 but leaves USART2 **disabled**; the
  skill enables it (Async) when it creates an app.
- No USART2 interrupt handler is generated in the default project: the skill's console polls the
  receive flag (LL driver) instead of using interrupt-driven HAL receive.
