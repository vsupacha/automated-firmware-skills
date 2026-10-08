# Common environment for scons-rtthread-visionboard scripts. Source it: . "$(dirname "$0")/env.sh"
# Bash (Git Bash on Windows). Everything comes from an RT-Thread Studio install: the board's SDK
# (BSP + example projects), the GNU Arm toolchain, the RT-Thread env (Python 2.7 + scons) and
# RT-Thread's pyOCD build with the Renesas RA packs.
# Shared helpers (board lookup, paths, need_user/exit 10, .gitignore): <repo>/lib/common.sh

SKILL_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SKILL_NAME="$(basename "$SKILL_DIR")"           # scons-rtthread-visionboard: profile subfolder in boards/<id>/
# stage 2d: a standalone IDE instead of a VS Code extension (docs/workflow.md "IDE handoff")
IDE_APP=rt-thread-studio
IDE_NAME="RT-Thread Studio"
REPO_ROOT="$(cd "$SKILL_DIR/../.." && pwd)"
# shellcheck disable=SC1091
. "$REPO_ROOT/lib/common.sh" || { echo "ERROR: $REPO_ROOT/lib/common.sh missing - keep the repo layout" >&2; exit 1; }
PATH_EXAMPLE="C:/rtt-ws"

# Where apps go (RTT_WS): <repo>/apps inside the repo checkout, else ./apps.
# Bench files: this PC's probe serial (ART-Link unique id) + COM port of its VCP.
RTT_WS="${RTT_WS:-$(fw_default_ws)}"
BENCH_DIR="${RTT_BENCH_DIR:-$RTT_WS/.bench}"
STUDIO_WS="${RTT_STUDIO_WS:-$RTT_WS/.rtstudio}"     # Studio workspace (per PC metadata, git-ignored)
fw_init_boards "$RTT_WS" "$RTT_BOARDS_DIR"

# RT-Thread Studio: installed for all users (GLOBAL, e.g. C:/RT-ThreadStudio, Program Files) or
# per user (LOCAL, under the user profile). Override: RTT_STUDIO_HOME.
if [ -z "$RTT_STUDIO_HOME" ]; then
  RTT_STUDIO_HOME="$(fw_find_dirs /c/RT-ThreadStudio /d/RT-ThreadStudio "/c/Program Files/RT-ThreadStudio" \
                       "$FW_LOCALAPPDATA/Programs/RT-ThreadStudio" "$HOME/RT-ThreadStudio" \
                     | while IFS= read -r d; do [ -x "$d/studio.exe" ] && echo "$d"; done | tail -1)"
fi
STUDIO_EXE="$RTT_STUDIO_HOME/studio.exe"
STUDIO_CLI="$RTT_STUDIO_HOME/eclipsec.exe"
RTT_EXTRACT="$RTT_STUDIO_HOME/repo/Extract"
# scons: the env Studio itself runs (env-new: Python 3.11 venv + scons 4.x), else the classic env
# (Python 2.7 + scons 3.1.2)
RTT_ENV_NEW="$RTT_STUDIO_HOME/platform/env_released/env-new"
RTT_ENV_TOOLS="$RTT_STUDIO_HOME/platform/env_released/env/tools"
RTT_PY27="$RTT_ENV_TOOLS/Python27/python.exe"
RTT_SCONS_LIB="$RTT_ENV_TOOLS/Python27/Lib/site-packages/scons"
RTT_SCONS_EXE="$RTT_ENV_NEW/.venv/Scripts/scons.exe"
PYTHON="${PYTHON:-$(command -v python || command -v python3)}"

# load_board <id>: board profile + bench file, then env overrides; sets the SDK paths it pins
load_board() {
  fw_load_profile "$1"
  [ -n "$RTT_PROBE_SERIAL" ] && PROBE_SERIAL="$RTT_PROBE_SERIAL"
  [ -n "$RTT_CONSOLE" ] && CONSOLE_PORT="$RTT_CONSOLE"
  BSP_DIR="$RTT_EXTRACT/Board_Support_Packages/$BSP_VENDOR/$BSP_NAME/$BSP_VERSION"
  GCC_BIN="$RTT_EXTRACT/ToolChain_Support_Packages/ARM/GNU_Tools_for_ARM_Embedded_Processors/$GCC_VERSION/bin"
  PYOCD_DIR="$RTT_EXTRACT/Debugger_Support_Packages/RealThread/PyOCD/$PYOCD_VERSION"
  return 0
}

# scons_run <app-dir> <args...>: RT-Thread's scons with GCC (env-new as Studio, else env Python 2.7)
scons_run() {
  local app="$1"; shift
  if [ -x "$RTT_SCONS_EXE" ]; then
    ( cd "$app" && RTT_CC=gcc RTT_EXEC_PATH="$(cygpath -w "$GCC_BIN")" "$RTT_SCONS_EXE" "$@" )
  else
    ( cd "$app" && RTT_CC=gcc RTT_EXEC_PATH="$(cygpath -w "$GCC_BIN")" PYTHONPATH="$(cygpath -w "$RTT_SCONS_LIB")" \
        "$RTT_PY27" -c "import sys; sys.argv = ['scons'] + sys.argv[1:]; import SCons.Script; SCons.Script.main()" "$@" )
  fi
}
# scons_version: "4.10.0 (env-new, Python 3.11)" or "3.1.2 (env, Python 2.7)"
scons_version() {
  if [ -x "$RTT_SCONS_EXE" ]; then
    echo "$("$RTT_ENV_NEW/.venv/Scripts/python.exe" -c "import SCons; print(SCons.__version__)" 2>/dev/null | tr -d '\r') (env-new, $("$RTT_ENV_NEW/.venv/Scripts/python.exe" --version 2>&1 | tr -d '\r'))"
  elif [ -x "$RTT_PY27" ]; then
    echo "$("$RTT_PY27" -c "import sys; sys.path.insert(0, sys.argv[1]); import SCons; print(SCons.__version__)" "$(winpath "$RTT_SCONS_LIB")" 2>/dev/null | tr -d '\r') (env, Python 2.7)"
  fi
}

# pyocd_run <args...>: RT-Thread Studio's pyOCD, run in its folder (pyocd.yaml there lists the packs)
pyocd_run() {
  [ -x "$PYOCD_DIR/pyocd.exe" ] || die "pyOCD not found ($PYOCD_DIR) - run check_tools.sh"
  ( cd "$PYOCD_DIR" && ./pyocd.exe "$@" 2>&1 | tr -d '\r' | grep -v "Overlapping memory regions" )
}
# probes: one line per CMSIS-DAP probe pyOCD sees: "<unique-id> <name...>"
probes() {
  pyocd_run list 2>/dev/null | awk '/^ *[0-9]+ +/ { uid=""; for (i=2;i<=NF;i++) if ($i ~ /^[0-9A-Fa-f]{8,}$/) uid=$i;
                                                     if (uid!="") { n=$0; sub(/^ *[0-9]+ +/, "", n); sub(uid".*", "", n); gsub(/ +$/, "", n); print uid, n } }'
}
# probe_port <serial>: COM port of the probe's VCP (USB serial number = probe unique id)
probe_port() {
  [ -n "$1" ] || return 0
  "$PYTHON" - "$1" "${PROBE_VID:-0416}" <<'EOF' 2>/dev/null | tr -d '\r'
import sys
from serial.tools import list_ports
for p in list_ports.comports():
    if p.vid == int(sys.argv[2], 16) and (p.serial_number or "").upper() == sys.argv[1].upper():
        print(p.device); break
EOF
}
# identity <serial>: read-only attach (no halt, no reset): "key=value" lines cpuid, state
identity() {
  local out
  out="$(pyocd_run cmd -u "$1" -t "$PYOCD_TARGET" -f "${PYOCD_FREQ:-1000000}" \
           -O connect_mode=attach -c "read32 0xE000ED00" -c "status")"
  echo "$out" >"${IDENTITY_LOG:-/dev/null}"
  echo "cpuid=0x$(echo "$out" | sed -n 's/^e000ed00: *\([0-9a-fA-F]\{8\}\).*/\1/p' | head -1 | tr a-f A-F)"
  echo "state=$(echo "$out" | sed -n 's/^Core 0 ([^)]*): *//p' | head -1)"
}

# write_workspace_gitignore <workspace>: this skill's per-PC / regenerable files
write_workspace_gitignore() {
  # .rtstudio/: Studio workspace metadata (absolute paths, per PC); build outputs per app (Debug/ = Studio)
  fw_gitignore "$1" "$SKILL_NAME" ".bench/" ".rtstudio/" "*/build/" "*/logs/" "*/rtthread.elf" \
    "*/rtthread.hex" "*/rtthread.map" "*/app.hex" "*/.sconsign.dblite" "*/Debug/" "*/__pycache__/"
}
