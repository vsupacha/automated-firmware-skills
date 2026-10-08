#!/usr/bin/env bash
# Stage 3: build an app with RT-Thread's scons + GNU Arm (both from RT-Thread Studio) and write
# the build manifest.
# Usage: build.sh <app-dir> [--clean] [--allow-warnings]
# Gate: "BUILD: PASS" = scons exit 0, rtthread.elf present and rebuilt or up to date, 0 warnings
# in the app's own src/ (an incremental build only recompiles changed files; --clean re-checks
# every file), and app.hex lies inside code flash.
# app.hex = rtthread.elf WITHOUT the FSP's option-setting sections (.option_setting_*: OFS, SAS,
# security/data-flash settings at 0x0300A100.. and 0x27030080..) - the image flash.sh programs.
# Exit 0 PASS, 1 FAIL, 2 warnings in src/ (fix them, or --allow-warnings).
# The manifest (build/manifest.txt: tools, sizes, app.hex address range, sha256 of rtthread.elf
# and app.hex) is written only on PASS.

. "$(dirname "$0")/env.sh"
APPDIR=""; CLEAN=0; ALLOW=0
for a in "$@"; do
  case "$a" in --clean) CLEAN=1;; --allow-warnings) ALLOW=1;; --*) die "unknown option $a";; *) APPDIR="$a";; esac
done
[ -n "$APPDIR" ] && [ -f "$APPDIR/rtt-app.env" ] || die "usage: build.sh <app-dir> [--clean] [--allow-warnings]  (an app made by new_app.sh)"
APPDIR="$(cd "$APPDIR" && pwd)"
require_safe_path "$APPDIR" "app" 100
# shellcheck disable=SC1091
. "$APPDIR/rtt-app.env"
load_board "$APP_BOARD"
require_vars CODE_FLASH_START CODE_FLASH_END
[ -n "$(scons_version)" ] || need_user SETUP "RT-Thread env (scons) not found in $RTT_STUDIO_HOME - run check_tools.sh"
[ -x "$GCC_BIN/arm-none-eabi-gcc.exe" ] || need_user SETUP "GNU Arm $GCC_VERSION not found ($GCC_BIN) - install it in RT-Thread Studio's SDK Manager, then re-run"
mkdir -p "$APPDIR/logs" "$APPDIR/build"; LOG="$APPDIR/logs/build-$(ts).log"; ELF="$APPDIR/rtthread.elf"

[ $CLEAN = 1 ] && { info "scons -c"; scons_run "$APPDIR" -c >>"$LOG" 2>&1; }
info "scons -j8 (GCC $GCC_VERSION, log $LOG)"
start=$(date +%s); sleep 1
scons_run "$APPDIR" -j8 >>"$LOG" 2>&1; rc=$?
secs=$(( $(date +%s) - start ))
tr -d '\r' <"$LOG" >"$LOG.tmp" && mv "$LOG.tmp" "$LOG"

# warnings in our own sources (src/), errors anywhere
srcw="$(grep -E "(^|[/\\\\])src[/\\\\][^:]*:[0-9]+:[0-9]+: warning:" "$LOG" | sort -u)"
nsrc=$(printf '%s' "$srcw" | grep -c . ); nall=$(grep -c ': warning:' "$LOG"); errs=$(grep -c ': error:' "$LOG")
fresh=1; [ -f "$ELF" ] && [ "$(date -r "$ELF" +%s)" -ge "$start" ] || fresh=0
echo "scons exit=$rc  time=${secs}s  warnings(src)=$nsrc  warnings(all)=$nall  errors=$errs  elf=$([ $fresh = 1 ] && echo rebuilt || echo up-to-date)"
grep -A1 -E '^ +text' "$LOG" | tail -2 | sed 's/^/  /'
[ -n "$srcw" ] && echo "$srcw" | head -20
if [ $rc -ne 0 ] || [ ! -f "$ELF" ]; then
  grep -E ': error:|Error|error:' "$LOG" | head -20
  echo "BUILD: FAIL  (see $LOG)"; exit 1
fi
if [ "$nsrc" -gt 0 ] && [ $ALLOW = 0 ]; then
  echo "BUILD: WARNINGS ($nsrc in src/) - fix them or re-run with --allow-warnings"; exit 2
fi

# app.hex: everything except the option-setting sections; every record must be in code flash
"$GCC_BIN/arm-none-eabi-objcopy" -O ihex --remove-section='.option_setting*' "$(winpath "$ELF")" "$(winpath "$APPDIR/app.hex")" \
  || { echo "BUILD: FAIL (objcopy app.hex)"; exit 1; }
RANGE="$("$PYTHON" - "$(winpath "$APPDIR/app.hex")" <<'EOF'
import sys
lo, hi, base = None, None, 0
for line in open(sys.argv[1]):
    n, a, t = int(line[1:3], 16), int(line[3:7], 16), int(line[7:9], 16)
    if t == 4: base = int(line[9:13], 16) << 16
    elif t == 2: base = int(line[9:13], 16) << 4
    elif t == 0:
        s = base + a; lo = s if lo is None else min(lo, s); hi = s + n if hi is None else max(hi, s + n)
print("0x%08X 0x%08X" % (lo, hi))
EOF
)"
read -r LO HI <<<"$(echo "$RANGE" | tr -d '\r')"
echo "app.hex range $LO..$HI (code flash $CODE_FLASH_START..$CODE_FLASH_END; option settings removed)"
[ $(( LO )) -ge $(( CODE_FLASH_START )) ] && [ $(( HI )) -le $(( CODE_FLASH_END )) ] \
  || { echo "BUILD: FAIL (app.hex $LO..$HI is not inside code flash)"; exit 1; }

# manifest: what was used, and the sha256 of what flash.sh may program
{
  echo "# build manifest - written by scons-rtthread-visionboard/build.sh on PASS, $(date '+%Y-%m-%d %H:%M:%S')"
  echo "app        $(basename "$APPDIR")  board=$APP_BOARD  template=$APP_TEMPLATE  sdk=$APP_SDK"
  echo "gcc        $("$GCC_BIN/arm-none-eabi-gcc" --version | head -1 | tr -d '\r')"
  echo "scons      $(scons_version)"
  echo "rt-thread  $(sed -n 's/^#define RT_VERSION_\(MAJOR\|MINOR\|PATCH\) *\([0-9]*\).*/\2/p' "$APPDIR/rt-thread/include/rtdef.h" | paste -sd. -)"
  grep -A1 -E '^ +text' "$LOG" | tail -1 | sed 's/^ */size       text data bss dec hex: /'
  echo "artifacts (sha256  bytes  file):"
  for f in rtthread.elf app.hex; do
    echo "$(sha256sum "$APPDIR/$f" | cut -d' ' -f1) $(wc -c <"$APPDIR/$f" | tr -d ' ') $f"
  done
  echo "flash $LO $HI app.hex"
} >"$APPDIR/build/manifest.txt"
echo "manifest: $APPDIR/build/manifest.txt"
grep -E '^[0-9a-f]{64} [0-9]+ app.hex$' "$APPDIR/build/manifest.txt"
echo "BUILD: PASS"
