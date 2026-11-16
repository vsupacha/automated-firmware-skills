# ST NUCLEO-WB55RG

STM32WB55RGV6 (dual core: Cortex-M4 application core at up to 64 MHz + Cortex-M0+ radio core,
1 MB flash, 256 KB RAM, Bluetooth LE 5 / 802.15.4) with an on-board ST-LINK/V2-1 (MB1355). The
Nucleo board of the P-NUCLEO-WB55 kit (the kit's ST-LINK reports `P-NUCLEO-WB55`). Tool-independent
hardware sheet.

| Profile | Skill | Status |
| --- | --- | --- |
| [cubemx-hal-stm32wb55nucleo/](cubemx-hal-stm32wb55nucleo/README.md) | [`skills/cubemx-hal-stm32wb55nucleo`](../../skills/cubemx-hal-stm32wb55nucleo/README.md) ([ไทย](../../skills/cubemx-hal-stm32wb55nucleo/README_TH.md)) (STM32CubeMX 6.18 + STM32CubeWB HAL + CMake) | M1 incl. board stages (connect, flash, test); debug planned |

## Bring-up demos

| Demo | Uses | `cubemx-hal-stm32wb55nucleo` |
| --- | --- | --- |
| hello-world | console: ST-LINK virtual COM port | tested |
| blink | LED1 = LED1 (blue) | built |
| push-to-light | BTN1..3 = SW1..SW3 toggle LED1..LED3 | observed |

Levels: built < flashed < tested (automatic test PASS) < interactive (a person pressed a
button) < observed (a person saw the LED). Dated evidence: the profile README of each skill.

## Required tools

- Windows with Git for Windows (Git Bash); Python 3 with pyserial (hardware stages).
- STM32CubeMX 6.18.1 (classic; installed for all users or per user - both are found) with the
  STM32Cube_FW_WB V1.24.0 package, and the STM32Cube bundles GNU Tools for STM32 14.3.1+st.2,
  CMake 4.4.0+st.1, Ninja 1.13.2+st.1, STM32CubeProgrammer 2.23.0.
- STM32CubeMX2 is **not** usable for this board yet: 1.1.2 lists `NUCLEO-WB55RG`, but its WB packs
  are "metadata only - incompatible" and `project create-from-board` answers "Board not found"
  (checked 2026-10-27).
- Workspace path without spaces, ≤100 characters.

## Commands

`<app folder>` = the folder `new_app.sh` prints (this PC's apps workspace; `apps/<name>` in the repository only when no workspace is chosen).

```bash
S=skills/cubemx-hal-stm32wb55nucleo/scripts
```

| Stage | Command | Gate |
| --- | --- | --- |
| 0 help | `bash $S/help.sh [--en]` | - |
| 1 setup | `bash $S/check_tools.sh <board> [--ws <workspace>]` | `missing/bad=0` |
| 2 create | `bash $S/new_app.sh <board> <app> [<workspace>\|""] [template] [--no-open]` | `REGEN: PASS`, `Created ...` |
| 2 regenerate (after a .ioc change) | `bash $S/regen.sh <app folder>` | `REGEN: PASS` |
| 2d open in IDE (run by new_app) | `bash $S/open_ide.sh <app folder> [--no-open]` - VS Code + the toolchain extension, on the same project as the scripts | `IDE: READY` |
| 3 build | `bash $S/build.sh <app folder> [--clean] [--allow-warnings]` | `BUILD: PASS` |
| 4 connect | `bash $S/discover.sh <board> [--serial <stlink-serial>]` | `IDENTITY: PASS` |
| 5 flash | `bash $S/flash.sh <app folder> --yes [--elf <file.elf>]` | `FLASH: PASS` |
| 6 test | `python $S/serial_test.py auto <app folder>/tests/<spec>.json <app folder>/logs/test.log --board <board> [--interactive]` | `RESULT: PASS` |
| 16 clean | `bash $S/clean.sh [--apps] [--yes]` | `CLEAN: done` |

Board: `nucleo-wb55rg`. Templates: `hello-world`, `blink`, `push-to-light` (SWn toggles LEDn). The
`.ioc` starts from the CubeMX board configuration (`loadboard NUCLEO-WB55RG nomode`), then
`clearpinout` and USART1 on the ST-LINK virtual COM port; the console receives by interrupt.

Run from the repo root in Git Bash. Exit code 10 = do what the `ACTION:` line says, then
re-run; common options: [docs/workflow.md](../../docs/workflow.md#common-options).

## Hardware

Sources: STM32CubeMX 6.18.1 board configuration `J02_Nucleo_NUCLEO-WB55RG_STM32WB55R_Board.ioc`
(`J00_..._P-NUCLEO-WB55-NUCLEO_...` is the same board with another BSP name); STM32CubeWB V1.24.0
BSP `Drivers/BSP/P-NUCLEO-WB55.Nucleo` (`stm32wbxx_nucleo.h/.c`). Board user manual: ST UM2435
"Bluetooth Low Energy and 802.15.4 Nucleo pack based on STM32WB Series microcontrollers"
(<https://www.st.com/resource/en/user_manual/um2435-bluetooth-low-energy-and-802154-nucleo-pack-based-on-stm32wb-series-microcontrollers-stmicroelectronics.pdf>)
- vendor documents are linked, not copied into the repo.

"Verified" = seen on hardware with a dated log line in a profile README. "BSP" / "CubeMX board" =
taken from ST's files, not yet checked by us on this board.

## MCU and debug

| Item | Value | Verified |
| --- | --- | --- |
| MCU | STM32WB55RGVx, VFQFPN68; STM32CubeProgrammer: device `STM32WB5x/35xx`, ID **0x495**, rev Y, VTarget 3.27 V | yes (2026-10-27, hot-plug connect) |
| Debug | on-board **ST-LINK/V2-1** (USB `0483:374B`, FW V2J45M31 seen), SWD; reports board name `P-NUCLEO-WB55` | yes (2026-10-27) |
| Console | **virtual COM port**: USART1 PB6 TX / PB7 RX → ST-LINK, 115200 8N1; RX FIFO left off, receive by interrupt | yes (2026-10-27, hello-world test 9/9) |
| Clocks | board default SYSCLK 32 MHz from MSI (range 10); SMPS clock from HSI; the 32 MHz HSE crystal (radio) is not used by default | generated code |
| Flash layout | CM4 application from 0x08000000; the CM0+ wireless stack + FUS sit at the top, secure from `SFSA`. Read on this board: RDP Level 0, `SFSA` = 0x080CE000, ESE = 1 (stack installed), CPU2 debug off | yes (2026-10-27, option bytes read only) |

## User I/O

| Silkscreen | Pin | Active level | Verified |
| --- | --- | --- | --- |
| LED1 (blue) | PB5 | high | yes (2026-10-27: driven by the console and SW1, seen lit by a person) |
| LED2 (green) | PB0 | high | yes (2026-10-27: driven by the console and SW2, seen lit by a person) |
| LED3 (red) | PB1 | high | BSP |
| SW1 | PC4 | low (pull-up) | yes (2026-10-27: pressed by a person, EVT btn1 seen) |
| SW2 | PD0 | low (pull-up) | yes (2026-10-27: pressed by a person, EVT btn2 seen) |
| SW3 | PD1 | low (pull-up) | BSP |
| SW4 RESET | NRST | - | - |

## On-board parts

USB user connector (USB FS on PA11/PA12), 32 MHz HSE and 32.768 kHz LSE crystals, PCB antenna,
Arduino Uno V3 and ST morpho connectors, CR2032 holder. The wireless stack (BLE / Thread / Zigbee)
is installed and updated with STM32CubeProgrammer's FUS commands - not part of this skill.
