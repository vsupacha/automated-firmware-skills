#!/usr/bin/env bash
# Stage 5: program an app's firmware.uf2 into the board of this PC's bench file.
# Usage: flash.sh <app-dir> --yes [--uf2 <file>]
#   --yes   required: the agent must have asked the user first (board, app, uf2 sha256 prefix),
#           unless the developer put FLASH_POLICY=auto into this board's bench file
#   --uf2   program another image (recovery / known-good); skips the manifest gate
# Gates: app made for this board -> uf2 matches the PASS manifest -> board with the bench USB
# serial found -> reboot to BOOTSEL (1200-baud touch) -> picotool identity (chip, flash size,
# chip id) -> picotool load --verify --execute -> sketch's CDC port is back.
# Exit 0 = "FLASH: PASS"; 1 = FAIL. Writes only the flash of the selected board.

. "$(dirname "$0")/env.sh"
require_milestone M1 "flash.sh (stage 5 flash)"
APPDIR=""; YES=0; UF2=""
while [ $# -gt 0 ]; do
  case "$1" in --yes) YES=1;; --uf2) UF2="$2"; shift;; --*) die "unknown option $1";; *) APPDIR="$1";; esac; shift
done
[ -n "$APPDIR" ] && [ -f "$APPDIR/pico-app.env" ] || die "usage: flash.sh <app-dir> --yes [--uf2 <file>]"
APPDIR="$(cd "$APPDIR" && pwd)"
# shellcheck disable=SC1091
. "$APPDIR/pico-app.env"
load_board "$APP_BOARD"
require_vars USB_SERIAL EXPECTED_CHIP
mkdir -p "$APPDIR/logs"; STAMP="$(ts)"; LOG="$APPDIR/logs/flash-$STAMP.log"
OUT="$APPDIR/.pio/build/$APP_PIO_ENV"

# 1. image + manifest gate
if [ -n "$UF2" ]; then
  [ -f "$UF2" ] || die "no file $UF2"; UF2="$(cd "$(dirname "$UF2")" && pwd)/$(basename "$UF2")"
  echo "NOTE: --uf2 given - programming $UF2 without the manifest gate (recovery image chosen by the user)"
else
  UF2="$OUT/firmware.uf2"
  [ -f "$OUT/manifest.txt" ] || die "no build manifest - run build.sh until BUILD: PASS"
  want="$(sed -n 's/^\([0-9a-f]\{64\}\) [0-9]* firmware.uf2$/\1/p' "$OUT/manifest.txt")"
  have="$(sha256sum "$UF2" | cut -d' ' -f1)"
  [ -n "$want" ] && [ "$want" = "$have" ] || die "firmware.uf2 does not match the PASS manifest (rebuilt or edited after the build?) - run build.sh"
fi
SHA="$(sha256sum "$UF2" | cut -d' ' -f1)"
require_flash_approval $YES "program board '$APP_BOARD' with app $(basename "$APPDIR") (uf2 sha256 ${SHA:0:16}...)"
bench_lock "$BOARD_ID" flash.sh
info "App $(basename "$APPDIR") for board $APP_BOARD, uf2 sha256 ${SHA:0:16}..."

# 2. find the board (sketch running, or already in BOOTSEL)
SER="$(echo "$USB_SERIAL" | tr a-z A-Z)"
PORT="$(find_port "$SER")"
if [ -n "$PORT" ]; then
  info "Board $SER runs a sketch on $PORT - 1200-baud touch to enter BOOTSEL"
  touch_1200 "$PORT"
fi
wait_bootsel "$SER" 15 || need_user CONNECT "board $SER not found in BOOTSEL - unplug it, hold BOOTSEL, plug it in, release (no reset button on this board), then re-run flash.sh"

# 3. identity gate (read-only)
INFO="$(picotool_info "$SER")"; echo "$INFO" >"$LOG"
chip="$(echo "$INFO" | sed -n 's/^ *type: *//p' | head -1)"
flash="$(echo "$INFO" | sed -n 's/^ *flash size: *//p' | head -1)"
chipid="$(echo "$INFO" | sed -n 's/^ *chipid: *0x//p' | head -1 | tr a-z A-Z)"
secure="$(echo "$INFO" | sed -n 's/^ *secure boot: *//p' | head -1)"
echo "identity: chip=$chip flash=$flash chipid=$chipid secure_boot=${secure:-?}"
[ "$chip" = "$EXPECTED_CHIP" ] || die "chip '$chip' != $EXPECTED_CHIP - not flashing"
[ -z "$EXPECTED_FLASH" ] || [ "$flash" = "$EXPECTED_FLASH" ] || die "flash '$flash' != $EXPECTED_FLASH - not flashing"
[ "$chipid" = "$SER" ] || die "chip id $chipid != bench USB serial $SER - not flashing"
[ "${secure:-0}" = 0 ] || die "secure boot is enabled on this chip - unsigned images will not run; stop and ask the user"

# 4. program + verify + run
info "picotool load -v -x  (log $LOG)"
"$PICOTOOL" load -v -x "$(winpath "$UF2")" --ser "$SER" >>"$LOG" 2>&1; rc=$?
# picotool draws progress bars with CR: one line per update after this
tr '\r' '\n' <"$LOG" | sed 's/\x1b\[[0-9;]*[A-Za-z]//g' | grep -v '^ *$' >"$LOG.tmp" && mv "$LOG.tmp" "$LOG"
grep -E '100%|rebooted|ERROR|[Ee]rror|[Ff]ail' "$LOG" | sed 's/^/  /'
if [ $rc -ne 0 ] || grep -qiE 'error|verify failed|mismatch' "$LOG" || ! grep -q 'Verifying Flash:.*100%' "$LOG"; then
  echo "FLASH: FAIL (picotool exit $rc or verify not completed, see $LOG)"; exit 1
fi

# 5. the sketch must come back on USB
PORT="$(wait_port "$SER" 20)" || { echo "FLASH: FAIL (programmed + verified, but no CDC port from $SER within 20 s - does the sketch start USB Serial?)"; exit 1; }
if [ -f "$BENCH_FILE" ] && ! grep -q "^CONSOLE_PORT=$PORT\$" "$BENCH_FILE"; then
  sed -i "s/^CONSOLE_PORT=.*/CONSOLE_PORT=$PORT/" "$BENCH_FILE"
fi
echo "device=$chip chipid=$chipid uf2_sha256=$SHA port=$PORT" >>"$LOG"
echo "FLASH: PASS (programmed + verified + running, console $PORT)"
