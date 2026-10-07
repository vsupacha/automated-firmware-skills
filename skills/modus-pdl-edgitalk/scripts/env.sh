# Common environment for modus-pdl-edgitalk scripts. Source it: . "$(dirname "$0")/env.sh"
# Windows + Git Bash only (uses cygpath and the .exe tools of ModusToolbox for Windows).
# Run scripts from Git Bash or Claude's Bash tool - in PowerShell, "bash" may start WSL instead.
# Shared helpers (board lookup, paths, need_user/exit 10, .gitignore): <repo>/lib/common.sh

SKILL_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SKILL_NAME="$(basename "$SKILL_DIR")"           # modus-pdl-edgitalk: profile subfolder in boards/<id>/
IDE_EXT=infineonag.modustoolbox-for-vscode   # stage 2d: VS Code extension that opens, builds, flashes and debugs the app
IDE_NAME="Infineon ModusToolbox for VS Code"
REPO_ROOT="$(cd "$SKILL_DIR/../.." && pwd)"
# shellcheck disable=SC1091
. "$REPO_ROOT/lib/common.sh" || { echo "ERROR: $REPO_ROOT/lib/common.sh missing - keep the repo layout" >&2; exit 1; }
PATH_EXAMPLE="C:/pse84-ws"

# Where apps go (PSE84_WS): <repo>/apps inside the repo checkout, else ./apps. Backups go next to
# the workspace unless PSE84_BACKUP_DIR is set. Bench files: this PC's probe serial + COM port.
PSE84_WS="${PSE84_WS:-$(fw_default_ws)}"
PSE84_BACKUP_DIR="${PSE84_BACKUP_DIR:-$(dirname "$PSE84_WS")/backup}"
BENCH_DIR="${PSE84_BENCH_DIR:-$PSE84_WS/.bench}"
fw_init_boards "$PSE84_WS" "$PSE84_BOARDS_DIR"

# ModusToolbox installs per user (LOCAL: ~/ModusToolbox, ~/Infineon/Tools) or for all users
# (GLOBAL: C:/Program Files/ModusToolbox, C:/ModusToolbox, C:/Infineon/Tools) - one PC can mix them
# (e.g. Programming Tools GLOBAL, GCC LOCAL). The newest version wins, whatever its scope;
# CY_TOOLS_PATHS (ModusToolbox's own override) / MTB_TOOLS_DIR / PROGTOOLS_DIR pin a folder.
if [ -z "$MTB_TOOLS_DIR" ] && [ -n "$CY_TOOLS_PATHS" ]; then MTB_TOOLS_DIR="$(cygpath -u "$CY_TOOLS_PATHS")"; fi
if [ -z "$MTB_TOOLS_DIR" ]; then
  MTB_TOOLS_DIR="$(fw_find_dirs "/c/Program Files/ModusToolbox/tools_*" "/c/ModusToolbox/tools_*" \
                                "$HOME/ModusToolbox/tools_*" | tail -1)"
fi
INFINEON_TOOLS=("/c/Infineon/Tools" "$HOME/Infineon/Tools")      # GLOBAL, LOCAL
if [ -z "$PROGTOOLS_DIR" ]; then
  PROGTOOLS_DIR="$(fw_find_dirs "${INFINEON_TOOLS[0]}/ModusToolboxProgtools-*" "${INFINEON_TOOLS[1]}/ModusToolboxProgtools-*" | tail -1)"
fi
GCC_DIR="$(fw_find_dirs "${INFINEON_TOOLS[0]}/mtb-gcc-arm-eabi/*" "${INFINEON_TOOLS[1]}/mtb-gcc-arm-eabi/*" | tail -1)"
[ -d "$GCC_DIR/gcc/bin" ] && GCC_DIR="$GCC_DIR/gcc"   # Infineon installer layout: <ver>/gcc/bin
EDGEPROTECT_DIR="$(fw_find_dirs "${INFINEON_TOOLS[0]}/ModusToolbox-Edge-Protect-Security-Suite-*" \
                                "${INFINEON_TOOLS[1]}/ModusToolbox-Edge-Protect-Security-Suite-*" | tail -1)"

MODUS_BASH="$MTB_TOOLS_DIR/modus-shell/bin/bash.exe"
PROJECT_CREATOR="$MTB_TOOLS_DIR/project-creator/project-creator-cli.exe"
DEVICE_CONFIGURATOR="$MTB_TOOLS_DIR/device-configurator/device-configurator-cli.exe"
QSPI_CONFIGURATOR="$MTB_TOOLS_DIR/qspi-configurator/qspi-configurator-cli.exe"
OPENOCD_DIR="$PROGTOOLS_DIR/openocd"
OPENOCD="$OPENOCD_DIR/bin/openocd.exe"
FW_LOADER="$PROGTOOLS_DIR/fw-loader/bin/fw-loader.exe"
PYTHON="${PYTHON:-$(command -v python || command -v python3)}"
# OpenOCD must not grab fixed TCP ports (several boards / an open IDE debug session)
OPENOCD_NO_PORTS="gdb_port disabled; telnet_port disabled; tcl_port disabled"

# load_board <id>: board profile + bench file, then env overrides
load_board() {
  fw_load_profile "$1"
  [ -n "$PSE84_PROBE_SERIAL" ] && PROBE_SERIAL="$PSE84_PROBE_SERIAL"
  [ -n "$PSE84_CONSOLE" ] && CONSOLE_PORT="$PSE84_CONSOLE"
  return 0
}

# mtb_make <app_dir> <make args...>: run make inside modus-shell with the pinned tools dir
mtb_make() {
  local winapp; winapp="$(cygpath -m "$1")"; shift
  local tools; tools="$(cygpath -m "$MTB_TOOLS_DIR")"
  "$MODUS_BASH" --login -c "cd \"\$(cygpath -u '$winapp')\" && make $* CY_TOOLS_PATHS='$tools'"
}

# find_console_port <probe_serial>: print the COM port of that KitProg3's USB-UART (or nothing)
find_console_port() {
  [ -n "$1" ] || return 0
  "$PYTHON" - "$1" <<'EOF'
import sys
from serial.tools import list_ports
want = sys.argv[1].upper()
for p in list_ports.comports():
    if p.vid == 0x04B4 and (p.serial_number or "").upper() == want:
        print(p.device); break
EOF
}

# resolve_console: set CONSOLE (auto-detect by probe serial, fallback to bench CONSOLE_PORT)
resolve_console() {
  CONSOLE="$(find_console_port "$PROBE_SERIAL" 2>/dev/null | tr -d '\r')"
  [ -n "$CONSOLE" ] || CONSOLE="$CONSOLE_PORT"
}

# write_workspace_gitignore <workspace>: this skill's per-PC / regenerable files
write_workspace_gitignore() {
  # */.vscode/, */*.code-workspace: make vscode output with this PC's tool paths (open_ide.sh re-makes it)
  fw_gitignore "$1" "$SKILL_NAME" "mtb_shared/" ".cache/" ".bench/" "*/build/" "*/proj_*/build/" \
    "*/proj_*/libs/" "*/logs/" ".mtbqueryapi" ".ninja_log" "nsc_veneer.o" "*/.vscode/" "*/*.code-workspace"
}
