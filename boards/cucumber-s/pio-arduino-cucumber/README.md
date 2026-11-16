# Gravitech Cucumber S - pio-arduino-cucumber profile

Board profile of the `pio-arduino-cucumber` skill: `board.env` (pinned platform, PlatformIO board,
define, labels, driver libraries, I2C pins/addresses, expected identity). Hardware:
[../README.md](../README.md).

| Item | Value |
| --- | --- |
| PlatformIO platform | `platformio/espressif32@6.12.0` (registry, exact version) |
| Framework | arduino-esp32 2.0.17 (`framework-arduinoespressif32` 3.20017.241212), GCC 8.4.0 (`toolchain-xtensa-esp32s2`) |
| Board id / env | `esp32-s2-saola-1` (as the LE380 POC; 4 MB flash, `Serial` = UART0) / `cucumber_s` |
| Libraries (`PIO_LIB_DEPS`) | Adafruit MPU6050 2.2.6, BMP280 Library 2.6.8, HTS221 0.1.5, Unified Sensor 1.1.13, BusIO 1.14.5, GFX 1.11.7, SSD1306 2.5.7 |
| Network library (`PIO_LIB_DEPS_NET`, iot-sensor) | PubSubClient 2.8 |
| Console | `Serial` = UART0 (GPIO43/44) via the USB-UART bridge, 115200 8N1 |
| Identity | esptool: chip ESP32-S2, flash 4MB, secure boot / flash encryption off; bench file keeps the MAC (flash gate) |
| Flash map | bootloader 0x1000 (ESP32-S2), partitions 0x8000, `boot_app0.bin` 0xe000, sketch 0x10000 - from `pio project metadata` |

## Verification log

- 2026-11-14 skill `pio-arduino-cucumber` created (owner's choices: skill name, board id
  `cucumber-s`, Arduino + Adafruit libraries in the board layer, sensors MPU6050 / BMP280 / HTS221 +
  RGB LED, IoT demo with Wi-Fi/MQTT). Facts from the LE380 POC (board `esp32-s2-saola-1`,
  `Wire.begin(41,40,100000)`, BMP280 at 0x76, LED on GPIO2 driven HIGH = on) and Gravitech's
  cucumber-library (I2C GPIO41/40, MPU6050 0x68, HTS221 0x5F, pinout image). The POC's MPU6050 2.2.4
  and BusIO 1.14.3 are not in the PlatformIO registry: pinned 2.2.6 / 1.14.5 instead.
  - Built on portable (PlatformIO 6.2, Windows 10 + Git Bash), every template **BUILD: PASS, 0
    warnings in src/**: hello-world firmware.bin `987147a8...`, blink `4f58e287...`, push-to-light
    `f4609c4c...`, iot-sensor `a5cfea72...` (RAM 12.6 %, flash 58.4 % of the 1.25 MB app slot).
  - Unit-test image of the iot-sensor app (`unit_test.sh --build-only`, env `cucumber_s_unit`: func/
    incl. `sensors.cpp` linked against the test stub): **UNIT-BUILD: PASS**, firmware.bin `bdfd1b26...`.
  - Owner's Build in PlatformIO IDE failed: the IDE builds every env and `cucumber_s_unit` links only
    under `pio test` (undefined `setup()`/`loop()`). new_app.sh now writes `[platformio]
    default_envs = cucumber_s`; the IDE's `pio run` then builds the app only (SUCCESS), unit image
    unchanged (`bdfd1b26...`).
  - Not done: no board connected - discover, flash and every test (incl. the per-peripheral specs)
    not run; USB-UART bridge chip (VID/PID) and RGB LED type not seen on hardware.
