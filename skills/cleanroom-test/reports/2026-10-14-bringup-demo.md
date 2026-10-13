# Clean-room run 2026-10-14: bring-up workflow (blink) on pio-arduino-unor4wifi

- **Prompt:** `../prompts/bringup-demo.md` with board `uno-r4-wifi`, skill `pio-arduino-unor4wifi`:
  app `blink-clean-test` from `blink`, LED1 every 0.25 s, INFO reports it, spec updated, stop after
  the build.
- **Agent:** general-purpose, no conversation context. 21 tool calls, about 2.5 min (its own
  estimate of the stages: about 6 min of work).
- **Verified by the session:** `git status` of skills/ boards/ lib/ docs/ tools/ README*.md
  milestones.env identical before and after the run; the app's PASS manifest exists
  (`firmware.bin` 36028 bytes, sha256 `64980ea3...`), its build log has 0 warnings, `main.cpp`
  has `BLINK_PERIOD_MS = 250`.

## Stages

| Stage | Result | Evidence |
| --- | --- | --- |
| tools check | PASS | `missing/bad=0 warnings=2` (Dropbox folder, no board connected) |
| create + IDE handoff | PASS | `Created ...`, `IDE: READY ... (VS Code + PlatformIO IDE)`, `IDE: not opened (--no-open)` |
| code change | PASS | `src/main.cpp` only (application layer per `reference/layering.md`): period 500 -> 250, version 1.1 |
| build | PASS | `pio exit=0 warnings(src)=0 warnings(all)=0 errors=0`, `BUILD: PASS` |
| test-spec update | PASS | `tests/blink.json`: INFO regex `period_ms=250[^0-9]*$`, step timeouts 0.75 s |

## Findings and triage

| # | Finding | Class | Fix | Status |
| --- | --- | --- | --- | --- |
| 1 | Test-spec keys documented only in `lib/fwtest.py`'s docstring | doc-fix | `docs/workflow.md` "Test specs" (keys table + rules); every SKILL.md Stage 6 points to it | done |
| 2 | The blink spec cannot really check the period (`expect` only proves lines arrived) | feature + accepted | "Test specs" says timing is not measured and the INFO line carries the period; measured intervals listed in `docs/milestones.md` Next | doc done, feature open |
| 3 | A `\b` in a JSON regex is a backspace - the step matched nothing | doc-fix | "Test specs": double backslashes, prefer character classes | done |
| 4 | README said `apps/` is git-ignored; app sources are not | doc-fix | README layout line: sources are not ignored, never commit test apps | done |
| 5 | Gate with `--no-open` (`IDE: not opened`) not in the SKILL.md gate line | doc-fix | all 10 SKILL.md: `(IDE: not opened with --no-open)` | done |
| 6 | "2 warnings" vs check_tools exit 0 with WARN rows | doc-fix | README exit codes: 0 pass (WARN rows are advice), 2 = warnings that block a gate | done |
| 7 | SKILL.md's own stage numbers (discover in stage 2, build = 4) differ from the shared ones | feature | renumbering listed in `docs/milestones.md` Next; the mapping table stays meanwhile | open |
| 8 | SKILL.md Stage 2 synopsis lacked `""` and `--no-open` | doc-fix | `[<workspace>\|""] [template] [--no-open]` in the 7 skills that use that line | done |
| 9 | Blink prompt "blink twice a second" ambiguous (toggles vs cycles) | doc-fix | all 10 blink specs: "toggle every 0.5 s (0.5 s on, 0.5 s off)" | done |
| 10 | `INFO app=` is the template name, not the app folder - renaming APP_NAME breaks the spec | doc-fix | "Test specs" rule | done |
| 11 | `Next: build.sh <abs path>` not a full command; Dropbox WARN printed twice | noise | - | - |

The fixes changed wording only (docs, SKILL.md lines, test prompts); the workflow itself is
unchanged, so no second clean-room run is needed. The test app was deleted afterwards.
