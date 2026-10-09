# RT-Thread Edgi-Talk

PSOC Edge E84 board by RT-Thread. Tool-independent hardware sheet - pins, user I/O and on-board
parts. Toolchain profiles live in subfolders:

| Profile | Skill | Status |
| --- | --- | --- |
| [modus-pdl-edgitalk/](modus-pdl-edgitalk/README.md) | `skills/modus-pdl-edgitalk` (ModusToolbox) | verified on hardware |

## Bring-up demos

| Demo | Uses | `modus-pdl-edgitalk` |
| --- | --- | --- |
| hello-world | console: KitProg3 USB-UART | tested |
| blink | LED1 = LED1 (red) | built |
| push-to-light | BTN1 = SW2 toggles LED1 | interactive * |

Levels: built < flashed < tested (automatic test PASS) < interactive (a person pressed a
button) < observed (a person saw the LED). \* = verified under its earlier name `uart-btn-led`
(renamed 2026-10-09, same code). Dated evidence: the profile README of each skill.

## Required tools

- Windows with Git for Windows (Git Bash); Python 3 with pyserial.
- ModusToolbox 3.9 tools, ModusToolbox Programming Tools, Arm GCC, Edge Protect Security Suite.
- **Short paths without spaces or non-English characters** for the workspace (≤100 characters),
  the Windows user folder and the ModusToolbox install - the scripts refuse unsafe paths.
  Cloud-synced folders work; pause sync if files get locked.

## Commands

```bash
S=skills/modus-pdl-edgitalk/scripts
```

| Stage | Command | Gate |
| --- | --- | --- |
| 0 help | `bash $S/help.sh [--en]` | - |
| 1 setup | `bash $S/check_tools.sh <board> [--fix] [--ws <workspace>]` | `missing/bad=0` |
| 4 connect | `bash $S/discover.sh <board> [--serial <probe-serial>]` | `IDENTITY: PASS` |
| 2 create | `bash $S/new_app.sh <board> <app> [<workspace>\|""] [template]` | `Created ...` |
| 2 create from example | `bash $S/examples.sh <board> [words] [--detail <id>]`, then `bash $S/new_app.sh <board> <app> "" --example <id>` | `Created ...` |
| 2d open in IDE (run by new_app) | `bash $S/open_ide.sh apps/<app> [--no-open]` - VS Code + the toolchain extension, on the same project as the scripts | `IDE: READY` |
| 3 build | `bash $S/build.sh apps/<app> [--clean] [--getlibs] [--allow-warnings]` | `BUILD: PASS` |
| 5 backup (before the first flash) | `bash $S/backup.sh <board>` | backup files written |
| 5 flash | `bash $S/flash.sh apps/<app> --yes [--hex <file.hex>]` | `FLASH: PASS` (exit 10 `ACTION: POWER_CYCLE` = replug USB) |
| 6 test | `python $S/serial_test.py auto apps/<app>/tests/<spec>.json apps/<app>/logs/test.log --board <board> [--interactive]` | `RESULT: PASS` |
| 16 clean | `bash $S/clean.sh [--apps] [--yes]` | `CLEAN: done` |

Board: `edgi-talk`. Templates: `hello-world`, `blink`, `push-to-light`, plus `button-led` and
`dual-core-ipc`. BSP diff tool: `python $S/modus_diff.py base.modus board.modus`.

Example - hello world on Edgi-Talk:

```bash
S=skills/modus-pdl-edgitalk/scripts
bash $S/check_tools.sh edgi-talk
bash $S/discover.sh edgi-talk
bash $S/new_app.sh edgi-talk hello-edgi "" hello-world
bash $S/build.sh apps/hello-edgi
bash $S/flash.sh apps/hello-edgi --yes
python $S/serial_test.py auto apps/hello-edgi/tests/hello_world.json apps/hello-edgi/logs/test.log --board edgi-talk
```

Run from the repo root in Git Bash. Exit code 10 = do what the `ACTION:` line says, then
re-run; common options: [docs/workflow.md](../../docs/workflow.md#common-options).

## Hardware

Sources: RT-Thread BSP <https://github.com/RT-Thread-Studio/sdk-bsp-psoc_e84-edgi-talk>
(schematics: `docs/board/PSOC-Edge-E84/PSoc_Edge_Basic_Schematic.pdf`, `..._Core_Schematic.pdf`;
product brief and data sheet in the same folder).

"Verified" = seen on our hardware with a dated log line in a profile README. "Vendor docs" = taken
from the RT-Thread project READMEs, not yet checked by us.

## MCU and debug

| Item | Value | Verified |
| --- | --- | --- |
| MCU | Infineon PSOC Edge E84 `PSE846GPS2DBZC4A`, EPC2, silicon B0, life cycle DEVELOPMENT | yes |
| Cores | CM33 secure + CM33 non-secure + CM55 | yes |
| Debug | **CN12 (USB-DEBUG)**: on-board KitProg3 (PSoC 5LP), SWD, CMSIS-DAPv2 `04b4:f155` | yes |
| Console | SCB2 RX P6[5] / TX P6[7] → KitProg3 USB-UART, 115200 8N1 | yes |
| MCU USB | CN11 = E84 USB device port | vendor docs |
| JTAG/trace | 20-pin J2, **1.8 V** reference (external probes must support 1.8 V); pin-1 orientation unconfirmed | partly |
| VTarget | ~1.81 V | yes |
| Alt. console | SCB5 P17[0]/P17[1] (RT-Thread M33 console), needs an external USB-UART adapter | vendor docs |

## User I/O

| Silkscreen | Pin | Active level | Verified |
| --- | --- | --- | --- |
| LED1 (red) | P16[7] | high | yes |
| LED2 (green) | P16[6] | high | yes |
| LED3 (blue) | P16[5] | high | yes |
| SW2 (the only user button) | P8[3], pull-up | low | yes |
| - | P8[7] | - | **not populated** (eval-kit button in the base BSP) |

## On-board parts

| Part | Function | Bus / pins | Verified |
| --- | --- | --- | --- |
| LCD + touch | display on MIPI DSI, backlight, BTB socket; panel/controller not named in the README - see schematic | MIPI DSI (`gfxss`) | vendor docs |
| ES8388 | audio codec, speaker output with volume control | I2S + I2C | vendor docs |
| PDM microphone | audio input | PDM | vendor docs |
| LSM6DS3TR-C | 6-axis IMU (accel + gyro + temperature) | I2C (`i2c0`) @ 0x6A | vendor docs |
| AHT10/AHT20 | temperature + humidity | I2C (`i2c1`); RT-Thread uses soft-I2C on P9[2]/P9[3], which the base BSP maps to SCB1 UART - choose one | vendor docs |
| HyperRAM | external RAM | SMIF slot 6 | vendor docs |
| QSPI NOR flash | external flash (app image area 0x60000000) | SMIF | yes (programmed + verified by flash) |
| SD card | storage | SDIO | vendor docs |
| Battery sense | voltage on ADC1 channel 1; P8.4 switches the divider power | ADC | vendor docs |
| Wi-Fi | used by RT-Thread project `Edgi_Talk_M55_WIFI`; module not named | - | vendor docs |
| CAN FD | in the RT-Thread `design.modus` | - | vendor docs |
| Crystal (ECO) | **12.288 MHz** (the EPC2 eval kit uses 17.2032 MHz + a 24 MHz external clock this board does not have) | - | yes (boots, 1 s SysTick accurate) |

To do (from the schematic): LCD panel size/resolution/controller, touch controller and address,
Wi-Fi/BT module part number, codec/IMU/AHT20 pin numbers, speaker amplifier part.

## Hardware quirks

- **Never run an image built for the stock EPC2 eval kit**: its clock path 0 expects an external
  clock on P7[4] that Edgi-Talk does not have.
