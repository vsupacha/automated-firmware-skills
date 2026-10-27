# Raspberry Pi Pico 2 W - how to use `pio-arduino-rpipico2w`

Firmware for the Raspberry Pi Pico 2 W - RP2350A - with PlatformIO + arduino-pico, from "are my tools installed?" to
"tested on the board", with a gate at every stage. You can ask Claude in your own words or run the
same scripts yourself in Git Bash. Thai: [README_TH.md](README_TH.md). The agent's instructions are
in [SKILL.md](SKILL.md).

Board stages (connect, flash, test) are verified on hardware. Demo levels per template and the exact tool versions:
[boards/rpi-pico-2w/README.md](../../boards/rpi-pico-2w/README.md).

| On the board | |
| --- | --- |
| Console | USB CDC |
| LED1 | LED (on the Wi-Fi module) |
| BTN1 | BOOTSEL |
| Probe / USB | the USB port (no debug probe needed) |

## 1. Prepare the PC (once)

- Windows 10/11 with Git for Windows (Git Bash) and Python 3 with `pyserial`.
- PlatformIO Core (pip or the VS Code extension) and Git; the first build downloads the pinned platform and arduino-pico (~1.5 GB).
- On Windows run `git config --global core.longpaths true` before the first build.
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
| "Check my tools for the Raspberry Pi Pico 2 W" | `check_tools.sh rpi-pico-2w` | `missing/bad=0`; every BAD row says what to install |
| "Create a push-to-light app called btn-led" | `new_app.sh rpi-pico-2w btn-led "" push-to-light` | `Created <app folder>` (first time on a PC: which workspace?) |
| "Open it in the IDE" | `open_ide.sh <app>` (new_app does it) | `IDE: OPENED` - PlatformIO IDE (VS Code) |
| "Build it" | `build.sh <app>` | `BUILD: PASS` with 0 warnings + a manifest (tool versions, image hash) |
| "Find my board" | `discover.sh rpi-pico-2w` | `IDENTITY: PASS` - read-only; saves this PC's probe / USB serial and console port |
| "Flash it" | `flash.sh <app> --yes` **after you said yes** | `FLASH: PASS` |
| "Run the test" | `serial_test.py auto <app>/tests/push_to_light.json ...` | `RESULT: PASS (n/n passed ...)` |
| "Run the unit tests" | `unit_test.sh <app>` - asks, then `--yes` | `UNIT: PASS (12/12)` - Unity tests of `func/` on the board (prototype); the board then runs the test image until you flash the app again |
| "Run the interactive test" | `serial_test.py auto <app>/tests/push_to_light.json ... --interactive` (a push-to-light app) | press BOOTSEL when asked and watch LED (on the Wi-Fi module) |
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
S=skills/pio-arduino-rpipico2w/scripts
bash $S/check_tools.sh rpi-pico-2w
bash $S/new_app.sh rpi-pico-2w btn-led "" push-to-light   # prints: Created <app folder>
bash $S/build.sh <app folder>
bash $S/discover.sh rpi-pico-2w
bash $S/flash.sh <app folder> --yes          # only after you decided to flash
python $S/serial_test.py auto <app folder>/tests/push_to_light.json <app folder>/logs/test.log --board rpi-pico-2w --interactive
```

`<app folder>` is what `new_app.sh` printed - `apps/btn-led`, or e.g. `C:/fw-ws/btn-led` with a
per-PC workspace. Exit codes: 0 pass, 1 fail, 2 warnings that block the gate, **10 = do what the
`ACTION:` line says, then re-run** (SETUP, CONNECT, APPROVE, CHOOSE).

## 5. Notes for this board

- **Flash:** picotool over USB: flash.sh reboots a running sketch into BOOTSEL itself (1200 baud touch), checks the identity (chip, flash size, chip ID) and loads with verify.
- BTN1 is the BOOTSEL button: the sketch reads it while running; holding it at power-up starts the USB bootloader instead.
- The code is Arduino style (C++ `func/` of its own).
- The board has no reset button. If it stops answering: unplug USB, hold BOOTSEL, plug in, release - it starts the bootloader and `flash.sh` can program it again.
- `discover.sh` saves the board's USB serial (= the chip ID) and its COM port for this PC.

## More

- [README.md](../../README.md) - concepts, all boards, plugins
- [docs/workflow.md](../../docs/workflow.md) - stages, gates, exit codes, apps workspace, tool updates
- [boards/rpi-pico-2w/README.md](../../boards/rpi-pico-2w/README.md) - hardware, tool versions, verification log
