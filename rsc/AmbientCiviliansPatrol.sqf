// AmbientCiviliansPatrol.sqf - zone pin state, enemy patrol spawn
FADE_civ_filterClasses = {
    params ["_classes", ["_unitsOnly", false]];
    if (isNil "_classes" || {!(_classes isEqualType [])}) exitWith { [] };
    private _out = [];
    {
        private _c = _x;
        if (!(_c isEqualType "") || { _c == "" }) then { continue };
        private _cfg = configFile >> "CfgVehicles" >> _c;
        if (!isClass _cfg) then { continue };
        private _scope = getNumber (_cfg >> "scope");
        private _side = getNumber (_cfg >> "side");
        // Align with CfgVehicles scan: civilian (side 3) may use scope 0/1; combat factions keep scope >= 2.
        private _scopeOk = if (_side == 3) then { _scope >= 0 } else { _scope >= 2 };
        if (!_scopeOk) then { continue };
        if (_unitsOnly && { !(_c isKindOf "Man") }) then { continue };
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
    private _filtered = [_raw, true] call FADE_civ_filterClasses;  // true = units only (Man), avoids abstract/faction-named classes
    // #region agent log
    diag_log format [
        "[FAC DbgBrowser 62d308] H26 civUnitClasses faction=%1 raw=%2 filtered=%3 sample=%4",
        _faction, count _raw, count _filtered,
        if (count _filtered > 0) then { _filtered select 0 } else { if (count _raw > 0) then { _raw select 0 } else { "" } }
    ];
    // #endregion
    _filtered
};

FADE_civ_getVehicleClassesFromGui = {
    private _faction = missionNamespace getVariable ["FADE_scenarioCivFaction", "CIV_F"];
    if (_faction == "") exitWith { [] };
    if (isNil "FADE_getCivVehiclesForFaction") exitWith { [] };
    private _raw = [_faction] call FADE_getCivVehiclesForFaction;
    private _filtered = [_raw, false] call FADE_civ_filterClasses;  // false = vehicles, not units
    // #region agent log
    diag_log format [
        "[FAC DbgBrowser 62d308] H26 civVehClasses faction=%1 raw=%2 filtered=%3 sample=%4",
        _faction, count _raw, count _filtered,
        if (count _filtered > 0) then { _filtered select 0 } else { if (count _raw > 0) then { _raw select 0 } else { "" } }
    ];
    // #endregion
    _filtered
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

// Raid / Invasion / Operation: release mission-pinned civ zones (idempotent; clears stored id lists).
FADE_mission_unpinCivZonesForTask = {
    params ["_taskId"];
    if (_taskId == "") exitWith {};
    private _raidIds = missionNamespace getVariable ["FADE_raidCivZoneIds_" + _taskId, []];
    if (_raidIds isNotEqualTo []) then {
        if (!isNil "FADE_civ_unpinZones") then { [_raidIds] call FADE_civ_unpinZones };
        missionNamespace setVariable ["FADE_raidCivZoneIds_" + _taskId, nil];
    };
    private _invIds = missionNamespace getVariable ["FADE_invasionCivZoneIds_" + _taskId, []];
    if (_invIds isNotEqualTo []) then {
        if (!isNil "FADE_civ_unpinZones") then { [_invIds] call FADE_civ_unpinZones };
        missionNamespace setVariable ["FADE_invasionCivZoneIds_" + _taskId, nil];
    };
    private _opIds = missionNamespace getVariable ["FADE_operationCivZoneIds_" + _taskId, []];
    if (_opIds isNotEqualTo []) then {
        if (!isNil "FADE_civ_unpinZones") then { [_opIds] call FADE_civ_unpinZones };
        missionNamespace setVariable ["FADE_operationCivZoneIds_" + _taskId, nil];
    };
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

// Snipers only spawn on rooftops; keep them out of ground patrol / garrison / vehicle pools.
FADE_filterNonSniperUnits = {
    params ["_classes"];
    if (_classes isEqualTo [] || { !(_classes isEqualType []) }) exitWith { _classes };
    private _out = _classes select { !([_x] call FADE_unitClassIsOpforSniper) };
    if (_out isEqualTo []) then { _classes } else { _out };
};

FADE_enemyPatrol_pickSniperRoofPos = {
    params ["_buildings", ["_minDistPlayers", 400], ["_usedRoofs", []]];
    if (_buildings isEqualTo [] || { isNil "FADE_buildingRoofPos" }) exitWith { [] };
    private _minElev = missionNamespace getVariable ["FADE_enemyPatrolSniperMinElevAboveTerrainM", 7];
    private _tries = missionNamespace getVariable ["FADE_enemyPatrolSniperBuildingTries", 8];
    private _pool = +_buildings;
    _pool = _pool call BIS_fnc_arrayShuffle;
    if (count _pool > _tries) then { _pool = _pool select [0, _tries] };
    private _roof = [];
    {
        if (count _roof >= 2) exitWith {};
        private _candidate = [_x] call FADE_buildingRoofPos;
        if (count _candidate < 3) then { continue };
        if ((_candidate select 2) < _minElev) then { continue };
        if (({ (_candidate distance2D _x) < 25 } count _usedRoofs) > 0) then { continue };
        if (({ alive _x && { isPlayer _x } && { (getPosATL _x) distance2D _candidate < _minDistPlayers } } count allPlayers) > 0) then { continue };
        _roof = _candidate;
    } forEach _pool;
    _roof
};

// Despawn all patrol entities for a zone (groups, vehicle groups, vehicles, garrison groups, sniper groups, barrels)
// Also cancels pending virtual garrison and sweeps any activated VG groups tagged with owner patrol:<zoneId>.
FADE_enemyPatrol_despawnVgOwnerGroups = {
    params ["_zoneId"];
    private _owner = format ["patrol:%1", _zoneId];
    private _sideEnemy = missionNamespace getVariable ["FADE_sideEnemy", east];
    {
        private _grp = _x;
        if (isNull _grp || { side _grp != _sideEnemy }) then { continue };
        if (_grp getVariable ["FADE_vgOwner", ""] != _owner) then { continue };
        { if (!isNull _x) then { deleteVehicle _x } } forEach units _grp;
        deleteGroup _grp;
    } forEach allGroups;
};

FADE_enemyPatrol_despawnForZone = {
    params ["_zoneId"];
    // Pending deferred garrisons must cancel even when zone state was never saved (VG-only registration).
    private _vgX = missionNamespace getVariable ["FADE_vg_cancelPendingByOwner", {}];
    if (!(_vgX isEqualTo {})) then { [format ["patrol:%1", _zoneId]] call _vgX };
    private _state = FADE_enemyPatrolZoneState get _zoneId;
    if (!isNil "_state") then {
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
    [_zoneId] call FADE_enemyPatrol_despawnVgOwnerGroups;
};

FADE_enemyPatrol_despawnAll = {
    if (!isNil "FADE_enemyPatrolZoneState" && { FADE_enemyPatrolZoneState isEqualType createHashMap }) then {
        private _ids = +(keys FADE_enemyPatrolZoneState);
        { [_x] call FADE_enemyPatrol_despawnForZone } forEach _ids;
    };
};
missionNamespace setVariable ["FADE_enemyPatrol_despawnAll", FADE_enemyPatrol_despawnAll];

// Spawn enemy patrol: infantry groups, 1-2 road vehicles (car type) with cargo and cycle waypoints, 2-4 garrisoned buildings with burning barrel
FADE_enemyPatrol_spawnForZone = {
    params ["_center", "_zoneId"];
    if (!(missionNamespace getVariable ["FADE_scenarioPatrols", true])) exitWith {};
    if (!isNil "FADE_civ_isZonePinned" && { [_zoneId] call FADE_civ_isZonePinned }) exitWith {};
    if (!(isNil { FADE_enemyPatrolZoneState get _zoneId })) exitWith {};
    // Never spawn ambient patrol within 1 km of player base (BASE_1)
    private _basePos = missionNamespace getVariable ["FADE_basePos", []];
    if (count _basePos >= 2 && { (_center distance _basePos) < 1000 }) exitWith {};
    private _townChance = missionNamespace getVariable ["FADE_enemyPatrolTownChance", 0.25];
    if (random 1 > _townChance) exitWith {};
    private _enemyUnits = missionNamespace getVariable ["FADE_enemyUnits", []];
    if (_enemyUnits isEqualTo []) exitWith {};
    private _groundUnits = [_enemyUnits] call FADE_filterNonSniperUnits;
    private _sideEnemy = missionNamespace getVariable ["FADE_sideEnemy", east];
    private _patrolGroups = [];
    private _vehicleGroups = [];
    private _vehicles = [];
    private _garrisonGroups = [];
    private _sniperGroups = [];
    private _barrels = [];
    private _vgSlotsRegistered = 0;
    private _zoneRadius = missionNamespace getVariable ["FADE_civSpawnRadius", 1000];
    if (_zoneRadius > 900) then { _zoneRadius = 800 };
    private _patrolPlClearM = missionNamespace getVariable ["FADE_enemyPatrolMinDistFromPlayersM", 400];
    private _spawnMinD = missionNamespace getVariable ["FADE_enemyPatrolSpawnMinDistM", 60];
    private _spawnMaxD = missionNamespace getVariable ["FADE_enemyPatrolSpawnMaxDistM", 280];
    private _wpMinD = missionNamespace getVariable ["FADE_enemyPatrolWpMinDistM", 40];
    private _wpMaxD = missionNamespace getVariable ["FADE_enemyPatrolWpMaxDistM", 200];
    private _vehRoadSearchM = missionNamespace getVariable ["FADE_enemyPatrolVehicleRoadSearchM", 350];
    _spawnMinD = (_spawnMinD max 20) min _spawnMaxD;
    _spawnMaxD = _spawnMaxD max (_spawnMinD + 40);
    _wpMinD = (_wpMinD max 15) min _wpMaxD;
    _wpMaxD = _wpMaxD max (_wpMinD + 30);
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
            private _dist = _spawnMinD + random ((_spawnMaxD - _spawnMinD) max 1);
            private _rough = _center getPos [_dist, _angle];
            _sp = [[_rough, 0, 15, 3, 1, 0.4, 0, [], _rough], _rough] call FADE_findSafePosArray;
            if (!(_sp isEqualType []) || { count _sp < 2 }) then { _sp = +_rough };
            if (count _sp < 3) then { _sp set [2, 0] };
            if ([_sp] call _dryFn && { [_sp, _patrolPlClearM] call _patrolFarFromPlayers }) exitWith {};
            _sp = [];
        };
        if (count _sp < 2) then { continue };
        private _size = 3 + floor random 4;
        private _shuffled = _groundUnits call BIS_fnc_arrayShuffle;
        private _units = _shuffled select [0, _size min count _shuffled];
        if (_units isEqualTo []) exitWith {};
        // createGroup + patrol cycle (not BIS_fnc_spawnGroup — avoids stale auto-waypoints leaving groups idle).
        private _grp = [_sp, _sideEnemy, _units] call FADE_missionCreateInfantryGroupAt;
        if (isNull _grp || { count units _grp == 0 }) then { continue };
        [_grp] call FAC_applyEnemyScenarioToGroup;
        private _wpMaxDist = _wpMaxD;
        private _patrolOk = [_grp, _center, _wpMinD, _wpMaxDist, 4, random 360, 90, "SAFE", "YELLOW", "LIMITED", true] call FADE_missionApplyPatrolCycle;
        if (!_patrolOk) then {
            _patrolOk = [_grp, _sp, 25, 120, 4, random 360, 90, "SAFE", "YELLOW", "LIMITED", true] call FADE_missionApplyPatrolCycle;
        };
        if (!_patrolOk) then { continue };
        _patrolGroups pushBack _grp;
    };

    // 1-2 cars on road: spawn on road in zone, waypoint random in zone then cycle, fill cargo with enemy units
    private _enemyVehList = missionNamespace getVariable ["FADE_enemyVehicles", []];
    private _carClasses = [];
    { if ((_x isEqualType "") && { isClass (configFile >> "CfgVehicles" >> _x) }) then { if (_x isKindOf "Car") then { _carClasses pushBack _x } } } forEach _enemyVehList;
    if (_carClasses isEqualTo [] && { count _enemyVehList > 0 }) then { _carClasses = _enemyVehList };
    if (!(_carClasses isEqualTo []) && { count _groundUnits > 0 }) then {
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
            _roadHit = [_center, _vehRoadSearchM, _spawnedPatrolVehs, -1, [], _center] call FADE_findOpforGroundVehicleRoadSpawn;
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
                _driverCls = selectRandom _groundUnits;
                _driver = _vehGrp createUnit [_driverCls, _roadPos, [], 0, "NONE"];
                if (isNull _driver) then { deleteVehicle _veh; deleteGroup _vehGrp; continue };
                _driver assignAsDriver _veh;
                _driver moveInDriver _veh;
                _cargoSeats = [_veh] call FADE_getCargoSeats;
                if (isNil "_cargoSeats") then { _cargoSeats = 0 };
                _cargoSeats = (_cargoSeats min 6) max 0;
                for "_c" from 0 to (_cargoSeats - 1) do {
                    _cls = selectRandom _groundUnits;
                    _u = _vehGrp createUnit [_cls, _roadPos, [], 0, "NONE"];
                    if (!isNull _u) then { _u assignAsCargo _veh; _u moveInCargo _veh };
                };
                [_veh, _enemyUnits] call FADE_ensureEnemyVehicleGunner;
                _vehGrp setBehaviour "SAFE";
                _vehGrp setSpeedMode "LIMITED";
                _wpPosA = [_center, _wpMaxD * 0.85] call FADE_civ_findSpawnPos;
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

    // 2-4 garrisoned buildings near town centre (virtual garrison activates when players approach).
    private _garScanR = missionNamespace getVariable ["FADE_garrisonAmbientScanRadiusM", 380];
    private _ambBChance = missionNamespace getVariable ["FADE_garrisonAmbientBuildingChance", 0.55];
    private _buildings = nearestObjects [_center, ["House", "Building"], _garScanR];
    private _buildingsWithPos = _buildings select {
        count (_x buildingPos -1) >= 2 && { [getPosATL _x] call _dryFn }
    };
    private _ctrSort = +_center;
    _buildingsWithPos = [_buildingsWithPos, [], { (getPosATL _x) distance2D _ctrSort }, "ASCEND"] call BIS_fnc_sortBy;
    private _thinnedBlds = _buildingsWithPos select { random 1 < _ambBChance };
    private _minGar = (2 min count _buildingsWithPos) max 0;
    if (count _thinnedBlds < _minGar && { count _buildingsWithPos > 0 }) then {
        _thinnedBlds = +(_buildingsWithPos select [0, _minGar min count _buildingsWithPos]);
    };
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
            _st set ["barrelMinDistPlayersM", -1];
            private _vgId = [_bld, _slotATL, _groundUnits, _st] call _vgFn;
            if (_vgId >= 0) then { _vgSlotsRegistered = _vgSlotsRegistered + 1 };
        } else {
            if (count _slotATL == 0) then { } else {
                private _garrisonGrp = createGroup _sideEnemy;
                {
                    private _p = +_x;
                    private _cls = selectRandom _groundUnits;
                    private _u = _garrisonGrp createUnit [_cls, _p, [], 0, "NONE"];
                    if (!isNull _u) then { _u setUnitPos "MIDDLE"; [_u] call FADE_tryAmbientCombatAnim };
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
                private _snMinElev = missionNamespace getVariable ["FADE_enemyPatrolSniperMinElevAboveTerrainM", 7];
                for "_sn" from 1 to _numSn do {
                    private _roof = [_buildingsWithPos, _patrolPlClearM, _usedRoofs] call FADE_enemyPatrol_pickSniperRoofPos;
                    if (count _roof < 3) then { continue };
                    if ((_roof select 2) < _snMinElev) then { continue };
                    _usedRoofs pushBack _roof;
                    private _snGrp = createGroup _sideEnemy;
                    private _cls = selectRandom _sniperClasses;
                    private _u = _snGrp createUnit [_cls, _roof, [], 0, "NONE"];
                    if (isNull _u) then {
                        deleteGroup _snGrp;
                        continue;
                    };
                    _u setPosATL _roof;
                    private _uPos = getPosATL _u;
                    if (((_uPos select 2) < _snMinElev) || { (_uPos distance2D _roof) > 4 }) then {
                        deleteVehicle _u;
                        deleteGroup _snGrp;
                        continue;
                    };
                    _u setUnitPos "UP";
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

    if (count _patrolGroups > 0 || { count _vehicles > 0 } || { count _garrisonGroups > 0 } || { count _sniperGroups > 0 } || { _vgSlotsRegistered > 0 } || { count _barrels > 0 }) then {
        private _state = createHashMap;
        _state set ["groups", _patrolGroups];
        _state set ["vehicleGroups", _vehicleGroups];
        _state set ["vehicles", _vehicles];
        _state set ["garrisonGroups", _garrisonGroups];
        _state set ["sniperGroups", _sniperGroups];
        _state set ["barrels", _barrels];
        FADE_enemyPatrolZoneState set [_zoneId, _state];
        [format ["PATROL ZONE %1: %2 group(s), %3 vehicle(s), %4 garrison(s), %5 sniper(s), VG=%6", _zoneId, count _patrolGroups, count _vehicles, count _garrisonGroups, count _sniperGroups, _vgSlotsRegistered]] call FADE_civ_debugChat;
        // #region agent log
        diag_log format ["[FAC DbgBrowser 62d308] H12 patrolZone=%1 spawnRing=%2-%3 wpRing=%4-%5 garScan=%6 blds=%7 vg=%8 garImmed=%9",
            _zoneId, _spawnMinD, _spawnMaxD, _wpMinD, _wpMaxD, _garScanR, count _buildingsWithPos, _vgSlotsRegistered, count _garrisonGroups];
        // #endregion
    };
};

FADE_civ_debugChat = {
    params ["_msg"];
    if (missionNamespace getVariable ["FADE_civDebug", false]) then {
        [format ["CIV: %1", _msg]] remoteExec ["systemChat", 0];
    };
};

