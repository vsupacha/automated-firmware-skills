# Security

## Reporting a problem

Please report security problems privately through GitHub: the repository's **Security** tab >
**Report a vulnerability**. Do not open a public issue for them. You should get an answer within
two weeks; fixes are listed in [CHANGELOG.md](CHANGELOG.md).

Please report, for example:

- a script that can write to a board without the developer's approval or without an identity check;
- a path that changes protected settings (option bytes, read-out protection, life cycle, eFuses,
  secure boot, OTP) or upgrades probe firmware;
- personal or machine data (probe serials, COM ports, user paths, Wi-Fi names) that ends up in git,
  in a report or in a published file;
- a skill instruction or script that runs commands from untrusted input (a board's console output,
  a downloaded file, a web page).

## What the scripts do on your PC and your board

- They run your installed vendor tools (STM32CubeMX / STM32CubeProgrammer, ModusToolbox, PlatformIO,
  MCUXpresso SDK / LinkServer, OpenOCD, GDB) and Python with `pyserial`. Nothing is installed for you:
  a missing tool stops the script with `ACTION: SETUP`.
- Network access only happens inside those tools (package or SDK downloads) and when a template app
  is cloned from the vendor's GitHub (ModusToolbox).
- Writing to a board (`flash.sh`) needs `--yes`, which the agent passes only after you said yes, and
  the script checks the probe and device identity first. `discover.sh` and `debug.sh status` are
  read-only. A per-board `FLASH_POLICY=auto` in your bench file is the only way to skip the question,
  and it is your setting.
- The skills never change life cycle, read-out protection, option bytes, OTP, eFuses or secure boot,
  never upgrade probe firmware and never run installers with admin rights.
- Per-PC data (probe serials, COM ports) stays in `.bench/` of your apps workspace, git-ignored.

## Hardware risk

These skills are provided as they are (see [LICENSE](LICENSE)). Flashing firmware can leave a board
unusable until it is recovered with the vendor's tools. Check the board, the app and the image hash
before you approve a flash.
