# ST STM32F407G-DISC1 (STM32F4DISCOVERY)

Discovery kit with the STM32F407VGT6 (Cortex-M4F, 1 MB flash, 192 KB RAM), MB997. Tool-independent
hardware sheet.

| Profile | Skill | Status |
| --- | --- | --- |
| [cubemx-hal-stm32f407disco/](cubemx-hal-stm32f407disco/README.md) | `skills/cubemx-hal-stm32f407disco` (STM32CubeMX 6.18 + STM32CubeF4 HAL + CMake) | M1: generated + built, not run on hardware |

Sources: STM32CubeMX 6.18.1 board configuration `C47_Discovery_STM32F407G-DISC1_STM32F407VG_Board.ioc`;
STM32CubeF4 V1.28.3 BSP `Drivers/BSP/STM32F4-Discovery`.

"Verified" = seen on hardware with a dated log line in a profile README. "BSP" / "CubeMX board" =
taken from ST's files, not yet checked by us on this board.

## MCU and debug

| Item | Value | Verified |
| --- | --- | --- |
| MCU | STM32F407VGT6; STM32CubeProgrammer: device ID **0x413** (STM32F405/407/415/417), rev Z, Cortex-M4, VTarget 3.23 V | yes (2026-10-07, hot-plug connect) |
| Debug | on-board **ST-LINK/V2** (USB `0483:3748`, FW V2J46S0 seen), SWD; reports no board name | yes (2026-10-07) |
| Console | **no virtual COM port** (ST-LINK/V2); SWO PB3 → ST-LINK (printf via ITM/SWV) | CubeMX board (SWO label) |
| Clocks | HSE 8 MHz crystal; CubeMX board default SYSCLK 25 MHz (PLL M=8 N=50 P=4) | CubeMX board |
| USB OTG FS | micro-USB CN5: PA11/PA12, VBUS PA9, ID PA10 | CubeMX board |

## User I/O

| Silkscreen | Pin | Active level | Verified |
| --- | --- | --- | --- |
| LD3 (orange) | PD13 | high | BSP |
| LD4 (green) | PD12 | high | BSP |
| LD5 (red) | PD14 | high | BSP |
| LD6 (blue) | PD15 | high | BSP |
| B1 (blue, user) | PA0 (EXTI0), external pull-down | high = pressed | BSP |
| B2 (black) | NRST | - | - |

## Safety notes

- Never change option bytes / read-out protection or upgrade the ST-LINK firmware without asking.
