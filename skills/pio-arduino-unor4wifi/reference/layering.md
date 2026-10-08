# Stage 3 - Layered code (Arduino)

```
src/main.cpp        the sketch: setup() wiring + banner, loop() polls the services
  │ uses
src/func/*.cpp/.h   services on the Arduino API: console (line editor + dispatch on a Stream,
  │ uses             output via console_out(): Print and console_printf()), led (1-based, pin
  │                  read-back), button (debounce timed with millis(), events; 0 buttons here)
src/board/board.*   board adaptation: pin table (LED_BUILTIN = D13), Serial as the console Stream,
  │ uses             pinMode/digitalWrite/digitalRead, BOARD_xxx #if tables
<Arduino.h>         Arduino UNO R4 core 1.4.1 (Renesas FSP underneath), variant UNOWIFIR4,
                    Serial = UART to the ESP32-S3 USB bridge
```

Call chain: reset → Arduino loader (below 0x4000) → sketch start-up at 0x4000 (FSP init) →
`setup()` once, then `loop()` forever.

Rules
- Every file includes `<Arduino.h>` - the Arduino API is the platform of this skill, in every
  layer (`check_layers.py` allows it). Dependency direction is strictly downward; `func/` and
  `main.cpp` never call `pinMode`/`digitalWrite`/`digitalRead` or name `Serial`
  (`check_layers.py` flags them) - they use `board.h`, `console_out()`/`console_printf()` and
  `millis()`.
- No FSP/`R_*` calls and no C stdio: output is `Print` (`print`/`println`) or `console_printf()`
  (the core's `Print` has no `printf`; up to 127 characters per call), input is `Stream`
  (`available`/`read`).
- A board difference goes in `board/` (the `#if` pin tables in board.cpp, `BOARD_ID_NAME` in board.h) -
  never `#ifdef` in `func/`.
- `loop()` must not block: `Serial` input is buffered, a long `delay()` still delays commands.
- Output with no host: `Serial` is a UART - prints never wait for a host.
- Everything in `src/` is compiled with `-Wall -Wextra` (`build_src_flags`); the build gate allows
  0 warnings there.

## Console protocol (test contract)

| Line | Meaning |
| --- | --- |
| `READY` | boot finished, accepting commands (printed after `INFO ...`) |
| `INFO app=<name> v=<ver> board=<id> ...` | identity - the test checks `board=<id>` |
| `OK ...` / `ERR <reason>` | command result |
| `EVT ...` | asynchronous event (`EVT btn1=pressed ...` - none on this board, no user button) |
| `<TAG> k=v ...` | state report (`LED led1=0`, `BTN`) |
