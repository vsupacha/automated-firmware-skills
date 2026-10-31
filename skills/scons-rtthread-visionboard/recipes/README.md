# HW driver recipes (Kconfig level) - Vision Board

A recipe names one on-chip or on-board driver of the RT-Thread Vision Board BSP and says, before any
firmware is written, what selecting it means for an app. Level: **Kconfig** (`.config` ->
`rtconfig.h`). A recipe never generates FSP code (`configuration.xml` -> `ra_gen/`): it states that as a precondition.
`recipe.sh check` reports what is missing; `recipe.sh apply` writes everything else (see below).

```bash
bash "$SKILL/scripts/recipe.sh" list
bash "$SKILL/scripts/recipe.sh" check <app> rw007 sdcard [--show]
bash "$SKILL/scripts/recipe.sh" apply <app> rw007 sdcard [--yes]   # without --yes: what it would write
bash "$SKILL/scripts/recipe.sh" derive <recipe> [--write]      # maintainer: re-take the values from the SDK
```

`check` loads the app's Kconfig tree with RT-Thread's own `kconfiglib` (as menuconfig does: selects,
depends, defaults), sets the recipe values and reports. Read-only. Gate: `RECIPE: READY` (exit 0) |
`RECIPE: ACTION n` (exit 10; one `ACTION:` line per missing precondition: `KCONFIG`, `FSP`, `PORT`,
`PACKAGE`) | `RECIPE: FAIL` (exit 1; unknown recipe or symbol, a pin or peripheral taken twice).
The apps from `new_app.sh` have no `rt-thread/examples`, which `rt-thread/Kconfig` sources, so the
Kconfig tree of RT-Thread comes from the pinned SDK (same RT-Thread 5.0.2); the package index comes
from RT-Thread Studio's env (`platform/env_released/env-new/packages`).

## apply

`recipe.sh apply <app> <recipe>...` does what `check`'s ACTION lines say, except `FSP` (nothing is
written while an FSP instance is missing): `board/Kconfig` blocks from the recipe's SDK project,
`ports` and `packages` from the SDK (+ `packages/SConscript`), `files` from the SDK or the skill,
`patches`, `inserts`, then the recipe values into `.config` (kconfiglib, as menuconfig) and
`rtconfig.h` (RT-Thread's `mk_rtconfig`), and `APP_RECIPES=...` in `rtt-app.env`. Without `--yes` it
prints one `WOULD <path> <what>` line per item and `ACTION: APPROVE` (exit 10); with `--yes` it copies
every file it replaces to `<app>/logs/recipe-backup-<time>/`, writes, runs `check` again (must be
`RECIPE: READY`) and prints `APPLY: DONE` plus what to look for on the board; `recipe.sh` then
re-syncs the RT-Thread Studio project (`scons --target=eclipse`). 2026-10-31: a new push-to-light app
with `i2c1-soft rw007 sci3-i2c sdcard-fat pwm6 at-cdc` (nine recipes with their requirements):
13 items written, `RECIPE: READY` with 0 symbols changed, Studio sync, build PASS (app.hex 1.2 MB as
hex, text 436 KB) - not flashed. Earlier board tests (below) used a prototype of the same steps.

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

## Software components (`sdcard-fat`)

A software component recipe (`kind: sw-component`) sits on a hardware recipe and adds two kinds of
precondition that `check` reports:
- `files` - a file that must equal the SDK project's copy (`ACTION: FILE`): `board/ports/mnt.c` from
  `usb/vision_board_tinyusb_msc`. The copy in `vision_board_blink_led` (base of every app) has
  `INIT_ENV_EXPORT(mount_init)` commented out (the card is never mounted) and polls a hard-coded card
  detect pin `p405`; the msc copy mounts the card at `/` at boot and uses `RA_SDHI_CD_PIN`.
- `source_checks` - facts in the app's sources (`ACTION: SOURCE`): elm-FAT built read-write
  (`FF_FS_READONLY 0`), `FF_USE_MKFS 1`, file timestamps from `time()` (`get_fattime`), msh file
  commands compiled, the mount exported at boot.
`test` names a serial test spec (`recipes/tests/sdcard_fat.json`): `df /`, then write, read back,
list and delete `/fwtest/a.txt` - only `/fwtest` on the card is touched. Cards up to 32 GB (FAT32);
exFAT would need `RT_DFS_ELM_USE_EXFAT`.

2026-10-31: applied to a push-to-light app with the openmv FSP (`sdcard` + `sdcard-fat`): `check`
READY with 0 symbols changed, build PASS (one warning in the SDK's own `mnt.c`, an intended
assignment in an `if`), app.hex 0x02000000..0x020299C0. On the board: flash 170432 bytes read back equal;
`msh_status.py` MSH: PASS - 25 commands (file commands added), threads `sd_mount mmcsd_detect`,
devices `sd0 sd`; `sdcard_fat.json` RESULT PASS 11/11 (`df /` 14.8 GB free, write, read back, list,
delete); a file written before `reboot` read back after it (then removed); push-to-light 17/17.
msh shows "Cannot find a RTC device!" on file writes: timestamps are not real time.

## USB CDC and the AT command layer (`usb-cdc`, `at-cdc`)

`usb-cdc` builds TinyUSB (the SDK's `libraries/components/tinyusb`, an `INSERT` into `SConstruct`,
port `board/tinyusb`) for the user USB-OTG port. `at-cdc` adds an AT command interface on it:
- port layer `board/ports/cdc_vcom.c` (skill file): TinyUSB CDC as the RT-Thread character device
  `cdc0` (TinyUSB has no rt_device; the AT server needs one);
- layer 3b `src/at/at_cmds.c` (skill file), a peer of the msh commands in `hal_entry.c` that calls the
  function layer only: `AT+INFO`, `AT+LED?`, `AT+LED=<n>,<0|1|2>` (off/on/toggle), `AT+BTN?`, plus the
  server's own `AT`, `ATE0/1`, `AT+RST`, `AT&L`; `templates/_common/src/SConscript` compiles `src/at/`;
- an `INSERT` of the `RtAtCmdTab` section into `script/fsp.ld` (the FSP linker script has none; the
  AT server finds its table between `__rtatcmdtab_start/_end`).
Recipe keys used here: `files` with `from_skill`, `inserts` (`ACTION: INSERT`), `patches`
(`ACTION: PATCH`), and a later recipe owns a value it overrides (`cdc_example` off).

On the board (2026-10-31, push-to-light app with the openmv FSP): `check` READY, build PASS,
`msh_status.py` shows `tusb`, `at_svr`, `cdc0`; the PC sees COM port VID 0xCAFE PID 0x4000;
`recipes/tests/at_cdc.json` on that port (`serial_test.py COMx ...`, spec has `"command_list": false`)
RESULT PASS 12/12; console push-to-light still 17/17. Found on the way:
- **`drv_gpio.c` re-applies the FSP pin setup.** `ra_pin_mode()` calls `R_IOPORT_Open()` on every
  `rt_pin_mode()`; with parameter checking off it re-writes all pins. TinyUSB set USB_CH_SEL (PA13)
  low (USB-FS), then the board layer's LED/KEY `rt_pin_mode()` put it back high (USB-HS path): the PC
  saw no device at all. The fix (open IOPORT once) is a `base` recipe patch: `new_app.sh` applies it to
  every new app and `check` reports it (`ACTION: PATCH`) for older apps.
- **End mark CR, not CRLF:** with CRLF the server echoes but never answers a terminal sending CR.
- `PKG_TINYUSB_DEVICE_PORT_SPEED` is 0x00 in the SDK project's `rtconfig.h` (older package index) and
  0x0200 here (same "Full Speed" choice); both enumerate.
- A charge-only cable on the user port looks the same from the board (pull-up on, VBUS seen) - the
  PC shows nothing; use a data cable.
- RT-Thread's `at_server.c` uses `strcasecmp` without `<strings.h>`: one warning in vendor code.

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
| `base` | `vision_board_blink_led` - blue LED blinks; "the base of your own work" | (the template); `PATCH` drv_gpio.c opens IOPORT once (new_app.sh applies it) | `g_uart9` | P102 P106 PA07 (LED), P907 (KEY0), P208/P209 / SCI9 | - |
| `i2c1-soft` | `vision_board_camera` - camera picture on the LCD (camera control bus) | `BSP_USING_I2C BSP_USING_I2C1 RT_USING_I2C` | none (bit-banged) | PB03 SCL, P50E SDA | `i2c1` |
| `spi1` | `vision_board_wifi` - RW007 over SPI | `BSP_USING_SPI BSP_USING_SPI1 RT_USING_SPI` | `g_spi1` | P410 P411 P412 / RSPI1 | `spi1` |
| `rw007` | `vision_board_wifi` - `wifi scan`, `wifi join`, `ping` | 16 values (WLAN, SAL, netdev, lwIP, package, bus `spi1`, pins); expects SCI2 SPI off | `g_external_irq11` | P40D P40C P800 P504 / IRQ11 | `wlan0` `wlan1`; `wifi` `ifconfig` `ping`; `wlan` `tcpip` |
| `sci3-i2c` | `lcd/vision_board_rgb_4.3inch` - touch points, `gt911_register` | `BSP_USING_SCI BSP_USING_SCI3 BSP_USING_SCI3_I2C RT_USING_I2C` | `g_sci3` | P408 P409 / SCI3 | `sci3i` |
| `sdcard` | `usb/vision_board_tinyusb_msc` - SD card as a USB drive and file system | `BSP_USING_FS BSP_USING_SDCARD_FS BSP_USING_SDHI RT_USING_DFS RT_USING_SDIO` | `g_sdmmc1` | P810-P812, P500-P503 / SDHI1 | `sd0`; `ls` `mount` `df`; `mmcsd_detect` |
| `sdcard-fat` (sw component, requires `sdcard`) | `usb/vision_board_tinyusb_msc` - SD card as file system | `RT_USING_DFS RT_USING_DFS_ELMFAT` (elm defaults = the project's: LFN 3, code page 437, 512-byte sectors, 2 drives, reentrant) | none | - | commands `ls cat echo mkdir rm df mkfs mount`, device `sd`, thread `sd_mount` |
| `usb-cdc` | `usb/vision_board_tinyusb_cdc` - the PC sees a serial port on the user USB port | 7 values (TinyUSB device, CDC, full speed, cdc_example) | none (TinyUSB drives the controller; the vector table needs the USBFS interrupts) | PA13 USB_CH_SEL / USBFS | thread `tusb` |
| `at-cdc` (sw component, requires `usb-cdc`) | none - RT-Thread's AT server (`components/net/at`) | `RT_USING_AT AT_USING_SERVER AT_SERVER_DEVICE=cdc0 AT_CMD_END_MARK_CR`, `cdc_example` off | none | - | device `cdc0`, thread `at_svr` |
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
| `files`, `source_checks` | single files that must equal the SDK project's copy; regex facts that must hold in the app's sources |
| `test`, `notes` | serial test spec for the board (`serial_test.py`); limits worth knowing |
| `packages` | package folders (`optional` = only a note) |
| `msh` | `devices`, `commands`, `threads` that `msh_status.py` must show on the board afterwards |
| `evidence` | other SDK projects (and board reads) that use the driver the same way |
