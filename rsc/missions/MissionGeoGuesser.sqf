// =============================================================================
// MissionGeoGuesser.sqf  -  navigation drill (server runner)
// =============================================================================
if (!isServer) exitWith {};

FADE_geoGuesser_difficultyConfig = {
    params [["_difficulty", "Normal"]];
    switch (_difficulty) do {
        case "Hard": { [3500, 1.2, 1.1] };
        case "Impossible": { [5000, 1.5, 1.25] };
        default { [2000, 1.0, 1.0] };
    };
};

FADE_geoGuesser_computeScore = {
    params ["_distanceM", "_timeRemaining", "_totalTime", "_distPenalty", "_diffMult"];
    if (_distanceM < 0) exitWith { 0 };
    private _accuracy = (1000 - (_distanceM * _distPenalty)) max 0;
    private _timeMult = 1 + (((_timeRemaining / (_totalTime max 1)) max 0) min 1) * 0.5;
    floor (_accuracy * _timeMult * _diffMult)
};

FADE_geoGuesser_resolveTeleportBasePos = {
    params [["_ringIdx", 0]];
    private _o = missionNamespace getVariable ["teleportBase", objNull];
    if (isNull _o) exitWith { [[], -1] };
    private _anchor = getPosATL _o;
    private _dir = getDir _o;
    private _dx = sin _dir * 5;
    private _dy = cos _dir * 5;
    private _tp = [(_anchor select 0) - _dx, (_anchor select 1) - _dy, _anchor select 2];
    private _faceDir = _tp getDir _anchor;
    if (_ringIdx > 0) then {
        private _ring = 1.2 + (_ringIdx mod 4);
        private _bear = _faceDir + 90 + (_ringIdx * 37);
        private _flat = _tp getPos [_ring, _bear];
        _tp = [_flat select 0, _flat select 1, _tp select 2];
    };
    [_tp, _faceDir]
};

FADE_geoGuesser_teleportPlayerToBase = {
    params ["_pl", ["_ringIdx", 0]];
    if (isNull _pl || { !alive _pl }) exitWith {};
    if (vehicle _pl != _pl) then { moveOut _pl };
    private _resolved = [_ringIdx] call FADE_geoGuesser_resolveTeleportBasePos;
    _resolved params [["_tp", []], ["_faceDir", -1]];
    if (count _tp < 2) exitWith {
        [format ["GEO-GUESSER: could not RTB %1 — Eden object teleportBase not found.", name _pl]] remoteExec ["systemChat", 0];
    };
    [_tp, _faceDir] remoteExec ["FADE_clientTeleportPos", _pl];
};

FADE_geoGuesser_pickDropPos = {
    params ["_difficulty"];
    private _cfg = [_difficulty] call FADE_geoGuesser_difficultyConfig;
    _cfg params ["_minDist", "_penalty", "_mult"];
    private _dry = missionNamespace getVariable ["FADE_surfaceIsDry", { params ["_p"]; count _p >= 2 && { !surfaceIsWater [_p select 0, _p select 1] } }];
    private _pos = [];
    if (_difficulty == "Normal") then {
        _pos = [_minDist] call FADE_findMissionPosUrban;
        if (count _pos < 2) then { _pos = [_minDist] call FADE_findMissionPos };
    } else {
        _pos = [_minDist] call FADE_findMissionPos;
    };
    if (count _pos >= 2 && { [_pos] call _dry }) exitWith { _pos };
    private _bp = missionNamespace getVariable ["FADE_basePos", [0, 0, 0]];
    if (_bp isEqualType objNull) then { _bp = getPosATL _bp };
    private _center = if (count _pos >= 2) then { _pos } else { _bp };
    private _fallback = [[_center, _minDist, 80, 8, 1, 0.3, 0, [], _center], _center] call FADE_findSafePosArray;
    if (count _fallback >= 2) then { _fallback } else { _pos }
};

FADE_geoGuesser_submitGuess = {
    params ["_taskId", "_guessPos", "_player"];
    if (!isServer) exitWith {};
    if (_taskId == "" || { isNull _player } || { !isPlayer _player }) exitWith {};
    if !(_guessPos isEqualType []) exitWith {};
    if (count _guessPos < 2) exitWith {};
    private _stateKey = "FADE_ggRound_" + _taskId;
    private _st = missionNamespace getVariable [_stateKey, createHashMap];
    if (_st isEqualTo createHashMap || { !(_st getOrDefault ["active", false]) }) exitWith {};
    private _uid = getPlayerUID _player;
    private _partUids = _st getOrDefault ["participantUids", []];
    if !(_uid in _partUids) exitWith {};
    private _subs = +(_st getOrDefault ["submissions", createHashMap]);
    if (_subs getOrDefault [_uid, nil] isEqualType []) exitWith {};
    private _actual = getPosATL _player;
    if (count _actual < 3) then { _actual = [(_actual select 0), (_actual select 1), 0] };
    private _deadline = _st getOrDefault ["deadline", serverTime];
    private _timeRem = ((_deadline - serverTime) max 0);
    _subs set [_uid, [_guessPos, _actual, serverTime, _timeRem]];
    _st set ["submissions", _subs];
    missionNamespace setVariable [_stateKey, _st];
    private _ring = _partUids find _uid;
    [_player, _ring max 0] call FADE_geoGuesser_teleportPlayerToBase;
    [_player] remoteExec ["FADE_ggClient_forceStop", _player];
    if (count (keys _subs) >= count _partUids) then {
        _st set ["allSubmitted", true];
        missionNamespace setVariable [_stateKey, _st];
    };
};

FADE_runMission_GeoGuesser = {
    private _missionType = missionNamespace getVariable ["FADE_missionRun_missionType", ""];
    private _dropPos = missionNamespace getVariable ["FADE_missionRun_destPos", [0, 0, 0]];
    private _player = missionNamespace getVariable ["FADE_missionRun_player", objNull];
    private _participants = missionNamespace getVariable ["FADE_missionRun_evadeePlayers", []];
    private _taskId = missionNamespace getVariable ["FADE_missionRun_taskId", ""];
    private _operationName = missionNamespace getVariable ["FADE_missionRun_operationName", ""];
    private _operationNameUpper = missionNamespace getVariable ["FADE_missionRun_operationNameUpper", ""];
    private _briefGuiTail = missionNamespace getVariable ["FADE_missionRun_briefGuiTail", ""];
    private _isGlobalMission = missionNamespace getVariable ["FADE_missionRun_isGlobalMission", false];
    private _basePos = missionNamespace getVariable ["FADE_missionRun_basePos", [0, 0, 0]];
    private _showAssignedHint = missionNamespace getVariable ["FADE_mission_showAssignedHint", {}];
    private _timeSec = missionNamespace getVariable ["FADE_ggRun_timeSec", 60];
    private _difficulty = missionNamespace getVariable ["FADE_ggRun_difficulty", "Normal"];
    _timeSec = round _timeSec max 30 min 600;
    if !(_difficulty in ["Normal", "Hard", "Impossible"]) then { _difficulty = "Normal" };
    private _diffCfg = [_difficulty] call FADE_geoGuesser_difficultyConfig;
    _diffCfg params ["_minDistCfg", "_distPenalty", "_diffMult"];

    if (count _participants < 1) exitWith {
        if (!isNull _player) then { [_player] call FADE_clearActiveMission };
        ["<t size='1.2' color='#FF6666'>MISSION ERROR</t><br/><br/><t color='#E0E0E0'>No participants for Geo-Guesser.</t>"] remoteExec ["FADE_showMissionHint", _player];
    };
    if (count _dropPos < 2) exitWith {
        if (!isNull _player) then { [_player] call FADE_clearActiveMission };
        ["<t size='1.2' color='#FF6666'>MISSION ERROR</t><br/><br/><t color='#E0E0E0'>Could not find a valid drop location.</t>"] remoteExec ["FADE_showMissionHint", _player];
    };

    missionNamespace setVariable ["FADE_ggAborted_" + _taskId, false];
    private _partUids = _participants apply { getPlayerUID _x };
    private _countdownSec = 10;
    private _state = createHashMapFromArray [
        ["active", false],
        ["participantUids", _partUids],
        ["submissions", createHashMap],
        ["deadline", 0],
        ["timeSec", _timeSec],
        ["difficulty", _difficulty],
        ["dropPos", _dropPos],
        ["allSubmitted", false]
    ];
    missionNamespace setVariable ["FADE_ggRound_" + _taskId, _state];

    private _sf = missionNamespace getVariable ["FADE_sideFriendly", west];
    private _taskTxt = format [
        "GEO-GUESSER (%1, %2 s): dropped at an unknown location. Look around, then open your map (M) and click where you think you are. Faster guesses earn a score bonus. No task marker shows your drop point. Results when the timer ends or all players have guessed.",
        _difficulty,
        _timeSec
    ];
    [_sf, _taskId, [_taskTxt, "Geo-Guesser", ""], objNull, "CREATED", 1, true, "search", false] call BIS_fnc_taskCreate;

    private _brief = format [
        "GEO-GUESSER%1%1Difficulty: %2  |  Round: %3 s%1%1Navigation drill  -  map click marks your guess. Score = accuracy x speed bonus.",
        toString [10],
        _difficulty,
        _timeSec
    ] + _briefGuiTail;
    if (!isNull _player) then {
        _player setVariable ["FADE_myMissionBrief", _brief, true];
    };
    [format [
        "<t color='#FFFFFF'>Geo-Guesser (%1)</t><br/><t color='#FFD700'>%2 s</t><br/><t color='#FFFFFF'>Look around first. Open map (M) and click your guess when ready. Faster = higher score.</t>",
        _difficulty,
        _timeSec
    ]] call _showAssignedHint;
    if (!isNull _player) then {
        [_player, "Geo-Guesser"] call FADE_notifyOthersMissionStarted;
    };

    private _partNames = (_participants select { !isNull _x && { alive _x } }) apply { name _x };
    private _partList = if (count _partNames > 0) then { _partNames joinString ", " } else { "none" };
    [
        format [
            "Geo-Guesser starts in %1 seconds. Participants: %2. Round time: %3 s (%4). After your map guess, or when the round ends, you will be returned to base (teleportBase).",
            _countdownSec,
            _partList,
            _timeSec,
            _difficulty
        ]
    ] remoteExec ["systemChat", 0];

    private _aborted = false;
    private _countdownEnd = time + _countdownSec;
    while { time < _countdownEnd } do {
        if (missionNamespace getVariable ["FADE_ggAborted_" + _taskId, false]) exitWith { _aborted = true };
        sleep 0.25;
    };
    if (_aborted) exitWith {
        [_taskId, "CANCELED"] call BIS_fnc_taskSetState;
        [_taskId, _missionType, false] call FADE_cleanupMissionEntities;
        missionNamespace setVariable ["FADE_ggRound_" + _taskId, nil];
        missionNamespace setVariable ["FADE_ggRun_timeSec", nil];
        missionNamespace setVariable ["FADE_ggRun_difficulty", nil];
        if (!isNull _player && { (_player getVariable ["FADE_myMissionTaskId", ""]) == _taskId }) then {
            [_player, _taskId] call FADE_clearActiveMission;
        };
    };

    private _deadline = serverTime + _timeSec;
    _state set ["active", true];
    _state set ["deadline", _deadline];
    missionNamespace setVariable ["FADE_ggRound_" + _taskId, _state];

    ["Geo-Guesser: teleporting participants to the drop zone..."] remoteExec ["systemChat", 0];

    {
        if (isNull _x || { !alive _x }) then { continue };
        if (vehicle _x != _x) then { moveOut _x };
        private _off = [random 8 - 4, random 8 - 4, 0];
        private _tp = [(_dropPos select 0) + (_off select 0), (_dropPos select 1) + (_off select 1), 0];
        _tp = [[_tp, 0, 12, 4, 1, 0.4, 0, [], _tp], _tp] call FADE_findSafePosArray;
        _x setPosATL _tp;
        [_taskId, _timeSec, _difficulty, _deadline] remoteExec ["FADE_ggClient_beginRound", _x];
    } forEach _participants;

    private _lastAnnounced = _timeSec + 1;
    while { true } do {
        if (missionNamespace getVariable ["FADE_ggAborted_" + _taskId, false]) exitWith { _aborted = true };
        _state = missionNamespace getVariable ["FADE_ggRound_" + _taskId, createHashMap];
        if (_state getOrDefault ["allSubmitted", false]) exitWith {};
        private _rem = ceil ((_deadline - serverTime) max 0);
        if (_rem <= 0) exitWith {};
        if (_rem <= 30 && { _rem != _lastAnnounced }) then {
            [format ["Geo-Guesser: %1 s remaining.", _rem]] remoteExec ["systemChat", 0];
            _lastAnnounced = _rem;
        } else {
            if (_rem > 30 && { _rem mod 30 == 0 } && { _rem != _lastAnnounced }) then {
                [format ["Geo-Guesser: %1 s remaining.", _rem]] remoteExec ["systemChat", 0];
                _lastAnnounced = _rem;
            };
        };
        sleep 1;
    };

    if (_state getOrDefault ["allSubmitted", false]) then {
        ["Geo-Guesser: all participants have guessed  -  scoring now."] remoteExec ["systemChat", 0];
    } else {
        if (!_aborted) then {
            ["Geo-Guesser: time is up  -  scoring now."] remoteExec ["systemChat", 0];
        };
    };

    {
        if (isNull _x) then { continue };
        [_x] remoteExec ["FADE_ggClient_forceStop", _x];
        private _uid = getPlayerUID _x;
        private _subs = _state getOrDefault ["submissions", createHashMap];
        if !(_subs getOrDefault [_uid, nil] isEqualType []) then {
            private _ri = _partUids find _uid;
            [_x, _ri max 0] call FADE_geoGuesser_teleportPlayerToBase;
        };
    } forEach _participants;

    private _subsFinal = _state getOrDefault ["submissions", createHashMap];
    if (_aborted) exitWith {
        {
            if (isNull _x) then { continue };
            [_x] remoteExec ["FADE_ggClient_forceStop", _x];
            private _ri = _partUids find (getPlayerUID _x);
            [_x, _ri max 0] call FADE_geoGuesser_teleportPlayerToBase;
        } forEach _participants;
        [_taskId, "CANCELED"] call BIS_fnc_taskSetState;
        [_taskId, _missionType, false] call FADE_cleanupMissionEntities;
        missionNamespace setVariable ["FADE_ggRound_" + _taskId, nil];
        missionNamespace setVariable ["FADE_ggRun_timeSec", nil];
        missionNamespace setVariable ["FADE_ggRun_difficulty", nil];
        if (!isNull _player && { (_player getVariable ["FADE_myMissionTaskId", ""]) == _taskId }) then {
            [_player, _taskId] call FADE_clearActiveMission;
        };
    };

    private _rows = [];
    {
        private _uid = _x;
        private _pl = objNull;
        { if (getPlayerUID _x == _uid) exitWith { _pl = _x } } forEach _participants;
        private _pName = if (isNull _pl) then { _uid } else { name _pl };
        private _sub = _subsFinal getOrDefault [_uid, []];
        private _score = 0;
        private _distM = -1;
        private _actual = [];
        private _guess = [];
        private _timeRem = 0;
        if (count _sub >= 4) then {
            _sub params ["_gPos", "_aPos", "_subT", "_tRem"];
            _guess = +_gPos;
            _actual = +_aPos;
            _timeRem = _tRem;
            _distM = _aPos distance2D _gPos;
            _score = [_distM, _timeRem, _timeSec, _distPenalty, _diffMult] call FADE_geoGuesser_computeScore;
        };
        _rows pushBack [_pName, _score, _distM, _actual, _guess, _timeRem, _uid];
    } forEach _partUids;

    _rows = [_rows, [], { -((_x select 1) * 1000000 + (_x select 5)) }, "ASCEND"] call BIS_fnc_sortBy;

    private _html = "<t size='1.2' color='#FFD700'>GEO-GUESSER  -  RESULTS</t><br/><br/>";
    private _rank = 1;
    private _revealPack = [];
    {
        _x params ["_pName", "_score", "_distM", "_actual", "_guess", "_timeRem", "_uid"];
        private _distStr = if (_distM < 0) then { "no guess" } else { format ["%1 m", round _distM] };
        private _actGrid = if (count _actual >= 2) then { mapGridPosition _actual } else { "-" };
        private _guessGrid = if (count _guess >= 2) then { mapGridPosition _guess } else { "-" };
        _html = _html + format [
            "<t color='#E0E0E0'>%1. %2</t><br/><t color='#A0D0A0'>%3 pts</t>  |  <t color='#808080'>%4</t><br/><t color='#808080'>Location: %5  |  Guess: %6</t><br/><br/>",
            _rank,
            _pName,
            _score,
            _distStr,
            _actGrid,
            _guessGrid
        ];
        if (count _actual >= 2) then {
            _revealPack pushBack [_pName, _actual, _guess, _uid];
        };
        _rank = _rank + 1;
    } forEach _rows;

    {
        [_html, _revealPack] remoteExec ["FADE_ggClient_showResults", _x];
    } forEach _participants;

    ["Geo-Guesser complete."] remoteExec ["systemChat", 0];
    [_taskId, "SUCCEEDED"] call BIS_fnc_taskSetState;
    [_taskId, _missionType, false] call FADE_cleanupMissionEntities;
    missionNamespace setVariable ["FADE_ggRound_" + _taskId, nil];
    missionNamespace setVariable ["FADE_ggRun_timeSec", nil];
    missionNamespace setVariable ["FADE_ggRun_difficulty", nil];

    if (!isNull _player && { (_player getVariable ["FADE_myMissionTaskId", ""]) == _taskId }) then {
        [_player, _taskId] call FADE_clearActiveMission;
    };
};
