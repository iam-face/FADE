// =============================================================================
// ServerGameplayMissionAdmin.sqf � extracted from ServerGameplay (compile via ServerGameplay.sqf)
// =============================================================================

// Mission-end despawn (default 60s delay). Markers removed immediately; entities after delay.
FADE_missionEnt_scheduledCleanup = {
    params ["_taskId", ["_delay", 60], ["_player", objNull]];
    if (_taskId == "") exitWith {};
    [_taskId, _delay, _player] spawn {
        params ["_tid", "_d", "_player"];
        [_tid, _player] call FADE_cleanupMissionMarkers;
        if (_d > 0) then { sleep _d };
        if !(missionNamespace getVariable [format ["FADE_missionEnt_cleaned_%1", _tid], false]) then {
            [_tid, "", false] call FADE_cleanupMissionEntities;
        };
    };
};

// Server: delete AO-spawned groups and composition for a task (safe if partial/empty; used by abort + AO script exit).
FADE_aoCleanupEntities = {
    params ["_taskId"];
    if (_taskId == "") exitWith {};
    private _aoEntities = missionNamespace getVariable ["FADE_aoEntities_" + _taskId, []];
    if (count _aoEntities >= 2) then {
        _aoEntities params ["_aoGroups", "_aoComposition"];
        if (_aoGroups isEqualType []) then {
            { if (_x isEqualType grpNull && { !isNull _x }) then { [_x] call FADE_missionEnt_deleteGroupFull } } forEach _aoGroups;
        };
        if (_aoComposition isEqualType []) then {
            {
                if (isNull _x) then { continue };
                if (_x isKindOf "LandVehicle" || { _x isKindOf "Air" }) then {
                    [_x] call FADE_missionEnt_deleteVehicleFull;
                } else {
                    deleteVehicle _x;
                };
            } forEach _aoComposition;
        };
    };
};

// Abort mission owned by _player (Global or Single)
FADE_abortMission = {
    params ["_player"];
    if (isNull _player) exitWith {};
    private _taskId = _player getVariable ["FADE_myMissionTaskId", ""];
    private _markerName = _player getVariable ["FADE_myMissionMarker", ""];
    private _markerNameEnd = _player getVariable ["FADE_myMissionMarkerEnd", ""];
    private _global = missionNamespace getVariable ["FADE_globalMission", []];
    private _isGlobalOwner = count _global >= 2 && { [_global, _player] call FADE_isMissionEntryOwnedByPlayer };
    private _missionType = if (_isGlobalOwner) then { _global select 0 } else { _player getVariable ["FADE_myMission", ""] };
    if (_taskId != "") then {
        if (_missionType in ["TroopInsert", "TroopExtract"]) then {
            private _abortKey = if (_missionType == "TroopInsert") then {
                "FADE_troopInsertAborted_" + _taskId
            } else {
                "FADE_troopExtractAborted_" + _taskId
            };
            missionNamespace setVariable [_abortKey, true, true];
            {
                if (!isNull _x && { isPlayer _x } && { (_x getVariable ["FADE_myMissionTaskId", ""]) == _taskId }) then {
                    ["MISSION ABORTED."] remoteExec ["systemChat", _x];
                };
            } forEach allPlayers;
        };
        [_taskId, "CANCELED"] call BIS_fnc_taskSetState;
        [_taskId, _missionType, true] call FADE_cleanupMissionEntities;
    } else {
        [_markerName] call FADE_deleteMarkerSafe;
        [_markerNameEnd] call FADE_deleteMarkerSafe;
    };
    if (_missionType in ["TroopInsert", "TroopExtract"] && { _taskId != "" }) then {
        {
            if (!isNull _x && { (_x getVariable ["FADE_myMissionTaskId", ""]) == _taskId }) then {
                _x setVariable ["FADE_myMission", "", true];
                _x setVariable ["FADE_myMissionTaskId", nil, true];
                _x setVariable ["FADE_myMissionMarker", nil, true];
                _x setVariable ["FADE_myMissionMarkerEnd", nil, true];
                _x setVariable ["FADE_myMissionBrief", nil, true];
            };
        } forEach allPlayers;
    };
    [_player] call FADE_clearActiveMission;
    if !(_missionType in ["TroopInsert", "TroopExtract"]) then {
        ["<t size='1.2' color='#B0B0B0'>MISSION ABORTED</t><br/><br/><t color='#E0E0E0'>Mission cancelled.</t>"] remoteExec ["FADE_showMissionHint", _player];
    };
};

// Asset Retrieval: secure intel from addAction (server).
FADE_assetIntelTakeServer = {
    params ["_taskId", "_intelObj", ["_player", objNull]];
    if (!isServer) exitWith {};
    missionNamespace setVariable ["FADE_assetIntelTaken_" + _taskId, true];
    private _logDiary = missionNamespace getVariable ["FADE_intelDiaryLog", true];
    if (
        _logDiary &&
        { !isNull _player } &&
        { isPlayer _player } &&
        { alive _player }
    ) then {
        private _grid = if (!isNull _intelObj) then { mapGridPosition _intelObj } else { "unknown" };
        private _whenStr = format ["Mission +%1 min", floor (time / 60) max 0];
        private _body = format [
            "Secured intel package from Asset Retrieval objective (approx. grid %1). Return to base per task to finish.",
            _grid
        ];
        ["Asset retrieval", _whenStr, _body, "Package secured"] remoteExec ["FADE_intel_clientAppendIntelDiary", _player];
    };
    if (!isNull _intelObj) then { deleteVehicle _intelObj };
};
publicVariable "FADE_assetIntelTakeServer";

// Abort by mission slot (G1, S1, S2, S3). If owner object no longer exists, clear slot directly.
FADE_abortMissionSlot = {
    params ["_slotKey", "_requester"];
    if (isNull _requester) exitWith {};
    private _slot = toUpper _slotKey;
    switch _slot do {
        case "G1": {
            private _global = missionNamespace getVariable ["FADE_globalMission", []];
            if (count _global < 2) exitWith { ["G1 has no active mission."] remoteExec ["systemChat", _requester] };
            private _owner = _global param [1, objNull];
            if (isNull _owner) then {
                missionNamespace setVariable ["FADE_globalMission", []];
                missionNamespace setVariable ["FADE_currentMissionType", ""];
                missionNamespace setVariable ["FADE_currentMissionPlayer", objNull];
                [] call FADE_missionSlots_publish;
                ["G1 slot was stale and is now cleared."] remoteExec ["systemChat", _requester];
            } else {
                [_owner] call FADE_abortMission;
                [format ["Aborted G1 mission started by %1.", name _owner]] remoteExec ["systemChat", _requester];
            };
        };
        case "S1";
        case "S2";
        case "S3": {
            private _idx = switch _slot do { case "S1": {0}; case "S2": {1}; default {2}; };
            private _single = missionNamespace getVariable ["FADE_singleMissions", []];
            private _entry = _single param [_idx, []];
            if (count _entry < 2) exitWith { [format ["%1 has no active mission.", _slot]] remoteExec ["systemChat", _requester] };
            private _owner = _entry param [1, objNull];
            if (isNull _owner) then {
                _single deleteAt _idx;
                missionNamespace setVariable ["FADE_singleMissions", _single];
    [] call FADE_missionSlots_publish;
                [format ["%1 slot was stale and is now cleared.", _slot]] remoteExec ["systemChat", _requester];
            } else {
                [_owner] call FADE_abortMission;
                [format ["Aborted %1 mission started by %2.", _slot, name _owner]] remoteExec ["systemChat", _requester];
            };
        };
        default {
            ["Unknown mission slot key."] remoteExec ["systemChat", _requester];
        };
    };
};
publicVariable "FADE_abortMissionSlot";

// Jukebox: stop-all (also Scenario Admin); must be defined before FADE_adminCleanupAction references it.
FAC_jukebox_stopAllMusic = {
    if (!isServer) exitWith {};
    params [["_requester", objNull]];
    private _sources = +(missionNamespace getVariable ["FAC_jukebox_activeSources", []]);
    private _sourceKeys = [];
    {
        private _k = _x param [0, ""];
        if (_k != "") then { _sourceKeys pushBackUnique _k };
        if (_k != "") then { ["", _k, _requester] call FAC_jukebox_serverPlay };
    } forEach _sources;
    if (!isNil "FADE_roadVehicles") then {
        {
            if (!isNull _x) then {
                _x setVariable ["FADE_civCarRadioSuppressed", true, false];
                _x setVariable ["FADE_civCarRadioStarted", true, false];
                _x setVariable ["FADE_civCarRadioPending", false, false];
            };
        } forEach FADE_roadVehicles;
    };
    missionNamespace setVariable ["FAC_jukebox_activeSources", []];
    [_sourceKeys] remoteExec ["FAC_jukebox_clientStopAll", 0];
    diag_log format ["[FAC Jukebox] stopAllMusic (%1 sources, requester=%2)", count _sources, if (isNull _requester) then {"?"} else {name _requester}];
    if (!isNull _requester) then {
        ["All jukebox music stopped (every source)."] remoteExec ["systemChat", _requester];
    };
};
publicVariable "FAC_jukebox_stopAllMusic";

// Admin cleanup actions from Scenario GUI.
FADE_adminCleanupAction = {
    params ["_action", "_requester"];
    if (_action == "stopAllMusic") exitWith {
        if ([_requester, "FAC_playerCanUseScenarioAdmin", "Scenario Admin access denied by lobby settings."] call FAC_lobbyParams_serverDenyUnless) exitWith {};
        [_requester] call FAC_jukebox_stopAllMusic
    };
    if (isNull _requester) exitWith {};
    if (_action in ["makeZeus", "removeMyZeus"]) then {
        if ([_requester, "FAC_playerCanUseScenarioAdmin", "Scenario Admin access denied by lobby settings."] call FAC_lobbyParams_serverDenyUnless) exitWith {};
        if ([_requester, "FAC_playerCanUseDebugTools", "Debug tools disabled by lobby settings (Zeus self-assign)."] call FAC_lobbyParams_serverDenyUnless) exitWith {};
    } else {
        if ([_requester, "FAC_playerCanUseScenarioAdmin", "Scenario Admin access denied by lobby settings."] call FAC_lobbyParams_serverDenyUnless) exitWith {};
    };
    switch (_action) do {
        case "abortAllMissions": {
            private _global = missionNamespace getVariable ["FADE_globalMission", []];
            if (count _global >= 2) then {
                private _gOwner = _global param [1, objNull];
                if (!isNull _gOwner) then { [_gOwner] call FADE_abortMission };
            };
            private _single = + (missionNamespace getVariable ["FADE_singleMissions", []]);
            {
                private _sOwner = _x param [1, objNull];
                if (!isNull _sOwner) then { [_sOwner] call FADE_abortMission };
            } forEach _single;
            missionNamespace setVariable ["FADE_globalMission", []];
            missionNamespace setVariable ["FADE_singleMissions", []];
            missionNamespace setVariable ["FADE_currentMissionType", ""];
            missionNamespace setVariable ["FADE_currentMissionPlayer", objNull];
            [] call FADE_missionSlots_publish;
            ["Admin cleanup complete: all mission slots aborted/cleared."] remoteExec ["systemChat", _requester];
        };
        case "despawnCivilians": {
            if (!isNil "FADE_civZoneState" && { FADE_civZoneState isEqualType createHashMap }) then {
                { [_x] call FADE_civ_despawnZone } forEach (keys FADE_civZoneState);
            };
            if (!isNil "FADE_roadVehicles") then {
                { if (!isNull _x) then { { deleteVehicle _x } forEach crew _x; deleteVehicle _x } } forEach FADE_roadVehicles;
                FADE_roadVehicles = [];
            };
            if (!isNil "FADE_civAmbientAircraft") then {
                { if (!isNull _x) then { { deleteVehicle _x } forEach crew _x; deleteVehicle _x } } forEach FADE_civAmbientAircraft;
                FADE_civAmbientAircraft = [];
            };
            ["Admin cleanup complete: civilians despawned."] remoteExec ["systemChat", _requester];
        };
        case "despawnOpfor": {
            {
                if (!isNull _x && { side _x == east }) then { deleteVehicle _x };
            } forEach allUnits;
            {
                if (!isNull _x && { side _x == east }) then {
                    { deleteVehicle _x } forEach crew _x;
                    deleteVehicle _x;
                };
            } forEach vehicles;
            ["Admin cleanup complete: OPFOR despawned."] remoteExec ["systemChat", _requester];
        };
        case "makeZeus": {
            private _oldScript = _requester getVariable ["FAC_scriptGrantedCurator", objNull];
            if (!isNull _oldScript) then {
                if (getAssignedCuratorLogic _requester == _oldScript) then { unassignCurator _oldScript };
                if (!isNull _oldScript) then { deleteVehicle _oldScript };
                _requester setVariable ["FAC_scriptGrantedCurator", nil, true];
            };
            private _existing = getAssignedCuratorLogic _requester;
            if (!isNull _existing) then { unassignCurator _existing };
            private _grp = createGroup [sideLogic, true];
            private _spawnPos = if (!isNull _requester) then { getPosATL _requester } else { [0, 0, 0] };
            private _curator = _grp createUnit ["ModuleCurator_F", _spawnPos, [], 0, "NONE"];
            if (isNull _curator) exitWith {
                ["Could not create Zeus module."] remoteExec ["systemChat", _requester];
            };
            _curator setVariable ["owner", getPlayerUID _requester, true];
            _requester assignCurator _curator;
            _requester setVariable ["FAC_scriptGrantedCurator", _curator, true];
            private _objs = [];
            _objs append vehicles;
            { if (!isNull _x && { alive _x }) then { _objs pushBackUnique _x } } forEach allUnits;
            _curator addCuratorEditableObjects [_objs, true];
            [format ["%1 is now Zeus.", name _requester]] remoteExec ["systemChat", 0];
        };
        case "removeMyZeus": {
            private _mine = _requester getVariable ["FAC_scriptGrantedCurator", objNull];
            private _assigned = getAssignedCuratorLogic _requester;
            if (isNull _mine || { isNull _assigned } || { _assigned != _mine }) exitWith {
                ["No script-granted Zeus to remove (or you are using a different Zeus module)."] remoteExec ["systemChat", _requester];
            };
            unassignCurator _mine;
            deleteVehicle _mine;
            _requester setVariable ["FAC_scriptGrantedCurator", nil, true];
            [format ["%1 is no longer Zeus (script module removed).", name _requester]] remoteExec ["systemChat", 0];
        };
        case "teleportAllToBase": {
            // Same anchor as Fast Travel HQ (rsc/TeleportGui.sqf FAC_teleportGui_destBaseKey)
            private _baseObj = missionNamespace getVariable ["teleportBase", objNull];
            if (isNull _baseObj) exitWith {
                ["Teleport-all failed: Eden object 'teleportBase' not found (place logic/object for HQ)."] remoteExec ["systemChat", _requester];
            };
            private _center = getPosATL _baseObj;
            private _face = getDir _baseObj;
            private _movedVehs = [];
            private _idx = 0;
            {
                if (isNull _x) then { continue };
                private _veh = vehicle _x;
                if (_veh in _movedVehs) then { continue };
                _movedVehs pushBack _veh;
                private _ring = 2 + (_idx mod 4) * 1.2;
                private _bear = _face + (_idx * 37);
                private _flat = _center getPos [_ring, _bear];
                // setPosATL Z is ATL (above terrain), not ASL  -  do not use getTerrainHeightASL here.
                private _atl = [_flat select 0, _flat select 1, 0.25];
                _veh setPosATL _atl;
                if (_veh isKindOf "Man") then {
                    _veh setDir ((getPosATL _veh) getDir _center);
                } else {
                    _veh setDir _face;
                };
                _idx = _idx + 1;
            } forEach allPlayers;
            [format ["Admin: all players teleported to HQ / teleportBase (by %1).", name _requester]] remoteExec ["systemChat", 0];
        };
        case "stopAllMusic": {
            [_requester] call FAC_jukebox_stopAllMusic;
        };
        default {
            ["Admin cleanup failed: unknown action."] remoteExec ["systemChat", _requester];
        };
    };
};
publicVariable "FADE_adminCleanupAction";

// Surrender Challenge: false = no player hotkey/GUI; server ignores remoteExec (rsc/SurrenderChallenge.sqf unchanged).
FAC_surrenderChallenge_playerEnabled = false;
publicVariable "FAC_surrenderChallenge_playerEnabled";
