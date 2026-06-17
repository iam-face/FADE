# FADE (Face’s Dynamic Environment)

**Beta 4** — sandbox for broad community use. No Zeus required. In-game boards and GUIs drive scenario options and dynamic missions so players can run and tailor sessions quickly. Built for **rotary piloting**, **joint fires**, and **infantry training** in **Arma 3** multiplayer (listen or dedicated server).

**Map:** Altis (this repository folder: `FAC_FADE.Altis`). **Slots:** up to **31** players (`description.ext` / `mission.sqm`).

---

## Features


| Feature                        | Description                                                                                                                                                                                                                                                       |
| ------------------------------ | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| **Scenario management**        | Weather, time of day, friendly/enemy/civilian factions, gear/loadout limits, time compression. Enemy AI: patrols, skill, routing, AAA level, AO strength. Server applies and broadcasts. **Lobby params** (`description.ext` **Params**, `rsc/FAC_LobbyParams.sqf`) set access gates (Missions / Scenario / Vehicle / Loadout GUIs, Fast Travel teleport-to-player, Scenario Admin tab, jukebox, ACE Arsenal) and starting defaults (civilians, OPFOR threat, gear policy, time/weather, civ talk, intel read, AO strength, HQ auto-heal, script debug tools). Group leaders and admin/Zeus override most leader-only locks. |
| **Missions**                   | **16** dynamic types — see [Mission types](#mission-types). **[G]** = one global mission at a time (**11** types); **[S]** = per-player singles, up to **3** concurrent (**5** types: Troop Insert/Extract, Cargo, Mine Clearing, CASEVAC). Locations are kept apart in logic. |
| **Vehicles**                   | Spawn/despawn aircraft at helipads and land vehicles at defined points. Lists from `CfgVehicles`; optional limits via Scenario GUI. Pylon/loadout action for pilots.                                                                                              |
| **Jukebox**                    | **Radio_1**–**Radio_4** objects and **Ctrl+'** (personal source): track list, play/stop, now-playing. 3D sound for clients; server sync and JIP replay.                                                                                                           |
| **Ambient civilians**          | Proximity spawn in **civ zones** built from map **named locations** (`rsc/FADE_civZonesFromLocations.sqf`, ≥ `FADE_civZoneMinDistFromBase` from HQ); road vehicles use active zones. `ROAD_SP_*` only for Intercept Convoy. Toggle in Scenario GUI. |
| **Civilian talk**              | **Talk to civilian** on ambient foot civs: local fade + face-to-face snap + scripted camera, then GUI (only for the initiating player). Dialogue topics with coordinated `switchMove` anims (player/civilian; pointing for intel). Actionable tips (OPFOR / vehicle) append to map **Intel** diary (`Briefing.sqf` subject `FAC_Intel`). Scenario: **Everyone** / **Interpreters only**; Loadout: interpreter flag. `rsc/CivTalkGui.sqf`, `rsc/CivTalkServer.sqf`, `rsc/Config.sqf` (`FADE_civTalk*`). |
| **Building intel**            | When a **virtual garrison** spawns, a small prop may appear in the building (random class from **`FADE_intelObjectClasses`** in `rsc/Config.sqf`). **Hold action** (default ~**5 s**) **Read intel** — server builds **1–3 lines** from **live** nearby OPFOR (vehicles, dismounts, pending garrisons, checkpoints, dynamic roadblocks) plus optional **Operation / Escape & Evasion** context; **group hint** and short-lived **map marker** when a vehicle contact line is included. Scenario toggle: **Who can read Intel?** (`Everyone` / `Specialists only`). In specialist-only mode, non-specialists can carry packages and process them at HQ (50 m) or hand to an Intel specialist. Role set in Loadout GUI. Tuning: `FADE_intel*` in `rsc/Config.sqf`; logic `rsc/FADE_IntelServer.sqf`, `rsc/FADE_IntelClient.sqf`. |
| **Loadouts**                   | Custom loadout dialog at loadout boxes; **Save my loadout** (session restore on respawn); ACE Arsenal when ACE is loaded; presets where implemented.                                                                                                            |
| **CQB shoothouse**             | **cqbBoard** + **CQB_POS_***: enemy type (targets or live), density, civilians. Start/End drill spawns/cleans at positions.                                                                                                                                        |
| **Teleporting**                | **Fast Travel** on **teleportBoard_1**…**teleportBoard_8**: Base, Medical, Pads, Firing Range, CQB, Vehicle Pad 2, Locker Room, SDE’s Pub (destinations: `rsc/TeleportGui.sqf` / `initPlayerLocal`; Eden naming detail in **`.cursor/agent-docs/AGENTS_EDEN.md`** locally). |
| **Firing / AT range**          | **terminalRange** action **Firing and AT range**: human and vehicle lanes, AT weapon slots where configured (`rsc/RangeGui.sqf`, `rsc/RangeServer.sqf`, `rsc/RangeShared.sqf`, `rsc/RangeDialog.hpp`).                                                              |
| **Sniper range**               | **terminalSniper** action **Sniper range**: session logic on server (`rsc/SniperRangeServer.sqf`), client GUI (`rsc/SniperGui.sqf`, `rsc/SniperDialog.hpp`); projectile trace / impact feedback.                                                                  |
| **Medical training**           | **terminalMedical** — **Medical training** action: dummy spawn, ACE + KAM injury presets, stabilise/heal (`rsc/MedicalTrainingGui.sqf`, `rsc/MedicalTrainingKAT.sqf`). **Not** a separate entry in the Missions GUI (training area only).                             |
| **Ambient enemy patrols & AA** | Optional patrols and garrisons; AAA level: Off, AAA, AAA+MANPADS (dynamic airborne-triggered spawns). Enemy retreat behaviour at ~50% casualties (server-side).                                                                                                     |
| **FAC doctrine (in-game)**     | Briefing and diary (map): Scenario Brief, **Notes** with joint fires — 5-line, CFF, RATEL, control measures, terminology, marking, LZ/EFM/EW (`rsc/Briefing.sqf`).                                                                                              |
| **FIRES fall of shot**         | **terminalFires** GUI: place a captive observer UAV via map click (spawner gets **UAV terminal**; no briefing-screen video). Per firing-slot **firesScreenPos_*** props can show a short impact-area RTT after qualifying indirect rounds when that screen is toggled **on** (`rsc/FiresFallOfShot.sqf`, `rsc/Config.sqf`). |


---

## Mission types

Script IDs and behaviour: `rsc/Missions.sqf`, `rsc/MissionsGui.sqf`, `initServer.sqf` (`FADE_globalMissionTypes`, `FADE_singleMissionTypes`). **[G]** = global stream; **[S]** = single-player mission slot.

### Area of Operations (`AreaOfOperations`) — [G]

- **Intent:** Large fight in a **2 km × 2 km** AO; **three sequential capture objectives** (OBJ1 → OBJ2 → OBJ3).
- **Typical experience:** BLUFOR AI spawns on one edge and pushes; OPFOR on objectives with patrols; strength tiers (Low/Mid/High) change density; **BLUFOR reinforcement waves**; **OPFOR reinforcement** (and vehicle respawn on High); **50% counter-attack wave** when BLUFOR first captures an objective.
- **Callouts:** AO centre from a civ zone **≥ 2500 m** from base; **~30 min** timeout. Not the same as **Operation**.

### Asset Retrieval (`AssetRetrieval`) — [G]

- **Intent:** Clear a small site, **scroll action** to secure the intel case, then **RTB** (within **150 m** of base with intel secured; **20 min** timeout in logic).
- **Typical experience:** **Two enemy infantry groups** toward the site; fight, grab intel, return.
- **Callouts:** **Counter-attack / QRF** (`FADE_counterAttackStart`, **320 m** detection radius).

### CAS / Fire Support (`CAS`) — [G]

- **Intent:** Rotary **CAS practice** — support a friendly squad under attack.
- **Typical experience:** Friendlies **200–400 m** from marker; **2–4 enemy groups** spawn **≥ 750 m** from friendlies and advance; AI **5-line CCA** and side chat; within **1 km**, friendlies use **green smoke** (day) or **IR strobes** (night, ACE).
- **Callouts:** **Succeed** when fewer than **20%** of enemies remain; **fail** if **all friendlies eliminated**. **No** separate QRF script beyond the assault groups.

### Cargo / Resupply (`Cargo`) — [S]

- **Intent:** **Logistics / sling-load** practice and landing discipline.
- **Typical experience:** Optional sling box at **`CargoPoint_1`**; friendly **camp** with garrison; **land at camp** → AI unload sequence → complete. **900 s** mission timeout in monitor.
- **Callouts:** **Non-combat** (friendly garrison only).

### CASEVAC (`CASEVAC`) — [S]

- **Intent:** **Medical evacuation** — wounded squad pickup and RTB (`TroopTransport.sqf`).
- **Typical experience:** **Some KIA** removed on spawn; survivors get **ACE wounds** (if ACE) or vanilla damage; **50%** chance of **1–5 enemy groups** moving on the LZ (same pattern as Troop Extract).
- **Callouts:** **Counter-attack QRF** when players enter the area (`Config.sqf` `FADE_counterAttack*`).

### Clear Area (`ClearArea`) — [G]

- **Intent:** **Medium assault** — enemy-held **town** (random civ zone centre) **or** procedural **camp** (tents, barriers, etc.).
- **Typical experience:** Patrols and garrison; **≥ 80%** enemy eliminated to win; **15 min** timeout.
- **Callouts:** **Counter-attack QRF** when BLUFOR enters the zone.

### CSAR (`CSAR`) — [G]

- **Intent:** **Downed aircraft** + **one survivor**; find, land, load, RTB.
- **Typical experience:** Wreck + survivor **moving toward nearest civ zone**; **OPFOR search patrols** toward crash then town; survivor **radios grid** at **1 km**, **green smoke** at **500 m**.
- **Callouts:** **Global mission slot** (one global at a time). **Counter-attack QRF** on crash site (**500 m** detection).

### Escape & Evasion (`EscapeEvasion`) — [G]

- **Intent:** Selected players (**evadees**) start dispersed in a hostile civilian area **without GPS**; OPFOR hunting pressure, road QRF on contact, later a **search helicopter** (orbit-only). **Win** if **at least one** originally selected evadee who has **never fully died** meets the RTB / extraction rule (e.g. alive at base). Evadees who **die once** may respawn and join the rescue side; they no longer count toward that win. **Fail** only if **every** originally selected evadee has **fully died** at least once (**ACE unconscious does not count**).
- **Typical experience:** Patrols and garrison in town; truck QRF; heli search pattern over the area. Started from Manage Missions with evadee selection (`rsc/EscapeEvasionPickGui.sqf`).
- **Callouts:** Global slot; uses same broad counter-attack registration as other combat globals where applicable (`Missions.sqf` / server start path).

### Hostage (`Hostage`) — [G]

- **Intent:** **Hostage rescue** in urban buildings (up to **3** hostages).
- **Typical experience:** Guards and combat; **fail** if more than **50%** of hostages killed; **win** when survivors **alive within ~100 m of base**.
- **Callouts:** **Counter-attack QRF** on site.

### HVT (`HVT`) — [G]

- **Intent:** **Snatch/kill** — officer-type HVT in a **large urban building** (10+ building positions), **guards**, **perimeter patrols**.
- **Typical experience:** HVT uses ambient anim; complete on **kill** or **capture** (bring to base, **~80 m**).
- **Callouts:** **Counter-attack QRF** on objective.

### Intercept Convoy (`InterceptConvoy`) — [G]

- **Intent:** **Interdiction** — stop enemy **road convoy** before end zone.
- **Typical experience:** **3–6 vehicles** (soft/armour from enemy faction); route from **random roads** with **≥ 5000 m** straight-line separation (configurable); **“Eagle Eye”** friendly side chat when lead is **~35%** along route; **succeed** when **≥ 60%** of convoy vehicles **destroyed or immobilised**. Road route helper: `rsc/fn_FADE_interceptConvoyRoadRoute.sqf`.
- **Callouts:** **Fails** if convoy **reaches end waypoint**; uses enemy retreat registration; **not** the same QRF system as counter-attack missions.

### Mine Clearing (`MineClearing`) — [S]

- **Intent:** **EOD on roads** near a **civ zone** anchor (**500 m**); each run is **either** **2–5** AP mines **or** **1–3** IEDs (not both). SMEAC states which.
- **Typical experience:** Hazards **on the road network**, **≥ 20 m** apart; map marker at **approximate centre** of the cluster; clear all (mines disarmed; IEDs disarmed or destroyed). **No** random or proximity-scripted detonations.
- **Callouts:** No OPFOR.

### Operation (`Operation`) — [G]

- **Intent:** **Multi-zone clearance** — hold civ zones until OPFOR cleared (**60 s** latch per zone).
- **Typical experience:** Zone count from scenario (**`FADE_operationZoneCount`**); patrols, garrison, **vehicles between enemy-held zones**, **periodic resupply**, **QRF from nearest enemy-held zone** when zone is **contested** (BLUFOR + OPFOR; cooldowns in `rsc/Config.sqf`).
- **Callouts:** Fleet caps, spawn distance from players, distance cleanup — see **`FADE_operation*`** in `rsc/Config.sqf`.

### Search & Destroy (`SearchDestroy`) — [G]

- **Intent:** **Ammo cache hunt** — up to **three** enemy **ammo caches** in garrisoned buildings (burning barrels mark sites); patrols in the zone.
- **Typical experience:** Search the **250 m** marked zone; task/SMEAC states **cache count** and **destroy %** required (`FADE_searchDestroyCacheDestroyPct` in `Config.sqf`, default **100%**). Eliminate all defenders; timeout/cancel per script.
- **Callouts:** **Counter-attack QRF** with detection radius on mission centre.

### Troop Extract (`TroopExtract`) — [S]

- **Intent:** **EXFIL** — LZ pickup, load **2–10** AI, RTB and land.
- **Typical experience:** **50%** chance **1–5 enemy groups** **500–2000 m** out pushing the LZ; otherwise quiet pickup (`TroopTransport.sqf`).
- **Callouts:** **Counter-attack QRF** on pickup area **plus** optional pre-spawned enemies.

### Troop Insert (`TroopInsert`) — [S]

- **Intent:** Pickup at `B_SP_*` (Eden triggers) → LZ → land → disembark.
- **Typical experience:** Squad sized to **heli cargo seats** (default 6); night **IR strobes** on friendlies; `TroopTransport.sqf` phases.
- **Callouts:** Requires Eden `B_SP_*`; **no** `FADE_counterAttackStart` in this block (unlike Extract / CASEVAC / CSAR).

---

## Documentation

**README.md** (this file) stays in the repo root for contributors.

**Agent / AI docs** live in **`.cursor/agent-docs/`** (next to **`.cursor/rules/`**). That folder is **gitignored** so Cursor rules can be shared without pushing local context; keep or regenerate copies locally. Typical contents:

| File | Purpose |
|------|---------|
| `AGENTS.md` | Hub: architecture, pointers, AI guidelines |
| `SCRIPT_INDEX.md` | Every `.sqf`, load paths, `remoteExec` / `publicVariable`, verification matrix |
| `AGENTS_EDEN.md`, `AGENTS_PATTERNS.md`, `AGENTS_REFERENCE.md` | Eden names, coding patterns, missions/BIS/RPT reference |
| `PRODUCTION_SERVER_ISSUES.md` | Production dedicated-server testing tracker |

---

## Production dedicated server

Post-deploy testing, severity/status, and planned fixes are tracked in **`.cursor/agent-docs/PRODUCTION_SERVER_ISSUES.md`** when that file is present locally (see [Documentation](#documentation) above). Use it for triage on a **production dedicated server**, JIP vs initial join, and mod loadouts. Open items there include mission cleanup edge cases, IED behaviour, lobby parameters, pad rearm consistency, AI dialogue visibility on dedicated, CQB/target polish, and feature backlog — not an exhaustive list of mission behaviour; see the tracker for current state.

---

## Todo

### Intel (`FADE_intel*` — `rsc/FADE_IntelServer.sqf`, `rsc/FADE_IntelClient.sqf`)

- **v2 / polish:** Optional **diary** entry; **reliability** roll (deliberate misinformation); Eden-placed intel props; tie **marker TTL** / **scope** to scenario presets.

### Escape & Evasion (`EscapeEvasion` — `rsc/Missions.sqf`, `rsc/EscapeEvasionPickGui.sqf`, `initServer.sqf` entry)

- **Win / fail (distinct evadee roster):** Track the **set of players selected as evadees** at start. **Success:** **at least one** of them **never fully dies** (vanilla/ACE **dead**, not merely unconscious) and satisfies RTB / win geometry. Evadees who **die once** may respawn as **rescue**; they are **out** of the “never died” pool but the mission can still **complete** if another evadee never died and extracts (e.g. **5** evadees, **3** die once and join rescue, **2** never die and RTB → **complete**). **Fail:** **every** selected evadee has **fully died** at least **once**.
- **Teleport placement:** After choosing dispersed positions, **validate dry land** (surface isWater / suitable ground); **re-roll** or offset if in water or unusable.
- **Cleanup:** On **success**, **fail**, or **abort**, **delete or despawn all units and objects** spawned for this mission (patrols, QRF, heli, local garrison created for the run) so nothing is left for the next mission.
- **Player information:** On teleport, **do not** show **grids**, **AO markers**, or **hunting area** to evadees (compass/map discipline); HQ / training overlay rules as designed.
- **Win condition bug:** Align script logic with the **Escape & Evasion** mission blurb under [Mission types](#mission-types): do **not** require **all** evadees alive; do **not** mark complete on **wrong** RTB states (e.g. only rescuers at base while evadees still in field — define **X m** of base and **who** must be present).
- **Spawn fairness:** Enforce **minimum distance** (and optionally **line-of-sight** or **building buffer**) between **evadee spawn** and **nearest OPFOR** so players cannot be killed before they can move (tune m values in `Config.sqf` or mission-local defines).
- **Pressure after exfil from initial zone:** Once evadees leave the **starting urban bubble**, **reduce** scripted hunt density to **ambient** level **except**:
  - **Dynamic roadblocks** and **garrisoned buildings** along **likely routes** / **main roads** back to base (spawn from road network + building scan).
  - **Secondary routes** comparatively **lighter** so **route choice** is the evasion lesson.
  
---

*Implementation detail for assistants: **`.cursor/agent-docs/AGENTS.md`** and siblings in the same folder (local).*
