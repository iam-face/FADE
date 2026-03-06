// =============================================================================
// TroopTransport.sqf -- AI boarding/disembark logic for Insert and Extract
// =============================================================================
// Uses spawn+sleep interval pattern -- each check runs in a fresh scheduler
// entry, avoids GIF/GIAR stack size violations. No CBA required.
// Params: [_missionType, _group, _player, _pickupPos, _dropPos, _taskId, _markerName, [_enemyGroups]]
// =============================================================================

if (isNil "heliOps_transportParams" || { count heliOps_transportParams < 7 }) exitWith {};
heliOps_transportParams params ["_missionType", "_group", "_player", "_pickupPos", "_dropPos", "_taskId", ["_markerName", ""], ["_enemyGroups", []]];
if (!isServer) exitWith {};

if (_group getVariable ["heliOps_callsign", ""] == "") then { [_group] call (missionNamespace getVariable ["heliOps_assignGroupCallsign", {}]) };
private _callsign = _group getVariable ["heliOps_callsign", "Alpha 1-1"];
private _initialCount = count units _group;

// Central cleanup: delete group, enemy groups, mission marker (safe delete), clear player mission state.
// Runs on server; marker must be deleted on server (same machine that created it).
private _cleanup = {
    params ["_grp", "_marker", "_pl", ["_enemyGrps", []]];
    // Delete any IR strobes placed/attached during night marking (ACE3)
    if (!isNull _grp) then {
        { if (!isNull _x) then { detach _x; deleteVehicle _x } } forEach (_grp getVariable ["heliOps_irStrobes", []]);
        { deleteVehicle _x } forEach units _grp;
        deleteGroup _grp;
    };
    { if (!isNull _x) then { { deleteVehicle _x } forEach units _x; deleteGroup _x } } forEach _enemyGrps;
    [_marker] call heliOps_deleteMarkerSafe;
    [_pl] call heliOps_clearActiveMission;
};

// TroopInsert: fail on any casualty. TroopExtract: fail if >50% of pickup team dead (alive < half rounded up).
private _checkCasualties = {
    params ["_missionType", "_group", "_initialCount"];
    if (isNull _group) exitWith { true };
    private _alive = { alive _x } count units _group;
    if (_missionType == "TroopInsert") exitWith { _alive < (_initialCount - 1) }; // 1 casualty allowed
    if (_missionType == "TroopExtract") exitWith { _alive < (ceil (_initialCount / 2)) };
    false
};

private _pickupRadius = 250;
private _dropRadius = 50;
private _timeout = 600;
private _startTime = time;
private _smokeSpawned = false;

if (!isNull _player && { !isNull _group } && { count units _group > 0 }) then {
    private _leader = leader _group;
    if (!isNull _leader && { alive _leader }) then {
        private _grid = mapGridPosition _pickupPos;
        _leader sideChat format ["RZ, This is %1. We're at Grid %2, awaiting pickup. Over.", _callsign, _grid];
    };
};

// Phase 1: poll every 1s in fresh spawn -- no waitUntil/while, minimal stack
heliOps_transport_phase1 = {
    params ["_missionType", "_group", "_player", "_pickupPos", "_dropPos", "_taskId", "_markerName", "_pickupRadius", "_dropRadius", "_timeout", "_cleanup", "_startTime", "_smokeSpawned", "_initialCount", "_enemyGroups", "_checkCasualties"];
    private _callsign = _group getVariable ["heliOps_callsign", "Alpha 1-1"];
    sleep 1;
    if (isNull _player) exitWith { [_group, _markerName, _player, _enemyGroups, _cleanup] spawn { params ["_g","_m","_p","_e","_c"]; sleep 60; [_g,_m,_p,_e] call _c } };
    if (isNull _group || { count units _group == 0 }) exitWith { [_group, _markerName, _player, _enemyGroups, _cleanup] spawn { params ["_g","_m","_p","_e","_c"]; sleep 60; [_g,_m,_p,_e] call _c } };
    if ((_taskId call BIS_fnc_taskState) in ["CANCELED","FAILED"]) exitWith { [_group, _markerName, _player, _enemyGroups, _cleanup] spawn { params ["_g","_m","_p","_e","_c"]; sleep 60; [_g,_m,_p,_e] call _c } };
    if ([_missionType, _group, _initialCount] call _checkCasualties) exitWith {
        ["MISSION FAILED. EXCESSIVE CASUALTIES."] remoteExec ["systemChat", _player];
        [_taskId, "FAILED"] call BIS_fnc_taskSetState;
        [_group, _markerName, _player, _enemyGroups, _cleanup] spawn { params ["_g","_m","_p","_e","_c"]; sleep 60; [_g,_m,_p,_e] call _c };
    };
    if (time - _startTime > _timeout) exitWith {
        ["MISSION FAILED. EXFIL WINDOW EXPIRED."] remoteExec ["systemChat", _player];
        [_taskId, "CANCELED"] call BIS_fnc_taskSetState;
        [_group, _markerName, _player, _enemyGroups, _cleanup] spawn { params ["_g","_m","_p","_e","_c"]; sleep 60; [_g,_m,_p,_e] call _c };
    };
    private _veh = vehicle _player;
    if (_missionType == "TroopExtract" && { _veh != _player } && { _veh isKindOf "Helicopter" } && { (_veh distance _pickupPos) < 1000 } && !_smokeSpawned) then {
        private _capable = (units _group) select { alive _x && { !(_x getVariable ["ACE_isUnconscious", false]) } };
        private _speaker = if (count _capable > 0) then { _capable select 0 } else { objNull };
        private _inCombat = (!isNull _speaker && { (behaviour _speaker) == "COMBAT" });
        private _timeMin = (date select 3) * 60 + (date select 4);
        private _isNight = (_timeMin >= 1170 || { _timeMin <= 270 });
        if (_isNight && { isClass (configFile >> "CfgPatches" >> "ace_attach") }) then {
            // Strobes attached at spawn -- radio callsign and contact status only
            if (!isNull _speaker) then {
                if (_inCombat) then {
                    _speaker sideChat format ["RZ, This is %1. We're in contact at the pickup zone. IR strobes active on all units. Over!", _callsign];
                } else {
                    _speaker sideChat format ["RZ, This is %1. Awaiting pickup. IR strobes active on all units. Over.", _callsign];
                };
            };
            ["Friendly units marked with IR strobes (NVG required)"] remoteExec ["systemChat", _player];
        } else {
            // Daytime or no ACE: deploy green smoke
            "SmokeShellGreen" createVehicle _pickupPos;
            if (!isNull _speaker) then {
                if (_inCombat) then {
                    _speaker sideChat format ["RZ, This is %1. Green smoke deployed. We're in contact at the pickup zone. Over!", _callsign];
                } else {
                    _speaker sideChat format ["RZ, This is %1. Green smoke deployed. Marking position. No contact. Over.", _callsign];
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
                _leader sideChat format ["RZ, This is %1. Negative - you have no cargo seats. We cannot board. Over.", _callsign];
            } else {
                if (_totalCount > _cargoSeats) then {
                    _leader sideChat format ["RZ, This is %1. We have more personnel than you have seats - loading %2. Stand by. Over.", _callsign, _cargoSeats];
                } else {
                    _leader sideChat format ["RZ, This is %1. We're loading now. Stand by. Over.", _callsign];
                };
            };
        };
        if (count _unitsToBoard > 0) then {
            ["FAC_heliOps_embarkStart"] remoteExec ["playSound", _player];
            [_missionType, _group, _player, _pickupPos, _dropPos, _taskId, _markerName, _veh, _unitsToBoard, _dropRadius, _timeout, _cleanup, _startTime, _initialCount, _enemyGroups, _checkCasualties] spawn heliOps_transport_phase2;
        } else {
            [_missionType, _group, _player, _pickupPos, _dropPos, _taskId, _markerName, _pickupRadius, _dropRadius, _timeout, _cleanup, _startTime, _smokeSpawned, _initialCount, _enemyGroups, _checkCasualties] spawn heliOps_transport_phase1;
        };
    } else {
        [_missionType, _group, _player, _pickupPos, _dropPos, _taskId, _markerName, _pickupRadius, _dropRadius, _timeout, _cleanup, _startTime, _smokeSpawned, _initialCount, _enemyGroups, _checkCasualties] spawn heliOps_transport_phase1;
    };
};

// Phase 2: wait for troops boarded
heliOps_transport_phase2 = {
    params ["_missionType", "_group", "_player", "_pickupPos", "_dropPos", "_taskId", "_markerName", "_veh", "_unitsToBoard", "_dropRadius", "_timeout", "_cleanup", "_startTime", "_initialCount", "_enemyGroups", "_checkCasualties"];
    private _callsign = _group getVariable ["heliOps_callsign", "Alpha 1-1"];
    sleep 0.5;
    if (isNull _veh || !alive _veh) exitWith { [_group, _markerName, _player, _enemyGroups, _cleanup] spawn { params ["_g","_m","_p","_e","_c"]; sleep 60; [_g,_m,_p,_e] call _c } };
    if (time - _startTime > _timeout) exitWith { [_group, _markerName, _player, _enemyGroups, _cleanup] spawn { params ["_g","_m","_p","_e","_c"]; sleep 60; [_g,_m,_p,_e] call _c } };
    if ([_missionType, _group, _initialCount] call _checkCasualties) exitWith {
        ["MISSION FAILED. EXCESSIVE CASUALTIES."] remoteExec ["systemChat", _player];
        [_taskId, "FAILED"] call BIS_fnc_taskSetState;
        [_group, _markerName, _player, _enemyGroups, _cleanup] spawn { params ["_g","_m","_p","_e","_c"]; sleep 60; [_g,_m,_p,_e] call _c };
    };
    if (({ vehicle _x == _veh } count _unitsToBoard) == count _unitsToBoard) then {
        private _leader = leader _group;
        private _totalSquad = count units _group;
        if (!isNull _leader && { alive _leader }) then {
            if (count _unitsToBoard < _totalSquad) then {
                _leader sideChat format ["RZ, This is %1. Only %2 aboard - not enough seats for everyone. Proceeding to LZ. Over.", _callsign, count _unitsToBoard];
            } else {
                _leader sideChat format ["RZ, This is %1. All aboard. Ready for liftoff. Over.", _callsign];
            };
            _leader sideChat format ["RZ, This is %1. Proceed to LZ. Land to disembark. Over.", _callsign];
        };
        ["FAC_heliOps_embarkDone"] remoteExec ["playSound", _player];
        [_missionType, _group, _player, _dropPos, _taskId, _markerName, _veh, _dropRadius, _timeout, _cleanup, _startTime, _initialCount, _enemyGroups, _checkCasualties] spawn heliOps_transport_phase3;
    } else {
        [_missionType, _group, _player, _pickupPos, _dropPos, _taskId, _markerName, _veh, _unitsToBoard, _dropRadius, _timeout, _cleanup, _startTime, _initialCount, _enemyGroups, _checkCasualties] spawn heliOps_transport_phase2;
    };
};

// Phase 3: wait for heli at drop zone
heliOps_transport_phase3 = {
    params ["_missionType", "_group", "_player", "_dropPos", "_taskId", "_markerName", "_veh", "_dropRadius", "_timeout", "_cleanup", "_startTime", "_initialCount", "_enemyGroups", "_checkCasualties"];
    private _callsign = _group getVariable ["heliOps_callsign", "Alpha 1-1"];
    sleep 1;
    if (isNull _player || isNull _veh || !alive _veh) exitWith { [_group, _markerName, _player, _enemyGroups, _cleanup] spawn { params ["_g","_m","_p","_e","_c"]; sleep 60; [_g,_m,_p,_e] call _c } };
    if ((_taskId call BIS_fnc_taskState) in ["CANCELED","FAILED"]) exitWith { [_group, _markerName, _player, _enemyGroups, _cleanup] spawn { params ["_g","_m","_p","_e","_c"]; sleep 60; [_g,_m,_p,_e] call _c } };
    if ([_missionType, _group, _initialCount] call _checkCasualties) exitWith {
        ["MISSION FAILED. EXCESSIVE CASUALTIES."] remoteExec ["systemChat", _player];
        [_taskId, "FAILED"] call BIS_fnc_taskSetState;
        [_group, _markerName, _player, _enemyGroups, _cleanup] spawn { params ["_g","_m","_p","_e","_c"]; sleep 60; [_g,_m,_p,_e] call _c };
    };
    if (time - _startTime > _timeout) exitWith {
        ["MISSION FAILED. LZ NOT REACHED. TIME EXPIRED."] remoteExec ["systemChat", _player];
        [_taskId, "CANCELED"] call BIS_fnc_taskSetState;
        [_group, _markerName, _player, _enemyGroups, _cleanup] spawn { params ["_g","_m","_p","_e","_c"]; sleep 60; [_g,_m,_p,_e] call _c };
    };
    if ((_veh distance _dropPos) < _dropRadius && { isTouchingGround _veh }) then {
        private _unitsInVeh = (units _group) select { vehicle _x == _veh };
        if (count _unitsInVeh > 0) then {
            private _leader = leader _group;
            if (!isNull _leader && { alive _leader }) then { _leader sideChat format ["RZ, This is %1. Disembarking. Over.", _callsign] };
            ["FAC_heliOps_disembarkStart"] remoteExec ["playSound", _player];
            { _x moveOut _veh } forEach _unitsInVeh;
            (units _group) orderGetIn false;
            [_missionType, _group, _player, _taskId, _markerName, _veh, _cleanup, _dropPos, time, _initialCount, _enemyGroups, _checkCasualties] spawn heliOps_transport_phase4;
        } else {
            [_taskId, "SUCCEEDED"] call BIS_fnc_taskSetState;
            private _leader = leader _group;
            if (!isNull _leader && { alive _leader }) then { _leader sideChat format ["RZ, This is %1. Mission complete. Over.", _callsign] };
            if (_missionType == "TroopExtract" && { count heliOps_bSpPoints > 0 }) then {
                private _leader = leader _group;
                private _nearest = [heliOps_bSpPoints, _leader] call BIS_fnc_nearestPosition;
                private _spawnPos = if (_nearest isEqualType []) then { _nearest } else { position _nearest };
                if (count _spawnPos >= 2) then {
                    _group addWaypoint [_spawnPos, 0];
                    [_group, _markerName, _player, _cleanup, _spawnPos, _enemyGroups] spawn heliOps_transport_phase4b;
                } else {
                    [_group, _markerName, _player, _cleanup, _enemyGroups] spawn { params ["_group", "_markerName", "_player", "_cleanup", "_enemyGroups"]; sleep 60; [_group, _markerName, _player, _enemyGroups] call _cleanup };
                };
            } else {
                private _wpPos = [_dropPos, 80, 120, 5, 0, 0, 0, [], _dropPos] call BIS_fnc_findSafePos;
                _group addWaypoint [_wpPos, 0];
                [_group, _markerName, _player, _cleanup, _enemyGroups] spawn { params ["_group", "_markerName", "_player", "_cleanup", "_enemyGroups"]; sleep 60; [_group, _markerName, _player, _enemyGroups] call _cleanup };
            };
        };
    } else {
        [_missionType, _group, _player, _dropPos, _taskId, _markerName, _veh, _dropRadius, _timeout, _cleanup, _startTime, _initialCount, _enemyGroups, _checkCasualties] spawn heliOps_transport_phase3;
    };
};

// Phase 4: wait for troops exited (30s max)
heliOps_transport_phase4 = {
    params ["_missionType", "_group", "_player", "_taskId", "_markerName", "_veh", "_cleanup", "_dropPos", "_exitStart", "_initialCount", "_enemyGroups", "_checkCasualties"];
    private _callsign = _group getVariable ["heliOps_callsign", "Alpha 1-1"];
    sleep 0.5;
    if ([_missionType, _group, _initialCount] call _checkCasualties) exitWith {
        ["MISSION FAILED. EXCESSIVE CASUALTIES."] remoteExec ["systemChat", _player];
        [_taskId, "FAILED"] call BIS_fnc_taskSetState;
        [_group, _markerName, _player, _enemyGroups, _cleanup] spawn { params ["_g","_m","_p","_e","_c"]; sleep 60; [_g,_m,_p,_e] call _c };
    };
    private _stillIn = (units _group) select { vehicle _x == _veh };
    if (count _stillIn == 0) then {
        private _leader = leader _group;
        if (!isNull _leader && { alive _leader }) then {
            _leader sideChat format ["RZ, This is %1. Last man! Over.", _callsign];
        };
        ["FAC_heliOps_disembarkDone"] remoteExec ["playSound", _player];
        [_taskId, "SUCCEEDED"] call BIS_fnc_taskSetState;
        if (_missionType == "TroopExtract" && { count heliOps_bSpPoints > 0 }) then {
            private _leader = leader _group;
            private _nearest = [heliOps_bSpPoints, _leader] call BIS_fnc_nearestPosition;
            private _spawnPos = if (_nearest isEqualType []) then { _nearest } else { position _nearest };
            if (count _spawnPos >= 2) then {
                _group addWaypoint [_spawnPos, 0];
                [_group, _markerName, _player, _cleanup, _spawnPos, _enemyGroups] spawn heliOps_transport_phase4b;
            } else {
                [_group, _markerName, _player, _cleanup, _enemyGroups] spawn { params ["_group", "_markerName", "_player", "_cleanup", "_enemyGroups"]; sleep 60; [_group, _markerName, _player, _enemyGroups] call _cleanup };
            };
        } else {
            private _wpPos = [_dropPos, 80, 120, 5, 0, 0, 0, [], _dropPos] call BIS_fnc_findSafePos;
            _group addWaypoint [_wpPos, 0];
            [_group, _markerName, _player, _cleanup, _enemyGroups] spawn { params ["_group", "_markerName", "_player", "_cleanup", "_enemyGroups"]; sleep 60; [_group, _markerName, _player, _enemyGroups] call _cleanup };
        };
    } else {
        if (time - _exitStart > 30) then {
            [_group, _markerName, _player, _enemyGroups, _cleanup] spawn { params ["_g","_m","_p","_e","_c"]; sleep 60; [_g,_m,_p,_e] call _c };
        } else {
            [_missionType, _group, _player, _taskId, _markerName, _veh, _cleanup, _dropPos, _exitStart, _initialCount, _enemyGroups, _checkCasualties] spawn heliOps_transport_phase4;
        };
    };
};

// Phase 4b: TroopExtract -- troops walk to nearest B_SP_*, despawn on arrival (or 120s timeout)
heliOps_transport_phase4b = {
    params ["_group", "_markerName", "_player", "_cleanup", "_spawnPos", ["_enemyGroups", []]];
    private _arrivalDist = 5;
    private _timeout = 120;
    private _start = time;
    scriptName "heliOps_transport_phase4b";
    while { !isNull _group && { count units _group > 0 } && { (leader _group) distance _spawnPos > _arrivalDist } && { time - _start < _timeout } } do {
        sleep 1;
    };
    [_group, _markerName, _player, _enemyGroups, _cleanup] spawn { params ["_g","_m","_p","_e","_c"]; sleep 60; [_g,_m,_p,_e] call _c };
};

// Start phase 1 (spawn = fresh scheduler entry, minimal stack)
[_missionType, _group, _player, _pickupPos, _dropPos, _taskId, _markerName, _pickupRadius, _dropRadius, _timeout, _cleanup, _startTime, _smokeSpawned, _initialCount, _enemyGroups, _checkCasualties] spawn heliOps_transport_phase1;
