# Milestone 0 - skill and platform study

## Goal

Understand how the firmware skill repositories select a workflow, create a project, and prove
results before starting a board-specific proof of concept (POC). M0 is a study and workflow
selection milestone; it does not enable later firmware milestones or grant permission to write to
a physical board.

## Repository map

The workspace contains four execution providers and one lifecycle coordinator/reference:

| Repository | Platform / execution model | Main workflow shape | Evidence and boundary |
| --- | --- | --- | --- |
| `automated-firmware-skills` | Bare-metal MCU; STM32 CubeMX/CubeMX2, PlatformIO Arduino/ESP-IDF, Infineon ModusToolbox, NXP MCUXpresso | `SKILL.md` routes to pinned board profile and scripts; create, IDE, build, then optional connect/flash/test | Gate lines, build manifests, serial specs/logs; identity checks and explicit approval before flash |
| `automated-firmware-skills-freertos` | MCU + FreeRTOS; CubeMX/CubeMX2-generated projects | Same gated board workflow, with RTOS middleware/configuration and task-aware app/tests | Build and board gates plus task/stack checks; portable `func/` is kept separate from RTOS execution code |
| `automated-firmware-skills-rtthread` | MCU + RT-Thread, SCons, RT-Thread Studio; Vision, Titan, Edgi-Talk | Board profile + SDK project, recipes, SCons build, msh console, board tests | Gate lines and msh/test logs; recipes alter the SDK project through explicit checks/backups |
| `automated-firmware-skills-emblinux` | Arduino UNO Q: Debian App Lab on QRB2210 + Zephyr-based STM32U585 sketch | Requirement → architecture → code checks → deploy/build → run → tests; Linux app and MCU sketch communicate over RPC | Separate requirement/architecture/code/build/run/test gates; asks before deploy/run/stop/destructive test actions |
| `firmware-dev-life-cycle` | Development lifecycle coordinator, initially local | Requirement → Design → Code gen → Test, with accepted handoffs and provider capability snapshots | Coordinator contract; it calls providers rather than copying their build/flash/test machinery |

The repositories are separate because board, framework, operating system, execution model and
test boundary change the project shape. `automated-firmware-skills-emblinux/README.md` describes
that repository as reserved/early work, while the UNO Q skill itself documents a richer
Linux-plus-MCU staged workflow. Treat its exact capabilities as specific to that skill and version,
not as a generic Linux board workflow.

## Common operating model

1. A skill description routes the request to a specific toolchain/framework/board (or app
   platform), rather than guessing a board API.
2. Board profiles pin versions, board identity and hardware facts. Per-PC probe/port data belongs
   in `.bench/`, not committed board metadata.
3. Scripts own repeatable checks and return a gate (`TOOLS`, `CREATE`, `BUILD`, `IDENTITY`,
   `FLASH`, `RESULT`, etc.). Exit code 10 plus `ACTION:` means a human action/decision is required;
   the agent relays it and waits.
4. Source creation, build, flash, boot, test and human observation are separate evidence levels.
   A successful build is not evidence that firmware ran on the board.
5. The IDE and script paths are alternate ways to work on the same app for most MCU repositories.
   The UNO Q skill has its own PC-master/board-deployment drift check and explicit pull-back path.
6. Safety is implemented at the action boundary: identity before writes, approval before flash or
   deployment, and explicit restrictions around option bytes, eFuses, device lifecycle, installers
   and cleanup.
7. Cross-cutting skills provide assistance around the board workflow: clean-room documentation
   checks, sensor console analysis, hardware triage, firmware unit tests and a browser wizard.

## Platform differences that matter to a developer

| Concern | Bare metal | FreeRTOS | RT-Thread | UNO Q / embedded Linux |
| --- | --- | --- | --- | --- |
| Project source of truth | Vendor-generated project plus layered `board/func/app` | Vendor-generated RTOS project plus task/execution layer | SDK/BSP project copied into app; recipes can add components | App Lab app with Linux Python/assets/Bricks plus MCU sketch |
| Runtime model | Superloop | Tasks, scheduler and RTOS-aware board services | Kernel threads, devices and msh | Linux process/services plus MCU RPC and web/REST paths |
| Main console/test contract | Serial protocol and JSON step specs | Serial specs plus RTOS-specific checks; unit test image on supported skills | msh commands/specs and status inspection | adb logs, HTTP/service checks, MCU and app-level tests |
| Typical build boundary | Vendor CLI/CMake, PlatformIO, make | CubeMX/CMake with RTOS pack and task config | SCons/SDK environment | Deploy to board then release build on board |
| Highest-impact review question | Are generated code and board facts kept in their proper layer? | Are task, tick, synchronization and stack assumptions correct? | Are SDK/recipe changes bounded and reproducible? | Are Linux/MCU responsibilities and RPC names consistent with the declared architecture? |

The repeated `board -> func -> execution/app` idea is useful, but not universal. PlatformIO
Arduino skills keep C++/Arduino APIs in their own templates; RTOS board layers may use RTOS
primitives; UNO Q spans two processors and a Linux app. Evaluate portability at the boundary the
skill actually defines rather than assuming all platforms share one source tree.

## POC project: `m0-status-console`

### Purpose

Exercise the smallest useful end-to-end developer change across distinct execution models: expose
a status/heartbeat over the platform's supported console or RPC path, toggle one on-board LED, and
prove both through an automated spec. The POC should reveal project generation, code ownership,
build reproducibility, test ergonomics, evidence quality and developer-action gates.

### Candidate targets

| Target | Why include it | POC adaptation |
| --- | --- | --- |
| Pico 2 W, PlatformIO + Arduino | Minimal, well-documented bare-metal representative with pinned platform and serial tests | `hello-world`/`blink` baseline; add a status query and verify the LED/console response |
| NUCLEO-C562RE, CubeMX2 + FreeRTOS | Same vendor family with a different execution model and RTOS-aware project | Use its FreeRTOS skill/template; demonstrate the same observable contract from tasks and collect RTOS status where supported |
| Vision Board, RT-Thread | Different SDK, SCons, msh and recipe workflow | Use the RT-Thread skill template; expose status as msh commands and verify via msh test/status tools |
| UNO Q, App Lab | Cross-processor Linux/MCU app model | Use the `blink` or `hello-world` template; show Linux-to-MCU RPC and the app/service test path |

The common behavior is intentionally small; it is not a claim that implementation or test files
are portable between providers. A target is in scope only when its skill reports the needed stage
as implemented and the developer has the matching board/toolchain available.

### Acceptance record per target

- Record selected repository, skill, board profile, pinned tools, template, and current bench
  readiness before creation.
- Create through the target skill's script and retain the printed `CREATE`/creation result.
- Make one small, reviewable behavior change in the layer the skill assigns to application logic.
- Build with the skill's script and retain the exact `BUILD: PASS` output and manifest/hash.
- If a board is available, discover identity before any write. Obtain explicit approval immediately
  before a flash/deploy/run action when required by that skill.
- Keep `FLASH`/`DEPLOY`, `BOOT`/`RUN`, automated `RESULT`, and human observation as separate
  records. Capture the test spec and log.
- Record friction: undocumented prerequisites, unsafe ambiguity, non-repeatable output, stale
  profile facts, unclear ownership, skipped checks, or a gate that cannot distinguish failure
  modes. Do not edit provider scripts merely to make the POC pass; report a proposed fix separately.

### M0 exit criteria

- [x] Identify the repositories and their execution models.
- [x] Explain the shared gate/evidence/safety contract and the main platform differences.
- [x] Select a small POC behavior and define the evidence to capture.
- [ ] Execute one POC through project creation and build using a provider's own scripts.
- [ ] If hardware/tool access is available, execute the approved board stages and record results.
- [x] Summarize the gaps found and recommend the next capability to exercise.

### Findings and next step

- The common gated vocabulary makes the MCU workflows recognizable, but the project generator,
  execution model, console protocol, build tool and test path still belong to each provider. The
  POC should compare outcomes and operator effort; it should not demand shared implementation.
- The lifecycle coordinator currently implements Requirement acquisition/snapshots, while Design,
  Code gen and Test automation are documented or planned. It should not yet be treated as an
  end-to-end controller for the provider repositories.
- Capability claims have different evidence ages and levels across board profiles. Before running
  a target, check its current profile and bench readiness; repository-wide status tables are a
  starting index, not proof of this machine's readiness.
- **Recommended first implementation POC:** Pico 2 W, PlatformIO + Arduino, starting from the
  `hello-world` or `blink` template. It has a compact app/build path and a documented serial spec,
  so project generation and build can be exercised without flashing. Then use the FreeRTOS C5,
  RT-Thread Vision Board and UNO Q targets to compare changes at the RTOS, kernel and
  multi-processor boundaries when those environments are available.
- The immediate blocker is execution of the required Git Bash scripts in this Windows sandbox.
  Resume with the read-only tool check, then create and build via the skill scripts. Hardware
  stages remain separate and require an available board plus any approval gate the selected skill
  emits.

## Study-session result

The repository and skill documents were studied across bare metal, FreeRTOS, RT-Thread, UNO Q
App Lab, and the lifecycle coordinator. A first hands-on command was attempted against the Pico
2 W skill's read-only `check_tools.sh`, but Windows returned `Bash/Service/CreateInstance/E_ACCESSDENIED`
before the script ran. Therefore no tool readiness, app creation, or build result is claimed in
this session. The implementation POC remains ready to run once Git Bash execution is available;
no board was flashed or otherwise modified.

## Source map

- `../README.md`, `../docs/workflow.md`, `../docs/milestones.md`
- `../skills/pio-arduino-rpipico2w/SKILL.md` and its `reference/` docs (bare-metal example)
- `../skills/firmware-test/SKILL.md`, `../skills/hw-troubleshooting/SKILL.md`,
  `../skills/sensor-debug/SKILL.md`, `../skills/cleanroom-test/SKILL.md`,
  `../skills/web-wizard/SKILL.md`
- `../../automated-firmware-skills-freertos/README.md` and its board skills
- `../../automated-firmware-skills-rtthread/README.md` and its Vision Board skill
- `../../automated-firmware-skills-emblinux/README.md` and
  `../../automated-firmware-skills-emblinux/skills/applab-zephyr-unoq/SKILL.md`
- `../../firmware-dev-life-cycle/README.md` and `../../firmware-dev-life-cycle/docs/phase-contract.md`
