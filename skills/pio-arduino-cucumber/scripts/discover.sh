#!/usr/bin/env bash
# Stage 4: find the connected board and save this PC's bench file (bridge VID + USB serial, COM port,
# the chip's MAC address).
# Usage: discover.sh <board-id> [--port <COMx|/dev/tty...>]
# Read-only: esptool reads chip, features, MAC, flash size and the security state through the
# board's USB-UART bridge - the DTR/RTS auto-reset RESTARTS the chip (the running firmware restarts)
# but nothing is written.
# Gates: chip = EXPECTED_CHIP, flash size = EXPECTED_FLASH, secure boot and flash encryption
# disabled. On PASS writes <CUKE_WS>/.bench/<board-id>.env (USB_VID, USB_SERIAL, CONSOLE_PORT, MAC).
# flash.sh then requires the same MAC: a bridge's USB serial alone does not identify the chip.

. "$(dirname "$0")/env.sh"
require_milestone M1 "discover.sh (stage 4 connect)"
BOARD=""; WANT=""
while [ $# -gt 0 ]; do
  case "$1" in --port) WANT="$2"; shift;; --*) die "unknown option $1";; *) BOARD="$1";; esac; shift
done
[ -n "$BOARD" ] || die "usage: discover.sh <board-id> [--port <port>]  (boards: $(known_boards))"
load_board "$BOARD"
bench_lock "$BOARD_ID" discover.sh

info "USB serial ports${USB_VID:+ (VID $USB_VID)} on this PC"
mapfile -t DEVS < <(usb_devices | tr -d '\r' | grep -v '^$')
[ ${#DEVS[@]} -gt 0 ] || need_user CONNECT "no USB serial port found - plug the $BOARD_NAME's UART micro-USB port (the one next to the TX/RX LEDs) into this PC with a data cable (install the bridge driver if Windows shows an unknown device); then re-run discover.sh"
for d in "${DEVS[@]}"; do echo "    $d   (usb-serial port vid pid)"; done

SEL=""
if [ -n "$WANT" ]; then
  for d in "${DEVS[@]}"; do [ "$(echo "$d" | awk '{print $2}')" = "$WANT" ] && SEL="$d"; done
  [ -n "$SEL" ] || die "no USB serial port $WANT"
elif [ ${#DEVS[@]} -eq 1 ]; then
  SEL="${DEVS[0]}"
else
  need_user CHOOSE "${#DEVS[@]} USB serial ports - ask which one is '$BOARD_ID' (unplug/replug shows it), then re-run with --port <port> (list above)"
fi
read -r SER PORT VID PID <<<"$SEL"
if [ -n "$USB_PIDS_APP" ]; then
  case " $USB_PIDS_APP " in *" $PID "*) ;; *) die "USB PID $PID is not the $BOARD_NAME's bridge ($USB_PIDS_APP)";; esac
fi

info "Identity check on $PORT (esptool, read-only - the chip restarts)"
mkdir -p "$BENCH_DIR"
ID="$(IDENTITY_LOG="$BENCH_DIR/$BOARD_ID.identity.log" identity "$PORT")"
val() { echo "$ID" | sed -n "s/^$1=//p"; }
fail=0
echo "usb bridge     serial=$SER  $VID:$PID  ($PORT)"
echo "chip           $(val chip)"
echo "features       $(val features)"
echo "mac            $(val mac)"
echo "flash size     $(val flash)"
echo "secure boot    $(val secure_boot)"
echo "flash crypt    $(val flash_crypt)"
case "$(val chip)" in "$EXPECTED_CHIP "*|"$EXPECTED_CHIP") ;; *) echo "FAIL: chip '$(val chip)' is not $EXPECTED_CHIP"; fail=1;; esac
[ -n "$(val mac)" ] || { echo "FAIL: no MAC read"; fail=1; }
[ -z "$EXPECTED_FLASH" ] || [ "$(val flash)" = "$EXPECTED_FLASH" ] || { echo "FAIL: flash '$(val flash)' != $EXPECTED_FLASH"; fail=1; }
[ "$(val secure_boot)" = Disabled ] || { echo "FAIL: secure boot is '$(val secure_boot)' - stop and ask the user (never change it)"; fail=1; }
[ "$(val flash_crypt)" = Disabled ] || { echo "FAIL: flash encryption is '$(val flash_crypt)' - stop and ask the user (never change it)"; fail=1; }
[ $fail = 0 ] || { echo "IDENTITY: FAIL (esptool output: $BENCH_DIR/$BOARD_ID.identity.log)"; exit 1; }
echo "IDENTITY: PASS"

KEEP="$(bench_dev_lines "$BENCH_DIR/$BOARD_ID.env")"   # e.g. FLASH_POLICY
cat >"$BENCH_DIR/$BOARD_ID.env" <<BENCH
# Bench instance: board '$BOARD_ID' on this PC, written $(date '+%Y-%m-%d %H:%M')
# by pio-arduino-cucumber/discover.sh. Re-run discover.sh after changing board or USB port.
USB_VID=$VID
USB_SERIAL=$SER
CONSOLE_PORT=$PORT
MAC=$(val mac)
BENCH
[ -z "$KEEP" ] || echo "$KEEP" >>"$BENCH_DIR/$BOARD_ID.env"
info "Saved $BENCH_DIR/$BOARD_ID.env  (USB_VID=$VID USB_SERIAL=$SER CONSOLE_PORT=$PORT MAC=$(val mac))"
