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
    [_player, "MISSION ERROR", "No friendly units for the scenario faction."] call FADE_missionErrorHint;
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

private _fnc_metaChat = { [_participants, _this select 0] call FADE_troopMission_metaChat; };

private _fnc_deleteFriendlyGroups = {
    params ["_groups"];
    [_groups, "FADE_troopExtractCleanupDone"] call FADE_troopMission_deleteFriendlyGroups;
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
private _fnc_clearPickupMarkers = { [_pickupMarkers] call FADE_troopMission_clearPickupMarkers; };

private _fnc_createPickupMarker = {
    params ["_owner", "_pos", "_label"];
    [_taskId, "te", _markerFriendly, _pickupMarkers, _owner, _pos, _label] call FADE_troopMission_createPickupMarker
};

private _fnc_squadRadio = { [_this select 0, _this select 1] call FADE_troopMission_squadRadio; };

private _fnc_unitClassesForParticipant = {
    params ["_participant"];
    [_participant, _friendlyUnits] call FADE_troopMission_unitClassesForParticipant
};

private _fnc_spawnWaveEnemies = {
    params ["_atPos"];
    [
        _atPos, _basePos, _enemyUnits, _sideEnemy, _taskId, _scaleOpforCount,
        0.5, 1, 5, 3, 5, 1000, true, true
    ] call FADE_mission_spawnFieldContactEnemies
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
        [_grp, false] call FADE_mission_applyPickupGroupPosture;
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
    private _runFn = missionNamespace getVariable ["FADE_troopExtract_runTransport", nil];
    [
        _pairs, _waveIdx, _waveTotal, _runFn, _taskId, _markerName, _abortFlag, _claimedVehKey, _waveTimeout, _missionEnded,
        "te", "FADE_troopExtractTransportDone", "FADE_troopExtractCleanupDone", _basePos
    ] call FADE_troopMission_runTransportWave
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
    [_participants] call FADE_troopMission_clearParticipantMissionVars;
    if (!isNull _player) then { [_player, _taskId] call FADE_clearActiveMission };
    missionNamespace setVariable [_abortFlag, nil];
    missionNamespace setVariable [_claimedVehKey, nil, true];
    missionNamespace setVariable ["FADE_currentMissionType", ""];
    missionNamespace setVariable ["FADE_currentMissionPlayer", objNull];
    [] call FADE_missionSlots_publish;
};

private _fnc_waveAllTransportOk = {
    params ["_pairList", "_waveIdx"];
    [_pairList, _waveIdx, _taskId, "te", "FADE_troopExtractTransportDone"] call FADE_troopMission_waveAllTransportOk
};

private _fnc_liveParticipants = { [_participants] call FADE_troopMission_liveParticipants };

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
private _createTask = missionNamespace getVariable ["FADE_mission_createTask", {}];
private _taskDesc = format [
    "Extract friendly squads from the field and RTB. %1 participating transport(s). %2.",
    count _participants,
    _waveLabel
];
if (_createTask isEqualTo {}) then {
    [_sf, _taskId, [_taskDesc, "Troop Extract", ""], _pickupPos, "CREATED", 1, true, "move", true] call BIS_fnc_taskCreate;
} else {
    [_player, _taskId, _taskDesc, "Troop Extract", _pickupPos, "move"] call _createTask;
};

{
    if (!isNull _x) then { _x setVariable ["FADE_myMissionMarker", _markerName, true] };
} forEach _participants;
private _zoneMarkerName = _markerName + "_zone";
private _extractPickupRadius = 200;
[_taskId, _zoneMarkerName, _pickupPos, _extractPickupRadius, _markerFriendly] call FADE_mission_createRadiusMarker;
private _marker = [_markerName, [_pickupPos] call FADE_normPos3, _taskId] call FADE_createRegisteredMarker;
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
        private _mkPos = [_pickupPos] call FADE_normPos3;
        _marker setMarkerPos _mkPos;
        [_zoneMarkerName, _mkPos, _extractPickupRadius] call FADE_mission_setRadiusMarkerGeometry;
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
