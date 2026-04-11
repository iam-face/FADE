// =============================================================================
// FiresFallOfShot.sqf - FIRES range: observer UAV (spawn + terminal) + per-slot impact RTT
// =============================================================================
// Compiled on server (initServer) and client (initPlayerLocal). Server: spawn,
// projectiles, toggles. Client: map click, impact PiP/RTT, local cameras.
//
// Drone briefing-screen video RTT removed from the mission; archived under
// rsc/archive/FiresDroneVideoFeed_archived.sqf (observer UAV + terminal unchanged).

#define FAC_FiresFoS_IMPACT_RTT_PREFIX "FAC_FiresImp"

// Used on clients (RTT screens) and server; must NOT live inside if (isServer) or clients never get the symbol.
FAC_firesFoS_fnc_resolveEdenNamedObject = {
    params [["_edenName", ""]];
    if (_edenName == "" || {!(_edenName isEqualType "")}) exitWith { objNull };
    private _cache = missionNamespace getVariable ["FAC_firesFoS_objCache", createHashMap];
    private _cached = _cache getOrDefault [_edenName, objNull];
    if (!isNull _cached) exitWith { _cached };
    private _o = missionNamespace getVariable [_edenName, objNull];
    if (!isNull _o) exitWith {
        _cache set [_edenName, _o];
        missionNamespace setVariable ["FAC_firesFoS_objCache", _cache];
        _o
    };
    // Do not call compile _edenName: names like "droneVideoScreen" compile to an undefined variable, not a string.
    private _scan = [];
    {
        _scan append (allMissionObjects _x);
    } forEach [
        "Land_BriefingRoomScreen_01_F",
        "Land_BriefingRoomScreen_01_black_F",
        "Land_TripodScreen_01_large_F",
        "Land_TripodScreen_01_small_F"
    ];
    private _i = _scan findIf { vehicleVarName _x == _edenName };
    if (_i < 0) exitWith { objNull };
    private _r = _scan select _i;
    _cache set [_edenName, _r];
    missionNamespace setVariable ["FAC_firesFoS_objCache", _cache];
    _r
};

// remoteExec target 0 hits every machine (scheduled on clients); dedicated server has hasInterface false so reImpactFeed exits before PiP.
FAC_firesFoS_fnc_reDroneStop = {
    if (!hasInterface) exitWith {};
    [] call FAC_firesFoS_fnc_clientDroneStop;
};
FAC_firesFoS_fnc_reDroneSync = {
    if (!hasInterface) exitWith {};
    _this call FAC_firesFoS_fnc_clientDroneSync;
};
FAC_firesFoS_fnc_reImpactFeed = {
    if (!hasInterface) exitWith {};
    // Scheduled context: clientImpactFeed uses sleep / camera setup.
    _this spawn { _this call FAC_firesFoS_fnc_clientImpactFeed };
};

// Shared server + client (CfgAmmo only — safe everywhere).
FAC_firesFoS_fnc_ammoLooksLikeIndirect = {
    params [["_ammo", ""]];
    if (_ammo == "" || {!(_ammo isEqualType "")}) exitWith { false };
    private _cfg = configFile >> "CfgAmmo" >> _ammo;
    if (!isClass _cfg) exitWith { false };
    private _ind = getNumber (_cfg >> "indirectHit");
    private _ihr = getNumber (_cfg >> "indirectHitRange");
    private _exp = getNumber (_cfg >> "explosive");
    private _cal = getNumber (_cfg >> "caliber");
    private _sim = toLower getText (_cfg >> "simulation");
    private _shotLike = (((_sim find "shot") >= 0) && {_sim != "shotbullet"}) || {(_sim find "shell") >= 0} || {(_sim find "submunition") >= 0};
    (_ind > 0) || {_ihr > 0} || {_exp >= 0.15} || {_cal >= 10 && _exp > 0} || {_shotLike}
};

if (isServer) then {

// Push RTT feed to all interface clients — only the server runs this (avoids client-initiated broadcast restrictions).
FAC_firesFoS_fnc_broadcastImpactFeed = {
    params ["_slotIdx", "_impactASL", "_duration"];
    [_slotIdx, _impactASL, _duration] remoteExec ["FAC_firesFoS_fnc_reImpactFeed", 0, true];
};

// Single entry for impacts: dedicated shooters report via remoteExec; listen server dedupes server tracker + local client tracker.
FAC_firesFoS_fnc_server_pushImpactFeed = {
    params ["_slotIdx", "_impactASL", "_duration"];
    if (!isServer) exitWith {};
    if (_slotIdx < 0) exitWith {};
    if (!(_impactASL isEqualType []) || {count _impactASL < 3}) exitWith {};
    private _dur = _duration;
    if (!(_dur isEqualType 0)) then { _dur = missionNamespace getVariable ["FADE_firesImpactFeedDuration", 10]; };
    if (_dur <= 0) then { _dur = missionNamespace getVariable ["FADE_firesImpactFeedDuration", 10]; };
    private _ded = missionNamespace getVariable ["FAC_firesFoS_impactDedupe", nil];
    if (isNil "_ded" || {!(_ded isEqualType [])} || {count _ded < 3}) then { _ded = [-1, -1e9, [0, 0, 0]] };
    _ded params ["_ds", "_dt", "_dp"];
    if (_slotIdx == _ds && {(time - _dt) < 1.25} && {(_impactASL distance _dp) < 20}) exitWith {};
    missionNamespace setVariable ["FAC_firesFoS_impactDedupe", [_slotIdx, time, +_impactASL]];
    [_slotIdx, _impactASL, _dur] call FAC_firesFoS_fnc_broadcastImpactFeed;
};

FAC_firesFoS_server_objFromNetId = {
    params [["_nid", ""]];
    if (_nid == "" || {!(_nid isEqualType "")}) exitWith { objNull };
    private _found = objNull;
    _found = objectFromNetId _nid;
    if (isNull _found) then {
        { if (netId _x == _nid) exitWith { _found = _x } } forEach vehicles;
    };
    _found
};

FAC_firesFoS_server_stripTerminalIfGranted = {
    params [["_unit", objNull], ["_cls", ""]];
    if (isNull _unit || {_cls == ""}) exitWith {};
    if !(_unit getVariable ["FAC_firesFoS_terminalGranted", false]) exitWith {};
    if (_cls in assignedItems _unit) then { _unit unlinkItem _cls };
    _unit setVariable ["FAC_firesFoS_terminalGranted", false, false];
};

FAC_firesFoS_server_grantTerminal = {
    params [["_unit", objNull], ["_cls", ""]];
    if (isNull _unit || {_cls == ""}) exitWith {};
    if (_cls in assignedItems _unit) exitWith {};
    if !(_cls in assignedItems _unit) then { _unit linkItem _cls };
    if (_cls in assignedItems _unit) then {
        _unit setVariable ["FAC_firesFoS_terminalGranted", true, false];
    };
};

FADE_firesFoS_droneDespawnServer = {
    if (!isServer) exitWith {};
    private _drone = missionNamespace getVariable ["FAC_firesFoS_rangeDrone", objNull];
    private _owner = missionNamespace getVariable ["FAC_firesFoS_droneOwnerUnit", objNull];
    private _term = missionNamespace getVariable ["FADE_firesUavTerminalClass", "B_UavTerminal"];
    [_owner, _term] call FAC_firesFoS_server_stripTerminalIfGranted;
    missionNamespace setVariable ["FAC_firesFoS_droneOwnerUnit", nil];
    missionNamespace setVariable ["FAC_firesFoS_droneOwnerUid", ""];
    missionNamespace setVariable ["FAC_firesFoS_droneOwnerName", "", true];
    if (!isNull _drone) then {
        { if (!isNull _x) then { _drone deleteVehicleCrew _x } } forEach crew _drone;
        deleteVehicle _drone;
    };
    missionNamespace setVariable ["FAC_firesFoS_rangeDrone", nil];
    missionNamespace setVariable ["FAC_firesFoS_rangeDroneNetId", "", true];
    [] remoteExec ["FAC_firesFoS_fnc_reDroneStop", 0, true];
};

FADE_firesFoS_droneSpawnRequest = {
    params [["_pos", []], ["_player", objNull]];
    if (!isServer) exitWith {};
    if (isNull _player || {!isPlayer _player}) exitWith {};
    if (!(_pos isEqualType []) || {count _pos < 2}) exitWith {
        ["FIRES: invalid map position for drone."] remoteExec ["systemChat", _player];
    };
    private _cls = missionNamespace getVariable ["FADE_firesRangeDroneClass", "B_UAV_01_F"];
    if (!isClass (configFile >> "CfgVehicles" >> _cls)) exitWith {
        [format ["FIRES: drone class missing: %1", _cls]] remoteExec ["systemChat", _player];
    };
    private _term = missionNamespace getVariable ["FADE_firesUavTerminalClass", "B_UavTerminal"];

    private _prevOwner = missionNamespace getVariable ["FAC_firesFoS_droneOwnerUnit", objNull];
    private _prevDrone = missionNamespace getVariable ["FAC_firesFoS_rangeDrone", objNull];
    if (!isNull _prevDrone) then {
        [_prevOwner, _term] call FAC_firesFoS_server_stripTerminalIfGranted;
        { if (!isNull _x) then { _prevDrone deleteVehicleCrew _x } } forEach crew _prevDrone;
        deleteVehicle _prevDrone;
        missionNamespace setVariable ["FAC_firesFoS_rangeDrone", nil];
    };

    private _x = _pos select 0;
    private _y = _pos select 1;
    private _agl = if (count _pos > 2) then { _pos select 2 } else { 0 };
    private _aslZ = (getTerrainHeightASL [_x, _y]) + 120 max 80;
    private _spawnASL = [_x, _y, _aslZ];
    private _spawnATL = ASLtoATL _spawnASL;

    private _drone = createVehicle [_cls, _spawnATL, [], 0, "FLY"];
    if (isNull _drone) exitWith {
        ["FIRES: drone spawn failed."] remoteExec ["systemChat", _player];
    };
    _drone setPosASL _spawnASL;
    _drone setDir random 360;
    _drone allowDamage false;
    _drone setCaptive true;
    createVehicleCrew _drone;
    if (isNull (driver _drone)) then {
        createVehicleCrew _drone;
    };
    private _dvr = driver _drone;
    if (!isNull _dvr) then {
        group _dvr setBehaviour "CARELESS";
        group _dvr setCombatMode "BLUE";
    };
    // After releasing the UAV terminal, AI otherwise recenters optics to default; keep last aim.
    {
        _x disableAI "AUTOTARGET";
        _x disableAI "TARGET";
        _x disableAI "WEAPONAIM";
        _x disableAI "AIMINGERROR";
    } forEach crew _drone;
    { _drone enableDirectionStabilization [false, _x] } forEach allTurrets _drone;
    _drone flyInHeight 120;
    _drone lock 0;

    missionNamespace setVariable ["FAC_firesFoS_rangeDrone", _drone];
    missionNamespace setVariable ["FAC_firesFoS_droneOwnerUnit", _player];
    missionNamespace setVariable ["FAC_firesFoS_droneOwnerUid", getPlayerUID _player];
    missionNamespace setVariable ["FAC_firesFoS_droneOwnerName", name _player, true];
    [_player, _term] call FAC_firesFoS_server_grantTerminal;

    private _nid = netId _drone;
    missionNamespace setVariable ["FAC_firesFoS_rangeDroneNetId", _nid, true];
    [] remoteExec ["FAC_firesFoS_fnc_reDroneStop", 0, true];

    [format ["FIRES: observer drone up. Use UAV terminal (%1) for camera.", _term]] remoteExec ["systemChat", _player];
};

FADE_firesFoS_droneDespawnRequest = {
    params [["_player", objNull]];
    if (!isServer) exitWith {};
    [] call FADE_firesFoS_droneDespawnServer;
    if (!isNull _player) then {
        ["FIRES: observer drone removed."] remoteExec ["systemChat", _player];
    };
};

FADE_firesFoS_requestSync = {
    params [["_player", objNull]];
    if (!isServer) exitWith {};
    // No briefing-screen drone RTT: clear any stale client cameras/textures (JIP / reconnect).
    if (!isNull _player) then {
        [] remoteExec ["FAC_firesFoS_fnc_reDroneStop", _player];
    };
};

// Server-only: track projectile to impact, then push fall-of-shot feed to all clients.
FAC_firesFoS_server_startImpactTracker = {
    // Two arguments: projectile/shell object, FIRES slot index (not params [["_p", _slotIdx]] — that only binds _p).
    params ["_p", "_slotIdx"];
    if (!isServer) exitWith {};
    if (_slotIdx < 0) exitWith {};
    // Fired + EntityCreated can both see the same shell — only one tracker.
    private _nid = if (!isNull _p) then { netId _p } else { "" };
    if (_nid != "") then {
        private _hm = missionNamespace getVariable ["FAC_firesFoS_trackedShells", nil];
        if (isNil "_hm" || {!(_hm isEqualType createHashMap)}) then { _hm = createHashMap };
        if (_hm getOrDefault [_nid, false]) exitWith {};
        _hm set [_nid, true];
        missionNamespace setVariable ["FAC_firesFoS_trackedShells", _hm];
    };
    // Snapshot before spawn: scheduled script may run after the shell is gone; alive _p is often false for projectiles.
    private _snap = if (!isNull _p) then { getPosASL _p } else { [0, 0, 0] };
    [_p, _slotIdx, _nid, _snap] spawn {
        params ["_p", "_slotIdx", "_nid", "_snap"];
        private _last = _snap;
        private _tEnd = time + 120;
        private _trk = missionNamespace getVariable ["FADE_firesProjectileTrackSleep", 0.1];
        if (_trk < 0.03) then { _trk = 0.03 };
        if (_trk > 0.5) then { _trk = 0.5 };
        while {
            time < _tEnd && {!isNull _p}
        } do {
            _last = getPosASL _p;
            sleep _trk;
        };
        private _impact = if (!isNull _p) then { getPosASL _p } else { _last };
        if ((_impact select 0) == 0 && {(_impact select 1) == 0}) exitWith {
            if (_nid != "") then {
                private _hmZ = missionNamespace getVariable ["FAC_firesFoS_trackedShells", createHashMap];
                _hmZ deleteAt _nid;
                missionNamespace setVariable ["FAC_firesFoS_trackedShells", _hmZ];
            };
        };
        private _dur = missionNamespace getVariable ["FADE_firesImpactFeedDuration", 10];
        [_slotIdx, _impact, _dur] call FAC_firesFoS_fnc_server_pushImpactFeed;
        if (_nid != "") then {
            private _hm2 = missionNamespace getVariable ["FAC_firesFoS_trackedShells", createHashMap];
            _hm2 deleteAt _nid;
            missionNamespace setVariable ["FAC_firesFoS_trackedShells", _hm2];
        };
    };
};

// When Fired passes objNull projectile (common for artillery computer / some mod pieces), match the next shell EntityCreated near that gun.
FAC_firesFoS_server_onShellEntityCreated = {
    if (!isServer) exitWith {};
    private _e = if (_this isEqualType []) then { _this param [0, objNull] } else { _this };
    if (isNull _e) exitWith {};
    private _cls = typeOf _e;
    private _cfgA = configFile >> "CfgAmmo" >> _cls;
    if (!isClass _cfgA) exitWith {};
    private _sim = toLower getText (_cfgA >> "simulation");
    if (_sim == "shotbullet") exitWith {};
    if (((_sim find "shot") < 0) && {(_sim find "shell") < 0} && {(_sim find "submunition") < 0}) exitWith {};

    private _pl = + (missionNamespace getVariable ["FAC_firesFoS_pendingVehList", []]);
    _pl = _pl select {
        private _v = _x;
        !isNull _v && {alive _v} && {
            private _pend = _v getVariable ["FAC_firesFoS_pendingImpact", []];
            (_pend isEqualType []) && {count _pend >= 2} && {time - (_pend select 0) < 4}
        }
    };
    missionNamespace setVariable ["FAC_firesFoS_pendingVehList", _pl];
    // Do NOT exit when _pl is empty: on dedicated server, Fired often never runs (no camera / locality),
    // so pending stays empty — we still match shells via nearest FIRES piece below.

    private _candidates = [];
    {
        private _veh = _x;
        if (isNull _veh || {!alive _veh}) then { continue };
        private _pend = _veh getVariable ["FAC_firesFoS_pendingImpact", []];
        if (!(_pend isEqualType []) || {count _pend < 2}) then { continue };
        _pend params ["_tF", "_ammoF"];
        if (time - _tF > 3) then { continue };
        private _d = _veh distance2D _e;
        if (_d > 80) then { continue };
        private _slotIdx = _veh getVariable ["FAC_firesFoS_slotIndex", -1];
        if (_slotIdx < 0) then { continue };
        private _ammoOk = (_ammoF == "") || {_cls == _ammoF} || {_cls find _ammoF >= 0} || {_ammoF find _cls >= 0};
        if (!_ammoOk) then { continue };
        _candidates pushBack [_d, _veh, _slotIdx];
    } forEach _pl;

    // Ammo class on spawned body can differ from Fired EH string (mods) — fall back to nearest pending gun.
    if (count _candidates == 0) then {
        {
            private _veh = _x;
            if (isNull _veh || {!alive _veh}) then { continue };
            private _pend = _veh getVariable ["FAC_firesFoS_pendingImpact", []];
            if (!(_pend isEqualType []) || {count _pend < 2}) then { continue };
            if (time - (_pend select 0) > 3) then { continue };
            private _d = _veh distance2D _e;
            if (_d > 80) then { continue };
            private _slotIdx = _veh getVariable ["FAC_firesFoS_slotIndex", -1];
            if (_slotIdx < 0) then { continue };
            _candidates pushBack [_d, _veh, _slotIdx];
        } forEach _pl;
    };

    // No pending / no server Fired: map shell spawn position to closest spawned FIRES piece (muzzle proximity).
    if (count _candidates == 0) then {
        if ((_sim find "smoke") < 0 && {[_cls] call FAC_firesFoS_fnc_ammoLooksLikeIndirect}) then {
            private _slots = missionNamespace getVariable ["FADE_fires_slots", []];
            if ((_slots isEqualType []) && {count _slots > 0}) then {
                private _en = missionNamespace getVariable ["FAC_firesFoS_impactEnabled", []];
                private _bestD = 1e9;
                private _bestSlot = -1;
                {
                    _x params ["", "", "_veh"];
                    if (isNull _veh || {!alive _veh}) then { continue };
                    private _si = _forEachIndex;
                    if (_si >= count _en) then { continue };
                    if (!(_en select _si)) then { continue };
                    private _d = _veh distance2D _e;
                    if (_d < _bestD && {_d <= 50}) then {
                        _bestD = _d;
                        _bestSlot = _si;
                    };
                } forEach _slots;
                if (_bestSlot >= 0) then {
                    [_e, _bestSlot] call FAC_firesFoS_server_startImpactTracker;
                };
            };
        };
    };

    if (count _candidates == 0) exitWith {};
    _candidates sort true;
    (_candidates select 0) params ["_d", "_veh", "_slotIdx"];

    _veh setVariable ["FAC_firesFoS_pendingImpact", nil, false];
    private _pl2 = _pl - [_veh];
    missionNamespace setVariable ["FAC_firesFoS_pendingVehList", _pl2];

    [_e, _slotIdx] call FAC_firesFoS_server_startImpactTracker;
};

FAC_firesFoS_server_onFiresVehicleFired = {
    // Fired EH: [unit, weapon, muzzle, mode, ammo, mag, projectile, gunner] — tolerate short _this (mods).
    params ["_unit", "_weapon", "_muzzle", "_mode", "_ammo", "_mag"];
    private _projectile = _this param [6, objNull];
    if (!isServer) exitWith {};
    private _veh = if (_unit isKindOf "Man") then { vehicle _unit } else { _unit };
    if (isNull _veh || {_veh isKindOf "Man"}) exitWith {};
    private _idx = _veh getVariable ["FAC_firesFoS_slotIndex", -1];
    if (_idx < 0) exitWith {};
    private _en = missionNamespace getVariable ["FAC_firesFoS_impactEnabled", []];
    if (_idx >= count _en) exitWith {};
    if (!(_en select _idx)) exitWith {};
    if !([_ammo] call FAC_firesFoS_fnc_ammoLooksLikeIndirect) exitWith {};

    _veh setVariable ["FAC_firesFoS_pendingImpact", nil, false];
    private _pl = missionNamespace getVariable ["FAC_firesFoS_pendingVehList", []];
    _pl = _pl - [_veh];
    missionNamespace setVariable ["FAC_firesFoS_pendingVehList", _pl];

    if (!isNull _projectile) then {
        [_projectile, _idx] call FAC_firesFoS_server_startImpactTracker;
    } else {
        // Artillery often reports objNull projectile — EntityCreated matches the shell to this piece.
        _veh setVariable ["FAC_firesFoS_pendingImpact", [time, _ammo], false];
        _pl = missionNamespace getVariable ["FAC_firesFoS_pendingVehList", []];
        if (!(_veh in _pl)) then { _pl pushBack _veh };
        missionNamespace setVariable ["FAC_firesFoS_pendingVehList", _pl];
    };
};

FAC_firesFoS_server_registerArtilleryPiece = {
    params [["_veh", objNull], ["_slotIdx", -1]];
    if (!isServer) exitWith {};
    if (isNull _veh || {_slotIdx < 0}) exitWith {};
    // Must replicate: clients need slot for local Fired / impact broadcast (false = server-only, broke MP).
    _veh setVariable ["FAC_firesFoS_slotIndex", _slotIdx, true];
    private _eh = _veh getVariable ["FAC_firesFoS_firedEh", -1];
    if (_eh >= 0) then { _veh removeEventHandler ["Fired", _eh] };
    private _id = _veh addEventHandler ["Fired", { _this call FAC_firesFoS_server_onFiresVehicleFired }];
    _veh setVariable ["FAC_firesFoS_firedEh", _id, false];
};

FADE_firesFoS_toggleImpactScreenSlot = {
    params ["_slotIdx", ["_player", objNull]];
    if (!isServer) exitWith {};
    private _arr = missionNamespace getVariable ["FAC_firesFoS_impactEnabled", []];
    if (_slotIdx < 0 || {_slotIdx >= count _arr}) exitWith {};
    private _next = !(_arr select _slotIdx);
    _arr set [_slotIdx, _next];
    missionNamespace setVariable ["FAC_firesFoS_impactEnabled", +_arr, true];
    private _msg = format ["FIRES: impact screen slot %1 %2.", _slotIdx + 1, if (_next) then {"ON"} else {"OFF"}];
    if (!isNull _player) then {
        [_msg] remoteExec ["systemChat", _player];
    };
};

FAC_firesFoS_server_setupImpactScreenActions = {
    if (!isServer) exitWith {};
    private _names = missionNamespace getVariable ["FADE_firesImpactScreenNames", []];
    {
        private _nm = _x;
        private _obj = missionNamespace getVariable [_nm, objNull];
        if (!isNull _obj) then {
            private _i = _forEachIndex;
            _obj removeAction (_obj getVariable ["FAC_firesFoS_actId", -1]);
            private _aid = _obj addAction [
                "<t color='#88CCFF'>Toggle impact screen (this position)</t>",
                {
                    params ["_target", "_caller", "_id", "_args"];
                    _args params ["_idx"];
                    [_idx, _caller] remoteExec ["FADE_firesFoS_toggleImpactScreenSlot", 2];
                },
                [_i],
                5,
                false,
                true,
                "",
                "",
                5
            ];
            _obj setVariable ["FAC_firesFoS_actId", _aid, false];
        };
    } forEach _names;
};

FAC_firesFoS_server_init = {
    if (!isServer) exitWith {};
    private _slots = missionNamespace getVariable ["FADE_firesPosNames", []];
    private _n = count _slots;
    private _en = missionNamespace getVariable ["FAC_firesFoS_impactEnabled", []];
    if !(_en isEqualType []) then { _en = [] };
    while { count _en < _n } do { _en pushBack true };
    if (count _en > _n) then { _en resize _n };
    missionNamespace setVariable ["FAC_firesFoS_impactEnabled", _en, true];
    missionNamespace setVariable ["FAC_firesFoS_rangeDroneNetId", "", true];
    [] call FAC_firesFoS_server_setupImpactScreenActions;

    if !(missionNamespace getVariable ["FAC_firesFoS_shellEhRegistered", false]) then {
        missionNamespace setVariable ["FAC_firesFoS_shellEhRegistered", true];
        addMissionEventHandler ["EntityCreated", { _this call FAC_firesFoS_server_onShellEntityCreated }];
    };

    addMissionEventHandler ["HandleDisconnect", {
        params ["_id", "_uid", "_name", "_jip", "_owner"];
        private _ou = missionNamespace getVariable ["FAC_firesFoS_droneOwnerUid", ""];
        if (_uid == _ou) then {
            [] call FADE_firesFoS_droneDespawnServer;
        };
    }];
};

};

if (hasInterface) then {

FAC_firesFoS_fnc_clientDroneStop = {
    if (!hasInterface) exitWith {};
    [] call FAC_firesFoS_fnc_stopDroneRtt;
};

FAC_firesFoS_fnc_resolveScreenBySlot = {
    params ["_slotIdx"];
    private _names = missionNamespace getVariable ["FADE_firesImpactScreenNames", []];
    if (_slotIdx < 0 || {_slotIdx >= count _names}) exitWith { objNull };
    private _nm = _names select _slotIdx;
    [_nm] call FAC_firesFoS_fnc_resolveEdenNamedObject
};

FAC_firesFoS_fnc_textureIndicesImpact = {
    private _a = missionNamespace getVariable ["FADE_firesImpactVideoTextureIndices", [0]];
    if !(_a isEqualType []) then { _a = [0] };
    if (count _a == 0) then { _a = [0] };
    // Only user-configured indices. Tripod / tablet models use extra indices for PiP or bezel quads — binding the same r2t to all of them tiles the feed.
    private _out = [];
    { if ((_x isEqualType 0) && {!(_x in _out)}) then { _out pushBack _x } } forEach _a;
    if (count _out == 0) then { [0] } else { _out }
};

// Must match working PiP/RTT monitors: #(argb,w,h,1)r2t(name,1.0) not r2t,name,1.0)
FAC_firesFoS_fnc_rttProceduralTex = {
    params [["_res", 512], ["_rttName", ""], ["_aspect", 1]];
    if (_rttName == "" || {!(_rttName isEqualType "")}) exitWith { "" };
    if (!(_aspect isEqualType 0)) then {
        _aspect = 1;
    } else {
        if (_aspect <= 0 || {_aspect > 20}) then { _aspect = 1 };
    };
    format ["#(argb,%1,%1,1)r2t(%2,%3)", _res, _rttName, _aspect]
};

FAC_firesFoS_fnc_applyRttGlobal = {
    params [["_obj", objNull], ["_tex", ""], ["_indices", [0]]];
    if (isNull _obj || {_tex == ""}) exitWith {};
    {
        _obj setObjectTextureGlobal [_x, _tex];
        _obj setObjectTexture [_x, _tex];
    } forEach _indices;
};

FAC_firesFoS_fnc_clearRttGlobal = {
    params [["_obj", objNull], ["_indices", [0]]];
    if (isNull _obj) exitWith {};
    { _obj setObjectTextureGlobal [_x, ""] } forEach _indices;
};

FAC_firesFoS_fnc_stopDroneRtt = {
    uiNamespace setVariable ["FAC_firesFoS_droneRttUseGunnerMem", false];
    uiNamespace setVariable ["FAC_firesFoS_droneGunnerSelA", nil];
    uiNamespace setVariable ["FAC_firesFoS_droneGunnerSelB", nil];
    private _cam = uiNamespace getVariable ["FAC_firesFoS_droneCam", objNull];
    if (!isNull _cam) then {
        _cam camCommit 0;
        _cam cameraEffect ["terminate", "back"];
        camDestroy _cam;
    };
    uiNamespace setVariable ["FAC_firesFoS_droneCam", nil];
    private _eh = uiNamespace getVariable ["FAC_firesFoS_droneFrameEh", -1];
    if (_eh >= 0) then {
        removeMissionEventHandler ["EachFrame", _eh];
    };
    uiNamespace setVariable ["FAC_firesFoS_droneFrameEh", -1];
    uiNamespace setVariable ["FAC_firesFoS_droneFrameCtr", 0];
    private _scr = missionNamespace getVariable ["FAC_firesFoS_droneScreenObj", objNull];
    if (isNull _scr) then { _scr = ["droneVideoScreen"] call FAC_firesFoS_fnc_resolveEdenNamedObject };
    if (!isNull _scr) then {
        [_scr, [0]] call FAC_firesFoS_fnc_clearRttGlobal;
    };
    missionNamespace setVariable ["FAC_firesFoS_droneScreenObj", nil];
    uiNamespace setVariable ["FAC_firesFoS_droneVeh", nil];
};

// Kept for remoteExec compatibility; briefing-screen drone RTT is disabled (see archive).
FAC_firesFoS_fnc_clientDroneSync = {
    [] call FAC_firesFoS_fnc_stopDroneRtt;
};

FAC_firesFoS_fnc_stopImpactRtt = {
    params ["_slotIdx"];
    private _cam = uiNamespace getVariable [format ["FAC_firesFoS_impCam%1", _slotIdx], objNull];
    if (!isNull _cam) then {
        _cam camCommit 0;
        _cam cameraEffect ["terminate", "BACK"];
        camDestroy _cam;
    };
    uiNamespace setVariable [format ["FAC_firesFoS_impCam%1", _slotIdx], nil];
    private _anchor = uiNamespace getVariable [format ["FAC_firesFoS_impAnchor%1", _slotIdx], objNull];
    if (!isNull _anchor) then {
        deleteVehicle _anchor;
    };
    uiNamespace setVariable [format ["FAC_firesFoS_impAnchor%1", _slotIdx], nil];
    private _hScript = uiNamespace getVariable [format ["FAC_firesFoS_impScript%1", _slotIdx], -1];
    if (_hScript isEqualType 0 && {_hScript >= 0} && {!scriptDone _hScript}) then { terminate _hScript };
    uiNamespace setVariable [format ["FAC_firesFoS_impScript%1", _slotIdx], -1];
    private _impScreen = [_slotIdx] call FAC_firesFoS_fnc_resolveScreenBySlot;
    if (!isNull _impScreen) then {
        [_impScreen, [] call FAC_firesFoS_fnc_textureIndicesImpact] call FAC_firesFoS_fnc_clearRttGlobal;
    };
};

FAC_firesFoS_fnc_clientImpactFeed = {
    params ["_slotIdx", "_impactASL", "_duration"];
    if (!hasInterface) exitWith {};
    if (_slotIdx < 0) exitWith {};
    private _scr = [_slotIdx] call FAC_firesFoS_fnc_resolveScreenBySlot;
    if (isNull _scr) exitWith {};

    [_slotIdx] call FAC_firesFoS_fnc_stopImpactRtt;

    private _en = missionNamespace getVariable ["FAC_firesFoS_impactEnabled", []];
    // If impactEnabled never replicated (rare JIP race), still show feed when slot index is valid.
    if (count _en > 0) then {
        if (_slotIdx >= count _en || {!(_en select _slotIdx)}) exitWith {};
    };

    sleep 0.05;

    private _rtt = format ["%1%2", FAC_FiresFoS_IMPACT_RTT_PREFIX, _slotIdx];
    private _resI = round (missionNamespace getVariable ["FADE_firesImpactVideoRttResolution", 512]);
    if (_resI < 512) then { _resI = 512 };
    if (_resI > 1024) then { _resI = 1024 };

    private _asp = missionNamespace getVariable ["FADE_firesImpactRttAspect", 1];
    if (!(_asp isEqualType 0) || {_asp <= 0} || {_asp > 4}) then { _asp = 1 };
    private _tex = [_resI, _rtt, _asp] call FAC_firesFoS_fnc_rttProceduralTex;

    private _anchor = "Land_HelipadEmpty_F" createVehicleLocal [0, 0, 0];
    if (!isNull _anchor) then {
        _anchor setPosASL _impactASL;
        _anchor enableSimulation false;
        uiNamespace setVariable [format ["FAC_firesFoS_impAnchor%1", _slotIdx], _anchor];
    };

    private _preloadPos = if (!isNull _anchor) then { getPosATL _anchor } else { ASLtoATL _impactASL };
    preloadCamera _preloadPos;

    private _idxList = [] call FAC_firesFoS_fnc_textureIndicesImpact;

    private _camH = round (missionNamespace getVariable ["FADE_firesImpactCamHeightM", 90]);
    if (_camH < 25) then { _camH = 90 };
    private _camPosASL = _impactASL vectorAdd [0, 0, _camH];
    private _cam = "camera" camCreate [0, 0, 0];
    uiNamespace setVariable [format ["FAC_firesFoS_impCam%1", _slotIdx], _cam];

    _cam setPosASL _camPosASL;
    private _aimASL = if (!isNull _anchor) then { getPosASL _anchor } else { _impactASL };
    private _look = vectorNormalized (_aimASL vectorDiff _camPosASL);
    if ((vectorMagnitude _look) < 1e-4) then { _look = [0, 0, -1] };
    private _worldUp = [0, 0, 1];
    if ((abs (_look vectorDotProduct _worldUp)) > 0.95) then { _worldUp = [0, 1, 0] };
    private _right = vectorNormalized (_worldUp vectorCrossProduct _look);
    private _up = vectorNormalized (_look vectorCrossProduct _right);
    _cam setVectorDirAndUp [_look, _up];
    _cam camSetFov 0.55;
    _cam camCommit 0;
    // Bind RTT first, then apply procedural texture to the screen (order avoids persistent black on tripod props).
    _cam cameraEffect ["Internal", "BACK", _rtt];
    sleep 0.05;
    [_scr, _tex, _idxList] call FAC_firesFoS_fnc_applyRttGlobal;
    [_scr, _tex, _idxList] spawn {
        params ["_scr", "_tex", "_idxList"];
        sleep 0.12;
        if (!hasInterface || {isNull _scr} || {_tex == ""}) exitWith {};
        [_scr, _tex, _idxList] call FAC_firesFoS_fnc_applyRttGlobal;
    };

    private _sp = [_duration, _slotIdx] spawn {
        params ["_dur", "_slot"];
        sleep _dur;
        [_slot] call FAC_firesFoS_fnc_stopImpactRtt;
    };
    uiNamespace setVariable [format ["FAC_firesFoS_impScript%1", _slotIdx], _sp];
};

// MP: shells + Fired often exist only on the shooter's machine; dedicated server never tracks them. Track locally, broadcast feed.
FAC_firesFoS_fnc_client_startImpactTracker = {
    params ["_p", "_slotIdx"];
    if (!hasInterface) exitWith {};
    if (_slotIdx < 0) exitWith {};
    if (isNull _p) exitWith {};
    private _nid = netId _p;
    if (_nid != "") then {
        private _hm = uiNamespace getVariable ["FAC_firesFoS_clientTrackedShells", nil];
        if (isNil "_hm" || {!(_hm isEqualType createHashMap)}) then { _hm = createHashMap };
        if (_hm getOrDefault [_nid, false]) exitWith {};
        _hm set [_nid, true];
        uiNamespace setVariable ["FAC_firesFoS_clientTrackedShells", _hm];
    };
    private _snap = if (!isNull _p) then { getPosASL _p } else { [0, 0, 0] };
    [_p, _slotIdx, _nid, _snap] spawn {
        params ["_p", "_slotIdx", "_nid", "_snap"];
        private _last = _snap;
        private _tEnd = time + 120;
        private _trk = missionNamespace getVariable ["FADE_firesProjectileTrackSleep", 0.1];
        if (_trk < 0.03) then { _trk = 0.03 };
        if (_trk > 0.5) then { _trk = 0.5 };
        while {
            time < _tEnd && {!isNull _p}
        } do {
            _last = getPosASL _p;
            sleep _trk;
        };
        private _impact = if (!isNull _p) then { getPosASL _p } else { _last };
        if ((_impact select 0) == 0 && {(_impact select 1) == 0}) exitWith {
            if (_nid != "") then {
                private _hmZ = uiNamespace getVariable ["FAC_firesFoS_clientTrackedShells", createHashMap];
                _hmZ deleteAt _nid;
                uiNamespace setVariable ["FAC_firesFoS_clientTrackedShells", _hmZ];
            };
        };
        private _dur = missionNamespace getVariable ["FADE_firesImpactFeedDuration", 10];
        [_slotIdx, _impact, _dur] remoteExec ["FAC_firesFoS_fnc_server_pushImpactFeed", 2];
        if (_nid != "") then {
            private _hm2 = uiNamespace getVariable ["FAC_firesFoS_clientTrackedShells", createHashMap];
            _hm2 deleteAt _nid;
            uiNamespace setVariable ["FAC_firesFoS_clientTrackedShells", _hm2];
        };
    };
};

// Replicated slot var or match FIRES GUI state by netId (same order as FADE_firesPosNames).
FAC_firesFoS_fnc_client_resolveSlotIdxForVehicle = {
    params [["_veh", objNull]];
    if (isNull _veh || {_veh isKindOf "Man"}) exitWith { -1 };
    private _idx = _veh getVariable ["FAC_firesFoS_slotIndex", -1];
    if (_idx >= 0) exitWith { _idx };
    private _nid = netId _veh;
    if (_nid == "" || {!(_nid isEqualType "")}) exitWith { -1 };
    private _st = missionNamespace getVariable ["FAC_fires_clientState", []];
    if (!(_st isEqualType []) || {count _st == 0}) exitWith { -1 };
    private _i = _st findIf {
        (_x isEqualType []) && {count _x > 3} && {(_x select 3) isEqualType ""} && {(_x select 3) == _nid}
    };
    if (_i < 0) exitWith { -1 };
    _i
};

FAC_firesFoS_fnc_client_registerShellCreatedEh = {
    if (!hasInterface) exitWith {};
    if (missionNamespace getVariable ["FAC_firesFoS_clientShellEhReg", false]) exitWith {};
    missionNamespace setVariable ["FAC_firesFoS_clientShellEhReg", true];
    addMissionEventHandler ["EntityCreated", { _this call FAC_firesFoS_fnc_client_onShellEntityCreated }];
};

FAC_firesFoS_fnc_client_onShellEntityCreated = {
    if (!hasInterface) exitWith {};
    private _pend = missionNamespace getVariable ["FAC_firesFoS_clientShellPending", []];
    if (!(_pend isEqualType []) || {count _pend < 2}) exitWith {};
    _pend params ["_t0", "_slotIdx", ["_ammoF", ""]];
    if (time - _t0 > 3) exitWith {
        missionNamespace setVariable ["FAC_firesFoS_clientShellPending", nil, false];
    };
    private _e = if (_this isEqualType []) then { _this param [0, objNull] } else { _this };
    if (isNull _e) exitWith {};
    private _cls = typeOf _e;
    private _cfgA = configFile >> "CfgAmmo" >> _cls;
    if (!isClass _cfgA) exitWith {};
    private _sim = toLower getText (_cfgA >> "simulation");
    if (_sim == "shotbullet") exitWith {};
    if (((_sim find "shot") < 0) && {(_sim find "shell") < 0} && {(_sim find "submunition") < 0}) exitWith {};
    if !([_cls] call FAC_firesFoS_fnc_ammoLooksLikeIndirect) exitWith {};
    private _veh = vehicle player;
    if (isNull _veh || {_veh isKindOf "Man"}) exitWith {};
    if ([_veh] call FAC_firesFoS_fnc_client_resolveSlotIdxForVehicle != _slotIdx) exitWith {};
    if (_veh distance2D _e > 80) exitWith {};
    if (_ammoF != "") then {
        private _ammoOk = (_cls == _ammoF) || {_cls find _ammoF >= 0} || {_ammoF find _cls >= 0};
        if (!_ammoOk) exitWith {};
    };
    missionNamespace setVariable ["FAC_firesFoS_clientShellPending", nil, false];
    [_e, _slotIdx] call FAC_firesFoS_fnc_client_startImpactTracker;
};

FAC_firesFoS_fnc_client_tryRemoveVehFiredEh = {
    params [["_veh", objNull]];
    if (!hasInterface) exitWith {};
    if (isNull _veh || {_veh isKindOf "Man"}) exitWith {};
    private _id = _veh getVariable ["FAC_firesFoS_clientVehFiredEh", -1];
    if (_id >= 0) then {
        _veh removeEventHandler ["Fired", _id];
        _veh setVariable ["FAC_firesFoS_clientVehFiredEh", -1, false];
    };
};

// Static mortars often trigger Fired on the weapon, not the gunner unit.
FAC_firesFoS_fnc_client_tryInstallVehFiredEh = {
    params [["_veh", objNull]];
    if (!hasInterface) exitWith {};
    if (isNull _veh || {_veh isKindOf "Man"}) exitWith {};
    if ([_veh] call FAC_firesFoS_fnc_client_resolveSlotIdxForVehicle < 0) exitWith {};
    private _id = _veh getVariable ["FAC_firesFoS_clientVehFiredEh", -1];
    if (_id >= 0) exitWith {};
    _id = _veh addEventHandler ["Fired", { _this call FAC_firesFoS_fnc_client_onPlayerFired }];
    _veh setVariable ["FAC_firesFoS_clientVehFiredEh", _id, false];
};

FAC_firesFoS_fnc_client_onPlayerFired = {
    if (!hasInterface) exitWith {};
    _this params ["_unit", "_weapon", "_muzzle", "_mode", "_ammo", "_mag"];
    private _projectile = _this param [6, objNull];
    private _veh = vehicle _unit;
    if (isNull _veh || {_veh isKindOf "Man"}) exitWith {};
    private _idx = [_veh] call FAC_firesFoS_fnc_client_resolveSlotIdxForVehicle;
    if (_idx < 0) exitWith {};
    private _en = missionNamespace getVariable ["FAC_firesFoS_impactEnabled", []];
    if (_idx >= count _en || {!(_en select _idx)}) exitWith {};
    if !([_ammo] call FAC_firesFoS_fnc_ammoLooksLikeIndirect) exitWith {};
    if (isNull _projectile) then {
        missionNamespace setVariable ["FAC_firesFoS_clientShellPending", [time, _idx, _ammo], false];
    } else {
        [_projectile, _idx] call FAC_firesFoS_fnc_client_startImpactTracker;
    };
};

FAC_firesFoS_fnc_client_installFiresFiredEh = {
    params [["_u", player]];
    if (!hasInterface) exitWith {};
    if (isNull _u) exitWith {};
    [] call FAC_firesFoS_fnc_client_registerShellCreatedEh;
    private _id = _u getVariable ["FAC_firesFoS_clientFiredEh", -1];
    if (_id >= 0) then { _u removeEventHandler ["Fired", _id] };
    _id = _u addEventHandler ["Fired", { _this call FAC_firesFoS_fnc_client_onPlayerFired }];
    _u setVariable ["FAC_firesFoS_clientFiredEh", _id, false];
    private _gi = _u getVariable ["FAC_firesFoS_clientGetInEh", -1];
    if (_gi >= 0) then { _u removeEventHandler ["GetInMan", _gi] };
    private _go = _u getVariable ["FAC_firesFoS_clientGetOutEh", -1];
    if (_go >= 0) then { _u removeEventHandler ["GetOutMan", _go] };
    _gi = _u addEventHandler ["GetInMan", {
        _this params ["_veh", "_role", "_unit", "_turret"];
        [_veh] call FAC_firesFoS_fnc_client_tryInstallVehFiredEh;
    }];
    _u setVariable ["FAC_firesFoS_clientGetInEh", _gi, false];
    _go = _u addEventHandler ["GetOutMan", {
        _this params ["_veh", "_role", "_unit", "_turret"];
        [_veh] call FAC_firesFoS_fnc_client_tryRemoveVehFiredEh;
    }];
    _u setVariable ["FAC_firesFoS_clientGetOutEh", _go, false];
    [] spawn {
        sleep 0.3;
        if (isNull player) exitWith {};
        private _v = vehicle player;
        if (!isNull _v && {!(_v isKindOf "Man")}) then { [_v] call FAC_firesFoS_fnc_client_tryInstallVehFiredEh };
        sleep 1.2;
        if (isNull player) exitWith {};
        _v = vehicle player;
        if (!isNull _v && {!(_v isKindOf "Man")}) then { [_v] call FAC_firesFoS_fnc_client_tryInstallVehFiredEh };
    };
};

FAC_firesFoS_fnc_startMapClickDrone = {
    if (!hasInterface) exitWith {};
    hint "Map: click where the observer drone should hover (high altitude). ESC to cancel.";
    openMap true;
    private _eh = addMissionEventHandler ["MapSingleClick", {
        params ["_units", "_pos", "_alt", "_shift"];
        removeMissionEventHandler ["MapSingleClick", _thisEventHandler];
        openMap false;
        missionNamespace setVariable ["FAC_firesFoS_mapClickPending", false];
        private _clickPos = _pos;
        if (!(_clickPos isEqualType []) || {count _clickPos < 2}) then {
            _clickPos = _units;
        };
        if (!(_clickPos isEqualType []) || {count _clickPos < 2}) exitWith { hintSilent "" };
        [_clickPos, player] remoteExec ["FADE_firesFoS_droneSpawnRequest", 2];
        hintSilent "";
    }];
    missionNamespace setVariable ["FAC_firesFoS_mapEh", _eh];
    missionNamespace setVariable ["FAC_firesFoS_mapClickPending", true];
};

FAC_firesFoS_fnc_cancelMapClickDrone = {
    private _eh = missionNamespace getVariable ["FAC_firesFoS_mapEh", -1];
    if (_eh >= 0) then {
        removeMissionEventHandler ["MapSingleClick", _eh];
    };
    missionNamespace setVariable ["FAC_firesFoS_mapEh", -1];
    missionNamespace setVariable ["FAC_firesFoS_mapClickPending", false];
};

    [] spawn {
        waitUntil { sleep 0.05; !isNull player };
        [player] call FAC_firesFoS_fnc_client_installFiresFiredEh;
    };

};
