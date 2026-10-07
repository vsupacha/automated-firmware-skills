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
