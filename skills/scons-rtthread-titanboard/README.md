# RT-Thread Titan Board - how to use `scons-rtthread-titanboard`

Firmware for the RT-Thread Titan Board - R7KA8P1KF, Renesas RA8P1, Cortex-M85 - with RT-Thread 5.1.0 + scons (RT-Thread Studio SDK), from "are my tools installed?" to
"tested on the board", with a gate at every stage. You can ask Claude in your own words or run the
same scripts yourself in Git Bash. Thai: [README_TH.md](README_TH.md). The agent's instructions are
in [SKILL.md](SKILL.md).

Board stages: hello-world is tested on hardware. Demo levels per template and the exact tool versions:
[boards/titan-board/README.md](../../boards/titan-board/README.md).

| On the board | |
| --- | --- |
| Console | RA4M2-VCOM virtual COM port (msh shell on uart8) |
| LED1 | red LED (P013) |
| BTN1 | KEY (P110) |
| Probe / USB | the on-board RA4M2 CMSIS-DAP (CMSIS-DAP v2, pyOCD) - Windows: WinUSB with a GUID on its Interface 2 (Zadig) |

## 1. Prepare the PC (once)

- Windows 10/11 with Git for Windows (Git Bash) and Python 3 with `pyserial`.
- RT-Thread Studio with, from its SDK Manager: the Titan-Board support package, GNU_Tools_for_ARM_Embedded_Processors 13.3 and RealThread PyOCD (Studio brings scons).
- Each app is a standalone copy of about 88 MB.
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
| "Check my tools for the RT-Thread Titan Board" | `check_tools.sh titan-board` | `missing/bad=0`; every BAD row says what to install |
| "Are my tools still the pinned versions?" | `update_tools.sh titan-board` | `UPDATE: NONE`, or a question before anything is re-pinned |
| "Create a hello-world app called hello" | `new_app.sh titan-board hello "" hello-world` | `Created <app folder>` (first time on a PC: which workspace?) |
| "Open it in the IDE" | `open_ide.sh <app>` (new_app does it) | `IDE: OPENED` - RT-Thread Studio |
| "Can this app use Wi-Fi and the SD card?" | `recipe.sh check <app> wifi sdcard` | `RECIPE: READY`, or `ACTION:` lines: board/Kconfig block, board port, package to add first (new apps already have every FSP instance - [recipes](recipes/README.md)) |
| "Add the SD card and the RTC to my app" | `recipe.sh apply <app> sdcard rtc`, then `--yes` **after you said yes** | `APPLY: DONE` - files from the SDK/skill, `.config` + `rtconfig.h`, backup of replaced files in `<app>/logs/` |
| "Build it" | `build.sh <app>` | `BUILD: PASS` with 0 warnings + a manifest (tool versions, image hash) |
| "Find my board" | `discover.sh titan-board` | `IDENTITY: PASS` - read-only; saves this PC's probe / USB serial and console port |
| "Flash it" | `flash.sh <app> --yes` **after you said yes** | `FLASH: PASS` |
| "Run the test" | `serial_test.py auto <app>/tests/hello_world.json ...` | `RESULT: PASS (n/n passed ...)` |
| "What is running on the board?" | `msh_status.py auto --board titan-board` | `MSH: PASS` - RT-Thread version, every msh command with its description, threads with stack use, heap, devices (read-only, no probe) |
| "Run the interactive test" | `serial_test.py auto <app>/tests/push_to_light.json ... --interactive` (a push-to-light app) | press KEY when asked and watch the red LED (P013) |
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
S=skills/scons-rtthread-titanboard/scripts
bash $S/check_tools.sh titan-board
bash $S/new_app.sh titan-board hello "" hello-world   # prints: Created <app folder>
bash $S/build.sh <app folder>
bash $S/discover.sh titan-board
bash $S/flash.sh <app folder> --yes          # only after you decided to flash
python $S/serial_test.py auto <app folder>/tests/hello_world.json <app folder>/logs/test.log --board titan-board
```

`<app folder>` is what `new_app.sh` printed - `apps/hello`, or e.g. `C:/fw-ws/hello` with a
per-PC workspace. Exit codes: 0 pass, 1 fail, 2 warnings that block the gate, **10 = do what the
`ACTION:` line says, then re-run** (SETUP, CONNECT, APPROVE, CHOOSE).

## 5. Notes for this board

- **Flash:** pyOCD over the RA4M2 CMSIS-DAP, code MRAM only (never the FSP option-setting memory), every byte read back.
- The console is RT-Thread's msh: commands `info`, `led`, `btn` (msh names cannot contain `?`).
- The IDE is RT-Thread Studio, not VS Code. **Studio's own Download writes `rtthread.hex` including the option-setting (security) sections** - prefer "flash it" (`flash.sh`), which writes code MRAM only.
- Tested on the board (2026-10-31): blink (red LED seen) and push-to-light 17/17; hello-world built only; the KEY press and LED colours of the interactive test are not run yet. Driver recipes build but have not run on the board.

## More

- [README.md](../../README.md) - concepts, all boards, plugins
- [docs/workflow.md](../../docs/workflow.md) - stages, gates, exit codes, apps workspace, tool updates
- [boards/titan-board/README.md](../../boards/titan-board/README.md) - hardware, tool versions, verification log
