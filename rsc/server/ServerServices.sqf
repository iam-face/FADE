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
// Ambient civ car radio (vehicle:<netId> only). Playback lives in FAC_CivCarRadio.sqf.
// -----------------------------------------------------------------------------
call compile preprocessFileLineNumbers "rsc\FAC_CivCarRadio.sqf";

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

// Mission playthrough suite — sequential live mission init + QRF probes (dev only).
// Debug console: [player] remoteExec ["FAC_playthroughSuite_execServer", 2]
FAC_playthroughSuite_execServer = {
    if (!isServer) exitWith {};
    private _to = _this param [0, objNull];
    private _types = _this param [1, []];
    if (isNil "FAC_playthroughSuite_runServer") then {
        call compile preprocessFileLineNumbers "rsc\MissionPlaythroughSuite.sqf";
        call compile preprocessFileLineNumbers "rsc\MissionPlaythroughProfiles.sqf";
    };
    if (_types isEqualTo []) then { _types = +FAC_playthroughSuite__missionTypes };
    if (isNil "FAC_playthroughSuite_runServer") exitWith {
        private _err = "[FAC Playthrough] Server: aborted (script failed to load — check RPT).";
        if (!isNull _to && { isPlayer _to }) then { [_err] remoteExec ["systemChat", _to]; } else { [_err] remoteExec ["systemChat", 0]; };
    };
    private _res = [_to, _types] call FAC_playthroughSuite_runServer;
    if (isNil "_res" || { count _res < 3 }) exitWith {};
    _res params ["_p", "_f", "_s"];
    private _end = format ["[FAC Playthrough] Server finished: %1 pass / %2 fail / %3 skipped.", _p, _f, _s];
    if (!isNull _to && { isPlayer _to }) then { [_end] remoteExec ["systemChat", _to]; } else { [_end] remoteExec ["systemChat", 0]; };
};
publicVariable "FAC_playthroughSuite_execServer";

FAC_playthroughSuite_abortServer = {
    if (!isServer) exitWith {};
    if (isNil "FAC_playthroughSuite__setAbortRequested") then {
        call compile preprocessFileLineNumbers "rsc\MissionPlaythroughSuite.sqf";
        call compile preprocessFileLineNumbers "rsc\MissionPlaythroughProfiles.sqf";
    };
    [] call FAC_playthroughSuite__setAbortRequested;
};
publicVariable "FAC_playthroughSuite_abortServer";

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

