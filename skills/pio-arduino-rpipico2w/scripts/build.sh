#!/usr/bin/env bash
# Stage 4: build an app with PlatformIO and write the build manifest.
# Usage: build.sh <app-dir> [--clean] [--allow-warnings]
# Gate: "BUILD: PASS" = pio exit 0, firmware.uf2/.elf present, 0 warnings in the app's own src/
# (an incremental build only recompiles changed files; --clean re-checks every file).
# Exit 0 PASS, 1 FAIL, 2 warnings in src/ (fix them, or --allow-warnings).
# The manifest (.pio/build/<env>/manifest.txt: tools, platform commit, packages, sizes, sha256) is
# written only on PASS - flash.sh requires it.

. "$(dirname "$0")/env.sh"
APPDIR=""; CLEAN=0; ALLOW=0
for a in "$@"; do
  case "$a" in --clean) CLEAN=1;; --allow-warnings) ALLOW=1;; --*) die "unknown option $a";; *) APPDIR="$a";; esac
done
[ -n "$APPDIR" ] && [ -f "$APPDIR/pico-app.env" ] || die "usage: build.sh <app-dir> [--clean] [--allow-warnings]  (an app made by new_app.sh)"
APPDIR="$(cd "$APPDIR" && pwd)"
require_safe_path "$APPDIR" "app" 120
[ -n "$PIO" ] || die "PlatformIO not found - run check_tools.sh"
# shellcheck disable=SC1091
. "$APPDIR/pico-app.env"
ENV="$APP_PIO_ENV"; OUT="$APPDIR/.pio/build/$ENV"
mkdir -p "$APPDIR/logs"; LOG="$APPDIR/logs/build-$(ts).log"

[ $CLEAN = 1 ] && { info "pio run -t clean"; "$PIO" run -d "$APPDIR" -e "$ENV" -t clean >>"$LOG" 2>&1; }
info "pio run -e $ENV  (log $LOG; the first build installs the platform + arduino-pico, ~1.5 GB)"
start=$(date +%s); sleep 1
"$PIO" run -d "$APPDIR" -e "$ENV" >>"$LOG" 2>&1; rc=$?
secs=$(( $(date +%s) - start ))
tr -d '\r' <"$LOG" >"$LOG.tmp" && mv "$LOG.tmp" "$LOG"

# warnings in our own sources (src/) vs the framework
srcw="$(grep -E '(^|[/\\])src[/\\][^:]*:[0-9]+:[0-9]+: warning:' "$LOG" | sort -u)"
nsrc=$(printf '%s' "$srcw" | grep -c . ); nall=$(grep -c ': warning:' "$LOG")
errs=$(grep -c ': error:' "$LOG")
# SCons relinks only when an object changed: an unchanged firmware after exit 0 is up to date
have=1; fresh=1
for f in firmware.uf2 firmware.elf; do
  [ -f "$OUT/$f" ] || have=0
  [ -f "$OUT/$f" ] && [ "$(date -r "$OUT/$f" +%s)" -ge "$start" ] || fresh=0
done
echo "pio exit=$rc  time=${secs}s  warnings(src)=$nsrc  warnings(all)=$nall  errors=$errs  uf2=$([ $fresh = 1 ] && echo rebuilt || echo up-to-date)"
grep -E '^(RAM|Flash):' "$LOG" | sed 's/^/  /'
[ -n "$srcw" ] && echo "$srcw" | head -20

if [ $rc -ne 0 ] || [ $have = 0 ]; then
  grep -E ': error:|Error|error:' "$LOG" | head -20
  echo "BUILD: FAIL  (see $LOG)"; exit 1
fi
if [ "$nsrc" -gt 0 ] && [ $ALLOW = 0 ]; then
  echo "BUILD: WARNINGS ($nsrc in src/) - fix them or re-run with --allow-warnings"; exit 2
fi

# manifest: what was used, and the sha256 of what flash.sh may program
platdir=""
for d in "$PIO_HOME"/platforms/*/; do
  [ -d "$d/.git" ] && [ "$(git -C "$d" rev-parse HEAD 2>/dev/null)" = "${APP_PIO_PLATFORM##*#}" ] && platdir="${d%/}"
done
{
  echo "# build manifest - written by pio-arduino-rpipico2w/build.sh on PASS, $(date '+%Y-%m-%d %H:%M:%S')"
  echo "app        $(basename "$APPDIR")  board=$APP_BOARD  template=$APP_TEMPLATE  env=$ENV"
  echo "pio        $("$PIO" --version | tr -d '\r')"
  echo "platform   $APP_PIO_PLATFORM"
  [ -n "$platdir" ] && echo "platform-dir $(basename "$platdir")"
  echo "packages:"
  "$PIO" pkg list -d "$APPDIR" -e "$ENV" 2>/dev/null | tr -d '\r' \
    | grep -E '^(Platform |[│├└─ ]+[a-z])' | sed 's/ (required:.*//; s/^[│├└─ ]*/  /'
  grep -E '^(RAM|Flash):' "$LOG" | sed 's/^/size  /'
  echo "artifacts (sha256  bytes  file):"
  for f in firmware.uf2 firmware.elf firmware.bin; do
    [ -f "$OUT/$f" ] && echo "$(sha256sum "$OUT/$f" | cut -d' ' -f1) $(wc -c <"$OUT/$f" | tr -d ' ') $f"
  done
} >"$OUT/manifest.txt"
echo "manifest: $OUT/manifest.txt"
grep ' firmware.uf2$' "$OUT/manifest.txt"
echo "BUILD: PASS"
