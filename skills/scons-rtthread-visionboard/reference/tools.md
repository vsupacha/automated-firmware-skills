# Tools and versions (scons-rtthread-visionboard)

Everything comes from one RT-Thread Studio install (`RTT_STUDIO_HOME`, default `C:/RT-ThreadStudio`,
GLOBAL or LOCAL); the board profile pins the package versions inside it.

| Tool | Where (under `repo/Extract` or `platform/env_released`) | Version proven | Notes |
| --- | --- | --- | --- |
| Vision Board SDK | `Board_Support_Packages/RealThread/VISION-BOARD/1.3.0` | 1.3.0 | RT-Thread 5.0.2, FSP 5.1.0 (RA8D1), example `vision_board_blink_led` |
| GNU Arm | `ToolChain_Support_Packages/ARM/GNU_Tools_for_ARM_Embedded_Processors/13.3` | 13.3.1 (13.3.Rel1) | the SDK project's 10.2.1 fails in Studio's build; scons builds with both |
| scons | `env-new/.venv` (Python 3.11.9) | 4.10.0 | the env Studio runs; fallback `env/tools/Python27` + scons 3.1.2 |
| pyOCD | `Debugger_Support_Packages/RealThread/PyOCD/0.2.9` | pyOCD 0.36.0 | `pyocd.yaml` in that folder lists the packs (`Renesas.RA_DFP` 6.1.0); run from that folder |
| RT-Thread Studio | `studio.exe`, `eclipsec.exe` (headless import) | (the install on this PC, 2026-10) | Eclipse CDT 10 based; Java 8 |

## Paths

| Path | Rule | Why |
| --- | --- | --- |
| workspace / app | no spaces, English characters only, ≤100 characters | the deepest file in an app is 105 characters (rt-thread/components/vmm/...): Windows 260-char limit |
| Studio paths for Eclipse | Windows backslash paths | `C:/...` is read as a URI scheme ("No file system is defined for scheme: C") |
| cloud-synced folder | allowed (WARN) | ~38 MB per app; pause sync if a build hits locked files |

## Troubleshooting

| Symptom | Cause / fix |
| --- | --- |
| Studio asks to sync scons / errors with GCC 10.2.1 | an app made before 2026-10-09: right-click > Sync scons configuration to project, Toolchain 13.3 (new_app.sh now does both) |
| project renamed to `project` after a Studio sync | RT-Thread 5.0.2 `--project-name` default; new_app.sh sets the app's copy to the app name |
| `open_ide.sh`: ACTION Studio is running | the headless import needs the workspace unlocked: File > Import > Existing Projects, or close Studio |
| discover: no answer from the target | SWD closed on a new board: hold RST while connecting (BSP note); never change security settings |
| `foo: command not found.` | msh's answer to unknown commands (tests expect it) |
