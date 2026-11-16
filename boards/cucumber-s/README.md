# Gravitech Cucumber S (RS / RIS / MS / MIS)

ESP32-S2 development board by Gravitech (Thailand) with an ESP32-S2-WROVER(-I) module, 4 MB flash
(R series: + 2 MB PSRAM), a blue user LED, an RGB LED and - on the **S** variants only - three
onboard sensors on one I2C bus. Tool-independent hardware sheet. Cucumber R / M / RI / MI (no
sensors) are the same board without the sensor chips: the sensor tests fail there by design.

| Profile | Skill | Status |
| --- | --- | --- |
| [pio-arduino-cucumber/](pio-arduino-cucumber/README.md) | [`skills/pio-arduino-cucumber`](../../skills/pio-arduino-cucumber/README.md) ([ไทย](../../skills/pio-arduino-cucumber/README_TH.md)) (PlatformIO + Arduino) | built only (not run on a board yet) |

## Bring-up demos

| Demo | Uses | `pio-arduino-cucumber` |
| --- | --- | --- |
| hello-world | console: UART0 via the USB-UART bridge | built |
| blink | LED1 = blue LED GPIO2 | built |
| push-to-light | BTN1 = BOOT toggles LED1 | built |
| iot-sensor | MPU6050 + BMP280 + HTS221 + RGB LED, Wi-Fi/MQTT | built |

Levels: built < flashed < tested (automatic test PASS) < interactive (a person pressed a button) <
observed (a person saw the LED). Dated evidence: the profile README.

## Hardware

| Item | Value | Source |
| --- | --- | --- |
| Module | ESP32-S2-WROVER (R/RS/M/MS) or -WROVER-I (RI/RIS/MI/MIS), 4 MB flash; R series 2 MB PSRAM | cucumber-library README |
| Console | UART0 TX GPIO43 / RX GPIO44 through the on-board USB-UART bridge (micro-USB next to the TX/RX LEDs); DTR/RTS auto-reset to EN/GPIO0 | pinout (U0TX/U0RX), POC (`Serial`, esptool upload) |
| Native USB | second micro-USB = ESP32-S2 USB OTG, GPIO19 (D-) / GPIO20 (D+) - not used by the templates | pinout |
| User LED | GPIO2 ("LED Builtin"), active high | pinout, POC (`digitalWrite(2, HIGH)` = on) |
| RGB LED | GPIO18, one addressable pixel (WS2812-type, as on the Espressif Saola-1) - **UNVERIFIED** type | pinout ("RGB LED") |
| Buttons | BOOT = GPIO0 (active low, held at reset = download mode), EN = reset | pinout |
| I2C (sensors) | SDA GPIO41, SCL GPIO40 | pinout (I2C0-SDA/SCL), cucumber-library (`GPIO_NUM_41/40`), POC (`Wire.begin(41,40,100000)`) |
| HTS221 humidity + temperature | 0x5F, WHO_AM_I 0xBC | pinout, cucumber-library |
| MPU6050 accel + gyro | 0x68 (AD0 low), WHO_AM_I 0x68 | pinout, cucumber-library |
| BMP280 pressure + temperature | 0x76, chip id 0x58 | pinout, cucumber-library, POC |
| Pins marked "not recommended" (* / **) on the pinout | GPIO0, GPIO2, GPIO18, GPIO26 (flash CS), GPIO45, GPIO46 (strapping or used on board) | pinout |

Notes:
- The arduino-esp32 variant of the PlatformIO board `esp32-s2-saola-1` defines `SDA`=8, `SCL`=9 and
  `LED_BUILTIN` = the RGB pixel: none of them is right for the Cucumber, so the board layer names its
  own pins (I2C 41/40, LED 2, RGB 18).
- Sources: Gravitech pinout and cucumber-library (github.com/gravitech-engineer/cucumber-library), and
  the owner's LE380 proof of concept (PlatformIO, `esp32-s2-saola-1`, Arduino, Adafruit libraries).

## Required tools

### pio-arduino-cucumber

- PlatformIO Core 6.2, Git, Python 3. The first build installs espressif32 6.12.0 +
  arduino-esp32 2.0.17 (GCC 8.4, `toolchain-xtensa-esp32s2`) and fetches the pinned libraries
  (Adafruit MPU6050 2.2.6, BMP280 2.6.8, HTS221 0.1.5 + dependencies; PubSubClient 2.8 for
  iot-sensor). Discover/flash/test use PlatformIO's own python (pyserial + esptool come with it).
- The USB-UART bridge's Windows driver (developer installs it if Windows does not).
- Workspace path without spaces, ≤100 characters.

## Commands

### pio-arduino-cucumber

```bash
S=skills/pio-arduino-cucumber/scripts
```

| Stage | Command | Gate |
| --- | --- | --- |
| 0 help | `bash $S/help.sh [--en]` | - |
| 1 setup | `bash $S/check_tools.sh <board> [--ws <workspace>]` | `missing/bad=0` |
| 4 connect | `bash $S/discover.sh <board> [--port <port>]` | `IDENTITY: PASS` |
| 2 create | `bash $S/new_app.sh <board> <app> [<workspace>\|""] [template]` | `Created ...` |
| 2d open in IDE (run by new_app) | `bash $S/open_ide.sh <app> [--no-open]` | `IDE: READY` |
| 3 build | `bash $S/build.sh <app> [--clean] [--allow-warnings]` | `BUILD: PASS` |
| 5 backup (optional) | `bash $S/backup.sh <board>` | `BACKUP: PASS` |
| 5 flash | `bash $S/flash.sh <app> --yes` | `FLASH: PASS` |
| 6 test | `~/.platformio/penv/Scripts/python $S/serial_test.py auto <app>/tests/<spec>.json <app>/logs/test.log --board <board> [--interactive]` | `RESULT: PASS` |
| 6 unit tests | `bash $S/unit_test.sh <app> [--yes] [--build-only \| --read-only]` | `UNIT: PASS` |
| 16 clean | `bash $S/clean.sh [--apps] [--yes]` | `CLEAN: done` |

Per-peripheral specs of an iot-sensor app: `tests/i2c_bus.json`, `mpu6050.json`, `bmp280.json`,
`hts221.json`, `rgb_led.json`, `iot_sensor.json`.
