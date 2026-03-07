# FADE (Face's Dynamic Environment)

FADE is a sandbox gamemode for **Combat Team Bravo (CTB)** built to provide an environment for quick operations with minimal setup and **no human Zeus (game master)**. Missions and scenario options are driven by in-game boards and GUIs so players can launch and tailor sessions without external mission editing or a dedicated game master.

The mission focuses on realistic milsim-style mission types: troop insert/extract, CAS and fire support, cargo resupply, HVT, hostage rescue, clear area, and intercept convoy. It is designed for **training** in infantry, rotary piloting, joint fires, and related procedures. **CTB training documentation** (e.g. joint fires, JTAC, CFF, RATEL) is built into the mission via the map briefing and diary for easy in-game access.

Features will evolve as more are developed. Implemented features and upcoming work are tracked in the tables below.

---

## Features


| Title                             | Description                                                                                                                                    | Status            |
| --------------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------- | ----------------- |
| Manage Vehicles GUI               | Spawn/despawn aircraft at defined positions and land vehicles. Dynamic aircraft/vehicle lists from CfgVehicles. Can be limited via Config GUI. | Ready for testing |
| Manage Missions GUI               | Start and abort dynamic missions; select mission type and parameters from board.                                                               | Ready for testing |
| Manage Scenario GUI               | Set weather, time of day, enemy/friendly/civilian factions, and limit gear. Server applies and broadcasts.                                     | Ready for testing |
| Manage My Loadout GUI             | Custom loadout dialog at loadout box; ACE Arsenal action when ACE loaded.                                                                      | Ready for testing |
| Jukebox                           | Radio_1 object: track list, play/stop, now-playing; 3D sound for all clients.                                                                  | Ready for testing |
| Mission: Troop Insert             | Insert friendly AI from B_SP_* to random mission location; landing and formation focus.                                                        | Ready for testing |
| Mission: Troop Extract            | Pick up AI from mission location and return to base; phase-based boarding/disembark.                                                           | Ready for testing |
| Mission: CAS / Fire Support       | Fly to mission location; support friendly AI with guns/rockets (attack heli focus).                                                            | Ready for testing |
| Mission: Cargo / Resupply         | Sling-load cargo to LZ; camp with garrison; AI confirms unload, then cleanup.                                                                  | Ready for testing |
| Mission: HVT                      | High-value target in urban building; guards and patrols; complete on kill or capture at base.                                                  | Ready for testing |
| Mission: Hostage                  | Civilian hostages in urban buildings; guards and patrols; succeed when all alive hostages at base.                                             | Ready for testing |
| Mission: Clear Area               | Enemy town (CIV_T_*) or camp; garrison, patrols, vehicles; succeed at ≥80% eliminated; 15 min timeout.                                         | Ready for testing |
| Mission: Intercept Convoy         | Enemy convoy (3–6 vehicles) between ROAD_SP_* start/end; destroy before arrival.                                                               | Ready for testing |
| Surrender Challenge Mechanic      | Key-bound challenge: chance-based AI surrender with modifiers; ACE captives integration.                                                       | Ready for testing |
| In-game briefing & diary          | Scenario Brief (Overview, How It Works, Rotary Piloting 101); Notes with CTB Joint Fires (9-line, 5-line, CFF, RATEL, etc.).                   | Ready for testing |
| Ambient civilians & road vehicles | Proximity spawn in CIV_T_* zones; road vehicles at ROAD_SP_*; used for atmosphere and urban mission placement.                                 | Ready for testing |
| Light towers                      | Invisible ambient lights 25 m above helipads and vehicle spawn points.                                                                         | Ready for testing |
| Helipad markers                   | Map markers updated with vehicle name when pad occupied; restored when empty.                                                                  | Ready for testing |
| Friendly callsigns & IR strobes   | NATO phonetic callsigns per group; ACE IR strobes for friendlies at night (Troop Insert/Extract).                                              | Ready for testing |
| Enemy patrols                     | Spawns enemy garrisons and patrols (inf and vic if available). Optional, set via Config GUI.                                                   | Ready for testing |


## Todo

Upcoming features and improvements. Conversations about new or changed features should be added here so they are tracked in one place.


| Title                               | Description                                                                                                                                                                                                                                               | Status  |
| ----------------------------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ------- |
| Surrender mechanic                  | Integrate with LAMBS AI. Simplify to 30° cone, 25 m in front of user; remove complex ray tracing. Simplify enemy decision paths to: refuse immediately, consider → refuse, consider → surrender.                                                          | Planned |
| Area of Operations (AO) mission     | Designate AO (auto or user centre); 2 km × 2 km zone. Cardinal BLUFOR/OPFOR sides; 3 target points aligned to BLUFOR axis; continuous respawn; mechanics for AO size, unit counts/types; capture mechanic; AO captured when all 3 targets held by BLUFOR. | Planned |
| AI JTAC (AO mode)                   | Spawn real JTAC unit; consider player assets; call fire missions via SideChat; target designation/priority; CTB 5-line; mark own position and enemy (within 200 m) with smoke.                                                                            | Planned |
| Locker room                         | From Juko's dynamic mission: Gachi sounds, locker slap sounds, etc. Sig to handle.                                                                                                                                                                        | Planned |
| CTB RATEL procedures                | Update all AI SideChat to follow CTB RATEL procedures.                                                                                                                                                                                                    | Planned |
| Enemy AAA level (global)            | Scenario config GUI: enemy AAA severity — none, light (MGs), medium (emplaced e.g. ZSU-23), MANPADS, roving heavy (e.g. Tunguska).                                                                                                                        | Planned |
| Pilot vehicle ammunition / pylons   | Method for pilots to manage vehicle ammunition loadouts (weapon pylons, etc.).                                                                                                                                                                            | Planned |
| AI artillery + player-directed fire | Place AI artillery; players direct via SideChat sequence (e.g. "FIRE MISSION" → grid request → 6-figure grid); AI fires and responds. Explore further.                                                                                                    | Planned |
| Convoy completion (60% inoperable)  | Intercept Convoy completes when 60% of convoy vehicles are inoperable (e.g. immobile), not only destroyed.                                                                                                                                                | Planned |
| Enemy AI skill and routing          | Config GUI: enemy skill level and ability to rout/run away; investigate LAMBS AI.                                                                                                                                                                         | Planned |
| CTB loadouts in arsenal             | Add typical CTB loadouts to arsenal; explore definitions and integration.                                                                                                                                                                                 | Planned |
| Save my loadout                     | addAction on loadout box to save current loadout.                                                                                                                                                                                                         | Planned |
| One global mission                  | Pivot mission approach to only allow one mission at a time on the server - this is the 'global mission'.                                                                                                                                                  | Planned |
| Respawn fix                         | Fix respawn to be base respawn, with ACE spectator whilst killed, timer.                                                                                                                                                                                  | Planned |


