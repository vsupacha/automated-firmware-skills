# Contributing

Thanks for helping. This repo ships gated firmware workflows that touch real hardware, so the bar is
"proven on a board and re-runnable by someone else", not "it looks right".

## Before you start

- Read [docs/workflow.md](docs/workflow.md) (stages, gates, exit codes, `ACTION:` lines) and
  [docs/board-api.md](docs/board-api.md) (the `board.h` API and the layering rules).
- Open an issue first for a new skill, board or milestone feature, so the scope and names
  (`<toolchain>-<framework>-<board>`) are agreed before the work.

## What a change needs

1. **Validator:** `python tools/validate_skills.py` ends with `VALIDATE: PASS` (warnings are listed;
   do not add new ones without saying why).
2. **Clean room:** for a new or changed skill, template or board profile, run the
   [cleanroom-test](skills/cleanroom-test/SKILL.md) skill and fix what its report finds; the report
   goes to `skills/cleanroom-test/reports/`.
3. **Honest verification:** add a dated line to the board profile's verification log
   (`boards/<id>/<skill>/README.md`) with what actually ran: built ≠ flashed ≠ tested ≠ observed by
   a person. Update the level in `boards/index.json` only to what the log shows, then run
   `python tools/board_status.py --write` - it rewrites the level tables in `boards/README.md` and the
   board READMEs (the validator fails while they differ from the index).
4. **Same tests everywhere:** the bring-up demos (`hello-world`, `blink`, `push-to-light`) keep the
   shared test specs; a board-specific difference is a deliberate, documented drift.
5. **Behaviour evals:** a new safety rule an agent could get wrong gets a case in `evals/`
   (see [evals/README.md](evals/README.md)); run `claude plugin eval . --runs 1 --ablation none`.
6. **Plugins:** a new board skill goes into exactly one vendor plugin in
   `.claude-plugin/marketplace.json` (the validator checks it); a new tool skill into `firmware-tools`.

## Never commit

- Probe serials, COM ports, IP addresses, user names or user paths (they live in `.bench/` of the
  apps workspace, which is per PC).
- Build outputs, logs, flash dumps (`backup/`), generated vendor trees (`mx/`, `.pio/`, `build/`).
- Test apps from `apps/` (or your per-PC workspace).
- Vendor files under licences that do not allow it (datasheets, manuals, SDK code): link them from
  the board README instead. Copy facts (pins, registers), not code.

## Style

- Scripts and `.env` files are LF (`.gitattributes` enforces it). Bash for stage scripts, Python 3
  standard library + `pyserial` for tools.
- Every stage script ends with one gate line (`BUILD: PASS`, `RESULT: PASS (n/m)` ...) and uses the
  exit codes 0 / 1 / 2 / 10 from docs/workflow.md. Developer actions go through `need_user`
  (`ACTION: <TYPE> ...`, exit 10), never a silent default.
- Anything that writes to a board (flash, erase, option bytes) asks first and checks the board's
  identity; never add a path that bypasses that.

## New board

Copy [boards/_template](boards/_template/README.md). For a board that only you have, put its profile in
your own project as `<project>/boards/<id>/<skill>/` - the skills look there first, so it does not
need to be in this repo.
