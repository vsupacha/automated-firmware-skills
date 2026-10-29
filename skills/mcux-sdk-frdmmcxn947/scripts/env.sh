# Common environment for mcux-sdk-frdmmcxn947 scripts. Source it: . "$(dirname "$0")/env.sh"
# Windows + Git Bash: the MCUXpresso SDK (GitHub west workspace), the tools of the MCUXpresso
# Installer (~/.mcuxpressotools: Arm GNU toolchain, Ninja, a Python venv with west), Kitware CMake,
# and LinkServer + the board's MCU-Link (SWD + VCOM) for the board stages.
# Rule: NXP apps are built with NXP's (or neutral Kitware) tools only - never with ST's
# cube-cmake / STM32CubeCLT CMake, Ninja or GCC, even when those come first on PATH.
# Shared helpers (board lookup, paths, need_user/exit 10, .gitignore): <repo>/lib/common.sh

SKILL_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SKILL_NAME="$(basename "$SKILL_DIR")"           # mcux-sdk-frdmmcxn947: profile subfolder in boards/<id>/
IDE_EXT=nxpsemiconductors.mcuxpresso            # stage 2d: VS Code extension that opens, builds, flashes and debugs the app
IDE_NAME="MCUXpresso for VS Code"
REPO_ROOT="$(cd "$SKILL_DIR/../.." && pwd)"
# shellcheck disable=SC1091
. "$REPO_ROOT/lib/common.sh" || { echo "ERROR: $REPO_ROOT/lib/common.sh missing - keep the repo layout" >&2; exit 1; }
PATH_EXAMPLE="C:/fw-ws"

# Where apps go (MCX_WS): the per-PC workspace (FW_WS / ~/.fw-skills.env, lib/fw_workspace.sh), else
# <repo>/apps inside the repo checkout, else ./apps.
MCX_WS="${MCX_WS:-$(fw_default_ws)}"
BENCH_DIR="${MCX_BENCH_DIR:-$MCX_WS/.bench}"
fw_init_boards "$MCX_WS" "$MCX_BOARDS_DIR"
PYTHON="${PYTHON:-$(command -v python || command -v python3)}"

# MCUXpresso Installer tools: LOCAL in the user profile (MCUX_TOOLS overrides)
MCUX_TOOLS="${MCUX_TOOLS:-$HOME/.mcuxpressotools}"

# st_tool <path>: true when the path belongs to an ST tool install (must never build an NXP app)
st_tool() {
  case "$(echo "$1" | tr 'A-Z' 'a-z')" in
    *stmicroelectronics*|*/st/stm32cube*|*stm32cubeclt*|*/stm32cube/*|*cube-cmake*|*gnu-tools-for-stm32*) return 0;;
  esac
  return 1
}

# find_cmake: Kitware CMake - MCUXpresso Installer copy first, then the user / system installs, then
# PATH; ST copies are skipped
find_cmake() {
  local c
  while IFS= read -r c; do
    [ -n "$c" ] && [ -x "$c" ] || continue
    st_tool "$c" && continue
    echo "$c"; return 0
  done < <(fw_find_dirs "$MCUX_TOOLS/cmake-*" | sort -rV | sed 's:$:/bin/cmake.exe:'
           echo "$FW_LOCALAPPDATA/Programs/CMake/bin/cmake.exe"; echo "/c/Program Files/CMake/bin/cmake.exe"
           which -a cmake 2>/dev/null)
  return 1
}
# cmake_version <cmake>: "4.1.0"
cmake_version() { "$1" --version 2>/dev/null | head -1 | tr -d '\r' | sed 's/^cmake version //'; }

# sdk_root_default: the per-PC SDK folder - MCUX_SDK_ROOT (environment or ~/.fw-skills.env), else
# C:/mcux-<major.minor> (e.g. C:/mcux-26.09)
sdk_root_default() {
  local s="$MCUX_SDK_ROOT"
  [ -n "$s" ] || s="$(sed -n 's/^MCUX_SDK_ROOT=//p' "$FW_SETTINGS" 2>/dev/null | tr -d '\r' | tail -1 | sed "s/^[\"']//; s/[\"']\$//")"
  [ -n "$s" ] || s="C:/mcux-${SDK_VERSION%.*}"
  if command -v cygpath >/dev/null 2>&1; then cygpath -u "$s"; else echo "$s"; fi
}
# sdk_installed_version <sdk-root>: "26.09.00" from mcuxsdk/MCUX_VERSION
sdk_installed_version() {
  local f="$1/mcuxsdk/MCUX_VERSION"
  [ -f "$f" ] || return 1
  tr -d '\r' <"$f" | awk -F' *= *' '/CURRENT_YEAR/{y=$2} /VERSION_MAJOR/{m=$2} /VERSION_MINOR/{n=$2} END{print y"."m"."n}'
}

# load_board <id>: board profile + bench file, then the pinned tool paths
load_board() {
  fw_load_profile "$1"
  [ -n "$MCX_PROBE_SERIAL" ] && PROBE_SERIAL="$MCX_PROBE_SERIAL"
  [ -n "$MCX_CONSOLE" ] && CONSOLE_PORT="$MCX_CONSOLE"
  GCC_DIR="$MCUX_TOOLS/arm-gnu-toolchain-$GCC_VERSION-mingw-w64-x86_64-arm-none-eabi"
  GCC_BIN="$GCC_DIR/bin"
  NINJA="$MCUX_TOOLS/ninja-$NINJA_VERSION/ninja.exe"
  VENV="$(fw_find_dirs "$MCUX_TOOLS/.mcux-venv-*" | tail -1)"
  WEST="$VENV/Scripts/west.exe"
  CMAKE="$(find_cmake)"
  SDK_ROOT="$(sdk_root_default)"
  LINKSERVER_DIR="$(fw_find_dirs "/c/NXP/LinkServer_$LINKSERVER_VERSION" "/c/nxp/LinkServer_$LINKSERVER_VERSION" | tail -1)"
  return 0
}

# require_build_tools: die unless the SDK and the NXP build tools are there (check_tools.sh lists them)
require_build_tools() {
  [ -f "$GCC_BIN/arm-none-eabi-gcc.exe" ] || die "Arm GNU $GCC_VERSION not found in $MCUX_TOOLS - run check_tools.sh"
  [ -x "$NINJA" ] || die "Ninja $NINJA_VERSION not found in $MCUX_TOOLS - run check_tools.sh"
  [ -n "$CMAKE" ] || die "Kitware CMake not found (ST's cube-cmake/CLT CMake are not used) - run check_tools.sh"
  [ "$(sdk_installed_version "$SDK_ROOT")" = "$SDK_VERSION" ] || die "MCUXpresso SDK $SDK_VERSION not found at $SDK_ROOT - run check_tools.sh"
}

# write_workspace_gitignore <workspace>: this skill's per-PC / regenerable files
write_workspace_gitignore() {
  # debug/ release/ build/: CMake build trees; .vscode/ + mcux_include.json: per-PC tool paths,
  # re-written by open_ide.sh; keep CMakeLists.txt, CMakePresets.json, the board files, src/, tests/
  fw_gitignore "$1" "$SKILL_NAME" ".bench/" "*/debug/" "*/release/" "*/build_tmp/" "*/logs/" \
    "*/.vscode/" "*/mcux_include.json" "*/*.code-workspace"
}
