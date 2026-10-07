#!/usr/bin/env bash
# Stage 5: program an app's ELF into the board of this PC's bench file.
# Usage: flash.sh <app-dir> --yes [--elf <file>]
#   --yes   required: the agent must have asked the user first (board, app, ELF sha256 prefix),
#           unless the developer put FLASH_POLICY=auto into this board's bench file
#   --elf   program another image (recovery / known-good); skips the manifest gate
# Gates: app made for this board -> ELF matches the PASS manifest -> bench ST-LINK connected ->
# read-only hot-plug identity (device name/ID) -> program under reset + verify + reset.
# Exit 0 = "FLASH: PASS"; 1 = FAIL.

. "$(dirname "$0")/env.sh"
require_milestone M3 "flash.sh (stage 7 flash)"
APPDIR=""; YES=0; ELF_ARG=""
while [ $# -gt 0 ]; do
  case "$1" in --yes) YES=1;; --elf) ELF_ARG="$2"; shift;; --*) die "unknown option $1";; *) APPDIR="$1";; esac; shift
done
[ -n "$APPDIR" ] && [ -f "$APPDIR/cubemx-app.env" ] || die "usage: flash.sh <app-dir> --yes [--elf <file>]"
APPDIR="$(cd "$APPDIR" && pwd)"
# shellcheck disable=SC1091
. "$APPDIR/cubemx-app.env"
load_board "$APP_BOARD"
require_vars PROBE_SERIAL EXPECTED_DEVICE_NAME
[ -x "$PROGRAMMER" ] || die "STM32CubeProgrammer CLI $PROGRAMMER_VERSION not found - run check_tools.sh"
mkdir -p "$APPDIR/logs"; LOG="$APPDIR/logs/flash-$(ts).log"
OUTDIR="$APPDIR/mx/build/$APP_PRESET"

# 1. image + manifest gate
if [ -n "$ELF_ARG" ]; then
  [ -f "$ELF_ARG" ] || die "no file $ELF_ARG"; ELF="$(cd "$(dirname "$ELF_ARG")" && pwd)/$(basename "$ELF_ARG")"
  echo "NOTE: --elf given - programming $ELF without the manifest gate (recovery image chosen by the user)"
else
  ELF="$OUTDIR/$APP_SW_PROJECT.elf"
  [ -f "$OUTDIR/manifest.txt" ] || die "no build manifest - run build.sh until BUILD: PASS"
  want="$(sed -n "s/^\([0-9a-f]\{64\}\) [0-9]* $APP_SW_PROJECT\.elf\$/\1/p" "$OUTDIR/manifest.txt")"
  [ -n "$want" ] && [ "$want" = "$(sha256sum "$ELF" | cut -d' ' -f1)" ] \
    || die "ELF does not match the PASS manifest (rebuilt or edited after the build?) - run build.sh"
fi
SHA="$(sha256sum "$ELF" | cut -d' ' -f1)"
require_flash_approval $YES "program board '$APP_BOARD' with app $(basename "$APPDIR") (ELF sha256 ${SHA:0:16}...)"
bench_lock "$BOARD_ID" flash.sh
info "App $(basename "$APPDIR") for board $APP_BOARD, ELF sha256 ${SHA:0:16}..."

# 2. probe + identity (read-only)
probe_serials | grep -qix "$PROBE_SERIAL" || die "ST-LINK $PROBE_SERIAL not connected (run discover.sh after changing board/USB port)"
ID="$(probe_identity "$PROBE_SERIAL")"; echo "$ID" >"$LOG"
name="$(echo "$ID" | sed -n 's/^ *Device name *: *//p' | head -1)"
devid="$(echo "$ID" | sed -n 's/^ *Device ID *: *//p' | head -1)"
sboard="$(echo "$ID" | sed -n 's/^ *Board *: *//p' | head -1)"
echo "identity: probe=$PROBE_SERIAL board='$sboard' device='$name' id=$devid"
[ -z "$EXPECTED_STLINK_BOARD" ] || [ "$sboard" = "$EXPECTED_STLINK_BOARD" ] || die "ST-LINK reports board '$sboard', expected $EXPECTED_STLINK_BOARD - not flashing"
case "$name" in "$EXPECTED_DEVICE_NAME"*) ;; *) die "device '$name' is not $EXPECTED_DEVICE_NAME* - not flashing";; esac
[ -z "$EXPECTED_DEVICE_ID" ] || [ "$devid" = "$EXPECTED_DEVICE_ID" ] || die "device ID $devid != $EXPECTED_DEVICE_ID - not flashing"
echo "$ID" | grep -qiE 'read.?out protection|RDP *: *(Level 1|Level 2|0xBB|0xCC)' && \
  die "read-out protection looks active - removing it erases the chip; stop and ask the user"

# 3. program under reset, verify, reset
info "STM32_Programmer_CLI -d <elf> -v -rst  (log $LOG)"
"$PROGRAMMER" -c port=SWD sn="$PROBE_SERIAL" mode=UR reset=HWrst -d "$(winpath "$ELF")" -v -rst >>"$LOG" 2>&1; rc=$?
tr -d '\r' <"$LOG" >"$LOG.tmp" && mv "$LOG.tmp" "$LOG"
grep -E 'Download verified successfully|File download complete|Error|error' "$LOG" | sed 's/^/  /' | tail -5
if [ $rc -ne 0 ] || ! grep -q 'Download verified successfully' "$LOG"; then
  echo "FLASH: FAIL (programmer exit $rc, see $LOG)"; exit 1
fi
echo "device=$name id=$devid elf_sha256=$SHA" >>"$LOG"
echo "FLASH: PASS (programmed + verified + reset)"
