# Adding a new PSOC Edge E84 board (modus-psoc-e84 profile)

1. **Collect sources:** schematic, vendor BSP or reference `design.modus`, board manual.
   Record: MCU MPN + EPC category, debug connector + probe type, console UART pins and where
   they go (probe USB-UART or header), LED/button pins and active levels, crystal (ECO)
   frequency and any external clock, external flash/RAM parts.
2. **Pick the base BSP** with the same MPN/EPC (`project-creator-cli --list-boards`):
   `KIT_PSE84_EVAL_EPC2`, `KIT_PSE84_EVAL_EPC4`, `KIT_PSE84_AI`, ...
3. **Copy `boards/_template/`** to `boards/<id>/`, fill `README.md` (hardware) and
   `modus-psoc-e84/board.env`. Unknown values → `# UNVERIFIED`.
4. **Probe first:** `discover.sh <id>` (read-only) lists probes and prints the detected device -
   copy the MPN into `EXPECTED_DEVICE` (and confirm EPC2/EPC4) before it can PASS. The probe
   serial and COM port go to the bench file, not into `boards/`.
5. **Base app without overlay:** `new_app.sh <id> probe-<id> apps none` → note the base
   `design.modus` sha256 and BSP version; compare clocks/pins with the board sources
   (`scripts/modus_diff.py`). If the clock tree differs, port it (reference/project.md).
   Do **not** flash until clocks + console + boot memory are confirmed for this board.
6. **Overlay:** save the edited `design.modus` in `boards/<id>/modus-psoc-e84/`, record both hashes in `board.env`.
7. **Smoke test:** `new_app.sh <id> uart-btn-led-<id>` → build → (ask) flash → test.
8. **Document** hardware in `boards/<id>/README.md` (pins, user I/O, on-board parts) and the
   BSP delta, tool quirks and a dated verification log in `boards/<id>/modus-psoc-e84/README.md`
   (copy the Edgi-Talk structure).
9. Add `BOARD_<ID>` → `BOARD_NAME` in `templates/_common/proj_cm33_ns/board/board.h`, and a row in
   the board table in `skills/modus-psoc-e84/SKILL.md`.
