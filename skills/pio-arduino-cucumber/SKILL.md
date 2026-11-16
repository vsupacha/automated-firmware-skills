---
name: pio-arduino-cucumber
description: Firmware workflow for the Gravitech Cucumber S (ESP32-S2-WROVER with onboard MPU6050, BMP280 and HTS221 sensors and an RGB LED) with PlatformIO and the Arduino framework (arduino-esp32) - check tools and folder paths, create a PlatformIO Arduino app from a layered template (board -> func -> setup/loop) whose board layer has one driver per onboard sensor, build it with a manifest of every image and its flash map, discover the board over its USB-UART bridge (chip, MAC, flash size, security state), flash with esptool behind identity gates and hash verification, and run automated serial tests per peripheral. Includes an IoT sensor demo (console + optional Wi-Fi/MQTT, credentials typed at run time). Use when asked to create, build, flash (แฟลช) or test Cucumber firmware (บอร์ด Cucumber, Gravitech, ESP32-S2, เซนเซอร์บนบอร์ด, IoT, MQTT), or how to use this skill (ขอวิธีใช้, help). Not for MicroPython, the Arduino IDE or Cucumber boards without sensors (R/M/RI/MI).
license: MIT
compatibility: Claude Code or another agent that runs bash; Windows 10/11 + Git Bash, Python 3 + pyserial; needs PlatformIO (arduino-esp32) and network for the first build (libraries); uses this repo's lib/ and boards/ (install the whole plugin or clone the repo)
---


# Gravitech Cucumber S firmware workflow (PlatformIO + Arduino)

Gated stages, the same contract as every skill in this repo (`docs/workflow.md`). Do them in order;
do not start a stage until the previous gate passed. Each stage has a script in `scripts/` and
details in `reference/`. Bash: Git Bash on Windows (Claude's Bash tool), or Linux/macOS.
Base: `pio-arduino-esp32s3box` (same Arduino-style func/ and scripts); this skill adds a **board layer
with one driver per onboard sensor** and an **IoT sensor demo**. Code is Arduino style throughout.

```
1 tools   ─► 2 project ─► 2e code ─► 3 build ─► 4 connect        ─► 5 flash ─► 6 test     ─► 16 clean
check_tools  new_app      src/board  build.sh   discover (esptool)  flash.sh   serial_test   clean.sh
                          (drivers)                                            (per sensor)
                          src/func
                          main.cpp
```

Stage numbers are the shared ones of `docs/workflow.md`; the section headings below use the same numbers.
Stage 4 (`discover.sh`, read-only) is needed before flash and test, not before create or build.

**Two paths after Stage 2** (`docs/workflow.md`): the developer may code in VS Code at any
time - the **IDE path** (`new_app.sh` already opened the app; `open_ide.sh <app>` reopens it; they
build, flash and debug with the vendor extension's buttons) - or let you run the stages - the
**script path** (build, layer checks, flash, tests behind their gates). Ask which one when it is
not clear. On the IDE path, stop after stage 2d and run scripts only when asked ("build it", "test
it"); never overwrite files the developer is editing. Both paths share the app folder and build
outputs, so switching is always possible: on the script path re-run the gates from Stage 3.

## Main path (script path)

<!-- main-path -->
The whole automated flow, in order, from the repository root. Board id `cucumber-s`; `<app>` is the
folder `new_app.sh` prints (in this PC's apps workspace). Other templates: replace `blink`.

```bash
S=skills/pio-arduino-cucumber/scripts
bash $S/check_tools.sh cucumber-s                         # 1 tools:   line with missing/bad=0
bash $S/new_app.sh cucumber-s my-app "" blink --no-open   # 2 create:  "Created <app>" (prints the app folder)
bash $S/build.sh <app>                                    # 3 build:   BUILD: PASS
bash $S/discover.sh cucumber-s                            # 4 connect: IDENTITY: PASS (read-only, needs the board)
bash $S/flash.sh <app>                                    # 5 flash:   stops with ACTION: APPROVE; after the developer's yes add --yes -> FLASH: PASS
python $S/serial_test.py auto <app>/tests/blink.json <app>/logs/test.log --board cucumber-s   # 6 test:    RESULT: PASS
```

A stage passed only when its gate line is printed. Exit code 10 with an `ACTION:` line means: stop,
relay it to the developer, and re-run the same command after they acted - never add `--yes` on
your own. The sections below explain these stages; IDE handoff, debug, unit tests, tool updates
and clean are optional.

## Milestones, stage numbers and developer actions

This skill implements the shared contract in `docs/workflow.md` (repo root):

| Milestone | Shared stage | In this file |
| --- | --- | --- |
| M1 bring-up | 1 setup, 2 create, 2d IDE, 3 build | Stage 1, Stage 2 step 2, Stage 3 |
| M1 bring-up (board) | 4 connect, 5 flash, 6 test, 7 debug *(planned)* | Stage 4 (discover), Stage 5 (+ backup), Stage 6 |
| M2 board support | 8 board drivers (sensor drivers in `templates/_common/src/board/`, per-peripheral specs), 9 layer check, 10 host test *(not for Arduino C++)* | Stage 2e (drivers, Arduino-style rules, `check_layers.py`) |
| M3 execution, M4 components, M5 application | 11 execution + trace, 12 components, 13 profile *(planned)* | - |
| - | 14 export *(planned)*, 15 port *(planned)* | Extending |
| - | 16 clean | Stage 16 |

**Exit codes:** 0 gate passed, 1 failed, 2 warnings, **10 = developer action needed**. On exit 10
the script's last line is `ACTION: <TYPE> <what to do>` (SETUP, CONNECT, APPROVE, CHOOSE ...):
tell the user exactly that, wait for their OK, then re-run the same command (with `--yes` /
`--serial` when the action says so). Never work around an ACTION yourself - installing tools,
changing system or git settings, plugging hardware and approving flashes or deletions are the
developer's.

**Release scope:** `<repo>/milestones.env` lists the active milestones (this release: **M1**).
M1 includes the board stages: discover, flash and serial tests run when the developer asks for
them, and **every flash needs the developer's yes first** (`flash.sh --yes` only after they said
yes in chat, or `FLASH_POLICY=auto` that they wrote into their own bench file). Scripts of an
inactive milestone (e.g. M2 `check_layers.py`) stop with `ACTION: SETUP ... not active`; never
edit `milestones.env` or set `FW_ACTIVE_MILESTONES` yourself - relay the ACTION like any other.

## Help menu (answer this first when asked how to use the skill)

When the user asks for help, usage or the list of commands ("ขอวิธีใช้หน่อย", "มีคำสั่งอะไรบ้าง",
"help"), run `bash "$SKILL/scripts/help.sh"` (Thai) or `help.sh --en` and show its output as-is.
Then offer the next step that fits (usually Stage 1). Do not run other stages.

`$SKILL` below = the folder containing this SKILL.md. Always quote: `bash "$SKILL/scripts/x.sh"`.
This skill is part of the automated-firmware-skills repo and needs the repo layout:

```
<repo>/skills/pio-arduino-cucumber/          this skill (SKILL.md, scripts/, reference/, templates/)
<repo>/boards/<id>/README.md                 board hardware (tool-independent)
<repo>/boards/<id>/pio-arduino-cucumber/     board profile: board.env, README (verification log)
<repo>/apps/                                 apps workspace only when this PC has none chosen
```

The apps workspace `$CUKE_WS`: the per-PC workspace (`~/.fw-skills.env`), else `<repo>/apps`. Board
profiles: `<project>/boards/<id>/pio-arduino-cucumber/` first, then `<repo>/boards` (override
`CUKE_BOARDS_DIR`). Overrides: `CUKE_WS`, `CUKE_BENCH_DIR`, `CUKE_USB_SERIAL`, `CUKE_CONSOLE`.

## What an app looks like

```
apps/<app>/
  platformio.ini        pinned platform (exact version), board, framework = arduino,
                        -DBOARD_<ID>, I2C pins, lib_deps (exact versions), -Wall -Wextra for src/
  src/board/            board layer: pins, Serial, pin I/O (board.h/.cpp) + one driver per device:
                        board_i2c (bus 41/40), board_imu (MPU6050), board_baro (BMP280),
                        board_hum (HTS221), board_rgb (GPIO18 pixel); iot-sensor adds
                        board_net (Wi-Fi + NVS settings), board_mqtt (PubSubClient)
  src/func/             services in Arduino C++: console (Stream/Print), led, button (millis());
                        iot-sensor adds sensors (snapshot, report lines, JSON payload)
  src/main.cpp          the sketch: setup() + loop()
  tests/<spec>.json     test contract (the same specs as the other skills)
  arduino-app.env       record: board, template, env, platform
  .pio/ logs/           build outputs and logs (git-ignored)
  <app>.code-workspace  VS Code workspace for PlatformIO IDE - open_ide.sh makes it (git-ignored)
```

## Board type vs bench instance

- **Board type** (`boards/<id>/`): `README.md` = hardware; `pio-arduino-cucumber/board.env` =
  pinned platform, PlatformIO board id (`esp32-s2-saola-1`, as the POC), `BOARD_DEFINE`, the drivers'
  libraries `PIO_LIB_DEPS` (+ `PIO_LIB_DEPS_NET` for iot-sensor), I2C pins and addresses,
  `BTN_LABELS`/`LED_LABELS`, expected identity.
- **Bench instance** (`<workspace>/.bench/<id>.env`, board stages): the USB-UART bridge's VID and USB
  serial, the COM port and the chip's **MAC** of one board on one PC. A bridge's USB serial is not
  the chip: flash.sh gates on the MAC. Never write a serial, MAC or COM port into `boards/`.

| id | board | status |
| --- | --- | --- |
| `cucumber-s` | Gravitech Cucumber RS/RIS/MS/MIS (ESP32-S2-WROVER, 4 MB flash, onboard sensors) | see `boards/cucumber-s/pio-arduino-cucumber/README.md` |

## Hardware quick reference

Use the **silkscreen name** with the user. Details: `boards/cucumber-s/README.md`.

| Board | Button | LED | Console |
| --- | --- | --- | --- |
| Cucumber S | **BOOT** GPIO0, active low (held at reset = download mode); **EN** = reset | LED1 = blue LED **GPIO2** (active high); **RGB LED GPIO18** (one pixel, `rgb` command) | `Serial` = UART0 (GPIO43/44) through the USB-UART bridge on the micro-USB port next to the TX/RX LEDs; the other micro-USB is the ESP32-S2's native USB (GPIO19/20, not used) |

| Device | Bus / address | Driver (board layer) | Test spec (iot-sensor) |
| --- | --- | --- | --- |
| I2C bus | SDA GPIO41, SCL GPIO40, 100 kHz | `board_i2c` | `tests/i2c_bus.json` (scan = 0x5F, 0x68, 0x76) |
| MPU6050 accel + gyro | 0x68 | `board_imu` (Adafruit MPU6050) | `tests/mpu6050.json` |
| BMP280 pressure + temp | 0x76 | `board_baro` (Adafruit BMP280) | `tests/bmp280.json` |
| HTS221 humidity + temp | 0x5F | `board_hum` (Adafruit HTS221) | `tests/hts221.json` |
| RGB LED | GPIO18 (WS2812-type, UNVERIFIED) | `board_rgb` (`neopixelWrite`) | `tests/rgb_led.json` |

## Stage 1 - Tools and folder paths

```bash
bash "$SKILL/scripts/check_tools.sh" <board-id> [--ws <workspace>]
```
Checks the workspace path (no spaces or non-ASCII, ≤100 characters), PlatformIO Core (called by
full path: `~/.platformio/penv/Scripts/pio.exe`; do not put penv on PATH), the pinned platform and
its packages (`framework-arduinoespressif32` 2.0.17, `toolchain-xtensa-esp32s2` GCC 8.4, esptool),
git + `core.longpaths` (Windows), python (+ pyserial, optional: tests use PlatformIO's python), and
lists USB serial ports. The libraries (`lib_deps`) are fetched by the first build (network). Read-only. **Gate:** `missing/bad=0`; report every WARN. Missing
PlatformIO: tell the user to install it - don't install it yourself. Changing git config is the
user's call - ask.

## Stage 2 - Create the project (and stage 4: discover the board)

1. **Discover:** `bash "$SKILL/scripts/discover.sh" <board-id> [--port <port>]`
   - lists USB serial ports (any VID unless the profile sets `USB_VID`), then esptool reads chip,
     features, MAC, flash size and the security state through the bridge. It writes nothing but the
     DTR/RTS auto-reset **restarts the chip** (the running firmware restarts) - say so.
   - **Gate:** `IDENTITY: PASS` (chip ESP32-S2, flash 4MB, secure boot and flash encryption
     disabled) + `Saved ...` (bench file: USB_VID, USB_SERIAL, CONSOLE_PORT, MAC). Several ports:
     `ACTION: CHOOSE` - ask which one, re-run with `--port`.
2. **Create the app:** `bash "$SKILL/scripts/new_app.sh" <board-id> <app-name> [<workspace>|""] [template] [--no-open]`
   - Example with a template and no IDE window (the empty `""` keeps this PC's workspace):
     `bash "$SKILL/scripts/new_app.sh" <board-id> my-app "" blink --no-open`
   - **Workspace (once per PC):** exit 10 `ACTION: CHOOSE` = no apps workspace chosen for this PC
     and `apps/` is in a synced folder or too long. Ask the developer (outside the synced folder,
     e.g. `C:/fw-ws` - recommended - or keep `apps/`), run `bash <repo>/lib/fw_workspace.sh set <dir>`,
     re-run `new_app.sh`; then use the app path it prints (`<workspace>/<app>`) in the later stages
     (docs/workflow.md "Apps workspace").
   - copies `templates/_common/src` (board + func layers) and the template's `src/` + `tests/`,
     writes `platformio.ini` and `arduino-app.env`. No network needed.
   - **Gate:** `Created ...`.
3. **Open in the IDE (stage 2d, automatic):** at the end, `new_app.sh` runs
   `bash "$SKILL/scripts/open_ide.sh" <app>` (`--no-open` on new_app/open_ide: no window). It writes
   `<app>.code-workspace` (the app folder, PlatformIO IDE recommended) and opens it in VS Code;
   PlatformIO IDE picks up `platformio.ini`. The developer can then Build (same env and
   `.pio/build/<env>` as build.sh), Upload, open the Serial Monitor and edit `src/` from the
   PlatformIO toolbar (PlatformIO IDE writes its own `.vscode/` - git-ignored). **Gate:**
   `IDE: READY <workspace>` + `IDE: OPENED` (`IDE: not opened` with `--no-open`); exit 10 `ACTION: SETUP` = VS Code or PlatformIO IDE is
   missing (new_app.sh only reports it). See docs/workflow.md "IDE handoff".

## Stage 2e - Code in layers

Read `reference/layering.md` before writing code. Rules:
Arduino style: every file includes `<Arduino.h>` and uses the Arduino API - `millis()`,
`Print`/`Stream` (`print`, `println`, `printf`), `pinMode`/`digitalWrite`/`digitalRead`, `HIGH`/`LOW`.
No ESP-IDF calls, no C stdio (`printf`, `stdout`) - output goes through `console_out()`.
- `src/board/` - **only** place for pin numbers, bus objects (`Wire`), sensor libraries (Adafruit
  classes), the console port (`Serial`, returned as a `Stream&` by `board_console()`), pin I/O calls,
  Wi-Fi/NVS/MQTT and `#if defined(BOARD_xxx)`. **One driver per device** (`board_<dev>.h/.cpp`): the
  header has plain C++ types only (`board_imu_t`, ...) and no library include, so func/ and the test
  stub never see a vendor class. A new sensor = a new `board_<dev>` pair + its test spec.
- `src/func/` - services (console, led, button) on the Arduino API + `board.h`; 1-based numbers
  like the silkscreen. No pins, no `Serial` directly.
- `src/main.cpp` - the sketch: `setup()` (init + banner) and `loop()` (poll the services); state is
  file-static. Print with `console_out().println(...)` / `.printf(...)` (`println` ends lines with
  CR LF). `loop()` must not block: no long `delay()`, time things with `millis()`.
- Keep the console protocol: `OK ...`, `ERR ...`, `EVT ...`, `<TAG> k=v ...`,
  `INFO ... board=<id> ...` then `READY` - tests depend on it.
- Templates: `hello-world` (1 s print), `blink` (LED1 every 0.5 s), `push-to-light` (console LED
  commands, BOOT toggles LED1, `EVT` lines), `iot-sensor` (see below). `help.sh` lists them from
  `description.txt`.
- Libraries: exact versions from the board profile (`PIO_LIB_DEPS`, written into `lib_deps` by
  new_app.sh; a template with a `needs-net` file also gets `PIO_LIB_DEPS_NET`); wrap anything that
  touches hardware in `board/`. Change versions in the profile, not only in one app.

**iot-sensor demo** - commands `i2c?`, `imu?`, `baro?`, `hum?`, `rgb <r> <g> <b>`/`rgb?`, `read`
(one `SENS ...` line), `json` (the MQTT payload), `period <ms>`, `stream on|off`, `led`, `btn?`,
`wifi set <ssid> <password>|join|off|forget`, `wifi?`, `mqtt set <host> [port]|off`, `mqtt?`,
`publish`. With stream on (default, 5 s) it prints a `SENS` line per period and, when MQTT is
connected, publishes JSON to `cucumber/<mac>/sensor`; `cucumber/<mac>/cmd` takes `{"led":1}` /
`{"rgb":[r,g,b]}`. **Credentials:** the developer types `wifi set ...` / `mqtt set ...` in a serial
monitor; they are stored in the chip's NVS, never in source, `platformio.ini`, test specs or git.
Never put an SSID, password or private broker into a file or a test spec, and do not type them for
the developer unless they give them to you for that purpose; the console echoes typed characters, so
`logs/` may contain them - keep logs in the app folder (git-ignored). MQTT is plain TCP without
authentication: suggest a test broker or one on their own network.

**Check the layers (M2 - gated, stops with `ACTION: SETUP` until enabled):**
`python <repo>/lib/check_layers.py <app-dir>` → `LAYERS: PASS` (`<Arduino.h>` is allowed in every
layer; pin I/O and `Serial` only in `board/`). `host_test.sh` does not cover this skill: it tests
the C `lib/func`, and this func/ is Arduino C++.

## Stage 3 - Build

```bash
bash "$SKILL/scripts/build.sh" <app-dir> [--clean] [--allow-warnings]
```
`pio run` with the app's env, log in `<app>/logs/` (about 1-3 min the first time per app: the
Adafruit libraries are fetched and compiled; later builds are incremental).
**Gate:** `BUILD: PASS` = pio exit 0, `firmware.bin`/`.elf`, `bootloader.bin`, `partitions.bin`
present, **0 warnings in `src/`** (C and C++; exit 2 = fix them). Use `--clean` for a full warning
check. `.pio/build/<env>/manifest.txt` (pio + platform version, every package, sizes, the flash map
PlatformIO would upload - bootloader 0x0, partitions 0x8000, `boot_app0.bin` 0xe000, sketch
0x10000 - and the sha256 of every image) is written **only on PASS**.

## Stage 5 - Flash

**Ask the user before every flash** (board, app, firmware.bin sha256 prefix): it replaces the
bootloader, partition table and app (NVS - saved Wi-Fi/MQTT settings - is kept). Offer a backup
first if the board holds firmware they care about:
```bash
bash "$SKILL/scripts/backup.sh" <board-id>        # optional: whole 4 MB flash -> <workspace>/../backup/ (minutes)
bash "$SKILL/scripts/flash.sh" <app-dir> --yes
```
`FLASH_POLICY=auto` in this board's bench file replaces `--yes` for a dedicated lab board - only
the developer writes it, never you. discover, backup, flash and test hold a per-board lock: `board
'<id>' is in use` means another run has the board - wait.
Gates inside: every image of the manifest's flash map matches its sha256 → the bridge with the bench
USB serial (or the bench port when the bridge has no serial) → esptool identity (chip, **MAC = bench
MAC**, flash size, security off) → `write_flash` of the map (flash mode/size/freq kept as built),
every region "Hash of data verified" → hard reset → the console port is back.
**Gate:** `FLASH: PASS (4/4 regions ...)`. Never use `pio run -t upload` (no gates).

## Stage 6 - Test (after flashing)

Spec format (`tests/*.json` keys, JSON escaping, what is not measured): `docs/workflow.md`
"Test specs" in the repo root.

```bash
~/.platformio/penv/Scripts/python "$SKILL/scripts/serial_test.py" auto <app>/tests/<spec>.json <app>/logs/test-<ts>.log --board <id> [--interactive | --only-interactive]
```
PlatformIO's python has pyserial (the system python may not). `auto` = the port whose USB serial +
VID are the bench file's; a bridge without a USB serial (`USB_SERIAL=-`) needs the port name from the
bench file instead of `auto`. Opening the port may pulse DTR/RTS and restart the sketch; default
`--sync` sends `info` until `READY`, checks `board=<id>`, runs the steps. Interactive steps (press
BOOT, look at the LED, lay the board flat, breathe on the HTS221) only with `--interactive`: tell the
user exactly what to do first. **Gate:** `RESULT: PASS`. `led?` reads the GPIO level back; `rgb?`
reports the last colour written (a pixel cannot be read) - only a human confirms what lit.

**Per-peripheral specs (iot-sensor app):** `tests/i2c_bus.json` (scan finds exactly 0x5F 0x68 0x76),
`tests/mpu6050.json`, `tests/bmp280.json`, `tests/hts221.json` (present in `INFO`, line format,
plausible ranges: pressure 80-110 kPa, temperatures 0-59 °C, humidity 1-99 %, gravity on one axis),
`tests/rgb_led.json` (colour commands, read-back, bad values) and `tests/iot_sensor.json` (stream,
`read`, the JSON payload, Wi-Fi/MQTT state; `publish` is checked online only when `mqtt?` says
connected). Run them one by one and report each result; ranges are plausibility checks, not
calibration - say "estimated", not "measured accurately".

**Unit tests on the board (prototype):** `bash "$SKILL/scripts/unit_test.sh" <app> [--build-only | --read-only]` -
Unity tests of `src/func/` (led read-back, button debounce with real `millis()`, console parsing) in
`test/test_func/test_driver.cpp` (the test driver), linked against the test stub (`test_stub.cpp`,
the board below `func/`) and the test log (`test_log.c`), built by `pio test` in
`[env:<env>_unit]` (only `src/func` + `test/`; the test stub also stands in for the sensor drivers,
so `func/sensors.cpp` of an iot-sensor app links) with a manifest of that build. Without `--yes` it
builds and stops with `ACTION: APPROVE` (the test image replaces the app): ask the user, then
re-run with `--yes` - `flash.sh --env <env>_unit` (manifest + identity gates). The results are read by
`<repo>/lib/unity_read.py`, not by `pio test`: opening the bridge port may restart the chip and lose
the first lines, so the test image waits for a start byte. **Gates:**
`UNIT-BUILD: PASS`, `UNIT: PASS (n/n, test log agrees)` (the `TESTLOG:` line after Unity's summary
must match Unity's results; lost lines = FAIL; procedure: tool skill `firmware-test`). If nothing at all arrives (`ACTION: POWER_CYCLE`), the chip may
still be in its ROM bootloader - `FLASH: PASS` does not prove the image booted: ask the user to press
EN (or unplug USB for 5 s), then `--read-only`.
Afterwards the board runs the test image: offer `flash.sh <app> --yes` (asks first) to put the app back.

## Stage 16 - Clean

```bash
bash "$SKILL/scripts/clean.sh" [--apps] [<workspace>]          # dry run
bash "$SKILL/scripts/clean.sh" [--apps] [<workspace>] --yes    # delete (ask the user first)
```
- default: **build outputs only** (`<app>/.pio`). Sources, tests, logs, `.bench` are kept.
- `--apps`: also deletes **whole apps** made by `new_app.sh` (`arduino-app.env`) - the user's code
  - and `.bench`. Only when the user explicitly asks; name the apps. `APP_PUBLISHED=1` apps keep
  sources.
- Never touches `~/.platformio` (shared by all PlatformIO projects).

## Extending the skill

- **Another ESP32-S2 board / Cucumber variant:** copy `boards/_template/` to `boards/<id>/`, fill
  `README.md` and `pio-arduino-cucumber/board.env` (`pio boards esp32s2`; check its variant's
  `pins_arduino.h` - the Saola-1 variant's SDA/SCL/LED_BUILTIN are NOT the Cucumber's), add a
  `BOARD_<ID>` block to `board.h` and its I/O table to `board.cpp`. Never invent a board id or pins.
- **New onboard or external sensor:** `templates/_common/src/board/board_<dev>.h/.cpp` (plain types
  in the header, the library in the .cpp, exact version in `PIO_LIB_DEPS`), a stub in
  `templates/_common/test/test_func/test_stub.cpp`, a console command + `tests/<dev>.json` in the
  template that uses it.
- **New template:** `templates/<name>/src/main.cpp` + `tests/<name>.json` + `description.txt`.
- **Platform update:** change `PIO_PLATFORM` in the board profile (exact version), rebuild every
  template, compare the manifests, re-test on hardware, log it - never float to "latest".

## Reporting (always)

Report verification levels separately: **source matches → built → flashed → booted (READY) →
tested (PASS n/m) → observed by a human**, and per peripheral (I2C scan, MPU6050, BMP280, HTS221,
RGB LED, Wi-Fi, MQTT). Quote the firmware.bin sha256, platform + library versions and log paths. Add
a dated line to `boards/<id>/pio-arduino-cucumber/README.md` (verification log) when a board fact is
newly verified (e.g. the bridge chip, the RGB LED type). Never record SSIDs, broker names of the
developer's network, MACs, serials or COM ports there.

## Safety rules

- Never burn eFuses (`espefuse.py`), enable flash encryption or secure boot - irreversible. Stop
  and ask.
- Identity gate before every write (chip, MAC = bench serial, flash size, security off); never
  flash an image without a PASS manifest. Ask before every flash and before `clean.sh --yes`.
- Never run installers or change drivers without asking (the bridge's USB driver is the developer's).
- Wi-Fi credentials and private broker addresses never go into files, specs, commits or reports.
