# ST STM32F407G-DISC1 (STM32F4DISCOVERY)

Discovery kit with the STM32F407VGT6 (Cortex-M4F, 1 MB flash, 192 KB RAM), MB997. Tool-independent
hardware sheet.

| Profile | Skill | Status |
| --- | --- | --- |
| [cubemx-hal-stm32f407disco/](cubemx-hal-stm32f407disco/README.md) | `skills/cubemx-hal-stm32f407disco` (STM32CubeMX 6.18 + STM32CubeF4 HAL + CMake) | M1: generated + built, not run on hardware |

## Bring-up demos

| Demo | Uses | `cubemx-hal-stm32f407disco` |
| --- | --- | --- |
| hello-world | console: SWO (no virtual COM port) | built |
| blink | LED1 = LD3 (orange) | built |
| push-to-light | BTN1 = B1 (blue) toggles LED1 | built |

Levels: built < flashed < tested (automatic test PASS) < interactive (a person pressed a
button) < observed (a person saw the LED). \* = verified under its earlier name `uart-btn-led`
(renamed 2026-10-09, same code). Dated evidence: the profile README of each skill.

## Required tools

- Windows with Git for Windows (Git Bash); Python 3.
- STM32CubeMX 6.18.1 with the STM32Cube_FW_F4 V1.28.3 package (installed from STM32CubeMX:
  Help > Manage embedded software packages), and the STM32Cube bundles GNU Tools for STM32
  14.3.1+st.2, CMake 4.4.0+st.1, Ninja 1.13.2+st.1.
- Workspace path without spaces, ≤100 characters.
- No serial port needed: the console is SWO (read it in the debugger's SWV view).

## Commands

```bash
S=skills/cubemx-hal-stm32f407disco/scripts
```

| Stage | Command | Gate |
| --- | --- | --- |
| 0 help | `bash $S/help.sh [--en]` | - |
| 1 setup | `bash $S/check_tools.sh <board> [--ws <workspace>]` | `missing/bad=0` |
| 2 create | `bash $S/new_app.sh <board> <app> [<workspace>\|""] [template]` | `REGEN: PASS`, `Created ...` |
| 2 regenerate (after a .ioc change) | `bash $S/regen.sh apps/<app>` | `REGEN: PASS` |
| 2d open in IDE (run by new_app) | `bash $S/open_ide.sh apps/<app> [--no-open]` - VS Code + the toolchain extension, on the same project as the scripts | `IDE: READY` |
| 3 build | `bash $S/build.sh apps/<app> [--clean] [--allow-warnings]` | `BUILD: PASS` |
| 16 clean | `bash $S/clean.sh [--apps] [--yes]` | `CLEAN: done` |

Board: `stm32f407g-disc1`. Templates: `hello-world`, `blink`, `push-to-light`. Each app's `<app>.ioc` starts
from ST's FSBL-only template in STM32CubeN6 plus the console UART; `mx/` is generated headlessly
by STM32CubeMX and never edited by hand. Flash and test are planned (M1 board stages).

Same commands and gates as cubemx-hal-stm32n6570dk with `S=skills/cubemx-hal-stm32f407disco/scripts`
and board `stm32f407g-disc1`. The `.ioc` starts from the CubeMX board configuration
(`loadboard STM32F407G-DISC1`) plus SWO; the console is SWO output only (the board's ST-LINK/V2 has
no virtual COM port).

Run from the repo root in Git Bash. Exit code 10 = do what the `ACTION:` line says, then
re-run; common options: [docs/workflow.md](../../docs/workflow.md#common-options).

## Hardware

Sources: STM32CubeMX 6.18.1 board configuration `C47_Discovery_STM32F407G-DISC1_STM32F407VG_Board.ioc`;
STM32CubeF4 V1.28.3 BSP `Drivers/BSP/STM32F4-Discovery`.

"Verified" = seen on hardware with a dated log line in a profile README. "BSP" / "CubeMX board" =
taken from ST's files, not yet checked by us on this board.

## MCU and debug

| Item | Value | Verified |
| --- | --- | --- |
| MCU | STM32F407VGT6; STM32CubeProgrammer: device ID **0x413** (STM32F405/407/415/417), rev Z, Cortex-M4, VTarget 3.23 V | yes (2026-10-07, hot-plug connect) |
| Debug | on-board **ST-LINK/V2** (USB `0483:3748`, FW V2J46S0 seen), SWD; reports no board name | yes (2026-10-07) |
| Console | **no virtual COM port** (ST-LINK/V2); SWO PB3 → ST-LINK (printf via ITM/SWV) | CubeMX board (SWO label) |
| Clocks | HSE 8 MHz crystal; CubeMX board default SYSCLK 25 MHz (PLL M=8 N=50 P=4) | CubeMX board |
| USB OTG FS | micro-USB CN5: PA11/PA12, VBUS PA9, ID PA10 | CubeMX board |

## User I/O

| Silkscreen | Pin | Active level | Verified |
| --- | --- | --- | --- |
| LD3 (orange) | PD13 | high | BSP |
| LD4 (green) | PD12 | high | BSP |
| LD5 (red) | PD14 | high | BSP |
| LD6 (blue) | PD15 | high | BSP |
| B1 (blue, user) | PA0 (EXTI0), external pull-down | high = pressed | BSP |
| B2 (black) | NRST | - | - |

## Safety notes

- Never change option bytes / read-out protection or upgrade the ST-LINK firmware without asking.
