#!/usr/bin/env bash
# Stage 3: build an app with its CMake preset "debug" - the same preset and debug/ folder as the
# VS Code Build button - using Kitware CMake, NXP's Ninja and Arm GNU toolchain (never ST tools).
# Usage: build.sh <app-dir> [--clean] [--allow-warnings]
# Gate: "BUILD: PASS" = cmake exit 0, ELF present, 0 warnings in the app's own src/ (exit 2 = fix
# them, or --allow-warnings). Writes debug/app_<core>.hex and debug/manifest.txt (tools, SDK,
# ELF/HEX sha256, size) only on PASS - the flash stage will require it.

. "$(dirname "$0")/env.sh"
APPDIR=""; CLEAN=0; ALLOW=0
for a in "$@"; do
  case "$a" in --clean) CLEAN=1;; --allow-warnings) ALLOW=1;; --*) die "unknown option $a";; *) APPDIR="$a";; esac
done
[ -n "$APPDIR" ] && [ -f "$APPDIR/mcx-app.env" ] || die "usage: build.sh <app-dir> [--clean] [--allow-warnings]  (an app made by new_app.sh)"
APPDIR="$(cd "$APPDIR" && pwd)"; APP="$(basename "$APPDIR")"
# shellcheck disable=SC1091
. "$APPDIR/mcx-app.env"
load_board "$APP_BOARD"
require_safe_path "$APPDIR" "app" 100
require_build_tools
# per-PC preset files (another PC, moved tools): written / refreshed from this PC's paths
bash "$SKILL_DIR/scripts/open_ide.sh" "$APPDIR" --files-only --refresh >/dev/null || die "could not write the preset files"
mkdir -p "$APPDIR/logs"; LOG="$APPDIR/logs/build-$(ts).log"
fw_warn_gate_start "$APPDIR"      # warnings of an earlier run are counted again
OUTDIR="$APPDIR/debug"; ELF="$OUTDIR/app_$SDK_CORE.elf"
export PATH="$GCC_BIN:$PATH"      # objcopy/size below; the build itself gets its tools from the presets

info "cmake --preset debug + build  ($(winpath "$CMAKE"); log $LOG)"
start=$(date +%s)
( cd "$APPDIR" && "$CMAKE" --preset debug ) >"$LOG" 2>&1; rc=$?
if [ $rc -eq 0 ]; then
  flags=(); [ $CLEAN = 1 ] && flags=(--clean-first)
  ( cd "$APPDIR" && "$CMAKE" --build --preset debug "${flags[@]}" ) >>"$LOG" 2>&1; rc=$?
fi
secs=$(( $(date +%s) - start ))
tr -d '\r' <"$LOG" >"$LOG.tmp" && mv "$LOG.tmp" "$LOG"
grep -qiE 'stmicroelectronics|stm32cube|cube-cmake' "$OUTDIR/CMakeCache.txt" 2>/dev/null \
  && { echo "BUILD: FAIL - an ST tool is in $OUTDIR/CMakeCache.txt (NXP apps use NXP/Kitware tools only); delete debug/ and re-run"; exit 1; }

# warnings in our own sources (<app>/src) vs SDK code
srcw="$(grep -E "[/\\\\]$APP[/\\\\]src[/\\\\][^:]*:[0-9]+:[0-9]+: warning:" "$LOG" | sort -u)"
nsrc=$(printf '%s' "$srcw" | grep -c .); nall=$(grep -c ': warning:' "$LOG"); errs=$(grep -c ': error:' "$LOG")
fw_warn_gate_end "$APPDIR" "$nsrc" "$rc"
echo "cmake exit=$rc  time=${secs}s  warnings(src)=$nsrc  warnings(all)=$nall  errors=$errs"
[ -n "$srcw" ] && echo "$srcw" | head -20
if [ $rc -ne 0 ] || [ ! -f "$ELF" ]; then
  grep -E ': error:|CMake Error|FAILED|undefined reference' "$LOG" | head -20
  echo "BUILD: FAIL  (see $LOG)"; exit 1
fi
if [ "$nsrc" -gt 0 ] && [ $ALLOW = 0 ]; then
  echo "BUILD: WARNINGS ($nsrc in src/) - fix them or re-run with --allow-warnings"; exit 2
fi
arm-none-eabi-objcopy -O ihex "$ELF" "${ELF%.elf}.hex" || die "objcopy failed"
size="$(arm-none-eabi-size "$ELF" | tr -d '\r' | tail -1 | awk '{print $1, $2, $3, $4, $5}')"

{
  echo "# build manifest - written by mcux-sdk-frdmmcxn947/build.sh on PASS, $(date '+%Y-%m-%d %H:%M:%S')"
  echo "app        $APP  board=$APP_BOARD  template=$APP_TEMPLATE  core=$SDK_CORE  sysclk=$SYSCLK_HZ"
  echo "tools      MCUXpresso SDK $SDK_VERSION, Arm GNU $GCC_VERSION, cmake $(cmake_version "$CMAKE") (Kitware), ninja $NINJA_VERSION"
  echo "gcc        $(arm-none-eabi-gcc --version | head -1 | tr -d '\r')"
  echo "size       (text data bss dec hex) $size"
  echo "artifacts (sha256  bytes  file):"
  for f in "$ELF" "${ELF%.elf}.hex"; do
    echo "$(sha256sum "$f" | cut -d' ' -f1) $(wc -c <"$f" | tr -d ' ') $(basename "$f")"
  done
} >"$OUTDIR/manifest.txt"
echo "  $size"
echo "manifest: $OUTDIR/manifest.txt"
grep -E "^[0-9a-f]{64} [0-9]+ app_$SDK_CORE.elf\$" "$OUTDIR/manifest.txt"
echo "BUILD: PASS"
