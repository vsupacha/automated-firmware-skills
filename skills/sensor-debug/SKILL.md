---
name: sensor-debug
description: PC-side debugging of the values a running app prints - a Python tool (scripts/sensor_debug.py) drives the app's console over the board's console port (no flashing) to check init status, bus scans, self-tests, value plausibility and noise against limits, decode raw driver error codes, sweep rates/settings, and run before/after physical stimulus tests (rotate, flip, breathe, lift); on request it opens a browser live view (scripts/sensor_dash.py + web/index.html) that charts every reading and sends console commands, with a raw log for the agent. Use when readings are missing, wrong, noisy or failing (ERR_BUS, ERR_NODEV, NODATA, stuck values, odd magnitudes), when verifying a new driver on hardware, or when asked to watch or chart what a board prints - for any app of this repo's board skills that keeps the console protocol.
---

# sensor-debug - drive and judge the numbers from the PC

A tool skill for every board skill. The firmware prints numbers; this skill makes the PC decide
whether they are right. `scripts/sensor_debug.py` (Python 3 + pyserial) talks to the **running**
app over the board's console port. It never flashes, resets or erases - firmware changes go
through the board skill (build, then **ask before every flash**).

```bash
DBG=skills/sensor-debug/scripts/sensor_debug.py
python "$DBG" --board <board-id> diag          # port from apps/.bench/<board-id>.env (the skill's discover.sh)
python "$DBG" --port <port> watch --seconds 10 --limits skills/sensor-debug/limits/example-at-rest.json
python "$DBG" ports                            # list serial ports
```

Close other users of the port first (`serial_test.py`, an IDE serial monitor, a terminal) - only
one program can own it. Gate lines: `DEBUG: PASS|FAIL`, plus `DIAG:`, `CHECK:`, `EXPECT:`, `SWEEP`,
`STAT`, `ERRS` details. Exit 0 = PASS. `watch` fails when no data line arrives at all (`WATCH: no
data lines received`): an app that only answers commands, like `push-to-light`, prints nothing on
its own - use `send`. `--limits` checks every field of the file: use a limits file for the tags
YOUR app prints (the example file lists typical sensor tags only).

## Commands

| Command | What it does | Use it for |
| --- | --- | --- |
| `ports` | list serial ports | find the console port |
| `send <cmd>... [--wait S]` | raw console session | anything the app's `help` lists |
| `diag [--seconds N]` | `info` (SENSORS init status), `scan` (bus addresses), `selftest`, short capture; decodes `rslt=` codes | first step for a sensor app |
| `watch [--seconds N] [--rate MS] [--tags ENV,IMU] [--csv F] [--limits F]` | capture, per-field n/mean/sd/min/max, error counts; limits = range + noise (sd) check | plausibility, noise floor, long runs, fast-rate stress, CSV for plots |
| `snapshot <f.json> [--seconds N]` | save field means | before a physical stimulus |
| `diff <f.json> [--seconds N] [--expect EXPR...]` | means now vs snapshot, deltas, expectations | after the stimulus |
| `sweep --cmd "rate {v}" --values 12,25,100 [--tags MAG]` | run a command per value, count samples/errors | find the setting that breaks it |

`--expect` syntax: `TAG.field>+N` rose >= N, `TAG.field<-N` fell >= N, `TAG.field~N` changed <= N,
`TAG.field!N` changed >= N either way. Units are the ones the firmware prints.
`--log F` (global) appends every received line to a file - keep it next to the app logs.
Port lookup: `--port`, else `--board` (needs the bench file `apps/.bench/<board>.env` with
`CONSOLE_PORT`, written by the board skill's `discover.sh` - without it `--board` stops), else the
only USB serial port. On a PC without a bench file, leave `--board` out (one board plugged in) or
pass `--port` (`ports` lists them). Every command prints the port it opened (`PORT: ...`).
A board flashed before 2026-10-09 may still run `uart-btn-led` - today's `push-to-light`.

## Live view (browser, only when the user asks)

Triggers: "show the readings live", "open the live view / graph", "watch the values in the
browser", "ดูค่าแบบสด", "เปิดกราฟ/หน้าเว็บดูค่า". Not for automated checks - those are `diag` /
`watch` / `diff`.

```bash
LIVE=skills/sensor-debug/scripts/sensor_dash.py
python "$LIVE" --app apps/<app>            # board from <app>/*-app.env, settings from <app>/tests/liveview.json
python "$LIVE" --board <board-id>          # any app; settings from web/config.json
python "$LIVE" --port <port> --config my.json --no-open
```

serial → `sensor_dash.py` (stdlib HTTP server, 127.0.0.1:8765) → **one** browser page
(`web/index.html`, Server-Sent Events). The server only forwards lines; the page parses the console
protocol and draws one card + chart per `TAG.field`, shows `<TAG> ERR ...` on that group, keeps a
console log and has a command box + quick buttons (`POST /cmd`). No installs, works offline,
reconnects after a USB replug or a reflash.

1. Only on request. Start it in the background (`run_in_background: true`); it opens the default
   browser (`--no-open` + the built-in browser pane when you need to look yourself).
2. Tell the user the URL, that it holds the console port, and how to stop it.
3. **Raw data first - you handle the data, the page only views it.** The bridge tees every board
   line (`<`), command (`>`) and status/marker (`#`) with a timestamp into a raw log
   (`<app>/logs/liveview-<time>.log` with `--app`, else `apps/liveview/logs/`; `--log F` to choose)
   before the page sees it. Read that log;
   never stop the view or ask the user what the page shows to get data. From another shell:
   ```bash
   CTL=skills/sensor-debug/scripts/dash_ctl.py
   python $CTL cmd "info" "rate 200"               # console commands, 1 s apart (--gap; a polled
                                                   # console loses bytes when they arrive back to back)
   python $CTL mark press_B1                       # '# mark press_B1' in the raw log (POST /mark)
   python $CTL --app apps/<app> log --tail 20 --grep "EVT|ENV"
   ```
   For "what changes when the user does X": mark the phase **before** asking for the action, keep
   rest phases and a positive control, then `skills/hw-troubleshooting/scripts/phase_diff.py <raw.log>`.
4. While it runs the port is busy: no `sensor_debug.py`, `serial_test.py` or test after a flash.
   Flashing over the debug probe still works; the bridge reconnects.
5. Stop it (TaskStop / Ctrl+C) when the user is done or before any other serial tool; say so.

Per app: ship `templates/<template>/tests/liveview.json` (copied into the app by `new_app.sh`); keys
as in `web/config.json`: `title`, `window_s`, `quick` (buttons = commands of THAT app), `units`
(`{"nT": [0.001, "µT"]}`), `skip_tags`, `order`. New data shows up by itself as long as the firmware
prints `<TAG> key=<number><unit>` lines. Change `web/index.html` / `sensor_dash.py` only for features
every app needs; keep the server a dumb forwarder.

## Debug playbook

1. **`diag`** - which part fails at init vs at read? Init `ERR_NODEV` = address, power or assembly
   option; a read `ERR_BUS` after a good init = driver/handle problem, not wiring.
2. **Decode the raw code** (`rslt=`, table `reference/result_codes.json`). Example from the TESAIoT
   project: a Bosch `-2 E_COM_FAIL` on every transfer after a good init was a device struct handed
   to the library as a stack variable (the library keeps the pointer) - fixed by making it static.
3. **`watch --limits`** at the default rate, then **`--rate 200`** (stress). A failure only at the
   faster rate = data-rate / data-ready handling (the driver must return `ERR_NODATA`, not wait).
4. **`sweep`** a setting (rate, oversampling, averaging) when one value fails and others work.
5. **Self-test** (`diag` does it) to separate sensor faults from driver faults; keep the board still.
6. **Physical stimulus** - `snapshot`, ask the user to do ONE action (say exactly what to do), then
   `diff --expect ...`:

| Sensor | Ask the user to... | Expect (typical) |
| --- | --- | --- |
| humidity | breathe gently on the board for 3 s | `ENV.rh>+3` `ENV.t>+0.2` |
| pressure | lift the board by ~1 m and hold it still | `ENV.p<-8` (about -12 Pa per m) |
| accelerometer | turn the board upside down, hold still | `IMU.az<-1500` and `IMU.amag~60` |
| gyroscope | keep still | `watch` sd of `IMU.gx/gy/gz` below the limit |
| magnetometer | rotate 90° flat on the desk | `MAG.x!8000` or `MAG.y!8000` (Earth ~25-65 uT) |
| magnetometer | bring a steel screwdriver close | `MAG.bmag!20000` |

   A delta far smaller than expected = the reading is dominated by an offset, or the field is not
   on the axis you think (axis map!).
7. **Record evidence**: a dated line in the board's profile README (verification log); a new code in
   `reference/result_codes.json`; board-specific limits in a `limits/<board>-*.json` of your own.

## Console protocol the tool understands (keep it in new apps)

- data `"<TAG> key=<number><unit> ..."` (TAG upper case; units glued to the number: `t=24.81C`,
  `p=101107Pa`, `ax=-12mg`, `x=-345210nT`) - integers or fixed-point, no exponents. The bring-up
  demos already fit: `BLINK led1=1` is the field `BLINK.led1`.
- failed read `"<TAG> ERR <status> [rslt=0x%08lX]"` - always print the raw code
- **JSON lines** too: `{"sensor":"sht4x","t_cx100":2512,"h_rhx100":4630,"seq":7}` → `SHT4X.t` 25.12 °C,
  `SHT4X.h` 46.30 %; key = `<name>_<unit>[x<scale>]` (units `c rh pct hpa pa g mg dps mdps ut nt lux
  ms v mv`), `{"sensor":"x","error":"init failed"}` → an error on that sensor
- `"SENSORS <name>=<status> ..."` (init), `"SCAN bus=<bus> n=<k> 0x.. ..."`,
  `"SELFTEST <name>=<status> rslt=0x.. ..."`, commands `info`, `scan`, `selftest`, `rate <ms>`,
  `read`, replies `OK ...` / `ERR ...` - the parts a sensor app should add
- a driver that can't produce fresh data returns `ERR_NODATA`, never a bus error

## Files

| Path | Content |
| --- | --- |
| `scripts/sensor_debug.py` | the tool (stdlib + pyserial) |
| `scripts/sensor_dash.py` + `web/index.html` | live view: serial → local server → one browser page (SSE); raw log tee, `POST /cmd`, `POST /mark` |
| `scripts/dash_ctl.py` | commands, phase marks and raw-log reading for a running live view |
| `web/config.json` | default page settings (title, chart window, quick buttons, units, tag order) |
| `limits/example-at-rest.json` | example ranges and noise limits for typical sensors at rest (physics only) |
| `reference/result_codes.json` | status names + raw codes → explanation (extend it) |

Origin: adapted from the TESAIoT project's sensor-debug (the board-specific limits, sensor notes and
the KitProg3 port lookup stayed there).
