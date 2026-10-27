# Unity 2.6.1 (pinned copy)

[Unity](https://github.com/ThrowTheSwitch/Unity) by Mike Karlesky, Mark VanderVoord and Greg
Williams, MIT licence ([LICENSE.txt](LICENSE.txt)). Only `src/` of the release is copied here, so
the on-target unit tests of the C skills build offline with a fixed version. The PlatformIO
skills get the same version from the registry (`throwtheswitch/Unity` 2.6.1).

| File | sha256 |
| --- | --- |
| unity.c | `b90e735a54cf3b3765ab6caa955d11a1488ee73d9c6152cdc98576c2d17cb871` |
| unity.h | `9db174d3c2c6424fd35c0980c5941d124c5ebb0f48e8172f997a2aa9554b64ea` |
| unity_internals.h | `fcd8b3f6b412ac0ab599547eb8a30b6d7f3f0af77aab31f7a1822a2a8fc9a2b2` |

Copied 2026-10-27 from the PlatformIO package `throwtheswitch/Unity` 2.6.1 (`library.json`
version 2.6.1, `UNITY_VERSION` 2.6.1). Do not edit these files; configure Unity with
`-DUNITY_INCLUDE_CONFIG_H` and a `unity_config.h` in the test sources instead. To update: replace
the three files from a newer release, update this table and re-run the unit tests on a board.
