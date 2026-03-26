# Script index — FAC Heli Ops (Sefrou-Ramal)

This document is the **inventory and layout map** for all mission scripts: what runs where, how pieces connect, and how that aligns with **multiplayer dedicated servers**. For gameplay features and editor object names, see **AGENTS.md** (which links here for discoverability).

### Formal verification

**FORMAL_SCRIPT_VERIFICATION.md** (repository root) holds the **signed-off matrix**: every `.sqf` file, execution context, checks applied (server guard, UI/headless, networking), and result. **`rsc/Missions.sqf`** is recorded there with explicit grep evidence (server guard, no `hint` command, `_player`-scoped feedback). Update that document whenever you add or change scripts.

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
2. `init.sqf` — runs on **all machines**; calls `fn_bisCpPreInit` (stubs for missing BIS campaign functions).
3. `CfgFunctions` **preInit** / **postInit** — same stub maintenance (`fn_bisCpPreInit`, `fn_bisCpPostInit`).
4. **`initServer.sqf`** — server only (`if (!isServer) exitWith {}`); config scan, `publicVariable` sync, long-running server loops, `remoteExec`-callable handlers.
5. **`initPlayerLocal.sqf`** — each **client** with a player (not dedicated server); GUIs, actions, hints, surrender/jukebox client side.

---

## Dedicated server audit (summary)

**Verdict:** The framework is **consistent with dedicated-server MP**: world state and AI run on the server; UI, cursor, and local audio run on clients; cross-boundary work uses `remoteExec` with target `2` (server), `_player` (one client), or `0` (all clients / broadcast) as documented in `initServer.sqf` and `initPlayerLocal.sqf`.

**Patterns verified:**

- **Server-only** mission logic uses `if (!isServer) exitWith {}` (`Missions.sqf`, `TroopTransport.sqf`, `AOMission.sqf`, `AmbientCivilians.sqf`, `EnemyAAA.sqf`, `EnemyCheckpoints.sqf`, `PadVehicleService.sqf`, `SurrenderChallenge.sqf`).
- **Client-only** effects use `hasInterface` where needed (`JukeboxGui.sqf` playback, `LockerRoomAmbient.sqf`, `CqbLoudspeaker.sqf`) so headless clients do not run UI/audio paths incorrectly.
- **Server functions invoked from clients** are **`publicVariable`'d** after definition in `initServer.sqf` (e.g. `FADE_startMission`, `FADE_spawnHeli`, `FAC_surrenderChallenge_start`, `FAC_jukebox_serverPlay`).
- **JIP:** Mission data clients need (`FADE_heliClasses`, board object refs, slot state, etc.) is **`publicVariable`'d** from the server; scenario apply also syncs via `remoteExec` + `publicVariable` where needed.
- **Client handler functions** targeted by `remoteExec` (`FADE_showMissionHint`, `FADE_receiveVehiclesAtBase`, `FADE_receiveCopilotState`, `FAC_jukebox_clientPlay`) are **defined in `initPlayerLocal` / GUI compiles** so each client has them before use; jukebox uses **`remoteExec` JIP queue** (`"FAC_jukebox_JIP"`) for late joiners.

**Residual risks (operational, not code bugs):**

- **`remoteExec` to a function name** requires that function to exist on the target machine when the call runs. This mission defines those functions during client init; avoid moving GUI init after first server→client `remoteExec`.
- **Mods** and **Eden object/module inits** are outside this index; RPT noise from `bis_fnc_cp_*` is addressed via stubs (see **AGENTS.md** Known RPT Warnings).

---

## Network surface (quick reference)

**From clients to server (`remoteExec [..., 2]`):**  
`FADE_applyScenarioSettings`, `FADE_sendScenarioConfigToClient` (also server-called), vehicle spawn/despawn/list, time/weather, copilot, `FADE_startMission`, `FADE_abortMission`, `FAC_surrenderChallenge_start`, `FAC_jukebox_serverPlay`, CQB drill start/end.

**From server to clients:**  
`FADE_showMissionHint`, `FADE_syncScenarioConfig`, `systemChat`, `playSound`, `say3D`, `FAC_jukebox_clientPlay`, `FAC_cqbLoudspeaker_clientPlay`, `FADE_receiveVehiclesAtBase`, `FADE_receiveCopilotState`, and mission-specific feedback — see `initServer.sqf`, `Missions.sqf`, `TroopTransport.sqf`, `AmbientCivilians.sqf`.

**`publicVariable`:**  
See the block in `initServer.sqf` (scenario helpers, mission slot globals, board lists, `FAC_surrenderChallenge_start`, `FAC_jukebox_serverPlay`, etc.).

---

## Script inventory

Columns: **Role** — primary purpose. **Context** — S = server only, C = client only (incl. UI), B = both / runs everywhere when executed. **Loaded from** — how execution starts.

| File | Role | Context | Loaded from |
|------|------|---------|-------------|
| `initServer.sqf` | Server init: CfgVehicles scan, faction caches, helipad/vehicle/board lists, scenario defaults, mission start/abort/spawn/copilot/jukebox/surrender handlers, ambient `execVM`, `publicVariable` of globals and server RPC names. | S | Engine (server) |
| `initPlayerLocal.sqf` | Client init: `FADE_showMissionHint`, surrender activation, GUI `compile`, `waitUntil` server vars, board/loadout/jukebox actions, briefing, locker ambient `execVM`, light towers, pylon action, keybinds. | C | Engine (each client) |
| `init.sqf` | Early `fn_bisCpPreInit` call so stubs exist before other inits. | B | Engine (all) |
| `onPlayerRespawn.sqf` | Restores mission UI vars and saved loadout on respawn (client). | C | `description.ext` / engine |
| `cba_settings.sqf` | CBA mission settings (e.g. ACE hearing). | B | CBA |
| `rsc/Config.sqf` | Scenario defaults, pad names, faction fallbacks, debug flags; loaded on server and client. | B | `initServer` / `initPlayerLocal` |
| `rsc/CfgFunctionsMission.hpp` | Declares preInit/postInit SQF files. | — | `description.ext` |
| `rsc/fn_bisCpPreInit.sqf` | Reapplies BIS CP stubs each frame when debug off; avoids campaign function errors. | B | CfgFunctions + `init.sqf` |
| `rsc/fn_bisCpPostInit.sqf` | Post-init stub reapply. | B | CfgFunctions postInit |
| `rsc/fn_bisCpStubApply.sqf` | Installs noop `bis_fnc_cp_main` / `bis_fnc_cp_getQueueDelay` in mission and ui namespaces. | B | Called from pre/post init |
| `rsc/DebugBIScpStub.sqf` | Optional logging stubs when `FADE_debugBIScp` is true (diagnostics). | B | `initServer` / `initPlayerLocal` |
| `rsc/Missions.sqf` | All dynamic mission implementations; `if (!isServer) exitWith {}`; `call compile` from `FADE_startMission`; includes AO and TroopTransport compiles. | S | `initServer` → `FADE_startMission` |
| `rsc/TroopTransport.sqf` | Troop Insert/Extract AI phases; server-only. | S | `Missions.sqf` |
| `rsc/AOMission.sqf` | Area of Operations mission; server-only. | S | `Missions.sqf` |
| `rsc/AmbientCivilians.sqf` | Civilian zones and road traffic; server loop; hints via `remoteExec`. | S | `initServer` `execVM` |
| `rsc/EnemyAAA.sqf` | Scenario AAA spawns near civ zones; server-only. | S | `initServer` `execVM` |
| `rsc/EnemyCheckpoints.sqf` | Checkpoint spawns near players when patrols enabled; server-only. | S | `initServer` `execVM` |
| `rsc/PadVehicleService.sqf` | Repair/refuel/rearm on pads; server poll loop. | S | `initServer` `execVM` |
| `rsc/SurrenderChallenge.sqf` | Surrender challenge logic; server-only; `execVM` from `FAC_surrenderChallenge_start`. | S | `initServer` |
| `rsc/VehicleGui.sqf` | Manage Vehicles dialog; `remoteExec` spawn/despawn/list to server; defines `FADE_receiveVehiclesAtBase`. | C | `initPlayerLocal` `compile` |
| `rsc/MissionsGui.sqf` | Manage Missions dialog; start/abort/copilot `remoteExec`; defines `FADE_receiveCopilotState`. | C | `initPlayerLocal` `compile` |
| `rsc/ScenarioGui.sqf` | Manage Scenario dialog; Apply → `FADE_applyScenarioSettings` on server. | C | `initPlayerLocal` `compile` |
| `rsc/LoadoutGui.sqf` | Loadout selection GUI; local/unit config only. | C | `initPlayerLocal` `compile` |
| `rsc/JukeboxGui.sqf` | Jukebox UI; `FAC_jukebox_clientPlay` + `remoteExec` to `FAC_jukebox_serverPlay`. | C | `initPlayerLocal` `compile` |
| `rsc/CQBGui.sqf` | CQB drill GUI; start/end `remoteExec` to server. | C | `initPlayerLocal` `compile` |
| `rsc/CqbLoudspeaker.sqf` | Client `FAC_cqbLoudspeaker_clientPlay` for 3D horn (called from server). | C | `initPlayerLocal` `compile` |
| `rsc/TeleportGui.sqf` | Fast travel UI; client `setPosATL`. | C | `initPlayerLocal` `preprocessFile` |
| `rsc/TeleportMapPick.sqf` | Map-click teleport helper; client `execVM` from board action. | C | `addAction` → `execVM` |
| `rsc/Briefing.sqf` | Map diary / briefing records. | C | `initPlayerLocal` `execVM` |
| `rsc/LightTowers.sqf` | Local lights above pads; `createVehicleLocal`. | C | `initPlayerLocal` `spawn` → `execVM` |
| `rsc/LockerRoomAmbient.sqf` | Locker room ambience; `hasInterface`; `say3D` via `remoteExec`. | C | `initPlayerLocal` `execVM` |

---

## How pieces fit together

1. **Scenario state** — Applied on the **server** (`FADE_applyScenarioSettings`); lists and flags live in `missionNamespace` and are replicated with `publicVariable` / `setVariable ... true` as needed. Clients refresh local GUI state via `FADE_syncScenarioConfig` and initial `FADE_sendScenarioConfigToClient`.

2. **Vehicles** — Client GUI sends class + player to **server**; server creates/deletes vehicles and sends **systemChat** / list updates back to the requesting client.

3. **Missions** — Client sends mission type + player; **server** validates slots, sets `FADE_missionParams`, `call compile`s `Missions.sqf` (not `execVM` for the main file, to avoid param races). Sub-scripts (`TroopTransport`, `AOMission`) are server `compile`d from within `Missions.sqf`.

4. **Feedback** — Structured hints use `remoteExec ["FADE_showMissionHint", _player]` (or `0` for all clients in a few ambient cases). **Sound** for transport uses `remoteExec ["playSound", _player]` from server (`TroopTransport.sqf`).

5. **Audio broadcast** — Jukebox server updates `FAC_jukebox_nowPlaying` and **`remoteExec`s** `FAC_jukebox_clientPlay` to every client with JIP key. Locker/surrender use **`say3D`** with `remoteExec` to `0` where 3D audio should be heard by everyone.

6. **BIS campaign function gaps** — `fn_bisCpStubApply` + preInit/postInit/`EachFrame` guard reduce RPT errors from mods expecting `bis_fnc_cp_*` (see **AGENTS.md**).

---

## Maintenance

When adding a script:

1. Decide **S / C / B** and add `isServer` or `hasInterface` guards as appropriate.
2. Any **new server entry point** from clients must be **`publicVariable`'d** after the function is assigned on the server.
3. Any **new client-only handler** for `remoteExec` must be **defined on every client** (typically in `initPlayerLocal` or a GUI file loaded there).
4. Update **this file** and, for player-facing behaviour, **AGENTS.md**.

---

*Generated as part of a dedicated-server compatibility pass; filenames and hooks refer to commit state at documentation time.*
