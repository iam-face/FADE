# FADE — Planned features

Backlog for upcoming mission systems and fixes. For shipped behaviour see **README.md**.

**Conventions (all items):** server authority (`isServer`), scenario data from **missionNamespace**, mission runners via **`FADE_installMissionModules`** + **`FADE_runMission_<Type>`**, client feedback via **`remoteExec`** to `_player` / **`FADE_showMissionHint`**, new server RPCs **`publicVariable`'d** in **initServer** / **ServerGameplay***, GUIs via **`FAC_*Gui_fnc`** dispatcher, placement via **`FADE_findSafePosArray`** / civ-zone snap helpers — see **`.cursor/agent-docs/AGENTS_PATTERNS.md`** and **SCRIPT_INDEX.md**.

---

## 1. Spoken radio messages (in-game AI voice)

**Goal:** Augment text-only **`FADE_aiSideChat`** with engine voice fragments (*“3, engage man, nine o’clock, one hundred metres”*) while keeping subtitles.

### How Arma does it

- Not TTS: faction **sentence databases** (`CfgSentences`, `CfgVoice`, radio protocol) assembled via **`kbTell`** / **`BIS_fnc_kbTell`**.
- Today: **ServerBootstrap.sqf** `FADE_aiSideChat` → `remoteExec ["FADE_aiSideChat_exec", 0]` → `sideChat` / matching-side `systemChat` only.
- Dynamic values must map to **sample tokens** (digit words, clock bearings, distance buckets).

### Expected approach

#### Phase A — Research spike (no mission changes)

1. Eden test mission or debug entry on listen server: spawn BLUFOR/OPFOR unit, trial `kbTell` with vanilla sentence IDs from [kbTell wiki](https://community.bistudio.com/wiki/kbTell).
2. Log per-faction what compiles: NATO vs CSAT vs mod factions from **`FADE_scenarioFriendlyFaction`** / **`FADE_scenarioEnemyFaction`**.
3. Decide v1 scope: **BLUFOR AI radio only** (friendly missions) + text fallback for OPFOR; expand later.

#### Phase B — `rsc/FADE_RadioVoice.sqf`

| Piece | Responsibility |
|-------|----------------|
| `FADE_radioVoice_bucketDistance` | Round metres → nearest phrase bucket (50 / 100 / 200 / 500 / 1000). |
| `FADE_radioVoice_bucketBearing` | Degrees → clock string token (12 o’clock = bearing to target from speaker). |
| `FADE_radioVoice_compile` | `params ["_template", "_params"]` → array of kb sentence args or `[]` on failure. |
| `FADE_radioVoice_playLocal` | **Client:** `params ["_unit", "_compiled"]`; run `kbTell` on local AI if possible. |
| `FADE_radioVoice_play` | **Server:** validate unit → pick client (`owner _unit` if ≠ 2, else nearest player within e.g. 2 km) → `remoteExec ["FADE_radioVoice_playLocal", _client]`. |

**Template table** (start small, data-driven array in same file or `rsc/RadioVoiceTemplates.sqf`):

| Template key | Used by | Params |
|--------------|---------|--------|
| `PICKUP_STANDBY` | TroopTransport | callsign |
| `PICKUP_GRID` | TroopTransport | callsign, grid |
| `CONTACT_STROBES` | TroopTransport | callsign |
| `CARGO_SIGHT` | MissionCargo | callsign |
| `QRF_WARNING` | counter-attack (optional) | bearing, distance |

Port prose from **TroopTransport.sqf**, **MissionCargo.sqf**, **TroopInsertMission.sqf** — keep template lines short.

#### Phase C — Wire into existing API

Extend **ServerBootstrap.sqf** `FADE_aiSideChat`:

```sqf
// params: [_unit, _message, _voiceTemplate, _voiceParams]
// If _voiceTemplate != "" → call FADE_radioVoice_play; always send _message as subtitle via existing exec path
```

No mass replace in v1: migrate the ~10 highest-traffic lines only; leave remainder text-only.

#### Phase D — Scenario / config (optional v2)

- **Config.sqf:** `FADE_radioVoiceEnabled = true` (default on).
- **ScenarioGui** toggle: Radio voice / Subtitles only — passed through **`FADE_applyScenarioSettings`** like AAA.

#### Files to touch

| File | Change |
|------|--------|
| `rsc/FADE_RadioVoice.sqf` | New |
| `rsc/server/ServerBootstrap.sqf` | Extend `FADE_aiSideChat`; compile + PV client handler |
| `initPlayerLocal.sqf` | `FADE_radioVoice_playLocal` definition (or compile RadioVoice on client) |
| `rsc/MissionTestSuite.sqf` | Smoke: compile + mock play doesn’t error |
| `rsc/Briefing.sqf` | Note radio behaviour if player-facing |

#### Testing

- Listen server: troop extract pickup lines audible + subtitle.
- Dedicated: AI not local → voice still plays on assigned client.
- Mod faction missing voice bank → text only, no RPT spam.

### Acceptance

- [ ] ≥3 existing mission lines play as heard radio on listen server.
- [ ] Subtitles on matching side via existing chat path.
- [ ] Text-only fallback when compile fails.

### Open questions

- [ ] Subtitle always on, or only when voice fails?
- [ ] OPFOR voice in v1 or v2?

---

## 2. Raid mission type

**Goal:** Global **[G]** mission — **3 objectives** at separate locations (map-click snap to **CIV_T_*** or random), each a random **variant** from a pool; complete all 3 to win; guarded zones + **immediate QRF** on detection.

### Expected approach

#### Registration (same pattern as Operation / AO)

1. **`rsc/missions/MissionRaid.sqf`** — export `FADE_runMission_Raid` (and optional `FADE_raidMissionMain` if loop is large).
2. **`rsc/FADE_MissionCompile.sqf`** — add to `FADE_missionModuleList`.
3. **`rsc/server/ServerGameplayMissions.sqf`** — add `"Raid"` to `FADE_globalMissionTypes`; add to `_spawnsEnemies`; map-click snap via existing **`FADE_missionMapClickSnapCivZoneTypes`** (same as Operation).
4. **`rsc/Config.sqf`** — `FADE_raidObjectiveCount = 3`, `FADE_raidQrfSkipDetectionWait = true`, `FADE_raidTimeoutSec = 0` (0 = none).
5. **`rsc/MissionsGui.sqf`** — list entry + blurb; **START** → **`FAC_missionLocationPickGui_fnc`** (Random / map click) like Operation.
6. **`rsc/Missions.sqf`** — dispatcher already resolves `FADE_runMission_%1`; no change if export name matches **`Raid`**.
7. **`FADE_globalMissionTypesWithQrf`** in **Config.sqf** — add `"Raid"` for civ rumours.
8. **README.md**, **Briefing.sqf**, **SCRIPT_INDEX.md**, **AGENTS_REFERENCE.md** when shipping.

#### Mission flow (`FADE_runMission_Raid`)

Mirror **OperationMission.sqf** / **MissionHVT.sqf** bootstrap:

1. Read **`FADE_missionRun_*`** namespace vars set by **Missions.sqf** (same as **MissionAssetRetrieval.sqf** header).
2. **Zone pick** — `FADE_raid_pickZones`:
   - Pool: **CIV_T_*** centres ≥1 km **BASE_1** (copy Operation’s `_zoneCandidates` filter).
   - If `_mapAnchor` valid: sort by distance to anchor, take nearest 3 distinct zones ≥ **`FADE_minDistBetweenMissions`** apart.
   - Else: shuffle + spacing check (retry up to N attempts).
3. **Variant pick** — per zone, weighted random from:

| Variant ID | Reuse from | Win condition |
|------------|------------|---------------|
| `RecoverObject` | Asset branch 1 (intel/hold) | Hold action complete + flag |
| `DestroyVehicle` | S&D / convoy vehicle destroy | `Killed` EH on mission vehicle |
| `KillHVT` | **MissionHVT.sqf** kill branch | HVT dead |
| `CaptureHVT` | **MissionHVT.sqf** capture | HVT within 100 m **BASE_1** |
| `RecoverHostage` | **MissionHostage.sqf** (single hostage) | Alive hostage within 100 m base |

4. **Spawn** — per zone: **`FADE_MissionSpawn.sqf`** helpers + urban garrison if near buildings; push groups to `_allGroups` for cleanup.
5. **Tasks** — parent `BIS_fnc_taskCreate` + 3 child tasks (`raid_obj_1`…); states update on variant complete.
6. **QRF** — per zone, on mission start spawn a monitor thread OR one-shot per zone:
   ```sqf
   [_taskId, _zonePos, _basePos, _enemyUnits, _allGroups, 450, true] call FADE_counterAttackStart;
   ```
   **`_skipDetectionWait = true`** for immediate QRF after **`FADE_raidQrfFirstDelaySec`** (new Config, default **0–30 s** not 120–360). Consider **`FADE_counterAttackFirstDelayMin/Max`** override only for Raid via extra param or missionNamespace flag **`FADE_counterAttack_immediateMode`**.
7. **Win** — all 3 variant flags true → parent SUCCEEDED → **`FADE_clearActiveMission`** / stream cleanup.
8. **Fail** — hostage variant: >50% hostages dead; optional global timeout.
9. **SMEAC** — **`FADE_formatSituationIntelHtml`** + **`FADE_showMissionAssignedIntro`**; inject **lore** paragraph when §3 ships.
10. **Cleanup** — delete markers, groups, hold actions, EHs; unregister retreat if used.

#### Refactor note (incremental)

Extract shared snippets into **FADE_MissionCommon.sqf** only when second copy is needed:

- `FADE_objective_spawnHVT`
- `FADE_objective_addRecoverHoldAction`
- `FADE_objective_trackHostageWin`

Do not block Raid on full extract — copy-paste + comment `// TODO: shared with HVT` is acceptable for v1 per project minimal-diff norm.

#### Files to touch

| File | Change |
|------|--------|
| `rsc/missions/MissionRaid.sqf` | New runner |
| `rsc/FADE_MissionCompile.sqf` | Module list |
| `rsc/server/ServerGameplayMissions.sqf` | Global type, placement |
| `rsc/Config.sqf` | Raid tunables, QRF list |
| `rsc/MissionsGui.sqf` | GUI entry |
| `rsc/server/ServerWorld.sqf` | Optional: `FADE_counterAttackStart` immediate mode |
| `rsc/MissionTestSuite.sqf` | `FADE_runMission_Raid` exists |

### Acceptance

- [ ] 3 parallel tasks on map; completing each updates child task.
- [ ] QRF wave spawns without 2-minute detection wait when player enters zone.
- [ ] Global slot rules enforced (one Raid at a time).
- [ ] Dedicated server PASS.

### Open questions

- [ ] Recover object: in-zone hold only vs return to base?
- [ ] Duplicate variant types across zones? **Recommend yes.**

---

## 3. Lore mechanic (mad-libs mission background)

**Goal:** Procedural **situation paragraph** per mission — BLUFOR/OPFOR roles, stakes, region — flavour only; feeds SMEAC/diary.

### Expected approach

#### Data — `rsc/MissionLore.sqf` (compile at boot with **OperationNames.sqf**)

Structure (mirror **OperationNames.sqf** style):

```sqf
FADE_lore_pool_bluforRole = ["peacekeeping detachment", "quick-reaction force", ...];
FADE_lore_pool_opforRole = ["insurgent cell", "garrison force", ...];
FADE_lore_pool_instigator = ["seized a relay station", "ambushed a supply convoy", ...];
FADE_lore_pool_stakes = ["restore government control", "recover critical equipment", ...];
FADE_lore_pool_timeHook = ["before nightfall", "before reinforcements arrive", ...];

// Per mission type: array of format strings
FADE_lore_templates_Raid = [
  "{opforRole} {instigator} near {region}. {bluforRole} must {stakes} {timeHook}."
];
```

**Slot resolvers** (`FADE_lore_resolveSlot`):

| Slot | Source |
|------|--------|
| `{opName}` | Existing **`FADE_generateOperationName`** / mission stream entry |
| `{region}` | **`FADE_getTopographySummary`** on objective pos (already in **FADE_MissionCommon.sqf**) |
| `{bluforRole}` / `{opforRole}` | Pools + **`getText (CfgFactionClasses >> displayName)`** |
| `{civSituation}` | Optional: nearest **CIV_T_*** tier from ambient metadata |

**API:** `FADE_lore_generate = { params ["_missionType", "_destPos"]; /* returns [shortSituation, longParagraph] */ }`

#### Integration points

| Consumer | Hook |
|----------|------|
| **Missions.sqf** | After op name generated: `FADE_missionRun_loreShort` / `FADE_missionRun_loreLong` on missionNamespace |
| **FADE_MissionCommon.sqf** | Append `{loreShort}` to SMEAC Situation HTML builder |
| **`FADE_showMissionAssignedIntro`** | Optional second line in type-text sequence |
| **FADE_client_appendIntelDiary** (**FADE_ClientCommon.sqf**) | On mission assign: diary **Intel — Background** with `{loreLong}` |
| **FADE_missionSlots_publish** | Optional: truncate lore to 1 line on **hqMainBoard** (low priority) |

#### Mission types (rollout order)

1. Raid, Operation, AreaOfOperations, HVT (high narrative value).
2. Remaining globals — add 1–2 templates each as needed.
3. Singles — one generic template keyed by `{missionType}`.

#### Files to touch

| File | Change |
|------|--------|
| `rsc/MissionLore.sqf` | New pools + generator |
| `initServer.sqf` or **ServerBootstrap** | `compile preprocessFileLineNumbers` MissionLore |
| `rsc/Missions.sqf` | Call generator before runner |
| `rsc/FADE_MissionCommon.sqf` | SMEAC slot |
| `initPlayerLocal.sqf` | Diary append on intro RPC (or server sends lore in intro payload) |

### Acceptance

- [ ] Lore generates without hardcoded NATO/CSAT strings.
- [ ] Visible in mission intro hint; no gameplay effect.
- [ ] Fails gracefully to empty string if pool missing.

### Open questions

- [ ] Seed per mission for reproducibility in briefing vs pure random?
- [ ] Tone filter for server/community-safe word pools (OperationNames already has edgy entries — separate **lore** pools may want stricter list).

---

## 4. Invasion mission type

**Goal:** Global **[G]** **defensive** mission — OPFOR invades from a **map corner**, holds beachhead, **captures civ zones** in sequence; BLUFOR defends.

### Expected approach

#### Strategy: fork Operation, invert capture

**OperationMission.sqf** already has:

- 5 s poll loop, zone markers (enemy / contested / friendly), ellipse capture ~250 m, fleet vehicles between zones, QRF on contest, **`FADE_operationZoneCount`**, cleanup intervals.

**Invasion** = copy structure to **`rsc/missions/MissionInvasion.sqf`** with **`FADE_invasion_*`** prefix (do not mutate Operation in place).

#### Zone selection — `FADE_invasion_pickZones`

1. `private _world = worldSize;`
2. Corners: `[0,0]`, `[_world,0]`, `[0,_world]`, `[_world,_world]`.
3. For each corner: nearest **CIV_T_*** trigger centre (≥1 km **BASE_1**) → 4 candidates; **pick 1** at random = **invasion beachhead**.
4. From remaining civ zones (eligible list): pick **furthest** from invasion = **deep zone** (must be in set).
5. `_wantN = (FADE_operationZoneCount max 2) min 10` — same scenario slider as Operation (update **ScenarioGui** tooltip: “Operation + Invasion zone count”).
6. Fill remaining slots: zones sorted by distance from invasion (ascending) = OPFOR advance route order.

#### Capture logic (invert Operation)

| Operation | Invasion |
|-----------|----------|
| BLUFOR presence + clear OPFOR → friendly | OPFOR presence + clear BLUFOR → **OPFOR-held** |
| Markers: player attacks red zones | Markers: player defends; invasion zone = special marker **INVASION** |

Implement `FADE_invasion_evaluateZone` mirroring Operation’s contested check with sides swapped. Initial state: all zones **friendly** except invasion zone **OPFOR-held** with garrison.

#### OPFOR behaviour

1. **Beachhead:** persistent spawn point at invasion zone (infantry + **`FADE_operationMaxFleetVehicles`** cap reused); resupply timer from **`FADE_operationVehicleResupplyMin/Max`**.
2. **Advance:** convoys/patrols from invasion → next **uncaptured** zone on route list (reuse Operation vehicle waypoint chain pattern).
3. **Reinforcements:** timer wave from beachhead + bonus on each OPFOR capture (not BLUFOR QRF).
4. **AI policy:** **`FAC_applyEnemyScenarioToGroup`**, **`FADE_enemySkill`**, no **`FADE_registerEnemyRetreat`** on invasion waves (keep pressure).

#### BLUFOR win / lose

| Outcome | Rule (default) |
|---------|----------------|
| **Win** | Survive **30 min** without OPFOR capturing more than **0** zones beyond beachhead OR recapture all OPFOR zones |
| **Lose** | OPFOR captures **all** route zones OR OPFOR squad enters **BASE_1** 200 m radius with no BLUFOR within 300 m |
| Config | `FADE_invasionDurationSec = 1800`, `FADE_invasionLoseZonesCaptured = -1` (all) |

Tune after playtest.

#### Registration

Same checklist as §2 Raid: **FADE_MissionCompile**, **ServerGameplayMissions** (`"Invasion"` global), **MissionsGui**, **Config**, **Briefing**, lore hook, **FADE_missionSlots**.

#### Files to touch

| File | Change |
|------|--------|
| `rsc/missions/MissionInvasion.sqf` | New (fork Operation) |
| `rsc/FADE_MissionCompile.sqf` | Module list |
| `rsc/server/ServerGameplayMissions.sqf` | Type + placement (`_spawnsEnemies`) |
| `rsc/Config.sqf` | Invasion tunables |
| `rsc/MissionsGui.sqf` | Entry + blurb |
| `rsc/ScenarioGui.sqf` | Clarify zone count label |

### Acceptance

- [ ] Invasion zone spawns at corner-near civ zone; OPFOR pushes toward deep zone.
- [ ] BLUFOR can recapture OPFOR-held zones.
- [ ] Win/lose fires correctly; cleanup on abort.
- [ ] Operation mission still passes regression.

### Open questions

- [ ] Win condition: time-based vs “hold all zones” only?
- [ ] Friendly AI defenders auto-spawn at zones or player-only defence?

---

## 5. Commander mechanic (command tent)

**Goal:** **BLUFOR commander** UI at command tent — recruit/manage AI (infantry, vehicles, aircraft), map waypoints, dismiss — **no Zeus**.

### Expected approach

#### Eden / client entry

1. **mission.sqm** — logic object **`terminalCommand`** on command tent (document in **AGENTS_EDEN.md**).
2. **FAC_ClientBoardActions.sqf** — `addAction` → `['open',[]] call FAC_commanderGui_fnc` after **`FADE_clientInitReady`**.
3. **initPlayerLocal.sqf** — `compile preprocessFileLineNumbers "rsc\CommanderGui.sqf"`.

#### GUI — `rsc/CommanderGui.sqf` + **description.ext**

| idd | `RscDisplayCommander` **60900** |
|-----|----------------------------------|
| Tabs | **Recruit** (type list), **Roster** (active units), **Orders** (waypoint) |
| Pattern | **`FAC_commanderGui_fnc`**: `"open"`, `"onLoad"`, `"recruit"`, `"dismiss"`, `"orderMove"` |
| Layout | **BaseControls.hpp**; margins 0.02/0.96; listboxes `lbSetData` = netId / groupId |

**Recruit tab**

- Infantry: headless list from **`FADE_friendlyUnits`** (scenario); count slider; spawn at **`B_SP_1`** (or nearest free **`B_SP_*`**) via server.
- Vehicle: list from **`FADE_getFriendlyVehicleClasses`**; land → **`VEH_1`/`VEH_2`** + **`BIS_fnc_findSafePos`**; air → pad picker like **VehicleGui** (reuse **`FADE_padNames`**).
- Aircraft: **`FADE_spawnHeli`** reuse — do not duplicate spawn logic; commander RPC wraps existing func with ownership tag.

**Roster tab**

- Server-maintained **`FADE_commander_roster`** PV or request/response: `[[groupId, type, displayName, netId], ...]`.
- Buttons: **Dismiss** → server cleanup group + vehicles.

**Orders tab**

- Select roster row → **Set waypoint** → reuse **`FADE_mapClickPick_start`** (**FADE_MapClickPick.sqf**) → `remoteExec ["FADE_commander_setWaypoint", 2]` with `[groupId, pos, "MOVE"|"LAND"]`.

#### Server — `rsc/server/ServerGameplayCommander.sqf` (or `rsc/CommanderServer.sqf`)

Compiled from **ServerGameplay.sqf** shell like other submodules.

| RPC | Behaviour |
|-----|-----------|
| `FADE_commander_requestRoster` | Return tagged groups |
| `FADE_commander_spawnSquad` | Validate cap → `BIS_fnc_spawnGroup` at B_SP → `FADE_commander_tagGroup` |
| `FADE_commander_spawnVehicle` | Validate cap → call **`FADE_spawnHeli`** / land spawn |
| `FADE_commander_dismiss` | Delete group/vehicle if `FADE_commanderOwned` |
| `FADE_commander_setWaypoint` | Server: clear WPs, add move/synchronised **`BIS_fnc_wpLand`** if helo |

**Ownership:** ` _grp setVariable ["FADE_commanderOwned", true, true]; _grp setVariable ["FADE_commanderOwnerUid", _uid, true];`

**Caps (**Config.sqf**):** `FADE_commander_maxInfantry = 24`, `maxVehicles = 4`, `maxAircraft = 2`.

**Authority:** `FADE_commander_playerUid` — first opener sets commander; transfer via UI later (v2). **`FADE_playerCanUseMissionsGui`**-style check optional (SL only).

**Cleanup:** **HandleDisconnect** / Scenario Admin abort → `FADE_commander_dismissAllForUid`.

All RPCs **`publicVariable`** in **initServer** after compile.

#### Phased delivery

| Phase | Scope |
|-------|--------|
| **MVP** | Infantry squad recruit/dismiss, one move WP |
| **V2** | Land vehicles + helo recruit, land WP |
| **V3** | Formation, hold/fire orders, FIRES request stub |

#### Files to touch

| File | Change |
|------|--------|
| `mission.sqm` | `terminalCommand` |
| `rsc/CommanderGui.sqf` | New |
| `description.ext` | Dialog 60900 |
| `rsc/server/ServerGameplayCommander.sqf` | New |
| `rsc/server/ServerGameplay.sqf` | Compile commander module |
| `rsc/Config.sqf` | Caps |
| `rsc/FAC_ClientBoardActions.sqf` | Board action |
| `initPlayerLocal.sqf` | GUI compile |
| `initServer.sqf` / **ServerGameplayMedTrain** area | PV RPCs |
| `rsc/MissionTestSuite.sqf` | RPC surface exists |

### Acceptance

- [ ] Dedicated: recruit squad at B_SP, dismiss, single move order works.
- [ ] Caps enforced server-side (client cannot bypass).
- [ ] No spawn inside base safe radius (<700 m **BASE_1**).

### Open questions

- [ ] Single commander slot vs per-squad leader?
- [ ] Recruited AI count toward ambient friendly caps / performance budget?

---

## 6. Fix AA (Enemy AAA)

**Goal:** Scenario **AAA** / **AAA+MANPADS** produces engaging ground threats for human pilots. **Currently broken.**

### Current implementation (**rsc/EnemyAAA.sqf**)

- Loaded **`execVM`** from **ServerWorld.sqf** after base/civ zones.
- Monitor loop (10 s): **`FADE_aaa_getAirbornePlayerVehicles`** → spawn cluster per aircraft (3 threats at bearings 0°/120°/200°, 1.5–2 km).
- **`FADE_aaa_getStaticLightClass`** — prefers **HMG** displayName heuristic, not missile AA.
- Spawns gunner in static but **no engagement loop** — no `Reveal`, `doTarget`, `commandFire`, or `enableAI`** on aircraft.
- **`FADE_aaa_applyLevel`** only despawns when Off; does not restart monitor (monitor always runs).
- Stubs **`FADE_aaa_maybeSpawnManpadsInZone`** empty (legacy).

### Expected approach

#### Step 1 — Diagnose (add debug, then remove or gate)

```sqf
// Config.sqf
FADE_aaa_debug = false;
// Log: mode, active aircraft count, spawn success/fail reason, cluster count
```

Repro script: Scenario AAA+MANPADS → fly at 300 m AGL >60 s → expect RPT lines + threats on map.

#### Step 2 — Classification fix

Split **ServerWorld** / **EnemyAAA.sqf**:

| Function | Purpose |
|----------|---------|
| `FADE_aaa_getStaticLightClass` | Keep for AO turrets / HMG |
| `FADE_aaa_getStaticAAClass` | New: `staticWeapon` with `airLock` / `maneuvrability` / displayName `aa` / `sam` / `flak` |
| `FADE_aaa_getManpadsUnitClass` | Keep; verify `Reveal` + `targetKnowledge` |

Spawn AA statics in AAA mode when class exists; fall back to HMG only if no faction AA.

#### Step 3 — Engagement loop (root cause fix)

Add **`FADE_aaa_clusterTick`** called from monitor each 10 s (or 3 s when cluster active):

```sqf
// For each gunner / MANPADS unit in cluster:
//   _air = cluster get "vehicle"
//   _gunner reveal [_air, 4]
//   _gunner doTarget _air
//   _static doTarget _air  // if vehicle weapon
//   group _gunner setCombatMode "RED"
//   _gunner enableAI "TARGET"
```

For MANPADS: `unit lock _air` if mod supports; else `commandFire` when `lineOfSight`.

Despawn cluster only when aircraft lands / destroyed / mode Off (existing logic).

#### Step 4 — Spawn reliability

| Issue | Fix |
|-------|-----|
| Position reject | Relax player exclusion 200→100 m in low-pop; log fail count |
| `isTouchingGround` false negative | Also treat `velocity _veh select 2 > 5` as airborne |
| Race on load | **`compile`** EnemyAAA from **ServerWorld** before `execVM`, or `waitUntil {!isNil "FADE_aaa_applyLevel"}` |

#### Step 5 — Balance (**Config.sqf**)

- `FADE_aaa_spawnDistMin/Max`
- `FADE_aaa_maxClustersPerPlayer = 1`
- `FADE_aaa_respawnCooldownSec = 120` after cluster deleted

#### Step 6 — Verification

- **MissionTestSuite**: `FADE_aaa_getStaticAAClass` returns class for vanilla OPFOR; `FADE_aaa_applyLevel` callable.
- Manual: listen + dedicated; AAA vs AAA+MANPADS; confirm shots/missiles in RPT **`Deleted`** not instant cleanup.

#### Files to touch

| File | Change |
|------|--------|
| `rsc/EnemyAAA.sqf` | AA class, engagement tick, debug |
| `rsc/Config.sqf` | Debug + balance |
| `rsc/server/ServerWorld.sqf` | Optional compile-before-execVM |
| `rsc/MissionTestSuite.sqf` | Func existence |
| `rsc/Briefing.sqf` | Player note on AAA behaviour when fixed |

### Acceptance

- [ ] AAA on: threat spawns within 2 km within 60 s of sustained flight.
- [ ] Threat fires (RPT or visual) at aircraft.
- [ ] Off: no clusters; scenario toggle applies without restart.
- [ ] AO static turrets unaffected.

### Open questions

- [ ] Should AAA threaten NPC aircraft or player-only only? (Current: player crew only.)
- [ ] Keep AT infantry in AAA+MANPADS cluster or pure AA?

---

## 7. OPFOR drones (ambient ISR + QRF vectoring)

**Goal:** Scenario setting parallel to **OPFOR air** — when enabled, OPFOR spawns faction-appropriate **UAVs** to patrol / search the battlefield; on spotting **ground** BLUFOR (not players in aircraft), vector an **ambient QRF** to the contact area.

### Design notes

| Aspect | Intent |
|--------|--------|
| Setting | `Off` \| `Low` \| `Medium` — same UX pattern as OPFOR air (Scenario GUI + lobby threat map + `FADE_applyScenarioSettings`) |
| Class pick | **Cfg-driven** from enemy faction (`FADE_getEnemyDroneVehicleClasses`); **fallback list** when faction has no loaded UAV addons |
| Patrol | Low-altitude search orbits over active areas (player centroid, civ zones, mission sectors) — not direct orbit on players |
| Spotting | Drone (or its OPFOR side) `knowsAbout` ≥ threshold on **ground** players only (`vehicle _x isKindOf "Air"` → ignore) |
| QRF | Reuse **`FADE_counterAttackStart`** wave spawn at last-known grid; ambient instance (not mission task-bound) |
| HQ safe | Mirror **`FADE_opforAir_hqSafeRadius`** — despawn / suppress when all friendlies within BASE_1 bubble |
| Separation | OPFOR air explicitly **excludes** UAV classnames today; drones are a **separate** system (no double-count air cap) |

### Expected approach

#### Phase A — Class resolution (mirror `FADE_getEnemyAirVehicleClasses`)

Add to **ServerBootstrap.sqf** (or new **`rsc/FADE_OpforDrones.sqf`** if block grows):

```sqf
FADE_getEnemyDroneVehicleClasses = {
    // Cache: FADE_enemyDroneVehicleClasses_cache (invalidate on faction change in FADE_applyScenarioSettings)
    // Scan FADE_heliClasses + full CfgVehicles pass if needed:
    //   isKindOf "UAV" OR (classname uav/drone) AND NOT isKindOf "Helicopter"/"Plane"
    //   faction == FADE_scenarioEnemyFaction && side == FADE_scenarioEnemySideNum
    // Side-only fallback pass (same pattern as air)
};

FADE_opforDrone_fallbackClasses = [
    "O_UAV_01_F",           // AR-2 Darter
    "O_UAV_06_F",           // AL-6 Pelican
    "O_T_UAV_04_CAS_backpack_F",
    "I_UAV_01_F",
    "B_UAV_01_F"            // last resort if nothing else loads
] select { isClass (configFile >> "CfgVehicles" >> _x) };
```

**Mod note:** RHS / 3CB / CSAT mod UAVs should match via `faction` field when present; filter out **backpack** / **static** launcher classes unless they spawn as flyable UAV.

#### Phase B — Ambient drone manager (mirror P24 OPFOR air)

| Piece | Responsibility |
|-------|----------------|
| `FADE_opforDrone_active` | Array of live UAV objects |
| `FADE_opforDrone_lastSpawnTime` | Cooldown gate |
| `FADE_opforDrone_trySpawn` | Poll entry (45 s loop alongside air, or shared tick) |
| `FADE_opforDrone_doSpawn` | Create UAV FLY, connect to OPFOR side, assign search WPs |
| `FADE_opforDrone_despawnAll` | On setting Off / HQ suppress / scenario apply |

**Intensity** (suggested defaults, tune in **Config.sqf**):

| Setting | Max active | Spawn cooldown | QRF cooldown per contact |
|---------|------------|----------------|--------------------------|
| Low | 1 | 8 min | 12 min |
| Medium | 2 | 5 min | 8 min |

**Spawn gate:** require BLUFOR players outside HQ safe radius (optional: also require existing OPFOR `knowsAbout` **or** always patrol once setting ≠ Off — recommend **patrol without prior contact**, spot → QRF).

**Patrol waypoints:** pick 3–5 points on ellipse ~1.5–3 km around friendly centroid or random civ-zone centre; `MOVE` + `CYCLE`; altitude 120–250 m AGL via `setPosATL` / `flyInHeight`.

**UAV AI:** enable `TARGET` / `AUTOTARGET` on drone if autonomous; for Darter-style, group may be empty — use `connectTerminalToUAV` optional v2; v1 can rely on engine UAV autosearch + side reveal:

```sqf
// Per-tick on active drones (15–30 s):
{ _drone reveal [_x, 4] } forEach _groundPlayersInSensorRange;
```

#### Phase C — Spot → QRF vectoring

New **`FADE_opforDrone_ambientQrf`** (thin wrapper in **ServerWorld.sqf** next to `FADE_counterAttackStart`):

```sqf
// Params: [_contactPosATL]
// - Cooldown: FADE_opforDrone_qrfCooldownSec (per-map, not per-mission)
// - Push groups into FADE_opforDrone_qrfGroups for cleanup
// - Call FADE_counterAttackStart with synthetic taskId "opfor_drone_ambient"
//   and _skipDetectionWait true, short first delay (60–120 s)
// - _taskDone lambda: always false OR time-based expiry — counter-attack thread
//   must not require BIS task; consider extracting wave spawn from
//   FADE_counterAttackStart into FADE_qrfSpawnWaveAtPos (refactor only if needed)
```

**Aircraft exclusion** in spot check:

```sqf
FADE_opforDrone_isGroundPlayer = {
    params ["_u"];
    isPlayer _u && { alive _u } && { !(_u isKindOf "Air") }
    && { !(vehicle _u isKindOf "Air") }
};
```

Optional: **`FADE_qrfSpawnHintFlare`** at contact pos (already exists) + sideChat “UAV reports movement” via **`FADE_aiSideChat`**.

#### Phase D — Scenario / lobby / GUI

Mirror OPFOR air wiring:

| File | Change |
|------|--------|
| `rsc/Config.sqf` | `FADE_opforDroneSetting = "Off"` + tunables |
| `description.ext` | Label + Off/Low/Medium buttons (shift Faction row down or second row under air) |
| `rsc/ScenarioGui.sqf` | `setOpforDrone`, sync buttons, apply payload |
| `rsc/FAC_LobbyParams.sqf` | Map threat tier → drone level (can track air 1:1 initially) |
| `rsc/server/ServerBootstrap.sqf` | `FADE_applyScenarioSettings` param + cache invalidation |
| `rsc/Briefing.sqf` | One line in enemy controls section |

#### Phase E — Cleanup & coexistence

- Tag drones: `FADE_opforDroneAsset` (exclude from Operation fleet cap like air).
- **Admin despawn OPFOR** should call `FADE_opforDrone_despawnAll`.
- Mission **Escape & Evasion** search heli is separate; no change required.
- **FADE_MissionCommon.sqf** situation blurb optional: “Enemy UAV patrols may be active.”

#### Files to touch

| File | Change |
|------|--------|
| `rsc/FADE_OpforDrones.sqf` | New (recommended) — class resolve + spawn/patrol/spot/QRF |
| `rsc/server/ServerBootstrap.sqf` | Compile module; scenario apply; poll loop |
| `rsc/server/ServerWorld.sqf` | Ambient QRF wrapper or shared wave helper |
| `rsc/ScenarioGui.sqf` + `description.ext` | GUI |
| `rsc/FAC_LobbyParams.sqf` | Lobby default |
| `rsc/Config.sqf` | Defaults |
| `rsc/Briefing.sqf` | Player doc |
| `rsc/MissionTestSuite.sqf` | Func smoke |

### Acceptance

- [ ] Off: no drones; existing OPFOR air unchanged.
- [ ] Low/Medium: faction UAV spawns and patrols; vanilla CSAT gets Darter (or fallback).
- [ ] Mod faction with UAV in Cfg uses that class without manual list.
- [ ] Faction with no UAV: fallback list used; mission still runs if at least one fallback class loads.
- [ ] Ground player spotted → QRF wave routes to area; player in heli/plane does not trigger.
- [ ] All players at HQ → drones despawn / no new spawns.
- [ ] Dedicated server PASS.

### Open questions

- [ ] Should drones require prior OPFOR `knowsAbout` before first spawn, or patrol immediately when setting is on?
- [ ] Armed UAV (e.g. Greyhawk) in pool or ISR-only for v1?
- [ ] Single global QRF cooldown vs per-drone contact cooldown?
- [ ] Counter-UAV / AAA interaction — ignore for v1?

---

## 8. Point defense mission

**Goal:** Global **[G]** **defensive** mission — BLUFOR holds a fixed point (FOB, relay, LZ, or map-click anchor) against escalating OPFOR waves until time expires or attackers are defeated.

### Expected approach

- **Fork reference:** **Invasion** (defensive pressure) + **Operation** zone markers; invert win condition to “hold” not “capture”.
- **Zone:** map-click or random snap near **CIV_T_*** / **BASE_1** perimeter; ellipse capture radius ~250 m (reuse Operation constants).
- **Waves:** timed OPFOR infantry + vehicle spawns from bearings outside the zone; intensity scales with wave number; optional QRF on contested state.
- **Win:** survive **`FADE_pointDefenseDurationSec`** (default 20–30 min) with zone never fully OPFOR-held.
- **Lose:** OPFOR uncontested in zone for N consecutive poll ticks, or >50% defenders dead (if friendly AI spawned).
- **Registration:** same checklist as §2 Raid — **MissionPointDefense.sqf**, **FADE_MissionCompile**, **ServerGameplayMissions**, **MissionsGui**, **Config**, lore hook.

### Open questions

- [ ] Player-chosen defend site vs random only?
- [ ] Auto-spawn friendly AI defenders or player-only?
- [ ] Single zone vs secondary fallback position?

---

## 9. SEAD / DEAD mission (destroy enemy air defences)

**Goal:** Global **[G]** — locate and **destroy** enemy air-defence assets (static AA, SAM sites, MANPADS caches, radar) in a marked sector before a time limit or before friendly air can be called (optional CAS phase).

### Expected approach

- **Targets:** reuse **`FADE_aaa_getStaticAAClass`** / **`EnemyAAA.sqf`** classification; spawn 2–4 clustered sites in one **CIV_T_*** zone or map-click sector.
- **Intel:** approximate markers (large ellipse) until players enter zone or complete a building search; refine to exact site on proximity.
- **Win:** all AA objectives destroyed (`Killed` EH on static / crate) or marked “destroyed” via hold action on radar truck.
- **Fail:** timeout; optional lose if friendly aircraft destroyed (tie to scenario AAA for ambient threat during mission).
- **Reuse:** **Search & Destroy** cache loop pattern + **Clear Area** garrison; no new QRF pattern required unless detection triggers counter-attack.
- **Registration:** **MissionSEAD.sqf** (or **MissionDead.sqf**), global type, map-click placement like S&D.

### Open questions

- [ ] SEAD (suppress) vs DEAD (kill) — v1 destroy-only or include “disable for 10 min” hold action?
- [ ] Tie to player-flown CAS objective or ground-only?
- [ ] Spawn live AAA that engages players during mission vs static props only?

---

## 10. Hunt mission (intel → locate camp / HVT)

**Goal:** Global **[G]** — enemy **camp** or **HVT** location is **hidden** at start; players **interview civilians**, search buildings, or recover intel objects to narrow the search area; assault phase unlocks after enough intel.

### Expected approach

- **Hidden objective:** true position stored server-side; map shows only region-tier hint (e.g. nearest **CIV_T_*** name) until intel thresholds met.
- **Intel sources** (stackable):
  - **Civilian talk** — extend ambient **`FADE_civ*`** / talk actions: chance to grant grid refinement or “rumour” marker.
  - **Building search** — reuse intel package / hold-search pattern from existing building intel.
  - **Recover object** — laptop, map, phone at decoy sites (Asset Retrieval branch).
- **Intel meter:** 0–100; each source adds points; at 25/50/75% shrink search ellipse; at 100% reveal exact marker + optional task waypoint.
- **Assault:** on reveal, spawn or activate garrison / HVT at true pos (**MissionHVT.sqf** / **Clear Area** spawn helpers).
- **Win:** HVT killed/captured or camp cleared per variant; **Fail:** HVT escapes after reveal (vehicle flee) or timeout with intel <100%.
- **Registration:** **MissionHunt.sqf**, global type; no map-click required (random region) or optional anchor like HVT.

### Open questions

- [ ] Camp clear vs HVT kill/capture — random variant or player choice in GUI?
- [ ] Decoy camps (false intel) in v1 or v2?
- [ ] Require minimum civilian talk count vs any intel path to 100%?

---

## Cross-cutting checklist (new missions + systems)

When shipping **Raid**, **Invasion**, **Point defense**, **SEAD/DEAD**, **Hunt**, **Commander**, or **Radio voice**:

1. **FADE_MissionCompile.sqf** module list  
2. **ServerGameplayMissions.sqf** types / placement flags  
3. **Config.sqf** tunables  
4. **MissionsGui.sqf** + **MissionLocationPickGui** if map pick  
5. **Missions.sqf** namespace / dispatcher (if new param shape)  
6. **FADE_missionSlots** / **FADE_MissionSlots.sqf** display name  
7. **Briefing.sqf** + **README.md** mission table  
8. **SCRIPT_INDEX.md** + **AGENTS_REFERENCE.md**  
9. **MissionTestSuite.sqf** compile + RPC smoke  
10. **Lore** hook when §3 done  

---

*Last expanded: planning pass — circle back to refine open questions and estimates.*
