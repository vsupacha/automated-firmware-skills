#!/usr/bin/env bash
# Stage 2a: find the connected board's ST-LINK, check the target read-only, save this PC's bench
# file (probe serial + VCP COM port).
# Usage: discover.sh <board-id> [--serial <stlink-serial>]
# Read-only: hot-plug connect (no reset, no write). On PASS writes <CUBE_WS>/.bench/<board-id>.env.

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
[ ${#SNS[@]} -gt 0 ] || need_user CONNECT "no ST-LINK found - plug the board's ST-LINK USB in and close tools that hold it (STM32CubeIDE, a debugger), then re-run discover.sh"
for s in "${SNS[@]}"; do echo "    $s  VCP=$(find_console_port "$s" | tr -d '\r')"; done
if [ -n "$WANT" ]; then
  printf '%s\n' "${SNS[@]}" | grep -qix "$WANT" || die "no ST-LINK with serial $WANT"
  SN="$WANT"
elif [ ${#SNS[@]} -eq 1 ]; then
  SN="${SNS[0]}"
else
  need_user CHOOSE "${#SNS[@]} ST-LINKs connected - ask which one is '$BOARD_ID', then re-run with --serial <sn> (list above)"
fi
COM="$(find_console_port "$SN" | tr -d '\r')"

info "Read-only identity check (hot-plug connect) of $SN"
OUT="$(probe_identity "$SN")"
name="$(echo "$OUT" | sed -n 's/^ *Device name *: *//p' | head -1)"
devid="$(echo "$OUT" | sed -n 's/^ *Device ID *: *//p' | head -1)"
volt="$(echo "$OUT" | sed -n 's/^ *Voltage *: *//p' | head -1)"
sboard="$(echo "$OUT" | sed -n 's/^ *Board *: *//p' | head -1)"
fw="$(echo "$OUT" | sed -n 's/^ *ST-LINK FW *: *//p' | head -1)"
echo "probe serial   $SN"; echo "ST-LINK FW     ${fw:-?}"; echo "ST-LINK board  ${sboard:-?}"; echo "voltage        ${volt:-?}"
echo "device name    ${name:-?}"; echo "device ID      ${devid:-?}"; echo "console port   ${COM:-not found}"
fail=0
[ -n "$name" ] || { echo "FAIL: no target answered (board powered? target in low-power or read-out protection?)"; echo "$OUT" | tail -5; fail=1; }
case "$name" in "$EXPECTED_DEVICE_NAME"*) ;; *) [ -n "$name" ] && { echo "FAIL: device '$name' is not $EXPECTED_DEVICE_NAME*"; fail=1; };; esac
[ -z "$EXPECTED_STLINK_BOARD" ] || [ "$sboard" = "$EXPECTED_STLINK_BOARD" ] || { echo "FAIL: ST-LINK reports board '${sboard:-none}', expected $EXPECTED_STLINK_BOARD"; fail=1; }
if [ -n "$EXPECTED_DEVICE_ID" ]; then
  [ "$devid" = "$EXPECTED_DEVICE_ID" ] || { echo "FAIL: device ID $devid != $EXPECTED_DEVICE_ID"; fail=1; }
else
  echo "NOTE: EXPECTED_DEVICE_ID is empty in $BOARD_DIR/board.env - record '$devid' there once confirmed"
fi
[ -n "$COM" ] || echo "WARN: no VCP COM port for $SN (VCP disabled in the ST-LINK, or driver missing) - tests need it"
[ $fail = 0 ] || { echo "IDENTITY: FAIL"; exit 1; }
echo "IDENTITY: PASS"

mkdir -p "$BENCH_DIR"
KEEP="$(bench_dev_lines "$BENCH_DIR/$BOARD_ID.env")"   # e.g. FLASH_POLICY
cat >"$BENCH_DIR/$BOARD_ID.env" <<EOF
# Bench instance: board '$BOARD_ID' on this PC, written $(date '+%Y-%m-%d %H:%M')
# by cubemx2-hal2-stm32c562nucleo/discover.sh. Re-run discover.sh after changing board or USB port.
PROBE_SERIAL=$SN
CONSOLE_PORT=$COM
EOF
[ -z "$KEEP" ] || echo "$KEEP" >>"$BENCH_DIR/$BOARD_ID.env"
info "Saved $BENCH_DIR/$BOARD_ID.env  (PROBE_SERIAL=$SN CONSOLE_PORT=${COM:--})"
