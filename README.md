# FADE [Face's Dynamic Environment]

**Sandbox for Combat Team Bravo (CTB)**. No Zeus required. In-game boards and GUIs drive scenario options and dynamic missions so players can run and tailor sessions quickly. Built for **rotary piloting**, **joint fires**, and **infantry training** in **ARMA 3** multiplayer (listen or dedicated server).

**Map:** Sefrou Ramal (Tunis).

---

## Features


| Feature                        | Description                                                                                                                                                                                                                                                       |
| ------------------------------ | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| **Scenario Management**        | Weather, time of day, friendly/enemy/civilian factions, gear/loadout limits, time compression. Enemy AI: patrols, skill, routing, AAA level, AO strength. Server applies and broadcasts.                                                                            |
| **Missions**                   | **17** dynamic types — see [Mission types](#mission-types). **[G]** = one global mission at a time; **[S]** = per-player singles (up to **3** concurrent). Locations ≥2 km apart. **terminalMedical** adds a medical dummy GUI (injuries + heal; ACE + KAM), independent of the Medical Training mission. |
| **Vehicles**                   | Spawn/despawn aircraft at helipads and land vehicles at defined points. Lists from `CfgVehicles`; optional limits via Scenario GUI. Pylon/loadout action for pilots.                                                                                              |
| **Jukebox**                    | **Radio_1**–**Radio_4** objects and **Ctrl+'** (personal source): track list, play/stop, now-playing. 3D sound for clients; server sync and JIP replay.                                                                                                           |
| **Ambient Civilians**          | Proximity spawn in `CIV_T_`* zones; road vehicles at `ROAD_SP_*`. Toggle on/off in Scenario GUI.                                                                                                                                                                  |
| **Loadouts**                   | Custom loadout dialog at loadout boxes; **Save my loadout** (session restore on respawn); ACE Arsenal when ACE loaded; presets where implemented.                                                                                                                 |
| **CQB Shoothouse**             | **cqbBoard** + **CQB_POS_***: enemy type (targets or real), density, civilians. Start/End drill spawns/cleans at positions.                                                                                                                                       |
| **Teleporting**                | **Fast Travel** on **teleportBoard_1**…**teleportBoard_8**: Base, Medical, Pads 3–5, Firing Range, CQB, Vehicle Pad 2, Locker Room, SDE's Pub (destinations: `rsc/TeleportGui.sqf` / `initPlayerLocal`; optional detail in **`.cursor/agent-docs/AGENTS_EDEN.md`** locally). |
| **Ambient Enemy Patrols & AA** | Optional patrols and garrisons; AAA level: None, Light, Medium, Heavy, MANPADS. Enemy retreat behaviour at ~50% casualties (server-side).                                                                                                                         |
| **CTB Doctrine Documentation** | In-game briefing and diary (map): Scenario Brief, **Notes** with Joint Fires — 9-line, 5-line, CFF, RATEL, control measures, terminology, marking, LZ/EFM/EW.                                                                                                     |
| **FIRES fall of shot**         | **terminalFires** GUI: place a captive observer UAV via map click (spawner gets **UAV terminal**; no briefing-screen video). Per firing-slot **firesScreenPos_*** props show a short impact-area RTT after qualifying indirect rounds when that screen is toggled **on** (`rsc/FiresFallOfShot.sqf`, **Config.sqf**). |


---

## Mission types

Script IDs and behaviour: `rsc/Missions.sqf`, `rsc/MissionsGui.sqf`, `initServer.sqf` (`FADE_globalMissionTypes`). **[G]** = global stream; **[S]** = single-player mission slot.

### Area of Operations (`AreaOfOperations`) — [G]

- **Intent:** Large fight in a **2 km × 2 km** AO; **three sequential capture objectives** (OBJ1 → OBJ2 → OBJ3).
- **Typical experience:** BLUFOR AI spawns on one edge and pushes; OPFOR on objectives with patrols; strength tiers (Low/Mid/High) change density; **BLUFOR reinforcement waves**; **OPFOR reinforcement** (and vehicle respawn on High); **50% counter-attack wave** when BLUFOR first captures an objective.
- **Callouts:** AO centre from a `CIV_T_*` zone **≥ 2500 m** from base; **~30 min** timeout. Not the same as **Operation**.

### Asset Retrieval (`AssetRetrieval`) — [S]

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

- **Intent:** **Medium assault** — enemy-held **town** (random `CIV_T_*` centre) **or** procedural **camp** (tents, barriers, etc.).
- **Typical experience:** Patrols and garrison; **≥ 80%** enemy eliminated to win; **15 min** timeout.
- **Callouts:** **Counter-attack QRF** when BLUFOR enters the zone.

### CSAR (`CSAR`) — [G]

- **Intent:** **Downed aircraft** + **one survivor**; find, land, load, RTB.
- **Typical experience:** Wreck + survivor **moving toward nearest civ zone**; **OPFOR search patrols** toward crash then town; survivor **radios grid** at **1 km**, **green smoke** at **500 m**.
- **Callouts:** **Global mission slot** (one global at a time). **Counter-attack QRF** on crash site (**500 m** detection).

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
- **Typical experience:** **3–6 vehicles** (soft/armour from enemy faction); route from **random roads** with **≥ 5000 m** straight-line separation (configurable); **“Eagle Eye”** friendly side chat when lead is **~35%** along route; **succeed** when **≥ 60%** of convoy vehicles **destroyed or immobilised**.
- **Callouts:** **Fails** if convoy **reaches end waypoint**; uses enemy retreat registration; **not** the same QRF system as counter-attack missions.

### Medical Training (`MedicalTraining`) — [S]

- **Intent:** **KAT/ACE medical drill** at **`MEDICAL_1`** (not a field mission).
- **Typical experience:** **1–3** dummies, **random injury presets**; **uniform only**; stabilise/heal all; **fail** if more than **50%** die.
- **Callouts:** Requires **ACE Medical + KAT** (and **KAT Surgery** for fracture presets per GUI text).

### Mine Clearing (`MineClearing`) — [S]

- **Intent:** **EOD on roads** near a **`CIV_T_*`** anchor (**500 m**); each run is **either** **2–5** AP mines **or** **1–3** IEDs (not both). SMEAC states which.
- **Typical experience:** Hazards **on the road network**, **≥ 20 m** apart; map marker at **approximate centre** of the cluster; clear all (mines disarmed; IEDs disarmed or destroyed). **No** random or proximity-scripted detonations.
- **Callouts:** No OPFOR.

### Operation (`Operation`) — [G]

- **Intent:** **Multi-zone clearance** — hold `CIV_T_*` zones until OPFOR cleared (**60 s** latch per zone).
- **Typical experience:** Zone count from scenario (**`FADE_operationZoneCount`**); patrols, garrison, **vehicles between enemy-held zones**, **periodic resupply**, **QRF from nearest enemy-held zone** when zone is **contested** (BLUFOR + OPFOR; cooldowns in `rsc/Config.sqf`).
- **Callouts:** Fleet caps, spawn distance from players, distance cleanup — see **`FADE_operation*`** in `rsc/Config.sqf`.

### Search & Destroy (`SearchDestroy`) — [G]

- **Intent:** **Urban clearance** — up to **three** OPFOR **buildings** in a civ town, patrols (GM ammo piles if mod present).
- **Typical experience:** Eliminate enemies in the marked building set; timeout/cancel per script.
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

Post-deploy testing, severity/status, and planned fixes are tracked in **`.cursor/agent-docs/PRODUCTION_SERVER_ISSUES.md`** when that file is present locally (see [Documentation](#documentation) above). Use it for triage on a **production dedicated server**, JIP vs initial join, and mod loadouts. Open items there include mission cleanup edge cases, IED behaviour, lobby parameters, pad rearm consistency, AI dialogue visibility on dedicated, CQB/target polish, and feature backlog - not an exhaustive list of mission behaviour; see the tracker for current state.

---

## Todo

- Implement full `terminalRange` firing/AT range workflow.
  - Reuse sniper session telemetry and projectile/hit feedback path where stable.
  - Support human (`shootPos_*`) and vehicle (`shootVehPos_*`) target sessions with per-type vehicle toggles.
  - Add FIRES-style AT weapon slot spawning at `rangeGunPos_1..6`.

---

*Implementation detail for assistants: **`.cursor/agent-docs/AGENTS.md`** and siblings in the same folder (local).*