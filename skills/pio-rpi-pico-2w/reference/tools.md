# Stages 1, 4, 5 - Tools, build and flash details

## PlatformIO

- Install: `python -m pip install -U platformio`, or the VS Code PlatformIO extension (it creates
  `~/.platformio/penv`). Scripts call `pio` by full path (`$PIO`, found by `env.sh`); do not add
  `penv/Scripts` to PATH - it shadows the system python (pyserial lives there).
- `PLATFORMIO_CORE_DIR` moves `~/.platformio` (useful when the Windows user name has non-English
  characters: the toolchain breaks on non-ASCII paths).
- `pio` output contains tree characters: `env.sh` sets `PYTHONIOENCODING=utf-8`, otherwise
  `pio pkg list` crashes with UnicodeEncodeError when piped on Windows.

## The platform pin

The official `platformio/raspberrypi` platform has **no RP2350 boards**. This skill uses Max
Gerhardt's fork, which bundles Earle Philhower's arduino-pico core:

```ini
platform = https://github.com/maxgerhardt/platform-raspberrypi.git#5d4561a05e3b212660ac6fdd3fbfb328d1988aa1
board = rpipico2w
framework = arduino
board_build.core = earlephilhower
```

- The platform commit pins `framework-arduinopico` (`fd65f6d4` = 6.1.0+4) and the toolchain
  (pico-quick-toolchain 5.0.0: GCC, picotool 2.0, pioasm). One commit = one reproducible toolchain.
- PlatformIO installs a commit-pinned platform as `platforms/raspberrypi@src-<hash>` next to an
  unpinned one; the 1.4 GB framework package is reused when its commit matches.
- First install clones arduino-pico with submodules (~1.4 GB). On Windows git needs
  `core.longpaths=true` (`git config --global core.longpaths true` - the user's decision).
- Updating: new commit in `boards/<id>/pio-rpi-pico-2w/board.env`, rebuild all templates, diff the
  manifests' package lists, re-test on hardware, log the result.

## Build (build.sh)

- `pio run -d <app> -e <env>`; `--clean` runs `-t clean` first.
- Warnings: `build_src_flags = -Wall -Wextra` applies to `src/` only, so framework warnings do not
  count; the gate counts warnings whose file is under `src/`.
- SCons relinks only when an object changed: an unchanged `firmware.uf2` after exit 0 is up to date.
- Artifacts: `.pio/build/<env>/firmware.uf2` (flashed), `firmware.elf` (debug, `arm-none-eabi-nm`),
  `firmware.bin`. The manifest records the sha256 of all three.

## Flash (flash.sh)

The skill drives picotool itself instead of `pio run -t upload` (which may rebuild and does not
pin the board by serial):

1. Board running an arduino-pico sketch: open its CDC port at **1200 baud** and close it - the
   core reboots into BOOTSEL. pyserial often raises "A device which does not exist was specified":
   the board left before the port was configured (expected).
2. `picotool info -d --ser <SERIAL>` - **the serial is case-sensitive, upper-case hex**. Gate on
   `type`, `flash size`, `chipid` (= USB serial), `secure boot: 0`.
3. `picotool load -v -x <uf2> --ser <SERIAL>` - program, verify, run. Gate: exit 0 and
   `Verifying Flash: ... 100%`.
4. Wait for the CDC port with the same serial (≤20 s).

Fallbacks (ask the user):
- **Manual UF2** (always works, no driver): unplug, hold BOOTSEL, plug in, release; copy
  `firmware.uf2` to the `RP2350` drive. The drive vanishing mid-copy is normal. Then run the test.
- **picotool cannot open the BOOTSEL device** on Windows while the drive is visible: no WinUSB
  driver on "RP2350 Boot" - bind it with Zadig (user's decision), or use the manual UF2 copy.
  Not needed on the Windows 11 PC used for verification (2026-10-07).
- **SWD probe** (`upload_protocol = cmsis-dap` / `picoprobe`): for boards that do not enumerate.

## Board facts: where they come from

PlatformIO first, never memory: `pio boards rp2350`, `pio boards <id> --json-output` (USB hwids,
upload protocols, flash/RAM). Pin/ADC facts: the core's `variants/<board>/pins_arduino.h`. If the
web and the CLI disagree, the CLI wins; no exact board id → stop and ask.
