#!/usr/bin/env bash
# Stage 2: create an NXP MCX app: the SDK example SDK_EXAMPLE exported as a freestanding CMake app
# (west export_app, board files copied in), trimmed to clocks + pin mux, plus the layered sources
# and the VS Code project files. Needs no hardware and no network.
# Usage: new_app.sh <board-id> <app-name> [<workspace-dir>] [template] [--no-open]
#   workspace-dir  where apps live (default: $MCX_WS, "" = default)
#   template       a folder under templates/ (default push-to-light); see help.sh for the list
# Writes <workspace>/<app>/:
#   CMakeLists.txt, prj.conf, Kconfig   the SDK app (project "app"; builds every .c/.h in src/)
#   <board>_<core>/   board_files.cmake, clock_config.*, pin_mux.*, .mex (MCUXpresso Config Tools)
#   src/              <repo>/lib/func (func/) + templates/_common/src (board/, main.c) + template
#   tests/            test specs                        mcx-app.env   record of what was used
#   CMakePresets.json (+ per-PC mcux_include.json, .vscode/)   build presets for build.sh and VS Code
# Gate: "Created ...". Then stage 2d: open_ide.sh checks VS Code + MCUXpresso for VS Code and opens
# the app (--no-open: no window, e.g. for headless runs).

. "$(dirname "$0")/env.sh"
OPEN=1; ARGS=()
for a in "$@"; do case "$a" in --no-open) OPEN=0;; *) ARGS+=("$a");; esac; done
set -- "${ARGS[@]}"
[ $# -ge 2 ] || die "usage: new_app.sh <board-id> <app-name> [<workspace-dir>] [template] [--no-open]"
load_board "$1"; APP="$2"; WS="${3:-$MCX_WS}"; TPL="${4:-push-to-light}"
require_vars BOARD_DEFINE SDK_VERSION SDK_BOARD SDK_CORE SDK_EXAMPLE SDK_BOARD_DIR SDK_PINMUX_DIR
case "$APP" in [A-Za-z]*) ;; *) die "app name '$APP' must start with a letter";; esac
case "$APP" in *[!A-Za-z0-9_-]*) die "app name '$APP': use letters, digits, - and _";; esac
[ -d "$SKILL_DIR/templates/$TPL" ] && [ "${TPL#_}" = "$TPL" ] \
  || die "no template '$TPL' (have: $(ls "$SKILL_DIR/templates" | grep -v '^_' | tr '\n' ' '))"
require_build_tools
[ -x "$WEST" ] || die "west (MCUXpresso venv) not found - run check_tools.sh"
[ -n "$PYTHON" ] || die "python not found - run check_tools.sh"

mkdir -p "$WS" || die "cannot create $WS"; WS="$(cd "$WS" && pwd)"; APPDIR="$WS/$APP"
fw_ws_choose "$WS" "$APPDIR" 100   # ACTION: CHOOSE when no workspace was chosen for this PC and apps/ is synced or too long
require_safe_path "$APPDIR" "app" 100
[ -e "$APPDIR" ] && die "$APPDIR already exists - pick another name (or delete it after asking the user)"
write_workspace_gitignore "$WS"

info "Creating $APPDIR (board $BOARD_ID, template $TPL)"
LOGDIR="$WS/.mcx-logs"; mkdir -p "$LOGDIR"; LOG="$LOGDIR/create-$APP-$(ts).log"
info "west export_app $SDK_EXAMPLE -b $SDK_BOARD -Dcore_id=$SDK_CORE --bf (SDK $SDK_VERSION; log $LOG)"
( cd "$SDK_ROOT/mcuxsdk" && export ARMGCC_DIR="$(winpath "$GCC_DIR")" PATH="$(dirname "$NINJA"):$(dirname "$CMAKE"):$PATH" \
  && "$WEST" export_app "$SDK_EXAMPLE" -b "$SDK_BOARD" -Dcore_id="$SDK_CORE" --bf -o "$(winpath "$APPDIR")" ) >"$LOG" 2>&1 \
  || { tail -5 "$LOG"; die "west export_app failed (log $LOG)"; }
[ -f "$APPDIR/CMakeLists.txt" ] || die "west export_app wrote no CMakeLists.txt (log $LOG)"
mkdir -p "$APPDIR/logs" && mv "$LOG" "$APPDIR/logs/" && rmdir "$LOGDIR" 2>/dev/null

"$PYTHON" "$SKILL_DIR/scripts/mcux_app.py" trim "$(winpath "$APPDIR")" "$SDK_BOARD_DIR" "$SDK_PINMUX_DIR" "$BOARD_DEFINE" \
  || die "trim of the exported app failed - the SDK layout may have changed"
mkdir -p "$APPDIR/src/func"
cp -r "$REPO_ROOT/lib/func/." "$APPDIR/src/func/"
for T in "$SKILL_DIR/templates/_common" "$SKILL_DIR/templates/$TPL"; do
  for part in src tests; do
    [ -d "$T/$part" ] && { mkdir -p "$APPDIR/$part"; cp -r "$T/$part/." "$APPDIR/$part/"; }
  done
done
[ -f "$APPDIR/src/app_main.c" ] || die "template $TPL has no src/app_main.c"

cat >"$APPDIR/mcx-app.env" <<EOF
# written by mcux-sdk-frdmmcxn947/new_app.sh $(date '+%Y-%m-%d %H:%M')
APP_BOARD=$BOARD_ID
APP_BOARD_DEFINE=$BOARD_DEFINE
APP_TEMPLATE=$TPL
APP_FROM="west export_app $SDK_EXAMPLE -b $SDK_BOARD -Dcore_id=$SDK_CORE --bf (MCUXpresso SDK $SDK_VERSION), trimmed"
APP_SDK_VERSION=$SDK_VERSION
EOF
bash "$SKILL_DIR/scripts/open_ide.sh" "$APPDIR" --files-only || die "could not write the project files"
info "Created $APPDIR  (board $BOARD_ID, template $TPL)"
info "Next: build.sh $APPDIR"
fw_new_app_ide "$APPDIR" $OPEN     # stage 2d: hand over to VS Code + MCUXpresso for VS Code
exit 0
