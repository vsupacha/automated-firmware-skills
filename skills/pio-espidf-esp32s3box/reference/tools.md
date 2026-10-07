# Tools and versions (pio-espidf-esp32s3box)

| Tool | Pinned by | Version proven | Notes |
| --- | --- | --- | --- |
| PlatformIO Core | user install (pip / VS Code extension) | 6.2.0 | called by full path `~/.platformio/penv/Scripts/pio.exe` |
| Platform `espressif32` | board profile `PIO_PLATFORM` (exact registry version) | 6.12.0 | pins the packages below |
| ESP-IDF | platform (`framework-espidf`) | 5.5.0 (3.50500.0) | own python env under `~/.platformio/penv/.espidf-*` created by the first build |
| GCC | platform (`toolchain-xtensa-esp-elf`) | 14.2.0+20241119 | `toolchain-xtensa-esp32s3` (GCC 8.4) is the Arduino-2.x toolchain, not used here |
| esptool | platform (`tool-esptoolpy`) | 4.9 (2.40900.x) | M3 flash/identity |
| CMake / ninja | platform (`tool-cmake`, `tool-ninja`) | 3.30.2 / 1.9.0 | |

The platform pins packages with `~` ranges (patch updates possible): the build manifest records the
exact versions used, compare manifests after a reinstall.

## Paths

| Path | Rule | Why |
| --- | --- | --- |
| workspace / app | no spaces, English characters only, ≤100 characters | ESP-IDF CMake + ninja + python env; Windows 260-char limit deep in `.pio/build/<env>/esp-idf/...` |
| `~/.platformio` | ≤60 characters, no spaces | the toolchains and ESP-IDF live there |
| cloud-synced folder | allowed (WARN) | pause sync if a build hits locked files |

## Troubleshooting

| Symptom | Cause / fix |
| --- | --- |
| `sdkconfig.defaults` change has no effect | `sdkconfig.<env>` already exists: delete it (or `clean.sh`), rebuild |
| task watchdog messages on the console | a loop that never yields - `board_delay_ms(1)` per superloop pass |
| nothing on the console | the app did not call `board_init()`, or the console option in `sdkconfig.defaults` was changed |
