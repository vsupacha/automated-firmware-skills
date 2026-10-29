#!/usr/bin/env bash
# Stage 4: find the connected board's MCU-Link, check what it reports read-only, save this PC's
# bench file (probe serial + VCOM COM port).
# Usage: discover.sh <board-id> [--serial <probe-serial>]
# Read-only: LinkServer probes + probe dapinfo (CMSIS-DAP info of the MCU-Link; no target access, no
# reset, no firmware update). On PASS writes <MCX_WS>/.bench/<board-id>.env.

. "$(dirname "$0")/env.sh"
require_milestone M1 "discover.sh (stage 4 connect)"
BOARD=""; WANT=""
while [ $# -gt 0 ]; do
  case "$1" in --serial) WANT="$2"; shift;; --*) die "unknown option $1";; *) BOARD="$1";; esac; shift
done
[ -n "$BOARD" ] || die "usage: discover.sh <board-id> [--serial <probe-serial>]  (boards: $(known_boards))"
load_board "$BOARD"
require_vars EXPECTED_TARGET EXPECTED_PROBE_BOARD
require_linkserver
bench_lock "$BOARD_ID" discover.sh

info "LinkServer probes on this PC"
mapfile -t ROWS < <(probe_list)
[ ${#ROWS[@]} -gt 0 ] || need_user CONNECT "no MCU-Link / CMSIS-DAP probe found - plug the board's USB-C J17 (MCU-Link) in and close tools that hold it (a debug session in VS Code), then re-run discover.sh"
for r in "${ROWS[@]}"; do echo "    ${r%% *}  target=${r#* }  VCOM=$(find_console_port "${r%% *}" | tr -d '\r')"; done
if [ -n "$WANT" ]; then
  printf '%s\n' "${ROWS[@]}" | awk '{print $1}' | grep -qix "$WANT" || die "no probe with serial $WANT"
  SN="$WANT"
elif [ ${#ROWS[@]} -eq 1 ]; then
  SN="${ROWS[0]%% *}"
elif [ "$(printf '%s\n' "${ROWS[@]}" | awk -v t="$LINKSERVER_DEVICE" '$2==t' | wc -l)" -eq 1 ]; then
  SN="$(printf '%s\n' "${ROWS[@]}" | awk -v t="$LINKSERVER_DEVICE" '$2==t{print $1}')"
  info "${#ROWS[@]} probes connected - $SN is the only one reporting $LINKSERVER_DEVICE"
else
  need_user CHOOSE "${#ROWS[@]} probes connected - ask which one is '$BOARD_ID' (target= column), then re-run with --serial <serial> (list above)"
fi
COM="$(find_console_port "$SN" | tr -d '\r')"

info "Read-only identity check (CMSIS-DAP info) of $SN"
OUT="$(probe_dapinfo "$SN")"
target="$(dap_field "$OUT" "Target Device Name")"; pboard="$(dap_field "$OUT" "Target Board Name")"
fw="$(dap_field "$OUT" "Firmware Version")"; prod="$(dap_field "$OUT" "Product Name")"
echo "probe serial   $SN"; echo "probe          ${prod:-?}  (firmware ${fw:-?})"
echo "target device  ${target:-?}"; echo "target board   ${pboard:-?}"; echo "console port   ${COM:-not found}"
fail=0
[ -n "$prod" ] || { echo "FAIL: the probe did not answer dapinfo"; echo "$OUT" | tail -5; fail=1; }
[ "$target" = "$EXPECTED_TARGET" ] || { [ -n "$prod" ] && echo "FAIL: probe reports target '${target:-none}', expected $EXPECTED_TARGET"; fail=1; }
[ "$pboard" = "$EXPECTED_PROBE_BOARD" ] || { [ -n "$prod" ] && echo "FAIL: probe reports board '${pboard:-none}', expected $EXPECTED_PROBE_BOARD"; fail=1; }
[ -n "$COM" ] || echo "WARN: no VCOM port for $SN (J18 shorted = VCOM off, or the driver is missing) - tests need it"
[ $fail = 0 ] || { echo "IDENTITY: FAIL"; exit 1; }
echo "IDENTITY: PASS"

mkdir -p "$BENCH_DIR"
KEEP="$(bench_dev_lines "$BENCH_DIR/$BOARD_ID.env")"   # e.g. FLASH_POLICY
cat >"$BENCH_DIR/$BOARD_ID.env" <<EOF
# Bench instance: board '$BOARD_ID' on this PC, written $(date '+%Y-%m-%d %H:%M')
# by mcux-sdk-frdmmcxn947/discover.sh. Re-run discover.sh after changing board or USB port.
PROBE_SERIAL=$SN
CONSOLE_PORT=$COM
EOF
[ -z "$KEEP" ] || echo "$KEEP" >>"$BENCH_DIR/$BOARD_ID.env"
info "Saved $BENCH_DIR/$BOARD_ID.env  (PROBE_SERIAL=$SN CONSOLE_PORT=${COM:--})"
