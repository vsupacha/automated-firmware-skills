#!/usr/bin/env bash
# Stage 1: check folder paths, the pinned STM32Cube bundles and CMSIS packs, python + pyserial,
# and list connected ST-LINKs. Read-only: never installs anything.
# Usage: check_tools.sh <board-id> [--ws <workspace>]
# Gate: "missing/bad=0".

. "$(dirname "$0")/env.sh"
BOARD=""; WS="$CUBE_WS"
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

echo "STM32C5 (STM32CubeMX2) toolchain check  ($(date '+%Y-%m-%d %H:%M'))"
echo "----------------------------------------------------------------"
WSABS="$(mkdir -p "$WS" 2>/dev/null; cd "$WS" 2>/dev/null && pwd || echo "$WS")"
for item in "workspace|$WSABS|100" "STM32Cube root|$STM32CUBE_ROOT|"; do
  IFS='|' read -r name p max <<<"$item"
  why="$(path_problem "$p" "$max")"
  if [ -n "$why" ]; then bad "path: $name" "$p -> $why"; else ok "path: $name" "$(fw_where "$p")"; fi
done
svc="$(path_synced "$WSABS")"
[ -n "$svc" ] && wrn "path: workspace sync" "$svc folder: pause sync if generation/build fails on locked files"
[ -d "$STM32CUBE_ROOT/bundles" ] || bad "STM32Cube bundles" "none under $STM32CUBE_ROOT - install STM32CubeMX2 (or the STM32Cube VS Code extension: LOCAL %LOCALAPPDATA%/stm32cube), or set STM32CUBE_ROOT to a shared GLOBAL copy"

# pinned bundles: exact version folder must exist; list what is there otherwise
bundle() {   # bundle <label> <tool-dir> <version> <file inside>
  local d="$STM32CUBE_ROOT/bundles/$2"
  if [ -e "$d/$3/$4" ]; then ok "$1" "$3  ($(fw_scope "$d"))"
  else bad "$1" "pinned $3 missing (installed: $(ls "$d" 2>/dev/null | tr '\n' ' ')) - install it with the STM32Cube bundle manager, or update the board profile after testing"; fi
}
bundle "STM32CubeMX2" stm32cubemx-application "$MX_VERSION" "dist/bin.js"
[ -x "$MX_NODE" ] && ok "node (bundled with MX)" "$NODE_VERSION" || bad "node (bundled with MX)" "$MX_NODE missing"
bundle "GNU Tools for STM32" gnu-tools-for-stm32 "$GCC_VERSION" "bin/arm-none-eabi-gcc.exe"
bundle "CMake" cmake "$CMAKE_VERSION" "bin/cmake.exe"
bundle "Ninja" ninja "$NINJA_VERSION" "bin/ninja.exe"
bundle "STM32CubeProgrammer CLI" programmer "$PROGRAMMER_VERSION" "bin/STM32_Programmer_CLI.exe"

# pinned packs
for pk in $PACKS; do
  d="$STM32CUBE_ROOT/packs/$pk"
  if ls "$d"/*.pdsc >/dev/null 2>&1; then ok "pack ${pk#*/}" "present"
  else bad "pack ${pk#*/}" "missing - open the board once in STM32CubeMX2 (or 'mx pack-manager') to install it"; fi
done

# python + pyserial
if [ -n "$PYTHON" ]; then
  ok "python" "$("$PYTHON" --version 2>&1 | tr -d '\r')  ($(fw_scope "$PYTHON"))"
  "$PYTHON" -c "import serial" 2>/dev/null && ok "pyserial" "$("$PYTHON" -c 'import serial;print(serial.VERSION)')" \
    || bad "pyserial" "missing - python -m pip install --user pyserial"
else
  bad "python" "not found"
fi

# ST-LINKs connected now (information only)
if [ -x "$PROGRAMMER" ]; then
  sns="$(probe_serials)"
  if [ -n "$sns" ]; then
    for sn in $sns; do ok "ST-LINK" "$sn  VCP=$(find_console_port "$sn" | tr -d '\r')"; done
  else
    wrn "ST-LINK" "none connected (fine for create/build; needed for discover/flash/test)"
  fi
fi

# IDE path (stage 2d): VS Code + STM32CubeIDE for VS Code - optional for the script path
fw_check_ide

echo "----------------------------------------------------------------"
echo "missing/bad=$missing warnings=$warn"
[ $missing -eq 0 ] || need_user SETUP "fix the BAD items above (install or update tools/packs/drivers, or move the workspace) - developer action; then re-run check_tools.sh"
