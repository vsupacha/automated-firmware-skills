# NXP FRDM-MCXN947

MCXN947VDF (dual Arm Cortex-M33 up to 150 MHz - core 0 with FPU/DSP, core 1 without -, 2 MB
flash, 512 KB RAM, eIQ Neutron NPU, PowerQuad) with an on-board MCU-Link (CMSIS-DAP debug probe +
virtual COM port) on USB-C J17. Tool-independent hardware sheet.

| Profile | Skill | Status |
| --- | --- | --- |
| [mcux-sdk-frdmmcxn947/](mcux-sdk-frdmmcxn947/README.md) | [`skills/mcux-sdk-frdmmcxn947`](../../skills/mcux-sdk-frdmmcxn947/README.md) ([ไทย](../../skills/mcux-sdk-frdmmcxn947/README_TH.md)) (MCUXpresso SDK 26.09 + CMake) | M1 incl. board stages (connect, flash, test); debug planned |

## Bring-up demos

| Demo | Uses | `mcux-sdk-frdmmcxn947` |
| --- | --- | --- |
| hello-world | console: MCU-Link virtual COM port | tested |
| blink | LED1 = red | built |
| push-to-light | BTN1..2 = SW2, SW3 toggle LED1..2 = red, green | tested |

Levels: built < flashed < tested (automatic test PASS) < interactive (a person pressed a
button) < observed (a person saw the LED). Dated evidence: the profile README of each skill.

## Required tools

- Windows with Git for Windows (Git Bash); Python 3 (pyserial for the board stages).
- MCUXpresso SDK v26.09.00 as a west workspace (default `C:/mcux-26.09`, or `MCUX_SDK_ROOT`).
- MCUXpresso Installer tools in `~/.mcuxpressotools`: Arm GNU Toolchain 14.2.Rel1, Ninja 1.13.2,
  the Python venv with west. Kitware CMake 3.30 or newer. LinkServer 26.5.59 (board stages).
- IDE path: VS Code + MCUXpresso for VS Code 26.9.44.
- **No ST tools**: `cube-cmake`, STM32CubeCLT CMake / Ninja / GCC are never used for this board.
- Workspace path without spaces, ≤100 characters.

## Commands

```bash
S=skills/mcux-sdk-frdmmcxn947/scripts
```

| Stage | Command | Gate |
| --- | --- | --- |
| 1 tools | `bash $S/check_tools.sh frdm-mcxn947` | `missing/bad=0` |
| 2 create | `bash $S/new_app.sh frdm-mcxn947 my-app "" push-to-light` | `Created <folder>` |
| 2d IDE | `bash $S/open_ide.sh <folder>` | `IDE: READY` |
| 3 build | `bash $S/build.sh <folder>` | `BUILD: PASS` |
| 4 connect | `bash $S/discover.sh frdm-mcxn947` | `IDENTITY: PASS` |
| 5 flash | `bash $S/flash.sh <folder> --yes` (ask first) | `FLASH: PASS` |
| 6 test | `python $S/serial_test.py auto <folder>/tests/push_to_light.json <folder>/logs/t.log --board frdm-mcxn947 --sync` | `RESULT: PASS` |
| 16 clean | `bash $S/clean.sh` (dry run), then `--yes` | `CLEAN: done` |

## Hardware

| Item | Value |
| --- | --- |
| Debug probe | MCU-Link on J17 (VID 0x1FC9), CMSIS-DAP + VCOM + SWO; target reports `MCXN947VDF` / `FRDM-MCXN947`. J18 open = VCOM on, J19 open = SWD on (defaults) |
| Console | LP_FLEXCOMM4 (P1_8 RX / P1_9 TX) → MCU-Link VCOM, 115200 8N1 |
| LEDs | RGB LED D2, active low: red P0_10, green P0_27, blue P1_2 |
| Buttons | SW1 reset; SW2 wakeup P0_23; SW3 ISP P0_6 (held at reset = ROM bootloader); pressed = low |
| Memory (LinkServer map) | internal flash 0x00000000-0x00200000 (two 1 MB regions; secure alias 0x10000000), RAM from 0x20000000, FlexSPI flash 0x80000000 (8 MB) |
| Protected flash | PFR (CMPA / CFPA) and IFR hold boot and security settings - never written by the skills |

Sources: SDK board files (`examples/_boards/frdmmcxn947/board.h`), NXP UM12018 (FRDM-MCXN947
board user manual), LinkServer `device MCXN947:FRDM-MCXN947 info`, the spikes of 2026-10-29.
