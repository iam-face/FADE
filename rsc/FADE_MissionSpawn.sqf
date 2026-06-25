// =============================================================================
// FADE_MissionSpawn.sqf  -  shared mission spawn helpers (server, compile once)
// =============================================================================

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
    private _scale = missionNamespace getVariable ["FADE_scaleOpforCount", { params ["_b"]; _b }];
    private _n = [_count, 1] call _scale min _cap;
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

FADE_missionSpawnPatrol = {
    params [
        "_center",
        "_areaRadius",
        "_patrolCount",
        "_enemyClasses",
        "_sideEnemy",
        "_taskId",
        ["_baseEnemyClass", ""]
    ];
    private _groups = [];
    private _dryPos = missionNamespace getVariable ["FADE_surfaceIsDry", { true }];
    private _scale = missionNamespace getVariable ["FADE_scaleOpforCount", { params ["_b"]; _b }];
    private _baseClass = if (_baseEnemyClass != "") then { _baseEnemyClass } else { _enemyClasses select 0 };
    private _numPatrols = [_patrolCount, 1] call _scale;
    for "_g" from 0 to (_numPatrols - 1) do {
        private _sp = [];
        for "_tryPat" from 1 to 18 do {
            private _angle = random 360;
            private _dist = 40 + random ((_areaRadius - 50) max 1);
            private _rough = [(_center select 0) + _dist * (cos _angle), (_center select 1) + _dist * (sin _angle), 0];
            _sp = [[_rough, 0, 15, 3, 1, 0.4, 0, [], _rough], _rough] call FADE_findSafePosArray;
            if (_sp isEqualType [] && { count _sp >= 2 } && { [_sp] call _dryPos }) exitWith {};
            _sp = [];
        };
        if (_sp isEqualType [] && { count _sp >= 2 }) then {
            _sp = [(_sp select 0), (_sp select 1), (_sp param [2, 0])];
            private _size = [3 + floor random 3, 2] call _scale;
            private _grp = createGroup _sideEnemy;
            for "_k" from 0 to (_size - 1) do {
                private _cls = if (_k < count _enemyClasses) then { _enemyClasses select _k } else { _baseClass };
                private _u = _grp createUnit [_cls, _sp, [], 0, "NONE"];
                if (!isNull _u) then { _u setPosATL _sp };
            };
            if (count units _grp > 0) then {
                [_grp] call FAC_applyEnemyScenarioToGroup;
                _grp setBehaviour "SAFE";
                _grp setCombatMode "YELLOW";
                for "_w" from 0 to 2 do {
                    private _wpPos = [];
                    for "_tryWp" from 1 to 12 do {
                        private _a = _w * 120 + (random 40);
                        private _d = 50 + random ((_areaRadius - 50) max 1);
                        private _wR = [(_center select 0) + _d * (cos _a), (_center select 1) + _d * (sin _a), 0];
                        _wpPos = [[_wR, 0, 12, 3, 1, 0.4, 0, [], _wR], _wR] call FADE_findSafePosArray;
                        if (_wpPos isEqualType [] && { count _wpPos >= 2 } && { [_wpPos] call _dryPos }) exitWith {};
                        _wpPos = [];
                    };
                    if (count _wpPos >= 2) then {
                        private _wp = _grp addWaypoint [_wpPos, 0];
                        _wp setWaypointType "MOVE";
                        _wp setWaypointSpeed "LIMITED";
                        if (_w == 2) then { _wp setWaypointType "CYCLE" };
                    };
                };
                _groups pushBack _grp;
                if (_taskId != "") then { [_taskId, _grp] call FADE_missionEnt_registerGroup };
            } else {
                deleteGroup _grp;
            };
        };
    };
    _groups
};

missionNamespace setVariable ["FADE_vg_registerMissionSite", FADE_vg_registerMissionSite];
missionNamespace setVariable ["FADE_missionSpawnGuards", FADE_missionSpawnGuards];
missionNamespace setVariable ["FADE_missionSpawnPatrol", FADE_missionSpawnPatrol];
