// =============================================================================
// AmbientCivilians.sqf - Civ spawn/despawn (CIV_T_* triggers; ambient road vehicles use active zones + roads)
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
missionNamespace setVariable ["FADE_civPlayerActivateDist", missionNamespace getVariable ["FADE_civPlayerActivateDist", 1000]];
missionNamespace setVariable ["FADE_civPlayerDeactivateDist", missionNamespace getVariable ["FADE_civPlayerDeactivateDist", 1400]];
missionNamespace setVariable ["FADE_civSpawnRadius", missionNamespace getVariable ["FADE_civSpawnRadius", 1000]];
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

// Collect CIV_T_* triggers (CIV_T_1 .. CIV_T_N, N = FADE_civTriggerIndexMax — keep in sync with Eden / mission.sqm)
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
FADE_roadVehicles = [];
FADE_civAmbientAircraft = [];
FADE_enemyPatrolZoneState = createHashMap;

// Despawn all patrol entities for a zone (groups, vehicle groups, vehicles, garrison groups, barrels)
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
    private _barrels = _state get "barrels";
    if (isNil "_barrels") then { _barrels = [] };
    {
        if (!isNull _x) then {
            { if (!isNull _x) then { deleteVehicle _x } } forEach units _x;
            deleteGroup _x;
        };
    } forEach (_groups + _vehicleGroups + _garrisonGroups);
    { if (!isNull _x) then { deleteVehicle _x } } forEach _vehicles;
    { if (!isNull _x) then { deleteVehicle _x } } forEach _barrels;
    FADE_enemyPatrolZoneState deleteAt _zoneId;
};

// Spawn enemy patrol: infantry groups, 1-3 road vehicles (car type) with cargo and cycle waypoints, 2-4 garrisoned buildings with burning barrel
FADE_enemyPatrol_spawnForZone = {
    params ["_center", "_zoneId"];
    if (!(missionNamespace getVariable ["FADE_scenarioPatrols", false])) exitWith {};
    if (!(isNil { FADE_enemyPatrolZoneState get _zoneId })) exitWith {};
    // Never spawn ambient patrol within 1 km of player base (BASE_1)
    private _basePos = missionNamespace getVariable ["FADE_basePos", []];
    if (count _basePos >= 2 && { (_center distance _basePos) < 1000 }) exitWith {};
    if (random 1 > 0.4) exitWith {};
    private _enemyUnits = missionNamespace getVariable ["FADE_enemyUnits", []];
    if (_enemyUnits isEqualTo []) exitWith {};
    private _sideEnemy = missionNamespace getVariable ["FADE_sideEnemy", east];
    private _patrolGroups = [];
    private _vehicleGroups = [];
    private _vehicles = [];
    private _garrisonGroups = [];
    private _barrels = [];
    private _zoneRadius = missionNamespace getVariable ["FADE_civSpawnRadius", 1000];
    if (_zoneRadius > 900) then { _zoneRadius = 800 };

    // Infantry patrol groups (1-2 groups; 3-6 units each)
    private _numGroups = 1 + floor random 2;
    for "_g" from 0 to (_numGroups - 1) do {
        private _angle = random 360;
        private _dist = 200 + random (_zoneRadius - 200);
        private _sp = _center getPos [_dist, _angle];
        _sp = [_sp, 0, 15, 3, 1, 0.4, 0, [], _sp] call BIS_fnc_findSafePos;
        if (!(_sp isEqualType []) || { count _sp < 2 }) then { _sp = _center getPos [_dist, _angle] };
        if (count _sp < 3) then { _sp set [2, 0] };
        private _size = 3 + floor random 4;
        private _shuffled = _enemyUnits call BIS_fnc_arrayShuffle;
        private _units = _shuffled select [0, _size min count _shuffled];
        if (_units isEqualTo []) exitWith {};
        private _grp = [_sp, _sideEnemy, _units] call BIS_fnc_spawnGroup;
        if (isNull _grp || { count units _grp == 0 }) then { continue };
        if (!isNil "FADE_applyOpforLauncherPolicyToUnit") then {
            { [_x] call FADE_applyOpforLauncherPolicyToUnit } forEach units _grp;
        };
        _grp setBehaviour "SAFE";
        _grp setCombatMode "YELLOW";
        for "_w" from 0 to 3 do {
            private _wpAngle = _w * 90 + (random 45);
            private _wpDist = 150 + random (_zoneRadius min 600);
            private _wpPos = [(_center select 0) + _wpDist * (cos _wpAngle), (_center select 1) + _wpDist * (sin _wpAngle), 0];
            _wpPos = [_wpPos, 0, 10, 2, 1, 0.4, 0, [], _wpPos] call BIS_fnc_findSafePos;
            if (_wpPos isEqualType [] && { count _wpPos >= 2 }) then {
                _wpPos = [(_wpPos select 0), (_wpPos select 1), (if (count _wpPos > 2) then { _wpPos select 2 } else { 0 })];
                private _wp = _grp addWaypoint [_wpPos, 0];
                _wp setWaypointType "MOVE";
                _wp setWaypointSpeed "LIMITED";
                if (_w == 3) then { _wp setWaypointType "CYCLE" };
            };
        };
        _patrolGroups pushBack _grp;
    };

    // 1-3 cars on road: spawn on road in zone, waypoint random in zone then cycle, fill cargo with enemy units
    private _enemyVehList = missionNamespace getVariable ["FADE_enemyVehicles", []];
    private _carClasses = [];
    { if ((_x isEqualType "") && { isClass (configFile >> "CfgVehicles" >> _x) }) then { if (_x isKindOf "Car") then { _carClasses pushBack _x } } } forEach _enemyVehList;
    if (_carClasses isEqualTo [] && { count _enemyVehList > 0 }) then { _carClasses = _enemyVehList };
    if (!(_carClasses isEqualTo []) && { count _enemyUnits > 0 }) then {
        private _roadPositions = [_center, _zoneRadius, 15] call FADE_civ_getRoadPositions;
        if (count _roadPositions >= 1) then {
            private _numVeh = (1 + floor random 3) min count _roadPositions;
            for "_v" from 0 to (_numVeh - 1) do {
                private _roadPos = _roadPositions select (_v min (count _roadPositions - 1));
                if (count _roadPos < 3) then { _roadPos set [2, 0] };
                private _carClass = selectRandom _carClasses;
                private _veh = createVehicle [_carClass, _roadPos, [], 0, "NONE"];
                if (isNull _veh) then { continue };
                _veh setPosATL _roadPos;
                _veh setDir (random 360);
                private _vehGrp = createGroup _sideEnemy;
                private _driverCls = selectRandom _enemyUnits;
                private _driver = _vehGrp createUnit [_driverCls, _roadPos, [], 0, "NONE"];
                if (isNull _driver) then { deleteVehicle _veh; deleteGroup _vehGrp; continue };
                _driver assignAsDriver _veh;
                _driver moveInDriver _veh;
                private _cargoSeats = [_veh] call FADE_getCargoSeats;
                if (isNil "_cargoSeats") then { _cargoSeats = 0 };
                _cargoSeats = (_cargoSeats min 6) max 0;
                for "_c" from 0 to (_cargoSeats - 1) do {
                    private _cls = selectRandom _enemyUnits;
                    private _u = _vehGrp createUnit [_cls, _roadPos, [], 0, "NONE"];
                    if (!isNull _u) then { _u assignAsCargo _veh; _u moveInCargo _veh };
                };
                _vehGrp setBehaviour "SAFE";
                _vehGrp setSpeedMode "LIMITED";
                private _wpPosA = [_center, _zoneRadius * 0.6] call FADE_civ_findSpawnPos;
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
    };

    // 2-4 garrisoned buildings: 2-3 enemy units each, burning barrel outside
    private _buildings = nearestObjects [_center, ["House", "Building"], _zoneRadius];
    private _buildingsWithPos = _buildings select { count (_x buildingPos -1) >= 2 };
    _buildingsWithPos = _buildingsWithPos call BIS_fnc_arrayShuffle;
    private _numGarrison = (2 + floor random 3) min count _buildingsWithPos;
    for "_b" from 0 to (_numGarrison - 1) do {
        private _bld = _buildingsWithPos select _b;
        private _bldPos = _bld buildingPos -1;
        if (_bldPos isEqualTo []) then { continue };
        private _cnt = (2 + floor random 2) min count _bldPos;
        private _indices = [];
        for "_i" from 0 to (count _bldPos - 1) do { _indices pushBack _i };
        _indices = _indices call BIS_fnc_arrayShuffle;
        private _garrisonGrp = createGroup _sideEnemy;
        for "_i" from 0 to (_cnt - 1) do {
            private _p = _bldPos select (_indices select _i);
            if (count _p < 3) then { _p = [(_p select 0), (_p select 1), (if (count _p > 2) then { _p select 2 } else { 0 })] };
            private _cls = selectRandom _enemyUnits;
            private _u = _garrisonGrp createUnit [_cls, _p, [], 0, "NONE"];
            if (!isNull _u) then { _u setUnitPos "MIDDLE"; [_u, "STAND", "FULL", { behaviour _this == "COMBAT" || { !alive _this } }, "COMBAT"] call BIS_fnc_ambientAnimCombat };
        };
        if (count units _garrisonGrp > 0) then {
            _garrisonGroups pushBack _garrisonGrp;
            private _bldCenter = getPosATL _bld;
            if (count _bldCenter < 3) then { _bldCenter = [(_bldCenter select 0), (_bldCenter select 1), 0] };
            private _barrelPos = [_bldCenter, 8, 22, 2, 1, 0.3, 0, [], _bldCenter] call BIS_fnc_findSafePos;
            if (_barrelPos isEqualType [] && { count _barrelPos >= 2 }) then {
                _barrelPos = [(_barrelPos select 0), (_barrelPos select 1), (if (count _barrelPos > 2) then { _barrelPos select 2 } else { 0 })];
                private _barrel = createVehicle ["MetalBarrel_burning_F", _barrelPos, [], 0, "NONE"];
                _barrel setPosATL _barrelPos;
                _barrels pushBack _barrel;
            };
        } else {
            deleteGroup _garrisonGrp;
        };
    };

    if (count _patrolGroups > 0 || { count _vehicles > 0 } || { count _garrisonGroups > 0 }) then {
        private _state = createHashMap;
        _state set ["groups", _patrolGroups];
        _state set ["vehicleGroups", _vehicleGroups];
        _state set ["vehicles", _vehicles];
        _state set ["garrisonGroups", _garrisonGroups];
        _state set ["barrels", _barrels];
        FADE_enemyPatrolZoneState set [_zoneId, _state];
        [format ["PATROL ZONE %1: %2 group(s), %3 vehicle(s), %4 garrison(s)", _zoneId, count _patrolGroups, count _vehicles, count _garrisonGroups]] call FADE_civ_debugChat;
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
    private _roads = _center nearRoads _radius;
    private _positions = [];
    for "_i" from 0 to (count _roads - 1) do {
        private _pos = getPos (_roads select _i);
        if (count _pos >= 2) then { _pos set [2, 0]; _positions pushBack _pos };
        if (count _positions >= _maxPos) exitWith {};
    };
    _positions
};

FADE_civ_findSpawnPos = {
    params ["_center", "_radius"];
    for "_attempt" from 1 to 20 do {
        private _angle = random 360;
        private _dist = random _radius;
        private _pos = _center getPos [_dist, _angle];
        _pos set [2, 0];
        private _safe = [_pos, 0, 5, 2, 1, 0.3, 0, [], _pos] call BIS_fnc_findSafePos;
        if (_safe isEqualType [] && { count _safe >= 2 } && { (_safe distance _center) <= _radius }) exitWith { _safe };
    };
    _center
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

    private _found = [];
    for "_attempt" from 1 to 55 do {
        private _angle = random 360;
        private _dist = _ringMin + random ((_ringMax - _ringMin) max 1);
        private _rough = _zoneCenter getPos [_dist, _angle];
        _rough set [2, 0];
        private _roads = _rough nearRoads 280;
        if (_roads isEqualTo []) then { continue };
        private _road = selectRandom _roads;
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
        private _safe = [_p, 0, 12, 8, 1, 0.35, 0, [], _p] call BIS_fnc_findSafePos;
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

// -----------------------------------------------------------------------------
// Spawn one civilian (used by lazy-load)
// -----------------------------------------------------------------------------
FADE_civ_spawnOne = {
    params ["_civClasses", "_center", "_spawnRadius", "_wanderRadius", "_firedNearHandler"];
    private _cls = _civClasses select (floor random (count _civClasses max 1));
    private _spawnPos = [_center, _spawnRadius] call FADE_civ_findSpawnPos;
    if (count _spawnPos < 2) then { _spawnPos = _center };

    private _grp = createGroup civilian;
    private _unit = _grp createUnit [_cls, _spawnPos, [], 0, "NONE"];
    if (isNull _unit) then {
        deleteGroup _grp;
        objNull
    } else {
        _unit setVariable ["BIS_cp_excluded", true];
        _grp setVariable ["BIS_cp_excluded", true];
        _unit setVariable ["FADE_ambientCiv", true];
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

// -----------------------------------------------------------------------------
// Spawn zone - lazy-load civs in batches to reduce performance hit
// -----------------------------------------------------------------------------
FADE_civ_spawnZone = {
    params ["_trigger", "_zoneId"];
    if (!(missionNamespace getVariable ["FADE_civiliansEnabled", true])) exitWith {};
    if (!(isNil { FADE_civZoneState get _zoneId })) exitWith {};

    private _civClasses = call FADE_civ_getUnitClassesFromGui;
    private _faction = missionNamespace getVariable ["FADE_scenarioCivFaction", "CIV_F"];
    if (_civClasses isEqualTo []) exitWith {
        call FADE_civ_showNoCivsHint;
        [format ["SPAWN BLOCKED: No civ units available for faction %1", _faction]] call FADE_civ_debugChat;
    };

    private _center = getPosATL _trigger;
    private _spawnRadius = missionNamespace getVariable ["FADE_civSpawnRadius", 1000];
    private _civMin = missionNamespace getVariable ["FADE_civCountMin", 5];
    private _civMax = missionNamespace getVariable ["FADE_civCountMax", 15];
    private _wanderRadius = missionNamespace getVariable ["FADE_civWanderRadius", 100];
    private _staggerDelay = missionNamespace getVariable ["FADE_civSpawnStaggerDelay", 1.5];
    private _batchSize = missionNamespace getVariable ["FADE_civSpawnBatchSize", 2];

    private _targetCount = _civMin + floor random ((_civMax - _civMin + 1) max 1);
    private _firedNearHandler = {
        params ["_unit", "_firer", "_distance"];
        if (!alive _unit) exitWith {};
        _unit setBehaviour "CARELESS";
        _unit setSpeedMode "FULL";
        _unit doMove (_unit getPos [150 + random 100, random 360]);
    };

    private _state = createHashMap;
    _state set ["groups", []];
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

    [format ["ZONE %1 ACTIVE (lazy-load %2 civs) | faction: %3", _zoneId, _targetCount, _faction]] call FADE_civ_debugChat;

    // Spawn ambient enemy patrol if enabled (40% chance per zone)
    [_center, _zoneId] call FADE_enemyPatrol_spawnForZone;
    // MANPADS: 25% chance per zone, max 2, non-respawning (EnemyAAA.sqf)
    if (!isNil "FADE_aaa_maybeSpawnManpadsInZone") then { [_zoneId, _center] call FADE_aaa_maybeSpawnManpadsInZone };

    [ _zoneId, _targetCount, _civClasses, _center, _spawnRadius, _wanderRadius, _firedNearHandler, _staggerDelay, _batchSize ] spawn {
        params ["_zoneId", "_targetCount", "_civClasses", "_center", "_spawnRadius", "_wanderRadius", "_firedNearHandler", "_staggerDelay", "_batchSize"];
        private _spawned = 0;
        while { _spawned < _targetCount } do {
            private _state = FADE_civZoneState get _zoneId;
            if (isNil "_state" || { _state get "despawning" }) exitWith {};

            private _batch = (_targetCount - _spawned) min _batchSize;
            for "_b" from 0 to (_batch - 1) do {
                private _grp = [_civClasses, _center, _spawnRadius, _wanderRadius, _firedNearHandler] call FADE_civ_spawnOne;
                if (!isNull _grp) then {
                    (_state get "groups") pushBack _grp;
                };
                _spawned = _spawned + 1;
            };
            if (_spawned >= _targetCount) exitWith {};
            sleep _staggerDelay;
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
    FADE_civZoneState deleteAt _zoneId;
    [_zoneId] call FADE_enemyPatrol_despawnForZone;
    if (!isNil "FADE_aaa_despawnManpadsInZone") then { [_zoneId] call FADE_aaa_despawnManpadsInZone };
    if (missionNamespace getVariable ["FADE_civDebugMarkers", false]) then {
        deleteMarker ("FADE_civActive_" + _zoneId);
    };
    [format ["ZONE %1 DESPAWNED", _zoneId]] call FADE_civ_debugChat;
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
        _veh setPosATL _startPos;
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
    private _distMax = missionNamespace getVariable ["FADE_civVehCleanupDist", 4500];
    if (_distMax <= 0) exitWith {};
    private _players = [];
    { if (alive _x && { isPlayer _x }) then { _players pushBack _x } } forEach allPlayers;
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
};

// -----------------------------------------------------------------------------
// Main loop
// -----------------------------------------------------------------------------
FADE_civ_checkZones = {
    if (!(missionNamespace getVariable ["FADE_civiliansEnabled", true])) exitWith {};
    call FADE_civ_cleanupDistantVehicles;
    private _players = [];
    { if (alive _x && { isPlayer _x }) then { _players pushBack _x } } forEach allPlayers;
    if (_players isEqualTo []) exitWith {};

    private _activateDist = missionNamespace getVariable ["FADE_civPlayerActivateDist", 800];
    private _deactivateDist = missionNamespace getVariable ["FADE_civPlayerDeactivateDist", 1200];
    private _triggerNames = missionNamespace getVariable ["FADE_civTriggerNames", []];
    private _numPlayers = count _players;

    for "_t" from 0 to (count _triggerNames - 1) do {
        private _name = _triggerNames select _t;
        private _trigger = missionNamespace getVariable [_name, objNull];
        if (!isNull _trigger) then {
            private _center = getPosATL _trigger;
            private _nearCount = 0;
            private _farCount = 0;
            for "_p" from 0 to (_numPlayers - 1) do {
                private _pl = _players select _p;
                if ((_pl distance _center) < _activateDist) then { _nearCount = _nearCount + 1 };
                if ((_pl distance _center) > _deactivateDist) then { _farCount = _farCount + 1 };
            };
            if (_nearCount > 0) then {
                private _alreadyActive = !(isNil { FADE_civZoneState get _name });
                private _activeCount = count (keys FADE_civZoneState);
                if (_alreadyActive || { _activeCount < (missionNamespace getVariable ["FADE_civMaxActiveZones", 4]) }) then {
                    [_trigger, _name] call FADE_civ_spawnZone;
                };
            };
            if (_farCount == _numPlayers) then { [_name] call FADE_civ_despawnZone };
        };
    };

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
        sleep _interval;
        call FADE_civ_checkZones;
    };
};

private _zoneCount = count (missionNamespace getVariable ["FADE_civTriggerNames", []]);
private _civClasses = call FADE_civ_getUnitClassesFromGui;
private _civVehClasses = call FADE_civ_getVehicleClassesFromGui;
private _factionStart = missionNamespace getVariable ["FADE_scenarioCivFaction", "CIV_F"];
if (_zoneCount == 0) then {
    ["NO CIV_T_* TRIGGERS. PLACE CIV_T_* ZONES IN EDEN."] call FADE_civ_debugChat;
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
