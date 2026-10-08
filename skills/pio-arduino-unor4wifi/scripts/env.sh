# Common environment for pio-arduino-unor4wifi scripts. Source it: . "$(dirname "$0")/env.sh"
# Bash (Git Bash on Windows, or Linux/macOS). PlatformIO is called by full path, so pio does not
# need to be on PATH (putting penv/Scripts on PATH shadows the system python).
# Shared helpers (board lookup, paths, need_user/exit 10, .gitignore): <repo>/lib/common.sh

SKILL_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SKILL_NAME="$(basename "$SKILL_DIR")"           # pio-arduino-unor4wifi: profile subfolder in boards/<id>/
IDE_EXT=platformio.platformio-ide   # stage 2d: VS Code extension that opens, builds, flashes and debugs the app
IDE_NAME="PlatformIO IDE"
REPO_ROOT="$(cd "$SKILL_DIR/../.." && pwd)"
# shellcheck disable=SC1091
. "$REPO_ROOT/lib/common.sh" || { echo "ERROR: $REPO_ROOT/lib/common.sh missing - keep the repo layout" >&2; exit 1; }
PATH_EXAMPLE="C:/uno-ws"

# Where apps go (UNO_WS): <repo>/apps inside the repo checkout, else ./apps.
# Bench files: this PC's USB serial (of the board's ESP32-S3 USB bridge) + COM port.
UNO_WS="${UNO_WS:-$(fw_default_ws)}"
BENCH_DIR="${UNO_BENCH_DIR:-$UNO_WS/.bench}"
fw_init_boards "$UNO_WS" "$UNO_BOARDS_DIR"

# PlatformIO core dir and tools
PIO_HOME="${PLATFORMIO_CORE_DIR:-$HOME/.platformio}"
# PlatformIO Core: the VS Code extension / installer script's own penv (LOCAL), then PATH, then
# pip installs: per user (LOCAL %APPDATA%/Python/*/Scripts) or for all users (GLOBAL Program Files)
if [ -z "$PIO" ]; then
  for c in "$PIO_HOME/penv/Scripts/pio.exe" "$PIO_HOME/penv/bin/pio" "$(command -v pio 2>/dev/null)"; do
    [ -n "$c" ] && [ -x "$c" ] && { PIO="$c"; break; }
  done
fi
if [ -z "$PIO" ]; then
  PIO="$(fw_find_dirs "$(cygpath -u "${APPDATA:-$HOME/AppData/Roaming}" 2>/dev/null)/Python/Python3*/Scripts" \
                      "/c/Program Files/Python3*/Scripts" "/c/Python3*/Scripts" \
         | while IFS= read -r d; do [ -x "$d/pio.exe" ] && echo "$d/pio.exe"; done | tail -1)"
fi
PYTHON="${PYTHON:-$(command -v python || command -v python3)}"
export PLATFORMIO_NO_ANSI=1 PLATFORMIO_DISABLE_PROGRESSBAR=true
# pio prints tree characters; without UTF-8 its output crashes when piped on Windows (cp1252)
export PYTHONIOENCODING=utf-8

# load_board <id>: board profile + bench file, then env overrides
load_board() {
  fw_load_profile "$1"
  [ -n "$UNO_USB_SERIAL" ] && USB_SERIAL="$UNO_USB_SERIAL"
  [ -n "$UNO_CONSOLE" ] && CONSOLE_PORT="$UNO_CONSOLE"
  return 0
}

# usb_devices: one line per Arduino USB device of the profile's VID: "<serial> <port> <pid>"
# (pyserial from the system python, else from PlatformIO's own environment)
usb_devices() {
  local py="$PYTHON"
  "$py" -c "import serial" 2>/dev/null || py="$(dirname "$PIO")/python"
  "$py" - "${USB_VID:-2341}" <<'EOF'
import sys
from serial.tools import list_ports
vid = int(sys.argv[1], 16)
for p in list_ports.comports():
    if p.vid == vid:
        print((p.serial_number or "-").upper(), p.device, f"{p.pid:04X}")
EOF
}

# ---- bossac (flash) ---------------------------------------------------------------------------
# The UNO R4 WiFi's ESP32-S3 bridge programs the RA4M1: a 1200 baud "touch" of the COM port starts
# its SAM-BA style loader on the SAME port, bossac then talks to it (as PlatformIO's upload does).
PIO_PY="${PIO_PY:-$(ls "$PIO_HOME/penv/Scripts/python.exe" "$PIO_HOME/penv/bin/python" 2>/dev/null | head -1)}"
BOSSAC="$(ls "$PIO_HOME/packages/tool-bossac/bossac.exe" "$PIO_HOME/packages/tool-bossac/bossac" 2>/dev/null | head -1)"
# touch_1200 <port>: open + close the port at 1200 baud (the bridge resets the RA4M1 into its loader)
touch_1200() {
  local py="$PYTHON"
  "$py" -c "import serial" 2>/dev/null || py="$PIO_PY"
  "$py" - "$1" <<'PY'
import sys, time, serial
s = serial.Serial(sys.argv[1], 1200)
s.dtr = False
s.close()
time.sleep(0.5)
PY
}
# bossac_run <port> <args...>: bossac on the board's port (the loader must be active: touch_1200)
bossac_run() {
  local port="$1"; shift
  [ -n "$BOSSAC" ] && [ -x "$BOSSAC" ] || die "bossac not found ($PIO_HOME/packages/tool-bossac) - run build.sh once (installs the platform tools)"
  "$BOSSAC" --port="$port" --usb-port "$@" 2>&1 | tr -d '\r'
}
# norm_serial <serial>: upper-case, no spaces
norm_serial() { echo "$1" | tr a-z A-Z | tr -d ' '; }
# find_port <usb_serial>: COM port of the board with this USB serial (or nothing)
find_port() {
  [ -n "$1" ] || return 0
  usb_devices 2>/dev/null | tr -d '\r' | awk -v s="$(norm_serial "$1")" '$1==s {print $2; exit}'
}
# wait_port <usb_serial> <seconds>: wait for the board's port (after a reset), print it
wait_port() {
  local end=$((SECONDS + $2)) p
  while [ $SECONDS -lt $end ]; do
    p="$(find_port "$1")"; [ -n "$p" ] && { echo "$p"; return 0; }
    sleep 1
  done
  return 1
}
# identity <port>: 1200 baud touch -> bossac --info --reset, as "key=value" lines: device, loader,
# security, locked. Read-only (no erase/write); the RA4M1 restarts its sketch. Full output goes
# to $IDENTITY_LOG. "device" is the bridge's emulated placeholder, not the RA4M1 (see board.env).
identity() {
  local out
  touch_1200 "$1"; sleep 1
  out="$(bossac_run "$1" --info --reset)"
  echo "$out" >"${IDENTITY_LOG:-/dev/null}"
  echo "device=$(echo "$out" | sed -n 's/^Device *: *//p' | head -1)"
  echo "loader=$(echo "$out" | sed -n 's/^Version *: *//p' | head -1)"
  echo "security=$(echo "$out" | sed -n 's/^Security *: *//p' | head -1)"
  echo "locked=$(echo "$out" | sed -n 's/^Locked *: *//p' | head -1)"
}

# pio_pkg_version <package-dir-name>: installed version of a PlatformIO package (or nothing)
pio_pkg_version() {
  "$PYTHON" -c "import json,sys;print(json.load(open(sys.argv[1]))['version'])" \
    "$(winpath "$PIO_HOME/packages/$1/package.json")" 2>/dev/null | tr -d '\r'
}

# write_workspace_gitignore <workspace>: this skill's per-PC / regenerable files
write_workspace_gitignore() {
  # */.vscode/, */*.code-workspace: IDE files with per-PC paths, re-made by open_ide.sh / PlatformIO IDE
  fw_gitignore "$1" "$SKILL_NAME" ".bench/" "*/.pio/" "*/logs/" "*/.vscode/" "*/*.code-workspace"
}
