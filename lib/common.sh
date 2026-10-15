# Shared shell helpers for every skill (sourced by skills/<skill>/scripts/env.sh).
# The skill's env.sh sets SKILL_DIR, SKILL_NAME and REPO_ROOT first, then sources this file, then
# calls fw_init_boards <workspace> [<boards-dir override>].
#
# Exit codes used by all stage scripts (docs/workflow.md):
#   0  gate passed            1  failed            2  passed with warnings (build: fix them)
#   10 developer action needed: the script printed "ACTION: <TYPE> <what to do>" - relay it to the
#      user, wait until they confirm, then re-run the same command

die()  { echo "ERROR: $*" >&2; exit 1; }
info() { echo "==> $*"; }
ts()   { date +%Y%m%d-%H%M%S; }
winpath() { if command -v cygpath >/dev/null 2>&1; then cygpath -m "$1"; else echo "$1"; fi; }

# need_user <TYPE> <message...>: stop and hand over to the developer (exit 10).
# TYPE: SETUP (install tools/drivers/packs, accept licences, change system or git settings)
#       CONNECT (plug the board / probe, hold a boot button)   POWER_CYCLE   JUMPER (switches,
#       solder bridges, unplug accessories)   APPROVE (flash, delete)   CHOOSE (pick one of several)
#       PRESS / OBSERVE are used inside interactive tests (serial_test.py)
need_user() {
  local type="$1"; shift
  echo "ACTION: $type $*"
  exit 10
}

# Release scope: <repo>/milestones.env lists the active milestones (FW_ACTIVE_MILESTONES overrides).
fw_active_milestones() {
  if [ -n "$FW_ACTIVE_MILESTONES" ]; then echo "$FW_ACTIVE_MILESTONES"; return 0; fi
  sed -n 's/^ACTIVE_MILESTONES="\{0,1\}\([^"#]*\)"\{0,1\}.*/\1/p' "$REPO_ROOT/milestones.env" 2>/dev/null | head -1
}
# require_milestone <M?> <what>: stop (exit 10) unless that milestone is active in this release
require_milestone() {
  local active; active="$(fw_active_milestones)"
  case " $active " in *" $1 "*) return 0;; esac
  need_user SETUP "$2 belongs to milestone $1, which is not active in this release (active: ${active:-none}). Enabling it is the developer's decision: add $1 to ACTIVE_MILESTONES in $REPO_ROOT/milestones.env, or export FW_ACTIVE_MILESTONES=\"${active:+$active }$1\" for one session"
}

# fw_default_ws: apps workspace = <repo>/apps inside the repo checkout, else ./apps
fw_default_ws() {
  case "$(pwd)/" in
    "$REPO_ROOT"/*) echo "$REPO_ROOT/apps";;
    *)              echo "$PWD/apps";;
  esac
}

# fw_init_boards <workspace> [<repo boards dir>]: board profile search path
#   1. <project>/boards  - the user's own boards, next to the apps workspace (survives updates)
#   2. <repo>/boards     - boards shipped with the skills (or the override)
fw_init_boards() {
  BOARDS_DIR="${2:-$REPO_ROOT/boards}"
  [ -d "$BOARDS_DIR" ] || { echo "ERROR: no boards folder at $BOARDS_DIR - keep skills/ and boards/ together (repo layout)" >&2; exit 1; }
  BOARDS_DIR="$(cd "$BOARDS_DIR" && pwd)"
  PROJECT_BOARDS_DIR="$(dirname "$1")/boards"
  BOARDS_DIRS=()
  if [ -d "$PROJECT_BOARDS_DIR" ]; then
    PROJECT_BOARDS_DIR="$(cd "$PROJECT_BOARDS_DIR" && pwd)"
    [ "$PROJECT_BOARDS_DIR" != "$BOARDS_DIR" ] && BOARDS_DIRS+=("$PROJECT_BOARDS_DIR")
  fi
  BOARDS_DIRS+=("$BOARDS_DIR")
}

# board_profile_dir <id>: first <boards>/<id>/<skill> folder with a board.env
board_profile_dir() {
  local d
  for d in "${BOARDS_DIRS[@]}"; do
    [ -f "$d/$1/$SKILL_NAME/board.env" ] && { echo "$d/$1/$SKILL_NAME"; return 0; }
  done
  return 1
}

# known_boards: ids of boards with a profile for this skill, in any boards folder
known_boards() {
  local d f seen=" "
  for d in "${BOARDS_DIRS[@]}"; do
    for f in "$d"/*/"$SKILL_NAME"/board.env; do
      [ -f "$f" ] || continue
      f="${f%/"$SKILL_NAME"/board.env}"; f="${f##*/}"
      [ "${f#_}" = "$f" ] || continue
      case "$seen" in *" $f "*) continue;; esac
      seen="$seen$f "; printf '%s ' "$f"
    done
  done
}

# fw_load_profile <id>: board type (parent via BOARD_EXTENDS, then the board) -> bench instance
# (BENCH_DIR/<id>.env, this PC). Sets BOARD_DIR, BOARD_PARENT_DIR, BENCH_FILE.
fw_load_profile() {
  BOARD_DIR="$(board_profile_dir "$1")" || die "unknown board '$1'. Known: $(known_boards)
       A custom board goes in ${PROJECT_BOARDS_DIR}/$1/$SKILL_NAME/board.env (copy $BOARDS_DIR/_template)."
  BOARD_PARENT_DIR=""
  local parent; parent="$(sed -n 's/^BOARD_EXTENDS=\([A-Za-z0-9_-]*\).*/\1/p' "$BOARD_DIR/board.env")"
  if [ -n "$parent" ]; then
    BOARD_PARENT_DIR="$(board_profile_dir "$parent")" || die "board '$1' extends unknown board '$parent'"
    # shellcheck disable=SC1090
    . "$BOARD_PARENT_DIR/board.env"
  fi
  # shellcheck disable=SC1090
  . "$BOARD_DIR/board.env"
  BENCH_FILE="$BENCH_DIR/$1.env"
  # shellcheck disable=SC1090
  [ -f "$BENCH_FILE" ] && . "$BENCH_FILE"
  return 0
}

# path_problem <path> [maxlen]: print why a path is unsafe for the toolchain, or nothing.
# Spaces break ModusToolbox make and some generators (set PATH_ALLOW_SPACES=1 where they don't);
# non-ASCII (e.g. Thai) characters break GCC/make/configurators; long paths hit Windows' 260-char
# limit deep inside generated/build trees.
path_problem() {
  local p="$1" max="$2" why="" n
  [ "${PATH_ALLOW_SPACES:-0}" = 1 ] || case "$p" in *" "*) why="contains a space";; esac
  case "$p" in *"'"*|*'"'*) why="${why:+$why, }contains a quote";; esac
  if LC_ALL=C printf '%s' "$p" | LC_ALL=C grep -q '[^ -~]'; then
    why="${why:+$why, }contains non-ASCII (non-English) characters"
  fi
  if [ -n "$max" ]; then
    n="$(winpath "$p" | tr -d '\r\n' | wc -c)"; n=$((n))
    [ "$n" -gt "$max" ] && why="${why:+$why, }is $n characters long (limit $max: Windows 260-char paths break the tools deeper inside)"
  fi
  [ -n "$why" ] && echo "$why"
}

# require_safe_path <path> <what> [maxlen]
require_safe_path() {
  local why; why="$(path_problem "$1" "$3")"
  [ -z "$why" ] || die "$2 path '$1' $why. Use a short folder with only English letters, digits, - and _ (e.g. ${PATH_EXAMPLE:-C:/fw-ws})"
}

# path_synced <path>: the sync service if the path is inside a cloud-synced folder
path_synced() {
  case "$(echo "$1" | tr 'A-Z' 'a-z')" in
    *dropbox*) echo Dropbox;; *onedrive*) echo OneDrive;; *"google drive"*|*googledrive*) echo "Google Drive";;
  esac
}

# require_vars VAR...: die if any profile/bench variable is empty
require_vars() {
  local v empty=""
  for v in "$@"; do [ -n "${!v}" ] || empty="$empty $v"; done
  [ -z "$empty" ] && return 0
  die "board '$BOARD_ID' has no value for:$empty
       Board-type values go in $BOARD_DIR/board.env; this PC's serial/COM port come from
       'discover.sh $BOARD_ID' (writes $BENCH_DIR/$BOARD_ID.env)."
}

# ---- bench instance: developer settings, flash policy, board lock (board stages) -------------------
# Lines of <bench>/<id>.env that belong to the developer, not to discover.sh; discover.sh keeps them
# when it rewrites the file:  FLASH_POLICY=ask|auto  (default ask)
BENCH_DEV_KEYS="FLASH_POLICY"
# bench_dev_lines <bench-file>: the developer's lines of an existing bench file (print before rewriting)
bench_dev_lines() {
  local k
  [ -f "$1" ] || return 0
  for k in $BENCH_DEV_KEYS; do grep "^$k=" "$1" | tail -1; done
}

# flash_policy: "auto" only when the developer wrote FLASH_POLICY=auto into this board's bench file
# (read from the file itself - an environment variable cannot switch approval off). Else "ask".
flash_policy() {
  local p=""
  [ -f "$BENCH_FILE" ] && p="$(sed -n 's/^FLASH_POLICY=\([a-z]*\)[[:space:]]*$/\1/p' "$BENCH_FILE" | tail -1)"
  case "$p" in auto) echo auto;; *) echo ask;; esac
}
# require_flash_approval <yes 0|1> <what is about to happen>: --yes, or FLASH_POLICY=auto, or exit 10
require_flash_approval() {
  [ "$1" = 1 ] && return 0
  if [ "$(flash_policy)" = auto ]; then
    echo "NOTE: FLASH_POLICY=auto in $BENCH_FILE - $2 without asking (the developer's setting for this board)"
    return 0
  fi
  need_user APPROVE "$2 - re-run with --yes after the user agrees"
}

# bench_lock <board-id> <tool>: exclusive use of this PC's board by one flash/test/debug run.
# Lock = <bench>/<id>.lock/ (mkdir is atomic) with an owner file; released on exit. A lock whose
# process is gone, or that came from another PC through a synced folder, is stale and replaced.
# Child scripts inherit the lock (FW_BENCH_LOCK_HELD). lib/fwtest.py implements the same protocol.
fw_pid() { cat "/proc/$$/winpid" 2>/dev/null || echo "$$"; }
fw_pid_alive() {
  if [ -e "/proc/$$/winpid" ]; then
    tasklist //FI "PID eq $1" //NH 2>/dev/null | grep -q "[[:space:]]$1[[:space:]]"
  else
    kill -0 "$1" 2>/dev/null
  fi
}
bench_lock() {
  local id="$1" tool="$2" dir host owner_host owner_pid
  [ "${FW_BENCH_LOCK_HELD:-}" = "$id" ] && return 0
  dir="$BENCH_DIR/$id.lock"; host="$(hostname)"
  mkdir -p "$BENCH_DIR" || die "cannot create $BENCH_DIR"
  if ! mkdir "$dir" 2>/dev/null; then
    owner_host="$(sed -n 's/^host=//p' "$dir/owner" 2>/dev/null)"
    owner_pid="$(sed -n 's/^pid=//p' "$dir/owner" 2>/dev/null)"
    if [ "${owner_host,,}" = "${host,,}" ] && [ -n "$owner_pid" ] && fw_pid_alive "$owner_pid"; then
      die "board '$id' is in use: $(tr '\n' ' ' <"$dir/owner")
       Wait until that run ends and re-run. If no such run exists any more, delete $dir"
    fi
    echo "NOTE: replacing a stale lock of board '$id' ($(tr '\n' ' ' <"$dir/owner" 2>/dev/null))"
    rm -rf "$dir"; mkdir "$dir" 2>/dev/null || die "cannot lock board '$id' ($dir)"
  fi
  printf 'host=%s\npid=%s\ntool=%s\nsince=%s\n' "$host" "$(fw_pid)" "$tool" "$(date '+%Y-%m-%d %H:%M:%S')" >"$dir/owner"
  BENCH_LOCK_DIR="$dir"; export FW_BENCH_LOCK_HELD="$id"
  trap bench_unlock EXIT
}
bench_unlock() {
  [ -n "${BENCH_LOCK_DIR:-}" ] && [ "$(sed -n 's/^pid=//p' "$BENCH_LOCK_DIR/owner" 2>/dev/null)" = "$(fw_pid)" ] \
    && rm -rf "$BENCH_LOCK_DIR"
  BENCH_LOCK_DIR=""
  return 0
}

# ---- Stage 2d: open the app in its IDE (docs/workflow.md "IDE handoff") -------------------------
# Every skill's open_ide.sh makes <app>/<app>.code-workspace usable by VS Code + the toolchain's
# extension and hands it over, so a developer can edit, build, flash and debug with the IDE's own
# buttons on the same project and build outputs as the scripts. env.sh sets IDE_EXT (extension
# id) and IDE_NAME.

# fw_code_workspace <app-dir> <path=label>...: write <app>/<app>.code-workspace unless it exists:
# relative folders only (no user paths - it can be committed) and IDE_EXT as the recommended
# extension (VS Code offers to install it).
fw_code_workspace() {
  local dir="$1" ws f sep=""; shift
  ws="$dir/$(basename "$dir").code-workspace"
  [ -f "$ws" ] && return 0
  {
    printf '{\n  "folders": [\n'
    for f in "$@"; do
      printf '%s    { "name": "%s", "path": "%s" }' "$sep" "${f#*=}" "${f%%=*}"; sep=$',\n'
    done
    printf '\n  ],\n  "settings": {},\n  "extensions": {\n    "recommendations": [ "%s" ]\n  }\n}\n' "$IDE_EXT"
  } >"$ws"
}

# ---- Tool installs: GLOBAL (per machine, all users) or LOCAL (per user) --------------------------
# Vendor installers offer both (Program Files, C:\ST, C:\Infineon vs %LOCALAPPDATA%, the user
# profile), and one PC can mix them. Scripts search both scopes; check_tools.sh labels every tool
# with the scope it was found in.
FW_LOCALAPPDATA="$(cygpath -u "${LOCALAPPDATA:-$HOME/AppData/Local}" 2>/dev/null || echo "$HOME/AppData/Local")"

# fw_scope <path>: LOCAL when the path is inside the user profile, else GLOBAL
fw_scope() {
  local p u
  p="$(cygpath -m "$1" 2>/dev/null || echo "$1")"; u="$(cygpath -m "${USERPROFILE:-$HOME}" 2>/dev/null || echo "$HOME")"
  case "$(echo "$p/" | tr 'A-Z' 'a-z')" in "$(echo "$u/" | tr 'A-Z' 'a-z')"*) echo LOCAL;; *) echo GLOBAL;; esac
}
# fw_where <path>: "LOCAL <user profile>/..." / "GLOBAL <Program Files>/..." for check_tools rows
fw_where() { echo "$(fw_scope "$1") $(winpath "$1")"; }

# fw_find_dirs <glob>...: existing directories matching the globs (list GLOBAL and LOCAL candidates;
# globs may contain spaces), one per line, sorted by the version in the last path element - so
# "| tail -1" is the newest install whichever scope it is in
fw_find_dirs() {
  local g d
  for g in "$@"; do
    while IFS= read -r d; do [ -d "$d" ] && echo "${d%/}"; done < <(compgen -G "$g")
  done | awk -F/ '{print $NF "\t" $0}' | sort -V | cut -f2- | uniq
}

# fw_code_cli: VS Code's command-line launcher - PATH first, then the per-user (LOCAL) and
# per-machine (GLOBAL) installs
fw_code_cli() {
  local c
  for c in "$(command -v code 2>/dev/null)" "$FW_LOCALAPPDATA/Programs/Microsoft VS Code/bin/code" \
           "/c/Program Files/Microsoft VS Code/bin/code"; do
    [ -n "$c" ] && [ -f "$c" ] && { echo "$c"; return 0; }
  done
  return 1
}
# fw_ide_ext_version <code-cli>: version of IDE_EXT installed in VS Code (exit 1 if missing). The
# whole list is read first (grep -q would cut the pipe); ids are compared in lowercase (Git Bash
# grep 3.0 aborts on -i together with -F).
fw_ide_ext_version() {
  local list want
  list="$("$1" --list-extensions --show-versions 2>/dev/null | tr -d '\r' | tr 'A-Z' 'a-z')"
  want="$(echo "$IDE_EXT" | tr 'A-Z' 'a-z')"
  printf '%s\n' "$list" | grep -F "$want@" | grep "^$want@" | head -1 | sed 's/.*@//' | grep .
}
# fw_check_ide: check_tools.sh rows for stage 2d (VS Code + IDE_EXT). WARN only: the script path
# works without the IDE. Needs the caller's ok/wrn row functions.
fw_check_ide() {
  local code v
  if ! code="$(fw_code_cli)"; then
    wrn "IDE: VS Code" "not found (user or system install) - needed only for the IDE path (open_ide.sh)"
    return 0
  fi
  v="$("$code" --version 2>/dev/null | head -1 | tr -d '\r')"
  ok "IDE: VS Code" "${v:-?}  ($(fw_where "$(dirname "$(dirname "$code")")"))"
  if v="$(fw_ide_ext_version "$code")"; then ok "IDE: extension" "$IDE_NAME $v"
  else wrn "IDE: extension" "$IDE_NAME missing - code --install-extension $IDE_EXT (IDE path only)"; fi
}

# fw_open_ide <workspace-file> [0]: gate "IDE: READY <file>", then check VS Code and IDE_EXT
# (missing -> exit 10 ACTION: SETUP; installing is the developer's) and open the workspace in
# VS Code - never the app folder. A second argument 0 = check only, do not open a window.
fw_open_ide() {
  local ws="$1" open="${2:-1}" code
  [ -f "$ws" ] || die "no $ws - re-run open_ide.sh (or new_app.sh)"
  echo "IDE: READY $(winpath "$ws")  (VS Code + $IDE_NAME)"
  code="$(fw_code_cli)" || need_user SETUP "install Visual Studio Code (user or system installer) and its extension $IDE_NAME ($IDE_EXT) - or open $(winpath "$ws") yourself with File > Open Workspace from File"
  fw_ide_ext_version "$code" >/dev/null \
    || need_user SETUP "install the VS Code extension $IDE_NAME: code --install-extension $IDE_EXT (or Extensions view), then re-run open_ide.sh"
  [ "$open" = 1 ] || { echo "IDE: not opened (--no-open)"; return 0; }
  # not in the background: the code CLI returns once VS Code has the window, and a backgrounded CLI
  # is killed with the caller's process tree before it launches VS Code (seen 2026-10-08)
  "$code" "$(winpath "$ws")" </dev/null >/dev/null 2>&1 \
    || need_user SETUP "VS Code did not start - open $(winpath "$ws") yourself with File > Open Workspace from File"
  echo "IDE: OPENED in VS Code"
}

# fw_new_app_ide <app-dir> <0|1>: stage 2d at the end of new_app.sh (1 = open a window). The app
# exists either way, so a missing IDE/extension is reported as a note and new_app.sh still exits 0.
fw_new_app_ide() {
  local out rc flag=""
  [ "$2" = 1 ] || flag=--no-open
  out="$(bash "$SKILL_DIR/scripts/open_ide.sh" "$1" $flag 2>&1)"; rc=$?
  printf '%s\n' "$out" | sed 's/^ACTION: SETUP /IDE: NOT OPENED - developer action: /'
  [ $rc = 0 ] || [ $rc = 10 ] || echo "WARN: open_ide.sh failed (exit $rc) - the app itself was created"
  return 0
}

# Build warning gate across runs: an incremental build only recompiles changed files, so a
# re-run after "BUILD: WARNINGS" would see 0 warnings and pass (found by a clean-room run,
# 2026-10-16). fw_warn_gate_start (after LOG=) forces a clean rebuild while warnings are pending;
# fw_warn_gate_end <app-dir> <warnings> <rc> (after counting) records them, and clears the mark
# only after a successful build with none.
fw_warn_gate_start() {
  local pending="$1/logs/.warnings-pending"
  if [ -f "$pending" ] && [ "${CLEAN:-0}" = 0 ]; then
    info "the previous build had warnings ($(head -1 "$pending")) - clean rebuild so they are counted again"
    CLEAN=1
  fi
}
fw_warn_gate_end() {
  local pending="$1/logs/.warnings-pending"
  if [ "${2:-0}" -gt 0 ]; then
    echo "$2 warning(s), $(date '+%Y-%m-%d %H:%M')" >"$pending"
  elif [ "${3:-1}" -eq 0 ]; then
    rm -f "$pending"
  fi
}

# fw_stlink_boards <STM32_Programmer_CLI>: "<probe serial> <board name>" per connected ST-LINK
# (the on-board ST-LINK reports its board, e.g. NUCLEO-C562RE; an external probe reports none -> "-")
fw_stlink_boards() {
  "$1" -l st-link 2>&1 | tr -d '\r' | awk '/ST-LINK SN/{if(sn)print sn, (b?b:"-"); sn=$NF; b=""} /Board Name/{b=$NF} END{if(sn)print sn, (b?b:"-")}'
}

# fw_stlink_debug status <board-id> | run <app-dir> <scenario.json> [--port N]
# Stage 7 (debug) for the STM32 skills, engine lib/fwdebug.py. The skill's debug.sh sources env.sh,
# sets DEBUG_APP_ENV (the app's record file, e.g. l4-app.env) and defines debug_app_elf (prints the
# ELF of $APPDIR after that file is sourced), then calls this. Needs from env.sh / the profile:
# PROGRAMMER, GCC_BIN, STM32CUBE_ROOT, GDBSERVER_VERSION, probe_serials, load_board; optional
# DEBUG_APID in board.env (the core's access port: 1 on the STM32C5, default 0).
fw_stlink_debug() {
  local mode="$1" py="$REPO_ROOT/lib/fwdebug.py"; shift || true
  case "$mode" in
  status)
    [ $# -ge 1 ] || die "usage: debug.sh status <board-id>"
    load_board "$1"
    require_vars PROBE_SERIAL EXPECTED_DEVICE_ID
    probe_serials | grep -qix "$PROBE_SERIAL" \
      || need_user CONNECT "ST-LINK $PROBE_SERIAL not connected - plug the board in (or run discover.sh after changing board/USB port)"
    bench_lock "$BOARD_ID" debug.sh
    mkdir -p "$BENCH_DIR"; local log="$BENCH_DIR/$BOARD_ID.debug-status.log" out dev fw
    out="$("$PROGRAMMER" -c port=SWD sn="$PROBE_SERIAL" mode=HOTPLUG \
            -r32 0xE000ED00 4 -r32 0xE000EDF0 4 -r32 0xE000ED28 20 2>&1 | tr -d '\r')"
    echo "$out" >"$log"
    dev="$(echo "$out" | sed -n 's/^Device ID *: *//p' | head -1)"
    [ "$(echo "$dev" | tr a-f A-F)" = "$(echo "$EXPECTED_DEVICE_ID" | tr a-f A-F | sed 's/^0X/0x/')" ] \
      || die "device id '$dev' is not $EXPECTED_DEVICE_ID - not this board (log $log)"
    _dbg_word() { echo "$out" | sed -n "s/^$1 : *//p" | head -1; }
    fw="$(_dbg_word 0xE000ED28) $(_dbg_word 0xE000ED38)"    # CFSR HFSR DFSR MMFAR | BFAR (4 words per line)
    set -- $fw
    [ -n "$(_dbg_word 0xE000ED00)" ] && [ -n "$(_dbg_word 0xE000EDF0)" ] && [ $# -ge 5 ] \
      || die "registers not readable (log $log)"
    echo "board=$BOARD_ID device=$dev probe=ST-LINK (hot plug: no reset, no halt)"
    "$PYTHON" "$(winpath "$py")" decode --cpuid "$(_dbg_word 0xE000ED00)" --dhcsr "$(_dbg_word 0xE000EDF0)" \
      --cfsr "$1" --hfsr "$2" --mmfar "$4" --bfar "$5"
    ;;
  run)
    local scen="" port=61234 elf gdb server log
    APPDIR=""
    while [ $# -gt 0 ]; do
      case "$1" in --port) port="$2"; shift;; --*) die "unknown option $1";; *) if [ -z "$APPDIR" ]; then APPDIR="$1"; else scen="$1"; fi;; esac; shift
    done
    [ -n "$APPDIR" ] && [ -f "$APPDIR/$DEBUG_APP_ENV" ] && [ -f "$scen" ] \
      || die "usage: debug.sh run <app-dir> <scenario.json> [--port N]"
    APPDIR="$(cd "$APPDIR" && pwd)"
    # shellcheck disable=SC1090
    . "$APPDIR/$DEBUG_APP_ENV"
    load_board "$APP_BOARD"
    require_vars PROBE_SERIAL GDBSERVER_VERSION
    elf="$(debug_app_elf)"
    [ -f "$elf" ] || die "no ELF $elf - run build.sh"
    gdb="$GCC_BIN/arm-none-eabi-gdb.exe"
    server="$STM32CUBE_ROOT/bundles/stlink-gdbserver/$GDBSERVER_VERSION/bin/ST-LINK_gdbserver.exe"
    [ -x "$gdb" ] && [ -x "$server" ] \
      || need_user SETUP "GDB or ST-LINK_gdbserver $GDBSERVER_VERSION missing in the STM32Cube bundles - install them with the STM32CubeIDE for VS Code extension"
    probe_serials | grep -qix "$PROBE_SERIAL" \
      || need_user CONNECT "ST-LINK $PROBE_SERIAL not connected - plug the board in (or run discover.sh)"
    bench_lock "$BOARD_ID" debug.sh
    mkdir -p "$APPDIR/logs"; log="$APPDIR/logs/debug-$(ts).log"
    info "attach (no reset) to board $BOARD_ID with $(basename "$elf"); the core is halted while GDB is attached"
    # -g = attach to the running target, -d = SWD, -m = the core's access port; no -k (reset), no --halt
    "$PYTHON" "$(winpath "$py")" run --gdb "$(winpath "$gdb")" --elf "$(winpath "$elf")" \
      --server "\"$(cygpath -w "$server")\" -p $port -d -g -m ${DEBUG_APID:-0} -i $PROBE_SERIAL -cp \"$(cygpath -w "$(dirname "$PROGRAMMER")")\"" \
      --port "$port" --scenario "$(winpath "$scen")" --log "$(winpath "$log")" \
      ${CONSOLE_PORT:+--console "$CONSOLE_PORT"} </dev/null
    ;;
  *)
    die "usage: debug.sh status <board-id> | debug.sh run <app-dir> <scenario.json> [--port N]"
    ;;
  esac
}

# fw_vscode_cube_setup <mx-dir>: pre-write the STM32CubeIDE for VS Code project setup of a
# generated CMake project, from the board profile, so the extension opens it as an already
# configured STM32Cube project (no "configure discovered projects?" prompt) with the pinned bundle
# versions: .vscode/settings.json (cube-cmake), .vscode/launch.json (the extension's own default
# "Launch ST-Link GDB Server": build, flash, run to main), .settings/ide.store.json (source,
# board, device, core, toolchain), .settings/bundles.store.json. Existing files are kept (the
# extension owns them once written). Profile: MCU_CPN, CMAKE/NINJA/GCC/PROGRAMMER_VERSION,
# CLANGD_VERSION, GDBSERVER_VERSION; optional VSCODE_BOARD, VSCODE_CORE, VSCODE_SOURCE
# (default STM32CubeMX; empty = not recorded).
fw_vscode_cube_setup() {
  local mx="$1" extra="" src="${VSCODE_SOURCE-STM32CubeMX}"
  mkdir -p "$mx/.vscode" "$mx/.settings"
  [ -f "$mx/.vscode/settings.json" ] || cat >"$mx/.vscode/settings.json" <<'EOF'
{
    "cmake.cmakePath": "cube-cmake",
    "cmake.configureArgs": [
        "-DCMAKE_COMMAND=cube-cmake"
    ],
    "cmake.preferredGenerators": [
        "Ninja"
    ]
}
EOF
  [ -f "$mx/.vscode/launch.json" ] || cat >"$mx/.vscode/launch.json" <<'EOF'
{
    "version": "0.2.0",
    "configurations": [
        {
            "type": "stlinkgdbtarget",
            "request": "launch",
            "name": "STM32Cube: Launch ST-Link GDB Server",
            "origin": "snippet",
            "cwd": "${workspaceFolder}",
            "preBuild": "${command:st-stm32-ide-debug-launch.build}",
            "runEntry": "main",
            "imagesAndSymbols": [
                {
                    "imageFileName": "${command:st-stm32-ide-debug-launch.get-projects-binary-from-context1}"
                }
            ]
        }
    ]
}
EOF
  [ -n "$src" ] && extra="
  \"source\": {
    \"sourceType\": \"$src\"
  },"
  [ -n "$VSCODE_BOARD" ] && extra="$extra
  \"board\": \"$VSCODE_BOARD\","
  [ -f "$mx/.settings/ide.store.json" ] || cat >"$mx/.settings/ide.store.json" <<EOF
{$extra
  "device": "$MCU_CPN",${VSCODE_CORE:+
  \"core\": \"$VSCODE_CORE\",}
  "toolchain": "GCC"
}
EOF
  [ -f "$mx/.settings/bundles.store.json" ] || cat >"$mx/.settings/bundles.store.json" <<EOF
{
  "bundles": [
    { "name": "cmake", "version": "$CMAKE_VERSION" },
    { "name": "ninja", "version": "$NINJA_VERSION" },
    { "name": "gnu-tools-for-stm32", "version": "$GCC_VERSION" },
    { "name": "st-arm-clangd", "version": "$CLANGD_VERSION" },
    { "name": "programmer", "version": "$PROGRAMMER_VERSION" },
    { "name": "stlink-gdbserver", "version": "$GDBSERVER_VERSION" }
  ]
}
EOF
  return 0
}

# fw_cube_open_ide <app-dir> [0]: stage 2d for the STM32Cube skills. The workspace opens mx/ as
# its own folder (STM32CubeIDE for VS Code sets up only a CMake project at a workspace folder's
# root - "contains multiple CMake projects" otherwise), plus src/ and tests/.
fw_cube_open_ide() {
  local d="$1"
  [ -f "$d/mx/.settings/ide.store.json" ] && [ -f "$d/mx/.vscode/launch.json" ] \
    || die "$d/mx has no STM32CubeIDE for VS Code setup - run regen.sh $d first"
  fw_code_workspace "$d" "mx=$(basename "$d") (STM32Cube project: mx)" "src=$(basename "$d") (app sources: src)" "tests=$(basename "$d") (tests)"
  if [ -f "$d/.vscode/settings.json" ] && grep -q 'cmake.sourceDirectory' "$d/.vscode/settings.json"; then
    echo "WARN: $d/.vscode/settings.json (cmake.sourceDirectory) was written when the app FOLDER was opened -"
    echo "      CMake Tools then configures mx/ without the STM32Cube toolchain. Ask the user before deleting it."
  fi
  fw_open_ide "$d/$(basename "$d").code-workspace" "${2:-1}"
}

# fw_gitignore <workspace> <skill> <line>...: append the missing lines to <workspace>/.gitignore
# (the workspace may be shared with other skills; the user's own lines stay)
fw_gitignore() {
  local f="$1/.gitignore" tag="$2" l; shift 2
  for l in "$@"; do
    [ -f "$f" ] && grep -qxF -- "$l" "$f" && continue
    grep -qF "$tag skill" "$f" 2>/dev/null || \
      echo "# added by the $tag skill: per-PC and regenerable files (keep app sources + tests)" >>"$f"
    echo "$l" >>"$f"
  done
}
