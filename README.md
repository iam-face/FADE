# FADE [Face's Dynamic Environment]

**Sandbox for Combat Team Bravo (CTB)**. No Zeus required. In-game boards and GUIs drive scenario options and dynamic missions so players can run and tailor sessions quickly. Built for **rotary piloting**, **joint fires**, and **infantry training** on ARMA 3.

---

## Features


| Feature                        | Description                                                                                                                                                                                                                                                       |
| ------------------------------ | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| **Scenario Management**        | Weather, time of day, friendly/enemy/civilian factions, limit gear. Enemy AI: patrols, skill, routing, AAA level, AO strength. Server applies and broadcasts.                                                                                                     |
| **Missions**                   | Dynamic mission types: Troop Insert/Extract, CAS, Cargo/Resupply, HVT, Hostage, Clear Area, Intercept Convoy, Area of Operations, Medical/MASCAS, Mine Clearing, Find and Clear IEDs. Global (one at a time) and Single (up to 3) streams; locations ≥2 km apart. |
| **Vehicles**                   | Spawn/despawn aircraft at helipads and land vehicles at defined points. Lists from `CfgVehicles`; optional limits via Scenario GUI. Pylon/loadout action for pilots.                                                                                              |
| **Jukebox**                    | **Radio_1** object: track list, play/stop, now-playing. 3D sound for all clients; server sync.                                                                                                                                                                    |
| **Ambient Civilians**          | Proximity spawn in `CIV_T_`* zones; road vehicles at `ROAD_SP_*`. Toggle on/off in Scenario GUI.                                                                                                                                                                  |
| **Loadouts**                   | Custom loadout dialog at loadout boxes; **Save my loadout** (session restore on respawn); ACE Arsenal when ACE loaded; CTB presets (Rifleman, TL, Medic, etc.).                                                                                                   |
| **CQB Shoothouse**             | **cqbBoard** + `CQB_POS_`*: enemy type (targets or real), density, civilians. Start/End drill spawns/cleans at positions.                                                                                                                                         |
| **Teleporting**                | **Fast Travel** on `teleportBoard_1`…`7`: Base, Medical, Pads 3–5, Firing Range, CQB, Vehicle Pad 2, Locker Room.                                                                                                                                                 |
| **Surrender Mechanic**         | Key-bound challenge: 30° cone, 25 m; chance-based surrender with modifiers; ACE captives integration.                                                                                                                                                             |
| **Ambient Enemy Patrols & AA** | Optional patrols and garrisons; AAA level: None, Light, Medium, Heavy, MANPADS.                                                                                                                                                                                   |
| **CTB Doctrine Documentation** | In-game briefing and diary (map): Scenario Brief, **Notes** with Joint Fires - 9-line, 5-line, CFF, RATEL, control measures, terminology, marking, LZ/EFM/EW.                                                                                                     |


---

## Work in Progress


| Item                           | Notes                                                                       |
| ------------------------------ | --------------------------------------------------------------------------- |
| **Dedicated server behaviour** | Validation and edge-case testing on dedicated server.                       |
| **Sounds**                     | Additional sound assets and events (e.g. locker, transport, ambient).       |
| **Locker Room**                | `LOCKER_1` action and slap sound in place; more sounds/actions to be added. |
| **Polish**                     | UX, balance, and general polish pass.                                       |


---

*For implementation details, mission structure, and scripting patterns see **AGENTS.md**.*