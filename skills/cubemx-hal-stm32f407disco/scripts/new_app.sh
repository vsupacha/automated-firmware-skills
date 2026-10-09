#!/usr/bin/env bash
# Stage 2b: create an STM32F4 app: hardware configuration (<app>.ioc) from the STM32CubeMX board
# configuration (MX_START) + the board profile's MX_CONFIG, the CubeMX-generated CMake project
# (mx/), the layered sources. Needs no hardware and no network.
# Usage: new_app.sh <board-id> <app-name> [<workspace-dir>] [template] [--no-open]
#   workspace-dir  where apps live (default: $F4_WS, "" = default)
#   template       a folder under templates/ (default push-to-light); see help.sh for the list
# Writes <workspace>/<app>/:
#   <app>.ioc      STM32CubeMX configuration - the source of truth for clocks/peripherals (commit it)
#   src/           <repo>/lib/func (func/) + templates/_common/src (board/, app_main.h) + template
#   tests/         test specs                        f4-app.env   record of what was used
#   <app>.code-workspace   VS Code workspace (mx/ as its own folder, for STM32CubeIDE for VS Code)
#   mx/            generated CMake project + overlay (regen.sh rewrites it; git-ignored)
# Gate: "REGEN: PASS" and "Created ...". Then stage 2d: open_ide.sh writes <app>.code-workspace, checks
# VS Code + STM32CubeIDE for VS Code and opens it (--no-open: no window, e.g. for headless runs).

. "$(dirname "$0")/env.sh"
OPEN=1; ARGS=()
for a in "$@"; do case "$a" in --no-open) OPEN=0;; *) ARGS+=("$a");; esac; done
set -- "${ARGS[@]}"
[ $# -ge 2 ] || die "usage: new_app.sh <board-id> <app-name> [<workspace-dir>] [template]"
load_board "$1"; APP="$2"; WS="${3:-$F4_WS}"; TPL="${4:-push-to-light}"
require_vars BOARD_DEFINE MX_START FW_VERSION CUBEMX_VERSION
case "$APP" in [A-Za-z]*) ;; *) die "app name '$APP' must start with a letter";; esac
case "$APP" in *[!A-Za-z0-9_-]*) die "app name '$APP': use letters, digits, - and _";; esac
[ -d "$SKILL_DIR/templates/$TPL" ] && [ "${TPL#_}" = "$TPL" ] \
  || die "no template '$TPL' (have: $(ls "$SKILL_DIR/templates" | grep -v '^_' | tr '\n' ' '))"
[ -d "$FW_DIR/Drivers" ] || die "no $FW_DIR - run check_tools.sh (firmware package)"
[ "$(cubemx_installed_version)" = "$CUBEMX_VERSION" ] || die "STM32CubeMX $CUBEMX_VERSION required - run check_tools.sh"

mkdir -p "$WS" || die "cannot create $WS"; WS="$(cd "$WS" && pwd)"; APPDIR="$WS/$APP"
require_safe_path "$APPDIR" "app" 100
[ -e "$APPDIR" ] && die "$APPDIR already exists - pick another name (or delete it after asking the user)"
write_workspace_gitignore "$WS"
svc="$(path_synced "$WS")"; [ -n "$svc" ] && echo "WARN: $WS is in a $svc folder - pause sync if generation fails on locked files"

info "Creating $APPDIR (board $BOARD_ID, template $TPL)"
mkdir -p "$APPDIR/src/func" "$APPDIR/.mx" "$APPDIR/logs"
cp -r "$REPO_ROOT/lib/func/." "$APPDIR/src/func/"
for T in "$SKILL_DIR/templates/_common" "$SKILL_DIR/templates/$TPL"; do
  for part in src tests; do
    [ -d "$T/$part" ] && { mkdir -p "$APPDIR/$part"; cp -r "$T/$part/." "$APPDIR/$part/"; }
  done
done
[ -f "$APPDIR/src/app_main.c" ] || die "template $TPL has no src/app_main.c"

LOG="$APPDIR/logs/create-$(ts).log"
{
  echo "$MX_START"
  echo "$MX_CONFIG" | tr ';' '\n' | sed 's/^ *//; /^$/d'
  echo "config saveas $(cygpath -w "$APPDIR/$APP.ioc")"
  mx_generate_lines "$APPDIR"
  echo "exit"
} >"$APPDIR/.mx/create.txt"
info "STM32CubeMX $CUBEMX_VERSION: $APP.ioc from '$MX_START' + MX_CONFIG, then generate mx/ (~2 min; log $LOG)"
cubemx_script "$APPDIR/.mx/create.txt" "$LOG" 600
if ! mx_check_log "$LOG" || [ ! -f "$APPDIR/$APP.ioc" ] || [ ! -f "$APPDIR/mx/Src/main.c" ]; then
  echo "REGEN: FAIL (see $LOG)"; exit 1
fi
"$PYTHON" "$SKILL_DIR/scripts/overlay.py" "$(winpath "$APPDIR/mx")" "$BOARD_DEFINE" || { echo "REGEN: FAIL (overlay)"; exit 1; }
fw_vscode_cube_setup "$APPDIR/mx"   # STM32CubeIDE for VS Code: open mx/ as a configured project
echo "REGEN: PASS ($APPDIR/mx)"

cat >"$APPDIR/f4-app.env" <<EOF
# written by cubemx-hal-stm32f407disco/new_app.sh $(date '+%Y-%m-%d %H:%M')
APP_BOARD=$BOARD_ID
APP_BOARD_DEFINE=$BOARD_DEFINE
APP_TEMPLATE=$TPL
APP_IOC_FROM="$MX_START + MX_CONFIG ($FW_PACKAGE V$FW_VERSION)"
APP_CUBEMX_VERSION=$CUBEMX_VERSION
EOF
info "Created $APPDIR  (board $BOARD_ID, template $TPL)"
info "Next: build.sh $APPDIR"
fw_new_app_ide "$APPDIR" $OPEN     # stage 2d: hand over to VS Code + STM32CubeIDE for VS Code
exit 0
