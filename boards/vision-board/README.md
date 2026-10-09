# RT-Thread Vision Board (RA8D1)

Machine-vision development board by RT-Thread with a Renesas RA8D1 (Arm Cortex-M85) and an on-board
ART-Link (CMSIS-DAP) debugger. Tool-independent hardware sheet.

| Profile | Skill | Status |
| --- | --- | --- |
| [scons-rtthread-visionboard/](scons-rtthread-visionboard/README.md) | `skills/scons-rtthread-visionboard` (RT-Thread 5.0.2 + scons + pyOCD, RT-Thread Studio) | hello-world tested on hardware |

## Bring-up demos

| Demo | Uses | `scons-rtthread-visionboard` |
| --- | --- | --- |
| hello-world | console: ART-Link virtual COM port (msh) | tested |
| blink | LED1 = blue LED (P102) | built |
| push-to-light | BTN1 = KEY0 toggles LED1 | built |

Levels: built < flashed < tested (automatic test PASS) < interactive (a person pressed a
button) < observed (a person saw the LED). \* = verified under its earlier name `uart-btn-led`
(renamed 2026-10-09, same code). Dated evidence: the profile README of each skill.

## Required tools

- Windows with Git for Windows (Git Bash); Python 3 with pyserial.
- RT-Thread Studio with, from its SDK Manager: the `VISION-BOARD` 1.3.0 board support package,
  GNU_Tools_for_ARM_Embedded_Processors 13.3 and RealThread PyOCD 0.2.9 (`check_tools.sh` lists
  what is missing). Studio brings the RT-Thread env (scons).
- Workspace path ≤100 characters, English characters only; each app is a standalone ~38 MB copy.

## Commands

```bash
S=skills/scons-rtthread-visionboard/scripts
```

| Stage | Command | Gate |
| --- | --- | --- |
| 0 help | `bash $S/help.sh [--en]` | - |
| 1 setup | `bash $S/check_tools.sh <board> [--ws <workspace>]` | `missing/bad=0` |
| 2 create | `bash $S/new_app.sh <board> <app> [<workspace>\|""] [template] [--no-open]` | `Created ...` |
| 2d open in IDE (run by new_app) | `bash $S/open_ide.sh apps/<app> [--no-open]` - import into the RT-Thread Studio workspace + start Studio | `IDE: READY` |
| 3 build | `bash $S/build.sh apps/<app> [--clean] [--allow-warnings]` | `BUILD: PASS` |
| 4 connect | `bash $S/discover.sh <board> [--serial <probe-serial>]` | `IDENTITY: PASS` |
| 5 flash | `bash $S/flash.sh apps/<app> --yes` | `FLASH: PASS` |
| 6 test | `python $S/serial_test.py auto apps/<app>/tests/<spec>.json apps/<app>/logs/test.log --board <board> [--interactive]` | `RESULT: PASS` |
| 16 clean | `bash $S/clean.sh [--apps] [--yes]` | `CLEAN: done` |

Board: `vision-board`. Templates: `hello-world`, `blink`, `push-to-light` (msh commands `info`, `led`, `btn`;
KEY0 toggles LED1 = the blue LED). An app is the SDK's blink project + RT-Thread + a layered `src/`,
already synced as an RT-Thread Studio project (GCC 13.3). flash.sh writes code flash only - never
the FSP's option-setting memory - and reads every byte back.

Example - hello-world on a Vision Board:

```bash
S=skills/scons-rtthread-visionboard/scripts
bash $S/check_tools.sh vision-board
bash $S/discover.sh vision-board
bash $S/new_app.sh vision-board hello "" hello-world
bash $S/build.sh apps/hello
bash $S/flash.sh apps/hello --yes
python $S/serial_test.py auto apps/hello/tests/hello_world.json apps/hello/logs/test.log --board vision-board
```

Run from the repo root in Git Bash. Exit code 10 = do what the `ACTION:` line says, then
re-run; common options: [docs/workflow.md](../../docs/workflow.md#common-options).

## Hardware

Sources: the Vision Board SDK 1.3.0 in RT-Thread Studio (sdk-bsp-ra8d1-vision-board: README,
`vision_board_blink_led`, `vision_board_openmv` Kconfig/pin data, KiCad schematic labels).

"Verified" = seen on hardware with a dated log line in a profile README. "Vendor docs" = taken from
the SDK, not yet checked by us on this board.

## MCU and USB

| Item | Value | Verified |
| --- | --- | --- |
| MCU | Renesas RA8D1 R7FA8D1BH, Arm Cortex-M85 480 MHz (Helium), 2 MB code flash at 0x02000000, 1 MB SRAM; 32 MB SDRAM, 8 MB QSPI flash on the board | CPUID `0x410FD232` (Cortex-M85 r0p2) read 2026-10-09 |
| Debugger | ART-Link CMSIS-DAP on the DAP-Link USB-C port: `0416:7687`, composite = CMSIS-DAP + virtual COM port + mass storage; pyOCD target `R7FA8D1BH` | yes (2026-10-09) |
| Console | RT-Thread msh on `uart9` (SCI9) -> the ART-Link virtual COM port, 115200 | yes (2026-10-09, hello-world test) |
| Security state | the core runs in Secure state (flat project, no TrustZone split) | read 2026-10-09 (`Running [Secure]`) |
| Option-setting memory | OFS/SAS/security settings at 0x0300A100.., data-flash settings at 0x27030080.. - the FSP build puts `.option_setting_*` sections there | ELF read 2026-10-09; never written by the skill |
| First connection | the BSP notes SWD may be closed on a new board: hold RST while the debugger connects | vendor docs (not needed on this board) |

## User I/O

| Silkscreen / name | Pin | Active level | Notes | Verified |
| --- | --- | --- | --- | --- |
| RGB LED - blue | P102 | low = on (common anode) | **LED1** of the skill's board layer; blinked by the SDK example | vendor docs |
| RGB LED - other colours | P106, PA07 | low = on | **LED2**, **LED3**; red/green order from the OpenMV port - to be confirmed by the interactive test | vendor docs (unverified colours) |
| **KEY0** | P907 | low = pressed (assumed) | input, external pull; `USER_KEY_PIN_NAME` default "p907" in the SDK | vendor docs |
| RST | reset | - | | - |
