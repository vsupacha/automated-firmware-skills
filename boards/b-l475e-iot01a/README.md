# ST B-L475E-IOT01A (Discovery kit IoT node)

STM32L475VGT6 (Cortex-M4F, 80 MHz, 1 MB flash, 128 KB RAM) with an on-board ST-LINK/V2-1 and
many sensors. Tool-independent hardware sheet.

| Profile | Skill | Status |
| --- | --- | --- |
| [cubemx-hal-stm32l475iot/](cubemx-hal-stm32l475iot/README.md) | `skills/cubemx-hal-stm32l475iot` (STM32CubeMX 6.18 + STM32CubeL4 HAL + CMake) | M1 verified on hardware (uart-btn-led: tests 13/13, interactive 5/5, LED2 seen) |

## Bring-up demos

| Demo | Uses | `cubemx-hal-stm32l475iot` |
| --- | --- | --- |
| hello-world | console: ST-LINK virtual COM port | unverified |
| blink | LED1 = LED2 (green) | built |
| push-to-light | BTN1 = B1 USER (blue) toggles LED1 | observed * |

Levels: built < flashed < tested (automatic test PASS) < interactive (a person pressed a
button) < observed (a person saw the LED). \* = verified under its earlier name `uart-btn-led`
(renamed 2026-10-09, same code). Dated evidence: the profile README of each skill.

## Required tools

- Windows with Git for Windows (Git Bash); Python 3 with pyserial (hardware stages).
- STM32CubeMX 6.18.1 (installed for all users or per user - both are found) with the
  STM32Cube_FW_L4 V1.18.2 package, and the STM32Cube bundles GNU Tools for STM32 14.3.1+st.2,
  CMake 4.4.0+st.1, Ninja 1.13.2+st.1, STM32CubeProgrammer 2.23.0.
- Workspace path without spaces, ≤100 characters.

## Commands

```bash
S=skills/cubemx-hal-stm32l475iot/scripts
```

| Stage | Command | Gate |
| --- | --- | --- |
| 0 help | `bash $S/help.sh [--en]` | - |
| 1 setup | `bash $S/check_tools.sh <board> [--ws <workspace>]` | `missing/bad=0` |
| 4 connect | `bash $S/discover.sh <board> [--serial <stlink-serial>]` | `IDENTITY: PASS` |
| 2 create | `bash $S/new_app.sh <board> <app> [<workspace>\|""] [template] [--no-open]` | `REGEN: PASS`, `Created ...` |
| 2 regenerate (after a .ioc change) | `bash $S/regen.sh apps/<app>` | `REGEN: PASS` |
| 2d open in IDE (run by new_app) | `bash $S/open_ide.sh apps/<app> [--no-open]` - VS Code + the toolchain extension, on the same project as the scripts | `IDE: READY` |
| 3 build | `bash $S/build.sh apps/<app> [--clean] [--allow-warnings]` | `BUILD: PASS` |
| 5 flash | `bash $S/flash.sh apps/<app> --yes [--elf <file.elf>]` | `FLASH: PASS` |
| 6 test | `python $S/serial_test.py auto apps/<app>/tests/<spec>.json apps/<app>/logs/test.log --board <board> [--interactive]` | `RESULT: PASS` |
| 16 clean | `bash $S/clean.sh [--apps] [--yes]` | `CLEAN: done` |

Board: `b-l475e-iot01a`. Templates: `hello-world`, `blink`, `push-to-light` (B1 USER toggles LED2). The
`.ioc` starts from the CubeMX board configuration (`loadboard B-L475E-IOT01A1`) plus USART1 on the
ST-LINK virtual COM port; the console receives by interrupt (the L4 USART has no RX FIFO).

Example - B1 toggles LED2 on a B-L475E-IOT01A:

```bash
S=skills/cubemx-hal-stm32l475iot/scripts
bash $S/check_tools.sh b-l475e-iot01a
bash $S/discover.sh b-l475e-iot01a
bash $S/new_app.sh b-l475e-iot01a btn-led "" push-to-light
bash $S/build.sh apps/btn-led
bash $S/flash.sh apps/btn-led --yes
python $S/serial_test.py auto apps/btn-led/tests/push_to_light.json apps/btn-led/logs/test.log --board b-l475e-iot01a --interactive
```

Run from the repo root in Git Bash. Exit code 10 = do what the `ACTION:` line says, then
re-run; common options: [docs/workflow.md](../../docs/workflow.md#common-options).

## Hardware

Sources: STM32CubeMX 6.18.1 board configurations `D42_Discovery_B-L475E-IOT01A1_STM32L475V_Board.ioc`
and `D57_..._B-L475E-IOT01A2_...` (identical apart from the board name); STM32CubeL4 V1.18.2 BSP
`Drivers/BSP/B-L475E-IOT01`. Board user manual: ST UM2153 "Discovery kit for IoT node,
multichannel communication with STM32L4"
(<https://www.st.com/resource/en/user_manual/um2153-discovery-kit-for-iot-node-multichannel-communication-with-stm32l4-stmicroelectronics.pdf>)
- vendor documents are linked, not copied into the repo.

"Verified" = seen on hardware with a dated log line in a profile README. "BSP" / "CubeMX board" =
taken from ST's files, not yet checked by us on this board.

## MCU and debug

| Item | Value | Verified |
| --- | --- | --- |
| MCU | STM32L475VGTx, LQFP100; STM32CubeProgrammer: device `STM32L4x1/STM32L475xx/STM32L476xx/STM32L486xx`, ID **0x415**, VTarget 3.23 V | yes (2026-10-08, hot-plug connect) |
| Debug | on-board **ST-LINK/V2-1** (USB `0483:374B`, FW V2J46M32 seen), SWD; reports board name `STM32L4IO` | yes (2026-10-08) |
| Console | **virtual COM port**: USART1 PB6 TX / PB7 RX → ST-LINK, 115200 8N1. The USART has **no RX FIFO**: receive by interrupt (polling while echoing drops bytes) | yes (2026-10-08, serial tests) |
| Clocks | board default SYSCLK 80 MHz (MSI + PLL); HSE not used by default | CubeMX board |

## User I/O

| Silkscreen | Pin | Active level | Verified |
| --- | --- | --- | --- |
| LED2 (green) | PB14 | high | yes (2026-10-08: driven by the console, seen lit by a person) |
| LED1 (green) | PA5 | high | not used: PA5 is Arduino D13 / SPI1_SCK in the board configuration |
| LED3 / LED4 (Wi-Fi / BLE, yellow / blue) | PC9 | - | CubeMX board label; driven by the radio modules |
| B1 USER (blue) | PC13 | low (pull-up) | yes (2026-10-08: pressed by a person, EVT btn1 seen); CubeMX labels the pin `[B2]` |
| B2 RESET (black) | NRST | - | - |

## On-board parts (from the board configuration labels; none used by the skill yet)

HTS221 humidity/temperature, LPS22HB pressure, LSM6DSL accelerometer/gyroscope, LIS3MDL
magnetometer, VL53L0X time-of-flight (internal I2C2 PB10/PB11), 2 × MP34DT01 microphones (DFSDM),
ISM43362 Wi-Fi (SPI3), SPBTLE-RF Bluetooth LE, SPSGRF sub-GHz radio, M24SR NFC tag,
MX25R6435F 64 Mbit QSPI flash, USB OTG FS, Arduino Uno V3 and PMOD connectors.
