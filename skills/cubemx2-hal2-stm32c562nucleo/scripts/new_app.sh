#!/usr/bin/env bash
# Stage 2b: create an STM32CubeMX2 app for a board and generate its CMake project. No hardware and
# no network needed (packs come from the local STM32Cube pack folder).
# Usage: new_app.sh <board-id> <app-name> [<workspace-dir>] [template] [--ioc2 <file>] [--no-open]
#   workspace-dir  where apps live (default: $CUBE_WS, "" = default)
#   template       folder under templates/ (default uart-btn-led); see help.sh
#   --ioc2 <file>  start from an existing .ioc2 (e.g. your own hardware config) instead of the
#                  board default; it must target the profile's board/MCU
#   --no-open      stage 2d without a VS Code window (headless runs)
# Steps: 1. <app>/<app>.ioc2 = mx project create-from-board (pinned board pack) + MX_CONFIG
#        (peripherals enabled, e.g. USART2:Async) - or a copy of --ioc2
#        2. src/ (<repo>/lib/func + templates/_common + template) and tests/
#        3. regen.sh: generate <app>/mx (CMake) from a working copy, hook src/ into it
#        4. stage 2d open_ide.sh: <app>.code-workspace for VS Code + STM32CubeIDE for VS Code
# Writes <app>/cubemx-app.env (record of what was used).

. "$(dirname "$0")/env.sh"
POS=(); SRC_IOC2=""; OPEN=1
while [ $# -gt 0 ]; do
  case "$1" in --ioc2) SRC_IOC2="$2"; shift;; --no-open) OPEN=0;; --*) die "unknown option $1";; *) POS+=("$1");; esac; shift
done
[ ${#POS[@]} -ge 2 ] || die "usage: new_app.sh <board-id> <app-name> [<workspace-dir>] [template] [--ioc2 <file>] [--no-open]"
load_board "${POS[0]}"; APP="${POS[1]}"; WS="${POS[2]:-$CUBE_WS}"; TPL="${POS[3]:-uart-btn-led}"
require_vars BOARD_DEFINE MX_BOARD_CPN MX_BOARD_PACK_VERSION MX_VERSION
case "$APP" in *[!A-Za-z0-9_-]*|"") die "app name '$APP': use letters, digits, - and _";; esac
[ -d "$SKILL_DIR/templates/$TPL" ] && [ "${TPL#_}" = "$TPL" ] \
  || die "no template '$TPL' (have: $(ls "$SKILL_DIR/templates" | grep -v '^_' | tr '\n' ' '))"
[ -z "$SRC_IOC2" ] || [ -f "$SRC_IOC2" ] || die "no file $SRC_IOC2"

mkdir -p "$WS" || die "cannot create $WS"; WS="$(cd "$WS" && pwd)"; APPDIR="$WS/$APP"
require_safe_path "$APPDIR" "app" 110
[ -e "$APPDIR" ] && die "$APPDIR already exists - pick another name (or delete it after asking the user)"
write_workspace_gitignore "$WS"
svc="$(path_synced "$WS")"; [ -n "$svc" ] && echo "WARN: $WS is in a $svc folder - pause sync if generation/build fails on locked files"
mkdir -p "$APPDIR/logs" "$APPDIR/.mx"
IOC="$APPDIR/$APP.ioc2"

# 1. hardware configuration (.ioc2)
if [ -n "$SRC_IOC2" ]; then
  info "Using $SRC_IOC2 as the hardware configuration"
  cp "$SRC_IOC2" "$IOC"
  sed -i 's|"outputPath": *"[^"]*"|"outputPath": ""|' "$IOC"     # drop a stale absolute path
else
  info "STM32CubeMX2: create-from-board $MX_BOARD_CPN (board pack $MX_BOARD_PACK_VERSION)"
  mx_start "$APPDIR/.mx/mx-create.log"
  out="$(mx project create-from-board --cpn "$MX_BOARD_CPN" --pack-version "$MX_BOARD_PACK_VERSION" \
           --project-location "$(winpath "$APPDIR")" --project-name "$APP")"
  echo "$out" >"$APPDIR/logs/create.log"
  echo "$out" | mx_ok && [ -f "$IOC" ] || { mx_stop; die "create-from-board failed: $(echo "$out" | tail -5)"; }
  mx_stop
  if [ -n "$MX_CONFIG" ]; then
    info "Configuring: $MX_CONFIG"
    mx_start "$APPDIR/.mx/mx-config.log" "$IOC"
    for pair in $MX_CONFIG; do
      out="$(mx peripherals enable --project-path "$(winpath "$IOC")" --peripheral "${pair%%:*}" \
               --software-project "$APP" --mode "${pair#*:}")"
      echo "$out" >>"$APPDIR/logs/create.log"
      echo "$out" | mx_ok || { mx_stop; die "enable ${pair%%:*} (${pair#*:}) failed: $(echo "$out" | tail -4)"; }
    done
    out="$(mx project save --project-path "$(winpath "$IOC")")"
    echo "$out" | mx_ok || { mx_stop; die "project save failed: $out"; }
    mx_stop
  fi
fi
grep -q "$MX_BOARD_CPN" "$IOC" || echo "WARN: $IOC does not mention $MX_BOARD_CPN - is it for this board?"

# 2. layered code + tests
# shared logic layer <repo>/lib/func, then templates/_common (board/ layer), then the template
mkdir -p "$APPDIR/src/func" && cp -r "$REPO_ROOT/lib/func/." "$APPDIR/src/func/"
for T in "$SKILL_DIR/templates/_common" "$SKILL_DIR/templates/$TPL"; do
  for part in src tests; do
    [ -d "$T/$part" ] && { mkdir -p "$APPDIR/$part"; cp -r "$T/$part/." "$APPDIR/$part/"; }
  done
done
[ -f "$APPDIR/src/app_main.c" ] || die "template $TPL has no src/app_main.c"

cat >"$APPDIR/cubemx-app.env" <<EOF
# written by cubemx2-hal2-stm32c562nucleo/new_app.sh $(date '+%Y-%m-%d %H:%M')
APP_BOARD=$BOARD_ID
APP_BOARD_DEFINE=$BOARD_DEFINE
APP_TEMPLATE=$TPL
APP_IOC2=$APP.ioc2
APP_IOC2_SOURCE="${SRC_IOC2:+file $(basename "$SRC_IOC2")}${SRC_IOC2:-create-from-board $MX_BOARD_CPN pack $MX_BOARD_PACK_VERSION, $MX_CONFIG}"
APP_MX_VERSION=$MX_VERSION
EOF

# 3. generate + hook src/
bash "$SKILL_DIR/scripts/regen.sh" "$APPDIR" || die "regen.sh failed"
info "Created $APPDIR  (board $BOARD_ID, template $TPL)"
info "Next: build.sh $APPDIR"
fw_new_app_ide "$APPDIR" $OPEN     # stage 2d: hand over to VS Code + STM32CubeIDE for VS Code
