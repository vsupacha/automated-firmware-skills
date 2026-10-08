#!/usr/bin/env bash
# Stage 4 (connect): find the board's ART-Link (CMSIS-DAP) probe and save this PC's bench file
# (probe serial + COM port of its virtual COM port).
# Usage: discover.sh <board-id> [--serial <probe-serial>]
# Read-only: pyOCD attaches WITHOUT halt or reset (connect_mode=attach) and reads the CPUID
# register; the running firmware keeps running, nothing is written.
# Gates: probe name = PROBE_NAME, target PYOCD_TARGET connects, CPUID = EXPECTED_CPUID (Cortex-M85),
# the probe's VCP is present. On PASS writes <RTT_WS>/.bench/<board-id>.env.

. "$(dirname "$0")/env.sh"
require_milestone M1 "discover.sh (stage 4 connect)"
BOARD=""; WANT=""
while [ $# -gt 0 ]; do
  case "$1" in --serial) WANT="$(echo "$2" | tr a-z A-Z)"; shift;; --*) die "unknown option $1";; *) BOARD="$1";; esac; shift
done
[ -n "$BOARD" ] || die "usage: discover.sh <board-id> [--serial <probe-serial>]  (boards: $(known_boards))"
load_board "$BOARD"
require_vars PYOCD_TARGET EXPECTED_CPUID PROBE_NAME
bench_lock "$BOARD_ID" discover.sh

info "CMSIS-DAP probes (pyOCD $PYOCD_VERSION from RT-Thread Studio)"
mapfile -t DEVS < <(probes | grep -v '^$')
[ ${#DEVS[@]} -gt 0 ] || need_user CONNECT "no probe found - plug the $BOARD_NAME's DAP-Link USB-C port (ART-Link) into this PC with a data cable, then re-run discover.sh"
for d in "${DEVS[@]}"; do echo "    $d"; done

SEL=""
if [ -n "$WANT" ]; then
  for d in "${DEVS[@]}"; do [ "$(echo "$d" | awk '{print toupper($1)}')" = "$WANT" ] && SEL="$d"; done
  [ -n "$SEL" ] || die "no probe with serial $WANT"
elif [ ${#DEVS[@]} -eq 1 ]; then
  SEL="${DEVS[0]}"
else
  need_user CHOOSE "${#DEVS[@]} probes connected - ask which one is '$BOARD_ID', then re-run with --serial <probe-serial> (list above)"
fi
SER="$(echo "$SEL" | awk '{print $1}')"; PNAME="$(echo "$SEL" | cut -d' ' -f2-)"
case "$PNAME" in *"$PROBE_NAME"*) ;; *) die "probe '$PNAME' is not the $BOARD_NAME's $PROBE_NAME";; esac
PORT="$(probe_port "$SER")"

info "Identity check via $SER (attach, no halt/reset, read-only)"
mkdir -p "$BENCH_DIR"
ID="$(IDENTITY_LOG="$BENCH_DIR/$BOARD_ID.identity.log" identity "$SER")"
val() { echo "$ID" | sed -n "s/^$1=//p"; }
fail=0
echo "probe          $SER  ($PNAME)"
echo "console port   ${PORT:-not found}"
echo "target         $PYOCD_TARGET"
echo "cpuid          $(val cpuid)  (expected $EXPECTED_CPUID)"
echo "core state     $(val state)"
if [ "$(val cpuid)" = "0x" ]; then
  echo "FAIL: no answer from the target (log: $BENCH_DIR/$BOARD_ID.identity.log)"
  need_user CONNECT "the RA8D1 did not answer over SWD - on a new board SWD may be closed until the first program: hold the RST button, re-run discover.sh, release RST about 1 s after it starts (never change security settings to get in)"
fi
[ "$(val cpuid)" = "$(echo "$EXPECTED_CPUID" | tr a-f A-F | sed 's/^0X/0x/')" ] || { echo "FAIL: CPUID $(val cpuid) != $EXPECTED_CPUID"; fail=1; }
case "$(val state)" in *[Ll]ock*) echo "FAIL: core state '$(val state)' - stop and ask the user"; fail=1;; esac
[ -n "$PORT" ] || { echo "FAIL: no COM port with USB serial $SER (VCP driver?)"; fail=1; }
[ $fail = 0 ] || { echo "IDENTITY: FAIL (pyOCD output: $BENCH_DIR/$BOARD_ID.identity.log)"; exit 1; }
echo "IDENTITY: PASS"

KEEP="$(bench_dev_lines "$BENCH_DIR/$BOARD_ID.env")"   # e.g. FLASH_POLICY
cat >"$BENCH_DIR/$BOARD_ID.env" <<EOF
# Bench instance: board '$BOARD_ID' on this PC, written $(date '+%Y-%m-%d %H:%M')
# by scons-rtthread-visionboard/discover.sh. Re-run discover.sh after changing board or USB port.
PROBE_SERIAL=$SER
CONSOLE_PORT=$PORT
EOF
[ -z "$KEEP" ] || echo "$KEEP" >>"$BENCH_DIR/$BOARD_ID.env"
info "Saved $BENCH_DIR/$BOARD_ID.env  (PROBE_SERIAL=$SER CONSOLE_PORT=$PORT)"
