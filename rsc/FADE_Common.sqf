// =============================================================================
// FADE_Common.sqf  -  shared helpers (server boot; compiled from initServer)
// =============================================================================

FADE_normPos3 = {
    params ["_p"];
    if (!(_p isEqualType []) || { count _p < 2 }) exitWith { [0, 0, 0] };
    if (count _p < 3) then { [(_p select 0), (_p select 1), 0] } else { _p }
};

FADE_surfaceIsDry = {
    params ["_p"];
    if (!(_p isEqualType []) || { count _p < 2 }) exitWith { false };
    !surfaceIsWater [_p select 0, _p select 1]
};

FADE_findSafePosArray = {
    params ["_args", "_fallback"];
    private _r = _args call BIS_fnc_findSafePos;
    if (!(_r isEqualType [])) exitWith { [_fallback] call FADE_normPos3 };
    if (count _r < 2) exitWith { [_fallback] call FADE_normPos3 };
    [_r] call FADE_normPos3
};

FADE_jitterMarkerPos = {
    params [["_pos", [0, 0, 0]], ["_radiusM", 100]];
    private _p = [_pos] call FADE_normPos3;
    if (_radiusM <= 0) exitWith { +_p };
    private _j = [_p, random _radiusM, random 360] call BIS_fnc_relPos;
    [(_j select 0), (_j select 1), (_p select 2)]
};

FADE_missionErrorHint = {
    params ["_player", "_title", "_body"];
    if (isNull _player) exitWith {};
    [format [
        "<t size='1.2' color='#FF6666'>%1</t><br/><br/><t color='#E0E0E0'>%2</t>",
        _title,
        _body
    ]] remoteExec ["FADE_showMissionHint", _player];
};

FADE_missionSlotGateHint = {
    params ["_player", "_reason"];
    if (isNull _player) exitWith {};
    private _html = switch (_reason) do {
        case "active": {
            "<t size='1.2' color='#FFAA00'>MISSION ACTIVE</t><br/><br/><t color='#E0E0E0'>You already have an active mission. Abort it before starting another.</t>"
        };
        case "global": {
            "<t size='1.2' color='#FFAA00'>GLOBAL MISSION ACTIVE</t><br/><br/><t color='#E0E0E0'>Another global mission is in progress. Abort it or wait for completion.</t>"
        };
        case "slotsFull": {
            "<t size='1.2' color='#FFAA00'>SINGLE SLOTS FULL</t><br/><br/><t color='#E0E0E0'>All single-mission slots are in use. Abort a mission or wait.</t>"
        };
        default {
            "<t size='1.2' color='#FF6666'>MISSION ERROR</t><br/><br/><t color='#E0E0E0'>Cannot start mission.</t>"
        };
    };
    [_html] remoteExec ["FADE_showMissionHint", _player];
};

// Road heading at _pos; optional _dirToward picks the lane that faces that point.
FADE_opforGroundVehicleRoadDirAt = {
    params ["_pos", ["_dirToward", []]];
    private _posN = [_pos] call FADE_normPos3;
    private _roads = (_posN nearRoads 12) select { !isNull _x };
    if (_roads isEqualTo []) exitWith { 0 };
    private _r0 = _roads select 0;
    private _conn = roadsConnectedTo _r0;
    private _dir = if (count _conn > 0) then {
        [getPosATL _r0, getPosATL (_conn select 0)] call BIS_fnc_dirTo
    } else {
        getDir _r0
    };
    if (count _dirToward >= 2) then {
        private _faceDir = _posN getDir _dirToward;
        private _delta = ((_dir - _faceDir + 540) mod 360) - 180;
        if (abs _delta > 90) then { _dir = (_dir + 180) mod 360 };
    };
    _dir
};

// Nearest clear road slot for OPFOR ground vehicles. Returns [posATL, dirDeg] or [].
// Air/ship/static spawns must not use this helper.
FADE_findOpforGroundVehicleRoadSpawn = {
    params [
        "_anchor",
        ["_roadSearchM", 450],
        ["_existingVehs", []],
        ["_minDistFromRef", -1],
        ["_refPoint", []],
        ["_dirToward", []],
        ["_minVehGap", 12],
        ["_objClear", 8],
        ["_terrainClear", 10]
    ];
    private _dryFn = missionNamespace getVariable ["FADE_surfaceIsDry", { params ["_p"]; count _p >= 2 && { !surfaceIsWater [_p select 0, _p select 1] } }];
    private _anchorN = [_anchor] call FADE_normPos3;
    private _refN = if (count _refPoint >= 2) then { [_refPoint] call FADE_normPos3 } else { [] };

    private _roads = _anchorN nearRoads _roadSearchM;
    if (_roads isEqualTo []) exitWith { [] };
    _roads = [_roads, [], { (getPosATL _x) distance2D _anchorN }, "ASCEND"] call BIS_fnc_sortBy;

    private _maxRoadTries = (count _roads) min 32;
    private _best = [];
    private _bestDir = 0;

    scopeName "FADE_opforRoadSpawn";
    for "_ri" from 0 to (_maxRoadTries - 1) do {
        private _road = _roads select _ri;
        private _roadPos = getPosATL _road;
        if (count _roadPos < 3) then { _roadPos = [(_roadPos select 0), (_roadPos select 1), 0] };
        if !([_roadPos] call _dryFn) then { continue };
        if (_minDistFromRef >= 0 && { count _refN >= 2 } && { _roadPos distance2D _refN <= _minDistFromRef }) then { continue };

        private _nearVeh = nearestObjects [_roadPos, ["LandVehicle", "Air", "Ship"], _minVehGap + 5];
        private _blacklist = [];
        {
            if (!isNull _x && { alive _x }) then {
                private _p = getPosATL _x;
                _blacklist pushBack [(_p select 0), (_p select 1), _minVehGap];
            };
        } forEach _nearVeh;
        {
            if (!isNull _x && { alive _x }) then {
                private _p = getPosATL _x;
                _blacklist pushBack [(_p select 0), (_p select 1), _minVehGap];
            };
        } forEach _existingVehs;

        private _probe = [[_roadPos, 0, 6, _objClear, 0, 0.35, 0, _blacklist, _roadPos], _roadPos] call FADE_findSafePosArray;
        if (!(_probe isEqualType []) || { count _probe < 2 } || { !([_probe] call _dryFn) }) then { continue };
        if (count _probe < 3) then { _probe = [(_probe select 0), (_probe select 1), 0] };

        if !(isOnRoad _probe || { count (_probe nearRoads 10) > 0 }) then { continue };

        private _terr = nearestTerrainObjects [_probe, ["HOUSE", "BUILDING", "WALL", "FENCE", "ROCK", "BUSH", "TREE"], _terrainClear, false, true];
        if (count _terr > 0) then { continue };

        private _nearStatic = nearestObjects [_probe, ["House", "Building", "Wall", "Rock"], _terrainClear];
        if (count _nearStatic > 0) then { continue };

        private _tooClose = false;
        {
            if (!isNull _x && { alive _x } && { (_x distance2D _probe) < _minVehGap }) exitWith { _tooClose = true };
        } forEach _existingVehs;
        if (_tooClose) then { continue };

        private _block = nearestObjects [_probe, ["LandVehicle", "Air"], _minVehGap] select { alive _x };
        if (count _block > 0) then { continue };

        _best = _probe;
        _bestDir = [_probe, _dirToward] call FADE_opforGroundVehicleRoadDirAt;
        breakOut "FADE_opforRoadSpawn";
    };

    if (count _best < 2) exitWith { [] };
    [_best, _bestDir]
};

missionNamespace setVariable ["FADE_normPos3", FADE_normPos3];
missionNamespace setVariable ["FADE_surfaceIsDry", FADE_surfaceIsDry];
missionNamespace setVariable ["FADE_findSafePosArray", FADE_findSafePosArray];
missionNamespace setVariable ["FADE_jitterMarkerPos", FADE_jitterMarkerPos];
missionNamespace setVariable ["FADE_missionErrorHint", FADE_missionErrorHint];
missionNamespace setVariable ["FADE_missionSlotGateHint", FADE_missionSlotGateHint];
missionNamespace setVariable ["FADE_opforGroundVehicleRoadDirAt", FADE_opforGroundVehicleRoadDirAt];
missionNamespace setVariable ["FADE_findOpforGroundVehicleRoadSpawn", FADE_findOpforGroundVehicleRoadSpawn];
