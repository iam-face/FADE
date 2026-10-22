// =============================================================================
// CompositionCommon.sqf -- rigid mission props (server)
// =============================================================================
// Loaded from FADE_missionModuleList before mission runners. Exposes:
//   FADE_comp_ids, FADE_comp_spawn, FADE_comp_siteOk, FADE_comp_findAnchor
// Offsets are [x, y, z] in metres at dir 0: +x east, +y north, z ATL.
// One yaw rotates the whole group. Pieces are not safe-pos searched.
// =============================================================================

if (!isServer) exitWith {};

FADE_comp_ids = ["camp", "mortarPit", "commsRelay"];

// [radius, pieces]. Piece: [classname, [x, y, z], dir]. Index 0 is the centre piece.
FADE_comp_defs = createHashMap;
FADE_comp_defs set ["camp", [
    12,
    [
        ["Campfire_burning_F", [0, 0, 0], 0],
        ["Land_CampingChair_V2_F", [2, 0, 0], 270],
        ["Land_CampingChair_V2_F", [-2, 0, 0], 90],
        ["Land_CampingChair_V2_F", [0, 2, 0], 180],
        ["Land_CampingChair_V2_F", [0.5, -2, 0], 0],
        ["Land_WoodPile_F", [2.7, 1.5, 0], 45],
        ["Land_TentDome_F", [-7.2, 1.2, 0], 90],
        ["Land_Sleeping_bag_brown_F", [-5.4, 1, 0], 90],
        ["Land_TentA_F", [5.8, 5.6, 0], 220],
        ["Land_Sleeping_bag_F", [4.2, 4, 0], 220],
        ["Land_TentA_F", [2.2, -7.6, 0], 0],
        ["Land_Sleeping_bag_blue_F", [2.2, -5.8, 0], 0],
        ["Land_CampingTable_small_F", [4, -1.2, 0], 80],
        ["Land_Ammobox_rounds_F", [4.6, -3.4, 0], 20],
        ["Land_WoodenBox_F", [5.6, -2.4, 0], 30],
        ["Land_MetalBarrel_F", [-3.8, -3.6, 0], 0],
        ["Land_BarrelWater_F", [-4.6, -2.5, 0], 40]
    ]
]];
FADE_comp_defs set ["mortarPit", [
    12,
    [
        ["Land_BagFence_Long_F", [3.21, 2.7, 0], 50],
        ["Land_BagFence_Long_F", [3.44, -2.41, 0], 125],
        ["Land_BagFence_Long_F", [-1.44, -3.95, 0], 200],
        ["Land_BagFence_Long_F", [-4.18, 0.37, 0], 275],
        ["Land_BagFence_Long_F", [-1.44, 3.95, 0], 340],
        ["Land_Ammobox_rounds_F", [-1.1, -1.2, 0], 15],
        ["Land_WoodenBox_F", [1.2, -0.6, 0], 40],
        ["Land_TentA_F", [0, 9, 0], 180]
    ]
]];
FADE_comp_defs set ["commsRelay", [
    10,
    [
        ["Land_Communication_F", [0, 0, 0], 0],
        ["Land_Portable_generator_F", [2.4, 1.6, 0], 200],
        ["Land_CampingTable_F", [-2.2, 1.8, 0], 110],
        ["Land_CampingChair_V2_F", [-2.2, 0.2, 0], 0],
        ["Land_PortableLongRangeRadio_F", [-1, 1.8, 0], 20],
        ["Land_Map_unfolded_F", [-3.2, 1.6, 0], 15],
        ["Land_MetalBarrel_F", [3.2, -1.5, 0], 0],
        ["Land_WoodenBox_F", [2.2, -2.6, 0], 25],
        ["Land_TentDome_F", [-5.5, -2.5, 0], 65]
    ]
]];

// Rotate a local offset by _dir (degrees clockwise, 0 = north). Matches setDir.
FADE_comp_relToWorld = {
    params ["_center", "_dir", "_rel"];
    private _rx = _rel param [0, 0];
    private _ry = _rel param [1, 0];
    private _rz = _rel param [2, 0];
    [
        (_center select 0) + (_rx * (cos _dir)) + (_ry * (sin _dir)),
        (_center select 1) + (_ry * (cos _dir)) - (_rx * (sin _dir)),
        _rz
    ]
};

// True when a disc of _radius metres is dry, nearly level, and clear of walls and trees.
FADE_comp_siteOk = {
    params ["_center", "_radius"];
    if (!(_center isEqualType []) || { count _center < 2 }) exitWith { false };
    private _c = [(_center select 0), (_center select 1), 0];
    private _r = _radius max 1;
    private _edge = _r * 0.75;
    private _pts = [_c];
    private _ang = 0;
    for "_i" from 0 to 3 do {
        _ang = _i * 90;
        _pts pushBack [(_c select 0) + (_edge * (cos _ang)), (_c select 1) + (_edge * (sin _ang)), 0];
    };
    private _ok = true;
    private _p = [0, 0, 0];
    private _sn = [0, 0, 1];
    {
        _p = _x;
        if !([_p] call FADE_surfaceIsDry) exitWith { _ok = false };
        // surfaceNormal ignores Z. Below 0.92 is steeper than about 23 degrees.
        _sn = surfaceNormal _p;
        if ((_sn select 2) < 0.92) exitWith { _ok = false };
    } forEach _pts;
    if (!_ok) exitWith { false };
    private _terr = nearestTerrainObjects [_c, ["HOUSE", "BUILDING", "WALL", "FENCE", "ROCK", "TREE"], _r, false, true];
    if (count _terr > 0) exitWith { false };
    private _near = nearestObjects [_c, ["House", "Building", "Wall", "Rock"], _r];
    if (count _near > 0) exitWith { false };
    // mode must stay -1. minDistance 4 avoids the bounding-sphere false rejects of a full-radius check.
    private _flat = _c isFlatEmpty [4, -1, 0.25, _r, 0, false];
    _flat isEqualType [] && { count _flat > 0 }
};

// _center when it passes, otherwise a point on a 12/20 m ring, otherwise [].
FADE_comp_findAnchor = {
    params ["_center", "_radius"];
    private _c = [_center] call FADE_normPos3;
    if ([_c, _radius] call FADE_comp_siteOk) exitWith { _c };
    private _found = [];
    private _dist = 0;
    private _ang = 0;
    private _try = [0, 0, 0];
    for "_i" from 0 to 7 do {
        if (count _found < 2) then {
            _dist = 12 + ((_i mod 2) * 8);
            _ang = _i * 45;
            _try = [(_c select 0) + (_dist * (cos _ang)), (_c select 1) + (_dist * (sin _ang)), 0];
            if ([_try, _radius] call FADE_comp_siteOk) then { _found = _try };
        };
    };
    _found
};

// How many pieces of _id exist in CfgVehicles.
FADE_comp_pieceCount = {
    params ["_id"];
    private _def = FADE_comp_defs getOrDefault [_id, []];
    if (count _def < 2) exitWith { 0 };
    private _n = 0;
    {
        if (isClass (configFile >> "CfgVehicles" >> (_x select 0))) then { _n = _n + 1 };
    } forEach (_def select 1);
    _n
};

// Spawn one composition. Returns the objects. Empty when the id is unknown or no site fits.
// Each object stores FADE_comp_anchor (the site centre) and FADE_comp_id.
FADE_comp_spawn = {
    params ["_id", "_center", ["_taskId", ""], ["_dir", -1]];
    private _def = FADE_comp_defs getOrDefault [_id, []];
    if (count _def < 2) exitWith { [] };
    private _radius = _def select 0;
    private _pieces = _def select 1;
    private _anchor = [_center, _radius] call FADE_comp_findAnchor;
    if (count _anchor < 2) exitWith { [] };
    if (_dir < 0) then { _dir = random 360 };
    private _objs = [];
    private _pos = [0, 0, 0];
    private _obj = objNull;
    private _sn = [0, 0, 1];
    {
        _x params ["_cls", "_off", "_dirObj"];
        if (isClass (configFile >> "CfgVehicles" >> _cls)) then {
            _pos = [_anchor, _dir, _off] call FADE_comp_relToWorld;
            // CAN_COLLIDE keeps the piece on this position. NONE would search and break the group.
            _obj = createVehicle [_cls, _pos, [], 0, "CAN_COLLIDE"];
            if (!isNull _obj) then {
                _obj setPosATL _pos;
                _obj setDir (_dir + _dirObj);
                _sn = surfaceNormal (getPosASL _obj);
                if ((_sn select 2) != 0) then { _obj setVectorUp _sn };
                _obj allowDamage false;
                _obj setVariable ["FADE_comp_anchor", _anchor];
                _obj setVariable ["FADE_comp_id", _id];
                _objs pushBack _obj;
                if (_taskId != "") then { [_taskId, _obj] call FADE_missionEnt_registerObject };
            };
        };
    } forEach _pieces;
    _objs
};

missionNamespace setVariable ["FADE_comp_ids", FADE_comp_ids];
missionNamespace setVariable ["FADE_comp_spawn", FADE_comp_spawn];
missionNamespace setVariable ["FADE_comp_siteOk", FADE_comp_siteOk];
missionNamespace setVariable ["FADE_comp_findAnchor", FADE_comp_findAnchor];
missionNamespace setVariable ["FADE_comp_pieceCount", FADE_comp_pieceCount];
