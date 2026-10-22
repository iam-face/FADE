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

// "" when the point can be the player base. Otherwise the sentence to send the player.
FADE_basePick_rejectReason = {
    params ["_pos"];
    if (!(_pos isEqualType []) || { count _pos < 2 }) exitWith { "That point is not on the map." };
    private _x = _pos select 0;
    private _y = _pos select 1;
    if (!(_x isEqualType 0) || { !(_y isEqualType 0) }) exitWith { "That point is not on the map." };
    if (!finite _x || { !finite _y }) exitWith { "That point is not on the map." };
    if (surfaceIsWater [_x, _y]) exitWith { "That point is in the water." };
    private _fn = missionNamespace getVariable ["FADE_mapPosInBounds", {}];
    private _in = if (_fn isEqualType {}) then { [_pos] call _fn } else { true };
    if (!_in) exitWith { "That point is off the map." };
    ""
};

FADE_basePick_posOk = {
    params ["_pos"];
    ([_pos] call FADE_basePick_rejectReason) == ""
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
    private _r = missionNamespace getVariable ["FADE_buildRadius", 500];
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

FADE_basePick_playerKey = {
    params ["_player"];
    if (isNull _player) exitWith { "" };
    private _uid = getPlayerUID _player;
    if (_uid == "") then { _uid = format ["owner:%1", owner _player] };
    _uid
};

FADE_basePick_pickSeconds = {
    private _secs = missionNamespace getVariable ["FADE_basePick_pickWait", 20];
    if (!(_secs isEqualType 0) || { _secs < 5 }) then { 20 } else { _secs }
};

// Flat rows the vote dialog reads: [id, name, x, y]. Replaces a row when the same player clicks again.
FADE_basePick_rememberChoice = {
    params ["_uid", "_nm", "_px", "_py"];
    private _list = missionNamespace getVariable ["FADE_basePick_choiceList", []];
    if !(_list isEqualType []) then { _list = [] };
    private _idx = -1;
    {
        if ((_x param [0, ""]) isEqualTo _uid) exitWith { _idx = _forEachIndex };
    } forEach _list;
    private _entry = [_uid, _nm, _px, _py];
    if (_idx < 0) then {
        _list pushBack _entry;
    } else {
        _list set [_idx, _entry];
    };
    missionNamespace setVariable ["FADE_basePick_choiceList", _list, true];
    _list
};

FADE_basePick_publishChoices = {
    private _list = missionNamespace getVariable ["FADE_basePick_choiceList", []];
    if !(_list isEqualType []) then { _list = [] };
    missionNamespace setVariable ["FADE_basePick_choiceList", _list, true];
    _list
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
    [] call FADE_basePick_clearChoiceMarkers;
    [FADE_basePos] call FADE_basePick_ensureZoneMarker;
    [] call FADE_basePick_refreshRespawnMarker;
    private _players = allPlayers select { !isNull _x && { isPlayer _x } };
    private _line = "";
    if (!_quiet) then {
        _line = [FADE_basePos] call FADE_basePick_placeLine;
        missionNamespace setVariable ["FADE_basePick_deployLine", _line, true];
    };
    missionNamespace setVariable ["FADE_basePickPhase", "done", true];
    if (_quiet) then {
        [_players] call FADE_basePick_movePlayers;
        { ["done"] remoteExec ["FAC_basePick_applyPhase", _x] } forEach _players;
    } else {
        {
            ["done", _line] remoteExec ["FAC_basePick_applyPhase", _x];
        } forEach _players;
        [_players] spawn {
            params ["_players"];
            sleep 1.2;
            [_players] call FADE_basePick_movePlayers;
        };
    };
    if (!isNil "FADE_world_startBaseDependent") then { [] call FADE_world_startBaseDependent };
    diag_log format ["[FADE] Player base committed at %1", FADE_basePos];
};

FADE_basePick_gridText = {
    params ["_pos"];
    private _g = mapGridPosition _pos;
    private _digits = (count _g) >= 4 && { ((count _g) mod 2) == 0 };
    if (_digits) then {
        private _i = 0;
        for "_i" from 0 to ((count _g) - 1) do {
            if !((_g select [_i, 1]) in ["0","1","2","3","4","5","6","7","8","9"]) exitWith { _digits = false };
        };
    };
    if (_digits) then {
        private _half = (count _g) / 2;
        format ["%1 %2", _g select [0, _half], _g select [_half, _half]]
    } else {
        _g
    }
};

// Compass direction of _to from _from. Wiki: (dx) atan2 (dy), then bring it into 0..360.
FADE_basePick_cardinal = {
    params ["_from", "_to"];
    private _dx = (_to select 0) - (_from select 0);
    private _dy = (_to select 1) - (_from select 1);
    private _dir = (_dx atan2 _dy);
    _dir = (_dir + 360) % 360;
    ["N", "NE", "E", "SE", "S", "SW", "W", "NW"] select ((round (_dir / 45)) mod 8)
};

FADE_basePick_placeLine = {
    params ["_pos"];
    private _grid = [_pos] call FADE_basePick_gridText;
    private _tail = "";
    private _locs = nearestLocations [[_pos select 0, _pos select 1, 0], ["NameCityCapital", "NameCity", "NameVillage"], 8000];
    if (count _locs > 0) then {
        private _loc = _locs select 0;
        private _name = text _loc;
        if (_name != "") then {
            private _lp = locationPosition _loc;
            if ((_pos distance2D _lp) < 400) then {
                _tail = format [", at %1", _name];
            } else {
                private _card = [_lp, _pos] call FADE_basePick_cardinal;
                _tail = format [", %1 of %2", _card, _name];
            };
        };
    };
    format ["Combat Team Bravo base established at %1%2. Deploying you now.", _grid, _tail]
};

FADE_basePick_movePlayers = {
    params ["_players"];
    private _live = _players select { !isNull _x && { isPlayer _x } };
    private _n = count _live;
    {
        private _ang = if (_n <= 1) then { 0 } else { _forEachIndex * (360 / _n) };
        private _tp = [FADE_basePos, 8, _ang] call BIS_fnc_relPos;
        if (surfaceIsWater _tp) then { _tp = FADE_basePos };
        [_tp, 0] remoteExec ["FADE_clientTeleportPos", _x];
    } forEach _live;
};

FADE_basePick_adminConfirm = {
    params ["_player", "_pos"];
    if (!isServer) exitWith {};
    if (missionNamespace getVariable ["FADE_basePickPhase", ""] != "admin") exitWith {};
    if !([_player] call FADE_basePick_loggedInAdmin) exitWith {};
    private _why = [_pos] call FADE_basePick_rejectReason;
    if (_why != "") exitWith {
        [_why] remoteExec ["systemChat", _player];
    };
    [_pos] call FADE_basePick_commit;
};

FADE_basePick_suggest = {
    params ["_player", "_pos"];
    if (!isServer) exitWith {};
    if (missionNamespace getVariable ["FADE_basePickPhase", ""] != "suggest") exitWith {};
    if (isNull _player || { !isPlayer _player }) exitWith {};
    private _why = [_pos] call FADE_basePick_rejectReason;
    if (_why != "") exitWith {
        [_why] remoteExec ["systemChat", _player];
    };
    private _uid = [_player] call FADE_basePick_playerKey;
    if (_uid == "") exitWith {};
    private _nm = name _player;
    if (_nm == "") then { _nm = "Unknown" };
    [_uid, _nm, _pos select 0, _pos select 1] call FADE_basePick_rememberChoice;
    private _choices = missionNamespace getVariable ["FADE_basePick_choices", createHashMap];
    _choices set [_uid, [_nm, [_pos select 0, _pos select 1, 0]]];
    missionNamespace setVariable ["FADE_basePick_choices", _choices];
    ["Choice recorded."] remoteExec ["systemChat", _player];
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
    private _uid = [_player] call FADE_basePick_playerKey;
    if (_uid == "") exitWith {};
    private _list = missionNamespace getVariable ["FADE_basePick_choiceList", []];
    if !(_list isEqualType []) then { _list = [] };
    private _known = false;
    {
        if (_x isEqualType [] && { (_x param [0, ""]) isEqualTo _choiceUid }) exitWith { _known = true };
    } forEach _list;
    if (!_known) exitWith {};
    private _votes = missionNamespace getVariable ["FADE_basePick_votes", createHashMap];
    _votes set [_uid, _choiceUid];
    missionNamespace setVariable ["FADE_basePick_votes", _votes];
};

FADE_basePick_runVote = {
    private _list = [] call FADE_basePick_publishChoices;
    if (_list isEqualTo []) exitWith {
        diag_log "[FADE] Base pick vote skipped (no choices).";
    };
    missionNamespace setVariable ["FADE_basePick_votes", createHashMap];
    private _secs = [] call FADE_basePick_pickSeconds;
    private _deadline = serverTime + _secs;
    missionNamespace setVariable ["FADE_basePick_deadline", _deadline, true];
    missionNamespace setVariable ["FADE_basePickPhase", "vote", true];
    {
        ["vote", _list] remoteExec ["FAC_basePick_applyPhase", _x];
    } forEach allPlayers;
    waitUntil {
        sleep 0.5;
        serverTime >= _deadline || { missionNamespace getVariable ["FADE_baseDefined", false] }
    };
    if (missionNamespace getVariable ["FADE_baseDefined", false]) exitWith {};
    _list = missionNamespace getVariable ["FADE_basePick_choiceList", []];
    if !(_list isEqualType []) then { _list = [] };
    private _uids = _list apply { _x param [0, ""] };
    private _votes = missionNamespace getVariable ["FADE_basePick_votes", createHashMap];
    private _cast = [];
    {
        private _choice = _votes get _x;
        if (_choice isEqualType "") then { _cast pushBack _choice };
    } forEach (keys _votes);
    private _winUid = [_uids, _cast] call FADE_basePick_tally;
    private _picked = [];
    {
        if ((_x param [0, ""]) isEqualTo _winUid) exitWith { _picked = _x };
    } forEach _list;
    if (count _picked < 4) exitWith {
        diag_log "[FADE] Base pick vote ended with no choice to commit.";
    };
    [[_picked select 2, _picked select 3, 0]] call FADE_basePick_commit;
};

FADE_basePick_runSuggestUntilCommit = {
    if (isNil { missionNamespace getVariable "FADE_basePick_choices" }) then {
        missionNamespace setVariable ["FADE_basePick_choices", createHashMap];
    };
    while { !(missionNamespace getVariable ["FADE_baseDefined", false]) } do {
        [] call FADE_basePick_holdStragglers;
        private _secs = [] call FADE_basePick_pickSeconds;
        private _deadline = serverTime + _secs;
        missionNamespace setVariable ["FADE_basePick_deadline", _deadline, true];
        missionNamespace setVariable ["FADE_basePickPhase", "suggest", true];
        {
            ["suggest"] remoteExec ["FAC_basePick_applyPhase", _x];
        } forEach allPlayers;
        waitUntil {
            sleep 0.5;
            serverTime >= _deadline || { missionNamespace getVariable ["FADE_baseDefined", false] }
        };
        if (missionNamespace getVariable ["FADE_baseDefined", false]) exitWith {};
        private _list = missionNamespace getVariable ["FADE_basePick_choiceList", []];
        if !(_list isEqualType [] && { count _list > 0 }) then {
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
    waitUntil {
        sleep 0.5;
        missionNamespace getVariable ["FADE_basePick_joinDone", false]
        || { missionNamespace getVariable ["FADE_baseDefined", false] }
    };
    if (missionNamespace getVariable ["FADE_baseDefined", false]) exitWith {};
    [] call FADE_basePick_holdStragglers;
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
