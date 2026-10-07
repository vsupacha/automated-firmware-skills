#!/usr/bin/env bash
# Stage 2c: regenerate <app>/mx from <app>/<app>.ioc with STM32CubeMX (headless), then re-apply the
# overlay (main.c hooks, FSBL/CMakeLists.txt sources). Run it after every .ioc change.
# Usage: regen.sh <app-dir>
# Gate: "REGEN: PASS" - every CubeMX command answered OK, no generated file lost, overlay applied.
# USER CODE sections of mx/ survive regeneration; anything else in mx/ is rewritten - never edit it.

. "$(dirname "$0")/env.sh"
APPDIR="$1"
[ -n "$APPDIR" ] && [ -f "$APPDIR/n6-app.env" ] || die "usage: regen.sh <app-dir>  (an app made by new_app.sh)"
APPDIR="$(cd "$APPDIR" && pwd)"; APP="$(basename "$APPDIR")"
require_safe_path "$APPDIR" "app" 100
# shellcheck disable=SC1091
. "$APPDIR/n6-app.env"
load_board "$APP_BOARD"
[ -f "$APPDIR/$APP.ioc" ] || die "no $APPDIR/$APP.ioc"
mkdir -p "$APPDIR/logs" "$APPDIR/.mx"; LOG="$APPDIR/logs/regen-$(ts).log"

{ mx_generate_lines "$APPDIR"; echo "exit"; } >"$APPDIR/.mx/regen.txt"
info "STM32CubeMX $CUBEMX_VERSION: generate mx/ from $APP.ioc (headless, ~2 min; log $LOG)"
cubemx_script "$APPDIR/.mx/regen.txt" "$LOG" 600
if ! mx_check_log "$LOG" || [ ! -f "$APPDIR/mx/FSBL/Src/main.c" ]; then
  echo "REGEN: FAIL (see $LOG and $CUBEMX_USER/STM32CubeMX.log)"; exit 1
fi
"$PYTHON" "$SKILL_DIR/scripts/overlay.py" "$(winpath "$APPDIR/mx")" "$APP_BOARD_DEFINE" || { echo "REGEN: FAIL (overlay)"; exit 1; }
fw_vscode_cube_setup "$APPDIR/mx"   # STM32CubeIDE for VS Code: open mx/ as a configured project
echo "REGEN: PASS ($APPDIR/mx)"
