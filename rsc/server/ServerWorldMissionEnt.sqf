// ServerWorldMissionEnt.sqf - marker delete, retreat, mission entity registry
// -----------------------------------------------------------------------------
// Reusable: delete marker only if it exists (avoids "marker not found" in RPT).
// Markers are global; must be deleted on the same machine that created them (server).
// -----------------------------------------------------------------------------
FADE_deleteMarkerSafe = {
    params ["_markerName"];
    if (_markerName != "" && { getMarkerColor _markerName != "" }) then { deleteMarker _markerName };
    private _legacyOuter = _markerName + "_outer";
    if (_legacyOuter != "" && { getMarkerColor _legacyOuter != "" }) then { deleteMarker _legacyOuter };
};

// Create marker at _pos and optionally register for mission-entity cleanup.
FADE_createRegisteredMarker = {
    params ["_name", "_pos", ["_taskId", ""]];
    private _p = if (_pos isEqualType []) then { [_pos] call FADE_normPos3 } else { [0, 0, 0] };
    createMarker [_name, _p];
    if (_taskId != "") then { [_taskId, _name] call FADE_missionEnt_registerMarker };
    _name
};
missionNamespace setVariable ["FADE_createRegisteredMarker", FADE_createRegisteredMarker];

// Enemy retreat: when 50% of mission enemies are dead, each remaining unit gets a skill-based chance to retreat (move 2 km away from base). Skill 0 = 100% retreat, skill 1 = 0%, linear in between. Call FADE_registerEnemyRetreat once per mission with enemy groups. Runs on server only (initServer / Missions.sqf).
FADE_retreatCheckInterval = 10;  // seconds between 50% checks
FADE_retreatDebug = false;  // set true for systemChat messages (retreat trigger, per-unit decisions)
FADE_doEnemyRetreat = {
    params ["_groups", "_basePos"];
    if (_groups isEqualTo [] || { _basePos isEqualTo [] }) exitWith {};
    private _skill = missionNamespace getVariable ["FADE_enemySkill", 0.0];
    private _retreatChance = 1 - (_skill max 0 min 1);
    private _debug = missionNamespace getVariable ["FADE_retreatDebug", false];
    if (_debug) then {
        [format ["Retreat: 50%% threshold reached. Rolling retreat (chance %1%2).", round (_retreatChance * 100), "%"]] remoteExec ["systemChat", 0];
    };
    {
        private _grp = _x;
        if (!isNull _grp && { side _grp == (missionNamespace getVariable ["FADE_sideEnemy", east]) }) then {
            private _toRetreat = [];
            private _staying = [];
            {
                if (alive _x) then {
                    private _roll = random 1;
                    private _retreat = _roll < _retreatChance;
                    if (_debug) then {
                        [format ["Retreat: unit %1 -> %2 (roll %3 vs %4)", _x, if (_retreat) then { "RETREAT" } else { "STAY" }, round (_roll * 100) / 100, round (_retreatChance * 100) / 100]] remoteExec ["systemChat", 0];
                    };
                    if (_retreat) then { _toRetreat pushBack _x } else { _staying pushBack _x };
                };
            } forEach units _grp;
            if (count _toRetreat > 0) then {
                if (_debug) then {
                    [format ["Retreat: group %1 -> %2 retreating, %3 staying. Clearing waypoints.", _grp, count _toRetreat, count _staying]] remoteExec ["systemChat", 0];
                };
                // Clear all current waypoints so retreat replaces orders, not appends
                private _wps = waypoints _grp;
                for "_i" from (count _wps - 1) to 0 step -1 do {
                    deleteWaypoint [_grp, _i];
                };
                _grp setSpeedMode "FULL";
                {
                    private _unitPos = getPos _x;
                    if (count _unitPos >= 2) then {
                        private _dirToBase = _x getDir _basePos;
                        private _dest = _unitPos getPos [2000, _dirToBase + 180];
                        _x doMove _dest;
                        _x setUnitPos "AUTO";
                    };
                } forEach _toRetreat;
            };
        };
    } forEach _groups;
    if (_debug) then {
        [format ["Retreat: done. Orders sent (doMove 2km away from base)."]] remoteExec ["systemChat", 0];
    };
};
FADE_registerEnemyRetreat = {
    params ["_groups", "_basePos"];
    if (!(_groups isEqualType [])) exitWith {}; // avoid foreach Type Bool (bad caller / scope collision)
    if (_groups isEqualTo [] || { _basePos isEqualTo [] }) exitWith {};
    private _initialTotal = 0;
    { _initialTotal = _initialTotal + count units _x } forEach _groups;
    if (_initialTotal <= 1) exitWith {};  // 50% of 0 or 1 is pointless; avoid spawning check thread
    private _interval = missionNamespace getVariable ["FADE_retreatCheckInterval", 10];
    private _debug = missionNamespace getVariable ["FADE_retreatDebug", false];
    if (_debug) then {
        [format ["Retreat: registered %1 groups, %2 total enemies. Checking every %3s.", count _groups, _initialTotal, _interval]] remoteExec ["systemChat", 0];
    };
    [_groups, _basePos, _initialTotal, _interval, _debug] spawn {
        params ["_groups", "_basePos", "_initialTotal", "_interval", "_debug"];
        waitUntil {
            sleep _interval;
            private _alive = 0;
            { _alive = _alive + ({ alive _x } count units _x) } forEach _groups;
            _alive <= _initialTotal * 0.5
        };
        private _aliveNow = 0;
        { _aliveNow = _aliveNow + ({ alive _x } count units _x) } forEach _groups;
        if (_debug) then {
            [format ["Retreat: 50%% condition met (%1 alive / %2 initial). Applying retreat roll.", _aliveNow, _initialTotal]] remoteExec ["systemChat", 0];
        };
        [_groups, _basePos] call FADE_doEnemyRetreat;
    };
};

// -----------------------------------------------------------------------------
// Mission entity registry  -  track groups / vehicles / objects per task for abort + finish cleanup
// (QRF trucks, virtual-garrison spawns, convoy vehicles, mission composition, etc.)
// -----------------------------------------------------------------------------
FADE_missionEnt_init = {
    params ["_taskId"];
    if (_taskId == "") exitWith {};
    missionNamespace setVariable [format ["FADE_missionEnt_%1", _taskId], createHashMapFromArray [
        ["groups", []],
        ["groupRefs", []],
        ["vehicles", []],
        ["objects", []],
        ["markers", []]
    ]];
    missionNamespace setVariable [format ["FADE_missionEnt_cleaned_%1", _taskId], false];
};

FADE_missionEnt_get = {
    params ["_taskId"];
    if (_taskId == "") exitWith { createHashMap };
    private _ent = missionNamespace getVariable [format ["FADE_missionEnt_%1", _taskId], createHashMap];
    if (_ent isEqualType createHashMap) then { _ent } else { createHashMap }
};

FADE_missionEnt_bindGroups = {
    params ["_taskId", "_groupsArr"];
    if (_taskId == "" || { !(_groupsArr isEqualType []) }) exitWith {};
    private _ent = [_taskId] call FADE_missionEnt_get;
    if (count keys _ent == 0) then { [_taskId] call FADE_missionEnt_init; _ent = [_taskId] call FADE_missionEnt_get };
    private _refs = +(_ent getOrDefault ["groupRefs", []]);
    if (!(_groupsArr in _refs)) then {
        _refs pushBack _groupsArr;
        _ent set ["groupRefs", _refs];
        missionNamespace setVariable [format ["FADE_missionEnt_%1", _taskId], _ent];
    };
};

FADE_missionEnt_registerGroup = {
    params ["_taskId", "_grp"];
    if (_taskId == "" || { isNull _grp }) exitWith {};
    private _ent = [_taskId] call FADE_missionEnt_get;
    if (count keys _ent == 0) then { [_taskId] call FADE_missionEnt_init; _ent = [_taskId] call FADE_missionEnt_get };
    private _grps = +(_ent getOrDefault ["groups", []]);
    if (!(_grp in _grps)) then {
        _grps pushBack _grp;
        _ent set ["groups", _grps];
        missionNamespace setVariable [format ["FADE_missionEnt_%1", _taskId], _ent];
    };
};

FADE_missionEnt_registerVehicle = {
    params ["_taskId", "_veh"];
    if (_taskId == "" || { isNull _veh }) exitWith {};
    private _ent = [_taskId] call FADE_missionEnt_get;
    if (count keys _ent == 0) then { [_taskId] call FADE_missionEnt_init; _ent = [_taskId] call FADE_missionEnt_get };
    private _vehs = +(_ent getOrDefault ["vehicles", []]);
    if (!(_veh in _vehs)) then {
        _vehs pushBack _veh;
        _ent set ["vehicles", _vehs];
        missionNamespace setVariable [format ["FADE_missionEnt_%1", _taskId], _ent];
    };
};

FADE_missionEnt_registerObject = {
    params ["_taskId", "_obj"];
    if (_taskId == "" || { isNull _obj }) exitWith {};
    private _ent = [_taskId] call FADE_missionEnt_get;
    if (count keys _ent == 0) then { [_taskId] call FADE_missionEnt_init; _ent = [_taskId] call FADE_missionEnt_get };
    private _objs = +(_ent getOrDefault ["objects", []]);
    if (!(_obj in _objs)) then {
        _objs pushBack _obj;
        _ent set ["objects", _objs];
        missionNamespace setVariable [format ["FADE_missionEnt_%1", _taskId], _ent];
    };
};

FADE_missionEnt_registerMarker = {
    params ["_taskId", "_markerName"];
    if (_taskId == "" || { _markerName isEqualTo "" }) exitWith {};
    private _ent = [_taskId] call FADE_missionEnt_get;
    if (count keys _ent == 0) then { [_taskId] call FADE_missionEnt_init; _ent = [_taskId] call FADE_missionEnt_get };
    private _marks = +(_ent getOrDefault ["markers", []]);
    if (!(_markerName in _marks)) then {
        _marks pushBack _markerName;
        _ent set ["markers", _marks];
        missionNamespace setVariable [format ["FADE_missionEnt_%1", _taskId], _ent];
    };
};

// Delete all map markers for a mission task (registry, legacy vars, player vars, FADE_* sweep). Idempotent.
FADE_cleanupMissionMarkers = {
    params ["_taskId", ["_player", objNull]];
    if (_taskId == "") exitWith {};

    private _ent = missionNamespace getVariable [format ["FADE_missionEnt_%1", _taskId], createHashMap];
    if (_ent isEqualType createHashMap) then {
        { [_x] call FADE_deleteMarkerSafe } forEach (_ent getOrDefault ["markers", []]);
    };

    private _sdM = missionNamespace getVariable ["FADE_searchDestroyMarker_" + _taskId, ""];
    if (_sdM != "") then { [_sdM] call FADE_deleteMarkerSafe };
    missionNamespace setVariable ["FADE_searchDestroyMarker_" + _taskId, nil];
    private _sdZ = missionNamespace getVariable ["FADE_searchDestroyZoneMarker_" + _taskId, ""];
    if (_sdZ != "") then { [_sdZ] call FADE_deleteMarkerSafe };
    missionNamespace setVariable ["FADE_searchDestroyZoneMarker_" + _taskId, nil];

    private _aoM = missionNamespace getVariable ["FADE_aoMarkers_" + _taskId, []];
    if (_aoM isEqualType []) then {
        { [_x] call FADE_deleteMarkerSafe } forEach _aoM;
    };
    missionNamespace setVariable ["FADE_aoMarkers_" + _taskId, nil];

    {
        if ((_x getVariable ["FADE_myMissionTaskId", ""]) == _taskId) then {
            [_x getVariable ["FADE_myMissionMarker", ""]] call FADE_deleteMarkerSafe;
            [_x getVariable ["FADE_myMissionMarkerEnd", ""]] call FADE_deleteMarkerSafe;
            _x setVariable ["FADE_myMissionMarker", nil, true];
            _x setVariable ["FADE_myMissionMarkerEnd", nil, true];
        };
    } forEach allPlayers;

    if (!isNull _player) then {
        [_player getVariable ["FADE_myMissionMarker", ""]] call FADE_deleteMarkerSafe;
        [_player getVariable ["FADE_myMissionMarkerEnd", ""]] call FADE_deleteMarkerSafe;
        _player setVariable ["FADE_myMissionMarker", nil, true];
        _player setVariable ["FADE_myMissionMarkerEnd", nil, true];
    };

    {
        if ((_x find "FADE_") == 0 && { _x find _taskId >= 0 }) then {
            [_x] call FADE_deleteMarkerSafe;
        };
    } forEach allMapMarkers;
};

FADE_missionEnt_deleteGroupFull = {
    params ["_grp"];
    if (isNull _grp) exitWith {};
    private _vehs = [];
    {
        if (!isNull _x) then {
            private _v = vehicle _x;
            if (!isNull _v && { _v != _x } && { !(_v in _vehs) }) then { _vehs pushBack _v };
            deleteVehicle _x;
        };
    } forEach +units _grp;
    {
        if (!isNull _x) then {
            { if (!isNull _x) then { deleteVehicle _x } } forEach crew _x;
            if (alive _x) then { deleteVehicle _x };
        };
    } forEach _vehs;
    if (!isNull _grp) then { deleteGroup _grp };
};

FADE_missionEnt_deleteVehicleFull = {
    params ["_veh"];
    if (isNull _veh) exitWith {};
    private _cg = _veh getVariable ["FADE_eeQrfCargoGrp", grpNull];
    if (isNull _cg) then { _cg = _veh getVariable ["FADE_opforAirCargoGrp", grpNull] };
    if (!isNull _cg) then {
        { if (!isNull _x) then { deleteVehicle _x } } forEach units _cg;
        deleteGroup _cg;
    };
    { if (!isNull _x) then { deleteVehicle _x } } forEach crew _veh;
    private _dg = group driver _veh;
    if (!isNull _dg) then {
        { if (!isNull _x) then { deleteVehicle _x } } forEach units _dg;
        if (count units _dg == 0) then { deleteGroup _dg };
    };
    if (!isNull _veh) then { deleteVehicle _veh };
};

