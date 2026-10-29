#!/usr/bin/env bash
# Stage 1: check the folder paths, the MCUXpresso SDK and the NXP build tools (MCUXpresso Installer:
# Arm GNU toolchain, Ninja, west venv) + Kitware CMake, LinkServer and the IDE for the FRDM-MCXN947.
# Usage: check_tools.sh <board-id> [--ws <workspace>]
#   --ws  workspace where apps are created (default: $MCX_WS)
# Read-only: never installs anything. Gate: "missing/bad=0".
# ST tools (cube-cmake, STM32CubeCLT CMake/Ninja/GCC) are reported as not usable, never picked.

. "$(dirname "$0")/env.sh"
BOARD=""; WS="$MCX_WS"
while [ $# -gt 0 ]; do
  case "$1" in --ws) WS="$2"; shift;; --*) die "unknown option $1";; *) BOARD="$1";; esac; shift
done
[ -n "$BOARD" ] || die "usage: check_tools.sh <board-id> [--ws <workspace>]  (boards: $(known_boards))"
load_board "$BOARD"

missing=0; warn=0
row()  { printf '%-8s %-30s %s\n' "$1" "$2" "$3"; }
ok()   { row "OK" "$1" "$2"; }
bad()  { row "BAD" "$1" "$2"; missing=$((missing+1)); }
wrn()  { row "WARN" "$1" "$2"; warn=$((warn+1)); }

echo "NXP MCX (MCUXpresso SDK + CMake) toolchain check  ($(date '+%Y-%m-%d %H:%M'))"
echo "----------------------------------------------------------------"

WSABS="$(mkdir -p "$WS" 2>/dev/null; cd "$WS" 2>/dev/null && pwd || echo "$WS")"
why="$(path_problem "$WSABS" 100)"
if [ -n "$why" ]; then bad "path: workspace" "$WSABS -> $why"; else ok "path: workspace" "$WSABS"; fi
svc="$(path_synced "$WSABS")"
[ -n "$svc" ] && wrn "path: workspace sync" "$svc folder: keep apps outside it: bash lib/fw_workspace.sh set $(fw_ws_suggest)"

# MCUXpresso SDK (west workspace, per-PC folder)
v="$(sdk_installed_version "$SDK_ROOT")"
if [ "$v" = "$SDK_VERSION" ]; then
  ok "MCUXpresso SDK" "$v  ($(fw_where "$SDK_ROOT"))"
  [ -d "$SDK_ROOT/mcuxsdk/examples/_boards/$SDK_BOARD" ] || bad "SDK board $SDK_BOARD" "not in $SDK_ROOT/mcuxsdk/examples - run: west update_board --set board $SDK_BOARD"
  [ -d "$SDK_ROOT/mcuxsdk/${SDK_EXAMPLE#examples/}" ] || [ -d "$SDK_ROOT/mcuxsdk/$SDK_EXAMPLE" ] || bad "SDK example" "$SDK_EXAMPLE missing in the SDK"
else
  bad "MCUXpresso SDK" "${v:+found $v, }$SDK_VERSION not at $(winpath "$SDK_ROOT") - install: west init -m https://github.com/nxp-mcuxpresso/mcuxsdk-manifests.git --mr v$SDK_VERSION $(winpath "$SDK_ROOT"), then in it: west update_board --set board $SDK_BOARD (or set MCUX_SDK_ROOT=<folder> in ~/.fw-skills.env)"
fi

# MCUXpresso Installer tools (LOCAL)
if [ -f "$GCC_BIN/arm-none-eabi-gcc.exe" ]; then ok "Arm GNU toolchain" "$GCC_VERSION  ($(fw_where "$GCC_DIR"))"
else bad "Arm GNU toolchain" "$GCC_VERSION not in $(winpath "$MCUX_TOOLS") - install it with the MCUXpresso Installer (Arm GNU Toolchain)"; fi
if [ -x "$NINJA" ]; then ok "Ninja" "$NINJA_VERSION  ($(fw_where "$NINJA"))"
else bad "Ninja" "$NINJA_VERSION not in $(winpath "$MCUX_TOOLS") - install it with the MCUXpresso Installer (or VS Code's MCUXpresso extension)"; fi
if [ -x "$WEST" ]; then ok "west (SDK commands)" "$("$WEST" --version 2>/dev/null | tr -d '\r' | sed 's/West version: //')  ($(fw_where "$VENV"))"
else bad "west (SDK commands)" "no MCUXpresso venv in $(winpath "$MCUX_TOOLS") - install the MCUXpresso SDK Developer pack with the MCUXpresso Installer"; fi

# Kitware CMake - never ST's
if [ -n "$CMAKE" ]; then
  cv="$(cmake_version "$CMAKE")"
  if [ "$(printf '%s\n%s\n' "$CMAKE_MIN" "$cv" | sort -V | head -1)" = "$CMAKE_MIN" ]; then ok "CMake (Kitware)" "$cv  ($(fw_where "$CMAKE"))"
  else bad "CMake (Kitware)" "$cv is older than $CMAKE_MIN - update CMake (cmake.org or the MCUXpresso Installer)"; fi
else
  bad "CMake (Kitware)" "not found - install CMake >= $CMAKE_MIN (cmake.org or the MCUXpresso Installer)"
fi
first="$(command -v cmake 2>/dev/null)"
[ -n "$first" ] && st_tool "$first" && wrn "PATH: first cmake is ST's" "$(winpath "$first") - not used by this skill (it always calls $(winpath "${CMAKE:-Kitware CMake}"))"

# LinkServer (board stages 4-7, planned in this skill)
if [ -n "$LINKSERVER_DIR" ] && [ -x "$LINKSERVER_DIR/LinkServer.exe" ]; then ok "LinkServer (board stages)" "$LINKSERVER_VERSION  ($(fw_where "$LINKSERVER_DIR"))"
else wrn "LinkServer (board stages)" "$LINKSERVER_VERSION not in C:/NXP - install LinkServer (MCUXpresso Installer or nxp.com); needed for flash/debug only"; fi

# python + pyserial (board tests)
if [ -n "$PYTHON" ]; then
  ok "python" "$("$PYTHON" --version 2>&1 | tr -d '\r')  ($(fw_scope "$PYTHON"))"
  if pv="$("$PYTHON" -c "import serial; print(serial.VERSION)" 2>/dev/null | tr -d '\r')"; then ok "pyserial" "$pv"
  else wrn "pyserial" "missing - python -m pip install pyserial (board tests only)"; fi
else
  wrn "python" "not found (new_app.sh needs it)"; missing=$((missing+1))
fi

# IDE path (stage 2d): VS Code + MCUXpresso for VS Code, and the SDK registered there
fw_check_ide
if [ -n "$PYTHON" ] && [ -n "$v" ]; then
  if "$PYTHON" "$SKILL_DIR/scripts/mcux_app.py" sdk-registered "$(cygpath -w "$SDK_ROOT")"; then ok "IDE: SDK registered" "mcuxpresso.sdks lists $(winpath "$SDK_ROOT")"
  else wrn "IDE: SDK registered" "VS Code does not know $(winpath "$SDK_ROOT") yet - open_ide.sh <app> --register-sdk (after the developer agrees: edits the VS Code user settings) or MCUXpresso > Import Repository > Local"; fi
fi

echo "----------------------------------------------------------------"
echo "missing/bad=$missing warnings=$warn"
[ $missing -eq 0 ] || need_user SETUP "fix the BAD items above (MCUXpresso SDK $SDK_VERSION / MCUXpresso Installer tools / Kitware CMake) - developer action; then re-run check_tools.sh"
