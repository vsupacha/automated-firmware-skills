# STM32CubeMX 6.18 headless (script) mode - what this skill relies on

Found by experiment on 2026-10-07 (STM32CubeMX 6.18.1, DB 6.0.181, STM32CubeN6 V1.4.1).

## Running it

| Fact | Consequence in the scripts |
| --- | --- |
| `STM32CubeMX.exe -q <script>` returns at once (the launch4j launcher detaches) and the script never runs | run CubeMX's own java: `jre/bin/java.exe -jar STM32CubeMX.exe -q <script>` from the install folder |
| after `exit` CubeMX prints `Bye bye` but the JVM keeps running | `cubemx_script` (env.sh) waits for `Bye bye`, then ends the process tree (`taskkill /T`) - only its own PID |
| every command echoes itself and answers `OK` or `KO` | `mx_check_log` fails the gate on any `KO` |
| a run takes 1-3 minutes (database load) | one CubeMX run per `new_app.sh` / `regen.sh` |
| `help` prints the command list; a wrong `set ...` prints the `set` sub-command usage | how the commands below were found |
| CubeMX's own log: `~/.stm32cubemx/STM32CubeMX.log` | first place to look after `REGEN: FAIL` |

## Commands used

| Command | Notes |
| --- | --- |
| `config load <file.ioc>` | Windows path |
| `set context <Context> <IP>` | multi-context MCUs (N6: FSBL / Appli / ExtMemLoader): assign the IP first - `set context FSBL USART1` |
| `set mode <IP> <Mode>` | e.g. `set mode USART1 Asynchronous` - **KO** until the IP has a context |
| `set pin <pin> <signal>` | e.g. `set pin PE5 USART1_TX` |
| `config saveas <file.ioc>` | writes the app's `.ioc` (no absolute paths inside) |
| `project name mx` / `project toolchain CMake` / `project path <dir>` / `project generate` | generates `<dir>/mx/`: top-level CMake (FSBL as an external project), `FSBL/` with `Src`, `Inc`, `Startup`, the AXISRAM2 linker script |
| `loadboard STM32N6570-DK allmodes` | loads the full board configuration (4 contexts, every on-board peripheral) - not used: ST's FSBL-only template is the starting point |

## Pitfalls

- **Forward-slash paths break generation:** with `project path C:/...` CubeMX 6.18.1 writes
  `syscalls.c`/`sysmem.c` to `<project>\C:\...` (FileNotFoundException in the output) but still
  lists them in `mx-generated.cmake` - the build then fails. Pass every path with backslashes
  (`cygpath -w`).
- Hand-editing `.ioc` text to add a peripheral does not work reliably (CubeMX drops the mode on
  load) - use `set context` + `set mode`.
- ST example `.ioc` files carry `ProjectManager.Example*` tags; they are removed before loading so
  the app is not treated as an ST example.
- The generated `mx-generated.cmake` files contain absolute paths (firmware repository, app
  folder): `mx/` is per PC and git-ignored; `<app>.ioc` is the shared source.

## STM32CubeIDE for VS Code (extensions core 1.5.0, build-cmake 1.47.0)

- Project discovery runs per **workspace folder**: `findProjects()` lists the CMake projects in the
  folder and `checkWorkspaceFolderConsistency()` requires one of them **at the folder root** - else
  "The workspace folder {0} contains multiple CMake projects, add project(s) as single workspace
  folder(s) instead." and nothing is discovered (seen 2026-10-07 when `apps/<app>` was opened).
- Fix: `<app>.code-workspace` (written by `new_app.sh`) with `mx`, `src`, `tests` as folders. Opening it
  discovered `mx/`, installed `stm32n6xx_dfp` 1.2.0, configured code indexing from
  `FSBL/build/compile_commands.json` (generated ExternalProject layout is supported).
- CMake Tools may write `cmake.sourceDirectory` with an absolute path into `<app>/.vscode/` when the
  app folder is opened - git-ignored (`*/.vscode/`).
