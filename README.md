# FADE (Face’s Dynamic Environment)

**Beta 6** — multiplayer **Arma 3** sandbox on **Altis**. No Zeus required: boards and GUIs at the base let players set the scenario, spawn vehicles, run training ranges, and start dynamic missions. Aimed at **rotary**, **joint fires**, and **infantry** practice (listen server or dedicated).

**Repo folder:** `CTB_FAC_FADE.Altis` · **Players:** up to **31**

---

## How it works

1. **Manage Scenario** — weather, time, factions, enemy threat, civilians, gear policy, and related options.
2. **Manage Missions** — pick a mission type, read the in-GUI blurb, start (some missions use a map or player picker).
3. **Terminals & boards** — vehicles, loadouts, **HQ recruit board** (spawn/dismiss friendly AI with preset loadouts), fast travel, CQB, jukebox, medical training, firing/AT range, sniper range, FIRES range.

Most settings are **server-authoritative** and sync to joining players. **Lobby parameters** (`description.ext`) can lock GUIs to group leaders, set starting defaults (civilians, OPFOR threat, civ talk, intel access, jukebox, ACE Arsenal, and more), and optional **DEBUG** overlays (garrison building markers, civilian town active/idle markers, spawn systemChat). Admins and Zeus usually override leader-only locks.

---

## What’s in the box

- **17 mission types** — see below (**[G]** one shared mission at a time; **[S]** up to three personal missions at once).
- **Scenario & enemy AI** — patrols, garrisons, skill, routing, retreat, AAA (Off / AAA / AAA+MANPADS), OPFOR air/drones (Off / Low / Normal / High), AO strength.
- **Vehicles** — spawn and manage at pads; pylons/loadouts where supported.
- **Loadouts** — box GUI, session save, presets; ACE Arsenal when enabled.
- **Recruit** — `hqRecruitBoard`: custom preset or faction infantry, assign to any friendly group, dismiss from Roster tab; lobby access Everyone / Group leaders / Admin.
- **Training** — CQB shoothouse; medical dummies (ACE + KAM); firing/AT and sniper ranges; FIRES terminal with fall-of-shot screens.
- **World life** — ambient civilians in map-derived zones; talk to civilians for tips; building intel packages; dynamic roadblocks.
- **Fast travel** — boards around the base area (base, medical, pads, range, CQB, locker, pub, etc.).
- **Jukebox** — base radios and personal **Ctrl+'** player music.
- **Briefing** — map diary with scenario notes and joint-fires reference material.

---

## Mission types

Descriptions in-game (**Manage Missions**) are the source of truth for objectives and win conditions.

### Global [G] — one at a time

| Mission | Summary |
|--------|---------|
| Area of Operations | Large fight; multiple objectives in a wide sector. |
| Asset Retrieval | Recover equipment from enemy ground; extract. |
| CAS / Fire Support | Support friendlies under attack. |
| Clear Area | Assault a town or camp. |
| CSAR | Recover personnel from a crash site. |
| Escape & Evasion | Evadees separated in hostile ground; rescue force coordinates recovery. |
| Geo-Guesser | Navigation drill: map-click guess where you were dropped; ranked scoring. |
| Hostage | Rescue civilians from a built-up site. |
| HVT | Find, kill, or capture a priority target. |
| Intercept Convoy | Stop a moving column before it finishes its route. *(temporarily disabled in Missions GUI — route/spawn rework in progress)* |
| Invasion | OPFOR beachhead push through nearest civil zones; retake INVASION to win. |
| Operation | Clear and hold several linked zones. |
| Raid | Three linked objectives (mixed task types) across the map; approximate intel, detection-triggered QRF per zone. |
| Search & Destroy | Find and destroy enemy ammo caches in a marked zone. |

### Single [S] — per player, up to 3 concurrent

| Mission | Summary |
|--------|---------|
| Troop Insert | Insert a squad from base to a chosen LZ. |
| Troop Extract | Pick up a team and RTB. |
| Cargo / Resupply | Deliver supplies to a forward camp (sling-load optional). |
| CASEVAC | Evacuate wounded to base. |
| Mine Clearing | Clear mines or IEDs on a road segment. |

---

## Planned work

Feature backlog: **[TODO.md](TODO.md)**.

**Upcoming mission types:** Point defense, SEAD/DEAD (destroy enemy air defences), Hunt (civilian interviews / intel to locate hidden camp or HVT).

Shipped in this pass: **Raid**, **Invasion**, procedural **lore**, **AAA** engagement fix, and **OPFOR drones** (ambient UAV patrol + QRF vectoring).

- **Intercept Convoy** — temporarily disabled (`FADE_disabledMissionTypes`); fix subdivided route waypoints, road spawn helper, and RPT errors before re-enabling.

---

## Mods

Core mission runs on vanilla-friendly setup. **ACE** and **KAT** are expected for full medical training and CASEVAC depth. Server mod list should match what the mission was built with (see `mission.sqm` addons).

---

## For contributors

Entry points: `initServer.sqf` (loads `rsc/server/`) and `initPlayerLocal.sqf`. Mission logic is split into `rsc/missions/` (one script per type); `rsc/Missions.sqf` dispatches. Shared helpers live in `rsc/FADE_*` and `rsc/FAC_*`. Local AI/editor notes may exist in `.cursor/agent-docs/` (gitignored).

**Regression tests:** `[] call FAC_missionTestSuite_execAll` (debug-tools lobby param adds a scroll-wheel action). RPT filter: `[FAC TestSuite]`. Covers compile, RPCs, mission placement, SMEAC/intel per type, zone pickers, and client GUI scripts — not full mission playthroughs.
