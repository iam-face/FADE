// =============================================================================
// MissionTestSuite.sqf — dev smoke tests (RPT via diag_log). Not auto-run.
//
// Debug console (Esc, when enableDebugConsole allows it):
//   Client:  [] call FAC_missionTestSuite_execClient
//   Server:  [player] remoteExec ["FAC_missionTestSuite_execServer", 2]
//            (use [player] so you get systemChat feedback; [] broadcasts to all)
// Listen-server host: run client line, then [player] remoteExec for server suite.
//
// Search RPT: [FAC TestSuite]
// =============================================================================

FAC_missionTestSuite__serverChat = {
    params ["_msg", ["_to", objNull]];
    if (!isServer) exitWith {};
    if (!isNull _to && { isPlayer _to }) then {
        [_msg] remoteExec ["systemChat", _to];
    } else {
        [_msg] remoteExec ["systemChat", 0];
    };
};

FAC_missionTestSuite_runServer = {
    params [["_notifyPlayer", objNull]];
    if (!isServer) exitWith { [0, 0] };
    private _pass = 0;
    private _fail = 0;

    diag_log "[FAC TestSuite] ========== SERVER SUITE START ==========";
    ["[FAC TestSuite] Server: running checks (state, positions, Operation, RPCs)...", _notifyPlayer] call FAC_missionTestSuite__serverChat;

    private _ok = false;

    // ----- Core state -----
    _ok = !isNil "FADE_basePos" && { count FADE_basePos >= 2 };
    if (_ok) then { _pass = _pass + 1; diag_log format ["[FAC TestSuite] PASS (server): FADE_basePos %1", FADE_basePos select [0, 2]]; } else { _fail = _fail + 1; diag_log "[FAC TestSuite] FAIL (server): FADE_basePos"; };

    private _helis = missionNamespace getVariable ["FADE_heliClasses", []];
    _ok = _helis isEqualType [] && { count _helis > 0 };
    if (_ok) then { _pass = _pass + 1; diag_log format ["[FAC TestSuite] PASS (server): FADE_heliClasses (%1)", count _helis]; } else { _fail = _fail + 1; diag_log "[FAC TestSuite] FAIL (server): FADE_heliClasses"; };

    private _land = missionNamespace getVariable ["FADE_landVehicleClasses", []];
    _ok = _land isEqualType [] && { count _land > 0 };
    if (_ok) then { _pass = _pass + 1; diag_log format ["[FAC TestSuite] PASS (server): FADE_landVehicleClasses (%1)", count _land]; } else { _fail = _fail + 1; diag_log "[FAC TestSuite] FAIL (server): FADE_landVehicleClasses"; };

    private _fu = missionNamespace getVariable ["FADE_friendlyUnits", []];
    private _eu = missionNamespace getVariable ["FADE_enemyUnits", []];
    _ok = _fu isEqualType [] && { count _fu > 0 };
    if (_ok) then { _pass = _pass + 1; diag_log format ["[FAC TestSuite] PASS (server): FADE_friendlyUnits (%1)", count _fu]; } else { _fail = _fail + 1; diag_log "[FAC TestSuite] FAIL (server): FADE_friendlyUnits"; };
    _ok = _eu isEqualType [] && { count _eu > 0 };
    if (_ok) then { _pass = _pass + 1; diag_log format ["[FAC TestSuite] PASS (server): FADE_enemyUnits (%1)", count _eu]; } else { _fail = _fail + 1; diag_log "[FAC TestSuite] FAIL (server): FADE_enemyUnits"; };

    private _mapMin = missionNamespace getVariable ["FADE_mapMin", -1];
    private _mapMax = missionNamespace getVariable ["FADE_mapMax", -1];
    _ok = _mapMax > _mapMin && { _mapMin >= 0 };
    if (_ok) then { _pass = _pass + 1; diag_log format ["[FAC TestSuite] PASS (server): FADE_mapMin/Max %1..%2", _mapMin, _mapMax]; } else { _fail = _fail + 1; diag_log "[FAC TestSuite] FAIL (server): FADE_mapMin/Max"; };

    private _civT = missionNamespace getVariable ["FADE_civTriggerNames", []];
    _ok = _civT isEqualType [];
    if (_ok) then { _pass = _pass + 1; diag_log format ["[FAC TestSuite] PASS (server): FADE_civTriggerNames (%1 zones)", count _civT]; } else { _fail = _fail + 1; diag_log "[FAC TestSuite] FAIL (server): FADE_civTriggerNames"; };

    private _hp = missionNamespace getVariable ["FADE_helipads", []];
    _ok = _hp isEqualType [] && { count _hp > 0 };
    if (_ok) then { _pass = _pass + 1; diag_log format ["[FAC TestSuite] PASS (server): FADE_helipads (%1)", count _hp]; } else { _fail = _fail + 1; diag_log "[FAC TestSuite] FAIL (server): FADE_helipads"; };

    private _gmt = missionNamespace getVariable ["FADE_globalMissionTypes", []];
    private _smt = missionNamespace getVariable ["FADE_singleMissionTypes", []];
    _ok = _gmt isEqualType [] && { "Operation" in _gmt };
    if (_ok) then { _pass = _pass + 1; diag_log "[FAC TestSuite] PASS (server): FADE_globalMissionTypes contains Operation"; } else { _fail = _fail + 1; diag_log "[FAC TestSuite] FAIL (server): FADE_globalMissionTypes / Operation"; };
    _ok = _smt isEqualType [] && { count _smt > 0 };
    if (_ok) then { _pass = _pass + 1; diag_log format ["[FAC TestSuite] PASS (server): FADE_singleMissionTypes (%1)", count _smt]; } else { _fail = _fail + 1; diag_log "[FAC TestSuite] FAIL (server): FADE_singleMissionTypes"; };

    // ----- Position helpers -----
    private _mpos = [] call FADE_findMissionPos;
    _ok = count _mpos >= 2 && { !(_mpos isEqualTo []) };
    if (_ok) then { _pass = _pass + 1; diag_log format ["[FAC TestSuite] PASS (server): FADE_findMissionPos %1", _mpos select [0, 2]]; } else { _fail = _fail + 1; diag_log "[FAC TestSuite] FAIL (server): FADE_findMissionPos"; };

    private _bp = missionNamespace getVariable ["FADE_basePos", [0, 0, 0]];
    private _lz = [_bp] call FADE_findSafeLZ;
    _ok = _lz isEqualTo [] || { count _lz >= 2 };
    if (_ok) then { _pass = _pass + 1; diag_log format ["[FAC TestSuite] PASS (server): FADE_findSafeLZ(base) %1", if (_lz isEqualTo []) then {"[]"} else { str (_lz select [0, 2]) }]; } else { _fail = _fail + 1; diag_log "[FAC TestSuite] FAIL (server): FADE_findSafeLZ"; };

    private _urban = [700] call FADE_findMissionPosUrban;
    _ok = count _civT == 0 || { count _urban >= 2 };
    if (_ok) then { _pass = _pass + 1; diag_log format ["[FAC TestSuite] PASS (server): FADE_findMissionPosUrban(700) %1", if (count _urban >= 2) then { str (_urban select [0, 2]) } else {"[]"}]; } else { _fail = _fail + 1; diag_log "[FAC TestSuite] FAIL (server): FADE_findMissionPosUrban (no pos with civ zones)"; };

    private _urbanN = [700] call FADE_findMissionPosUrbanNearCenter;
    _ok = count _civT == 0 || { count _urbanN >= 2 };
    if (_ok) then { _pass = _pass + 1; diag_log format ["[FAC TestSuite] PASS (server): FADE_findMissionPosUrbanNearCenter %1", if (count _urbanN >= 2) then { str (_urbanN select [0, 2]) } else {"[]"}]; } else { _fail = _fail + 1; diag_log "[FAC TestSuite] FAIL (server): FADE_findMissionPosUrbanNearCenter"; };

    private _ied = [] call FADE_findMissionPosIED;
    _ok = count _civT == 0 || { count _ied >= 2 };
    if (_ok) then { _pass = _pass + 1; diag_log format ["[FAC TestSuite] PASS (server): FADE_findMissionPosIED %1", if (count _ied >= 2) then { str (_ied select [0, 2]) } else {"[]"}]; } else { _fail = _fail + 1; diag_log "[FAC TestSuite] FAIL (server): FADE_findMissionPosIED"; };

    // ----- Operation mode preconditions (mirrors rsc\OperationMission.sqf) -----
    private _basePos = missionNamespace getVariable ["FADE_basePos", [0, 0, 0]];
    private _civNames = missionNamespace getVariable ["FADE_civTriggerNames", []];
    private _minOp = 1000;
    private _zoneCandidates = [];
    {
        private _trig = missionNamespace getVariable [_x, objNull];
        if (!isNull _trig) then {
            private _p = getPosATL _trig;
            if (count _p >= 2 && { (_p distance _basePos) >= _minOp }) then {
                _zoneCandidates pushBack [(_p select 0), (_p select 1), (_p param [2, 0])];
            };
        };
    } forEach _civNames;

    if (count _civNames == 0) then {
        _fail = _fail + 1;
        diag_log "[FAC TestSuite] FAIL (server): Operation — no CIV_T_* (FADE_civTriggerNames empty)";
    } else {
        _pass = _pass + 1;
        diag_log format ["[FAC TestSuite] PASS (server): Operation — CIV zones listed (%1)", count _civNames];
    };

    if (count _civNames > 0 && { count _zoneCandidates == 0 }) then {
        _fail = _fail + 1;
        diag_log "[FAC TestSuite] FAIL (server): Operation — no civ zone >= 1000m from base (see OperationMission)";
    } else {
        if (count _zoneCandidates > 0) then {
            _pass = _pass + 1;
            private _wantOp = missionNamespace getVariable ["FADE_operationZoneCount", 6];
            _wantOp = (round _wantOp) max 2 min 10;
            private _effN = _wantOp min count _zoneCandidates;
            diag_log format ["[FAC TestSuite] PASS (server): Operation — zoneCandidates %1 (use %2 of want %3)", count _zoneCandidates, _effN, _wantOp];
            if (_effN < _wantOp) then {
                diag_log format ["[FAC TestSuite] NOTE (server): Operation — FADE_operationZoneCount trims (only %1 zones >= 1km from base)", count _zoneCandidates];
            };
        };
    };

    // ----- Names / stubs / scenario helpers -----
    private _opName = [] call FADE_generateOperationName;
    _ok = _opName isEqualType "" && { count _opName > 0 };
    if (_ok) then { _pass = _pass + 1; diag_log format ["[FAC TestSuite] PASS (server): FADE_generateOperationName %1", _opName]; } else { _fail = _fail + 1; diag_log "[FAC TestSuite] FAIL (server): FADE_generateOperationName"; };

    private _cpMain = missionNamespace getVariable ["bis_fnc_cp_main", nil];
    private _cpQ = missionNamespace getVariable ["bis_fnc_cp_getQueueDelay", nil];
    _ok = !isNil "_cpMain" && {!isNil "_cpQ"};
    if (_ok) then { _pass = _pass + 1; diag_log "[FAC TestSuite] PASS (server): bis_fnc_cp_* stubs"; } else { _fail = _fail + 1; diag_log "[FAC TestSuite] FAIL (server): bis_fnc_cp_* stubs"; };

    private _w = [1] call FADE_sideNumToSide;
    private _e = [0] call FADE_sideNumToSide;
    _ok = _w != _e;
    if (_ok) then { _pass = _pass + 1; diag_log format ["[FAC TestSuite] PASS (server): FADE_sideNumToSide %1 vs %2", _w, _e]; } else { _fail = _fail + 1; diag_log "[FAC TestSuite] FAIL (server): FADE_sideNumToSide"; };

    private _mc = [1] call FADE_markerColorForSideNum;
    _ok = _mc isEqualType "" && { count _mc > 0 };
    if (_ok) then { _pass = _pass + 1; diag_log format ["[FAC TestSuite] PASS (server): FADE_markerColorForSideNum %1", _mc]; } else { _fail = _fail + 1; diag_log "[FAC TestSuite] FAIL (server): FADE_markerColorForSideNum"; };

    private _ef = missionNamespace getVariable ["FADE_scenarioEnemyFaction", "OPF_F"];
    private _unitsE = [_ef, 0] call FADE_getUnitsForFaction;
    _ok = _unitsE isEqualType [] && { count _unitsE > 0 };
    if (_ok) then { _pass = _pass + 1; diag_log format ["[FAC TestSuite] PASS (server): FADE_getUnitsForFaction(enemy) (%1)", count _unitsE]; } else { _fail = _fail + 1; diag_log "[FAC TestSuite] FAIL (server): FADE_getUnitsForFaction(enemy)"; };

    private _ev = [_ef] call FADE_getEnemyVehiclesForFaction;
    _ok = _ev isEqualType [];
    if (_ok) then { _pass = _pass + 1; diag_log format ["[FAC TestSuite] PASS (server): FADE_getEnemyVehiclesForFaction (%1)", count _ev]; } else { _fail = _fail + 1; diag_log "[FAC TestSuite] FAIL (server): FADE_getEnemyVehiclesForFaction"; };

    private _fnReg = missionNamespace getVariable ["FADE_registerEnemyRetreat", nil];
    _ok = !isNil "_fnReg" && { _fnReg isEqualType {} };
    if (_ok) then { _pass = _pass + 1; diag_log "[FAC TestSuite] PASS (server): FADE_registerEnemyRetreat"; } else { _fail = _fail + 1; diag_log "[FAC TestSuite] FAIL (server): FADE_registerEnemyRetreat"; };

    private _fires = missionNamespace getVariable ["FAC_fires_artilleryDefinitions", []];
    _ok = _fires isEqualType [] && { count _fires > 0 };
    if (_ok) then { _pass = _pass + 1; diag_log format ["[FAC TestSuite] PASS (server): FAC_fires_artilleryDefinitions (%1)", count _fires]; } else { _fail = _fail + 1; diag_log "[FAC TestSuite] FAIL (server): FAC_fires_artilleryDefinitions"; };

    // ----- All server publicVariable RPCs (must be CODE on server) -----
    private _rpcAll = [
        "FADE_applyScenarioSettings",
        "FADE_sendScenarioConfigToClient",
        "FADE_getUnitsForFaction",
        "FADE_getEnemyVehiclesForFaction",
        "FADE_getCivVehiclesForFaction",
        "FADE_getFactionSideNum",
        "FADE_sideNumToSide",
        "FADE_markerColorForSideNum",
        "FADE_resolveScenarioFriendlyUnits",
        "FADE_resolveScenarioEnemyUnits",
        "FADE_normPos3",
        "FADE_findSafePosArray",
        "FADE_op_countBluforPlayersInRadius",
        "FADE_op_countEnemyMenInRadius",
        "FADE_ensureBisTaskSetParent",
        "FAC_applyEnemyScenarioToGroup",
        "FADE_scaleOpforCount",
        "FADE_aiSideChat",
        "FADE_aiSideChat_exec",
        "FADE_applyOpforLauncherPolicyToUnit",
        "FADE_spawnHeli",
        "FADE_duplicateVehicleAtBase",
        "FADE_despawnVehicle",
        "FADE_serviceVehicle",
        "FADE_serviceVehiclePart",
        "FADE_spawnLandVehicle",
        "FADE_requestVehiclesAtBase",
        "FADE_setTime",
        "FADE_setWeather",
        "FADE_requestCopilotState",
        "FADE_spawnCopilot",
        "FADE_removeCopilot",
        "FADE_startMission",
        "FADE_abortMission",
        "FADE_getCargoSeats",
        "FADE_fires_spawnPiece",
        "FADE_fires_despawnSlot",
        "FADE_fires_rearmSlot",
        "FADE_fires_requestState",
        "FADE_fires_setAmmoAmount",
        "FADE_fires_spawnAmmoTruck",
        "FADE_assetIntelTakeServer",
        "FADE_abortMissionSlot",
        "FAC_jukebox_stopAllMusic",
        "FAC_jukebox_serverPlay",
        "FADE_adminCleanupAction",
        "FAC_surrenderChallenge_start",
        "FAC_loadoutGui_serverRequestApplyToMember",
        "FADE_cqbStartDrill",
        "FADE_cqbEndDrill"
    ];
    {
        private _n = _x;
        private _fn = missionNamespace getVariable [_n, nil];
        if (!isNil "_fn" && {_fn isEqualType {}}) then {
            _pass = _pass + 1;
            diag_log format ["[FAC TestSuite] PASS (server): RPC %1", _n];
        } else {
            _fail = _fail + 1;
            diag_log format ["[FAC TestSuite] FAIL (server): RPC %1", _n];
        };
    } forEach _rpcAll;

    // ----- Compile mission scripts (syntax / preprocess only; does not start missions) -----
    ["[FAC TestSuite] Server: compiling mission .sqf (may take a few seconds)...", _notifyPlayer] call FAC_missionTestSuite__serverChat;
    diag_log "[FAC TestSuite] --- compile checks (script error here = FAIL in RPT) ---";
    private _compileFiles = [
        "rsc\Missions.sqf",
        "rsc\TroopTransport.sqf",
        "rsc\AOMission.sqf",
        "rsc\OperationMission.sqf",
        "rsc\AmbientCivilians.sqf",
        "rsc\EnemyAAA.sqf",
        "rsc\EnemyCheckpoints.sqf",
        "rsc\DummyUnits.sqf",
        "rsc\PadVehicleService.sqf",
        "rsc\SurrenderChallenge.sqf"
    ];
    {
        private _path = _x;
        private _code = compile preprocessFileLineNumbers _path;
        if (isNil "_code" || { typeName _code != "CODE" }) then {
            _fail = _fail + 1;
            diag_log format ["[FAC TestSuite] FAIL (server): compile %1 (not CODE)", _path];
        } else {
            _pass = _pass + 1;
            diag_log format ["[FAC TestSuite] PASS (server): compile %1", _path];
        };
    } forEach _compileFiles;

    diag_log format ["[FAC TestSuite] ========== SERVER SUITE END: %1 passed, %2 failed ==========", _pass, _fail];
    [_pass, _fail]
};

FAC_missionTestSuite_runClient = {
    if (!hasInterface) exitWith { [0, 0] };
    private _pass = 0;
    private _fail = 0;

    diag_log "[FAC TestSuite] ========== CLIENT SUITE START ==========";
    systemChat "[FAC TestSuite] Client: starting (functions + data)...";

    private _fncNames = [
        "FADE_showMissionHint",
        "FADE_syncScenarioConfig",
        "FADE_aiSideChat_exec",
        "FAC_playerCanUseMissionsGui",
        "FAC_playerCanUseScenarioGui",
        "FAC_playerCanTeleportToPlayers",
        "FAC_guiScheduleHeaderRefresh",
        "FAC_vehicleGui_fnc",
        "FAC_missionsGui_fnc",
        "FAC_scenarioGui_fnc",
        "FAC_loadoutGui_fnc",
        "FAC_jukeboxGui_fnc",
        "FAC_jukebox_clientPlay",
        "FAC_jukebox_clientStopAll",
        "FAC_jukebox_fnc_addVehicleLoudspeakerAction",
        "FAC_jukebox_fnc_installVehicleLoudspeakerHandlers",
        "FAC_cqbGui_fnc",
        "FAC_firesGui_fnc",
        "FAC_teleportGui_fnc",
        "FAC_cqbLoudspeaker_clientPlay",
        "FAC_surrenderChallenge_fnc_activate",
        "FADE_cqbClient_forceTargetDown"
    ];
    private _ok = false;
    {
        private _n = _x;
        private _fn = missionNamespace getVariable [_n, nil];
        _ok = !isNil "_fn" && {_fn isEqualType {}};
        if (_ok) then {
            _pass = _pass + 1;
            diag_log format ["[FAC TestSuite] PASS (client): %1", _n];
        } else {
            _fail = _fail + 1;
            diag_log format ["[FAC TestSuite] FAIL (client): %1", _n];
        };
    } forEach _fncNames;

    systemChat "[FAC TestSuite] Client: checking Rsc dialogs (description.ext)...";

    private _helis = missionNamespace getVariable ["FADE_heliClasses", []];
    _ok = _helis isEqualType [] && { count _helis > 0 };
    if (_ok) then { _pass = _pass + 1; diag_log format ["[FAC TestSuite] PASS (client): FADE_heliClasses (%1)", count _helis]; } else { _fail = _fail + 1; diag_log "[FAC TestSuite] FAIL (client): FADE_heliClasses"; };

    private _fires = missionNamespace getVariable ["FAC_fires_artilleryDefinitions", []];
    _ok = _fires isEqualType [] && { count _fires > 0 };
    if (_ok) then { _pass = _pass + 1; diag_log format ["[FAC TestSuite] PASS (client): FAC_fires_artilleryDefinitions (%1)", count _fires]; } else { _fail = _fail + 1; diag_log "[FAC TestSuite] FAIL (client): FAC_fires_artilleryDefinitions"; };

    // ----- description.ext / Rsc displays (createDialog targets) -----
    private _rscNames = [
        "RscDisplayVehicle",
        "RscDisplayMissions",
        "RscDisplayScenario",
        "RscDisplayScenarioAdmin",
        "RscDisplayLoadout",
        "RscDisplayJukebox",
        "RscDisplayCQB",
        "RscDisplayTeleport",
        "RscDisplayTeleportPlayers",
        "RscDisplayFires"
    ];
    {
        private _cls = _x;
        private _p = missionConfigFile >> "RscTitles" >> _cls;
        private _exists = isClass _p;
        if (!_exists) then { _p = missionConfigFile >> _cls; _exists = isClass _p; };
        if (_exists) then {
            _pass = _pass + 1;
            diag_log format ["[FAC TestSuite] PASS (client): Rsc %1", _cls];
        } else {
            _fail = _fail + 1;
            diag_log format ["[FAC TestSuite] FAIL (client): Rsc %1 (not in missionConfigFile)", _cls];
        };
    } forEach _rscNames;

    diag_log format ["[FAC TestSuite] ========== CLIENT SUITE END: %1 passed, %2 failed ==========", _pass, _fail];
    [_pass, _fail]
};
