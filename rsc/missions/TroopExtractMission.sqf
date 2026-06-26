// =============================================================================
// TroopExtractMission.sqf  -  multi-participant Troop Extract (server)
// FADE_troopExtractParams: [_missionType, _destPos, _player, _participants, _waveCount]
// =============================================================================
if (!isServer) exitWith {};
FADE_troopExtractMissionMain = {
if (isNil "FADE_troopExtractParams" || { count FADE_troopExtractParams < 5 }) exitWith {};
FADE_troopExtractParams params ["_missionType", "_destPos", "_player", "_participants", "_waveCount"];
if (_missionType != "TroopExtract") exitWith {};
if (!(_participants isEqualType []) || { count _participants == 0 }) exitWith {};
if (!(_waveCount isEqualType 0)) then { _waveCount = 1 };
_waveCount = (_waveCount max 1) min 10;

private _friendlyUnits = [] call FADE_resolveScenarioFriendlyUnits;
if (_friendlyUnits isEqualTo []) exitWith {
    if (!isNull _player) then { [_player] call FADE_clearActiveMission };
    ["MISSION ERROR: No friendly units for the scenario faction."] remoteExec ["systemChat", _player];
};
private _enemyUnits = [] call FADE_resolveScenarioEnemyUnits;
private _sideFriendly = missionNamespace getVariable ["FADE_sideFriendly", west];
private _sideEnemy = missionNamespace getVariable ["FADE_sideEnemy", east];
private _markerFriendly = missionNamespace getVariable ["FADE_markerColorFriendly", "ColorWEST"];
private _mkrJitter = missionNamespace getVariable ["FADE_jitterMarkerPos", { params [["_p", [0, 0, 0]]]; [_p] call FADE_normPos3 }];
private _basePos = missionNamespace getVariable ["FADE_basePos", [0, 0, 0]];
private _scaleOpforCount = missionNamespace getVariable ["FADE_scaleOpforCount", { params ["_n", "_min"]; _n max _min }];
private _minDistFromBase = FADE_troopInsertExtractMinDistFromBase max 1000;
private _waveTimeout = missionNamespace getVariable ["FADE_troopInsertWaveTimeout", 620];

private _taskId = "FADE_TroopExtract" + str (floor (time * 1000));
private _abortFlag = "FADE_troopExtractAborted_" + _taskId;
private _claimedVehKey = "FADE_troopExtract_claimedVehs_" + _taskId;
missionNamespace setVariable [_abortFlag, false];
missionNamespace setVariable [_claimedVehKey, [], true];

private _missionEnded = false;
private _pairs = [];
private _enemyGroups = [];
private _markerName = "";
private _pickupPos = +_destPos;
private _prevPickupSites = [];
private _waveIndex = 0;

private _fnc_metaChat = {
    params ["_msg"];
    { [_msg] remoteExec ["systemChat", _x] } forEach _participants;
};

private _fnc_deleteFriendlyGroups = {
    params ["_groups"];
    {
        if (!isNull _x) then {
            _x setVariable ["FADE_troopExtractCleanupDone", true, true];
            { if (!isNull _x) then { detach _x; deleteVehicle _x } } forEach (_x getVariable ["FADE_irStrobes", []]);
            { if (!isNull _x) then { deleteVehicle _x } } forEach units _x;
            deleteGroup _x;
        };
    } forEach _groups;
};

private _fnc_deleteEnemyGroups = {
    params ["_groups"];
    {
        if (!isNull _x) then {
            [_x] call FADE_missionEnt_deleteGroupFull;
        };
    } forEach _groups;
};

private _pickupMarkers = [];
private _fnc_clearPickupMarkers = {
    {
        _x params ["_mkrName", "_owner"];
        if (!isNull _owner) then {
            [_mkrName] remoteExec ["FAC_troopInsertClient_deletePickupMarker", _owner];
        };
    } forEach _pickupMarkers;
    _pickupMarkers = [];
};

private _fnc_createPickupMarker = {
    params ["_owner", "_pos", "_label"];
    if (isNull _owner) exitWith { "" };
    private _mkr = format ["FADE_te_pick_%1_%2", _taskId, getPlayerUID _owner];
    [_mkr, _pos, _label, _markerFriendly] remoteExec ["FAC_troopInsertClient_createPickupMarker", _owner];
    _pickupMarkers pushBack [_mkr, _owner];
    _mkr
};

private _fnc_squadRadio = {
    params ["_grp", "_msg"];
    if (isNull _grp || { count units _grp == 0 }) exitWith {};
    private _ldr = leader _grp;
    if (isNull _ldr || { !alive _ldr }) exitWith {};
    [_ldr, _msg] call FADE_aiSideChat;
};

private _fnc_unitClassesForParticipant = {
    params ["_participant"];
    if (isNull _participant || { !alive _participant }) exitWith { _friendlyUnits };
    private _cfgRoot = configFile >> "CfgVehicles";
    private _pFac = getText (_cfgRoot >> typeOf _participant >> "faction");
    if (_pFac == "") exitWith { _friendlyUnits };
    private _matched = _friendlyUnits select { getText (_cfgRoot >> _x >> "faction") == _pFac };
    if (count _matched > 0) then { _matched } else { _friendlyUnits }
};

private _fnc_spawnWaveEnemies = {
    params ["_atPos"];
    private _groups = [];
    if (count _enemyUnits == 0) exitWith { _groups };
    if (random 1 >= 0.5) exitWith { _groups };
    private _numEnemyGroups = [1 + floor random 5, 1] call _scaleOpforCount;
    private _minDistFromBase = 1000;
    for "_g" from 0 to (_numEnemyGroups - 1) do {
        private _grpPos = [];
        for "_try" from 0 to 10 do {
            private _dist = 500 + random 1500;
            private _candidate = _atPos getPos [_dist, random 360];
            _candidate = [[_candidate, 0, 30, 3, 1, 0.4, 0, [], _candidate], _candidate] call FADE_findSafePosArray;
            if (count _candidate < 2) then { _candidate = _atPos getPos [_dist, random 360] };
            if ((_candidate distance _basePos) >= _minDistFromBase) exitWith { _grpPos = _candidate };
        };
        if (count _grpPos < 2) then {
            _grpPos = _atPos getPos [800, (_atPos getDir _basePos) + 180];
        };
        private _grpSize = [3 + floor random 5, 2] call _scaleOpforCount;
        private _shuffled = _enemyUnits call BIS_fnc_arrayShuffle;
        private _grpUnits = (_shuffled select [0, _grpSize min count _shuffled]);
        if (count _grpUnits == 0) then { _grpUnits = [_enemyUnits select 0] };
        private _grp = [_grpPos, _sideEnemy, _grpUnits] call BIS_fnc_spawnGroup;
        [_grp] call FAC_applyEnemyScenarioToGroup;
        _grp setBehaviour "AWARE";
        _grp setCombatMode "RED";
        _grp addWaypoint [_atPos, 0];
        [_taskId, _grp] call FADE_missionEnt_registerGroup;
        _groups pushBack _grp;
    };
    if (count _groups > 0) then {
        [_groups, _basePos] call FADE_registerEnemyRetreat;
    };
    _groups
};

private _fnc_spawnSquadInField = {
    params ["_participant", "_atPos", "_inContact"];
    private _pickupCount = 2 + floor random 9;
    private _classes = ([_participant] call _fnc_unitClassesForParticipant);
    private _pickClasses = (_classes select [0, _pickupCount min count _classes]);
    for "_i" from (count _pickClasses) to (_pickupCount - 1) do { _pickClasses pushBack (_classes select 0) };
    private _wpPos = _atPos getPos [10, random 360];
    _wpPos = [[_wpPos, 0, 15, 2, 1, 0.3, 0, [], _wpPos], _wpPos] call FADE_findSafePosArray;
    if (count _wpPos < 2) then { _wpPos = _atPos getPos [10, random 360] };
    private _grp = [_wpPos, _sideFriendly, _pickClasses] call BIS_fnc_spawnGroup;
    [_grp] call (missionNamespace getVariable ["FADE_assignGroupCallsign", {}]);
    [_grp] call (missionNamespace getVariable ["FADE_attachNightStrobes", {}]);
    if (_inContact) then {
        _grp setBehaviour "COMBAT";
        _grp setFormation "DIAMOND";
    } else {
        _grp setBehaviour "SAFE";
        _grp setCombatMode "GREEN";
        _grp setFormation "STAG COLUMN";
    };
    _grp addWaypoint [_wpPos, 0];
    _grp setVariable ["FADE_troopExtractOwner", _participant, true];
    [_taskId, _grp] call FADE_missionEnt_registerGroup;
    private _cs = _grp getVariable ["FADE_callsign", "Alpha 1-1"];
    [_grp, format ["%1, holding Grid %2, awaiting exfil. Over.", _cs, mapGridPosition _atPos]] call _fnc_squadRadio;
    _grp
};

private _fnc_spawnSquadsForParticipants = {
    params ["_liveParticipants", "_sharedPickup", "_inContact"];
    private _liveCount = count _liveParticipants;
    private _spawnJitterR = if (_liveCount <= 1) then { 0 } else { 25 };
    private _newPairs = [];
    {
        private _angle = (_forEachIndex * (360 / (_liveCount max 1))) + (random 20);
        private _spawnPos = [_sharedPickup, _spawnJitterR, _angle] call BIS_fnc_relPos;
        if (count _spawnPos < 3) then { _spawnPos set [2, 0] };
        private _grp = [_x, _spawnPos, _inContact] call _fnc_spawnSquadInField;
        if (!isNull _grp) then {
            private _cs = _grp getVariable ["FADE_callsign", "Squad"];
            private _pickMkr = [_x, _sharedPickup, _cs] call _fnc_createPickupMarker;
            _newPairs pushBack [_grp, _x, _sharedPickup, _pickMkr];
        };
    } forEach _liveParticipants;
    _newPairs
};

private _fnc_pickPickupSite = {
    [_minDistFromBase, _prevPickupSites, []] call FADE_fnc_pickTroopHeliSiteAtCivZone
};

private _fnc_runTransportWave = {
    params ["_pairs", "_waveIdx", "_waveTotal"];
    if (_missionEnded) exitWith { [] };
    private _runFn = missionNamespace getVariable ["FADE_troopExtract_runTransport", nil];
    if (isNil "_runFn") exitWith { [] };
    missionNamespace setVariable [_claimedVehKey, [], true];
    private _waveOkKeyPrefix = "FADE_teWaveOk_" + _taskId + "_";
    private _scripts = [];
    private _waveStart = time;
    {
        _x params ["_grp", "_owner", "_pick", "_pickMkr"];
        if (!isNull _owner) then {
            _owner setVariable [_waveOkKeyPrefix + str _waveIdx, false, false];
        };
        if (!isNull _grp && { count units _grp > 0 }) then {
            _grp setVariable ["FADE_troopExtractTransportDone", false, true];
            private _scr = [_grp, _owner, _pick, _basePos, _taskId, _markerName, _abortFlag, _claimedVehKey, _pickMkr, _waveIdx, _waveTotal] spawn _runFn;
            _scripts pushBack [_scr, _grp, _owner];
        };
    } forEach _pairs;
    if (count _scripts == 0) exitWith { _scripts };
    waitUntil {
        sleep 2;
        if (_missionEnded || { missionNamespace getVariable [_abortFlag, false] }) exitWith { true };
        ({ scriptDone (_x select 0) } count _scripts) == count _scripts || { time - _waveStart > _waveTimeout }
    };
    {
        _x params ["_scr", "_grp", "_owner"];
        private _ownerOk = !isNull _owner && { _owner getVariable [_waveOkKeyPrefix + str _waveIdx, false] };
        private _grpOk = !isNull _grp && { _grp getVariable ["FADE_troopExtractTransportDone", false] };
        if (!_ownerOk && { !_grpOk }) then {
            if (!isNull _grp && { !(_grp getVariable ["FADE_troopExtractCleanupDone", false]) }) then {
                [_grp] call FADE_missionEnt_deleteGroupFull;
            };
            if (!isNull _owner) then {
                [format ["TROOP EXTRACT: Transport failed or timed out (wave %1/%2).", _waveIdx, _waveTotal]] remoteExec ["systemChat", _owner];
            };
        };
    } forEach _scripts;
    _scripts
};

private _fnc_cleanupWave = {
    [_pairs apply { _x select 0 }] call _fnc_deleteFriendlyGroups;
    [_enemyGroups] call _fnc_deleteEnemyGroups;
    _enemyGroups = [];
    [] call _fnc_clearPickupMarkers;
    _pairs = [];
};

private _fnc_finishMission = {
    params [
        ["_taskState", ""],
        ["_metaMsg", ""]
    ];
    if (_missionEnded) exitWith {};
    _missionEnded = true;
    missionNamespace setVariable [_abortFlag, true, true];
    [] call _fnc_cleanupWave;
    if (_taskState != "") then { [_taskId, _taskState] call BIS_fnc_taskSetState };
    if (_metaMsg != "") then { [_metaMsg] call _fnc_metaChat };
    if (_markerName != "") then { [_markerName] call FADE_deleteMarkerSafe };
    if (_taskId != "") then { [_taskId, "TroopExtract", false] call FADE_cleanupMissionEntities };
    {
        if (!isNull _x) then {
            _x setVariable ["FADE_myMission", "", true];
            _x setVariable ["FADE_myMissionTaskId", nil, true];
            _x setVariable ["FADE_myMissionMarker", nil, true];
            _x setVariable ["FADE_myMissionMarkerEnd", nil, true];
            _x setVariable ["FADE_myMissionBrief", nil, true];
        };
    } forEach _participants;
    if (!isNull _player) then { [_player, _taskId] call FADE_clearActiveMission };
    missionNamespace setVariable [_abortFlag, nil];
    missionNamespace setVariable [_claimedVehKey, nil, true];
    missionNamespace setVariable ["FADE_currentMissionType", ""];
    missionNamespace setVariable ["FADE_currentMissionPlayer", objNull];
    [] call FADE_missionSlots_publish;
};

private _fnc_waveAllTransportOk = {
    params ["_pairList", "_waveIdx"];
    if (_pairList isEqualTo []) exitWith { false };
    private _waveOkKey = "FADE_teWaveOk_" + _taskId + "_" + str _waveIdx;
    private _ok = true;
    {
        _x params ["_grp", "_owner"];
        private _ownerOk = !isNull _owner && { _owner getVariable [_waveOkKey, false] };
        private _grpOk = !isNull _grp && { _grp getVariable ["FADE_troopExtractTransportDone", false] };
        if (!_ownerOk && { !_grpOk }) then { _ok = false };
    } forEach _pairList;
    _ok
};

private _fnc_liveParticipants = {
    private _live = [];
    { if (!isNull _x && { alive _x }) then { _live pushBack _x } } forEach _participants;
    _live
};

// --- Mission setup ---
if (!isNull _player) then {
    _player setVariable ["FADE_myMission", "TroopExtract", true];
    _player setVariable ["FADE_myMissionTaskId", _taskId, true];
};
{
    if (!isNull _x && { _x != _player }) then {
        _x setVariable ["FADE_myMission", "TroopExtract", true];
        _x setVariable ["FADE_myMissionTaskId", _taskId, true];
    };
} forEach _participants;

[_taskId] call FADE_missionEnt_init;

private _operationName = "Operation Iron Resolve";
private _playerUid = if (isNull _player) then { "" } else { getPlayerUID _player };
private _singleList = missionNamespace getVariable ["FADE_singleMissions", []];
private _singleIdx = _singleList findIf {
    (_x param [0, ""]) == "TroopExtract" && { (_x param [3, ""]) == _playerUid }
};
if (_singleIdx >= 0) then { _operationName = (_singleList select _singleIdx) param [4, _operationName] };

_markerName = "FADE_extract_" + _taskId;
_prevPickupSites pushBack _pickupPos;

private _waveLabel = format ["%1 wave(s)", _waveCount];
private _sf = _sideFriendly;
private _grid = mapGridPosition _pickupPos;
private _taskDesc = format [
    "Extract friendly squads from the field and RTB. %1 participating transport(s). %2.",
    count _participants,
    _waveLabel
];
[_sf, _taskId, [_taskDesc, "Troop Extract", ""], _pickupPos, "CREATED", 1, true, "move", true] call BIS_fnc_taskCreate;

{
    if (!isNull _x) then { _x setVariable ["FADE_myMissionMarker", _markerName, true] };
} forEach _participants;
private _marker = createMarker [_markerName, [_pickupPos, 100] call _mkrJitter];
[_taskId, _markerName] call FADE_missionEnt_registerMarker;
_marker setMarkerType "mil_pickup";
_marker setMarkerColor _markerFriendly;
_marker setMarkerText _operationName;

private _brief = format [
    "TROOP EXTRACT (%1)%2%2Pickup (approx.): Grid %3%2%2Recover squads and RTB. %4 participating pilot(s)/driver(s).",
    _waveLabel, toString [10], _grid, count _participants
];
if (!isNull _player) then { _player setVariable ["FADE_myMissionBrief", _brief, true] };
[format [
    "TROOP EXTRACT: %1. Wave 1/%2. Proceed to pickup Grid %3. Load squads and RTB to base.",
    _waveLabel, _waveCount, _grid
]] call _fnc_metaChat;
if (!isNull _player) then { [_player, "Troop Extract"] call FADE_notifyOthersMissionStarted };

for "_waveIndex" from 1 to _waveCount do {
    if (_missionEnded || { missionNamespace getVariable [_abortFlag, false] }) exitWith {};
    private _liveParticipants = [] call _fnc_liveParticipants;
    if (_liveParticipants isEqualTo []) exitWith {
        ["SUCCEEDED", "TROOP EXTRACT ENDED: All participating players left or were killed."] call _fnc_finishMission;
    };
    if (_waveIndex > 1) then {
        _pickupPos = [] call _fnc_pickPickupSite;
        if (count _pickupPos < 2) exitWith {
            ["SUCCEEDED", format ["TROOP EXTRACT ENDED: No valid pickup for wave %1/%2.", _waveIndex, _waveCount]] call _fnc_finishMission;
        };
        _prevPickupSites pushBack _pickupPos;
        _grid = mapGridPosition _pickupPos;
        private _mkPos = [_pickupPos, 100] call _mkrJitter;
        _marker setMarkerPos _mkPos;
        [_taskId, _pickupPos] call BIS_fnc_taskSetDestination;
        [format [
            "TROOP EXTRACT: Wave %1/%2. New pickup Grid %3. Proceed to the field, load squads, RTB.",
            _waveIndex, _waveCount, _grid
        ]] call _fnc_metaChat;
        sleep 8;
    } else {
        _pickupPos = +_destPos;
    };
    _enemyGroups = [_pickupPos] call _fnc_spawnWaveEnemies;
    private _inContact = count _enemyGroups > 0;
    _pairs = [_liveParticipants, _pickupPos, _inContact] call _fnc_spawnSquadsForParticipants;
    if (_pairs isEqualTo []) exitWith {
        [_enemyGroups] call _fnc_deleteEnemyGroups;
        ["FAILED", "MISSION ERROR: Could not spawn extract squads."] call _fnc_finishMission;
    };
    [_pairs, _waveIndex, _waveCount] call _fnc_runTransportWave;
    if (_missionEnded) exitWith {};
    if (missionNamespace getVariable [_abortFlag, false]) exitWith {
        ["CANCELED", "MISSION ABORTED."] call _fnc_finishMission;
    };
    if !([_pairs, _waveIndex] call _fnc_waveAllTransportOk) exitWith {
        [] call _fnc_cleanupWave;
        ["FAILED", format ["TROOP EXTRACT FAILED: Wave %1/%2 incomplete.", _waveIndex, _waveCount]] call _fnc_finishMission;
    };
    [] call _fnc_cleanupWave;
    if (_waveIndex >= _waveCount) exitWith {
        ["SUCCEEDED", format ["TROOP EXTRACT COMPLETE: All %1 wave(s) finished.", _waveCount]] call _fnc_finishMission;
    };
    [format [
        "TROOP EXTRACT: Wave %1/%2 complete. Stand by for the next pickup tasking.",
        _waveIndex, _waveCount
    ]] call _fnc_metaChat;
};

if (!_missionEnded) then {
    if (missionNamespace getVariable [_abortFlag, false]) then {
        ["CANCELED", "MISSION ABORTED."] call _fnc_finishMission;
    } else {
        ["SUCCEEDED", format ["TROOP EXTRACT COMPLETE: All %1 wave(s) finished.", _waveCount]] call _fnc_finishMission;
    };
};

};

FADE_runMission_TroopExtract = {
    if (isNil "FADE_troopExtractParams") exitWith {
        private _p = missionNamespace getVariable ["FADE_missionRun_player", objNull];
        if (!isNull _p) then { [_p] call FADE_clearActiveMission };
        ["TROOP EXTRACT: Use START to open the participant list (include yourself)."] remoteExec ["systemChat", _p];
    };
    [] call FADE_troopExtractMissionMain;
};
