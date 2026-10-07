# Stage 3 - Layered code

```
src/main.cpp        application: setup()/loop() wiring, command table, policies
  │ uses
src/func/*.cpp/.h   services: console (line editor + dispatch), led (1-based), button (debounce,
  │ uses             events); later: sensors, storage, wifi...
src/board/board.*   board adaptation: pins, LED_BUILTIN, BOOTSEL, BOARD_xxx #ifdefs, Serial
  │ uses
arduino-pico core   (framework, never edited)
```

Rules
- Dependency direction is strictly downward. `func/` includes `../board/board.h` only; no
  `digitalWrite(<pin>)`, `BOOTSEL` or pin numbers outside `board/`.
- A board difference is fixed in `board/` (or the board profile), not with `#ifdef` in `func/`.
- `board.h` maps `-DBOARD_<ID>` to `BOARD_ID_NAME`, `BOARD_NUM_LEDS`, `BOARD_NUM_BUTTONS`.
  Do not name a macro `BOARD_NAME`: arduino-pico passes `-DBOARD_NAME=...` itself.
- Everything under `src/` is compiled with `-Wall -Wextra`; the build gate allows 0 warnings there.
- PlatformIO compiles all of `src/` recursively - no build-file edits for new files. Prefer `src/`
  subfolders over `lib/` for app code (warnings flags and include paths stay simple).
- Never block in `loop()` longer than ~1 ms per service: the console and buttons are polled.
- `BOOTSEL` briefly disables flash access while read: poll it (10 ms), never from an interrupt.

## Console protocol (test contract)

| Line | Meaning |
| --- | --- |
| `READY` | accepting commands (printed after `INFO ...`) |
| `INFO app=<name> v=<ver> board=<id> ...` | identity - the test checks `board=<id>` |
| `OK ...` | command succeeded, with resulting state (`OK led1=1`) |
| `ERR <reason>` | command rejected (`ERR unknown command 'foo' (try help)`) |
| `EVT ...` | asynchronous event (`EVT btn1=pressed name=BOOTSEL led1=1`) |
| `<TAG> k=v ...` | state report (`LED led1=0`, `BTN btn1=0`) |

Input: CR or LF ends a line; characters are echoed; lines < 64 chars. The USB CDC port only exists
after the sketch started, so the boot banner is usually missed - tests sync with `info`.

## Adding a feature (recipe)

1. Survey the hardware from `boards/<id>/README.md` and the core's variant header - is the pin
   free (not CYW43439-owned)? Which library supports it on this core?
2. Add `board_xxx()` in `board/` hiding pins and core calls.
3. Add `func/xxx.cpp/.h` with init/poll/get (no blocking > 1 ms in poll).
4. Register console commands in `main.cpp`; print with the protocol above.
5. Add test steps to `tests/<app>.json` (automatic first; interactive only when a human is needed).
6. Libraries: `lib_deps = owner/name @ x.y.z` (exact version) in `platformio.ini`.
