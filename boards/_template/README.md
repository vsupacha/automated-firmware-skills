# <Board name>

Tool-independent hardware sheet. Copy `boards/_template/` to `boards/<id>/` (lowercase, hyphens),
fill this file, then add one profile subfolder per skill that supports the board
(`<skill>/`, e.g. `modus-pdl-edgitalk/` - see its README for the steps).

| Profile | Skill | Status |
| --- | --- | --- |
| [modus-pdl-edgitalk/](modus-pdl-edgitalk/README.md) | `skills/modus-pdl-edgitalk` | not verified |
| cubemx2-hal2-stm32c562nucleo/ | `skills/cubemx2-hal2-stm32c562nucleo` (STM32C5 boards) | not verified |
| pio-arduino-rpipico2w/ | `skills/pio-arduino-rpipico2w` (RP2350 boards) | not verified |

Sources: schematic, vendor manual, BSP (links).

"Verified" = seen on hardware, with a dated line in a profile README's verification log.
Mark everything else "vendor docs" or "UNVERIFIED". Never put a probe serial, COM port or user path here.

## MCU and debug

| Item | Value | Verified |
| --- | --- | --- |
| MCU | MPN, package, security category | |
| Debug | connector, on-board probe type, USB VID:PID | |
| Console | UART instance, RX/TX pins, where it goes (probe USB-UART / header), baud | |
| Clocks | crystal frequencies, external clocks | |
| Supply | I/O voltage, VTarget | |

## User I/O

| Silkscreen | Pin | Active level | Verified |
| --- | --- | --- | --- |
| LED1 | | | |
| SW1 | | | |

## On-board parts

| Part | Function | Bus / pins / address | Verified |
| --- | --- | --- | --- |
| e.g. LCD | size, resolution, interface, controller | | |
| e.g. microphone | PDM / I2S | | |
| e.g. sensor | | I2C @ 0x.. | |

## Connectors

| Connector | Signals | Notes |
| --- | --- | --- |

## Hardware quirks

- Shared pins, unpopulated parts, jumpers/switches that must be set, things that break boot.
