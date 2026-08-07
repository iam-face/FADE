// =============================================================================
// ServerGameplayMedTrain.sqf � extracted from ServerGameplay (compile via ServerGameplay.sqf)
// =============================================================================

// -----------------------------------------------------------------------------
// Medical training terminal  -  KAT dummies (server)
// -----------------------------------------------------------------------------
FADE_medTrain_sanitizeList = {
    if (!isServer) exitWith {};
    private _lst = missionNamespace getVariable ["FADE_medTrainingDummies", []];
    _lst = _lst select { !isNull _x && { alive _x } };
    missionNamespace setVariable ["FADE_medTrainingDummies", _lst];
};

FADE_medTrain_resolveManagedUnit = {
    params ["_netIdStr"];
    if (!(_netIdStr isEqualType "") || { _netIdStr == "" }) exitWith { objNull };
    private _u = _netIdStr call BIS_fnc_objectFromNetId;
    if (isNull _u) then {
        { if (netId _x == _netIdStr) exitWith { _u = _x } } forEach allUnits;
    };
    if (isNull _u || {!alive _u}) exitWith { objNull };
    if (!(_u getVariable ["FADE_medTrainingDummy", false])) exitWith { objNull };
    if (!(_u in (missionNamespace getVariable ["FADE_medTrainingDummies", []]))) exitWith { objNull };
    _u
};

FADE_medTrain_getAnchor = {
    private _med = missionNamespace getVariable ["MEDICAL_1", objNull];
    private _term = missionNamespace getVariable ["FADE_medicalTrainingTerminal", objNull];
    if (!isNull _med) exitWith { _med };
    _term
};

FADE_medTrain_publishList = {
    if (!isServer) exitWith {};
    [] call FADE_medTrain_sanitizeList;
    private _lst = missionNamespace getVariable ["FADE_medTrainingDummies", []];
    private _out = [];
    { _out pushBack [netId _x, alive _x, _forEachIndex] } forEach _lst;
    missionNamespace setVariable ["FAC_medTrain_clientList", _out, true];
};

FADE_medTrain_requestList = {
    params [["_player", objNull]];
    if (!isServer) exitWith {};
    [] call FADE_medTrain_publishList;
};

FADE_medTrain_spawn = {
    params [["_player", objNull]];
    if (!isServer) exitWith {};
    private _useACE = isClass (configFile >> "CfgPatches" >> "ace_medical");
    private _useKAT = isClass (configFile >> "CfgPatches" >> "kat_main");
    if (!_useACE || { !_useKAT }) exitWith {
        if (!isNull _player) then { ["Medical terminal: ACE Medical and KAT (KAM) required."] remoteExec ["systemChat", _player] };
    };
    [] call FADE_medTrain_sanitizeList;
    private _lst = + (missionNamespace getVariable ["FADE_medTrainingDummies", []]);
    private _max = missionNamespace getVariable ["FADE_medTrain_maxDummies", 8];
    if ((count _lst) >= _max) exitWith {
        if (!isNull _player) then { ["Medical terminal: maximum dummies reached."] remoteExec ["systemChat", _player] };
    };
    private _anchor = [] call FADE_medTrain_getAnchor;
    if (isNull _anchor) exitWith {
        if (!isNull _player) then { ["Medical terminal: place MEDICAL_1 or terminalMedical."] remoteExec ["systemChat", _player] };
    };
    private _sideFriendly = missionNamespace getVariable ["FADE_sideFriendly", west];
    private _friendlyUnits = missionNamespace getVariable ["FADE_friendlyUnits", []];
    if ((count _friendlyUnits) < 1) exitWith {
        if (!isNull _player) then { ["Medical terminal: no friendly unit classes (scenario)."] remoteExec ["systemChat", _player] };
    };
    private _baseAtl = getPosATL _anchor;
    private _i = count _lst;
    private _dist = ((0.45 + (_i * 0.55) + random 0.35) min 2.95) max 0.35;
    private _yaw = (_i * 119) + random 61;
    private _flat = _anchor getPos [_dist, _yaw];
    private _grp = createGroup _sideFriendly;
    private _u = _grp createUnit [(_friendlyUnits select 0), _flat, [], 0, "NONE"];
    _u setPos [_flat select 0, _flat select 1];
    _u setPosATL [getPosATL _u select 0, getPosATL _u select 1, _baseAtl select 2];
    _u setDamage 0;
    [_u] call FAC_medKAT_fnc_configureTrainingDummy;
    _u setBehaviour "CARELESS";
    _u setCaptive true;
    _u setVariable ["FADE_medTrainingDummy", true, true];
    _u addEventHandler ["Killed", {
        params ["_unit"];
        [_unit] spawn {
            params ["_unit"];
            sleep 5;
            if (isNull _unit) exitWith {};
            if (!(_unit getVariable ["FADE_medTrainingDummy", false])) exitWith {};
            private _lst = missionNamespace getVariable ["FADE_medTrainingDummies", []];
            private _ni = _lst find _unit;
            if (_ni >= 0) then {
                _lst deleteAt _ni;
                missionNamespace setVariable ["FADE_medTrainingDummies", _lst];
            };
            private _grp = group _unit;
            deleteVehicle _unit;
            if (!isNull _grp && { count units _grp == 0 }) then { deleteGroup _grp };
            [] call FADE_medTrain_publishList;
        };
    }];
    _lst pushBack _u;
    missionNamespace setVariable ["FADE_medTrainingDummies", _lst];
    [] call FADE_medTrain_publishList;
};

FADE_medTrain_delete = {
    params ["_netIdStr", ["_player", objNull]];
    if (!isServer) exitWith {};
    private _u = [_netIdStr] call FADE_medTrain_resolveManagedUnit;
    if (isNull _u) exitWith {
        if (!isNull _player) then { ["Medical terminal: invalid dummy."] remoteExec ["systemChat", _player] };
    };
    private _lst = missionNamespace getVariable ["FADE_medTrainingDummies", []];
    private _ni = _lst find _u;
    if (_ni >= 0) then { _lst deleteAt _ni };
    missionNamespace setVariable ["FADE_medTrainingDummies", _lst];
    private _grp = group _u;
    deleteVehicle _u;
    if (!isNull _grp && { count units _grp == 0 }) then { deleteGroup _grp };
    [] call FADE_medTrain_publishList;
};

FADE_medTrain_applyPreset = {
    params ["_netIdStr", "_scenario", ["_player", objNull]];
    if (!isServer) exitWith {};
    private _u = [_netIdStr] call FADE_medTrain_resolveManagedUnit;
    if (isNull _u) exitWith {};
    [_u, _scenario] call FAC_medKAT_applyScenarioNow;
};

FADE_medTrain_applyWound = {
    params ["_netIdStr", "_part", "_woundType", "_bleed", "_depth", ["_player", objNull]];
    if (!isServer) exitWith {};
    private _u = [_netIdStr] call FADE_medTrain_resolveManagedUnit;
    if (isNull _u) exitWith {};
    [_u, _part, _woundType, _bleed, _depth] call FAC_medKAT_applyCustomWound;
};

// Zeus-parity airway / chest / PTX / blood gas / deep penetrating (MedicalTrainingKAT.sqf)
FADE_medTrain_applyAirwayChest = {
    params ["_netIdStr", "_ob", "_oc", "_hem", "_ten", "_ptx", "_spo2", "_det", "_dpen", ["_player", objNull]];
    if (!isServer) exitWith {};
    private _u = [_netIdStr] call FADE_medTrain_resolveManagedUnit;
    if (isNull _u) exitWith {};
    [
        _u,
        _ob > 0,
        _oc > 0,
        _hem > 0,
        _ten > 0,
        _ptx,
        _spo2,
        _det > 0,
        _dpen > 0
    ] call FAC_medKAT_applyAirwayChestZeus;
};

FADE_medTrain_applyCardiac = {
    params ["_netIdStr", "_rhythm", ["_player", objNull]];
    if (!isServer) exitWith {};
    private _u = [_netIdStr] call FADE_medTrain_resolveManagedUnit;
    if (isNull _u) exitWith {};
    [_u, _rhythm] call FAC_medKAT_applyCardiacRhythm;
};

FADE_medTrain_healAll = {
    params ["_netIdStr", ["_player", objNull]];
    if (!isServer) exitWith {};
    private _u = [_netIdStr] call FADE_medTrain_resolveManagedUnit;
    if (isNull _u) exitWith {};
    [_u] call FAC_medKAT_fullHealTrainingUnit;
};

FADE_medTrain_healPart = {
    params ["_netIdStr", "_part", ["_player", objNull]];
    if (!isServer) exitWith {};
    private _u = [_netIdStr] call FADE_medTrain_resolveManagedUnit;
    if (isNull _u) exitWith {};
    [_u, _part] call FAC_medKAT_healBodyPart;
};

FADE_medTrain_setUnconscious = {
    params ["_netIdStr", "_uncon", ["_player", objNull]];
    if (!isServer) exitWith {};
    private _u = [_netIdStr] call FADE_medTrain_resolveManagedUnit;
    if (isNull _u) exitWith {};
    [_u, _uncon] call FAC_medKAT_setUnconscious;
};

FADE_medTrain_deleteAll = {
    params [["_player", objNull]];
    if (!isServer) exitWith {};
    private _lst = + (missionNamespace getVariable ["FADE_medTrainingDummies", []]);
    {
        private _g = group _x;
        deleteVehicle _x;
        if (!isNull _g && { count units _g == 0 }) then { deleteGroup _g };
    } forEach _lst;
    missionNamespace setVariable ["FADE_medTrainingDummies", []];
    [] call FADE_medTrain_publishList;
};

publicVariable "FADE_spawnHeli";
publicVariable "FADE_duplicateVehicleAtBase";
publicVariable "FADE_despawnVehicle";
publicVariable "FADE_deleteWrecksNearVehicleTerminal";
publicVariable "FADE_serviceVehicle";
publicVariable "FADE_serviceVehiclePart";
publicVariable "FADE_spawnLandVehicle";
publicVariable "FADE_requestVehiclesAtBase";
publicVariable "FADE_setTime";
publicVariable "FADE_setWeather";
publicVariable "FADE_requestCopilotState";
publicVariable "FADE_spawnCopilot";
publicVariable "FADE_removeCopilot";
publicVariable "FADE_startMission";
publicVariable "FADE_startEscapeEvasion";
publicVariable "FADE_startGeoGuesser";
publicVariable "FADE_startPointDefense";
publicVariable "FADE_geoGuesser_submitGuess";
publicVariable "FADE_abortMission";
publicVariable "FADE_getCargoSeats";
publicVariable "FADE_ensureEnemyVehicleGunner";
publicVariable "FADE_fires_spawnPiece";
publicVariable "FADE_fires_despawnSlot";
publicVariable "FADE_fires_rearmSlot";
publicVariable "FADE_fires_requestState";
publicVariable "FADE_fires_setAmmoAmount";
publicVariable "FADE_fires_spawnAmmoTruck";
publicVariable "FADE_fires_drillStart";
publicVariable "FADE_fires_drillCancel";
publicVariable "FADE_fires_drillRequestSummary";
publicVariable "FADE_firesFoS_droneSpawnRequest";
publicVariable "FADE_firesFoS_droneDespawnRequest";
publicVariable "FADE_firesFoS_requestSync";
publicVariable "FADE_firesFoS_toggleImpactScreenSlot";
publicVariable "FADE_medTrain_requestList";
publicVariable "FADE_medTrain_spawn";
publicVariable "FADE_medTrain_delete";
publicVariable "FADE_medTrain_applyPreset";
publicVariable "FADE_medTrain_applyWound";
publicVariable "FADE_medTrain_applyAirwayChest";
publicVariable "FADE_medTrain_applyCardiac";
publicVariable "FADE_medTrain_healAll";
publicVariable "FADE_medTrain_healPart";
publicVariable "FADE_medTrain_setUnconscious";
publicVariable "FADE_medTrain_deleteAll";
publicVariable "FADE_cutscene_testCam_start";
publicVariable "FADE_cutscene_testCam_stop";
publicVariable "FADE_cutscene_testCam_serverFinished";

// Helper: clear active mission for a player (removes from Global or Single list).
// Optional _taskIdGuard prevents stale mission threads from clearing a newer mission.
FADE_clearActiveMission = {
    params ["_player", ["_taskIdGuard", ""]];
    if (isNull _player) exitWith {};
    if (_taskIdGuard != "" && { (_player getVariable ["FADE_myMissionTaskId", ""]) != _taskIdGuard }) exitWith {};
    private _playerUid = getPlayerUID _player;
    if (!isNull _player) then {
        _player setVariable ["FADE_myMission", "", true];
        _player setVariable ["FADE_myMissionTaskId", nil, true];
        _player setVariable ["FADE_myMissionMarker", nil, true];
        _player setVariable ["FADE_myMissionMarkerEnd", nil, true];
        _player setVariable ["FADE_myMissionBrief", nil, true];
    };
    private _global = missionNamespace getVariable ["FADE_globalMission", []];
    if (count _global >= 2 && { [_global, _player] call FADE_isMissionEntryOwnedByPlayer }) then {
        missionNamespace setVariable ["FADE_globalMission", []];
        missionNamespace setVariable ["FADE_currentMissionType", ""];
        missionNamespace setVariable ["FADE_currentMissionPlayer", objNull];
        [] call FADE_missionSlots_publish;
    } else {
        private _singleList = missionNamespace getVariable ["FADE_singleMissions", []];
        _singleList = _singleList select {
            private _ownerObj = _x param [1, objNull];
            private _ownerUid = _x param [3, ""];
            !((_ownerObj == _player) || { _ownerUid != "" && { _ownerUid == _playerUid } })
        };
        missionNamespace setVariable ["FADE_singleMissions", _singleList];
    [] call FADE_missionSlots_publish;
    };
};

// AO: true while mission may spawn reinforcements / counter-attacks.
FADE_aoMissionActive = {
    params ["_taskId", "_startTime", "_timeout"];
    if (missionNamespace getVariable ["FADE_aoEnded_" + _taskId, false]) exitWith { false };
    if (missionNamespace getVariable ["FADE_aoAborted_" + _taskId, false]) exitWith { false };
    if (time - _startTime >= _timeout) exitWith { false };
    private _st = _taskId call BIS_fnc_taskState;
    if (_st in ["SUCCEEDED", "FAILED", "CANCELED"]) exitWith { false };
    true
};
missionNamespace setVariable ["FADE_aoMissionActive", FADE_aoMissionActive];

// AO: register spawned group for cleanup (missionEnt + live FADE_aoEntities_ list).
FADE_aoRegisterGroup = {
    params ["_taskId", "_grp"];
    if (_taskId == "" || { isNull _grp }) exitWith {};
    [_taskId, _grp] call FADE_missionEnt_registerGroup;
    private _ent = missionNamespace getVariable ["FADE_aoEntities_" + _taskId, [[], []]];
    if (!(_ent isEqualType []) || { count _ent < 2 }) then { _ent = [[], []] };
    private _grps = +(_ent select 0);
    if (!(_grp in _grps)) then {
        _grps pushBack _grp;
        _ent set [0, _grps];
        missionNamespace setVariable ["FADE_aoEntities_" + _taskId, _ent];
    };
};
missionNamespace setVariable ["FADE_aoRegisterGroup", FADE_aoRegisterGroup];

// AO: register vehicle + composition entry for cleanup.
FADE_aoRegisterVehicle = {
    params ["_taskId", "_veh"];
    if (_taskId == "" || { isNull _veh }) exitWith {};
    [_taskId, _veh] call FADE_missionEnt_registerVehicle;
    private _ent = missionNamespace getVariable ["FADE_aoEntities_" + _taskId, [[], []]];
    if (!(_ent isEqualType []) || { count _ent < 2 }) then { _ent = [[], []] };
    private _objs = +(_ent select 1);
    if (!(_veh in _objs)) then {
        _objs pushBack _veh;
        _ent set [1, _objs];
        missionNamespace setVariable ["FADE_aoEntities_" + _taskId, _ent];
    };
};
missionNamespace setVariable ["FADE_aoRegisterVehicle", FADE_aoRegisterVehicle];

// AO: register composition object (turrets, props) for cleanup.
FADE_aoRegisterObject = {
    params ["_taskId", "_obj"];
    if (_taskId == "" || { isNull _obj }) exitWith {};
    [_taskId, _obj] call FADE_missionEnt_registerObject;
    private _ent = missionNamespace getVariable ["FADE_aoEntities_" + _taskId, [[], []]];
    if (!(_ent isEqualType []) || { count _ent < 2 }) then { _ent = [[], []] };
    private _objs = +(_ent select 1);
    if (!(_obj in _objs)) then {
        _objs pushBack _obj;
        _ent set [1, _objs];
        missionNamespace setVariable ["FADE_aoEntities_" + _taskId, _ent];
    };
};
missionNamespace setVariable ["FADE_aoRegisterObject", FADE_aoRegisterObject];

// Despawn all entities registered for a mission task (abort + mission-end). Idempotent.
FADE_cleanupMissionEntities = {
    params ["_taskId", ["_missionType", ""], ["_setAbortFlags", true]];
    if (_taskId == "") exitWith {};
    // Civ-zone unpin is deferred to FADE_missionEnt_scheduledCleanup so ambient roadblocks/patrols
    // do not respawn OPFOR at the objective while players are still on site after abort.
    if (missionNamespace getVariable [format ["FADE_missionEnt_cleaned_%1", _taskId], false]) exitWith {};

    if (_missionType == "AreaOfOperations") then {
        missionNamespace setVariable ["FADE_aoEnded_" + _taskId, true];
    };

    if (_setAbortFlags) then {
        if (_missionType == "AreaOfOperations") then { missionNamespace setVariable ["FADE_aoAborted_" + _taskId, true] };
        if (_missionType == "Operation") then { missionNamespace setVariable ["FADE_operationAborted_" + _taskId, true] };
        if (_missionType == "SearchDestroy") then { missionNamespace setVariable ["FADE_sdAborted_" + _taskId, true] };
        if (_missionType == "EscapeEvasion") then { missionNamespace setVariable ["FADE_eeAborted_" + _taskId, true] };
        if (_missionType == "GeoGuesser") then { missionNamespace setVariable ["FADE_ggAborted_" + _taskId, true] };
        if (_missionType == "AssetRetrieval") then { missionNamespace setVariable ["FADE_assetAborted_" + _taskId, true] };
        if (_missionType == "Raid") then { missionNamespace setVariable ["FADE_raidAborted_" + _taskId, true] };
        if (_missionType == "Invasion") then { missionNamespace setVariable ["FADE_invasionAborted_" + _taskId, true] };
        if (_missionType == "PointDefense") then { missionNamespace setVariable ["FADE_pdAborted_" + _taskId, true] };
        if (_missionType in ["TroopInsert", "TroopExtract"]) then {
            private _abortKey = if (_missionType == "TroopInsert") then {
                "FADE_troopInsertAborted_" + _taskId
            } else {
                "FADE_troopExtractAborted_" + _taskId
            };
            missionNamespace setVariable [_abortKey, true, true];
        };
    };

    private _vgX = missionNamespace getVariable ["FADE_vg_cancelPendingByOwner", {}];
    if (!(_vgX isEqualTo {})) then {
        [format ["mis:%1", _taskId]] call _vgX;
        [format ["op:%1", _taskId]] call _vgX;
    };

    missionNamespace setVariable [format ["FADE_missionEnt_cleaned_%1", _taskId], true];

    private _ent = missionNamespace getVariable [format ["FADE_missionEnt_%1", _taskId], createHashMap];
    private _seenGrps = [];
    {
        if (_x isEqualType []) then {
            { if (_x isEqualType grpNull && { !isNull _x } && { !(_x in _seenGrps) }) then { _seenGrps pushBack _x } } forEach _x;
        };
    } forEach (_ent getOrDefault ["groupRefs", []]);
    {
        if (_x isEqualType grpNull && { !isNull _x } && { !(_x in _seenGrps) }) then { _seenGrps pushBack _x };
    } forEach (_ent getOrDefault ["groups", []]);
    { [_x] call FADE_missionEnt_deleteGroupFull } forEach _seenGrps;
    { if (!isNull _x) then { [_x] call FADE_missionEnt_deleteVehicleFull } } forEach (_ent getOrDefault ["vehicles", []]);
    { if (!isNull _x) then { deleteVehicle _x } } forEach (_ent getOrDefault ["objects", []]);

    private _aoEnt = missionNamespace getVariable ["FADE_aoEntities_" + _taskId, []];
    if (_aoEnt isEqualType [] && { count _aoEnt >= 2 }) then {
        [_taskId] call FADE_aoCleanupEntities;
        missionNamespace setVariable ["FADE_aoEntities_" + _taskId, nil];
    };
    private _opEnt = missionNamespace getVariable ["FADE_operationEntities_" + _taskId, []];
    if (_opEnt isEqualType [] && { count _opEnt >= 2 }) then {
        private _opOwner = format ["op:%1", _taskId];
        private _vgEll = missionNamespace getVariable ["FADE_vg_cancelPendingInEllipse", {}];
        private _zones = if (count _opEnt >= 3) then { _opEnt select 2 } else { [] };
        private _zr = if (count _opEnt >= 4 && { (_opEnt select 3) isEqualType 0 }) then { _opEnt select 3 } else { 250 };
        if (!(_vgEll isEqualTo {})) then {
            { [_x, _zr, _opOwner] call _vgEll } forEach _zones;
        };
        if ((_opEnt select 1) isEqualType []) then {
            { if (_x isEqualType "" && { _x != "" }) then { [_x] call FADE_deleteMarkerSafe } } forEach (_opEnt select 1);
        };
        {
            if (_x isEqualType grpNull && { !isNull _x }) then { [_x] call FADE_missionEnt_deleteGroupFull };
        } forEach (_opEnt select 0);
        if (count _opEnt >= 6) then {
            {
                if (!isNull _x) then {
                    private _cg = _x getVariable ["FADE_opCargoGrp", grpNull];
                    if (!isNull _cg) then { [_cg] call FADE_missionEnt_deleteGroupFull };
                    [_x] call FADE_missionEnt_deleteVehicleFull;
                };
            } forEach (_opEnt select 4);
            { if (!isNull _x) then { deleteVehicle _x } } forEach (_opEnt select 5);
        };
        {
            private _g = group _x;
            if (!isNull _g && { (_g getVariable ["FADE_vgOwner", ""]) == _opOwner }) then {
                if (alive _x) then { deleteVehicle _x };
            };
        } forEach allUnits;
        {
            if (!isNull _x && { _x getVariable ["FADE_opHomeIdx", -1] >= 0 }) then {
                private _cg = _x getVariable ["FADE_opCargoGrp", grpNull];
                if (!isNull _cg) then { [_cg] call FADE_missionEnt_deleteGroupFull };
                [_x] call FADE_missionEnt_deleteVehicleFull;
            };
        } forEach vehicles;
        missionNamespace setVariable ["FADE_operationEntities_" + _taskId, nil];
        missionNamespace setVariable ["FADE_operationCapState_" + _taskId, nil];
        missionNamespace setVariable ["FADE_operationZoneCenters_" + _taskId, nil];
        missionNamespace setVariable ["FADE_operationHqIdx_" + _taskId, nil];
        missionNamespace setVariable ["FADE_operationCivZoneIds_" + _taskId, nil];
        missionNamespace setVariable ["FADE_operationMakeVehFn_" + _taskId, nil];
        missionNamespace setVariable ["FADE_operationQrfLast_" + _taskId, nil];
    };
    private _invEnt = missionNamespace getVariable ["FADE_invasionEntities_" + _taskId, []];
    if (_invEnt isEqualType [] && { count _invEnt >= 1 }) then {
        if ((_invEnt select 0) isEqualType []) then {
            { if (_x isEqualType grpNull && { !isNull _x }) then { [_x] call FADE_missionEnt_deleteGroupFull } } forEach (_invEnt select 0);
        };
        if (count _invEnt >= 2 && { (_invEnt select 1) isEqualType [] }) then {
            { if (_x isEqualType "" && { _x != "" }) then { [_x] call FADE_deleteMarkerSafe } } forEach (_invEnt select 1);
        };
        missionNamespace setVariable ["FADE_invasionEntities_" + _taskId, nil];
        missionNamespace setVariable ["FADE_invasionZoneCenters_" + _taskId, nil];
        missionNamespace setVariable ["FADE_invasionCapState_" + _taskId, nil];
    };
    private _sdEnt = missionNamespace getVariable ["FADE_searchDestroyEntities_" + _taskId, []];
    if (_sdEnt isEqualType [] && { count _sdEnt >= 1 }) then {
        private _slot0 = _sdEnt select 0;
        if (_slot0 isEqualType []) then {
            { [_x] call FADE_missionEnt_deleteGroupFull } forEach _slot0;
            if (count _sdEnt >= 2) then {
                private _sdObjs = _sdEnt select 1;
                if (_sdObjs isEqualType []) then { { if (!isNull _x) then { deleteVehicle _x } } forEach _sdObjs };
            };
        } else {
            { [_x] call FADE_missionEnt_deleteGroupFull } forEach _sdEnt;
        };
        missionNamespace setVariable ["FADE_searchDestroyEntities_" + _taskId, nil];
    };
    private _eeEnt = missionNamespace getVariable ["FADE_eeEntities_" + _taskId, []];
    if (_eeEnt isEqualType [] && { count _eeEnt >= 1 }) then {
        { [_x] call FADE_missionEnt_deleteGroupFull } forEach (_eeEnt select 0);
        if (count _eeEnt >= 2) then {
            private _ex = _eeEnt select 1;
            if (_ex isEqualType []) then { { if (!isNull _x) then { deleteVehicle _x } } forEach _ex };
        };
    };
    private _qv = missionNamespace getVariable ["FADE_eeQrfVehs_" + _taskId, []];
    { if (!isNull _x) then { [_x] call FADE_missionEnt_deleteVehicleFull } } forEach _qv;
    private _eeH = missionNamespace getVariable ["FADE_eeSearchHeli_" + _taskId, []];
    if (_eeH isEqualType [] && { count _eeH >= 1 }) then {
        private _hv = _eeH param [0, objNull];
        private _hcg = _eeH param [2, grpNull];
        if (!isNull _hcg) then {
            { if (!isNull _x) then { deleteVehicle _x } } forEach units _hcg;
            deleteGroup _hcg;
        };
        if (!isNull _hv) then { [_hv] call FADE_missionEnt_deleteVehicleFull };
    };
    missionNamespace setVariable ["FADE_eeEntities_" + _taskId, nil];
    missionNamespace setVariable ["FADE_eeQrfVehs_" + _taskId, nil];
    missionNamespace setVariable ["FADE_eeSearchHeli_" + _taskId, nil];
    missionNamespace setVariable ["FADE_eeAborted_" + _taskId, nil];
    missionNamespace setVariable ["FADE_dynRb_escapeZone", nil];
    if (!(isNil "FADE_dynamicRoadblocks_despawnAll")) then { [] call FADE_dynamicRoadblocks_despawnAll };
    private _arEnt = missionNamespace getVariable ["FADE_assetEntities_" + _taskId, []];
    if (_arEnt isEqualType [] && { count _arEnt > 0 }) then {
        private _grps = [];
        if ((count _arEnt > 0) && { (_arEnt select 0) isEqualType grpNull }) then {
            _grps = _arEnt;
        } else {
            private _slot0 = _arEnt param [0, []];
            if (_slot0 isEqualType []) then { _grps = _slot0 };
        };
        { [_x] call FADE_missionEnt_deleteGroupFull } forEach _grps;
        missionNamespace setVariable ["FADE_assetEntities_" + _taskId, nil];
    };
    { if (!isNull _x) then { deleteVehicle _x } } forEach (missionNamespace getVariable ["FADE_assetObjects_" + _taskId, []]);
    missionNamespace setVariable ["FADE_assetObjects_" + _taskId, nil];
    private _w = missionNamespace getVariable ["FADE_csarWreck_" + _taskId, objNull];
    if (!isNull _w) then { deleteVehicle _w };
    missionNamespace setVariable ["FADE_csarWreck_" + _taskId, nil];
    [_taskId] call FADE_cleanupMissionMarkers;
    missionNamespace setVariable [format ["FADE_missionEnt_%1", _taskId], nil];
    if (_missionType == "AreaOfOperations") then {
        missionNamespace setVariable ["FADE_aoOpforSpawnPos_" + _taskId, nil];
        missionNamespace setVariable ["FADE_aoMarkers_" + _taskId, nil];
        missionNamespace setVariable ["FADE_aoAborted_" + _taskId, nil];
        missionNamespace setVariable ["FADE_aoEnded_" + _taskId, nil];
        missionNamespace setVariable ["FADE_aoVehicles_" + _taskId, nil];
        missionNamespace setVariable ["FADE_aoSpawnVehFn_" + _taskId, nil];
    };
};