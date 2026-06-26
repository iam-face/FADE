// =============================================================================
// TroopExtractTransport.sqf  -  per-participant extract transport (server)
// Params: [_group, _ownerPlayer, _pickupPos, _dropPos, _taskId, _markerName, _abortFlag,
//          _claimedVehKey, _pickupMarker, _waveIndex, _waveCount]
// =============================================================================
if (!isServer) exitWith {};

FADE_troopExtract_runTransport = {
    params [
        "_group", "_ownerPlayer", "_pickupPos", "_dropPos", "_taskId", "_markerName", "_abortFlag",
        ["_claimedVehKey", ""],
        ["_pickupMarker", ""],
        ["_waveIndex", 1],
        ["_waveCount", 1]
    ];

    private _fnc_clearLocalPickupMarker = {
        if (_pickupMarker isEqualTo "") exitWith {};
        if (isNull _ownerPlayer) exitWith {};
        [_pickupMarker] remoteExec ["FAC_troopInsertClient_deletePickupMarker", _ownerPlayer];
        _pickupMarker = "";
    };

    private _dropRadius = 80;
    private _pickupRadius = 200;
    private _timeout = 600;
    private _startTime = time;

    if (_group getVariable ["FADE_callsign", ""] == "") then {
        [_group] call (missionNamespace getVariable ["FADE_assignGroupCallsign", {}]);
    };

    private _fnc_aborted = { missionNamespace getVariable [_abortFlag, false] };
    private _fnc_callsign = { _group getVariable ["FADE_callsign", "Alpha 1-1"] };
    private _fnc_leader = {
        private _ldr = leader _group;
        if (isNull _ldr || { !alive _ldr }) then {
            private _alive = (units _group) select { alive _x };
            if (count _alive > 0) then { _ldr = _alive select 0 };
        };
        _ldr
    };
    private _fnc_sideChat = {
        params ["_msg"];
        private _ldr = [] call _fnc_leader;
        if (!isNull _ldr && { alive _ldr }) then { [_ldr, _msg] call FADE_aiSideChat };
    };
    private _fnc_metaOwner = {
        params ["_msg"];
        if (!isNull _ownerPlayer && { alive _ownerPlayer }) then {
            [_msg] remoteExec ["systemChat", _ownerPlayer];
        };
    };

    private _fnc_airReadyForPickup = {
        params ["_veh", "_anchor"];
        if (!(_veh isKindOf "Air")) exitWith { true };
        if (isTouchingGround _veh) exitWith { true };
        (speed _veh < 8) && { (getPosATL _veh select 2) < 25 } && { _veh distance2D _anchor < 250 }
    };

    private _fnc_ownerVehicle = {
        params ["_center", "_radius", "_owner"];
        if (isNull _owner) exitWith { objNull };
        private _best = objNull;
        private _bestD = 1e12;
        {
            if (isPlayer _x && { alive _x } && { _x == _owner }) then {
                private _veh = vehicle _x;
                if (!isNull _veh && { _veh != _x }) then {
                    private _isDriver = (driver _veh == _owner) || { effectiveCommander _veh == _owner };
                    if (_isDriver && { [_veh, _center] call _fnc_airReadyForPickup } && { (_veh distance _center) <= _radius }) then {
                        private _d = _veh distance _center;
                        if (_d < _bestD) then { _bestD = _d; _best = _veh };
                    };
                };
            };
        } forEach allUnits;
        _best
    };

    private _fnc_claimVehicle = {
        params ["_veh"];
        if (_claimedVehKey == "" || { isNull _veh }) exitWith { true };
        private _claimed = + (missionNamespace getVariable [_claimedVehKey, []]);
        if (_veh in _claimed) exitWith { false };
        _claimed pushBack _veh;
        missionNamespace setVariable [_claimedVehKey, _claimed, true];
        _group setVariable ["FADE_troopExtractClaimedVeh", _veh, false];
        true
    };

    private _fnc_releaseClaimedVehicle = {
        if (_claimedVehKey == "") exitWith {};
        private _veh = _group getVariable ["FADE_troopExtractClaimedVeh", objNull];
        if (isNull _veh) exitWith {};
        private _claimed = + (missionNamespace getVariable [_claimedVehKey, []]);
        private _idx = _claimed find _veh;
        if (_idx >= 0) then {
            _claimed deleteAt _idx;
            missionNamespace setVariable [_claimedVehKey, _claimed, true];
        };
        _group setVariable ["FADE_troopExtractClaimedVeh", nil, false];
    };

    private _initialCount = count units _group;
    private _fnc_checkCasualties = {
        if (isNull _group) exitWith { true };
        ({ alive _x } count units _group) < (ceil (_initialCount / 2))
    };

    private _transportDone = false;
    private _smokeSpawned = false;
    while {
        !_transportDone
        && { !isNull _group }
        && { count (units _group) > 0 }
        && { !([] call _fnc_aborted) }
    } do {
        if (time - _startTime > _timeout) exitWith {
            [format ["TROOP EXTRACT: Transport timed out (wave %1/%2).", _waveIndex, _waveCount]] call _fnc_metaOwner;
            [format ["%1, negative - exfil window expired. Over.", [] call _fnc_callsign]] call _fnc_sideChat;
        };
        if ([] call _fnc_checkCasualties) exitWith {
            [format ["TROOP EXTRACT FAILED: Excessive casualties (wave %1/%2).", _waveIndex, _waveCount]] call _fnc_metaOwner;
        };
        private _anchor = if (count _pickupPos >= 2) then { _pickupPos } else { getPosATL (leader _group) };
        private _veh = [_anchor, _pickupRadius, _ownerPlayer] call _fnc_ownerVehicle;
        if (isNull _veh) then {
            if (!_smokeSpawned) then {
                private _capable = (units _group) select { alive _x && { !(_x getVariable ["ACE_isUnconscious", false]) } };
                private _speaker = if (count _capable > 0) then { _capable select 0 } else { objNull };
                private _timeMin = (date select 3) * 60 + (date select 4);
                private _isNight = (_timeMin >= 1170 || { _timeMin <= 270 });
                if (_isNight && { isClass (configFile >> "CfgPatches" >> "ace_attach") }) then {
                    if (!isNull _speaker) then {
                        [format ["%1, IR strobes active on all units. Awaiting pickup. Over.", [] call _fnc_callsign]] call _fnc_sideChat;
                    };
                } else {
                    "SmokeShellGreen" createVehicle _anchor;
                    if (!isNull _speaker) then {
                        [format ["%1, green smoke deployed. Marking position. Over.", [] call _fnc_callsign]] call _fnc_sideChat;
                    };
                };
                _smokeSpawned = true;
            };
            if (time - _startTime > 45) then {
                [format ["%1, still no pickup at Grid %2. Over.", [] call _fnc_callsign, mapGridPosition _anchor]] call _fnc_sideChat;
            };
            sleep 2;
            continue;
        };
        if !([_veh] call _fnc_claimVehicle) then {
            [format ["%1, negative - that aircraft is already assigned to another lift. Over.", [] call _fnc_callsign]] call _fnc_sideChat;
            sleep 3;
            continue;
        };
        private _cargoSeats = (_veh emptyPositions "cargo") max 0;
        private _unitsToBoard = (units _group) select [0, _cargoSeats max 0];
        private _totalCount = count units _group;
        private _cs = [] call _fnc_callsign;
        if (count _unitsToBoard == 0) then {
            [format ["%1, negative - no cargo seats. We cannot board. Over.", _cs]] call _fnc_sideChat;
            [] call _fnc_releaseClaimedVehicle;
            sleep 3;
            continue;
        };
        if (_totalCount > _cargoSeats) then {
            [format ["%1, loading %2 personnel only - not enough seats. Stand by. Over.", _cs, _cargoSeats]] call _fnc_sideChat;
        } else {
            [format ["%1, loading now. Stand by. Over.", _cs]] call _fnc_sideChat;
        };
        { _x assignAsCargo _veh } forEach _unitsToBoard;
        _unitsToBoard orderGetIn true;
        private _tBoard = time + 90;
        waitUntil {
            sleep 0.5;
            ({ vehicle _x == _veh } count _unitsToBoard) == count _unitsToBoard ||
            { time > _tBoard } || { [] call _fnc_aborted } || { isNull _veh || {!alive _veh} }
        };
        if ([] call _fnc_aborted) exitWith {};
        if (({ vehicle _x == _veh } count _unitsToBoard) < count _unitsToBoard) then {
            [] call _fnc_releaseClaimedVehicle;
            sleep 2;
            continue;
        };
        [format ["%1, all aboard. RTB. Over.", _cs]] call _fnc_sideChat;
        [] call _fnc_clearLocalPickupMarker;
        private _tBase = time + _timeout;
        waitUntil {
            sleep 1;
            ([] call _fnc_aborted) || { isNull _veh || {!alive _veh} } ||
            { (_veh distance _dropPos) < _dropRadius && { if (_veh isKindOf "Air") then { isTouchingGround _veh } else { true } } } ||
            { time > _tBase }
        };
        if ([] call _fnc_aborted) exitWith {};
        if (isNull _veh || {!alive _veh}) exitWith {
            [format ["TROOP EXTRACT: Transport vehicle lost en route (wave %1/%2).", _waveIndex, _waveCount]] call _fnc_metaOwner;
        };
        private _atBase = (_veh distance _dropPos) < _dropRadius && { if (_veh isKindOf "Air") then { isTouchingGround _veh } else { true } };
        if (!_atBase) exitWith {
            [format ["TROOP EXTRACT: Base not reached in time (wave %1/%2).", _waveIndex, _waveCount]] call _fnc_metaOwner;
        };
        private _inVeh = (units _group) select { vehicle _x == _veh };
        [format ["%1, disembarking at base. Over.", _cs]] call _fnc_sideChat;
        {
            if (!isNull _x && { alive _x } && { vehicle _x == _veh }) then {
                unassignVehicle _x;
                _x moveOut _veh;
            };
            sleep 0.35;
        } forEach _inVeh;
        (units _group) orderGetIn false;
        [format ["%1, last man clear. Good work. Over.", _cs]] call _fnc_sideChat;
        _group setVariable ["FADE_troopExtractTransportDone", true, true];
        if (!isNull _ownerPlayer) then {
            _ownerPlayer setVariable [format ["FADE_teWaveOk_%1_%2", _taskId, _waveIndex], true, false];
        };
        _transportDone = true;
    };

    if (!(_group getVariable ["FADE_troopExtractTransportDone", false])) then {
        [] call _fnc_releaseClaimedVehicle;
        [] call _fnc_clearLocalPickupMarker;
    };
};

missionNamespace setVariable ["FADE_troopExtract_runTransport", FADE_troopExtract_runTransport];
