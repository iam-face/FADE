# Formal script verification — dedicated multiplayer / dedicated server

**Mission:** FAC Heli Ops (Sefrou-Ramal)  
**Scope:** All `.sqf` files in the mission repository  
**Standard:** Server authority for simulation and spawning; clients own UI, local player, and effects requiring `hasInterface`; cross-machine work via `remoteExec` / `publicVariable` / global `setVariable` as documented in `initServer.sqf`.  
**Verification date:** 2026-03-26  

This document is the **formal record** that each listed file was reviewed for the checks below. It complements **SCRIPT_INDEX.md** (inventory and layout) and **AGENTS.md** (features and conventions).

---

## Methodology

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

**Out of scope (not mission SQF):** `mission.sqm` init fields, addon scripts, CBA/ACE internals.

---

## Verification matrix (all 30 files)

**Legend — Checks:** **G** = execution guard / entry path OK · **UI** = client UI/audio safe (or N/A) · **NET** = networking consistent · **Result** = PASS / PASS\*  

\*PASS\* = passes by design (config/stub; no MP risk).

| # | File | ~Lines | Ctx | Checks | Result | Evidence / notes |
|---|------|--------|-----|--------|--------|------------------|
| 1 | `initServer.sqf` | 1477 | S | G, NET | PASS | `if (!isServer) exitWith {}` L16; spawns, PV, `remoteExec` to clients; comments only re “hint”. |
| 2 | `initPlayerLocal.sqf` | 409 | C | G, UI, NET | PASS | Client-only; `FADE_showMissionHint`; `remoteExec` to server `2`; boards/actions/GUI. |
| 3 | `init.sqf` | 3 | B | G | PASS\* | Calls `fn_bisCpPreInit` only. |
| 4 | `onPlayerRespawn.sqf` | 21 | C | G, UI | PASS | Client respawn; `player`/`setUnitLoadout` local. |
| 5 | `cba_settings.sqf` | 4 | B | G | PASS\* | CBA `force` assignments only. |
| 6 | `rsc/Config.sqf` | 134 | B | G | PASS\* | Data + `call compile fn_bisCpPreInit`; no network API. |
| 7 | `rsc/fn_bisCpPreInit.sqf` | 14 | B | G | PASS\* | Stub guard; `EachFrame` when not debugging. |
| 8 | `rsc/fn_bisCpPostInit.sqf` | 2 | B | G | PASS\* | Reapplies stub. |
| 9 | `rsc/fn_bisCpStubApply.sqf` | 12 | B | G | PASS\* | Sets mission/uiNamespace stubs. |
| 10 | `rsc/DebugBIScpStub.sqf` | 43 | B | G | PASS\* | Exits if `FADE_debugBIScp` false; diag_log only. |
| 11 | `rsc/Missions.sqf` | ~1860 | S | G, NET | PASS | L22 `if (!isServer) exitWith {}`; no `hint` statement; feedback via `remoteExec` to `_player` or `systemChat` via server; `_player` param. |
| 12 | `rsc/TroopTransport.sqf` | 293 | S | G, NET | PASS | L13 `if (!isServer) exitWith {}`; `playSound`/`systemChat` via `remoteExec` to `_player`. |
| 13 | `rsc/AOMission.sqf` | 665 | S | G, NET | PASS | L6 `if (!isServer) exitWith {}`; compiled only from server `Missions.sqf`. |
| 14 | `rsc/AmbientCivilians.sqf` | 665 | S | G, NET | PASS | L12 `if (!isServer) exitWith {}`; “hint” via `remoteExec ["FADE_showMissionHint", 0]` (server→clients). |
| 15 | `rsc/EnemyAAA.sqf` | 313 | S | G | PASS | L10 `if (!isServer) exitWith {}`. |
| 16 | `rsc/EnemyCheckpoints.sqf` | 222 | S | G, NET | PASS | L12 `if (!isServer) exitWith {}`; debug `systemChat` remoteExec to 0. |
| 17 | `rsc/PadVehicleService.sqf` | 42 | S | G | PASS | L6 `if (!isServer) exitWith {}`. |
| 18 | `rsc/SurrenderChallenge.sqf` | 325 | S | G, NET | PASS | L40 `if (!isServer) exitWith {}`; `remoteExec` to `_player` for feedback. |
| 19 | `rsc/VehicleGui.sqf` | 236 | C | UI, NET | PASS | Client GUI; `remoteExec` to server for spawn/despawn/list. |
| 20 | `rsc/MissionsGui.sqf` | 243 | C | UI, NET | PASS | Client GUI; mission/copilot `remoteExec` to `2`. |
| 21 | `rsc/ScenarioGui.sqf` | 256 | C | UI, NET | PASS | Apply → `FADE_applyScenarioSettings` on server. |
| 22 | `rsc/LoadoutGui.sqf` | 343 | C | UI | PASS | Local loadout; `player` only in GUI context. |
| 23 | `rsc/JukeboxGui.sqf` | 159 | C | UI, NET | PASS | `FAC_jukebox_clientPlay` uses `hasInterface` L62; server `remoteExec` for play. |
| 24 | `rsc/CQBGui.sqf` | 100 | C | UI, NET | PASS | CQB `remoteExec` to server. |
| 25 | `rsc/CqbLoudspeaker.sqf` | 35 | C | UI | PASS | `FAC_cqbLoudspeaker_clientPlay`: `hasInterface` L13. |
| 26 | `rsc/TeleportGui.sqf` | 215 | C | UI | PASS | Client `setPosATL` / dialogs. |
| 27 | `rsc/TeleportMapPick.sqf` | 34 | C | UI | PASS | Client `execVM`; map/hint local. |
| 28 | `rsc/Briefing.sqf` | 347 | C | UI | PASS | `player createDiaryRecord` — client init only. |
| 29 | `rsc/LightTowers.sqf` | 40 | C | UI | PASS | `createVehicleLocal`; client `execVM`. |
| 30 | `rsc/LockerRoomAmbient.sqf` | 94 | C | UI, NET | PASS | `hasInterface` L4; `say3D` via `remoteExec` to 0. |

---

## `rsc/Missions.sqf` — extended record

| Check | Result |
|--------|--------|
| Server entry guard | `if (!isServer) exitWith {}` immediately after params (L22). |
| `hint` command | **None** in executable code (grep: only comments L10–11, 52). |
| Player-specific feedback | Uses `_player` from `FADE_missionParams`; **39** `remoteExec ["FADE_showMissionHint", …]` usages. |
| Global `player` in code | **None** in executable lines (grep: comments only). |
| Sub-includes | `call compile` of `rsc/AOMission.sqf` and `rsc/TroopTransport.sqf` only from this server script. |

---

## Sign-off

| Role | Meaning |
|------|---------|
| **Verified** | All 30 mission `.sqf` files listed above passed the methodology for dedicated-server / MP consistency. |

**Maintainer:** When adding or changing any `.sqf`, update this document’s matrix (new row or revised notes) and **SCRIPT_INDEX.md** in the same change.

---

## References

- **SCRIPT_INDEX.md** — File inventory and load order.  
- **AGENTS.md** — Gameplay, editor names, patterns.  
- **Bohemia Wiki — Multiplayer scripting:** https://community.bistudio.com/wiki/Multiplayer_Scripting  
