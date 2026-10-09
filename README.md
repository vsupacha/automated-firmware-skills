# automated-firmware-skills

Agent skills that take an MCU firmware project from "tools installed?" to "tested on the board",
with a gate at every stage. Written for Claude Code; the scripts are plain bash/Python, so a
developer (or another agent) can run every stage by hand.

Other languages: [ภาษาไทย](README_TH.md) · [日本語](README_JA.md)

## Concepts

- **Skill = toolchain + framework + board.** Each skill (`skills/<toolchain>-<framework>-<board>/`,
  e.g. `cubemx-hal-stm32l475iot`, `pio-arduino-unor4wifi`) drives one dev tool for one board family:
  a `SKILL.md` the agent follows, plain scripts, references and app templates.
- **Gated stages.** Every skill has the same stages and script names - check tools, create the
  project, open it in the IDE, build, connect, flash, test, clean. Each script ends with a gate line
  (`BUILD: PASS`, `IDENTITY: PASS`, `RESULT: PASS` ...); the next stage starts only after a PASS.
- **The developer decides.** Steps only a person can do - installing tools, plugging a board,
  pressing a button, **approving a flash** - stop the script with exit code 10 and an
  `ACTION: <TYPE> ...` line; the agent relays it and waits. Nothing is flashed without your yes.
- **Two paths, switch any time.** After the project is created you can code, build, flash and debug
  it yourself in the IDE (**IDE path**), or let the agent run the gated stages (**script path**).
  Both work on the same app folder and build outputs.
- **Bring-up demos.** Every skill has the same three templates, proven with the same test specs on
  every board: **hello-world** (UART console), **blink** (LED), **push-to-light** (button lights
  an LED). A board without a button gets the first two.
- **Board type vs bench.** `boards/<id>/` describes a board type (pins, expected identity, pinned
  tools); the probe serial and COM port of *your* board on *your* PC go into `apps/.bench/`, never
  into git.
- **Honest results.** built ≠ flashed ≠ tested ≠ observed by a person - every board keeps a dated
  verification log.

## How to use

1. **Install** the plugin in Claude Code (works from any project folder; apps go to `./apps` there):

   ```
   /plugin marketplace add vsupacha/automated-firmware-skills
   /plugin install automated-firmware-skills@automated-firmware-skills
   ```

   Or work inside a clone of this repo (apps go to its `apps/`): `claude --plugin-dir .`
2. **Pick your board** in [boards/README.md](boards/README.md); its README lists the tools to
   install and the commands.
3. **Ask** in your own words: "how do I use this?" / "ขอวิธีใช้หน่อย" (the skill shows its command
   menu), "check my tools for the Vision Board", "create a blink app and build it", "flash it and
   run the test".

Without an agent, run the same scripts in **Git Bash** from the repo root, e.g. for the B-L475E-IOT01A:

```bash
S=skills/cubemx-hal-stm32l475iot/scripts
bash $S/check_tools.sh b-l475e-iot01a                 # 1 setup      -> missing/bad=0
bash $S/new_app.sh b-l475e-iot01a my-blink "" blink   # 2 create     -> opens it in the IDE
bash $S/build.sh apps/my-blink                        # 3 build      -> BUILD: PASS
bash $S/discover.sh b-l475e-iot01a                    # 4 connect    -> IDENTITY: PASS
bash $S/flash.sh apps/my-blink --yes                  # 5 flash      -> FLASH: PASS (only after you decided)
python $S/serial_test.py auto apps/my-blink/tests/blink.json apps/my-blink/logs/test.log --board b-l475e-iot01a
```

Exit codes: 0 pass, 1 fail, 2 warnings, **10 = do what the `ACTION:` line says, then re-run**.
Common options and overrides: [docs/workflow.md](docs/workflow.md#common-options).

## Status

Milestone **M1 bring-up** is active: 10 skills, board stages verified on 8 boards. M2 board support
(layer checks) is implemented but gated; M3-M5 are planned. Plan and per-skill state:
[docs/milestones.md](docs/milestones.md).

| Skill | Dev tool | MCU | Board |
| --- | --- | --- | --- |
| [modus-pdl-edgitalk](skills/modus-pdl-edgitalk/SKILL.md) | ModusToolbox 3.9 | Infineon PSOC Edge E84 | [Edgi-Talk](boards/edgi-talk/README.md) |
| [cubemx2-hal2-stm32c562nucleo](skills/cubemx2-hal2-stm32c562nucleo/SKILL.md) | STM32CubeMX2 1.1.1 + CMake | ST STM32C5 | [NUCLEO-C562RE](boards/nucleo-c562re/README.md) |
| [cubemx-hal-stm32l475iot](skills/cubemx-hal-stm32l475iot/SKILL.md) | STM32CubeMX 6.18 + STM32CubeL4 + CMake | ST STM32L4 | [B-L475E-IOT01A](boards/b-l475e-iot01a/README.md) |
| [cubemx-hal-stm32n6570dk](skills/cubemx-hal-stm32n6570dk/SKILL.md) | STM32CubeMX 6.18 + STM32CubeN6 + CMake | ST STM32N6 | [STM32N6570-DK](boards/stm32n6570-dk/README.md) |
| [cubemx-hal-stm32f407disco](skills/cubemx-hal-stm32f407disco/SKILL.md) | STM32CubeMX 6.18 + STM32CubeF4 + CMake | ST STM32F4 | [STM32F407G-DISC1](boards/stm32f407g-disc1/README.md) |
| [pio-arduino-rpipico2w](skills/pio-arduino-rpipico2w/SKILL.md) | PlatformIO + arduino-pico | Raspberry Pi RP2350 | [Pico 2 W](boards/rpi-pico-2w/README.md) |
| [pio-espidf-esp32s3box](skills/pio-espidf-esp32s3box/SKILL.md) | PlatformIO + ESP-IDF 5.5 | Espressif ESP32-S3 | [ESP32-S3-BOX](boards/esp32-s3-box/README.md) |
| [pio-arduino-esp32s3box](skills/pio-arduino-esp32s3box/SKILL.md) | PlatformIO + arduino-esp32 | Espressif ESP32-S3 | [ESP32-S3-BOX](boards/esp32-s3-box/README.md) |
| [pio-arduino-unor4wifi](skills/pio-arduino-unor4wifi/SKILL.md) | PlatformIO + Arduino UNO R4 core | Renesas RA4M1 | [UNO R4 WiFi](boards/uno-r4-wifi/README.md) |
| [scons-rtthread-visionboard](skills/scons-rtthread-visionboard/SKILL.md) | RT-Thread 5.0.2 + scons (RT-Thread Studio SDK) | Renesas RA8D1 | [Vision Board](boards/vision-board/README.md) |

## IDEs

Every app a skill creates opens in the toolchain vendor's IDE (stage 2d, `open_ide.sh`), on the same
project and build folders as the scripts. Details: [docs/workflow.md](docs/workflow.md#ide-handoff-stage-2d).

| IDE | Extension | Skills |
| --- | --- | --- |
| VS Code | Infineon ModusToolbox for VS Code (`infineonag.modustoolbox-for-vscode`) | modus-pdl-edgitalk |
| VS Code | STM32CubeIDE for Visual Studio Code (`stmicroelectronics.stm32-vscode-extension`) | cubemx2-hal2-stm32c562nucleo, cubemx-hal-stm32l475iot, cubemx-hal-stm32n6570dk, cubemx-hal-stm32f407disco |
| VS Code | PlatformIO IDE (`platformio.platformio-ide`) | pio-arduino-rpipico2w, pio-espidf-esp32s3box, pio-arduino-esp32s3box, pio-arduino-unor4wifi |
| RT-Thread Studio | - (standalone Eclipse-based IDE) | scons-rtthread-visionboard |

## Documentation

| Document | What it covers |
| --- | --- |
| [boards/README.md](boards/README.md) | supported boards, their on-board I/O and which bring-up demos are verified; each board's README: tools to install, commands, hardware, verification log |
| [docs/milestones.md](docs/milestones.md) | the M1-M5 plan and the current status |
| [docs/workflow.md](docs/workflow.md) | the contract every skill follows: stages, gates, exit codes, ACTIONs, IDE handoff, common options |
| [docs/board-api.md](docs/board-api.md) | the `board.h` API and the layering rules (board → func → app) |
| [docs/walkthrough-edgi-talk-ide.md](docs/walkthrough-edgi-talk-ide.md) | a recorded session on the IDE path, with real prompts and outputs |
| [docs/related-work.md](docs/related-work.md) | related public work and what each milestone takes from it |
| [apps/README.md](apps/README.md) | the apps workspace |

## Layout

```
automated-firmware-skills/
├── .claude-plugin/          plugin + marketplace manifests (install with /plugin)
├── milestones.env           release scope: active milestones (M1)
├── skills/<toolchain>-<framework>-<board>/   SKILL.md, scripts/, reference/, templates/
├── boards/<id>/             board README (tools, commands, hardware) + one profile per skill
├── boards/index.json        board ids, aliases, MCU and evidence level per profile (for agents)
├── lib/                     shared: common.sh, fwtest.py (test engine), func/ (C logic layer), M2 checks
├── docs/                    milestones, workflow contract, board API, walkthrough
├── tools/validate_skills.py repo validator: run it before every commit
└── apps/<app>/              projects generated by the skills (git-ignored except README)
```

## Contributing

Follow [docs/workflow.md](docs/workflow.md) and [docs/board-api.md](docs/board-api.md); run
`python tools/validate_skills.py` before every commit (`VALIDATE: PASS`). Never commit probe serials,
COM ports, IP addresses, user paths, build outputs or flash dumps (`.gitignore` covers the usual
places). Keep scripts and `.env` files LF. Report verification honestly: built ≠ flashed ≠ tested.
New board: copy [boards/_template](boards/_template/README.md); your own board in your own project:
put its profile in `<project>/boards/<id>/<skill>/` - the skills look there first.

## License

MIT - see [LICENSE](LICENSE). Vendor files inside `apps/` keep their own licenses.
