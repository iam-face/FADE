// =============================================================================
// EnemyCheckpoints.sqf -- Dynamic enemy checkpoints near players
// =============================================================================
// Loaded from initServer only when FADE_enemyCheckpointsEnabled is true (Config.sqf).
// Spawns at Eden objects named checkPointPos_*
// - Gated by Scenario setting: FADE_scenarioPatrols (Enemy Patrols ON/OFF)
// - Spawn radius: 2 km from any alive player
// - Despawn: when no alive player is within 2 km
// - Content: either a checkpoint composition OR an enemy vehicle, plus infantry
// - Debug: set FADE_checkpointDebug = true in Config.sqf - systemChat via remoteExec (all clients)
// =============================================================================

if (!isServer) exitWith {};

private _scaleOpforCount = missionNamespace getVariable ["FADE_scaleOpforCount", {
    params ["_baseCount", ["_minCount", 1], ["_maxCount", -1]];
    private _base = floor (_baseCount max 0);
    if (_base <= 0) exitWith { 0 };
    private _scaled = _base max _minCount;
    if (_maxCount >= 0 && { _scaled > _maxCount }) then { _scaled = _maxCount };
    _scaled
}];

private _chkLog = {
    params ["_msg"];
    if (missionNamespace getVariable ["FADE_checkpointDebug", false]) then {
        [format ["[Checkpoint] %1", _msg]] remoteExec ["systemChat", 0];
    };
};

private _radius = 2000;
private _poll = 12;
private _spawnChancePerCheck = 0.35;

private _state = createHashMap; // id -> [objects, groups, vehicle]

private _relToWorld = {
    params ["_center", "_dir", "_rel"];
    private _rx = _rel param [0, 0];
    private _ry = _rel param [1, 0];
    [
        (_center select 0) + (_rx * cos _dir) - (_ry * sin _dir),
        (_center select 1) + (_rx * sin _dir) + (_ry * cos _dir),
        0
    ]
};

private _checkpointCompositions = [
    // Light roadblock
    [
        ["Land_BagFence_Long_F", [0, -3, 0], 0],
        ["Land_BagFence_Long_F", [0, 3, 0], 180],
        ["Land_BagFence_Round_F", [3, -2, 0], 90],
        ["Land_BagFence_Round_F", [3, 2, 0], 90],
        ["Land_RoadBarrier_01_F", [-2, 0, 0], 90],
        ["Land_RoadBarrier_01_F", [2, 0, 0], 90]
    ],
    // Hesco choke
    [
        ["Land_HBarrier_3_F", [0, -4, 0], 0],
        ["Land_HBarrier_3_F", [0, 4, 0], 180],
        ["Land_HBarrier_5_F", [4, 0, 0], 90],
        ["Land_RoadBarrier_01_F", [-2, 0, 0], 90],
        ["Land_CzechHedgehog_01_new_F", [1.5, -1.5, 0], 45],
        ["Land_CzechHedgehog_01_new_F", [1.5, 1.5, 0], 45]
    ]
];

private _getRoadAlignedDir = {
    params ["_cpObj", "_fallbackDir"];
    private _center = getPosATL _cpObj;
    private _roads = _center nearRoads 40;
    if (_roads isEqualTo []) exitWith { _fallbackDir };
    private _r0 = _roads select 0;
    private _conn = roadsConnectedTo _r0;
    if (_conn isEqualTo []) exitWith { _fallbackDir };
    private _r1 = _conn select 0;
    [getPosATL _r0, getPosATL _r1] call BIS_fnc_dirTo
};

private _findCheckpointObjects = {
    private _pairs = [];
    {
        if (_x find "checkPointPos_" == 0) then {
            private _obj = missionNamespace getVariable [_x, objNull];
            if (!isNull _obj) then { _pairs pushBack [_x, _obj] };
        };
    } forEach allVariables missionNamespace;
    _pairs
};

private _despawnCheckpoint = {
    params ["_id", ["_reason", ""], ["_quiet", false]];
    private _entry = _state getOrDefault [_id, []];
    if (_entry isEqualTo []) exitWith {};
    _entry params [["_objs", []], ["_groups", []], ["_veh", objNull]];
    { if (!isNull _x) then { deleteVehicle _x } } forEach _objs;
    if (!isNull _veh) then { deleteVehicle _veh };
    {
        if (!isNull _x) then {
            { if (!isNull _x) then { deleteVehicle _x } } forEach units _x;
            deleteGroup _x;
        };
    } forEach _groups;
    _state deleteAt _id;
    if (!_quiet) then {
        private _r = if (_reason != "") then { format [" (%1)", _reason] } else { "" };
        [format ["Despawned %1%2.", _id, _r]] call _chkLog;
    };
};

private _spawnCheckpoint = {
    params ["_id", "_cpObj"];
    if (isNull _cpObj) exitWith {};

    private _enemyUnits = missionNamespace getVariable ["FADE_enemyUnits", []];
    private _sideEnemy = missionNamespace getVariable ["FADE_sideEnemy", east];
    if (_enemyUnits isEqualTo []) then {
        _enemyUnits = +(missionNamespace getVariable ["FADE_fallbackEnemyUnits", ["O_Soldier_TL_F", "O_Soldier_F", "O_Soldier_AR_F"]]);
    };
    private _enemyVeh = missionNamespace getVariable ["FADE_enemyVehicles", []];
    private _roadVeh = _enemyVeh select {
        !(_x isKindOf "Air") && { !(_x isKindOf "Ship") } && { !(_x isKindOf "StaticWeapon") }
    };

    private _center = getPosATL _cpObj;
    if (count _center < 3) then { _center = [(_center select 0), (_center select 1), 0] };
    private _dir = [_cpObj, getDir _cpObj] call _getRoadAlignedDir;

    private _spawnedObjs = [];
    private _groups = [];
    private _vehObj = objNull;

    private _spawnAsVehicle = (count _roadVeh > 0) && { random 1 < 0.5 };
    private _layoutDesc = "";
    if (_spawnAsVehicle) then {
        private _vClass = selectRandom _roadVeh;
        _layoutDesc = format ["vehicle %1", _vClass];
        private _vPos = [_center, 0, 18, 6, 1, 0.3, 0, [], _center] call BIS_fnc_findSafePos;
        if (count _vPos < 2) then { _vPos = _center };
        if (count _vPos < 3) then { _vPos = [(_vPos select 0), (_vPos select 1), 0] };
        _vehObj = createVehicle [_vClass, _vPos, [], 0, "NONE"];
        if (!isNull _vehObj) then {
            _vehObj setPosATL _vPos;
            _vehObj setDir _dir;
            private _vehGrp = createGroup _sideEnemy;
            private _driver = _vehGrp createUnit [selectRandom _enemyUnits, _vPos, [], 0, "NONE"];
            if (!isNull _driver) then { _driver moveInDriver _vehObj };
            if (_vehObj emptyPositions "gunner" > 0) then {
                private _g = _vehGrp createUnit [selectRandom _enemyUnits, _vPos, [], 0, "NONE"];
                if (!isNull _g) then { _g moveInGunner _vehObj };
            };
            [_vehGrp] call (missionNamespace getVariable ["FAC_applyEnemyScenarioToGroup", {}]);
            _groups pushBack _vehGrp;
        };
    } else {
        private _compIdx = floor random count _checkpointCompositions;
        private _comp = _checkpointCompositions select _compIdx;
        _layoutDesc = ["Light roadblock", "Hesco choke"] select _compIdx;
        {
            _x params ["_cls", "_rel", "_relDir"];
            private _wPos = [_center, _dir, _rel] call _relToWorld;
            private _obj = createVehicle [_cls, _wPos, [], 0, "CAN_COLLIDE"];
            if (!isNull _obj) then {
                _obj setPosATL _wPos;
                _obj setDir (_dir + _relDir);
                _spawnedObjs pushBack _obj;
            };
        } forEach _comp;
    };

    // Infantry manning checkpoint with ambient stand/watch animations.
    private _infCount = [3 + floor random 3, 1] call _scaleOpforCount;
    private _infClasses = [];
    for "_i" from 0 to (_infCount - 1) do { _infClasses pushBack (selectRandom _enemyUnits) };
    private _infGrp = [_center, _sideEnemy, _infClasses] call BIS_fnc_spawnGroup;
    [_infGrp] call (missionNamespace getVariable ["FAC_applyEnemyScenarioToGroup", {}]);
    _groups pushBack _infGrp;
    {
        if (alive _x) then {
            private _ang = random 360;
            private _rad = 4 + random 8;
            private _uPos = [(_center select 0) + (sin _ang) * _rad, (_center select 1) + (cos _ang) * _rad, 0];
            _x setPosATL _uPos;
            _x setDir (_dir + (-40 + random 80));
            _x disableAI "PATH";
            doStop _x;
            _x setUnitPos "UP";
            if (random 1 < 0.5) then {
                _x switchMove (selectRandom ["HubStanding_idle1", "HubStanding_idle2", "HubStanding_idle3"]);
            };
        };
    } forEach units _infGrp;

    _state set [_id, [_spawnedObjs, _groups, _vehObj]];
    [
        format [
            "Spawned %1 at %2 - %3, %4 infantry (grid %5).",
            _id,
            _center,
            _layoutDesc,
            _infCount,
            mapGridPosition _cpObj
        ]
    ] call _chkLog;
};

private _loggedStart = false;
while { true } do {
    private _dbg = missionNamespace getVariable ["FADE_checkpointDebug", false];
    if (_dbg && { !_loggedStart }) then {
        _loggedStart = true;
        [
            format [
                "Loop active - poll %1s, radius %2m, spawn roll %3%% per check (nearby & empty slot).",
                _poll,
                _radius,
                round (_spawnChancePerCheck * 100)
            ]
        ] call _chkLog;
    };

    private _enabled = missionNamespace getVariable ["FADE_scenarioPatrols", false];
    private _allCp = call _findCheckpointObjects;

    // Cleanup states for checkpoints that no longer exist in missionNamespace.
    private _validIds = _allCp apply { _x select 0 };
    {
        if !(_x in _validIds) then { [_x, "Eden object gone"] call _despawnCheckpoint };
    } forEach (keys _state);

    if (!_enabled) then {
        private _keys = keys _state;
        if (count _keys > 0) then {
            [format ["Patrols OFF - clearing %1 active checkpoint(s).", count _keys]] call _chkLog;
        };
        { [_x, "patrols OFF", true] call _despawnCheckpoint } forEach _keys;
    } else {
        {
            _x params ["_id", "_cpObj"];
            private _near = { alive _x && { (_x distance2D _cpObj) <= _radius } } count allPlayers > 0;
            private _exists = !((_state getOrDefault [_id, []]) isEqualTo []);
            if (_near) then {
                if (!_exists && { random 1 < _spawnChancePerCheck }) then {
                    [_id, _cpObj] call _spawnCheckpoint;
                };
            } else {
                if (_exists) then { [_id, "no player within 2km"] call _despawnCheckpoint };
            };
        } forEach _allCp;
    };

    sleep _poll;
};

