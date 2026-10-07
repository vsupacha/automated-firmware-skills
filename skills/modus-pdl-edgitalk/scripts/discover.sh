#!/usr/bin/env bash
# Stage 2a: find the board connected to THIS PC and record it as a bench instance.
# Usage: discover.sh <board-id> [--serial <probe-serial>]
# Lists KitProg3 probes (fw-loader + USB-UART ports). With one probe it is selected
# automatically; with several, pass --serial. Then runs the read-only identity check and,
# on PASS, writes <PSE84_WS>/.bench/<board-id>.env with PROBE_SERIAL and CONSOLE_PORT.
# Every student/PC runs this once; board type data in boards/<id>/ stays untouched.

. "$(dirname "$0")/env.sh"
require_milestone M3 "discover.sh (stage 6 connect)"
BOARD=""; SERIAL=""
while [ $# -gt 0 ]; do
  case "$1" in --serial) SERIAL="$2"; shift;; --*) die "unknown option $1";; *) BOARD="$1";; esac; shift
done
[ -n "$BOARD" ] || die "usage: discover.sh <board-id> [--serial <probe-serial>]"
load_board "$BOARD"
bench_lock "$BOARD_ID" discover.sh

info "KitProg3 probes on this PC"
[ -x "$FW_LOADER" ] && "$FW_LOADER" --device-list 2>&1 | grep -E '^\s+[0-9]+:' || true
ports="$("$PYTHON" -c 'from serial.tools import list_ports
for p in list_ports.comports():
    if p.vid == 0x04B4 and p.serial_number: print(p.serial_number, p.device)' | tr -d '\r')"
[ -n "$ports" ] || need_user CONNECT "no KitProg3 found - plug the board's debug USB port (Edgi-Talk: CN12, AI Kit: KitProg3 USB-C), then re-run discover.sh"
echo "$ports" | sed 's/^/    serial+COM: /'

if [ -z "$SERIAL" ]; then
  n="$(echo "$ports" | wc -l)"
  [ "$n" -eq 1 ] || need_user CHOOSE "$n probes connected - ask which one is '$BOARD_ID', then re-run with --serial <serial> (list above)"
  SERIAL="$(echo "$ports" | cut -d' ' -f1)"
fi
COM="$(echo "$ports" | awk -v s="$SERIAL" 'toupper($1)==toupper(s){print $2}')"
[ -n "$COM" ] || die "probe $SERIAL has no USB-UART port"
# One physical board = one board id. Several boards share the same MPN, so the identity
# check cannot tell an Edgi-Talk from an AI Kit - a mix-up here would flash the wrong image.
for f in "$BENCH_DIR"/*.env; do
  [ -f "$f" ] || continue
  other="$(basename "$f" .env)"
  [ "$other" = "$BOARD_ID" ] && continue
  if grep -qi "^PROBE_SERIAL=$SERIAL\$" "$f"; then
    die "probe $SERIAL is already registered as board '$other' ($f).
       If that was wrong, delete that bench file, then re-run discover.sh for the right board."
  fi
done

info "Read-only identity check of probe $SERIAL"
PSE84_PROBE_SERIAL="$SERIAL" PSE84_CONSOLE="$COM" bash "$SKILL_DIR/scripts/identity_check.sh" "$BOARD_ID" \
  || die "identity check failed - not saving. Is this really a '$BOARD_ID' board?"

mkdir -p "$BENCH_DIR"
KEEP="$(bench_dev_lines "$BENCH_DIR/$BOARD_ID.env")"   # e.g. FLASH_POLICY
cat >"$BENCH_DIR/$BOARD_ID.env" <<EOF
# Bench instance for board '$BOARD_ID' on $(hostname), discovered $(date '+%Y-%m-%d %H:%M')
# by modus-pdl-edgitalk/discover.sh. Re-run discover.sh after changing board or USB port.
PROBE_SERIAL=$SERIAL
CONSOLE_PORT=$COM
EOF
[ -z "$KEEP" ] || echo "$KEEP" >>"$BENCH_DIR/$BOARD_ID.env"
info "Saved $BENCH_DIR/$BOARD_ID.env  (PROBE_SERIAL=$SERIAL CONSOLE_PORT=$COM)"
