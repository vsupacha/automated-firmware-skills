#!/usr/bin/env bash
# Stage 4: find the connected board's ST-LINK, check the target read-only, save this PC's bench
# file (probe serial). The board's ST-LINK/V2 has no virtual COM port (console = SWO).
# Usage: discover.sh <board-id> [--serial <stlink-serial>]
# Read-only: hot-plug connect (no reset, no write). On PASS writes <F3_WS>/.bench/<board-id>.env.

. "$(dirname "$0")/env.sh"
require_milestone M1 "discover.sh (stage 4 connect)"
BOARD=""; WANT=""
while [ $# -gt 0 ]; do
  case "$1" in --serial) WANT="$2"; shift;; --*) die "unknown option $1";; *) BOARD="$1";; esac; shift
done
[ -n "$BOARD" ] || die "usage: discover.sh <board-id> [--serial <stlink-serial>]  (boards: $(known_boards))"
load_board "$BOARD"
bench_lock "$BOARD_ID" discover.sh
[ -x "$PROGRAMMER" ] || die "STM32CubeProgrammer CLI $PROGRAMMER_VERSION not found - run check_tools.sh"

info "ST-LINK probes on this PC"
mapfile -t SNS < <(probe_serials)
[ ${#SNS[@]} -gt 0 ] || need_user CONNECT "no ST-LINK found - plug the board's ST-LINK USB (CN1, mini-USB) in and close tools that hold it (STM32CubeIDE, a debugger), then re-run discover.sh"
BOARDS="$(fw_stlink_boards "$PROGRAMMER")"       # "<sn> <ST-LINK board name>" per probe
for s in "${SNS[@]}"; do      # the ST-LINK/V2 reports ":" / "--" for no board name
  b="$(echo "$BOARDS" | awk -v s="$s" 'toupper($1)==toupper(s){print $2}')"; case "$b" in ""|:|--) b=none;; esac
  echo "    $s  board=$b"
done
if [ -n "$WANT" ]; then
  printf '%s\n' "${SNS[@]}" | grep -qix "$WANT" || die "no ST-LINK with serial $WANT"
  SN="$WANT"
elif [ ${#SNS[@]} -eq 1 ]; then
  SN="${SNS[0]}"
elif [ -n "$EXPECTED_STLINK_BOARD" ] && [ "$(echo "$BOARDS" | awk -v b="$EXPECTED_STLINK_BOARD" '$2==b' | wc -l)" -eq 1 ]; then
  SN="$(echo "$BOARDS" | awk -v b="$EXPECTED_STLINK_BOARD" '$2==b{print $1}')"
  info "${#SNS[@]} ST-LINKs connected - $SN is the only one reporting board $EXPECTED_STLINK_BOARD"
else
  need_user CHOOSE "${#SNS[@]} ST-LINKs connected - ask which one is '$BOARD_ID' (its ST-LINK/V2 reports no board name, like an external probe): unplug the others, or re-run with --serial <sn> from the list above"
fi

info "Read-only identity check (hot-plug connect) of $SN"
OUT="$(probe_identity "$SN")"
name="$(echo "$OUT" | sed -n 's/^ *Device name *: *//p' | head -1)"
devid="$(echo "$OUT" | sed -n 's/^ *Device ID *: *//p' | head -1)"
volt="$(echo "$OUT" | sed -n 's/^ *Voltage *: *//p' | head -1)"
sboard="$(echo "$OUT" | sed -n 's/^ *Board *: *//p' | head -1)"
fw="$(echo "$OUT" | sed -n 's/^ *ST-LINK FW *: *//p' | head -1)"
case "$sboard" in :|--) sboard="";; esac
echo "probe serial   $SN"; echo "ST-LINK FW     ${fw:-?}"; echo "ST-LINK board  ${sboard:-none}"; echo "voltage        ${volt:-?}"
echo "device name    ${name:-?}"; echo "device ID      ${devid:-?}"; echo "console        SWO (PB3) through the ST-LINK - no COM port"
fail=0
[ -n "$name" ] || { echo "FAIL: no target answered (board powered? JP1 IDD fitted? CN3 ST-LINK jumpers on?)"; echo "$OUT" | tail -5; fail=1; }
case "$name" in "$EXPECTED_DEVICE_NAME"*) ;; *) [ -n "$name" ] && { echo "FAIL: device '$name' is not $EXPECTED_DEVICE_NAME*"; fail=1; };; esac
[ -z "$EXPECTED_STLINK_BOARD" ] || [ "$sboard" = "$EXPECTED_STLINK_BOARD" ] || { echo "FAIL: ST-LINK reports board '${sboard:-none}', expected $EXPECTED_STLINK_BOARD"; fail=1; }
if [ -n "$EXPECTED_DEVICE_ID" ]; then
  [ "$devid" = "$EXPECTED_DEVICE_ID" ] || { echo "FAIL: device ID $devid != $EXPECTED_DEVICE_ID"; fail=1; }
else
  echo "NOTE: EXPECTED_DEVICE_ID is empty in $BOARD_DIR/board.env - record '$devid' there once confirmed"
fi
[ $fail = 0 ] || { echo "IDENTITY: FAIL"; exit 1; }
echo "IDENTITY: PASS"

mkdir -p "$BENCH_DIR"
KEEP="$(bench_dev_lines "$BENCH_DIR/$BOARD_ID.env")"   # e.g. FLASH_POLICY
cat >"$BENCH_DIR/$BOARD_ID.env" <<EOF
# Bench instance: board '$BOARD_ID' on this PC, written $(date '+%Y-%m-%d %H:%M')
# by cubemx-hal-stm32f303disco/discover.sh. Re-run discover.sh after changing board or USB port.
PROBE_SERIAL=$SN
EOF
[ -z "$KEEP" ] || echo "$KEEP" >>"$BENCH_DIR/$BOARD_ID.env"
info "Saved $BENCH_DIR/$BOARD_ID.env  (PROBE_SERIAL=$SN)"
