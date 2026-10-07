#!/usr/bin/env bash
# Stage 1: check the folder paths and the PlatformIO toolchain for the Pico 2 W skill.
# Usage: check_tools.sh <board-id> [--ws <workspace>]
#   --ws  workspace where apps are created (default: $PICO_WS)
# Read-only: never installs anything. Gate: "missing/bad=0".

. "$(dirname "$0")/env.sh"
BOARD=""; WS="$PICO_WS"
while [ $# -gt 0 ]; do
  case "$1" in --ws) WS="$2"; shift;; --*) die "unknown option $1";; *) BOARD="$1";; esac; shift
done
[ -n "$BOARD" ] || die "usage: check_tools.sh <board-id> [--ws <workspace>]  (boards: $(known_boards))"
load_board "$BOARD"

missing=0; warn=0
row()  { printf '%-8s %-28s %s\n' "$1" "$2" "$3"; }
ok()   { row "OK" "$1" "$2"; }
bad()  { row "BAD" "$1" "$2"; missing=$((missing+1)); }
wrn()  { row "WARN" "$1" "$2"; warn=$((warn+1)); }

echo "Pico 2 W (PlatformIO) toolchain check  ($(date '+%Y-%m-%d %H:%M'))"
echo "----------------------------------------------------------------"

WSABS="$(mkdir -p "$WS" 2>/dev/null; cd "$WS" 2>/dev/null && pwd || echo "$WS")"
for item in "workspace|$WSABS|100" "PlatformIO home|$PIO_HOME|60"; do
  IFS='|' read -r name p max <<<"$item"
  why="$(path_problem "$p" "$max")"
  if [ -n "$why" ]; then bad "path: $name" "$p -> $why"; else ok "path: $name" "$p"; fi
done
case "$WSABS" in *" "*) wrn "path: workspace" "contains a space - PlatformIO copes, some tools may not; prefer no spaces";; esac
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

# Pinned platform (installed on the first build)
want="${PIO_PLATFORM##*#}"; found=""
for d in "$PIO_HOME"/platforms/*/; do
  [ -d "$d/.git" ] || continue
  url="$(git -C "$d" config --get remote.origin.url 2>/dev/null)"
  case "$url" in *maxgerhardt/platform-raspberrypi*)
    head="$(git -C "$d" rev-parse HEAD 2>/dev/null)"; found="$found ${d%/}@${head:0:8}"
    [ "$head" = "$want" ] && found="MATCH ${d%/}";;
  esac
done
case "$found" in
  MATCH*) ok "platform raspberrypi (git)" "${want:0:8}  (${found#MATCH })";;
  "")     wrn "platform raspberrypi (git)" "not installed yet - the first build.sh downloads it + arduino-pico (~1.5 GB)";;
  *)      wrn "platform raspberrypi (git)" "installed at$found, profile pins ${want:0:8} - the first build installs the pinned one";;
esac
if [ -x "$PICOTOOL" ]; then
  ok "picotool" "$("$PICOTOOL" version 2>/dev/null | tr -d '\r' | head -1)"
else
  wrn "picotool" "not installed yet (comes with the platform on the first build)"
fi

# git (PlatformIO clones the platform and framework with it)
if command -v git >/dev/null; then
  ok "git" "$(git --version | sed 's/git version //')"
  case "$(uname -s)" in MINGW*|MSYS*|CYGWIN*)
    if [ "$(git config --get core.longpaths)" = true ]; then ok "git core.longpaths" "true"
    else wrn "git core.longpaths" "not set - the arduino-pico clone may fail on Windows; ask the user to run: git config --global core.longpaths true"; fi;;
  esac
else
  bad "git" "not found - install Git (Git for Windows)"
fi

# python + pyserial (discover, flash, tests)
if [ -n "$PYTHON" ]; then
  ok "python" "$("$PYTHON" --version 2>&1 | tr -d '\r')"
  if "$PYTHON" -c "import serial" 2>/dev/null; then ok "pyserial" "$("$PYTHON" -c 'import serial;print(serial.VERSION)')"
  else bad "pyserial" "missing - python -m pip install --user pyserial"; fi
else
  bad "python" "not found"
fi

# Boards connected now (information only)
devs="$(usb_devices 2>/dev/null | tr -d '\r')"
if [ -n "$devs" ]; then
  while read -r mode ser port pid; do ok "RP2 USB device" "$mode serial=$ser port=$port pid=$pid"; done <<<"$devs"
else
  wrn "RP2 USB device" "none connected (fine for create/build; needed for discover/flash/test)"
fi

echo "----------------------------------------------------------------"
echo "missing/bad=$missing warnings=$warn"
[ $missing -eq 0 ] || need_user SETUP "fix the BAD items above (install or update tools/packs/drivers, or move the workspace) - developer action; then re-run check_tools.sh"
