#!/usr/bin/env bash
# Stage 1: check the folder paths and the PlatformIO + ESP-IDF toolchain for the ESP32-S3 skill.
# Usage: check_tools.sh <board-id> [--ws <workspace>]
#   --ws  workspace where apps are created (default: $ESP_WS)
# Read-only: never installs anything. Gate: "missing/bad=0".

. "$(dirname "$0")/env.sh"
BOARD=""; WS="$ESP_WS"
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

echo "ESP32-S3 (PlatformIO + ESP-IDF) toolchain check  ($(date '+%Y-%m-%d %H:%M'))"
echo "----------------------------------------------------------------"

WSABS="$(mkdir -p "$WS" 2>/dev/null; cd "$WS" 2>/dev/null && pwd || echo "$WS")"
for item in "workspace|$WSABS|100" "PlatformIO home|$PIO_HOME|60"; do
  IFS='|' read -r name p max <<<"$item"
  why="$(path_problem "$p" "$max")"
  if [ -n "$why" ]; then bad "path: $name" "$p -> $why"; else ok "path: $name" "$p"; fi
done
svc="$(path_synced "$WSABS")"
[ -n "$svc" ] && wrn "path: workspace sync" "$svc folder: pause sync if a build fails on locked files"

# PlatformIO Core
if [ -n "$PIO" ] && [ -x "$PIO" ]; then
  v="$("$PIO" --version 2>/dev/null | tr -d '\r' | sed 's/.*version //')"
  ok "PlatformIO Core" "$v  ($PIO)"
  case "$v" in "$PIO_VERSION"*) ;; *) wrn "PlatformIO vs profile" "profile proven with $PIO_VERSION.x, found $v";; esac
else
  bad "PlatformIO Core" "not found - install: python -m pip install -U platformio (or the VS Code PlatformIO extension)"
fi

# Pinned platform + the packages it pins (installed on the first build if missing)
want="${PIO_PLATFORM##*@}"; pname="${PIO_PLATFORM%@*}"; pname="${pname##*/}"
have="$("$PYTHON" -c "import json,sys;print(json.load(open(sys.argv[1]))['version'])" \
        "$(winpath "$PIO_HOME/platforms/$pname/platform.json")" 2>/dev/null | tr -d '\r')"
if [ "$have" = "$want" ]; then ok "platform $pname" "$have"
elif [ -n "$have" ]; then wrn "platform $pname" "installed $have, profile pins $want - the first build installs $want"
else wrn "platform $pname" "not installed yet - the first build.sh downloads $want + ESP-IDF (~2 GB)"; fi
# ESP-IDF 5.x builds with the GCC 14 "esp-elf" toolchain (toolchain-xtensa-esp32s3 is the old GCC 8 of Arduino 2.x)
for pkg in framework-espidf toolchain-xtensa-esp-elf tool-esptoolpy tool-cmake tool-ninja; do
  pv="$(pio_pkg_version "$pkg")"
  if [ -n "$pv" ]; then ok "package $pkg" "$pv"; else wrn "package $pkg" "not installed yet (comes with the first build)"; fi
done

# git (PlatformIO / ESP-IDF fetch components with it)
if command -v git >/dev/null; then
  ok "git" "$(git --version | sed 's/git version //')"
  case "$(uname -s)" in MINGW*|MSYS*|CYGWIN*)
    if [ "$(git config --get core.longpaths)" = true ]; then ok "git core.longpaths" "true"
    else wrn "git core.longpaths" "not set - long ESP-IDF paths may fail on Windows; ask the user to run: git config --global core.longpaths true"; fi;;
  esac
else
  bad "git" "not found - install Git (Git for Windows)"
fi

# python + pyserial (discover, flash, tests - M3; not needed to create/build)
if [ -n "$PYTHON" ]; then
  ok "python" "$("$PYTHON" --version 2>&1 | tr -d '\r')"
  if "$PYTHON" -c "import serial" 2>/dev/null; then ok "pyserial" "$("$PYTHON" -c 'import serial;print(serial.VERSION)')"
  else wrn "pyserial" "missing - needed for discover/flash/test (M3): python -m pip install --user pyserial"; fi
else
  bad "python" "not found"
fi

# Boards connected now (information only)
devs="$(usb_devices 2>/dev/null | tr -d '\r')"
if [ -n "$devs" ]; then
  while read -r ser port pid; do ok "Espressif USB device" "serial=$ser port=$port pid=$pid"; done <<<"$devs"
else
  wrn "Espressif USB device" "none connected (fine for create/build; needed for discover/flash/test)"
fi

echo "----------------------------------------------------------------"
echo "missing/bad=$missing warnings=$warn"
[ $missing -eq 0 ] || need_user SETUP "fix the BAD items above (install or update tools, or move the workspace) - developer action; then re-run check_tools.sh"
