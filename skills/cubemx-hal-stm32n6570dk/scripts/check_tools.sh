#!/usr/bin/env bash
# Stage 1: check the folder paths, STM32CubeMX (classic), the STM32CubeN6 firmware package and the
# pinned STM32Cube build bundles for the STM32N6570-DK skill.
# Usage: check_tools.sh <board-id> [--ws <workspace>]
#   --ws  workspace where apps are created (default: $N6_WS)
# Read-only: never installs anything. Gate: "missing/bad=0".

. "$(dirname "$0")/env.sh"
BOARD=""; WS="$N6_WS"
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

echo "STM32N6 (STM32CubeMX + STM32CubeN6 + CMake) toolchain check  ($(date '+%Y-%m-%d %H:%M'))"
echo "----------------------------------------------------------------"

WSABS="$(mkdir -p "$WS" 2>/dev/null; cd "$WS" 2>/dev/null && pwd || echo "$WS")"
why="$(path_problem "$WSABS" 100)"
if [ -n "$why" ]; then bad "path: workspace" "$WSABS -> $why"; else ok "path: workspace" "$WSABS"; fi
svc="$(path_synced "$WSABS")"
[ -n "$svc" ] && wrn "path: workspace sync" "$svc folder: pause sync if generation or a build fails on locked files"

# STM32CubeMX (classic, headless script mode through its bundled java)
if [ -f "$CUBEMX_EXE" ] && [ -x "$CUBEMX_JAVA" ]; then
  v="$(cubemx_installed_version)"
  if [ "$v" = "$CUBEMX_VERSION" ]; then ok "STM32CubeMX" "$v  ($(fw_where "$CUBEMX_HOME"))"
  else bad "STM32CubeMX" "found ${v:-unknown version}, profile pins $CUBEMX_VERSION - install/update STM32CubeMX $CUBEMX_VERSION"; fi
else
  bad "STM32CubeMX" "not found (GLOBAL: Program Files/STMicroelectronics/STM32Cube, LOCAL: %LOCALAPPDATA%/Programs) - install STM32CubeMX $CUBEMX_VERSION (or set CUBEMX_HOME)"
fi

# Firmware package in the CubeMX repository
REPO="$(cubemx_repository)"
if [ -d "$REPO" ]; then ok "CubeMX repository" "$(fw_where "$REPO")"; else bad "CubeMX repository" "not found (STM32CubeMX: Help > Updater Settings)"; fi
have="$(fw_packages | tr '\n' ' ')"
if [ -d "$FW_DIR/Drivers/STM32N6xx_HAL_Driver" ]; then
  ok "firmware ${FW_PACKAGE}" "V$FW_VERSION"
else
  bad "firmware ${FW_PACKAGE}" "V$FW_VERSION not installed${have:+ (have: $have)} - STM32CubeMX: Help > Manage embedded software packages > STM32N6 > $FW_VERSION > Install"
fi
[ -d "$FW_DIR/Drivers/BSP/STM32N6570-DK" ] && ok "BSP STM32N6570-DK" "in the firmware package"

# Build bundles (pinned)
for t in "GNU Tools for STM32|$GCC_BIN/arm-none-eabi-gcc.exe|$GCC_VERSION" "CMake|$CMAKE_BIN/cmake.exe|$CMAKE_VERSION" \
         "Ninja|$NINJA_BIN/ninja.exe|$NINJA_VERSION"; do
  IFS='|' read -r name exe ver <<<"$t"
  if [ -x "$exe" ]; then ok "$name" "$ver  ($(fw_scope "$exe"))"; else bad "$name" "$ver not found ($exe) - install the STM32Cube bundle (STM32Cube for VS Code / bundle manager)"; fi
done

# python (tests, M3)
if [ -n "$PYTHON" ]; then ok "python" "$("$PYTHON" --version 2>&1 | tr -d '\r')"; else wrn "python" "not found (needed for M3 tests only)"; fi

# IDE path (stage 2d): VS Code + STM32CubeIDE for VS Code - optional for the script path
fw_check_ide

echo "----------------------------------------------------------------"
echo "missing/bad=$missing warnings=$warn"
[ $missing -eq 0 ] || need_user SETUP "fix the BAD items above (install STM32CubeMX $CUBEMX_VERSION / the ${FW_PACKAGE} V$FW_VERSION package / STM32Cube bundles) - developer action; then re-run check_tools.sh"
