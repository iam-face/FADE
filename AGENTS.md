# Face's Dynamic Sandbox -- ARMA 3 Mission (Tunis)

## Project Context

This is a **helicopter piloting sandbox** for **ARMA 3**, designed for **multiplayer**. Players can use a variety of helicopters to conduct simple missions. The purpose is to allow them to practice with the airframes.

## Reference Documentation

**Arma 3 Wiki:** https://armedassault.fandom.com/wiki/ArmA_3  
**Bohemia Community Wiki:** https://community.bistudio.com/wiki/

Use the Wikis as the primary source for:

- **Scripting** -- SQF syntax, commands, and best practices
- **Multiplayer functionality** -- network events, server/client execution, JIP
- **Mission structure** -- `description.ext`, `mission.sqm`, init scripts
- **Event handlers** -- `onPlayerRespawn.sqf`, `onPlayerKilled.sqf`, etc.
- **Vehicles and airframes** -- helicopter class names, flight dynamics, sling loading

---

## Mission Structure

- **initServer.sqf** -- Server-side init: CfgVehicles scan, faction/unit caches, helper functions, vehicle spawn/despawn, mission start/abort, weather, Surrender Challenge, Jukebox server side.
- **initPlayerLocal.sqf** -- Client-side init: load GUI scripts, add board/loadoutbox/radio actions, Surrender Challenge key binding, welcome hint, LightTowers.
- **description.ext** -- Mission config (Header, respawn, CfgSounds, CfgUserActions, CfgIdentities, GUI dialogs). GUI dialogs defined here (RscDisplayVehicle, RscDisplayMissions, RscDisplayScenario, RscDisplayLoadout, RscDisplayJukebox).
- **Img/** -- Mission images (load screen, overview, etc.)
- **Sounds/** -- Sound files (.ogg): surrender sounds, apprehend shouts, troop transport cues.
- **rsc/Config.sqf** -- Scenario defaults (time, weather, factions, pad names, unit fallbacks, civ config).
- **rsc/Briefing.sqf** -- In-game briefing and diary records (map screen). Keep in sync with key scenario/mission changes.
- **rsc/Missions.sqf** -- All dynamic mission implementations (server-only). Branched by `_missionType`; calls TroopTransport.sqf for insert/extract.
- **rsc/TroopTransport.sqf** -- AI boarding/disembark logic for Troop Insert and Troop Extract (server-only, phase-based spawn pattern).
- **rsc/AmbientCivilians.sqf** -- Ambient civilian spawning in CIV_T_* zones and road vehicle spawning on ROAD_SP_* points.
- **rsc/SurrenderChallenge.sqf** -- Surrender challenge system (server-side). Chance-based AI surrender with modifiers (distance, angle, players, captives, ratio). ACE3 captives integration.
- **rsc/LightTowers.sqf** -- Invisible ambient lights 25 m above each helipad and vehicle spawn point (client-side, spawned from initPlayerLocal).
- **rsc/VehicleGui.sqf** -- Manage Vehicles GUI logic.
- **rsc/MissionsGui.sqf** -- Manage Missions GUI logic.
- **rsc/ScenarioGui.sqf** -- Manage Scenario GUI logic (weather, time, factions, limit gear).
- **rsc/LoadoutGui.sqf** -- Manage My Loadout GUI logic.
- **rsc/JukeboxGui.sqf** -- Jukebox GUI logic (Radio_1 object). Track list, play/stop, now-playing display.
- **rsc/BaseControls.hpp** -- Shared base control class definitions (included in description.ext).
- **SoundEvents.md** -- Documents the sound events / OGG files used by CfgSounds.

### Custom GUIs (Boards / Loadout / Jukebox)

Dialogs are defined in **description.ext** (RscDisplayVehicle idd=60001, RscDisplayMissions idd=60002, RscDisplayScenario idd=60003, RscDisplayLoadout idd=60200, RscDisplayJukebox idd=60400). Logic lives in **rsc/*Gui.sqf** (VehicleGui, MissionsGui, ScenarioGui, LoadoutGui, JukeboxGui), all loaded via `call compile preprocessFileLineNumbers` in initPlayerLocal.sqf. For consistency:

- **Open**: Each GUI has an `"open"` case that checks preconditions (if any), then `if (!createDialog "RscDisplayX") then { systemChat "X GUI: RESOURCE NOT FOUND." };`.
- **onLoad**: All use `onLoad = "[] spawn { sleep 0.01; ['onLoad', []] call (missionNamespace getVariable ['FAC_xxxGui_fnc', {}]); };";` and in onLoad set `uinamespace setVariable ["FAC_xxxGui_fnc", FAC_xxxGui_fnc]` so config callbacks find the function.
- **Layout**: Background/Title use margins 0.02 / 0.96 (or 0.005/0.99 for Loadout). Close button action: `closeDialog 0;`. Base controls come from **rsc/BaseControls.hpp** (included in description.ext). Missions GUI has no map control (map was removed; it caused crashes).
- **Faction display names**: LoadoutGui defines `FAC_loadoutGui_getFactionDisplayName`; VehicleGui and ScenarioGui reuse it when available.
- **Jukebox (RscDisplayJukebox):** Opened via `Radio_1` object action. Tracks defined in `FAC_jukebox_tracks` (JukeboxGui.sqf). Play sends `[_class] remoteExec ["FAC_jukebox_serverPlay", 2]`; server broadcasts `FAC_jukebox_clientPlay` to all clients with JIP key `"FAC_jukebox_JIP"`. Each client creates a local sound helper object and calls `playSound3D`. Stop sends `[""] remoteExec ["FAC_jukebox_serverPlay", 2]`. The server-side `FAC_jukebox_serverPlay` is defined in initServer.sqf and publicVariable'd.

### In-Game Briefing & Diary

Players open the **map (M)** to access the briefing and notes. Content is defined in **rsc/Briefing.sqf** (run from initPlayerLocal.sqf). The custom scenario content uses the diary subject **Scenario Brief** (not "Briefing") so it appears as a separate section from the game's vanilla Briefing in the map menu.

- **Scenario Brief** subject: **Overview**, **How It Works**, **Rotary Piloting 101**.
- **Notes** subject -- Joint Fires and CAS reference (source of truth: *Combat Team Bravo Joint Fires Observer - Joint Terminal Attack Controller* doc). Notes include:
  - **9-Line JTAC Call-in** -- Full NATO 9-line CAS.
  - **CCA/CAS 5-Line Call for Fire** -- Simplified 5-line for rotary (CCA) and fixed-wing (CAS).
  - **Call for Fire (CFF) / Artillery** -- Indirect fires (GPO update, 4-element CFF, readbacks, adjusting, FFE, linear, round types, artillery callsigns, silent marking).
  - **Joint Fires Roles** -- JFO, JTAC, GPO; who requests fires.
  - **Control Measures** -- Ingress/egress, battle positions, anchor point, FLOT, NAI.
  - **Terminology and Brevity Codes** -- Glossary and procedure terms (REPEAT, CHECK FIRE, CLEARED HOT, etc.).
  - **Marking (Friendly and Enemy)** -- Positive/negative colours, target talk-on.
  - **Air Support Coordination** -- Radio check, check-in, sit update, repeat/re-attack, show of force.
  - **LZs, EZs and Supply Drops** -- Info to provide, ALCO.
  - **Emergency Fire Mission (EFM)** -- When JFO/JTAC is unavailable; chain of seniority; destruction vs screening.
  - **Electronic Warfare (Jamming)** -- Transmit out when jammed; confirm with show of force.

When adding or changing major features or joint fires procedures, update Briefing.sqf and this section of AGENTS.md. For joint fires content, align with the CTB Joint Fires doc.

---

## Eden Object Callouts

- **BASE_1** -- Defines the player base (centre of map). Used for base position, respawn, and mission distance checks.
- **Boards** -- `BOARD_1`, `BOARD_2`, `BOARD_3`. Three action boards: **Manage Vehicles**, **Manage Missions**, **Manage Scenario**. `BOARD_1` and `BOARD_2` / `BOARD_2b` receive custom board textures via `setObjectTextureGlobal` (initServer). `BOARD_3` receives the loading board texture.
- **LOADOUTBOX** / **LOADOUTBOX_2** -- Objects for loadout. Actions: **Manage My Loadout** (custom GUI), **Open ACE Arsenal** (if ACE3 loaded). Both are ACE arsenal-init'd on the server if ACE is present.
- **Radio_1** -- The jukebox radio object. Receives the **Jukebox** action (initPlayerLocal). Server owns its locality; `FAC_jukebox_serverPlay` targets server (`remoteExec [..., 2]`). All clients play audio locally via `FAC_jukebox_clientPlay`.
- **Helipads** -- `HP_1` through `HP_8`. Objects where aircraft spawn. Configured in `heliOps_padNames` (Config.sqf). Planes cannot spawn at pads in `heliOps_planeForbiddenPads` (default: HP_1, HP_2). Helipad markers (map) are updated by `heliOps_updateHelipadMarkers` periodically.
- **Vehicle spawn points** -- `VEH_1`, `VEH_2`. Land vehicles spawn here using `BIS_fnc_findSafePos` for dynamic placement.
- **Friendly AI infantry spawn points** -- `B_SP_1`, `B_SP_2`, `B_SP_3`. Used for Troop Insert pickup at base and Troop Extract walk-back point.
- **Civilian zone triggers** -- `CIV_T_1`, `CIV_T_2`, etc. Used by AmbientCivilians.sqf for proximity-based civ spawning and by `heliOps_findMissionPosUrban` for HVT/Hostage/ClearArea placement.
- **Road spawn points** -- `ROAD_SP_1` through `ROAD_SP_25`. Used by AmbientCivilians.sqf for road vehicle spawning and by Intercept Convoy for start/end positions.
- **CargoPoint_1** -- Map marker position. Cargo/Resupply mission spawns the sling-load box here. Falls back to base position if marker not found.
- **Mission locations** -- Generated dynamically by `heliOps_findMissionPos`: within map bounds (X/Y 500-9500), at least 700m from base (1000m for enemy missions), using `BIS_fnc_findSafePos` for clear ground. Urban missions use `heliOps_findMissionPosUrban` (CIV_T_* zones).

---

## Scenario Settings (Manage Scenario GUI)

Players can configure scenario-wide settings via **Manage Scenario** on the board:

- **Weather** -- Clear, Overcast, Foggy, Rain, Storm
- **Time of day** -- Dawn (06:00), Day (12:00), Dusk (18:00), Night (21:00), Midnight (00:00)
- **Enemy faction** -- OPFOR factions from `CfgFactionClasses` (side 0). Used for CAS, Clear Area, HVT, Hostage, Intercept Convoy, etc.
- **Friendly faction** -- BLUFOR factions (side 1). Used for Troop Insert/Extract, CAS support.
- **Civilian faction** -- Civilian factions (side 3). Used for ambient civilians (CIV_T_* zones, ROAD_SP_* vehicles).

**Scenario choices are server-side and global:** when a player clicks **Apply**, the server runs `heliOps_applyScenarioSettings`, which rebuilds unit/vehicle arrays from the chosen factions and stores them in `missionNamespace`. All mission spawns (Missions.sqf, AmbientCivilians.sqf) read these arrays from `missionNamespace`; there is no per-client or per-mission override. Config.sqf and initServer set initial defaults; Apply overwrites them.

---

## Spawnable Aircraft Classes

Aircraft are detected dynamically from `CfgVehicles` (initServer.sqf):

- **Helicopters** -- All classes inheriting from `Helicopter` with `scope >= 2`
- **Planes** -- All classes inheriting from `Plane` with `scope >= 2`
- **Sorting** -- Alphabetically by `displayName`
- **Pads** -- Helicopters: any pad. Planes: all pads except those in `heliOps_planeForbiddenPads` (Config.sqf)
- **Land vehicles** -- All `LandVehicle` classes with `scope >= 2` (excluding Air). Spawn at VEH_1/VEH_2 via `BIS_fnc_findSafePosition`.

---

## Dynamic Mission Types (Starting Points)

1. **Troop Insert** -- Insert friendly AI from B_SP_* to a randomly generated mission location. Focus on landing, formation flying, and terrain masking.
2. **Troop Extract** -- Pick up AI from a mission location and return them to base. Adds landing under pressure and coordination with ground units.
3. **CAS / Fire Support** -- Fly to a mission location and support friendly AI with guns/rockets. Suits attack helis (AH64, AH1Z, AH6M).
4. **Cargo / Resupply** -- Deliver cargo to a mission location; a small camp with garrison is spawned at the LZ; player lands at camp, an AI walks to the vehicle and confirms unload (animation + sideChat), then 60s after completion camp and units are removed.
5. **HVT** -- High value target in urban building; guards (ambient combat anim) + patrols; complete on kill or capture at base.
6. **Hostage** -- Up to 3 civilian hostages in urban building(s); 3–6 guards per hostage inside, up to 2 patrol groups (4–8 each) per building outside; hostages in `Acts_ExecutionVictim_Loop`; fail if >50% hostages die; succeed when all alive hostages within 100 m of base.
7. **Clear Area** -- Enemy-occupied town (50% chance, CIV_T_* zone) or enemy camp (50% chance, open ground). Garrison up to 35 units in buildings (max 2 per building) + 2–4 patrol groups + 1–3 enemy vehicles on roads. Succeed when ≥80% of enemy eliminated. 15-minute timeout.
8. **Intercept Convoy** -- Enemy convoy (3–6 vehicles, mix of soft/armoured) drives from a ROAD_SP_* start point to a ROAD_SP_* end point (best pair ≥2km apart). Succeed when all convoy vehicles destroyed before arrival. Convoy waypoint failure triggers "FAILED" task state.

---

## Required Classnames (To Implement Missions)

Classnames needed for dynamic mission scripting. Fill in as mods/factions are confirmed.

| Category | Purpose | Examples / Notes |
|----------|---------|------------------|
| **Friendly infantry** | Troop insert, extract, CAS support | BLUFOR unit classes for B_SP_* spawns; squad composition (TL, rifleman, medic, etc.) |
| **Enemy infantry** | CAS targets, recon spotting | OPFOR unit classes; spawn at mission locations for fire support missions |
| **Enemy vehicles** | CAS targets (optional) | Light armour, trucks; for varied CAS objectives |
| **Cargo / sling objects** | Resupply missions | Sling-load compatible: ammo crates, medical crates, supply boxes (e.g. `B_Slingload_01_Cargo_F`, `Box_NATO_Ammo_F`) |
| **Ammo / supply boxes** | Resupply payloads | Ammo, medical, general supply; must match mod set |
| **Smoke / flares** | Target marking, LZ marking | `SmokeShell`, `SmokeShellGreen`, chemlights; for player marking and AI coordination |
| **Wounded / medic** | Extract variants | Injured unit class or `ACE_medical` wounded state; for medevac-style extracts |

---

## Implemented Patterns & Callouts (Reference Before Writing New Code)

**Agents should consider these working examples before writing new code. Prefer reusing or mirroring existing patterns for consistency and to avoid regressions.**

### Text Formatting

- **Mission hints (rich text):** Use `hint parseText _string` where `_string` is structured text. The client function `FAC_heliOps_showMissionHint` (initPlayerLocal.sqf) takes one argument and runs `hint parseText (_this select 0)`. **Server → client:** build the string on the server and send it: `[format ["<t size='1.2' color='#FF6666'>TITLE</t><br/><br/><t color='#E0E0E0'>%1</t>", _msg]] remoteExec ["FAC_heliOps_showMissionHint", _player];` -- see Missions.sqf and initServer.sqf (heliOps_applyScenarioSettings, heliOps_startMission, heliOps_abortMission).
- **Structured text tags:** Use `<t size='1.2' color='#HEX'>`, `</t>`, `<br/>` for titles, body, line breaks. Error style: `#FF6666`; warning: `#FFAA00`; success/neutral: `#B0B0B0` or `#E0E0E0`; gold header: `#FFD700`.
- **systemChat (short messages):** Plain strings; no HTML. Use for spawn/despawn confirmations, validation errors. Server sends to requesting player: `["MESSAGE"] remoteExec ["systemChat", _player];` -- see initServer.sqf (heliOps_spawnHeli, heliOps_despawnVehicle, heliOps_spawnLandVehicle).
- **sideChat (in-world):** For AI/unit dialogue: `(leader _group) sideChat "Message";` -- see Missions.sqf (CAS friendlies), TroopTransport.sqf (pickup/drop messages).
- **Diary / Briefing:** HTML in strings: `<font color='#FFD700' size='14'>`, `<br/><br/>`. Create subjects and records in **rsc/Briefing.sqf**; create in reverse order so last created appears first. Run from initPlayerLocal via `execVM "rsc\Briefing.sqf"`.

### GUIs

- **Dispatcher pattern:** Each GUI has a single entry function, e.g. `FAC_vehicleGui_fnc`, with `params ["_action", "_params"];`. Switch on `_action`: `"open"`, `"onLoad"`, plus action-specific cases. **Open** checks preconditions then `if (!createDialog "RscDisplayX") then { systemChat "X GUI: RESOURCE NOT FOUND." };`. **onLoad** runs only when display exists: `findDisplay idd`, `uinamespace setVariable ["FAC_xxxGui_fnc", FAC_xxxGui_fnc];`, then populate controls and call other cases. Reference: **rsc/VehicleGui.sqf**, **rsc/MissionsGui.sqf**, **rsc/ScenarioGui.sqf**, **rsc/LoadoutGui.sqf**.
- **description.ext:** Dialog class extends `RscDisplayEmpty`; `onLoad = "[] spawn { sleep 0.01; ['onLoad', []] call (missionNamespace getVariable ['FAC_xxxGui_fnc', {}]); };";` so the config finds the function. Control actions use `(missionNamespace getVariable ['FAC_xxxGui_fnc', {}])` for the same reason. Close button: `action = "closeDialog 0;";`. Layout: Background/Title margins 0.02 / 0.96 (or 0.005/0.99 for Loadout); base controls from **rsc/BaseControls.hpp** (RscText, RscButton, RscListBox, RscEdit, RscStructuredText, RscPicture, RscCombo). **No map control** in Missions GUI (removed; caused crashes).
- **ListBox data:** Use `lbAdd` for display text, `lbSetData` for stored value (e.g. classname, missionId); read with `lbCurSel` and `lbData`. Filter lists in script; keep display name and data in sync (e.g. faction display name from LoadoutGui/VehicleGui/ScenarioGui helpers).
- **Reuse:** LoadoutGui defines `FAC_loadoutGui_getFactionDisplayName`; VehicleGui and ScenarioGui call it when available (`!isNil "FAC_loadoutGui_getFactionDisplayName"`).

### Scripts

- **Server-only scripts:** Start with `if (!isServer) exitWith {};` (initServer.sqf) or `if (!isServer) exitWith {};` after reading params (Missions.sqf, TroopTransport.sqf). Config is loaded once on server: `call compile preprocessFileLineNumbers "rsc\Config.sqf";`.
- **Mission flow:** Server sets `heliOps_missionParams` (or similar), then `execVM "rsc\Missions.sqf";`. Missions.sqf reads params, validates, then branches by mission type and calls sub-scripts (e.g. `heliOps_transportParams` → `execVM "rsc\TroopTransport.sqf"`).
- **Single source of truth:** Scenario unit/vehicle lists live in **missionNamespace** (e.g. `heliOps_friendlyUnits`, `heliOps_enemyUnits`). Set by initServer defaults and overwritten by Scenario GUI Apply (`heliOps_applyScenarioSettings`). All mission spawns read from missionNamespace; do not pass faction/unit lists from client.
- **Client GUI load order:** initPlayerLocal loads GUIs with `call compile preprocessFileLineNumbers "rsc\LoadoutGui.sqf";` (etc.), then `waitUntil { !isNil "heliOps_heliClasses" && !isNil "heliOps_boards" };` before adding board actions so server vars are replicated.
- **Night IR strobes:** `heliOps_attachNightStrobes` (Missions.sqf) attaches ACE IR strobe objects to every friendly group unit when time is 19:30–04:30 and `ace_attach` is loaded. Strobes stored in group variable `heliOps_irStrobes` for cleanup. TroopTransport.sqf cleans up strobes via `detach` + `deleteVehicle` in `_cleanup`.
- **Friendly callsigns:** `heliOps_assignGroupCallsign` (initServer) assigns a random NATO phonetic callsign (e.g. "Bravo 2-3") to each spawned group and stores it in the group variable `heliOps_callsign`. All AI sideChat references use this callsign for consistency.
- **Helipad markers:** `heliOps_updateHelipadMarkers` (initServer) updates map marker text to show the vehicle name when an aircraft is on pad, or restores the original text when the pad is empty. Runs on a 4-second poll loop (server).

### Surrender Challenge

- **Key binding:** `DIK_U` (0x16) via `displayAddEventHandler ["KeyDown", ...]` on findDisplay 46 (game HUD). Also bound via `inputAction "FAC_SurrenderChallenge"` or `inputAction "User1"` in a polling loop (fallback for custom key binds). Debounced to 1.5s.
- **Client flow:** `FAC_surrenderChallenge_fnc_activate` (initPlayerLocal) resolves the target unit from `cursorTarget` / `cursorObject` (handles weapon-mesh quirk via `attachedTo` + `nearestObjects`), plays a random `FAC_apprehend*` sound via `say3D`, then `[player, _target] remoteExec ["FAC_surrenderChallenge_start", 2]`.
- **Server flow:** `FAC_surrenderChallenge_start` (initServer, publicVariable'd) runs `SurrenderChallenge.sqf`. Validates guards (already in challenge, dead, not Man, same side, already surrendered, >25m). Freezes secondary units within 5m. Rolls surrender chance from base 0.25 + modifiers (distance, player count, angle, captive bonus, ratio malus). Civilians always surrender immediately. High-skill units may refuse immediately before animation.
- **ACE3:** If `ace_captives` is loaded, surrendered units use `ace_captives_fnc_setSurrendered` (enables escort/frisk interactions). Falls back to `setCaptive true` + surrender animation.
- **Debug:** `FAC_surrenderChallenge_debug` (initServer) and `FAC_surrenderChallenge_debugKeys` (initPlayerLocal) — both set to `false` in production. Set to `true` only for testing; they flood systemChat.

### Unit & Vehicle Spawning

- **Friendly/Enemy groups:** Use `BIS_fnc_spawnGroup`: `[_pos, side, _unitClasses] call BIS_fnc_spawnGroup`. Unit classnames from `missionNamespace getVariable ["heliOps_friendlyUnits", []]` / `heliOps_enemyUnits` (from Scenario Apply or initServer). For variety use `_units call BIS_fnc_arrayShuffle` then take a slice. Example: Missions.sqf (Troop Insert, Troop Extract, CAS).
- **Vehicles:** `createVehicle [_class, _pos, [], 0, "NONE"]`; then `setPosATL`, `setDir`, `setVehicleAmmo 1`; clear crew with `deleteVehicleCrew` for unmanned spawn. Land vehicles: use **BIS_fnc_findSafePos** for spawn position; see initServer.sqf `heliOps_spawnLandVehicle`.
- **Cleanup:** Delete units then group: `{ deleteVehicle _x } forEach units _group; deleteGroup _group`. For markers use **heliOps_deleteMarkerSafe** (initServer): `[_markerName] call heliOps_deleteMarkerSafe` -- avoids RPT errors when marker already gone. TroopTransport.sqf `_cleanup` and Missions.sqf use it. For weather use **heliOps_applyWeatherPreset**: `[_preset] call heliOps_applyWeatherPreset` (Clear/Overcast/Foggy/Rain/Storm).

### Dedicated Server & Multiplayer

- **Server guard:** `if (!isServer) exitWith {};` at top of initServer.sqf. Mission scripts (Missions.sqf, TroopTransport.sqf) also check `isServer` after reading params.
- **remoteExec targets:** Use `2` for server-only: `[args] remoteExec ["functionName", 2];`. Use `_player` to target the requesting player for feedback (systemChat, FAC_heliOps_showMissionHint). Use `0` for all clients when the result is global (e.g. scenario applied hint).
- **Server functions called from client:** Must be **publicVariable**'d on the server so clients (and JIP) can invoke them. Example: `heliOps_applyScenarioSettings`, `heliOps_startMission`, `heliOps_abortMission`, `heliOps_spawnHeli`, `FAC_surrenderChallenge_start` in initServer.sqf.
- **Client-only context:** initPlayerLocal.sqf runs **only on clients** (not on dedicated server). `cursorObject` / `cursorTarget` are client-side; the server cannot determine what the player is looking at. For target-based actions (e.g. Surrender Challenge), client gets target then `[player, _target] remoteExec ["FAC_surrenderChallenge_start", 2];`.
- **JIP:** Variables and functions that clients need (e.g. `heliOps_heliClasses`, `heliOps_boards`, `heliOps_startMission`) are publicVariable'd so joining players receive them.

### Position & Map

- **Mission position:** Use `heliOps_findMissionPos` or `heliOps_findMissionPosUrban` (initServer). LZ missions use `heliOps_findSafeLZ` for landing clearance. Do not invent new position logic without checking these.
- **Eden names:** Resolve via `missionNamespace getVariable ["BOARD_1", objNull]` etc. Server builds lists with `heliOps_collectEdenNames` from Config pad/board names.

---

## Useful BIS Functions

Reference: [Bohemia Community Wiki](https://community.bistudio.com/wiki/). To browse all BIS functions in-game: `[] spawn BIS_fnc_help` (Functions Viewer).

### Spawning & Units

| Function | Purpose |
|----------|---------|
| **BIS_fnc_spawnGroup** | Spawn dynamic groups at a position. Params: `[position, side, toSpawn, relPositions, ranks, skillRange, ammoRange, ...]`. Use for friendly AI at B_SP_* and enemies at mission locations. |
| **BIS_fnc_spawnVehicle** | Spawn vehicle with crew. Params: `[position, direction, type, sideOrGroup]`. Returns `[vehicle, crew, group]`. Use for heli spawns and enemy vehicles. |

### Tasks & Objectives

| Function | Purpose |
|----------|---------|
| **BIS_fnc_taskCreate** | Create tasks for players. Params: `[owner, taskID, description, destination, state, priority, showNotification, type, visibleIn3D]`. |
| **BIS_fnc_taskSetState** | Set task state: `[taskName, taskState, showHint]`. States: `"CREATED"`, `"ASSIGNED"`, `"SUCCEEDED"`, `"FAILED"`, `"CANCELED"`. |
| **BIS_fnc_showNotification** | Display config-defined notification popup. Params: `[template, arguments]`. |

### Waypoints & Movement

| Function | Purpose |
|----------|---------|
| **BIS_fnc_wpLand** | Make a group land at a position. Params: `[group, position, target]`. Essential for troop insert/extract AI behaviour. |

### Positions

| Function | Purpose |
|----------|---------|
| **BIS_fnc_findSafePos** | Find a valid position within min/max distance from center. Params: `[center, minDist, maxDist, objDist, waterMode, maxGrad, shoreMode, blacklistPos, defaultPos]`. Used by `heliOps_findMissionPos` for clear ground (no water, obstacles). |

### Interaction (Boards)

| Function | Purpose |
|----------|---------|
| **BIS_fnc_holdActionAdd** | Add hold-to-complete action to object (e.g. BOARD_*). Supports on start, on hold, on completion, on interruption callbacks. Use for spawn/mission selection. |

### UI & Feedback

| Function | Purpose |
|----------|---------|
| **BIS_fnc_dynamicText** | Display HUD text. Params: `[text, x, y, duration, fadeInTime, deltaY, rscLayer]`. Must be **spawned**, not called. Use for mission briefs, countdowns. |

### Randomisation

| Function | Purpose |
|----------|---------|
| **BIS_fnc_selectRandom** | Pick one random element from array. (Or use built-in `selectRandom`.) |
| **BIS_fnc_arrayShuffle** | Shuffle array. Use for randomising mission order or spawn options. |

### Multiplayer

| Function | Purpose |
|----------|---------|
| **remoteExec** | Preferred over BIS_fnc_MP. Run code on server/clients. Params: `params remoteExec [order, targets, JIP]`. |
| **BIS_fnc_MP** | Legacy remote execution. Use `remoteExec` for new scripts. |

### Cargo & Sling

| Command / Function | Purpose |
|--------------------|---------|
| **setSlingLoad** | `heli setSlingLoad cargo` -- attach sling load. `heli setSlingLoad objNull` -- detach. Requires `enableRopeAttach` on both. |
| **BIS_fnc_attachToRelative** | Attach object to another while preserving relative pose. Params: `[object1, object2, visual]`. |

---

## Known RPT Warnings (Not Mission Bugs)

These appear in the Arma 3 RPT (report) when running the mission with certain mods. They are **not caused by mission scripts** and cannot be fixed in the mission.

- **No entry '…CfgVehicles/XXX.threat'** and **[]: '/' not an array** -- The engine (or a BIS subsystem) reads a `threat` property from CfgVehicles for AI targeting. Many addon vehicle/backpack classes (e.g. CUP, SADO Crocus, Sig tropico bags, B_Simc_*) do not define it. The warning is from config, not mission SQF. Fix would require addon authors to add `threat[] = { … };` to their configs, or ignore the warnings.
- **A null object passed as a target to RemoteExec(Call) 'bis_fnc_objectvar'** -- BIS/engine code runs `bis_fnc_objectvar` on objects (e.g. for JIP/replication). When the target object has already been deleted, this message is logged. The mission does not call `bis_fnc_objectvar`; its `remoteExec` targets are players or `0`/`2`. Likely cause: another mod or engine cleanup. Safe to ignore unless tracking a specific gameplay bug.

- **Error Undefined variable in expression: bis_fnc_cp_main** and **Undefined variable: _t** -- Code somewhere (e.g. a mod such as MCC, or an object init) runs `_threat = [_this,_threatsNew] call bis_fnc_cp_main;` and a wait `time > _t`. `bis_fnc_cp_main` is a BIS Campaign function and may be missing if the campaign/DLC that provides it is not loaded or a mod expects it. When the call fails, `_t` is never set, so the wait condition then errors on `_t`. The mission does not use `bis_fnc_cp_main` or this pattern. Fix: disable or update the mod that runs this script, or ignore if no gameplay impact.

- **Error Undefined variable: hitengine** (Error compiling 'HitEngine' in 'hithull') -- From vehicle config (e.g. RHS MELB). Addon HitPoints reference a variable the config doesn’t define. Not mission script.

- **Error Undefined variable in expression: speedx / speedy / speedz** (CfgCloudlets SmallWreckSmoke.moveVelocity) -- Vanilla or addon particle config uses speedX/speedY/speedZ (case-sensitive); engine may expect different casing. Not mission script.

- **Attempt to override final function - bis_effects_muzzle_break_cannon** -- A mod (e.g. JSRS, sound/effects) tries to override a BIS function marked final. Not mission script; mod/engine load order.
- **Attempt to override final function - spe_ui_system_tank_interface_display_interface** -- Spearhead 1944 (SPE) or another mod overrides a BIS/SPE final function. Same category as above. Many "Attempt to override final function" lines (e.g. ace_*, cba_*) are from ACE/CBA and are normal with overlapping mods.

---

## Guidelines for AI Assistance

1. **Always read this file (AGENTS.md)** at the start of work on this project.
2. **Prefer existing patterns:** Before writing new code, look at the **Implemented Patterns & Callouts** section above and the referenced scripts (VehicleGui, MissionsGui, Missions.sqf, initServer, initPlayerLocal, etc.). Reuse or mirror working patterns for text formatting, GUIs, spawning, and server/client flow. The purpose is to ensure go-forward edits leverage existing best practices and avoid regressions.
3. **Always use the Arma 3 Wiki** as the **source of truth** for scripting, syntax, commands, and game systems.
4. **When unsure** about syntax or ARMA 3-specific behavior -- **check the Arma 3 Wiki** before answering.
5. Consider **execution context** -- server vs client -- and use `remoteExec` appropriately for multiplayer.
