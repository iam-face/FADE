// =============================================================================
// MissionTestSuite.sqf  -  in-game regression / smoke tests (RPT via diag_log).
// Not auto-run on mission start.
//
// RECOMMENDED  -  full stack (client + server):
//   [] call FAC_missionTestSuite_execAll
//   Scroll wheel (debug-tools lobby param): "[DEV] Run FAC Test Suite"
//
// Individual suites (debug console):
//   Client:  [] call FAC_missionTestSuite_execClient
//   Server:  [player] remoteExec ["FAC_missionTestSuite_execServer", 2]
//            (pass player for systemChat; add true as 2nd arg for execAll callback)
//
// RPT filter: [FAC TestSuite]    -  PASS / FAIL / SKIP per check; sections:
//   BOOT / NET / MISSIONS / GUI / EDEN / compile
// =============================================================================

FAC_missionTestSuite__missionRunnerTypes = [
    "AreaOfOperations", "Operation", "TroopInsert", "TroopExtract", "Cargo", "MineClearing",
    "CASEVAC", "CSAR", "AssetRetrieval", "SearchDestroy", "InterceptConvoy", "EscapeEvasion", "GeoGuesser",
    "CAS", "HVT", "Hostage", "ClearArea"
];

// Returns true when a global variable holds CODE (a function is installed).
// _side is accepted for call-site symmetry with the diag_log lines (unused here).
FAC_missionTestSuite__checkFn = {
    params ["_side", "_name"];
    private _fn = missionNamespace getVariable [_name, nil];
    !isNil "_fn" && { _fn isEqualType {} }
};

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

    private _baseNpcReplies = missionNamespace getVariable ["FADE_baseNpcTalkReplies", []];
    _ok = _baseNpcReplies isEqualType [] && { count _baseNpcReplies >= 9 };
    if (_ok) then { _pass = _pass + 1; diag_log format ["[FAC TestSuite] PASS (server): FADE_baseNpcTalkReplies (%1)", count _baseNpcReplies]; } else { _fail = _fail + 1; diag_log "[FAC TestSuite] FAIL (server): FADE_baseNpcTalkReplies"; };
    private _bnMarker = missionNamespace getVariable ["FADE_baseNpcPosMarkerName", "BaseNPCPos"];
    private _bnPosObj = missionNamespace getVariable [_bnMarker, objNull];
    _ok = !isNull _bnPosObj;
    if (_ok) then { _pass = _pass + 1; diag_log format ["[FAC TestSuite] PASS (server): Eden %1 spawn marker", _bnMarker]; } else { _fail = _fail + 1; diag_log format ["[FAC TestSuite] FAIL (server): Eden %1 missing (save mission.sqm)", _bnMarker]; };
    private _baseNpcObj = missionNamespace getVariable ["FADE_baseNpc_unit", objNull];
    if (!isNull _baseNpcObj) then {
        _ok = _baseNpcObj getVariable ["FADE_baseNpcTalk", false];
        if (_ok) then { _pass = _pass + 1; diag_log "[FAC TestSuite] PASS (server): FADE_baseNpc_unit FADE_baseNpcTalk"; } else { _fail = _fail + 1; diag_log "[FAC TestSuite] FAIL (server): FADE_baseNpc_unit FADE_baseNpcTalk"; };
        private _bnNet = missionNamespace getVariable ["FADE_baseNpcTalk_netId", ""];
        _ok = _bnNet isEqualType "" && { _bnNet != "" };
        if (_ok) then { _pass = _pass + 1; diag_log format ["[FAC TestSuite] PASS (server): FADE_baseNpcTalk_netId %1", _bnNet]; } else { _fail = _fail + 1; diag_log "[FAC TestSuite] FAIL (server): FADE_baseNpcTalk_netId"; };
    } else {
        diag_log "[FAC TestSuite] SKIP (server): FADE_baseNpc_unit not spawned yet";
    };

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
    _ok = _gmt isEqualType [] && { "EscapeEvasion" in _gmt };
    if (_ok) then { _pass = _pass + 1; diag_log "[FAC TestSuite] PASS (server): FADE_globalMissionTypes contains EscapeEvasion"; } else { _fail = _fail + 1; diag_log "[FAC TestSuite] FAIL (server): FADE_globalMissionTypes / EscapeEvasion"; };
    _ok = _gmt isEqualType [] && { "GeoGuesser" in _gmt };
    if (_ok) then { _pass = _pass + 1; diag_log "[FAC TestSuite] PASS (server): FADE_globalMissionTypes contains GeoGuesser"; } else { _fail = _fail + 1; diag_log "[FAC TestSuite] FAIL (server): FADE_globalMissionTypes / GeoGuesser"; };
    _ok = _smt isEqualType [] && { count _smt > 0 };
    if (_ok) then { _pass = _pass + 1; diag_log format ["[FAC TestSuite] PASS (server): FADE_singleMissionTypes (%1)", count _smt]; } else { _fail = _fail + 1; diag_log "[FAC TestSuite] FAIL (server): FADE_singleMissionTypes"; };

    // ----- Position helpers -----
    private _mpos = [] call FADE_findMissionPos;
    _ok = count _mpos >= 2 && { !(_mpos isEqualTo []) };
    if (_ok) then { _pass = _pass + 1; diag_log format ["[FAC TestSuite] PASS (server): FADE_findMissionPos %1", _mpos select [0, 2]]; } else { _fail = _fail + 1; diag_log "[FAC TestSuite] FAIL (server): FADE_findMissionPos"; };

    private _anchorTest = if (count _mpos >= 2) then { +_mpos } else { +FADE_basePos };
    private _anchorPos = [_anchorTest, 700, 2500] call FADE_findMissionPosNearAnchor;
    _ok = count _anchorPos >= 2 && { (_anchorPos distance2D _anchorTest) <= 2550 };
    if (_ok) then { _pass = _pass + 1; diag_log format ["[FAC TestSuite] PASS (server): FADE_findMissionPosNearAnchor %1 (<= 2500m from anchor)", _anchorPos select [0, 2]]; } else { _fail = _fail + 1; diag_log "[FAC TestSuite] FAIL (server): FADE_findMissionPosNearAnchor"; };

    private _tiers = missionNamespace getVariable ["FADE_missionMapClickRadiusTiers", []];
    _ok = count _tiers >= 6 && { (_tiers select 0) == 250 } && { (_tiers select 5) == -1 };
    if (_ok) then { _pass = _pass + 1; diag_log format ["[FAC TestSuite] PASS (server): FADE_missionMapClickRadiusTiers %1", _tiers]; } else { _fail = _fail + 1; diag_log "[FAC TestSuite] FAIL (server): FADE_missionMapClickRadiusTiers"; };

    _ok = (missionNamespace getVariable ["FADE_missionMapPickTimeoutSec", 0]) == 20;
    if (_ok) then { _pass = _pass + 1; diag_log "[FAC TestSuite] PASS (server): FADE_missionMapPickTimeoutSec"; } else { _fail = _fail + 1; diag_log "[FAC TestSuite] FAIL (server): FADE_missionMapPickTimeoutSec"; };

    _ok = !([[]] call FADE_fnc_isValidMapClickPos) && { [[100, 200]] call FADE_fnc_isValidMapClickPos };
    if (_ok) then { _pass = _pass + 1; diag_log "[FAC TestSuite] PASS (server): FADE_fnc_isValidMapClickPos"; } else { _fail = _fail + 1; diag_log "[FAC TestSuite] FAIL (server): FADE_fnc_isValidMapClickPos"; };

    if (count _anchorPos >= 2) then {
        private _snap = [_anchorPos, 700] call FADE_fnc_snapMapClickToNearestCivZone;
        _ok = _snap isEqualType [] && { count _civT == 0 || { count _snap >= 2 } };
        if (_ok) then {
            _pass = _pass + 1;
            diag_log format ["[FAC TestSuite] PASS (server): FADE_fnc_snapMapClickToNearestCivZone %1", if (count _snap >= 2) then { str (_snap select [0, 2]) } else {"[] (no zones)"}];
        } else {
            _fail = _fail + 1;
            diag_log "[FAC TestSuite] FAIL (server): FADE_fnc_snapMapClickToNearestCivZone";
        };
        private _pick = [_anchorPos, "CAS", 700, false] call FADE_fnc_pickMissionDestNearMapClick;
        _ok = _pick isEqualType [] && { count _pick == 3 };
        if (_ok) then {
            _pick params ["_pickPos", "_pickR", "_pickSnap"];
            _ok = _pickPos isEqualType [] && { _pickR isEqualType 0 } && { _pickSnap isEqualType [] };
        };
        if (_ok) then {
            _pass = _pass + 1;
            diag_log format ["[FAC TestSuite] PASS (server): FADE_fnc_pickMissionDestNearMapClick CAS %1 r=%2", if (count (_pick select 0) >= 2) then { str ((_pick select 0) select [0, 2]) } else {"[]"}, _pick select 1];
        } else {
            _fail = _fail + 1;
            diag_log "[FAC TestSuite] FAIL (server): FADE_fnc_pickMissionDestNearMapClick";
        };
    } else {
        _fail = _fail + 1;
        diag_log "[FAC TestSuite] FAIL (server): map-click pick tests skipped (no anchor pos)";
    };

    private _bp = missionNamespace getVariable ["FADE_basePos", [0, 0, 0]];
    private _lz = [_bp] call FADE_findSafeLZ;
    _ok = _lz isEqualTo [] || { count _lz >= 2 };
    if (_ok) then { _pass = _pass + 1; diag_log format ["[FAC TestSuite] PASS (server): FADE_findSafeLZ(base) %1", if (_lz isEqualTo []) then {"[]"} else { str (_lz select [0, 2]) }]; } else { _fail = _fail + 1; diag_log "[FAC TestSuite] FAIL (server): FADE_findSafeLZ"; };

    // ----- Troop Insert / Extract (wave count, civ-zone heli sites) -----
    private _clampLo = [1] call FADE_startTroopTransport_clampWaves;
    private _clampHi = [99] call FADE_startTroopTransport_clampWaves;
    private _clampBad = ["x"] call FADE_startTroopTransport_clampWaves;
    _ok = _clampLo == 1 && { _clampHi == 10 } && { _clampBad == 1 };
    if (_ok) then { _pass = _pass + 1; diag_log "[FAC TestSuite] PASS (server): FADE_startTroopTransport_clampWaves (1..10)"; } else { _fail = _fail + 1; diag_log format ["[FAC TestSuite] FAIL (server): FADE_startTroopTransport_clampWaves (%1 %2 %3)", _clampLo, _clampHi, _clampBad]; };

    private _eligZones = [2000] call FADE_fnc_eligibleCivZoneCenters;
    _ok = _eligZones isEqualType [];
    if (_ok) then { _pass = _pass + 1; diag_log format ["[FAC TestSuite] PASS (server): FADE_fnc_eligibleCivZoneCenters (%1 zones)", count _eligZones]; } else { _fail = _fail + 1; diag_log "[FAC TestSuite] FAIL (server): FADE_fnc_eligibleCivZoneCenters"; };

    if (count _eligZones > 0) then {
        private _troopSite = [2000, [], [], -1, []] call FADE_fnc_pickTroopHeliSiteAtCivZone;
        _ok = _troopSite isEqualType [] && { count _troopSite == 0 || { count _troopSite >= 2 } };
        if (_ok) then {
            _pass = _pass + 1;
            diag_log format ["[FAC TestSuite] PASS (server): FADE_fnc_pickTroopHeliSiteAtCivZone %1", if (count _troopSite >= 2) then { str (_troopSite select [0, 2]) } else {"[] (no clear site this roll)"}];
        } else {
            _fail = _fail + 1;
            diag_log "[FAC TestSuite] FAIL (server): FADE_fnc_pickTroopHeliSiteAtCivZone";
        };
    } else {
        diag_log "[FAC TestSuite] SKIP (server): FADE_fnc_pickTroopHeliSiteAtCivZone (no eligible civ zones)";
    };

    _ok = !isNil "FADE_startTroopInsert" && { FADE_startTroopInsert isEqualType {} };
    if (_ok) then { _pass = _pass + 1; diag_log "[FAC TestSuite] PASS (server): FADE_startTroopInsert installed"; } else { _fail = _fail + 1; diag_log "[FAC TestSuite] FAIL (server): FADE_startTroopInsert missing"; };

    _ok = !isNil "FADE_startTroopExtract" && { FADE_startTroopExtract isEqualType {} };
    if (_ok) then { _pass = _pass + 1; diag_log "[FAC TestSuite] PASS (server): FADE_startTroopExtract installed"; } else { _fail = _fail + 1; diag_log "[FAC TestSuite] FAIL (server): FADE_startTroopExtract missing"; };

    if (!isNil "FADE_geoGuesser_computeScore") then {
        private _ggPerfect = [0, 60, 60, 1, 1] call FADE_geoGuesser_computeScore;
        private _ggMiss = [-1, 0, 60, 1, 1] call FADE_geoGuesser_computeScore;
        _ok = _ggPerfect == 1500 && { _ggMiss == 0 };
        if (_ok) then { _pass = _pass + 1; diag_log format ["[FAC TestSuite] PASS (server): FADE_geoGuesser_computeScore (%1 / %2)", _ggPerfect, _ggMiss]; } else { _fail = _fail + 1; diag_log format ["[FAC TestSuite] FAIL (server): FADE_geoGuesser_computeScore (%1 / %2)", _ggPerfect, _ggMiss]; };
    } else {
        _fail = _fail + 1;
        diag_log "[FAC TestSuite] FAIL (server): FADE_geoGuesser_computeScore missing";
    };

    private _urban = [700] call FADE_findMissionPosUrban;
    _ok = count _civT == 0 || { count _urban >= 2 };
    if (_ok) then { _pass = _pass + 1; diag_log format ["[FAC TestSuite] PASS (server): FADE_findMissionPosUrban(700) %1", if (count _urban >= 2) then { str (_urban select [0, 2]) } else {"[]"}]; } else { _fail = _fail + 1; diag_log "[FAC TestSuite] FAIL (server): FADE_findMissionPosUrban (no pos with civ zones)"; };

    private _urbanN = [700] call FADE_findMissionPosUrbanNearCenter;
    _ok = count _civT == 0 || { count _urbanN >= 2 };
    if (_ok) then { _pass = _pass + 1; diag_log format ["[FAC TestSuite] PASS (server): FADE_findMissionPosUrbanNearCenter %1", if (count _urbanN >= 2) then { str (_urbanN select [0, 2]) } else {"[]"}]; } else { _fail = _fail + 1; diag_log "[FAC TestSuite] FAIL (server): FADE_findMissionPosUrbanNearCenter"; };

    private _ied = [] call FADE_findMissionPosIED;
    _ok = count _civT == 0 || { count _ied >= 2 };
    if (_ok) then { _pass = _pass + 1; diag_log format ["[FAC TestSuite] PASS (server): FADE_findMissionPosIED %1", if (count _ied >= 2) then { str (_ied select [0, 2]) } else {"[]"}]; } else { _fail = _fail + 1; diag_log "[FAC TestSuite] FAIL (server): FADE_findMissionPosIED"; };

    // ----- Operation mode preconditions (mirrors rsc\missions\OperationMission.sqf) -----
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
        diag_log "[FAC TestSuite] FAIL (server): Operation  -  no civ zones (FADE_civTriggerNames empty)";
    } else {
        _pass = _pass + 1;
        diag_log format ["[FAC TestSuite] PASS (server): Operation  -  CIV zones listed (%1)", count _civNames];
    };

    if (count _civNames > 0 && { count _zoneCandidates == 0 }) then {
        _fail = _fail + 1;
        diag_log "[FAC TestSuite] FAIL (server): Operation  -  no civ zone >= 1000m from base (see OperationMission)";
    } else {
        if (count _zoneCandidates > 0) then {
            _pass = _pass + 1;
            private _wantOp = missionNamespace getVariable ["FADE_operationZoneCount", 6];
            _wantOp = (round _wantOp) max 2 min 10;
            private _effN = _wantOp min count _zoneCandidates;
            diag_log format ["[FAC TestSuite] PASS (server): Operation  -  zoneCandidates %1 (use %2 of want %3)", count _zoneCandidates, _effN, _wantOp];
            if (_effN < _wantOp) then {
                diag_log format ["[FAC TestSuite] NOTE (server): Operation  -  FADE_operationZoneCount trims (only %1 zones >= 1km from base)", count _zoneCandidates];
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

    if (!isNil "FADE_runMission" && { FADE_runMission isEqualType {} }) then {
        _pass = _pass + 1;
        diag_log "[FAC TestSuite] PASS (server): FADE_runMission installed";
    } else {
        _fail = _fail + 1;
        diag_log "[FAC TestSuite] FAIL (server): FADE_runMission missing";
    };
    if (!isNil "FADE_troopInsert_runTransport" && { FADE_troopInsert_runTransport isEqualType {} }) then {
        _pass = _pass + 1;
        diag_log "[FAC TestSuite] PASS (server): FADE_troopInsert_runTransport installed";
    } else {
        _fail = _fail + 1;
        diag_log "[FAC TestSuite] FAIL (server): FADE_troopInsert_runTransport missing";
    };
    if (!isNil "FADE_troopExtract_runTransport" && { FADE_troopExtract_runTransport isEqualType {} }) then {
        _pass = _pass + 1;
        diag_log "[FAC TestSuite] PASS (server): FADE_troopExtract_runTransport installed";
    } else {
        _fail = _fail + 1;
        diag_log "[FAC TestSuite] FAIL (server): FADE_troopExtract_runTransport missing";
    };
    if (missionNamespace getVariable ["FADE_missions_installed", false]) then {
        _pass = _pass + 1;
        diag_log "[FAC TestSuite] PASS (server): FADE_missions_installed";
    } else {
        _fail = _fail + 1;
        diag_log "[FAC TestSuite] FAIL (server): FADE_missions_installed false";
    };

    private _fires = missionNamespace getVariable ["FAC_fires_artilleryDefinitions", []];
    _ok = _fires isEqualType [] && { count _fires > 0 };
    if (_ok) then { _pass = _pass + 1; diag_log format ["[FAC TestSuite] PASS (server): FAC_fires_artilleryDefinitions (%1)", count _fires]; } else { _fail = _fail + 1; diag_log "[FAC TestSuite] FAIL (server): FAC_fires_artilleryDefinitions"; };

    // ----- All server publicVariable RPCs (must be CODE on server) -----
    private _lazyRangeServers = missionNamespace getVariable ["FADE_lazyLoadRangeServers", {}];
    if (_lazyRangeServers isEqualType {}) then { [] call _lazyRangeServers };

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
        "FADE_startEscapeEvasion",
        "FADE_startGeoGuesser",
        "FADE_geoGuesser_submitGuess",
        "FADE_startTroopInsert",
        "FADE_startTroopExtract",
        "FADE_getEnemyMenCount",
        "FADE_missionSlots_publish",
        "FADE_abortMission",
        "FADE_getCargoSeats",
        "FADE_ensureEnemyVehicleGunner",
        "FADE_fires_spawnPiece",
        "FADE_fires_despawnSlot",
        "FADE_fires_rearmSlot",
        "FADE_fires_requestState",
        "FADE_fires_setAmmoAmount",
        "FADE_fires_spawnAmmoTruck",
        "FADE_firesFoS_droneSpawnRequest",
        "FADE_firesFoS_droneDespawnRequest",
        "FADE_firesFoS_requestSync",
        "FADE_firesFoS_toggleImpactScreenSlot",
        "FADE_assetIntelTakeServer",
        "FADE_abortMissionSlot",
        "FAC_jukebox_stopAllMusic",
        "FAC_jukebox_serverPlay",
        "FADE_adminCleanupAction",
        "FAC_surrenderChallenge_start",
        "FAC_loadoutGui_serverRequestApplyToMember",
        "FADE_cqbStartDrill",
        "FADE_cqbEndDrill",
        "FADE_sniperStartSession",
        "FADE_sniperEndSession",
        "FADE_sniperServer_impactSphereFromClient",
        "FADE_rangeStartSession",
        "FADE_rangeEndSession",
        "FADE_rangeRequestAtWeaponState",
        "FADE_rangeSpawnFriendlyLandAtSlot",
        "FADE_rangeDespawnFriendlyLandAtSlot",
        "FADE_civTalk_start",
        "FADE_civTalk_topic",
        "FADE_civTalk_end",
        "FADE_civTalk_serverCivAnim"
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
        "rsc\missions\AOMission.sqf",
        "rsc\missions\OperationMission.sqf",
        "rsc\TroopInsertTransport.sqf",
        "rsc\TroopExtractTransport.sqf",
        "rsc\missions\TroopInsertMission.sqf",
        "rsc\missions\TroopExtractMission.sqf",
        "rsc\TroopInsertPickGui.sqf",
        "rsc\FADE_MapClickPick.sqf",
        "rsc\MissionPickOverlay.sqf",
        "rsc\ServerEntityRegistry.sqf",
        "rsc\FADE_Common.sqf",
        "rsc\FADE_MissionSlots.sqf",
        "rsc\FADE_MOTDBoard.sqf",
        "rsc\FADE_ClientCommon.sqf",
        "rsc\FAC_ClientBoardActions.sqf",
        "rsc\server\ServerGameplayCqb.sqf",
        "rsc\server\ServerGameplayCore.sqf",
        "rsc\server\ServerGameplayVehicles.sqf",
        "rsc\server\ServerGameplayMissions.sqf",
        "rsc\server\ServerGameplayMedTrain.sqf",
        "rsc\server\ServerGameplayMissionAdmin.sqf",
        "rsc\LoadoutPresetCommon.sqf",
        "rsc\FADE_MissionCommon.sqf",
        "rsc\missions\MissionAssetRetrieval.sqf",
        "rsc\missions\MissionSearchDestroy.sqf",
        "rsc\missions\MissionCasevacCsar.sqf",
        "rsc\missions\MissionInterceptConvoy.sqf",
        "rsc\missions\MissionEscapeEvasion.sqf",
        "rsc\missions\MissionGeoGuesser.sqf",
        "rsc\GeoGuesserPickGui.sqf",
        "rsc\GeoGuesserClient.sqf",
        "rsc\EscapeEvasionPickGui.sqf",
        "rsc\missions\MissionCAS.sqf",
        "rsc\missions\MissionCargo.sqf",
        "rsc\missions\MissionHVT.sqf",
        "rsc\missions\MissionHostage.sqf",
        "rsc\missions\MissionClearArea.sqf",
        "rsc\missions\MissionMineClearing.sqf",
        "rsc\missions\MissionTroopExtract.sqf",
        "rsc\EnemyAAA.sqf",
        "rsc\RoadblockCommon.sqf",
        "rsc\DynamicRoadblocks.sqf",
        "rsc\DummyUnits.sqf",
        "rsc\FiresFallOfShot.sqf",
        "rsc\FiresDrillServer.sqf",
        "rsc\SurrenderChallenge.sqf",
        "rsc\SniperRangeServer.sqf",
        "rsc\RangeShared.sqf",
        "rsc\RangeServer.sqf",
        "rsc\CivTalkServer.sqf",
        "rsc\FADE_IntelServer.sqf",
        "rsc\FADE_IntelClient.sqf",
        "rsc\FADE_MissionCompile.sqf",
        "rsc\FAC_MissionTypeLabels.sqf"
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

    // ----- BOOT / NET / MISSIONS (post-refactor) -----
    diag_log "[FAC TestSuite] --- BOOT / NET / MISSIONS (extended) ---";
    ["[FAC TestSuite] Server: boot, networking, mission runners, Eden...", _notifyPlayer] call FAC_missionTestSuite__serverChat;

    _ok = missionNamespace getVariable ["FADE_clientInitReady", false];
    if (_ok) then { _pass = _pass + 1; diag_log "[FAC TestSuite] PASS (server): FADE_clientInitReady"; } else { _fail = _fail + 1; diag_log "[FAC TestSuite] FAIL (server): FADE_clientInitReady"; };

    private _scenarioPack = missionNamespace getVariable ["FADE_scenarioClientSync", []];
    if (count _scenarioPack == 0 && {!isNil "FADE_scenarioClientSync"}) then { _scenarioPack = +FADE_scenarioClientSync; };
    _ok = count _scenarioPack >= 19 && { (_scenarioPack select 0) isEqualTo "v1" };
    if (_ok) then { _pass = _pass + 1; diag_log format ["[FAC TestSuite] PASS (server): FADE_scenarioClientSync v1 (%1 fields)", count _scenarioPack]; } else { _fail = _fail + 1; diag_log "[FAC TestSuite] FAIL (server): FADE_scenarioClientSync v1 pack"; };

    if (!isNil "FADE_missionSlots_publish") then { [] call FADE_missionSlots_publish; };
    private _slotsPack = missionNamespace getVariable ["FADE_missionSlotsSync", []];
    _ok = count _slotsPack == 5 && { (_slotsPack select 0) isEqualTo "v1" };
    if (_ok) then { _pass = _pass + 1; diag_log "[FAC TestSuite] PASS (server): FADE_missionSlotsSync v1 pack"; } else { _fail = _fail + 1; diag_log "[FAC TestSuite] FAIL (server): FADE_missionSlotsSync v1 pack"; };

    _ok = isNil "FADE_syncScenarioConfig";
    if (_ok) then { _pass = _pass + 1; diag_log "[FAC TestSuite] PASS (server): legacy FADE_syncScenarioConfig removed"; } else { _fail = _fail + 1; diag_log "[FAC TestSuite] FAIL (server): FADE_syncScenarioConfig still defined"; };

    {
        private _runnerName = format ["FADE_runMission_%1", _x];
        private _runner = missionNamespace getVariable [_runnerName, nil];
        _ok = !isNil "_runner" && { _runner isEqualType {} };
        if (_ok) then {
            _pass = _pass + 1;
            diag_log format ["[FAC TestSuite] PASS (server): %1", _runnerName];
        } else {
            _fail = _fail + 1;
            diag_log format ["[FAC TestSuite] FAIL (server): %1 missing", _runnerName];
        };
    } forEach FAC_missionTestSuite__missionRunnerTypes;

    private _gameplayFns = [
        "FADE_startMission", "FADE_clearActiveMission", "FADE_abortMission", "FADE_missionSlots_set",
        "FADE_installMissionModules", "FADE_aoMissionMain", "FADE_operationMissionMain", "FADE_troopInsertMissionMain", "FADE_troopExtractMissionMain",
        "FADE_cqbStartDrill", "FADE_cqbEndDrill", "FADE_rangeStartSession", "FADE_rangeEndSession",
        "FADE_sniperStartSession", "FADE_sniperEndSession", "FADE_startTroopInsert", "FADE_startTroopExtract",
        "FADE_startEscapeEvasion", "FADE_startGeoGuesser", "FADE_geoGuesser_submitGuess", "FADE_geoGuesser_computeScore",
        "FADE_startTroopTransport_clampWaves", "FADE_fnc_eligibleCivZoneCenters", "FADE_fnc_pickTroopHeliSiteAtCivZone"
    ];
    {
        private _chk = ["server", _x] call FAC_missionTestSuite__checkFn;
        if (_chk) then { _pass = _pass + 1; diag_log format ["[FAC TestSuite] PASS (server): %1", _x]; } else { _fail = _fail + 1; diag_log format ["[FAC TestSuite] FAIL (server): %1", _x]; };
    } forEach _gameplayFns;

    private _registryFns = [
        "FADE_entityRegistry_register", "FADE_entityRegistry_resolveNetId", "FADE_entityRegistry_install"
    ];
    {
        private _chk = ["server", _x] call FAC_missionTestSuite__checkFn;
        if (_chk) then { _pass = _pass + 1; diag_log format ["[FAC TestSuite] PASS (server): %1", _x]; } else { _fail = _fail + 1; diag_log format ["[FAC TestSuite] FAIL (server): %1", _x]; };
    } forEach _registryFns;

    _ok = missionNamespace getVariable ["FADE_entityRegistry_installed", false];
    if (_ok) then { _pass = _pass + 1; diag_log "[FAC TestSuite] PASS (server): FADE_entityRegistry_installed"; } else { _fail = _fail + 1; diag_log "[FAC TestSuite] FAIL (server): FADE_entityRegistry_installed"; };

    if (!isNil "FADE_getEnemyMenCount") then {
        private _emc = [] call FADE_getEnemyMenCount;
        _ok = _emc isEqualType 0 && { _emc >= 0 };
        if (_ok) then { _pass = _pass + 1; diag_log format ["[FAC TestSuite] PASS (server): FADE_getEnemyMenCount %1", _emc]; } else { _fail = _fail + 1; diag_log "[FAC TestSuite] FAIL (server): FADE_getEnemyMenCount"; };
    } else {
        _fail = _fail + 1;
        diag_log "[FAC TestSuite] FAIL (server): FADE_getEnemyMenCount missing";
    };

    if (!isNil "FADE_findSafePosArray") then {
        private _bpSafe = missionNamespace getVariable ["FADE_basePos", [0, 0, 0]];
        private _safePos = [[_bpSafe, 0, 80, 8, 1, 0.3, 0, [], _bpSafe], _bpSafe] call FADE_findSafePosArray;
        _ok = _safePos isEqualType [] && { count _safePos >= 2 };
        if (_ok) then { _pass = _pass + 1; diag_log format ["[FAC TestSuite] PASS (server): FADE_findSafePosArray %1", _safePos select [0, 2]]; } else { _fail = _fail + 1; diag_log "[FAC TestSuite] FAIL (server): FADE_findSafePosArray"; };
    } else {
        _fail = _fail + 1;
        diag_log "[FAC TestSuite] FAIL (server): FADE_findSafePosArray missing";
    };

    // ----- Eden terminals / boards -----
    diag_log "[FAC TestSuite] --- EDEN ---";
    private _edenRefs = [
        ["FADE_missionBoard", "missionBoard"],
        ["FADE_terminalRange", "terminalRange"]
    ];
    {
        _x params ["_var", "_fallback"];
        private _obj = missionNamespace getVariable [_var, objNull];
        if (isNull _obj) then { _obj = missionNamespace getVariable [_fallback, objNull]; };
        _ok = !isNull _obj;
        if (_ok) then { _pass = _pass + 1; diag_log format ["[FAC TestSuite] PASS (server): Eden %1", _var]; } else { _fail = _fail + 1; diag_log format ["[FAC TestSuite] FAIL (server): Eden %1 / %2 missing", _var, _fallback]; };
    } forEach _edenRefs;
    private _vehicleGuiAnchor = missionNamespace getVariable ["FADE_vehicleTerminal", objNull];
    private _vehicleGuiLabel = "FADE_vehicleTerminal";
    if (isNull _vehicleGuiAnchor) then {
        _vehicleGuiAnchor = missionNamespace getVariable ["terminalVeh", objNull];
        _vehicleGuiLabel = "terminalVeh";
    };
    if (isNull _vehicleGuiAnchor) then {
        _vehicleGuiAnchor = missionNamespace getVariable ["FADE_vehicleBoard", objNull];
        _vehicleGuiLabel = "FADE_vehicleBoard";
    };
    if (isNull _vehicleGuiAnchor) then {
        _vehicleGuiAnchor = missionNamespace getVariable ["vehicleBoard", objNull];
        _vehicleGuiLabel = "vehicleBoard";
    };
    _ok = !isNull _vehicleGuiAnchor;
    if (_ok) then { _pass = _pass + 1; diag_log format ["[FAC TestSuite] PASS (server): Eden vehicle GUI anchor (%1)", _vehicleGuiLabel]; } else { _fail = _fail + 1; diag_log "[FAC TestSuite] FAIL (server): Eden vehicle GUI anchor missing (terminalVeh or vehicleBoard)"; };

    diag_log format ["[FAC TestSuite] ========== SERVER SUITE END: %1 passed, %2 failed ==========", _pass, _fail];
    [_pass, _fail]
};

FAC_missionTestSuite_runClient = {
    if (!hasInterface) exitWith { [0, 0] };
    private _pass = 0;
    private _fail = 0;

    diag_log "[FAC TestSuite] ========== CLIENT SUITE START ==========";
    systemChat "[FAC TestSuite] Client: starting (functions + data)...";
    if (isNil "FAC_ensureMissionsGui") then { call compile preprocessFileLineNumbers "rsc\FAC_ClientGuiEnsure.sqf"; };
    if (!isNil "FAC_ensureMissionsGui") then { [] call FAC_ensureMissionsGui };
    {
        private _ensure = missionNamespace getVariable [_x, {}];
        if (_ensure isEqualType {}) then { [] call _ensure };
    } forEach [
        "FAC_ensureLoadoutGui",
        "FAC_ensureVehicleGui",
        "FAC_ensureMissionsGui",
        "FAC_ensureScenarioGui",
        "FAC_ensureJukeboxGui",
        "FAC_ensureCQBGui",
        "FAC_ensureFiresGui",
        "FAC_ensureTeleportGui",
        "FAC_ensureRangeGui",
        "FAC_ensureSniperGui",
        "FAC_ensureCivTalkGui",
        "FAC_ensureMedicalTrainingGui"
    ];

    private _fncNames = [
        "FADE_showMissionHint",
        "FADE_applyScenarioClientSync",
        "FADE_applyMissionSlotsClientSync",
        "FADE_aiSideChat_exec",
        "FAC_playerCanUseMissionsGui",
        "FAC_playerCanUseScenarioGui",
        "FAC_playerCanUseVehicleGui",
        "FAC_playerCanUseLoadoutGui",
        "FAC_playerCanUseScenarioAdmin",
        "FAC_playerCanUseJukebox",
        "FAC_playerCanUseDebugTools",
        "FAC_playerCanTeleportToPlayers",
        "FAC_lobbyParams_callAccess",
        "FAC_lobbyParams_serverDenyUnless",
        "FAC_ensureLobbyParams",
        "FAC_guiScheduleHeaderRefresh",
        "FAC_clientInstallBoardActions",
        "FAC_addScenarioActionToTerminal",
        "FAC_vehicleGui_fnc",
        "FAC_missionsGui_fnc",
        "FAC_missionLocationPickGui_fnc",
        "FAC_troopInsertPickGui_fnc",
        "FAC_escapeEvasionPickGui_fnc",
        "FAC_geoGuesserPickGui_fnc",
        "FADE_ggClient_beginRound",
        "FADE_ggClient_closeMissionGui",
        "FADE_ggClient_forceStop",
        "FADE_ggClient_showResults",
        "FAC_scenarioGui_fnc",
        "FAC_loadoutGui_fnc",
        "FAC_jukeboxGui_fnc",
        "FAC_jukebox_clientPlay",
        "FAC_jukebox_clientStopAll",
        "FAC_jukebox_fnc_addVehicleLoudspeakerAction",
        "FAC_jukebox_fnc_installVehicleLoudspeakerHandlers",
        "FAC_cqbGui_fnc",
        "FAC_firesGui_fnc",
        "FAC_firesFoS_fnc_clientDroneSync",
        "FAC_firesFoS_fnc_clientDroneStop",
        "FAC_firesFoS_fnc_clientImpactFeed",
        "FAC_firesFoS_fnc_reDroneSync",
        "FAC_firesFoS_fnc_reDroneStop",
        "FAC_firesFoS_fnc_reImpactFeed",
        "FAC_firesFoS_fnc_startMapClickDrone",
        "FAC_teleportGui_fnc",
        "FAC_cqbLoudspeaker_clientPlay",
        "FAC_surrenderChallenge_fnc_activate",
        "FADE_cqbClient_forceTargetDown",
        "FAC_sniperGui_fnc",
        "FADE_sniperClient_setProjectileTrace",
        "FADE_sniperClient_clearRangeFx",
        "FADE_sniperClient_setProjectileImpactMarkers",
        "FADE_sniperClient_showTrialHint",
        "FAC_rangeGui_fnc",
        "FADE_rangeClient_onSessionStarted",
        "FADE_rangeClient_enableSniperFxForRange",
        "FADE_rangeClient_disableSniperFxForRange",
        "FADE_rangeClient_setAtWeaponState",
        "FAC_civTalkGui_fnc",
        "FADE_civTalk_addLocalAction",
        "FADE_civTalk_clientOpen",
        "FADE_civTalk_clientBeginCutscene",
        "FADE_civTalk_clientTeardown",
        "FADE_civTalk_clientPlayerAnim",
        "FADE_civTalk_clientSetReply",
        "FADE_civTalk_clientPlayGestureAnimOnUnit",
        "FADE_civTalk_clientCloseCivTalkForGesture",
        "FADE_civTalk_clientMenuApplyLabels",
        "FADE_civTalk_clientApplyVerticalLayout",
        "FADE_client_escapeForDiary",
        "FADE_client_appendIntelDiary",
        "FADE_civTalk_clientAppendIntelDiary",
        "FADE_civTalk_clientClearPlayerAnim",
        "FADE_civTalk_debugPreviewCamera",
        "FADE_civTalk_debugApplyPreviewCamera",
        "FADE_civTalk_debugSpawnSceneAndCamera",
        "FADE_civTalk_debugResetScene",
        "FADE_civTalk_debugStopCamera",
        "FADE_intel_clientRegister",
        "FADE_intel_clientAppendIntelDiary",
        "FADE_showMissionAssignedIntro",
        "FAC_ensureLoadoutGui",
        "FAC_ensureVehicleGui",
        "FAC_ensureMissionsGui",
        "FAC_ensureScenarioGui",
        "FAC_ensureJukeboxGui",
        "FAC_ensureCQBGui",
        "FAC_ensureFiresGui",
        "FAC_ensureTeleportGui",
        "FAC_ensureRangeGui",
        "FAC_ensureSniperGui",
        "FAC_ensureCivTalkGui",
        "FAC_ensureMedicalTrainingGui"
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

    private _rangeVehicleMap = missionNamespace getVariable ["FADE_rangeVehicleTypeMap", []];
    _ok = _rangeVehicleMap isEqualType [] && {count _rangeVehicleMap >= 4};
    if (_ok) then { _pass = _pass + 1; diag_log format ["[FAC TestSuite] PASS (client): FADE_rangeVehicleTypeMap (%1)", count _rangeVehicleMap]; } else { _fail = _fail + 1; diag_log "[FAC TestSuite] FAIL (client): FADE_rangeVehicleTypeMap"; };

    private _rangeAtDefs = missionNamespace getVariable ["FADE_rangeAtWeaponDefinitions", []];
    _ok = _rangeAtDefs isEqualType [] && {count _rangeAtDefs > 0};
    if (_ok) then { _pass = _pass + 1; diag_log format ["[FAC TestSuite] PASS (client): FADE_rangeAtWeaponDefinitions (%1)", count _rangeAtDefs]; } else { _fail = _fail + 1; diag_log "[FAC TestSuite] FAIL (client): FADE_rangeAtWeaponDefinitions"; };

    // ----- description.ext / Rsc displays (createDialog targets) -----
    private _rscNames = [
        "RscDisplayVehicle",
        "RscDisplayMissions",
        "RscDisplayScenario",
        "RscDisplayLoadout",
        "RscDisplayJukebox",
        "RscDisplayCQB",
        "RscDisplayTeleport",
        "RscDisplayTeleportPlayers",
        "RscDisplayFires",
        "RscDisplaySniper",
        "RscDisplayRange",
        "RscDisplayMedicalTraining",
        "RscDisplayCivTalk"
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

    // ----- BOOT / NET / GUI (post-refactor) -----
    diag_log "[FAC TestSuite] --- BOOT / NET / GUI (extended) ---";
    systemChat "[FAC TestSuite] Client: boot sync, board actions, GUI ensure...";

    private _ok = missionNamespace getVariable ["FADE_clientInitReady", false];
    if (_ok) then { _pass = _pass + 1; diag_log "[FAC TestSuite] PASS (client): FADE_clientInitReady"; } else { _fail = _fail + 1; diag_log "[FAC TestSuite] FAIL (client): FADE_clientInitReady"; };

    private _scenarioPack = missionNamespace getVariable ["FADE_scenarioClientSync", []];
    if (count _scenarioPack == 0 && {!isNil "FADE_scenarioClientSync"}) then { _scenarioPack = +FADE_scenarioClientSync; };
    _ok = count _scenarioPack >= 19 && { (_scenarioPack select 0) isEqualTo "v1" };
    if (_ok) then { _pass = _pass + 1; diag_log format ["[FAC TestSuite] PASS (client): FADE_scenarioClientSync received (%1)", count _scenarioPack]; } else { _fail = _fail + 1; diag_log "[FAC TestSuite] FAIL (client): FADE_scenarioClientSync pack"; };

    private _slotsPack = missionNamespace getVariable ["FADE_missionSlotsSync", []];
    _ok = count _slotsPack == 5 && { (_slotsPack select 0) isEqualTo "v1" };
    if (_ok) then { _pass = _pass + 1; diag_log "[FAC TestSuite] PASS (client): FADE_missionSlotsSync received"; } else { _fail = _fail + 1; diag_log "[FAC TestSuite] FAIL (client): FADE_missionSlotsSync pack"; };

    private _gSlots = missionNamespace getVariable ["FADE_globalMission", []];
    private _sSlots = missionNamespace getVariable ["FADE_singleMissions", []];
    _ok = _gSlots isEqualType [] && { _sSlots isEqualType [] };
    if (_ok) then { _pass = _pass + 1; diag_log format ["[FAC TestSuite] PASS (client): mission slot vars (global %1, singles %2)", count _gSlots, count _sSlots]; } else { _fail = _fail + 1; diag_log "[FAC TestSuite] FAIL (client): mission slot client vars"; };

    _ok = isNil "FADE_syncScenarioConfig";
    if (_ok) then { _pass = _pass + 1; diag_log "[FAC TestSuite] PASS (client): legacy FADE_syncScenarioConfig removed"; } else { _fail = _fail + 1; diag_log "[FAC TestSuite] FAIL (client): FADE_syncScenarioConfig still defined"; };

    if (!isNil "FADE_client_escapeForDiary") then {
        private _escaped = ["test&line<tag>"] call FADE_client_escapeForDiary;
        _ok = _escaped find "&amp;" >= 0 && { _escaped find "&lt;" >= 0 } && { _escaped find "<tag>" < 0 };
        if (_ok) then { _pass = _pass + 1; diag_log "[FAC TestSuite] PASS (client): FADE_client_escapeForDiary"; } else { _fail = _fail + 1; diag_log format ["[FAC TestSuite] FAIL (client): FADE_client_escapeForDiary (%1)", _escaped]; };
    } else {
        _fail = _fail + 1;
        diag_log "[FAC TestSuite] FAIL (client): FADE_client_escapeForDiary missing";
    };

    private _ensureFns = [
        ["FAC_ensureLoadoutGui", "FAC_loadoutGui_fnc"],
        ["FAC_ensureVehicleGui", "FAC_vehicleGui_fnc"],
        ["FAC_ensureMissionsGui", "FAC_missionsGui_fnc"],
        ["FAC_ensureScenarioGui", "FAC_scenarioGui_fnc"],
        ["FAC_ensureJukeboxGui", "FAC_jukeboxGui_fnc"],
        ["FAC_ensureCQBGui", "FAC_cqbGui_fnc"],
        ["FAC_ensureFiresGui", "FAC_firesGui_fnc"],
        ["FAC_ensureTeleportGui", "FAC_teleportGui_fnc"],
        ["FAC_ensureRangeGui", "FAC_rangeGui_fnc"],
        ["FAC_ensureSniperGui", "FAC_sniperGui_fnc"],
        ["FAC_ensureCivTalkGui", "FAC_civTalkGui_fnc"],
        ["FAC_ensureMedicalTrainingGui", "FAC_medicalTrainingGui_fnc"]
    ];
    {
        _x params ["_ensure", "_guiFn"];
        private _ensureFn = missionNamespace getVariable [_ensure, {}];
        if (_ensureFn isEqualType {}) then { call _ensureFn; };
        private _gui = missionNamespace getVariable [_guiFn, nil];
        _ok = !isNil "_gui" && { _gui isEqualType {} };
        if (_ok) then { _pass = _pass + 1; diag_log format ["[FAC TestSuite] PASS (client): %1 -> %2", _ensure, _guiFn]; } else { _fail = _fail + 1; diag_log format ["[FAC TestSuite] FAIL (client): %1 -> %2", _ensure, _guiFn]; };
    } forEach _ensureFns;

    if (!isNil "FAC_troopInsertPickGui_fnc_missionLabels") then {
        private _tiLbl = ["TroopInsert"] call FAC_troopInsertPickGui_fnc_missionLabels;
        private _teLbl = ["TroopExtract"] call FAC_troopInsertPickGui_fnc_missionLabels;
        _ok = count _tiLbl == 3 && { count _teLbl == 3 } && { (_tiLbl select 0) == "TROOP INSERT" } && { (_teLbl select 0) == "TROOP EXTRACT" };
        if (_ok) then { _pass = _pass + 1; diag_log "[FAC TestSuite] PASS (client): troop transport pick labels (Insert + Extract)"; } else { _fail = _fail + 1; diag_log format ["[FAC TestSuite] FAIL (client): troop transport pick labels (%1 / %2)", _tiLbl, _teLbl]; };
    } else {
        _fail = _fail + 1;
        diag_log "[FAC TestSuite] FAIL (client): FAC_troopInsertPickGui_fnc_missionLabels missing";
    };

    private _mb = missionNamespace getVariable ["FADE_missionBoard", objNull];
    if (isNull _mb) then { _mb = missionNamespace getVariable ["missionBoard", objNull]; };
    if (!isNull _mb) then {
        _ok = count (actionIDs _mb) > 0;
        if (_ok) then { _pass = _pass + 1; diag_log format ["[FAC TestSuite] PASS (client): mission board actions (%1)", count (actionIDs _mb)]; } else { _fail = _fail + 1; diag_log "[FAC TestSuite] FAIL (client): mission board has no actions"; };
    } else {
        _fail = _fail + 1;
        diag_log "[FAC TestSuite] FAIL (client): mission board object missing";
    };

    diag_log format ["[FAC TestSuite] ========== CLIENT SUITE END: %1 passed, %2 failed ==========", _pass, _fail];
    [_pass, _fail]
};

FAC_missionTestSuite_showSummary = {
    params [
        ["_clientRes", [0, 0]],
        ["_serverRes", [0, 0]],
        ["_serverPending", false]
    ];
    if (!hasInterface) exitWith {};
    _clientRes params [["_cp", 0], ["_cf", 0]];
    _serverRes params [["_sp", 0], ["_sf", 0]];
    private _totalP = _cp + _sp;
    private _totalF = _cf + _sf;
    private _pendingLine = if (_serverPending) then { "<br/><font color='#FFA45B'>Server suite still running…</font>" } else { "" };
    private _color = if (_serverPending) then { "#FFD700" } else { if (_totalF == 0) then { "#90EE90" } else { "#FF6B6B" } };
    private _html = format [
        "<t size='1.1' color='%5'>FAC Test Suite</t><br/>Client: %1 pass / %2 fail<br/>Server: %3 pass / %4 fail<br/><br/>Total: %6 pass / %7 fail%8<br/><br/><font size='0.85'>Failure detail in RPT  -  filter: [FAC TestSuite] FAIL</font>",
        _cp, _cf, if (_serverPending) then { "…" } else { str _sp }, if (_serverPending) then { "…" } else { str _sf },
        _color, _totalP, _totalF, _pendingLine
    ];
    hint parseText _html;
    if (_serverPending) then {
        systemChat format ["[FAC TestSuite] Client done: %1 pass, %2 fail  -  server suite running…", _cp, _cf];
    } else {
        systemChat format ["[FAC TestSuite] Done  -  client %1/%2, server %3/%4 (%5 total fail). RPT filter: [FAC TestSuite] FAIL", _cp, _cf, _sp, _sf, _totalF];
    };
};
