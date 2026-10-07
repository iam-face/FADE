# FADE (Face's Dynamic Environment)

**Beta 7.** FADE is a multiplayer Arma 3 sandbox mission on Altis. Players configure the fight and run training or dynamic missions from boards and GUIs at a fixed player base. You do not need Zeus for day-to-day play.

It is built for rotary, joint fires, and infantry practice on a listen server or dedicated server. Up to 31 players. Mission folder name: `CTB_FAC_FADE.Altis`.

Server owns scenario state, AI, and mission spawns. Clients use GUIs and get updates over `remoteExec` / public variables. Lobby parameters in `description.ext` set access locks and starting defaults before the mission starts.

---

## How a session runs

1. Open **Manage Scenario** at the mission board: weather, time, friendly/enemy/civilian factions, OPFOR threat, civilians, gear policy, and related options.
2. Open **Manage Missions**: pick a type, read the in-GUI blurb, start. Some types ask for a map click or player pick first.
3. Use base terminals and boards for vehicles, loadouts, recruit AI, fast travel, CQB, jukebox, medical training, live-fire / AT / sniper ranges, and the FIRES range.

Admins and Zeus can usually override group-leader-only GUI locks. Changes from Scenario apply on the server and sync to players who join later (JIP).

---

## Features

### Scenario control

- Weather, time of day, and gear policy (including optional ACE Arsenal on loadout boxes).
- Friendly, enemy, and civilian factions from `CfgFactionClasses`, limited to factions the server can spawn infantry for. Friendly list covers EAST / WEST / GUER. Enemy list is filtered to opposed sides (GUER counts as hostile to both majors). Apply rejects a faction with no infantry and keeps the previous one. Invalid mixes are corrected on Apply with a hint; player side syncs on Apply, JIP, and respawn.
- OPFOR population multiplier, patrols (including town chance), skill / routing / retreat behaviour, and AAA (Off / AAA / AAA+MANPADS).
- OPFOR grenades (Normal / Reduced / Minimal / None, default Reduced): caps thrown HE, under-barrel HE, and dedicated grenade launchers on enemy infantry. Smoke, flares, and chemlights stay.
- OPFOR player scaling (default On): garrison, patrol, and QRF counts follow alive player count on top of the population multiplier. Off keeps population-only counts.
- OPFOR air and drones (Off / Low / Normal / High): ambient UAV patrol plus QRF vectoring when configured.
- Ambient civilian budget and density; who may talk to civilians; who may read building intel.
- HQ auto-heal and other gameplay toggles from lobby and Scenario Admin.
- Scenario Admin tab for operators (access locked by lobby param).

### Missions

**Global [G]** missions share one slot for the whole server. **Single [S]** missions are per player (up to three at once). The tables below list every type currently wired in the Missions GUI (including Intercept Convoy, which is disabled for start).

In-GUI blurbs under Manage Missions are the source of truth for objectives and win conditions. Mission logic lives under `rsc/missions/`; `rsc/Missions.sqf` dispatches.

Search-style globals (HVT, Hostage, Search & Destroy, Asset Retrieval, Raid) use 100 m grid search zones and shared `mil_*` map markers. Dead OPFOR can be searched for field intel that tightens those zones (server-side, dedicated-safe).

**Intercept Convoy** is temporarily hidden in the Missions GUI (`FADE_disabledMissionTypes`) while route and spawn fixes finish.

#### Global [G] (one at a time)

| Mission | Summary |
|--------|---------|
| Area of Operations | Large fight with multiple objectives in a wide sector. |
| Asset Retrieval | Recover equipment from enemy ground, then extract. |
| CAS / Fire Support | Support friendlies under attack. |
| Clear Area | Assault a town or camp. |
| CSAR | Recover personnel from a crash site. |
| Escape & Evasion | Evadees separated in hostile ground; rescue force recovers them. |
| Geo-Guesser | Navigation drill: map-click guess where you were dropped; ranked scoring. |
| Hostage | Rescue civilians from a built-up site (free hold action on hostages). |
| HVT | Find, kill, or capture a priority target. |
| Intercept Convoy | Stop a moving column before it finishes its route. (disabled in GUI for now) |
| Invasion | OPFOR beachhead through nearest civil zones; retake INVASION to win. |
| Point Defense | Hold a 250 m zone against assault waves for a set duration (timer starts when a player enters). |
| Operation | Clear outer zones, then capture the OPFOR HQ hub. |
| Raid | Three linked objectives (mixed task types) across the map; target buildings marked. |
| Search & Destroy | Find and destroy enemy ammo caches in a marked zone. |

#### Single [S] (per player, up to 3)

| Mission | Summary |
|--------|---------|
| Troop Insert | Insert a squad from base to a chosen LZ. |
| Troop Extract | Pick up a team and return to base. |
| Cargo / Resupply | Deliver supplies to a forward camp (sling-load optional). |
| CASEVAC | Evacuate wounded to base. |
| Mine Clearing | Clear mines or IEDs on a road segment. |

### Vehicles

- Vehicle GUI at the vehicle terminal / board: spawn aircraft and land vehicles onto pads (`HP_1` to `HP_8`, `VEH_1` / `VEH_2`).
- Search, faction filter, optional aircraft whitelist.
- Manage spawned assets: ammo, fuel, health, pylons / loadouts where the vehicle supports them.
- Pad indicators update which pads are free.

### Loadouts

- Loadout GUI at loadout boxes / boards: presets, session save, apply.
- Optional ACE Arsenal actions on those boxes (lobby: ACCESS Loadout box ACE Arsenal).

### Recruit

- `hqRecruitBoard`: spawn or dismiss friendly AI with custom presets or faction infantry.
- Assign recruits to any friendly group; dismiss from the Roster tab.
- Lobby access: Everyone / Group leaders / Admin.

### Training ranges

- **CQB** shoothouse (`cqbBoard`, `CQB_POS_*`).
- **Medical** training terminal: ACE + KAT dummies at `MEDICAL_1`.
- **Firing / AT** and **sniper** ranges with info boards.
- **FIRES** terminal: call-for-fire practice, fall-of-shot / drone video screens (`terminalFires`, `droneVideoScreen`, `firesScreenPos_*`).

### Base and world

- Fast travel boards around base (base, medical, pads, range, CQB, locker, pub, and related spots). Lobby can restrict teleport-to-player.
- Ambient civilians in map-derived zones (`CIV_T_*`); talk for tips; building intel packages; dynamic roadblocks.
- Terrain survey (`FADE_AoSurvey`) buckets roads, flat ground, forest, and buildings for patrol placement.
- Jukebox on `Radio_1` to `Radio_4` plus in-vehicle loudspeaker (`@CTB - Mission Sounds Library`). Scenario Admin can stop all.
- Map diary briefing with scenario notes and joint-fires reference (`rsc/Briefing.sqf`).
- MOTD boards rotate messages; HQ main board shows the current procedural op name.
- Procedural mission lore / SMEAC-style brief content for started missions.

### Lobby parameters (`description.ext`)

Grouped roughly as:

- **ACCESS:** Scenario, Missions, Vehicle, Loadout, Recruit, Jukebox, Fast Travel to player, Scenario Admin, ACE Arsenal on loadout boxes.
- **CIVILIANS:** Ambient on/off at start, who can interrogate, who can read intel.
- **GAMEPLAY:** Gear policy, HQ auto-heal.
- **MISSIONS:** AO strength.
- **OPFOR:** Air, drones, grenades, patrols, patrol town chance, player scaling, population multiplier.
- **WORLD:** Starting time and weather.
- **DEBUG:** Spawn prints, garrison building markers, civilian town markers, script debug tools (including Zeus via Admin tab when enabled).

---

## Mods

Vanilla-friendly core. **ACE** and **KAT** are expected for full medical training and CASEVAC depth. Keep the dedicated server mod list aligned with the addons listed in `mission.sqm`.

---

## Planned work

Full backlog and design notes: [TODO.md](TODO.md). Status there is the source of truth.

**Open**

- **Intercept Convoy re-enable** (`FADE_disabledMissionTypes`): fix route / road spawn / RPT errors, then show it in the Missions GUI again.
- **SEAD / DEAD:** destroy enemy air-defence sites in a sector (reuse AAA class resolution).
- **Operation v2:** intel-gated 3×3 km grid with three hidden objectives (civ talk + body search); replaces standalone Hunt (not planned as its own type).
- **Spoken radio:** `kbTell` voice on top of existing `FADE_aiSideChat` subtitles.
- **OPFOR roadblocks:** place blocks using `FADE_AoSurvey` road buckets and real player traffic.
- **Commander / RCT-C:** map-order UI at a command tent (HQ recruit board already covers base spawn/dismiss). Deferred until after Operation v2.
- **Portable FADE:** mod package + Eden base module so FADE can run on maps other than Altis with thin mission glue.

**Already shipped (see Features above, not the open list):** Raid, Invasion, Point Defense, lore, AAA engagement fix, OPFOR drones, field intel / grid search / AoSurvey, any-side factions, HQ recruit board, player-facing copy pass.

---

## For contributors

Entry points: `initServer.sqf` (loads `rsc/server/`) and `initPlayerLocal.sqf`. Per-type runners sit in `rsc/missions/`; shared helpers use `FADE_*` (server / world / missions) and `FAC_*` (client GUIs, theme, lobby). Local AI notes may sit in `.cursor/agent-docs/` (gitignored). Tracked Cursor skills under `.cursor/skills/` include humanizer and fade-player-copy.

**Regression tests:** `[] call FAC_missionTestSuite_execAll` (debug-tools lobby param adds a scroll-wheel action). RPT filter: `[FAC TestSuite]`. Covers compile, RPCs, placement, SMEAC/intel per type, zone pickers, and client GUI scripts. It does not run full playthroughs.

**Mission playthrough tests:** `[] call FAC_playthroughSuite_execAll` (second dev scroll-wheel action). RPT filter: `[FAC Playthrough]`. Runs mission types in about 10 minutes or less with no player input after exec (server teleports and win cheats). Abort with `[] call FAC_playthroughSuite_abort`. Tune budget and phase toggles in `rsc/MissionPlaythroughProfiles.sqf`.

**Offline SQF lint:** Install the [SQF-VM Language Server](https://marketplace.visualstudio.com/items?itemName=SQF-VM.sqf-vm-language-server) in Cursor/VS Code. From the mission folder: `powershell -ExecutionPolicy Bypass -File ..\tools\sqfvm\Invoke-FadeSqfLint.ps1 -InstallIfMissing`. Static analysis only; it does not prove runtime mission behaviour.

**Headless dedicated tests (optional):** `powershell -ExecutionPolicy Bypass -File ..\tools\headless\Run-FadeHeadlessTest.ps1`. Modes: `-Mode boot`, `-Mode compile` (default), `-Mode playthrough`, `-Mode all`. Config: `..\tools\headless\headless.local.json`. Agent workflow: `.cursor/skills/fade-headless-test/SKILL.md`.
