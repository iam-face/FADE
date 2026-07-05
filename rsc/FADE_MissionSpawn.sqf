// =============================================================================
// FADE_MissionSpawn.sqf  -  shared mission spawn helpers (server, compile once)
// =============================================================================

FADE_spawnEnemyGroupAt = {
    params ["_pos", "_side", "_classes", ["_anchor", []]];
    private _ensureDry = missionNamespace getVariable ["FADE_ensureDryLandPos", {}];
    private _spawnPos = if (_ensureDry isEqualTo {}) then { [_pos] call FADE_normPos3 } else { [_pos, _anchor] call _ensureDry };
    [_spawnPos, _side, _classes] call BIS_fnc_spawnGroup
};

FADE_createEnemyUnitAt = {
    params ["_group", "_class", "_pos", ["_anchor", []]];
    private _ensureDry = missionNamespace getVariable ["FADE_ensureDryLandPos", {}];
    private _spawnPos = if (_ensureDry isEqualTo {}) then { [_pos] call FADE_normPos3 } else { [_pos, _anchor] call _ensureDry };
    private _u = _group createUnit [_class, _spawnPos, [], 0, "NONE"];
    if (!isNull _u) then { _u setPosATL _spawnPos };
    _u
};

FADE_vg_registerMissionSite = {
    params [
        "_center",
        ["_tryBarrel", true],
        ["_groupsRef", []],
        ["_barrelClasses", ["Land_BarrelSand_F", "Land_MetalBarrel_F"]]
    ];
    if (!isNil "FADE_vg_register") then {
        [
            _center,
            _tryBarrel,
            random 1 < 0.5,
            _barrelClasses,
            _center,
            _groupsRef
        ] call FADE_vg_register;
    };
};

// createGroup + createUnit at one ATL (patrol groups; avoids BIS_fnc_spawnGroup stale-waypoint issues).
FADE_missionCreateInfantryGroupAt = {
    params ["_pos", "_side", "_classes"];
    private _spawnPos = [_pos] call FADE_normPos3;
    private _grp = createGroup _side;
    {
        private _u = _grp createUnit [_x, _spawnPos, [], 0, "NONE"];
        if (!isNull _u) then { _u setPosATL _spawnPos };
    } forEach _classes;
    if (count units _grp == 0) then {
        deleteGroup _grp;
        grpNull
    } else {
        _grp
    };
};

// Cyclic patrol route around _center. Clears existing waypoints, sets group orders, adds MOVE + CYCLE.
FADE_missionApplyPatrolCycle = {
    params [
        "_grp",
        "_center",
        ["_minDist", 50],
        ["_maxDist", 180],
        ["_numWp", 4],
        ["_angleOffset", 0],
        ["_angleStep", 90],
        ["_behaviour", "SAFE"],
        ["_combatMode", "YELLOW"],
        ["_speedMode", "LIMITED"],
        ["_requireDry", true]
    ];
    if (isNull _grp || { ({ alive _x } count units _grp) == 0 }) exitWith { false };
    if (count _center < 2) exitWith { false };
    private _cx = _center select 0;
    private _cy = _center select 1;
    private _dryFn = missionNamespace getVariable ["FADE_surfaceIsDry", { true }];
    {
        if (alive _x) then {
            _x switchMove "";
            _x setUnitPos "AUTO";
        };
    } forEach units _grp;
    while { count waypoints _grp > 0 } do { deleteWaypoint [_grp, 0] };
    _grp setBehaviour _behaviour;
    _grp setCombatMode _combatMode;
    _grp setSpeedMode _speedMode;
    private _added = 0;
    for "_w" from 0 to (_numWp - 1) do {
        private _wpPos = [];
        private _fallback = [];
        for "_try" from 1 to 14 do {
            private _a = _angleOffset + _w * _angleStep + (random 40);
            private _d = _minDist + random ((_maxDist - _minDist) max 1);
            private _rough = [_cx + _d * (cos _a), _cy + _d * (sin _a), 0];
            _fallback = +_rough;
            _wpPos = [[_rough, 0, 12, 3, 1, 0.4, 0, [], _rough], _rough] call FADE_findSafePosArray;
            if (_wpPos isEqualType [] && { count _wpPos >= 2 }) then {
                if (!_requireDry || { [_wpPos] call _dryFn }) exitWith {};
            };
            _wpPos = [];
        };
        if (count _wpPos < 2) then { _wpPos = _fallback };
        if (count _wpPos >= 2) then {
            if (count _wpPos < 3) then { _wpPos = [(_wpPos select 0), (_wpPos select 1), 0] };
            private _wp = _grp addWaypoint [_wpPos, 20];
            _wp setWaypointType "MOVE";
            _wp setWaypointSpeed _speedMode;
            _wp setWaypointBehaviour _behaviour;
            _wp setWaypointCombatMode _combatMode;
            _added = _added + 1;
        };
    };
    if (_added > 0) then {
        private _cyc = _grp addWaypoint [waypointPosition [_grp, 0], 20];
        _cyc setWaypointType "CYCLE";
        true
    } else {
        false
    };
};

FADE_missionSpawnGuards = {
    params [
        "_center",
        "_count",
        "_enemyClasses",
        "_sideEnemy",
        "_taskId",
        ["_minDist", 12],
        ["_maxDist", 100],
        ["_cap", 20]
    ];
    private _spawned = 0;
    private _groups = [];
    private _dryPos = missionNamespace getVariable ["FADE_surfaceIsDry", { true }];
    private _scaleFn = missionNamespace getVariable ["FADE_scaleOpforCount", nil];
    private _scaledCount = _count;
    if (_scaleFn isEqualType {}) then {
        private _scaled = [_count, 1] call _scaleFn;
        if (_scaled isEqualType 0) then { _scaledCount = _scaled };
    };
    private _n = (_scaledCount min _cap) max 0;
    for "_g" from 0 to (_n - 1) do {
        if (_spawned >= _cap) exitWith {};
        private _guardPos = [];
        for "_tryG" from 1 to 16 do {
            _guardPos = [[_center, _minDist, _maxDist, 3, 1, 0.3, 0, [], _center], _center] call FADE_findSafePosArray;
            if (_guardPos isEqualType [] && { count _guardPos >= 2 } && { [_guardPos] call _dryPos }) exitWith {};
            _guardPos = [];
        };
        if (_guardPos isEqualType [] && { count _guardPos >= 2 }) then {
            if (count _guardPos < 3) then { _guardPos = [(_guardPos select 0), (_guardPos select 1), 0] };
            private _guardGrp = createGroup _sideEnemy;
            private _u = _guardGrp createUnit [selectRandom _enemyClasses, _guardPos, [], 0, "NONE"];
            if (!isNull _u) then {
                [_guardGrp] call FAC_applyEnemyScenarioToGroup;
                _u setPosATL _guardPos;
                _u setUnitPos "MIDDLE";
                [_u, "STAND", "FULL", { behaviour _this == "COMBAT" || { !alive _this } }, "COMBAT"] call BIS_fnc_ambientAnimCombat;
                _groups pushBack _guardGrp;
                if (_taskId != "") then { [_taskId, _guardGrp] call FADE_missionEnt_registerGroup };
                _spawned = _spawned + 1;
            } else {
                deleteGroup _guardGrp;
            };
        };
    };
    _groups
};

// Optional field contact: enemy groups in a ring around pickup (CASEVAC, Troop Extract, etc.).
FADE_mission_spawnFieldContactEnemies = {
    params [
        "_atPos",
        "_basePos",
        "_enemyUnits",
        "_sideEnemy",
        "_taskId",
        "_scaleOpforCount",
        ["_contactChance", 0.5],
        ["_groupsBase", 1],
        ["_groupsRand", 5],
        ["_grpSizeMin", 3],
        ["_grpSizeRand", 5],
        ["_minDistFromBase", 1000],
        ["_registerEach", false],
        ["_useScenarioSpawn", false]
    ];
    private _groups = [];
    if (count _enemyUnits == 0) exitWith { _groups };
    if (random 1 >= _contactChance) exitWith { _groups };

    private _spawnEnemyGrp = missionNamespace getVariable ["FADE_spawnEnemyGroupAt", BIS_fnc_spawnGroup];
    private _ensureDry = missionNamespace getVariable ["FADE_ensureDryLandPos", {}];
    private _numEnemyGroups = [_groupsBase + floor random _groupsRand, 1] call _scaleOpforCount;

    for "_g" from 0 to (_numEnemyGroups - 1) do {
        private _grpPos = [];
        for "_try" from 0 to 10 do {
            private _dist = 500 + random 1500;
            private _candidate = _atPos getPos [_dist, random 360];
            _candidate = [[_candidate, 0, 30, 3, 1, 0.4, 0, [], _candidate], _candidate] call FADE_findSafePosArray;
            if (count _candidate < 2) then { _candidate = _atPos getPos [_dist, random 360] };
            if ((_candidate distance _basePos) >= _minDistFromBase) exitWith { _grpPos = _candidate };
        };
        if (count _grpPos < 2) then {
            _grpPos = _atPos getPos [800, (_atPos getDir _basePos) + 180];
        };
        if (!(_ensureDry isEqualTo {})) then { _grpPos = [_grpPos, _atPos] call _ensureDry };

        private _grpSize = [_grpSizeMin + floor random _grpSizeRand, 2] call _scaleOpforCount;
        private _shuffled = _enemyUnits call BIS_fnc_arrayShuffle;
        private _grpUnits = (_shuffled select [0, _grpSize min count _shuffled]);
        if (count _grpUnits == 0) then { _grpUnits = [_enemyUnits select 0] };

        private _grp = if (_useScenarioSpawn) then {
            [_grpPos, _sideEnemy, _grpUnits, _atPos] call _spawnEnemyGrp
        } else {
            [_grpPos, _sideEnemy, _grpUnits] call BIS_fnc_spawnGroup
        };
        [_grp] call FAC_applyEnemyScenarioToGroup;
        _grp setBehaviour "AWARE";
        _grp setCombatMode "RED";
        _grp addWaypoint [_atPos, 0];
        if (_registerEach && { _taskId != "" }) then {
            [_taskId, _grp] call FADE_missionEnt_registerGroup;
        };
        _groups pushBack _grp;
    };

    if (count _groups > 0) then {
        [_groups, _basePos] call FADE_registerEnemyRetreat;
    };
    _groups
};

// Thick ring: solid outer ellipse + inner border (same centre). Outer name = _markerName + "_outer".
FADE_mission_radiusBorderThick = {
    missionNamespace getVariable ["FADE_missionRadiusBorderThick", 40]
};

FADE_mission_setRadiusMarkerColor = {
    params ["_markerName", "_color"];
    if (_markerName == "") exitWith {};
    if (markerShape _markerName != "") then { _markerName setMarkerColor _color };
    private _outerName = _markerName + "_outer";
    if (markerShape _outerName != "") then { _outerName setMarkerColor _color };
};

FADE_mission_setRadiusMarkerGeometry = {
    params ["_markerName", "_center", "_radiusM"];
    if (_markerName == "" || { _radiusM <= 0 }) exitWith {};
    private _centerN = [_center] call FADE_normPos3;
    private _borderThick = [] call FADE_mission_radiusBorderThick;
    private _outerName = _markerName + "_outer";
    if (markerShape _markerName != "") then {
        _markerName setMarkerPos _centerN;
        _markerName setMarkerSize [_radiusM, _radiusM];
    };
    if (markerShape _outerName != "") then {
        _outerName setMarkerPos _centerN;
        _outerName setMarkerSize [_radiusM + _borderThick, _radiusM + _borderThick];
    };
};

// Border ellipse for mission search / completion radii (exact center; register for cleanup).
FADE_mission_createRadiusMarker = {
    params [
        "_taskId",
        "_markerName",
        "_center",
        "_radiusM",
        ["_markerColor", "ColorEAST"],
        ["_alpha", 0.45]
    ];
    if (_markerName == "" || { _radiusM <= 0 }) exitWith { "" };
    private _centerN = [_center] call FADE_normPos3;
    private _borderThick = [] call FADE_mission_radiusBorderThick;
    private _outerName = _markerName + "_outer";
    private _outerMarker = createMarker [_outerName, _centerN];
    if (_taskId != "") then { [_taskId, _outerName] call FADE_missionEnt_registerMarker };
    _outerMarker setMarkerShape "ELLIPSE";
    _outerMarker setMarkerSize [_radiusM + _borderThick, _radiusM + _borderThick];
    _outerMarker setMarkerBrush "Solid";
    _outerMarker setMarkerColor _markerColor;
    _outerMarker setMarkerAlpha _alpha;

    private _zoneMarker = createMarker [_markerName, _centerN];
    if (_taskId != "") then { [_taskId, _markerName] call FADE_missionEnt_registerMarker };
    _zoneMarker setMarkerShape "ELLIPSE";
    _zoneMarker setMarkerSize [_radiusM, _radiusM];
    _zoneMarker setMarkerBrush "Border";
    _zoneMarker setMarkerColor _markerColor;
    _zoneMarker setMarkerAlpha _alpha;
    _markerName
};

// Zone ellipse + centred objective icon (register both for cleanup). Returns [_iconMarker, _zoneMarker].
FADE_mission_createObjectiveMarker = {
    params [
        "_taskId",
        "_markerBaseName",
        "_center",
        ["_zoneRadius", 0],
        ["_markerColor", "ColorEAST"],
        ["_markerType", "mil_objective"],
        ["_markerText", ""],
        ["_jitterRadius", 0],
        ["_zoneAlpha", 0.45]
    ];
    private _centerN = [_center] call FADE_normPos3;
    private _zoneName = "";
    if (_zoneRadius > 0) then {
        _zoneName = _markerBaseName + "_zone";
        [_taskId, _zoneName, _centerN, _zoneRadius, _markerColor, _zoneAlpha] call FADE_mission_createRadiusMarker;
    };
    private _mkrJitter = missionNamespace getVariable ["FADE_jitterMarkerPos", { params [["_p", [0, 0, 0]]]; [_p] call FADE_normPos3 }];
    private _iconPos = if (_jitterRadius > 0) then { [_centerN, _jitterRadius] call _mkrJitter } else { +_centerN };
    private _icon = createMarker [_markerBaseName, _iconPos];
    [_taskId, _markerBaseName] call FADE_missionEnt_registerMarker;
    _icon setMarkerType _markerType;
    _icon setMarkerColor _markerColor;
    if (_markerText != "") then { _icon setMarkerText _markerText };
    [_markerBaseName, _zoneName]
};

// Cargo camp delayed despawn (success / fail / timeout paths).
FADE_cargo_cleanupSiteDeferred = {
    params [["_campObjects", []], ["_garrisonGroup", grpNull], ["_cargo", objNull], ["_patrolGroups", []], ["_delay", 60]];
    [_campObjects, _garrisonGroup, _cargo, _patrolGroups, _delay] spawn {
        params ["_campObjects", "_garrisonGroup", "_cargo", "_pgGrps", "_delay"];
        sleep _delay;
        { if (!isNull _x) then { deleteVehicle _x } } forEach _campObjects;
        if (!isNull _garrisonGroup) then {
            { if (!isNull _x) then { deleteVehicle _x } } forEach units _garrisonGroup;
            deleteGroup _garrisonGroup;
        };
        if (!isNull _cargo) then { deleteVehicle _cargo };
        {
            if (!isNull _x) then {
                { if (!isNull _x) then { deleteVehicle _x } } forEach units _x;
                deleteGroup _x;
            };
        } forEach _pgGrps;
    };
};

missionNamespace setVariable ["FADE_vg_registerMissionSite", FADE_vg_registerMissionSite];
missionNamespace setVariable ["FADE_spawnEnemyGroupAt", FADE_spawnEnemyGroupAt];
missionNamespace setVariable ["FADE_createEnemyUnitAt", FADE_createEnemyUnitAt];
missionNamespace setVariable ["FADE_missionCreateInfantryGroupAt", FADE_missionCreateInfantryGroupAt];
missionNamespace setVariable ["FADE_missionApplyPatrolCycle", FADE_missionApplyPatrolCycle];
missionNamespace setVariable ["FADE_missionSpawnGuards", FADE_missionSpawnGuards];
missionNamespace setVariable ["FADE_mission_spawnFieldContactEnemies", FADE_mission_spawnFieldContactEnemies];
missionNamespace setVariable ["FADE_mission_radiusBorderThick", FADE_mission_radiusBorderThick];
missionNamespace setVariable ["FADE_mission_setRadiusMarkerColor", FADE_mission_setRadiusMarkerColor];
missionNamespace setVariable ["FADE_mission_setRadiusMarkerGeometry", FADE_mission_setRadiusMarkerGeometry];
missionNamespace setVariable ["FADE_mission_createRadiusMarker", FADE_mission_createRadiusMarker];
missionNamespace setVariable ["FADE_mission_createObjectiveMarker", FADE_mission_createObjectiveMarker];
missionNamespace setVariable ["FADE_cargo_cleanupSiteDeferred", FADE_cargo_cleanupSiteDeferred];
