# Common environment for pio-arduino-rpipico2w scripts. Source it: . "$(dirname "$0")/env.sh"
# Bash (Git Bash on Windows, or Linux/macOS). PlatformIO and picotool are called by full path,
# so pio does not need to be on PATH (putting penv/Scripts on PATH shadows the system python).
# Shared helpers (board lookup, paths, need_user/exit 10, .gitignore): <repo>/lib/common.sh

SKILL_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SKILL_NAME="$(basename "$SKILL_DIR")"           # pio-arduino-rpipico2w: profile subfolder in boards/<id>/
IDE_EXT=platformio.platformio-ide   # stage 2d: VS Code extension that opens, builds, flashes and debugs the app
IDE_NAME="PlatformIO IDE"
REPO_ROOT="$(cd "$SKILL_DIR/../.." && pwd)"
# shellcheck disable=SC1091
. "$REPO_ROOT/lib/common.sh" || { echo "ERROR: $REPO_ROOT/lib/common.sh missing - keep the repo layout" >&2; exit 1; }
PATH_ALLOW_SPACES=1                             # PlatformIO copes with spaces (check_tools warns)
PATH_EXAMPLE="C:/pico-ws"

# Where apps go (PICO_WS): <repo>/apps inside the repo checkout, else ./apps.
# Bench files: this PC's USB serial (= chip ID) + COM port.
PICO_WS="${PICO_WS:-$(fw_default_ws)}"
BENCH_DIR="${PICO_BENCH_DIR:-$PICO_WS/.bench}"
fw_init_boards "$PICO_WS" "$PICO_BOARDS_DIR"

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
PICOTOOL="${PICOTOOL:-$(ls "$PIO_HOME"/packages/tool-picotool-rp2040-earlephilhower/picotool.exe \
                        "$PIO_HOME"/packages/tool-picotool-rp2040-earlephilhower/picotool 2>/dev/null | head -1)}"
PYTHON="${PYTHON:-$(command -v python || command -v python3)}"
export PLATFORMIO_NO_ANSI=1 PLATFORMIO_DISABLE_PROGRESSBAR=true
# pio prints tree characters; without UTF-8 its output crashes when piped on Windows (cp1252)
export PYTHONIOENCODING=utf-8

# load_board <id>: board profile + bench file, then env overrides
load_board() {
  fw_load_profile "$1"
  [ -n "$PICO_USB_SERIAL" ] && USB_SERIAL="$PICO_USB_SERIAL"
  [ -n "$PICO_CONSOLE" ] && CONSOLE_PORT="$PICO_CONSOLE"
  return 0
}

# usb_devices: one line per RP2 USB device of this VID: "<mode> <serial> <port-or-dash> <pid>"
#   mode = app (sketch with CDC port) | bootsel (ROM USB boot)
usb_devices() {
  "$PYTHON" - "${USB_VID:-2E8A}" "${USB_PID_BOOTSEL:-000F}" "${USB_PIDS_APP:-F00F}" <<'EOF'
import subprocess, sys
vid, boot_pid, app_pids = int(sys.argv[1], 16), int(sys.argv[2], 16), {int(p, 16) for p in sys.argv[3].split()}
seen = set()
try:
    from serial.tools import list_ports
    for p in list_ports.comports():
        if p.vid == vid and p.serial_number:
            mode = "app" if p.pid in app_pids else "other"
            print(mode, p.serial_number.upper(), p.device, f"{p.pid:04X}")
            seen.add(p.serial_number.upper())
except ImportError:
    print("ERROR pyserial missing", file=sys.stderr)
# BOOTSEL devices have no COM port: Windows PnP (the USB serial number is the chip ID)
if sys.platform == "win32":
    ps = ("Get-PnpDevice -PresentOnly | Where-Object { $_.InstanceId -match "
          f"'^USB\\\\VID_{vid:04X}&PID_{boot_pid:04X}\\\\' }} | ForEach-Object {{ $_.InstanceId }}")
    try:
        out = subprocess.run(["powershell", "-NoProfile", "-Command", ps], capture_output=True,
                             text=True, timeout=30).stdout
        for line in out.split():
            ser = line.rsplit("\\", 1)[-1].upper()
            if ser and ser not in seen:
                print("bootsel", ser, "-", f"{boot_pid:04X}")
    except Exception as e:
        print(f"WARN PnP query failed: {e}", file=sys.stderr)
EOF
}

# find_port <usb_serial>: COM port of the running sketch with this USB serial (or nothing)
find_port() {
  [ -n "$1" ] || return 0
  usb_devices 2>/dev/null | tr -d '\r' | awk -v s="$(echo "$1" | tr a-z A-Z)" '$1=="app" && $2==s {print $3; exit}'
}

# picotool_info <usb_serial>: device info of a board in BOOTSEL (empty if not in BOOTSEL)
picotool_info() {
  [ -x "$PICOTOOL" ] || die "picotool not found (installed with the platform on the first build: build.sh)"
  # --ser is case-sensitive: the USB serial is upper-case hex
  "$PICOTOOL" info -d --ser "$(echo "$1" | tr a-z A-Z)" 2>&1 | tr -d '\r'
}

# touch_1200 <port>: open the sketch's CDC port at 1200 baud -> arduino-pico reboots to BOOTSEL
touch_1200() {
  "$PYTHON" - "$1" <<'EOF'
import sys, time, serial
try:
    s = serial.Serial(sys.argv[1], 1200); time.sleep(0.2); s.close()
except serial.SerialException:
    pass   # the board usually re-enumerates before pyserial finishes configuring: expected
EOF
}

# wait_bootsel <usb_serial> <seconds>: wait until picotool sees the board in BOOTSEL
wait_bootsel() {
  local end=$((SECONDS + $2))
  while [ $SECONDS -lt $end ]; do
    picotool_info "$1" | grep -q '^ *type:' && return 0
    sleep 1
  done
  return 1
}

# wait_port <usb_serial> <seconds>: wait for the sketch's CDC port, print it
wait_port() {
  local end=$((SECONDS + $2)) p
  while [ $SECONDS -lt $end ]; do
    p="$(find_port "$1")"; [ -n "$p" ] && { echo "$p"; return 0; }
    sleep 1
  done
  return 1
}

# write_workspace_gitignore <workspace>: this skill's per-PC / regenerable files
write_workspace_gitignore() {
  # */.vscode/, */*.code-workspace: IDE files with per-PC paths, re-made by open_ide.sh / PlatformIO IDE
  fw_gitignore "$1" "$SKILL_NAME" ".bench/" "*/.pio/" "*/logs/" "*/.vscode/" "*/*.code-workspace"
}
