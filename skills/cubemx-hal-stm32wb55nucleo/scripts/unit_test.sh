#!/usr/bin/env bash
# Stage 6 (test: unit tests on the board, prototype): Unity suites of the app's func/ code, built
# into a separate image of the same CubeMX project and run on the NUCLEO-WB55RG.
# Usage: unit_test.sh <app-dir> [--yes] [--build-only | --read-only] [--timeout <s>]
#   --yes         flash the unit-test image (only after the user agreed - it replaces the app on
#                 the board), unless the developer wrote FLASH_POLICY=auto into the bench file
#   --build-only  build the test image and stop (no board needed)
#   --read-only   only read the results of the test image already on the board (press RESET
#                 first: a finished run sends nothing more) - no build, no flash
# Steps: 0. the app gets <app>/test/unity (pinned copy of <repo>/lib/unity, always refreshed) and,
#        when missing, the runner + suites from <repo>/lib/test_func and func/ modules the suites
#        need from <repo>/lib/func or lib/func_dsp; overlay.py adds the FW_UNIT switch to mx/CMakeLists.txt ->
#        1. CMake build of mx/ with -DFW_UNIT=ON into mx/build/Unit (test/*.c replace
#        src/app_main.c), 0 warnings in src/ and test/ (Unity's own file is not counted), manifest ->
#        2. flash.sh --yes --elf mx/build/Unit/mx.elf (identity gates) -> 3. <repo>/lib/unity_read.py
#        on the bench console port: the image waits for a start byte, the reader sends it.
# After the run the board keeps the unit-test image: flash.sh <app> --yes restores the app.
# Gates: "UNIT-BUILD: PASS" (image sha256), "UNIT: PASS (n/n)" / "UNIT: FAIL (...)".
# Exit 0 PASS, 1 FAIL, 2 warnings in src/ or test/, 10 = developer action (approve, connect).

. "$(dirname "$0")/env.sh"
APPDIR=""; YES=0; BUILD_ONLY=0; READ_ONLY=0; TMO=60
while [ $# -gt 0 ]; do
  case "$1" in --yes) YES=1;; --build-only) BUILD_ONLY=1;; --read-only) READ_ONLY=1;;
    --timeout) TMO="$2"; shift;; --*) die "unknown option $1";; *) APPDIR="$1";; esac; shift
done
[ -n "$APPDIR" ] && [ -f "$APPDIR/wb-app.env" ] || die "usage: unit_test.sh <app-dir> [--yes] [--build-only | --read-only]  (an app made by new_app.sh)"
APPDIR="$(cd "$APPDIR" && pwd)"; APP="$(basename "$APPDIR")"
# shellcheck disable=SC1091
. "$APPDIR/wb-app.env"
load_board "$APP_BOARD"
mkdir -p "$APPDIR/logs"; LOG="$APPDIR/logs/unit-$(ts).log"
UDIR="$APPDIR/mx/build/Unit"; UELF="$UDIR/mx.elf"

read_results() {
  require_milestone M1 "unit_test.sh (stage 6 test on the board)"
  resolve_console
  [ -n "$CONSOLE" ] || need_user CONNECT "no console port for board '$BOARD_ID' - run discover.sh first"
  info "Reading Unity output on $CONSOLE (log $LOG)"
  out="$("$PYTHON" "$REPO_ROOT/lib/unity_read.py" "$CONSOLE" "$LOG" --timeout "$TMO")"; rc=$?
  echo "$out"
  sum="$(echo "$out" | sed -n 's/^UNITY: \([0-9]*\) \([0-9]*\) \([0-9]*\)$/\1 \2 \3/p')"
  if [ -z "$sum" ]; then
    echo "UNIT: FAIL (no Unity summary within ${TMO} s - board running the test image? press RESET and use --read-only)"; exit 1
  fi
  set -- $sum
  if [ $rc -eq 0 ] && [ "$1" -gt 0 ]; then echo "UNIT: PASS ($(( $1 - $3 ))/$1, $3 ignored)"; exit 0; fi
  echo "UNIT: FAIL ($2 of $1 failed, $3 ignored; log $LOG)"; exit 1
}
[ $READ_ONLY = 1 ] && read_results

# 0. test sources in the app
mkdir -p "$APPDIR/test/unity"
cp "$REPO_ROOT"/lib/unity/unity.c "$REPO_ROOT"/lib/unity/unity.h "$REPO_ROOT"/lib/unity/unity_internals.h "$APPDIR/test/unity/"
for f in "$REPO_ROOT"/lib/test_func/*.[ch]; do
  [ -f "$APPDIR/test/$(basename "$f")" ] || { cp "$f" "$APPDIR/test/"; echo "added test/$(basename "$f")"; }
done
for m in gesture fxscale; do                    # lib/func (every new app has it) or lib/func_dsp (opt-in)
  for x in h c; do
    src="$REPO_ROOT/lib/func/$m.$x"; [ -f "$src" ] || src="$REPO_ROOT/lib/func_dsp/$m.$x"
    [ -f "$APPDIR/src/func/$m.$x" ] || { cp "$src" "$APPDIR/src/func/"; echo "added src/func/$m.$x"; }
  done
done
"$PYTHON" "$SKILL_DIR/scripts/overlay.py" "$APPDIR/mx" "$APP_BOARD_DEFINE" >/dev/null || die "overlay.py failed on $APPDIR/mx"

# 1. build the unit-test image
export PATH="$GCC_BIN:$CMAKE_BIN:$NINJA_BIN:$PATH"
info "cmake -DFW_UNIT=ON into mx/build/Unit  (log $LOG)"
( cd "$APPDIR/mx" && cmake -S . -B build/Unit -G Ninja -DCMAKE_TOOLCHAIN_FILE=cmake/gcc-arm-none-eabi.cmake \
    -DCMAKE_BUILD_TYPE=Debug -DFW_UNIT=ON && cmake --build build/Unit ) >"$LOG" 2>&1; rc=$?
tr -d '\r' <"$LOG" >"$LOG.tmp" && mv "$LOG.tmp" "$LOG"
ownw="$(grep -E "(\.\./|[/\\\\]$APP[/\\\\])(src|test)[/\\\\][^:]*:[0-9]+:[0-9]+: warning:" "$LOG" | grep -v "test[/\\\\]unity[/\\\\]" | sort -u)"
nown=$(printf '%s' "$ownw" | grep -c .)
echo "cmake exit=$rc  warnings(src+test)=$nown  errors=$(grep -c ': error:' "$LOG")"
if [ $rc -ne 0 ] || [ ! -f "$UELF" ]; then
  grep -E ': error:' "$LOG" | head -10 | sed 's/^/  /'; echo "UNIT-BUILD: FAIL (see $LOG)"; exit 1
fi
[ "$nown" -eq 0 ] || { echo "$ownw" | head -10 | sed 's/^/  /'; echo "UNIT-BUILD: WARNINGS ($nown in src/ or test/) - fix them"; exit 2; }
SHA="$(sha256sum "$UELF" | cut -d' ' -f1)"
{ echo "# unit-test image manifest - unit_test.sh, $(date '+%Y-%m-%d %H:%M:%S')"
  echo "app        $APP (board $APP_BOARD), FW_UNIT=ON, Unity $(sed -n 's/^#define UNITY_VERSION_MAJOR *\([0-9]*\).*/\1/p' "$APPDIR/test/unity/unity.h").$(sed -n 's/^#define UNITY_VERSION_MINOR *\([0-9]*\).*/\1/p' "$APPDIR/test/unity/unity.h").$(sed -n 's/^#define UNITY_VERSION_BUILD *\([0-9]*\).*/\1/p' "$APPDIR/test/unity/unity.h")"
  echo "suites     $(cd "$APPDIR/test" && ls *.c | tr '\n' ' ')"
  echo "$SHA $(stat -c %s "$UELF") mx.elf"; } >"$UDIR/manifest.txt"
echo "UNIT-BUILD: PASS (image sha256 ${SHA:0:16}..., $UDIR/manifest.txt)"
[ $BUILD_ONLY = 1 ] && exit 0

# 2. flash the unit-test image (asks first)
require_milestone M1 "unit_test.sh (stage 6 test on the board)"
require_flash_approval $YES "program board '$APP_BOARD' with the UNIT-TEST image of $APP (sha256 ${SHA:0:16}...; replaces the app until flash.sh <app> --yes)"
bash "$SKILL_DIR/scripts/flash.sh" "$APPDIR" --yes --elf "$UELF" || { echo "UNIT: FAIL (flash failed)"; exit 1; }

# 3. read the results
read_results
