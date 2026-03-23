// =============================================================================
// TroopTransport.sqf -- AI boarding/disembark logic for Insert and Extract
// =============================================================================
// Uses spawn+sleep interval pattern -- each check runs in a fresh scheduler
// entry, avoids GIF/GIAR stack size violations. No CBA required.
// Params: [_missionType, _group, _player, _pickupPos, _dropPos, _taskId, _markerName, [_enemyGroups]]
// Phase fns are local (not globals) so concurrent missions cannot overwrite each other's handlers.
// _cleanup receives task id explicitly -- parent execVM scope must not be relied on after script ends.
// =============================================================================

if (isNil "FADE_transportParams" || { count FADE_transportParams < 7 }) exitWith {};
FADE_transportParams params ["_missionType", "_group", "_player", "_pickupPos", "_dropPos", "_taskId", ["_markerName", ""], ["_enemyGroups", []]];
if (!isServer) exitWith {};

if (_group getVariable ["FADE_callsign", ""] == "") then { [_group] call (missionNamespace getVariable ["FADE_assignGroupCallsign", {}]) };
private _callsign = _group getVariable ["FADE_callsign", "Alpha 1-1"];
private _initialCount = count units _group;

// Central cleanup: delete group, enemy groups, mission marker (safe delete).
// Player mission state is only cleared when the task id still matches, to avoid overlap races.
// Runs on server; marker must be deleted on server (same machine that created it).
private _cleanup = {
    params ["_grp", "_marker", "_pl", ["_enemyGrps", []], ["_taskIdGuard", ""]];
    // Delete any IR strobes placed/attached during night marking (ACE3)
    if (!isNull _grp) then {
        { if (!isNull _x) then { detach _x; deleteVehicle _x } } forEach (_grp getVariable ["FADE_irStrobes", []]);
        { deleteVehicle _x } forEach units _grp;
        deleteGroup _grp;
    };
    { if (!isNull _x) then { { deleteVehicle _x } forEach units _x; deleteGroup _x } } forEach _enemyGrps;
    [_marker] call FADE_deleteMarkerSafe;
    if (!isNull _pl && { (_pl getVariable ["FADE_myMissionTaskId", ""]) == _taskIdGuard }) then {
        [_pl, _taskIdGuard] call FADE_clearActiveMission;
    };
};

// Set final task state and immediately clear player's active mission slot.
private _setTaskFinalState = {
    params ["_taskId", "_state", "_pl", ["_msg", ""]];
    if (_msg != "" && { !isNull _pl }) then {
        [_msg] remoteExec ["systemChat", _pl];
    };
    [_taskId, _state] call BIS_fnc_taskSetState;
    if (!isNull _pl && { (_pl getVariable ["FADE_myMissionTaskId", ""]) == _taskId }) then {
        [_pl, _taskId] call FADE_clearActiveMission;
    };
};

// Stagger unit disembark so they do not all exit on the same frame.
private _staggerDisembark = {
    params ["_units", "_veh", ["_delay", 0.35]];
    [_units, _veh, _delay] spawn {
        params ["_uList", "_v", "_d"];
        {
            if (!isNull _x && { alive _x } && { vehicle _x == _v }) then {
                _x moveOut _v;
                sleep _d;
            };
        } forEach _uList;
    };
};

// TroopInsert: fail if strictly >50% killed before LZ; no % casualty fail after insert. TroopExtract: >50% anytime en route.
private _checkCasualties = {
    params ["_missionType", "_group", "_initialCount"];
    if (isNull _group) exitWith { true };
    private _alive = { alive _x } count units _group;
    if (_missionType == "TroopInsert") exitWith {
        if (_group getVariable ["FADE_insertReachedLZ", false]) exitWith { false };
        _alive < (ceil (_initialCount / 2))
    };
    if (_missionType == "TroopExtract") exitWith { _alive < (ceil (_initialCount / 2)) };
    false
};

private _pickupRadius = 250;
private _dropRadius = if (_missionType == "TroopInsert") then { 500 } else { 50 };
private _timeout = 600;
private _startTime = time;
private _smokeSpawned = false;

if (!isNull _player && { !isNull _group } && { count units _group > 0 }) then {
    private _leader = leader _group;
    if (!isNull _leader && { alive _leader }) then {
        if (_missionType == "TroopInsert") then {
            _leader sideChat format ["This is %1. We're at base, standing by for pickup. Over.", _callsign];
        } else {
            private _grid = mapGridPosition _pickupPos;
            _leader sideChat format ["This is %1. We're at Grid %2, awaiting pickup. Over.", _callsign, _grid];
        };
    };
};

// --- Local phase closures (not missionNamespace) so parallel transport scripts do not clobber each other ---
private _phase1 = {};
private _phase2 = {};
private _phase3 = {};
private _phase4 = {};
private _phase4b = {};

_phase1 = {
    params ["_missionType", "_group", "_player", "_pickupPos", "_dropPos", "_taskId", "_markerName", "_pickupRadius", "_dropRadius", "_timeout", "_cleanup", "_startTime", "_smokeSpawned", "_initialCount", "_enemyGroups", "_checkCasualties", "_setTaskFinalState", "_staggerDisembark", "_fnPhase1", "_fnPhase2", "_fnPhase3", "_fnPhase4", "_fnPhase4b"];
    private _callsign = _group getVariable ["FADE_callsign", "Alpha 1-1"];
    sleep 1;
    if (isNull _player) exitWith { [_group, _markerName, _player, _enemyGroups, _cleanup, _taskId] spawn { params ["_g","_m","_p","_e","_c","_tid"]; sleep 60; [_g,_m,_p,_e,_tid] call _c } };
    if (isNull _group || { count units _group == 0 }) exitWith { [_group, _markerName, _player, _enemyGroups, _cleanup, _taskId] spawn { params ["_g","_m","_p","_e","_c","_tid"]; sleep 60; [_g,_m,_p,_e,_tid] call _c } };
    if ((_taskId call BIS_fnc_taskState) in ["CANCELED","FAILED"]) exitWith { [_group, _markerName, _player, _enemyGroups, _cleanup, _taskId] spawn { params ["_g","_m","_p","_e","_c","_tid"]; sleep 60; [_g,_m,_p,_e,_tid] call _c } };
    if ([_missionType, _group, _initialCount] call _checkCasualties) exitWith {
        [_taskId, "FAILED", _player, "MISSION FAILED. EXCESSIVE CASUALTIES."] call _setTaskFinalState;
        [_group, _markerName, _player, _enemyGroups, _cleanup, _taskId] spawn { params ["_g","_m","_p","_e","_c","_tid"]; sleep 60; [_g,_m,_p,_e,_tid] call _c };
    };
    if (time - _startTime > _timeout) exitWith {
        [_taskId, "CANCELED", _player, "MISSION FAILED. EXFIL WINDOW EXPIRED."] call _setTaskFinalState;
        [_group, _markerName, _player, _enemyGroups, _cleanup, _taskId] spawn { params ["_g","_m","_p","_e","_c","_tid"]; sleep 60; [_g,_m,_p,_e,_tid] call _c };
    };
    private _veh = vehicle _player;
    if (_missionType == "TroopExtract" && { _veh != _player } && { _veh isKindOf "Helicopter" } && { (_veh distance _pickupPos) < 1000 } && !_smokeSpawned) then {
        private _capable = (units _group) select { alive _x && { !(_x getVariable ["ACE_isUnconscious", false]) } };
        private _speaker = if (count _capable > 0) then { _capable select 0 } else { objNull };
        private _inCombat = (!isNull _speaker && { (behaviour _speaker) == "COMBAT" });
        private _timeMin = (date select 3) * 60 + (date select 4);
        private _isNight = (_timeMin >= 1170 || { _timeMin <= 270 });
        if (_isNight && { isClass (configFile >> "CfgPatches" >> "ace_attach") }) then {
            if (!isNull _speaker) then {
                if (_inCombat) then {
                    _speaker sideChat format ["This is %1. We're in contact at the pickup zone. IR strobes active on all units. Over!", _callsign];
                } else {
                    _speaker sideChat format ["This is %1. Awaiting pickup. IR strobes active on all units. Over.", _callsign];
                };
            };
            ["Friendly units marked with IR strobes (NVG required)"] remoteExec ["systemChat", _player];
        } else {
            "SmokeShellGreen" createVehicle _pickupPos;
            if (!isNull _speaker) then {
                if (_inCombat) then {
                    _speaker sideChat format ["This is %1. Green smoke deployed. We're in contact at the pickup zone. Over!", _callsign];
                } else {
                    _speaker sideChat format ["This is %1. Green smoke deployed. Marking position. No contact. Over.", _callsign];
                };
            };
        };
        _smokeSpawned = true;
    };
    if (_veh != _player && { _veh isKindOf "Helicopter" } && { (_veh distance _pickupPos) < _pickupRadius } && { isTouchingGround _veh }) then {
        private _cargoSeats = (_veh emptyPositions "cargo") max 0;
        private _unitsToBoard = (units _group) select [0, _cargoSeats];
        private _totalCount = count units _group;
        { _x assignAsCargo _veh } forEach _unitsToBoard;
        _unitsToBoard orderGetIn true;
        private _leader = leader _group;
        if (!isNull _leader && { alive _leader }) then {
            if (_cargoSeats == 0) then {
                _leader sideChat format ["This is %1. Negative - you have no cargo seats. We cannot board. Over.", _callsign];
            } else {
                if (_totalCount > _cargoSeats) then {
                    _leader sideChat format ["This is %1. We have more personnel than you have seats - loading %2. Stand by. Over.", _callsign, _cargoSeats];
                } else {
                    _leader sideChat format ["This is %1. We're loading now. Stand by. Over.", _callsign];
                };
            };
        };
        if (count _unitsToBoard > 0) then {
            ["FADE_embarkStart"] remoteExec ["playSound", _player];
            [_missionType, _group, _player, _pickupPos, _dropPos, _taskId, _markerName, _veh, _unitsToBoard, _dropRadius, _timeout, _cleanup, _startTime, _initialCount, _enemyGroups, _checkCasualties, _setTaskFinalState, _staggerDisembark, _fnPhase2, _fnPhase3, _fnPhase4, _fnPhase4b] spawn _fnPhase2;
        } else {
            [_missionType, _group, _player, _pickupPos, _dropPos, _taskId, _markerName, _pickupRadius, _dropRadius, _timeout, _cleanup, _startTime, _smokeSpawned, _initialCount, _enemyGroups, _checkCasualties, _setTaskFinalState, _staggerDisembark, _fnPhase1, _fnPhase2, _fnPhase3, _fnPhase4, _fnPhase4b] spawn _fnPhase1;
        };
    } else {
        [_missionType, _group, _player, _pickupPos, _dropPos, _taskId, _markerName, _pickupRadius, _dropRadius, _timeout, _cleanup, _startTime, _smokeSpawned, _initialCount, _enemyGroups, _checkCasualties, _setTaskFinalState, _staggerDisembark, _fnPhase1, _fnPhase2, _fnPhase3, _fnPhase4, _fnPhase4b] spawn _fnPhase1;
    };
};

_phase2 = {
    params ["_missionType", "_group", "_player", "_pickupPos", "_dropPos", "_taskId", "_markerName", "_veh", "_unitsToBoard", "_dropRadius", "_timeout", "_cleanup", "_startTime", "_initialCount", "_enemyGroups", "_checkCasualties", "_setTaskFinalState", "_staggerDisembark", "_fnPhase2", "_fnPhase3", "_fnPhase4", "_fnPhase4b"];
    private _callsign = _group getVariable ["FADE_callsign", "Alpha 1-1"];
    sleep 0.5;
    if (isNull _veh || !alive _veh) exitWith { [_group, _markerName, _player, _enemyGroups, _cleanup, _taskId] spawn { params ["_g","_m","_p","_e","_c","_tid"]; sleep 60; [_g,_m,_p,_e,_tid] call _c } };
    if (time - _startTime > _timeout) exitWith { [_group, _markerName, _player, _enemyGroups, _cleanup, _taskId] spawn { params ["_g","_m","_p","_e","_c","_tid"]; sleep 60; [_g,_m,_p,_e,_tid] call _c } };
    if ([_missionType, _group, _initialCount] call _checkCasualties) exitWith {
        [_taskId, "FAILED", _player, "MISSION FAILED. EXCESSIVE CASUALTIES."] call _setTaskFinalState;
        [_group, _markerName, _player, _enemyGroups, _cleanup, _taskId] spawn { params ["_g","_m","_p","_e","_c","_tid"]; sleep 60; [_g,_m,_p,_e,_tid] call _c };
    };
    if (({ vehicle _x == _veh } count _unitsToBoard) == count _unitsToBoard) then {
        if (_missionType == "TroopExtract") then {
            [_taskId, _dropPos] call BIS_fnc_taskSetDestination;
        };
        private _leader = leader _group;
        private _totalSquad = count units _group;
        if (!isNull _leader && { alive _leader }) then {
            if (count _unitsToBoard < _totalSquad) then {
                _leader sideChat format ["This is %1. Only %2 aboard - not enough seats for everyone. Proceeding to LZ. Over.", _callsign, count _unitsToBoard];
            } else {
                _leader sideChat format ["This is %1. All aboard. Ready for liftoff. Over.", _callsign];
            };
        };
        ["FADE_embarkDone"] remoteExec ["playSound", _player];
        [_missionType, _group, _player, _dropPos, _taskId, _markerName, _veh, _dropRadius, _timeout, _cleanup, _startTime, _initialCount, _enemyGroups, _checkCasualties, _setTaskFinalState, _fnPhase3, _fnPhase4, _fnPhase4b, _staggerDisembark] spawn _fnPhase3;
    } else {
        [_missionType, _group, _player, _pickupPos, _dropPos, _taskId, _markerName, _veh, _unitsToBoard, _dropRadius, _timeout, _cleanup, _startTime, _initialCount, _enemyGroups, _checkCasualties, _setTaskFinalState, _staggerDisembark, _fnPhase2, _fnPhase3, _fnPhase4, _fnPhase4b] spawn _fnPhase2;
    };
};

_phase3 = {
    params ["_missionType", "_group", "_player", "_dropPos", "_taskId", "_markerName", "_veh", "_dropRadius", "_timeout", "_cleanup", "_startTime", "_initialCount", "_enemyGroups", "_checkCasualties", "_setTaskFinalState", "_fnPhase3", "_fnPhase4", "_fnPhase4b", "_staggerDisembark"];
    private _callsign = _group getVariable ["FADE_callsign", "Alpha 1-1"];
    sleep 1;
    if (isNull _player || isNull _veh || !alive _veh) exitWith { [_group, _markerName, _player, _enemyGroups, _cleanup, _taskId] spawn { params ["_g","_m","_p","_e","_c","_tid"]; sleep 60; [_g,_m,_p,_e,_tid] call _c } };
    if ((_taskId call BIS_fnc_taskState) in ["CANCELED","FAILED"]) exitWith { [_group, _markerName, _player, _enemyGroups, _cleanup, _taskId] spawn { params ["_g","_m","_p","_e","_c","_tid"]; sleep 60; [_g,_m,_p,_e,_tid] call _c } };
    if ([_missionType, _group, _initialCount] call _checkCasualties) exitWith {
        [_taskId, "FAILED", _player, "MISSION FAILED. EXCESSIVE CASUALTIES."] call _setTaskFinalState;
        [_group, _markerName, _player, _enemyGroups, _cleanup, _taskId] spawn { params ["_g","_m","_p","_e","_c","_tid"]; sleep 60; [_g,_m,_p,_e,_tid] call _c };
    };
    if (time - _startTime > _timeout) exitWith {
        [_taskId, "CANCELED", _player, "MISSION FAILED. LZ NOT REACHED. TIME EXPIRED."] call _setTaskFinalState;
        [_group, _markerName, _player, _enemyGroups, _cleanup, _taskId] spawn { params ["_g","_m","_p","_e","_c","_tid"]; sleep 60; [_g,_m,_p,_e,_tid] call _c };
    };
    if ((_veh distance _dropPos) < _dropRadius && { isTouchingGround _veh }) then {
        private _unitsInVeh = (units _group) select { vehicle _x == _veh };
        if (count _unitsInVeh > 0) then {
            if (_missionType == "TroopInsert") then { _group setVariable ["FADE_insertReachedLZ", true] };
            private _leader = leader _group;
            if (!isNull _leader && { alive _leader }) then { _leader sideChat format ["This is %1. Disembarking. Over.", _callsign] };
            ["FADE_disembarkStart"] remoteExec ["playSound", _player];
            [_unitsInVeh, _veh, 0.35] call _staggerDisembark;
            (units _group) orderGetIn false;
            [_missionType, _group, _player, _taskId, _markerName, _veh, _cleanup, _dropPos, time, _initialCount, _enemyGroups, _checkCasualties, _setTaskFinalState, _fnPhase4, _fnPhase4b, _staggerDisembark] spawn _fnPhase4;
        } else {
            [_taskId, "SUCCEEDED", _player] call _setTaskFinalState;
            private _leader = leader _group;
            if (!isNull _leader && { alive _leader }) then { _leader sideChat format ["This is %1. Mission complete. Over.", _callsign] };
            if (_missionType == "TroopExtract" && { count FADE_bSpPoints > 0 }) then {
                private _leader = leader _group;
                private _nearest = [FADE_bSpPoints, _leader] call BIS_fnc_nearestPosition;
                private _spawnPos = if (_nearest isEqualType []) then { _nearest } else { position _nearest };
                if (count _spawnPos >= 2) then {
                    _group addWaypoint [_spawnPos, 0];
                    [_group, _markerName, _player, _cleanup, _spawnPos, _enemyGroups, _taskId] spawn _fnPhase4b;
                } else {
                    [_group, _markerName, _player, _cleanup, _enemyGroups, _taskId] spawn { params ["_group", "_markerName", "_player", "_cleanup", "_enemyGroups", "_tid"]; sleep 60; [_group, _markerName, _player, _enemyGroups, _tid] call _cleanup };
                };
            } else {
                private _wpPos = [_dropPos, 80, 120, 5, 0, 0, 0, [], _dropPos] call BIS_fnc_findSafePos;
                _group addWaypoint [_wpPos, 0];
                [_group, _markerName, _player, _cleanup, _enemyGroups, _taskId] spawn { params ["_group", "_markerName", "_player", "_cleanup", "_enemyGroups", "_tid"]; sleep 60; [_group, _markerName, _player, _enemyGroups, _tid] call _cleanup };
            };
        };
    } else {
        [_missionType, _group, _player, _dropPos, _taskId, _markerName, _veh, _dropRadius, _timeout, _cleanup, _startTime, _initialCount, _enemyGroups, _checkCasualties, _setTaskFinalState, _fnPhase3, _fnPhase4, _fnPhase4b, _staggerDisembark] spawn _fnPhase3;
    };
};

_phase4 = {
    params ["_missionType", "_group", "_player", "_taskId", "_markerName", "_veh", "_cleanup", "_dropPos", "_exitStart", "_initialCount", "_enemyGroups", "_checkCasualties", "_setTaskFinalState", "_fnPhase4", "_fnPhase4b", "_staggerDisembark"];
    private _callsign = _group getVariable ["FADE_callsign", "Alpha 1-1"];
    sleep 0.5;
    if ([_missionType, _group, _initialCount] call _checkCasualties) exitWith {
        [_taskId, "FAILED", _player, "MISSION FAILED. EXCESSIVE CASUALTIES."] call _setTaskFinalState;
        [_group, _markerName, _player, _enemyGroups, _cleanup, _taskId] spawn { params ["_g","_m","_p","_e","_c","_tid"]; sleep 60; [_g,_m,_p,_e,_tid] call _c };
    };
    private _stillIn = (units _group) select { vehicle _x == _veh };
    if (count _stillIn == 0) then {
        private _leader = leader _group;
        if (!isNull _leader && { alive _leader }) then {
            _leader sideChat format ["This is %1. Last man! Over.", _callsign];
        };
        ["FADE_disembarkDone"] remoteExec ["playSound", _player];
        [_taskId, "SUCCEEDED", _player] call _setTaskFinalState;
        if (_missionType == "TroopExtract" && { count FADE_bSpPoints > 0 }) then {
            private _leader = leader _group;
            private _nearest = [FADE_bSpPoints, _leader] call BIS_fnc_nearestPosition;
            private _spawnPos = if (_nearest isEqualType []) then { _nearest } else { position _nearest };
            if (count _spawnPos >= 2) then {
                _group addWaypoint [_spawnPos, 0];
                [_group, _markerName, _player, _cleanup, _spawnPos, _enemyGroups, _taskId] spawn _fnPhase4b;
            } else {
                [_group, _markerName, _player, _cleanup, _enemyGroups, _taskId] spawn { params ["_group", "_markerName", "_player", "_cleanup", "_enemyGroups", "_tid"]; sleep 60; [_group, _markerName, _player, _enemyGroups, _tid] call _cleanup };
            };
        } else {
            private _wpPos = [_dropPos, 80, 120, 5, 0, 0, 0, [], _dropPos] call BIS_fnc_findSafePos;
            _group addWaypoint [_wpPos, 0];
            [_group, _markerName, _player, _cleanup, _enemyGroups, _taskId] spawn { params ["_group", "_markerName", "_player", "_cleanup", "_enemyGroups", "_tid"]; sleep 60; [_group, _markerName, _player, _enemyGroups, _tid] call _cleanup };
        };
    } else {
        if (time - _exitStart > 30) then {
            [_group, _markerName, _player, _enemyGroups, _cleanup, _taskId] spawn { params ["_g","_m","_p","_e","_c","_tid"]; sleep 60; [_g,_m,_p,_e,_tid] call _c };
        } else {
            [_missionType, _group, _player, _taskId, _markerName, _veh, _cleanup, _dropPos, _exitStart, _initialCount, _enemyGroups, _checkCasualties, _setTaskFinalState, _fnPhase4, _fnPhase4b, _staggerDisembark] spawn _fnPhase4;
        };
    };
};

_phase4b = {
    params ["_group", "_markerName", "_player", "_cleanup", "_spawnPos", ["_enemyGroups", []], "_taskId"];
    private _arrivalDist = 5;
    private _timeout = 120;
    private _start = time;
    scriptName "FADE_transport_phase4b";
    while { !isNull _group && { count units _group > 0 } && { (leader _group) distance _spawnPos > _arrivalDist } && { time - _start < _timeout } } do {
        sleep 1;
    };
    [_group, _markerName, _player, _enemyGroups, _cleanup, _taskId] spawn { params ["_g","_m","_p","_e","_c","_tid"]; sleep 60; [_g,_m,_p,_e,_tid] call _c };
};

// Start phase 1 (spawn = fresh scheduler entry, minimal stack)
[
    _missionType, _group, _player, _pickupPos, _dropPos, _taskId, _markerName, _pickupRadius, _dropRadius, _timeout, _cleanup, _startTime, _smokeSpawned, _initialCount, _enemyGroups, _checkCasualties, _setTaskFinalState, _staggerDisembark,
    _phase1, _phase2, _phase3, _phase4, _phase4b
] spawn _phase1;
