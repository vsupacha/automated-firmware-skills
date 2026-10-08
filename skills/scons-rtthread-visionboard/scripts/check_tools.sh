#!/usr/bin/env bash
# Stage 1: check the folder paths and the RT-Thread Studio toolchain (SDK, GNU Arm, env + scons,
# pyOCD + packs) for the Vision Board.
# Usage: check_tools.sh <board-id> [--ws <workspace>]
#   --ws  workspace where apps are created (default: $RTT_WS)
# Read-only: never installs anything. Gate: "missing/bad=0".

. "$(dirname "$0")/env.sh"
BOARD=""; WS="$RTT_WS"
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

echo "RT-Thread (scons + GNU Arm + pyOCD from RT-Thread Studio) toolchain check  ($(date '+%Y-%m-%d %H:%M'))"
echo "----------------------------------------------------------------"

WSABS="$(mkdir -p "$WS" 2>/dev/null; cd "$WS" 2>/dev/null && pwd || echo "$WS")"
why="$(path_problem "$WSABS" 100)"
if [ -n "$why" ]; then bad "path: workspace" "$WSABS -> $why"; else ok "path: workspace" "$WSABS"; fi
svc="$(path_synced "$WSABS")"
[ -n "$svc" ] && wrn "path: workspace sync" "$svc folder: apps are ~38 MB each (RT-Thread + FSP copied); pause sync if a build fails on locked files"

# RT-Thread Studio and what the profile pins from it
if [ -x "$STUDIO_EXE" ]; then
  why="$(path_problem "$RTT_STUDIO_HOME" 60)"
  ok "RT-Thread Studio" "$(fw_where "$RTT_STUDIO_HOME")"
  [ -z "$why" ] || wrn "path: RT-Thread Studio" "$why"
else
  bad "RT-Thread Studio" "not found (GLOBAL C:/RT-ThreadStudio or Program Files, LOCAL under the user profile; or set RTT_STUDIO_HOME) - install from www.rt-thread.io/studio.html"
fi
if [ -f "$BSP_DIR/projects/$BSP_PROJECT/SConstruct" ] && [ -d "$BSP_DIR/rt-thread" ]; then
  ok "SDK $BSP_NAME" "$BSP_VERSION ($BSP_PROJECT, RT-Thread $(sed -n 's/^#define RT_VERSION_\(MAJOR\|MINOR\|PATCH\) *\([0-9]*\).*/\2/p' "$BSP_DIR/rt-thread/include/rtdef.h" | paste -sd. -))"
else
  bad "SDK $BSP_NAME" "$BSP_VERSION not installed - RT-Thread Studio SDK Manager > Board_Support_Packages > $BSP_VENDOR > $BSP_NAME $BSP_VERSION"
fi
if [ -x "$GCC_BIN/arm-none-eabi-gcc.exe" ]; then
  ok "GNU Arm toolchain" "$("$GCC_BIN/arm-none-eabi-gcc" -dumpversion | tr -d '\r') (Studio package $GCC_VERSION)"
else
  bad "GNU Arm toolchain" "$GCC_VERSION missing - SDK Manager > ToolChain_Support_Packages > GNU_Tools_for_ARM_Embedded_Processors $GCC_VERSION"
fi
sv="$(scons_version)"
if [ -n "$sv" ]; then ok "RT-Thread env scons" "$sv"
else bad "RT-Thread env scons" "not found under $RTT_STUDIO_HOME/platform/env_released (part of RT-Thread Studio)"; fi
if [ -x "$PYOCD_DIR/pyocd.exe" ]; then
  pv="$(cd "$PYOCD_DIR" && ./pyocd.exe --version 2>/dev/null | tr -d '\r')"
  ok "pyOCD" "$pv (Studio package $PYOCD_VERSION)"
  if grep -q "Renesas.RA_DFP" "$PYOCD_DIR/pyocd.yaml" 2>/dev/null; then ok "pyOCD pack Renesas.RA_DFP" "$(grep -o 'Renesas.RA_DFP[^ ]*pack' "$PYOCD_DIR/pyocd.yaml" | tail -1)"
  else bad "pyOCD pack Renesas.RA_DFP" "not listed in $PYOCD_DIR/pyocd.yaml (needed for target $PYOCD_TARGET)"; fi
else
  bad "pyOCD" "$PYOCD_VERSION missing - SDK Manager > Debugger_Support_Packages > RealThread > PyOCD $PYOCD_VERSION"
fi

# python + pyserial (tests, probe port lookup)
if [ -n "$PYTHON" ]; then
  ok "python" "$("$PYTHON" --version 2>&1 | tr -d '\r')  ($(fw_scope "$PYTHON"))"
  if "$PYTHON" -c "import serial" 2>/dev/null; then ok "pyserial" "$("$PYTHON" -c 'import serial;print(serial.VERSION)')"
  else bad "pyserial" "missing - python -m pip install pyserial (needed by discover/test)"; fi
else
  bad "python" "not found (Python 3 with pyserial)"
fi

# Probes connected now (information only)
devs="$([ -x "$PYOCD_DIR/pyocd.exe" ] && probes 2>/dev/null)"
if [ -n "$devs" ]; then
  while read -r ser name; do ok "CMSIS-DAP probe" "$ser $name port=$(probe_port "$ser")"; done <<<"$devs"
else
  wrn "CMSIS-DAP probe" "none connected (fine for create/build; needed for discover/flash/test)"
fi

# IDE path (stage 2d): RT-Thread Studio is the IDE (checked above) - optional for the script path
if [ -x "$STUDIO_EXE" ]; then ok "IDE: $IDE_NAME" "$(winpath "$STUDIO_EXE")"
else wrn "IDE: $IDE_NAME" "missing - IDE path only"; fi

echo "----------------------------------------------------------------"
echo "missing/bad=$missing warnings=$warn"
[ $missing -eq 0 ] || need_user SETUP "fix the BAD items above (install tools in RT-Thread Studio, or move the workspace) - developer action; then re-run check_tools.sh"
