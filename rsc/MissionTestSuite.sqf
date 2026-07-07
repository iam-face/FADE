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
//   BOOT / NET / MISSIONS / PLACEMENT / SMEAC / MISSION HELPERS / GUI / EDEN / compile
// =============================================================================

FAC_missionTestSuite__missionRunnerTypes = [
    "AreaOfOperations", "Operation", "Raid", "Invasion", "TroopInsert", "TroopExtract", "Cargo", "MineClearing",
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

// try { call _code } — returns [ok, result, exceptionText]
FAC_missionTestSuite__tryCall = {
    params ["_code"];
    private _result = [];
    private _err = "";
    private _ok = true;
    try {
        _result = call _code;
    } catch {
        _ok = false;
        _err = str _exception;
    };
    [_ok, _result, _err]
};

FAC_missionTestSuite__placementMinDist = {
    params ["_missionType"];
    private _spawnsEnemies = _missionType in [
        "TroopExtract", "CAS", "HVT", "Hostage", "ClearArea", "InterceptConvoy", "AreaOfOperations",
        "CASEVAC", "CSAR", "AssetRetrieval", "SearchDestroy", "Operation", "Raid", "Invasion", "EscapeEvasion"
    ];
    private _minDist = if (_spawnsEnemies) then { 1000 } else { missionNamespace getVariable ["FADE_minDistFromBase", 500] };
    if (_missionType in ["TroopInsert", "TroopExtract"]) then {
        _minDist = _minDist max (missionNamespace getVariable ["FADE_troopInsertExtractMinDistFromBase", 1000]);
    };
    _minDist
};

// #region agent log
FAC_facDebugAgentLog = {
    params ["_hypothesisId", "_location", "_message", ["_data", []]];
    private _dataStr = if (_data isEqualType []) then { str _data } else { str _data };
    private _ts = round (diag_tickTime * 1000);
    private _line = format [
        "{\"sessionId\":\"add34b\",\"hypothesisId\":\"%1\",\"location\":\"%2\",\"message\":\"%3\",\"data\":%4,\"timestamp\":%5}",
        _hypothesisId, _location, _message, _dataStr, _ts
    ];
    diag_log format ["[DBG-add34b] %1", _line];
    private _cfg = str missionConfigFile;
    private _idx = _cfg find "\description.ext";
    if (_idx > 0) then {
        private _dir = _cfg select [1, _idx - 1];
        private _fh = openFile [_dir + "\debug-add34b.log", "Append"];
        if (!isNil "_fh" && { _fh >= 0 }) then {
            writeLine [_fh, _line];
            closeFile _fh;
        };
    };
};
// #endregion

// Append paths from a missionNamespace module manifest (unique, stable order).
FAC_missionTestSuite__appendModuleManifest = {
    params [["_files", []], ["_listVar", ""]];
    private _list = missionNamespace getVariable [_listVar, nil];
    if (isNil "_list" || {!(_list isEqualType [])}) exitWith { _files };
    {
        if !(_x in _files) then { _files pushBack _x };
    } forEach _list;
    _files
};

// Union of all FADE_*ModuleList manifests (post-boot).
FAC_missionTestSuite__collectModuleManifest = {
    private _out = [];
    {
        _out = [_out, _x] call FAC_missionTestSuite__appendModuleManifest;
    } forEach [
        "FADE_missionModuleList",
        "FADE_serverWorldModuleList",
        "FADE_serverBootstrapModuleList",
        "FADE_ambientCiviliansModuleList",
        "FADE_serverGameplayMissionsModuleList",
        "FADE_aoMissionModuleList",
        "FADE_operationMissionModuleList",
        "FADE_invasionMissionModuleList"
    ];
    _out
};

// Runners that use custom param globals instead of FADE_missionRun_getContext (anti-regression exempt).
FAC_missionTestSuite__getContextExemptPaths = [
    "rsc\\missions\\AOMission.sqf",
    "rsc\\missions\\AOMissionInfil.sqf",
    "rsc\\missions\\AOMissionMain.sqf",
    "rsc\\missions\\AOMissionRunner.sqf",
    "rsc\\missions\\OperationMission.sqf",
    "rsc\\missions\\OperationMissionPick.sqf",
    "rsc\\missions\\OperationMissionMain.sqf",
    "rsc\\missions\\OperationMissionRunner.sqf",
    "rsc\\missions\\MissionInvasion.sqf",
    "rsc\\missions\\MissionInvasionHelpers.sqf",
    "rsc\\missions\\MissionInvasionMain.sqf",
    "rsc\\missions\\MissionInvasionRunner.sqf",
    "rsc\\missions\\TroopInsertMission.sqf",
    "rsc\\missions\\TroopExtractMission.sqf"
];

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
        private _maxCivDist = missionNamespace getVariable ["FADE_troopHeliSiteMaxDistFromCivZone", 250];
        _ok = _troopSite isEqualType [] && { count _troopSite == 0 || { count _troopSite >= 2 } };
        if (_ok && { count _troopSite >= 2 }) then {
            private _nearestZoneD = 1e15;
            { _nearestZoneD = _nearestZoneD min (_troopSite distance2D _x) } forEach _eligZones;
            _ok = _nearestZoneD <= _maxCivDist;
            if (!_ok) then {
                diag_log format ["[FAC TestSuite] FAIL (server): troop heli site %1 m from nearest eligible civ zone (max %2)", round _nearestZoneD, _maxCivDist];
            };
        };
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

    _ok = !isNil "FADE_getEnemyDroneVehicleClasses" && { !isNil "FADE_opforDrone_trySpawn" } && { !isNil "FADE_opforThreatIntensity" };
    if (_ok) then {
        private _ti = ["Normal"] call FADE_opforThreatIntensity;
        _ok = _ti isEqualTo [2, 300];
    };
    if (_ok) then { _pass = _pass + 1; diag_log "[FAC TestSuite] PASS (server): OPFOR drone/air intensity helpers"; } else { _fail = _fail + 1; diag_log "[FAC TestSuite] FAIL (server): OPFOR drone/air intensity helpers"; };

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
        "FADE_filterEnemyUnitsByLauncherPolicy",
        "FADE_reapplyOpforLauncherPolicyToAliveEnemy",
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
        "FADE_civTalk_serverCivAnim",
        "FADE_recruit_requestFactionList",
        "FADE_recruit_requestFactionUnits",
        "FADE_recruit_requestRoster",
        "FADE_recruit_spawnUnit",
        "FADE_recruit_dismissUnits"
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
    private _compileFiles = [] call FAC_missionTestSuite__collectModuleManifest;
    // #region agent log
    ["C", "MissionTestSuite.sqf:compile", "collectModuleManifest", [count _compileFiles]] call FAC_facDebugAgentLog;
    // #endregion
    {
        if !(_x in _compileFiles) then { _compileFiles pushBack _x };
    } forEach [
        "rsc\Missions.sqf",
        "rsc\TroopTransport.sqf",
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
        "rsc\ConfigClient.sqf",
        "rsc\ConfigClientDefaults.sqf",
        "rsc\FADE_MissionSpawn.sqf",
        "rsc\FADE_RaidHelpers.sqf",
        "rsc\FADE_ObjectiveHelpers.sqf",
        "rsc\FADE_ZoneCaptureHelpers.sqf",
        "rsc\FADE_MedevacMissionCommon.sqf",
        "rsc\FADE_TroopMissionCommon.sqf",
        "rsc\MissionLore.sqf",
        "rsc\MissionConvoyMapPick.sqf",
        "rsc\MissionRaidMapPick.sqf",
        "rsc\fn_FADE_interceptConvoyRoadRoute.sqf",
        "rsc\fn_FADE_interceptConvoyRouteWaypoints.sqf",
        "rsc\GeoGuesserPickGui.sqf",
        "rsc\GeoGuesserClient.sqf",
        "rsc\EscapeEvasionPickGui.sqf",
        "rsc\ConfigDefaults.sqf",
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
        "rsc\FAC_MissionTypeLabels.sqf",
        "rsc\FADE_OpforDrones.sqf",
        "rsc\FADE_VirtualGarrison.sqf",
        "rsc\AmbientCivilians.sqf",
        "rsc\BaseNpcTalk.sqf",
        "rsc\CutsceneServer.sqf",
        "rsc\server\ServerGameplayRecruit.sqf",
        "rsc\server\ServerWorld.sqf",
        "rsc\server\ServerBootstrap.sqf"
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
        "FADE_installMissionModules", "FADE_aoMissionMain", "FADE_operationMissionMain", "FADE_invasionMissionMain", "FADE_lore_generate", "FADE_troopInsertMissionMain", "FADE_troopExtractMissionMain",
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

    {
        private _chk = ["server", _x] call FAC_missionTestSuite__checkFn;
        if (_chk) then { _pass = _pass + 1; diag_log format ["[FAC TestSuite] PASS (server): %1", _x]; } else { _fail = _fail + 1; diag_log format ["[FAC TestSuite] FAIL (server): %1", _x]; };
    } forEach ["FADE_aaa_getStaticAAClass", "FADE_aaa_applyLevel", "FADE_aaa_clusterTick"];

    if (!isNil "FADE_aaa_getStaticAAClass") then {
        private _aaClass = [missionNamespace getVariable ["FADE_scenarioEnemyFaction", "OPF_F"]] call FADE_aaa_getStaticAAClass;
        _ok = _aaClass isEqualType "" && { _aaClass != "" } && { isClass (configFile >> "CfgVehicles" >> _aaClass) };
        if (_ok) then { _pass = _pass + 1; diag_log format ["[FAC TestSuite] PASS (server): FADE_aaa_getStaticAAClass %1", _aaClass]; } else { _fail = _fail + 1; diag_log "[FAC TestSuite] FAIL (server): FADE_aaa_getStaticAAClass invalid"; };
    };

    if (!isNil "FADE_lore_generate") then {
        private _lore = ["HVT", FADE_basePos, "Operation Test"] call FADE_lore_generate;
        _ok = _lore isEqualType [] && { count _lore >= 3 } && { (_lore select 0) isEqualType "" } && { (_lore select 1) isEqualType "" } && { (_lore select 2) isEqualType "" } && { (_lore select 0) != "" } && { (_lore select 2) find "BACKGROUND" >= 0 } && { (_lore select 2) find "Threat assessment:" >= 0 } && { (_lore select 2) find "Commander's intent:" >= 0 } && { (_lore select 1) find "SITUATION:" < 0 } && { count (_lore select 2) > 120 };
        if (_ok) then { _pass = _pass + 1; diag_log "[FAC TestSuite] PASS (server): FADE_lore_generate"; } else { _fail = _fail + 1; diag_log "[FAC TestSuite] FAIL (server): FADE_lore_generate"; };
        private _loreRaid = ["Raid", FADE_basePos, "Operation Test"] call FADE_lore_generate;
        _ok = (_loreRaid select 2) find "is reported to have" >= 0 || { (_loreRaid select 2) find "is active near" >= 0 };
        if (_ok) then { _pass = _pass + 1; diag_log "[FAC TestSuite] PASS (server): FADE_lore_generate enemy lore line"; } else { _fail = _fail + 1; diag_log "[FAC TestSuite] FAIL (server): FADE_lore_generate enemy lore line"; };
        private _lore2 = ["HVT", FADE_basePos, "Operation Test"] call FADE_lore_generate;
        _ok = _lore isEqualTo _lore2;
        if (_ok) then { _pass = _pass + 1; diag_log "[FAC TestSuite] PASS (server): FADE_lore_generate seeded"; } else { _fail = _fail + 1; diag_log "[FAC TestSuite] FAIL (server): FADE_lore_generate seeded"; };
        private _loreCargo = ["Cargo", FADE_basePos, "Supply Run"] call FADE_lore_generate;
        _ok = (_loreCargo select 1) find "eliminate the threat" < 0;
        if (_ok) then { _pass = _pass + 1; diag_log "[FAC TestSuite] PASS (server): FADE_lore_generate Cargo tone"; } else { _fail = _fail + 1; diag_log "[FAC TestSuite] FAIL (server): FADE_lore_generate Cargo tone"; };
    };

    private _smeacBuilder = missionNamespace getVariable ["FADE_buildMissionTaskSmeacText", {}];
    if (!(_smeacBuilder isEqualTo {})) then {
        private _smeacTxt = [
            "Test mission objective.",
            FADE_basePos,
            "<t align='left' color='#FFD166'>ENEMY</t><br/><t align='left' color='#B0B0B0'>Hostile patrols in sector.</t>",
            "<t align='left' color='#C0C0C0'>Step one.</t>",
            "<t align='left' color='#FFFFFF'>Mission lead: Zero Alpha.</t>",
            "<t align='left' color='#FFFFFF'>Radio: test.</t>"
        ] call _smeacBuilder;
        private _iBg = _smeacTxt find "BACKGROUND";
        private _iSit = _smeacTxt find "SITUATION";
        private _iMis = _smeacTxt find "MISSION";
        private _iExec = _smeacTxt find "EXECUTION";
        private _iAdmin = _smeacTxt find "ADMIN";
        private _iCmd = _smeacTxt find "COMMAND";
        _ok = _iBg >= 0 && { _iSit > _iBg } && { _iMis > _iSit } && { _iExec > _iMis } && { _iAdmin > _iExec } && { _iCmd > _iAdmin };
        if (_ok) then { _pass = _pass + 1; diag_log "[FAC TestSuite] PASS (server): FADE_buildMissionTaskSmeacText order"; } else { _fail = _fail + 1; diag_log "[FAC TestSuite] FAIL (server): FADE_buildMissionTaskSmeacText order"; };
    };

    if (!isNil "FADE_raid_pickVariants") then {
        private _rv = [3] call FADE_raid_pickVariants;
        private _inZ = [] call FADE_raid_inZoneVariants;
        private _rtb = [] call FADE_raid_rtbVariants;
        _ok = count _rv == 3 && { (_rv findIf { _x in _inZ }) >= 0 } && { (_rv findIf { _x in _rtb }) >= 0 } && { { _x == "RecoverHostage" } count _rv <= 1 };
        if (_ok) then { _pass = _pass + 1; diag_log "[FAC TestSuite] PASS (server): FADE_raid_pickVariants"; } else { _fail = _fail + 1; diag_log "[FAC TestSuite] FAIL (server): FADE_raid_pickVariants"; };
    };

    if (!isNil "FADE_raid_pickObjectiveCodenames") then {
        private _cn = ["FADE_test_raid", 3] call FADE_raid_pickObjectiveCodenames;
        _ok = count _cn == 3 && { (_cn select 0) isEqualType "" } && { (_cn select 0) == toUpper (_cn select 0) } && { count (_cn arrayIntersect +_cn) == 3 };
        if (_ok) then { _pass = _pass + 1; diag_log format ["[FAC TestSuite] PASS (server): FADE_raid_pickObjectiveCodenames %1", _cn]; } else { _fail = _fail + 1; diag_log "[FAC TestSuite] FAIL (server): FADE_raid_pickObjectiveCodenames"; };
    };

    {
        private _chk = ["server", _x] call FAC_missionTestSuite__checkFn;
        if (_chk) then { _pass = _pass + 1; diag_log format ["[FAC TestSuite] PASS (server): %1", _x]; } else { _fail = _fail + 1; diag_log format ["[FAC TestSuite] FAIL (server): %1", _x]; };
    } forEach [
        "FADE_raid_pickCellName", "FADE_raid_pickObjectiveCodenames", "FADE_raid_spawnZone", "FADE_objective_findBuilding",
        "FADE_raid_applyScale", "FADE_objective_spawnRecoverObject", "FADE_objective_registerNearbyGarrisons", "FADE_raid_startIntelMonitor",
        "FADE_objective_findBuildingsWithMinSlots", "FADE_objective_addHostageToGroup", "FADE_objective_garrisonBuildingSlots",
        "FADE_objective_spawnPatrolsPerBuilding", "FADE_objective_spawnHostageInBuilding", "FADE_pickHostageIdentity"
    ];

    // ----- Shared mission helpers (refactor pass) -----
    diag_log "[FAC TestSuite] --- MISSION HELPERS (shared) ---";

    _ok = isNil "FADE_missionSpawnPatrol";
    if (_ok) then { _pass = _pass + 1; diag_log "[FAC TestSuite] PASS (server): FADE_missionSpawnPatrol removed (dead code)"; } else { _fail = _fail + 1; diag_log "[FAC TestSuite] FAIL (server): FADE_missionSpawnPatrol still defined"; };

    _ok = !isNil "FADE_missionModuleList" && { FADE_missionModuleList isEqualType [] } && { count FADE_missionModuleList >= 25 };
    if (_ok) then { _pass = _pass + 1; diag_log format ["[FAC TestSuite] PASS (server): FADE_missionModuleList (%1 modules)", count FADE_missionModuleList]; } else { _fail = _fail + 1; diag_log "[FAC TestSuite] FAIL (server): FADE_missionModuleList"; };

    _ok = (missionNamespace getVariable ["FADE_minDistBetweenMissions", -1]) == 2000;
    if (_ok) then { _pass = _pass + 1; diag_log "[FAC TestSuite] PASS (server): FADE_minDistBetweenMissions (ConfigClient)"; } else { _fail = _fail + 1; diag_log "[FAC TestSuite] FAIL (server): FADE_minDistBetweenMissions"; };

    {
        private _chk = ["server", _x] call FAC_missionTestSuite__checkFn;
        if (_chk) then { _pass = _pass + 1; diag_log format ["[FAC TestSuite] PASS (server): %1", _x]; } else { _fail = _fail + 1; diag_log format ["[FAC TestSuite] FAIL (server): %1", _x]; };
    } forEach [
        "FADE_missionRun_getContext", "FADE_mission_completeCleanup",
        "FADE_createRegisteredMarker", "FADE_deleteMarkerSafe",
        "FADE_getAlivePlayers", "FADE_getAlivePlayerPositions", "FADE_countFriendlyPlayers",
        "FADE_ao_pointsWithoutFriendlies",
        "FADE_missionErrorHint", "FADE_missionOutcomeHint", "FADE_missionFailHint", "FADE_missionSuccessHint",
        "FADE_textureText_sanitize", "FADE_textureText_wrap",
        "FADE_mission_createRadiusMarker", "FADE_mission_createObjectiveMarker",
        "FADE_mission_computeSearchZone", "FADE_mission_positionsCentroid",
        "FADE_mission_spawnFieldContactEnemies", "FADE_missionSpawnGuards", "FADE_cargo_cleanupSiteDeferred",
        "FADE_mission_findPickupSpawnPos", "FADE_mission_spawnFriendlyPickupGroup", "FADE_mission_spawnCasualtyHeliWreck", "FADE_mission_groundAtlPos",
        "FADE_mission_applyPickupGroupPosture", "FADE_mission_casevacCasualtyPrep", "FADE_mission_csarPilotWoundPrep",
        "FADE_zone_createCaptureMarkerPair", "FADE_zone_tickOperationCapture", "FADE_zone_tickInvasionHold",
        "FADE_troopMission_liveParticipants", "FADE_troopMission_runTransportWave", "FADE_troopMission_clearParticipantMissionVars",
        "FADE_pickHvtCodename", "FADE_getIdentityDisplayName", "FADE_objective_findBuildingForMission"
    ];

    if (!isNil "FADE_missionRun_getContext") then {
        private _ctx = call FADE_missionRun_getContext;
        private _fieldCount = missionNamespace getVariable ["FADE_missionRun_contextFieldCount", 49];
        _ok = _ctx isEqualType [] && { count _ctx == _fieldCount };
        if (_ok) then { _pass = _pass + 1; diag_log format ["[FAC TestSuite] PASS (server): FADE_missionRun_getContext (%1 fields)", _fieldCount]; } else { _fail = _fail + 1; diag_log format ["[FAC TestSuite] FAIL (server): FADE_missionRun_getContext count %1 (expected %2)", count _ctx, _fieldCount]; };
    };

    if (!isNil "FADE_missionModuleList") then {
        private _legacyRunners = [];
        private _samplePath = "rsc\missions\MissionHVT.sqf";
        private _loadLen = count (loadFile _samplePath);
        private _preLen = count (preprocessFileLineNumbers _samplePath);
        // #region agent log
        ["A", "MissionTestSuite.sqf:antiRegress", "loadFile vs preprocess", [_samplePath, _loadLen, _preLen]] call FAC_facDebugAgentLog;
        // #endregion
        {
            private _path = _x;
            if (_path in FAC_missionTestSuite__getContextExemptPaths) then { continue };
            if !(_path find "rsc\missions\Mission" == 0 || { _path find "rsc\missions\Troop" == 0 }) then { continue };
            private _txt = preprocessFileLineNumbers _path;
            if (_txt == "") then {
                _legacyRunners pushBack _path;
                continue;
            };
            private _usesCtx = _txt find "FADE_missionRun_getContext" >= 0;
            private _legacy = _txt find "missionNamespace getVariable [""FADE_missionRun_missionType""" >= 0;
            if (!_usesCtx || _legacy) then { _legacyRunners pushBack _path };
        } forEach FADE_missionModuleList;
        // #region agent log
        ["A", "MissionTestSuite.sqf:antiRegress", "legacyRunners", _legacyRunners] call FAC_facDebugAgentLog;
        // #endregion
        _ok = count _legacyRunners == 0;
        if (_ok) then {
            _pass = _pass + 1;
            diag_log "[FAC TestSuite] PASS (server): standard runners use FADE_missionRun_getContext (no legacy missionType block)";
        } else {
            _fail = _fail + 1;
            diag_log format ["[FAC TestSuite] FAIL (server): legacy missionRun reads in %1", _legacyRunners];
        };
    };

    private _ambientWaitEnd = diag_tickTime + 15;
    waitUntil {
        sleep 0.1;
        !isNil { missionNamespace getVariable "FADE_ambientCiviliansModuleList" } || { diag_tickTime > _ambientWaitEnd }
    };
    // #region agent log
    ["B", "MissionTestSuite.sqf:manifest", "ambientModuleList ready", [
        !isNil { missionNamespace getVariable "FADE_ambientCiviliansModuleList" },
        count (missionNamespace getVariable ["FADE_ambientCiviliansModuleList", []])
    ]] call FAC_facDebugAgentLog;
    // #endregion

    {
        private _lst = missionNamespace getVariable [_x select 0, nil];
        _ok = !isNil "_lst" && { _lst isEqualType [] } && { count _lst >= (_x select 1) };
        if (_ok) then {
            _pass = _pass + 1;
            diag_log format ["[FAC TestSuite] PASS (server): %1 (%2 paths)", _x select 0, count _lst];
        } else {
            _fail = _fail + 1;
            diag_log format ["[FAC TestSuite] FAIL (server): %1 manifest", _x select 0];
        };
    } forEach [
        ["FADE_serverWorldModuleList", 6],
        ["FADE_serverBootstrapModuleList", 3],
        ["FADE_ambientCiviliansModuleList", 4],
        ["FADE_serverGameplayMissionsModuleList", 3],
        ["FADE_aoMissionModuleList", 3],
        ["FADE_operationMissionModuleList", 3],
        ["FADE_invasionMissionModuleList", 3]
    ];

    if (!isNil "FADE_missionModuleList") then {
        _ok = !("rsc\\missions\\MissionTroopExtract.sqf" in FADE_missionModuleList);
        if (_ok) then { _pass = _pass + 1; diag_log "[FAC TestSuite] PASS (server): MissionTroopExtract.sqf removed from module list"; } else { _fail = _fail + 1; diag_log "[FAC TestSuite] FAIL (server): MissionTroopExtract.sqf still in FADE_missionModuleList"; };
    };

    if (!isNil "FADE_createRegisteredMarker") then {
        private _testMkr = ["FAC_testSuite_mkr", [0, 0, 0], ""] call FADE_createRegisteredMarker;
        [_testMkr] call FADE_deleteMarkerSafe;
        _ok = _testMkr isEqualType "" && { _testMkr == "FAC_testSuite_mkr" };
        if (_ok) then { _pass = _pass + 1; diag_log "[FAC TestSuite] PASS (server): FADE_createRegisteredMarker round-trip"; } else { _fail = _fail + 1; diag_log "[FAC TestSuite] FAIL (server): FADE_createRegisteredMarker"; };
    };

    if (!isNil "FADE_startupFactionFriendly") then {
        _pass = _pass + 1;
        diag_log "[FAC TestSuite] PASS (server): ConfigDefaults loaded (FADE_startupFactionFriendly)";
    } else {
        _fail = _fail + 1;
        diag_log "[FAC TestSuite] FAIL (server): ConfigDefaults not loaded";
    };

    _ok = (missionNamespace getVariable ["FADE_minDistBetweenMissions", -1]) == 2000 && { !isNil "FADE_missionMapClickRadiusTiers" };
    if (_ok) then { _pass = _pass + 1; diag_log "[FAC TestSuite] PASS (server): ConfigClientDefaults loaded"; } else { _fail = _fail + 1; diag_log "[FAC TestSuite] FAIL (server): ConfigClientDefaults"; };

    if (!isNil "FADE_getAlivePlayers") then {
        _ok = ([] call FADE_getAlivePlayers) isEqualType [];
        if (_ok) then { _pass = _pass + 1; diag_log format ["[FAC TestSuite] PASS (server): FADE_getAlivePlayers (%1)", count ([] call FADE_getAlivePlayers)]; } else { _fail = _fail + 1; diag_log "[FAC TestSuite] FAIL (server): FADE_getAlivePlayers return type"; };
    };

    private _fcpFn = missionNamespace getVariable ["FADE_countFriendlyPlayers", nil];
    if (!isNil "_fcpFn" && { _fcpFn isEqualType {} }) then {
        private _fcp = [missionNamespace getVariable ["FADE_sideFriendly", west]] call _fcpFn;
        _ok = _fcp isEqualType 0 && { _fcp >= 0 };
        if (_ok) then { _pass = _pass + 1; diag_log format ["[FAC TestSuite] PASS (server): FADE_countFriendlyPlayers %1", _fcp]; } else { _fail = _fail + 1; diag_log "[FAC TestSuite] FAIL (server): FADE_countFriendlyPlayers"; };
    };

    if (!isNil "FADE_ao_pointsWithoutFriendlies") then {
        _ok = ([[], 100, west] call FADE_ao_pointsWithoutFriendlies) isEqualTo [];
        if (_ok) then { _pass = _pass + 1; diag_log "[FAC TestSuite] PASS (server): FADE_ao_pointsWithoutFriendlies empty input"; } else { _fail = _fail + 1; diag_log "[FAC TestSuite] FAIL (server): FADE_ao_pointsWithoutFriendlies empty input"; };
    };

    if (!isNil "FADE_textureText_sanitize") then {
        private _san = ["say ""hi"""] call FADE_textureText_sanitize;
        _ok = _san find "'" >= 0 && { _san find (toString [34]) < 0 };
        if (_ok) then { _pass = _pass + 1; diag_log format ["[FAC TestSuite] PASS (server): FADE_textureText_sanitize (%1)", _san]; } else { _fail = _fail + 1; diag_log format ["[FAC TestSuite] FAIL (server): FADE_textureText_sanitize (%1)", _san]; };
    };

    if (!isNil "FADE_textureText_wrap") then {
        private _wrap = ["one two three four five", 12] call FADE_textureText_wrap;
        _ok = _wrap isEqualType "" && { _wrap find " " >= 0 };
        if (_ok) then { _pass = _pass + 1; diag_log "[FAC TestSuite] PASS (server): FADE_textureText_wrap"; } else { _fail = _fail + 1; diag_log "[FAC TestSuite] FAIL (server): FADE_textureText_wrap"; };
    };

    if (!isNil "FADE_mission_findPickupSpawnPos") then {
        private _bpPick = missionNamespace getVariable ["FADE_basePos", [0, 0, 0]];
        private _pickPos = [_bpPick, 10, 15] call FADE_mission_findPickupSpawnPos;
        _ok = _pickPos isEqualType [] && { count _pickPos >= 2 } && { (_pickPos distance2D _bpPick) < 500 };
        if (_ok) then { _pass = _pass + 1; diag_log format ["[FAC TestSuite] PASS (server): FADE_mission_findPickupSpawnPos %1", _pickPos select [0, 2]]; } else { _fail = _fail + 1; diag_log "[FAC TestSuite] FAIL (server): FADE_mission_findPickupSpawnPos"; };
    };

    if (!isNil "FADE_pickHvtCodename") then {
        private _cnHvt = [] call FADE_pickHvtCodename;
        _ok = _cnHvt isEqualType "" && { count _cnHvt > 0 } && { _cnHvt == toUpper _cnHvt };
        if (_ok) then { _pass = _pass + 1; diag_log format ["[FAC TestSuite] PASS (server): FADE_pickHvtCodename %1", _cnHvt]; } else { _fail = _fail + 1; diag_log format ["[FAC TestSuite] FAIL (server): FADE_pickHvtCodename (%1)", _cnHvt]; };
    };

    if (!isNil "FADE_pickHostageIdentity") then {
        private _hid = [] call FADE_pickHostageIdentity;
        _ok = _hid isEqualType "" && { _hid != "" };
        if (_ok) then { _pass = _pass + 1; diag_log format ["[FAC TestSuite] PASS (server): FADE_pickHostageIdentity %1", _hid]; } else { _fail = _fail + 1; diag_log format ["[FAC TestSuite] FAIL (server): FADE_pickHostageIdentity (%1)", _hid]; };
    };

    // ----- Mission type registry (GUI labels ↔ runners ↔ slot lists) -----
    diag_log "[FAC TestSuite] --- MISSION REGISTRY ---";
    if ((missionNamespace getVariable ["FAC_missionTypeLabels", []]) isEqualTo []) then {
        call compile preprocessFileLineNumbers "rsc\FAC_MissionTypeLabels.sqf";
    };
    private _labelIds = (missionNamespace getVariable ["FAC_missionTypeLabels", []]) apply { _x select 1 };
    private _slotTypes = (+_gmt) + (+_smt);
    {
        private _mt = _x;
        private _runnerName = format ["FADE_runMission_%1", _mt];
        _ok = !isNil _runnerName && { (missionNamespace getVariable [_runnerName, nil]) isEqualType {} };
        if (_ok) then { _pass = _pass + 1; diag_log format ["[FAC TestSuite] PASS (server): registry runner %1", _mt]; } else { _fail = _fail + 1; diag_log format ["[FAC TestSuite] FAIL (server): registry missing runner %1", _mt]; };
        _ok = _mt in _slotTypes;
        if (_ok) then { _pass = _pass + 1; diag_log format ["[FAC TestSuite] PASS (server): registry slot %1", _mt]; } else { _fail = _fail + 1; diag_log format ["[FAC TestSuite] FAIL (server): registry %1 not in global/single lists", _mt]; };
        _ok = _mt in _labelIds;
        if (_ok) then { _pass = _pass + 1; diag_log format ["[FAC TestSuite] PASS (server): registry label %1", _mt]; } else { _fail = _fail + 1; diag_log format ["[FAC TestSuite] FAIL (server): registry %1 missing FAC_missionTypeLabels entry", _mt]; };
    } forEach FAC_missionTestSuite__missionRunnerTypes;
    {
        private _orphan = _x;
        if !(_orphan in FAC_missionTestSuite__missionRunnerTypes) then {
            _fail = _fail + 1;
            diag_log format ["[FAC TestSuite] FAIL (server): slot type %1 has no FADE_runMission_* runner in test list", _orphan];
        };
    } forEach _slotTypes;

    // ----- Mission placement (mirrors FADE_startMission_pickDestPos / map-click) -----
    diag_log "[FAC TestSuite] --- MISSION PLACEMENT ---";
    ["[FAC TestSuite] Server: placement + intel smoke (may take a few seconds)...", _notifyPlayer] call FAC_missionTestSuite__serverChat;
    private _needsLZTypes = ["TroopInsert", "TroopExtract", "Cargo", "CASEVAC", "CSAR"];
    private _placementSkip = ["EscapeEvasion", "GeoGuesser"];
    private _placementAnchor = [] call FADE_findMissionPos;
    if (count _placementAnchor < 2) then { _placementAnchor = +FADE_basePos };
    {
        private _mt = _x;
        if (_mt in _placementSkip) then {
            diag_log format ["[FAC TestSuite] SKIP (server): placement %1 (special START flow)", _mt];
        } else {
            private _needsLZ = _mt in _needsLZTypes;
            private _minDist = [_mt] call FAC_missionTestSuite__placementMinDist;
            private _dest = [];
            for "_a" from 1 to 25 do {
                private _try = [_mt, _minDist, _needsLZ, [], -1] call FADE_startMission_pickDestPos;
                if (count _try >= 2) exitWith { _dest = _try };
            };
            if (_mt == "InterceptConvoy") then {
                if (!isNil "FADE_interceptConvoyRoadRoute") then {
                    private _routeTry = [{ [FADE_basePos] call FADE_interceptConvoyRoadRoute }] call FAC_missionTestSuite__tryCall;
                    _routeTry params ["_routeOk", "_routeRes"];
                    if (_routeOk && { _routeRes isEqualType [] } && { count _routeRes == 2 }) then {
                        _dest = _routeRes select 0;
                    };
                };
            };
            _ok = count _dest >= 2;
            if (_mt in ["Operation", "Raid", "Invasion"]) then {
                _ok = _ok && { (_dest distance2D FADE_basePos) >= 0 };
            };
            if (_ok) then {
                _pass = _pass + 1;
                diag_log format ["[FAC TestSuite] PASS (server): placement random %1 %2", _mt, _dest select [0, 2]];
            } else {
                _fail = _fail + 1;
                diag_log format ["[FAC TestSuite] FAIL (server): placement random %1 (no valid site after 25 tries)", _mt];
            };
            if (_mt != "InterceptConvoy") then {
                private _pickTry = [{ [_placementAnchor, _mt, _minDist, _needsLZ] call FADE_fnc_pickMissionDestNearMapClick }] call FAC_missionTestSuite__tryCall;
                _pickTry params ["_pickOk", "_pickRes", "_pickErr"];
                if (!_pickOk) then {
                    _fail = _fail + 1;
                    diag_log format ["[FAC TestSuite] FAIL (server): placement map-click %1 script error: %2", _mt, _pickErr];
                } else {
                    _pickRes params ["_pickPos", "_pickR", "_pickSnap"];
                    _ok = _pickPos isEqualType [] && { _pickR isEqualType 0 };
                    if (_ok) then {
                        _pass = _pass + 1;
                        diag_log format ["[FAC TestSuite] PASS (server): placement map-click %1 (resolved=%2)", _mt, if (count _pickPos >= 2) then { "yes" } else { "no site (ok)" }];
                    } else {
                        _fail = _fail + 1;
                        diag_log format ["[FAC TestSuite] FAIL (server): placement map-click %1 bad return %2", _mt, _pickRes];
                    };
                };
            };
        };
    } forEach FAC_missionTestSuite__missionRunnerTypes;

    if (!isNil "FADE_interceptConvoyRoadRoute") then {
        private _convTry = [{ [FADE_basePos] call FADE_interceptConvoyRoadRoute }] call FAC_missionTestSuite__tryCall;
        _convTry params ["_convOk", "_convRes", "_convErr"];
        if (!_convOk) then {
            _fail = _fail + 1;
            diag_log format ["[FAC TestSuite] FAIL (server): FADE_interceptConvoyRoadRoute error: %1", _convErr];
        } else {
            _ok = _convRes isEqualType [] && { count _convRes == 0 || { count _convRes == 2 } };
            if (_ok && { count _convRes == 2 }) then {
                private _wpTry = [{ [_convRes select 0, _convRes select 1, 9] call FADE_interceptConvoyRouteWaypoints }] call FAC_missionTestSuite__tryCall;
                _wpTry params ["_wpOk", "_wpRes", "_wpErr"];
                if (!_wpOk) then {
                    _fail = _fail + 1;
                    diag_log format ["[FAC TestSuite] FAIL (server): FADE_interceptConvoyRouteWaypoints error: %1", _wpErr];
                } else {
                    _ok = _wpRes isEqualType [] && { count _wpRes >= 2 };
                    if (_ok) then { _pass = _pass + 1; diag_log format ["[FAC TestSuite] PASS (server): convoy route + waypoints (%1 pts)", count _wpRes]; }
                    else { _fail = _fail + 1; diag_log "[FAC TestSuite] FAIL (server): FADE_interceptConvoyRouteWaypoints short"; };
                };
            } else {
                if (count _convRes == 0) then {
                    diag_log "[FAC TestSuite] SKIP (server): FADE_interceptConvoyRoadRoute (no random route this map roll)";
                } else {
                    _fail = _fail + 1;
                    diag_log format ["[FAC TestSuite] FAIL (server): FADE_interceptConvoyRoadRoute bad return %1", _convRes];
                };
            };
        };
    };

    // ----- Zone pickers (Operation / Invasion / Raid civ-zone chains) -----
    diag_log "[FAC TestSuite] --- ZONE PICKERS ---";
    private _civZoneEntries = [];
    {
        private _trig = missionNamespace getVariable [_x, objNull];
        if (!isNull _trig) then {
            private _p = getPosATL _trig;
            if (count _p >= 2) then { _civZoneEntries pushBack [_x, _p] };
        };
    } forEach _civNames;
    if (count _civZoneEntries > 0) then {
        private _wantZones = (round (missionNamespace getVariable ["FADE_operationZoneCount", 6])) max 2 min 10;
        if (!isNil "FADE_invasion_pickZones") then {
            private _invTry = [{ [_civZoneEntries, _wantZones, []] call FADE_invasion_pickZones }] call FAC_missionTestSuite__tryCall;
            _invTry params ["_invOk", "_invRes", "_invErr"];
            if (!_invOk) then {
                _fail = _fail + 1;
                diag_log format ["[FAC TestSuite] FAIL (server): FADE_invasion_pickZones error: %1", _invErr];
            } else {
                _ok = _invRes isEqualType [] && { count _invRes >= 1 };
                if (_ok) then { _pass = _pass + 1; diag_log format ["[FAC TestSuite] PASS (server): FADE_invasion_pickZones (%1 zones)", count _invRes]; }
                else { _fail = _fail + 1; diag_log "[FAC TestSuite] FAIL (server): FADE_invasion_pickZones empty"; };
            };
        };
        if (!isNil "FADE_raid_variantFallbacks") then {
            private _vfTry = [{ ["RecoverHostage"] call FADE_raid_variantFallbacks }] call FAC_missionTestSuite__tryCall;
            _vfTry params ["_vfOk", "_vfRes", "_vfErr"];
            if (!_vfOk) then {
                _fail = _fail + 1;
                diag_log format ["[FAC TestSuite] FAIL (server): FADE_raid_variantFallbacks error: %1", _vfErr];
            } else {
                _ok = _vfRes isEqualType [] && { count _vfRes > 0 };
                if (_ok) then { _pass = _pass + 1; diag_log format ["[FAC TestSuite] PASS (server): FADE_raid_variantFallbacks %1", _vfRes]; }
                else { _fail = _fail + 1; diag_log "[FAC TestSuite] FAIL (server): FADE_raid_variantFallbacks empty"; };
            };
        };
    } else {
        diag_log "[FAC TestSuite] SKIP (server): zone picker tests (no civ zone positions)";
    };

    // ----- SMEAC / intel formatters (runtime errors often only show here) -----
    diag_log "[FAC TestSuite] --- SMEAC / INTEL ---";
    private _intelPos = if (count _mpos >= 2) then { +_mpos } else { +FADE_basePos };
    private _sideE = missionNamespace getVariable ["FADE_sideEnemy", east];
    private _sideF = missionNamespace getVariable ["FADE_sideFriendly", west];
    {
        private _mt = _x;
        private _intelTry = [{
            [
                _mt, _intelPos, _sideE, _sideF, 12, 1,
                missionNamespace getVariable ["FADE_scenarioEnemyFaction", "OPF_F"],
                [] call FADE_getSmeacFriendlyLabel,
                2, "123456", "Test Area"
            ] call FADE_formatSituationIntelHtml
        }] call FAC_missionTestSuite__tryCall;
        _intelTry params ["_iOk", "_iRes", "_iErr"];
        if (!_iOk) then {
            _fail = _fail + 1;
            diag_log format ["[FAC TestSuite] FAIL (server): FADE_formatSituationIntelHtml %1: %2", _mt, _iErr];
        } else {
            _ok = _iRes isEqualType "" && { count _iRes > 40 } && { _iRes find "ENEMY" >= 0 || { _mt == "Cargo" } };
            if (_ok) then { _pass = _pass + 1; diag_log format ["[FAC TestSuite] PASS (server): FADE_formatSituationIntelHtml %1", _mt]; }
            else { _fail = _fail + 1; diag_log format ["[FAC TestSuite] FAIL (server): FADE_formatSituationIntelHtml %1 short/malformed", _mt]; };
        };
        if (!isNil "FADE_lore_generate") then {
            private _loreTry = [{ [_mt, FADE_basePos, "Op Test"] call FADE_lore_generate }] call FAC_missionTestSuite__tryCall;
            _loreTry params ["_lOk", "_lRes", "_lErr"];
            if (!_lOk) then {
                _fail = _fail + 1;
                diag_log format ["[FAC TestSuite] FAIL (server): FADE_lore_generate %1: %2", _mt, _lErr];
            } else {
                _ok = _lRes isEqualType [] && { count _lRes >= 3 } && { (_lRes select 0) isEqualType "" };
                if (_ok) then { _pass = _pass + 1; diag_log format ["[FAC TestSuite] PASS (server): FADE_lore_generate %1", _mt]; }
                else { _fail = _fail + 1; diag_log format ["[FAC TestSuite] FAIL (server): FADE_lore_generate %1 bad return", _mt]; };
            };
        };
        if (!isNil "FADE_missionTypeDisplayName") then {
            private _expectedDisp = _mt;
            {
                if ((_x select 1) == _mt) exitWith { _expectedDisp = _x select 0 };
            } forEach (missionNamespace getVariable ["FAC_missionTypeLabels", []]);
            private _disp = [_mt] call FADE_missionTypeDisplayName;
            _ok = _disp isEqualType "" && { _disp isEqualTo _expectedDisp };
            if (_ok) then { _pass = _pass + 1; diag_log format ["[FAC TestSuite] PASS (server): FADE_missionTypeDisplayName %1 -> %2", _mt, _disp]; }
            else { _fail = _fail + 1; diag_log format ["[FAC TestSuite] FAIL (server): FADE_missionTypeDisplayName %1 (%2, expected %3)", _mt, _disp, _expectedDisp]; };
        };
    } forEach FAC_missionTestSuite__missionRunnerTypes;

    if (!isNil "FADE_normPos3") then {
        private _np = [[100, 200]] call FADE_normPos3;
        _ok = _np isEqualType [] && { count _np == 3 };
        if (_ok) then { _pass = _pass + 1; diag_log format ["[FAC TestSuite] PASS (server): FADE_normPos3 %1", _np]; } else { _fail = _fail + 1; diag_log "[FAC TestSuite] FAIL (server): FADE_normPos3"; };
    };

    if (!isNil "FADE_getEnemyDroneVehicleClasses") then {
        private _drones = [] call FADE_getEnemyDroneVehicleClasses;
        _ok = _drones isEqualType [] && { count _drones > 0 };
        if (_ok) then {
            _pass = _pass + 1;
            diag_log format ["[FAC TestSuite] PASS (server): FADE_getEnemyDroneVehicleClasses (%1)", count _drones];
            private _badDrone = _drones findIf { !isClass (configFile >> "CfgVehicles" >> _x) };
            _ok = _badDrone < 0;
            if (_ok) then { _pass = _pass + 1; diag_log "[FAC TestSuite] PASS (server): drone classes valid in CfgVehicles"; }
            else { _fail = _fail + 1; diag_log format ["[FAC TestSuite] FAIL (server): invalid drone class %1", _drones select _badDrone]; };
        } else {
            _fail = _fail + 1;
            diag_log "[FAC TestSuite] FAIL (server): FADE_getEnemyDroneVehicleClasses empty";
        };
    };

    if (!isNil "FADE_recruit_buildFactionList") then {
        private _rflTry = [{ [] call FADE_recruit_buildFactionList }] call FAC_missionTestSuite__tryCall;
        _rflTry params ["_rflOk", "_rflRes", "_rflErr"];
        if (!_rflOk) then {
            _fail = _fail + 1;
            diag_log format ["[FAC TestSuite] FAIL (server): FADE_recruit_buildFactionList error: %1", _rflErr];
        } else {
            _ok = _rflRes isEqualType [] && { count _rflRes > 0 };
            if (_ok) then { _pass = _pass + 1; diag_log format ["[FAC TestSuite] PASS (server): FADE_recruit_buildFactionList (%1)", count _rflRes]; }
            else { _fail = _fail + 1; diag_log "[FAC TestSuite] FAIL (server): FADE_recruit_buildFactionList empty"; };
        };
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
    if (!isNil "FAC_ensureMissionsGui_mapPicks") then { [] call FAC_ensureMissionsGui_mapPicks };
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
        "FAC_ensureMedicalTrainingGui",
        "FAC_ensureRecruitGui"
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
        "FAC_recruitGui_fnc",
        "FAC_recruitGui_onFactionList",
        "FAC_recruitGui_onFactionUnits",
        "FAC_recruitGui_onRoster",
        "FAC_raidMapPick_fnc_start",
        "FAC_convoyMapPick_fnc_start",
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
        "FAC_ensureMedicalTrainingGui",
        "FAC_ensureRecruitGui"
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

    diag_log "[FAC TestSuite] --- CLIENT COMPILE ---";
    private _clientCompileFiles = [
        "rsc\FAC_ClientGuiEnsure.sqf",
        "rsc\MissionsGui.sqf",
        "rsc\ScenarioGui.sqf",
        "rsc\VehicleGui.sqf",
        "rsc\LoadoutGui.sqf",
        "rsc\RecruitGui.sqf",
        "rsc\JukeboxGui.sqf",
        "rsc\CQBGui.sqf",
        "rsc\FiresGui.sqf",
        "rsc\TeleportGui.sqf",
        "rsc\RangeGui.sqf",
        "rsc\SniperGui.sqf",
        "rsc\CivTalkGui.sqf",
        "rsc\MedicalTrainingGui.sqf",
        "rsc\MissionLocationPickGui.sqf",
        "rsc\MissionMapPick.sqf",
        "rsc\MissionMapPick_exec.sqf",
        "rsc\MissionRaidMapPick.sqf",
        "rsc\MissionRaidMapPick_exec.sqf",
        "rsc\MissionConvoyMapPick.sqf",
        "rsc\MissionConvoyMapPick_exec.sqf",
        "rsc\TroopInsertPickGui.sqf",
        "rsc\EscapeEvasionPickGui.sqf",
        "rsc\GeoGuesserPickGui.sqf",
        "rsc\GeoGuesserClient.sqf",
        "rsc\MissionPickOverlay.sqf",
        "rsc\FAC_ClientBoardActions.sqf",
        "rsc\FAC_Theme.sqf",
        "rsc\CutsceneClient.sqf",
        "rsc\ConfigClient.sqf"
    ];
    {
        private _path = _x;
        private _code = compile preprocessFileLineNumbers _path;
        if (isNil "_code" || { typeName _code != "CODE" }) then {
            _fail = _fail + 1;
            diag_log format ["[FAC TestSuite] FAIL (client): compile %1 (not CODE)", _path];
        } else {
            _pass = _pass + 1;
            diag_log format ["[FAC TestSuite] PASS (client): compile %1", _path];
        };
    } forEach _clientCompileFiles;

    private _helis = missionNamespace getVariable ["FADE_heliClasses", []];
    _ok = _helis isEqualType [] && { count _helis > 0 };
    if (_ok) then { _pass = _pass + 1; diag_log format ["[FAC TestSuite] PASS (client): FADE_heliClasses (%1)", count _helis]; } else { _fail = _fail + 1; diag_log "[FAC TestSuite] FAIL (client): FADE_heliClasses"; };

    private _fires = missionNamespace getVariable ["FAC_fires_artilleryDefinitions", []];
    _ok = _fires isEqualType [] && { count _fires > 0 };
    if (_ok) then { _pass = _pass + 1; diag_log format ["[FAC TestSuite] PASS (client): FAC_fires_artilleryDefinitions (%1)", count _fires]; } else { _fail = _fail + 1; diag_log "[FAC TestSuite] FAIL (client): FAC_fires_artilleryDefinitions"; };

    // @CTB - Mission Sounds Library (jukebox OGGs in Sig_CTB_MSL_Music_Loudspeaker.pbo)
    private _ctbSfx = isClass (configFile >> "CfgSFX" >> "Sig_Buttrock_1");
    if (_ctbSfx) then {
        _pass = _pass + 1;
        diag_log "[FAC TestSuite] PASS (client): CTB music mod CfgSFX Sig_Buttrock_1 (configFile)";
    } else {
        _fail = _fail + 1;
        diag_log "[FAC TestSuite] FAIL (client): CTB music mod CfgSFX Sig_Buttrock_1 missing (is @CTB - Mission Sounds Library loaded?)";
    };
    private _ctbOgg = "\Sig_CTB_MSL_Music_Loudspeaker\loudspeaker\bhd_mix.ogg";
    private _ctbFe = fileExists _ctbOgg;
    if (_ctbFe) then {
        _pass = _pass + 1;
        diag_log format ["[FAC TestSuite] PASS (client): CTB music OGG fileExists %1", _ctbOgg];
    } else {
        _fail = _fail + 1;
        diag_log format ["[FAC TestSuite] FAIL (client): CTB music OGG fileExists %1 (mod PBO mounted but path not readable)", _ctbOgg];
    };
    private _jukeSfx = getText (missionConfigFile >> "CfgVehicles" >> "FAC_Jukebox_Sig_Buttrock_1" >> "sound");
    private _jukeChain = (_jukeSfx == "Sig_Buttrock_1") && { isClass (configFile >> "CfgSFX" >> _jukeSfx) };
    if (_jukeChain) then {
        _pass = _pass + 1;
        diag_log "[FAC TestSuite] PASS (client): FAC_Jukebox_Sig_Buttrock_1 sound= -> mod CfgSFX";
    } else {
        _fail = _fail + 1;
        diag_log format ["[FAC TestSuite] FAIL (client): FAC_Jukebox sound chain (got sound=%1; expect Sig_Buttrock_1 + configFile CfgSFX)", _jukeSfx];
    };

    // Range vehicle/AT defs live in Config.sqf (server); RangeGui syncs runtime lists via RPC.
    private _rangeVehicleMap = missionNamespace getVariable ["FADE_rangeVehicleTypeMap", []];
    if (_rangeVehicleMap isEqualType [] && { count _rangeVehicleMap >= 4 }) then {
        _pass = _pass + 1;
        diag_log format ["[FAC TestSuite] PASS (client): FADE_rangeVehicleTypeMap (%1)", count _rangeVehicleMap];
    } else {
        if (isDedicated) then {
            diag_log "[FAC TestSuite] SKIP (client): FADE_rangeVehicleTypeMap (server Config.sqf; RangeGui uses RPC lists)";
        } else {
            _fail = _fail + 1;
            diag_log "[FAC TestSuite] FAIL (client): FADE_rangeVehicleTypeMap";
        };
    };

    private _rangeAtDefs = missionNamespace getVariable ["FADE_rangeAtWeaponDefinitions", []];
    if (_rangeAtDefs isEqualType [] && { count _rangeAtDefs > 0 }) then {
        _pass = _pass + 1;
        diag_log format ["[FAC TestSuite] PASS (client): FADE_rangeAtWeaponDefinitions (%1)", count _rangeAtDefs];
    } else {
        if (isDedicated) then {
            diag_log "[FAC TestSuite] SKIP (client): FADE_rangeAtWeaponDefinitions (server Config.sqf; RangeGui uses RPC lists)";
        } else {
            _fail = _fail + 1;
            diag_log "[FAC TestSuite] FAIL (client): FADE_rangeAtWeaponDefinitions";
        };
    };

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
        "RscDisplayCivTalk",
        "RscDisplayRecruit"
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

    _ok = (missionNamespace getVariable ["FADE_minDistBetweenMissions", -1]) == 2000;
    if (_ok) then { _pass = _pass + 1; diag_log "[FAC TestSuite] PASS (client): FADE_minDistBetweenMissions (ConfigClient)"; } else { _fail = _fail + 1; diag_log "[FAC TestSuite] FAIL (client): FADE_minDistBetweenMissions"; };

    if (!isNil "FADE_mapPick_formatCountdownHint" && { FADE_mapPick_formatCountdownHint isEqualType {} }) then {
        private _initHint = [-1, ["Pick a point on the map."], "", 20] call FADE_mapPick_formatCountdownHint;
        private _tickHint = [15, ["Pick a point on the map."], "", 20] call FADE_mapPick_formatCountdownHint;
        _ok = _initHint find "20 seconds" >= 0 && { _tickHint find "15 s remaining" >= 0 };
        if (_ok) then { _pass = _pass + 1; diag_log "[FAC TestSuite] PASS (client): FADE_mapPick_formatCountdownHint"; } else { _fail = _fail + 1; diag_log format ["[FAC TestSuite] FAIL (client): FADE_mapPick_formatCountdownHint (%1 / %2)", _initHint, _tickHint]; };
    } else {
        _fail = _fail + 1;
        diag_log "[FAC TestSuite] FAIL (client): FADE_mapPick_formatCountdownHint missing";
    };

    if (!isNil "FADE_mapClickPick_parsePos" && { FADE_mapClickPick_parsePos isEqualType {} }) then {
        private _parsed = [[], [12345.6, 23456.7, 12.3], 0, false] call FADE_mapClickPick_parsePos;
        _ok = _parsed isEqualTo [12345.6, 23456.7, 12.3];
        if (_ok) then { _pass = _pass + 1; diag_log "[FAC TestSuite] PASS (client): FADE_mapClickPick_parsePos"; } else { _fail = _fail + 1; diag_log format ["[FAC TestSuite] FAIL (client): FADE_mapClickPick_parsePos (%1)", _parsed]; };
    } else {
        _fail = _fail + 1;
        diag_log "[FAC TestSuite] FAIL (client): FADE_mapClickPick_parsePos missing";
    };

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
        ["FAC_ensureMedicalTrainingGui", "FAC_medicalTrainingGui_fnc"],
        ["FAC_ensureRecruitGui", "FAC_recruitGui_fnc"]
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
