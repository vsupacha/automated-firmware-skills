#!/usr/bin/env bash
# Stage 5 (M2 host test): compile the logic layer against the fake board (lib/host) and run its
# unit tests on this PC - no board, no vendor toolchain.
# Usage: host_test.sh [<app-dir> | <func-dir>] [--keep]
#   default: <repo>/lib/func. An app dir is searched for its func/ folder (src/func,
#   proj_cm33_ns/func, ...). Only the shared modules are tested (console, led, button); other
#   files in func/ are listed as not covered.
#   --keep  keep the build folder and print where it is
# Compiler: HOST_CC (gcc/clang/cc-compatible, or "msvc"), else gcc, clang, cc on PATH, else
# Visual Studio C++ (found with vswhere). None: exit 10 ACTION: SETUP.
# Exit 0 = "HOST: PASS"; 1 = FAIL; 10 = developer action.

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck disable=SC1091
. "$REPO_ROOT/lib/common.sh"
require_milestone M2 "host_test.sh (stage 5 host test)"

TARGET=""; KEEP=0
while [ $# -gt 0 ]; do
  case "$1" in --keep) KEEP=1;; -h|--help) sed -n '2,12p' "$0"; exit 0;; --*) die "unknown option $1";; *) TARGET="$1";; esac; shift
done
TARGET="${TARGET:-$REPO_ROOT/lib/func}"
[ -d "$TARGET" ] || die "no folder $TARGET"
TARGET="$(cd "$TARGET" && pwd)"
HOST_DIR="$REPO_ROOT/lib/host"
MODULES="console led button"

# 1. the func folder: the target itself, or the one func/ inside an app (generated trees skipped)
has_module() { local m; for m in $MODULES; do [ -f "$1/$m.c" ] && return 0; done; return 1; }
if has_module "$TARGET"; then
  FUNC="$TARGET"
else
  FUNC=""
  while IFS= read -r d; do
    has_module "$d" || continue
    [ -z "$FUNC" ] || die "several func/ folders in $TARGET ($FUNC, $d) - pass the one to test"
    FUNC="$d"
  done < <(find "$TARGET" \( -name build -o -name libs -o -name mx -o -name .mx -o -name .pio \
             -o -name mtb_shared -o -name bsps -o -name .git \) -prune -o -type d -name func -print)
  if [ -z "$FUNC" ]; then
    if find "$TARGET" -path '*/func/*.cpp' -not -path '*/.pio/*' | grep -q .; then
      die "only C++ func sources in $TARGET (pio-rpi-pico-2w copy) - host tests cover the C lib/func; see docs/board-api.md"
    fi
    die "no func/ folder with $MODULES sources in $TARGET"
  fi
fi
FOUND=""; DEFS=""; SRCS=""
for m in $MODULES; do
  [ -f "$FUNC/$m.c" ] || continue
  FOUND="$FOUND $m"; SRCS="$SRCS $FUNC/$m.c"
  DEFS="$DEFS HOST_HAS_$(echo "$m" | tr 'a-z' 'A-Z')"
done
FOUND="${FOUND# }"
OTHERS="$(cd "$FUNC" && ls -- *.c *.cpp 2>/dev/null | grep -vxE "($(echo "$MODULES" | sed 's/ /|/g'))\.c" | tr '\n' ' ')"
info "func: $FUNC"
info "modules: $FOUND${OTHERS:+ (not covered: $OTHERS)}"

# 2. compiler
find_vcvars() {
  local vswhere="/c/Program Files (x86)/Microsoft Visual Studio/Installer/vswhere.exe" inst
  [ -x "$vswhere" ] || return 1
  inst="$("$vswhere" -latest -products '*' -requires Microsoft.VisualStudio.Component.VC.Tools.x86.x64 \
          -property installationPath 2>/dev/null | tr -d '\r' | head -1)"
  [ -n "$inst" ] || return 1
  inst="$(cygpath -u "$inst" 2>/dev/null || echo "$inst")"
  [ -f "$inst/VC/Auxiliary/Build/vcvars64.bat" ] || return 1
  # the C library headers come from the Windows SDK (UCRT), a separate VS component
  ls "/c/Program Files (x86)/Windows Kits/10/Include/"*/ucrt/stdio.h >/dev/null 2>&1 || return 1
  echo "$inst/VC/Auxiliary/Build/vcvars64.bat"
}
CC_KIND=""; CC=""; MSVC_NO_SDK=""
case "${HOST_CC:-}" in
  "")   for c in gcc clang cc; do command -v "$c" >/dev/null 2>&1 && { CC="$c"; CC_KIND=gnu; break; }; done
        if [ -z "$CC" ]; then VCVARS="$(find_vcvars)" && { CC=cl; CC_KIND=msvc; }; fi;;
  msvc) VCVARS="$(find_vcvars)" && { CC=cl; CC_KIND=msvc; };;
  *)    command -v "$HOST_CC" >/dev/null 2>&1 || die "HOST_CC=$HOST_CC not found"; CC="$HOST_CC"; CC_KIND=gnu;;
esac
[ -z "$CC" ] && [ -x "/c/Program Files (x86)/Microsoft Visual Studio/Installer/vswhere.exe" ] && \
  ! ls "/c/Program Files (x86)/Windows Kits/10/Include/"*/ucrt/stdio.h >/dev/null 2>&1 && MSVC_NO_SDK=1
[ -n "$CC" ] || need_user SETUP "no host C compiler for the host tests${MSVC_NO_SDK:+ (Visual Studio is installed but without the Windows SDK, so it has no C library headers)} - install one of: gcc (MSYS2 / w64devkit on Windows, build-essential on Linux), LLVM clang, or in the Visual Studio Installer the 'Desktop development with C++' workload incl. a Windows 11 SDK; then re-run (or set HOST_CC)"

# 3. build + run in a scratch folder
OUT="$(mktemp -d "${TMPDIR:-/tmp}/fw-host-test.XXXXXX")" || die "mktemp failed"
[ $KEEP = 1 ] || trap 'rm -rf "$OUT"' EXIT
LOG="$OUT/build.log"
EXE="$OUT/test_func"
if [ "$CC_KIND" = gnu ]; then
  CC_VER="$("$CC" --version 2>/dev/null | head -1)"
  FLAGS="-std=c99 -Wall -Wextra -Werror -g"
  # undefined-behaviour sanitizer where the toolchain has its runtime (not MinGW)
  echo 'int main(void){return 0;}' >"$OUT/probe.c"
  "$CC" -fsanitize=undefined -fno-sanitize-recover=all "$OUT/probe.c" -o "$OUT/probe" >/dev/null 2>&1 \
    && FLAGS="$FLAGS -fsanitize=undefined -fno-sanitize-recover=all"
  # shellcheck disable=SC2086
  "$CC" $FLAGS $(for d in $DEFS; do printf -- '-D%s ' "$d"; done) -I"$HOST_DIR" -I"$FUNC" \
    "$HOST_DIR/test_func.c" "$HOST_DIR/board_fake.c" $SRCS -o "$EXE" >"$LOG" 2>&1; rc=$?
else
  w() { cygpath -w "$1"; }
  {
    echo '@echo off'
    # Git Bash drops variables with "(" in the name; vcvars needs them to find vswhere + the SDK
    echo 'if not defined ProgramFiles(x86) set "ProgramFiles(x86)=C:\Program Files (x86)"'
    echo 'if not defined CommonProgramFiles(x86) set "CommonProgramFiles(x86)=C:\Program Files (x86)\Common Files"'
    echo "call \"$(w "$VCVARS")\" >nul || exit /b 1"
    echo "cl 2>\"$(w "$OUT/cl_version.txt")\" >nul"
    printf 'cl /nologo /W4 /WX /TC /D_CRT_SECURE_NO_WARNINGS'
    for d in $DEFS; do printf ' /D%s' "$d"; done
    printf ' /I"%s" /I"%s" "%s" "%s"' "$(w "$HOST_DIR")" "$(w "$FUNC")" "$(w "$HOST_DIR/test_func.c")" "$(w "$HOST_DIR/board_fake.c")"
    for s in $SRCS; do printf ' "%s"' "$(w "$s")"; done
    printf ' /Fe:"%s"\r\n' "$(w "$EXE.exe")"
  } >"$OUT/build.bat"
  (cd "$OUT" && cmd //c "$(w "$OUT/build.bat")") >"$LOG" 2>&1; rc=$?
  CC_VER="$(tr -d '\r' <"$OUT/cl_version.txt" 2>/dev/null | head -1)"
fi
info "compiler: $CC_VER"
if [ $rc -ne 0 ]; then
  tr -d '\r' <"$LOG" | grep -vE '^(test_func|board_fake|console|led|button)\.c$' | sed 's/^/  /' | tail -30
  echo "HOST: FAIL (build - lib/func must compile warning-free on the host too)"; exit 1
fi

"$EXE" "$(winpath "$OUT/capture.txt")" 2>"$OUT/result.txt"; rc=$?
tr -d '\r' <"$OUT/result.txt" | sed 's/^/  /'
[ $KEEP = 1 ] && info "build folder kept: $OUT"
summary="$(tr -d '\r' <"$OUT/result.txt" | sed -n 's/^TESTS: //p' | tail -1)"
if [ $rc -eq 0 ] && [ -n "$summary" ]; then
  echo "HOST: PASS ($FOUND: $summary)"; exit 0
fi
echo "HOST: FAIL (${summary:-test program exit $rc})"; exit 1
