#!/usr/bin/env bash
# Stage 2d: hand an app over to the IDE - VS Code + MCUXpresso for VS Code - so the developer can
# edit, build, flash and debug it with the extension's own buttons. No GUI import: the project
# files are written here in the form the extension's Import Project uses (mcux_app.py ide):
# .vscode/mcuxpresso-tools.json (sdk-v2-freestanding), settings.json (Kitware CMake for this app -
# never ST's cube-cmake), launch.json, CMakePresets.json + mcux_include.json (per-PC tool paths).
# new_app.sh runs this after creating the app (--no-open skips the window).
# Usage: open_ide.sh <app-dir> [--no-open] [--register-sdk] [--refresh]
#   --no-open       check only, no VS Code window
#   --register-sdk  add the SDK to VS Code's user setting mcuxpresso.sdks (the scripted form of
#                   MCUXpresso > Import Repository; ask the developer first - it is a user-wide setting)
#   --refresh       rewrite the per-PC files (tool paths moved, another PC)
# Gate: "IDE: READY <workspace>" (+ "IDE: OPENED"). Exit 10 ACTION: SETUP = VS Code, the extension
# or the SDK registration is missing (the developer's to install / approve).

. "$(dirname "$0")/env.sh"
APPDIR=""; OPEN=1; REG=0; FILES_ONLY=0; REFRESH=""
for a in "$@"; do
  case "$a" in --no-open) OPEN=0;; --register-sdk) REG=1;; --refresh) REFRESH=--refresh;; --files-only) FILES_ONLY=1;;
    --*) die "unknown option $a";; *) APPDIR="$a";; esac
done
[ -n "$APPDIR" ] && [ -f "$APPDIR/CMakeLists.txt" ] || die "usage: open_ide.sh <app-dir> [--no-open] [--register-sdk] [--refresh]  (an app made by new_app.sh)"
APPDIR="$(cd "$APPDIR" && pwd)"; APP="$(basename "$APPDIR")"
BOARD="$(sed -n 's/^APP_BOARD=//p' "$APPDIR/mcx-app.env" 2>/dev/null)"
load_board "${BOARD:-frdm-mcxn947}"
require_build_tools

"$PYTHON" "$SKILL_DIR/scripts/mcux_app.py" ide "$(winpath "$APPDIR")" $REFRESH \
  --sdk "$(winpath "$SDK_ROOT")" --board "$SDK_BOARD" --core "$SDK_CORE" --device "$SDK_DEVICE" \
  --gcc "$(winpath "$GCC_DIR")" --ninja "$(winpath "$NINJA")" --cmake "$(winpath "$CMAKE")" \
  --venv "$(winpath "$VENV/Scripts")" || die "could not write the project files"
fw_code_workspace "$APPDIR" ".=$APP"
[ $FILES_ONLY = 1 ] && exit 0

SDKW="$(cygpath -w "$SDK_ROOT")"
if [ $REG = 1 ]; then "$PYTHON" "$SKILL_DIR/scripts/mcux_app.py" register-sdk "$SDKW" || die "could not register the SDK"; fi
"$PYTHON" "$SKILL_DIR/scripts/mcux_app.py" sdk-registered "$SDKW" \
  || need_user SETUP "VS Code does not know the SDK $(winpath "$SDK_ROOT") yet: re-run open_ide.sh $APPDIR --register-sdk after the developer agrees (it edits the VS Code user settings), or MCUXpresso > Import Repository > Local > $(winpath "$SDK_ROOT")"
fw_open_ide "$APPDIR/$APP.code-workspace" $OPEN
cat <<'TXT'
  In VS Code (MCUXpresso for VS Code, Projects view):
    build         Build (or CMake: Build, F7) - preset debug, the same debug/ folder as build.sh
    flash + debug Debug (F5, "Debug" in .vscode/launch.json): LinkServer + MCU-Link, stops at main
    test          serial_test.py with the app's tests/*.json (planned), or any serial terminal on the MCU-Link VCOM (115200)
    hardware      pins/clocks: MCUXpresso Config Tools on the .mex in <board>_<core>/ - code goes in src/
TXT
