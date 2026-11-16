# ST STM32L476G-DISCO (32L476GDISCOVERY)

Discovery kit with the STM32L476VGT6 (Cortex-M4F, 80 MHz max, 1 MB flash, 128 KB RAM), MB1184, with
an on-board ST-LINK/V2-1 (virtual COM port). Tool-independent hardware sheet.

| Profile | Skill | Status |
| --- | --- | --- |
| [cubemx-hal-stm32l476disco/](cubemx-hal-stm32l476disco/README.md) | [`skills/cubemx-hal-stm32l476disco`](../../skills/cubemx-hal-stm32l476disco/README.md) ([ไทย](../../skills/cubemx-hal-stm32l476disco/README_TH.md)) (STM32CubeMX 6.18 + STM32CubeL4 HAL + CMake) | M1 incl. board stages; push-to-light tested |

FreeRTOS on this board: skill `cubemx-freertos-stm32l476disco` in
[automated-firmware-skills-freertos](https://github.com/vsupacha/automated-firmware-skills-freertos).

## Bring-up demos

| Demo | Uses | `cubemx-hal-stm32l476disco` |
| --- | --- | --- |
| hello-world | console: ST-LINK virtual COM port | built |
| blink | LED1 = LD4 (red) | built |
| push-to-light | BTN1 = joystick center toggles LED1 | tested |

Levels: built < flashed < tested (automatic test PASS) < interactive (a person pressed a
button) < observed (a person saw the LED). Dated evidence: the profile README of each skill.

## Required tools

- Windows with Git for Windows (Git Bash); Python 3 with pyserial.
- STM32CubeMX 6.18.1 with the STM32Cube_FW_L4 V1.18.2 package, and the STM32Cube bundles GNU Tools
  for STM32 14.3.1+st.2, CMake 4.4.0+st.1, Ninja 1.13.2+st.1, STM32CubeProgrammer 2.23.0; for
  `debug.sh run` also the ST-LINK GDB server 7.14.0+st.2 bundle.
- Workspace path without spaces, ≤100 characters.

## Commands

`<app folder>` = the folder `new_app.sh` prints (this PC's apps workspace; `apps/<name>` in the repository only when no workspace is chosen).

```bash
S=skills/cubemx-hal-stm32l476disco/scripts
```

| Stage | Command | Gate |
| --- | --- | --- |
| 0 help | `bash $S/help.sh [--en]` | - |
| 1 setup | `bash $S/check_tools.sh <board> [--ws <workspace>]` | `missing/bad=0` |
| 4 connect | `bash $S/discover.sh <board> [--serial <stlink-serial>]` | `IDENTITY: PASS` |
| 2 create | `bash $S/new_app.sh <board> <app> [<workspace>\|""] [template] [--no-open]` | `REGEN: PASS`, `Created ...` |
| 2 regenerate (after a .ioc change) | `bash $S/regen.sh <app folder>` | `REGEN: PASS` |
| 2d open in IDE (run by new_app) | `bash $S/open_ide.sh <app folder> [--no-open]` | `IDE: READY` |
| 3 build | `bash $S/build.sh <app folder> [--clean] [--allow-warnings]` | `BUILD: PASS` |
| 5 flash | `bash $S/flash.sh <app folder> --yes [--elf <file.elf>]` | `FLASH: PASS` |
| 6 test | `python $S/serial_test.py auto <app folder>/tests/<spec>.json <app folder>/logs/test.log --board <board> [--interactive]` | `RESULT: PASS` |
| 7 debug (read-only status) | `bash $S/debug.sh status <board>` - no reset, no halt | `DEBUG: STATUS running fault=none` |
| 16 clean | `bash $S/clean.sh [--apps] [--yes]` | `CLEAN: done` |

Board: `stm32l476g-disco`. Templates: `hello-world`, `blink`, `push-to-light`. The `.ioc` starts
from the CubeMX board configuration (`loadboard STM32L476G-DISCO nomode`) plus USART2 on the ST-LINK
virtual COM port; the console receives by interrupt.

Run from the repo root in Git Bash. Exit code 10 = do what the `ACTION:` line says, then
re-run; common options: [docs/workflow.md](../../docs/workflow.md#common-options).

## Hardware

Sources: STM32CubeMX 6.18.1 board configuration `D40_Discovery_STM32L476G-DISCO_STM32L476VG_Board.ioc`;
STM32CubeL4 V1.18.2 BSP `Drivers/BSP/STM32L476G-Discovery`. Board user manual: ST UM1879 "Discovery
kit with STM32L476VG MCU" (<https://www.st.com/resource/en/user_manual/um1879-discovery-kit-with-stm32l476vg-mcu-stmicroelectronics.pdf>)
- vendor documents are linked, not copied into the repo.

"Verified" = seen on hardware with a dated log line in a profile README. "BSP" / "CubeMX board" =
taken from ST's files, not yet checked by us on this board.

### MCU and debug

| Item | Value | Verified |
| --- | --- | --- |
| MCU | STM32L476VGTx, LQFP100; STM32CubeProgrammer: device `STM32L4x1/STM32L475xx/STM32L476xx/STM32L486xx`, ID **0x415**, rev 4, VTarget 3.23 V; CPUID 0x410FC241 (Cortex-M4 r0p1) | yes (2026-11-12) |
| Debug | on-board **ST-LINK/V2-1** (USB `0483:374B`, FW V2J32M22 seen), SWD; reports board name `STM32L476G-DK` | yes (2026-11-12) |
| Console | **virtual COM port**: USART2 PD5 TX / PD6 RX → ST-LINK, 115200 8N1; RX by interrupt | yes (2026-11-12, serial tests) |
| Clocks | board default SYSCLK 4 MHz (MSI range 6, no PLL) | generated code |

### User I/O

| Silkscreen | Pin | Active level | Verified |
| --- | --- | --- | --- |
| LD4 (red) | PB2 | high | yes (2026-11-12: driven by the console, read back) |
| LD5 (green) | PE8 | high | yes (2026-11-12: driven by the console, read back) |
| Joystick center (BTN1) | PA0 | high (pull-down) | read released (2026-11-12) |
| Joystick left / right / up / down (BTN2..BTN5) | PA1 / PA2 / PA3 / PA5 | high (pull-down) | read released (2026-11-12) |
| B1 RESET (black) | NRST | - | - |

### On-board parts (none used by the skill yet)

24-segment LCD glass, L3GD20 gyroscope, LSM303C accelerometer + magnetometer, MP34DT01 microphone,
CS43L22 audio DAC, N25Q128A 128 Mbit QSPI flash, USB OTG FS, IDD measurement.
