# FADE headless test — reference

## Typical timings (full modset)

| Phase | Duration |
|-------|----------|
| Mod load + Steam | 4–8 min |
| Mission init | 1–3 min |
| MissionTestSuite (server) | 15–30 s |
| MissionPlaythroughSuite | 10–20 min |
| **compile total** | ~6 min wall clock |
| **all total** | ~45–50 min wall clock |

`bootTimeoutSec` default 600; raised to 900 in local config when needed. Suite timeouts: `compileTimeoutSec` 900, `playthroughTimeoutSec` 1800.

## Boot detection (FadeHeadlessLib.ps1)

1. `Connected to Steam servers`
2. `Mission file: CTB_FAC_FADE` (folder name without `.Altis` suffix)
3. First of: `[FAC profile] FADE_serverInitReady`, `initServer total`, `[AmbientCivilians] v4 loading`

## Headless harness modes (FADE_HeadlessTest.sqf)

`headless_test.flg` contents: `boot` | `compile` | `testsuite` | `suite` | `playthrough` | `all`

`FADE_headlessTest__lightenWorld` sets civilians/opfor/drones off before suites — headless only.

## Result parsing

Runner waits for `[FAC Headless] ========== DONE ==========` then reads:

- `[FAC Headless] pass=`, `fail=`, `skip=`
- `[FAC TestSuite] ========== SERVER SUITE END: X passed, Y failed ==========`
- `[FAC Playthrough] ========== PLAYTHROUGH SUITE END: ...`

`Get-FadeHeadlessRptSummary` collects last 25 `[FAC TestSuite] FAIL` lines for console output.

## Server vs client coverage

| Check type | Headless | In-game `execAll` |
|------------|----------|-------------------|
| Server state, RPCs, compile | Yes | Yes |
| Client GUI, displayName | No | Yes |
| Playthrough teleports/cheats | Server path only | Full with player |

## SQF-VM offline lint

```powershell
powershell -ExecutionPolicy Bypass -File tools/sqfvm/Install-SqfVmRuntime.ps1   # once
powershell -ExecutionPolicy Bypass -File tools/sqfvm/Invoke-FadeSqfLint.ps1
```

Catches many syntax issues before paying mod-load cost. Not a substitute for dedicated-server preprocess quirks (`#`, `preprocessFileLineNumbers`).

## local_server requirements

`Face/local_server/server.cfg`:

```
persistent = 1;   // required for -autoInit
```

`StartServer.ps1` must include `-autoInit` and `-loadMissionToMemory` in server argv.

## Junction layout

```
C:\Arma3Server\mpmissions\CTB_FAC_FADE.Altis  →  <repo root>
```

Repo edits are live via `-filePatching` + junction; no copy step.

## Installing this skill elsewhere

Copy `.cursor/skills/fade-headless-test/` to another machine's project `.cursor/skills/`, or to `~/.cursor/skills/fade-headless-test/` for user-wide use. Adjust paths in `headless.local.json` per machine.

## Known RPT noise (ignore)

- Mod bone/animation warnings
- `ServerBootstrap*.sqf not found` during **compile checks** that use wrong path strings (runtime must use single `\`)
- String STR_* not found from optional DLC UI
