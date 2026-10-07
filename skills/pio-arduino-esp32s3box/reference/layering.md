# Stage 3 - Layered code (Arduino)

```
src/main.cpp        the sketch: setup() wiring + banner, loop() polls the services
  │ uses
src/func/*.cpp/.h   services on the Arduino API: console (line editor + dispatch on a Stream,
  │ uses             output via console_out(): Print), led (1-based, pin read-back), button
  │                  (debounce timed with millis(), events)
src/board/board.*   board adaptation: pin table (TFT_BL, GPIO0), Serial as the console Stream,
  │ uses             pinMode/digitalWrite/digitalRead, BOARD_xxx #if tables
<Arduino.h>         arduino-esp32 2.0.17 core, variant esp32s3box, Serial = HWCDC (USB Serial/JTAG)
```

Call chain: ROM → bootloader → ESP-IDF start-up → Arduino `loopTask` → `setup()` once, then
`loop()` forever.

Rules
- Every file includes `<Arduino.h>` - the Arduino API is the platform of this skill, in every
  layer (`check_layers.py` allows it). Dependency direction is strictly downward; `func/` and
  `main.cpp` never call `pinMode`/`digitalWrite`/`digitalRead` or name `Serial`
  (`check_layers.py` flags them) - they use `board.h`, `console_out()` and `millis()`.
- No ESP-IDF APIs and no C stdio: output is `Print` (`print`/`println`/`printf`), input is `Stream`
  (`available`/`read`).
- A board difference goes in `board/` (the `#if` pin tables in board.cpp, `BOARD_ID_NAME` in board.h) -
  never `#ifdef` in `func/`.
- `loop()` runs in the Arduino loop task on core 1; it may poll without yielding, but must not
  block: `Serial` input is buffered, a long `delay()` still delays commands and debouncing.
- Output with no host: HWCDC drops data while the port is closed - prints never block.
- Everything in `src/` is compiled with `-Wall -Wextra` (`build_src_flags`); the build gate allows
  0 warnings there.

## Console protocol (test contract)

| Line | Meaning |
| --- | --- |
| `READY` | boot finished, accepting commands (printed after `INFO ...`) |
| `INFO app=<name> v=<ver> board=<id> ...` | identity - the test checks `board=<id>` |
| `OK ...` / `ERR <reason>` | command result |
| `EVT ...` | asynchronous event (`EVT btn1=pressed name=BOOT pin=GPIO0 led1=1`) |
| `<TAG> k=v ...` | state report (`LED led1=0`, `BTN btn1=0`) |
