# Clean-room run 2026-10-14: sensor-debug (+ hw-troubleshooting phase_diff) on NUCLEO-C562RE

- **Prompt:** a NUCLEO-C562RE is plugged in and runs an unknown app, no bench file, port unknown:
  find the port and the app, read LED/button state, `watch`, live view headless with `dash_ctl`
  command + marks, raw log, `phase_diff.py`, stop and free the port. Read-only console commands
  only (`info`, `help`, `led?`, `btn?`), no flashing, no LED changes, nobody presses buttons.
- **Agent:** general-purpose, no conversation context. 24 tool calls, about 3 min (its estimate of
  the stages: about 12 min of work).
- **Verified by the session:** `git status` of skills/ boards/ lib/ docs/ tools/ README*.md
  milestones.env identical before and after the run; no python process left; the agent's
  `apps/sensor-clean-test/` deleted afterwards.

## Stages

| Stage | Result | Evidence |
| --- | --- | --- |
| port + app identification | PASS (workaround) | `--board` without a bench file stopped; without `--board` the only USB port: `INFO app=uart-btn-led v=1.0 board=nucleo-c562re leds=1 btns=1` |
| LED / button state | PASS | `LED led1=0`, `BTN btn1=0` |
| watch | PASS (expected FAIL) | `DEBUG: FAIL watch 5.0s` - the app prints nothing on its own |
| live view start | PASS | `DASH: http://127.0.0.1:8765/ <- <port> @ 115200` (`--no-open`) |
| command + marks | PASS with a fault | two commands in one `dash_ctl cmd` 3 ms apart -> `bled?` / lost bytes |
| raw log | PASS | marks, commands, replies with timestamps |
| phase_diff | runs, misleading | only rest phases -> no verdict; 0/1 fields and values with units never reported |
| stop + port free | PASS | `send info` answered again after TaskStop |

## Findings and triage

| # | Finding | Class | Fix | Status |
| --- | --- | --- | --- | --- |
| 1 | `phase_diff` never reports a 0/1 field (button) - default `--margin 4` | script-fix | default `--margin 0`: the rest range is the noise band; documented | done, re-tested (synthetic log: `BTN.btn1 1..1 (rest 0..0)`) |
| 2 | `phase_diff` skips values with units or decimals (`t=24.81C`, `p=101107Pa`) | script-fix | parses numbers like sensor_debug.py (decimals, unit glued on) | done, re-tested (`ENV.t`, `ENV.p` reported) |
| 3 | several commands in one `dash_ctl cmd` call garble a polled console | script-fix | commands paced 1 s apart (`--gap`); SKILL.md says why | done, re-tested on the board (`led?` + `btn?` both answered) |
| 4 | `phase_diff` output unexplained, no verdict with only rest phases | script-fix + doc-fix | `PHASE: <n> action phase(s), <k> with changes` / `PHASE: nothing to compare` (exit 1); docstring + hw-troubleshooting toolbox explain "rest" before the first mark and "samples" | done |
| 5 | `--board` without a bench file stops; the fallback was not described | doc-fix | SKILL.md: when to leave `--board` out or pass `--port` | done |
| 6 | `send` printed no port and no gate line | script-fix | every command prints `PORT: ...`; `send` ends with `DEBUG: PASS/FAIL send (n reply lines)` | done, re-tested |
| 7 | the board reports `uart-btn-led`, a name the docs no longer use | doc-fix | SKILL.md: boards flashed before 2026-10-09 may run `uart-btn-led` = `push-to-light` | done |
| 8 | `watch` FAIL gave no reason; the example limits add `no samples` noise | script-fix + accepted | `WATCH: no data lines received - ...`; SKILL.md: use a limits file for the tags your app prints | done, re-tested |
| 9 | without `--app` the raw log went to the current folder, where `dash_ctl log` does not look | script-fix | default `apps/liveview/logs/`; `dash_ctl log` searches it | done, re-tested |
| 10 | `--log` of sensor_debug.py wrote CR LF; echoes in the logs; a stopped server times out instead of refusing | script-fix / noise | log written with LF; the rest noise | done |

Findings 1-3, 6, 8 and 9 changed script behaviour; the affected stages were re-run by the session
on the same board (send, watch, live view with two paced commands and marks, default log
location, phase_diff on synthetic logs). The rest of the workflow is unchanged.
