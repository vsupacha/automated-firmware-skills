# Arduino UNO R4 WiFi (ABX00087)

UNO-form-factor board with a Renesas RA4M1 (the target MCU) and an ESP32-S3-MINI-1 module that is
the USB bridge, the RA4M1 programmer and the WiFi/BLE radio. Tool-independent hardware sheet.

| Profile | Skill | Status |
| --- | --- | --- |
| [pio-arduino-unor4wifi/](pio-arduino-unor4wifi/README.md) | `skills/pio-arduino-unor4wifi` (PlatformIO + Arduino UNO R4 core) | verified on hardware (LED L seen) |

Sources: Arduino UNO R4 WiFi datasheet and schematics (docs.arduino.cc), the Arduino UNO R4 core
1.4.1 variant `UNOWIFIR4` (`pins_arduino.h`, `variant.cpp`), PlatformIO `renesas-ra` 1.7.0 board
`uno_r4_wifi`.

"Verified" = seen on hardware with a dated log line in a profile README. "Vendor docs" = taken from
Arduino's documentation or the core, not yet checked by us on this board.

## MCU and USB

| Item | Value | Verified |
| --- | --- | --- |
| MCU | Renesas RA4M1 R7FA4M1AB3CFM, Arm Cortex-M4F 48 MHz, 256 KB flash, 32 KB SRAM, 8 KB data flash | vendor docs (not readable over USB - see Identity) |
| USB | USB-C to the ESP32-S3 bridge: `2341:1002`, one CDC COM port; the USB serial number is the bridge's | `2341:1002` seen 2026-10-08 |
| Console | `Serial` = RA4M1 UART to the ESP32-S3, bridged to the USB CDC port; baud rate set by the sketch (115200) | yes (2026-10-08, hello-world test) |
| Upload | 1200 baud open of the COM port: the bridge resets the RA4M1 into its loader and emulates a SAM-BA loader on the same port; `bossac --erase --write --reset` writes the sketch from 0x4000 | yes (2026-10-08) |
| Read-back | **not supported** by the bridge's loader: `bossac --verify` fails ("SAM-BA operation failed") and skips the reset | yes (2026-10-08) |
| Debug | 10-pin SWD header for the RA4M1 (external probe: CMSIS-DAP, J-Link) | vendor docs, not used |

## Identity

`bossac --info` after a 1200 baud touch reports what the bridge emulates, the same on every board:
"Arduino Bootloader (SAM-BA extended) 2.0 [Arduino:IKXYZ]", device `nRF52840-QIAA` (a placeholder,
not the RA4M1), 256 pages of 4096 bytes, security false, nothing locked (read 2026-10-08). The
RA4M1's own id is only readable over SWD; the sketch's INFO line (`board=uno-r4-wifi`) confirms the
target after flashing.

## User I/O

| Silkscreen / name | Pin | Active level | Notes | Verified |
| --- | --- | --- | --- | --- |
| **L** LED (yellow) | D13 = P102 (`LED_BUILTIN`) | high = on | **LED1** of the skill's board layer; shares D13 (SPI SCK) | yes (2026-10-09, on/off seen by the user) |
| RESET button | RA4M1 reset | - | double-press enters the loader (Arduino) | - |
| User buttons | none | - | the templates' button steps are skipped (`btns=0`) | yes (board has none) |
| 12x8 LED matrix | charlieplexed on P003/P004/P011/P012/P013/P015/P204/P205/P206/P212/P213 | - | `Arduino_LED_Matrix` library; not used by the M1 templates | vendor docs |
| TX / RX LEDs | driven by the bridge | - | not software controlled from the RA4M1 | vendor docs |

## On-board parts (not used by the M1 templates)

| Part | Connection | Notes |
| --- | --- | --- |
| ESP32-S3-MINI-1 | RA4M1 UART (`Serial2`/`SerialNina` in the core) + the USB bridge role | WiFi/BLE through the `WiFiS3` library; its firmware is Arduino's - never flash it from this skill |
| Qwiic connector | I2C1 (`Wire1`), 3.3 V | |
| Headers | UNO R3 layout, 5 V I/O on the RA4M1 pins | |
