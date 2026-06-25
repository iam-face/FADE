// Surrender Challenge debug: set true to show verbose server messages in chat (diag_log always in RPT)
FAC_surrenderChallenge_debug = false;
publicVariable "FAC_surrenderChallenge_debug";

// -----------------------------------------------------------------------------
// Surrender Challenge - server entry point
// -----------------------------------------------------------------------------
// Called via remoteExec from client. MUST be publicVariable so clients can
// invoke it. On dedicated server: clients send [player, target]; server runs
// SurrenderChallenge.sqf. execVM spawns script in new scope; server owns AI
// so disableAI/setBehaviour/doTarget work here. Path uses backslash for
// Windows mission folders; Arma accepts both.
// -----------------------------------------------------------------------------
FAC_surrenderChallenge_start = {
    if (!(missionNamespace getVariable ["FAC_surrenderChallenge_playerEnabled", false])) exitWith {};
    params ["_player", "_targetUnit", ["_playerDir", -1]];
    if (_playerDir < 0) then { _playerDir = getDir _player };
    diag_log format ["[FAC SurrenderChallenge] Server received request from %1 for target %2", name _player, if (isNull _targetUnit) then {"null"} else {name _targetUnit}];
    [_player, _targetUnit, _playerDir] execVM "rsc\SurrenderChallenge.sqf";
};
publicVariable "FAC_surrenderChallenge_start";

// -----------------------------------------------------------------------------
// Jukebox -- per-source playback: Radio_1..4 (Eden) and vehicle:<netId> (in-vehicle loudspeaker action).
// Clients attach a deletable sound source to the resolved emitter; FAC_jukebox_activeSources = [[key,song,vol,dist],...] on server, mirrored by playback RPCs on clients.
// No client-side JIP replay of activeSources (avoids duplicate 3D sound / random restarts on dedicated).
// remoteExec: [_song, _sourceKey, _requester, _vol, _dist] remoteExec ["FAC_jukebox_serverPlay", 2]
// Stop:        ["", _sourceKey, _requester] remoteExec ["FAC_jukebox_serverPlay", 2]
// Stop all:    [_requester] remoteExec ["FAC_jukebox_stopAllMusic", 2] -> [_sourceKeys] remoteExec ["FAC_jukebox_clientStopAll", 0]
// Debug: FAC_jukebox_debug - systemChat to requester + diag_log on server. true = verbose chat (dev only).
// -----------------------------------------------------------------------------
FAC_jukebox_debug = false;
publicVariable "FAC_jukebox_debug";

missionNamespace setVariable ["FAC_jukebox_activeSources", []];

FAC_jukebox_serverDbg = {
    params ["_msg", ["_to", objNull]];
    if (!isServer) exitWith {};
    diag_log format ["[FAC Jukebox] %1", _msg];
    if (!(missionNamespace getVariable ["FAC_jukebox_debug", false])) exitWith {};
    if (isNull _to) exitWith {};
    [_msg] remoteExec ["FAC_jukebox_serverDbgChat", _to];
};

// Resolve emitter: radio:Radio_1 -> missionNamespace object; vehicle:<netId> -> objectFromNetId
FAC_jukebox_fnc_resolveSourceObject = {
    params ["_sourceKey"];
    if (_sourceKey find "radio:" == 0) exitWith {
        private _eden = _sourceKey select [6];
        missionNamespace getVariable [_eden, objNull]
    };
    if (_sourceKey find "vehicle:" == 0) exitWith {
        private _nid = _sourceKey select [8];
        if (_nid == "") exitWith {objNull};
        objectFromNetId _nid
    };
    objNull
};

FAC_jukebox_fnc_requesterMayControlVehicleSource = {
    params [["_requester", objNull], ["_veh", objNull]];
    if (isNull _requester || {!isPlayer _requester} || {isNull _veh}) exitWith {false};
    _requester in crew _veh && { vehicle _requester == _veh }
};

FAC_jukebox_fnc_setActiveSourceSong = {
    params ["_key", "_song", ["_vol", 4], ["_dist", 400]];
    private _arr = missionNamespace getVariable ["FAC_jukebox_activeSources", []];
    private _filt = _arr select { (_x select 0) != _key };
    if (_song != "") then {
        _vol = ((round _vol) max 1) min 25;
        _dist = ((round _dist) max 50) min 2500;
        _filt pushBack [_key, _song, _vol, _dist];
    };
    missionNamespace setVariable ["FAC_jukebox_activeSources", _filt];
};


FAC_jukebox_serverPlay = {
    if (!isServer) exitWith {};
    params [["_song", ""], ["_sourceKey", ""], ["_requester", objNull], ["_vol", 4], ["_dist", 400]];

    if (_sourceKey == "") exitWith {
        diag_log "FAC_jukebox_serverPlay: empty _sourceKey";
    };

    if (_song == "") exitWith {
        [format ["Stopped source %1 (from %2)", _sourceKey, if (isNull _requester) then {"?"} else { name _requester }], _requester] call FAC_jukebox_serverDbg;
        [_sourceKey, ""] call FAC_jukebox_fnc_setActiveSourceSong;
        ["", _sourceKey] remoteExec ["FAC_jukebox_clientPlay", 0];
    };

    if (!isNull _requester && { isPlayer _requester }) then {
        if ([_requester, "FAC_playerCanUseJukebox", "Jukebox access denied by lobby settings."] call FAC_lobbyParams_serverDenyUnless) exitWith {};
    };

    private _emitter = [_sourceKey] call FAC_jukebox_fnc_resolveSourceObject;
    if (isNull _emitter) exitWith {
        diag_log format ["FAC_jukebox_serverPlay: no emitter for %1", _sourceKey];
        [format ["FAIL: jukebox source not available (%1).", _sourceKey], _requester] call FAC_jukebox_serverDbg;
    };

    private _civCarRadio = (_sourceKey find "vehicle:" == 0) && {
        _emitter getVariable ["FADE_civCarRadioOwned", false]
    };
    if (_sourceKey find "vehicle:" == 0 && {!_civCarRadio}) then {
        if (
            isNull _requester
            || {!([_requester, _emitter] call FAC_jukebox_fnc_requesterMayControlVehicleSource)}
        ) exitWith {
            diag_log "FAC_jukebox_serverPlay: vehicle source  -  requester not crew";
            ["FAIL: jukebox  -  you must be in that vehicle to use its loudspeaker.", _requester] call FAC_jukebox_serverDbg;
        };
    };

    _vol = ((round _vol) max 1) min 25;
    _dist = ((round _dist) max 50) min 2500;

    if (_song != "") then {
        private _cur = (missionNamespace getVariable ["FAC_jukebox_activeSources", []]) select { (_x select 0) == _sourceKey };
        if (
            count _cur > 0
            && { (_cur select 0) select 1 == _song }
            && { (_cur select 0) param [2, -1] == _vol }
            && { (_cur select 0) param [3, -1] == _dist }
        ) exitWith {
            [format ["SKIP duplicate play: %1 @ %2", _song, _sourceKey], _requester] call FAC_jukebox_serverDbg;
        };
        private _wasPlaying = _cur select { (_x select 1) != "" };
        if (count _wasPlaying > 0) then {
            [_sourceKey, ""] call FAC_jukebox_fnc_setActiveSourceSong;
            ["", _sourceKey] remoteExec ["FAC_jukebox_clientPlay", 0];
        };
    };

    private _sndCfg = missionConfigFile >> "CfgSounds" >> _song;
    if (!isClass _sndCfg) then { _sndCfg = configFile >> "CfgSounds" >> _song };
    if (!isClass _sndCfg) exitWith {
        diag_log format ["FAC_jukebox_serverPlay: CfgSounds %1 not found (missionConfigFile/configFile)", _song];
        [format ["FAIL: CfgSounds %1 missing (description.ext / mod).", _song], _requester] call FAC_jukebox_serverDbg;
    };

    [_sourceKey, _song, _vol, _dist] call FAC_jukebox_fnc_setActiveSourceSong;
    [format ["OK: %1 @ %2 (vol=%3 dist=%4)", _song, _sourceKey, _vol, _dist], _requester] call FAC_jukebox_serverDbg;
    [_song, _sourceKey, _vol, _dist] remoteExec ["FAC_jukebox_clientPlay", 0];

    if (_sourceKey find "vehicle:" == 0) then {
        [_emitter, _sourceKey] spawn {
            params ["_veh", "_key"];
            waitUntil { sleep 1; isNull _veh || {!alive _veh} };
            if (isNull _veh || {!alive _veh}) then {
                private _arr = missionNamespace getVariable ["FAC_jukebox_activeSources", []];
                private _hit = _arr select { (_x select 0) == _key && { (_x select 1) != "" } };
                if (!(_hit isEqualTo [])) then {
                    [_key, ""] call FAC_jukebox_fnc_setActiveSourceSong;
                    ["", _key] remoteExec ["FAC_jukebox_clientPlay", 0];
                };
            };
        };
    };
};
publicVariable "FAC_jukebox_serverPlay";

// FAC_jukebox_stopAllMusic: defined above (before FADE_adminCleanupAction).

// Mission test suite  -  manual only. Debug console: [player] remoteExec ["FAC_missionTestSuite_execServer", 2]  (systemChat to that player; use [] to broadcast)
FAC_missionTestSuite_execServer = {
    if (!isServer) exitWith {};
    private _to = _this param [0, objNull];
    private _callback = _this param [1, false];
    private _startMsg = "[FAC TestSuite] Server: starting...";
    if (!isNull _to && { isPlayer _to }) then {
        [_startMsg] remoteExec ["systemChat", _to];
    } else {
        [_startMsg] remoteExec ["systemChat", 0];
    };
    if (isNil "FAC_missionTestSuite_runServer") then {
        call compile preprocessFileLineNumbers "rsc\MissionTestSuite.sqf";
    };
    private _res = [_to] call FAC_missionTestSuite_runServer;
    if (isNil "_res" || { count _res < 2 }) then {
        private _err = "[FAC TestSuite] Server: aborted (script error  -  check RPT).";
        if (!isNull _to && { isPlayer _to }) then { [_err] remoteExec ["systemChat", _to]; } else { [_err] remoteExec ["systemChat", 0]; };
    } else {
        _res params ["_p", "_f"];
        private _end = format ["[FAC TestSuite] Server finished: %1 pass, %2 fail  -  see RPT for [FAC TestSuite].", _p, _f];
        if (!isNull _to && { isPlayer _to }) then { [_end] remoteExec ["systemChat", _to]; } else { [_end] remoteExec ["systemChat", 0]; };
        if (_callback && { !isNull _to } && { isPlayer _to }) then {
            [_res] remoteExec ["FAC_missionTestSuite_onServerDone", _to];
        };
    };
};
publicVariable "FAC_missionTestSuite_execServer";

// Retry base NPC spawn if postInit / spawn failed; re-anchor if Eden logic was late.
[] spawn {
    private _delays = [2, 6, 15, 30];
    {
        sleep _x;
        if (missionNamespace getVariable ["FADE_baseNpc_initDone", false]) then {
            if (!isNil "FADE_baseNpc_serverReanchorIfNeeded") then { [] call FADE_baseNpc_serverReanchorIfNeeded };
        } else {
            if (!isNil "FADE_baseNpc_spawnAndRegister") then { [] call FADE_baseNpc_spawnAndRegister };
        };
    } forEach _delays;
    if (!isNil "FADE_baseNpc_serverReanchorIfNeeded") then { [] call FADE_baseNpc_serverReanchorIfNeeded };
};

