#!/usr/bin/env bash
# Stage 1b (tool updates): compare the RT-Thread Studio packages pinned in the board profile with
# what this PC's SDK Manager has installed - the board support package, the GNU Arm toolchain and
# the pyOCD debugger package (SDK Manager keeps versions side by side). RT-Thread Studio itself and
# its env/scons are not pinned. Read-only unless --apply --yes. See docs/workflow.md "Tool updates".
# Usage: update_tools.sh <board-id> [--apply --yes]
# Gate: "UPDATE: NONE" (exit 0) | "UPDATE: AVAILABLE n" + ACTION: APPROVE (exit 10: ask the
#       developer; staying on the pins is fine while they are installed) | "UPDATE: APPLIED n"
#       (profile re-pinned + dated log line; the board must be re-qualified, nothing is rebuilt).

. "$(dirname "$0")/env.sh"
APPLY=0; YES=0; BOARD=""
for a in "$@"; do case "$a" in --apply) APPLY=1;; --yes) YES=1;; --*) die "unknown option $a";; *) BOARD="$a";; esac; done
[ -n "$BOARD" ] || die "usage: update_tools.sh <board-id> [--apply --yes]  (boards: $(known_boards))"
[ "$APPLY" = 1 ] && [ "$YES" != 1 ] && die "--apply needs --yes (only after the developer agreed)"
load_board "$BOARD"
[ -d "$RTT_EXTRACT" ] || die "RT-Thread Studio SDK folder not found ($RTT_EXTRACT) - run check_tools.sh"

# rtt_versions <folder under repo/Extract>: package versions installed side by side
rtt_versions() {
  local d
  for d in "$RTT_EXTRACT/$1"/*/; do [ -d "$d" ] && basename "$d"; done
}

echo "Pinned tools of board $BOARD ($(winpath "$BOARD_DIR/board.env")) vs this PC  ($(date '+%Y-%m-%d %H:%M'))"
echo "----------------------------------------------------------------"
fw_pin_check BSP_VERSION "SDK $BSP_NAME" "$BSP_VERSION" $(rtt_versions "Board_Support_Packages/$BSP_VENDOR/$BSP_NAME")
fw_pin_check GCC_VERSION "GNU Arm toolchain" "$GCC_VERSION" $(rtt_versions ToolChain_Support_Packages/ARM/GNU_Tools_for_ARM_Embedded_Processors)
fw_pin_check PYOCD_VERSION "pyOCD package" "$PYOCD_VERSION" $(rtt_versions Debugger_Support_Packages/RealThread/PyOCD)
echo "----------------------------------------------------------------"
fw_pin_gate "$BOARD" "$APPLY"
