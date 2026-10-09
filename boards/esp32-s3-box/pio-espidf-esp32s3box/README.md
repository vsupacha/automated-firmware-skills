# ESP32-S3-BOX - pio-espidf-esp32s3box profile

Board profile of the `pio-espidf-esp32s3box` skill: `board.env` (pinned platform, board id, define, labels,
expected identity) and `sdkconfig.board` (flash, PSRAM). Hardware: [../README.md](../README.md).

| Item | Value |
| --- | --- |
| PlatformIO platform | `platformio/espressif32@6.12.0` (registry, exact version) |
| Framework | ESP-IDF 5.5.0 (`framework-espidf` 3.50500.0, pinned by the platform) |
| Board id / env | `esp32s3box` / `esp32_s3_box` |
| Console | USB Serial/JTAG through the IDF driver: non-blocking reads, output dropped after 50 ms when no host reads, LF kept as written |
| FreeRTOS tick | 1 kHz (`CONFIG_FREERTOS_HZ=1000`): the superloop yields 1 ms per pass |
| PSRAM | 8 MB embedded (esptool 2026-10-07); still off in `sdkconfig.board` until an app needs it |

## Verification log

- 2026-10-07 skill `pio-espidf-esp32s3box` created (PlatformIO 6.2.0, espressif32 6.12.0, ESP-IDF
  5.5.0, GCC 14.2.0, Windows 11 + Git Bash). discover: ESP32-S3 (QFN56) rev v0.1, embedded PSRAM
  8 MB, flash 16 MB, MAC = USB serial, secure boot + flash encryption disabled - IDENTITY PASS.
  - `hello-world` (app `hello-box`): build PASS 0 warnings (flash 211,261 B), firmware.bin
    `9b198bcf...`; flash 3/3 regions hash-verified, no replug; test PASS 9/9 (1 s period, no
    watchdog or reset messages, opening the port does not reset the app).
  - `uart-btn-led` (app `btn-box`): build PASS 0 warnings, firmware.bin `1e83b9b4...`; a planted
    unused variable gave `BUILD: WARNINGS` (exit 2) as intended; flash PASS; automatic test PASS
    13/13 (LED1 = LCD backlight on/off/toggle with GPIO read-back). Interactive BOOT step: attempt 1
    FAIL (no `EVT btn1` within 30 s, press timing); attempt 2 lost the COM port at the press while
    the app kept running (LED1 read back 1 afterwards: the press was seen, no reboot - USB cable
    disturbed); attempt 3 PASS 5/5: `EVT btn1=pressed name=BOOT pin=GPIO0 led1=1`,
    `EVT btn1=released`, `LED led1=1` - BOOT (GPIO0) run-time read + debounce verified.
    **Observed by the user:** the LCD backlight (LED1, GPIO45) lit after the BOOT press.
- 2026-10-09 template `uart-btn-led` renamed `push-to-light` (same code apart from the app
  name) - build PASS 0 warnings; new template `blink` (LED1 every 0.5 s) - build PASS 0
  warnings. Both built only, not flashed (the earlier results above were with the old name).
