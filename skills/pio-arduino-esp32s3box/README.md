# Espressif ESP32-S3-BOX (2021) - how to use `pio-arduino-esp32s3box`

Firmware for the Espressif ESP32-S3-BOX (2021) - ESP32-S3 - with PlatformIO + arduino-esp32, from "are my tools installed?" to
"tested on the board", with a gate at every stage. You can ask Claude in your own words or run the
same scripts yourself in Git Bash. Thai: [README_TH.md](README_TH.md). The agent's instructions are
in [SKILL.md](SKILL.md).

Board stages (connect, flash, test) are verified on hardware. Demo levels per template and the exact tool versions:
[boards/esp32-s3-box/README.md](../../boards/esp32-s3-box/README.md).

| On the board | |
| --- | --- |
| Console | USB Serial/JTAG |
| LED1 | LCD backlight |
| BTN1 | BOOT |
| Probe / USB | the USB Serial/JTAG port |

## 1. Prepare the PC (once)

- Windows 10/11 with Git for Windows (Git Bash) and Python 3 with `pyserial`.
- PlatformIO Core and Git; the first build installs espressif32 + arduino-esp32 2.0.17.
- PlatformIO's own python runs discover, flash and test (pyserial and esptool come with it).
- Optional: VS Code and PlatformIO IDE (VS Code) for the IDE path; Claude Code for the agent path.

`check_tools.sh` (step 3) lists anything missing with the version the board profile pins.

## 2. Install the plugin

In Claude Code, from your project folder:

```
/plugin marketplace add vsupacha/automated-firmware-skills
/plugin install firmware-platformio@automated-firmware-skills
```

It brings `firmware-tools` along. `automated-firmware-skills@automated-firmware-skills` installs
every board instead - pick one of the two.

## 3. Ask Claude

| You say | Claude runs | You see |
| --- | --- | --- |
| "How do I use this?" | `help.sh` | the command menu, boards and templates |
| "Check my tools for the Espressif ESP32-S3-BOX" | `check_tools.sh esp32-s3-box` | `missing/bad=0`; every BAD row says what to install |
| "Create a push-to-light app called btn-esa" | `new_app.sh esp32-s3-box btn-esa "" push-to-light` | `Created <app folder>` (first time on a PC: which workspace?) |
| "Open it in the IDE" | `open_ide.sh <app>` (new_app does it) | `IDE: OPENED` - PlatformIO IDE (VS Code) |
| "Build it" | `build.sh <app>` | `BUILD: PASS` with 0 warnings + a manifest (tool versions, image hash) |
| "Back up the board first" | `backup.sh esp32-s3-box` | the factory image saved before the first flash |
| "Find my board" | `discover.sh esp32-s3-box` | `IDENTITY: PASS` - read-only; saves this PC's probe / USB serial and console port |
| "Flash it" | `flash.sh <app> --yes` **after you said yes** | `FLASH: PASS` |
| "Run the test" | `serial_test.py auto <app>/tests/push_to_light.json ...` | `RESULT: PASS (n/n passed ...)` |
| "Run the unit tests" | `unit_test.sh <app>` - asks, then `--yes` | `UNIT: PASS (12/12, test log agrees)` - Unity tests of `func/` on the board (prototype); if nothing arrives, unplug USB for 5 s and run it with `--read-only` |
| "Run the interactive test" | `serial_test.py auto <app>/tests/push_to_light.json ... --interactive` (a push-to-light app) | press BOOT when asked and watch LCD backlight |
| "Clean up" | `clean.sh` (dry run first) | a list, then deletion only after your yes; `--apps` also deletes app sources |

- **First app on a PC:** if `apps/` is in Dropbox/OneDrive or its path is too long, `new_app.sh`
  stops with `ACTION: CHOOSE` and Claude asks where apps should live (recommended: a short folder
  outside the synced folder, such as `C:/fw-ws`). It saves the answer with
  `lib/fw_workspace.sh set <dir>` and does not ask again on that PC.
- **Two paths:** after the app is created you can code, build, flash and debug it yourself in
  PlatformIO IDE (VS Code) (IDE path) or let Claude run the gated stages (script path). Both use the same app
  folder, so you can switch at any time.
- **Your code** goes in `src/` in layers: `board/` (pins and peripherals), `func/` (portable logic),
  `app_main` (wiring) - see [docs/board-api.md](../../docs/board-api.md).
- **Nothing is flashed without your yes.** Claude shows the board, the app and the image hash and
  waits; `flash.sh` checks the board's identity again before writing.

## 4. The same without Claude (Git Bash, from the repo root)

```bash
S=skills/pio-arduino-esp32s3box/scripts
bash $S/check_tools.sh esp32-s3-box
bash $S/new_app.sh esp32-s3-box btn-esa "" push-to-light   # prints: Created <app folder>
bash $S/build.sh <app folder>
bash $S/discover.sh esp32-s3-box
bash $S/flash.sh <app folder> --yes          # only after you decided to flash
~/.platformio/penv/Scripts/python $S/serial_test.py auto <app folder>/tests/push_to_light.json <app folder>/logs/test.log --board esp32-s3-box --interactive
```

`<app folder>` is what `new_app.sh` printed - `apps/btn-esa`, or e.g. `C:/fw-ws/btn-esa` with a
per-PC workspace. Exit codes: 0 pass, 1 fail, 2 warnings that block the gate, **10 = do what the
`ACTION:` line says, then re-run** (SETUP, CONNECT, APPROVE, CHOOSE).

## 5. Notes for this board

- **Flash:** esptool over USB after the same identity gate as the ESP-IDF skill, four regions (bootloader, partitions, boot_app0, sketch).
- Same board and commands as `pio-espidf-esp32s3box`, Arduino style: `<Arduino.h>` in every layer, `setup()` / `loop()`, its own C++ `func/`.
- LED1 is the LCD backlight and BTN1 is the BOOT button.
- "Back up the board" (`backup.sh esp32-s3-box`) before the first flash keeps the factory firmware.

## More

- [README.md](../../README.md) - concepts, all boards, plugins
- [docs/workflow.md](../../docs/workflow.md) - stages, gates, exit codes, apps workspace, tool updates
- [boards/esp32-s3-box/README.md](../../boards/esp32-s3-box/README.md) - hardware, tool versions, verification log
