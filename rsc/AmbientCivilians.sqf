// =============================================================================
// AmbientCivilians.sqf - Civ spawn/despawn (CIV_T_* zone refs from FADE_civZonesFromLocations_build; road vehicles use active zones + roads).
//   Ambient road cars: optional one-shot Sig jukebox track (FAC_jukebox_clientPlay + vehicle netId); see FADE_civ_*CarRadio* vars.
// =============================================================================
// ONLY uses FADE_scenarioCivFaction from Scenario GUI. No fallbacks.
// If selected faction has no civilian units/vehicles: shows hint error, does not spawn.
// Spawned units are marked BIS_cp_excluded / FADE_ambientCiv so BIS Civilian Presence
// (or mods like CPE) skip them and don't call bis_fnc_cp_main (avoids undefined-variable RPT errors).
// =============================================================================
// v4 - GUI faction only, no defaults
// =============================================================================

if (!isServer) exitWith {};
diag_log "[AmbientCivilians] v4 loading (GUI faction only)";

// bis_fnc_cp_* stubs: see Config.sqf (loaded before this on server)

// Store config in missionNamespace
missionNamespace setVariable ["FADE_civTriggerIndexMax", missionNamespace getVariable ["FADE_civTriggerIndexMax", if (isNil "FADE_civTriggerIndexMax") then { 109 } else { FADE_civTriggerIndexMax }]];
missionNamespace setVariable ["FADE_civCheckInterval", missionNamespace getVariable ["FADE_civCheckInterval", 45]];
missionNamespace setVariable ["FADE_roadSpawnIntervalMin", missionNamespace getVariable ["FADE_roadSpawnIntervalMin", 90]];
missionNamespace setVariable ["FADE_roadSpawnIntervalMax", missionNamespace getVariable ["FADE_roadSpawnIntervalMax", 180]];
missionNamespace setVariable ["FADE_roadSpawnTickSec", missionNamespace getVariable ["FADE_roadSpawnTickSec", 60]];
missionNamespace setVariable ["FADE_roadSpawnChance", missionNamespace getVariable ["FADE_roadSpawnChance", 1]];
missionNamespace setVariable ["FADE_roadSpawnRingMin", missionNamespace getVariable ["FADE_roadSpawnRingMin", 1000]];
missionNamespace setVariable ["FADE_roadSpawnRingMax", missionNamespace getVariable ["FADE_roadSpawnRingMax", 2500]];
missionNamespace setVariable ["FADE_roadSpawnPlayerClear", missionNamespace getVariable ["FADE_roadSpawnPlayerClear", 500]];
missionNamespace setVariable ["FADE_roadFinalWpMinDist", missionNamespace getVariable ["FADE_roadFinalWpMinDist", 2000]];
missionNamespace setVariable ["FADE_civPlayerActivateDist", missionNamespace getVariable ["FADE_civPlayerActivateDist", 900]];
missionNamespace setVariable ["FADE_civPlayerDeactivateDist", missionNamespace getVariable ["FADE_civPlayerDeactivateDist", 1150]];
missionNamespace setVariable ["FADE_civSpawnRadius", missionNamespace getVariable ["FADE_civSpawnRadius", 1000]];
missionNamespace setVariable ["FADE_civFootSpawnRadius", missionNamespace getVariable ["FADE_civFootSpawnRadius", if (isNil "FADE_civFootSpawnRadius") then { 200 } else { FADE_civFootSpawnRadius }]];
missionNamespace setVariable ["FADE_civFootSpawnMinSep", missionNamespace getVariable ["FADE_civFootSpawnMinSep", if (isNil "FADE_civFootSpawnMinSep") then { 28 } else { FADE_civFootSpawnMinSep }]];
missionNamespace setVariable ["FADE_civParkedBuildingScanRadius", missionNamespace getVariable ["FADE_civParkedBuildingScanRadius", if (isNil "FADE_civParkedBuildingScanRadius") then { 380 } else { FADE_civParkedBuildingScanRadius }]];
missionNamespace setVariable ["FADE_civParkedRoadFromBuildingRadius", missionNamespace getVariable ["FADE_civParkedRoadFromBuildingRadius", if (isNil "FADE_civParkedRoadFromBuildingRadius") then { 100 } else { FADE_civParkedRoadFromBuildingRadius }]];
missionNamespace setVariable ["FADE_civParkedCenterRoadRadius", missionNamespace getVariable ["FADE_civParkedCenterRoadRadius", if (isNil "FADE_civParkedCenterRoadRadius") then { 260 } else { FADE_civParkedCenterRoadRadius }]];
missionNamespace setVariable ["FADE_civParkedWideRoadRadius", missionNamespace getVariable ["FADE_civParkedWideRoadRadius", if (isNil "FADE_civParkedWideRoadRadius") then { 400 } else { FADE_civParkedWideRoadRadius }]];
missionNamespace setVariable ["FADE_civParkedNearBuildingMax", missionNamespace getVariable ["FADE_civParkedNearBuildingMax", if (isNil "FADE_civParkedNearBuildingMax") then { 125 } else { FADE_civParkedNearBuildingMax }]];
missionNamespace setVariable ["FADE_civParkedMinAlongRoadM", missionNamespace getVariable ["FADE_civParkedMinAlongRoadM", if (isNil "FADE_civParkedMinAlongRoadM") then { 7 } else { FADE_civParkedMinAlongRoadM }]];
missionNamespace setVariable ["FADE_civParkedCrossRoadScan", missionNamespace getVariable ["FADE_civParkedCrossRoadScan", if (isNil "FADE_civParkedCrossRoadScan") then { 24 } else { FADE_civParkedCrossRoadScan }]];
missionNamespace setVariable ["FADE_civParkedCrossRoadClearM", missionNamespace getVariable ["FADE_civParkedCrossRoadClearM", if (isNil "FADE_civParkedCrossRoadClearM") then { 6.8 } else { FADE_civParkedCrossRoadClearM }]];
missionNamespace setVariable ["FADE_civParkedCrossRoadAngleMin", missionNamespace getVariable ["FADE_civParkedCrossRoadAngleMin", if (isNil "FADE_civParkedCrossRoadAngleMin") then { 38 } else { FADE_civParkedCrossRoadAngleMin }]];
missionNamespace setVariable ["FADE_civParkedCrossRoadHalfLen", missionNamespace getVariable ["FADE_civParkedCrossRoadHalfLen", if (isNil "FADE_civParkedCrossRoadHalfLen") then { 4.5 } else { FADE_civParkedCrossRoadHalfLen }]];
missionNamespace setVariable ["FADE_civWanderRadius", missionNamespace getVariable ["FADE_civWanderRadius", 100]];
missionNamespace setVariable ["FADE_civCountMin", missionNamespace getVariable ["FADE_civCountMin", 5]];
missionNamespace setVariable ["FADE_civCountMax", missionNamespace getVariable ["FADE_civCountMax", 15]];
missionNamespace setVariable ["FADE_civSpawnStaggerDelay", missionNamespace getVariable ["FADE_civSpawnStaggerDelay", 1.5]];
missionNamespace setVariable ["FADE_civSpawnBatchSize", missionNamespace getVariable ["FADE_civSpawnBatchSize", 2]];
missionNamespace setVariable ["FADE_roadVehicleMax", missionNamespace getVariable ["FADE_roadVehicleMax", 10]];
missionNamespace setVariable ["FADE_civMaxActiveZones", missionNamespace getVariable ["FADE_civMaxActiveZones", 4]];
missionNamespace setVariable ["FADE_civDebug", missionNamespace getVariable ["FADE_civDebug", false]];
missionNamespace setVariable ["FADE_civVehCleanupDist", missionNamespace getVariable ["FADE_civVehCleanupDist", if (isNil "FADE_civVehCleanupDist") then { 4500 } else { FADE_civVehCleanupDist }]];
missionNamespace setVariable ["FADE_civAirCleanupDist", missionNamespace getVariable ["FADE_civAirCleanupDist", if (isNil "FADE_civAirCleanupDist") then { -1 } else { FADE_civAirCleanupDist }]];
missionNamespace setVariable ["FADE_civGlobalMaxAlive", missionNamespace getVariable ["FADE_civGlobalMaxAlive", if (isNil "FADE_civGlobalMaxAlive") then { 55 } else { FADE_civGlobalMaxAlive }]];
missionNamespace setVariable ["FADE_civDensityScale", missionNamespace getVariable ["FADE_civDensityScale", if (isNil "FADE_civDensityScale") then { 1 } else { FADE_civDensityScale }]];
missionNamespace setVariable ["FADE_civUnitCullDist", missionNamespace getVariable ["FADE_civUnitCullDist", if (isNil "FADE_civUnitCullDist") then { 750 } else { FADE_civUnitCullDist }]];
// Ambient road car radio (Sig list / jukebox vehicle path): chance, proximity trigger, client vol/dist (fallback path; CfgVehicles Sound uses mission FAC_JukeVeh_*)
missionNamespace setVariable ["FADE_civCarRadioChance", missionNamespace getVariable ["FADE_civCarRadioChance", if (isNil "FADE_civCarRadioChance") then { 1 } else { FADE_civCarRadioChance }]];
missionNamespace setVariable ["FADE_civCarRadioTriggerDist", missionNamespace getVariable ["FADE_civCarRadioTriggerDist", if (isNil "FADE_civCarRadioTriggerDist") then { 1000 } else { FADE_civCarRadioTriggerDist }]];
missionNamespace setVariable ["FADE_civCarRadioVolume", missionNamespace getVariable ["FADE_civCarRadioVolume", if (isNil "FADE_civCarRadioVolume") then { 25 } else { FADE_civCarRadioVolume }]];
missionNamespace setVariable ["FADE_civCarRadioAudibleDist", missionNamespace getVariable ["FADE_civCarRadioAudibleDist", if (isNil "FADE_civCarRadioAudibleDist") then { 1000 } else { FADE_civCarRadioAudibleDist }]];
missionNamespace setVariable ["FADE_civCarRadioCheckInterval", missionNamespace getVariable ["FADE_civCarRadioCheckInterval", if (isNil "FADE_civCarRadioCheckInterval") then { 10 } else { FADE_civCarRadioCheckInterval }]];

// Filter to valid CfgVehicles classes: must exist, scope >= 2 (avoids "Cannot create non-ai vehicle" for player-only/private classes).
// When _unitsOnly is true, only classes that inherit from Man are kept (avoids "abstract type Civilian_F" / wrong type).
FADE_civ_filterClasses = {
    params ["_classes", ["_unitsOnly", false]];
    if (isNil "_classes" || {!(_classes isEqualType [])}) exitWith { [] };
    private _out = [];
    {
        private _c = _x;
        if (!(_c isEqualType "") || { _c == "" }) then { continue };
        private _cfg = configFile >> "CfgVehicles" >> _c;
        if (!isClass _cfg) then { continue };
        if (getNumber (_cfg >> "scope") < 2) then { continue };
        if (_unitsOnly && { !(_c isKindOf ["Man", configFile >> "CfgVehicles"]) }) then { continue };
        _out pushBack _c;
    } forEach _classes;
    _out
};

// -----------------------------------------------------------------------------
// Get civ classes ONLY from Scenario GUI faction - no fallbacks
// -----------------------------------------------------------------------------
FADE_civ_getUnitClassesFromGui = {
    private _faction = missionNamespace getVariable ["FADE_scenarioCivFaction", "CIV_F"];
    if (_faction == "") exitWith { [] };
    if (isNil "FADE_getUnitsForFaction") exitWith { [] };
    private _raw = [_faction, 3] call FADE_getUnitsForFaction;
    [_raw, true] call FADE_civ_filterClasses  // true = units only (Man), avoids abstract/faction-named classes
};

FADE_civ_getVehicleClassesFromGui = {
    private _faction = missionNamespace getVariable ["FADE_scenarioCivFaction", "CIV_F"];
    if (_faction == "") exitWith { [] };
    if (isNil "FADE_getCivVehiclesForFaction") exitWith { [] };
    private _raw = [_faction] call FADE_getCivVehiclesForFaction;
    [_raw, false] call FADE_civ_filterClasses  // false = vehicles, not units
};

// Road-parkable cars only (no ships/air)
FADE_civ_getParkedCarClassesFromGui = {
    private _all = call FADE_civ_getVehicleClassesFromGui;
    _all select { _x isKindOf "Car" }
};

// Per-zone metadata from FADE_civZonesFromLocations_build (defaults if missing  -  e.g. legacy Eden zones)
FADE_civ_getZoneMeta = {
    params ["_zoneId"];
    if (!isNil "FADE_civZoneMeta" && { FADE_civZoneMeta isEqualType createHashMap } && { !isNil { FADE_civZoneMeta get _zoneId } }) exitWith {
        FADE_civZoneMeta get _zoneId
    };
    private _d = createHashMap;
    _d set ["locType", "NameVillage"];
    _d set ["hasAmbientPop", true];
    _d set ["parkedVehicles", 3];
    _d set ["footMult", 1];
    _d
};

FADE_civ_countAmbientFootCivs = {
    private _n = 0;
    {
        if (alive _x && { _x getVariable ["FADE_ambientCiv", false] }) then { _n = _n + 1 };
    } forEach allUnits;
    _n
};

// Show hint when no civs available (once per session to avoid spam)
FADE_civ_showNoCivsHint = {
    if (missionNamespace getVariable ["FADE_civNoCivsHintShown", false]) exitWith {};
    missionNamespace setVariable ["FADE_civNoCivsHintShown", true];
    private _faction = missionNamespace getVariable ["FADE_scenarioCivFaction", "CIV_F"];
    private _factionDn = getText (configFile >> "CfgFactionClasses" >> _faction >> "displayName");
    if (_factionDn == "") then { _factionDn = _faction };
    private _msg = format [
        "<t size='1.2' color='#FF6666'>AMBIENT CIVS: NO UNITS</t><br/><br/>" +
        "<t color='#E0E0E0'>Faction '%1' has no civilian units. Check mods are loaded or select a different faction in Scenario GUI.</t>",
        _factionDn
    ];
    [_msg] remoteExec ["FADE_showMissionHint", 0];
    diag_log format ["[AmbientCivilians] No civ units for faction %1 - hint shown", _faction];
};

FADE_civ_showNoCivVehiclesHint = {
    if (missionNamespace getVariable ["FADE_civNoCivVehHintShown", false]) exitWith {};
    missionNamespace setVariable ["FADE_civNoCivVehHintShown", true];
    private _faction = missionNamespace getVariable ["FADE_scenarioCivFaction", "CIV_F"];
    private _factionDn = getText (configFile >> "CfgFactionClasses" >> _faction >> "displayName");
    if (_factionDn == "") then { _factionDn = _faction };
    private _msg = format [
        "<t size='1.2' color='#FF6666'>AMBIENT CIVS: NO VEHICLES</t><br/><br/>" +
        "<t color='#E0E0E0'>Faction '%1' has no civilian vehicles. Road vehicles disabled.</t>",
        _factionDn
    ];
    [_msg] remoteExec ["FADE_showMissionHint", 0];
    diag_log format ["[AmbientCivilians] No civ vehicles for faction %1 - hint shown", _faction];
};

// Collect CIV_T_* zone refs (CIV_T_1 .. CIV_T_N, N = FADE_civTriggerIndexMax after named-location build)
private _civTriggerNames = [];
private _civTMax = missionNamespace getVariable ["FADE_civTriggerIndexMax", 109];
for "_i" from 1 to _civTMax do {
    private _name = format ["CIV_T_%1", _i];
    private _trig = missionNamespace getVariable [_name, objNull];
    if (!isNull _trig) then { _civTriggerNames pushBack _name };
};
missionNamespace setVariable ["FADE_civTriggerNames", _civTriggerNames];

// ROAD_SP_* still used by Intercept Convoy mission; ambient civ road spawns no longer depend on them
private _roadPoints = [];
for "_i" from 1 to 25 do {
    private _obj = missionNamespace getVariable [format ["ROAD_SP_%1", _i], objNull];
    if (!isNull _obj) then { _roadPoints pushBack _obj };
};
missionNamespace setVariable ["FADE_civRoadPoints", _roadPoints];

FADE_civZoneState = createHashMap;
if (isNil "FADE_civZoneMeta" || { !(FADE_civZoneMeta isEqualType createHashMap) }) then { FADE_civZoneMeta = createHashMap };
// Mission-pinned zones (e.g. Invasion sectors): always spawned; exempt from max-active cap and player-distance despawn.
FADE_civPinnedZones = createHashMap;

FADE_civ_isZonePinned = {
    params ["_zoneId"];
    if (isNil "FADE_civPinnedZones") exitWith { false };
    private _n = FADE_civPinnedZones get _zoneId;
    !isNil "_n" && { _n > 0 }
};

FADE_civ_countActiveNonPinnedZones = {
    if (isNil "FADE_civZoneState") exitWith { 0 };
    private _n = 0;
    { if !([_x] call FADE_civ_isZonePinned) then { _n = _n + 1 } } forEach (keys FADE_civZoneState);
    _n
};

FADE_civ_ensurePinnedZonesSpawned = {
    if (isNil "FADE_civPinnedZones") exitWith {};
    {
        private _name = _x;
        if !([_name] call FADE_civ_isZonePinned) then { continue };
        private _trigger = missionNamespace getVariable [_name, objNull];
        if (isNull _trigger) then { continue };
        if (isNil { FADE_civZoneState get _name }) then {
            [_trigger, _name] call FADE_civ_spawnZone;
        };
    } forEach (keys FADE_civPinnedZones);
};

FADE_civ_pinZones = {
    params [["_zoneIds", []]];
    if !(isServer) exitWith {};
    if (isNil "FADE_civPinnedZones") then { FADE_civPinnedZones = createHashMap };
    {
        private _id = _x;
        if (_id isEqualType "" && { _id != "" }) then {
            private _n = FADE_civPinnedZones getOrDefault [_id, 0];
            FADE_civPinnedZones set [_id, _n + 1];
            if (!isNil "FADE_enemyPatrol_despawnForZone") then { [_id] call FADE_enemyPatrol_despawnForZone };
            if (!isNil "FADE_dynamicRoadblocks_despawnForZone") then { [_id] call FADE_dynamicRoadblocks_despawnForZone };
        };
    } forEach _zoneIds;
    [_zoneIds] spawn {
        params [["_zoneIds", []]];
        sleep 0.1;
        call FADE_civ_ensurePinnedZonesSpawned;
    };
};

FADE_civ_unpinZones = {
    params [["_zoneIds", []]];
    if !(isServer) exitWith {};
    if (isNil "FADE_civPinnedZones") exitWith {};
    {
        private _id = _x;
        if (_id isEqualType "" && { _id != "" } && { !isNil { FADE_civPinnedZones get _id } }) then {
            private _n = (FADE_civPinnedZones get _id) - 1;
            if (_n <= 0) then {
                FADE_civPinnedZones deleteAt _id;
            } else {
                FADE_civPinnedZones set [_id, _n];
            };
        };
    } forEach _zoneIds;
};
FADE_roadVehicles = [];
FADE_civAmbientAircraft = [];
FADE_enemyPatrolZoneState = createHashMap;

FADE_unitClassIsOpforSniper = {
    params ["_class"];
    if (!(_class isEqualType "") || { !isClass (configFile >> "CfgVehicles" >> _class) }) exitWith { false };
    private _dn = toLower getText (configFile >> "CfgVehicles" >> _class >> "displayName");
    if ((_dn find "sniper" >= 0) || { _dn find "marksman" >= 0 }) exitWith { true };
    private _hit = false;
    {
        private _w = toLower _x;
        if ((_w find "srifle" >= 0) || { _w find "gm6" >= 0 } || { _w find "cyrus" >= 0 } || { _w find "dmr" >= 0 }) exitWith { _hit = true };
    } forEach (getArray (configFile >> "CfgVehicles" >> _class >> "weapons"));
    _hit
};

FADE_resolveEnemySniperClasses = {
    private _enemyUnits = missionNamespace getVariable ["FADE_enemyUnits", []];
    private _snipers = _enemyUnits select { [_x] call FADE_unitClassIsOpforSniper };
    if (_snipers isEqualTo [] && { !isNil "FADE_getUnitsForFaction" }) then {
        private _fac = missionNamespace getVariable ["FADE_scenarioEnemyFaction", "OPF_F"];
        private _sn = missionNamespace getVariable ["FADE_scenarioEnemySideNum", 0];
        private _all = [_fac, _sn] call FADE_getUnitsForFaction;
        _snipers = _all select { [_x] call FADE_unitClassIsOpforSniper };
    };
    if (_snipers isEqualTo []) then {
        private _fb = ["O_sniper_F", "O_T_Soldier_F"];
        { if (isClass (configFile >> "CfgVehicles" >> _x)) exitWith { _snipers = [_x] } } forEach _fb;
    };
    _snipers
};

FADE_enemyPatrol_pickSniperRoofPos = {
    params ["_buildings", ["_minDistPlayers", 400]];
    if (_buildings isEqualTo [] || { isNil "FADE_buildingRoofPos" }) exitWith { [] };
    private _tries = missionNamespace getVariable ["FADE_enemyPatrolSniperBuildingTries", 8];
    private _pool = +_buildings;
    _pool = _pool call BIS_fnc_arrayShuffle;
    if (count _pool > _tries) then { _pool = _pool select [0, _tries] };
    private _roof = [];
    {
        if (count _roof >= 2) exitWith {};
        private _candidate = [_x] call FADE_buildingRoofPos;
        if (count _candidate < 2) then { continue };
        if (({ alive _x && { isPlayer _x } && { (getPosATL _x) distance2D _candidate < _minDistPlayers } } count allPlayers) > 0) then { continue };
        _roof = _candidate;
    } forEach _pool;
    _roof
};

// Despawn all patrol entities for a zone (groups, vehicle groups, vehicles, garrison groups, sniper groups, barrels)
FADE_enemyPatrol_despawnForZone = {
    params ["_zoneId"];
    private _state = FADE_enemyPatrolZoneState get _zoneId;
    if (isNil "_state") exitWith {};
    private _groups = _state get "groups";
    if (isNil "_groups") then { _groups = [] };
    private _vehicleGroups = _state get "vehicleGroups";
    if (isNil "_vehicleGroups") then { _vehicleGroups = [] };
    private _vehicles = _state get "vehicles";
    if (isNil "_vehicles") then { _vehicles = [] };
    private _garrisonGroups = _state get "garrisonGroups";
    if (isNil "_garrisonGroups") then { _garrisonGroups = [] };
    private _sniperGroups = _state get "sniperGroups";
    if (isNil "_sniperGroups") then { _sniperGroups = [] };
    private _barrels = _state get "barrels";
    if (isNil "_barrels") then { _barrels = [] };
    private _vgX = missionNamespace getVariable ["FADE_vg_cancelPendingByOwner", {}];
    if (!(_vgX isEqualTo {})) then { [format ["patrol:%1", _zoneId]] call _vgX };
    {
        if (!isNull _x) then {
            { if (!isNull _x) then { deleteVehicle _x } } forEach units _x;
            deleteGroup _x;
        };
    } forEach (_groups + _vehicleGroups + _garrisonGroups + _sniperGroups);
    { if (!isNull _x) then { deleteVehicle _x } } forEach _vehicles;
    { if (!isNull _x) then { deleteVehicle _x } } forEach _barrels;
    FADE_enemyPatrolZoneState deleteAt _zoneId;
};

// Spawn enemy patrol: infantry groups, 1-2 road vehicles (car type) with cargo and cycle waypoints, 2-4 garrisoned buildings with burning barrel
FADE_enemyPatrol_spawnForZone = {
    params ["_center", "_zoneId"];
    if (!(missionNamespace getVariable ["FADE_scenarioPatrols", true])) exitWith {};
    if (!isNil "FADE_civ_isZonePinned" && { [_zoneId] call FADE_civ_isZonePinned }) exitWith {};
    if (!(isNil { FADE_enemyPatrolZoneState get _zoneId })) exitWith {};
    // Never spawn ambient patrol within 1 km of player base (BASE_1)
    private _basePos = missionNamespace getVariable ["FADE_basePos", []];
    if (count _basePos >= 2 && { (_center distance _basePos) < 1000 }) exitWith {};
    if (random 1 > 0.25) exitWith {};
    private _enemyUnits = missionNamespace getVariable ["FADE_enemyUnits", []];
    if (_enemyUnits isEqualTo []) exitWith {};
    private _sideEnemy = missionNamespace getVariable ["FADE_sideEnemy", east];
    private _patrolGroups = [];
    private _vehicleGroups = [];
    private _vehicles = [];
    private _garrisonGroups = [];
    private _sniperGroups = [];
    private _barrels = [];
    private _zoneRadius = missionNamespace getVariable ["FADE_civSpawnRadius", 1000];
    if (_zoneRadius > 900) then { _zoneRadius = 800 };
    private _patrolPlClearM = missionNamespace getVariable ["FADE_enemyPatrolMinDistFromPlayersM", 400];
    private _patrolFarFromPlayers = {
        params [["_pos", [0, 0, 0]], ["_minD", 400]];
        if (count _pos < 2) exitWith { false };
        private _ok = true;
        {
            if (alive _x && { isPlayer _x } && { (getPosATL _x) distance2D _pos < _minD }) then { _ok = false };
        } forEach allPlayers;
        _ok
    };

    // Infantry patrol groups (1-2 groups; 3-6 units each)
    private _dryFn = missionNamespace getVariable ["FADE_surfaceIsDry", { params ["_p"]; count _p >= 2 && { !surfaceIsWater [_p select 0, _p select 1] } }];
    private _numGroups = 1 + floor random 2;
    for "_g" from 0 to (_numGroups - 1) do {
        private _sp = [];
        for "_trySp" from 1 to 22 do {
            private _angle = random 360;
            private _dist = 200 + random ((_zoneRadius - 200) max 1);
            private _rough = _center getPos [_dist, _angle];
            _sp = [[_rough, 0, 15, 3, 1, 0.4, 0, [], _rough], _rough] call FADE_findSafePosArray;
            if (!(_sp isEqualType []) || { count _sp < 2 }) then { _sp = +_rough };
            if (count _sp < 3) then { _sp set [2, 0] };
            if ([_sp] call _dryFn && { [_sp, _patrolPlClearM] call _patrolFarFromPlayers }) exitWith {};
            _sp = [];
        };
        if (count _sp < 2) then { continue };
        private _size = 3 + floor random 4;
        private _shuffled = _enemyUnits call BIS_fnc_arrayShuffle;
        private _units = _shuffled select [0, _size min count _shuffled];
        if (_units isEqualTo []) exitWith {};
        private _grp = [_sp, _sideEnemy, _units] call BIS_fnc_spawnGroup;
        if (isNull _grp || { count units _grp == 0 }) then { continue };
        [_grp] call FAC_applyEnemyScenarioToGroup;
        _grp setBehaviour "SAFE";
        _grp setCombatMode "YELLOW";
        for "_w" from 0 to 3 do {
            private _wpPos = [];
            for "_tryWp" from 1 to 14 do {
                private _wpAngle = _w * 90 + (random 45);
                private _wpDist = 150 + random (_zoneRadius min 600);
                private _wRough = [(_center select 0) + _wpDist * (cos _wpAngle), (_center select 1) + _wpDist * (sin _wpAngle), 0];
                _wpPos = [[_wRough, 0, 10, 2, 1, 0.4, 0, [], _wRough], _wRough] call FADE_findSafePosArray;
                if (_wpPos isEqualType [] && { count _wpPos >= 2 }) then {
                    _wpPos = [(_wpPos select 0), (_wpPos select 1), (if (count _wpPos > 2) then { _wpPos select 2 } else { 0 })];
                    if ([_wpPos] call _dryFn) exitWith {};
                };
                _wpPos = [];
            };
            if (count _wpPos >= 2) then {
                private _wp = _grp addWaypoint [_wpPos, 0];
                _wp setWaypointType "MOVE";
                _wp setWaypointSpeed "LIMITED";
                if (_w == 3) then { _wp setWaypointType "CYCLE" };
            };
        };
        _patrolGroups pushBack _grp;
    };

    // 1-2 cars on road: spawn on road in zone, waypoint random in zone then cycle, fill cargo with enemy units
    private _enemyVehList = missionNamespace getVariable ["FADE_enemyVehicles", []];
    private _carClasses = [];
    { if ((_x isEqualType "") && { isClass (configFile >> "CfgVehicles" >> _x) }) then { if (_x isKindOf "Car") then { _carClasses pushBack _x } } } forEach _enemyVehList;
    if (_carClasses isEqualTo [] && { count _enemyVehList > 0 }) then { _carClasses = _enemyVehList };
    if (!(_carClasses isEqualTo []) && { count _enemyUnits > 0 }) then {
        private _numVeh = 1 + floor random 2;
        private _spawnedPatrolVehs = [];
        private _roadHit = [];
        private _roadPos = [0, 0, 0];
        private _roadDir = 0;
        private _carClass = "";
        private _veh = objNull;
        private _vehGrp = grpNull;
        private _driverCls = "";
        private _driver = objNull;
        private _cargoSeats = 0;
        private _cls = "";
        private _u = objNull;
        private _wpPosA = [0, 0, 0];
        for "_v" from 0 to (_numVeh - 1) do {
            _roadHit = [_center, _zoneRadius, _spawnedPatrolVehs, -1, [], _center] call FADE_findOpforGroundVehicleRoadSpawn;
            if (!(_roadHit isEqualType []) || { count _roadHit < 2 }) then { continue };
            _roadPos = +(_roadHit param [0, []]);
            _roadDir = _roadHit param [1, 0];
            if (count _roadPos < 2) then { continue };
            if !([_roadPos, _patrolPlClearM] call _patrolFarFromPlayers) then { continue };
            _carClass = selectRandom _carClasses;
            _veh = createVehicle [_carClass, _roadPos, [], 0, "NONE"];
            if (isNull _veh) then { continue };
            _veh setPosATL _roadPos;
            _veh setDir _roadDir;
            _veh setVectorUp surfaceNormal _roadPos;
            _spawnedPatrolVehs pushBack _veh;
                _vehGrp = createGroup _sideEnemy;
                _driverCls = selectRandom _enemyUnits;
                _driver = _vehGrp createUnit [_driverCls, _roadPos, [], 0, "NONE"];
                if (isNull _driver) then { deleteVehicle _veh; deleteGroup _vehGrp; continue };
                _driver assignAsDriver _veh;
                _driver moveInDriver _veh;
                _cargoSeats = [_veh] call FADE_getCargoSeats;
                if (isNil "_cargoSeats") then { _cargoSeats = 0 };
                _cargoSeats = (_cargoSeats min 6) max 0;
                for "_c" from 0 to (_cargoSeats - 1) do {
                    _cls = selectRandom _enemyUnits;
                    _u = _vehGrp createUnit [_cls, _roadPos, [], 0, "NONE"];
                    if (!isNull _u) then { _u assignAsCargo _veh; _u moveInCargo _veh };
                };
                [_veh, _enemyUnits] call FADE_ensureEnemyVehicleGunner;
                _vehGrp setBehaviour "SAFE";
                _vehGrp setSpeedMode "LIMITED";
                _wpPosA = [_center, _zoneRadius * 0.6] call FADE_civ_findSpawnPos;
                private _wp1 = _vehGrp addWaypoint [_wpPosA, 0];
                _wp1 setWaypointType "MOVE";
                _wp1 setWaypointSpeed "LIMITED";
                private _wp2 = _vehGrp addWaypoint [_roadPos, 0];
                _wp2 setWaypointType "CYCLE";
                _wp2 setWaypointSpeed "LIMITED";
                _vehicleGroups pushBack _vehGrp;
                _vehicles pushBack _veh;
        };
    };

    // 2-4 garrisoned buildings: 2-3 enemy units each, burning barrel outside (wider scan; subset of buildings).
    private _ambGarExtra = missionNamespace getVariable ["FADE_garrisonAmbientRadiusExtraM", 300];
    private _ambBChance = missionNamespace getVariable ["FADE_garrisonMissionNearbyBuildingChance", 0.25];
    private _buildings = nearestObjects [_center, ["House", "Building"], _zoneRadius + _ambGarExtra];
    private _buildingsWithPos = _buildings select {
        count (_x buildingPos -1) >= 2 && { [getPosATL _x] call _dryFn }
    };
    private _thinnedBlds = _buildingsWithPos select { random 1 < _ambBChance };
    if (count _thinnedBlds < ((2 min count _buildingsWithPos) max 1) && { count _buildingsWithPos > 0 }) then { _thinnedBlds = +_buildingsWithPos };
    _thinnedBlds = _thinnedBlds call BIS_fnc_arrayShuffle;
    private _numGarrison = (2 + floor random 3) min count _thinnedBlds;
    private _vgFn = missionNamespace getVariable ["FADE_vg_register", {}];
    for "_b" from 0 to (_numGarrison - 1) do {
        private _bld = _thinnedBlds select _b;
        private _bldPos = _bld buildingPos -1;
        if (_bldPos isEqualTo []) then { continue };
        private _cnt = (2 + floor random 2) min count _bldPos;
        private _indices = [];
        for "_i" from 0 to (count _bldPos - 1) do { _indices pushBack _i };
        _indices = _indices call BIS_fnc_arrayShuffle;
        private _slotATL = [];
        for "_i" from 0 to (_cnt - 1) do {
            private _p = _bldPos select (_indices select _i);
            if (count _p < 3) then { _p = [(_p select 0), (_p select 1), (if (count _p > 2) then { _p select 2 } else { 0 })] };
            if !([_p] call _dryFn) then { continue };
            if !([_p, _patrolPlClearM] call _patrolFarFromPlayers) then { continue };
            _slotATL pushBack _p;
        };
        if (count _slotATL > 0 && { !(_vgFn isEqualTo {}) }) then {
            private _bldCenter = getPosATL _bld;
            if (count _bldCenter < 3) then { _bldCenter = [(_bldCenter select 0), (_bldCenter select 1), 0] };
            private _st = createHashMap;
            _st set ["owner", format ["patrol:%1", _zoneId]];
            _st set ["groupsRef", _garrisonGroups];
            _st set ["barrelsRef", _barrels];
            _st set ["tryBarrel", true];
            _st set ["barrelRoll", missionNamespace getVariable ["FADE_vgLazyOutdoorHintChance", 0.5]];
            _st set ["barrelClasses", missionNamespace getVariable ["FADE_vgLazyOutdoorHintClasses", ["MetalBarrel_burning_F"]]];
            _st set ["barrelCenter", _bldCenter];
            _st set ["barrelMinDistPlayersM", _patrolPlClearM];
            [_bld, _slotATL, [], _st] call _vgFn;
        } else {
            if (count _slotATL == 0) then { } else {
                private _garrisonGrp = createGroup _sideEnemy;
                {
                    private _p = +_x;
                    private _cls = selectRandom _enemyUnits;
                    private _u = _garrisonGrp createUnit [_cls, _p, [], 0, "NONE"];
                    if (!isNull _u) then { _u setUnitPos "MIDDLE"; [_u, "STAND", "FULL", { behaviour _this == "COMBAT" || { !alive _this } }, "COMBAT"] call BIS_fnc_ambientAnimCombat };
                } forEach _slotATL;
                if (count units _garrisonGrp > 0) then {
                    _garrisonGroups pushBack _garrisonGrp;
                    private _bldCenter = getPosATL _bld;
                    if (count _bldCenter < 3) then { _bldCenter = [(_bldCenter select 0), (_bldCenter select 1), 0] };
                    private _barrelPos = [_bldCenter] call FADE_findOutdoorHintPos;
                    if (_barrelPos isEqualType [] && { count _barrelPos >= 2 }) then {
                        _barrelPos = [(_barrelPos select 0), (_barrelPos select 1), (if (count _barrelPos > 2) then { _barrelPos select 2 } else { 0 })];
                        if ([_barrelPos, _patrolPlClearM] call _patrolFarFromPlayers) then {
                            private _barrel = createVehicle ["MetalBarrel_burning_F", _barrelPos, [], 0, "NONE"];
                            _barrel setPosATL _barrelPos;
                            _barrels pushBack _barrel;
                        };
                    };
                } else {
                    deleteGroup _garrisonGrp;
                };
            };
        };
    };

    // Rooftop snipers in garrisoned towns (elevated positions; requires enterable buildings in zone).
    if (count _buildingsWithPos > 0) then {
        private _snZoneChance = missionNamespace getVariable ["FADE_enemyPatrolSniperZoneChance", 0.45];
        if (random 1 <= _snZoneChance) then {
            private _sniperClasses = call FADE_resolveEnemySniperClasses;
            if !(_sniperClasses isEqualTo []) then {
                private _maxSn = (missionNamespace getVariable ["FADE_enemyPatrolSniperMaxPerZone", 2]) max 1;
                private _numSn = 1 + floor random _maxSn;
                private _usedRoofs = [];
                for "_sn" from 1 to _numSn do {
                    private _roof = [_buildingsWithPos, _patrolPlClearM] call FADE_enemyPatrol_pickSniperRoofPos;
                    if (count _roof < 2) then { continue };
                    private _tooClose = false;
                    { if ((_roof distance2D _x) < 25) exitWith { _tooClose = true } } forEach _usedRoofs;
                    if (_tooClose) then { continue };
                    _usedRoofs pushBack _roof;
                    private _snGrp = createGroup _sideEnemy;
                    private _cls = selectRandom _sniperClasses;
                    private _u = _snGrp createUnit [_cls, _roof, [], 0, "NONE"];
                    if (isNull _u) then {
                        deleteGroup _snGrp;
                        continue;
                    };
                    _u setPosATL _roof;
                    _u setUnitPos "MIDDLE";
                    _u disableAI "PATH";
                    _u enableAI "TARGET";
                    _u enableAI "AUTOTARGET";
                    _u doWatch (_center getPos [250 + random 200, random 360]);
                    [_snGrp] call FAC_applyEnemyScenarioToGroup;
                    _snGrp setBehaviour "AWARE";
                    _snGrp setCombatMode "RED";
                    _sniperGroups pushBack _snGrp;
                };
            };
        };
    };

    if (count _patrolGroups > 0 || { count _vehicles > 0 } || { count _garrisonGroups > 0 } || { count _sniperGroups > 0 }) then {
        private _state = createHashMap;
        _state set ["groups", _patrolGroups];
        _state set ["vehicleGroups", _vehicleGroups];
        _state set ["vehicles", _vehicles];
        _state set ["garrisonGroups", _garrisonGroups];
        _state set ["sniperGroups", _sniperGroups];
        _state set ["barrels", _barrels];
        FADE_enemyPatrolZoneState set [_zoneId, _state];
        [format ["PATROL ZONE %1: %2 group(s), %3 vehicle(s), %4 garrison(s), %5 sniper(s)", _zoneId, count _patrolGroups, count _vehicles, count _garrisonGroups, count _sniperGroups]] call FADE_civ_debugChat;
    };
};

FADE_civ_debugChat = {
    params ["_msg"];
    if (missionNamespace getVariable ["FADE_civDebug", false]) then {
        [format ["CIV: %1", _msg]] remoteExec ["systemChat", 0];
    };
};

// -----------------------------------------------------------------------------
// Helpers
// -----------------------------------------------------------------------------
FADE_civ_getBuildingPositions = {
    params ["_center", "_radius", ["_maxPos", 50], ["_maxPerBuilding", 2]];
    private _buildings = nearestObjects [_center, ["House", "Building"], _radius];
    private _positions = [];
    for "_i" from 0 to (count _buildings - 1) do {
        private _bps = (_buildings select _i) buildingPos -1;
        private _taken = 0;
        for "_j" from 0 to (count _bps - 1) do {
            if (_taken >= _maxPerBuilding) exitWith {};
            private _p = _bps select _j;
            if ((_p distance [0,0,0]) > 1) then {
                _positions pushBack _p;
                _taken = _taken + 1;
            };
            if (count _positions >= _maxPos) exitWith {};
        };
        if (count _positions >= _maxPos) exitWith {};
    };
    _positions
};

FADE_civ_getRoadPositions = {
    params ["_center", "_radius", ["_maxPos", 25]];
    private _dryFn = missionNamespace getVariable ["FADE_surfaceIsDry", { params ["_p"]; count _p >= 2 && { !surfaceIsWater [_p select 0, _p select 1] } }];
    private _roads = _center nearRoads _radius;
    private _positions = [];
    for "_i" from 0 to (count _roads - 1) do {
        private _pos = getPos (_roads select _i);
        if (count _pos >= 2) then {
            _pos set [2, 0];
            if ([_pos] call _dryFn) then { _positions pushBack _pos };
        };
        if (count _positions >= _maxPos) exitWith {};
    };
    _positions
};

// Uniform disk (sqrt) avoids clustering at the centre; optional min 2D separation from _otherPos (relaxed after ~24 tries)
FADE_civ_findSpawnPos = {
    params ["_center", "_radius", ["_minSep", 0], ["_otherPos", []]];
    private _dryFn = missionNamespace getVariable ["FADE_surfaceIsDry", { params ["_p"]; count _p >= 2 && { !surfaceIsWater [_p select 0, _p select 1] } }];
    private _found = [];
    private _n = 0;
    while { _n < 40 && { count _found < 2 } } do {
        _n = _n + 1;
        private _sepTry = if (_n > 24) then { 0 } else { _minSep };
        private _angle = random 360;
        private _dist = _radius * sqrt random 1;
        private _pos = _center getPos [_dist, _angle];
        _pos set [2, 0];
        private _safe = [[_pos, 0, 5, 2, 1, 0.3, 0, [], _pos], _pos] call FADE_findSafePosArray;
        if (_safe isEqualType [] && { count _safe >= 2 } && { [_safe] call _dryFn } && { (_safe distance2D _center) <= _radius }) then {
            private _sepOk = true;
            if (_sepTry > 0 && {!(_otherPos isEqualTo [])}) then {
                {
                    if (_sepOk && { (_safe distance2D _x) < _sepTry }) then { _sepOk = false };
                } forEach _otherPos;
            };
            if (_sepOk) then {
                _found = _safe;
            };
        };
    };
    if (count _found >= 2) then { _found } else { _center }
};

// On terrain (ASL)  -  belts-and-suspenders after createUnit/createVehicle / bad Z from mixed coord spaces
FADE_civ_snapToTerrain = {
    params ["_obj", ["_aboveTerrain", 0.15]];
    if (isNull _obj) exitWith {};
    private _p = getPosASL _obj;
    private _gx = _p select 0;
    private _gy = _p select 1;
    private _gz = getTerrainHeightASL [_gx, _gy];
    _obj setPosASL [_gx, _gy, _gz + _aboveTerrain];
};

// Road spawn for ambient civ vehicles: ring around a random active zone centre, on a road, clear of players
FADE_civ_getAlivePlayers = {
    private _out = [];
    { if (alive _x && { isPlayer _x }) then { _out pushBack _x } } forEach allPlayers;
    _out
};

FADE_civ_findAmbientRoadSpawnPos = {
    private _activeIds = keys FADE_civZoneState;
    if (_activeIds isEqualTo []) exitWith { [] };
    private _ringMin = missionNamespace getVariable ["FADE_roadSpawnRingMin", 1000];
    private _ringMax = missionNamespace getVariable ["FADE_roadSpawnRingMax", 2500];
    private _clear = missionNamespace getVariable ["FADE_roadSpawnPlayerClear", 500];
    private _players = call FADE_civ_getAlivePlayers;

    private _anchorId = selectRandom _activeIds;
    private _trig = missionNamespace getVariable [_anchorId, objNull];
    if (isNull _trig) exitWith { [] };
    private _zoneCenter = getPosATL _trig;
    if (count _zoneCenter < 3) then { _zoneCenter = [(_zoneCenter select 0), (_zoneCenter select 1), 0] };

    private _dryFn = missionNamespace getVariable ["FADE_surfaceIsDry", { params ["_p"]; count _p >= 2 && { !surfaceIsWater [_p select 0, _p select 1] } }];
    private _found = [];
    for "_attempt" from 1 to 55 do {
        private _angle = random 360;
        private _dist = _ringMin + random ((_ringMax - _ringMin) max 1);
        private _rough = _zoneCenter getPos [_dist, _angle];
        _rough set [2, 0];
        private _roads = _rough nearRoads 280;
        if (_roads isEqualTo []) then { continue };
        private _roadsDry = _roads select { [getPosATL _x] call _dryFn };
        if (_roadsDry isEqualTo []) then { continue };
        private _road = selectRandom _roadsDry;
        private _pos = getPosATL _road;
        if (count _pos < 3) then { _pos = [(_pos select 0), (_pos select 1), 0] };
        private _dZ = _pos distance _zoneCenter;
        if (_dZ < _ringMin || { _dZ > _ringMax }) then { continue };
        if !(_players isEqualTo []) then {
            private _okPl = true;
            {
                if ((_pos distance _x) < _clear) exitWith { _okPl = false };
            } forEach _players;
            if (!_okPl) then { continue };
        };
        _found = _pos;
    };
    _found
};

// Nearest / furthest active civilian zone centres to a position (for road vehicle waypoints)
FADE_civ_zoneCentersNearestFurthest = {
    params ["_fromPos"];
    private _ids = keys FADE_civZoneState;
    private _nearest = [];
    private _furthest = [];
    private _minD = 1e12;
    private _maxD = -1;
    {
        private _t = missionNamespace getVariable [_x, objNull];
        if (!isNull _t) then {
            private _c = getPosATL _t;
            if (count _c < 3) then { _c = [(_c select 0), (_c select 1), 0] };
            private _d = _c distance _fromPos;
            if (_d < _minD) then { _minD = _d; _nearest = _c };
            if (_d > _maxD) then { _maxD = _d; _furthest = _c };
        };
    } forEach _ids;
    if (count _nearest < 2) exitWith { [[], []] };
    [_nearest, _furthest]
};

FADE_civ_randomPosMinDistFrom = {
    params ["_center", "_minDist"];
    private _pos = [];
    for "_a" from 1 to 35 do {
        private _ang = random 360;
        private _d = _minDist + random 3500;
        private _p = _center getPos [_d, _ang];
        _p set [2, 0];
        private _safe = [[_p, 0, 12, 8, 1, 0.35, 0, [], _p], _p] call FADE_findSafePosArray;
        if (_safe isEqualType [] && { count _safe >= 2 } && { (_safe distance _center) >= (_minDist * 0.92) }) exitWith {
            _pos = [(_safe select 0), (_safe select 1), if (count _safe > 2) then { _safe select 2 } else { 0 }];
        };
    };
    if (_pos isEqualTo []) then {
        _pos = _center getPos [_minDist + 400 + random 800, random 360];
        _pos set [2, 0];
    };
    _pos
};

// Acute angle (0 = parallel, 90 = perpendicular) between two compass headings
FADE_civ_acuteRoadAngleDeg = {
    params ["_d1", "_d2"];
    private _d = abs (_d1 - _d2);
    if (_d > 180) then { _d = 360 - _d };
    if (_d > 90) then { _d = 180 - _d };
    _d
};

// 2D distance from _pxy to segment _a-_b (clamp to segment)
FADE_civ_distPointToSeg2D = {
    params ["_pxy", "_a", "_b"];
    private _ax = _a select 0;
    private _ay = _a select 1;
    private _bx = _b select 0;
    private _by = _b select 1;
    private _px = _pxy select 0;
    private _py = _pxy select 1;
    private _abx = _bx - _ax;
    private _aby = _by - _ay;
    private _len2 = _abx * _abx + _aby * _aby;
    if (_len2 < 0.01) exitWith { _pxy distance2D [_ax, _ay] };
    private _t = (((_px - _ax) * _abx + (_py - _ay) * _aby) / _len2) max 0 min 1;
    private _qx = _ax + _t * _abx;
    private _qy = _ay + _t * _aby;
    _pxy distance2D [_qx, _qy]
};

// Reject if parked car (center + fore/aft samples) lies too close to another road segment that crosses ours
FADE_civ_parkClearOfCrossRoads = {
    params ["_xy", "_vehDir", "_rOwn", "_r2Own"];
    private _scan = missionNamespace getVariable ["FADE_civParkedCrossRoadScan", 24];
    private _minClear = missionNamespace getVariable ["FADE_civParkedCrossRoadClearM", 6.8];
    private _angMin = missionNamespace getVariable ["FADE_civParkedCrossRoadAngleMin", 38];
    _scan = (_scan max 12) min 40;
    _minClear = (_minClear max 4.5) min 12;
    private _nearL = [_xy select 0, _xy select 1];
    private _near = _nearL nearRoads _scan;
    private _px = _nearL select 0;
    private _py = _nearL select 1;
    private _halfLen = missionNamespace getVariable ["FADE_civParkedCrossRoadHalfLen", 4.5];
    _halfLen = (_halfLen max 3) min 7;
    private _checkPts = [
        _nearL,
        [_px, _py] getPos [_halfLen, _vehDir],
        [_px, _py] getPos [_halfLen, _vehDir + 180]
    ];
    private _ok = true;
    {
        if (_ok) then {
            private _rd = _x;
            {
                if (_ok) then {
                    private _rc = _x;
                    if (!(_rd isEqualTo _rc)) then {
                        if (!((_rd isEqualTo _rOwn && _rc isEqualTo _r2Own) || {_rd isEqualTo _r2Own && _rc isEqualTo _rOwn})) then {
                            private _da = getPosATL _rd;
                            private _db = getPosATL _rc;
                            if ((_da distance2D _db) >= 2.8) then {
                                private _sd = _da getDir _db;
                                private _acute = [_vehDir, _sd] call FADE_civ_acuteRoadAngleDeg;
                                if (_acute >= _angMin) then {
                                    {
                                        if (_ok) then {
                                            private _dist = [_x, _da, _db] call FADE_civ_distPointToSeg2D;
                                            if (_dist < _minClear) then { _ok = false };
                                        };
                                    } forEach _checkPts;
                                };
                            };
                        };
                    };
                };
            } forEach (roadsConnectedTo _rd);
        };
    } forEach _near;
    _ok
};

// Try shuffled road segments; optional require House/Building within _nearBldM of park ASL
FADE_civ_pickParkSlotFromRoadList = {
    params ["_roads", "_requireNearBuilding", ["_nearBldM", 125]];
    if (_roads isEqualTo []) exitWith { [] };
    _roads = _roads call BIS_fnc_arrayShuffle;
    private _lim = (count _roads) min 60;
    private _res = [];
    private _k = 0;
    private _minAlong = missionNamespace getVariable ["FADE_civParkedMinAlongRoadM", 7];
    _minAlong = (_minAlong max 4) min 18;
    while { _k < _lim && { _res isEqualTo [] } } do {
        private _r = _roads select _k;
        _k = _k + 1;
        private _conn = roadsConnectedTo _r;
        if (!(_conn isEqualTo [])) then {
            private _r2 = selectRandom _conn;
            private _p1 = getPosASL _r;
            private _p2 = getPosASL _r2;
            private _segLen = _p1 distance2D _p2;
            if (_segLen >= (_minAlong * 2 + 2)) then {
                private _dir = _p1 getDir _p2;
                private _alongMin = _minAlong min (_segLen * 0.45);
                private _alongMax = (_segLen - _minAlong) max (_segLen * 0.55);
                if (_alongMax > _alongMin + 0.5) then {
                    private _along = _alongMin + random (_alongMax - _alongMin);
                    private _anchor = [_p1 select 0, _p1 select 1] getPos [_along, _dir];
                    private _lat = if (random 1 > 0.5) then { 90 } else { -90 };
                    private _off = 3.2 + random 1.6;
                    private _xy = _anchor getPos [_off, _dir + _lat];
                    if (!surfaceIsWater _xy) then {
                        private _z = getTerrainHeightASL _xy;
                        private _asl = [_xy select 0, _xy select 1, _z + 0.25];
                        if (count (nearestObjects [_asl, ["AllVehicles", "Wreck_Base"], 5.5] select { alive _x }) == 0) then {
                            private _bldOk = true;
                            if (_requireNearBuilding && { _nearBldM > 0 }) then {
                                _bldOk = count (nearestObjects [_asl, ["House", "Building"], _nearBldM]) > 0;
                            };
                            if (_bldOk && { [_xy, _dir, _r, _r2] call FADE_civ_parkClearOfCrossRoads }) then {
                                _res = [_asl, _dir];
                            };
                        };
                    };
                };
            };
        };
    };
    _res
};

// Roads near buildings first (urban), then tight ring from zone centre, then wider ring; building proximity required until last merge pass
FADE_civ_tryRoadParkPosition = {
    params ["_center", "_searchRadius"];
    private _bScan = missionNamespace getVariable ["FADE_civParkedBuildingScanRadius", 380];
    private _roadAtB = missionNamespace getVariable ["FADE_civParkedRoadFromBuildingRadius", 100];
    private _cenNarrow = missionNamespace getVariable ["FADE_civParkedCenterRoadRadius", 260];
    private _cenWide = missionNamespace getVariable ["FADE_civParkedWideRoadRadius", 400];
    private _nearBld = missionNamespace getVariable ["FADE_civParkedNearBuildingMax", 125];
    _bScan = (_bScan max 120) min 650;
    _roadAtB = (_roadAtB max 40) min 180;
    _cenNarrow = (_cenNarrow max 80) min 450;
    _cenWide = (_cenWide max _cenNarrow) min (_searchRadius max _cenNarrow);

    private _urban = [];
    private _blds = nearestObjects [_center, ["House", "Building"], _bScan];
    _blds = _blds call BIS_fnc_arrayShuffle;
    private _nb = (count _blds) min 48;
    private _bi = 0;
    while { _bi < _nb } do {
        private _bp = getPosATL (_blds select _bi);
        _bi = _bi + 1;
        { if (!(_x in _urban)) then { _urban pushBack _x } } forEach (_bp nearRoads _roadAtB);
    };

    private _res = [_urban, true, _nearBld] call FADE_civ_pickParkSlotFromRoadList;
    if (_res isEqualTo []) then {
        private _ring = _center nearRoads ((_cenNarrow min _searchRadius) max 90);
        _res = [_ring, true, _nearBld] call FADE_civ_pickParkSlotFromRoadList;
    };
    if (_res isEqualTo []) then {
        private _ring2 = _center nearRoads ((_cenWide min _searchRadius) max 120);
        _res = [_ring2, true, _nearBld] call FADE_civ_pickParkSlotFromRoadList;
    };
    if (_res isEqualTo []) then {
        private _merged = +_urban;
        { if (!(_x in _merged)) then { _merged pushBack _x } } forEach (_center nearRoads ((_cenWide min _searchRadius) max 90));
        _res = [_merged, false, _nearBld] call FADE_civ_pickParkSlotFromRoadList;
    };
    _res
};

// Empty parked civ cars on roads (side of road, aligned to segment)
FADE_civ_spawnZoneParkedVehicles = {
    params ["_zoneId", "_center", "_want"];
    if (_want <= 0) exitWith {};
    if (!(missionNamespace getVariable ["FADE_civiliansEnabled", true])) exitWith {};
    private _classes = call FADE_civ_getParkedCarClassesFromGui;
    if (_classes isEqualTo []) exitWith {
        call FADE_civ_showNoCivVehiclesHint;
    };
    private _state = FADE_civZoneState get _zoneId;
    if (isNil "_state") exitWith {};
    private _existing = _state get "parkedVehs";
    if (isNil "_existing") then { _existing = [] };
    private _rad = missionNamespace getVariable ["FADE_civParkedWideRoadRadius", if (isNil "FADE_civParkedWideRoadRadius") then { 400 } else { FADE_civParkedWideRoadRadius }];
    _rad = (_rad max 200) min ((missionNamespace getVariable ["FADE_civSpawnRadius", 1000]) min 700);
    private _used = +_existing;
    for "_i" from 1 to _want do {
        private _slot = [];
        private _tryN = 0;
        while { _tryN < 28 && { _slot isEqualTo [] } } do {
            _tryN = _tryN + 1;
            private _cand = [_center, _rad] call FADE_civ_tryRoadParkPosition;
            if (!(_cand isEqualTo [])) then {
                private _p = _cand select 0;
                private _ok = true;
                { if (!isNull _x && { alive _x } && { (_p distance getPosASL _x) < 7 }) then { _ok = false } } forEach _used;
                if (_ok) then { _slot = _cand };
            };
        };
        if (!(_slot isEqualTo [])) then {
            private _asl = _slot select 0;
            private _dir = _slot select 1;
            private _cls = selectRandom _classes;
            private _veh = createVehicle [_cls, _asl, [], 0, "NONE"];
            if (!isNull _veh) then {
                _veh setPosASL _asl;
                _veh setDir _dir;
                _veh setVariable ["FADE_ambientParkedVeh", true];
                _veh enableSimulationGlobal true;
                _used pushBack _veh;
                [format ["PARKED %1 | zone %2", _cls, _zoneId]] call FADE_civ_debugChat;
            };
        };
    };
    _state set ["parkedVehs", _used];
};

// -----------------------------------------------------------------------------
// Spawn one civilian (used by lazy-load)
// -----------------------------------------------------------------------------
FADE_civ_spawnOne = {
    params ["_civClasses", "_center", "_spawnRadius", "_wanderRadius", "_firedNearHandler", ["_otherFootPos", []], ["_minSep", 0]];
    private _cls = _civClasses select (floor random (count _civClasses max 1));
    private _spawnPos = [_center, _spawnRadius, _minSep, _otherFootPos] call FADE_civ_findSpawnPos;
    if (count _spawnPos < 2) then { _spawnPos = _center };

    private _grp = createGroup civilian;
    private _unit = _grp createUnit [_cls, _spawnPos, [], 0, "NONE"];
    if (isNull _unit) then {
        deleteGroup _grp;
        objNull
    } else {
        [_unit] call FADE_civ_snapToTerrain;
        _unit setVariable ["BIS_cp_excluded", true];
        _grp setVariable ["BIS_cp_excluded", true];
        _unit setVariable ["FADE_ambientCiv", true];
        [_unit] call (missionNamespace getVariable ["FADE_entityRegistry_register", {}]);
        _unit setVariable ["FADE_civPatrolCenter", +_center, false];
        _unit setVariable ["FADE_civPatrolWanderR", _wanderRadius, false];
        [_unit] remoteExec ["FADE_civTalk_addLocalAction", 0, true];
        removeHeadgear _unit;
        removeGoggles _unit;
        _unit setBehaviour "SAFE";
        _unit setSpeedMode "LIMITED";
        _unit setUnitPos "UP";
        _unit addEventHandler ["FiredNear", _firedNearHandler];

        private _wpRadius = ((_wanderRadius * 1.5) min 200) max 80;
        private _localBuildings = [_spawnPos, _wpRadius, 25, 2] call FADE_civ_getBuildingPositions;
        private _localRoads = [_spawnPos, _wpRadius, 12] call FADE_civ_getRoadPositions;
        private _localWaypoints = _localBuildings + _localRoads;
        if (_localWaypoints isEqualTo []) then {
            for "_k" from 0 to 5 do {
                _localWaypoints pushBack (_spawnPos getPos [20 + random (_wanderRadius - 20), random 360]);
            };
        };
        _localWaypoints pushBack _spawnPos;
        _localWaypoints = _localWaypoints call BIS_fnc_arrayShuffle;

        private _pathCount = (4 + floor random 3) min (count _localWaypoints);
        for "_j" from 0 to (_pathCount - 1) do {
            private _dest = _localWaypoints select _j;
            private _wp = _grp addWaypoint [_dest, 2 + random 4];
            _wp setWaypointType "MOVE";
            _wp setWaypointSpeed "LIMITED";
            _wp setWaypointBehaviour "SAFE";
            if (_j == _pathCount - 1) then { _wp setWaypointType "CYCLE" };
        };
        _grp
    }
};

// Rebuild ambient foot patrol waypoints (after CivTalk cleared them, etc.). Server only.
FADE_civ_restoreAmbientFootPatrol = {
    params [["_unit", objNull]];
    if (!isServer) exitWith {};
    if (isNull _unit || {!alive _unit}) exitWith {};
    if !(_unit getVariable ["FADE_ambientCiv", false]) exitWith {};
    private _grp = group _unit;
    if (isNull _grp) exitWith {};
    while { count waypoints _grp > 0 } do { deleteWaypoint [_grp, 0] };
    private _center = _unit getVariable ["FADE_civPatrolCenter", []];
    if (count _center < 2) then { _center = +getPosATL _unit };
    private _wanderRadius = _unit getVariable ["FADE_civPatrolWanderR", missionNamespace getVariable ["FADE_civWanderRadius", 100]];
    private _spawnPos = +_center;
    private _wpRadius = ((_wanderRadius * 1.5) min 200) max 80;
    private _localBuildings = [_spawnPos, _wpRadius, 25, 2] call FADE_civ_getBuildingPositions;
    private _localRoads = [_spawnPos, _wpRadius, 12] call FADE_civ_getRoadPositions;
    private _localWaypoints = _localBuildings + _localRoads;
    if (_localWaypoints isEqualTo []) then {
        for "_k" from 0 to 5 do {
            _localWaypoints pushBack (_spawnPos getPos [20 + random (_wanderRadius - 20), random 360]);
        };
    };
    _localWaypoints pushBack _spawnPos;
    _localWaypoints = _localWaypoints call BIS_fnc_arrayShuffle;
    private _pathCount = (4 + floor random 3) min (count _localWaypoints);
    for "_j" from 0 to (_pathCount - 1) do {
        private _dest = _localWaypoints select _j;
        private _wp = _grp addWaypoint [_dest, 2 + random 4];
        _wp setWaypointType "MOVE";
        _wp setWaypointSpeed "LIMITED";
        _wp setWaypointBehaviour "SAFE";
        if (_j == _pathCount - 1) then { _wp setWaypointType "CYCLE" };
    };
};

// -----------------------------------------------------------------------------
// Spawn zone - lazy-load civs in batches to reduce performance hit
// -----------------------------------------------------------------------------
FADE_civ_spawnZone = {
    params ["_trigger", "_zoneId"];
    if (!(missionNamespace getVariable ["FADE_civiliansEnabled", true])) exitWith {};
    if (!(isNil { FADE_civZoneState get _zoneId })) exitWith {};

    private _meta = [_zoneId] call FADE_civ_getZoneMeta;
    private _hasPop = _meta get "hasAmbientPop";
    private _footMult = _meta get "footMult";
    private _parkedWant = _meta get "parkedVehicles";
    if (isNil "_hasPop") then { _hasPop = true };
    if (isNil "_footMult") then { _footMult = 1 };
    if (isNil "_parkedWant") then { _parkedWant = 0 };

    private _civClasses = call FADE_civ_getUnitClassesFromGui;
    private _faction = missionNamespace getVariable ["FADE_scenarioCivFaction", "CIV_F"];

    private _center = getPosATL _trigger;
    private _footSpawnRadius = missionNamespace getVariable ["FADE_civFootSpawnRadius", if (isNil "FADE_civFootSpawnRadius") then { 200 } else { FADE_civFootSpawnRadius }];
    private _footMinSep = missionNamespace getVariable ["FADE_civFootSpawnMinSep", if (isNil "FADE_civFootSpawnMinSep") then { 28 } else { FADE_civFootSpawnMinSep }];
    _footSpawnRadius = (_footSpawnRadius max 30) min 800;
    _footMinSep = (_footMinSep max 0) min 120;
    private _baseMin = missionNamespace getVariable ["FADE_civCountMin", 5];
    private _baseMax = missionNamespace getVariable ["FADE_civCountMax", 15];
    private _dens = missionNamespace getVariable ["FADE_civDensityScale", 1];
    private _wanderRadius = missionNamespace getVariable ["FADE_civWanderRadius", 100];
    private _staggerDelay = missionNamespace getVariable ["FADE_civSpawnStaggerDelay", 1.5];
    private _batchSize = missionNamespace getVariable ["FADE_civSpawnBatchSize", 2];

    private _civMin = 0;
    private _civMax = 0;
    private _targetCount = 0;
    if (_hasPop && { _footMult > 0 }) then {
        _civMin = round (_baseMin * _footMult * _dens) max 1;
        _civMax = round (_baseMax * _footMult * _dens) max _civMin;
        _targetCount = _civMin + floor random ((_civMax - _civMin + 1) max 1);
    };

    if (_targetCount > 0 && { _civClasses isEqualTo [] }) then {
        call FADE_civ_showNoCivsHint;
        [format ["FOOT CIVS SKIPPED: No civ units for faction %1 (parked/road may still run)", _faction]] call FADE_civ_debugChat;
        _targetCount = 0;
    };

    private _firedNearHandler = {
        params ["_unit", "_firer", "_distance"];
        if (!alive _unit) exitWith {};
        _unit setBehaviour "CARELESS";
        _unit setSpeedMode "FULL";
        _unit doMove (_unit getPos [150 + random 100, random 360]);
    };

    private _state = createHashMap;
    _state set ["groups", []];
    _state set ["parkedVehs", []];
    _state set ["despawning", false];
    FADE_civZoneState set [_zoneId, _state];

    if (missionNamespace getVariable ["FADE_civDebugMarkers", false]) then {
        private _mrkId = "FADE_civActive_" + _zoneId;
        createMarker [_mrkId, _center];
        _mrkId setMarkerType "hd_flag";
        _mrkId setMarkerColor "ColorCivilian";
        _mrkId setMarkerText ("Civ: " + _zoneId);
        _mrkId setMarkerSize [0.5, 0.5];
    };

    [format ["ZONE %1 ACTIVE | foot %2 parked %3 | faction %4 | pop %5", _zoneId, _targetCount, _parkedWant, _faction, _hasPop]] call FADE_civ_debugChat;

    if (_hasPop && { _parkedWant > 0 }) then {
        [_zoneId, _center, _parkedWant] call FADE_civ_spawnZoneParkedVehicles;
    };

    // Spawn ambient enemy patrol if enabled (25% chance per zone; skip mission-pinned zones e.g. Invasion sectors)
    if (!([_zoneId] call FADE_civ_isZonePinned)) then {
        [_center, _zoneId] call FADE_enemyPatrol_spawnForZone;
    };
    if (!([_zoneId] call FADE_civ_isZonePinned) && { !isNil "FADE_aaa_maybeSpawnManpadsInZone" }) then {
        [_zoneId, _center] call FADE_aaa_maybeSpawnManpadsInZone;
    };

    if (_targetCount > 0 && { count _civClasses > 0 }) then {
        [ _zoneId, _targetCount, _civClasses, _center, _footSpawnRadius, _footMinSep, _wanderRadius, _firedNearHandler, _staggerDelay, _batchSize ] spawn {
            params ["_zoneId", "_targetCount", "_civClasses", "_center", "_footSpawnRadius", "_footMinSep", "_wanderRadius", "_firedNearHandler", "_staggerDelay", "_batchSize"];
            private _spawned = 0;
            private _footPosSoFar = [];
            while { _spawned < _targetCount } do {
                private _state = FADE_civZoneState get _zoneId;
                if (isNil "_state" || { _state get "despawning" }) exitWith {};

                private _cap = missionNamespace getVariable ["FADE_civGlobalMaxAlive", 0];
                if (_cap > 0 && { ([] call FADE_civ_countAmbientFootCivs) >= _cap }) exitWith {};

                private _batch = (_targetCount - _spawned) min _batchSize;
                private _left = _batch;
                while { _left > 0 } do {
                    _cap = missionNamespace getVariable ["FADE_civGlobalMaxAlive", 0];
                    if (_cap > 0 && { ([] call FADE_civ_countAmbientFootCivs) >= _cap }) then {
                        _left = 0;
                    } else {
                        private _grp = [_civClasses, _center, _footSpawnRadius, _wanderRadius, _firedNearHandler, _footPosSoFar, _footMinSep] call FADE_civ_spawnOne;
                        if (!isNull _grp) then {
                            (_state get "groups") pushBack _grp;
                            private _ldr = leader _grp;
                            if (!isNull _ldr) then { _footPosSoFar pushBack (getPosATL _ldr) };
                        };
                        _spawned = _spawned + 1;
                        _left = _left - 1;
                    };
                };
                if (_spawned >= _targetCount) exitWith {};
                sleep _staggerDelay;
            };
        };
    };
};

// -----------------------------------------------------------------------------
// Despawn zone
// -----------------------------------------------------------------------------
FADE_civ_despawnZone = {
    params ["_zoneId"];
    private _state = FADE_civZoneState get _zoneId;
    if (isNil "_state") exitWith {};
    _state set ["despawning", true];
    private _groups = _state get "groups";
    {
        if (!isNull _x) then {
            { deleteVehicle _x } forEach units _x;
            deleteGroup _x;
        };
    } forEach _groups;
    private _parked = _state get "parkedVehs";
    if (isNil "_parked") then { _parked = [] };
    { if (!isNull _x) then { deleteVehicle _x } } forEach _parked;
    FADE_civZoneState deleteAt _zoneId;
    [_zoneId] call FADE_enemyPatrol_despawnForZone;
    if (!isNil "FADE_aaa_despawnManpadsInZone") then { [_zoneId] call FADE_aaa_despawnManpadsInZone };
    if (missionNamespace getVariable ["FADE_civDebugMarkers", false]) then {
        deleteMarker ("FADE_civActive_" + _zoneId);
    };
    [format ["ZONE %1 DESPAWNED", _zoneId]] call FADE_civ_debugChat;
};

// -----------------------------------------------------------------------------
// Ambient road car: one random Sig track, starts once when any player is within trigger distance; same 3D path as jukebox vehicle
// -----------------------------------------------------------------------------
FADE_civ_setupRoadCarRadio = {
    params ["_veh"];
    if (isNull _veh) exitWith {};
    private _ch = missionNamespace getVariable ["FADE_civCarRadioChance", 1];
    if (random 1 >= _ch) exitWith {};
    if (isNil "FAC_civRadio_trackClassnames") then {
        call compile preprocessFileLineNumbers "rsc\FAC_CivCarRadioTracks.sqf";
    };
    private _pool = FAC_civRadio_trackClassnames;
    if (_pool isEqualTo [] || {!(_pool isEqualType [])}) exitWith {};
    private _song = selectRandom _pool;
    _veh setVariable ["FADE_civCarRadioSong", _song, false];
    _veh setVariable ["FADE_civCarRadioPending", true, false];
    _veh setVariable ["FADE_civCarRadioStarted", false, false];
    _veh setVariable ["FADE_civCarRadioSuppressed", false, false];
    _veh setVariable ["FADE_civCarRadioOwned", true, false];
    _veh setVariable ["FADE_civCarRadioSourceKey", "", false];
    _veh addEventHandler ["Deleted", {
        params ["_veh"];
        if (_veh getVariable ["FADE_civCarRadioStarted", false]) then {
            private _key = _veh getVariable ["FADE_civCarRadioSourceKey", ""];
            if (_key != "") then { ["", _key, objNull] remoteExec ["FAC_jukebox_serverPlay", 2]; };
        };
    }];
};

FADE_civ_tickCarRadios = {
    if (!(missionNamespace getVariable ["FADE_civiliansEnabled", true])) exitWith {};
    private _players = [];
    { if (alive _x && { isPlayer _x }) then { _players pushBack _x } } forEach allPlayers;
    if (_players isEqualTo []) exitWith {};
    private _trigD = missionNamespace getVariable ["FADE_civCarRadioTriggerDist", 1000];
    private _vol = missionNamespace getVariable ["FADE_civCarRadioVolume", 25];
    private _aud = missionNamespace getVariable ["FADE_civCarRadioAudibleDist", 1000];
    {
        private _v = _x;
        if (isNull _v || {!alive _v}) then { continue };
        if (_v getVariable ["FADE_civCarRadioSuppressed", false]) then { continue };
        if (!(_v getVariable ["FADE_civCarRadioPending", false])) then { continue };
        if (_v getVariable ["FADE_civCarRadioStarted", false]) then { continue };
        private _pos = getPosATL _v;
        private _md = 1e12;
        { _md = _md min (_pos distance2D _x) } forEach _players;
        if (_md >= _trigD) then { continue };
        _v setVariable ["FADE_civCarRadioStarted", true, false];
        private _song = _v getVariable ["FADE_civCarRadioSong", ""];
        if (_song == "") then { continue };
        private _nid = netId _v;
        if (_nid == "") then {
            _v setVariable ["FADE_civCarRadioStarted", false, false];
            continue;
        };
        private _key = _v getVariable ["FADE_civCarRadioSourceKey", ""];
        if (_key == "" || { _key == "vehicle:" }) then {
            _key = format ["vehicle:%1", _nid];
            _v setVariable ["FADE_civCarRadioSourceKey", _key, false];
        };
        [_song, _key, objNull, _vol, _aud] remoteExec ["FAC_jukebox_serverPlay", 2];
    } forEach FADE_roadVehicles;
};

// -----------------------------------------------------------------------------
// Road vehicle spawn - ONLY GUI faction; requires ≥1 active civ zone; road in ring around zone
// -----------------------------------------------------------------------------
FADE_civ_spawnRoadVehicle = {
    if (!(missionNamespace getVariable ["FADE_civiliansEnabled", true])) exitWith {};
    private _roadVehClasses = call FADE_civ_getVehicleClassesFromGui;
    private _driverClasses = call FADE_civ_getUnitClassesFromGui;
    private _faction = missionNamespace getVariable ["FADE_scenarioCivFaction", "CIV_F"];

    if (_roadVehClasses isEqualTo [] && { _driverClasses isEqualTo [] }) exitWith {
        call FADE_civ_showNoCivsHint;
        call FADE_civ_showNoCivVehiclesHint;
        [format ["ROAD VEH BLOCKED: No civ units AND no civ vehicles for faction %1", _faction]] call FADE_civ_debugChat;
    };
    if (_roadVehClasses isEqualTo []) exitWith {
        call FADE_civ_showNoCivVehiclesHint;
        [format ["ROAD VEH BLOCKED: No civ vehicles available for faction %1", _faction]] call FADE_civ_debugChat;
    };
    if (_driverClasses isEqualTo []) exitWith {
        call FADE_civ_showNoCivsHint;
        [format ["ROAD VEH BLOCKED: No civ units available for faction %1 (need drivers)", _faction]] call FADE_civ_debugChat;
    };

    private _roadMax = missionNamespace getVariable ["FADE_roadVehicleMax", 5];
    if (count FADE_roadVehicles >= _roadMax) exitWith {};

    if (count (keys FADE_civZoneState) == 0) exitWith {};

    private _startPos = call FADE_civ_findAmbientRoadSpawnPos;
    if (_startPos isEqualTo []) exitWith {};

    private _cls = _roadVehClasses select (floor random (count _roadVehClasses max 1));
    private _veh = createVehicle [_cls, _startPos, [], 0, "NONE"];
    if (isNull _veh) exitWith {};
    [_veh, 0.35] call FADE_civ_snapToTerrain;

    private _grp = createGroup civilian;
    private _driverCls = _driverClasses select (floor random (count _driverClasses max 1));
    private _driver = _grp createUnit [_driverCls, _startPos, [], 0, "NONE"];
    if (isNull _driver) then {
        deleteVehicle _veh;
        deleteGroup _grp;
    } else {
        _driver setVariable ["BIS_cp_excluded", true];
        _grp setVariable ["BIS_cp_excluded", true];
        _driver setVariable ["FADE_ambientCiv", true];
        removeHeadgear _driver;
        removeGoggles _driver;
        _driver moveInDriver _veh;
        _driver setBehaviour "SAFE";
        _driver setSpeedMode "LIMITED";

        private _nearestFurthest = [_startPos] call FADE_civ_zoneCentersNearestFurthest;
        private _wpNearest = _nearestFurthest select 0;
        private _wpFurthest = _nearestFurthest select 1;
        if (count _wpNearest < 2 || { count _wpFurthest < 2 }) then {
            { deleteVehicle _x } forEach units _grp;
            deleteGroup _grp;
            deleteVehicle _veh;
        } else {
        private _minFinal = missionNamespace getVariable ["FADE_roadFinalWpMinDist", 2000];
        private _finalPos = [_wpFurthest, _minFinal] call FADE_civ_randomPosMinDistFrom;

        if ((_wpNearest distance _wpFurthest) < 15) then {
            private _w1 = _grp addWaypoint [_wpNearest, 0];
            _w1 setWaypointType "MOVE";
            _w1 setWaypointSpeed "LIMITED";
        } else {
            private _w1 = _grp addWaypoint [_wpNearest, 0];
            _w1 setWaypointType "MOVE";
            _w1 setWaypointSpeed "LIMITED";
            private _w2 = _grp addWaypoint [_wpFurthest, 0];
            _w2 setWaypointType "MOVE";
            _w2 setWaypointSpeed "LIMITED";
        };
        private _wLast = _grp addWaypoint [_finalPos, 0];
        _wLast setWaypointType "MOVE";
        _wLast setWaypointSpeed "LIMITED";
        _wLast setWaypointStatements ["true", "private _v = vehicle this; private _g = group this; FADE_roadVehicles = FADE_roadVehicles - [_v]; { deleteVehicle _x } forEach units _g; deleteGroup _g; deleteVehicle _v;"];

        FADE_roadVehicles pushBack _veh;
        [_veh] call FADE_civ_setupRoadCarRadio;
        [format ["ROAD VEH SPAWNED (%1/%2) | faction: %3 | vehicle: %4 | driver: %5", count FADE_roadVehicles, _roadMax, _faction, _cls, _driverCls]] call FADE_civ_debugChat;
        };
    };
};

// Delete one ambient civ vehicle (road or air) and its crew/group; does not touch FADE_roadVehicles / aircraft list
FADE_civ_deleteAmbientVehicle = {
    params ["_veh"];
    if (isNull _veh) exitWith {};
    private _d = driver _veh;
    private _g = if (!isNull _d) then { group _d } else { grpNull };
    if (!isNull _g) then {
        { deleteVehicle _x } forEach units _g;
        deleteGroup _g;
    } else {
        { deleteVehicle _x } forEach crew _veh;
    };
    if (!isNull _veh) then { deleteVehicle _veh };
};

// Despawn ambient civ road + aircraft too far from any player (frees sim when nobody can see them)
FADE_civ_cleanupDistantVehicles = {
    params [["_players", []]];
    if (_players isEqualTo []) then {
        { if (alive _x && { isPlayer _x }) then { _players pushBack _x } } forEach allPlayers;
    };
    private _distMax = missionNamespace getVariable ["FADE_civVehCleanupDist", 4500];
    if (_distMax <= 0) exitWith {};
    private _nearest = {
        params ["_pos"];
        if (_players isEqualTo []) exitWith { 1e12 };
        private _best = 1e12;
        { _best = _best min (_pos distance2D _x) } forEach _players;
        _best
    };

    private _newRoad = [];
    {
        private _v = _x;
        if (isNull _v || { !alive _v }) then { continue };
        if (([getPosATL _v] call _nearest) > _distMax) then {
            [_v] call FADE_civ_deleteAmbientVehicle;
            [format ["ROAD VEH CLEANUP: too far from players (> %1 m)", round _distMax]] call FADE_civ_debugChat;
        } else {
            _newRoad pushBack _v;
        };
    } forEach FADE_roadVehicles;
    FADE_roadVehicles = _newRoad;

    private _airDist = missionNamespace getVariable ["FADE_civAirCleanupDist", -1];
    if (_airDist < 0) then { _airDist = _distMax * 1.75 };
    private _newAir = [];
    {
        private _v = _x;
        if (isNull _v || { !alive _v }) then { continue };
        if (([getPosATL _v] call _nearest) > _airDist) then {
            [_v] call FADE_civ_deleteAmbientVehicle;
            [format ["CIV AIR CLEANUP: too far from players (> %1 m)", round _airDist]] call FADE_civ_debugChat;
        } else {
            _newAir pushBack _v;
        };
    } forEach FADE_civAmbientAircraft;
    FADE_civAmbientAircraft = _newAir;

    // Parked zone cars (same distance rule as road traffic)
    {
        private _zid = _x;
        private _st = FADE_civZoneState get _zid;
        if (isNil "_st") then { continue };
        private _pv = _st get "parkedVehs";
        if (isNil "_pv") then { continue };
        private _keep = [];
        {
            private _v = _x;
            if (isNull _v || { !alive _v }) then { continue };
            if (([getPosATL _v] call _nearest) > _distMax) then {
                deleteVehicle _v;
                [format ["PARKED CLEANUP zone %1 (> %2 m)", _zid, round _distMax]] call FADE_civ_debugChat;
            } else {
                _keep pushBack _v;
            };
        } forEach _pv;
        _st set ["parkedVehs", _keep];
    } forEach (keys FADE_civZoneState);
};

// Delete walking civ groups whose leader is farther than FADE_civUnitCullDist from every player
FADE_civ_cullDistantFootGroups = {
    params [["_players", []]];
    private _dCull = missionNamespace getVariable ["FADE_civUnitCullDist", 0];
    if (_dCull <= 0) exitWith {};
    if (_players isEqualTo []) then {
        { if (alive _x && { isPlayer _x }) then { _players pushBack _x } } forEach allPlayers;
    };
    if (_players isEqualTo []) exitWith {};
    private _nearDist = {
        params ["_pos"];
        private _best = 1e12;
        { _best = _best min (_pos distance2D _x) } forEach _players;
        _best
    };
    {
        private _zid = _x;
        if ([_zid] call FADE_civ_isZonePinned) then { continue };
        private _st = FADE_civZoneState get _zid;
        if (isNil "_st") then { continue };
        private _grps = _st get "groups";
        if (isNil "_grps") then { _grps = [] };
        private _keep = [];
        {
            private _g = _x;
            if (isNull _g) then { continue };
            private _ldr = leader _g;
            private _kill = false;
            if (!isNull _ldr && { alive _ldr } && { _ldr getVariable ["FADE_ambientCiv", false] }) then {
                if (([getPosATL _ldr] call _nearDist) > _dCull) then { _kill = true };
            };
            if (_kill) then {
                { deleteVehicle _x } forEach units _g;
                deleteGroup _g;
            } else {
                _keep pushBack _g;
            };
        } forEach _grps;
        _st set ["groups", _keep];
    } forEach (keys FADE_civZoneState);
};

// Trim ambient foot civs down to FADE_civGlobalMaxAlive (removes farthest first; non-pinned zones first)
FADE_civ_enforceGlobalFootCap = {
    params [["_players", []]];
    private _cap = missionNamespace getVariable ["FADE_civGlobalMaxAlive", 0];
    if (_cap <= 0) exitWith {};
    if (_players isEqualTo []) then {
        { if (alive _x && { isPlayer _x }) then { _players pushBack _x } } forEach allPlayers;
    };
    if (_players isEqualTo []) exitWith {};

    private _fnc_trimOne = {
        params [["_pinnedOk", false]];
        private _bestD = -1;
        private _bestGrp = grpNull;
        private _bestZid = "";
        {
            private _zid = _x;
            if (!_pinnedOk && { [_zid] call FADE_civ_isZonePinned }) then { continue };
            private _st = FADE_civZoneState get _zid;
            if (!isNil "_st") then {
                private _gl = _st get "groups";
                if (isNil "_gl") then { _gl = [] };
                {
                    private _g = _x;
                    if (isNull _g) then { continue };
                    private _ldr = leader _g;
                    if (!isNull _ldr && { alive _ldr } && { _ldr getVariable ["FADE_ambientCiv", false] }) then {
                        private _d = 1e12;
                        { _d = _d min (_ldr distance2D _x) } forEach _players;
                        if (_d > _bestD) then {
                            _bestD = _d;
                            _bestGrp = _g;
                            _bestZid = _zid;
                        };
                    };
                } forEach _gl;
            };
        } forEach (keys FADE_civZoneState);
        if (isNull _bestGrp || { count units _bestGrp == 0 }) exitWith { false };
        private _u = selectRandom (units _bestGrp);
        if (!isNull _u) then { deleteVehicle _u };
        if (count units _bestGrp == 0) then {
            deleteGroup _bestGrp;
            private _st2 = FADE_civZoneState get _bestZid;
            if (!isNil "_st2") then {
                _st2 set ["groups", (_st2 get "groups") select { !isNull _x && { (count units _x) > 0 } }];
            };
        };
        true
    };

    private _safety = 0;
    while { ([] call FADE_civ_countAmbientFootCivs) > _cap && { _safety < 250 } } do {
        _safety = _safety + 1;
        if ([false] call _fnc_trimOne) then { continue };
        if !([true] call _fnc_trimOne) exitWith {};
    };
};

// -----------------------------------------------------------------------------
// Main loop
// -----------------------------------------------------------------------------
FADE_civ_checkZones = {
    if (!(missionNamespace getVariable ["FADE_civiliansEnabled", true])) exitWith {};
    private _players = [];
    { if (alive _x && { isPlayer _x }) then { _players pushBack _x } } forEach allPlayers;
    if (_players isEqualTo []) exitWith {};
    [_players] call FADE_civ_cleanupDistantVehicles;
    call FADE_civ_ensurePinnedZonesSpawned;

    private _activateDist = missionNamespace getVariable ["FADE_civPlayerActivateDist", 800];
    private _deactivateDist = missionNamespace getVariable ["FADE_civPlayerDeactivateDist", 1200];
    private _zoneActivationDist = missionNamespace getVariable ["FADE_civZoneActivationDist", _activateDist];
    private _triggerNames = missionNamespace getVariable ["FADE_civTriggerNames", []];
    private _numPlayers = count _players;
    private _zoneKeys = keys FADE_civZoneState;

    for "_t" from 0 to (count _triggerNames - 1) do {
        private _name = _triggerNames select _t;
        private _trigger = missionNamespace getVariable [_name, objNull];
        if (!isNull _trigger) then {
            private _pinned = [_name] call FADE_civ_isZonePinned;
            private _center = getPosATL _trigger;
            private _minPlayerDist = 1e12;
            {
                _minPlayerDist = _minPlayerDist min (_x distance2D _center);
            } forEach _players;
            if (_minPlayerDist > _zoneActivationDist && { !_pinned }) then { continue };
            private _nearCount = 0;
            private _farCount = 0;
            for "_p" from 0 to (_numPlayers - 1) do {
                private _pl = _players select _p;
                if ((_pl distance _center) < _activateDist) then { _nearCount = _nearCount + 1 };
                if ((_pl distance _center) > _deactivateDist) then { _farCount = _farCount + 1 };
            };
            if (_nearCount > 0 || { _pinned }) then {
                private _alreadyActive = !(isNil { FADE_civZoneState get _name });
                private _maxZ = missionNamespace getVariable ["FADE_civMaxActiveZones", 4];
                if (!_alreadyActive && { !_pinned }) then {
                    private _guard = 0;
                    while { ([] call FADE_civ_countActiveNonPinnedZones) >= _maxZ && { _guard < 8 } } do {
                        _guard = _guard + 1;
                        private _evict = "";
                        private _evictScore = -1;
                        {
                            private _zid = _x;
                            if ([_zid] call FADE_civ_isZonePinned) then { continue };
                            private _zt = missionNamespace getVariable [_zid, objNull];
                            if (isNull _zt) then { continue };
                            private _zc = getPosATL _zt;
                            private _dClose = 1e12;
                            { _dClose = _dClose min (_zc distance2D _x) } forEach _players;
                            if (_dClose > _evictScore) then { _evictScore = _dClose; _evict = _zid };
                        } forEach _zoneKeys;
                        if (_evict == "") exitWith {};
                        [_evict] call FADE_civ_despawnZone;
                    };
                };
                if (_alreadyActive || { _pinned } || { ([] call FADE_civ_countActiveNonPinnedZones) < _maxZ }) then {
                    [_trigger, _name] call FADE_civ_spawnZone;
                };
            };
            if (_farCount == _numPlayers && { !_pinned }) then { [_name] call FADE_civ_despawnZone };
        };
    };

    [_players] call FADE_civ_cullDistantFootGroups;
    [_players] call FADE_civ_enforceGlobalFootCap;

    private _validRoad = [];
    for "_i" from 0 to (count FADE_roadVehicles - 1) do {
        private _v = FADE_roadVehicles select _i;
        if (!isNull _v && { alive _v }) then { _validRoad pushBack _v };
    };
    FADE_roadVehicles = _validRoad;
};

// -----------------------------------------------------------------------------
// Start - reset hint flags when scenario settings applied (so re-apply can show hint again)
// -----------------------------------------------------------------------------
FADE_civ_resetHintFlags = {
    missionNamespace setVariable ["FADE_civNoCivsHintShown", false];
    missionNamespace setVariable ["FADE_civNoCivVehHintShown", false];
};

// -----------------------------------------------------------------------------
// Start
// -----------------------------------------------------------------------------
[] spawn {
    private _interval = missionNamespace getVariable ["FADE_civCheckInterval", 45];
    while { true } do {
        private _players = playableUnits select { alive _x && { isPlayer _x } };
        if (_players isEqualTo []) then {
            sleep 60;
        } else {
            sleep _interval;
            call FADE_civ_checkZones;
        };
    };
};

private _zoneCount = count (missionNamespace getVariable ["FADE_civTriggerNames", []]);
private _civClasses = call FADE_civ_getUnitClassesFromGui;
private _civVehClasses = call FADE_civ_getVehicleClassesFromGui;
private _factionStart = missionNamespace getVariable ["FADE_scenarioCivFaction", "CIV_F"];
if (_zoneCount == 0) then {
    ["NO CIV ZONES BUILT (named locations + distance/water filter). Check FADE_basePos and FADE_civZone* Config."] call FADE_civ_debugChat;
} else {
    if (_civClasses isEqualTo [] && { _civVehClasses isEqualTo [] }) then {
        call FADE_civ_showNoCivsHint;
        call FADE_civ_showNoCivVehiclesHint;
        [format ["CIV POP: No civ units AND no civ vehicles for faction %1 - zone/road spawns disabled", _factionStart]] call FADE_civ_debugChat;
    } else {
        if (_civClasses isEqualTo []) then {
            call FADE_civ_showNoCivsHint;
            [format ["CIV POP: No civ units for faction %1 - zone spawns disabled, road vehicles need drivers", _factionStart]] call FADE_civ_debugChat;
        } else {
            if (_civVehClasses isEqualTo []) then {
                call FADE_civ_showNoCivVehiclesHint;
                [format ["CIV POP: %1 ZONES, faction %2 - zone spawns OK, no civ vehicles (road spawns disabled)", _zoneCount, _factionStart]] call FADE_civ_debugChat;
            } else {
                [format ["CIV POP: %1 ZONES, faction %2 - %3 unit types, %4 vehicle types (ambient road: ring around active zones)", _zoneCount, _factionStart, count _civClasses, count _civVehClasses]] call FADE_civ_debugChat;
            };
        };
    };
};

[] spawn {
    private _tick = missionNamespace getVariable ["FADE_roadSpawnTickSec", 60];
    private _chance = missionNamespace getVariable ["FADE_roadSpawnChance", 1];
    sleep _tick;
    while { true } do {
        if (
            (missionNamespace getVariable ["FADE_civiliansEnabled", true]) &&
            { count (keys FADE_civZoneState) > 0 } &&
            { random 1 < _chance }
        ) then {
            call FADE_civ_spawnRoadVehicle;
        };
        sleep _tick;
    };
};

[] spawn {
    private _intv = missionNamespace getVariable ["FADE_civCarRadioCheckInterval", 10];
    sleep _intv;
    while { true } do {
        call FADE_civ_tickCarRadios;
        sleep _intv;
    };
};

// -----------------------------------------------------------------------------
// Ambient civilian aircraft - fly past every ~10 minutes
// Spawns a civ aircraft at map edge, flies to the opposite edge, then despawns.
// Only runs if the civ faction has aircraft (scope >= 2, isKindOf "Air").
// -----------------------------------------------------------------------------
[] spawn {
    sleep 120;
    while { true } do {
        sleep (540 + random 120);
        if (!(missionNamespace getVariable ["FADE_civiliansEnabled", true])) then { continue };
        private _faction = missionNamespace getVariable ["FADE_scenarioCivFaction", "CIV_F"];
        if (_faction == "" || { isNil "FADE_getUnitsForFaction" }) then { continue };

        // Collect civ air classes from CfgVehicles: scope >= 2, Air, civ side (3) or faction matches
        private _civAir = [];
        {
            private _cfg = configFile >> "CfgVehicles" >> _x;
            if (isClass _cfg && { getNumber (_cfg >> "scope") >= 2 } && { _x isKindOf "Air" }) then {
                private _side = getNumber (_cfg >> "side");
                private _fac = getText (_cfg >> "faction");
                if (_side == 3 || { _fac == _faction }) then { _civAir pushBack _x };
            };
        } forEach (keys FADE_civVehiclesByFaction);
        // Fall back to scanning known civ aircraft if map empty
        if (_civAir isEqualTo []) then {
            {
                private _cfg = configFile >> "CfgVehicles" >> _x;
                if (isClass _cfg && { getNumber (_cfg >> "scope") >= 2 } && { _x isKindOf "Air" } && { getNumber (_cfg >> "side") == 3 }) then { _civAir pushBack _x };
            } forEach ["C_Plane_Civil_01_F", "C_Plane_Civil_01_racing_F", "C_Helicopter_01_F"];
        };
        if (_civAir isEqualTo []) then { continue };

        private _aircraftClass = selectRandom _civAir;
        private _side = random 360;
        private _mapMin = missionNamespace getVariable ["FADE_mapMin", 0];
        private _mapMax = missionNamespace getVariable ["FADE_mapMax", worldSize];
        private _halfMap = (_mapMin + _mapMax) / 2;
        private _halfSpan = (_mapMax - _mapMin) / 2;
        private _startEdge = [_halfMap + _halfSpan * (sin _side) * 0.95, _halfMap + _halfSpan * (cos _side) * 0.95, 180 + random 250];
        private _endEdge   = [_halfMap - _halfSpan * (sin _side) * 0.95, _halfMap - _halfSpan * (cos _side) * 0.95, _startEdge select 2];

        private _aircraft = createVehicle [_aircraftClass, _startEdge, [], 0, "FLY"];
        if (!isNull _aircraft) then {
            FADE_civAmbientAircraft pushBack _aircraft;
            _aircraft flyInHeight (180 + random 250);
            private _grp = createGroup civilian;
            private _driverCls = call FADE_civ_getUnitClassesFromGui;
            private _pilotCls = if (_driverCls isEqualTo []) then { "C_man_1" } else { selectRandom _driverCls };
            private _pilot = _grp createUnit [_pilotCls, _startEdge, [], 0, "NONE"];
            _pilot moveInDriver _aircraft;
            _pilot setVariable ["BIS_cp_excluded", true];
            _grp setVariable ["BIS_cp_excluded", true];
            _pilot setVariable ["FADE_ambientCiv", true];
            _aircraft setBehaviour "CARELESS";
            _aircraft setSpeedMode "FULL";
            private _wp = _grp addWaypoint [_endEdge, 0];
            _wp setWaypointType "MOVE";
            _wp setWaypointStatements ["true", "private _v = vehicle this; if (!isNil 'FADE_civAmbientAircraft') then { FADE_civAmbientAircraft = FADE_civAmbientAircraft - [_v] }; private _g = group this; { deleteVehicle _x } forEach units _g; deleteGroup _g; deleteVehicle _v;"];
            [format ["AMBIENT AIRCRAFT: %1 spawned", _aircraftClass]] call FADE_civ_debugChat;
        };
    };
};
