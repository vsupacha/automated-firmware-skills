# ST NUCLEO-C562RE

Nucleo-64 board (MB2213) with an STM32C562RET6. Tool-independent hardware sheet.

| Profile | Skill | Status |
| --- | --- | --- |
| [cubemx-stm32c5/](cubemx-stm32c5/README.md) | `skills/cubemx-stm32c5` (STM32CubeMX2 + CMake + STM32CubeProgrammer) | verified on hardware |

Sources: STM32CubeMX2 board pack `STMicroelectronics/nucleo-c562re_hw-board` 2.1.0 (BOM, netlist,
part parameters, read 2026-10-07); the board-default project of STM32CubeMX2 1.1.1; the earlier
CubeMX2 SCPI toolkit (`.ioc2` of 2026-09, hardware-tested UART ping/pong).

"Verified" = seen on hardware with a dated log line in a profile README. "Board pack" = taken from
ST's machine-readable board description, not yet checked by us on this board.

## MCU and debug

| Item | Value | Verified |
| --- | --- | --- |
| MCU | STM32C562RET6, Arm Cortex-M33, up to 144 MHz, LQFP64 (programmer: device "STM32C5x", ID 0x44E, rev Y, 512 KB) | yes (2026-10-07) |
| Clocks | HSE 24 MHz crystal (X3, NX2016SA), LSE 32.768 kHz (X2), HSI 144 MHz | board pack |
| Debug | on-board STLINK-V3EC (U13): SWD (PA13 SWDIO, PA14 SWCLK, PB3 SWO); reports board name "NUCLEO-C562RE" | yes (2026-10-07) |
| Console | USART2 TX PA2 / RX PA3 (AF7) → STLINK-V3EC virtual COM port, USB `0483:3754`; the VCP USB serial = the ST-LINK serial | yes (2026-10-07) |

## User I/O

| Silkscreen | Pin | Active level | Verified |
| --- | --- | --- | --- |
| LD1 (green, user) | PA5 (via transistor Q1, solder bridge SB8) | high | yes (2026-10-07: driven + read back, seen by a human) |
| B1 (USER, blue) | PC13, pull-down R13 | **high** when pressed | yes (2026-10-07: press/release events) |
| B2 | RESET (NRST) | - | - |

PA5 is also Arduino D13 (CN5-6 / CN10-11) - open SB8 to use D13 without the LED.

## On-board parts

| Part | Function | Notes |
| --- | --- | --- |
| STLINK-V3EC | SWD probe + virtual COM port + mass storage | firmware upgrades with STLinkUpgrade (user's decision) |
| X3 NX2016SA 24 MHz | HSE | |
| X2 32.768 kHz | LSE (RTC) | |

## Connectors

| Connector | Signals |
| --- | --- |
| CN7/CN10 | ST morpho headers (all MCU pins) |
| CN5/CN6/CN8/CN9 | Arduino Uno V3 headers |
| CN1 | USB-C to the STLINK-V3EC (power, debug, VCP) |

## Hardware quirks

- The board-default CubeMX2 project assigns PA2/PA3 to USART2 but leaves USART2 **disabled**; the
  skill enables it (Async) when it creates an app.
- No USART2 interrupt handler is generated in the default project: the skill's console polls the
  receive flag (LL driver) instead of using interrupt-driven HAL receive.
