# Milestones

The plan behind the skills, and where each one stands. The stage-by-stage contract (scripts, gates,
exit codes, ACTIONs) is in [workflow.md](workflow.md).

## What these milestones deliver

An AI assistant can change one project and show that it works once. This repo aims for more: each
milestone ships **open, re-runnable proof** that a firmware layer works - across boards and
toolchains - which a team, a teacher or an auditor can check without trusting the agent.

1. **Evidence is a repo artifact, not a chat answer.** Every milestone ends in gate lines, a
   manifest (tool versions, image hashes), a test spec and a dated verification-log line. Anyone
   re-runs them with the plain bash/Python scripts - offline, without an agent or an account.
2. **Same tests on every board.** A demo or component counts as done only when the *same*
   `tests/*.json` passes on more than one board; portability is proven, not claimed.
3. **Pinned and diffable.** Exact toolchain, SDK and pack versions live in the board profiles; an
   upgrade is a diff of two manifests plus a re-run of the same tests.
4. **Safety as code.** Identity gates, protected option bytes / loaders / security settings and
   ask-before-every-flash are enforced by the scripts, not by the agent's good behaviour.
5. **Docs proven by a clean room.** A skill or workflow ships only after a fresh agent with no
   context completed it from the docs alone ([cleanroom-test](../skills/cleanroom-test/SKILL.md)),
   with the report and its triage kept in the repo.

## Current status (2026-10-15)

**Release scope:** [milestones.env](../milestones.env) activates **M1** only - including its board
stages: the agent finds, flashes and tests a board when you ask, and **asks before every flash**.
Scripts of a later milestone stop with `ACTION: SETUP ... not active` until the developer enables
it there (or for one shell: `export FW_ACTIVE_MILESTONES="M1 M2"`).

| Milestone | State |
| --- | --- |
| **M1 bring-up** | active - 10 board skills; build stages work in all of them, board stages (connect, flash, test) verified on 8 boards; `debug.sh` and the bring-up certificate planned |
| **M2 board support** | layer check (`check_layers.py`) and host test (`host_test.sh`) implemented, gated; `parts.json` + board-driver stage planned |
| **M3 execution model** | planned (design: [trace](#m3-trace-planned-design) below) |
| **M4 components** | planned |
| **M5 application + profiling** | planned |

Tool skills that serve every milestone: [cleanroom-test](../skills/cleanroom-test/SKILL.md) (docs
proven by a fresh agent), [sensor-debug](../skills/sensor-debug/SKILL.md) (PC-side checks and live
view of what a board prints), [hw-troubleshooting](../skills/hw-troubleshooting/SKILL.md) (firmware
vs setup vs hardware), [web-wizard](../skills/web-wizard/SKILL.md) (choices on one page).

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

Next:
1. **Finish M1:** `debug.sh` (stage 7, halt at `main`), board stages for N6 / F4, and the **bring-up
   certificate** per board in `boards/README.md`, generated from `index.json`, the build manifests
   and the clean-room reports.
2. **Start M2:** `boards/<id>/parts.json` (parts and pins with source + verification level) and the
   board-driver stage, first on a board with sensors (B-L475E-IOT01A).
3. Engine items from the clean-room runs: measured intervals in the test engine (a blink period is
   only checked through the INFO line today); SKILL.md stage headings numbered like the shared
   stages; a bounded-read command in sensor-debug ("read N s, report resets and errors").

## Milestones: bottom-up, one firmware layer at a time

The milestones follow how an embedded developer brings up firmware - bottom-up, each layer proven
**on the real board** before the next one is generated on top of it. The outcome of each milestone
is a **collection of skills + scripts** that can do that milestone's jobs on its own; each layer's
output (pin map, `board.h` API, component APIs) is the catalog the next layer's generation may use,
so an agent never calls APIs that were not built and tested first.

| Milestone | Builds | Outcome (skills + scripts) | Proven by (on the board) | Evidence anyone can re-run |
| --- | --- | --- | --- | --- |
| **M1 bring-up** | toolchain, project, IDE, build, probe connection, flash, smoke test, debug attach | one skill per toolchain + framework + board (`<toolchain>-<framework>-<board>`) | the three bring-up demos PASS; debugger halts at `main` | a **bring-up certificate** per board: demo levels up to *observed*, pinned-tools manifest, IDE path and script path both proven, a clean-room report |
| **M2 board support** | BSP drivers behind the `board.h` API, from vendor board configs > netlist > schematic > the developer | board-driver skills + the layer checks | per-peripheral tests (loopback, `WHO_AM_I`, LED seen) + `LAYERS: PASS` | `boards/<id>/parts.json`: every part and pin with its source (board config, netlist, schematic, measured) and verification level; `board.h` proven to be the only board-specific code |
| **M3 execution model** | bare-metal superloop, RTOS (FreeRTOS), RTOS + stack (Zephyr, RT-Thread) | execution skills + the trace tool | the same logic tests pass under each model; trace rules (order, latency, period, stack) PASS | trace rules kept as test specs; the **same app logic** passing under at least two execution models - the execution layer is swappable |
| **M4 components** | middleware on M2 + M3: LVGL, USB device classes, file system, network stack ... | one skill per component (adapter to `board.h` + the execution model) | component demo test | each component's demo test passing on **at least two boards**, versions pinned in the manifest |
| **M5 application + profiling** | application logic in `func/`, tested on the board with stub/driver inputs; time and memory per function (e.g. a digital filter) | profiling scripts | tests + budgets PASS (cycles, stack, RAM/flash) | budgets as gates (`PROFILE: PASS`), *measured* vs *estimated* labelled, tracked across commits; instruments (logic analyser, power meter) only feed these gates |
| **Export / port** (stages 14-15) | a standalone project; the same app on another board | `export_app.sh`, `port.sh --to <skill>:<board>` | the exported project builds and tests on its own; the target passes the **same** tests | an exported project carries its skills, scripts and tests - no dependency on this repo or on any service |

Order: M3 (execution model) comes before M4 (components) because middleware depends on it - LVGL
needs a tick and a lock, a network stack runs with or without an OS, USB needs ISR/task decisions.
For Zephyr / RT-Thread the M2 work is mostly devicetree / Kconfig instead of hand-written drivers,
so the execution model is recorded when the app is created even though it is proven in M3.

**Testing runs through every milestone, on the target.** Each milestone ends with a test on the real
board (`serial_test.py` + `tests/*.json`). Logic is validated on the board with stub or driver
inputs injected through the console, not by running the code on the PC; `host_test.sh` stays an
optional quick check. Timing is only *measured* on hardware (DWT cycle counter, `CCOUNT`, a timer);
memory can be read without it (map file, `-fstack-usage`) - report *estimated* vs *measured*.

### M3 trace (planned design)

Execution flow is checked from a binary event trace, not `printf` (a UART line costs milliseconds
and changes the scheduling it measures): `trace(id, arg)` writes `{cycles, id, arg}` into a RAM ring
buffer (`.noinit`, survives a reset) from ISRs, tasks and the RTOS trace hooks; after the run the
buffer is read over the console (`trace dump`) or by the debugger (works after a fault), decoded
with the event-id table shared by C and Python, and checked against rules next to the tests -
`follows A->B within_us`, `period`, `never`, `stack_free_min_pct`. Each board supplies
`board_cycles()`; the tracer reports its own overhead.
