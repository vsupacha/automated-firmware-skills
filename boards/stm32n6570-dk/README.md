# ST STM32N6570-DK

Discovery kit with the STM32N657X0H3Q (Cortex-M55 + Neural-ART NPU, no internal flash: code runs
from internal SRAM or boots from external XSPI flash through the first-stage boot loader).
Tool-independent hardware sheet.

| Profile | Skill | Status |
| --- | --- | --- |
| [cubemx-hal-stm32n6570dk/](cubemx-hal-stm32n6570dk/README.md) | `skills/cubemx-hal-stm32n6570dk` (STM32CubeMX 6.18 + STM32CubeN6 HAL + CMake) | M1: generated + built, not run on hardware |

## Bring-up demos

| Demo | Uses | `cubemx-hal-stm32n6570dk` |
| --- | --- | --- |
| hello-world | console: ST-LINK virtual COM port | built |
| blink | LED1 = LED1 (green) | not built yet |
| push-to-light | BTN1 = USER1 toggles LED1 | built |

Levels: built < flashed < tested (automatic test PASS) < interactive (a person pressed a
button) < observed (a person saw the LED). \* = verified under its earlier name `uart-btn-led`
(renamed 2026-10-09, same code). Dated evidence: the profile README of each skill.

## Required tools

- Windows with Git for Windows (Git Bash); Python 3.
- STM32CubeMX 6.18.1 with the STM32Cube_FW_N6 V1.4.1 package (installed from STM32CubeMX:
  Help > Manage embedded software packages), and the STM32Cube bundles GNU Tools for STM32
  14.3.1+st.2, CMake 4.4.0+st.1, Ninja 1.13.2+st.1 (as for cubemx2-hal2-stm32c562nucleo).
- Workspace path without spaces, ≤100 characters.

## Commands

```bash
S=skills/cubemx-hal-stm32n6570dk/scripts
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

Board: `stm32n6570-dk`. Templates: `hello-world`, `blink`, `push-to-light`. Each app's `<app>.ioc` starts
from ST's FSBL-only template in STM32CubeN6 plus the console UART; `mx/` is generated headlessly
by STM32CubeMX and never edited by hand. Flash and test are planned (M1 board stages).

Run from the repo root in Git Bash. Exit code 10 = do what the `ACTION:` line says, then
re-run; common options: [docs/workflow.md](../../docs/workflow.md#common-options).

## Hardware

Sources: STM32CubeMX 6.18.1 board configuration `M13_Discovery_STM32N6570-DK_STM32N657X0H_Board.ioc`
(board database); STM32CubeN6 V1.4.1 BSP `Drivers/BSP/STM32N6570-DK` and `Projects/STM32N6570-DK/Templates`.

"Verified" = seen on hardware with a dated log line in a profile README. "CubeMX board" = taken from
the STM32CubeMX board configuration, not yet checked by us on this board.

## MCU and debug

| Item | Value | Verified |
| --- | --- | --- |
| MCU | STM32N657X0H3Q (CubeMX name STM32N657X0HxQ), Cortex-M55, VFBGA264, no internal flash | CubeMX board |
| Boot | FSBL (first-stage boot loader) in internal SRAM; development boot mode lets the debugger load and run code in SRAM | vendor docs |
| Debug | on-board STLINK-V3 (PID 0x3754, FW V3J16M8 seen), SWD; reports board name "STM32N6570-DK" | yes (2026-10-07) |
| Debug attach | only in **development boot mode (BOOT1 switch 1-3)** and only **connect under reset**: hot-plug gives "Unable to get core ID"; in flash boot (BOOT1 0) no attach at all | yes (2026-10-07) |
| Device | STM32CubeProgrammer: device ID **0x486**, STM32N6xx, rev Z, Cortex-M55, VTarget 3.29 V | yes (2026-10-07) |
| SMPS control | PF4: high = overdrive voltage, needed for the 800 MHz CPU clock (BSP `BSP_SMPS_Init`) | BSP |
| Console | USART1 TX PE5 / RX PE6 (labels VCP_TX / VCP_RX) → ST-LINK virtual COM port | CubeMX board |
| CubeMX contexts | FSBL, AppliSecure, AppliNonSecure, ExtMemLoader | CubeMX board |

## User I/O

| Name | Pin | Active level | Verified |
| --- | --- | --- | --- |
| LED1 (green) | PO1 | high (BSP `BSP_LED_On`) | BSP, not seen on hardware |
| LED2 (red) | PG10 | **low** (BSP `BSP_LED_On`) | BSP, not seen on hardware |
| USER1 button (BSP `BUTTON_USER1`) | PC13 (EXTI13), pull-down | high = pressed | BSP, not seen on hardware |

## Safety notes

- Never program OTP fuses or change the product state / security settings - irreversible.
- Boot switches (BOOT0/BOOT1) select development vs flash boot - the developer sets them (JUMPER).
