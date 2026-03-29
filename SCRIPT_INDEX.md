# Scripts reference - FAC Heli Ops (Sefrou-Ramal)

This document is the **single source** for mission scripting documentation: **inventory and layout** (what runs where, how pieces connect, multiplayer / dedicated-server alignment), the **`remoteExec` / `publicVariable` surface**, and the **formal per-file verification matrix** (server authority, guards, networking). For gameplay features and Eden object names, see **AGENTS.md**.

**Out of scope:** `mission.sqm` object/module init fields, third-party mod scripts, and CBA/ACE internals are not mission `.sqf`.

---

## Repository layout

| Location | Purpose |
|----------|---------|
| **Mission root** | Entry scripts (`initServer.sqf`, `initPlayerLocal.sqf`, `init.sqf`), `description.ext` (dialogs, sounds, includes), `mission.sqm`, `cba_settings.sqf` (CBA/ACE mission overrides). |
| **`rsc/`** | All compiled or executed SQF: GUIs, dynamic missions, ambient systems, debug stubs, BIS CP workarounds. |
| **`rsc/BaseControls.hpp`** | Included by `description.ext`; shared UI control classes (not executable SQF). |
| **`rsc/CfgFunctionsMission.hpp`** | `CfgFunctions` preInit/postInit hooks → `fn_bisCpPreInit.sqf` / `fn_bisCpPostInit.sqf`. |
| **`Img/`**, **`Sounds/`** | Assets referenced by config and scripts (not listed as scripts below). |

**Execution order (typical MP):**

1. `description.ext` loads includes (`CfgFunctionsMission.hpp`, `BaseControls.hpp`).
2. `init.sqf` - runs on **all machines**; calls `fn_bisCpPreInit` (stubs for missing BIS campaign functions).
3. `CfgFunctions` **preInit** / **postInit** - same stub maintenance (`fn_bisCpPreInit`, `fn_bisCpPostInit`).
4. **`initServer.sqf`** - server only (`if (!isServer) exitWith {}`); config scan, `publicVariable` sync, long-running server loops, `remoteExec`-callable handlers.
5. **`initPlayerLocal.sqf`** - each **client** with a player (not dedicated server); GUIs, actions, hints, jukebox client side (`FAC_surrenderChallenge_fnc_activate` present but gated off).

---

## Dedicated server audit (summary)

**Verdict:** The framework is **consistent with dedicated-server MP**: world state and AI run on the server; UI, cursor, and local audio run on clients; cross-boundary work uses `remoteExec` with target `2` (server), `_player` (one client), or `0` (all clients / broadcast) as documented in `initServer.sqf` and `initPlayerLocal.sqf`.

**Patterns verified:**

- **Server-only** mission logic uses `if (!isServer) exitWith {}` (`Missions.sqf`, `TroopTransport.sqf`, `AOMission.sqf`, `AmbientCivilians.sqf`, `EnemyAAA.sqf`, `EnemyCheckpoints.sqf`, `PadVehicleService.sqf`, `SurrenderChallenge.sqf`).
- **Client-only** effects use `hasInterface` where needed (`JukeboxGui.sqf` playback, `LockerRoomAmbient.sqf`, `CqbLoudspeaker.sqf`) so headless clients do not run UI/audio paths incorrectly.
- **Server functions invoked from clients** are **`publicVariable`'d** after definition in `initServer.sqf` (e.g. `FADE_startMission`, `FADE_spawnHeli`, `FADE_serviceVehicle`, `FAC_surrenderChallenge_start`, `FAC_jukebox_serverPlay`).
- **JIP:** Mission data clients need (`FADE_heliClasses`, board object refs, slot state, etc.) is **`publicVariable`'d** from the server; scenario apply also syncs via `remoteExec` + `publicVariable` where needed.
- **Client handler functions** targeted by `remoteExec` (`FADE_showMissionHint`, `FADE_receiveVehiclesAtBase`, `FADE_receiveCopilotState`, `FAC_jukebox_clientPlay`) are **defined in `initPlayerLocal` / GUI compiles** so each client has them before use; jukebox **JIP** replays active sources from **`FAC_jukebox_activeSources`** (spawn in `initPlayerLocal` after `JukeboxGui` compile).

**Residual risks (operational, not code bugs):**

- **`remoteExec` to a function name** requires that function to exist on the target machine when the call runs. This mission defines those functions during client init; avoid moving GUI init after first server→client `remoteExec`.
- **Mods** and **Eden object/module inits** are outside this index; RPT noise from `bis_fnc_cp_*` is addressed via stubs (see **AGENTS.md** Known RPT Warnings).

---

## Network surface (quick reference)

**From clients to server (`remoteExec [..., 2]`):**  
`FADE_applyScenarioSettings`, `FADE_sendScenarioConfigToClient` (also server-called), vehicle spawn/despawn/service/list, time/weather, copilot, `FADE_startMission`, `FADE_abortMission`, `FAC_surrenderChallenge_start`, `FAC_jukebox_serverPlay`, CQB drill start/end.

**From server to clients:**  
`FADE_showMissionHint`, `FADE_syncScenarioConfig`, `systemChat`, `playSound`, `say3D`, `FAC_jukebox_clientPlay`, `FAC_cqbLoudspeaker_clientPlay`, `FADE_receiveVehiclesAtBase`, `FADE_receiveCopilotState`, and mission-specific feedback - see `initServer.sqf`, `Missions.sqf`, `TroopTransport.sqf`, `AmbientCivilians.sqf`.

**`publicVariable`:**  
See the block in `initServer.sqf` (scenario helpers, mission slot globals, board lists, `FAC_surrenderChallenge_start`, `FAC_jukebox_serverPlay`, etc.).

---

## Script inventory

Columns: **Role** - primary purpose. **Context** - S = server only, C = client only (incl. UI), B = both / runs everywhere when executed. **Loaded from** - how execution starts.

| File | Role | Context | Loaded from |
|------|------|---------|-------------|
| `initServer.sqf` | Server init: CfgVehicles scan, faction caches, helipad/vehicle/board lists, scenario defaults, mission start/abort/spawn/copilot/jukebox, `FAC_surrenderChallenge_start` (gated by `FAC_surrenderChallenge_playerEnabled`), mission tasks via `BIS_fnc_taskCreate` for starter only (`ASSIGNED`, not side-wide), `FADE_counterAttackStart` / cargo-seat filter + RHS/vanilla truck fallbacks + 1–3 QRF waves (HVT/Hostage/Clear Area), ambient `execVM`, `publicVariable` of globals and server RPC names. | S | Engine (server) |
| `initPlayerLocal.sqf` | Client init: `FADE_showMissionHint`, GUI `compile`, `waitUntil` server vars, board/loadout/jukebox actions, briefing, locker ambient `execVM`, light towers, pylon action, Ctrl+;/Ctrl+' keybinds. | C | Engine (each client) |
| `init.sqf` | Early `fn_bisCpPreInit` call so stubs exist before other inits. | B | Engine (all) |
| `onPlayerRespawn.sqf` | Restores mission UI vars and saved loadout on respawn (client). | C | `description.ext` / engine |
| `cba_settings.sqf` | CBA mission settings (e.g. ACE hearing). | B | CBA |
| `rsc/Config.sqf` | Scenario defaults, pad names, faction fallbacks, debug flags; loaded on server and client. | B | `initServer` / `initPlayerLocal` |
| `rsc/CfgFunctionsMission.hpp` | Declares preInit/postInit SQF files. | - | `description.ext` |
| `rsc/fn_bisCpPreInit.sqf` | Reapplies BIS CP stubs each frame when debug off; avoids campaign function errors. | B | CfgFunctions + `init.sqf` |
| `rsc/fn_bisCpPostInit.sqf` | Post-init stub reapply. | B | CfgFunctions postInit |
| `rsc/fn_bisCpStubApply.sqf` | Installs noop `bis_fnc_cp_main` / `bis_fnc_cp_getQueueDelay` in mission and ui namespaces. | B | Called from pre/post init |
| `rsc/DebugBIScpStub.sqf` | Optional logging stubs when `FADE_debugBIScp` is true (diagnostics). | B | `initServer` / `initPlayerLocal` |
| `rsc/Missions.sqf` | All dynamic mission implementations; `if (!isServer) exitWith {}`; `call compile` from `FADE_startMission`; starter-only mission tasks via `BIS_fnc_taskCreate` (`ASSIGNED` for `_player`); includes AO and TroopTransport compiles; HVT/Hostage/Clear Area call `FADE_counterAttackStart`. | S | `initServer` → `FADE_startMission` |
| `rsc/TroopTransport.sqf` | Troop Insert/Extract AI phases; server-only. | S | `Missions.sqf` |
| `rsc/AOMission.sqf` | Area of Operations mission; server-only. | S | `Missions.sqf` |
| `rsc/AmbientCivilians.sqf` | Civilian zones and road traffic; server loop; hints via `remoteExec`. | S | `initServer` `execVM` |
| `rsc/EnemyAAA.sqf` | Scenario AAA spawns near civ zones; server-only. | S | `initServer` `execVM` |
| `rsc/EnemyCheckpoints.sqf` | Checkpoint spawns near players when patrols enabled; server-only. | S | `initServer` `execVM` |
| `rsc/PadVehicleService.sqf` | Repair/refuel/rearm on pads; server poll loop. | S | `initServer` `execVM` |
| `rsc/SurrenderChallenge.sqf` | Surrender challenge logic; server-only; `execVM` from `FAC_surrenderChallenge_start` when player flag enabled. | S | `initServer` |
| `rsc/VehicleGui.sqf` | Manage Vehicles dialog; `remoteExec` spawn/despawn/`FADE_serviceVehicle`/list to server; defines `FADE_receiveVehiclesAtBase`. | C | `initPlayerLocal` `compile` |
| `rsc/MissionsGui.sqf` | Manage Missions dialog; start/abort/copilot `remoteExec`; defines `FADE_receiveCopilotState`. | C | `initPlayerLocal` `compile` |
| `rsc/ScenarioGui.sqf` | Manage Scenario dialog; Apply → `FADE_applyScenarioSettings` on server. | C | `initPlayerLocal` `compile` |
| `rsc/LoadoutGui.sqf` | Loadout selection GUI; local/unit config only. | C | `initPlayerLocal` `compile` |
| `rsc/JukeboxGui.sqf` | Jukebox UI; `FAC_jukebox_clientPlay` + `remoteExec` to `FAC_jukebox_serverPlay`. Loudness: **CfgSounds** `Sig_*` in `description.ext` (createSoundSource); mirror `FAC_jukebox_soundVolumeMission` / `FAC_jukebox_soundDistanceMission` in this file. | C | `initPlayerLocal` `compile` |
| `rsc/CQBGui.sqf` | CQB drill GUI; start/end `remoteExec` to server. | C | `initPlayerLocal` `compile` |
| `rsc/CqbLoudspeaker.sqf` | Client `FAC_cqbLoudspeaker_clientPlay` for 3D horn (called from server). | C | `initPlayerLocal` `compile` |
| `rsc/TeleportGui.sqf` | Fast travel UI; client `setPosATL`. | C | `initPlayerLocal` `preprocessFile` |
| `rsc/TeleportMapPick.sqf` | Map-click teleport helper; client `execVM` from board action. | C | `addAction` → `execVM` |
| `rsc/Briefing.sqf` | Map diary / briefing records. | C | `initPlayerLocal` `execVM` |
| `rsc/LightTowers.sqf` | Local lights above pads; `createVehicleLocal`. | C | `initPlayerLocal` `spawn` → `execVM` |
| `rsc/LockerRoomAmbient.sqf` | Locker room ambience; `hasInterface`; `say3D` via `remoteExec`. | C | `initPlayerLocal` `execVM` |

---

## Formal verification (dedicated MP / server authority)

**Standard:** Server authority for simulation and spawning; clients own UI, local player, and effects requiring `hasInterface`; cross-machine work via `remoteExec` / `publicVariable` / global `setVariable` as documented in `initServer.sqf`.  
**Verification date:** 2026-03-26  

### Methodology

| Step | Action |
|------|--------|
| 1 | Enumerate every `*.sqf` under the mission folder (30 files). |
| 2 | Classify each file: **S** server-only, **C** client-only, **B** runs on all machines when invoked. |
| 3 | **S:** Confirm `if (!isServer) exitWith {}` or exclusive `execVM`/`compile` only from server; no `hint` / `createDialog` / `findDisplay` / global `player` for gameplay on server paths. |
| 4 | **C:** Confirm execution only from `initPlayerLocal` or client actions; UI/audio uses `hasInterface` where broadcast audio could otherwise run on headless. |
| 5 | **B:** Confirm safe on dedicated (no UI assumptions); stubs run everywhere by design. |
| 6 | **Network:** Grep mission for `remoteExec`, `publicVariable`; confirm server-exposed functions are `publicVariable`'d in `initServer.sqf`. |
| 7 | **`rsc/Missions.sqf`:** Full header and dependency read; automated checks: `if (!isServer)` at L22; zero `hint` **commands** (only comment text); `_player` parameter for feedback; **39** `remoteExec ["FADE_showMissionHint", …]` usages; no bare `player` token in executable code (comments only). |

**Tools used:** repository grep, line counts, targeted file reads, structural review of `initServer.sqf` publicVariable block.

### Verification matrix (all 30 files)

**Legend - Checks:** **G** = execution guard / entry path OK · **UI** = client UI/audio safe (or N/A) · **NET** = networking consistent · **Result** = PASS / PASS\*  

\*PASS\* = passes by design (config/stub; no MP risk).

| # | File | ~Lines | Ctx | Checks | Result | Evidence / notes |
|---|------|--------|-----|--------|--------|------------------|
| 1 | `initServer.sqf` | 2169 | S | G, NET | PASS | `if (!isServer) exitWith {}` L16; `FAC_surrenderChallenge_playerEnabled` gates surrender RPC; spawns, PV (`FADE_serviceVehicle` + vehicle RPCs), compiles `Missions.sqf`; `remoteExec` to clients; comments only re “hint”. |
| 2 | `initPlayerLocal.sqf` | 433 | C | G, UI, NET | PASS | Client-only; `FADE_showMissionHint`; `FAC_surrenderChallenge_fnc_activate` gated; `remoteExec` to server `2`; boards/actions/GUI. |
| 3 | `init.sqf` | 3 | B | G | PASS\* | Calls `fn_bisCpPreInit` only. |
| 4 | `onPlayerRespawn.sqf` | 21 | C | G, UI | PASS | Client respawn; `player`/`setUnitLoadout` local. |
| 5 | `cba_settings.sqf` | 4 | B | G | PASS\* | CBA `force` assignments only. |
| 6 | `rsc/Config.sqf` | 134 | B | G | PASS\* | Data + `call compile fn_bisCpPreInit`; no network API. |
| 7 | `rsc/fn_bisCpPreInit.sqf` | 14 | B | G | PASS\* | Stub guard; `EachFrame` when not debugging. |
| 8 | `rsc/fn_bisCpPostInit.sqf` | 2 | B | G | PASS\* | Reapplies stub. |
| 9 | `rsc/fn_bisCpStubApply.sqf` | 12 | B | G | PASS\* | Sets mission/uiNamespace stubs. |
| 10 | `rsc/DebugBIScpStub.sqf` | 43 | B | G | PASS\* | Exits if `FADE_debugBIScp` false; diag_log only. |
| 11 | `rsc/Missions.sqf` | ~1967 | S | G, NET | PASS | L22 `if (!isServer) exitWith {}`; no `hint` statement; feedback via `remoteExec` to `_player` or `systemChat` via server; `_player` param; starter-only `BIS_fnc_taskCreate` (`ASSIGNED`). |
| 12 | `rsc/TroopTransport.sqf` | 293 | S | G, NET | PASS | L13 `if (!isServer) exitWith {}`; `playSound`/`systemChat` via `remoteExec` to `_player`. |
| 13 | `rsc/AOMission.sqf` | 665 | S | G, NET | PASS | L6 `if (!isServer) exitWith {}`; compiled only from server `Missions.sqf`. |
| 14 | `rsc/AmbientCivilians.sqf` | 665 | S | G, NET | PASS | L12 `if (!isServer) exitWith {}`; “hint” via `remoteExec ["FADE_showMissionHint", 0]` (server→clients). |
| 15 | `rsc/EnemyAAA.sqf` | 313 | S | G | PASS | L10 `if (!isServer) exitWith {}`. |
| 16 | `rsc/EnemyCheckpoints.sqf` | 222 | S | G, NET | PASS | L12 `if (!isServer) exitWith {}`; debug `systemChat` remoteExec to 0. |
| 17 | `rsc/PadVehicleService.sqf` | 42 | S | G | PASS | L6 `if (!isServer) exitWith {}`. |
| 18 | `rsc/SurrenderChallenge.sqf` | 325 | S | G, NET | PASS | L40 `if (!isServer) exitWith {}`; `remoteExec` to `_player` for feedback. |
| 19 | `rsc/VehicleGui.sqf` | 265 | C | UI, NET | PASS | Client GUI; `remoteExec` to server for spawn/despawn/`FADE_serviceVehicle`/list. |
| 20 | `rsc/MissionsGui.sqf` | 243 | C | UI, NET | PASS | Client GUI; mission/copilot `remoteExec` to `2`. |
| 21 | `rsc/ScenarioGui.sqf` | 256 | C | UI, NET | PASS | Apply → `FADE_applyScenarioSettings` on server. |
| 22 | `rsc/LoadoutGui.sqf` | 343 | C | UI | PASS | Local loadout; `player` only in GUI context. |
| 23 | `rsc/JukeboxGui.sqf` | 398 | C | UI, NET | PASS | `FAC_jukebox_clientPlay` uses `hasInterface`; server `remoteExec` for play. Loudness: CfgSounds `Sig_*` + mirror `FAC_jukebox_soundVolumeMission` / `FAC_jukebox_soundDistanceMission`. |
| 24 | `rsc/CQBGui.sqf` | 100 | C | UI, NET | PASS | CQB `remoteExec` to server. |
| 25 | `rsc/CqbLoudspeaker.sqf` | 35 | C | UI | PASS | `FAC_cqbLoudspeaker_clientPlay`: `hasInterface` L13. |
| 26 | `rsc/TeleportGui.sqf` | 215 | C | UI | PASS | Client `setPosATL` / dialogs. |
| 27 | `rsc/TeleportMapPick.sqf` | 34 | C | UI | PASS | Client `execVM`; map/hint local. |
| 28 | `rsc/Briefing.sqf` | 347 | C | UI | PASS | `player createDiaryRecord` - client init only. |
| 29 | `rsc/LightTowers.sqf` | 40 | C | UI | PASS | `createVehicleLocal`; client `execVM`. |
| 30 | `rsc/LockerRoomAmbient.sqf` | 94 | C | UI, NET | PASS | `hasInterface` L4; `say3D` via `remoteExec` to 0. |

### `rsc/Missions.sqf` - extended record

| Check | Result |
|--------|--------|
| Server entry guard | `if (!isServer) exitWith {}` immediately after params (L22). |
| `hint` command | **None** in executable code (grep: only comments L10–11, 52). |
| Player-specific feedback | Uses `_player` from `FADE_missionParams`; **39** `remoteExec ["FADE_showMissionHint", …]` usages. |
| Global `player` in code | **None** in executable lines (grep: comments only). |
| Sub-includes | `call compile` of `rsc/AOMission.sqf` and `rsc/TroopTransport.sqf` only from this server script. |

### Sign-off

| Role | Meaning |
|------|---------|
| **Verified** | All 30 mission `.sqf` files listed above passed the methodology for dedicated-server / MP consistency. |

---

## How pieces fit together

1. **Scenario state** - Applied on the **server** (`FADE_applyScenarioSettings`); lists and flags live in `missionNamespace` and are replicated with `publicVariable` / `setVariable ... true` as needed. Clients refresh local GUI state via `FADE_syncScenarioConfig` and initial `FADE_sendScenarioConfigToClient`.

2. **Vehicles** - Client GUI sends class + player to **server**; server creates/deletes vehicles and sends **systemChat** / list updates back to the requesting client.

3. **Missions** - Client sends mission type + player; **server** validates slots, sets `FADE_missionParams`, `call compile`s `Missions.sqf` (not `execVM` for the main file, to avoid param races). Sub-scripts (`TroopTransport`, `AOMission`) are server `compile`d from within `Missions.sqf`.

4. **Feedback** - Structured hints use `remoteExec ["FADE_showMissionHint", _player]` (or `0` for all clients in a few ambient cases). **Sound** for transport uses `remoteExec ["playSound", _player]` from server (`TroopTransport.sqf`).

5. **Audio broadcast** - Jukebox server maintains **`FAC_jukebox_activeSources`** (`[[sourceKey, song], ...]`, public) and **`remoteExec`s** `FAC_jukebox_clientPlay` with **`[song, sourceKey]`** to every client (per-source audio; multiple radios at once). JIP clients replay from that array. Locker (and optional surrender audio when enabled) use **`say3D`** with `remoteExec` to `0` where 3D audio should be heard by everyone.

6. **BIS campaign function gaps** - `fn_bisCpStubApply` + preInit/postInit/`EachFrame` guard reduce RPT errors from mods expecting `bis_fnc_cp_*` (see **AGENTS.md**).

---

## Maintenance

When adding or changing scripts:

1. Decide **S / C / B** and add `isServer` or `hasInterface` guards as appropriate.
2. Any **new server entry point** from clients must be **`publicVariable`'d** after the function is assigned on the server.
3. Any **new client-only handler** for `remoteExec` must be **defined on every client** (typically in `initPlayerLocal` or a GUI file loaded there).
4. Update **this file** (inventory table **and** verification matrix / evidence), and for player-facing behaviour, **AGENTS.md**.

---

## References

- **AGENTS.md** - Gameplay, editor names, patterns.  
- **Bohemia Wiki - Multiplayer scripting:** https://community.bistudio.com/wiki/Multiplayer_Scripting  

---

*Inventory and dedicated-server compatibility pass; filenames and hooks refer to commit state at documentation time. Line numbers in the verification matrix may drift as files grow - re-grep when auditing.*
