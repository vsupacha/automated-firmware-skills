#!/usr/bin/env bash
# Stage 7 (debug): read the MCU's internal state, or run a scripted breakpoint / watch / step
# scenario, through the board's ST-LINK. Shared code: fw_stlink_debug in lib/common.sh, engine
# lib/fwdebug.py (scenario keys in its header).
# Usage:
#   debug.sh status <board-id>
#       Read-only: STM32CubeProgrammer hot-plug connect (no reset, no halt) reads CPUID, DHCSR and
#       the fault registers (CFSR, HFSR, MMFAR, BFAR). Note: the connect enables "debug in low
#       power mode" in the MCU's debug unit - a debug-only setting, not program memory.
#       Gate: "DEBUG: STATUS <running|halted|sleeping|lockup> fault=<none|...>", exit 0 / 1 = fault.
#   debug.sh run <app-dir> <scenario.json> [--port N]
#       ST-LINK_gdbserver in ATTACH mode (no reset, no programming) + arm-none-eabi-gdb (MI):
#       checks that the board runs this app's ELF (loadable segments read back) - otherwise stops
#       ("flash the app first", which needs the user's yes) - then runs the scenario (break / watch /
#       step / print / read, console lines sent while running). The core is HALTED while GDB is
#       attached - tell the user first; the engine always detaches so the firmware runs on.
#       Gate: "DEBUG: PASS (n/m steps)" exit 0, "DEBUG: FAIL ..." exit 1.

. "$(dirname "$0")/env.sh"
require_milestone M1 "debug.sh (stage 7 debug)"
DEBUG_APP_ENV=l4-app.env
debug_app_elf() { echo "$APPDIR/mx/build/Debug/mx.elf"; }
fw_stlink_debug "$@"
