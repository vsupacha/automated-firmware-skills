# ST NUCLEO-WB55RG - how to use `cubemx-hal-stm32wb55nucleo`

Firmware for the ST NUCLEO-WB55RG - STM32WB55RGV6 (Cortex-M4 application core), STM32WB - with STM32CubeMX 6.18 + STM32CubeWB HAL + CMake, from "are my tools installed?" to
"tested on the board", with a gate at every stage. You can ask Claude in your own words or run the
same scripts yourself in Git Bash. Thai: [README_TH.md](README_TH.md). The agent's instructions are
in [SKILL.md](SKILL.md).

Board stages connect, flash and test; debug (stage 7) is planned. Demo levels per template and the exact tool versions:
[boards/nucleo-wb55rg/README.md](../../boards/nucleo-wb55rg/README.md).

| On the board | |
| --- | --- |
| Console | ST-LINK virtual COM port |
| LED1, LED2, LED3 | LED1 (blue), LED2 (green), LED3 (red) |
| BTN1, BTN2, BTN3 | SW1, SW2, SW3 |
| Probe / USB | the on-board ST-LINK/V2-1 |

## 1. Prepare the PC (once)

- Windows 10/11 with Git for Windows (Git Bash) and Python 3 with `pyserial`.
- STM32CubeMX 6.18 (classic) with the STM32Cube_FW_WB package.
- The STM32Cube bundles: GNU Tools for STM32, CMake, Ninja, STM32CubeProgrammer, ST-LINK GDB server (VS Code debug).
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
| "Check my tools for the ST NUCLEO-WB55RG" | `check_tools.sh nucleo-wb55rg` | `missing/bad=0`; every BAD row says what to install |
| "Are my tools still the pinned versions?" | `update_tools.sh nucleo-wb55rg` | `UPDATE: NONE`, or a question before anything is re-pinned |
| "Create a push-to-light app called btn-led" | `new_app.sh nucleo-wb55rg btn-led "" push-to-light` | `Created <app folder>` (first time on a PC: which workspace?) |
| "Open it in the IDE" | `open_ide.sh <app>` (new_app does it) | `IDE: OPENED` - STM32CubeIDE for VS Code |
| "Build it" | `build.sh <app>` | `BUILD: PASS` with 0 warnings + a manifest (tool versions, image hash) |
| "Find my board" | `discover.sh nucleo-wb55rg` | `IDENTITY: PASS` - read-only; saves this PC's probe / USB serial and console port |
| "Flash it" | `flash.sh <app> --yes` **after you said yes** | `FLASH: PASS` |
| "Run the test" | `serial_test.py auto <app>/tests/push_to_light.json ...` | `RESULT: PASS (n/n passed ...)` |
| "Run the interactive test" | `serial_test.py auto <app>/tests/push_to_light.json ... --interactive` (a push-to-light app) | press SW1 / SW2 when asked and watch LED1 (blue) |
| "Run the unit tests on the board" | `unit_test.sh <app> --yes` **after you said yes** (or `FLASH_POLICY=auto`) | `UNIT: PASS (n/n, test log agrees)` - Unity suites of `func/` code; the board keeps the test image until you flash the app again |
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
S=skills/cubemx-hal-stm32wb55nucleo/scripts
bash $S/check_tools.sh nucleo-wb55rg
bash $S/new_app.sh nucleo-wb55rg btn-led "" push-to-light   # prints: Created <app folder>
bash $S/build.sh <app folder>
bash $S/discover.sh nucleo-wb55rg
bash $S/flash.sh <app folder> --yes          # only after you decided to flash
python $S/serial_test.py auto <app folder>/tests/push_to_light.json <app folder>/logs/test.log --board nucleo-wb55rg --interactive
```

`<app folder>` is what `new_app.sh` printed - `apps/btn-led`, or e.g. `C:/fw-ws/btn-led` with a
per-PC workspace. Exit codes: 0 pass, 1 fail, 2 warnings that block the gate, **10 = do what the
`ACTION:` line says, then re-run** (SETUP, CONNECT, APPROVE, CHOOSE).

## 5. Notes for this board

- **Flash:** STM32CubeProgrammer over the ST-LINK (identity gate: ST-LINK board, device ID; verify after write).
- Every app has a `<app>.ioc` started from the CubeMX board configuration plus USART1 on the ST-LINK virtual COM port. Change hardware in STM32CubeMX on that file, then "regenerate" (`regen.sh`); never edit `mx/` by hand.
- The console receives by interrupt into a ring buffer (the USART1 RX FIFO is left off).
- The `.ioc` starts with `clearpinout`: after this board's `loadboard`, CubeMX refuses USART1 until the board's locked pins are cleared. LEDs and buttons are set up in `src/board/board.c`.
- **Wireless stack:** the CM0+ BLE/802.15.4 stack and FUS sit at the top of flash (secure, above `SFSA`). The skill writes only the CM4 application at 0x08000000 and never erases or updates the stack; the board's original BLE demo is overwritten by the first flash.
- STM32CubeMX2 1.1.2 lists this board but cannot create a project for it (its WB packs are marked incompatible), so this skill uses classic STM32CubeMX.

## More

- [README.md](../../README.md) - concepts, all boards, plugins
- [docs/workflow.md](../../docs/workflow.md) - stages, gates, exit codes, apps workspace, tool updates
- [boards/nucleo-wb55rg/README.md](../../boards/nucleo-wb55rg/README.md) - hardware, tool versions, verification log
