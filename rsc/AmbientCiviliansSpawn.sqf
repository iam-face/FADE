// AmbientCiviliansSpawn.sqf - civ spawn/despawn helpers
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
        [_mrkId, _center, ""] call FADE_createRegisteredMarker;
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
    if (!isNil "_state") then {
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
    };
    // Always run: virtual garrison / patrol OPFOR can outlive civ foot state (or civ state may already be gone).
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

