# HW driver recipes (Kconfig level) - Vision Board

A recipe names one on-chip or on-board driver of the RT-Thread Vision Board BSP and says, before any
firmware is written, what selecting it means for an app. Level: **Kconfig** (`.config` ->
`rtconfig.h`). A recipe never generates FSP code (`configuration.xml` -> `ra_gen/`), board ports or
packages; it states them as preconditions, and `scripts/recipe.sh check` reports which are missing.

```bash
bash "$SKILL/scripts/recipe.sh" list
bash "$SKILL/scripts/recipe.sh" check <app> rw007 sdcard [--show]
bash "$SKILL/scripts/recipe.sh" derive <recipe> [--write]      # maintainer: re-take the values from the SDK
```

`check` loads the app's Kconfig tree with RT-Thread's own `kconfiglib` (as menuconfig does: selects,
depends, defaults), sets the recipe values and reports. Read-only. Gate: `RECIPE: READY` (exit 0) |
`RECIPE: ACTION n` (exit 10; one `ACTION:` line per missing precondition: `KCONFIG`, `FSP`, `PORT`,
`PACKAGE`) | `RECIPE: FAIL` (exit 1; unknown recipe or symbol, a pin or peripheral taken twice).
The apps from `new_app.sh` have no `rt-thread/examples`, which `rt-thread/Kconfig` sources, so the
Kconfig tree of RT-Thread comes from the pinned SDK (same RT-Thread 5.0.2); the package index comes
from RT-Thread Studio's env (`platform/env_released/env-new/packages`).

## FSP of the apps

`new_app.sh` takes the FSP side of every app from `FSP_PROJECT` = `vision_board_openmv` (board profile):
the only SDK project whose `ra_gen/` declares every instance the recipes need (`g_spi1`,
`g_external_irq11`, `g_sci3`, `g_sdmmc1`, `g_timer6`, also `g_uart2`, `g_flash`, `g_timer7/13`, CEU,
display, USB). Kconfig, `.config` and `board/` stay those of `vision_board_blink_led`, so nothing is
integrated: an app still enables only GPIO, UART9 and SDRAM. With it, `check` reports no `FSP` action
(2026-10-31, app built 0 warnings): `i2c1-soft spi1 sci3-i2c sdcard pwm6` are `READY`, `rw007` still
needs its `board/Kconfig` block, board port and package. Apps made before keep blink's FSP (`ioport`
+ `uart` only; `rtt-app.env` has no `APP_FSP`). Ranking of the 19 projects by recipe instances:
openmv 10, rgb_4.3inch_nes / rgb_4.3inch_doom 4, wifi 3 (spi1, irq11), blink 1 (uart9).

## On the board

- 2026-10-31 `rw007` (+ `spi1`) on a push-to-light app with the openmv FSP: applied by hand (prototype
  of an apply step: the `board/Kconfig` block from `vision_board_wifi`, `board/ports/wifi`,
  `packages/rw007-v2.1.0` + `packages/SConscript`, recipe values set with kconfiglib, `.config` ->
  `rtconfig.h` with RT-Thread's `mk_rtconfig`); `check` READY with 0 symbols changed. Build PASS,
  0 warnings in the app (3 in RT-Thread's own `components/drivers/wlan/wlan_mgnt.c`), app.hex
  0x02000000..0x02039F94. On the board: `msh_status.py` MSH: PASS - 16 commands (`wifi ifconfig ping
  dns netstat` added), threads `wifi_xfer wifi_handle wlan tcpip etx erx`, devices `w0 w1 wlan0 wlan1
  wspi spi1`; msh `wifi scan` listed 3 access points (names not recorded); push-to-light test still
  17/17. Then (developer's own access point, credentials given in the session, not stored): `wifi join`
  -> "wifi connect success" + DHCP address, `wifi status` RSSI -62, `ifconfig` w0 default with gateway
  and DNS, `ping www.rt-thread.org` 4 replies (57-127 ms). Auto-connect is off: the join is not kept
  after a reset.

## One project per recipe, chosen by its README

Each recipe names the **one** SDK example project whose README is about that hardware (`project`,
`readme`) and the symbols that name the driver (`anchors`). The Kconfig values are not picked by hand:
`derive` loads that project (its `.config` on its own `board/Kconfig`) and the base project
`vision_board_blink_led` (what `new_app.sh` copies for every app), enables the anchors' menus and the
anchors in the base, follows every symbol that changes or appears, and keeps the values in which the
base would differ from the project:
- `kconfig` - the values to set (the rest follows from selects and defaults);
- `expect` - values the base's own `board/Kconfig` cannot reach (it defines the driver differently);
- `kconfig_defs` - a hash of the anchors' definitions in the project; `check` reports an app whose
  `board/Kconfig` defines them differently, with the project block to take.

`derive` also checks the project itself holds what the recipe states (FSP instances in its `ra_gen/`,
board ports, packages, pin functions in its `configuration.xml`). `check` against copies of
`vision_board_wifi` (`rw007`) and `vision_board_openmv` (`sdcard sci3-i2c pwm6 i2c1-soft`) gives
`RECIPE: READY` with **0** symbols changed.

## Recipes

| Recipe | Project (README) | Kconfig (derived) | FSP instance | Pins / peripheral | msh shows |
|---|---|---|---|---|---|
| `base` | `vision_board_blink_led` - blue LED blinks; "the base of your own work" | (the template) | `g_uart9` | P102 P106 PA07 (LED), P907 (KEY0), P208/P209 / SCI9 | - |
| `i2c1-soft` | `vision_board_camera` - camera picture on the LCD (camera control bus) | `BSP_USING_I2C BSP_USING_I2C1 RT_USING_I2C` | none (bit-banged) | PB03 SCL, P50E SDA | `i2c1` |
| `spi1` | `vision_board_wifi` - RW007 over SPI | `BSP_USING_SPI BSP_USING_SPI1 RT_USING_SPI` | `g_spi1` | P410 P411 P412 / RSPI1 | `spi1` |
| `rw007` | `vision_board_wifi` - `wifi scan`, `wifi join`, `ping` | 16 values (WLAN, SAL, netdev, lwIP, package, bus `spi1`, pins); expects SCI2 SPI off | `g_external_irq11` | P40D P40C P800 P504 / IRQ11 | `wlan0` `wlan1`; `wifi` `ifconfig` `ping`; `wlan` `tcpip` |
| `sci3-i2c` | `lcd/vision_board_rgb_4.3inch` - touch points, `gt911_register` | `BSP_USING_SCI BSP_USING_SCI3 BSP_USING_SCI3_I2C RT_USING_I2C` | `g_sci3` | P408 P409 / SCI3 | `sci3i` |
| `sdcard` | `usb/vision_board_tinyusb_msc` - SD card as a USB drive and file system | `BSP_USING_FS BSP_USING_SDCARD_FS BSP_USING_SDHI RT_USING_DFS RT_USING_SDIO` | `g_sdmmc1` | P810-P812, P500-P503 / SDHI1 | `sd0`; `ls` `mount` `df`; `mmcsd_detect` |
| `pwm6` | `lcd/vision_board_mipi_2.0inch` - `lcd_test` colours (backlight) | `BSP_USING_PWM BSP_USING_PWM6 RT_USING_PWM` | `g_timer6` | PA11 / GPT6 | `pwm6` |

The exact values are in `drivers/<name>.json`. Not prepared: UART2 (only `vision_board_openmv`
enables it and its README does not say what for), LCD (MIPI / RGB565), camera (CEU), USB (TinyUSB),
on-chip flash/FAL, Ethernet, ADC, DAC, CAN - mostly FSP configuration, or no project README about them.

## Study of the SDK projects (VISION-BOARD 1.3.0, 2026-10-31)

The 19 example projects of `projects/` (same set as the GitHub repo
RT-Thread-Studio/sdk-bsp-ra8d1-vision-board, tag 1.3.0) and their READMEs were compared: purpose
and hardware (README), `.config`, `packages/`, FSP modules and pins in `configuration.xml`, and
`board/Kconfig`. Findings:
- **One Kconfig option is not one driver.** The FSP side differs per project: the base
  `vision_board_blink_led` has only `ioport` + `uart`; the board-wide `pincfg` is almost the same in
  every project, but modules, instances and clocks (`spiclk` off in blink, PLL1P in wifi) are not.
- **`board/Kconfig` differs per project.** In blink's copy, `BSP_USING_RW007` selects SCI2 SPI,
  bus `scpi0` and P60x pins; wifi's selects SPI1 with the working pins. A `select` cannot be undone
  from `.config`: `check` names the block to take (`kconfig_defs`).
- RW007 also needs the board port `board/ports/wifi/drv_rw007.c` (SPI attach, INT/BUSY irq, reset)
  and the package source `packages/rw007-v2.1.0` - neither is in a blink-based app.
- Several projects enable the same driver with the same values (e.g. SDHI1 in msc, doom, nes, openmv;
  SCI3 I2C in every touch LCD project); the recipe takes the one whose README is about it.
- The factory OpenMV image (read by `msh_status.py`, 2026-10-31) shows `rw007` + `sdcard` on the
  board: devices `wspi w0 w1 wlan0 wlan1 sd0 sd`, threads `wlan tcpip wifi_xfer wifi_handle
  mmcsd_detect sd_mount`.

## Recipe file (`drivers/<name>.json`)

| Key | Meaning |
|---|---|
| `recipe`, `kind`, `board`, `level`, `status` | name; `hw-driver` (or `base`); board id; `kconfig`; `prepared` = derived from the SDK, not yet built or run in an app of ours; `tested` = applied to an app, built and run on the board (see below) |
| `summary` | one line |
| `requires` | other recipes, checked first (e.g. `rw007` needs `spi1`) |
| `project`, `readme`, `anchors` | the SDK project whose README is about this hardware, what that README says it shows, the symbols that name the driver |
| `kconfig`, `expect`, `kconfig_defs` | written by `derive --write` (see above) - do not edit by hand |
| `pins`, `peripherals` | what the driver takes; `check` fails when two recipes take the same one |
| `fsp`, `fsp_note` | FSP instances the driver binds to (searched in `ra_gen/*.h`) |
| `ports` | board port folders the app must contain, and where they come from |
| `packages` | package folders (`optional` = only a note) |
| `msh` | `devices`, `commands`, `threads` that `msh_status.py` must show on the board afterwards |
| `evidence` | other SDK projects (and board reads) that use the driver the same way |
