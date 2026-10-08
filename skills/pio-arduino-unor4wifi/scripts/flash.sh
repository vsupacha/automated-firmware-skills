#!/usr/bin/env bash
# Stage 5: program an app (firmware.bin of its build manifest) into the board of this PC's bench
# file through the ESP32-S3 USB bridge with bossac, run.
# Usage: flash.sh <app-dir> --yes
#   --yes   required: the agent must have asked the user first (board, app, firmware.bin sha256
#           prefix), unless the developer put FLASH_POLICY=auto into this board's bench file
# Gates: app made for this board -> firmware.bin matches the PASS manifest's sha256 and offset ->
# board with the bench USB serial found -> identity (loader, loader device, security off, nothing
# locked) -> 1200 baud touch -> bossac --erase --write --reset (the bridge maps address 0 to
# APP_OFFSET: the sketch region only, the Arduino loader stays) -> all pages written -> the console
# port is back. NO read-back: the bridge's loader cannot read flash (bossac --verify fails with
# "SAM-BA operation failed" and then skips --reset, leaving the RA4M1 in the loader - seen
# 2026-10-08). Proof that the image runs = the test's INFO line (board=<id>), stage 6.
# Exit 0 = "FLASH: PASS"; 1 = FAIL. The ESP32-S3 bridge firmware is never written.

. "$(dirname "$0")/env.sh"
require_milestone M1 "flash.sh (stage 5 flash)"
APPDIR=""; YES=0
while [ $# -gt 0 ]; do
  case "$1" in --yes) YES=1;; --*) die "unknown option $1";; *) APPDIR="$1";; esac; shift
done
[ -n "$APPDIR" ] && [ -f "$APPDIR/arduino-app.env" ] || die "usage: flash.sh <app-dir> --yes"
APPDIR="$(cd "$APPDIR" && pwd)"
# shellcheck disable=SC1091
. "$APPDIR/arduino-app.env"
load_board "$APP_BOARD"
require_vars USB_SERIAL EXPECTED_LOADER APP_OFFSET
OUT="$APPDIR/.pio/build/$APP_PIO_ENV"; M="$OUT/manifest.txt"; BIN="$OUT/firmware.bin"
mkdir -p "$APPDIR/logs"; LOG="$APPDIR/logs/flash-$(ts).log"

# 1. image + manifest gate
[ -f "$M" ] || die "no build manifest - run build.sh until BUILD: PASS"
grep -q "^flash $APP_OFFSET firmware.bin\$" "$M" || die "manifest offset is not $APP_OFFSET - rebuild with build.sh"
want="$(sed -n 's/^\([0-9a-f]\{64\}\) [0-9]* firmware.bin$/\1/p' "$M")"
SHA="$(sha256sum "$BIN" 2>/dev/null | cut -d' ' -f1)"
[ -n "$want" ] && [ "$want" = "$SHA" ] || die "firmware.bin does not match the PASS manifest (rebuilt or edited after the build?) - run build.sh"
require_flash_approval $YES "program board '$APP_BOARD' with app $(basename "$APPDIR") (firmware.bin sha256 ${SHA:0:16}...)"
bench_lock "$BOARD_ID" flash.sh
info "App $(basename "$APPDIR") for board $APP_BOARD, firmware.bin sha256 ${SHA:0:16}..."

# 2. board + identity (read-only; the sketch restarts)
PORT="$(find_port "$USB_SERIAL")"
[ -n "$PORT" ] || die "board $USB_SERIAL not connected (run discover.sh after changing board/USB port)"
ID="$(IDENTITY_LOG="$LOG" identity "$PORT")"
val() { echo "$ID" | sed -n "s/^$1=//p"; }
echo "identity: port=$PORT loader='$(val loader)' device=$(val device) security=$(val security) locked=$(val locked)"
case "$(val loader)" in "$EXPECTED_LOADER"*) ;; *) die "loader '$(val loader)' is not '$EXPECTED_LOADER' - not flashing";; esac
[ -z "$EXPECTED_LOADER_DEVICE" ] || [ "$(val device)" = "$EXPECTED_LOADER_DEVICE" ] || die "loader device $(val device) != $EXPECTED_LOADER_DEVICE - not flashing"
[ "$(val security)" = false ] && [ "$(val locked)" = none ] || die "security on / locked regions - stop and ask the user (never unlock)"

# 3. loader again, then erase + write + verify + reset (the port may re-enumerate)
PORT="$(wait_port "$USB_SERIAL" 15)" || die "board port did not come back after the identity check"
info "bossac erase + write $(basename "$BIN") ($(wc -c <"$BIN" | tr -d ' ') bytes at $APP_OFFSET), log $LOG"
touch_1200 "$PORT"; sleep 1
bossac_run "$PORT" --erase --write --reset "$(winpath "$BIN")" >>"$LOG"; rc=$?
grep -E '^(Erase|Write|Verify|Set binary|Done|.*[Ee]rror|.*failed)' "$LOG" | sed 's/^/  /'
npages="$(sed -n 's/^Write [0-9]* bytes to flash (\([0-9]*\) pages)$/\1/p' "$LOG" | tail -1)"
if [ $rc -ne 0 ] || [ -z "$npages" ] || ! grep -q "($npages/$npages pages)" "$LOG" || grep -qiE 'failed|error' "$LOG"; then
  echo "FLASH: FAIL (bossac exit $rc, pages written ${npages:-?}, see $LOG)"; exit 1
fi
PORT="$(wait_port "$USB_SERIAL" 20)" || { echo "FLASH: FAIL (written, but the console port did not come back - see $LOG)"; exit 1; }
if [ -f "$BENCH_FILE" ] && ! grep -q "^CONSOLE_PORT=$PORT\$" "$BENCH_FILE"; then
  sed -i "s/^CONSOLE_PORT=.*/CONSOLE_PORT=$PORT/" "$BENCH_FILE"
fi
echo "board=$APP_BOARD port=$PORT firmware_sha256=$SHA" >>"$LOG"
echo "FLASH: PASS (firmware.bin $npages/$npages pages written at $APP_OFFSET, reset; console on $PORT; not read back - stage 6 INFO line proves the image)"
