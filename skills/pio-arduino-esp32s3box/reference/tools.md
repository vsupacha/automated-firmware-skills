# Tools and versions (pio-arduino-esp32s3box)

| Tool | Pinned by | Version proven | Notes |
| --- | --- | --- | --- |
| PlatformIO Core | user install (pip / VS Code extension) | 6.2.0 | called by full path `~/.platformio/penv/Scripts/pio.exe` |
| Platform `espressif32` | board profile `PIO_PLATFORM` (exact registry version) | 6.12.0 | pins the packages below |
| arduino-esp32 | platform (`framework-arduinoespressif32`) | 2.0.17 (3.20017.241212) | prebuilt on ESP-IDF 4.4 |
| GCC | platform (`toolchain-xtensa-esp32s3`) | 8.4.0+2021r2-patch5 | the ESP-IDF skill uses GCC 14 instead |
| esptool | platform (`tool-esptoolpy`) | 4.9 (2.40900.x) | discover/backup/flash, run with PlatformIO's python |

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
| nothing on the USB console | `board_init()` not called first in `setup()` (it starts `Serial`); C `printf()` goes to UART0, not USB - print with `console_out()` |
| `Serial` shows only after a delay | the host opened the port late: tests sync with `info`, the banner may be missed - that is fine |
| port lost during an interactive test | the USB-C cable moved; the sketch keeps running (check `led?`), re-run the test |
