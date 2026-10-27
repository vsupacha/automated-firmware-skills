# Arduino UNO R4 WiFi - how to use `pio-arduino-unor4wifi`

Firmware for the Arduino UNO R4 WiFi - R7FA4M1AB3CFM, Renesas RA4M1 - with PlatformIO + Arduino UNO R4 core, from "are my tools installed?" to
"tested on the board", with a gate at every stage. You can ask Claude in your own words or run the
same scripts yourself in Git Bash. Thai: [README_TH.md](README_TH.md). The agent's instructions are
in [SKILL.md](SKILL.md).

Board stages (connect, flash, test) are verified on hardware. Demo levels per template and the exact tool versions:
[boards/uno-r4-wifi/README.md](../../boards/uno-r4-wifi/README.md).

| On the board | |
| --- | --- |
| Console | UART via the USB bridge |
| LED1 | L (yellow, D13) |
| BTN1 | none |
| Probe / USB | the USB port (the ESP32-S3 USB bridge) |

## 1. Prepare the PC (once)

- Windows 10/11 with Git for Windows (Git Bash) and Python 3 with `pyserial`.
- PlatformIO Core and Git; the first build downloads the pinned `renesas-ra` platform, the UNO R4 core, GCC 7.2.1 and bossac.
- No driver on Windows (standard USB CDC port); PlatformIO's python has pyserial.
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
| "Check my tools for the Arduino UNO R4 WiFi" | `check_tools.sh uno-r4-wifi` | `missing/bad=0`; every BAD row says what to install |
| "Create a hello-world app called hello" | `new_app.sh uno-r4-wifi hello "" hello-world` | `Created <app folder>` (first time on a PC: which workspace?) |
| "Open it in the IDE" | `open_ide.sh <app>` (new_app does it) | `IDE: OPENED` - PlatformIO IDE (VS Code) |
| "Build it" | `build.sh <app>` | `BUILD: PASS` with 0 warnings + a manifest (tool versions, image hash) |
| "Find my board" | `discover.sh uno-r4-wifi` | `IDENTITY: PASS` - read-only; saves this PC's probe / USB serial and console port |
| "Flash it" | `flash.sh <app> --yes` **after you said yes** | `FLASH: PASS` |
| "Run the test" | `serial_test.py auto <app>/tests/hello_world.json ...` | `RESULT: PASS (n/n passed ...)` |
| "Run the interactive test" | `serial_test.py auto <app>/tests/push_to_light.json ... --interactive` (a push-to-light app) | look at L (yellow, D13) when asked |
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
S=skills/pio-arduino-unor4wifi/scripts
bash $S/check_tools.sh uno-r4-wifi
bash $S/new_app.sh uno-r4-wifi hello "" hello-world   # prints: Created <app folder>
bash $S/build.sh <app folder>
bash $S/discover.sh uno-r4-wifi
bash $S/flash.sh <app folder> --yes          # only after you decided to flash
~/.platformio/penv/Scripts/python $S/serial_test.py auto <app folder>/tests/hello_world.json <app folder>/logs/test.log --board uno-r4-wifi
```

`<app folder>` is what `new_app.sh` printed - `apps/hello`, or e.g. `C:/fw-ws/hello` with a
per-PC workspace. Exit codes: 0 pass, 1 fail, 2 warnings that block the gate, **10 = do what the
`ACTION:` line says, then re-run** (SETUP, CONNECT, APPROVE, CHOOSE).

## 5. Notes for this board

- **Flash:** bossac through the board's USB bridge after an identity gate (loader, security off, nothing locked): a 1200 baud touch starts the loader, only the sketch region is written, the Arduino loader stays.
- The board has **no user button**: push-to-light runs the console LED commands only, and the test asks you to look at L instead.
- The loader cannot read flash: there is no backup and no read-back verify; the test's `INFO` line proves which image runs.

## More

- [README.md](../../README.md) - concepts, all boards, plugins
- [docs/workflow.md](../../docs/workflow.md) - stages, gates, exit codes, apps workspace, tool updates
- [boards/uno-r4-wifi/README.md](../../boards/uno-r4-wifi/README.md) - hardware, tool versions, verification log
