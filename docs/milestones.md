# Milestones

The plan behind the skills, and where each one stands. The stage-by-stage contract (scripts, gates,
exit codes, ACTIONs) is in [workflow.md](workflow.md).

## What these milestones deliver

An AI assistant can change one project and show that it works once. This repo aims for more: each
milestone ships **open, re-runnable proof** that a firmware layer works - across boards and
toolchains - which a team, a teacher or an auditor can check without trusting the agent.

**Division of work.** Firmware is built bottom-up, one layer at a time, each proven on the board
before the next goes on top. The **scripts own the gates** (tools, identity, build manifest, flash,
tests, layer rules) and never change between runs. The **AI customizes and integrates**: it picks a
proven template or component, adapts it to the board (pins from the board sheet, options from the
user), wires it into the layer above, and then lets the scripts prove the result. It never invents
an API from a layer that has not passed its gates, and it never replaces a gate with its own
judgement.

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
| **M1 bring-up** | active - 10 board skills; build stages work in all of them, board stages (connect, flash, test) verified on 8 boards; `debug.sh` (status + scripted break / watch / step) in the STM32 C5 and L475 skills; bring-up certificate planned |
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

Next: finish M1 (the M1 items of the roadmap below, then the bring-up certificate), then start M2
on a board with sensors (B-L475E-IOT01A). The roadmap lists every planned item per milestone.

## Roadmap per milestone

Each item names what the **AI** customizes or integrates and the **gate** (a script, a test spec or
a recorded fact) that proves it. Items run bottom-up: a milestone's items build only on layers whose
gates already passed. `(cr)` = found by a clean-room run.

### Every milestone - evidence rules

- **One observable outcome per step.** Each change states its finish line (the gate line or test
  that proves it) before the AI starts; a step ends with that evidence, not with "it should work".
- **Separate results, never merged:** `BUILD:` (it compiles) ≠ `FLASH:` (the image was written and,
  where the chip allows, read back) ≠ `BOOT:` (the board printed its boot marker within a bounded
  time) ≠ `RESULT:` (behaviour tested) ≠ observed by a person.
- **Gaps are visible:** skipped or unavailable checks are counted and printed (`SKIPPED n`), never
  folded into a PASS; machine-readable results (`--json`) next to the gate lines.
- **Status per recorded fact or command** in board profiles: `verified` (it ran, with a dated log
  line) / `user-confirmed` / `inferred` / `unavailable` - next to the demo levels.
- **Generated blocks between markers** in READMEs and profiles, so a script can refresh its section
  without touching hand-written notes.
- **Policy that can only tighten:** a committed per-board policy (e.g. never auto-flash this board)
  that `FLASH_POLICY` in a bench file cannot loosen; the bench lock also notices when another
  session reflashed the board.
- **Long runs are bounded:** soak tests, trace captures and profiling runs have an iteration or
  time limit and stop after repeated failures; unattended runs never flash.

### M1 bring-up - a board and its toolchain, proven

| Item | AI customizes / integrates | Gate |
| --- | --- | --- |
| Hardware assumptions check | lists boot pins, straps, clocks, console path and debug path from the board sheet and BSP before any code; unconfirmed facts go to the user | every assumption `verified` or answered, recorded in the board sheet |
| `BOOT:` gate after flash | - (script) | boot marker within N s after reset, separate from `FLASH:` |
| Test engine: `SKIPPED`, `--json`, measured intervals, values captured in one step and compared in a later one `(cr)` | - (engine) | the same specs report skips, emit JSON, and can check a period (e.g. blink 0.5 s ± tolerance) |
| `debug.sh` | - (script) | attach **without** reset or programming by default; halt at `main` on request; refuses to reset or reflash while a fault's state is being kept, unless the user agrees. Done for STM32 (C5, L475: `status` + scenarios); next: other probes (pyOCD, OpenOCD, esptool/JTAG), halt at `main`, scenario checks "no change" and values compared across steps, offline scenario check `(cr)` |
| Board stages for N6 / F4 | adapts discover/flash to the board's boot mode and console (dev boot mode, SWO) | `IDENTITY:` / `FLASH:` / `BOOT:` / `RESULT:` on the board |
| Bring-up certificate | - (generated) | per board: demo levels up to observed, pinned-tools manifest, IDE and script path, clean-room report |
| SKILL.md stage numbers = shared stages `(cr)` | - (docs) | validator: headings match the stage table |

### M2 board support - drivers behind `board.h`, proven per peripheral

| Item | AI customizes / integrates | Gate |
| --- | --- | --- |
| `boards/<id>/parts.json` | extracts parts, buses, addresses and pins from the vendor board configuration > netlist > schematic; asks for anything else | every entry has a source and a status; conflicts listed, never guessed |
| Driver contract per peripheral | fills a template: modes, calling context, bus ownership, error codes, a deadline on every wait, retries, state after a failure | the contract is reviewed before code |
| Driver | reuses the vendor HAL/BSP driver where it fits, else writes device logic over a bus interface; pins stay in `board/` | build 0 warnings + `LAYERS: PASS` |
| Per-peripheral test | writes the test spec: ID read, value plausibility (sensor-debug limits), failure path (absent device, timeout) | `RESULT: PASS` on the board; ACK alone is not proof - bus traffic or values compared with the datasheet |
| Regression | one test per fixed bug | the test fails before the fix and passes after |

### M3 execution model - the same logic under different models

| Item | AI customizes / integrates | Gate |
| --- | --- | --- |
| Execution layer templates | bare-metal superloop, FreeRTOS, RT-Thread / Zephyr variants of the same app | the M1/M2 tests pass under each model |
| Trace ring buffer + rules | inserts trace points at the integration points (ISR entry, task switch, queue) | trace rules (`follows A->B within_us`, `period`, `never`, stack margin) PASS |
| Execution-model checklist | checks priorities (direction), stack units, queue ownership, timer and ISR context, drift of relative delays | checklist answered per port; one end-to-end data path ported and passing first |

### M4 components - middleware integrated on proven layers

| Item | AI customizes / integrates | Gate |
| --- | --- | --- |
| Component adapter | adapts LVGL, USB device classes, a file system or a network stack to `board.h` + the execution model, with versions pinned | build + layer check |
| Component demo test | wires the component into a demo app with a console contract | the same demo test PASS on at least two boards |
| Intermediate description | for generated or converted designs: one source-of-truth file with a status per item (direct, approximate, custom, unknown); the user signs off every approximate item | no `unknown` left; approximations accepted by the user |

### M5 application + profiling - logic tested on the board, budgets as gates

| Item | AI customizes / integrates | Gate |
| --- | --- | --- |
| Application logic in `func/` | writes the logic against proven APIs only; stub/driver inputs through the console | tests PASS on the board |
| Profiling gates | adds measurement points (cycle counter, GPIO markers) | `PROFILE: PASS` against budgets; supply, flags, workload and method recorded; a gain smaller than the run-to-run variation counts as no gain |
| Instruments | logic analyser / power meter captures with stated channels, rate, trigger and tolerance | saved raw capture + bounded script; feeds the profiling gate |

### Export / port - the same tests elsewhere

| Item | AI customizes / integrates | Gate |
| --- | --- | --- |
| `port.sh --to <skill>:<board>` | ports one layer at a time: image → console → one service, register values checked against the target's reference manual | baseline captured on the source board with the same specs; each check passed / failed / unverified on the target |
| `export_app.sh` | packs the app with its skills, scripts and tests | the exported project builds and tests on its own |

### Tool skills

| Item | Gate |
| --- | --- |
| hw-troubleshooting: `CASE.md` per investigation (symptom, hypotheses with verdicts, captures, next check); keep the live fault before any reset; outcome = verified fix / mitigation / unresolved | the original reproducer re-run after the fix, with the same capture setup |
| sensor-debug: bounded read ("read N s, report resets and errors") `(cr)` | `DEBUG:` gate line |
| sensor-debug: own gate prefix (its `DEBUG:` lines clash with `debug.sh`) `(cr)` | renamed gate line, old one accepted for a release |
| cleanroom-test: a run per new skill, template or board profile | report with triage in `reports/` |

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
