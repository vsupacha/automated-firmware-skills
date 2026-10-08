# Tools and versions (pio-arduino-unor4wifi)

| Tool | Pinned by | Version proven | Notes |
| --- | --- | --- | --- |
| PlatformIO Core | user install (pip / VS Code extension) | 6.2.0 | called by full path `~/.platformio/penv/Scripts/pio.exe` |
| Platform `renesas-ra` | board profile `PIO_PLATFORM` (exact registry version) | 1.7.0 | pins the packages below |
| Arduino UNO R4 core | platform (`framework-arduinorenesas-uno`) | 1.4.1 | variant `UNOWIFIR4`, FSP underneath; `Print` has no `printf` |
| GCC | platform (`toolchain-gccarmnoneeabi@1.70201.0`) | 7.2.1 | a newer generic `toolchain-gccarmnoneeabi` folder may exist - not used; profile `TOOLCHAIN_VERSION` |
| bossac | platform (`tool-bossac`) | 1.9.1 (1.10901.0) | discover/flash; talks to the ESP32-S3 bridge's emulated SAM-BA loader |

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
| nothing on the console after a flash | the RA4M1 stayed in the loader (an upload stopped before `--reset`, e.g. with `--verify`): re-run flash.sh, or press RESET once |
| `No device found on COMx` from bossac | the loader is not active: it needs a 1200 baud open of the port first (flash.sh/discover.sh do it) |
| `SAM-BA operation failed` at verify | the bridge's loader cannot read flash - never use `--verify` / `--read` on this board |
| `console_out().printf` does not compile | the Renesas core's `Print` has no `printf`: use `console_printf()` |
| port busy | a Serial Monitor (VS Code, Arduino IDE) holds the COM port - close it |
