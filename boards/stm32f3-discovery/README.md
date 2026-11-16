# ST STM32F3DISCOVERY

Discovery kit with the STM32F303VCT6 (Cortex-M4F, 72 MHz max, 256 KB flash, 48 KB SRAM + 8 KB CCM),
MB1035, with an on-board ST-LINK/V2. Tool-independent hardware sheet.

| Profile | Skill | Status |
| --- | --- | --- |
| [cubemx-hal-stm32f303disco/](cubemx-hal-stm32f303disco/README.md) | [`skills/cubemx-hal-stm32f303disco`](../../skills/cubemx-hal-stm32f303disco/README.md) ([ไทย](../../skills/cubemx-hal-stm32f303disco/README_TH.md)) (STM32CubeMX 6.18 + STM32CubeF3 HAL + CMake) | M1 create, build, connect, flash; blink observed |

FreeRTOS on this board: skill `cubemx-freertos-stm32f303disco` in
[automated-firmware-skills-freertos](https://github.com/vsupacha/automated-firmware-skills-freertos).

## Bring-up demos

| Demo | Uses | `cubemx-hal-stm32f303disco` |
| --- | --- | --- |
| hello-world | console: SWO (no virtual COM port) | built |
| blink | LED1 = LD3 (red) | observed |
| push-to-light | BTN1 = B1 (blue) toggles LED1 | built |

Levels: built < flashed < tested (automatic test PASS) < interactive (a person pressed a
button) < observed (a person saw the LED). Dated evidence: the profile README of each skill.

## Required tools

- Windows with Git for Windows (Git Bash); Python 3.
- STM32CubeMX 6.18.1 with the STM32Cube_FW_F3 V1.11.6 package (installed from STM32CubeMX:
  Help > Manage embedded software packages), and the STM32Cube bundles GNU Tools for STM32
  14.3.1+st.2, CMake 4.4.0+st.1, Ninja 1.13.2+st.1, STM32CubeProgrammer 2.23.0 (flash).
- Workspace path without spaces, ≤100 characters.
- No serial port needed: the console is SWO (read it in the debugger's SWV view).

## Commands

`<app folder>` = the folder `new_app.sh` prints (this PC's apps workspace; `apps/<name>` in the repository only when no workspace is chosen).

```bash
S=skills/cubemx-hal-stm32f303disco/scripts
```

| Stage | Command | Gate |
| --- | --- | --- |
| 0 help | `bash $S/help.sh [--en]` | - |
| 1 setup | `bash $S/check_tools.sh <board> [--ws <workspace>]` | `missing/bad=0` |
| 2 create | `bash $S/new_app.sh <board> <app> [<workspace>\|""] [template]` | `REGEN: PASS`, `Created ...` |
| 2 regenerate (after a .ioc change) | `bash $S/regen.sh <app folder>` | `REGEN: PASS` |
| 2d open in IDE (run by new_app) | `bash $S/open_ide.sh <app folder> [--no-open]` - VS Code + the toolchain extension, on the same project as the scripts | `IDE: READY` |
| 3 build | `bash $S/build.sh <app folder> [--clean] [--allow-warnings]` | `BUILD: PASS` |
| 4 connect (read-only) | `bash $S/discover.sh <board> [--serial <sn>]` | `IDENTITY: PASS` |
| 5 flash (ask first) | `bash $S/flash.sh <app folder> --yes [--elf <file>]` | `FLASH: PASS` |
| 16 clean | `bash $S/clean.sh [--apps] [--yes]` | `CLEAN: done` |

Board: `stm32f3-discovery`. Templates: `hello-world`, `blink`, `push-to-light`. `mx/` is generated
headlessly by STM32CubeMX from each app's `<app>.ioc` and never edited by hand. The `.ioc` starts
from the CubeMX board configuration (`loadboard STM32F3DISCOVERY`) plus SWO; the console is SWO
output only (the board's ST-LINK/V2 has no virtual COM port), so the test stage (SWO reader) is
planned, as for the F4 Discovery.

Run from the repo root in Git Bash. Exit code 10 = do what the `ACTION:` line says, then
re-run; common options: [docs/workflow.md](../../docs/workflow.md#common-options).

## Hardware

Sources: STM32CubeMX 6.18.1 board configuration `C30_Discovery_STM32F3DISCOVERY_STM32F303VC_Board.ioc`;
STM32CubeF3 V1.11.6 BSP `Drivers/BSP/STM32F3-Discovery`. Board user manual: ST UM1570 "Discovery
kit with STM32F303VC MCU" (<https://www.st.com/resource/en/user_manual/um1570-discovery-kit-with-stm32f303vc-mcu-stmicroelectronics.pdf>)
- vendor documents are linked, not copied into the repo. CubeMX also lists `STM32F303C-DISC1` - the
newer board revision with an ST-LINK/V2-B (virtual COM port); this sheet is the ST-LINK/V2 board.

"Verified" = seen on hardware with a dated log line in a profile README. "BSP" / "CubeMX board" =
taken from ST's files, not yet checked by us on this board.

### MCU and debug

| Item | Value | Verified |
| --- | --- | --- |
| MCU | STM32F303VCTx, LQFP100; STM32CubeProgrammer: device `STM32F302xB-xC/STM32F303xB-xC/F358xx`, ID **0x422**, rev Y, VTarget 2.93 V | yes (2026-11-12, hot-plug connect) |
| Debug | on-board **ST-LINK/V2** (USB `0483:3748`, FW V2J45S0 seen), SWD + SWO; reports no board name, no virtual COM port | yes (2026-11-12) |
| Console | SWO on PB3 (ITM port 0) only | CubeMX board |
| Clocks | board default SYSCLK 48 MHz: HSE 8 MHz from the ST-LINK's MCO x PLL 12 | generated code |

### User I/O

| Silkscreen | Pin | Active level | Verified |
| --- | --- | --- | --- |
| LD3 (red) | PE9 | high | yes (2026-11-12: blink, seen by a person) |
| LD4 (blue) | PE8 | high | BSP |
| LD5 (orange) | PE10 | high | BSP |
| LD6 (green) | PE15 | high | BSP |
| LD7 (green) | PE11 | high | BSP |
| LD8 (orange) | PE14 | high | BSP |
| LD9 (blue) | PE12 | high | BSP |
| LD10 (red) | PE13 | high | BSP |
| B1 USER (blue) | PA0 | high (pull-down) | BSP |
| B2 RESET (black) | NRST | - | - |

The skill numbers the LEDs in the BSP order: LED1 = LD3, LED2 = LD4, ... LED8 = LD10.

### On-board parts (none used by the skill yet)

L3GD20 3-axis gyroscope (SPI1 PA5/PA6/PA7, CS PE3, INT PE0/PE1), LSM303DLHC accelerometer +
magnetometer (I2C1 PB6/PB7, INT PE2/PE4/PE5), USB user connector (PA11/PA12).
