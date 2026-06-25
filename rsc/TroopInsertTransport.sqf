// =============================================================================
// TroopInsertTransport.sqf  -  per-participant insert transport (server)
// Params: [_group, _ownerPlayer, _pickupPos, _dropPos, _taskId, _markerName, _abortFlag,
//          _claimedVehKey, _pickupMarker]
// _pickupMarker (optional) is the per-player local marker name created by the mission
// script; this transport runner deletes it on the owner's client once boarding succeeds.
// =============================================================================
if (!isServer) exitWith {};

FADE_troopInsert_runTransport = {
    params [
        "_group", "_ownerPlayer", "_pickupPos", "_dropPos", "_taskId", "_markerName", "_abortFlag",
        ["_claimedVehKey", ""],
        ["_pickupMarker", ""]
    ];

    private _fnc_clearLocalPickupMarker = {
        if (_pickupMarker isEqualTo "") exitWith {};
        if (isNull _ownerPlayer) exitWith {};
        [_pickupMarker] remoteExec ["FAC_troopInsertClient_deletePickupMarker", _ownerPlayer];
        _pickupMarker = "";
    };

    private _dropRadius = 500;
    private _pickupRadius = 200;
    private _timeout = 600;
    private _startTime = time;

    if (_group getVariable ["FADE_callsign", ""] == "") then {
        [_group] call (missionNamespace getVariable ["FADE_assignGroupCallsign", {}]);
    };

    private _fnc_aborted = {
        missionNamespace getVariable [_abortFlag, false]
    };

    private _fnc_callsign = {
        _group getVariable ["FADE_callsign", "Alpha 1-1"]
    };

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

    private _fnc_hintOwner = {
        params ["_msg"];
        if (!isNull _ownerPlayer && { alive _ownerPlayer }) then {
            [_msg] remoteExec ["FADE_showMissionHint", _ownerPlayer];
        };
    };

    private _fnc_playOwnerSound = {
        params ["_soundClass"];
        if (isNull _ownerPlayer) exitWith {};
        if (isClass (missionConfigFile >> "CfgSounds" >> _soundClass)) then {
            [_soundClass] remoteExec ["playSound", _ownerPlayer];
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
        _group setVariable ["FADE_troopInsertClaimedVeh", _veh, false];
        true
    };

    private _fnc_releaseClaimedVehicle = {
        if (_claimedVehKey == "") exitWith {};
        private _veh = _group getVariable ["FADE_troopInsertClaimedVeh", objNull];
        if (isNull _veh) exitWith {};
        private _claimed = + (missionNamespace getVariable [_claimedVehKey, []]);
        private _idx = _claimed find _veh;
        if (_idx >= 0) then {
            _claimed deleteAt _idx;
            missionNamespace setVariable [_claimedVehKey, _claimed, true];
        };
        _group setVariable ["FADE_troopInsertClaimedVeh", nil, false];
    };

    private _fnc_disembarkOneByOne = {
        params ["_units", "_veh", ["_delay", 1.2]];
        private _list = +_units;
        private _n = count _list;
        for "_i" from 0 to (_n - 1) do {
            private _u = _list select _i;
            if (!isNull _u && { alive _u } && { vehicle _u == _veh }) then {
                unassignVehicle _u;
                _u moveOut _veh;
                if (_i == _n - 1) then {
                    [format ["This is %1. Last man! Over.", [] call _fnc_callsign]] call _fnc_sideChat;
                    ["FADE_disembarkDone"] call _fnc_playOwnerSound;
                };
            };
            if (_i < _n - 1) then { sleep _delay };
        };
    };

    private _fnc_scheduleGroupCleanup = {
        params ["_grp", "_tid", ["_delay", 30]];
        if (isNull _grp) exitWith {};
        if (_grp getVariable ["FADE_troopInsertCleanupScheduled", false]) exitWith {};
        _grp setVariable ["FADE_troopInsertCleanupScheduled", true, true];
        [_grp, _tid, _delay] spawn {
            params ["_grp", "_tid", "_delay"];
            sleep _delay;
            if (isNull _grp) exitWith {};
            if (_grp getVariable ["FADE_troopInsertCleanupDone", false]) exitWith {};
            _grp setVariable ["FADE_troopInsertCleanupDone", true, true];
            { if (!isNull _x) then { detach _x; deleteVehicle _x } } forEach (_grp getVariable ["FADE_irStrobes", []]);
            { if (!isNull _x) then { deleteVehicle _x } } forEach units _grp;
            if (!isNull _grp) then { deleteGroup _grp };
        };
    };

    private _fnc_pickupAnchor = {
        private _ldr = [] call _fnc_leader;
        if (!isNull _ldr && { alive _ldr }) exitWith { getPosATL _ldr };
        if (count _pickupPos >= 2) exitWith { _pickupPos };
        if (!isNull _ownerPlayer && { alive _ownerPlayer }) exitWith { getPosATL _ownerPlayer };
        _pickupPos
    };

    private _fnc_compassSector = {
        params ["_from", "_to"];
        private _pFrom = if (_from isEqualType []) then { _from } else { getPosATL _from };
        private _pTo = if (_to isEqualType []) then { _to } else { getPosATL _to };
        private _sectors = ["N", "NE", "E", "SE", "S", "SW", "W", "NW"];
        private _bearing = _pFrom getDir _pTo;
        _sectors select ((round ((_bearing + 22.5) / 45)) % 8)
    };

    private _transportDone = false;
    private _warnedNoVehicle = false;
    private _warnedTravelToPickup = false;
    private _warnedDuplicateVeh = false;
    while {
        !_transportDone
        && { !isNull _group }
        && { count (units _group) > 0 }
        && { !([] call _fnc_aborted) }
    } do {
        if (time - _startTime > _timeout) exitWith {
            ["<t size='1.2' color='#FF6666'>TROOP INSERT</t><br/><br/><t color='#E0E0E0'>Transport timed out  -  squad could not complete insertion.</t>"] call _fnc_hintOwner;
            [format ["This is %1. Negative  -  no pickup. Standing down. Over.", [] call _fnc_callsign]] call _fnc_sideChat;
        };
        private _anchor = [] call _fnc_pickupAnchor;
        private _veh = [_anchor, _pickupRadius, _ownerPlayer] call _fnc_ownerVehicle;
        if (isNull _veh) then {
            if (
                !_warnedTravelToPickup
                && { !isNull _ownerPlayer }
                && { alive _ownerPlayer }
                && { count _pickupPos >= 2 }
                && { (getPosATL _ownerPlayer) distance2D _pickupPos > 250 }
            ) then {
                // Squad spawn already issues the "holding at grid" sidechat via _fnc_squadPickupSideChat;
                // here we only update the requesting player's UI hint to avoid a duplicate radio call.
                _warnedTravelToPickup = true;
                private _pickGrid = mapGridPosition _anchor;
                private _sector = [getPosATL _ownerPlayer, _pickupPos] call _fnc_compassSector;
                private _dist = round ((getPosATL _ownerPlayer) distance2D _pickupPos);
                [format [
                    "<t color='#FFFFFF'>TROOP INSERT</t><br/><br/><t color='#E0E0E0'>Proceed to squad link-up: Grid %1  -  approx %2 m %3. Land or hold steady to board  -  driver/commander within 200 m.</t>",
                    _pickGrid, _dist, _sector
                ]] call _fnc_hintOwner;
            };
            if (time - _startTime > 45 && { !_warnedNoVehicle }) then {
                _warnedNoVehicle = true;
                private _pickGrid = mapGridPosition _anchor;
                [format ["This is %1. Still no pickup at Grid %2. Where's our lift? Over.", [] call _fnc_callsign, _pickGrid]] call _fnc_sideChat;
                ["<t color='#FFFFFF'>TROOP INSERT</t><br/><br/><t color='#E0E0E0'>Link up with your squad  -  be driver or commander of your landed vehicle within 200 m of the link-up point.</t>"] call _fnc_hintOwner;
            };
            sleep 2;
            continue;
        };
        if !([_veh] call _fnc_claimVehicle) then {
            if (!_warnedDuplicateVeh) then {
                _warnedDuplicateVeh = true;
                ["<t color='#FFFFFF'>TROOP INSERT</t><br/><br/><t color='#E0E0E0'>That vehicle is already assigned to another transport  -  use a different vehicle.</t>"] call _fnc_hintOwner;
                [format ["This is %1. Negative  -  that vehicle is already assigned to another lift. Over.", [] call _fnc_callsign]] call _fnc_sideChat;
            };
            sleep 3;
            continue;
        };
        private _cargoSeats = (_veh emptyPositions "cargo") max 0;
        private _unitsToBoard = (units _group) select [0, _cargoSeats max 0];
        private _totalCount = count units _group;
        private _cs = [] call _fnc_callsign;
        if (count _unitsToBoard == 0) then {
            [format ["This is %1. Negative  -  you have no cargo seats. We cannot board. Over.", _cs]] call _fnc_sideChat;
            ["<t color='#FFFFFF'>TROOP INSERT</t><br/><br/><t color='#E0E0E0'>Your vehicle has no cargo seats for the squad.</t>"] call _fnc_hintOwner;
            [] call _fnc_releaseClaimedVehicle;
            sleep 3;
            continue;
        };
        if (_totalCount > _cargoSeats) then {
            [format ["This is %1. We have more personnel than you have seats  -  loading %2. Stand by. Over.", _cs, _cargoSeats]] call _fnc_sideChat;
        } else {
            [format ["This is %1. We're loading now. Stand by. Over.", _cs]] call _fnc_sideChat;
        };
        { _x assignAsCargo _veh } forEach _unitsToBoard;
        _unitsToBoard orderGetIn true;
        ["FADE_embarkStart"] call _fnc_playOwnerSound;
        private _tBoard = time + 90;
        waitUntil {
            sleep 0.5;
            (count _unitsToBoard == 0) || { ({ vehicle _x == _veh } count _unitsToBoard) == count _unitsToBoard } ||
            { time > _tBoard } || { [] call _fnc_aborted } || { isNull _veh || {!alive _veh} }
        };
        if ([] call _fnc_aborted) exitWith {};
        if (isNull _veh || {!alive _veh}) exitWith {
            ["<t size='1.2' color='#FF6666'>TROOP INSERT</t><br/><br/><t color='#E0E0E0'>Your transport vehicle was lost before insertion.</t>"] call _fnc_hintOwner;
        };
        if (({ vehicle _x == _veh } count _unitsToBoard) < count _unitsToBoard) then {
            [] call _fnc_releaseClaimedVehicle;
            sleep 2;
            continue;
        };
        if (count _unitsToBoard < _totalCount) then {
            [format ["This is %1. Only %2 aboard  -  not enough seats for everyone. Proceeding to LZ. Over.", [] call _fnc_callsign, count _unitsToBoard]] call _fnc_sideChat;
        } else {
            [format ["This is %1. All aboard. Ready for liftoff. Over.", [] call _fnc_callsign]] call _fnc_sideChat;
        };
        ["FADE_embarkDone"] call _fnc_playOwnerSound;
        [] call _fnc_clearLocalPickupMarker;
        private _tLz = time + _timeout;
        waitUntil {
            sleep 1;
            ([] call _fnc_aborted) || { isNull _veh || {!alive _veh} } ||
            { (_veh distance _dropPos) < _dropRadius && { if (_veh isKindOf "Air") then { isTouchingGround _veh } else { true } } } ||
            { time > _tLz }
        };
        if ([] call _fnc_aborted) exitWith {};
        if (isNull _veh || {!alive _veh}) exitWith {
            ["<t size='1.2' color='#FF6666'>TROOP INSERT</t><br/><br/><t color='#E0E0E0'>Your transport vehicle was lost en route to the LZ.</t>"] call _fnc_hintOwner;
        };
        private _atLz = (_veh distance _dropPos) < _dropRadius && { if (_veh isKindOf "Air") then { isTouchingGround _veh } else { true } };
        if (!_atLz) exitWith {
            ["<t size='1.2' color='#FF6666'>TROOP INSERT</t><br/><br/><t color='#E0E0E0'>LZ not reached in time  -  insert failed.</t>"] call _fnc_hintOwner;
        };
        _group setVariable ["FADE_insertReachedLZ", true, true];
        private _inVeh = (units _group) select { vehicle _x == _veh };
        [format ["This is %1. Disembarking. Over.", [] call _fnc_callsign]] call _fnc_sideChat;
        ["FADE_disembarkStart"] call _fnc_playOwnerSound;
        [_inVeh, _veh, 1.2] call _fnc_disembarkOneByOne;
        (units _group) orderGetIn false;
        private _tOut = time + 60;
        waitUntil {
            sleep 0.25;
            ([] call _fnc_aborted) || { ({ vehicle _x == _veh } count (units _group)) == 0 } || { time > _tOut }
        };
        [format ["This is %1. On the ground at the LZ. Good hunting. Over.", [] call _fnc_callsign]] call _fnc_sideChat;
        ["<t color='#FFFFFF'>TROOP INSERT</t><br/><br/><t color='#E0E0E0'>Squad inserted at the LZ.</t>"] call _fnc_hintOwner;
        _group setVariable ["FADE_troopInsertTransportDone", true, true];
        [_group, _taskId, 30] call _fnc_scheduleGroupCleanup;
        _transportDone = true;
    };

    if (!(_group getVariable ["FADE_troopInsertTransportDone", false])) then {
        [] call _fnc_releaseClaimedVehicle;
        [] call _fnc_clearLocalPickupMarker;
        [_group, _taskId, 0] call _fnc_scheduleGroupCleanup;
    };
};

missionNamespace setVariable ["FADE_troopInsert_runTransport", FADE_troopInsert_runTransport];
