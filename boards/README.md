# Supported boards

Each board folder has a README with the tools to install, the commands of its skill(s), the bring-up
demos, the hardware sheet (pins, console, quirks) and one profile per skill (`<skill>/board.env` +
a dated verification log). Machine-readable: [index.json](index.json).

## Boards and on-board I/O

| Board | MCU | Skill | Console (UART) | LED1 | BTN1 |
| --- | --- | --- | --- | --- | --- |
| [RT-Thread Edgi-Talk](edgi-talk/README.md) | Infineon PSOC Edge E84 (PSE846GPS2DBZC4A) | `modus-pdl-edgitalk` | KitProg3 USB-UART | LED1 (red) | SW2 |
| [ST NUCLEO-C562RE](nucleo-c562re/README.md) | ST STM32C5 (STM32C562RET6) | `cubemx2-hal2-stm32c562nucleo` | ST-LINK virtual COM port | LD1 (green) | B1 (USER) |
| [ST B-L475E-IOT01A (IoT node)](b-l475e-iot01a/README.md) | ST STM32L4 (STM32L475VGT6) | `cubemx-hal-stm32l475iot` | ST-LINK virtual COM port | LED2 (green) | B1 USER (blue) |
| [ST STM32N6570-DK](stm32n6570-dk/README.md) | ST STM32N6 (STM32N657X0H3Q) | `cubemx-hal-stm32n6570dk` | ST-LINK virtual COM port | LED1 (green) | USER1 |
| [ST STM32F407G-DISC1](stm32f407g-disc1/README.md) | ST STM32F4 (STM32F407VGT6) | `cubemx-hal-stm32f407disco` | SWO (no virtual COM port) | LD3 (orange) | B1 (blue) |
| [Raspberry Pi Pico 2 W](rpi-pico-2w/README.md) | Raspberry Pi RP2350 (RP2350A) | `pio-arduino-rpipico2w` | USB CDC | LED (on the Wi-Fi module) | BOOTSEL |
| [Espressif ESP32-S3-BOX (2021)](esp32-s3-box/README.md) | Espressif ESP32-S3 (ESP32-S3) | `pio-espidf-esp32s3box` | USB Serial/JTAG | LCD backlight | BOOT |
| [Espressif ESP32-S3-BOX (2021)](esp32-s3-box/README.md) | Espressif ESP32-S3 (ESP32-S3) | `pio-arduino-esp32s3box` | USB Serial/JTAG | LCD backlight | BOOT |
| [Arduino UNO R4 WiFi](uno-r4-wifi/README.md) | Renesas RA4M1 (R7FA4M1AB3CFM) | `pio-arduino-unor4wifi` | UART via the USB bridge | L (yellow) | none |
| [RT-Thread Vision Board](vision-board/README.md) | Renesas RA8D1 (R7FA8D1BH) | `scons-rtthread-visionboard` | ART-Link virtual COM port (msh) | blue LED (P102) | KEY0 |

## Bring-up demos

The same three templates in every skill, checked with the same test specs (`tests/*.json`):

| Demo | Proves | Needs |
| --- | --- | --- |
| `hello-world` | toolchain, clock, console: prints "hello, world" every 1 s | a console (UART, USB CDC, SWO) |
| `blink` | GPIO output: LED1 toggles every 0.5 s, reported as `BLINK led1=0\|1` | one LED |
| `push-to-light` | GPIO input + console commands: a button press toggles LED1 (`EVT` lines), `led`/`btn` commands | one button + one LED |

| Board | Skill | hello-world | blink | push-to-light |
| --- | --- | --- | --- | --- |
| [RT-Thread Edgi-Talk](edgi-talk/README.md) | `modus-pdl-edgitalk` | tested | built | interactive * |
| [ST NUCLEO-C562RE](nucleo-c562re/README.md) | `cubemx2-hal2-stm32c562nucleo` | tested | built | observed * |
| [ST B-L475E-IOT01A (IoT node)](b-l475e-iot01a/README.md) | `cubemx-hal-stm32l475iot` | unverified | built | observed * |
| [ST STM32N6570-DK](stm32n6570-dk/README.md) | `cubemx-hal-stm32n6570dk` | built | not built yet | built |
| [ST STM32F407G-DISC1](stm32f407g-disc1/README.md) | `cubemx-hal-stm32f407disco` | built | built | built |
| [Raspberry Pi Pico 2 W](rpi-pico-2w/README.md) | `pio-arduino-rpipico2w` | tested | built | observed * |
| [Espressif ESP32-S3-BOX (2021)](esp32-s3-box/README.md) | `pio-espidf-esp32s3box` | tested | built | observed * |
| [Espressif ESP32-S3-BOX (2021)](esp32-s3-box/README.md) | `pio-arduino-esp32s3box` | tested | built | observed * |
| [Arduino UNO R4 WiFi](uno-r4-wifi/README.md) | `pio-arduino-unor4wifi` | tested | built | observed * |
| [RT-Thread Vision Board](vision-board/README.md) | `scons-rtthread-visionboard` | tested | built | built |

Levels: unverified < built < flashed < tested (automatic test PASS) < interactive (a person pressed
a button) < observed (a person saw the LED). \* = verified under the earlier template name
`uart-btn-led` (renamed 2026-10-09, same code). The UNO R4 WiFi has no user button: its
push-to-light runs the console LED commands only.

## Add a board

Copy [_template](_template/README.md) to `boards/<id>/`, fill the hardware sheet and the skill
profile (`<skill>/board.env`), add the board to the skill's board layer, then run the demos. Your own
board in your own project: put the profile in `<project>/boards/<id>/<skill>/` - the skills look there
first.
