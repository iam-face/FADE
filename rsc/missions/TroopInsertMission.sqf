// =============================================================================
// TroopInsertMission.sqf  -  multi-participant Troop Insert (server)
// FADE_troopInsertParams: [_missionType, _destPos, _player, _participants, _waveCount]
// =============================================================================
if (!isServer) exitWith {};
FADE_troopInsertMissionMain = {
if (isNil "FADE_troopInsertParams" || { count FADE_troopInsertParams < 5 }) exitWith {};
FADE_troopInsertParams params ["_missionType", "_destPos", "_player", "_participants", "_waveCount"];
if (_missionType != "TroopInsert") exitWith {};
if (!(_participants isEqualType []) || { count _participants == 0 }) exitWith {};
if (!(_waveCount isEqualType 0)) then { _waveCount = 1 };
_waveCount = (_waveCount max 1) min 10;

if (([] call FADE_resolveScenarioFriendlyUnits) isEqualTo []) exitWith {
    if (!isNull _player) then { [_player] call FADE_clearActiveMission };
    [_player, "MISSION ERROR", "No friendly units for the scenario faction. Apply scenario settings or pick a faction with infantry."] call FADE_missionErrorHint;
};
private _markerFriendly = missionNamespace getVariable ["FADE_markerColorFriendly", "ColorWEST"];
private _mkrJitter = missionNamespace getVariable ["FADE_jitterMarkerPos", { params [["_p", [0, 0, 0]]]; [_p] call FADE_normPos3 }];
private _taskId = "FADE_TroopInsert" + str (floor (time * 1000));
private _abortFlag = "FADE_troopInsertAborted_" + _taskId;
private _claimedVehKey = "FADE_troopInsert_claimedVehs_" + _taskId;
missionNamespace setVariable [_abortFlag, false];
missionNamespace setVariable [_claimedVehKey, [], true];

private _lzMinFromPickup = missionNamespace getVariable ["FADE_troopInsertLzMinDistFromPickup", 2500];
private _waveTimeout = missionNamespace getVariable ["FADE_troopInsertWaveTimeout", 620];
private _minDistFromBase = FADE_troopInsertExtractMinDistFromBase max FADE_minDistFromBase;
private _basePosInit = missionNamespace getVariable ["FADE_basePos", [0, 0, 0]];
private _basePickupRef = +_basePosInit;
if (count FADE_bSpPoints > 0) then {
    private _bSp = selectRandom FADE_bSpPoints;
    if (!isNull _bSp) then { _basePickupRef = getPosATL _bSp };
};

private _missionEnded = false;
private _pairs = [];
private _markerName = "";
private _prevLzSites = [];

private _fnc_metaChat = { [_participants, _this select 0] call FADE_troopMission_metaChat; };

private _fnc_deleteGroups = {
    params ["_groups"];
    [_groups, "FADE_troopInsertCleanupDone"] call FADE_troopMission_deleteFriendlyGroups;
};

private _pickupMarkers = [];
private _fnc_clearPickupMarkers = { [_pickupMarkers] call FADE_troopMission_clearPickupMarkers; };

private _fnc_createPickupMarker = {
    params ["_owner", "_pos", "_label"];
    [_taskId, "ti", _markerFriendly, _pickupMarkers, _owner, _pos, _label] call FADE_troopMission_createPickupMarker
};

private _fnc_squadRadio = { [_this select 0, _this select 1] call FADE_troopMission_squadRadio; };

private _fnc_squadPickupSideChat = {
    params ["_grp", "_atPos"];
    if (isNull _grp) exitWith {};
    private _cs = _grp getVariable ["FADE_callsign", "Alpha 1-1"];
    [_grp, format ["%1, holding Grid %2, awaiting pickup. Over.", _cs, mapGridPosition _atPos]] call _fnc_squadRadio;
};

private _fnc_unitClassesForParticipant = {
    params ["_participant"];
    private _units = [] call FADE_resolveScenarioFriendlyUnits;
    [_participant, _units] call FADE_troopMission_unitClassesForParticipant
};

private _fnc_spawnSquadAtBase = {
    params ["_participant", "_atPos"];
    private _unitCount = 6;
    if (!isNull _participant) then {
        private _veh = vehicle _participant;
        if (_veh != _participant && { _veh isKindOf "Helicopter" }) then {
            _unitCount = ([_veh] call FADE_getCargoSeats) max 1;
        };
    };
    private _friendlyUnits = [_participant] call _fnc_unitClassesForParticipant;
    if (_friendlyUnits isEqualTo []) exitWith { grpNull };
    private _sideFriendly = missionNamespace getVariable ["FADE_sideFriendly", west];
    private _classes = (_friendlyUnits select [0, _unitCount min count _friendlyUnits]);
    private _baseClass = _friendlyUnits select 0;
    for "_i" from (count _classes) to (_unitCount - 1) do { _classes pushBack _baseClass };
    private _grp = [_atPos, _sideFriendly, _classes] call FADE_spawnFriendlyInfantryGroupAt;
    [_grp] call (missionNamespace getVariable ["FADE_assignGroupCallsign", {}]);
    [_grp] call (missionNamespace getVariable ["FADE_attachNightStrobes", {}]);
    _grp setBehaviour "SAFE";
    _grp setCombatMode "GREEN";
    _grp setVariable ["FADE_troopInsertOwner", _participant, true];
    [_taskId, _grp] call FADE_missionEnt_registerGroup;
    [_grp, _atPos] call _fnc_squadPickupSideChat;
    _grp
};

private _fnc_spawnSquadsAtBaseForParticipants = {
    params ["_liveParticipants"];
    private _bSpPool = +(missionNamespace getVariable ["FADE_bSpPoints", []]);
    private _newPairs = [];
    {
        if (!isNull _x && { alive _x }) then {
            private _pickPos = [];
            if (count _bSpPool > 0) then {
                private _bsp = [_bSpPool, _x] call BIS_fnc_nearestPosition;
                if (!isNull _bsp) then {
                    _bSpPool = _bSpPool - [_bsp];
                    _pickPos = getPosATL _bsp;
                };
            };
            if (count _pickPos < 2 && { count _basePosInit >= 2 }) then { _pickPos = +_basePosInit };
            private _grp = [_x, _pickPos] call _fnc_spawnSquadAtBase;
            if (!isNull _grp) then {
                private _cs = _grp getVariable ["FADE_callsign", "Squad"];
                private _pickMkr = [_x, _pickPos, _cs] call _fnc_createPickupMarker;
                _newPairs pushBack [_grp, _x, _pickPos, _pickMkr];
            };
        };
    } forEach _liveParticipants;
    _newPairs
};

private _fnc_pickInsertLz = {
    private _lz = [_minDistFromBase, _prevLzSites, [], _lzMinFromPickup, _basePickupRef] call FADE_fnc_pickTroopHeliSiteAtCivZone;
    _lz
};

private _fnc_runTransportWave = {
    params ["_pairs", "_drop", "_waveIdx", "_waveTotal"];
    private _runFn = missionNamespace getVariable ["FADE_troopInsert_runTransport", nil];
    [
        _pairs, _waveIdx, _waveTotal, _runFn, _taskId, _markerName, _abortFlag, _claimedVehKey, _waveTimeout, _missionEnded,
        "ti", "FADE_troopInsertTransportDone", "FADE_troopInsertCleanupDone", _drop, _basePickupRef
    ] call FADE_troopMission_runTransportWave
};

private _fnc_finishMission = {
    params [
        ["_taskState", ""],
        ["_metaMsg", ""]
    ];
    if (_missionEnded) exitWith {};
    _missionEnded = true;
    missionNamespace setVariable [_abortFlag, true, true];
    if (_taskState != "") then { [_taskId, _taskState] call BIS_fnc_taskSetState };
    if (_metaMsg != "") then { [_metaMsg] call _fnc_metaChat };
    [_pairs apply { _x select 0 }] call _fnc_deleteGroups;
    [] call _fnc_clearPickupMarkers;
    if (_markerName != "") then { [_markerName] call FADE_deleteMarkerSafe };
    if (_taskId != "") then { [_taskId, "TroopInsert", false] call FADE_cleanupMissionEntities };
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
    [_pairList, _waveIdx, _taskId, "ti", "FADE_troopInsertTransportDone"] call FADE_troopMission_waveAllTransportOk
};

private _fnc_liveParticipants = { [_participants] call FADE_troopMission_liveParticipants };

// --- Mission setup ---
if (!isNull _player) then {
    _player setVariable ["FADE_myMission", "TroopInsert", true];
    _player setVariable ["FADE_myMissionTaskId", _taskId, true];
};
{
    if (!isNull _x && { _x != _player }) then {
        _x setVariable ["FADE_myMission", "TroopInsert", true];
        _x setVariable ["FADE_myMissionTaskId", _taskId, true];
    };
} forEach _participants;

[_taskId] call FADE_missionEnt_init;

private _operationName = "Operation Iron Resolve";
private _playerUid = if (isNull _player) then { "" } else { getPlayerUID _player };
private _singleList = missionNamespace getVariable ["FADE_singleMissions", []];
private _singleIdx = _singleList findIf {
    (_x param [0, ""]) == "TroopInsert" && { (_x param [3, ""]) == _playerUid }
};
if (_singleIdx >= 0) then { _operationName = (_singleList select _singleIdx) param [4, _operationName] };

_markerName = "FADE_insert_" + _taskId;
private _dropPos = +_destPos;
_prevLzSites pushBack _dropPos;

private _waveLabel = format ["%1 wave(s)", _waveCount];
private _sf = missionNamespace getVariable ["FADE_sideFriendly", west];
private _createTask = missionNamespace getVariable ["FADE_mission_createTask", {}];
private _taskDesc = format [
    "Insert friendly squads at the marked LZ. %1 participating transport(s). %2. Pick up at base; insert at LZ; RTB between waves.",
    count _participants,
    _waveLabel
];
if (_createTask isEqualTo {}) then {
    [_sf, _taskId, [_taskDesc, "Troop Insert", ""], _dropPos, "CREATED", 1, true, "move", true] call BIS_fnc_taskCreate;
} else {
    [_player, _taskId, _taskDesc, "Troop Insert", _dropPos, "move"] call _createTask;
};

{
    if (!isNull _x) then { _x setVariable ["FADE_myMissionMarker", _markerName, true] };
} forEach _participants;
private _insertLzRadius = 500;
[_taskId, _markerName + "_zone", _dropPos, _insertLzRadius, _markerFriendly] call FADE_mission_createRadiusMarker;
private _marker = [_markerName, [_dropPos] call FADE_normPos3, _taskId] call FADE_createRegisteredMarker;
_marker setMarkerType "mil_pickup";
_marker setMarkerColor _markerFriendly;
_marker setMarkerText _operationName;

private _grid = mapGridPosition _dropPos;
private _brief = format [
    "TROOP INSERT (%1)%2%2LZ (approx.): Grid %3%2%2Multi-transport insert. %4 participating pilot(s)/driver(s).",
    _waveLabel, toString [10], _grid, count _participants
];
if (!isNull _player) then { _player setVariable ["FADE_myMissionBrief", _brief, true] };
[format [
    "TROOP INSERT: %1. Wave 1/%2. Squads link up at base. Insert LZ Grid %3. Pick up as driver/commander within 200 m, then fly to the marked LZ.",
    _waveLabel, _waveCount, _grid
]] call _fnc_metaChat;
if (!isNull _player) then { [_player, "Troop Insert"] call FADE_notifyOthersMissionStarted };

for "_waveIndex" from 1 to _waveCount do {
    if (_missionEnded || { missionNamespace getVariable [_abortFlag, false] }) exitWith {};
    private _liveParticipants = [] call _fnc_liveParticipants;
    if (_liveParticipants isEqualTo []) exitWith {
        ["SUCCEEDED", "TROOP INSERT ENDED: All participating players left or were killed."] call _fnc_finishMission;
    };
    if (_waveIndex > 1) then {
        _dropPos = [] call _fnc_pickInsertLz;
        if (count _dropPos < 2) exitWith {
            ["SUCCEEDED", format ["TROOP INSERT ENDED: No valid LZ for wave %1/%2.", _waveIndex, _waveCount]] call _fnc_finishMission;
        };
        _prevLzSites pushBack _dropPos;
        private _mkPos = [_dropPos] call FADE_normPos3;
        _marker setMarkerPos _mkPos;
        [_markerName + "_zone", _mkPos, _insertLzRadius] call FADE_mission_setRadiusMarkerGeometry;
        [_taskId, _dropPos] call BIS_fnc_taskSetDestination;
        _grid = mapGridPosition _dropPos;
        [format [
            "TROOP INSERT: Wave %1/%2. RTB to base and pick up fresh squads. Insert LZ Grid %3.",
            _waveIndex, _waveCount, _grid
        ]] call _fnc_metaChat;
        sleep 8;
    };
    [] call _fnc_clearPickupMarkers;
    _pairs = [_liveParticipants] call _fnc_spawnSquadsAtBaseForParticipants;
    if (_pairs isEqualTo []) exitWith {
        ["FAILED", "MISSION ERROR: Could not spawn squads at base (check scenario friendly units)."] call _fnc_finishMission;
    };
    [_pairs, _dropPos, _waveIndex, _waveCount] call _fnc_runTransportWave;
    if (_missionEnded) exitWith {};
    if (missionNamespace getVariable [_abortFlag, false]) exitWith {
        ["CANCELED", "MISSION ABORTED."] call _fnc_finishMission;
    };
    if !([_pairs, _waveIndex] call _fnc_waveAllTransportOk) exitWith {
        ["FAILED", format ["TROOP INSERT FAILED: Wave %1/%2 transport incomplete.", _waveIndex, _waveCount]] call _fnc_finishMission;
    };
    if (_waveIndex >= _waveCount) exitWith {
        ["SUCCEEDED", format ["TROOP INSERT COMPLETE: All %1 wave(s) finished.", _waveCount]] call _fnc_finishMission;
    };
    [format [
        "TROOP INSERT: Wave %1/%2 complete. RTB to base. Stand by for the next pickup at base.",
        _waveIndex, _waveCount
    ]] call _fnc_metaChat;
};

if (!_missionEnded) then {
    if (missionNamespace getVariable [_abortFlag, false]) then {
        ["CANCELED", "MISSION ABORTED."] call _fnc_finishMission;
    } else {
        ["SUCCEEDED", format ["TROOP INSERT COMPLETE: All %1 wave(s) finished.", _waveCount]] call _fnc_finishMission;
    };
};

};

FADE_runMission_TroopInsert = {
    if (isNil "FADE_troopInsertParams") exitWith {
        private _p = missionNamespace getVariable ["FADE_missionRun_player", objNull];
        if (!isNull _p) then { [_p] call FADE_clearActiveMission };
        ["TROOP INSERT: Use START to open the participant list (include yourself)."] remoteExec ["systemChat", _p];
    };
    [] call FADE_troopInsertMissionMain;
};
