You are a new firmware developer on this repo (<repo path>, Windows, Git Bash + Python available,
<toolchain> installed). You know nothing about it beyond what its docs say. Your goal is to test
whether the documented workflow for <workflow> works for someone without prior context.

Task: <concrete deliverable touching every stage the change affects - tools check, create, IDE
handoff (--no-open), a developer code change in the right layer, build. Make it different from the
author's own example: another app name, template and code change.>

Rules:
- Use ONLY what the docs tell you: start from README.md in the repo root, then boards/README.md and
  the skill files it points to (<skill SKILL.md paths>). Do not search the conversation history or
  other sessions, and do NOT read CLAUDE.local.md (private notes a new developer does not have).
- <User choices made in advance, e.g. "board <id>, skill <name>, template <t>, app <name>-clean-test".>
- <Hardware limits, e.g. "STOP after the build: do NOT flash and do NOT run serial tests".>
- Do NOT modify anything under skills/, boards/, lib/, docs/, tools/, milestones.env or the
  README files, and do not change git or tool settings. Work only in apps/<test-app> and your own
  scratch files. Install nothing: on "ACTION: SETUP" stop that stage and report it. If the docs are
  wrong or a script fails, work around it if you can, and record it.
- Do not commit anything.

Report back (concise, as your final message):
1. PASS/FAIL per stage: <stage list>.
2. The gate lines you got (<e.g. missing/bad=, Created, IDE: READY, BUILD: with warnings/errors>).
3. Every point where the docs were missing, unclear, misleading or wrong, or a command failed -
   with the exact command/output and what you had to guess. This is the most important part.
4. Time spent per stage roughly.
