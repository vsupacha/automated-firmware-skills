# Edgi-Talk - ModusToolbox profile (modus-psoc-e84)

RT-Thread Edgi-Talk, PSOC Edge E84 `PSE846GPS2DBZC4A` (EPC2), silicon B0, life cycle DEVELOPMENT.
Board hardware (tool-independent): [../README.md](../README.md). This file: BSP aliases, BSP delta,
tool quirks and the verification log of the `modus-psoc-e84` skill.
Machine-readable values: `board.env`. Hardware reference: RT-Thread BSP
<https://github.com/RT-Thread-Studio/sdk-bsp-psoc_e84-edgi-talk> (schematics in `docs/board/`).

## Connections

| Item | Value | Verified |
| --- | --- | --- |
| Debug USB | **CN12 (USB-DEBUG)**, onboard KitProg3 (PSoC 5LP), SWD. CN11 is the E84 USB device port. | yes |
| Probe | CMSIS-DAPv2 `04b4:f155`; serial differs per board - `discover.sh` records it in the bench file | yes |
| Console | SCB2 `CYBSP_DEBUG_UART`, RX P6[5] / TX P6[7] → KitProg3 USB-UART (COM number differs per PC; `discover.sh` finds it), 115200 8N1 | yes (banner seen) |
| M33 console in RT-Thread | SCB5 P17[0]/P17[1], needs an external USB-UART adapter | not used here |
| VTarget | ~1.81 V | yes |

## User I/O (BSP aliases)

| Alias | Pin | Active level |
| --- | --- | --- |
| `CYBSP_USER_LED1` | P16[7] (red) | high (`CYBSP_LED_STATE_ON = 1`) |
| `CYBSP_USER_LED2` | P16[6] (green) | high |
| `CYBSP_USER_LED3` | P16[5] (blue) | high |
| `CYBSP_USER_BTN1` = `CYBSP_SW2` | P8[3], pull-up | low (`CYBSP_BTN_PRESSED = 0`) - **the only user button** |
| `CYBSP_USER_BTN2` = `CYBSP_SW4` | P8[7] | **not populated** on Edgi-Talk (eval-kit leftover in the BSP); `board.h` sets `BOARD_NUM_BUTTONS 1` |

## BSP delta vs `KIT_PSE84_EVAL_EPC2` v1.4.0

The overlay `design.modus` changes **only the clock tree** (required to boot):

| Setting | EPC2 | Edgi-Talk |
| --- | --- | --- |
| `eco[0]` | 17.2032 MHz | 12.288 MHz |
| `ext[0]` + P7[4] ext_clk | 24 MHz external clock | removed |
| `pathmux[0]` / `pathmux[4]` | ext / ext | eco / iho |
| `hfclk[12]` divider | 1 | 2 |

**Never flash an unmodified EPC2 image to Edgi-Talk**: clock path 0 expects an external clock on
P7[4] that this board does not have.

Not ported yet (not needed for UART/LED/button): HyperRAM on SMIF slot 6, SCB5/SCB7/SCB9,
CAN FD, display (`gfxss`), PDM/I2S routing, memory-map changes. See the RT-Thread
`design.modus` and `scripts/modus_diff.py` if needed. Also not ported on purpose: WCO setting and
idle power mode (RT-Thread uses Sleep, the overlay keeps the EPC2 Deep Sleep), RT-Thread's
memory map. P9[2]/P9[3] are soft-I2C (AHT20) in RT-Thread but SCB1 UART in `design.modus` -
choose one before using them.

## Verification log

- 2026-10-07 `hello-world` after the move to the automated-firmware-skills repo (skill renamed
  `modus-psoc-e84`, board profile under `boards/edgi-talk/modus-psoc-e84/`), empty `apps/`:
  discover IDENTITY PASS (VTarget 1.812 V), new_app 2 min 50 s, build PASS 0 warnings in 34 s,
  hex `a6601ea1...` byte-identical to the TESAIoT_track build of 2026-10-04 (same libraries),
  acquire DEVELOPMENT, flash verified 72,100 bytes, no replug, test PASS 9/9.
- 2026-10-03 `uart-btn-led` (skill template, MTB 3.9, BSP 1.4.0 + overlay, mtb-dsl-pse8xxgp 1.7.0):
  built 0 warnings, flashed + verified (hex `55e8e5fc...`), booted in ~7.6 s,
  automatic test PASS 15/15, interactive SW2 test PASS (`EVT btn1=pressed led1=1`, LED1 read back 1).
- 2026-10-03 re-test with revised scripts (discover/bench, manifest + acquire life-cycle gates, sync
  test mode) in a Dropbox-synced workspace without spaces: new_app 3.5 min, build PASS 0 warnings,
  hex byte-identical to the previous run (`55e8e5fc...`, reproducible), acquire: DEVELOPMENT,
  flash verified 73,452 bytes, test PASS 16/16 + interactive SW2 PASS 4/4 (1 skipped: no BTN2).
- 2026-10-03 `hello-world-1s` (template board layer + new `board_millis()` SysTick 1 kHz): build PASS,
  flash verified 72,028 bytes (hex `0aa84675...`), test PASS 9/9; 30 s capture: 30 periods in
  30.0002 s (mean 1.00001 s) - SysTick from SystemCoreClock is accurate with the ported clock tree.

## Quirks

- `make qprogram` acquires in Test Mode (XRES). The flash script adds `adapter serial`.
- Serial capture must be opened **before** flashing to see the boot banner (`--wait-boot`);
  the default test flow syncs with `info` after flashing instead.
- KitProg3 "Test Mode acquisition failed" lines can appear (RT-Thread log) without being fatal.
- Hello-world's CM55 prints nothing; CM55 boot was proven only by `led-uart-ipc` (2026-09-27).
- External 20-pin J2 JTAG/trace header uses a **1.8 V** reference; pin-1 orientation unconfirmed -
  external probes must support 1.8 V.
- `device-configurator-cli --build` must be run **without** `--library` (fails with
  "No device support library information found").
