# Common environment for cubemx-hal-stm32f407disco scripts. Source it: . "$(dirname "$0")/env.sh"
# Windows + Git Bash: classic STM32CubeMX 6.x (headless script mode), the STM32CubeF4 firmware
# package from the CubeMX repository, and the pinned STM32Cube bundles (GCC, CMake, Ninja).
# Shared helpers (board lookup, paths, need_user/exit 10, .gitignore): <repo>/lib/common.sh

SKILL_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SKILL_NAME="$(basename "$SKILL_DIR")"           # cubemx-hal-stm32f407disco: profile subfolder in boards/<id>/
IDE_EXT=stmicroelectronics.stm32-vscode-extension   # stage 2d: VS Code extension that opens, builds, flashes and debugs the app
IDE_NAME="STM32CubeIDE for Visual Studio Code"
REPO_ROOT="$(cd "$SKILL_DIR/../.." && pwd)"
# shellcheck disable=SC1091
. "$REPO_ROOT/lib/common.sh" || { echo "ERROR: $REPO_ROOT/lib/common.sh missing - keep the repo layout" >&2; exit 1; }
PATH_EXAMPLE="C:/f4-ws"

# Where apps go (F4_WS): <repo>/apps inside the repo checkout, else ./apps.
F4_WS="${F4_WS:-$(fw_default_ws)}"
BENCH_DIR="${F4_BENCH_DIR:-$F4_WS/.bench}"
fw_init_boards "$F4_WS" "$F4_BOARDS_DIR"
PYTHON="${PYTHON:-$(command -v python || command -v python3)}"

# STM32CubeMX (classic): install folder, user settings, firmware repository
# per-machine install (Program Files) or per-user install (%LOCALAPPDATA%\Programs); CUBEMX_HOME overrides
if [ -z "$CUBEMX_HOME" ]; then
  for d in "/c/Program Files/STMicroelectronics/STM32Cube/STM32CubeMX"            "$(cygpath -u "${LOCALAPPDATA:-C:/nonexistent}" 2>/dev/null)/Programs/STM32CubeMX"; do
    [ -f "$d/STM32CubeMX.exe" ] && { CUBEMX_HOME="$d"; break; }
  done
  CUBEMX_HOME="${CUBEMX_HOME:-/c/Program Files/STMicroelectronics/STM32Cube/STM32CubeMX}"
fi
CUBEMX_EXE="$CUBEMX_HOME/STM32CubeMX.exe"
CUBEMX_JAVA="$CUBEMX_HOME/jre/bin/java.exe"
CUBEMX_USER="${CUBEMX_USER:-$HOME/.stm32cubemx}"
cubemx_installed_version() {
  sed -n 's/^SoftVersion=MX\.//p' "$CUBEMX_USER/plugins/updater/updater.ini" 2>/dev/null | tr -d '\r' | head -1
}
cubemx_repository() {
  local r; r="$(sed -n 's/^RepositoryPath=//p' "$CUBEMX_USER/plugins/updater/updater.ini" 2>/dev/null | tr -d '\r' | head -1)"
  [ -n "$r" ] && cygpath -u "$r" 2>/dev/null | sed 's:/*$::'
}
# fw_packages: installed firmware package versions in the CubeMX repository (e.g. "1.28.3")
fw_packages() {
  local r; r="$(cubemx_repository)"; [ -d "$r" ] || return 0
  for d in "$r/${FW_PACKAGE:-STM32Cube_FW_F4}"_V*/; do
    [ -d "$d" ] && basename "$d" | sed 's/.*_V//'
  done
}

# STM32Cube bundles (GCC, CMake, Ninja, Programmer) - installed with STM32Cube for VS Code / CubeMX2
if [ -z "$STM32CUBE_ROOT" ] && [ -n "$LOCALAPPDATA" ]; then STM32CUBE_ROOT="$(cygpath -u "$LOCALAPPDATA")/stm32cube"; fi

# load_board <id>: board profile + bench file, then the pinned tool paths
load_board() {
  fw_load_profile "$1"
  local B="$STM32CUBE_ROOT/bundles"
  GCC_BIN="$B/gnu-tools-for-stm32/$GCC_VERSION/bin"
  CMAKE_BIN="$B/cmake/$CMAKE_VERSION/bin"
  NINJA_BIN="$B/ninja/$NINJA_VERSION/bin"
  PROGRAMMER="$B/programmer/$PROGRAMMER_VERSION/bin/STM32_Programmer_CLI.exe"
  FW_DIR="$(cubemx_repository)/${FW_PACKAGE}_V$FW_VERSION"
  return 0
}

# cubemx_script <script-file> <log> [timeout-s]: run STM32CubeMX headless on a script (must end
# with "exit"). The .exe launcher detaches, so CubeMX's own java is run directly; after "exit" it
# prints "Bye bye" but its JVM stays alive - we wait for that line, then end the process tree.
# Returns 0 when "Bye bye" was seen, 1 otherwise. CubeMX's own log: $CUBEMX_USER/STM32CubeMX.log.
cubemx_script() {
  local script="$1" log="$2" max="${3:-600}" pid winpid end
  [ -x "$CUBEMX_JAVA" ] && [ -f "$CUBEMX_EXE" ] || die "STM32CubeMX not found under $CUBEMX_HOME - run check_tools.sh"
  : >"$log"
  ( cd "$CUBEMX_HOME" && exec "$CUBEMX_JAVA" -jar "$(winpath "$CUBEMX_EXE")" -q "$(winpath "$script")" ) >>"$log" 2>&1 &
  pid=$!; sleep 1; winpid="$(cat "/proc/$pid/winpid" 2>/dev/null)"
  end=$((SECONDS + max))
  while [ $SECONDS -lt $end ] && kill -0 "$pid" 2>/dev/null; do
    grep -q '^Bye bye' "$log" && break
    sleep 1
  done
  [ -n "$winpid" ] && taskkill //PID "$winpid" //T //F >/dev/null 2>&1
  kill "$pid" 2>/dev/null; wait "$pid" 2>/dev/null
  tr -d '\r' <"$log" >"$log.tmp" && mv "$log.tmp" "$log"
  grep -q '^Bye bye' "$log"
}

# mx_generate_lines <app-dir>: CubeMX commands that (re)generate <app>/mx from <app>/<app>.ioc.
# Paths are passed in Windows form (backslashes): with forward slashes CubeMX 6.18.1 builds wrong
# paths for syscalls.c/sysmem.c ("<project>\C:\...") and leaves them out of the project.
mx_generate_lines() {
  local app; app="$(basename "$1")"
  echo "config load $(cygpath -w "$1/$app.ioc")"
  echo "project name mx"
  echo "project toolchain CMake"
  echo "project path $(cygpath -w "$1")"
  echo "project generate"
}
# mx_check_log <log>: 0 when every script command answered OK, no file was lost, CubeMX exited
mx_check_log() {
  local ko lost
  ko="$(grep -c '^KO' "$1")"; lost="$(grep -c 'FileNotFoundException' "$1")"
  [ "$ko" -eq 0 ] || { echo "  $ko command(s) answered KO:"; grep -B1 '^KO' "$1" | grep -vE '^KO|^--' | sed 's/^/    /'; }
  [ "$lost" -eq 0 ] || echo "  $lost FileNotFoundException(s) - generated files missing"
  grep -q '^Bye bye' "$1" || echo "  CubeMX did not reach 'exit' (timeout or crash)"
  [ "$ko" -eq 0 ] && [ "$lost" -eq 0 ] && grep -q '^Bye bye' "$1"
}

# write_workspace_gitignore <workspace>: this skill's per-PC / regenerable files
write_workspace_gitignore() {
  # mx/ = CubeMX output (absolute per-PC paths, regenerated by regen.sh); keep <app>.ioc, src/, tests/
  # */.vscode/, */*.code-workspace: IDE files with per-PC paths, re-made by open_ide.sh / the extension
  fw_gitignore "$1" "$SKILL_NAME" ".bench/" "*/mx/" "*/.mx/" "*/logs/" "*/.vscode/" "*/*.code-workspace"
}
