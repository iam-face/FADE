// =============================================================================
// ServerBasePick.sqf — non-Altis player base (admin confirm, or suggest + vote)
// Altis keeps the Eden base and does not run the orchestrator.
// =============================================================================
if (!isServer) exitWith {};

FADE_basePick_loggedInAdmin = {
    params [["_player", objNull]];
    if (isNull _player || { !isPlayer _player }) exitWith { false };
    (admin (owner _player)) == 2
};

FADE_basePick_anyLoggedInAdmin = {
    private _found = false;
    {
        if ([_x] call FADE_basePick_loggedInAdmin) exitWith { _found = true };
    } forEach allPlayers;
    _found
};

FADE_basePick_posOk = {
    params ["_pos"];
    if (!(_pos isEqualType []) || { count _pos < 2 }) exitWith { false };
    private _x = _pos select 0;
    private _y = _pos select 1;
    if (!(_x isEqualType 0) || { !(_y isEqualType 0) }) exitWith { false };
    if (!finite _x || { !finite _y }) exitWith { false };
    if (surfaceIsWater [_x, _y]) exitWith { false };
    private _fn = missionNamespace getVariable ["FADE_mapPosInBounds", {}];
    if (_fn isEqualType {}) then { [_pos] call _fn } else { true }
};

FADE_basePick_findDryFromCenter = {
    private _cx = (FADE_mapMinX + FADE_mapMaxX) / 2;
    private _cy = (FADE_mapMinY + FADE_mapMaxY) / 2;
    private _found = [];
    private _half = ((FADE_mapMaxX - FADE_mapMinX) max (FADE_mapMaxY - FADE_mapMinY)) / 2;
    for "_i" from 0 to 64 do {
        private _dist = if (_i == 0) then { 0 } else { (_i / 64) * _half };
        private _ang = (_i * 47) mod 360;
        private _try = [[_cx, _cy, 0], _dist, _ang] call BIS_fnc_relPos;
        if ([_try] call FADE_mapPosInBounds && { [_try] call FADE_surfaceIsDry }) exitWith { _found = _try };
    };
    if (count _found >= 2) exitWith { _found };
    private _step = (worldSize / 16) max 400;
    private _x = FADE_mapMinX;
    while { _x <= FADE_mapMaxX && { count _found < 2 } } do {
        private _y = FADE_mapMinY;
        while { _y <= FADE_mapMaxY && { count _found < 2 } } do {
            private _try = [_x, _y, 0];
            if ([_try] call FADE_surfaceIsDry) then { _found = _try };
            _y = _y + _step;
        };
        _x = _x + _step;
    };
    _found
};

FADE_basePick_holdStragglers = {
    private _dry = [] call FADE_basePick_findDryFromCenter;
    if (count _dry < 2) exitWith {};
    {
        if (isNull _x || { !isPlayer _x }) then { continue };
        private _p = getPosATL _x;
        private _bad = !([_p] call FADE_mapPosInBounds) || { !([_p] call FADE_surfaceIsDry) };
        if (_bad) then {
            [_dry, 0] remoteExec ["FADE_clientTeleportPos", _x];
        };
    } forEach allPlayers;
};

FADE_basePick_respawnMarkerName = {
    private _side = missionNamespace getVariable ["FADE_sideFriendly", west];
    switch (_side) do {
        case east: { "respawn_east" };
        case independent: { "respawn_guerrila" };
        case civilian: { "respawn_civilian" };
        default { "respawn_west" };
    }
};

FADE_basePick_refreshRespawnMarker = {
    if !(missionNamespace getVariable ["FADE_baseDefined", false]) exitWith {};
    private _pos = [] call FADE_getPlayerBasePos;
    if (count _pos < 2) exitWith {};
    private _keep = [] call FADE_basePick_respawnMarkerName;
    {
        if (_x != _keep && { getMarkerColor _x != "" }) then { deleteMarker _x };
    } forEach ["respawn_west", "respawn_east", "respawn_guerrila", "respawn_civilian"];
    if (getMarkerColor _keep == "") then {
        createMarker [_keep, _pos];
        _keep setMarkerType "mil_triangle";
        _keep setMarkerText " CTB HQ";
        _keep setMarkerColor "ColorBLUFOR";
    };
};

FADE_basePick_ensureZoneMarker = {
    params ["_pos"];
    if (getMarkerColor "mkrBaseZone" != "") exitWith {};
    private _r = missionNamespace getVariable ["FADE_buildRadius", 1000];
    createMarker ["mkrBaseZone", _pos];
    "mkrBaseZone" setMarkerShape "ELLIPSE";
    "mkrBaseZone" setMarkerBrush "Border";
    "mkrBaseZone" setMarkerSize [_r, _r];
    "mkrBaseZone" setMarkerColor "ColorBLUFOR";
};

FADE_basePick_clearChoiceMarkers = {
    private _choices = missionNamespace getVariable ["FADE_basePick_choices", createHashMap];
    {
        private _m = format ["FADE_basePick_%1", _x];
        if (getMarkerColor _m != "") then { deleteMarker _m };
    } forEach (keys _choices);
};

FADE_basePick_publishChoices = {
    private _choices = missionNamespace getVariable ["FADE_basePick_choices", createHashMap];
    private _out = [];
    {
        private _row = _choices get _x;
        if (_row isEqualType [] && { count _row >= 2 }) then {
            _row params ["_nm", "_pos"];
            _out pushBack [_x, _nm, _pos select 0, _pos select 1];
        };
    } forEach (keys _choices);
    missionNamespace setVariable ["FADE_basePick_choiceList", _out, true];
};

// _choiceUids: candidate ids. _voteChoiceUids: one entry per voter (last vote already applied).
// Highest count wins. Equal counts, including all zeros, pick at random among the tie.
FADE_basePick_tally = {
    params ["_choiceUids", "_voteChoiceUids"];
    if !(_choiceUids isEqualType []) exitWith { "" };
    if (_choiceUids isEqualTo []) exitWith { "" };
    private _scores = _choiceUids apply { 0 };
    {
        private _i = _choiceUids find _x;
        if (_i >= 0) then { _scores set [_i, (_scores select _i) + 1] };
    } forEach _voteChoiceUids;
    private _best = selectMax _scores;
    private _tied = [];
    {
        if ((_scores select _forEachIndex) == _best) then { _tied pushBack _x };
    } forEach _choiceUids;
    if (_tied isEqualTo []) exitWith { "" };
    selectRandom _tied
};

FADE_basePick_commit = {
    params ["_pos", ["_quiet", false]];
    if (missionNamespace getVariable ["FADE_baseDefined", false]) exitWith {};
    if (!(_pos isEqualType []) || { count _pos < 2 }) exitWith {};
    FADE_basePos = [_pos select 0, _pos select 1, 0];
    publicVariable "FADE_basePos";
    missionNamespace setVariable ["FADE_baseDefined", true, true];
    missionNamespace setVariable ["FADE_basePickPhase", "done", true];
    [] call FADE_basePick_clearChoiceMarkers;
    [FADE_basePos] call FADE_basePick_ensureZoneMarker;
    [] call FADE_basePick_refreshRespawnMarker;
    if (!_quiet) then {
        ["Player base set. Moving now."] remoteExec ["systemChat", 0];
    };
    private _players = allPlayers select { !isNull _x && { isPlayer _x } };
    private _n = count _players;
    {
        private _ang = if (_n <= 1) then { 0 } else { _forEachIndex * (360 / _n) };
        private _tp = [FADE_basePos, 8, _ang] call BIS_fnc_relPos;
        if (surfaceIsWater _tp) then { _tp = FADE_basePos };
        [_tp, 0] remoteExec ["FADE_clientTeleportPos", _x];
        ["done"] remoteExec ["FAC_basePick_applyPhase", _x];
    } forEach _players;
    if (!isNil "FADE_world_startBaseDependent") then { [] call FADE_world_startBaseDependent };
    diag_log format ["[FADE] Player base committed at %1", FADE_basePos];
};

FADE_basePick_adminConfirm = {
    params ["_player", "_pos"];
    if (!isServer) exitWith {};
    if (missionNamespace getVariable ["FADE_basePickPhase", ""] != "admin") exitWith {};
    if !([_player] call FADE_basePick_loggedInAdmin) exitWith {};
    if !([_pos] call FADE_basePick_posOk) exitWith {
        ["That point is off the map or in the water."] remoteExec ["systemChat", _player];
    };
    [_pos] call FADE_basePick_commit;
};

FADE_basePick_suggest = {
    params ["_player", "_pos"];
    if (!isServer) exitWith {};
    if (missionNamespace getVariable ["FADE_basePickPhase", ""] != "suggest") exitWith {};
    if (isNull _player || { !isPlayer _player }) exitWith {};
    if !([_pos] call FADE_basePick_posOk) exitWith {
        ["That point is off the map or in the water."] remoteExec ["systemChat", _player];
    };
    private _uid = getPlayerUID _player;
    if (_uid == "") exitWith {};
    private _nm = name _player;
    if (_nm == "") then { _nm = "Unknown" };
    private _choices = missionNamespace getVariable ["FADE_basePick_choices", createHashMap];
    _choices set [_uid, [_nm, [_pos select 0, _pos select 1, 0]]];
    missionNamespace setVariable ["FADE_basePick_choices", _choices];
    private _m = format ["FADE_basePick_%1", _uid];
    if (getMarkerColor _m == "") then {
        createMarker [_m, _pos];
        _m setMarkerType "mil_dot";
        _m setMarkerColor "ColorYellow";
    } else {
        _m setMarkerPos _pos;
    };
    _m setMarkerText format ["%1's Choice", _nm];
};

FADE_basePick_vote = {
    params ["_player", "_choiceUid"];
    if (!isServer) exitWith {};
    if (missionNamespace getVariable ["FADE_basePickPhase", ""] != "vote") exitWith {};
    if (isNull _player || { !isPlayer _player }) exitWith {};
    if !(_choiceUid isEqualType "") exitWith {};
    private _uid = getPlayerUID _player;
    if (_uid == "") exitWith {};
    private _choices = missionNamespace getVariable ["FADE_basePick_choices", createHashMap];
    if (isNil { _choices get _choiceUid }) exitWith {};
    private _votes = missionNamespace getVariable ["FADE_basePick_votes", createHashMap];
    _votes set [_uid, _choiceUid];
    missionNamespace setVariable ["FADE_basePick_votes", _votes];
};

FADE_basePick_runVote = {
    [] call FADE_basePick_publishChoices;
    missionNamespace setVariable ["FADE_basePick_votes", createHashMap];
    missionNamespace setVariable ["FADE_basePick_deadline", serverTime + 60, true];
    missionNamespace setVariable ["FADE_basePickPhase", "vote", true];
    {
        ["vote"] remoteExec ["FAC_basePick_applyPhase", _x];
    } forEach allPlayers;
    private _end = time + 60;
    waitUntil { sleep 1; time >= _end || { missionNamespace getVariable ["FADE_baseDefined", false] } };
    if (missionNamespace getVariable ["FADE_baseDefined", false]) exitWith {};
    private _choices = missionNamespace getVariable ["FADE_basePick_choices", createHashMap];
    private _uids = keys _choices;
    private _votes = missionNamespace getVariable ["FADE_basePick_votes", createHashMap];
    private _cast = [];
    { _cast pushBack (_votes get _x) } forEach (keys _votes);
    private _winUid = [_uids, _cast] call FADE_basePick_tally;
    private _row = _choices get _winUid;
    if (isNil "_row") exitWith {};
    _row params ["_nm", "_pos"];
    [_pos] call FADE_basePick_commit;
};

FADE_basePick_runSuggestUntilCommit = {
    if (isNil { missionNamespace getVariable "FADE_basePick_choices" }) then {
        missionNamespace setVariable ["FADE_basePick_choices", createHashMap];
    };
    while { !(missionNamespace getVariable ["FADE_baseDefined", false]) } do {
        [] call FADE_basePick_holdStragglers;
        missionNamespace setVariable ["FADE_basePick_deadline", serverTime + 60, true];
        missionNamespace setVariable ["FADE_basePickPhase", "suggest", true];
        {
            ["suggest"] remoteExec ["FAC_basePick_applyPhase", _x];
        } forEach allPlayers;
        private _end = time + 60;
        waitUntil { sleep 1; time >= _end || { missionNamespace getVariable ["FADE_baseDefined", false] } };
        if (missionNamespace getVariable ["FADE_baseDefined", false]) exitWith {};
        private _choices = missionNamespace getVariable ["FADE_basePick_choices", createHashMap];
        if ((count (keys _choices)) == 0) then {
            ["No choices yet. Mark a point on the map."] remoteExec ["systemChat", 0];
        } else {
            [] call FADE_basePick_runVote;
        };
    };
};

FADE_basePick_runAdmin = {
    private _uids = [];
    {
        if ([_x] call FADE_basePick_loggedInAdmin) then {
            _uids pushBackUnique (getPlayerUID _x);
        };
    } forEach allPlayers;
    missionNamespace setVariable ["FADE_basePick_adminUids", _uids, true];
    missionNamespace setVariable ["FADE_basePickPhase", "admin", true];
    {
        ["admin"] remoteExec ["FAC_basePick_applyPhase", _x];
    } forEach allPlayers;
    waitUntil {
        sleep 1;
        missionNamespace getVariable ["FADE_baseDefined", false]
        || { !([] call FADE_basePick_anyLoggedInAdmin) }
    };
    if !(missionNamespace getVariable ["FADE_baseDefined", false]) then {
        missionNamespace setVariable ["FADE_basePick_adminUids", [], true];
        {
            ["adminLeft"] remoteExec ["FAC_basePick_applyPhase", _x];
        } forEach allPlayers;
    };
};

FADE_basePick_orchestrate = {
    if (!isServer) exitWith {};
    if (worldName == "Altis") exitWith {};
    waitUntil { sleep 0.5; !isNil "FADE_mapMinX" };
    if (fileExists "headless_test.flg") exitWith {
        private _pos = [] call FADE_basePick_findDryFromCenter;
        if (count _pos >= 2) then {
            [_pos, true] call FADE_basePick_commit;
        } else {
            diag_log "[FADE] Headless base pick found no dry ground.";
        };
    };
    waitUntil { sleep 0.5; missionNamespace getVariable ["FADE_clientInitReady", false] };
    waitUntil { sleep 1; count allPlayers > 0 };
    sleep 1;
    [] call FADE_basePick_holdStragglers;
    private _deadline = time + 20;
    waitUntil {
        sleep 1;
        ([] call FADE_basePick_anyLoggedInAdmin) || { time >= _deadline }
    };
    if ([] call FADE_basePick_anyLoggedInAdmin) then {
        [] call FADE_basePick_runAdmin;
    };
    if !(missionNamespace getVariable ["FADE_baseDefined", false]) then {
        [] call FADE_basePick_runSuggestUntilCommit;
    };
};

publicVariable "FADE_basePick_adminConfirm";
publicVariable "FADE_basePick_suggest";
publicVariable "FADE_basePick_vote";
publicVariable "FADE_basePick_tally";
