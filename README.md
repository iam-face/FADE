# FADE [Face's Dynamic Environment]

**Sandbox for Combat Team Bravo (CTB)**. No Zeus required. In-game boards and GUIs drive scenario options and dynamic missions so players can run and tailor sessions quickly. Built for **rotary piloting**, **joint fires**, and **infantry training** in **ARMA 3** multiplayer (listen or dedicated server).

**Map:** Sefrou Ramal (Tunis).

---

## Features


| Feature                        | Description                                                                                                                                                                                                                                                       |
| ------------------------------ | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| **Scenario Management**        | Weather, time of day, friendly/enemy/civilian factions, gear/loadout limits, time compression. Enemy AI: patrols, skill, routing, AAA level, AO strength. Server applies and broadcasts.                                                                            |
| **Missions**                   | Dynamic mission types: Troop Insert/Extract, CAS, Cargo/Resupply, HVT, Hostage, Clear Area, Intercept Convoy, Area of Operations, Medical/MASCAS, Mine Clearing, Find and Clear IEDs. Global (one at a time) and Single (up to 3) streams; locations ≥2 km apart. |
| **Vehicles**                   | Spawn/despawn aircraft at helipads and land vehicles at defined points. Lists from `CfgVehicles`; optional limits via Scenario GUI. Pylon/loadout action for pilots.                                                                                              |
| **Jukebox**                    | **Radio_1**–**Radio_4** objects and **Ctrl+'** (personal source): track list, play/stop, now-playing. 3D sound for clients; server sync and JIP replay.                                                                                                           |
| **Ambient Civilians**          | Proximity spawn in `CIV_T_`* zones; road vehicles at `ROAD_SP_*`. Toggle on/off in Scenario GUI.                                                                                                                                                                  |
| **Loadouts**                   | Custom loadout dialog at loadout boxes; **Save my loadout** (session restore on respawn); ACE Arsenal when ACE loaded; presets where implemented.                                                                                                                 |
| **CQB Shoothouse**             | **cqbBoard** + **CQB_POS_***: enemy type (targets or real), density, civilians. Start/End drill spawns/cleans at positions.                                                                                                                                       |
| **Teleporting**                | **Fast Travel** on **teleportBoard_1**…**teleportBoard_8**: Base, Medical, Pads 3–5, Firing Range, CQB, Vehicle Pad 2, Locker Room, SDE's Pub (destinations: `rsc/TeleportGui.sqf` / `initPlayerLocal`; optional detail in **`.cursor/agent-docs/AGENTS_EDEN.md`** locally). |
| **Ambient Enemy Patrols & AA** | Optional patrols and garrisons; AAA level: None, Light, Medium, Heavy, MANPADS. Enemy retreat behaviour at ~50% casualties (server-side).                                                                                                                         |
| **CTB Doctrine Documentation** | In-game briefing and diary (map): Scenario Brief, **Notes** with Joint Fires — 9-line, 5-line, CFF, RATEL, control measures, terminology, marking, LZ/EFM/EW.                                                                                                     |


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

*Implementation detail for assistants: **`.cursor/agent-docs/AGENTS.md`** and siblings in the same folder (local).*