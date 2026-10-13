---
name: hw-troubleshooting
description: Hardware troubleshooting method for any board of this repo - find out whether a fault is firmware, configuration, bench setup or hardware, without guessing pins and without risky writes - least-invasive steps first (console of the running app, read-only identity/register reads, then a gated firmware change), one physical action at a time with marked phases and a positive control, separation by a reference (second board, vendor firmware, known-good image), and recording every finding in the board's verification log. Covers a stuck or clamped bus, devices that do not answer, buttons/LEDs that do nothing, values that change for no reason, "works on one board but not the other", and a second probe on the same PC. Use when the user says something does not work on the board, "check the HW", "why is X dead", "compare with the working board", "is it firmware or hardware", "which pin is this button".
---

# hw-troubleshooting - is it firmware, setup or hardware?

A tool skill (method) for every board skill. It owns no board facts: pins come from
`boards/<id>/README.md` (hardware sheet) or the vendor BSP; findings go back into the board's
profile README (verification log). Works with the board skill's scripts (`discover.sh`,
`backup.sh` where it exists, `build.sh`, `flash.sh`, `serial_test.py`) and with the
[sensor-debug](../sensor-debug/SKILL.md) skill (console tool, live view, raw log).

## Rules

1. **Least invasive first:** console commands of the running app → read-only reads (the skill's
   `discover.sh` identity check, a read-only register read through the debugger) → a firmware
   change built and flashed through the board skill. **Ask before every flash** (one approval =
   one flash, per board). No register or option-byte *writes* through the debugger - add a console
   command to the app instead and flash that.
2. **One physical action at a time.** The user acts, you record. With the live view running:
   `dash_ctl.py mark <phase>` **before** asking for the action (marks sent after the answer lag the
   action by seconds), keep a clean rest phase between actions, and include a **positive control**
   phase (an action that must show a change) - if the control shows nothing, the capture is broken.
3. **Raw data first.** When the live view runs, its bridge owns the port and tees every line into
   `<app>/logs/liveview-*.log`: read that (`dash_ctl.py log`), never stop the view to get data.
   Show raw words (register values, raw readings) before trusting a decoded value.
4. **Separate firmware from hardware** with a reference: the same image on a second board, the
   vendor's demo/release firmware on both boards, or an image of a known-good board. Same image,
   different result → hardware or bench state.
5. **Pins only from the board sheet or the BSP** - never from photos or guesses. A pin found on
   hardware goes into the board sheet with the date; an unknown pin = ask for the schematic.
6. **Record as you go:** a dated line in `boards/<id>/<skill>/README.md` (verification log); a
   hardware quirk in `boards/<id>/README.md` ("Hardware quirks"). Never commit probe serials, COM
   ports or flash dumps (`apps/`, `backup/` are git-ignored).

## Toolbox

| Need | Tool | Notes |
| --- | --- | --- |
| is the board there, the right one, unlocked | the skill's `discover.sh <board>` | read-only identity (chip/device id, probe, security state); never changes protection |
| what the running app says | `sensor-debug/scripts/sensor_debug.py send info` / `diag` | `help` lists the app's commands |
| what changes when the user does X | live view + `dash_ctl.py mark` + `scripts/phase_diff.py <raw.log> [--tag ...] [--ignore ...]` | lines before the first mark are phase "rest"; rest phases (`--rest`, default names starting with "rest") give each field's range; every other phase lists the fields that leave it (`--margin 0` default, raise it for noisy raw values); ends with `PHASE: <n> action phase(s), <k> with changes`; counters that always move go into `--ignore` |
| how another firmware configures a pin / peripheral | a read-only register read through the skill's debugger (pyOCD `cmd -O connect_mode=attach -c "read32 <addr>"`, STM32CubeProgrammer read, OpenOCD `mdw`) | attach without halt/reset where the tool allows; addresses from the reference manual |
| keep the current firmware before overwriting it | the skill's `backup.sh <board>` (where it has one) or a read-only flash read with the debugger | dumps go to `backup/`, never to git |
| try the vendor's firmware / a known-good image | download only with the user's OK, check its hash, list its address ranges, then the skill's flash path | never images that write option bytes / security areas |
| second board or probe on the same PC | `discover.sh <board> --serial <probe>`; each board has its own bench file and console port | one probe serial = one board id |

## Playbooks

**A. Bus stuck / devices do not answer**
1. Read the line levels (an app command that reports SCL/SDA with the MCU pull-ups on, or a scan).
   Both high → the bus is free, go to B. Low with pull-ups on → a device clamps it.
2. Change one switch / connector / jumper at a time, wait, read again - a release can take minutes
   (slow supply decay). Unpowered devices clamp a bus through their protection diodes.
3. Record which position frees / clamps the bus.

**B. A device NACKs on a free bus**
1. Scan - is the address there at all? Right after a reset the device may still boot - retry for
   ~200 ms before calling it dead.
2. Compare the bus speed and pin modes with a firmware where it works (read-only register read).
3. Run the vendor's demo firmware - if it fails the same way, it is the board, not our code.

**C. Button / switch / LED does nothing**
1. Check the board sheet: pin, active level, pull, assembly options (solder bridges), and nets
   shared with other parts (a camera, a USB power switch).
2. Read the raw level through the app (`btn` / `led` commands of push-to-light read the pin back),
   with a marked press phase and a rest phase in the live view.
3. Nothing changes at all → not on that pin: ask for the schematic; record the answer.

**D. Values move for no reason / drift**
1. Capture rest phases only; a field that moves at rest is a counter, a timestamp or noise -
   `sensor_debug.py watch` gives its sd; compare with the limits.
2. Isolate the stimulus: one action per marked phase, `phase_diff.py` lists what really moved.

**E. Firmware or hardware?**
1. Same image on the suspect and a known-good board (or the vendor firmware on both): same symptom
   on both → firmware or configuration; only on one → that board or its bench.
2. A debugger acquire resets the MCU but not the rest of the board - a board can lose a "working"
   state across tests; power-cycle (all USB out) before concluding.

## Pitfalls (tooling)

- The live view holds the console port: use its raw log + `dash_ctl.py`, not a second serial client.
- Bash heredocs in some shells turn `\r\n` / `\d` into control characters - write helper files with
  an editor (or the Write tool) and check C `printf` strings after a scripted edit.
- A probe that vanished from the PC needs the user: replug it with a data cable; never update probe
  firmware without asking.

## Files

| Path | Content |
| --- | --- |
| `scripts/phase_diff.py` | which values leave their rest range in each marked phase of a live-view raw log |

Origin: the method of the TESAIoT project's hw-troubleshooting (its PSOC Edge register-peek script,
board commands and known issues stayed there).
