# Raspberry Pi Pico 2 W

RP2350 board with a CYW43439 Wi-Fi/Bluetooth module. Tool-independent hardware sheet.

| Profile | Skill | Status |
| --- | --- | --- |
| [pio-rpi-pico-2w/](pio-rpi-pico-2w/README.md) | `skills/pio-rpi-pico-2w` (PlatformIO + arduino-pico) | verified on hardware |

Sources: Raspberry Pi Pico 2 W datasheet and pinout (raspberrypi.com/documentation/microcontrollers);
arduino-pico core `variants/rpipico2w/pins_arduino.h`, `variants/generic/common.h`,
`cores/rp2040/wiring_analog.cpp` (surveyed 2026-09-22 in the PIO LINX toolkit, Pico 2 W port).

## MCU and USB

| Item | Value | Verified |
| --- | --- | --- |
| MCU | RP2350A (QFN60), rev A2, dual Cortex-M33 (or dual Hazard3 RISC-V), 150 MHz, 520 KB SRAM | yes (picotool: RP2350 A2 QFN60) |
| Flash | 4 MB QSPI | yes (picotool: 4096K) |
| USB | micro-USB, native RP2350 USB (no separate debug probe) | yes |
| USB IDs | BOOTSEL ROM: `2E8A:000F` (mass-storage drive `RP2350` + `RP2350 Boot` interface); arduino-pico sketch: `2E8A:F00F` CDC serial | yes |
| USB serial number | = chip ID (`picotool info` `chipid`), the same in BOOTSEL and in an arduino-pico sketch - unique per board | yes (2026-10-07) |
| Console | USB CDC of the sketch (no UART bridge); UART0 GP0/GP1 on the header if needed | USB CDC yes |
| Debug | 3-pin SWD header (SWCLK, GND, SWDIO) for an external probe | not used |
| Logic level | 3.3 V; ADC reference = 3V3 through an RC filter | vendor docs |

## User I/O

| Silkscreen | Pin | Active level | Verified |
| --- | --- | --- | --- |
| LED | on the CYW43439 module (WL_GPIO0) - **not an RP2350 GPIO**; arduino-pico `LED_BUILTIN` = 64 | high | yes (2026-10-07: driven by the sketch, seen lit by a human) |
| BOOTSEL | QSPI CS line; readable at run time (`BOOTSEL` in arduino-pico) - pressed at power-up = USB boot mode | pressed = 1 via `BOOTSEL` | yes (boot mode; run-time read + debounce 2026-10-07) |
| - | **no RESET button** | - | yes |

## Pins

| Pins | Use |
| --- | --- |
| GP0–GP22 | free GPIO on the header |
| GP26/27/28 | GPIO or ADC0/1/2 (12-bit hardware; arduino-pico `analogRead` defaults to 10 bits unless `analogReadResolution(12)`) |
| GP23, GP24, GP25, GP29 | **owned by the CYW43439** (WL_ON, SPI data, CS, SPI clock) - not on the header. GP29 is ADC3 on a non-W Pico 2: do not copy that map |
| ADC4 | internal temperature sensor (not a pin) |

## On-board parts

| Part | Function | Bus | Verified |
| --- | --- | --- | --- |
| CYW43439 | Wi-Fi 4 + Bluetooth 5.2, also drives the LED | PIO-SPI on GP23/24/25/29 | LED only |

## Hardware quirks

- A blank board (or one whose image does not start) comes up in BOOTSEL mode by itself.
- No reset button: to force BOOTSEL, unplug, hold BOOTSEL, plug in, release.
- Reading `BOOTSEL` at run time briefly disables flash (XIP) - poll it, don't read it from ISRs.
