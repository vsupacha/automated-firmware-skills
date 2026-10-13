---
name: web-wizard
description: Browser forms instead of one-by-one console questions - opens a local page, waits for the user's submit and returns all answers at once. "project" mode is a new-app wizard for the board skills of this repo (board, skill, bring-up template with its verified level, app name, then generate + IDE / build / build + flash + test), with the scripts' first gates and optionally the skill's check_tools.sh run before submit; "ask" mode renders any set of questions (AskUserQuestion-like JSON). Use when several choices are needed at once, when creating a new app and the user would rather pick on one page, or when the user asks for a web form ("open the wizard", "ask me in the browser", "เปิดหน้าเว็บให้เลือก").
---

# web-wizard - answer many questions on one page

A tool skill shared by all board skills: a local Python (stdlib) server with one page; you wait
for the result. The page only collects answers - every action still runs through the gated
scripts of the chosen board skill afterwards.

## When to use it (vs. console questions)

When **two or more** decisions are pending (typical: a new app = board, skill, template, app name,
next step), offer both once per session and remember the choice: "Answer in the browser (one form)
or here (console questions)?" A single quick decision stays in the console. Never open the browser
without the user's consent.

## Project wizard (new app)

```bash
python skills/web-wizard/scripts/wizard.py project [--board <id>] [--skill <name>] [--app <name>] [--ws <apps-dir>]
```
Run it in the background (`run_in_background: true`); it opens the default browser and exits
when the user submits, cancels, or after `--timeout` (900 s). The last stdout line is
`WIZARD: ANSWERS {json}` | `WIZARD: CANCELLED` | `WIZARD: TIMEOUT`.

The form is built from the repo's live data, so it only offers what exists:
- boards with a profile (`boards/index.json`) and, per board, the skills that have a profile, with
  the best level verified on hardware
- the skill's templates (`templates/*/description.txt`), each with its level on that board; the
  bring-up demos are `hello-world`, `blink`, `push-to-light`
- next step: `generate_ide` | `build` | `build_flash_test` (not offered when the skill's board
  stages are planned) and "also open in the IDE" for the build steps
- **Check** = the gates `new_app.sh` runs first (app name, app does not exist, board profile,
  template); **Check tools** also runs the skill's read-only `check_tools.sh`. Submit runs Check
  again and refuses a selection it blocks.

Answers JSON: `board, skill, app, template, action, open_ide, commands[], check{rc, lines}`.
`commands` are the commands in order (new_app, build, discover, flash, test) - use them as a plan,
but follow the board skill's SKILL.md for each stage (e.g. the python that runs its
`serial_test.py`, relaying `ACTION:` lines).

| `action` | What you do |
| --- | --- |
| `generate_ide` | run the `new_app.sh` command (it opens the IDE, stage 2d); tell the user it is open |
| `build` | `new_app.sh`, then `build.sh`; report `BUILD:` |
| `build_flash_test` | `new_app.sh`, `build.sh`, `discover.sh <board>` if this PC has no bench file, `flash.sh <app> --yes`, the skill's `serial_test.py` with the template's spec. Picking this in the form is the user's approval for **that one** flash of that app to that board; any further flash needs a new OK |

If the user cancels or it times out, fall back to console questions.

## Generic questions

```bash
python skills/web-wizard/scripts/wizard.py ask questions.json [--out answers.json]
```
`questions.json` (see `examples/questions.json`):
`{"title": "...", "questions": [{"id", "header", "question", "multi": false, "other": true,
"options": [{"label", "description"}]}]}`. Every question needs an answer (a choice or "Other").
Answer: `{"mode": "ask", "answers": {"<id>": {"question", "selected": label | [labels], "other"}}}`.

## Files

| Path | Content |
| --- | --- |
| `scripts/wizard.py` | server: `project` / `ask`, `/data.json`, `/check`, `/submit`, `/cancel` (127.0.0.1:8766) |
| `web/project.html` | new-app wizard page |
| `web/ask.html` | generic question page |
| `examples/questions.json` | example spec for `ask` |

Origin: adapted from the TESAIoT project's web-wizard (its project mode used that project's
component engine; here it uses this repo's board index, profiles and templates).
