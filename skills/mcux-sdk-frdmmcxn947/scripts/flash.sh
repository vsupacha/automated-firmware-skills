#!/usr/bin/env bash
# Stage 5: program an app's ELF into the board of this PC's bench file with LinkServer.
# Usage: flash.sh <app-dir> --yes [--elf <file>]
#   --yes   required: the agent must have asked the user first (board, app, ELF sha256 prefix),
#           unless the developer put FLASH_POLICY=auto into this board's bench file
#   --elf   program another image (recovery / known-good); skips the manifest gate, not the region gate
# Gates: app made for this board -> ELF matches the PASS manifest -> every load segment inside internal
# flash 0x00000000-0x00200000 or RAM (never PFR / IFR / FlexSPI) -> bench probe connected -> read-only
# identity (dapinfo) -> load (-u none: no MCU-Link firmware update) -> verify -> reset (verify leaves
# the core halted). Exit 0 = "FLASH: PASS"; 1 = FAIL.

. "$(dirname "$0")/env.sh"
require_milestone M1 "flash.sh (stage 5 flash)"
APPDIR=""; YES=0; ELF_ARG=""
while [ $# -gt 0 ]; do
  case "$1" in --yes) YES=1;; --elf) ELF_ARG="$2"; shift;; --*) die "unknown option $1";; *) APPDIR="$1";; esac; shift
done
[ -n "$APPDIR" ] && [ -f "$APPDIR/mcx-app.env" ] || die "usage: flash.sh <app-dir> --yes [--elf <file>]"
APPDIR="$(cd "$APPDIR" && pwd)"
# shellcheck disable=SC1091
. "$APPDIR/mcx-app.env"
load_board "$APP_BOARD"
require_vars PROBE_SERIAL EXPECTED_TARGET EXPECTED_PROBE_BOARD LINKSERVER_DEVICE
require_linkserver
[ -f "$GCC_BIN/arm-none-eabi-readelf.exe" ] || die "Arm GNU $GCC_VERSION not found - run check_tools.sh"
mkdir -p "$APPDIR/logs"; LOG="$APPDIR/logs/flash-$(ts).log"
OUTDIR="$APPDIR/debug"; ELFNAME="app_$SDK_CORE.elf"

# 1. image + manifest gate
if [ -n "$ELF_ARG" ]; then
  [ -f "$ELF_ARG" ] || die "no file $ELF_ARG"; ELF="$(cd "$(dirname "$ELF_ARG")" && pwd)/$(basename "$ELF_ARG")"
  echo "NOTE: --elf given - programming $ELF without the manifest gate (recovery image chosen by the user)"
else
  ELF="$OUTDIR/$ELFNAME"
  [ -f "$OUTDIR/manifest.txt" ] || die "no build manifest - run build.sh until BUILD: PASS"
  want="$(sed -n "s/^\([0-9a-f]\{64\}\) [0-9]* ${ELFNAME//./\\.}\$/\1/p" "$OUTDIR/manifest.txt")"
  [ -n "$want" ] && [ "$want" = "$(sha256sum "$ELF" | cut -d' ' -f1)" ] \
    || die "ELF does not match the PASS manifest (rebuilt or edited after the build?) - run build.sh"
fi

# 2. region gate: load segments with data only in internal flash (or RAM, loaded by the startup code)
segs="$("$GCC_BIN/arm-none-eabi-readelf.exe" -lW "$ELF" | tr -d '\r' | awk '$1=="LOAD"{print $4, $5}')"
[ -n "$segs" ] || die "no loadable segments in $ELF"
bad="$(echo "$segs" | while read -r pa sz; do
  p=$((pa)); s=$((sz)); [ $s -eq 0 ] && continue
  [ $p -ge 0 ] && [ $((p + s)) -le $((0x00200000)) ] && continue
  echo "$pa+$sz"
done | tr '\n' ' ' | sed 's/ $//')"
[ -z "$bad" ] || die "ELF has data outside internal flash 0x00000000-0x00200000 ($bad) - not flashing (PFR / IFR / FlexSPI are never written by this skill)"

SHA="$(sha256sum "$ELF" | cut -d' ' -f1)"
require_flash_approval $YES "program board '$APP_BOARD' with app $(basename "$APPDIR") (ELF sha256 ${SHA:0:16}...)"
bench_lock "$BOARD_ID" flash.sh
info "App $(basename "$APPDIR") for board $APP_BOARD, ELF sha256 ${SHA:0:16}..."

# 3. probe + identity (read-only)
probe_list | awk '{print $1}' | grep -qix "$PROBE_SERIAL" || die "probe $PROBE_SERIAL not connected (run discover.sh after changing board/USB port)"
OUT="$(probe_dapinfo "$PROBE_SERIAL")"; echo "$OUT" >"$LOG"
target="$(dap_field "$OUT" "Target Device Name")"; pboard="$(dap_field "$OUT" "Target Board Name")"
echo "identity: probe=$PROBE_SERIAL target='$target' board='$pboard'"
[ "$target" = "$EXPECTED_TARGET" ] || die "probe reports target '$target', expected $EXPECTED_TARGET - not flashing"
[ "$pboard" = "$EXPECTED_PROBE_BOARD" ] || die "probe reports board '$pboard', expected $EXPECTED_PROBE_BOARD - not flashing"

# 4. load, verify, reset
LS=("$LINKSERVER" flash -p "$PROBE_SERIAL" -u none "$LINKSERVER_DEVICE")
info "LinkServer flash load + verify + reset  (log $LOG)"
"${LS[@]}" load "$(winpath "$ELF")" >>"$LOG" 2>&1; rc=$?
if [ $rc -eq 0 ]; then "${LS[@]}" verify "$(winpath "$ELF")" >>"$LOG" 2>&1; rc=$?; fi
tr -d '\r' <"$LOG" >"$LOG.tmp" && mv "$LOG.tmp" "$LOG"
nver="$(grep -c 'verify succeeded' "$LOG")"
grep -E 'Loaded 0x|verify succeeded|Ef\(|CRITICAL|ERRMSG|matches probe' "$LOG" | sed 's/^/  /' | tail -8
if [ $rc -ne 0 ] || [ "$nver" -eq 0 ] || grep -qE 'CRITICAL|ERRMSG|verify failed' "$LOG"; then
  echo "FLASH: FAIL (LinkServer exit $rc, see $LOG)"; exit 1
fi
"$LINKSERVER" probe "$PROBE_SERIAL" wiretimedreset 100 >>"$LOG" 2>&1 \
  || { echo "FLASH: FAIL - programmed and verified, but the reset failed (press SW1 RESET; see $LOG)"; exit 1; }
echo "target=$target board=$pboard elf_sha256=$SHA verified_sections=$nver" >>"$LOG"
echo "FLASH: PASS (programmed + verified $nver section(s) + reset)"
