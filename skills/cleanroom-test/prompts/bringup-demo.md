You are a new firmware developer on this repo (the repo root, Windows, Git Bash + Python available, the toolchain of the board below installed). You know nothing about it beyond what its docs say. Your goal is to test whether the documented bring-up workflow works for someone without prior context.

Task: on board `<board-id>` with skill `<skill>`, create an app named `blink-clean-test` from the `blink` template, then change the application so LED1 blinks twice as fast (every 0.25 s) and its INFO line reports the new period - in the layer the docs say application code belongs to, without touching the board layer. Build it until the build gate passes with 0 warnings in the app's own sources, and update the app's test spec so it would check the new period.

Rules:
- Use ONLY what the docs tell you: start from README.md in the repo root, then boards/README.md, the board's README (`boards/<board-id>/README.md`) and the skill files it points to (`skills/<skill>/SKILL.md` and what that references). Do not search the conversation history or other sessions, and do NOT read CLAUDE.local.md (private notes a new developer does not have).
- Choices made in advance by the user: board `<board-id>`, skill `<skill>`, template `blink`, app `blink-clean-test`, script path (run the scripts yourself). Create the app with `--no-open` (no IDE window in this test), but confirm the IDE handoff gate line.
- STOP after the build: do NOT run discover, flash or serial tests (no board is assigned to you in this test).
- Do NOT modify anything under skills/, boards/, lib/, docs/, tools/, milestones.env or the README files, and do not change git or tool settings. Work only in apps/blink-clean-test and your own scratch files. Install nothing: on "ACTION: SETUP" stop that stage and report it. If the docs are wrong or a script fails, work around it if you can, and record it.
- Do not commit anything.

Report back (concise, as your final message):
1. PASS/FAIL per stage: tools check, app creation + IDE handoff gate, code change (which file, which layer), build, test-spec update.
2. The gate lines you got (missing/bad=, Created, IDE: READY, BUILD: with warnings/errors).
3. Every point where the docs were missing, unclear, misleading or wrong, or a command failed - with the exact command/output and what you had to guess. This is the most important part.
4. Time spent per stage roughly.
