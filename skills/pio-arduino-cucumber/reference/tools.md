# Tools and versions (pio-arduino-cucumber)

| Tool | Pinned by | Version proven | Notes |
| --- | --- | --- | --- |
| PlatformIO Core | user install (pip / VS Code extension) | 6.2.0 | called by full path `~/.platformio/penv/Scripts/pio.exe` |
| Platform `espressif32` | board profile `PIO_PLATFORM` (exact registry version) | 6.12.0 | pins the packages below |
| arduino-esp32 | platform (`framework-arduinoespressif32`) | 2.0.17 (3.20017.241212) | prebuilt on ESP-IDF 4.4 |
| GCC | platform (`toolchain-xtensa-esp32s2`) | 8.4.0+2021r2-patch5 | |
| esptool | platform (`tool-esptoolpy`) | 4.9 (2.40900.x) | discover/backup/flash, run with PlatformIO's python |
| Adafruit MPU6050 / BMP280 / HTS221 | board profile `PIO_LIB_DEPS` | 2.2.6 / 2.6.8 / 0.1.5 | + Unified Sensor 1.1.13, BusIO 1.14.5, GFX 1.11.7, SSD1306 2.5.7 (MPU6050 dependencies) |
| PubSubClient | board profile `PIO_LIB_DEPS_NET` | 2.8 | iot-sensor only |

The platform pins packages with `~` ranges (patch updates possible): the build manifest records the
exact versions used, compare manifests after a reinstall.

## Paths

| Path | Rule | Why |
| --- | --- | --- |
| workspace / app | no spaces, English characters only, ≤100 characters | Windows 260-char limit deep in `.pio/`; some tools break on spaces |
| `~/.platformio` | ≤60 characters, no spaces | toolchains and the framework live there |
| cloud-synced folder | allowed (WARN) | pause sync if a build hits locked files |

## Troubleshooting

| Symptom | Cause / fix |
| --- | --- |
| no USB serial port | the cable is on the native-USB micro-USB port (GPIO19/20) or charge-only - use the UART port next to the TX/RX LEDs; Windows may need the bridge's driver (developer installs it) |
| esptool cannot connect | the auto-reset needs DTR/RTS: close serial monitors; else hold BOOT, press EN, release BOOT, re-run |
| `Serial` shows only after a delay | opening the port pulsed DTR/RTS and restarted the sketch: tests sync with `info`, the banner may be missed - that is fine |
| `I2C n=0` / `imu=0 baro=0 hum=0` | a Cucumber without sensors (R/M/RI/MI), or I2C on the wrong pins (must be 41/40, not the variant's 8/9) |
| `EVT mqtt=failed state=-2` | broker unreachable (TCP); `state=5` = not authorised (this demo has no user/password) |
