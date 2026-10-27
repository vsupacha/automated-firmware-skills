#!/usr/bin/env bash
# Stage 6 (test: unit tests on the board, prototype): Unity tests of the app's src/func/ (led,
# button, console) against a fake board, built by PlatformIO's test runner and run on the Pico.
# Usage: unit_test.sh <app-dir> [--yes] [--build-only] [--filter <glob>] [--timeout <s>]
#   --yes         flash the unit-test image (only after the user agreed - it replaces the app)
#   --build-only  build the test image and stop (no board needed)
#   --filter      pio test -f <glob> (default: every test/test_* suite)
# Steps: 1. pio test --without-uploading --without-testing (build test/test_* + src/func only,
#        env <env>_unit of platformio.ini) -> 2. flash.sh --yes --uf2 <test image> (identity gate,
#        after the approval asked here) -> 3. pio test --without-building --without-uploading on
#        the board's console port (bench file): the runner reads Unity's result lines.
# The app (test/ folder, [env:<env>_unit]) gets both from the template when they are missing.
# After the run the board keeps the unit-test image: flash.sh <app> --yes restores the app.
# Gates: "UNIT-BUILD: PASS" (built, image sha256), "UNIT: PASS (n/n)" / "UNIT: FAIL (...)".
# Exit 0 PASS, 1 FAIL, 10 = developer action (approve the flash, connect the board).

. "$(dirname "$0")/env.sh"
APPDIR=""; YES=0; BUILD_ONLY=0; FILTER=""; TMO=120
while [ $# -gt 0 ]; do
  case "$1" in --yes) YES=1;; --build-only) BUILD_ONLY=1;; --filter) FILTER="$2"; shift;;
    --timeout) TMO="$2"; shift;; --*) die "unknown option $1";; *) APPDIR="$1";; esac; shift
done
[ -n "$APPDIR" ] && [ -f "$APPDIR/pico-app.env" ] || die "usage: unit_test.sh <app-dir> [--yes] [--build-only] [--filter <glob>]  (an app made by new_app.sh)"
APPDIR="$(cd "$APPDIR" && pwd)"; APP="$(basename "$APPDIR")"
# shellcheck disable=SC1091
. "$APPDIR/pico-app.env"
load_board "$APP_BOARD"
[ -n "$PIO" ] || die "PlatformIO not found - run check_tools.sh"
UENV="${APP_PIO_ENV}_unit"
mkdir -p "$APPDIR/logs"; STAMP="$(ts)"; LOG="$APPDIR/logs/unit-$STAMP.log"

# 0. test sources and the unit-test environment (older apps have neither)
if [ ! -d "$APPDIR/test" ]; then
  cp -r "$SKILL_DIR/templates/_common/test" "$APPDIR/test" || die "cannot copy the test suite"
  info "added test/ from the skill template (Unity tests of src/func)"
fi
if ! grep -q "^\[env:$UENV\]" "$APPDIR/platformio.ini"; then
  { echo; fw_pio_unit_env "$APP_PIO_ENV" "${CONSOLE_BAUD:-115200}"; } >>"$APPDIR/platformio.ini"
  info "added [env:$UENV] to platformio.ini"
fi
fopt=(); [ -n "$FILTER" ] && fopt=(-f "$FILTER")

# 1. build the unit-test image (no board)
info "pio test -e $UENV --without-uploading --without-testing  (log $(winpath "$LOG"))"
if ! "$PIO" test -d "$APPDIR" -e "$UENV" "${fopt[@]}" --without-uploading --without-testing >"$LOG" 2>&1; then
  grep -E "error|Error" "$LOG" | head -15
  echo "UNIT-BUILD: FAIL (see $(winpath "$LOG"))"; exit 1
fi
UF2="$APPDIR/.pio/build/$UENV/firmware.uf2"
[ -f "$UF2" ] || { echo "UNIT-BUILD: FAIL (no $UF2)"; exit 1; }
SHA="$(sha256sum "$UF2" | cut -d' ' -f1)"
echo "UNIT-BUILD: PASS ($(winpath "$UF2"), sha256 ${SHA:0:16}...)"
[ "$BUILD_ONLY" = 1 ] && exit 0

# 2. flash the test image - asks first, flash.sh checks the board's identity
require_milestone M1 "unit_test.sh (stage 6 test on the board)"
require_flash_approval $YES "program board '$APP_BOARD' with the UNIT-TEST image of app $APP (uf2 sha256 ${SHA:0:16}...); it replaces the app until flash.sh $APP --yes"
bench_lock "$BOARD_ID" unit_test.sh
bash "$SKILL_DIR/scripts/flash.sh" "$APPDIR" --yes --uf2 "$UF2" | tee -a "$LOG" | grep -E "^(identity|FLASH|ERROR|ACTION|NOTE)"
[ "${PIPESTATUS[0]}" = 0 ] || { echo "UNIT: FAIL (the unit-test image was not flashed)"; exit 1; }

# 3. read the results from the board's console port
SER="$(echo "$USB_SERIAL" | tr a-z A-Z)"
PORT="$(find_port "$SER")"
[ -n "$PORT" ] || need_user CONNECT "no console port of board $SER after flashing - replug USB, then re-run unit_test.sh $APPDIR --yes"
info "pio test -e $UENV --without-building --without-uploading --test-port $PORT"
timeout "$TMO" "$PIO" test -d "$APPDIR" -e "$UENV" "${fopt[@]}" --without-building --without-uploading \
  --test-port "$PORT" >>"$LOG" 2>&1
rc=$?
grep -E "\[(PASSED|FAILED|IGNORED|SKIPPED)\]$" "$LOG" | sed 's/^.*: /  /; s/\t/  /'
sum="$(grep -E "[0-9]+ test cases?:" "$LOG" | tail -1)"
total="$(echo "$sum" | grep -oE '[0-9]+ test cases?' | grep -oE '^[0-9]+')"
okn="$(echo "$sum" | grep -oE '[0-9]+ succeeded' | grep -oE '^[0-9]+')"
[ "$rc" = 124 ] && { echo "UNIT: FAIL (no result within $TMO s on $PORT - log $(winpath "$LOG"))"; exit 1; }
if [ "$rc" = 0 ] && [ -n "$total" ] && [ "$total" -gt 0 ] && [ "${okn:-0}" = "$total" ]; then
  echo "UNIT: PASS ($okn/$total)"
  echo "NOTE: the board now runs the unit-test image - flash.sh $APPDIR --yes puts the app back (asks first)"
  exit 0
fi
echo "UNIT: FAIL (${sum:-no summary} - log $(winpath "$LOG"))"
exit 1
