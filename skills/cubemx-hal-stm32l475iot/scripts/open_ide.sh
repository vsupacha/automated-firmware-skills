#!/usr/bin/env bash
# Stage 2d: hand an app over to the IDE - VS Code + STM32CubeIDE for Visual Studio Code - so the
# developer can edit, build, flash and debug it with the extension's own buttons. Opens
# <app>.code-workspace (mx/, src/, tests/ as separate folders), never the app folder itself.
# new_app.sh runs this after a successful generation (--no-ide skips it).
# Usage: open_ide.sh <app-dir> [--no-open]     (--no-open: check only, no VS Code window)
# Gate: "IDE: READY <workspace>" (+ "IDE: OPENED"). Exit 10 ACTION: SETUP = VS Code or the
# extension is missing (installing them is the developer's).
#
# The IDE works on the same project and outputs as the scripts: mx/.settings/*.store.json pin the
# same STM32Cube bundles as the board profile, CMake presets build into mx/build/<preset> like
# build.sh, and mx/.vscode/launch.json is the extension's default ST-LINK launch (F5 = build,
# flash, run to main). After a change in STM32CubeMX, run regen.sh (never edit mx/ by hand).

. "$(dirname "$0")/env.sh"
APPDIR=""; OPEN=1
for a in "$@"; do case "$a" in --no-open) OPEN=0;; --*) die "unknown option $a";; *) APPDIR="$a";; esac; done
[ -n "$APPDIR" ] && [ -d "$APPDIR/mx" ] || die "usage: open_ide.sh <app-dir> [--no-open]  (an app made by new_app.sh)"
APPDIR="$(cd "$APPDIR" && pwd)"
fw_cube_open_ide "$APPDIR" $OPEN
cat <<'TXT'
  In VS Code (STM32CubeIDE for Visual Studio Code):
    build         CMake: Build (F7) - same preset and mx/build/<preset> as build.sh
    flash + debug Run and Debug > "STM32Cube: Launch ST-Link GDB Server" (F5): builds, flashes, stops at main
    test          serial_test.py with the app's tests/*.json (M3), or any serial terminal on the ST-LINK VCP (115200)
    hardware      change <app>.ioc in STM32CubeMX, then regen.sh - code goes in src/, never in mx/
TXT
