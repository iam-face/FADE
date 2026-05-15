// =============================================================================
// FADE_IntelServer.sqf -- Building intel: spawn on VG activation, read on server (server)
// =============================================================================
// Loaded from initServer after FADE_VirtualGarrison.sqf.
// Client hold + remoteExec: rsc\FADE_IntelClient.sqf (initPlayerLocal).
// If the prop is removed another way (e.g. ACE Intel Items "pick up"), server Deleted EH attributes nearby BLUFOR and runs the same consume path.
// =============================================================================

if (!isServer) exitWith {};

FADE_intel_cardinalTo = {
    params ["_fromPos", "_toPos"];
    if (count _fromPos < 2 || count _toPos < 2) exitWith { "unknown" };
    private _d = [_fromPos, _toPos] call BIS_fnc_dirTo;
    private _i = (round (_d / 45)) mod 8;
    ["N", "NE", "E", "SE", "S", "SW", "W", "NW"] select _i
};

// Live intel lines from world state (generate-on-read). Returns [lines, optionalMarkerPos].
FADE_intel_buildLines = {
    params ["_center", "_radiusM"];
    if (count _center < 2) exitWith { [["Invalid intel sector."], []] };
    private _cc = +_center;
    if (count _cc < 3) then { _cc set [2, 0] };
    private _r = _radiusM max 100;
    private _sideE = missionNamespace getVariable ["FADE_sideEnemy", east];
    private _lines = [];
    private _markerPos = [];

    private _pendingMen = 0;
    if (!(isNil "FADE_vg_pending") && { !(isNil "FADE_vg_entryAnchor") }) then {
        {
            private _e = _x;
            private _a = [_e] call FADE_vg_entryAnchor;
            if (count _a >= 2 && { (_a distance2D _cc) <= _r }) then {
                _pendingMen = _pendingMen + count (_e get "positions");
            };
        } forEach FADE_vg_pending;
    };

    private _enyDismounts = 0;
    {
        if (alive _x && { side _x == _sideE } && { _x isKindOf "Man" } && { (_x distance2D _cc) <= _r }) then {
            _enyDismounts = _enyDismounts + 1;
        };
    } forEach allUnits;

    private _vehCandidates = (nearestObjects [_cc, ["AllVehicles"], _r, false]) select {
        !isNull _x && { alive _x } && { side _x == _sideE } && {
            !(_x isKindOf "StaticWeapon")
        } && {
            private _crew = crew _x;
            (count _crew > 0) || { _x isKindOf "Tank" } || { _x isKindOf "Car" } || { _x isKindOf "Truck_F" }
        }
    };

    private _rbCenters = [];
    {
        private _e = (missionNamespace getVariable ["FADE_dynamicRoadblockState", createHashMap]) get _x;
        if (_e isEqualType [] && { count _e >= 1 }) then {
            private _c = _e select 0;
            if (_c isEqualType [] && { count _c >= 2 && { (_c distance2D _cc) <= _r } }) then {
                _rbCenters pushBack _c;
            };
        };
    } forEach keys (missionNamespace getVariable ["FADE_dynamicRoadblockState", createHashMap]);

    private _roll = random 1;
    private _specificBias = missionNamespace getVariable ["FADE_intelSpecificLineChance", 0.42];

    if (count _vehCandidates > 0 && { _roll < _specificBias }) then {
        private _v = selectRandom _vehCandidates;
        private _cls = typeOf _v;
        private _dn = getText (configFile >> "CfgVehicles" >> _cls >> "displayName");
        if (_dn == "") then { _dn = _cls };
        _lines pushBack format ["Contact: %1 at grid %2.", _dn, mapGridPosition _v];
        _markerPos = getPosATL _v;
    };

    if (count _rbCenters > 0 && { count _lines < 3 && { random 1 < 0.5 } }) then {
        private _rb = selectRandom _rbCenters;
        _lines pushBack format ["Road network: obstruction / watch reported near grid %1.", mapGridPosition _rb];
    };

    if (_pendingMen > 0 && { count _lines < 3 && { random 1 < 0.65 } }) then {
        _lines pushBack format ["Garrison traffic: ~%1 OPFOR positions still tied to structures in sector (pending or active).", _pendingMen];
    };

    if (_enyDismounts > 0 && { count _lines < 3 }) then {
        _lines pushBack format ["Dismounted OPFOR headcount in sector (live): ~%1.", _enyDismounts];
    };

    private _gm = missionNamespace getVariable ["FADE_globalMission", []];
    private _gt = _gm param [0, ""];
    if (_gt == "Operation" && { count _lines < 3 && { random 1 < 0.7 } }) then {
        _lines pushBack "Higher: OPFOR shifts quick-reaction traffic between contested zones when engaged.";
    };
    if (_gt == "EscapeEvasion" && { count _lines < 3 && { random 1 < 0.55 } }) then {
        _lines pushBack "Source: truck-mounted QRF on a long cycle after confirmed contact in the town belt.";
    };

    if (count _lines == 0) then {
        _lines pushBack "No indexed hostile contacts in this sector at read time — area may be clear or outside collection radius.";
    };

    private _maxL = (missionNamespace getVariable ["FADE_intelMaxLinesPerRead", 3]) max 1 min 5;
    if (count _lines > _maxL) then { _lines resize _maxL };
    private _stillContact = _lines findIf { _x find "Contact:" == 0 } >= 0;
    if (!_stillContact) then { _markerPos = [] };
    [_lines, _markerPos]
};

FADE_intel_isSpecialist = {
    params [["_u", objNull]];
    !isNull _u && { _u getVariable ["FADE_intelSpecialist", false] }
};

FADE_intel_getCarryPackages = {
    params [["_u", objNull]];
    if (isNull _u) exitWith { [] };
    private _pk = _u getVariable ["FADE_intelCarryPackages", []];
    if (!(_pk isEqualType [])) then { _pk = [] };
    _pk
};

FADE_intel_setCarryPackages = {
    params [["_u", objNull], ["_pk", []]];
    if (isNull _u) exitWith {};
    if (!(_pk isEqualType [])) then { _pk = [] };
    _u setVariable ["FADE_intelCarryPackages", _pk, true];
    _u setVariable ["FADE_intelCarryCount", count _pk, true];
};

FADE_intel_revealPackage = {
    params [["_reader", objNull], ["_pkg", []], ["_sourceLabel", ""]];
    if (isNull _reader || { !isPlayer _reader }) exitWith {};
    if (!(_pkg isEqualType []) || { count _pkg < 2 }) exitWith {};
    private _center = _pkg param [0, []];
    if (count _center < 2) exitWith {};
    private _rad = _pkg param [1, missionNamespace getVariable ["FADE_intelScopeRadiusM", 1200]];
    private _built = [_center, _rad] call FADE_intel_buildLines;
    _built params ["_lines", "_markerPos"];
    private _body = "";
    {
        _body = _body + format ["<t color='#E0E0E0' align='left'>%1</t><br/><br/>", _x];
    } forEach _lines;
    private _src = if (_sourceLabel != "") then {
        format ["<t color='#A0B4C8' size='0.9'>Source: %1</t><br/><br/>", _sourceLabel]
    } else {
        ""
    };
    private _hint = format ["<t size='1.15' color='#87CEEB'>INTEL</t><br/><br/>%1%2", _src, _body];

    private _broadcast = missionNamespace getVariable ["FADE_intelBroadcastToGroup", true];
    private _recipients = if (_broadcast) then {
        (units group _reader) select {
            isPlayer _x && { alive _x } && { side group _x == missionNamespace getVariable ["FADE_sideFriendly", west] }
        };
    } else {
        [_reader]
    };
    {
        [_hint] remoteExec ["FADE_showMissionHint", _x];
    } forEach _recipients;

    private _logDiary = missionNamespace getVariable ["FADE_intelDiaryLog", true];
    if (_logDiary && { count _lines > 0 }) then {
        private _whenStr = format ["Mission +%1 min", floor (time / 60) max 0];
        private _bodyRaw = _lines joinString (toString [10]);
        private _kindStr = if (_sourceLabel != "") then { _sourceLabel } else { "Sector read" };
        {
            ["Building intel", _whenStr, _bodyRaw, _kindStr] remoteExec ["FADE_intel_clientAppendIntelDiary", _x];
        } forEach _recipients;
    };

    if (missionNamespace getVariable ["FADE_intelMapMarkerOnSpecific", true] && { count _markerPos >= 2 }) then {
        private _ttl = (missionNamespace getVariable ["FADE_intelMapMarkerTTL", 480]) max 30;
        private _nid = missionNamespace getVariable ["FADE_intelNextMarkerId", 0];
        missionNamespace setVariable ["FADE_intelNextMarkerId", _nid + 1];
        private _mname = format ["FADE_intel_m_%1_%2", _nid, floor (random 1e6)];
        private _mk = createMarker [_mname, _markerPos];
        _mk setMarkerType "mil_unknown";
        _mk setMarkerColor "ColorOPFOR";
        _mk setMarkerText "Intel (approx.)";
        [_mname, _ttl] spawn {
            params ["_mn", "_t"];
            sleep _t;
            if (getMarkerColor _mn != "") then { deleteMarker _mn };
        };
    };
};

// _deleteAfter: true = normal hold read (delete prop here). false = prop already being deleted (ACE pickup, etc.).
// _distSlackM: extra metres allowed on distance check (pickup path uses small slack so timing/position jitter does not fail).
// _revealSource: diary/hint "Source" line for revealPackage.
FADE_intel_serverConsumeIntel = {
    if (!isServer) exitWith {};
    params [
        ["_obj", objNull],
        ["_player", objNull],
        ["_deleteAfter", true],
        ["_revealSource", "On-site read"],
        ["_distSlackM", 0]
    ];
    if (isNull _obj || { isNull _player } || { !isPlayer _player } || { !alive _player }) exitWith {};
    if (!(_obj getVariable ["FADE_intelProp", false])) exitWith {};

    if (_obj getVariable ["FADE_intelConsumed", false]) exitWith {
        if (_deleteAfter) then {
            private _msg = "<t size='1.05' color='#AAAAAA'>INTEL</t><br/><br/><t color='#E0E0E0'>Already recovered or stale.</t>";
            [_msg] remoteExec ["FADE_showMissionHint", _player];
        };
    };

    private _maxD = (_obj getVariable ["FADE_intelInteractDistM", missionNamespace getVariable ["FADE_intelInteractDistM", 6]]) + _distSlackM;
    if ((_player distance _obj) > _maxD) exitWith {};

    if (side group _player != missionNamespace getVariable ["FADE_sideFriendly", west]) exitWith {};

    _obj setVariable ["FADE_intelConsumed", true, true];
    private _center = _obj getVariable ["FADE_intelQueryCenter", []];
    if (count _center < 2) then { _center = getPosATL _obj };
    private _rad = _obj getVariable ["FADE_intelScopeRadiusM", missionNamespace getVariable ["FADE_intelScopeRadiusM", 1200]];
    private _pkg = [_center, _rad];
    private _specOnly = missionNamespace getVariable ["FADE_intelSpecialistsOnly", false];
    if (_specOnly && { !([_player] call FADE_intel_isSpecialist) }) then {
        private _cur = [_player] call FADE_intel_getCarryPackages;
        _cur pushBack _pkg;
        [_player, _cur] call FADE_intel_setCarryPackages;
        private _q = count _cur;
        private _msg = format [
            "<t size='1.05' color='#FFCC66'>INTEL STORED</t><br/><br/><t color='#E0E0E0'>You secured an intel package.</t><br/><t color='#E0E0E0'>Carry count: %1</t><br/><br/><t color='#BFD7EA'>Deliver at HQ (within 50 m) or hand it to an Intel specialist.</t>",
            _q
        ];
        [_msg] remoteExec ["FADE_showMissionHint", _player];
    } else {
        [_player, _pkg, _revealSource] call FADE_intel_revealPackage;
    };

    if (_deleteAfter && {!isNull _obj}) then { deleteVehicle _obj };
};

missionNamespace setVariable ["FADE_intel_serverConsumeIntel", FADE_intel_serverConsumeIntel];

FADE_intel_serverTryRead = {
    if (!isServer) exitWith {};
    params [["_obj", objNull], ["_player", objNull]];
    [_obj, _player, true, "On-site read", 0] call FADE_intel_serverConsumeIntel;
};

missionNamespace setVariable ["FADE_intel_serverTryRead", FADE_intel_serverTryRead];

FADE_intel_serverDeliverAtBase = {
    if (!isServer) exitWith {};
    params [["_player", objNull]];
    if (isNull _player || { !isPlayer _player } || { !alive _player }) exitWith {};
    private _pk = [_player] call FADE_intel_getCarryPackages;
    if (_pk isEqualTo []) exitWith {};
    private _base = missionNamespace getVariable ["FADE_basePos", []];
    if (count _base < 2) exitWith {};
    if ((_player distance2D _base) > 50) exitWith {
        ["<t size='1.05' color='#FFAA66'>INTEL</t><br/><br/><t color='#E0E0E0'>You must be within 50 m of HQ to process carried intel.</t>"] remoteExec ["FADE_showMissionHint", _player];
    };
    private _pkg = _pk deleteAt 0;
    [_player, _pk] call FADE_intel_setCarryPackages;
    [_player, _pkg, "HQ analysis"] call FADE_intel_revealPackage;
};

missionNamespace setVariable ["FADE_intel_serverDeliverAtBase", FADE_intel_serverDeliverAtBase];

FADE_intel_serverTransferToSpecialist = {
    if (!isServer) exitWith {};
    params [["_giver", objNull], ["_specialist", objNull]];
    if (isNull _giver || { isNull _specialist }) exitWith {};
    if (!isPlayer _giver || { !isPlayer _specialist } || { !alive _giver } || { !alive _specialist }) exitWith {};
    if ((_giver distance _specialist) > 4) exitWith {};
    if (side group _giver != missionNamespace getVariable ["FADE_sideFriendly", west]) exitWith {};
    if (side group _specialist != missionNamespace getVariable ["FADE_sideFriendly", west]) exitWith {};
    if !([_specialist] call FADE_intel_isSpecialist) exitWith {
        ["<t size='1.05' color='#FFAA66'>INTEL</t><br/><br/><t color='#E0E0E0'>Target player is not marked as an Intel specialist.</t>"] remoteExec ["FADE_showMissionHint", _giver];
    };
    private _pk = [_giver] call FADE_intel_getCarryPackages;
    if (_pk isEqualTo []) exitWith {};
    private _pkg = _pk deleteAt 0;
    [_giver, _pk] call FADE_intel_setCarryPackages;
    [format ["You handed one intel package to %1.", name _specialist]] remoteExec ["systemChat", _giver];
    [format ["%1 handed you an intel package.", name _giver]] remoteExec ["systemChat", _specialist];
    [_specialist, _pkg, format ["Field handoff from %1", name _giver]] call FADE_intel_revealPackage;
};

missionNamespace setVariable ["FADE_intel_serverTransferToSpecialist", FADE_intel_serverTransferToSpecialist];

// Called from FADE_vg_spawnOne when a garrison activates.
FADE_intel_onVgSpawned = {
    // _vgEntry: VG hash map — do not reuse name "_entry" inside forEach _pool (private overwrites outer scope).
    params ["_vgEntry", "_grp", "_building"];
    if (!(missionNamespace getVariable ["FADE_intelEnabled", true])) exitWith {};
    if (isNull _grp || { count units _grp == 0 }) exitWith {};
    private _chance = missionNamespace getVariable ["FADE_intelSpawnChanceOnGarrison", 0.5];
    if (random 1 > _chance) exitWith {};

    private _positions = _vgEntry get "positions";
    if (!(_positions isEqualType []) || { count _positions == 0 }) exitWith {};

    private _p = + (selectRandom _positions);
    if (count _p < 3) then { _p set [2, 0] };
    _p set [2, (_p select 2) + 0.05];

    // Pool from mission namespace; mirror global if Config used bare assignment (JIP / load order).
    private _pool = missionNamespace getVariable ["FADE_intelObjectClasses", []];
    if (!(_pool isEqualType [])) then { _pool = [] };
    if (count _pool == 0 && { !isNil "FADE_intelObjectClasses" } && { FADE_intelObjectClasses isEqualType [] }) then {
        _pool = +FADE_intelObjectClasses;
    };
    if (count _pool == 0 && { !isNil "FADE_intelObjectClass" } && { FADE_intelObjectClass isEqualType "" }) then {
        _pool = [FADE_intelObjectClass];
    };
    // One resolved CfgVehicles class per configured prop (try alternates where vanilla uses different names).
    private _resolved = [];
    {
        private _poolCls = _x;
        if (_poolCls isEqualType "") then {
            // ACE Intel Items hooks BIS "Intel_*" world props; pickup without ACE intel data yields a blank map diary entry.
            if ((toLower _poolCls) find "intel_" == 0) exitWith {};
            private _tries = +[_poolCls];
            if (_poolCls == "Clipboard_F") then { _tries pushBack "Land_Clipboard_F" };
            private _pick = "";
            {
                private _cand = _x;
                if (isClass (configFile >> "CfgVehicles" >> _cand)) exitWith { _pick = _cand };
            } forEach _tries;
            if (_pick != "") then { _resolved pushBack _pick };
        };
    } forEach _pool;
    private _fallbacks = ["Land_SatellitePhone_F", "Land_MobilePhone_smart_F"];
    if (_resolved isEqualTo []) then {
        private _fb = _fallbacks select { isClass (configFile >> "CfgVehicles" >> _x) };
        if (count _fb > 0) then { _resolved = _fb };
    };
    if (_resolved isEqualTo []) exitWith {};
    private _cls = selectRandom _resolved;

    private _intel = createVehicle [_cls, [0, 0, 0], [], 0, "CAN_COLLIDE"];
    if (isNull _intel) exitWith {};
    _intel setPosATL _p;
    _intel enableSimulationGlobal false;

    private _anchor = if (isNil "FADE_vg_entryAnchor") then { getPosATL _intel } else { [_vgEntry] call FADE_vg_entryAnchor };
    if (count _anchor < 2) then { _anchor = getPosATL _intel };
    if (count _anchor < 3) then { _anchor set [2, 0] };

    _intel setVariable ["FADE_intelProp", true, true];
    _intel setVariable ["FADE_intelQueryCenter", _anchor, true];
    _intel setVariable ["FADE_intelScopeRadiusM", missionNamespace getVariable ["FADE_intelScopeRadiusM", 1200], true];
    _intel setVariable ["FADE_intelInteractDistM", missionNamespace getVariable ["FADE_intelInteractDistM", 6], true];
    _intel setVariable ["FADE_intelConsumed", false, true];

    _intel addEventHandler ["Deleted", {
        params ["_entity"];
        if (!isServer) exitWith {};
        if (isNull _entity) exitWith {};
        if (_entity getVariable ["FADE_intelConsumed", false]) exitWith {};
        if (!(_entity getVariable ["FADE_intelProp", false])) exitWith {};
        private _baseD = _entity getVariable ["FADE_intelInteractDistM", missionNamespace getVariable ["FADE_intelInteractDistM", 6]];
        private _claimDist = _baseD + 2;
        private _pos = getPosATL _entity;
        private _sideF = missionNamespace getVariable ["FADE_sideFriendly", west];
        private _claim = objNull;
        private _best = 1e12;
        {
            if (isPlayer _x && { alive _x } && { side group _x == _sideF }) then {
                private _d = _x distance2D _pos;
                if (_d <= _claimDist && { _d < _best }) then {
                    _best = _d;
                    _claim = _x;
                };
            };
        } forEach allPlayers;
        if (isNull _claim) exitWith {};
        [_entity, _claim, false, "Recovered on site (pickup)", 2] call FADE_intel_serverConsumeIntel;
    }];

    [_intel] remoteExec ["FADE_intel_clientRegister", 0, true];
};

missionNamespace setVariable ["FADE_intel_onVgSpawned", FADE_intel_onVgSpawned];
