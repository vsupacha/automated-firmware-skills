# RT-Thread Vision Board - how to use `scons-rtthread-visionboard`

Firmware for the RT-Thread Vision Board - R7FA8D1BH, Renesas RA8D1, Cortex-M85 - with RT-Thread 5.0.2 + scons (RT-Thread Studio SDK), from "are my tools installed?" to
"tested on the board", with a gate at every stage. You can ask Claude in your own words or run the
same scripts yourself in Git Bash. Thai: [README_TH.md](README_TH.md). The agent's instructions are
in [SKILL.md](SKILL.md).

Board stages: hello-world is tested on hardware. Demo levels per template and the exact tool versions:
[boards/vision-board/README.md](../../boards/vision-board/README.md).

| On the board | |
| --- | --- |
| Console | ART-Link virtual COM port (msh shell) |
| LED1 | blue LED (P102) |
| BTN1 | KEY0 |
| Probe / USB | the on-board ART-Link (pyOCD) |

## 1. Prepare the PC (once)

- Windows 10/11 with Git for Windows (Git Bash) and Python 3 with `pyserial`.
- RT-Thread Studio with, from its SDK Manager: the VISION-BOARD support package, GNU_Tools_for_ARM_Embedded_Processors 13.3 and RealThread PyOCD (Studio brings scons).
- Each app is a standalone copy of about 40 MB.
- Optional: VS Code and RT-Thread Studio for the IDE path (RT-Thread Studio is its own IDE); Claude Code for the agent path.

`check_tools.sh` (step 3) lists anything missing with the version the board profile pins.

## 2. Install the plugin

In Claude Code, from your project folder:

```
/plugin marketplace add vsupacha/automated-firmware-skills
/plugin install firmware-rtthread@automated-firmware-skills
```

It brings `firmware-tools` along. `automated-firmware-skills@automated-firmware-skills` installs
every board instead - pick one of the two.

## 3. Ask Claude

| You say | Claude runs | You see |
| --- | --- | --- |
| "How do I use this?" | `help.sh` | the command menu, boards and templates |
| "Check my tools for the RT-Thread Vision Board" | `check_tools.sh vision-board` | `missing/bad=0`; every BAD row says what to install |
| "Are my tools still the pinned versions?" | `update_tools.sh vision-board` | `UPDATE: NONE`, or a question before anything is re-pinned |
| "Create a hello-world app called hello" | `new_app.sh vision-board hello "" hello-world` | `Created <app folder>` (first time on a PC: which workspace?) |
| "Open it in the IDE" | `open_ide.sh <app>` (new_app does it) | `IDE: OPENED` - RT-Thread Studio |
| "Can this app use Wi-Fi (RW007) and an SD card?" | `recipe.sh check <app> rw007 sdcard` | `RECIPE: READY`, or `ACTION:` lines: board/Kconfig block, FSP instance, board port, package to add first ([recipes](recipes/README.md)) |
| "Build it" | `build.sh <app>` | `BUILD: PASS` with 0 warnings + a manifest (tool versions, image hash) |
| "Find my board" | `discover.sh vision-board` | `IDENTITY: PASS` - read-only; saves this PC's probe / USB serial and console port |
| "Flash it" | `flash.sh <app> --yes` **after you said yes** | `FLASH: PASS` |
| "Run the test" | `serial_test.py auto <app>/tests/hello_world.json ...` | `RESULT: PASS (n/n passed ...)` |
| "What is running on the board?" | `msh_status.py auto --board vision-board` | `MSH: PASS` - RT-Thread version, every msh command with its description, threads with stack use, heap, devices (read-only, no probe) |
| "Run the interactive test" | `serial_test.py auto <app>/tests/push_to_light.json ... --interactive` (a push-to-light app) | press KEY0 when asked and watch blue LED (P102) |
| "Clean up" | `clean.sh` (dry run first) | a list, then deletion only after your yes; `--apps` also deletes app sources |

- **First app on a PC:** if `apps/` is in Dropbox/OneDrive or its path is too long, `new_app.sh`
  stops with `ACTION: CHOOSE` and Claude asks where apps should live (recommended: a short folder
  outside the synced folder, such as `C:/fw-ws`). It saves the answer with
  `lib/fw_workspace.sh set <dir>` and does not ask again on that PC.
- **Two paths:** after the app is created you can code, build, flash and debug it yourself in
  RT-Thread Studio (IDE path) or let Claude run the gated stages (script path). Both use the same app
  folder, so you can switch at any time.
- **Your code** goes in `src/` in layers: `board/` (pins and peripherals), `func/` (portable logic),
  `app_main` (wiring) - see [docs/board-api.md](../../docs/board-api.md).
- **Nothing is flashed without your yes.** Claude shows the board, the app and the image hash and
  waits; `flash.sh` checks the board's identity again before writing.

## 4. The same without Claude (Git Bash, from the repo root)

```bash
S=skills/scons-rtthread-visionboard/scripts
bash $S/check_tools.sh vision-board
bash $S/new_app.sh vision-board hello "" hello-world   # prints: Created <app folder>
bash $S/build.sh <app folder>
bash $S/discover.sh vision-board
bash $S/flash.sh <app folder> --yes          # only after you decided to flash
python $S/serial_test.py auto <app folder>/tests/hello_world.json <app folder>/logs/test.log --board vision-board
```

`<app folder>` is what `new_app.sh` printed - `apps/hello`, or e.g. `C:/fw-ws/hello` with a
per-PC workspace. Exit codes: 0 pass, 1 fail, 2 warnings that block the gate, **10 = do what the
`ACTION:` line says, then re-run** (SETUP, CONNECT, APPROVE, CHOOSE).

## 5. Notes for this board

- **Flash:** pyOCD over the ART-Link, code flash only (never the FSP option-setting memory), every byte read back.
- The console is RT-Thread's msh: commands `info`, `led`, `btn` (msh names cannot contain `?`).
- The IDE is RT-Thread Studio, not VS Code. **Studio's own Download writes `rtthread.hex` including the option-setting (security) sections** - prefer "flash it" (`flash.sh`), which writes code flash only.
- Only hello-world has been tested on the board so far; LED colours and the KEY0 level of push-to-light are not verified yet.

## More

- [README.md](../../README.md) - concepts, all boards, plugins
- [docs/workflow.md](../../docs/workflow.md) - stages, gates, exit codes, apps workspace, tool updates
- [boards/vision-board/README.md](../../boards/vision-board/README.md) - hardware, tool versions, verification log
