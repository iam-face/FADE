---
name: fade-headless-test
description: >-
  Run FADE dedicated-server headless E2E tests (MissionTestSuite + MissionPlaythroughSuite),
  triage RPT failures, and fix in a loop. Use when the user asks for headless testing,
  dedicated-server validation, Run-FadeHeadlessTest, MissionTestSuite automation, or
  debugging FADE without launching the Arma 3 client.
---

# FADE headless dedicated-server testing

Automated E2E validation: PowerShell runner boots `arma3server_x64`, mission auto-runs suites via `headless_test.flg`, runner parses RPT, exits 0/1.

**Normal in-game suites are unchanged.** Headless is an additive path; dev scroll-wheel `[] call FAC_missionTestSuite_execAll` still works.

## Prerequisites

- **Steam running** before server start (mod auth).
- `C:\Arma3Server\arma3server_x64.exe` installed.
- `Face\local_server\` with `StartServer.ps1`, `server.cfg`, `client_modline.txt`.
- `server.cfg`: `persistent = 1` (required for `-autoInit`).
- `StartServer.ps1`: passes `-autoInit` and `-loadMissionToMemory`.
- Config: copy `../tools/headless/headless.local.json.example` → `headless.local.json` (beside the example; outside mission git).
- Mission junction: `C:\Arma3Server\mpmissions\CTB_FAC_FADE.Altis` → mission folder (runner creates if missing).
- Helpers live in sibling `mpmissions/tools/` (not inside the mission PBO folder).

Env overrides: `FADE_A3_SERVER_ROOT`, `FADE_A3_CLIENT_ROOT`, `FADE_LOCAL_SERVER_DIR`.

## Quick commands

From mission folder:

```powershell
# Fast offline syntax lint (~seconds) — run before headless when editing .sqf
powershell -ExecutionPolicy Bypass -File ..\tools\sqfvm\Invoke-FadeSqfLint.ps1

# Headless (slow: ~5 min mod load + suite)
powershell -ExecutionPolicy Bypass -File ..\tools\headless\Run-FadeHeadlessTest.ps1 -Mode compile -SkipModSync
powershell -ExecutionPolicy Bypass -File ..\tools\headless\Run-FadeHeadlessTest.ps1 -Mode playthrough -SkipModSync
powershell -ExecutionPolicy Bypass -File ..\tools\headless\Run-FadeHeadlessTest.ps1 -Mode all -SkipModSync
powershell -ExecutionPolicy Bypass -File ..\tools\headless\Run-FadeHeadlessTest.ps1 -Mode boot -SkipModSync
```

| Mode | What runs | Typical time after boot |
|------|-----------|-------------------------|
| `boot` | Init smoke only | ~30 s |
| `compile` | MissionTestSuite (server) | ~20 s |
| `playthrough` | MissionPlaythroughSuite | ~10–20 min |
| `all` | compile then playthrough | ~15–25 min |

Use `-SkipModSync` when `client_modline.txt` is current. Use `-KeepServer` to leave server running for manual RPT inspection.

## Architecture (do not break)

| Piece | Role |
|-------|------|
| `../tools/headless/Run-FadeHeadlessTest.ps1` | Orchestrator |
| `../tools/headless/FadeHeadlessLib.ps1` | Boot wait, RPT parse, flag cleanup |
| `rsc/FADE_HeadlessTest.sqf` | Server-side harness (modes, lighten world) |
| `initServer.sqf` | Spawns harness only if `headless_test.flg` exists |
| `rsc/MissionTestSuite.sqf` | Shared server+client checks (headless calls server only) |
| `rsc/MissionPlaythroughSuite.sqf` | Live mission init smoke (shared) |

Runner writes `headless_test.flg`, clears it in `finally`. **Never leave the flag in mission root for normal play.**

## RPT markers (success / failure)

**Paths:** `C:\Arma3Server\profiles_local\arma3server_x64_*.rpt`  
**Runner log:** `../tools/headless/last-run.log`

| Marker | Meaning |
|--------|---------|
| `Connected to Steam servers` | Mod load done |
| `Mission file: CTB_FAC_FADE` | Mission started |
| `[FAC profile] FADE_serverInitReady` | Server init complete |
| `[FAC Headless] ========== START` | Harness running |
| `[FAC TestSuite] SERVER SUITE END: N passed, M failed` | Compile done |
| `[FAC Headless] ========== DONE ==========` | Runner can stop server |
| `PASS: headless compile` | Exit 0 |

Filter RPT: `[FAC Headless]`, `[FAC TestSuite]`, `[FAC Playthrough]`.

Exit `4294967295` = process killed externally (cancel), not a test failure.

## Fix loop workflow

A bug that is not already a failing headless run: follow [fade-debug](../fade-debug/SKILL.md) (reproduce, localize, fix the cause, add a suite guard). Then use this loop to prove it.

Copy and track:

```
- [ ] 1. SQF-VM lint (if .sqf changed)
- [ ] 2. Run headless (-Mode compile first)
- [ ] 3. Grep RPT for FAIL / Error in expression
- [ ] 4. Fix root cause (minimal diff)
- [ ] 5. Re-run until PASS or user stops
```

1. **Lint first** for compile/syntax issues (`../tools/sqfvm/Invoke-FadeSqfLint.ps1`).
2. **Run compile** before `all` — catches 500+ checks in ~6 min total.
3. **Read FAIL lines** from runner output or RPT tail; fix one cluster at a time.
4. **Re-run** same mode to verify.
5. After compile green, run `-Mode playthrough` or `-Mode all`.

Run in background for long modes; poll terminal or RPT for `DONE`.

## Cancel a run

```powershell
Get-Process -Name 'arma3server_x64' -ErrorAction SilentlyContinue | Stop-Process -Force
# Also stop the Run-FadeHeadlessTest.ps1 PowerShell parent if needed
Remove-Item -Force headless_test.flg -ErrorAction SilentlyContinue
```

## SQF / headless pitfalls

When editing harness or suite code:

- **No `serverCommand "#shutdown"`** in preprocessed files — breaks `preprocessFileLineNumbers` on dedicated server.
- **No `openFile` / file I/O** in MissionTestSuite on dedicated — use `diag_log` only (`FAC_facDebugAgentLog` stub).
- **Headless loads MissionTestSuite with `preprocessFile`** (not line numbers) — avoid literal `#` lines in that load path.
- **Module paths: single backslash** — `"rsc\server\ServerBootstrapFactions.sqf"`. Double `\\` in runtime strings = file not found (bootstrap/RPC silent failure).
- **Exempt-path lists** must match `FADE_missionModuleList` path style (single `\`).
- **Do not refactor suites to be headless-only** — keep `FAC_missionTestSuite_runServer` / `FAC_playthroughSuite_runServer` shared; headless passes `objNull` for notify player.

## Common failure clusters

| Symptom | Likely cause |
|---------|----------------|
| Steam / mod load timeout | Steam not running; increase `bootTimeoutSec` in json |
| Mission never starts | Missing `persistent = 1` or `-autoInit` |
| Empty `FADE_friendlyUnits`, RPC FAILs | Bootstrap modules not loaded (bad paths) |
| `MissionTestSuite failed to load` | Preprocess/compile error in suite — grep `Error in expression` |
| `legacy missionRun reads` | Runner uses custom params; should be in `FAC_missionTestSuite__getContextExemptPaths` with matching path strings |
| Boot OK but instant FAIL | Check RPT between `START` and `SERVER SUITE END` |

## Agent behavior

- **Execute** the runner; do not simulate results.
- Prefer **`-Mode compile -SkipModSync`** for iteration unless playthrough-specific.
- After fixes to `.sqf`, update `agent-docs/SCRIPT_INDEX.md` if project docs exist.
- Do not commit `headless.local.json`, `headless_test.flg`, or RPT files.
- For long runs, offer to check progress after ~6 min (boot) or ~10 min (suite).

## Additional reference

- Detailed troubleshooting and timings: [reference.md](reference.md)
- Runner header comments: `../tools/headless/Run-FadeHeadlessTest.ps1`
- README section: headless dedicated-server tests
