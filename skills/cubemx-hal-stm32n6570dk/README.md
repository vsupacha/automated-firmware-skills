# ST STM32N6570-DK - how to use `cubemx-hal-stm32n6570dk`

Firmware for the ST STM32N6570-DK - STM32N657X0H3Q, STM32N6 - with STM32CubeMX 6.18 + STM32CubeN6 HAL + CMake, from "are my tools installed?" to
"tested on the board", with a gate at every stage. You can ask Claude in your own words or run the
same scripts yourself in Git Bash. Thai: [README_TH.md](README_TH.md). The agent's instructions are
in [SKILL.md](SKILL.md).

Build stages only - board stages are planned. Demo levels per template and the exact tool versions:
[boards/stm32n6570-dk/README.md](../../boards/stm32n6570-dk/README.md).

| On the board | |
| --- | --- |
| Console | ST-LINK virtual COM port |
| LED1 | LED1 (green) |
| BTN1 | USER1 |
| Probe / USB | the on-board ST-LINK |

## 1. Prepare the PC (once)

- Windows 10/11 with Git for Windows (Git Bash) and Python 3 with `pyserial`.
- STM32CubeMX 6.18 (classic) with the STM32Cube_FW_N6 package.
- The STM32Cube bundles: GNU Tools for STM32, CMake, Ninja.
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
| "Check my tools for the ST STM32N6570-DK" | `check_tools.sh stm32n6570-dk` | `missing/bad=0`; every BAD row says what to install |
| "Are my tools still the pinned versions?" | `update_tools.sh stm32n6570-dk` | `UPDATE: NONE`, or a question before anything is re-pinned |
| "Create a hello-world app called hello-n6" | `new_app.sh stm32n6570-dk hello-n6 "" hello-world` | `Created <app folder>` (first time on a PC: which workspace?) |
| "Open it in the IDE" | `open_ide.sh <app>` (new_app does it) | `IDE: OPENED` - STM32CubeIDE for VS Code |
| "Build it" | `build.sh <app>` | `BUILD: PASS` with 0 warnings + a manifest (tool versions, image hash) |
| "Clean up" | `clean.sh` (dry run first) | a list, then deletion only after your yes; `--apps` also deletes app sources |

- **First app on a PC:** if `apps/` is in Dropbox/OneDrive or its path is too long, `new_app.sh`
  stops with `ACTION: CHOOSE` and Claude asks where apps should live (recommended: a short folder
  outside the synced folder, such as `C:/fw-ws`). It saves the answer with
  `lib/fw_workspace.sh set <dir>` and does not ask again on that PC.
- **Two paths:** after the app is created you can code, build and debug it yourself in
  STM32CubeIDE for VS Code (IDE path) or let Claude run the gated stages (script path). Both use the same app
  folder, so you can switch at any time.
- **Your code** goes in `src/` in layers: `board/` (pins and peripherals), `func/` (portable logic),
  `app_main` (wiring) - see [docs/board-api.md](../../docs/board-api.md).

## 4. The same without Claude (Git Bash, from the repo root)

```bash
S=skills/cubemx-hal-stm32n6570dk/scripts
bash $S/check_tools.sh stm32n6570-dk
bash $S/new_app.sh stm32n6570-dk hello-n6 "" hello-world   # prints: Created <app folder>
bash $S/build.sh <app folder>
```

`<app folder>` is what `new_app.sh` printed - `apps/hello-n6`, or e.g. `C:/fw-ws/hello-n6` with a
per-PC workspace. Exit codes: 0 pass, 1 fail, 2 warnings that block the gate, **10 = do what the
`ACTION:` line says, then re-run** (SETUP, CONNECT, APPROVE, CHOOSE).

## 5. Notes for this board

- Board stages (connect, flash, test) are **planned**: the N6 boots from external flash, so loading an app needs the development boot mode (BOOT1 switch) and "connect under reset". Until then the skill creates, opens in the IDE and builds.
- Every app's `<app>.ioc` starts from ST's FSBL-only template in STM32CubeN6 plus the console UART; never edit `mx/` by hand.

## More

- [README.md](../../README.md) - concepts, all boards, plugins
- [docs/workflow.md](../../docs/workflow.md) - stages, gates, exit codes, apps workspace, tool updates
- [boards/stm32n6570-dk/README.md](../../boards/stm32n6570-dk/README.md) - hardware, tool versions, verification log
