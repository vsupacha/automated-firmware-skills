#!/usr/bin/env bash
# Stage 5: program an app (app.hex of its build manifest) into the board of this PC's bench file
# with pyOCD + the board's ART-Link (CMSIS-DAP), read it back, run.
# Usage: flash.sh <app-dir> --yes
#   --yes   required: the agent must have asked the user first (board, app, app.hex sha256 prefix),
#           unless the developer put FLASH_POLICY=auto into this board's bench file
# Gates: app made for this board -> app.hex matches the PASS manifest's sha256 and lies inside code
# flash -> probe with the bench serial found -> identity (CPUID, attach) -> pyocd flash
# --erase=auto (only the sectors app.hex touches) + reset -> every byte of app.hex read back from
# the target and compared. Exit 0 = "FLASH: PASS"; 1 = FAIL.
# Never written: option-setting memory (OFS, security attribution, ID code, DLM) - app.hex has none
# of it (build.sh removes .option_setting_*); data flash and the QSPI flash are not touched either.

. "$(dirname "$0")/env.sh"
require_milestone M1 "flash.sh (stage 5 flash)"
APPDIR=""; YES=0
while [ $# -gt 0 ]; do
  case "$1" in --yes) YES=1;; --*) die "unknown option $1";; *) APPDIR="$1";; esac; shift
done
[ -n "$APPDIR" ] && [ -f "$APPDIR/rtt-app.env" ] || die "usage: flash.sh <app-dir> --yes"
APPDIR="$(cd "$APPDIR" && pwd)"
# shellcheck disable=SC1091
. "$APPDIR/rtt-app.env"
load_board "$APP_BOARD"
require_vars PROBE_SERIAL PYOCD_TARGET EXPECTED_CPUID CODE_FLASH_START CODE_FLASH_END
M="$APPDIR/build/manifest.txt"; HEX="$APPDIR/app.hex"
mkdir -p "$APPDIR/logs"; LOG="$APPDIR/logs/flash-$(ts).log"

# 1. image + manifest gate
[ -f "$M" ] || die "no build manifest - run build.sh until BUILD: PASS"
want="$(sed -n 's/^\([0-9a-f]\{64\}\) [0-9]* app.hex$/\1/p' "$M")"
SHA="$(sha256sum "$HEX" 2>/dev/null | cut -d' ' -f1)"
[ -n "$want" ] && [ "$want" = "$SHA" ] || die "app.hex does not match the PASS manifest (rebuilt or edited after the build?) - run build.sh"
read -r LO HI <<<"$(sed -n 's/^flash \(0x[0-9A-Fa-f]*\) \(0x[0-9A-Fa-f]*\) app.hex$/\1 \2/p' "$M")"
[ -n "$HI" ] && [ $(( LO )) -ge $(( CODE_FLASH_START )) ] && [ $(( HI )) -le $(( CODE_FLASH_END )) ] \
  || die "manifest range '$LO..$HI' is not inside code flash - rebuild with build.sh"
require_flash_approval $YES "program board '$APP_BOARD' with app $(basename "$APPDIR") (app.hex sha256 ${SHA:0:16}..., $LO..$HI)"
bench_lock "$BOARD_ID" flash.sh
info "App $(basename "$APPDIR") for board $APP_BOARD, app.hex sha256 ${SHA:0:16}... ($LO..$HI)"

# 2. probe + identity (read-only)
probes | awk '{print toupper($1)}' | grep -qx "$(echo "$PROBE_SERIAL" | tr a-z A-Z)" \
  || die "probe $PROBE_SERIAL not connected (run discover.sh after changing board/USB port)"
ID="$(IDENTITY_LOG="$LOG" identity "$PROBE_SERIAL")"
val() { echo "$ID" | sed -n "s/^$1=//p"; }
echo "identity: probe=$PROBE_SERIAL cpuid=$(val cpuid) state='$(val state)'"
[ "$(val cpuid)" = "$(echo "$EXPECTED_CPUID" | tr a-f A-F | sed 's/^0X/0x/')" ] || die "CPUID $(val cpuid) != $EXPECTED_CPUID - not flashing"
case "$(val state)" in *[Ll]ock*) die "core state '$(val state)' - stop and ask the user";; esac

# 3. program (sector erase of the touched sectors only) + reset
info "pyocd flash $PYOCD_TARGET --erase=auto app.hex, log $LOG"
pyocd_run flash -u "$PROBE_SERIAL" -t "$PYOCD_TARGET" -f "${PYOCD_FREQ:-1000000}" --erase=auto "$(winpath "$HEX")" >>"$LOG"; rc=$?
grep -iE '(erased|programmed|bytes|error|fail)' "$LOG" | grep -v "Overlapping" | tail -4 | sed 's/^/  /'
[ $rc -eq 0 ] && ! grep -qiE '^[0-9]+ [CE] |error' "$LOG" || { echo "FLASH: FAIL (pyocd exit $rc, see $LOG)"; exit 1; }

# 4. read back every byte of app.hex (attach, no halt) and compare
RB="$APPDIR/build/readback.bin"; rm -f "$RB"
pyocd_run cmd -u "$PROBE_SERIAL" -t "$PYOCD_TARGET" -f "${PYOCD_FREQ:-1000000}" -O connect_mode=attach \
  -c "savemem $LO $(( HI - LO )) $(winpath "$RB")" >>"$LOG"
CMP="$("$PYTHON" - "$(winpath "$HEX")" "$(winpath "$RB")" "$LO" <<'EOF'
import sys
hexf, rb, lo = sys.argv[1], sys.argv[2], int(sys.argv[3], 16)
try:
    data = open(rb, "rb").read()
except OSError:
    print("noread 0"); sys.exit()
base, n, bad = 0, 0, 0
for line in open(hexf):
    cnt, a, t = int(line[1:3], 16), int(line[3:7], 16), int(line[7:9], 16)
    if t == 4: base = int(line[9:13], 16) << 16
    elif t == 2: base = int(line[9:13], 16) << 4
    elif t == 0:
        for i in range(cnt):
            off = base + a + i - lo
            n += 1
            if off >= len(data) or data[off] != int(line[9 + 2 * i:11 + 2 * i], 16):
                bad += 1
print("%s %d %d" % ("ok" if bad == 0 and n > 0 else "bad", n, bad))
EOF
)"
read -r verdict nbytes nbad <<<"$(echo "$CMP" | tr -d '\r')"
echo "readback: $nbytes bytes compared, ${nbad:-?} different"
[ "$verdict" = ok ] || { echo "FLASH: FAIL (read-back mismatch or no read-back, see $LOG)"; exit 1; }
rm -f "$RB"
echo "board=$APP_BOARD probe=$PROBE_SERIAL app_sha256=$SHA" >>"$LOG"
echo "FLASH: PASS (app.hex $LO..$HI written, $nbytes bytes read back equal, reset; console on ${CONSOLE_PORT:-?})"
