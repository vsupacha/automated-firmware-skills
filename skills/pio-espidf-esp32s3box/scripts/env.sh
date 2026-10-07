# Common environment for pio-espidf-esp32s3box scripts. Source it: . "$(dirname "$0")/env.sh"
# Bash (Git Bash on Windows, or Linux/macOS). PlatformIO is called by full path, so pio does not
# need to be on PATH (putting penv/Scripts on PATH shadows the system python).
# Shared helpers (board lookup, paths, need_user/exit 10, .gitignore): <repo>/lib/common.sh

SKILL_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SKILL_NAME="$(basename "$SKILL_DIR")"           # pio-espidf-esp32s3box: profile subfolder in boards/<id>/
IDE_EXT=platformio.platformio-ide   # stage 2d: VS Code extension that opens, builds, flashes and debugs the app
IDE_NAME="PlatformIO IDE"
REPO_ROOT="$(cd "$SKILL_DIR/../.." && pwd)"
# shellcheck disable=SC1091
. "$REPO_ROOT/lib/common.sh" || { echo "ERROR: $REPO_ROOT/lib/common.sh missing - keep the repo layout" >&2; exit 1; }
PATH_EXAMPLE="C:/esp-ws"                        # ESP-IDF (CMake + ninja + its python env) breaks on spaces

# Where apps go (ESP_WS): <repo>/apps inside the repo checkout, else ./apps.
# Bench files: this PC's USB serial (= MAC address) + COM port.
ESP_WS="${ESP_WS:-$(fw_default_ws)}"
BENCH_DIR="${ESP_BENCH_DIR:-$ESP_WS/.bench}"
fw_init_boards "$ESP_WS" "$ESP_BOARDS_DIR"

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
  [ -n "$ESP_USB_SERIAL" ] && USB_SERIAL="$ESP_USB_SERIAL"
  [ -n "$ESP_CONSOLE" ] && CONSOLE_PORT="$ESP_CONSOLE"
  return 0
}

# usb_devices: one line per Espressif USB device of the profile's VID: "<serial> <port> <pid>"
# (pyserial from the system python, else from PlatformIO's own environment)
usb_devices() {
  local py="$PYTHON"
  "$py" -c "import serial" 2>/dev/null || py="$(dirname "$PIO")/python"
  "$py" - "${USB_VID:-303A}" <<'EOF'
import sys
from serial.tools import list_ports
vid = int(sys.argv[1], 16)
for p in list_ports.comports():
    if p.vid == vid:
        print((p.serial_number or "-").upper(), p.device, f"{p.pid:04X}")
EOF
}

# ---- esptool (M3) -----------------------------------------------------------------------------
# PlatformIO's python has pyserial + esptool's dependencies; esptool comes with the platform.
ESP_PY="${ESP_PY:-$(ls "$PIO_HOME/penv/Scripts/python.exe" "$PIO_HOME/penv/bin/python" 2>/dev/null | head -1)}"
ESPTOOL="$PIO_HOME/packages/tool-esptoolpy/esptool.py"
# esptool_run <port> <args...>: run esptool for this board's chip on a port (resets the chip)
esptool_run() {
  local port="$1"; shift
  [ -x "$ESP_PY" ] && [ -f "$ESPTOOL" ] || die "esptool not found ($ESPTOOL) - run build.sh once (installs the platform tools)"
  "$ESP_PY" "$(winpath "$ESPTOOL")" --chip "${IDF_TARGET:-esp32s3}" --port "$port" "$@" 2>&1 | tr -d '\r'
}
# norm_mac <mac>: upper-case hex with colons (USB serial of the USB Serial/JTAG = the MAC)
norm_mac() { echo "$1" | tr a-z A-Z | tr -d ' '; }
# find_port <usb_serial>: COM port of the board with this USB serial (or nothing)
find_port() {
  [ -n "$1" ] || return 0
  usb_devices 2>/dev/null | tr -d '\r' | awk -v s="$(norm_mac "$1")" '$1==s {print $2; exit}'
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
# identity <port>: esptool flash_id + get_security_info, as "key=value" lines:
#   chip, features, mac, flash, secure_boot, flash_crypt (read-only; resets the chip)
identity() {
  local out sec
  out="$(esptool_run "$1" --before default_reset --after hard_reset flash_id)"
  sec="$(esptool_run "$1" --before default_reset --after hard_reset get_security_info)"
  printf '%s\n%s\n' "$out" "$sec" >"${IDENTITY_LOG:-/dev/null}"
  echo "chip=$(echo "$out" | sed -n 's/^Chip is \(.*\)$/\1/p' | head -1)"
  echo "features=$(echo "$out" | sed -n 's/^Features: *//p' | head -1)"
  echo "mac=$(norm_mac "$(echo "$out" | sed -n 's/^MAC: *//p' | head -1)")"
  echo "flash=$(echo "$out" | sed -n 's/^Detected flash size: *//p' | head -1)"
  echo "secure_boot=$(echo "$sec" | sed -n 's/^Secure Boot: *//p' | head -1)"
  echo "flash_crypt=$(echo "$sec" | sed -n 's/^Flash Encryption: *//p' | head -1)"
}

# pio_pkg_version <package-dir-name>: installed version of a PlatformIO package (or nothing)
pio_pkg_version() {
  "$PYTHON" -c "import json,sys;print(json.load(open(sys.argv[1]))['version'])" \
    "$(winpath "$PIO_HOME/packages/$1/package.json")" 2>/dev/null | tr -d '\r'
}

# write_workspace_gitignore <workspace>: this skill's per-PC / regenerable files
write_workspace_gitignore() {
  # sdkconfig.<env> is generated from sdkconfig.defaults by every build; dependencies.lock is kept
  # */.vscode/, */*.code-workspace: IDE files with per-PC paths, re-made by open_ide.sh / PlatformIO IDE
  fw_gitignore "$1" "$SKILL_NAME" ".bench/" "*/.pio/" "*/logs/" "*/.vscode/" "*/*.code-workspace" "*/sdkconfig.*" "!*/sdkconfig.defaults" "*/managed_components/"
}
