# HW driver recipes (Kconfig level) - Titan Board

A recipe names one on-chip or on-board driver of the RT-Thread Titan Board BSP and says, before any
firmware is written, what selecting it means for an app. Level: **Kconfig** (`.config` ->
`rtconfig.h`). A recipe never generates FSP code (`configuration.xml` -> `ra_gen/`): it states that as
a precondition. `recipe.sh check` reports what is missing; `recipe.sh apply` writes everything else.

```bash
bash "$SKILL/scripts/recipe.sh" list
bash "$SKILL/scripts/recipe.sh" check <app> sdcard rtc [--show]
bash "$SKILL/scripts/recipe.sh" apply <app> sdcard rtc [--yes]     # without --yes: what it would write
bash "$SKILL/scripts/recipe.sh" derive <recipe> [--write]          # maintainer: re-take the values from the SDK
```

The engine (`scripts/recipe.py`) is the Vision Board skill's: `check` loads the app's Kconfig tree with
RT-Thread's own `kconfiglib` (selects, depends, defaults) and reports `RECIPE: READY` (exit 0) |
`RECIPE: ACTION n` (exit 10: `KCONFIG`, `FSP`, `PORT`, `PACKAGE`, `FILE`, `INSERT`, `PATCH`, `SOURCE`) |
`RECIPE: FAIL` (exit 1: unknown recipe or symbol, a pin or peripheral taken twice). `apply` writes what
the ACTION lines say except `FSP`, backs up what it replaces (`<app>/logs/recipe-backup-<time>/`),
re-checks (`RECIPE: READY` -> `APPLY: DONE`) and re-syncs the RT-Thread Studio project. The app's
RT-Thread Kconfig tree comes from the pinned SDK (RT-Thread 5.1.0; apps have no `rt-thread/examples`);
the package index from RT-Thread Studio's env.

## One project per recipe

Each recipe names the SDK example project (`project/Titan_*`, SDK Titan-Board 1.0.2) whose README is
about that hardware, and the symbols that name the driver (`anchors`); `derive` takes every related
Kconfig value from that project against the base `Titan_template` (what `new_app.sh` copies). Some
project Kconfig files use preprocessor variables (`RTT_DIR := rt-thread`); derive points them at the
SDK. The base `Titan_template` already generates nearly every FSP instance, so most recipes need no
FSP step.

| Recipe | Project (README) | Kconfig (derived) | FSP instance | msh shows |
|---|---|---|---|---|
| `adc0` | `Titan_driver_adc` - ADC0 channels | `BSP_USING_ADC BSP_USING_ADC0 RT_USING_ADC` | `g_adc0` (in base) | `adc0`, command `adc` |
| `canfd` | `Titan_driver_can` - CANFD0/1 | `BSP_USING_CANFD BSP_USING_CAN0 BSP_USING_CAN1 RT_USING_CAN` | `g_canfd0/1` (in base) | `canfd0`, `canfd1` |
| `eth` | `Titan_driver_eth` - Ethernet + lwIP | `BSP_USING_ETH` + SAL/netdev/lwIP (IP settings left to you) | `g_ether0` (in base) | `ifconfig`, `ping`; thread `tcpip` |
| `gpt-pwm12` | `Titan_driver_gpt` - hwtimer + PWM | `BSP_USING_TIM1 BSP_USING_PWM12` + hwtimer/PWM | `g_timer1`, `g_timer12` (in base) | `timer1`, `pwm12` |
| `hyperram` | `Titan_driver_hyperram` - OSPI HyperRAM | `BSP_USING_OSPI_RAM` | `g_ospi1` (in base) | - |
| `i2c2-ist8310` | `Titan_driver_iic_ist8310` - I2C2 + IST8310 | `BSP_USING_HW_I2C BSP_USING_HW_I2C2 RT_USING_I2C` | (in base) | `i2c2` |
| `ospi-flash-fs` (sw) | `Titan_component_flash_fs` - OSPI flash + LittleFS | 10 values (FAL, MTD NOR, DFS, LittleFS, auto mount) | `g_ospi_b` (in base) | `ls` `df` `mkdir` `echo` `cat` |
| `pwm7-buzzer` | `Titan_basic_buzzer` - buzzer | `BSP_USING_PWM BSP_USING_PWM7 RT_USING_PWM` | (in base) | `pwm7`, command `pwm` |
| `rs485` | `Titan_driver_rs485` - RS485 half duplex | `BSP_USING_RS485` | `g_uart0`, `g_uart5` (in base) | `uart0`, `uart5` |
| `rtc` | `Titan_driver_rtc` - on-chip RTC | `BSP_USING_ONCHIP_RTC RT_USING_RTC RT_USING_ALARM` | `g_rtc` (in base) | `rtc`, command `date` |
| `sdcard` | `Titan_driver_sdcard` - SD card FAT, auto mount | `BSP_USING_SDCARD_FATFS BSP_USING_FS_AUTO_MOUNT` + SDHI/DFS | `g_sdmmc0` (in base) | `ls` `df` `mkdir` `echo` `cat` |
| `spi0-bmi088` | `Titan_driver_spi_bmi088` - SPI0 + BMI088 | `BSP_USING_SPI BSP_USING_SPI0 RT_USING_SPI` | `g_spi0` (in base) | `spi0` |
| `usb-pcdc` | `Titan_driver_usb_pcdc` - FSP USB PCDC | `BSP_USING_RA8P1_USB BSP_USING_USB_PCDC` | **`g_basic0` not in base** (FSP configurator) | - |
| `wdt` | `Titan_driver_wdt` - watchdog | `BSP_USING_WDT RT_USING_WDT` | **`g_wdt` not in base** (FSP configurator) | `wdt` |
| `wifi` | `Titan_driver_wifi` - CYW43438 on SDHI1 | 21 values (SDHI1, WHD package, WLAN, lwIP, FAL) + packages wifi-host-driver, littlefs | `g_sdmmc1` (in base) | `wifi`, `ifconfig` |

`base` lists the template's pins (LEDs P013/P012/P613, KEY P110, console P500/P501 on SCI8) for the
clash check. Not prepared: displays (MIPI / RGB LCD, LVGL), cameras (CEU, MIPI CSI), USB host HID,
NPU, dual core / RPMsg - mostly display and camera FSP stacks, or multi-project setups.

Notes: `wifi` needs the CYW43438 firmware and CLM blobs in the OSPI flash FAL partitions `whd_firmware`
/ `whd_clm` before it can work; `eth` drops the SDK example's static IP for its own lab network;
`i2c2-ist8310` and `spi0-bmi088` mark the sensor packages optional (the bus works without them).

## Results (2026-10-31, portable PC)

- `check` on a new push-to-light app: 11 recipes `READY`; `ospi-flash-fs` and `wifi` only need their
  packages (apply copies them); `usb-pcdc` and `wdt` need an FSP instance the base lacks.
- `apply` + `build.sh`: `adc0 canfd gpt-pwm12 rtc spi0-bmi088 i2c2-ist8310 pwm7-buzzer rs485 hyperram
  sdcard` together - PASS (warnings only in the SDK's HAL drivers, e.g. `drv_adc.c` calls `R_ADC_Close`
  without a declaration); `ospi-flash-fs` + `wifi` - PASS; `eth` - PASS. Nothing run on the board yet:
  status `prepared` for every driver recipe.
- Two recipes can share a package (littlefs): apply copies it once.

## Recipe file (`drivers/<name>.json`)

Same format as the Vision Board skill: `recipe`, `kind`, `board`, `level`, `status`, `summary`,
`requires`, `project`, `readme`, `anchors`, `kconfig` / `expect` / `kconfig_defs` (written by
`derive --write`), `pins`, `peripherals`, `fsp`, `ports`, `packages` (`optional`), `files`
(`from` / `from_skill`), `inserts`, `patches`, `source_checks`, `msh`, `test`, `notes`, `evidence`.
