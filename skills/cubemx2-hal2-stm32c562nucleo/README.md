# ST NUCLEO-C562RE - how to use `cubemx2-hal2-stm32c562nucleo`

Firmware for the ST NUCLEO-C562RE - STM32C562RET6, STM32C5 - with STM32CubeMX2 + STM32Cube HAL2 + CMake, from "are my tools installed?" to
"tested on the board", with a gate at every stage. You can ask Claude in your own words or run the
same scripts yourself in Git Bash. Thai: [README_TH.md](README_TH.md). The agent's instructions are
in [SKILL.md](SKILL.md).

Board stages (connect, flash, test, debug) are verified on hardware. Demo levels per template and the exact tool versions:
[boards/nucleo-c562re/README.md](../../boards/nucleo-c562re/README.md).

| On the board | |
| --- | --- |
| Console | ST-LINK virtual COM port |
| LED1 | LD1 (green) |
| BTN1 | B1 (USER) |
| Probe / USB | the on-board ST-LINK |

## 1. Prepare the PC (once)

- Windows 10/11 with Git for Windows (Git Bash) and Python 3 with `pyserial`.
- STM32CubeMX2 and its packs (STM32C5 DFP, HAL drivers, templates, the NUCLEO-C562RE board pack).
- The STM32Cube bundles: GNU Tools for STM32, CMake, Ninja, STM32CubeProgrammer, ST-LINK GDB server (for debug).
- Optional: VS Code and STM32CubeIDE for VS Code for the IDE path; Claude Code for the agent path.

`check_tools.sh` (step 3) lists anything missing with the version the board profile pins.

## 2. Install the plugin

In Claude Code, from your project folder:

```
/plugin marketplace add vsupacha/automated-firmware-skills
/plugin install firmware-stm32@automated-firmware-skills
```

It brings `firmware-tools` along. `automated-firmware-skills@automated-firmware-skills` installs
every board instead - pick one of the two.

## 3. Ask Claude

| You say | Claude runs | You see |
| --- | --- | --- |
| "How do I use this?" | `help.sh` | the command menu, boards and templates |
| "Check my tools for the ST NUCLEO-C562RE" | `check_tools.sh nucleo-c562re` | `missing/bad=0`; every BAD row says what to install |
| "Create a push-to-light app called btn-led" | `new_app.sh nucleo-c562re btn-led "" push-to-light` | `Created <app folder>` (first time on a PC: which workspace?) |
| "Open it in the IDE" | `open_ide.sh <app>` (new_app does it) | `IDE: OPENED` - STM32CubeIDE for VS Code |
| "Build it" | `build.sh <app>` | `BUILD: PASS` with 0 warnings + a manifest (tool versions, image hash) |
| "Find my board" | `discover.sh nucleo-c562re` | `IDENTITY: PASS` - read-only; saves this PC's probe / USB serial and console port |
| "Flash it" | `flash.sh <app> --yes` **after you said yes** | `FLASH: PASS` |
| "Run the test" | `serial_test.py auto <app>/tests/push_to_light.json ...` | `RESULT: PASS (n/n passed ...)` |
| "Run the interactive test" | `serial_test.py auto <app>/tests/push_to_light.json ... --interactive` (a push-to-light app) | press B1 (USER) when asked and watch LD1 (green) |
| "Show the MCU status" | `debug.sh status nucleo-c562re` | `DEBUG: STATUS running fault=none` - no reset, no halt |
| "Run the debug scenario" | `debug.sh run <app> .../scenarios/push-to-light.json` | `DEBUG: PASS` - breakpoints / watchpoints; halts the core while attached |
| "Clean up" | `clean.sh` (dry run first) | a list, then deletion only after your yes; `--apps` also deletes app sources |

- **First app on a PC:** if `apps/` is in Dropbox/OneDrive or its path is too long, `new_app.sh`
  stops with `ACTION: CHOOSE` and Claude asks where apps should live (recommended: a short folder
  outside the synced folder, such as `C:/fw-ws`). It saves the answer with
  `lib/fw_workspace.sh set <dir>` and does not ask again on that PC.
- **Two paths:** after the app is created you can code, build, flash and debug it yourself in
  STM32CubeIDE for VS Code (IDE path) or let Claude run the gated stages (script path). Both use the same app
  folder, so you can switch at any time.
- **Your code** goes in `src/` in layers: `board/` (pins and peripherals), `func/` (portable logic),
  `app_main` (wiring) - see [docs/board-api.md](../../docs/board-api.md).
- **Nothing is flashed without your yes.** Claude shows the board, the app and the image hash and
  waits; `flash.sh` checks the board's identity again before writing.

## 4. The same without Claude (Git Bash, from the repo root)

```bash
S=skills/cubemx2-hal2-stm32c562nucleo/scripts
bash $S/check_tools.sh nucleo-c562re
bash $S/new_app.sh nucleo-c562re btn-led "" push-to-light   # prints: Created <app folder>
bash $S/build.sh <app folder>
bash $S/discover.sh nucleo-c562re
bash $S/flash.sh <app folder> --yes          # only after you decided to flash
python $S/serial_test.py auto <app folder>/tests/push_to_light.json <app folder>/logs/test.log --board nucleo-c562re --interactive
```

`<app folder>` is what `new_app.sh` printed - `apps/btn-led`, or e.g. `C:/fw-ws/btn-led` with a
per-PC workspace. Exit codes: 0 pass, 1 fail, 2 warnings that block the gate, **10 = do what the
`ACTION:` line says, then re-run** (SETUP, CONNECT, APPROVE, CHOOSE).

## 5. Notes for this board

- **Flash:** STM32CubeProgrammer over the ST-LINK (identity gate: ST-LINK board, device name and ID; verify after write).
- Every app has a `<app>.ioc2` (STM32CubeMX2 hardware configuration) created from the board pack, or copied with `--ioc2 <file>`. Change hardware there (CubeMX2 GUI or CLI), then "regenerate" (`regen.sh`); never edit `mx/` by hand.
- The C5 core is on debug access port 1 (`DEBUG_APID=1` in the profile) - `debug.sh` handles it.
- Pins: LD1 = PA5 (high = on), B1 = PC13 (high when pressed), B2 = RESET; console = USART2 (PA2/PA3) on the ST-LINK virtual COM port at 115200 - details in the board README.

## More

- [README.md](../../README.md) - concepts, all boards, plugins
- [docs/workflow.md](../../docs/workflow.md) - stages, gates, exit codes, apps workspace, tool updates
- [boards/nucleo-c562re/README.md](../../boards/nucleo-c562re/README.md) - hardware, tool versions, verification log
