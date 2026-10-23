// =============================================================================
// MissionRoadblocks.sqf — objective checkpoints (server)
// =============================================================================
// Not gated by FADE_scenarioPatrols. Ambient blocks in DynamicRoadblocks.sqf stay on that switch.
// Call FADE_missionRoadblocks_spawnAround once the objective position is known.
// Up to 4 barricades on a ring, 90 degrees apart. Spoke 0 faces base (the ground approach).
// A spoke with no road inside the snap radius is skipped. Two spokes on the same road keep one.
// Barricade + road party only. Buildings stay with the mission garrison.
// Despawn with the task via FADE_cleanupMissionEntities.
// Not used for Operation, Escape & Evasion, Intercept Convoy, Geo-Guesser, or Mine Clearing.
// =============================================================================

if (!isServer) exitWith {};

if (isNil "FADE_roadblock_spawnBundle") exitWith {
    diag_log "[FADE] MissionRoadblocks: RoadblockCommon not loaded.";
};

missionNamespace setVariable ["FADE_missionRoadblockState", missionNamespace getVariable ["FADE_missionRoadblockState", createHashMap]];

FADE_missionRoadblocks_despawnForTask = {
    params ["_taskId"];
    if (_taskId == "") exitWith {};
    private _st = missionNamespace getVariable ["FADE_missionRoadblockState", createHashMap];
    private _remove = [];
    {
        private _e = _st get _x;
        if (_e isEqualType [] && { count _e >= 3 } && { (_e select 2) == _taskId }) then {
            if (count _e >= 2) then { [_e select 1] call FADE_roadblock_despawnBundle };
            _remove pushBack _x;
        };
    } forEach (keys _st);
    { _st deleteAt _x } forEach _remove;
};

FADE_missionRoadblocks_despawnAll = {
    private _st = missionNamespace getVariable ["FADE_missionRoadblockState", createHashMap];
    {
        private _e = _st get _x;
        if (_e isEqualType [] && { count _e >= 2 }) then {
            [_e select 1] call FADE_roadblock_despawnBundle;
        };
    } forEach (keys _st);
    missionNamespace setVariable ["FADE_missionRoadblockState", createHashMap];
};

// Returns how many new blocks were placed. Repeat call for the same anchor does nothing.
FADE_missionRoadblocks_spawnAround = {
    params ["_taskId", "_center", ["_base", []]];
    if (!isServer) exitWith { 0 };
    if !(missionNamespace getVariable ["FADE_missionRoadblocksEnabled", true]) exitWith { 0 };
    if (_taskId == "") exitWith { 0 };
    if (isNil "FADE_roadblock_spawnBundle") exitWith { 0 };
    if (!(_center isEqualType []) || { count _center < 2 }) exitWith { 0 };
    if (isNil "FADE_normPos3") exitWith { 0 };

    _center = [_center] call FADE_normPos3;
    if (count _base < 2) then {
        _base = missionNamespace getVariable ["FADE_basePos", [0, 0, 0]];
    };
    if (_base isEqualType objNull) then { _base = getPosATL _base };
    _base = [_base] call FADE_normPos3;

    private _ring = missionNamespace getVariable ["FADE_missionRoadblockRingM", 220];
    private _snap = missionNamespace getVariable ["FADE_missionRoadblockRoadSnapM", 90];
    private _ringMin = missionNamespace getVariable ["FADE_missionRoadblockRingMinM", 80];
    private _ringMax = missionNamespace getVariable ["FADE_missionRoadblockRingMaxM", 350];
    private _dedupe = missionNamespace getVariable ["FADE_missionRoadblockDedupeM", 120];
    private _spokes = (round (missionNamespace getVariable ["FADE_missionRoadblockSpokes", 4])) max 1 min 4;
    private _maxTask = (round (missionNamespace getVariable ["FADE_missionRoadblockMaxPerTask", 12])) max 1;
    private _minBase = missionNamespace getVariable ["FADE_missionRoadblockMinDistFromBase", 400];

    private _st = missionNamespace getVariable ["FADE_missionRoadblockState", createHashMap];
    private _already = false;
    private _taskCount = 0;
    {
        private _e = _st get _x;
        if (_e isEqualType [] && { count _e >= 3 } && { (_e select 2) == _taskId }) then {
            _taskCount = _taskCount + 1;
            if (count _e >= 4 && { ((_e select 3) distance2D _center) < 40 }) then { _already = true };
        };
    } forEach (keys _st);
    if (_already) exitWith { 0 };
    if (_taskCount >= _maxTask) exitWith { 0 };

    // Direction from the objective toward base, so spoke 0 is the ground approach.
    private _bearing = if ((_center distance2D _base) > 5) then {
        [_center, _base] call BIS_fnc_dirTo
    } else {
        0
    };

    private _spawned = 0;
    private _i = 0;
    while { _i < _spokes && { _taskCount < _maxTask } } do {
        private _aim = _center getPos [_ring, _bearing + (_i * (360 / _spokes))];
        if (count _aim < 3) then { _aim = [(_aim select 0), (_aim select 1), 0] };
        private _roads = _aim nearRoads _snap;
        private _bestP = [];
        private _bestD = 1e9;
        {
            if (!isNull _x) then {
                private _rp = getPosATL _x;
                if (count _rp < 3) then { _rp = [(_rp select 0), (_rp select 1), 0] };
                private _dAim = _aim distance2D _rp;
                if (_dAim < _bestD) then {
                    _bestD = _dAim;
                    _bestP = _rp;
                };
            };
        } forEach _roads;

        if (count _bestP >= 2) then {
            private _fromObj = _bestP distance2D _center;
            private _fromBase = _bestP distance2D _base;
            private _bandOk = _fromObj >= _ringMin && { _fromObj <= _ringMax } && { _fromBase >= _minBase };
            private _dup = false;
            if (_bandOk) then {
                {
                    private _e = _st get _x;
                    if (_e isEqualType [] && { count _e >= 1 }) then {
                        private _c = _e select 0;
                        if (_c isEqualType [] && { (_c distance2D _bestP) < _dedupe }) exitWith { _dup = true };
                    };
                } forEach (keys _st);
            };
            if (_bandOk && { !_dup }) then {
                private _dir = [_bestP, _bearing] call FADE_roadblock_dirFromPos;
                private _bundle = [_bestP, _dir, false] call FADE_roadblock_spawnBundle;
                private _nid = missionNamespace getVariable ["FADE_missionRoadblockNextId", 0];
                private _id = format ["mrb_%1", _nid];
                missionNamespace setVariable ["FADE_missionRoadblockNextId", _nid + 1];
                _st set [_id, [_bestP, _bundle, _taskId, _center]];
                _bundle params [["_objs", []], ["_groups", []], ["_veh", objNull]];
                { if (!isNull _x && { !isNil "FADE_missionEnt_registerObject" }) then { [_taskId, _x] call FADE_missionEnt_registerObject } } forEach _objs;
                { if (!isNull _x && { !isNil "FADE_missionEnt_registerGroup" }) then { [_taskId, _x] call FADE_missionEnt_registerGroup } } forEach _groups;
                if (!isNull _veh && { !isNil "FADE_missionEnt_registerVehicle" }) then { [_taskId, _veh] call FADE_missionEnt_registerVehicle };
                _spawned = _spawned + 1;
                _taskCount = _taskCount + 1;
            };
        };
        _i = _i + 1;
    };

    if (missionNamespace getVariable ["FADE_checkpointDebug", false]) then {
        diag_log format ["[FADE] MissionRoadblock task=%1 spawned=%2 grid=%3", _taskId, _spawned, mapGridPosition _center];
    };
    _spawned
};

missionNamespace setVariable ["FADE_missionRoadblocks_spawnAround", FADE_missionRoadblocks_spawnAround];
missionNamespace setVariable ["FADE_missionRoadblocks_despawnForTask", FADE_missionRoadblocks_despawnForTask];
missionNamespace setVariable ["FADE_missionRoadblocks_despawnAll", FADE_missionRoadblocks_despawnAll];
