# NXP FRDM-MCXN947 - how to use `mcux-sdk-frdmmcxn947`

Step-by-step guide for people. The agent's instructions are in [SKILL.md](SKILL.md); the shared
contract (stages, gates, exit codes) is in [docs/workflow.md](../../docs/workflow.md). Hardware:
[boards/frdm-mcxn947](../../boards/frdm-mcxn947/README.md). Status of this skill: **create, open in
VS Code and build work; flash, test and debug are planned** (they were proven by hand - see
[docs/related-work.md](../../docs/related-work.md), "NXP FRDM-MCXN947").

| On the board | |
| --- | --- |
| Console | MCU-Link virtual COM port (USB-C J17), 115200 |
| LED1, LED2, LED3 | RGB LED D2: red, green, blue |
| BTN1, BTN2 | SW2 (wakeup), SW3 (ISP - do not hold it while resetting) |
| Probe / USB | the on-board MCU-Link (CMSIS-DAP + VCOM) |

## 1. Prepare the PC (once)

- Windows 10/11, Git for Windows (Git Bash), Python 3.
- **MCUXpresso Installer** (nxp.com): Arm GNU Toolchain, Ninja, MCUXpresso SDK Developer (the
  Python venv with west), LinkServer. They land in `~/.mcuxpressotools` and `C:/NXP`.
- **Kitware CMake 3.30+** (cmake.org). ST's `cube-cmake` / STM32CubeCLT tools are never used,
  even if they come first on PATH.
- **MCUXpresso SDK 26.09** in a short folder outside cloud sync, e.g. in Git Bash:
  `~/.mcuxpressotools/.mcux-venv-3.12/Scripts/west.exe init -m https://github.com/nxp-mcuxpresso/mcuxsdk-manifests.git --mr v26.09.00 C:/mcux-26.09`,
  then in `C:/mcux-26.09`: `west update_board --set board frdmmcxn947` (several GB). Another folder:
  `MCUX_SDK_ROOT=<folder>` in `~/.fw-skills.env`.
- IDE path (optional): VS Code + **MCUXpresso for VS Code**.

## 2. Install the plugin

In Claude Code: `/plugin marketplace add vsupacha/automated-firmware-skills`, then
`/plugin install firmware-mcuxpresso@automated-firmware-skills` (or the all-in-one
`automated-firmware-skills`, not both).

## 3. Ask Claude

| You say | Claude runs | You see |
| --- | --- | --- |
| "How do I use this?" | `help.sh` | the command menu, boards and templates |
| "Check my tools for the FRDM-MCXN947" | `check_tools.sh frdm-mcxn947` | `missing/bad=0`; every BAD row says what to install |
| "Create a push-to-light app called btn-led" | `new_app.sh frdm-mcxn947 btn-led "" push-to-light` | `Created <app folder>` (first time on a PC: which workspace?) |
| "Open it in the IDE" | `open_ide.sh <app>` (new_app does it) | `IDE: OPENED` - MCUXpresso for VS Code lists the app in its Projects view |
| "Register the SDK in VS Code" | `open_ide.sh <app> --register-sdk` **after you said yes** | `SDK: REGISTERED` - one entry in your VS Code user settings |
| "Build it" | `build.sh <app>` | `BUILD: PASS` with 0 warnings + a manifest (tool versions, image hash) |
| "Clean up" | `clean.sh` (dry run first) | a list, then deletion only after your yes; `--apps` also deletes app sources |

Flashing, tests and debugging are not in this skill yet - Claude will say so instead of flashing.

## 4. The same without Claude (Git Bash, from the repo root)

```bash
S=skills/mcux-sdk-frdmmcxn947/scripts
bash $S/check_tools.sh frdm-mcxn947
bash $S/new_app.sh frdm-mcxn947 btn-led "" push-to-light     # prints: Created C:/fw-ws/btn-led
bash $S/build.sh C:/fw-ws/btn-led
```

In VS Code the Build button uses the same preset (`debug`) and the same `debug/` folder.

## 5. Notes for this board

- An app is the SDK's `hello_world` example exported with `west export_app`, then trimmed: the SDK
  `board.c/board.h` and debug console go, `clock_config` (150 MHz) and `pin_mux` stay, our layered
  `src/` comes in. Pins and clocks: MCUXpresso Config Tools on the `.mex` in the board folder.
- The SDK compiles with `-Werror`; the skill turns that off so `build.sh` reports warnings itself
  (exit 2) - fix them before you continue.
- SW3 is the ISP button: held while the board resets, it starts the ROM bootloader instead of your app.
- When flashing comes to this skill it will never write the protected flash region or update the
  MCU-Link firmware on its own.

## More

- Thai guide: [README_TH.md](README_TH.md)
- Board profile and verification log: [boards/frdm-mcxn947/mcux-sdk-frdmmcxn947/README.md](../../boards/frdm-mcxn947/mcux-sdk-frdmmcxn947/README.md)
