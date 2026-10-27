# RT-Thread Edgi-Talk - how to use `modus-pdl-edgitalk`

Firmware for the RT-Thread Edgi-Talk - PSE846GPS2DBZC4A, Infineon PSOC Edge E84 - with ModusToolbox 3.9 + PDL, from "are my tools installed?" to
"tested on the board", with a gate at every stage. You can ask Claude in your own words or run the
same scripts yourself in Git Bash. Thai: [README_TH.md](README_TH.md). The agent's instructions are
in [SKILL.md](SKILL.md).

Board stages (connect, flash, test) are verified on hardware. Demo levels per template and the exact tool versions:
[boards/edgi-talk/README.md](../../boards/edgi-talk/README.md).

| On the board | |
| --- | --- |
| Console | KitProg3 USB-UART |
| LED1 | LED1 (red) |
| BTN1 | SW2 |
| Probe / USB | the on-board KitProg3 |

## 1. Prepare the PC (once)

- Windows 10/11 with Git for Windows (Git Bash) and Python 3 with `pyserial`.
- ModusToolbox 3.9 tools, ModusToolbox Programming Tools, Arm GCC, Edge Protect Security Suite.
- Short paths without spaces or non-English characters for the workspace, the Windows user folder and the ModusToolbox install.
- Optional: VS Code and Infineon ModusToolbox for VS Code for the IDE path; Claude Code for the agent path.

`check_tools.sh` (step 3) lists anything missing with the version the board profile pins.

## 2. Install the plugin

In Claude Code, from your project folder:

```
/plugin marketplace add vsupacha/automated-firmware-skills
/plugin install firmware-modustoolbox@automated-firmware-skills
```

It brings `firmware-tools` along. `automated-firmware-skills@automated-firmware-skills` installs
every board instead - pick one of the two.

## 3. Ask Claude

| You say | Claude runs | You see |
| --- | --- | --- |
| "How do I use this?" | `help.sh` | the command menu, boards and templates |
| "Check my tools for the RT-Thread Edgi-Talk" | `check_tools.sh edgi-talk` | `missing/bad=0`; every BAD row says what to install |
| "Create a push-to-light app called btn-edgi" | `new_app.sh edgi-talk btn-edgi "" push-to-light` | `Created <app folder>` (first time on a PC: which workspace?) |
| "Open it in the IDE" | `open_ide.sh <app>` (new_app does it) | `IDE: OPENED` - Infineon ModusToolbox for VS Code |
| "Build it" | `build.sh <app>` | `BUILD: PASS` with 0 warnings + a manifest (tool versions, image hash) |
| "Back up the board first" | `backup.sh edgi-talk` | the factory image saved before the first flash |
| "Find my board" | `discover.sh edgi-talk` | `IDENTITY: PASS` - read-only; saves this PC's probe / USB serial and console port |
| "Flash it" | `flash.sh <app> --yes` **after you said yes** | `FLASH: PASS` |
| "Run the test" | `serial_test.py auto <app>/tests/push_to_light.json ...` | `RESULT: PASS (n/n passed ...)` |
| "Run the interactive test" | `serial_test.py auto <app>/tests/push_to_light.json ... --interactive` (a push-to-light app) | press SW2 when asked and watch LED1 (red) |
| "Clean up" | `clean.sh` (dry run first) | a list, then deletion only after your yes; `--apps` also deletes app sources |

- **First app on a PC:** if `apps/` is in Dropbox/OneDrive or its path is too long, `new_app.sh`
  stops with `ACTION: CHOOSE` and Claude asks where apps should live (recommended: a short folder
  outside the synced folder, such as `C:/fw-ws`). It saves the answer with
  `lib/fw_workspace.sh set <dir>` and does not ask again on that PC.
- **Two paths:** after the app is created you can code, build, flash and debug it yourself in
  Infineon ModusToolbox for VS Code (IDE path) or let Claude run the gated stages (script path). Both use the same app
  folder, so you can switch at any time.
- **Your code** goes in `src/` in layers: `board/` (pins and peripherals), `func/` (portable logic),
  `app_main` (wiring) - see [docs/board-api.md](../../docs/board-api.md).
- **Nothing is flashed without your yes.** Claude shows the board, the app and the image hash and
  waits; `flash.sh` checks the board's identity again before writing.

## 4. The same without Claude (Git Bash, from the repo root)

```bash
S=skills/modus-pdl-edgitalk/scripts
bash $S/check_tools.sh edgi-talk
bash $S/new_app.sh edgi-talk btn-edgi "" push-to-light   # prints: Created <app folder>
bash $S/build.sh <app folder>
bash $S/discover.sh edgi-talk
bash $S/flash.sh <app folder> --yes          # only after you decided to flash
python $S/serial_test.py auto <app folder>/tests/push_to_light.json <app folder>/logs/test.log --board edgi-talk --interactive
```

`<app folder>` is what `new_app.sh` printed - `apps/btn-edgi`, or e.g. `C:/fw-ws/btn-edgi` with a
per-PC workspace. Exit codes: 0 pass, 1 fail, 2 warnings that block the gate, **10 = do what the
`ACTION:` line says, then re-run** (SETUP, CONNECT, APPROVE, CHOOSE).

## 5. Notes for this board

- **Flash:** OpenOCD (ModusToolbox Programming Tools) over the KitProg3 (identity gate: probe serial, device, life cycle checked before programming; verified).
- Creating an app runs ModusToolbox Project Creator (a few minutes, downloads `mtb_shared` the first time). It fails with no clear reason when Dropbox or OneDrive locks files - keep the apps workspace outside synced folders (`new_app.sh` asks once per PC).
- Extra templates: `button-led`, `dual-core-ipc` (CM33 + CM55). The IDE handoff runs ModusToolbox's `make vscode` and applies the extension's "Fix Tasks / Fix Settings" up front (`vscode_fix.py`).
- "Back up the board" (`backup.sh edgi-talk`) before the first flash keeps the factory image.
- If your Windows user name has non-English characters, keep the apps workspace outside the user folder (e.g. `C:/fw-ws`).
- `flash.sh` may stop with `ACTION: POWER_CYCLE`: unplug and replug USB, then re-run. `clean.sh` reports `CLEAN: INCOMPLETE` when a sync service locks files - pause sync and re-run.
- Infineon code examples: "list the examples for edgi-talk" (`examples.sh`), "start from example <id>" (`new_app.sh ... --example <id>`, example and BSP versions pinned). Examples that change the BSP themselves (e.g. Bluetooth) need their settings merged by hand with the Edgi-Talk overlay.
- Several boards on one PC: run `discover.sh edgi-talk --serial <probe>` for each - all have the same chip, so only the probe serial tells them apart.

## More

- [README.md](../../README.md) - concepts, all boards, plugins
- [docs/workflow.md](../../docs/workflow.md) - stages, gates, exit codes, apps workspace, tool updates
- [boards/edgi-talk/README.md](../../boards/edgi-talk/README.md) - hardware, tool versions, verification log
