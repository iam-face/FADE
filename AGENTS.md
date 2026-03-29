# Face's Dynamic Sandbox -- ARMA 3 Mission (Tunis)

## Project Context

This is a **helicopter piloting sandbox** for **ARMA 3**, designed for **multiplayer**. Players can use a variety of helicopters to conduct simple missions. The purpose is to allow them to practice with the airframes.

## Reference Documentation

**Arma 3 Wiki:** https://armedassault.fandom.com/wiki/ArmA_3  
**Bohemia Community Wiki:** https://community.bistudio.com/wiki/  
**Eden custom textures (per-object default sizes):** https://community.bistudio.com/wiki/Eden_Editor:_Custom_Entity_Textures
**LAMBS AI:** https://github.com/nk3nny/LambsDanger/wiki  
**KAT Medical:** https://github.com/KAT-Advanced-Medical/KAM  
**SCRIPT_INDEX.md** (repository root) — Inventory of **every mission `.sqf` file**, server vs client execution, how each file is loaded, multiplayer/dedicated-server notes, and the main `remoteExec` / `publicVariable` surface. Use alongside this document for scripting and architecture work.  
**FORMAL_SCRIPT_VERIFICATION.md** (repository root) — Formal **per-file verification matrix** (dedicated MP / server authority); update when scripts change.

Use the Wikis as the primary source for:

- **Scripting** -- SQF syntax, commands, and best practices
- **Multiplayer functionality** -- network events, server/client execution, JIP
- **Mission structure** -- `description.ext`, `mission.sqm`, init scripts
- **Event handlers** -- `onPlayerKilled.sqf`, etc. (this mission does not use player respawn.)
- **Vehicles and airframes** -- helicopter class names, flight dynamics, sling loading

---

## Debugging

- **RPT FILE** -- You have access to the Arma RPT file for debugging, it is located in the Arma 3 folder within the workspace.

## Mission Structure

For a **complete list of scripts** and how they connect in MP, see **SCRIPT_INDEX.md** in the repository root.

- **initServer.sqf** -- Server-side init: CfgVehicles scan, faction/unit caches, helper functions, vehicle spawn/despawn, mission start/abort, weather, optional Surrender Challenge RPC (disabled for players; see below), Jukebox server side.
- **initPlayerLocal.sqf** -- Client-side init: load GUI scripts, add board/loadoutbox/radio actions, welcome hint, LightTowers, Ctrl+; / Ctrl+' keybinds (missions + jukebox).
- **description.ext** -- Mission config (Header, CfgSounds, CfgIdentities, GUI dialogs). GUI dialogs defined here (RscDisplayVehicle, RscDisplayMissions, RscDisplayScenario, RscDisplayLoadout, RscDisplayJukebox).
- **Img/** -- Mission images (load screen, overview, etc.)
- **Sounds/** -- Sound files (.ogg): apprehend/Surrender-Challenge audio (retained), troop transport cues, hostage/jukebox/locker, etc.
- **rsc/Config.sqf** -- Scenario defaults (time, weather, factions, pad names, unit fallbacks, civ config).
- **rsc/Briefing.sqf** -- In-game briefing and diary records (map screen). Keep in sync with key scenario/mission changes.
- **rsc/Missions.sqf** -- All dynamic mission implementations (server-only). Branched by `_missionType`; calls TroopTransport.sqf for insert/extract. Loaded via `call compile preprocessFileLineNumbers` from `FADE_startMission` (not `execVM`).
- **rsc/TroopTransport.sqf** -- AI boarding/disembark logic for Troop Insert and Troop Extract (server-only, phase-based spawn pattern).
- **rsc/AmbientCivilians.sqf** -- Ambient civilian spawning in CIV_T_* zones and road vehicle spawning on ROAD_SP_* points.
- **rsc/EnemyAAA.sqf** -- Enemy AAA spawning (server-only). Governed by Scenario GUI "Enemy AAA" level: None = no spawns; Light/Medium/Heavy = up to 5 AA units near random CIV_T_* zones: spawn within **500 m** of civ center using **BIS_fnc_findSafePos** (clear of buildings/water); turret/vehicle **oriented toward BASE_1**. MANPADS = 25% chance per active civ zone, max 2 infantry with shoulder-launched AA per zone, non-respawning, SAD waypoint at spawn. **AA assets are resolved from the Scenario GUI enemy faction**: static HMG/GMG (Light), AA vehicles (Medium/Heavy), MANPADS infantry (unit with Titan/Stinger/Igla or launch_*aa* in weapons); vanilla East classnames used as fallback when faction has no match.
- **rsc/SurrenderChallenge.sqf** -- Surrender challenge logic (server-side); **not used by players** while `FAC_surrenderChallenge_playerEnabled` is false (see Surrender Challenge section). ACE3 captives integration when enabled.
- **rsc/LightTowers.sqf** -- Invisible ambient lights 25 m above each helipad and vehicle spawn point (client-side, spawned from initPlayerLocal).
- **rsc/VehicleGui.sqf** -- Manage Vehicles GUI logic.
- **rsc/MissionsGui.sqf** -- Manage Missions GUI logic.
- **rsc/ScenarioGui.sqf** -- Manage Scenario GUI logic (weather, time, factions, limit gear).
- **rsc/LoadoutGui.sqf** -- Manage My Loadout GUI logic.
- **rsc/JukeboxGui.sqf** -- Jukebox GUI logic (per-source: `Radio_1`–`Radio_4` and Ctrl+' personal). Track list, play/stop, now-playing display.
- **rsc/CQBGui.sqf** -- CQB Training Shoothouse GUI (cqbBoard). Config: enemy type (targets/real), density, civilians; start/end drill.
- **rsc/TeleportGui.sqf** -- Fast Travel GUI (teleportBoard_1..8). Select destination from list; player is teleported 5 m behind the target Eden object (facing it). Destinations defined in `FAC_teleportGui_destinations`.
- **rsc/BaseControls.hpp** -- Shared base control class definitions (included in description.ext).
- **SoundEvents.md** -- Documents the sound events / OGG files used by CfgSounds.

### Custom GUIs (Boards / Loadout / Jukebox)

Dialogs are defined in **description.ext** (RscDisplayVehicle idd=60001, RscDisplayMissions idd=60002, RscDisplayScenario idd=60003, RscDisplayLoadout idd=60200, RscDisplayJukebox idd=60400, RscDisplayCQB idd=60500, RscDisplayTeleport idd=60600). Logic lives in **rsc/*Gui.sqf** (VehicleGui, MissionsGui, ScenarioGui, LoadoutGui, JukeboxGui, CQBGui, TeleportGui), all loaded via `call compile preprocessFileLineNumbers` in initPlayerLocal.sqf. For consistency:

- **Open**: Each GUI has an `"open"` case that checks preconditions (if any), then `if (!createDialog "RscDisplayX") then { systemChat "X GUI: RESOURCE NOT FOUND." };`.
- **onLoad**: All use `onLoad = "[] spawn { sleep 0.01; ['onLoad', []] call (missionNamespace getVariable ['FAC_xxxGui_fnc', {}]); };";` and in onLoad set `uinamespace setVariable ["FAC_xxxGui_fnc", FAC_xxxGui_fnc]` so config callbacks find the function.
- **Layout**: Background/Title use margins 0.02 / 0.96 (or 0.005/0.99 for Loadout). Close button action: `closeDialog 0;`. Base controls come from **rsc/BaseControls.hpp** (included in description.ext). Missions GUI has no map control (map was removed; it caused crashes).
- **Faction display names**: LoadoutGui defines `FAC_loadoutGui_getFactionDisplayName`; VehicleGui and ScenarioGui reuse it when available.
- **Jukebox (RscDisplayJukebox):** Opened via **Jukebox** actions on `Radio_1`–`Radio_4` (optional Eden objects) or **Ctrl+'** (sound follows the player). Tracks in `FAC_jukebox_tracks` (JukeboxGui.sqf). Play sends `[_class, _sourceKey, player] remoteExec ["FAC_jukebox_serverPlay", 2]`; server stores `FAC_jukebox_activeSources` and `remoteExec`s `FAC_jukebox_clientPlay` with `[_song, _sourceKey]` to all clients. Each source has at most one track; multiple sources may play at once. JIP clients replay from `FAC_jukebox_activeSources`. Stop sends `["", _sourceKey, player] remoteExec [...]`. `FAC_jukebox_serverPlay` is in initServer.sqf and publicVariable'd. **Volume / max distance:** `description.ext` **CfgSounds** `Sig_*` (`sound[]` 2nd and 4th numbers); keep **JukeboxGui.sqf** `FAC_jukebox_soundVolumeMission` / `FAC_jukebox_soundDistanceMission` aligned (documentation anchor).

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

- **BASE_1** -- Defines the player base (centre of map). Used for base position, respawn, mission distance checks, and 1 km exclusion for ambient enemy patrols (no patrol spawn in CIV_T_* zones within 1 km of base).
- **Boards** -- Eden object names and behaviour (textures set in initServer under `img\`; actions in initPlayerLocal where noted):
  - **vehBoard** -- Interactable. **Manage Vehicles** action; texture `img\vehicles2.jpg`.
  - **missionBoard** -- Interactable. **Manage Missions** and **Manage Scenario** actions; texture `img\laptopScenario.jpg`.
  - **cqbBoard** -- Optional, interactable. **CQB Training** action opens CQB GUI; texture `img\laptopCQB.jpg`. Server spawns at **CQB_POS_*** positions.
  - **baseBoard_1**, **baseBoard_2**, **baseBoard_3** -- Non-interactable large billboards (Land_Billboard_F); texture `img\baseBoards.jpg`.
  - **hqMainBoard** -- Non-interactable; texture `img\hqMainBoard.jpg`.
  - **canvas_1**, **canvas_3** -- Non-interactable; texture `img\flagCTB.jpg`.
  - **canvas_2** -- Non-interactable; texture `img\flagAustralia.jpg`.
  - **canvas_4** -- Non-interactable; texture `img\missionsconfig.jpg`.
  - **whiteboardAdmin** -- Non-interactable **Land_MapBoard_01_Wall_F**; texture `img\whiteboardAdmin.jpg` (`_applyBoardTextureMapWall` in initServer).
  - **bannerSDE** -- Non-interactable; texture `img\bannerSDE.jpg`.
  - **sdeArt_1** -- Non-interactable; texture `img\letsgo.jpg`.
  - **loadoutboard_1**, **loadoutboard_3**, **loadoutboard_4** -- Non-interactable **Land_MapBoard_01_Wall_F**; texture `img\whiteboardLoadouts.jpg` (Eden names lowercase `board` to match **mission.sqm**). initServer resolves each board via `missionNamespace` **or** `vehicleVarName` scan on `allMissionObjects "Land_MapBoard_01_Wall_F"`, applies slot **0**, then **re-applies at 0.5 s and 2.5 s** (spawn) so textures win over late Eden init. If they stay blank while **whiteboardAdmin** shows art, confirm **`img\whiteboardLoadouts.jpg`** exists in the mission folder and uses a valid resolution (wiki default for this class is **2048×2048** for the map face — match aspect like **whiteboardAdmin.jpg**).
  - **loadoutBoard_2** -- Non-interactable sign; texture `img\loadouts.jpg`.
  - **musicBoard** -- Non-interactable, next to jukebox; texture `img\music.jpg`.
  - **firingRangeBoard**, **signFire_1** -- Non-interactable firing range signs; texture `img\signLiveFire.jpg`.
  - **teleportBoard_1** … **teleportBoard_8** -- Interactable. **Fast Travel** action opens Teleport GUI (rsc/TeleportGui.sqf); texture `img\teleporter.jpg` on all boards. Fast-travel list preview for SDE's Pub uses `img\teleport_SDE.jpg` (see TeleportGui overrides). Destinations: Base (BASE_1), Medical Area (MEDICAL_1), Pads 3–5 (HP_4), Firing Range, CQB Killhouse, Vehicle Pad 2 (VEH_2), CTB Locker Room (teleportBoard_7), SDE's Pub (teleportBoard_8).

### Eden custom textures: objects and sizes (validation)

**Source of truth:** [Eden Editor: Custom Entity Textures](https://community.bistudio.com/wiki/Eden_Editor:_Custom_Entity_Textures) (Bohemia Community Wiki). It lists entities that support Eden **Custom textures** / `setObjectTexture`, with each **texture slot**, **default `.paa` path**, and **Default Texture Size**.

**Why:** Custom mission art (`img\*.jpg` applied in initServer, or textures set in Eden) is mapped to each model’s UVs. If your image **aspect ratio or proportions** do not match what the object expects, you get stretched, squashed, or cropped signage. Use the wiki row for the **exact** object classname to align new textures with vanilla defaults.

**Workflow:** (1) Note the **CfgVehicles** classname of the billboard/sign/object in Eden (e.g. **Land_Billboard_F** for large billboards). (2) Find that classname in the wiki’s tables and read **Default Texture Size** (and which slot is **Texture #0**, **#1**, … if multiple). (3) Author replacement images at the **same aspect ratio** as the documented default; prefer **power-of-two** width and height where possible (engine texture guidance; see also [setObjectTexture](https://community.bistudio.com/wiki/setObjectTexture)). (4) Verify in-game after applying the texture.

**Mission.sqm ∩ wiki (custom-texture entities):** The following **classnames** appear in **mission.sqm** and are listed on [Eden Editor: Custom Entity Textures](https://community.bistudio.com/wiki/Eden_Editor:_Custom_Entity_Textures). **Eden display name** and **default texture sizes** are taken from that page (re-check if Bohemia updates the table). Where the default is procedural, **Default Texture Size** is **N/A** in the wiki—there is no raster dimension to match; use Eden preview or config paths on the wiki row.

| Eden display name | Classname | Default texture size(s) (wiki) |
| --- | --- | --- |
| Banner | `Banner_01_F` | Texture #0: **512×256** |
| Canvas (Medium, Landscape) | `Canvas_01_Landscape_F` | Texture #0: **2048×1024** |
| Canvas (Large) | `Canvas_01_Large_F` | Texture #0: **2048×1024** |
| Billboard 1 (Blank) | `Land_Billboard_F` | Texture #0: **256×256** |
| Briefing Room Screen | `Land_BriefingRoomScreen_01_F` | Texture #0: **2048×2048** |
| Laptop (Open, Intel v2) | `Land_Laptop_Intel_02_F` | Texture #0: **1024×512** |
| Sleeved Map (Livonia) | `Land_Map_unfolded_Enoch_F` | Texture #0: **512×512** |
| Whiteboard (Empty, Wall) | `Land_MapBoard_01_Wall_F` | Texture #0: **2048×2048** |
| Notepad | `Land_Notepad_F` | Texture #0: procedural (**N/A**) |
| PC Set (Screen, Intel v2) | `Land_PCSet_Intel_02_F` | Texture #0: **1024×1024** |
| Rugged Dual Screen (Black, Horizontal) | `Land_TripodScreen_01_dual_v1_black_F` | Texture #0–#1: **N/A**; Texture #2: **2048×2048** (screen) |
| VR Obstacle (10x5x4) | `Land_VR_Block_05_F` | Texture #0–#1: procedural (**N/A**) |
| Rugged Communications Terminal (Large) | `RuggedTerminal_02_communications_F` | Texture #0: **1024×1024**; Texture #1–#2: **N/A**; Texture #3–#7: **2048×2048** |
| Sign (Sponsor) | `SignAd_Sponsor_F` | Texture #0: **1024×512** |

**Also in mission.sqm but not on that wiki list** (no official per-slot default sizes there): e.g. `Land_LandMark_F`, `ContainmentArea_01_sand_F`, `Land_SignM_WarningMilAreaSmall_english_F`, `Sig_Flag_CTB`, `TargetP_*`, `PLP_spotlight_screen`, and most modded / DLC props—use object config, Eden preview, or trial in-game.

- **CQB_POS_*** -- Optional. Eden triggers or objects defining CQB drill positions (e.g. `CQB_POS_1`, `CQB_POS_2`, …). Listed in `FADE_cqbPosNames` (Config.sqf). Spawned units/targets adopt each position's `getDir`. Used only when a drill is started from the CQB GUI. Density: Low 20%, Medium 33%, High 50% per position; civilians 15% per spawn when enabled. Targets use `noPop` so they do not pop back up when shot; real enemies use `disableAI "PATH"` and scenario enemy/civ factions.
- **LOADOUTBOX** / **LOADOUTBOX_2** / **LOADOUTBOX_3** (and any in **FADE_loadoutBoxNames**, Config.sqf) -- Loadout boxes. Each gets **Manage My Loadout** (custom GUI), **Save my loadout**, **Open ACE Arsenal** (if ACE3 loaded). All are ACE arsenal-init'd on the server when ACE is present. Add more Eden names to `FADE_loadoutBoxNames` to give new boxes the same actions.
- **Radio_1**, **Radio_2**, **Radio_3**, **Radio_4** -- Optional jukebox radio objects (same behaviour per object). Each receives **Jukebox** (initPlayerLocal); playback is 3D at that object. **Ctrl+'** opens the same GUI with sound attached to the player (`player:<UID>` source). Texture `img\laptopJukebox.jpg` (initServer).
- **LOCKER_1** -- Optional. Locker room interaction point. If present in Eden, receives **Locker room** action (initPlayerLocal); plays sound (CfgSounds FAC_LockerSlap or fallback) and local flavour message. Add `Sounds\locker_slap.ogg` for custom slap sound.
- **Helipads** -- `HP_1` through `HP_8`. Objects where aircraft spawn. Configured in `FADE_padNames` (Config.sqf). Planes cannot spawn at pads in `FADE_planeForbiddenPads` (default: HP_1, HP_2). Helipad markers (map) are updated by `FADE_updateHelipadMarkers` periodically.
- **Vehicle spawn points** -- `VEH_1`, `VEH_2`. Land vehicles spawn here using `BIS_fnc_findSafePos` for dynamic placement.
- **Friendly AI infantry spawn points** -- `B_SP_1`, `B_SP_2`, `B_SP_3`. Used for Troop Insert pickup at base and Troop Extract walk-back point.
- **Civilian zone triggers** -- `CIV_T_1`, `CIV_T_2`, etc. Used by AmbientCivilians.sqf for proximity-based civ spawning and by `FADE_findMissionPosUrban` for HVT/Hostage/ClearArea placement.
- **Road spawn points** -- `ROAD_SP_1` through `ROAD_SP_25`. Used by AmbientCivilians.sqf for road vehicle spawning and by Intercept Convoy for start/end positions.
- **CargoPoint_1** -- Map marker position. Cargo/Resupply mission spawns the sling-load box here. Falls back to base position if marker not found.
- **MEDICAL_1** -- Optional. Object (e.g. flag or marker) defining the medical/MASCAS mission location. Medical and MASCAS missions spawn BLUFOR casualties here (findSafePos); units spawn conscious/standing and receive varied injuries (ACE addDamageToUnit/addWound/setUnconscious when ACE/KAT present). If absent, those mission types show an error.
- **Mission locations** -- Generated dynamically by `FADE_findMissionPos`: within map bounds (X/Y 500-9500), at least 700m from base (1000m for enemy missions), using `BIS_fnc_findSafePos` for clear ground. Urban missions use `FADE_findMissionPosUrban` (CIV_T_* zones). All mission positions are at least 2 km apart (`FADE_minDistBetweenMissions`). **Mission streams:** Global (one at a time: AO, Hostage, HVT, Clear Area, CAS, Intercept Convoy) and Single (up to 3 at a time: Insert, Extract, Cargo, Mine Clearing, Find and Clear IEDs, Medical, MedicalKAT, MASCAS, MASCASKAT).

---

## Scenario Settings (Manage Scenario GUI)

Players can configure scenario-wide settings via **Manage Scenario** on the board:

- **Environment** -- Time of day (0000–2300), Weather (Clear, Overcast, Foggy, Rain, Storm), Limit gear (TRUE/FALSE).
- **Enemy AI** -- Patrols (ON/OFF), AI skill (Low/Medium/High/Very High), Routing (ON/OFF), AAA (None/Light/Medium/MANPADS/Heavy), AO - Strength (Low/Mid/High). AO Strength sets `FADE_aoStrength` for the Area of Operations mission type (expand later).
- **Factions** (order: Friendly, Enemy, Civilian) -- Friendly: BLUFOR (side 1) for Troop Insert/Extract, CAS support. Enemy: OPFOR (side 0) for CAS, Clear Area, HVT, Hostage, Intercept Convoy, etc. Civilian: side 3 for ambient civilians (CIV_T_* zones, ROAD_SP_* vehicles).
- **Civilians enabled** -- TRUE/FALSE. When FALSE, no ambient civilians spawn (zones, road vehicles, civ aircraft). Governs all civilian presence.

**Scenario choices are server-side and global:** when a player clicks **Apply**, the server runs `FADE_applyScenarioSettings`, which rebuilds unit/vehicle arrays from the chosen factions and stores them in `missionNamespace`. All mission spawns (Missions.sqf, AmbientCivilians.sqf) read these arrays from `missionNamespace`; there is no per-client or per-mission override. Config.sqf and initServer set initial defaults; Apply overwrites them. **AO: AI JTAC** (Manage Scenario) is a TRUE/FALSE option defaulting to true; when false, the Area of Operations mission does not spawn the AI JTAC unit or its radio call (`FADE_aoJtacEnabled`). **AO - Strength** (Low/Mid/High) sets `FADE_aoStrength` for the AO mission type to use when expanding (e.g. enemy count, objectives).

---

## Spawnable Aircraft Classes

Aircraft are detected dynamically from `CfgVehicles` (initServer.sqf):

- **Helicopters** -- All classes inheriting from `Helicopter` with `scope >= 2`
- **Planes** -- All classes inheriting from `Plane` with `scope >= 2`
- **Sorting** -- Alphabetically by `displayName`
- **Pads** -- Helicopters: any pad. Planes: all pads except those in `FADE_planeForbiddenPads` (Config.sqf)
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
9. **Area of Operations (AO)** -- AO centre from a CIV_T_* zone **at least 2500 m from BASE_1** (never overlap base); if none, from `FADE_findMissionPos(2500)` or mission fails. Zone **2 km × 2 km square**, rotated by attack axis. Three objectives spread inside: OBJ 1 ~500 m from centre toward BLUFOR edge, OBJ 2 at centre, OBJ 3 ~500 m toward OPFOR edge. BLUFOR spawn **100 m outside** one edge (not on OBJ 1); OPFOR: **static group on each OBJ** (at/near the point) plus **patrol group around each OBJ**. Compositions at OBJs when few buildings. Capture when BLUFOR holds all 3; 30 min timeout. See **rsc/AOMission.sqf**.
10. **Medical / MASCAS** -- BLUFOR casualties at MEDICAL_1. Units spawn **conscious and standing** with 0 base damage; injuries are applied via **ACE Medical** when present (Medical and MedicalKAT/MASCAS): `ace_medical_fnc_addDamageToUnit`, `ace_medical_fnc_addWound` (Laceration, VelocityWound, Avulsion on body/limbs), and ~35% chance `ace_medical_fnc_setUnconscious` per unit. Severity varies (light / heavy / critical). Without ACE, fallback is vanilla `setDamage`. Success when all alive and (ACE: `ace_medical_fnc_isInStableCondition`; else damage < 0.01). Fail if >50% die.

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

- **Mission hints (rich text):** Use `hint parseText _string` where `_string` is structured text. The client function `FADE_showMissionHint` (initPlayerLocal.sqf) takes one argument and runs `hint parseText (_this select 0)`. **Server → client:** build the string on the server and send it: `[format ["<t size='1.2' color='#FF6666'>TITLE</t><br/><br/><t color='#E0E0E0'>%1</t>", _msg]] remoteExec ["FADE_showMissionHint", _player];` -- see Missions.sqf and initServer.sqf (FADE_applyScenarioSettings, FADE_startMission, FADE_abortMission).
- **Structured text tags:** Use `<t size='1.2' color='#HEX'>`, `</t>`, `<br/>` for titles, body, line breaks. Error style: `#FF6666`; warning: `#FFAA00`; success/neutral: `#B0B0B0` or `#E0E0E0`; gold header: `#FFD700`.
- **systemChat (short messages):** Plain strings; no HTML. Use for spawn/despawn confirmations, validation errors. Server sends to requesting player: `["MESSAGE"] remoteExec ["systemChat", _player];` -- see initServer.sqf (FADE_spawnHeli, FADE_despawnVehicle, FADE_spawnLandVehicle).
- **sideChat (in-world):** For AI/unit dialogue: `(leader _group) sideChat "Message";` -- see Missions.sqf (CAS friendlies), TroopTransport.sqf (pickup/drop messages).
- **Diary / Briefing:** HTML in strings: `<font color='#FFD700' size='14'>`, `<br/><br/>`. Create subjects and records in **rsc/Briefing.sqf**; create in reverse order so last created appears first. Run from initPlayerLocal via `execVM "rsc\Briefing.sqf"`.

### GUIs

- **Dispatcher pattern:** Each GUI has a single entry function, e.g. `FAC_vehicleGui_fnc`, with `params ["_action", "_params"];`. Switch on `_action`: `"open"`, `"onLoad"`, plus action-specific cases. **Open** checks preconditions then `if (!createDialog "RscDisplayX") then { systemChat "X GUI: RESOURCE NOT FOUND." };`. **onLoad** runs only when display exists: `findDisplay idd`, `uinamespace setVariable ["FAC_xxxGui_fnc", FAC_xxxGui_fnc];`, then populate controls and call other cases. Reference: **rsc/VehicleGui.sqf**, **rsc/MissionsGui.sqf**, **rsc/ScenarioGui.sqf**, **rsc/LoadoutGui.sqf**.
- **description.ext:** Dialog class extends `RscDisplayEmpty`; `onLoad = "[] spawn { sleep 0.01; ['onLoad', []] call (missionNamespace getVariable ['FAC_xxxGui_fnc', {}]); };";` so the config finds the function. Control actions use `(missionNamespace getVariable ['FAC_xxxGui_fnc', {}])` for the same reason. Close button: `action = "closeDialog 0;";`. Layout: Background/Title margins 0.02 / 0.96 (or 0.005/0.99 for Loadout); base controls from **rsc/BaseControls.hpp** (RscText, RscButton, RscListBox, RscEdit, RscStructuredText, RscPicture, RscCombo). **No map control** in Missions GUI (removed; caused crashes).
- **ListBox data:** Use `lbAdd` for display text, `lbSetData` for stored value (e.g. classname, missionId); read with `lbCurSel` and `lbData`. Filter lists in script; keep display name and data in sync (e.g. faction display name from LoadoutGui/VehicleGui/ScenarioGui helpers).
- **Reuse:** LoadoutGui defines `FAC_loadoutGui_getFactionDisplayName`; VehicleGui and ScenarioGui call it when available (`!isNil "FAC_loadoutGui_getFactionDisplayName"`).

### Scripts

- **Server-only scripts:** Start with `if (!isServer) exitWith {};` (initServer.sqf) or `if (!isServer) exitWith {};` after reading params (Missions.sqf, TroopTransport.sqf). Config is loaded once on server: `call compile preprocessFileLineNumbers "rsc\Config.sqf";`.
- **Mission flow:** Server sets `FADE_missionParams`, then `call compile preprocessFileLineNumbers "rsc\Missions.sqf";`. Missions.sqf reads params, validates, then branches by mission type and calls sub-scripts (e.g. `FADE_transportParams` → `execVM "rsc\TroopTransport.sqf"`).
- **Single source of truth:** Scenario unit/vehicle lists live in **missionNamespace** (e.g. `FADE_friendlyUnits`, `FADE_enemyUnits`). Set by initServer defaults and overwritten by Scenario GUI Apply (`FADE_applyScenarioSettings`). All mission spawns read from missionNamespace; do not pass faction/unit lists from client.
- **Client GUI load order:** initPlayerLocal loads GUIs with `call compile preprocessFileLineNumbers "rsc\LoadoutGui.sqf";` (etc.), then `waitUntil { !isNil "FADE_heliClasses" && !isNil "FADE_boards" };` before adding board actions so server vars are replicated.
- **Night IR strobes:** `FADE_attachNightStrobes` (Missions.sqf) attaches ACE IR strobe objects to every friendly group unit when time is 19:30–04:30 and `ace_attach` is loaded. Strobes stored in group variable `FADE_irStrobes` for cleanup. TroopTransport.sqf cleans up strobes via `detach` + `deleteVehicle` in `_cleanup`.
- **Friendly callsigns:** `FADE_assignGroupCallsign` (initServer) assigns a random NATO phonetic callsign (e.g. "Bravo 2-3") to each spawned group and stores it in the group variable `FADE_callsign`. All AI sideChat references use this callsign for consistency.
- **Helipad markers:** `FADE_updateHelipadMarkers` (initServer) updates map marker text to show the vehicle name when an aircraft is on pad, or restores the original text when the pad is empty. Runs on a 4-second poll loop (server).

### Surrender Challenge (player-facing disabled)

- **Production default:** `FAC_surrenderChallenge_playerEnabled = false` in **initServer.sqf** (publicVariable). **Client** `FAC_surrenderChallenge_fnc_activate` and **server** `FAC_surrenderChallenge_start` exit immediately when this flag is false — no hotkey, no CfgUserActions, no U-key or inputAction polling. **rsc/SurrenderChallenge.sqf** and CfgSounds entries remain for future re-enable.
- **To re-enable for players:** set `FAC_surrenderChallenge_playerEnabled = true`, restore **CfgUserActions** `FAC_SurrenderChallenge` in **description.ext**, re-add **DIK_U** handling and the `inputAction` polling loop in **initPlayerLocal.sqf** (see git history), and restore welcome-hint line if desired.
- **When enabled — client flow:** `FAC_surrenderChallenge_fnc_activate` resolves target from `cursorTarget` / `cursorObject` (`attachedTo` + `nearestObjects`), plays `FAC_apprehend*` via `say3D`, then `[player, _target, getDir player] remoteExec ["FAC_surrenderChallenge_start", 2]`.
- **When enabled — server flow:** `FAC_surrenderChallenge_start` runs `SurrenderChallenge.sqf` (validation, roll, ACE `ace_captives_fnc_setSurrendered` or fallback animation).
- **Debug:** `FAC_surrenderChallenge_debug` (initServer) and `FAC_surrenderChallenge_debugKeys` (initPlayerLocal) — default `false`.

### Enemy Retreat (50% threshold)

- **Trigger:** For all mission types that spawn enemy units, when 50% of those enemies have been killed, every remaining enemy gets one chance to retreat. Implemented in **initServer.sqf**: `FADE_registerEnemyRetreat` (call once per mission with array of enemy groups and base position) and `FADE_doEnemyRetreat` (applies the behaviour).
- **Check interval:** The 50% condition is evaluated every **FADE_retreatCheckInterval** seconds (default **10**). One spawned thread per mission; thread exits after retreat runs. Skips registration when total enemies ≤ 1.
- **Debug:** Set `FADE_retreatDebug = true` in initServer (or before first mission) to get systemChat messages: registration (groups/total/interval), 50% met (alive/initial), per-unit decision (RETREAT/STAY and roll vs chance), per-group summary (retreating vs staying), and done. Can be chatty with many units.
- **Dedicated server:** Logic runs entirely on the server (initServer and Missions.sqf are server-only); no client or JIP dependency for the check.
- **Retreat chance:** Per unit, based on scenario enemy skill (`FADE_enemySkill`): skill 0 → 100% retreat, skill 1 → 0% retreat, linear in between (e.g. 0.5 → 50%).
- **Behaviour:** Units that roll retreat have **all group waypoints cleared first** (retreat replaces orders, does not append). Then each retreating unit receives `doMove` to a position 2 km away from the player base (direction = opposite to base, i.e. unit getDir base + 180°). Group speed set to FULL. Applied in: Troop Extract, CAS, HVT (guards/patrols only), Hostage (guards/patrols only), Clear Area, Intercept Convoy, Area of Operations.

### Unit & Vehicle Spawning

- **Friendly/Enemy groups:** Use `BIS_fnc_spawnGroup`: `[_pos, side, _unitClasses] call BIS_fnc_spawnGroup`. Unit classnames from `missionNamespace getVariable ["FADE_friendlyUnits", []]` / `FADE_enemyUnits` (from Scenario Apply or initServer). For variety use `_units call BIS_fnc_arrayShuffle` then take a slice. Example: Missions.sqf (Troop Insert, Troop Extract, CAS).
- **Vehicles:** `createVehicle [_class, _pos, [], 0, "NONE"]`; then `setPosATL`, `setDir`, `setVehicleAmmo 1`; clear crew with `deleteVehicleCrew` for unmanned spawn. Land vehicles: use **BIS_fnc_findSafePos** for spawn position; see initServer.sqf `FADE_spawnLandVehicle`.
- **Cleanup:** Delete units then group: `{ deleteVehicle _x } forEach units _group; deleteGroup _group`. For markers use **FADE_deleteMarkerSafe** (initServer): `[_markerName] call FADE_deleteMarkerSafe` -- avoids RPT errors when marker already gone. TroopTransport.sqf `_cleanup` and Missions.sqf use it. For weather use **FADE_applyWeatherPreset**: `[_preset] call FADE_applyWeatherPreset` (Clear/Overcast/Foggy/Rain/Storm).

### Dedicated Server & Multiplayer

- **Server guard:** `if (!isServer) exitWith {};` at top of initServer.sqf. Mission scripts (Missions.sqf, TroopTransport.sqf) also check `isServer` after reading params.
- **remoteExec targets:** Use `2` for server-only: `[args] remoteExec ["functionName", 2];`. Use `_player` to target the requesting player for feedback (systemChat, FADE_showMissionHint). Use `0` for all clients when the result is global (e.g. scenario applied hint).
- **Server functions called from client:** Must be **publicVariable**'d on the server so clients (and JIP) can invoke them. Example: `FADE_applyScenarioSettings`, `FADE_startMission`, `FADE_abortMission`, `FADE_spawnHeli`, `FAC_surrenderChallenge_start` in initServer.sqf (surrender RPC no-ops while `FAC_surrenderChallenge_playerEnabled` is false).
- **Client-only context:** initPlayerLocal.sqf runs **only on clients** (not on dedicated server). `cursorObject` / `cursorTarget` are client-side; the server cannot determine what the player is looking at.
- **JIP:** Variables and functions that clients need (e.g. `FADE_heliClasses`, `FADE_boards`, `FADE_startMission`) are publicVariable'd so joining players receive them.

### Position & Map

- **Mission position:** Use `FADE_findMissionPos` or `FADE_findMissionPosUrban` (initServer). LZ missions use `FADE_findSafeLZ` for landing clearance. Do not invent new position logic without checking these.
- **Eden names:** Resolve via `missionNamespace getVariable ["BOARD_1", objNull]` etc. Server builds lists with `FADE_collectEdenNames` from Config pad/board names.

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
| **BIS_fnc_findSafePos** | Find a valid position within min/max distance from center. Params: `[center, minDist, maxDist, objDist, waterMode, maxGrad, shoreMode, blacklistPos, defaultPos]`. Used by `FADE_findMissionPos` for clear ground (no water, obstacles). |

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
- **A null object passed as a target to RemoteExec(Call) 'bis_fnc_objectvar'** -- BIS/engine code runs `bis_fnc_objectvar` on objects (e.g. for JIP/replication of object identity). When the target object has already been deleted, this message is logged. Often appears when shooting/killing enemies: hit or death triggers replication, but the unit can be deleted (e.g. by mission cleanup or engine) before the RemoteExec runs. The mission does not call `bis_fnc_objectvar`; its `remoteExec` targets are players or `0`/`2`. Not fixable in mission code; safe to ignore unless tracking a specific gameplay bug.

- **Error Undefined variable in expression: bis_fnc_cp_main** and **Undefined variable: _t** -- Code somewhere (e.g. a mod such as MCC, or an object init) runs `_threat = [_this,_threatsNew] call bis_fnc_cp_main;` and a wait `time > _t`. `bis_fnc_cp_main` is a BIS Campaign function and may be missing if the campaign/DLC that provides it is not loaded or a mod expects it. When the call fails, `_t` is never set, so the wait condition then errors on `_t`. The mission does not use `bis_fnc_cp_main` or this pattern. Fix: disable or update the mod that runs this script, or ignore if no gameplay impact.
- **Error Undefined variable in expression: bis_fnc_cp_getQueueDelay** and **Undefined variable: _t** -- Same family as above. Some script (mod or object init) runs code that calls `_this call bis_fnc_cp_getQueueDelay` and then waits on `time > _t`. `bis_fnc_cp_getQueueDelay` is a BIS Campaign function (cp = campaign) and is not present in the main game; when the call fails, `_t` is never set and the subsequent `time > _t` check errors repeatedly. The mission does not call any `bis_fnc_cp_*` functions. **To find the caller:** use **rsc/DebugBIScpStub.sqf** (run from initServer and initPlayerLocal): it installs stubs that log to RPT with `diag_stacktrace` when the function is called. Search RPT for `[FADE BIS CP DEBUG]` to see the call stack. Set `FADE_debugBIScp = false` before the stub runs to disable. Fix: identify and disable/update the mod that invokes campaign code, or ignore if no gameplay impact.

- **Error Undefined variable: hitengine** (Error compiling 'HitEngine' in 'hithull') -- From vehicle config (e.g. RHS MELB). Addon HitPoints reference a variable the config doesn’t define. Not mission script.

- **Error Undefined variable in expression: speedx / speedy / speedz** (CfgCloudlets SmallWreckSmoke.moveVelocity) -- Vanilla or addon particle config uses speedX/speedY/speedZ (case-sensitive); engine may expect different casing. Not mission script.

- **Attempt to override final function - bis_effects_muzzle_break_cannon** -- A mod (e.g. JSRS, sound/effects) tries to override a BIS function marked final. Not mission script; mod/engine load order.
- **Attempt to override final function - spe_ui_system_tank_interface_display_interface** -- Spearhead 1944 (SPE) or another mod overrides a BIS/SPE final function. Same category as above. Many "Attempt to override final function" lines (e.g. ace_*, cba_*) are from ACE/CBA and are normal with overlapping mods.

---

## Guidelines for AI Assistance

1. **Always read this file (AGENTS.md)** at the start of work on this project. For script inventory and execution/network scope, read **SCRIPT_INDEX.md**; for verification status and the formal checklist, read **FORMAL_SCRIPT_VERIFICATION.md** when changing or adding `.sqf` files.
2. **Prefer existing patterns:** Before writing new code, look at the **Implemented Patterns & Callouts** section above and the referenced scripts (VehicleGui, MissionsGui, Missions.sqf, initServer, initPlayerLocal, etc.). Reuse or mirror working patterns for text formatting, GUIs, spawning, and server/client flow. The purpose is to ensure go-forward edits leverage existing best practices and avoid regressions.
3. **Always use the Arma 3 Wiki** as the **source of truth** for scripting, syntax, commands, and game systems.
4. **When unsure** about syntax or ARMA 3-specific behavior -- **check the Arma 3 Wiki** before answering.
5. Consider **execution context** -- server vs client -- and use `remoteExec` appropriately for multiplayer.
