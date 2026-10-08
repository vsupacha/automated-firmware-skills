#!/usr/bin/env bash
# Stage 5: program an app (the flash map of its build manifest: bootloader, partition table,
# boot_app0 OTA data, sketch) into the board of this PC's bench file with esptool, verify, run.
# Usage: flash.sh <app-dir> --yes
#   --yes   required: the agent must have asked the user first (board, app, firmware.bin sha256
#           prefix), unless the developer put FLASH_POLICY=auto into this board's bench file
# Gates: app made for this board -> every image of the manifest's flash map matches its sha256 ->
# board with the bench USB serial found -> esptool identity (chip, MAC = serial, flash size, secure
# boot and flash encryption off) -> write_flash at the map's offsets (flash mode/size/freq kept as
# built into the bootloader), each region verified by hash -> hard reset -> the console port is back.
# Exit 0 = "FLASH: PASS"; 1 = FAIL. Writes only the regions of the mapped images.

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
require_vars USB_SERIAL EXPECTED_CHIP
OUT="$APPDIR/.pio/build/$APP_PIO_ENV"; M="$OUT/manifest.txt"
mkdir -p "$APPDIR/logs"; LOG="$APPDIR/logs/flash-$(ts).log"

# 1. image + manifest gate: the flash map and every image's sha256 come from the PASS manifest
[ -f "$M" ] || die "no build manifest - run build.sh until BUILD: PASS"
mapfile -t MAP < <(sed -n 's/^flash \(0x[0-9a-fA-F]*\) \([A-Za-z0-9_.-]*\)$/\1 \2/p' "$M")
[ ${#MAP[@]} -ge 2 ] || die "manifest has no flash map - rebuild with build.sh"
ARGS=()
for m in "${MAP[@]}"; do
  read -r off f <<<"$m"
  want="$(sed -n "s/^\([0-9a-f]\{64\}\) [0-9]* $f\$/\1/p" "$M")"
  [ -n "$want" ] && [ -f "$OUT/$f" ] && [ "$want" = "$(sha256sum "$OUT/$f" | cut -d' ' -f1)" ] \
    || die "$f does not match the PASS manifest (rebuilt or edited after the build?) - run build.sh"
  ARGS+=("$off" "$(winpath "$OUT/$f")")
done
SHA="$(sha256sum "$OUT/firmware.bin" | cut -d' ' -f1)"
require_flash_approval $YES "program board '$APP_BOARD' with app $(basename "$APPDIR") (firmware.bin sha256 ${SHA:0:16}...)"
bench_lock "$BOARD_ID" flash.sh
info "App $(basename "$APPDIR") for board $APP_BOARD, firmware.bin sha256 ${SHA:0:16}..."

# 2. board + identity (read-only)
PORT="$(find_port "$USB_SERIAL")"
[ -n "$PORT" ] || die "board $USB_SERIAL not connected (run discover.sh after changing board/USB port)"
ID="$(IDENTITY_LOG="$LOG" identity "$PORT")"
val() { echo "$ID" | sed -n "s/^$1=//p"; }
echo "identity: port=$PORT chip='$(val chip)' mac=$(val mac) flash=$(val flash) secure_boot=$(val secure_boot) flash_crypt=$(val flash_crypt)"
case "$(val chip)" in "$EXPECTED_CHIP "*|"$EXPECTED_CHIP") ;; *) die "chip '$(val chip)' is not $EXPECTED_CHIP - not flashing";; esac
[ "$(val mac)" = "$(norm_mac "$USB_SERIAL")" ] || die "MAC $(val mac) != bench serial $USB_SERIAL - not flashing"
[ -z "$EXPECTED_FLASH" ] || [ "$(val flash)" = "$EXPECTED_FLASH" ] || die "flash $(val flash) != $EXPECTED_FLASH - not flashing"
[ "$(val secure_boot)" = Disabled ] && [ "$(val flash_crypt)" = Disabled ] \
  || die "secure boot / flash encryption not disabled - stop and ask the user (never change eFuses)"

# 3. write + verify + reset (the port may re-enumerate during the reset)
PORT="$(wait_port "$USB_SERIAL" 15)" || die "board port did not come back after the identity check"
info "esptool write_flash ${#MAP[@]} regions: $(printf '%s, ' "${MAP[@]}")log $LOG"
esptool_run "$PORT" --baud 921600 --before default_reset --after hard_reset write_flash \
  --flash_mode keep --flash_freq keep --flash_size keep "${ARGS[@]}" >>"$LOG"; rc=$?
grep -E '^(Wrote|Hash of data verified|Hard resetting|A fatal error)' "$LOG" | sed 's/^/  /'
nver="$(grep -c 'Hash of data verified' "$LOG")"
if [ $rc -ne 0 ] || [ "$nver" -lt ${#MAP[@]} ]; then
  echo "FLASH: FAIL (esptool exit $rc, $nver/${#MAP[@]} regions verified, see $LOG)"; exit 1
fi
PORT="$(wait_port "$USB_SERIAL" 20)" || { echo "FLASH: FAIL (programmed + verified, but the console port did not come back - see $LOG)"; exit 1; }
if [ -f "$BENCH_FILE" ] && ! grep -q "^CONSOLE_PORT=$PORT\$" "$BENCH_FILE"; then
  sed -i "s/^CONSOLE_PORT=.*/CONSOLE_PORT=$PORT/" "$BENCH_FILE"
fi
echo "board=$APP_BOARD port=$PORT firmware_sha256=$SHA" >>"$LOG"
echo "FLASH: PASS (${#MAP[@]}/${#MAP[@]} regions written + verified, reset; console on $PORT)"
