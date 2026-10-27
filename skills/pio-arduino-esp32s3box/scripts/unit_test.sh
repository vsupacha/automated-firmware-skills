#!/usr/bin/env bash
# Stage 6 (test: unit tests on the board, prototype): Unity tests of the app's src/func/ (led,
# button, console) against a fake board, built by PlatformIO's test runner and run on the
# ESP32-S3-BOX.
# Usage: unit_test.sh <app-dir> [--yes] [--build-only | --read-only] [--filter <glob>] [--timeout <s>]
#   --yes         flash the unit-test image (only after the user agreed - it replaces the app)
#   --build-only  build the test image and stop (no board needed)
#   --read-only   only step 3: read the results of the test image already on the board (after a
#                 power cycle, for example) - no build, no flash
#   --filter      pio test -f <glob> (default: every test/test_* suite)
# Steps: 1. pio test --without-uploading --without-testing (env <env>_unit: test/test_* + src/func
#        only) and a manifest of that build (sha256 + the flash map PlatformIO would upload) ->
#        2. flash.sh --yes --env <env>_unit (manifest + identity gates, after the approval asked
#        here) -> 3. scripts/unity_read.py on the board's console port: the test image waits for
#        a start byte (USB Serial/JTAG drops output while no host reads; pio test's reset does
#        not restart this chip), the reader sends it and parses Unity's summary.
# The app (test/ folder, [env:<env>_unit]) gets both from the template when they are missing.
# After the run the board keeps the unit-test image: flash.sh <app> --yes restores the app.
# Gates: "UNIT-BUILD: PASS" (built, image sha256), "UNIT: PASS (n/n)" / "UNIT: FAIL (...)".
# Exit 0 PASS, 1 FAIL, 10 = developer action (approve the flash, connect the board).

. "$(dirname "$0")/env.sh"
APPDIR=""; YES=0; BUILD_ONLY=0; READ_ONLY=0; FILTER=""; TMO=120
while [ $# -gt 0 ]; do
  case "$1" in --yes) YES=1;; --build-only) BUILD_ONLY=1;; --read-only) READ_ONLY=1;; --filter) FILTER="$2"; shift;;
    --timeout) TMO="$2"; shift;; --*) die "unknown option $1";; *) APPDIR="$1";; esac; shift
done
[ -n "$APPDIR" ] && [ -f "$APPDIR/arduino-app.env" ] || die "usage: unit_test.sh <app-dir> [--yes] [--build-only] [--filter <glob>]  (an app made by new_app.sh)"
APPDIR="$(cd "$APPDIR" && pwd)"; APP="$(basename "$APPDIR")"
# shellcheck disable=SC1091
. "$APPDIR/arduino-app.env"
load_board "$APP_BOARD"
[ -n "$PIO" ] || die "PlatformIO not found - run check_tools.sh"
UENV="${APP_PIO_ENV}_unit"; OUT="$APPDIR/.pio/build/$UENV"
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

if [ "$READ_ONLY" = 0 ]; then
# 1. build the unit-test image (no board) + its manifest for flash.sh
info "pio test -e $UENV --without-uploading --without-testing  (log $(winpath "$LOG"))"
if ! "$PIO" test -d "$APPDIR" -e "$UENV" "${fopt[@]}" --without-uploading --without-testing >"$LOG" 2>&1; then
  grep -E "error|Error" "$LOG" | head -15
  echo "UNIT-BUILD: FAIL (see $(winpath "$LOG"))"; exit 1
fi
[ -f "$OUT/firmware.bin" ] || { echo "UNIT-BUILD: FAIL (no $OUT/firmware.bin)"; exit 1; }
MAP="$(pio_flash_map "$UENV" "$OUT")"
echo "$MAP" | grep -q ' firmware.bin$' || { echo "UNIT-BUILD: FAIL (no flash map from pio project metadata)"; exit 1; }
{
  echo "# unit-test build manifest - written by pio-arduino-esp32s3box/unit_test.sh, $(date '+%Y-%m-%d %H:%M:%S')"
  echo "app        $APP  board=$APP_BOARD  env=$UENV  (Unity tests of src/func, not the app)"
  echo "artifacts (sha256  bytes  file):"
  for f in $(echo "$MAP" | awk '{print $2}'); do
    echo "$(sha256sum "$OUT/$f" | cut -d' ' -f1) $(wc -c <"$OUT/$f" | tr -d ' ') $f"
  done
  echo "flash map (offset file):"
  echo "$MAP" | sed 's/^/flash /'
} >"$OUT/manifest.txt"
SHA="$(sha256sum "$OUT/firmware.bin" | cut -d' ' -f1)"
echo "UNIT-BUILD: PASS ($(winpath "$OUT/firmware.bin"), sha256 ${SHA:0:16}...)"
[ "$BUILD_ONLY" = 1 ] && exit 0

# 2. flash the test image - asks first, flash.sh checks the manifest and the board's identity
require_milestone M1 "unit_test.sh (stage 6 test on the board)"
require_flash_approval $YES "program board '$APP_BOARD' with the UNIT-TEST image of app $APP (firmware.bin sha256 ${SHA:0:16}...); it replaces the app until flash.sh $APP --yes"
bench_lock "$BOARD_ID" unit_test.sh
bash "$SKILL_DIR/scripts/flash.sh" "$APPDIR" --yes --env "$UENV" | tee -a "$LOG" | grep -E "^(identity|FLASH|ERROR|ACTION|NOTE)"
[ "${PIPESTATUS[0]}" = 0 ] || { echo "UNIT: FAIL (the unit-test image was not flashed)"; exit 1; }
else
  require_milestone M1 "unit_test.sh (stage 6 test on the board)"
  bench_lock "$BOARD_ID" unit_test.sh
fi

# 3. read the results: the test image waits for a start byte (USB Serial/JTAG drops output while
#    no host reads, and pio test cannot reset this chip), so scripts/unity_read.py starts it
PORT="$(wait_port "$USB_SERIAL" 15)" || need_user CONNECT "no console port of board $USB_SERIAL after flashing - replug USB, then re-run unit_test.sh $APPDIR --yes"
info "unity_read.py on the console port (sends the start byte, reads one Unity run)"
RES="$("$ESP_PY" "$(winpath "$SKILL_DIR/scripts/unity_read.py")" "$PORT" "$(winpath "$LOG")" --timeout "$TMO" 2>&1 | tr -d '\r')"
rc=$?
echo "$RES" | grep -v '^UNITY'
sum="$(echo "$RES" | sed -n 's/^UNITY: //p')"
read -r total fails ign <<<"$sum"
if [ -n "$total" ] && [ "$total" -gt 0 ] 2>/dev/null && [ "$fails" = 0 ]; then
  note=""; [ "${ign:-0}" != 0 ] && note=", $ign ignored"
  echo "UNIT: PASS ($((total - ign))/$total$note)"
  echo "NOTE: the board now runs the unit-test image - flash.sh $APPDIR --yes puts the app back (asks first)"
  exit 0
fi
err="$(echo "$RES" | sed -n 's/^UNITY-ERR //p')"
case "$err" in *"(0 lines received)"*)
  need_user POWER_CYCLE "nothing at all came from the board: the chip is most likely still in its ROM bootloader (FLASH: PASS does not prove the image booted, and a download flag set over USB survives the RESET button). Unplug the USB cable for 5 s, plug it in again without pressing a button, then run unit_test.sh $APPDIR --read-only";;
esac
echo "UNIT: FAIL (${sum:+tests/failures/ignored $sum}${err} - log $(winpath "$LOG"))"
exit 1
