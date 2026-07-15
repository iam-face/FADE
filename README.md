# FADE (Face’s Dynamic Environment)

**Beta 7** — multiplayer **Arma 3** sandbox on **Altis**. No Zeus required: boards and GUIs at the base let players set the scenario, spawn vehicles, run training ranges, and start dynamic missions. Aimed at **rotary**, **joint fires**, and **infantry** practice (listen server or dedicated).

**Repo folder:** `CTB_FAC_FADE.Altis` · **Players:** up to **31**

---

## How it works

1. **Manage Scenario** — weather, time, factions, enemy threat, civilians, gear policy, and related options.
2. **Manage Missions** — pick a mission type, read the in-GUI blurb, start (some missions use a map or player picker).
3. **Terminals & boards** — vehicles, loadouts, **HQ recruit board** (spawn/dismiss friendly AI with preset loadouts), fast travel, CQB, **jukebox** (`Radio_1`–`Radio_4`), medical training, firing/AT range, sniper range, FIRES range.

Most settings are **server-authoritative** and sync to joining players. **Lobby parameters** (`description.ext`) can lock GUIs to group leaders, set starting defaults (civilians, OPFOR threat, civ talk, intel access, base music, ACE Arsenal, and more), and optional **DEBUG** overlays (garrison building markers, civilian town active/idle markers, spawn systemChat). Admins and Zeus usually override leader-only locks.

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
- **Jukebox** — `Radio_1`–`Radio_4` + vehicle loudspeaker (`@CTB - Mission Sounds Library`); Scenario Admin stop-all
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
| Operation | Clear outer zones, then capture the OPFOR HQ hub. |
| Raid | Three linked objectives (mixed task types) across the map; each target building marked on the map. |
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

**Recently shipped (faction flexibility):**
- **Any-side player faction** — Scenario GUI friendly list: all EAST/WEST/GUER `CfgFactionClasses` entries; enemy list filtered to opposed sides (GUER hostile to both majors); auto-correct + hint on Apply; mission-start validation; player side sync on Apply.

**Upcoming mission types:** Point defense, SEAD/DEAD (destroy enemy air defences). **Operation v2** (intel-gated multi-objective grid) replaces the standalone Hunt concept — see TODO §11.

**Recently shipped (DRO/DCO-inspired pass):**
- **100 m grid search zones** on HVT, Hostage, S&D, Asset Retrieval, and Raid — standardised **`mil_*`** map markers mission-wide
- **Body search field intel** — search dead OPFOR to refine search zones (server-authoritative; dedicated-safe)
- **Terrain survey (`FADE_AoSurvey`)** — road/flat/forest/building buckets for patrol WP placement
- **Jukebox** — Sig/CTB loudspeaker at `Radio_1`–`Radio_4` and in-vehicle loudspeaker; Scenario Admin stop-all

**Deferred (separate tasks):**
- **Operation v2** — intel-gated 3×3 km grid, three hidden objectives via civ talk / body search; supersedes current Operation + Hunt
- **Commander mode / RCT-C** — embedded-map UI for AI support tasking
- **OPFOR roadblocks revisit** — use `FADE_aoSurvey` road buckets to place blocks on routes players actually use
- **Portable FADE** — ship FADE as a mod + thin mission glue; Eden **FADE Player Base** module sets base location; auto-discover vehicle/AI spawns, civ zones, configs for non-Altis maps (see TODO §13)
- **Player-facing copy (Humanizer)** — skill at `.cursor/skills/fade-player-copy/` (uses vendored Humanizer).
  - Done: lore / Missions GUI / SMEAC; Briefing diary + Rotary filler; Intel About + field/building lines; **welcome hint**, **lobby overview** (`mission.sqm` / `description.ext`), **civ talk** pools (+ CivTalk OPFOR/car reply formats). Base NPC (S Wordsman) humour left alone.

Previously shipped: **Raid**, **Invasion**, procedural **lore**, **AAA** engagement fix, and **OPFOR drones** (ambient UAV patrol + QRF vectoring).

- **Intercept Convoy** — temporarily disabled (`FADE_disabledMissionTypes`); fix subdivided route waypoints, road spawn helper, and RPT errors before re-enabling.

---

## Mods

Core mission runs on vanilla-friendly setup. **ACE** and **KAT** are expected for full medical training and CASEVAC depth. Server mod list should match what the mission was built with (see `mission.sqm` addons).

---

## For contributors

Entry points: `initServer.sqf` (loads `rsc/server/`) and `initPlayerLocal.sqf`. Mission logic is split into `rsc/missions/` (one script per type); `rsc/Missions.sqf` dispatches. Shared helpers live in `rsc/FADE_*` and `rsc/FAC_*`. Local AI/editor notes may exist in `.cursor/agent-docs/` (gitignored). Shared Cursor skills live under `.cursor/skills/` — **humanizer** (AI-tell scrub) and **fade-player-copy** (when/how to scrub player-visible FADE text).

**Regression tests:** `[] call FAC_missionTestSuite_execAll` (debug-tools lobby param adds a scroll-wheel action). RPT filter: `[FAC TestSuite]`. Covers compile, RPCs, mission placement, SMEAC/intel per type, zone pickers, and client GUI scripts — not full mission playthroughs.

**Offline SQF lint (no Arma):** Install the recommended **[SQF-VM Language Server](https://marketplace.visualstudio.com/items?itemName=SQF-VM.sqf-vm-language-server)** extension in Cursor/VS Code — syntax and preprocessor diagnostics as you edit. CLI batch check: `powershell -ExecutionPolicy Bypass -File tools\sqfvm\Invoke-FadeSqfLint.ps1 -InstallIfMissing` (downloads SQF-VM runtime to `tools/sqfvm/bin/`). Task: **SQF: Lint mission scripts (SQF-VM CLI)**. Suppress a line: `#pragma sls disable line CODE` (see extension docs). SQF-VM is static analysis only; it does not run `compile preprocessFileLineNumbers` chains or prove mission behaviour.

**Headless dedicated-server tests (optional, slow with full modset):** `powershell -ExecutionPolicy Bypass -File tools\headless\Run-FadeHeadlessTest.ps1` — boots `C:\Arma3Server` via `Face\local_server`, runs **MissionTestSuite** server checks, parses RPT, exits non-zero on failure. Modes: `-Mode boot`, `-Mode compile` (default), `-Mode playthrough`, `-Mode all`. Config: `tools\headless\headless.local.json`. Cursor agent workflow: `.cursor/skills/fade-headless-test/SKILL.md`.

**Mission playthrough tests:** `[] call FAC_playthroughSuite_execAll` (second dev scroll-wheel action). RPT filter: `[FAC Playthrough]`. Runs all 19 mission types in **≤10 minutes** with **no player input** after exec (server teleports + win cheats). Phases: (1) init checks, (2) per-type win simulation, (4) short task-state assertions. Abort: `[] call FAC_playthroughSuite_abort`. Tune `FAC_playthroughSuite__suiteBudgetSec` and phase toggles in `rsc/MissionPlaythroughProfiles.sqf`.
