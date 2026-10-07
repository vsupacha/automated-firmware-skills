# ST B-L475E-IOT01A (Discovery kit IoT node)

STM32L475VGT6 (Cortex-M4F, 80 MHz, 1 MB flash, 128 KB RAM) with an on-board ST-LINK/V2-1 and
many sensors. Tool-independent hardware sheet.

| Profile | Skill | Status |
| --- | --- | --- |
| [cubemx-hal-stm32l475iot/](cubemx-hal-stm32l475iot/README.md) | `skills/cubemx-hal-stm32l475iot` (STM32CubeMX 6.18 + STM32CubeL4 HAL + CMake) | M1 + M3 verified on hardware (uart-btn-led: tests 13/13, interactive 5/5, LED2 seen) |

Sources: STM32CubeMX 6.18.1 board configurations `D42_Discovery_B-L475E-IOT01A1_STM32L475V_Board.ioc`
and `D57_..._B-L475E-IOT01A2_...` (identical apart from the board name); STM32CubeL4 V1.18.2 BSP
`Drivers/BSP/B-L475E-IOT01`.

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
