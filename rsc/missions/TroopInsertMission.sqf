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
    ["MISSION ERROR: No friendly units for the scenario faction. Apply scenario settings or pick a faction with infantry."] remoteExec ["systemChat", _player];
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

private _fnc_metaChat = {
    params ["_msg"];
    { [_msg] remoteExec ["systemChat", _x] } forEach _participants;
};

private _fnc_deleteGroups = {
    params ["_groups"];
    {
        if (!isNull _x) then {
            _x setVariable ["FADE_troopInsertCleanupDone", true, true];
            { if (!isNull _x) then { detach _x; deleteVehicle _x } } forEach (_x getVariable ["FADE_irStrobes", []]);
            { if (!isNull _x) then { deleteVehicle _x } } forEach units _x;
            deleteGroup _x;
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
    private _mkr = format ["FADE_ti_pick_%1_%2", _taskId, getPlayerUID _owner];
    private _labelOut = if (_label != "") then { _label } else { "Squad link-up" };
    [_mkr, _pos, _labelOut, _markerFriendly] remoteExec ["FAC_troopInsertClient_createPickupMarker", _owner];
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

private _fnc_squadPickupSideChat = {
    params ["_grp", "_atPos"];
    if (isNull _grp) exitWith {};
    private _cs = _grp getVariable ["FADE_callsign", "Alpha 1-1"];
    [_grp, format ["%1, holding Grid %2, awaiting pickup. Over.", _cs, mapGridPosition _atPos]] call _fnc_squadRadio;
};

private _fnc_unitClassesForParticipant = {
    params ["_participant"];
    private _units = [] call FADE_resolveScenarioFriendlyUnits;
    if (isNull _participant || { !alive _participant }) exitWith { _units };
    private _cfgRoot = configFile >> "CfgVehicles";
    private _pFac = getText (_cfgRoot >> typeOf _participant >> "faction");
    if (_pFac == "") exitWith { _units };
    private _matched = _units select { getText (_cfgRoot >> _x >> "faction") == _pFac };
    if (count _matched > 0) then { _matched } else { _units }
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
    private _grp = [_atPos, _sideFriendly, _classes] call BIS_fnc_spawnGroup;
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
    if (_missionEnded) exitWith { [] };
    private _runFn = missionNamespace getVariable ["FADE_troopInsert_runTransport", nil];
    if (isNil "_runFn") exitWith { [] };
    missionNamespace setVariable [_claimedVehKey, [], true];
    private _waveOkKeyPrefix = "FADE_tiWaveOk_" + _taskId + "_";
    private _scripts = [];
    private _waveStart = time;
    {
        _x params ["_grp", "_owner", ["_pick", []], ["_pickMkr", ""]];
        private _pickupPos = if (count _pick >= 2) then { _pick } else { _basePickupRef };
        if (!isNull _owner) then {
            _owner setVariable [_waveOkKeyPrefix + str _waveIdx, false, false];
        };
        if (!isNull _grp && { count units _grp > 0 }) then {
            _grp setVariable ["FADE_troopInsertTransportDone", false, true];
            private _scr = [_grp, _owner, _pickupPos, _drop, _taskId, _markerName, _abortFlag, _claimedVehKey, _pickMkr, _waveIdx, _waveTotal] spawn _runFn;
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
        private _grpOk = !isNull _grp && { _grp getVariable ["FADE_troopInsertTransportDone", false] };
        if (!_ownerOk && { !_grpOk }) then {
            if (!isNull _grp && { !(_grp getVariable ["FADE_troopInsertCleanupDone", false]) }) then {
                { if (!isNull _x) then { detach _x; deleteVehicle _x } } forEach (_grp getVariable ["FADE_irStrobes", []]);
                { if (!isNull _x) then { deleteVehicle _x } } forEach units _grp;
                deleteGroup _grp;
            };
            if (!isNull _owner) then {
                [format ["TROOP INSERT: Your squad transport failed or timed out (wave %1/%2).", _waveIdx, _waveTotal]] remoteExec ["systemChat", _owner];
            };
        };
    } forEach _scripts;
    _scripts
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
    private _waveOkKey = "FADE_tiWaveOk_" + _taskId + "_" + str _waveIdx;
    private _ok = true;
    {
        _x params ["_grp", "_owner"];
        private _ownerOk = !isNull _owner && { _owner getVariable [_waveOkKey, false] };
        private _grpOk = !isNull _grp && { _grp getVariable ["FADE_troopInsertTransportDone", false] };
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
private _taskDesc = format [
    "Insert friendly squads at the marked LZ. %1 participating transport(s). %2. Pick up at base; insert at LZ; RTB between waves.",
    count _participants,
    _waveLabel
];
[_sf, _taskId, [_taskDesc, "Troop Insert", ""], _dropPos, "CREATED", 1, true, "move", true] call BIS_fnc_taskCreate;

{
    if (!isNull _x) then { _x setVariable ["FADE_myMissionMarker", _markerName, true] };
} forEach _participants;
private _marker = createMarker [_markerName, [_dropPos, 100] call _mkrJitter];
[_taskId, _markerName] call FADE_missionEnt_registerMarker;
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
        private _mkPos = [_dropPos, 100] call _mkrJitter;
        _marker setMarkerPos _mkPos;
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
