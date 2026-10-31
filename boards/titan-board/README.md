# RT-Thread Titan Board (RA8P1)

Development board by RT-Thread with a Renesas RA8P1 (Arm Cortex-M85 1 GHz + Cortex-M33 250 MHz,
Ethos-U55 NPU) and an on-board RA4M2 CMSIS-DAP debugger. Tool-independent hardware sheet.

| Profile | Skill | Status |
| --- | --- | --- |
| [scons-rtthread-titanboard/](scons-rtthread-titanboard/README.md) | [`skills/scons-rtthread-titanboard`](../../skills/scons-rtthread-titanboard/README.md) ([ไทย](../../skills/scons-rtthread-titanboard/README_TH.md)) (RT-Thread 5.1.0 + scons + pyOCD, RT-Thread Studio) | blink, push-to-light tested on hardware |

## Bring-up demos

| Demo | Uses | `scons-rtthread-titanboard` |
| --- | --- | --- |
| hello-world | console: RA4M2 CMSIS-DAP virtual COM port (msh, uart8) | built |
| blink | LED1 = red LED (P013) | tested |
| push-to-light | BTN1 = KEY toggles LED1 | tested |

Levels: built < flashed < tested (automatic test PASS) < interactive (a person pressed a
button) < observed (a person saw the LED). Dated evidence: the profile README of each skill.

## Required tools

- Windows with Git for Windows (Git Bash); Python 3 with pyserial.
- RT-Thread Studio with, from its SDK Manager: the `Titan-Board` 1.0.2 board support package,
  GNU_Tools_for_ARM_Embedded_Processors 13.3 and RealThread PyOCD 0.2.9 (`check_tools.sh` lists
  what is missing). Studio brings the RT-Thread env (scons).
- **Windows driver for the debugger:** the CMSIS-DAP interface (Interface 2, "RA4M2 CMSIS-DAP") must
  have WinUSB **with a device interface GUID** (Zadig: WinUSB on "RA4M2 CMSIS-DAP (Interface 2)").
  An old libwdi "WinUSB Generic Device" INF without a GUID makes pyOCD and Studio see no probe.
- Workspace path ≤100 characters, English characters only; each app is a standalone ~88 MB copy.

## Commands

```bash
S=skills/scons-rtthread-titanboard/scripts
```

| Stage | Command | Gate |
| --- | --- | --- |
| 0 help | `bash $S/help.sh [--en]` | - |
| 1 setup | `bash $S/check_tools.sh <board> [--ws <workspace>]` | `missing/bad=0` |
| 2 create | `bash $S/new_app.sh <board> <app> [<workspace>\\|""] [template] [--no-open]` | `Created ...` |
| 2 compose | `bash $S/recipe.sh check apps/<app> <recipe>...` (read-only), `bash $S/recipe.sh apply apps/<app> <recipe>... [--yes]` | `RECIPE: READY`, `APPLY: DONE` |
| 2d open in IDE (run by new_app) | `bash $S/open_ide.sh apps/<app> [--no-open]` | `IDE: READY` |
| 3 build | `bash $S/build.sh apps/<app> [--clean] [--allow-warnings]` | `BUILD: PASS` |
| 4 connect | `bash $S/discover.sh <board> [--serial <probe-serial>]` | `IDENTITY: PASS` |
| 5 flash | `bash $S/flash.sh apps/<app> --yes` | `FLASH: PASS` |
| 6 test | `python $S/serial_test.py auto apps/<app>/tests/<spec>.json apps/<app>/logs/test.log --board <board> [--interactive]` | `RESULT: PASS` |
| 7 status | `python $S/msh_status.py auto --board <board>` | `MSH: PASS` |
| 16 clean | `bash $S/clean.sh [--apps] [--yes]` | `CLEAN: done` |

Board: `titan-board`. Templates: `hello-world`, `blink`, `push-to-light` (msh commands `info`, `led`,
`btn`; KEY toggles LED1 = the red LED). An app is the SDK's `Titan_template` project (Kconfig: GPIO +
UART8 only; FSP: nearly every peripheral generated) + RT-Thread 5.1.0 + a layered `src/`, synced as an
RT-Thread Studio project (GCC 13.3). Drivers are added with Kconfig recipes (`recipe.sh list`: ADC,
CANFD, Ethernet, GPT/PWM, HyperRAM, OSPI flash + LittleFS, I2C2, RS485, RTC, SD card, SPI0, USB PCDC,
WDT, Wi-Fi). flash.sh writes code MRAM only and reads every byte back.

## Hardware

Sources: the Titan Board SDK 1.0.2 in RT-Thread Studio (sdk-bsp-ra8p1-titan-board: README,
`Titan_template`, `Titan_basic_blink_led`, `Titan_basic_key_irq`, project .config / configuration.xml).
"Verified" = seen on hardware with a dated log line in the profile README; "vendor docs" = from the SDK.

| Item | Value | Verified |
| --- | --- | --- |
| MCU | Renesas RA8P1 R7KA8P1KFLCAC: Cortex-M85 1 GHz + Cortex-M33 250 MHz, Ethos-U55, 1 MB code MRAM at 0x02000000, 2 MB SRAM | CPUID `0x411FD231` (Cortex-M85 r1p1) read 2026-10-31 |
| Debugger | "RA4M2 CMSIS-DAP Probe" `045B:201F`: CMSIS-DAP v2 (WinUSB, no HID) + virtual COM port "RA4M2-VCOM"; pyOCD target `R7KA8P1KF` (Renesas.RA_DFP 6.1.0) | yes (2026-10-31, after the WinUSB GUID fix) |
| Console | RT-Thread msh on `uart8` (P500 RX / P501 TX) -> the probe's virtual COM port, 115200 | yes (2026-10-31) |
| Security state | the core runs in Secure state | read 2026-10-31 (`Running [Secure]`) |
| pyOCD messages | "Error probing AP#2" and an SVD parse traceback on every connect - harmless (`PYOCD_NOISE` in the profile) | 2026-10-31 |
| Factory image | RT-Thread 5.1.0 demo; on this board it hard-faulted right after starting the LCD (no display attached) - backed up before the first flash | 2026-10-31 |
| RGB LED | R = P013, B = P012, G = P613, low = on | red blinks (owner, 2026-10-31) |
| KEY | P110, MCU pull-up, low = pressed | vendor docs (interactive test not run yet) |
| Interfaces | 40-pin Raspberry Pi header, MIPI DSI/CSI, CEU camera, RGB LCD, 2 Ethernet, 4 CAN, 2 RS485, 3 UART, USBHS/USBFS, SD card, OSPI flash + HyperRAM, Wi-Fi (CYW43438 on SDHI1), IST8310, BMI088 | vendor docs |
