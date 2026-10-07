#!/usr/bin/env bash
# Regenerate <app>/mx (the STM32CubeMX2 CMake project) from <app>/<app>.ioc2 and hook the layered
# code (src/) into it. Run after every change to the .ioc2 (GUI or CLI). new_app.sh calls it.
# Usage: regen.sh <app-dir>
# - generates from a working copy (<app>/.mx/<app>.ioc2): CubeMX2 writes the absolute destination
#   into the project it generates, which must not end up in the shareable <app>.ioc2
#   (the copy keeps the app's file name: CubeMX2 names the software project after it)
# - --diff overwrite: everything under mx/ is CubeMX-owned and rewritten; never edit it - put
#   code in src/ (the hook into main.c and CMakeLists.txt is re-applied here every time)
# Gate: "REGEN: PASS".

. "$(dirname "$0")/env.sh"
APPDIR="$1"
[ -n "$APPDIR" ] && [ -f "$APPDIR/cubemx-app.env" ] || die "usage: regen.sh <app-dir>  (an app made by new_app.sh)"
APPDIR="$(cd "$APPDIR" && pwd)"
# shellcheck disable=SC1091
. "$APPDIR/cubemx-app.env"
load_board "$APP_BOARD"
require_safe_path "$APPDIR" "app" 110
IOC="$APPDIR/$APP_IOC2"; [ -f "$IOC" ] || die "missing $IOC"
APP="$(basename "$APPDIR")"
mkdir -p "$APPDIR/.mx" "$APPDIR/logs"
LOG="$APPDIR/logs/regen-$(ts).log"

if grep -qE '"outputPath": *"[A-Za-z]:' "$IOC"; then
  echo "NOTE: $APP_IOC2 holds an absolute outputPath (saved by the GUI) - clearing it"
  sed -i 's|"outputPath": *"[^"]*"|"outputPath": ""|' "$IOC"
fi
before="$(sha256sum "$IOC" | cut -d' ' -f1)"
# same file name as the app: CubeMX2 names the software project / ELF after it
WORK="$APPDIR/.mx/$APP_IOC2"; cp "$IOC" "$WORK"

info "STM32CubeMX2 $MX_VERSION: generate CMake project into mx/  (log $LOG)"
mx_start "$APPDIR/.mx/mx-regen.log" "$WORK"
SW="$(mx project get-sw-project-list --project-path "$(winpath "$WORK")" | sed -n 's/.*"name": *"\([^"]*\)".*/\1/p' | head -1)"
[ -n "$SW" ] || { mx_stop; die "no software project in $APP_IOC2"; }
out="$(mx ide-project generate --project-path "$(winpath "$WORK")" --software-project "$SW" \
         --build-target "$BUILD_TARGET" --destination "$(winpath "$APPDIR/mx")" --format CMake \
         --source include-packs-from-local --force --remove-board --diff overwrite)"
echo "$out" >"$LOG"
mx_stop
echo "$out" | mx_ok || die "generation failed: $(echo "$out" | tail -5)"

after="$(sha256sum "$IOC" | cut -d' ' -f1)"
[ "$before" = "$after" ] || die "$APP_IOC2 changed during generation - it must stay untouched"
grep -qE '"outputPath": *"[A-Za-z]:' "$IOC" && die "$APP_IOC2 now holds an absolute path"

info "Hooking src/ into mx/ (main.c -> app_main(), CMakeLists.txt -> ../src, -D$BOARD_DEFINE)"
"$PYTHON" "$SKILL_DIR/scripts/overlay.py" "$APPDIR/mx" --define "$BOARD_DEFINE" >>"$LOG" 2>&1 \
  || { tail -5 "$LOG"; die "overlay failed - the generated main.c/CMakeLists.txt markers changed (new STM32CubeMX2?)"; }

sed -i '/^APP_SW_PROJECT=/d; /^APP_PRESET=/d' "$APPDIR/cubemx-app.env"
printf 'APP_SW_PROJECT=%s\nAPP_PRESET=%s\n' "$SW" "$PRESET" >>"$APPDIR/cubemx-app.env"
echo "REGEN: PASS (software project $SW, preset $PRESET)"
