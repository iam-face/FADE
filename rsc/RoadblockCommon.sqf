// =============================================================================
// RoadblockCommon.sqf -- Shared enemy roadblock spawn (server)
// =============================================================================
// Loaded from initServer via call compile before DynamicRoadblocks.sqf. Exposes:
//   FADE_roadblock_relToWorld, FADE_roadblock_dirFromPos,
//   FADE_roadblock_spawnBundle, FADE_roadblock_despawnBundle
// Props: one random barricade (Land_Barricade_01_10m_F, Land_Barricade_01_4m_F,
//   Fort_Barricade — invalid classes skipped). Infantry on the road + garrison in
//   enterable buildings within 25 m. No vehicles or other props.
// =============================================================================

if (!isServer) exitWith {};

FADE_roadblock_relToWorld = {
    params ["_center", "_dir", "_rel"];
    private _rx = _rel param [0, 0];
    private _ry = _rel param [1, 0];
    [
        (_center select 0) + (_rx * cos _dir) - (_ry * sin _dir),
        (_center select 1) + (_rx * sin _dir) + (_ry * cos _dir),
        0
    ]
};

// Road heading at a world position (for composition layout).
FADE_roadblock_dirFromPos = {
    params ["_center", "_fallbackDir"];
    if (!(_center isEqualType []) || { count _center < 2 }) exitWith { _fallbackDir };
    private _roads = _center nearRoads 40;
    if (_roads isEqualTo []) exitWith { _fallbackDir };
    private _r0 = _roads select 0;
    private _conn = roadsConnectedTo _r0;
    if (_conn isEqualTo []) exitWith { _fallbackDir };
    private _r1 = _conn select 0;
    [getPosATL _r0, getPosATL _r1] call BIS_fnc_dirTo
};

// One prop per roadblock; try in random order so missing mod/DLC classes are skipped.
FADE_roadblock_barricadeClasses = [
    "Land_Barricade_01_10m_F",
    "Land_Barricade_01_4m_F",
    "Fort_Barricade"
];

// Returns [objects, groups, vehicle, vgOwner] for state storage (_veh always objNull).
// vgOwner: cancel pending virtual garrison on despawn (may be "").
FADE_roadblock_spawnBundle = {
    params ["_center", "_dir"];
    private _scaleOpforCount = missionNamespace getVariable ["FADE_scaleOpforCount", {
        params ["_baseCount", ["_minCount", 1], ["_maxCount", -1]];
        private _base = floor (_baseCount max 0);
        if (_base <= 0) exitWith { 0 };
        private _scaled = _base max _minCount;
        if (_maxCount >= 0 && { _scaled > _maxCount }) then { _scaled = _maxCount };
        _scaled
    }];
    private _enemyUnits = missionNamespace getVariable ["FADE_enemyUnits", []];
    private _sideEnemy = missionNamespace getVariable ["FADE_sideEnemy", east];
    if (_enemyUnits isEqualTo []) then {
        _enemyUnits = +(missionNamespace getVariable ["FADE_fallbackEnemyUnits", ["O_Soldier_TL_F", "O_Soldier_F", "O_Soldier_AR_F"]]);
    };
    private _garrisonRadius = missionNamespace getVariable ["FADE_roadblockGarrisonRadiusM", 25];
    private _garrisonMax = missionNamespace getVariable ["FADE_roadblockGarrisonMax", 16];
    private _dryFn = missionNamespace getVariable ["FADE_surfaceIsDry", { params ["_p"]; count _p >= 2 && { !surfaceIsWater [_p select 0, _p select 1] } }];

    if (count _center < 3) then { _center = [(_center select 0), (_center select 1), 0] };

    private _spawnedObjs = [];
    private _groups = [];
    private _vehObj = objNull;

    private _barClasses = missionNamespace getVariable ["FADE_roadblock_barricadeClasses", FADE_roadblock_barricadeClasses];
    private _shuf = (+_barClasses) select { isClass (configFile >> "CfgVehicles" >> _x) };
    _shuf = _shuf call BIS_fnc_arrayShuffle;
    {
        private _tryBar = createVehicle [_x, _center, [], 0, "CAN_COLLIDE"];
        if (!isNull _tryBar) exitWith {
            _tryBar setPosATL _center;
            _tryBar setDir _dir;
            _spawnedObjs pushBack _tryBar;
        };
    } forEach _shuf;

    private _infCount = [3 + floor random 3, 1] call _scaleOpforCount;
    private _infClasses = [];
    for "_i" from 0 to (_infCount - 1) do { _infClasses pushBack (selectRandom _enemyUnits) };
    private _infGrp = [_center, _sideEnemy, _infClasses] call BIS_fnc_spawnGroup;
    [_infGrp] call (missionNamespace getVariable ["FAC_applyEnemyScenarioToGroup", {}]);
    _infGrp setBehaviour "COMBAT";
    _groups pushBack _infGrp;
    {
        if (alive _x) then {
            private _ang = random 360;
            private _rad = 4 + random 8;
            private _uPos = [(_center select 0) + (sin _ang) * _rad, (_center select 1) + (cos _ang) * _rad, 0];
            _x setPosATL _uPos;
            _x setDir ([_uPos, _center] call BIS_fnc_dirTo);
            _x setUnitPos "AUTO";
        };
    } forEach units _infGrp;

    // Ambush party: fill building positions on houses within radius (capped).
    private _houses = nearestObjects [_center, ["House", "Building"], _garrisonRadius];
    private _slots = [];
    {
        private _b = _x;
        if (isNull _b) then { } else {
            private _test0 = _b buildingPos 0;
            if (!(_test0 isEqualTo [0, 0, 0])) then {
                private _i = 0;
                while { true } do {
                    private _bp = _b buildingPos _i;
                    if (_bp isEqualTo [0, 0, 0]) exitWith {};
                    if ((_bp distance2D _center) <= _garrisonRadius && { [_bp] call _dryFn }) then {
                        _slots pushBack [_b, _bp];
                    };
                    _i = _i + 1;
                };
            };
        };
    } forEach _houses;

    private _vgOwner = "";
    if (count _slots > 0) then {
        _slots = _slots call BIS_fnc_arrayShuffle;
        private _nGar = (count _slots) min _garrisonMax;
        private _posATL = [];
        for "_k" from 0 to (_nGar - 1) do {
            (_slots select _k) params ["_b", "_bp"];
            private _p = +_bp;
            if (count _p < 3) then { _p set [2, 0] };
            _posATL pushBack _p;
        };
        private _vgFn = missionNamespace getVariable ["FADE_vg_register", {}];
        if (!(_vgFn isEqualTo {}) && { count _posATL > 0 }) then {
            private _seq = missionNamespace getVariable ["FADE_roadblockVgSeq", 0];
            missionNamespace setVariable ["FADE_roadblockVgSeq", _seq + 1];
            _vgOwner = format ["rb:%1", _seq];
            private _st = createHashMap;
            _st set ["owner", _vgOwner];
            _st set ["groupsRef", _groups];
            _st set ["anchorPos", _center];
            _st set ["facApply", true];
            _st set ["ambientCombat", false];
            _st set ["disablePath", true];
            _st set ["faceToward", _center];
            _st set ["behaviour", "COMBAT"];
            _st set ["combatMode", "RED"];
            [objNull, _posATL, [], _st] call _vgFn;
        } else {
            private _garGrp = createGroup _sideEnemy;
            for "_k" from 0 to (_nGar - 1) do {
                (_slots select _k) params ["_b", "_bp"];
                private _u = _garGrp createUnit [selectRandom _enemyUnits, _bp, [], 0, "NONE"];
                if (!isNull _u) then {
                    _u setPosATL _bp;
                    _u setDir ([_bp, _center] call BIS_fnc_dirTo);
                    _u disableAI "PATH";
                    _u setUnitPos "MIDDLE";
                };
            };
            [_garGrp] call (missionNamespace getVariable ["FAC_applyEnemyScenarioToGroup", {}]);
            _garGrp setBehaviour "COMBAT";
            _groups pushBack _garGrp;
        };
    };

    [_spawnedObjs, _groups, _vehObj, _vgOwner]
};

// _entry: [objects, groups, vehicle, optional vgOwner]
FADE_roadblock_despawnBundle = {
    params ["_entry"];
    if (isNil "_entry" || { !(_entry isEqualType []) } || { count _entry < 3 }) exitWith {};
    _entry params [["_objs", []], ["_groups", []], ["_veh", objNull], ["_vgOwner", ""]];
    if (_vgOwner != "") then {
        private _vgX = missionNamespace getVariable ["FADE_vg_cancelPendingByOwner", {}];
        if (!(_vgX isEqualTo {})) then { [_vgOwner] call _vgX };
    };
    { if (!isNull _x) then { deleteVehicle _x } } forEach _objs;
    if (!isNull _veh) then { deleteVehicle _veh };
    {
        if (!isNull _x) then {
            { if (!isNull _x) then { deleteVehicle _x } } forEach units _x;
            deleteGroup _x;
        };
    } forEach _groups;
};
