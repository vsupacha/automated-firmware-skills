#!/usr/bin/env bash
# Stage 2d: hand an app over to the IDE - VS Code + PlatformIO IDE - so the developer can edit,
# build, upload and monitor it with the extension's own buttons. Opens <app>.code-workspace (the
# app folder, whose platformio.ini PlatformIO IDE picks up), with PlatformIO IDE recommended.
# new_app.sh runs this after creating the app (--no-open there: no window).
# Usage: open_ide.sh <app-dir> [--no-open]     (--no-open: check only, no VS Code window)
# Gate: "IDE: READY <workspace>" (+ "IDE: OPENED"). Exit 10 ACTION: SETUP = VS Code or PlatformIO
# IDE is missing (installing them is the developer's).
#
# The IDE works on the same project and outputs as the scripts: platformio.ini pins the platform,
# PlatformIO IDE builds the same env into .pio/build/<env> like build.sh, and PlatformIO IDE writes
# its own .vscode/ (absolute paths - git-ignored).

. "$(dirname "$0")/env.sh"
APPDIR=""; OPEN=1
for a in "$@"; do case "$a" in --no-open) OPEN=0;; --*) die "unknown option $a";; *) APPDIR="$a";; esac; done
[ -n "$APPDIR" ] && [ -f "$APPDIR/platformio.ini" ] || die "usage: open_ide.sh <app-dir> [--no-open]  (an app made by new_app.sh)"
APPDIR="$(cd "$APPDIR" && pwd)"
fw_code_workspace "$APPDIR" ".=$(basename "$APPDIR") (PlatformIO project)"
fw_open_ide "$APPDIR/$(basename "$APPDIR").code-workspace" $OPEN
cat <<'TXT'
  In VS Code (PlatformIO IDE, status bar / PlatformIO sidebar):
    build         Build (check mark) - same env and .pio/build/<env> as build.sh
    flash         Upload (->) - esptool via PlatformIO, auto port (bootloader + partitions + boot_app0 + sketch)
    monitor       Serial Monitor (plug) at monitor_speed; tests: serial_test.py with tests/*.json (stage 6)
    debug         USB Serial/JTAG: PlatformIO Debug (F5) with debug_tool = esp-builtin in platformio.ini (not set up by the skill)
    code          src/ (board -> func -> main); keep platformio.ini pins in step with the board profile
TXT
