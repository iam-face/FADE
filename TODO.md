# FADE planned features

Backlog for upcoming systems and fixes. Shipped behaviour is summarised in **README.md**. Git history still has the original plans.

**Conventions (all items):** server authority (`isServer`), scenario data from **missionNamespace**, mission runners via **`FADE_installMissionModules`** + **`FADE_runMission_<Type>`**, client feedback via **`remoteExec`** to `_player` / **`FADE_showMissionHint`**, new server RPCs **`publicVariable`'d** in **initServer** / **ServerGameplay***, GUIs via **`FAC_*Gui_fnc`** dispatcher, placement via **`FADE_findSafePosArray`** / civ-zone snap helpers. See **`.cursor/agent-docs/AGENTS_PATTERNS.md`** and **SCRIPT_INDEX.md**.

### Status index

| # | Item | Status |
|---|------|--------|
| 1 | Spoken radio messages | Open |
| 11 | Operation v2 | Open |
| 13 | Portable FADE (mod / multi-map) | Done |
| 14 | Intercept Convoy re-enable | In portable |

---

## 1. Spoken radio messages (in-game AI voice)

**Goal:** Augment text-only **`FADE_aiSideChat`** with engine voice fragments (*"3, engage man, nine o'clock, one hundred metres"*) while keeping subtitles.

### How Arma does it

- Not TTS: faction **sentence databases** (`CfgSentences`, `CfgVoice`, radio protocol) assembled via **`kbTell`** / **`BIS_fnc_kbTell`**.
- Today: **ServerBootstrap.sqf** `FADE_aiSideChat` → `remoteExec ["FADE_aiSideChat_exec", 0]` → `sideChat` / matching-side `systemChat` only.
- Dynamic values must map to **sample tokens** (digit words, clock bearings, distance buckets).

### Expected approach

#### Phase A: research spike (no mission changes)

1. Eden test mission or debug entry on listen server: spawn BLUFOR/OPFOR unit, trial `kbTell` with vanilla sentence IDs from [kbTell wiki](https://community.bistudio.com/wiki/kbTell).
2. Log per-faction what compiles: NATO vs CSAT vs mod factions from **`FADE_scenarioFriendlyFaction`** / **`FADE_scenarioEnemyFaction`**.
3. Decide v1 scope: **friendly AI radio only** + text fallback for OPFOR; expand later.

#### Phase B: `rsc/FADE_RadioVoice.sqf`

| Piece | Responsibility |
|-------|----------------|
| `FADE_radioVoice_bucketDistance` | Round metres → nearest phrase bucket (50 / 100 / 200 / 500 / 1000). |
| `FADE_radioVoice_bucketBearing` | Degrees → clock string token (12 o'clock = bearing to target from speaker). |
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

Port prose from **TroopTransport.sqf**, **MissionCargo.sqf**, **TroopInsertMission.sqf**. Keep template lines short.

#### Phase C: wire into existing API

Extend **ServerBootstrap.sqf** `FADE_aiSideChat`:

```sqf
// params: [_unit, _message, _voiceTemplate, _voiceParams]
// If _voiceTemplate != "" → call FADE_radioVoice_play; always send _message as subtitle via existing exec path
```

No mass replace in v1: migrate the ~10 highest-traffic lines only; leave remainder text-only.

#### Phase D: Scenario / config (optional v2)

- **Config.sqf:** `FADE_radioVoiceEnabled = true` (default on).
- **ScenarioGui** toggle: Radio voice / Subtitles only, passed through **`FADE_applyScenarioSettings`** like AAA.

#### Files to touch

| File | Change |
|------|--------|
| `rsc/FADE_RadioVoice.sqf` | New |
| `rsc/server/ServerBootstrap.sqf` | Extend `FADE_aiSideChat`; compile + PV client handler |
| `initPlayerLocal.sqf` | `FADE_radioVoice_playLocal` definition (or compile RadioVoice on client) |
| `rsc/MissionTestSuite.sqf` | Smoke: compile + mock play does not error |
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

## 11. Operation v2 (intel-gated multi-objective grid)

**Goal:** Global **[G]** replacement for current **Operation**. Players get a **3×3 km grid** (100 m cells) with **three hidden objectives**; intel from **civilian interviews** and **body search** (existing **`FADE_FieldIntel`**) narrows zones before assault.

### Expected approach (separate implementation task)

1. **New runner:** `rsc/missions/OperationMissionV2.sqf`. Do not extend current Operation loop in place; mirror **Raid** multi-zone bootstrap + **FieldIntel** per child task.
2. **Zone layout:** single map pick or random anchor → compute 9×9 grid overlay; pick 3 objective cells server-side (hidden true positions); initial markers show full grid or coarse sub-regions only.
3. **Intel sources:** stack **`FADE_fieldIntel_addPoints`** from body search (wired) + extend **`FADE_civ*`** talk to grant points / grid refinement.
4. **Assault variants:** per revealed objective, delegate to Raid variant picker (KillHVT / RecoverObject / RecoverHostage).
5. **Win:** all three objectives cleared. **Fail:** timeout or critical objective fail (hostage/HVT).
6. **Registration:** new type `"OperationV2"` or replace `"Operation"` after playtest. Keep current Operation until v2 passes headless + playthrough suite.
7. **Hunt:** do not register as its own type.

### Reuse (intel mechanics already shipped)

- **Intel meter:** 0–100; 25/50/75/100% shrink search grid; 100% snap + task destination (`FADE_FieldIntel_applyGeometry`).
- **Civilian talk:** extend ambient talk actions for grid refinement / rumour markers.
- **Building search:** optional decoy sites / intel packages.

### Open questions

- [ ] Replace Operation in GUI immediately or run both behind lobby flag during beta?
- [ ] Show full 3×3 km grid at start vs only outer border until first intel?
- [ ] Decoy objectives (false intel) in v1 or later?

---

## 14. Intercept Convoy re-enable

**Goal:** Bring **Intercept Convoy** back into the Missions GUI. It is currently in **`FADE_disabledMissionTypes`** (`ConfigClientDefaults.sqf` default includes `"InterceptConvoy"`).

### Approach

Work in **`CTB_FAC_FADE_Portable.Stratis`** only. Keep the player contract: global mission, start and end on roads, stop the column before the end (at least 60% destroyed or immobilised). Keep map-click start/end and Random. Do not add a threat-level vehicle table; keep the current soft-plus-a-few-armoured mix and `_scaleOpforCount`.

The route must be a connected road path. `fn_FADE_interceptConvoyRouteWaypoints.sqf` bisects the straight line and snaps each midpoint to the nearest road, so the column and the map line leave the road. Replace that helper with one road-graph walk (`roadsConnectedTo` from the snapped start road to the snapped end road). If no path connects them, return `[]` and keep the existing error hint. Do not use `calculatePath`: it spawns an agent, returns only the first segment, and fires `PathCalculated` twice ([wiki](https://community.bistudio.com/wiki/calculatePath)).

Keep init cheap. The search runs once, inside the mission `spawn` (scheduled). Do not search again from `FADE_startMission`. Snap each end with one `nearRoads` (500 m) and sort at most a few dozen results; sorting a full town set already stalls mission start (`FADE_findOpforGroundVehicleRoadSpawn`). Walk best-first toward the end road and stop at a hard visit cap (about 800). On cap or no link, return `[]`. Delete the 90-try random `nearRoads` loop; random routes try a few civ-zone pairs through the same capped walk. Spawn the column on path points already on the road, so init does not call the road-spawn probe per vehicle. After start, the monitor stays a `sleep 0.5` distance check.

Then slim **`MissionInterceptConvoy.sqf`**:

1. Sample the path into a short MOVE list for the lead (about one point every 200 m). Followers stay one group each, `FOLLOW` on the vehicle ahead, spaced back along the same path. Spawn with **`FADE_spawnCrewedGroundVehicle`**. Drop the 10 s stagger and the speed-under-1 respawn pass.
2. One monitor loop owns the result: 60% inoperable succeeds; lead vehicle reaching the end fails. Delete the waypoint-statement string that deletes the column. Cleanup stays on **`FADE_mission_completeCleanup`**.
3. Markers: start, end, and one polyline of the sampled path. Drop the per-point dots.
4. **`FADE_convoyMinRouteM`**: scale to the playable map (floor about 1200 m, cap at the config value) so a random route can exist on Stratis. Map-click routes use the same floor, not the old 50 m snap.
5. Remove `"InterceptConvoy"` from **`FADE_disabledMissionTypes`** after the playthrough case passes. Do not use Eden **`ROAD_SP_*`**.

### Acceptance

Portable code is in. The Altis copy is unchanged. The headless runner still boots Altis, so these boxes wait on a Stratis run.

- [ ] Start from Missions GUI on dedicated without RPT script errors.
- [ ] Convoy moves along a connected road path; ≥60% destroy/immobilise win still works.
- [ ] PlaythroughSuite InterceptConvoy case passes.
- [ ] Not listed in `FADE_disabledMissionTypes` by default.

---

## Cross-cutting checklist (new missions + systems)

When shipping **Operation v2**, **Radio voice**, or **re-enabled Convoy**:

1. **FADE_MissionCompile.sqf** module list (missions)
2. **ServerGameplayMissions.sqf** types / placement flags
3. **Config.sqf** / **ConfigClientDefaults.sqf** tunables and disabled-type list
4. **MissionsGui.sqf** + **MissionLocationPickGui** if map pick
5. **Missions.sqf** namespace / dispatcher (if new param shape)
6. **FADE_MissionSlots.sqf** / **FAC_MissionTypeLabels.sqf** display names
7. **Briefing.sqf** + **README.md** mission table
8. **SCRIPT_INDEX.md** + **AGENTS_REFERENCE.md**
9. **MissionTestSuite.sqf** + **MissionPlaythroughSuite** as applicable
10. **MissionLore.sqf** hook for new global types
11. Player-facing strings through **fade-player-copy** / Humanizer

---

*Last updated: open specs only. Shipped plans removed (Raid, Invasion, Point Defense, lore, AAA, drones, field intel, factions, recruit board, player copy, construction, non-Altis base pick, objective roadblocks, portable template). Development uses `CTB_FAC_FADE_Portable.Stratis`, not a separate mod PBO.*
