// =============================================================================
// MissionPlaythroughSuite.sqf  -  sequential mission init + mechanic smoke tests.
// Complements MissionTestSuite.sqf (static smoke). Mutates live mission state.
//
// RECOMMENDED (debug-tools lobby param adds scroll-wheel action):
//   [] call FAC_playthroughSuite_execAll
//
// Server only (debug console, dedicated host):
//   [player] remoteExec ["FAC_playthroughSuite_execServer", 2]
//
// RPT filter: [FAC Playthrough]
// Target: full suite <=10 min, zero player input after exec (server teleports + cheats).
// =============================================================================

FAC_playthroughSuite__suiteBudgetSec = 600;

FAC_playthroughSuite__missionTypes = [
    "AreaOfOperations", "Operation", "Raid", "Invasion", "TroopInsert", "TroopExtract", "Cargo", "MineClearing",
    "CASEVAC", "CSAR", "AssetRetrieval", "SearchDestroy", "InterceptConvoy", "EscapeEvasion", "GeoGuesser",
    "CAS", "HVT", "Hostage", "ClearArea"
];

FAC_playthroughSuite__counterAttackTypes = [
    "AssetRetrieval", "SearchDestroy", "ClearArea", "CAS", "Raid", "Hostage", "HVT", "CASEVAC", "CSAR"
];

FAC_playthroughSuite__longInitTypes = ["AreaOfOperations", "Operation", "Raid", "Invasion", "InterceptConvoy", "AssetRetrieval"];
FAC_playthroughSuite__initTimeoutSec = 14;
FAC_playthroughSuite__longInitTimeoutSec = 22;
FAC_playthroughSuite__convoyInitTimeoutSec = 40;
FAC_playthroughSuite__cleanupTimeoutSec = 8;
FAC_playthroughSuite__betweenMissionSec = 0.5;
FAC_playthroughSuite__enableQrfProbe = false;
FAC_playthroughSuite__qrfWaitSec = 6;

FAC_playthroughSuite__budgetRemaining = {
    private _start = missionNamespace getVariable ["FAC_playthroughSuite_startTime", time];
    ((_start + FAC_playthroughSuite__suiteBudgetSec) - time) max 0
};

FAC_playthroughSuite__budgetExceeded = {
    ([] call FAC_playthroughSuite__budgetRemaining) <= 0
};

FAC_playthroughSuite__budgetCap = {
    params ["_default", ["_floor", 2]];
    private _rem = [] call FAC_playthroughSuite__budgetRemaining;
    (_default min _rem) max _floor
};

FAC_playthroughSuite__log = {
    params ["_level", "_msg"];
    private _line = format ["[FAC Playthrough] %1: %2", _level, _msg];
    diag_log _line;
    _line
};

FAC_playthroughSuite__chat = {
    params ["_msg", ["_to", objNull]];
    if (!isServer) exitWith {};
    if (!isNull _to && { isPlayer _to }) then {
        [_msg] remoteExec ["systemChat", _to];
    } else {
        [_msg] remoteExec ["systemChat", 0];
    };
};

FAC_playthroughSuite__entSummary = {
    params ["_taskId"];
    if (_taskId == "") exitWith { [0, 0, 0, 0] };
    private _ent = [_taskId] call FADE_missionEnt_get;
    private _grps = count (_ent getOrDefault ["groups", []]);
    private _refs = count (_ent getOrDefault ["groupRefs", []]);
    private _vehs = count (_ent getOrDefault ["vehicles", []]);
    private _mkrs = count (_ent getOrDefault ["markers", []]);
    [_grps, _refs, _vehs, _mkrs]
};

FAC_playthroughSuite__getDestPos = {
    params ["_player", "_missionType"];
    private _global = missionNamespace getVariable ["FADE_globalMission", []];
    if (count _global >= 3 && { (_global select 0) == _missionType } && { [_global, _player] call FADE_isMissionEntryOwnedByPlayer }) exitWith {
        +(_global select 2)
    };
    private _singleList = missionNamespace getVariable ["FADE_singleMissions", []];
    {
        if ((_x select 0) == _missionType && { [_x, _player] call FADE_isMissionEntryOwnedByPlayer }) exitWith {
            +(_x select 2)
        };
    } forEach _singleList;
    []
};

FAC_playthroughSuite__saveCounterAttackTiming = {
    private _keys = [
        "FADE_counterAttackFirstDelayMin", "FADE_counterAttackFirstDelayMax",
        "FADE_counterAttackBetweenMin", "FADE_counterAttackBetweenMax",
        "FADE_counterAttackPollInterval", "FADE_counterAttackDetectionRadius"
    ];
    private _saved = createHashMap;
    { _saved set [_x, missionNamespace getVariable [_x, nil]] } forEach _keys;
    _saved
};

FAC_playthroughSuite__restoreCounterAttackTiming = {
    params ["_saved"];
    if (!(_saved isEqualType createHashMap)) exitWith {};
    {
        private _v = _saved get _x;
        if (isNil "_v") then {
            missionNamespace setVariable [_x, nil];
        } else {
            missionNamespace setVariable [_x, _v];
        };
    } forEach (keys _saved);
};

FAC_playthroughSuite__fastCounterAttackTiming = {
    missionNamespace setVariable ["FADE_counterAttackFirstDelayMin", 1];
    missionNamespace setVariable ["FADE_counterAttackFirstDelayMax", 2];
    missionNamespace setVariable ["FADE_counterAttackBetweenMin", 3];
    missionNamespace setVariable ["FADE_counterAttackBetweenMax", 5];
    missionNamespace setVariable ["FADE_counterAttackPollInterval", 1];
};

FAC_playthroughSuite__teleportPlayer = {
    params ["_player", "_pos"];
    if (isNull _player || { count _pos < 2 }) exitWith {};
    private _p = if (count _pos >= 3) then { +_pos } else { [(_pos select 0), (_pos select 1), 0] };
    private _veh = vehicle _player;
    if (_veh != _player && { _veh isKindOf "Air" }) then {
        _veh setPosATL [_p select 0, _p select 1, (_p select 2) + 1.5 max 1];
    } else {
        _player setPosATL _p;
    };
};

FAC_playthroughSuite__restorePlayerHome = {
    params ["_player"];
    private _home = missionNamespace getVariable ["FAC_playthroughSuite_playerHome", []];
    if (!isNull _player && { count _home >= 2 }) then {
        [_player, _home] call FAC_playthroughSuite__teleportPlayer;
    };
};

FAC_playthroughSuite__startMission = {
    params ["_missionType", "_player"];
    private _uid = getPlayerUID _player;
    missionNamespace setVariable ["FADE_startMission_bypassDisabled", true];
    switch _missionType do {
        case "TroopInsert": {
            [[_uid], 1, _player] call FADE_startTroopInsert;
        };
        case "TroopExtract": {
            [[_uid], 1, _player] call FADE_startTroopExtract;
        };
        case "EscapeEvasion": {
            [[_uid], _player] call FADE_startEscapeEvasion;
        };
        case "GeoGuesser": {
            [[_uid], 30, "Normal", _player] call FADE_startGeoGuesser;
        };
        default {
            [_missionType, _player] call FADE_startMission;
        };
    };
    missionNamespace setVariable ["FADE_startMission_bypassDisabled", false];
};

FAC_playthroughSuite__protectMedevacSurvivors = {
    params ["_taskId"];
    if (_taskId == "") exitWith {};
    if (isNil "FAC_playthroughSuite__findFriendlyCasualtyGroup") exitWith {};
    private _grp = [_taskId] call FAC_playthroughSuite__findFriendlyCasualtyGroup;
    if (isNull _grp) exitWith {};
    { if (alive _x) then { _x setDamage 0; _x allowDamage false } } forEach units _grp;
};

FAC_playthroughSuite__waitForInit = {
    params ["_player", "_missionType", "_timeoutSec"];
    _timeoutSec = [_timeoutSec, 3] call FAC_playthroughSuite__budgetCap;
    private _deadline = time + _timeoutSec;
    private _taskId = "";
    private _state = "";
    private _healedMedevac = false;
    waitUntil {
        sleep 0.25;
        _taskId = _player getVariable ["FADE_myMissionTaskId", ""];
        if (_taskId != "" && { !_healedMedevac } && { _missionType in ["CASEVAC", "CSAR"] }) then {
            [_taskId] call FAC_playthroughSuite__protectMedevacSurvivors;
            _healedMedevac = true;
        };
        if (_taskId != "") then {
            _state = _taskId call BIS_fnc_taskState;
            if (_state in ["ASSIGNED", "CREATED", "SUCCEEDED", "FAILED", "CANCELED"]) exitWith { true };
        };
        time >= _deadline || { [] call FAC_playthroughSuite__budgetExceeded }
    };
    [_taskId, _state, time < _deadline && { !([] call FAC_playthroughSuite__budgetExceeded) }]
};

FAC_playthroughSuite__waitForCleanup = {
    params ["_player", "_timeoutSec"];
    _timeoutSec = [_timeoutSec, 1] call FAC_playthroughSuite__budgetCap;
    private _deadline = time + _timeoutSec;
    waitUntil {
        sleep 0.25;
        (_player getVariable ["FADE_myMissionTaskId", ""] == "") || { time >= _deadline } || { [] call FAC_playthroughSuite__budgetExceeded }
    };
    _player getVariable ["FADE_myMissionTaskId", ""] == ""
};

// Longest mission-type names first (taskId = FADE_<Type><ms>).
FAC_playthroughSuite__missionTypesByLength = [
    "AreaOfOperations", "AssetRetrieval", "SearchDestroy", "InterceptConvoy", "EscapeEvasion",
    "TroopInsert", "TroopExtract", "MineClearing", "Operation", "Invasion", "ClearArea",
    "GeoGuesser", "CASEVAC", "Hostage", "Cargo", "CSAR", "Raid", "CAS", "HVT"
];

FAC_playthroughSuite__missionTypeFromTaskId = {
    params ["_taskId"];
    if (_taskId isNotEqualTo "" && { _taskId find "FADE_" == 0 }) then {
        private _rest = _taskId select [5];
        private _found = "";
        {
            if (_rest find _x == 0) exitWith { _found = _x };
        } forEach FAC_playthroughSuite__missionTypesByLength;
        _found
    } else {
        ""
    }
};

FAC_playthroughSuite__logTask = {
    params ["_taskId", "_missionType"];
    if (_taskId == "") exitWith {};
    private _log = missionNamespace getVariable ["FAC_playthroughSuite_taskLog", []];
    private _hit = _log findIf { (_x select 0) == _taskId };
    if (_hit < 0) then {
        _log pushBack [_taskId, _missionType];
        missionNamespace setVariable ["FAC_playthroughSuite_taskLog", _log];
    };
};

FAC_playthroughSuite__setAbortFlagsForTask = {
    params ["_taskId", "_mType"];
    if (_taskId == "") exitWith {};
    if (_mType == "") then { _mType = [_taskId] call FAC_playthroughSuite__missionTypeFromTaskId };
    if (_mType == "AreaOfOperations") then {
        missionNamespace setVariable ["FADE_aoAborted_" + _taskId, true];
        missionNamespace setVariable ["FADE_aoEnded_" + _taskId, true];
    };
    if (_mType == "Operation") then { missionNamespace setVariable ["FADE_operationAborted_" + _taskId, true] };
    if (_mType == "Raid") then { missionNamespace setVariable ["FADE_raidAborted_" + _taskId, true] };
    if (_mType == "Invasion") then { missionNamespace setVariable ["FADE_invasionAborted_" + _taskId, true] };
    if (_mType == "SearchDestroy") then { missionNamespace setVariable ["FADE_sdAborted_" + _taskId, true] };
    if (_mType == "AssetRetrieval") then { missionNamespace setVariable ["FADE_assetAborted_" + _taskId, true] };
    if (_mType == "EscapeEvasion") then { missionNamespace setVariable ["FADE_eeAborted_" + _taskId, true] };
    if (_mType == "GeoGuesser") then { missionNamespace setVariable ["FADE_ggAborted_" + _taskId, true] };
    if (_mType in ["TroopInsert", "TroopExtract"]) then {
        private _abortKey = if (_mType == "TroopInsert") then {
            "FADE_troopInsertAborted_" + _taskId
        } else {
            "FADE_troopExtractAborted_" + _taskId
        };
        missionNamespace setVariable [_abortKey, true, true];
    };
};

FAC_playthroughSuite__taskChildrenSafe = {
    params ["_taskId"];
    if (_taskId == "") exitWith { [] };
    private _raw = [_taskId] call BIS_fnc_taskChildren;
    if (_raw isEqualType []) exitWith { _raw };
    if (_raw isEqualType "") exitWith { if (_raw == "") then { [] } else { [_raw] } };
    []
};

FAC_playthroughSuite__purgeTaskId = {
    params ["_taskId", ["_mType", ""], ["_player", objNull]];
    if (_taskId == "") exitWith {};
    if (_mType == "") then { _mType = [_taskId] call FAC_playthroughSuite__missionTypeFromTaskId };

    missionNamespace setVariable [format ["FADE_missionEnt_cleaned_%1", _taskId], false];
    [_taskId, _mType] call FAC_playthroughSuite__setAbortFlagsForTask;

    if (_mType in ["Operation", "Raid", "Invasion", "AreaOfOperations"]) then { sleep 1.5 };

    private _st = _taskId call BIS_fnc_taskState;
    if (_st in ["ASSIGNED", "CREATED"]) then {
        [_taskId, "CANCELED"] call BIS_fnc_taskSetState;
    };
    {
        private _childSt = _x call BIS_fnc_taskState;
        if (_childSt in ["ASSIGNED", "CREATED"]) then { [_x, "CANCELED"] call BIS_fnc_taskSetState };
    } forEach ([_taskId] call FAC_playthroughSuite__taskChildrenSafe);

    if (_mType == "AreaOfOperations") then {
        private _bluM = "FADE_ao_bluSpawn_" + _taskId;
        if (markerShape _bluM != "") then { [_bluM] call FADE_deleteMarkerSafe };
    };

    if (!isNil "FADE_cleanupMissionEntities") then {
        [_taskId, _mType, true] call FADE_cleanupMissionEntities;
    };
    if (!isNil "FADE_cleanupMissionMarkers") then {
        [_taskId, _player] call FADE_cleanupMissionMarkers;
    };
    if (!isNil "FADE_mission_unpinCivZonesForTask") then {
        [_taskId] call FADE_mission_unpinCivZonesForTask;
    };
    if (!isNil "FADE_missionEnt_scheduledCleanup") then {
        [_taskId, 0, _player] spawn FADE_missionEnt_scheduledCleanup;
    };
};

FAC_playthroughSuite__collectOrphanTaskIds = {
    private _found = [];
    private _seen = [];
    {
        private _key = _x;
        {
            private _prefix = _x select 0;
            private _mType = _x select 1;
            if (_key find _prefix == 0) exitWith {
                private _tid = _key select [count _prefix];
                if (_tid != "" && { !(_tid in _seen) }) then {
                    _seen pushBack _tid;
                    _found pushBack [_tid, _mType];
                };
            };
        } forEach [
            ["FADE_operationEntities_", "Operation"],
            ["FADE_invasionEntities_", "Invasion"],
            ["FADE_aoEntities_", "AreaOfOperations"],
            ["FADE_searchDestroyEntities_", "SearchDestroy"],
            ["FADE_assetEntities_", "AssetRetrieval"],
            ["FADE_raidEntities_", "Raid"]
        ];
    } forEach allVariables missionNamespace;
    _found
};

FAC_playthroughSuite__purgeAllTracked = {
    params [["_player", objNull]];
    {
        _x params ["_tid", "_mt"];
        [_tid, _mt, _player] call FAC_playthroughSuite__purgeTaskId;
    } forEach (missionNamespace getVariable ["FAC_playthroughSuite_taskLog", []]);
    {
        _x params ["_tid", "_mt"];
        [_tid, _mt, _player] call FAC_playthroughSuite__purgeTaskId;
    } forEach ([] call FAC_playthroughSuite__collectOrphanTaskIds);
    missionNamespace setVariable ["FAC_playthroughSuite_taskLog", []];
    if (!isNil "FADE_dynamicRoadblocks_despawnAll") then { [] call FADE_dynamicRoadblocks_despawnAll };
};

// Force full mission cleanup between playthrough steps (slots, markers, entities, civ pins).
FAC_playthroughSuite__hardResetMission = {
    params ["_player", ["_forceTaskId", ""], ["_forceMType", ""]];
    if (isNull _player) exitWith {};

    private _tid = _forceTaskId;
    private _mType = _forceMType;
    if (_tid == "") then { _tid = _player getVariable ["FADE_myMissionTaskId", ""] };
    if (_mType == "") then { _mType = _player getVariable ["FADE_myMission", ""] };
    private _global = missionNamespace getVariable ["FADE_globalMission", []];
    if (_mType == "" && { count _global >= 1 } && { [_global, _player] call FADE_isMissionEntryOwnedByPlayer }) then {
        _mType = _global select 0;
    };

    if (_tid != "") then {
        [_tid, _mType, _player] call FAC_playthroughSuite__purgeTaskId;
    } else {
        if (_mType != "" && { !isNil "FADE_abortMission" }) then { [_player] call FADE_abortMission };
    };

    if (!isNil "FADE_clearActiveMission") then { [_player] call FADE_clearActiveMission };

    if (count _global >= 2 && { [_global, _player] call FADE_isMissionEntryOwnedByPlayer }) then {
        missionNamespace setVariable ["FADE_globalMission", []];
        missionNamespace setVariable ["FADE_currentMissionType", ""];
        missionNamespace setVariable ["FADE_currentMissionPlayer", objNull];
    };
    private _singleList = missionNamespace getVariable ["FADE_singleMissions", []];
    _singleList = _singleList select { !([_x, _player] call FADE_isMissionEntryOwnedByPlayer) };
    missionNamespace setVariable ["FADE_singleMissions", _singleList];
    if (!isNil "FADE_missionSlots_publish") then { [] call FADE_missionSlots_publish };

    sleep 0.5;
};

FAC_playthroughSuite__teardown = {
    params ["_player", ["_forceAbort", true], ["_taskId", ""], ["_mType", ""]];
    [_player, _taskId, _mType] call FAC_playthroughSuite__hardResetMission;
    [_player, FAC_playthroughSuite__cleanupTimeoutSec] call FAC_playthroughSuite__waitForCleanup
};

FAC_playthroughSuite__checkInit = {
    params ["_missionType", "_player", "_taskId", "_state"];
    private _pass = 0;
    private _fail = 0;
    private _notes = [];

    if (_taskId == "") exitWith {
        [0, 1, ["no taskId after init wait"]]
    };
    if !(_state in ["ASSIGNED", "CREATED"]) exitWith {
        [0, 1, [format ["task state %1 (expected ASSIGNED/CREATED)", _state]]]
    };
    _pass = _pass + 1;

    private _ent = [_taskId] call FAC_playthroughSuite__entSummary;
    _ent params ["_grps", "_refs", "_vehs", "_mkrs"];
    private _entTotal = _grps + _refs + _vehs + _mkrs;

    private _needsEntities = _missionType in [
        "TroopExtract", "CAS", "HVT", "Hostage", "ClearArea", "InterceptConvoy", "AreaOfOperations",
        "CASEVAC", "CSAR", "AssetRetrieval", "SearchDestroy", "Operation", "Raid", "Invasion", "EscapeEvasion"
    ];
    private _lightTypes = ["Cargo", "MineClearing", "TroopInsert", "GeoGuesser"];

    if (_needsEntities && { _entTotal == 0 }) then {
        private _alt = missionNamespace getVariable [format ["FADE_aoEntities_%1", _taskId], []];
        if (count _alt >= 1) then {
            _pass = _pass + 1;
            _notes pushBack format ["aoEntities fallback (%1)", count _alt];
        } else {
            _fail = _fail + 1;
            _notes pushBack "no mission entities registered";
        };
    } else {
        if (_entTotal > 0 || { _missionType in _lightTypes }) then {
            _pass = _pass + 1;
            if (_entTotal > 0) then { _notes pushBack format ["entities g=%1 r=%2 v=%3 m=%4", _grps, _refs, _vehs, _mkrs] };
        } else {
            _fail = _fail + 1;
            _notes pushBack "expected entities or markers";
        };
    };

    if (_missionType == "Operation") then {
        private _zones = missionNamespace getVariable [format ["FADE_operationZoneCenters_%1", _taskId], []];
        private _hqIdx = missionNamespace getVariable [format ["FADE_operationHqIdx_%1", _taskId], -1];
        if (count _zones >= 2 && { _hqIdx >= 0 }) then {
            _pass = _pass + 1;
            _notes pushBack format ["operation hub+spoke zones=%1 hqIdx=%2", count _zones, _hqIdx];
        } else {
            _fail = _fail + 1;
            _notes pushBack format ["operation zone setup incomplete (zones=%1 hqIdx=%2)", count _zones, _hqIdx];
        };
    };

    private _marker = _player getVariable ["FADE_myMissionMarker", ""];
    private _markerOptional = _missionType in [
        "GeoGuesser", "Operation", "Invasion", "Raid", "TroopInsert", "AreaOfOperations"
    ];
    if (_marker != "") then {
        _pass = _pass + 1;
    } else {
        if (_markerOptional) then {
            _notes pushBack "player mission marker optional (zone/task markers)";
        } else {
            _fail = _fail + 1;
            _notes pushBack "player mission marker missing";
        };
    };

    [_pass, _fail, _notes]
};

FAC_playthroughSuite__runQrfProbe = {
    params ["_missionType", "_player", "_taskId", "_savedTiming"];
    if (!FAC_playthroughSuite__enableQrfProbe) exitWith { [0, 0, ["skipped (fast mode)"]] };
    if !(_missionType in FAC_playthroughSuite__counterAttackTypes) exitWith { [0, 0, ["no truck QRF for type"]] };
    if (_taskId == "") exitWith { [0, 0, ["no taskId"]] };

    private _dest = [_player, _missionType] call FAC_playthroughSuite__getDestPos;
    if (count _dest < 2) exitWith { [0, 0, ["no dest pos for QRF probe"]] };

    private _before = [_taskId] call FAC_playthroughSuite__entSummary;
    private _vehBefore = _before select 2;

    [_savedTiming] call FAC_playthroughSuite__restoreCounterAttackTiming;
    [] call FAC_playthroughSuite__fastCounterAttackTiming;

    private _probePos = if (count _dest >= 3) then { +_dest } else { [(_dest select 0), (_dest select 1), 0] };
    [_player, _probePos] call FAC_playthroughSuite__teleportPlayer;

    private _deadline = time + ([FAC_playthroughSuite__qrfWaitSec, 2] call FAC_playthroughSuite__budgetCap);
    private _qrfSeen = false;
    waitUntil {
        sleep 0.5;
        private _after = [_taskId] call FAC_playthroughSuite__entSummary;
        if ((_after select 2) > _vehBefore) exitWith { _qrfSeen = true; true };
        if (((_after select 0) + (_after select 1)) > ((_before select 0) + (_before select 1))) exitWith { _qrfSeen = true; true };
        time >= _deadline || { [] call FAC_playthroughSuite__budgetExceeded }
    };

    [_savedTiming] call FAC_playthroughSuite__restoreCounterAttackTiming;
    [_player] call FAC_playthroughSuite__restorePlayerHome;

    if (_qrfSeen) then {
        [0, 0, ["QRF entities appeared (informational)"]]
    } else {
        [0, 0, ["no QRF in fast window (informational)"]]
    };
};

FAC_playthroughSuite__runOne = {
    params ["_missionType", "_player", "_savedTiming", ["_notifyPlayer", objNull], ["_missionsLeft", 1]];
    private _pass = 0;
    private _fail = 0;
    private _skip = 0;

    if ([] call FAC_playthroughSuite__budgetExceeded) exitWith {
        diag_log format ["[FAC Playthrough] SKIP: %1 (suite budget exceeded)", _missionType];
        [0, 0, 1]
    };

    diag_log format ["[FAC Playthrough] --- %1 ---", _missionType];
    [format ["[FAC Playthrough] Starting %1...", _missionType], _notifyPlayer] call FAC_playthroughSuite__chat;

    if (missionNamespace getVariable ["FAC_playthroughSuite_abortRequested", false]) exitWith {
        diag_log format ["[FAC Playthrough] SKIP: %1 (abort requested)", _missionType];
        [0, 0, 1]
    };

    [_player, true, "", ""] call FAC_playthroughSuite__teardown;
    [_player] call FAC_playthroughSuite__purgeAllTracked;
    sleep 0.25;

    private _baseInit = if (_missionType == "InterceptConvoy") then {
        FAC_playthroughSuite__convoyInitTimeoutSec
    } else {
        if (_missionType in FAC_playthroughSuite__longInitTypes) then {
            FAC_playthroughSuite__longInitTimeoutSec
        } else {
            FAC_playthroughSuite__initTimeoutSec
        }
    };
    private _perMission = (([] call FAC_playthroughSuite__budgetRemaining) / (_missionsLeft max 1)) - FAC_playthroughSuite__betweenMissionSec;
    private _timeout = [_baseInit, 3] call FAC_playthroughSuite__budgetCap;
    if (_perMission > 0) then { _timeout = _timeout min _perMission };

    [_missionType, _player] call FAC_playthroughSuite__startMission;
    private _waitRes = [_player, _missionType, _timeout] call FAC_playthroughSuite__waitForInit;
    _waitRes params ["_taskId", "_state", "_inTime"];

    if (!_inTime && { _taskId == "" }) then {
        [_player, true, "", _missionType] call FAC_playthroughSuite__teardown;
        {
            _x params ["_ot", "_om"];
            [_ot, _om, _player] call FAC_playthroughSuite__purgeTaskId;
        } forEach ([] call FAC_playthroughSuite__collectOrphanTaskIds);
        sleep 0.5;
        [_missionType, _player] call FAC_playthroughSuite__startMission;
        _waitRes = [_player, _missionType, _timeout] call FAC_playthroughSuite__waitForInit;
        _waitRes params ["_taskId", "_state", "_inTime"];
    };

    if (!_inTime && { _taskId == "" }) exitWith {
        diag_log format ["[FAC Playthrough] FAIL: %1 init timeout (%2s, no task)", _missionType, _timeout];
        [_player, true, "", _missionType] call FAC_playthroughSuite__teardown;
        [_player] call FAC_playthroughSuite__purgeAllTracked;
        [_player] call FAC_playthroughSuite__restorePlayerHome;
        [0, 1, 0]
    };

    [_taskId, _missionType] call FAC_playthroughSuite__logTask;

    private _initRes = [_missionType, _player, _taskId, _state] call FAC_playthroughSuite__checkInit;
    _initRes params ["_ip", "_if", "_notes"];
    _pass = _pass + _ip;
    _fail = _fail + _if;
    { diag_log format ["[FAC Playthrough]   init note: %1", _x] } forEach _notes;

    if (_fail == 0) then {
        if (_missionType in ["CASEVAC", "CSAR"]) then {
            private _grp = [_taskId] call FAC_playthroughSuite__findFriendlyCasualtyGroup;
            if (!isNull _grp) then {
                { if (alive _x) then { _x setDamage 0; _x allowDamage false } } forEach units _grp;
            };
        };
        private _qrfRes = [_missionType, _player, _taskId, _savedTiming] call FAC_playthroughSuite__runQrfProbe;
        _qrfRes params ["_qp", "_qf", "_qNotes"];
        _pass = _pass + _qp;
        _fail = _fail + _qf;
        { diag_log format ["[FAC Playthrough]   qrf note: %1", _x] } forEach _qNotes;
    };

    if (_fail == 0 && { FAC_playthroughSuite__enablePhase2 }) then {
        private _compRes = [_missionType, _player, _taskId, _savedTiming, _missionsLeft] call FAC_playthroughSuite__runComplete;
        _compRes params ["_cp", "_cf", "_cNotes"];
        _pass = _pass + _cp;
        _fail = _fail + _cf;
        { diag_log format ["[FAC Playthrough]   complete note: %1", _x] } forEach _cNotes;
    };

    [_player, true, _taskId, _missionType] call FAC_playthroughSuite__teardown;
    [_player] call FAC_playthroughSuite__restorePlayerHome;
    sleep FAC_playthroughSuite__betweenMissionSec;

    if (_fail > 0) then {
        diag_log format ["[FAC Playthrough] FAIL: %1 (%2 pass / %3 fail checks)", _missionType, _pass, _fail];
    } else {
        diag_log format ["[FAC Playthrough] PASS: %1 (%2 checks)", _missionType, _pass];
    };

    [_pass, _fail, _skip]
};

FAC_playthroughSuite_runServer = {
    params [
        ["_notifyPlayer", objNull],
        ["_types", FAC_playthroughSuite__missionTypes]
    ];
    if (!isServer) exitWith { [0, 0, 0] };

    if (missionNamespace getVariable ["FAC_playthroughSuite_running", false]) exitWith {
        ["[FAC Playthrough] Already running.", _notifyPlayer] call FAC_playthroughSuite__chat;
        [0, 0, 0]
    };

    if (isNull _notifyPlayer) then {
        _notifyPlayer = objNull;
        { if (isPlayer _x) exitWith { _notifyPlayer = _x } } forEach allPlayers;
    };
    if (isNull _notifyPlayer || { !isPlayer _notifyPlayer }) exitWith {
        diag_log "[FAC Playthrough] FAIL: no player available for mission ownership";
        [0, 1, 0]
    };

    missionNamespace setVariable ["FAC_playthroughSuite_running", true];
    missionNamespace setVariable ["FAC_playthroughSuite_abortRequested", false];
    missionNamespace setVariable ["FAC_playthroughSuite_startTime", time];
    missionNamespace setVariable ["FAC_playthroughSuite_playerHome", getPosATL _notifyPlayer];
    missionNamespace setVariable ["FAC_playthroughSuite_taskLog", []];

    if (isNil "FAC_playthroughSuite__runComplete") then {
        call compile preprocessFileLineNumbers "rsc\MissionPlaythroughProfiles.sqf";
    };
    if (isNil "FAC_playthroughSuite__runComplete") exitWith {
        diag_log "[FAC Playthrough] FAIL: MissionPlaythroughProfiles.sqf failed to compile (check RPT)";
        missionNamespace setVariable ["FAC_playthroughSuite_running", false];
        ["[FAC Playthrough] Profiles script failed to load — check RPT.", _notifyPlayer] call FAC_playthroughSuite__chat;
        [0, 1, 0]
    };

    private _pass = 0;
    private _fail = 0;
    private _skip = 0;
    private _savedTiming = [] call FAC_playthroughSuite__saveCounterAttackTiming;
    [] call FAC_playthroughSuite__fastCounterAttackTiming;

    diag_log "[FAC Playthrough] ========== PLAYTHROUGH SUITE START ==========";
    [format [
        "[FAC Playthrough] %1 types, <=%2s budget, player %3 (no input required). RPT: [FAC Playthrough]",
        count _types,
        FAC_playthroughSuite__suiteBudgetSec,
        name _notifyPlayer
    ], _notifyPlayer] call FAC_playthroughSuite__chat;

    private _total = count _types;
    {
        if ([] call FAC_playthroughSuite__budgetExceeded) exitWith {
            _skip = _skip + (_total - _forEachIndex);
        };
        if (missionNamespace getVariable ["FAC_playthroughSuite_abortRequested", false]) exitWith {
            _skip = _skip + (_total - _forEachIndex);
        };
        private _left = _total - _forEachIndex;
        private _one = [_x, _notifyPlayer, _savedTiming, _notifyPlayer, _left] call FAC_playthroughSuite__runOne;
        _one params ["_p", "_f", "_s"];
        _pass = _pass + _p;
        _fail = _fail + _f;
        _skip = _skip + _s;
    } forEach _types;

    [_savedTiming] call FAC_playthroughSuite__restoreCounterAttackTiming;
    [_notifyPlayer] call FAC_playthroughSuite__purgeAllTracked;
    [_notifyPlayer, true, "", ""] call FAC_playthroughSuite__teardown;
    [_notifyPlayer] call FAC_playthroughSuite__restorePlayerHome;

    missionNamespace setVariable ["FAC_playthroughSuite_running", false];

    private _elapsed = time - (missionNamespace getVariable ["FAC_playthroughSuite_startTime", time]);
    diag_log format [
        "[FAC Playthrough] ========== PLAYTHROUGH SUITE END: %1 pass, %2 fail, %3 skipped (%.0fs) ==========",
        _pass, _fail, _skip, _elapsed
    ];
    [format [
        "[FAC Playthrough] Done in %4s — %1 pass / %2 fail / %3 skipped. Filter RPT: [FAC Playthrough]",
        _pass, _fail, _skip, round _elapsed
    ], _notifyPlayer] call FAC_playthroughSuite__chat;

    [_pass, _fail, _skip]
};

FAC_playthroughSuite__setAbortRequested = {
    missionNamespace setVariable ["FAC_playthroughSuite_abortRequested", true];
    ["[FAC Playthrough] Abort requested — stops after current mission.", objNull] call FAC_playthroughSuite__chat;
};
