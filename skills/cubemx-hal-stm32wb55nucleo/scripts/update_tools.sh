#!/usr/bin/env bash
# Stage 1b (tool updates): compare the tool versions pinned in the board profile with what is
# installed on this PC - STM32CubeMX, the STM32Cube firmware package, the STM32Cube bundles (GCC,
# CMake, Ninja, STM32CubeProgrammer, clangd, ST-LINK gdbserver) and the STM32CubeIDE for VS Code
# extension (VS Code updates it silently). Read-only unless --apply --yes. See docs/workflow.md
# "Tool updates".
# Usage: update_tools.sh <board-id> [--apply --yes]
# Gate: "UPDATE: NONE" (exit 0) | "UPDATE: AVAILABLE n" + ACTION: APPROVE (exit 10: ask the
#       developer; staying on the pins is fine while they are installed) | "UPDATE: APPLIED n"
#       (profile re-pinned + dated log line; the board must be re-qualified, nothing is rebuilt).

. "$(dirname "$0")/env.sh"
APPLY=0; YES=0; BOARD=""
for a in "$@"; do case "$a" in --apply) APPLY=1;; --yes) YES=1;; --*) die "unknown option $a";; *) BOARD="$a";; esac; done
[ -n "$BOARD" ] || die "usage: update_tools.sh <board-id> [--apply --yes]"
[ "$APPLY" = 1 ] && [ "$YES" != 1 ] && die "--apply needs --yes (only after the developer agreed)"
load_board "$BOARD"

echo "Pinned tools of board $BOARD ($(winpath "$BOARD_DIR/board.env")) vs this PC  ($(date '+%Y-%m-%d %H:%M'))"
echo "----------------------------------------------------------------"
fw_pin_check CUBEMX_VERSION "STM32CubeMX" "$CUBEMX_VERSION" $(cubemx_installed_version)
fw_pin_check FW_VERSION "firmware $FW_PACKAGE" "$FW_VERSION" $(fw_packages)
fw_pin_check GCC_VERSION "GNU Tools for STM32" "$GCC_VERSION" $(fw_bundle_versions gnu-tools-for-stm32)
fw_pin_check CMAKE_VERSION "CMake" "$CMAKE_VERSION" $(fw_bundle_versions cmake)
fw_pin_check NINJA_VERSION "Ninja" "$NINJA_VERSION" $(fw_bundle_versions ninja)
fw_pin_check PROGRAMMER_VERSION "STM32CubeProgrammer" "$PROGRAMMER_VERSION" $(fw_bundle_versions programmer)
fw_pin_check CLANGD_VERSION "st-arm-clangd (IDE indexing)" "$CLANGD_VERSION" $(fw_bundle_versions st-arm-clangd)
fw_pin_check GDBSERVER_VERSION "ST-LINK gdbserver (debug)" "$GDBSERVER_VERSION" $(fw_bundle_versions stlink-gdbserver)
if code="$(fw_code_cli)"; then
  fw_pin_check IDE_EXT_VERSION "$IDE_NAME" "$IDE_EXT_VERSION" $(fw_ide_ext_version "$code")
else
  echo "skip     $IDE_NAME (no VS Code - IDE path only)"
fi
echo "----------------------------------------------------------------"
fw_pin_gate "$BOARD" "$APPLY"
