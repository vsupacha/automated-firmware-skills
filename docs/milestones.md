# Milestones

The plan behind the skills, and where each one stands. The stage-by-stage contract (scripts, gates,
exit codes, ACTIONs) is in [workflow.md](workflow.md).

## Current status (2026-10-09)

**Release scope:** [milestones.env](../milestones.env) activates **M1** only - including its board
stages: the agent finds, flashes and tests a board when you ask, and **asks before every flash**.
Scripts of a later milestone stop with `ACTION: SETUP ... not active` until the developer enables
it there (or for one shell: `export FW_ACTIVE_MILESTONES="M1 M2"`).

| Milestone | State |
| --- | --- |
| **M1 bring-up** | active - 10 skills; build stages work in all of them, board stages (connect, flash, test) verified on 8 boards; `debug.sh` planned |
| **M2 board support** | layer check (`check_layers.py`) and host test (`host_test.sh`) implemented, gated; board-driver stage planned |
| **M3 execution model** | planned (design: [trace](#milestones-bottom-up-one-firmware-layer-at-a-time) below) |
| **M4 components** | planned |
| **M5 application + profiling** | planned |

M1 per skill - the bring-up demos are `hello-world` (UART), `blink` (LED) and `push-to-light`
(button -> LED); per-board results: [boards/README.md](../boards/README.md).

| Skill | Build stages (setup, create, IDE, build) | Board stages (connect, flash, test) |
| --- | --- | --- |
| modus-pdl-edgitalk | yes | verified on hardware |
| cubemx2-hal2-stm32c562nucleo | yes | verified on hardware |
| pio-arduino-rpipico2w | yes | verified on hardware |
| pio-espidf-esp32s3box | yes | verified on hardware |
| pio-arduino-esp32s3box | yes | verified on hardware |
| cubemx-hal-stm32l475iot | yes | verified on hardware |
| pio-arduino-unor4wifi | yes | verified on hardware |
| scons-rtthread-visionboard | yes | hello-world tested on hardware |
| cubemx-hal-stm32n6570dk | yes | planned (dev boot mode, connect under reset) |
| cubemx-hal-stm32f407disco | yes | planned (SWO console) |

Next: `debug.sh` (M1 stage 7), board stages for N6 / F4, then M2 board drivers and the M3 trace.

## Milestones: bottom-up, one firmware layer at a time

The milestones follow how an embedded developer brings up firmware - bottom-up, each layer proven
**on the real board** before the next one is generated on top of it. The outcome of each milestone
is a **collection of skills + scripts** that can do that milestone's jobs on its own; each layer's
output (pin map, `board.h` API, component APIs) is the catalog the next layer's generation may use,
so an agent never calls APIs that were not built and tested first.

| Milestone | Builds | Outcome (skills + scripts) | Proven by (on the board) |
| --- | --- | --- | --- |
| **M1 bring-up** | toolchain, project, IDE, build, probe connection, flash, smoke test, debug attach | one skill per toolchain + framework + board (`<toolchain>-<framework>-<board>`) | smoke test PASS; debugger halts at `main` |
| **M2 board support** | BSP drivers behind the `board.h` API, from vendor board configs > netlist > schematic > the developer | board-driver skills + the layer checks | per-peripheral tests (loopback, `WHO_AM_I`, LED seen) + `LAYERS: PASS` |
| **M3 execution model** | bare-metal superloop, RTOS (FreeRTOS), RTOS + stack (Zephyr, RT-Thread) | execution skills + the trace tool | the same logic tests pass under each model; trace rules (order, latency, period, stack) PASS |
| **M4 components** | middleware on M2 + M3: LVGL, USB device classes, file system, network stack ... | one skill per component (adapter to `board.h` + the execution model) | component demo test |
| **M5 application + profiling** | application logic in `func/`, tested on the board with stub/driver inputs; time and memory per function (e.g. a digital filter) | profiling scripts | tests + budgets PASS (cycles, stack, RAM/flash) |

Order: M3 (execution model) comes before M4 (components) because middleware depends on it - LVGL
needs a tick and a lock, a network stack runs with or without an OS, USB needs ISR/task decisions.
For Zephyr / RT-Thread the M2 work is mostly devicetree / Kconfig instead of hand-written drivers,
so the execution model is recorded when the app is created even though it is proven in M3.

**Testing runs through every milestone, on the target.** Each milestone ends with a test on the real
board (`serial_test.py` + `tests/*.json`). Logic is validated on the board with stub or driver
inputs injected through the console, not by running the code on the PC; `host_test.sh` stays an
optional quick check. Timing is only *measured* on hardware (DWT cycle counter, `CCOUNT`, a timer);
memory can be read without it (map file, `-fstack-usage`) - report *estimated* vs *measured*.

**M3 trace (planned design).** Execution flow is checked from a binary event trace, not `printf`
(a UART line costs milliseconds and changes the scheduling it measures): `trace(id, arg)` writes
`{cycles, id, arg}` into a RAM ring buffer (`.noinit`, survives a reset) from ISRs, tasks and the
RTOS trace hooks; after the run the buffer is read over the console (`trace dump`) or by the
debugger (works after a fault), decoded with the event-id table shared by C and Python, and checked
against rules next to the tests - `follows A->B within_us`, `period`, `never`, `stack_free_min_pct`.
Each board supplies `board_cycles()`; the tracer reports its own overhead.
