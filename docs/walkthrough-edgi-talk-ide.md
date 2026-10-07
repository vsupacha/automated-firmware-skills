# Walkthrough: Edgi-Talk on the IDE path (code it yourself, Claude helps)

A developer story, captured on 2026-10-07 with the `modus-pdl-edgitalk` skill on Windows 11
(ModusToolbox 3.9, VS Code 1.141 + Infineon ModusToolbox for VS Code 1.12.0, Claude Code in the
repo folder). Every command output below is real (trimmed; personal paths shown as `<you>`).
Steps marked **[developer, in VS Code]** are done by hand in the IDE - Claude does not click there.

The two paths are described in [workflow.md](workflow.md#two-paths-after-stage-2-code-it-yourself-or-let-the-agent-run-the-stages):
the **IDE path** (you code, build, flash and debug in VS Code) and the **script path** (Claude runs
the gated stages). This story stays on the IDE path and borrows the script path twice - to check
the work and to see what flashing needs.

```
you ──"how do I start?"──► help ──"check my tools"──► check_tools ──"create an app, I'll code it"──► new_app + VS Code
                                                                                                      │
   ┌──────────────────────────────────────────────────────────────────────────────────────────────────┘
   ▼
 [VS Code] edit main.c ─► [VS Code] Build ─► "check my build" ─► build.sh + check_layers.py ─► [VS Code] Program / Debug
```

## 1. "How do I use this?"

> **You:** I have an Edgi-Talk on my desk. How do I use this skill?

Claude runs `bash skills/modus-pdl-edgitalk/scripts/help.sh --en` and shows the menu:

```
 Create + build
  "create a hello-world app for edgi-talk" -> new_app.sh <board> <app> "" hello-world
  "write an app: press SW1, LED1 lights"   -> template + code in board/ func/ main.c layers
  "open it in VS Code"                     -> open_ide.sh <app>  (VS Code + ModusToolbox extension; new_app does it)
     then choose: code + build/flash/debug yourself in VS Code (IDE path), or let Claude run build/flash/test (script path) - switch any time
  "build it"                               -> build.sh <app>
 Run on hardware (Claude asks before every flash)
  "flash it" / "restore the backup"        -> flash.sh <app> --yes [--hex <file>]
 Active milestones: M1  (hardware commands = M3; enable in milestones.env)
```

## 2. "Check my tools"

> **You:** Check my PC for the Edgi-Talk tools.

Claude runs `check_tools.sh edgi-talk`. Every tool shows where it was found - **GLOBAL** (installed
for all users) or **LOCAL** (installed for you only); one PC can mix both:

```
OK       ModusToolbox tools           3.9  (LOCAL C:/Users/<you>/ModusToolbox/tools_3.9)
OK       Programming Tools            ModusToolboxProgtools-1.9  openocd 0.12.0+dev-5.19.0.4782  (GLOBAL)
OK       Arm GNU toolchain            14.2.1  (LOCAL C:/Users/<you>/Infineon/Tools/mtb-gcc-arm-eabi/14.2.1/gcc)
OK       Edge Protect Security Suite  2.3.0  (LOCAL)
OK       IDE: VS Code                 1.141.0  (LOCAL C:/Users/<you>/AppData/Local/Programs/Microsoft VS Code)
OK       IDE: extension               Infineon ModusToolbox for VS Code 1.12.0
WARN     path: workspace sync         Dropbox folder: pause sync during getlibs/build ...
missing/bad=0 warnings=1
```

The warning is real: with Dropbox syncing `apps/`, ModusToolbox's Project Creator failed on locked
files ("Processing project failed for 'proj_...'", no reason given). Pause sync while creating apps.

## 3. "Create an app - I'll write the code myself"

> **You:** Create a uart-btn-led app called my-edgi for the Edgi-Talk. I want to code it myself in VS Code.

Claude runs `new_app.sh edgi-talk my-edgi` (the default template is `uart-btn-led`). In 3.5 minutes
(first run: ModusToolbox downloads its libraries into `apps/mtb_shared`):

```
==> Project Creator: board KIT_PSE84_EVAL_EPC2 -> apps/my-edgi  (takes a few minutes)
==> Overlay design.modus -> config/design.modus
==> Regenerating GeneratedSource (device-configurator-cli, no --library)
==> Applying template uart-btn-led
==> Created apps/my-edgi  (board edgi-talk, template uart-btn-led)
==> make vscode (ModusToolbox: .vscode/ + my-edgi.code-workspace)
VSCODE-FIX: done (13 files, TOOLCHAIN=GCC_ARM CONFIG=Debug)
IDE: READY C:/Users/<you>/.../apps/my-edgi/my-edgi.code-workspace  (VS Code + Infineon ModusToolbox for VS Code)
IDE: OPENED in VS Code
```

VS Code opens on its own. The extension log for that window: *"ModusToolbox application loaded
successfully"*, 0 tasks missing, 0 tasks different - no "Fix Tasks" prompt, because `new_app.sh`
already applied the extension's own fix to what `make vscode` wrote.

Claude stops here: you chose the IDE path, so it runs nothing else until you ask.

## 4. [developer, in VS Code] Read and edit the code

The workspace shows the app root, `proj_cm33_s`, `proj_cm33_ns`, `proj_cm55` and `mtb_shared`. The
layered code is in `proj_cm33_ns`:

| Layer | Folder | What is in it |
| --- | --- | --- |
| execution | `proj_cm33_ns/main.c` | the console commands and the main loop |
| logic | `proj_cm33_ns/func/` | console, led, button services (portable C, shared with other boards) |
| board | `proj_cm33_ns/board/` | Edgi-Talk pins, UART glue - the only place for vendor calls |

You add an `uptime` command to `main.c`:

```c
/* uptime - added by hand in VS Code (walkthrough, IDE path) */
static void cmd_uptime(int argc, char *argv[])
{
    (void)argc; (void)argv;
    printf("UPTIME ms=%lu\r\n", (unsigned long)board_millis());
}
...
    { "uptime", "uptime                - ms since reset", cmd_uptime },
```

## 5. [developer, in VS Code] Build

**Terminal > Run Build Task** (Ctrl+Shift+B) > **Build**. The task runs
`make build TOOLCHAIN=GCC_ARM CONFIG=Debug` with the extension's tool paths - the same Makefiles and
`build/` folder as the skill's `build.sh` (an IDE build and a `build.sh` build of the same code gave
the identical signed `app_combined.hex`, checked on `hello-edgi` the same day).

## 6. "Check my build" - borrowing the script path

> **You:** I added an uptime command. Can you check it builds cleanly and keeps the layering rules?

Claude runs the gates on the same app folder:

```
$ bash skills/modus-pdl-edgitalk/scripts/build.sh apps/my-edgi
make exit=0  time=29s  warnings=0  errors=0  sign-ok=1  fresh-hex=1
BUILD: PASS

$ python lib/check_layers.py apps/my-edgi
FAIL my-edgi/proj_cm33_ns/retarget_io_init.c:111: exec calls Cy_SCB_UART_Init - vendor API, wrap it in board/
FAIL my-edgi/proj_cm33_ns/retarget_io_init.h:45: exec includes "cybsp.h" - ... only board/ may use it
FAIL my-edgi/proj_cm33_ns/board/board.c:15: board includes "retarget_io_init.h" from the exec layer
LAYERS: FAIL (8 violations, 0 warnings; 2 board, 6 func, 3 exec files)
```

Your `uptime` code is clean - all 8 violations are in Infineon's `retarget_io_init.c/.h`, UART glue
that the hello-world template keeps at the project root (= execution layer). It is board code, so
it belongs in `board/`. **Found by this walkthrough and fixed in the skill:** `new_app.sh` now moves
it there (ModusToolbox compiles sub-folders automatically). After the move:

```
BUILD: PASS
LAYERS: PASS (4 board, 6 func, 1 exec files)
```

## 7. "Flash it"

> **You:** Flash it.

Two ways, both your decision:

- **IDE path** - in VS Code: **Run Task > Build & Program** (or **Program**), or **Run and Debug >
  Launch PSOCE84 CM33 (KitProg3_MiniProg4)** to program and stop in the debugger. These tasks
  program whatever KitProg3 is connected - there is no identity check; with several probes set
  `MTB_PROBE_SERIAL` in `bsp.mk` and re-run `open_ide.sh --refresh`.
- **Script path** - Claude's `flash.sh` checks the probe, the board and the image hash first. In
  this release only milestone M1 is active, so it stops before touching any hardware:

```
$ bash skills/modus-pdl-edgitalk/scripts/flash.sh apps/my-edgi --yes
ACTION: SETUP flash.sh (stage 7 flash) belongs to milestone M3, which is not active in this release
(active: M1). Enabling it is the developer's decision: add M3 to ACTIVE_MILESTONES in milestones.env,
or export FW_ACTIVE_MILESTONES="M1 M3" for one session
```

Claude relays that line and waits. With M3 enabled it would run `discover.sh edgi-talk`, then ask
before every flash (board, app, hash), then `serial_test.py` with `tests/uart_btn_led.json` - and
`uptime` can be added to that spec as one more step.

## What this story shows

| Moment | Who | Path |
| --- | --- | --- |
| help, tools check, create | Claude | script (stages 0-2) |
| open the app | `new_app.sh` | stage 2d, automatic |
| read, edit, build, program, debug | you | IDE |
| check build + layering on request | Claude | script (stages 3-4) on the same folder |
| flash with identity gates, serial tests | Claude, after you enable M3 | script (stages 6-8) |

Switching never needs an export or a copy: the IDE and the scripts share one app folder, one
`build/` and one set of tests.
