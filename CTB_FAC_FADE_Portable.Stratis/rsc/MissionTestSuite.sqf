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
    "CAS", "HVT", "Hostage", "ClearArea", "PointDefense"
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
        "CASEVAC", "CSAR", "AssetRetrieval", "SearchDestroy", "Operation", "Raid", "Invasion", "EscapeEvasion", "PointDefense"
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
    diag_log format ["[DBG-add34b] hypothesis=%1 location=%2 message=%3 data=%4", _hypothesisId, _location, _message, _data];
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
    "rsc\missions\AOMission.sqf",
    "rsc\missions\AOMissionInfil.sqf",
    "rsc\missions\AOMissionMain.sqf",
    "rsc\missions\AOMissionRunner.sqf",
    "rsc\missions\OperationMission.sqf",
    "rsc\missions\OperationMissionPick.sqf",
    "rsc\missions\OperationMissionMain.sqf",
    "rsc\missions\OperationMissionRunner.sqf",
    "rsc\missions\MissionInvasion.sqf",
    "rsc\missions\MissionInvasionHelpers.sqf",
    "rsc\missions\MissionInvasionMain.sqf",
    "rsc\missions\MissionInvasionRunner.sqf",
    "rsc\missions\TroopInsertMission.sqf",
    "rsc\missions\TroopExtractMission.sqf"
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

    private _mapMinX = missionNamespace getVariable ["FADE_mapMinX", -1];
    private _mapMaxX = missionNamespace getVariable ["FADE_mapMaxX", -1];
    private _mapMinY = missionNamespace getVariable ["FADE_mapMinY", -1];
    private _mapMaxY = missionNamespace getVariable ["FADE_mapMaxY", -1];
    private _mapMin = missionNamespace getVariable ["FADE_mapMin", -1];
    private _mapMax = missionNamespace getVariable ["FADE_mapMax", -1];
    _ok = _mapMaxX > _mapMinX && { _mapMaxY > _mapMinY } && { _mapMinX > -1 } && { _mapMinY > -1 };
    if (_ok) then {
        _pass = _pass + 1;
        diag_log format ["[FAC TestSuite] PASS (server): FADE_map bounds X %1..%2 Y %3..%4 (envelope %5..%6)", _mapMinX, _mapMaxX, _mapMinY, _mapMaxY, _mapMin, _mapMax];
    } else {
        _fail = _fail + 1;
        diag_log "[FAC TestSuite] FAIL (server): FADE_mapMinX/MaxX/MinY/MaxY";
    };
    _ok = _mapMinX == 0 && { _mapMinY == 0 } && { abs (_mapMaxX - worldSize) < 1 } && { abs (_mapMaxY - worldSize) < 1 };
    if (_ok) then {
        _pass = _pass + 1;
        diag_log "[FAC TestSuite] PASS (server): map bounds are 0..worldSize";
    } else {
        _fail = _fail + 1;
        diag_log format ["[FAC TestSuite] FAIL (server): map bounds are 0..worldSize (got %1..%2 / %3..%4, world %5)", _mapMinX, _mapMaxX, _mapMinY, _mapMaxY, worldSize];
    };

    if (!isNil "FADE_basePick_tally") then {
        private _only = [["a", "b"], ["a"]] call FADE_basePick_tally;
        private _tie = [["a", "b"], ["a", "b"]] call FADE_basePick_tally;
        private _none = [[], []] call FADE_basePick_tally;
        private _zero = [["a", "b"], []] call FADE_basePick_tally;
        _ok = _only == "a" && { _tie in ["a", "b"] } && { _none == "" } && { _zero in ["a", "b"] };
        if (_ok) then {
            _pass = _pass + 1;
            diag_log format ["[FAC TestSuite] PASS (server): FADE_basePick_tally only=%1 tie=%2", _only, _tie];
        } else {
            _fail = _fail + 1;
            diag_log format ["[FAC TestSuite] FAIL (server): FADE_basePick_tally only=%1 tie=%2 none=%3 zero=%4", _only, _tie, _none, _zero];
        };
    } else {
        _fail = _fail + 1;
        diag_log "[FAC TestSuite] FAIL (server): FADE_basePick_tally missing";
    };

    if (!isNil "FADE_basePick_rememberChoice") then {
        private _savedChoices = missionNamespace getVariable ["FADE_basePick_choiceList", []];
        ["p1", "Alpha", 1000, 2000] call FADE_basePick_rememberChoice;
        ["p1", "Alpha", 1100, 2100] call FADE_basePick_rememberChoice;
        ["p2", "Bravo", 3000, 4000] call FADE_basePick_rememberChoice;
        private _choiceRows = missionNamespace getVariable ["FADE_basePick_choiceList", []];
        _ok = (count _choiceRows) == 2
            && { (_choiceRows select 0) isEqualTo ["p1", "Alpha", 1100, 2100] }
            && { (_choiceRows select 1) isEqualTo ["p2", "Bravo", 3000, 4000] };
        if (_ok) then {
            _pass = _pass + 1;
            diag_log "[FAC TestSuite] PASS (server): base-pick choice rows";
        } else {
            _fail = _fail + 1;
            diag_log format ["[FAC TestSuite] FAIL (server): base-pick choice rows %1", _choiceRows];
        };
        missionNamespace setVariable ["FADE_basePick_choiceList", _savedChoices, true];
    };

    if (!isNil "FADE_basePick_cardinal") then {
        private _cardN = [[0, 0, 0], [0, 100, 0]] call FADE_basePick_cardinal;
        private _cardE = [[0, 0, 0], [100, 0, 0]] call FADE_basePick_cardinal;
        private _cardS = [[0, 0, 0], [0, -100, 0]] call FADE_basePick_cardinal;
        private _cardW = [[0, 0, 0], [-100, 0, 0]] call FADE_basePick_cardinal;
        private _cardNE = [[0, 0, 0], [100, 100, 0]] call FADE_basePick_cardinal;
        _ok = _cardN == "N" && { _cardE == "E" } && { _cardS == "S" } && { _cardW == "W" } && { _cardNE == "NE" };
        if (_ok) then {
            _pass = _pass + 1;
            diag_log "[FAC TestSuite] PASS (server): base-pick compass";
        } else {
            _fail = _fail + 1;
            diag_log format ["[FAC TestSuite] FAIL (server): base-pick compass N=%1 E=%2 S=%3 W=%4 NE=%5", _cardN, _cardE, _cardS, _cardW, _cardNE];
        };
    };

    if (!isNil "FADE_basePick_placeLine") then {
        private _place = [[worldSize * 0.5, worldSize * 0.5, 0]] call FADE_basePick_placeLine;
        _ok = (_place find "Combat Team Bravo base established at ") == 0 && { (_place find "Deploying you now.") > 0 };
        if (_ok) then {
            _pass = _pass + 1;
            diag_log format ["[FAC TestSuite] PASS (server): base-pick place line %1", _place];
        } else {
            _fail = _fail + 1;
            diag_log format ["[FAC TestSuite] FAIL (server): base-pick place line %1", _place];
        };
    };

    if (!isNil "FADE_basePick_ensureZoneMarker") then {
        private _testName = "FADE_suite_basePick_mkr";
        if (getMarkerColor _testName != "") then { deleteMarker _testName };
        createMarker [_testName, [1, 2, 0]];
        "FADE_suite_basePick_mkr" setMarkerType "mil_dot";
        _ok = getMarkerColor _testName != "" && { (getMarkerPos _testName) distance2D [1, 2] < 1 };
        if (_ok) then {
            _pass = _pass + 1;
            diag_log "[FAC TestSuite] PASS (server): base-pick marker create";
        } else {
            _fail = _fail + 1;
            diag_log "[FAC TestSuite] FAIL (server): base-pick marker create";
        };
        if (getMarkerColor _testName != "") then { deleteMarker _testName };
    };

    if (!isNil "FADE_basePick_rejectReason") then {
        private _dry = [];
        private _wet = [];
        private _i = 0;
        for "_i" from 0 to 40 do {
            private _p = [100 + (_i * ((worldSize - 200) / 40)), worldSize * 0.45, 0];
            private _why = [_p] call FADE_basePick_rejectReason;
            if (_why == "" && { count _dry < 2 }) then { _dry = _p };
            if (_why == "That point is in the water." && { count _wet < 2 }) then { _wet = _p };
        };
        if (count _dry < 2 || { count _wet < 2 }) then {
            diag_log "[FAC TestSuite] SKIP (server): base-pick land/water sample";
        } else {
            // `_pos call fn` with params ["_pos"] keeps only X. The map handler must pass [_pos].
            private _unwrapped = _dry call { params ["_pos"]; _pos };
            _ok = !(_unwrapped isEqualType [])
                && { [_dry] call FADE_basePick_posOk }
                && { !([_wet] call FADE_basePick_posOk) }
                && { ([_wet] call FADE_basePick_rejectReason) == "That point is in the water." };
            if (_ok) then {
                _pass = _pass + 1;
                diag_log format ["[FAC TestSuite] PASS (server): base-pick click accepts land %1 rejects water %2", _dry select [0, 2], _wet select [0, 2]];
            } else {
                _fail = _fail + 1;
                diag_log format ["[FAC TestSuite] FAIL (server): base-pick click land %1 water %2 unwrap %3", _dry, _wet, _unwrapped];
            };
        };
        private _src = preprocessFileLineNumbers "rsc\FAC_BasePick.sqf";
        _ok = (_src find "FAC_basePick_clickPos") >= 0
            && { (_src find "_pos call FAC_basePick_onMapClick") < 0 }
            && { (_src find "BLACK FADED") < 0 }
            && { (_src find "60962") >= 0 }
            && { (_src find "FAC_basePick_showDeploy") >= 0 };
        if (_ok) then {
            _pass = _pass + 1;
            diag_log "[FAC TestSuite] PASS (server): base-pick map click stores _pos";
        } else {
            _fail = _fail + 1;
            diag_log "[FAC TestSuite] FAIL (server): base-pick map click stores _pos";
        };
        private _dlg = preprocessFileLineNumbers "rsc\BasePickDialog.hpp";
        _ok = (_src find "ctrlMapAnimAdd") >= 0
            && { (_src find "voteFocus") >= 0 }
            && { (_dlg find "voteFocus") >= 0 };
        if (_ok) then {
            _pass = _pass + 1;
            diag_log "[FAC TestSuite] PASS (server): base-pick vote row pans the map";
        } else {
            _fail = _fail + 1;
            diag_log "[FAC TestSuite] FAIL (server): base-pick vote row pans the map";
        };
        private _welcome = preprocessFileLineNumbers "initPlayerLocal.sqf";
        private _deployIdx = _src find "FAC_basePick_deployFinished";
        private _blackInIdx = _src find "BLACK IN";
        _ok = _deployIdx > _blackInIdx
            && { _blackInIdx >= 0 }
            && { (_welcome find "FAC_basePick_deployFinished") >= 0 }
            && { (_welcome find "missionNamespace getVariable [""FADE_baseDefined"", false]") < 0 || { (_welcome find "hint parseText _welcomeText") > (_welcome find "FAC_basePick_deployFinished") } };
        if (_ok) then {
            _pass = _pass + 1;
            diag_log "[FAC TestSuite] PASS (server): welcome hint waits until the deploy card closes";
        } else {
            _fail = _fail + 1;
            diag_log "[FAC TestSuite] FAIL (server): welcome hint waits until the deploy card closes";
        };
    };

    private _civT = missionNamespace getVariable ["FADE_civTriggerNames", []];
    _ok = _civT isEqualType [];
    if (_ok) then { _pass = _pass + 1; diag_log format ["[FAC TestSuite] PASS (server): FADE_civTriggerNames (%1 zones)", count _civT]; } else { _fail = _fail + 1; diag_log "[FAC TestSuite] FAIL (server): FADE_civTriggerNames"; };

    // Smaller terrains: a named location is a civ zone only when it is farther than 500 m from HQ.
    if (isNil "FADE_civZoneCutoffDist") then {
        _fail = _fail + 1;
        diag_log "[FAC TestSuite] FAIL (server): FADE_civZoneCutoffDist missing";
    } else {
        private _prevFlat = missionNamespace getVariable ["FADE_civZoneMinDistFromBase", 500];
        missionNamespace setVariable ["FADE_civZoneMinDistFromBase", 500];
        private _stratisCut = [8192] call FADE_civZoneCutoffDist;
        private _altisCut = [30720] call FADE_civZoneCutoffDist;
        private _src = preprocessFileLineNumbers "rsc\FADE_civZonesFromLocations.sqf";
        _ok = _stratisCut isEqualTo 500
            && { _altisCut isEqualTo 2000 }
            && { (_src find "_dist > _cut") >= 0 }
            && { (_src find "_dist >= _cut") < 0 };
        if (_ok) then {
            _pass = _pass + 1;
            diag_log format ["[FAC TestSuite] PASS (server): civ zone HQ cutoff Stratis %1 Altis %2", _stratisCut, _altisCut];
        } else {
            _fail = _fail + 1;
            diag_log format ["[FAC TestSuite] FAIL (server): civ zone HQ cutoff Stratis %1 Altis %2", _stratisCut, _altisCut];
        };
        missionNamespace setVariable ["FADE_civZoneMinDistFromBase", _prevFlat];
    };

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
    _ok = _gmt isEqualType [] && { "PointDefense" in _gmt };
    if (_ok) then { _pass = _pass + 1; diag_log "[FAC TestSuite] PASS (server): FADE_globalMissionTypes contains PointDefense"; } else { _fail = _fail + 1; diag_log "[FAC TestSuite] FAIL (server): FADE_globalMissionTypes / PointDefense"; };
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

    private _indUnits = ["IND_F", 2] call FADE_getUnitsForFaction;
    _ok = "I_soldier_F" in _indUnits;
    if (_ok) then { _pass = _pass + 1; diag_log "[FAC TestSuite] PASS (server): FADE_getUnitsForFaction(IND_F)"; } else { _fail = _fail + 1; diag_log "[FAC TestSuite] FAIL (server): FADE_getUnitsForFaction(IND_F)"; };

    private _missingFaction = ["FADE_NO_SUCH_FACTION", 0] call FADE_getUnitsForFaction;
    _ok = _missingFaction isEqualTo [];
    if (_ok) then { _pass = _pass + 1; diag_log "[FAC TestSuite] PASS (server): empty faction stays empty"; } else { _fail = _fail + 1; diag_log "[FAC TestSuite] FAIL (server): empty faction stays empty"; };

    _ok = ["rhs_faction_usarmy", "rhs_faction_usarmy_wd"] call FADE_factionKeysShareStem
        && { !(["IND_F", "IND_C_F"] call FADE_factionKeysShareStem) }
        && { !(["BLU_F", "BLU_F"] call FADE_factionKeysShareStem) };
    if (_ok) then { _pass = _pass + 1; diag_log "[FAC TestSuite] PASS (server): faction stem match"; } else { _fail = _fail + 1; diag_log "[FAC TestSuite] FAIL (server): faction stem match"; };

    private _choiceRows = missionNamespace getVariable ["FADE_factionChoiceRows", []];
    _ok = _choiceRows isEqualType [] && { { (_x select 0) == "BLU_F" } count _choiceRows > 0 } && { { (_x select 0) == "FADE_NO_SUCH_FACTION" } count _choiceRows == 0 };
    if (_ok) then { _pass = _pass + 1; diag_log format ["[FAC TestSuite] PASS (server): faction choice rows (%1)", count _choiceRows]; } else { _fail = _fail + 1; diag_log "[FAC TestSuite] FAIL (server): faction choice rows"; };

    _ok = (["HandGrenade"] call FADE_magazineOpforGrenadeKind) == "throw"
        && { (["SmokeShell"] call FADE_magazineOpforGrenadeKind) == "" }
        && { (["1Rnd_HE_Grenade_shell"] call FADE_magazineOpforGrenadeKind) == "gl" }
        && { (["1Rnd_Smoke_Grenade_shell"] call FADE_magazineOpforGrenadeKind) == "" }
        && { !(["arifle_MX_GL_F"] call FADE_weaponIsDedicatedGrenadeLauncher) }
        && { !(["launch_RPG32_F"] call FADE_weaponIsDedicatedGrenadeLauncher) };
    if (_ok) then { _pass = _pass + 1; diag_log "[FAC TestSuite] PASS (server): OPFOR grenade kind"; } else { _fail = _fail + 1; diag_log "[FAC TestSuite] FAIL (server): OPFOR grenade kind"; };

    private _scaleWas = missionNamespace getVariable ["FADE_opforPlayerScale", true];
    private _popWas = missionNamespace getVariable ["FADE_opforPopulationScale", 1];
    missionNamespace setVariable ["FADE_opforPlayerScale", true];
    _ok = ([1] call FADE_opforPlayerScaleForCount) == 0.55
        && { ([2] call FADE_opforPlayerScaleForCount) == 0.70 }
        && { ([3] call FADE_opforPlayerScaleForCount) == 0.85 }
        && { ([6] call FADE_opforPlayerScaleForCount) == 1 }
        && { ([10] call FADE_opforPlayerScaleForCount) == 1.15 }
        && { ([14] call FADE_opforPlayerScaleForCount) == 1.25 };
    missionNamespace setVariable ["FADE_opforPlayerScale", false];
    _ok = _ok && { ([1] call FADE_opforPlayerScaleForCount) == 1 };
    missionNamespace setVariable ["FADE_opforPopulationScale", 1];
    private _scaleOff = [10, 8] call FADE_scaleOpforCount;
    private _savedPlayerFactor = FADE_opforPlayerScaleFactor;
    FADE_opforPlayerScaleFactor = { 0.55 };
    missionNamespace setVariable ["FADE_opforPlayerScale", true];
    private _scaleShrunk = [8, 8] call FADE_scaleOpforCount;
    FADE_opforPlayerScaleFactor = _savedPlayerFactor;
    missionNamespace setVariable ["FADE_opforPlayerScale", _scaleWas];
    missionNamespace setVariable ["FADE_opforPopulationScale", _popWas];
    _ok = _ok && { _scaleOff == 10 } && { _scaleShrunk == 5 };
    if (_ok) then { _pass = _pass + 1; diag_log "[FAC TestSuite] PASS (server): OPFOR player scale"; } else { _fail = _fail + 1; diag_log format ["[FAC TestSuite] FAIL (server): OPFOR player scale off=%1 shrunk=%2", _scaleOff, _scaleShrunk]; };

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

    _ok = !isNil "FADE_parkedOpfor_classOk" && { !isNil "FADE_parkedOpfor_spawnAt" };
    if (_ok) then {
        private _truckOk = ["O_Truck_02_transport_F"] call FADE_parkedOpfor_classOk;
        private _jeepOk = ["O_G_Offroad_01_F"] call FADE_parkedOpfor_classOk;
        private _apcOk = ["O_APC_Wheeled_02_rcws_v2_F"] call FADE_parkedOpfor_classOk;
        private _mrapOk = ["O_MRAP_02_F"] call FADE_parkedOpfor_classOk;
        private _armedOk = ["O_G_Offroad_01_armed_F"] call FADE_parkedOpfor_classOk;
        _ok = _truckOk && { _jeepOk } && { !_apcOk } && { !_mrapOk } && { !_armedOk };
    };
    if (_ok) then { _pass = _pass + 1; diag_log "[FAC TestSuite] PASS (server): parked OPFOR transport filter"; } else { _fail = _fail + 1; diag_log "[FAC TestSuite] FAIL (server): parked OPFOR transport filter"; };

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
        "FADE_spawnVehicleAtPos",
        "FADE_pylon_applyLocal",
        "FADE_despawnVehicle",
        "FADE_serviceVehicle",
        "FADE_serviceVehiclePart",
        "FADE_requestVehiclesAtBase",
        "FADE_setTime",
        "FADE_setWeather",
        "FADE_requestCopilotState",
        "FADE_spawnCopilot",
        "FADE_removeCopilot",
        "FADE_startMission",
        "FADE_startEscapeEvasion",
        "FADE_startGeoGuesser",
        "FADE_startPointDefense",
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
        "FADE_civCarRadio_serverPlay",
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
        "FADE_recruit_dismissUnits",
        "FADE_build_place",
        "FADE_build_remove",
        "FADE_build_undo",
        "FADE_build_sendList",
        "FADE_build_signSet",
        "FADE_build_setCatalog"
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
        "rsc\TeleportGui.sqf",
        "rsc\TeleportMapPick.sqf",
        "rsc\server\ServerGameplayCqb.sqf",
        "rsc\server\ServerGameplayCore.sqf",
        "rsc\server\ServerGameplayVehicles.sqf",
        "rsc\FADE_PylonApply.sqf",
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
        "rsc\PointDefensePickGui.sqf",
        "rsc\missions\MissionPointDefense.sqf",
        "rsc\ConfigDefaults.sqf",
        "rsc\EnemyAAA.sqf",
        "rsc\RoadblockCommon.sqf",
        "rsc\MissionRoadblocks.sqf",
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
        "rsc\server\ServerBootstrapOpforDrones.sqf",
        "rsc\FADE_VirtualGarrison.sqf",
        "rsc\AmbientCivilians.sqf",
        "rsc\BaseNpcTalk.sqf",
        "rsc\CutsceneServer.sqf",
        "rsc\server\ServerGameplayRecruit.sqf",
        "rsc\server\ServerGameplayBuild.sqf",
        "rsc\BuildCatalog.sqf",
        "rsc\BuildCommon.sqf",
        "rsc\BuildGui.sqf",
        "rsc\BuildSignGui.sqf",
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
        "FADE_startEscapeEvasion", "FADE_startGeoGuesser", "FADE_startPointDefense", "FADE_geoGuesser_submitGuess", "FADE_geoGuesser_computeScore",
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
        private _wetProbe = [];
        private _wetTry = [0, 0, 0];
        private _wetI = 0;
        for "_wetI" from 0 to 16 do {
            if (count _wetProbe < 2) then {
                _wetTry = [200 + (_wetI * 400), 200, 0];
                if !([_wetTry] call FADE_surfaceIsDry) then { _wetProbe = _wetTry };
            };
        };
        if (count _wetProbe < 2 || { isNil "FADE_posClearOfWater" }) then {
            diag_log "[FAC TestSuite] SKIP (server): FADE_posClearOfWater (no wet point)";
        } else {
            _ok = !([_wetProbe, 15] call FADE_posClearOfWater);
            if (_ok) then { _pass = _pass + 1; diag_log "[FAC TestSuite] PASS (server): FADE_posClearOfWater rejects sea"; } else { _fail = _fail + 1; diag_log "[FAC TestSuite] FAIL (server): FADE_posClearOfWater rejects sea"; };
        };
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
        private _raidSmeac = _loreRaid select 2;
        _ok = false;
        {
            if (_raidSmeac find _x >= 0) exitWith { _ok = true };
        } forEach [
            "seized several sites",
            "split its force between nearby towns",
            "fortified several towns",
            "is active near"
        ];
        if (_ok) then { _pass = _pass + 1; diag_log "[FAC TestSuite] PASS (server): FADE_lore_generate enemy lore line"; } else { _fail = _fail + 1; diag_log format ["[FAC TestSuite] FAIL (server): FADE_lore_generate enemy lore line: %1", _raidSmeac select [0, 240]]; };
        private _lore2 = ["HVT", FADE_basePos, "Operation Test"] call FADE_lore_generate;
        _ok = _lore isEqualTo _lore2;
        if (_ok) then { _pass = _pass + 1; diag_log "[FAC TestSuite] PASS (server): FADE_lore_generate seeded"; } else { _fail = _fail + 1; diag_log "[FAC TestSuite] FAIL (server): FADE_lore_generate seeded"; };
        private _loreCargo = ["Cargo", FADE_basePos, "Supply Run"] call FADE_lore_generate;
        _ok = (_loreCargo select 1) find "eliminate the threat" < 0;
        if (_ok) then { _pass = _pass + 1; diag_log "[FAC TestSuite] PASS (server): FADE_lore_generate Cargo tone"; } else { _fail = _fail + 1; diag_log "[FAC TestSuite] FAIL (server): FADE_lore_generate Cargo tone"; };
        private _lorePd = ["PointDefense", FADE_basePos, "Operation Test"] call FADE_lore_generate;
        private _pdJoined = toLower ((_lorePd select 0) + " " + (_lorePd select 1) + " " + (_lorePd select 2));
        _ok = (_pdJoined find "hold" >= 0) || { _pdJoined find "defend" >= 0 } || { _pdJoined find "point" >= 0 };
        if (_ok) then { _pass = _pass + 1; diag_log "[FAC TestSuite] PASS (server): FADE_lore_generate PointDefense tone"; } else { _fail = _fail + 1; diag_log "[FAC TestSuite] FAIL (server): FADE_lore_generate PointDefense tone"; };
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
        "FADE_objective_isSettlementBuilding", "FADE_objective_pickBestBuilding",
        "FADE_raid_applyScale", "FADE_objective_spawnRecoverObject", "FADE_objective_registerNearbyGarrisons", "FADE_raid_startIntelMonitor",
        "FADE_objective_findBuildingsWithMinSlots", "FADE_objective_addHostageToGroup", "FADE_objective_garrisonBuildingSlots",
        "FADE_objective_spawnPatrolsPerBuilding", "FADE_objective_spawnHostageInBuilding", "FADE_pickHostageIdentity",
        "FADE_hostage_playReturnCue"
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
        "FADE_comp_spawn", "FADE_comp_siteOk", "FADE_comp_findAnchor", "FADE_comp_pieceCount",
        "FADE_mission_findPickupSpawnPos", "FADE_mission_spawnFriendlyPickupGroup", "FADE_mission_spawnCasualtyHeliWreck", "FADE_mission_groundAtlPos",
        "FADE_mission_applyPickupGroupPosture", "FADE_mission_casevacCasualtyPrep", "FADE_mission_csarPilotWoundPrep",
        "FADE_zone_createCaptureMarkerPair", "FADE_zone_tickOperationCapture", "FADE_zone_tickInvasionHold",
        "FADE_runMission_PointDefense", "FADE_pd_findAdjacentCivZonePos", "FADE_pd_pickInfSpawnPos", "FADE_pd_spawnInfWave", "FADE_pd_spawnVehWave",
        "FADE_troopMission_liveParticipants", "FADE_troopMission_runTransportWave", "FADE_troopMission_clearParticipantMissionVars",
        "FADE_pickHvtCodename", "FADE_getIdentityDisplayName", "FADE_objective_findBuildingForMission",
        "FADE_marker_getType", "FADE_map_gridCellsForSearchZone", "FADE_map_gridCellOrigin",
        "FADE_map_gridBoundsForSearchZone",
        "FADE_aoSurvey_build", "FADE_fieldIntel_startForMission", "FADE_fieldIntel_endMission", "FADE_fieldIntel_endRaidZones",
        "FADE_map_gridOriginOffset"
    ];

    if (!isNil "FADE_comp_defs" && { !isNil "FADE_comp_ids" }) then {
        _ok = (count FADE_comp_ids) == 3 && { FADE_comp_ids isEqualTo ["camp", "mortarPit", "commsRelay"] };
        if (_ok) then { _pass = _pass + 1; diag_log "[FAC TestSuite] PASS (server): FADE_comp_ids"; } else { _fail = _fail + 1; diag_log format ["[FAC TestSuite] FAIL (server): FADE_comp_ids %1", FADE_comp_ids]; };
        private _campPieces = ((FADE_comp_defs getOrDefault ["camp", []]) param [1, []]);
        private _campTents = { (_x select 0) in ["Land_TentA_F", "Land_TentDome_F"] } count _campPieces;
        _ok = _campTents == 3;
        if (_ok) then { _pass = _pass + 1; diag_log "[FAC TestSuite] PASS (server): camp composition has 3 tents"; } else { _fail = _fail + 1; diag_log format ["[FAC TestSuite] FAIL (server): camp composition tents %1", _campTents]; };
        private _mortarPieces = ((FADE_comp_defs getOrDefault ["mortarPit", []]) param [1, []]);
        _ok = ({ (_x select 0) find "Mortar" >= 0 } count _mortarPieces) == 0 && { count _mortarPieces >= 5 };
        if (_ok) then { _pass = _pass + 1; diag_log "[FAC TestSuite] PASS (server): mortar pit is scenery"; } else { _fail = _fail + 1; diag_log "[FAC TestSuite] FAIL (server): mortar pit is scenery"; };
        private _commsPieces = ((FADE_comp_defs getOrDefault ["commsRelay", []]) param [1, []]);
        _ok = ({ (_x select 0) == "Land_Communication_F" } count _commsPieces) == 1;
        if (_ok) then { _pass = _pass + 1; diag_log "[FAC TestSuite] PASS (server): comms relay has a mast"; } else { _fail = _fail + 1; diag_log "[FAC TestSuite] FAIL (server): comms relay has a mast"; };
        _ok = (["no-such-comp", [0, 0, 0], ""] call FADE_comp_spawn) isEqualTo [];
        if (_ok) then { _pass = _pass + 1; diag_log "[FAC TestSuite] PASS (server): FADE_comp_spawn unknown id"; } else { _fail = _fail + 1; diag_log "[FAC TestSuite] FAIL (server): FADE_comp_spawn unknown id"; };

        private _compOrigin = missionNamespace getVariable ["FADE_basePos", [15000, 15000, 0]];
        if (!(_compOrigin isEqualType []) || { count _compOrigin < 2 }) then { _compOrigin = [15000, 15000, 0] };
        private _compAnchor = [];
        private _compProbe = [0, 0, 0];
        private _compI = 0;
        for "_compI" from 0 to 24 do {
            if (count _compAnchor < 2) then {
                _compProbe = [
                    (_compOrigin select 0) + ((200 + (_compI * 80)) * (cos (_compI * 36))),
                    (_compOrigin select 1) + ((200 + (_compI * 80)) * (sin (_compI * 36))),
                    0
                ];
                _compAnchor = [_compProbe, 12] call FADE_comp_findAnchor;
            };
        };
        if (count _compAnchor < 2) then {
            diag_log "[FAC TestSuite] SKIP (server): composition spawn (no flat site near base)";
        } else {
            private _compId = "";
            private _compTid = "";
            private _compObjs = [];
            private _compPlaced = _compAnchor;
            private _compRadius = 0;
            private _compFar = false;
            private _compReg = [];
            private _compFires = 0;
            private _compTentN = 0;
            private _compMasts = 0;
            private _compStill = [];
            {
                _compId = _x;
                _compTid = "FADE_test_comp_" + _compId;
                _compObjs = [_compId, _compAnchor, _compTid, 0] call FADE_comp_spawn;
                _compRadius = ((FADE_comp_defs get _compId) select 0);
                _ok = (count _compObjs) == ([_compId] call FADE_comp_pieceCount) && { count _compObjs > 0 };
                if (_ok && { count _compObjs > 0 }) then {
                    _compPlaced = (_compObjs select 0) getVariable ["FADE_comp_anchor", _compAnchor];
                    _compFar = false;
                    {
                        if ((_x distance2D _compPlaced) > (_compRadius + 1)) then { _compFar = true };
                    } forEach _compObjs;
                    _ok = !_compFar;
                };
                if (_ok && { _compId == "camp" }) then {
                    _compFires = { typeOf _x == "Campfire_burning_F" && { (_x distance2D _compPlaced) < 1.5 } } count _compObjs;
                    _compTentN = { typeOf _x in ["Land_TentA_F", "Land_TentDome_F"] } count _compObjs;
                    _ok = _compFires == 1 && { _compTentN == 3 };
                };
                if (_ok && { _compId == "commsRelay" }) then {
                    _compMasts = { typeOf _x == "Land_Communication_F" && { (_x distance2D _compPlaced) < 1.5 } } count _compObjs;
                    _ok = _compMasts == 1;
                };
                _compReg = (missionNamespace getVariable [format ["FADE_missionEnt_%1", _compTid], createHashMap]) getOrDefault ["objects", []];
                if (_ok) then { _ok = count _compReg == count _compObjs };
                if (_ok) then { _pass = _pass + 1; diag_log format ["[FAC TestSuite] PASS (server): FADE_comp_spawn %1 (%2)", _compId, count _compObjs]; } else { _fail = _fail + 1; diag_log format ["[FAC TestSuite] FAIL (server): FADE_comp_spawn %1 count=%2 reg=%3", _compId, count _compObjs, count _compReg]; };
                [_compTid, "", false] call FADE_cleanupMissionEntities;
                if (canSuspend) then { sleep 0.1 };
                _compStill = nearestObjects [_compPlaced, ["All"], _compRadius + 2] select {
                    (_x getVariable ["FADE_comp_id", ""]) == _compId
                };
                _ok = (count _compStill) == 0 && { missionNamespace getVariable [format ["FADE_missionEnt_cleaned_%1", _compTid], false] };
                if (_ok) then { _pass = _pass + 1; diag_log format ["[FAC TestSuite] PASS (server): composition cleanup %1", _compId]; } else {
                    private _compTypes = [];
                    { if ((count _compTypes) < 4) then { _compTypes pushBack (typeOf _x) } } forEach _compStill;
                    _fail = _fail + 1;
                    diag_log format ["[FAC TestSuite] FAIL (server): composition cleanup %1 still=%2 types=%3", _compId, count _compStill, _compTypes];
                };
            } forEach FADE_comp_ids;
        };

        private _compWet = [];
        private _compWetTry = [0, 0, 0];
        private _compW = 0;
        for "_compW" from 0 to 12 do {
            if (count _compWet < 2) then {
                _compWetTry = [400 + (_compW * 350), 400, 0];
                if !([_compWetTry] call FADE_surfaceIsDry) then { _compWet = _compWetTry };
            };
        };
        if (count _compWet < 2) then {
            diag_log "[FAC TestSuite] SKIP (server): composition water reject (no wet point)";
        } else {
            _ok = !([_compWet, 12] call FADE_comp_siteOk);
            private _compWetObjs = ["camp", _compWet, "FADE_test_comp_wet", 0] call FADE_comp_spawn;
            _ok = _ok && { count _compWetObjs == 0 };
            if (_ok) then { _pass = _pass + 1; diag_log "[FAC TestSuite] PASS (server): composition rejects water"; } else { _fail = _fail + 1; diag_log format ["[FAC TestSuite] FAIL (server): composition rejects water spawned=%1", count _compWetObjs]; };
            if (count _compWetObjs > 0) then { ["FADE_test_comp_wet", "", false] call FADE_cleanupMissionEntities };
        };
    };

    diag_log "[FAC TestSuite] --- MARKERS / GRID / FIELD INTEL ---";

    if (!isNil "FADE_marker_getType") then {
        _ok = (["objective"] call FADE_marker_getType) == "mil_objective" && { (["flag"] call FADE_marker_getType) == "mil_flag" };
        if (_ok) then { _pass = _pass + 1; diag_log "[FAC TestSuite] PASS (server): FADE_marker_getType"; } else { _fail = _fail + 1; diag_log "[FAC TestSuite] FAIL (server): FADE_marker_getType"; };
    };

    if (!isNil "FADE_map_gridCellsForSearchZone") then {
        private _testCenter = [(FADE_basePos select 0) + 500, (FADE_basePos select 1) + 500, 0];
        private _truePos = [(_testCenter select 0) + 120, (_testCenter select 1) - 80, 0];
        private _cells = [_testCenter, 200, [_truePos]] call FADE_map_gridCellsForSearchZone;
        _ok = _cells isEqualType [] && { count _cells >= 1 };
        if (_ok) then { _pass = _pass + 1; diag_log format ["[FAC TestSuite] PASS (server): FADE_map_gridCellsForSearchZone (%1 cells)", count _cells]; } else { _fail = _fail + 1; diag_log "[FAC TestSuite] FAIL (server): FADE_map_gridCellsForSearchZone"; };
        private _off = [] call FADE_map_gridOriginOffset;
        private _origin = [_testCenter] call FADE_map_gridCellOrigin;
        private _originX = _origin select 0;
        private _expectedX = (_off select 0) + ((floor (((_testCenter select 0) - (_off select 0)) / 100)) * 100);
        _ok = _originX == _expectedX;
        if (_ok) then { _pass = _pass + 1; diag_log format ["[FAC TestSuite] PASS (server): FADE_map_gridCellOrigin Altis offset %1", _origin]; } else { _fail = _fail + 1; diag_log format ["[FAC TestSuite] FAIL (server): FADE_map_gridCellOrigin Altis offset %1", _origin]; };
    };

    if (!isNil "FADE_map_gridBoundsForSearchZone") then {
        private _bounds = [FADE_basePos, 125, [FADE_basePos]] call FADE_map_gridBoundsForSearchZone;
        _bounds params ["_bCentre", "_bHalf", "_bCells"];
        _ok = _bCells >= 1 && { (_bHalf select 0) >= 50 } && { (_bHalf select 1) >= 50 } && { (_bHalf select 0) mod 50 == 0 } && { (_bHalf select 1) mod 50 == 0 };
        if (_ok) then { _pass = _pass + 1; diag_log format ["[FAC TestSuite] PASS (server): FADE_map_gridBoundsForSearchZone %1 cells half=%2", _bCells, _bHalf]; } else { _fail = _fail + 1; diag_log format ["[FAC TestSuite] FAIL (server): FADE_map_gridBoundsForSearchZone %1", _bounds]; };
    };

    if (!isNil "FADE_mission_computeSearchZone") then {
        private _anchor = [12000, 15000, 0];
        private _truePos = [12080, 14920, 0];
        private _nominal = 180;
        private _computed = [_anchor, _nominal, 0, [_truePos]] call FADE_mission_computeSearchZone;
        _computed params ["_mPos", "_mRad"];
        _ok = (_truePos distance2D _mPos) <= (_mRad + 1);
        if (_ok) then { _pass = _pass + 1; diag_log format ["[FAC TestSuite] PASS (server): FADE_mission_computeSearchZone contains true pos (r=%1)", _mRad]; } else { _fail = _fail + 1; diag_log format ["[FAC TestSuite] FAIL (server): FADE_mission_computeSearchZone contains true pos dist=%1 rad=%2", _truePos distance2D _mPos, _mRad]; };
        private _shrinkNom = (_nominal * 0.25) max 45;
        private _shrunk = [_anchor, _shrinkNom, 0, [_truePos]] call FADE_mission_computeSearchZone;
        _shrunk params ["_sPos", "_sRad"];
        _ok = (_truePos distance2D _sPos) <= (_sRad + 1);
        if (_ok) then { _pass = _pass + 1; diag_log format ["[FAC TestSuite] PASS (server): FADE_mission_computeSearchZone shrink contains true pos (r=%1)", _sRad]; } else { _fail = _fail + 1; diag_log format ["[FAC TestSuite] FAIL (server): FADE_mission_computeSearchZone shrink contains true pos dist=%1 rad=%2", _truePos distance2D _sPos, _sRad]; };
    };

    if (!isNil "FADE_missionRoadblocks_spawnAround" && { !isNil "FADE_missionRoadblocks_despawnForTask" }) then {
        private _mrbTask = "FADE_test_missionRoadblock";
        private _mrbBase = FADE_basePos;
        if (_mrbBase isEqualType objNull) then { _mrbBase = getPosATL _mrbBase };
        _mrbBase = [_mrbBase] call FADE_normPos3;
        private _mrbRoads = _mrbBase nearRoads 2000;
        private _mrbAnchor = [];
        {
            private _rp = getPosATL _x;
            if (count _rp >= 2 && { (_rp distance2D _mrbBase) > 900 }) exitWith { _mrbAnchor = [(_rp select 0), (_rp select 1), 0] };
        } forEach _mrbRoads;
        if (count _mrbAnchor < 2) then {
            _pass = _pass + 1;
            diag_log "[FAC TestSuite] PASS (server): mission roadblock (no road 900m+ from base to sample)";
        } else {
            private _mrbPatrols = missionNamespace getVariable ["FADE_scenarioPatrols", true];
            missionNamespace setVariable ["FADE_scenarioPatrols", false];
            private _mrbN = [_mrbTask, _mrbAnchor, _mrbBase] call FADE_missionRoadblocks_spawnAround;
            private _mrbAgain = [_mrbTask, _mrbAnchor, _mrbBase] call FADE_missionRoadblocks_spawnAround;
            missionNamespace setVariable ["FADE_scenarioPatrols", _mrbPatrols];
            private _mrbSt = missionNamespace getVariable ["FADE_missionRoadblockState", createHashMap];
            private _mrbSeen = 0;
            private _mrbOnRoad = true;
            private _mrbInRing = true;
            {
                private _e = _mrbSt get _x;
                if (_e isEqualType [] && { count _e >= 3 } && { (_e select 2) == _mrbTask }) then {
                    _mrbSeen = _mrbSeen + 1;
                    private _p = _e select 0;
                    if ((count (_p nearRoads 25)) == 0) then { _mrbOnRoad = false };
                    private _dObj = _p distance2D _mrbAnchor;
                    if (_dObj < 80 || { _dObj > 350 }) then { _mrbInRing = false };
                };
            } forEach (keys _mrbSt);
            _ok = _mrbN == _mrbSeen && { _mrbN <= 4 } && { _mrbAgain == 0 } && { _mrbOnRoad } && { _mrbInRing };
            if (_ok) then { _pass = _pass + 1; diag_log format ["[FAC TestSuite] PASS (server): mission roadblock spokes=%1", _mrbN]; } else { _fail = _fail + 1; diag_log format ["[FAC TestSuite] FAIL (server): mission roadblock n=%1 seen=%2 again=%3 onRoad=%4 ring=%5", _mrbN, _mrbSeen, _mrbAgain, _mrbOnRoad, _mrbInRing]; };
            [_mrbTask] call FADE_missionRoadblocks_despawnForTask;
            missionNamespace setVariable [format ["FADE_missionEnt_%1", _mrbTask], nil];
            missionNamespace setVariable [format ["FADE_missionEnt_cleaned_%1", _mrbTask], nil];
        };
    };

    if (!isNil "FADE_aoSurvey_build") then {
        private _survey = [FADE_basePos, 400] call FADE_aoSurvey_build;
        _ok = _survey isEqualType createHashMap && { _survey getOrDefault ["center", []] isEqualType [] } && { (_survey getOrDefault ["roadsNear", []]) isEqualType [] };
        if (_ok) then { _pass = _pass + 1; diag_log "[FAC TestSuite] PASS (server): FADE_aoSurvey_build"; } else { _fail = _fail + 1; diag_log "[FAC TestSuite] FAIL (server): FADE_aoSurvey_build"; };
    };

    if (!isNil "FADE_fieldIntel_applyGeometry" && { !isNil "FADE_fieldIntel_addPoints" }) then {
        private _fiTask = "FADE_test_fieldIntel";
        private _fiA = [13000, 16000, 0];
        private _fiB = [13160, 16000, 0];
        private _fiAnchor = [13080, 16000, 0];
        private _fiZone = "FADE_test_fieldIntel_grid";
        private _fiState = [
            _fiTask, "Hostage", _fiAnchor, _fiAnchor, [_fiA, _fiB],
            "grid", "", _fiZone, [], 200,
            0, 0, "ColorEAST", _fiTask,
            objNull, _fiAnchor, [200, 200]
        ];
        missionNamespace setVariable ["FADE_fieldIntel_" + _fiTask, _fiState];
        private _fiInside = {
            params ["_p"];
            private _c = getMarkerPos _fiZone;
            private _hs = getMarkerSize _fiZone;
            (markerShape _fiZone == "RECTANGLE")
            && { abs ((_p select 0) - (_c select 0)) <= ((_hs select 0) + 1) }
            && { abs ((_p select 1) - (_c select 1)) <= ((_hs select 1) + 1) }
        };
        [_fiTask, 18, "Body search"] call FADE_fieldIntel_addPoints;
        _ok = getMarkerColor _fiZone == "";
        if (_ok) then { _pass = _pass + 1; diag_log "[FAC TestSuite] PASS (server): field intel below 25 does not redraw"; } else { _fail = _fail + 1; diag_log "[FAC TestSuite] FAIL (server): field intel below 25 redrew the zone"; };
        [_fiTask, 12, "Body search"] call FADE_fieldIntel_addPoints;
        _ok = ([_fiA] call _fiInside) && { [_fiB] call _fiInside };
        if (_ok) then { _pass = _pass + 1; diag_log "[FAC TestSuite] PASS (server): field intel 30pt grid contains both objectives"; } else { _fail = _fail + 1; diag_log format ["[FAC TestSuite] FAIL (server): field intel 30pt grid missed an objective shape=%1 pos=%2 size=%3", markerShape _fiZone, getMarkerPos _fiZone, getMarkerSize _fiZone]; };
        [_fiTask, 70, "Body search"] call FADE_fieldIntel_addPoints;
        _ok = ([_fiA] call _fiInside) && { [_fiB] call _fiInside };
        if (_ok) then { _pass = _pass + 1; diag_log "[FAC TestSuite] PASS (server): field intel 100pt grid contains both objectives"; } else { _fail = _fail + 1; diag_log format ["[FAC TestSuite] FAIL (server): field intel 100pt grid missed an objective shape=%1 pos=%2 size=%3", markerShape _fiZone, getMarkerPos _fiZone, getMarkerSize _fiZone]; };
        [_fiTask] call FADE_fieldIntel_endMission;
        private _fiPartial = [[_fiA, _fiB], false, 2] call FADE_fieldIntel_diaryBody;
        private _fiGridA = mapGridPosition _fiA;
        _ok = (_fiPartial find "grid") < 0 && { (_fiPartial find _fiGridA) < 0 };
        if (_ok) then { _pass = _pass + 1; diag_log "[FAC TestSuite] PASS (server): field intel partial diary has no grid"; } else { _fail = _fail + 1; diag_log format ["[FAC TestSuite] FAIL (server): field intel partial diary leaked a grid: %1", _fiPartial]; };
        private _fiFull = [[_fiA, _fiB], true, 2] call FADE_fieldIntel_diaryBody;
        _ok = (_fiFull find _fiGridA) >= 0 && { (_fiFull find (mapGridPosition _fiB)) >= 0 };
        if (_ok) then { _pass = _pass + 1; diag_log "[FAC TestSuite] PASS (server): field intel confirmed diary lists objective grids"; } else { _fail = _fail + 1; diag_log format ["[FAC TestSuite] FAIL (server): field intel confirmed diary: %1", _fiFull]; };
        private _fiHint = [25, 2] call FADE_fieldIntel_hintText;
        private _fiHintFull = [100, 2] call FADE_fieldIntel_hintText;
        _ok = (_fiHint find "grid") < 0 && { (_fiHint find "objectives") >= 0 } && { (_fiHintFull find "refined") < 0 } && { (_fiHintFull find "objectives") >= 0 };
        if (_ok) then { _pass = _pass + 1; diag_log "[FAC TestSuite] PASS (server): field intel hints name the objectives and omit the grid"; } else { _fail = _fail + 1; diag_log format ["[FAC TestSuite] FAIL (server): field intel hints partial=%1 full=%2", _fiHint, _fiHintFull]; };
    };

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
        _ok = !("rsc\missions\MissionTroopExtract.sqf" in FADE_missionModuleList);
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

    diag_log "[FAC TestSuite] --- FACTION SCENARIO ---";
    if (!isNil "FADE_normalizeScenarioFactions") then {
        private _normRu = ["OPF_F", "OPF_F"] call FADE_normalizeScenarioFactions;
        _ok = (_normRu select 0) == "OPF_F" && { (_normRu select 1) != "OPF_F" } && { "same_faction" in (_normRu select 2) };
        if (_ok) then {
            _pass = _pass + 1;
            diag_log format ["[FAC TestSuite] PASS (server): normalize corrects same faction (%1 vs %2)", _normRu select 0, _normRu select 1];
        } else {
            _fail = _fail + 1;
            diag_log format ["[FAC TestSuite] FAIL (server): normalize same faction %1", _normRu];
        };
        private _oppEast = [0] call FADE_getOpposedSideNums;
        _ok = 1 in _oppEast && { 2 in _oppEast } && { !(0 in _oppEast) };
        if (_ok) then {
            _pass = _pass + 1;
            diag_log format ["[FAC TestSuite] PASS (server): EAST opposed sides %1", _oppEast];
        } else {
            _fail = _fail + 1;
            diag_log format ["[FAC TestSuite] FAIL (server): EAST opposed sides %1", _oppEast];
        };
        private _oppGuer = [2] call FADE_getOpposedSideNums;
        _ok = 0 in _oppGuer && { 1 in _oppGuer } && { !(2 in _oppGuer) };
        if (_ok) then {
            _pass = _pass + 1;
            diag_log "[FAC TestSuite] PASS (server): GUER opposed to EAST and WEST only";
        } else {
            _fail = _fail + 1;
            diag_log format ["[FAC TestSuite] FAIL (server): GUER opposed sides %1", _oppGuer];
        };
        _ok = (["CIV_F", "BLU_F"] call FADE_scenarioFactionsDescribeIssue) in ["friendly_not_playable", "civ_friendly"];
        if (_ok) then {
            _pass = _pass + 1;
            diag_log "[FAC TestSuite] PASS (server): CIV rejected as friendly faction";
        } else {
            _fail = _fail + 1;
            diag_log "[FAC TestSuite] FAIL (server): CIV friendly rejection";
        };
        _ok = ["BLU_F", "OPF_F"] call FADE_scenarioFactionsDescribeIssue == "";
        if (_ok) then {
            _pass = _pass + 1;
            diag_log "[FAC TestSuite] PASS (server): BLU vs OPF valid";
        } else {
            _fail = _fail + 1;
            diag_log "[FAC TestSuite] FAIL (server): BLU vs OPF should be valid";
        };
        if (!isNil "FADE_despawnScenarioWorldUnits" && { !isNil "FADE_enemyPatrol_despawnAll" }) then {
            _pass = _pass + 1;
            diag_log "[FAC TestSuite] PASS (server): FADE_despawnScenarioWorldUnits installed";
        } else {
            _fail = _fail + 1;
            diag_log "[FAC TestSuite] FAIL (server): FADE_despawnScenarioWorldUnits missing";
        };
        if (!isNil "FADE_dummyUnits_refreshForScenarioFaction") then {
            _pass = _pass + 1;
            diag_log "[FAC TestSuite] PASS (server): FADE_dummyUnits_refreshForScenarioFaction installed";
        } else {
            _fail = _fail + 1;
            diag_log "[FAC TestSuite] FAIL (server): FADE_dummyUnits_refreshForScenarioFaction missing";
        };
        if (!isNil "FADE_anyScenarioMissionActive") then {
            private _savedGlobal = +(missionNamespace getVariable ["FADE_globalMission", []]);
            private _savedSingles = +(missionNamespace getVariable ["FADE_singleMissions", []]);
            missionNamespace setVariable ["FADE_globalMission", []];
            missionNamespace setVariable ["FADE_singleMissions", []];
            _ok = !([] call FADE_anyScenarioMissionActive);
            missionNamespace setVariable ["FADE_globalMission", ["AreaOfOperations", objNull, [0, 0, 0], "", "Test Op"]];
            private _okActive = [] call FADE_anyScenarioMissionActive;
            missionNamespace setVariable ["FADE_globalMission", _savedGlobal];
            missionNamespace setVariable ["FADE_singleMissions", _savedSingles];
            if (_ok && { _okActive }) then {
                _pass = _pass + 1;
                diag_log "[FAC TestSuite] PASS (server): FADE_anyScenarioMissionActive";
            } else {
                _fail = _fail + 1;
                diag_log "[FAC TestSuite] FAIL (server): FADE_anyScenarioMissionActive";
            };
        } else {
            _fail = _fail + 1;
            diag_log "[FAC TestSuite] FAIL (server): FADE_anyScenarioMissionActive missing";
        };
    } else {
        _fail = _fail + 1;
        diag_log "[FAC TestSuite] FAIL (server): FADE_normalizeScenarioFactions missing";
    };

    _ok = !isNil "FADE_syncPlayerToScenarioFriendlySide" && { !isNil "FADE_requestScenarioFriendlySideSync" };
    if (_ok) then { _pass = _pass + 1; diag_log "[FAC TestSuite] PASS (server): FADE_syncPlayerToScenarioFriendlySide / request RPC"; } else { _fail = _fail + 1; diag_log "[FAC TestSuite] FAIL (server): player side sync helpers missing"; };

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

    // Operation cleanup used to delete the civ-zone id list, so the deferred unpin released nothing.
    // Skip the cleanup call while an operation vehicle is live: that path deletes every FADE_opHomeIdx vehicle.
    if (!isNil "FADE_civ_pinZones" && { !isNil "FADE_cleanupMissionEntities" } && { !isNil "FADE_mission_unpinCivZonesForTask" } && { !isNil "FADE_civ_isZonePinned" }) then {
        private _pinTid = "FADE_suite_opCivPin";
        private _pinIds = ["FADE_suite_civPin_a", "FADE_suite_civPin_b", "FADE_suite_civPin_c"];
        private _liveOpVeh = vehicles findIf { _x getVariable ["FADE_opHomeIdx", -1] >= 0 };
        missionNamespace setVariable ["FADE_operationCivZoneIds_" + _pinTid, +_pinIds];
        [_pinIds] call FADE_civ_pinZones;
        if (_liveOpVeh >= 0) then {
            diag_log "[FAC TestSuite] SKIP (server): Operation cleanup keeps civ-zone pins (live operation vehicle present)";
        } else {
            missionNamespace setVariable ["FADE_operationEntities_" + _pinTid, [[], [], [], 250, [], []]];
            missionNamespace setVariable [format ["FADE_missionEnt_cleaned_%1", _pinTid], false];
            [_pinTid, "Operation", false] call FADE_cleanupMissionEntities;
            private _idsAfter = missionNamespace getVariable ["FADE_operationCivZoneIds_" + _pinTid, []];
            private _stillPinned = [_pinIds select 0] call FADE_civ_isZonePinned;
            _ok = _idsAfter isEqualTo _pinIds && { _stillPinned };
            if (_ok) then {
                _pass = _pass + 1;
                diag_log "[FAC TestSuite] PASS (server): Operation cleanup keeps civ-zone pins for deferred unpin";
            } else {
                _fail = _fail + 1;
                diag_log format ["[FAC TestSuite] FAIL (server): Operation cleanup dropped civ-zone pins (ids %1 pinned %2)", _idsAfter, _stillPinned];
            };
        };
        [_pinTid] call FADE_mission_unpinCivZonesForTask;
        private _idsGone = missionNamespace getVariable ["FADE_operationCivZoneIds_" + _pinTid, []];
        private _released = !([_pinIds select 0] call FADE_civ_isZonePinned);
        _ok = _idsGone isEqualTo [] && { _released };
        if (_ok) then {
            _pass = _pass + 1;
            diag_log "[FAC TestSuite] PASS (server): Operation unpin releases civ-zone pins";
        } else {
            _fail = _fail + 1;
            diag_log format ["[FAC TestSuite] FAIL (server): Operation unpin left civ-zone pins (ids %1 released %2)", _idsGone, _released];
        };
        missionNamespace setVariable [format ["FADE_missionEnt_cleaned_%1", _pinTid], nil];
        missionNamespace setVariable ["FADE_operationAborted_" + _pinTid, nil];
        missionNamespace setVariable ["FADE_operationEntities_" + _pinTid, nil];
        missionNamespace setVariable ["FADE_operationCivZoneIds_" + _pinTid, nil];
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

    // Faction-matched UAV list may be empty (e.g. 3CB ADA); pickClass then uses FADE_opforDrone_fallbackClasses.
    if (!isNil "FADE_getEnemyDroneVehicleClasses") then {
        private _drones = [] call FADE_getEnemyDroneVehicleClasses;
        _ok = _drones isEqualType [];
        if (_ok) then {
            _pass = _pass + 1;
            diag_log format ["[FAC TestSuite] PASS (server): FADE_getEnemyDroneVehicleClasses (%1 faction-matched)", count _drones];
            if (count _drones > 0) then {
                private _badDrone = _drones findIf { !isClass (configFile >> "CfgVehicles" >> _x) };
                _ok = _badDrone < 0;
                if (_ok) then { _pass = _pass + 1; diag_log "[FAC TestSuite] PASS (server): drone classes valid in CfgVehicles"; }
                else { _fail = _fail + 1; diag_log format ["[FAC TestSuite] FAIL (server): invalid drone class %1", _drones select _badDrone]; };
            };
        } else {
            _fail = _fail + 1;
            diag_log "[FAC TestSuite] FAIL (server): FADE_getEnemyDroneVehicleClasses not an array";
        };
        if (!isNil "FADE_opforDrone_pickClass") then {
            private _picked = [] call FADE_opforDrone_pickClass;
            _ok = (_picked isEqualType "") && { _picked != "" } && { isClass (configFile >> "CfgVehicles" >> _picked) };
            if (_ok) then { _pass = _pass + 1; diag_log format ["[FAC TestSuite] PASS (server): FADE_opforDrone_pickClass %1", _picked]; }
            else { _fail = _fail + 1; diag_log format ["[FAC TestSuite] FAIL (server): FADE_opforDrone_pickClass %1", _picked]; };
        };
    };

    // Empty FLY + a forward shove leaves the engine off and the helicopter nose-dives.
    if (!isNil "FADE_opforAir_placeAirborne" && { !isNil "FADE_opforAir_keepAirborne" }) then {
        private _heliClass = "O_Heli_Light_02_unarmed_F";
        if !(isClass (configFile >> "CfgVehicles" >> _heliClass)) then { _heliClass = "O_Heli_Light_02_dynamicLoadout_F" };
        private _pilotClass = "O_helipilot_F";
        if !(isClass (configFile >> "CfgVehicles" >> _pilotClass)) then { _pilotClass = "O_Soldier_F" };
        private _xy = [4000, 4000];
        private _base = missionNamespace getVariable ["FADE_basePos", []];
        if (_base isEqualType [] && { count _base >= 2 }) then {
            _xy = [(_base select 0) + 3500, (_base select 1) + 500];
        };
        if (!isNil "FADE_mapClampPos2D") then { _xy = [_xy, 300] call FADE_mapClampPos2D };
        private _atl = [_xy select 0, _xy select 1, 300];
        private _heli = createVehicle [_heliClass, _atl, [], 0, "CAN_COLLIDE"];
        if (isNull _heli) then {
            _fail = _fail + 1;
            diag_log "[FAC TestSuite] FAIL (server): OPFOR air test heli was not created";
        } else {
            _heli allowDamage false;
            private _sideE = missionNamespace getVariable ["FADE_sideEnemy", east];
            private _airGrp = createGroup _sideE;
            private _pilot = _airGrp createUnit [_pilotClass, _atl, [], 0, "NONE"];
            if (!isNull _pilot) then { _pilot moveInDriver _heli };
            private _flew = [_heli, _atl, 0, 200] call FADE_opforAir_placeAirborne;
            [_heli, 200] call FADE_opforAir_keepAirborne;
            sleep 1.5;
            private _aglNow = (getPosATL _heli) select 2;
            private _engine = isEngineOn _heli;
            _ok = _flew && { alive _heli } && { _engine } && { !(isTouchingGround _heli) } && { _aglNow > 40 };
            if (_ok) then {
                _pass = _pass + 1;
                diag_log format ["[FAC TestSuite] PASS (server): OPFOR heli stayed airborne engine=%1 agl=%2", _engine, _aglNow];
            } else {
                _fail = _fail + 1;
                diag_log format [
                    "[FAC TestSuite] FAIL (server): OPFOR heli dive engine=%1 agl=%2 flew=%3 touching=%4",
                    _engine, _aglNow, _flew, isTouchingGround _heli
                ];
            };
            { if (!isNull _x) then { deleteVehicle _x } } forEach units _airGrp;
            if (!isNull _heli) then { deleteVehicle _heli };
            if (!isNull _airGrp) then { deleteGroup _airGrp };
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

    // A magazine the pylon does not list is not applied. Pilot path [-1] normalizes to [] above.
    // Attack-heli pylon 1 is a gunner hardpoint and stays on turret [0].
    _ok = (!isNil "FADE_pylon_normalizeTurret")
        && { ([[-1]] call FADE_pylon_normalizeTurret) isEqualTo [] }
        && { ([[0]] call FADE_pylon_normalizeTurret) isEqualTo [0] };
    if (_ok) then {
        private _pylonClass = "";
        {
            if (isClass (configFile >> "CfgVehicles" >> _x)) exitWith { _pylonClass = _x };
        } forEach ["B_Heli_Attack_01_dynamicLoadout_F", "O_Heli_Attack_02_dynamicLoadout_F"];
        if (_pylonClass == "") then {
            diag_log "[FAC TestSuite] PASS (server): pylon turret normalize (no dynamic-loadout class to spawn)";
            _pass = _pass + 1;
        } else {
            private _pylonVeh = createVehicle [_pylonClass, [0, 0, 800], [], 0, "NONE"];
            if (isNull _pylonVeh) then {
                _fail = _fail + 1;
                diag_log format ["[FAC TestSuite] FAIL (server): pylon spawn %1", _pylonClass];
            } else {
                private _rejected = [_pylonVeh, 1, "FADE_NotARealPylonMag", [-1], -1] call FADE_pylon_applyLocal;
                private _slotMag = (getPylonMagazines _pylonVeh) param [0, ""];
                private _slotTurret = [((getAllPylonsInfo _pylonVeh) param [0, []]) param [2, []]] call FADE_pylon_normalizeTurret;
                _ok = (!_rejected) && {_slotMag != "FADE_NotARealPylonMag"} && {_slotTurret isEqualTo [] || {_slotTurret isEqualTo [0]}};
                if (_ok) then {
                    _pass = _pass + 1;
                    diag_log format ["[FAC TestSuite] PASS (server): rejected pylon magazine cleared on %1", _pylonClass];
                } else {
                    _fail = _fail + 1;
                    diag_log format ["[FAC TestSuite] FAIL (server): pylon reject applied=%1 mag=%2 turret=%3", _rejected, _slotMag, _slotTurret];
                };
                { if (!isNull _x) then { deleteVehicle _x } } forEach crew _pylonVeh;
                deleteVehicle _pylonVeh;
            };
        };
    } else {
        _fail = _fail + 1;
        diag_log "[FAC TestSuite] FAIL (server): FADE_pylon_normalizeTurret";
    };

    if (isClass (configFile >> "CfgVehicles" >> "RS_MH6V3")) then {
        _ok = missionNamespace getVariable ["FADE_pylon_mh6SyncPatched", false];
        if (_ok) then {
            _pass = _pass + 1;
            diag_log "[FAC TestSuite] PASS (server): RS_MH6V3 pylon sync runs on the aircraft owner";
        } else {
            _fail = _fail + 1;
            diag_log "[FAC TestSuite] FAIL (server): RS_MH6V3 pylon sync was not replaced";
        };
    } else {
        _pass = _pass + 1;
        diag_log "[FAC TestSuite] PASS (server): RS_MH6V3 not loaded; pylon sync patch not required";
    };

    diag_log "[FAC TestSuite] --- VEHICLE PLACEMENT ---";
    {
        private _fn = missionNamespace getVariable [_x, {}];
        if (_fn isEqualType {}) then {
            _pass = _pass + 1;
            diag_log format ["[FAC TestSuite] PASS (server): %1 is code", _x];
        } else {
            _fail = _fail + 1;
            diag_log format ["[FAC TestSuite] FAIL (server): %1 missing", _x];
        };
    } forEach ["FADE_vehiclePlacement_reason", "FADE_vehiclePlacement_createAt", "FADE_spawnVehicleAtPos"];

    private _placeClass = "";
    {
        if (([_x] call FADE_vehiclePlacement_classReason) == "") exitWith { _placeClass = _x };
    } forEach (missionNamespace getVariable ["FADE_landVehicleClasses", []]);
    if (_placeClass == "") then {
        _fail = _fail + 1;
        diag_log "[FAC TestSuite] FAIL (server): no placeable land class for placement checks";
    } else {
        private _soldierWhy = ["B_Soldier_F", [0, 0, 0], 0] call FADE_vehiclePlacement_reason;
        private _unknownWhy = ["FADE_NotAVehicle", [0, 0, 0], 0] call FADE_vehiclePlacement_reason;
        if (_soldierWhy != "" && { _unknownWhy != "" }) then {
            _pass = _pass + 1;
            diag_log "[FAC TestSuite] PASS (server): placement rejects infantry and unknown class";
        } else {
            _fail = _fail + 1;
            diag_log format ["[FAC TestSuite] FAIL (server): placement class reject soldier=%1 unknown=%2", _soldierWhy, _unknownWhy];
        };

        private _base = [] call FADE_vehiclePlacement_basePos;
        private _farWhy = [_placeClass, AGLToASL [(_base select 0) + 1500, (_base select 1), 1.5], 0] call FADE_vehiclePlacement_reason;
        if (_farWhy != "") then {
            _pass = _pass + 1;
            diag_log "[FAC TestSuite] PASS (server): placement rejects 1500 m from base";
        } else {
            _fail = _fail + 1;
            diag_log "[FAC TestSuite] FAIL (server): placement accepted a pose 1500 m from base";
        };

        // Same pose as the player ghost: model origin on the surface, no bounding-box lift.
        private _poseAt = {
            params ["_px", "_py"];
            AGLToASL [_px, _py, 0]
        };
        private _clear = [];
        for "_i" from 0 to 15 do {
            private _dist = 25 + (_i * 8);
            private _ang = _i * 47;
            private _try = [(_base select 0) + (_dist * sin _ang), (_base select 1) + (_dist * cos _ang)] call _poseAt;
            if (([_placeClass, _try, 90] call FADE_vehiclePlacement_reason) == "") exitWith { _clear = _try };
        };
        if (_clear isEqualTo []) then {
            _fail = _fail + 1;
            diag_log "[FAC TestSuite] FAIL (server): no clear placement pose near base";
        } else {
            _pass = _pass + 1;
            diag_log "[FAC TestSuite] PASS (server): clear placement pose near base";

            private _before = count (nearestObjects [ASLToAGL _clear, ["LandVehicle", "Air"], 12]);
            [_placeClass, objNull, _clear, 0] call FADE_spawnVehicleAtPos;
            private _after = count (nearestObjects [ASLToAGL _clear, ["LandVehicle", "Air"], 12]);
            if (_after == _before) then {
                _pass = _pass + 1;
                diag_log "[FAC TestSuite] PASS (server): spawn RPC with no player creates nothing";
            } else {
                _fail = _fail + 1;
                diag_log "[FAC TestSuite] FAIL (server): spawn RPC with no player created a vehicle";
            };

            private _preview = [_placeClass, [0, 0, 1000]] call FAC_vehiclePlacement_createGhost;
            if (!isNull _preview && { isSimpleObject _preview }) then {
                _pass = _pass + 1;
                diag_log format ["[FAC TestSuite] PASS (server): placement preview for %1 is a simple object", _placeClass];
                // getPhysicsCollisionFlag returns one boolean in an array.
                // https://community.bistudio.com/wiki/getPhysicsCollisionFlag
                private _colFlag = _preview call FAC_vehiclePlacement_ghostCollisionFlag;
                if (_colFlag isEqualType [] && { (_colFlag param [0, true]) isEqualTo false }) then {
                    _pass = _pass + 1;
                    diag_log format ["[FAC TestSuite] PASS (server): placement preview for %1 has no PhysX collision", _placeClass];
                } else {
                    _fail = _fail + 1;
                    diag_log format ["[FAC TestSuite] FAIL (server): placement preview for %1 collision flag %2", _placeClass, _colFlag];
                };
            } else {
                _fail = _fail + 1;
                diag_log format ["[FAC TestSuite] FAIL (server): placement preview for %1 is not a simple object", _placeClass];
            };
            if (!isNull _preview) then { deleteVehicle _preview };

            private _decoy = _placeClass createVehicleLocal [0, 0, 1000];
            if (isNull _decoy) then {
                _fail = _fail + 1;
                diag_log "[FAC TestSuite] FAIL (server): placement ghost decoy was not created";
            } else {
                _decoy allowDamage false;
                _decoy enableSimulation false;
                _decoy setVariable ["FAC_vehiclePlacement_isGhost", true];
                deleteVehicleCrew _decoy;
                _decoy setPosASL _clear;
                _decoy setDir 90;
                private _ghostWhy = [_placeClass, _clear, 90] call FADE_vehiclePlacement_reason;
                if (_ghostWhy == "") then {
                    _pass = _pass + 1;
                    diag_log "[FAC TestSuite] PASS (server): placement ghost does not block the pose";
                } else {
                    _fail = _fail + 1;
                    diag_log format ["[FAC TestSuite] FAIL (server): placement ghost blocked the pose (%1)", _ghostWhy];
                };
                deleteVehicle _decoy;
            };

            private _placed = [_placeClass, _clear, 90] call FADE_vehiclePlacement_createAt;
            if (isNull _placed) then {
                _fail = _fail + 1;
                diag_log "[FAC TestSuite] FAIL (server): createAt returned null on a clear pose";
            } else {
                sleep 2;
                private _dmg = damage _placed;
                if (alive _placed && { _dmg < 0.2 }) then {
                    _pass = _pass + 1;
                    diag_log format ["[FAC TestSuite] PASS (server): placed %1 stayed intact (damage %2)", _placeClass, _dmg];
                } else {
                    _fail = _fail + 1;
                    diag_log format ["[FAC TestSuite] FAIL (server): placed %1 exploded (alive=%2 damage=%3)", _placeClass, alive _placed, _dmg];
                };
                _placed enableSimulationGlobal false;
                _placed setPosASL _clear;
                _placed setDir 90;
                private _posOk = ((getPosASL _placed) distance _clear) < 3;
                private _dirNow = getDir _placed;
                private _dirOk = abs (_dirNow - 90) < 5;
                if (_posOk && { _dirOk }) then {
                    _pass = _pass + 1;
                    diag_log format ["[FAC TestSuite] PASS (server): placed %1 at requested pose", _placeClass];
                } else {
                    _fail = _fail + 1;
                    diag_log format ["[FAC TestSuite] FAIL (server): placed pose posOk=%1 dir=%2", _posOk, _dirNow];
                };

                private _here = getPosASL _placed;
                private _overlapWhy = [_placeClass, _here, getDir _placed] call FADE_vehiclePlacement_reason;
                private _second = [_placeClass, _here, getDir _placed] call FADE_vehiclePlacement_createAt;
                private _nearCount = count (nearestObjects [_placed, ["LandVehicle", "Air"], 8] select { typeOf _x == _placeClass });
                if (_overlapWhy != "" && { isNull _second } && { _nearCount == 1 }) then {
                    _pass = _pass + 1;
                    diag_log "[FAC TestSuite] PASS (server): overlapping placement rejected";
                } else {
                    _fail = _fail + 1;
                    diag_log format ["[FAC TestSuite] FAIL (server): overlap why=%1 secondNull=%2 near=%3", _overlapWhy, isNull _second, _nearCount];
                };
                if (!isNull _second) then {
                    { if (!isNull _x) then { deleteVehicle _x } } forEach crew _second;
                    deleteVehicle _second;
                };

                private _awayOk = false;
                private _placedAgl = getPos _placed;
                for "_k" from 0 to 7 do {
                    private _ang = _k * 45;
                    private _away = [(_placedAgl select 0) + (40 * sin _ang), (_placedAgl select 1) + (40 * cos _ang)] call _poseAt;
                    if (([_placeClass, _away, 0] call FADE_vehiclePlacement_reason) == "") exitWith { _awayOk = true };
                };
                if (_awayOk) then {
                    _pass = _pass + 1;
                    diag_log "[FAC TestSuite] PASS (server): pose about 40 m away is clear";
                } else {
                    _fail = _fail + 1;
                    diag_log "[FAC TestSuite] FAIL (server): no clear pose about 40 m from the placed vehicle";
                };

                { if (!isNull _x) then { deleteVehicle _x } } forEach crew _placed;
                deleteVehicle _placed;
            };

            {
                private _kind = _x;
                private _pool = if (_kind == "Helicopter") then {
                    missionNamespace getVariable ["FADE_heliClasses", []]
                } else {
                    missionNamespace getVariable ["FADE_landVehicleClasses", []]
                };
                private _class = "";
                {
                    if (([_x] call FADE_vehiclePlacement_classReason) == "" && { _x isKindOf _kind }) exitWith {
                        _class = _x
                    };
                } forEach _pool;
                if (_class == "") then {
                    _pass = _pass + 1;
                    diag_log format ["[FAC TestSuite] PASS (server): no %1 class to place", _kind];
                } else {
                    private _spot = [];
                    for "_n" from 0 to 15 do {
                        private _distN = 40 + (_n * 11);
                        private _angN = 15 + (_n * 37);
                        private _tryN = [(_base select 0) + (_distN * sin _angN), (_base select 1) + (_distN * cos _angN)] call _poseAt;
                        if (([_class, _tryN, 0] call FADE_vehiclePlacement_reason) == "") exitWith { _spot = _tryN };
                    };
                    if (_spot isEqualTo []) then {
                        _fail = _fail + 1;
                        diag_log format ["[FAC TestSuite] FAIL (server): no clear pose for %1", _class];
                    } else {
                        private _spawned = [_class, _spot, 0] call FADE_vehiclePlacement_createAt;
                        if (isNull _spawned) then {
                            _fail = _fail + 1;
                            diag_log format ["[FAC TestSuite] FAIL (server): createAt null for %1", _class];
                        } else {
                            sleep 2;
                            private _dmgK = damage _spawned;
                            if (alive _spawned && { _dmgK < 0.2 }) then {
                                _pass = _pass + 1;
                                diag_log format ["[FAC TestSuite] PASS (server): placed %1 stayed intact (damage %2)", _class, _dmgK];
                            } else {
                                _fail = _fail + 1;
                                diag_log format ["[FAC TestSuite] FAIL (server): placed %1 exploded (alive=%2 damage=%3)", _class, alive _spawned, _dmgK];
                            };
                            { if (!isNull _x) then { deleteVehicle _x } } forEach crew _spawned;
                            deleteVehicle _spawned;
                        };
                    };
                };
            } forEach ["Car", "Tank", "Helicopter"];
        };
    };

    // A non-string uid must not throw. A matching string uid despawns the FIRES drone.
    _ok = !isNil "FADE_onPlayerDisconnected";
    if (_ok) then {
        private _discSavedOu = missionNamespace getVariable ["FAC_firesFoS_droneOwnerUid", ""];
        private _discSavedFn = missionNamespace getVariable ["FADE_firesFoS_droneDespawnServer", {}];
        missionNamespace setVariable ["FAC_firesFoS_droneOwnerUid", "FADE_TEST_DISCONNECT_UID"];
        missionNamespace setVariable ["FADE_testDisconnectDespawned", false];
        missionNamespace setVariable ["FADE_firesFoS_droneDespawnServer", {
            missionNamespace setVariable ["FADE_testDisconnectDespawned", true];
        }];
        [1, 5, "name", false, 2, "1"] call FADE_onPlayerDisconnected;
        [1, "other-uid", "name", false, 2, "1"] call FADE_onPlayerDisconnected;
        private _kept = !(missionNamespace getVariable ["FADE_testDisconnectDespawned", false])
            && {(missionNamespace getVariable ["FAC_firesFoS_droneOwnerUid", ""]) isEqualTo "FADE_TEST_DISCONNECT_UID"};
        [1, "FADE_TEST_DISCONNECT_UID", "name", false, 2, "1"] call FADE_onPlayerDisconnected;
        _ok = _kept && {missionNamespace getVariable ["FADE_testDisconnectDespawned", false]};
        missionNamespace setVariable ["FAC_firesFoS_droneOwnerUid", _discSavedOu];
        missionNamespace setVariable ["FADE_firesFoS_droneDespawnServer", _discSavedFn];
        missionNamespace setVariable ["FADE_testDisconnectDespawned", nil];
    };
    if (_ok) then {
        _pass = _pass + 1;
        diag_log "[FAC TestSuite] PASS (server): PlayerDisconnected uid match";
    } else {
        _fail = _fail + 1;
        diag_log "[FAC TestSuite] FAIL (server): PlayerDisconnected uid match";
    };

    diag_log "[FAC TestSuite] --- BUILD ---";
    private _buildSavedAccess = missionNamespace getVariable ["FAC_param_buildAccess", 1];
    private _buildSavedLog = missionNamespace getVariable ["FAC_param_buildLogistics", 0];
    private _buildSavedArea = missionNamespace getVariable ["FAC_param_buildArea", 0];
    private _buildSavedCatalog = missionNamespace getVariable ["FAC_param_buildCatalog", 0];
    private _buildSavedRequire = missionNamespace getVariable ["FAC_param_buildRequire", 0];
    missionNamespace setVariable ["FAC_param_buildCatalog", 0];
    missionNamespace setVariable ["FAC_param_buildRequire", 0];
    private _buildSavedSupply = missionNamespace getVariable ["FADE_buildSupply", 0];
    private _buildCat = missionNamespace getVariable ["FADE_buildCatalog", []];
    _ok = _buildCat isEqualType [] && { count _buildCat > 0 };
    private _buildCatBad = "";
    if (_ok) then {
        {
            _x params ["_c", "_name", "_cost", "_bt", "_un", ["_cat", ""], ["_sub", ""]];
            if (!isClass (configFile >> "CfgVehicles" >> _c)) exitWith { _ok = false; _buildCatBad = _c };
            if !(_bt isEqualTo 0) exitWith { _ok = false; _buildCatBad = _c + " buildTime" };
            if !(_un isEqualTo "") exitWith { _ok = false; _buildCatBad = _c + " unlock" };
            if !(_cost isEqualType 0) exitWith { _ok = false; _buildCatBad = _c + " cost" };
            if !(_cat isEqualType "" && { _cat != "" }) exitWith { _ok = false; _buildCatBad = _c + " category" };
            if !(_sub isEqualType "" && { _sub != "" }) exitWith { _ok = false; _buildCatBad = _c + " subcategory" };
        } forEach _buildCat;
        {
            if (isClass (configFile >> "CfgVehicles" >> _x)) then {
                private _hit = [_x] call FADE_build_findEntry;
                if (_hit isEqualTo [] || { (_hit param [5, ""]) == "" }) exitWith {
                    _ok = false;
                    _buildCatBad = _x + " missing from eden list";
                };
            };
        } forEach ["Land_BagFence_Long_F", "Land_WallSign_01_F"];
    };
    private _signTex = ["Hello\nWorld"] call FADE_build_signTexture;
    private _signQuote = ["A""B"] call FADE_build_signTexture;
    private _signPct = ["100%"] call FADE_build_signTexture;
    private _signEmpty = [""] call FADE_build_signTexture;
    private _signTexOk = (_signTex find "Caveat") >= 0
        && { _signTex find "Hello\nWorld" >= 0 }
        && { _signQuote find "A'B" >= 0 }
        && { _signPct find "100%" >= 0 }
        && { _signPct find "%%" < 0 }
        && { _signEmpty == "" };
    if (_signTexOk) then {
        _pass = _pass + 1;
        diag_log "[FAC TestSuite] PASS (server): build sign texture";
    } else {
        _fail = _fail + 1;
        diag_log format ["[FAC TestSuite] FAIL (server): build sign texture plain=%1 quote=%2 pct=%3 empty=%4", _signTex, _signQuote, _signPct, _signEmpty];
    };
    if (_ok) then {
        _pass = _pass + 1;
        diag_log format ["[FAC TestSuite] PASS (server): build catalog (%1)", count _buildCat];
    } else {
        _fail = _fail + 1;
        diag_log format ["[FAC TestSuite] FAIL (server): build catalog %1", _buildCatBad];
    };

    private _buildGrp = createGroup [west, true];
    private _buildBase = missionNamespace getVariable ["FADE_basePos", [0, 0, 0]];
    private _buildUnit = _buildGrp createUnit ["B_Soldier_F", _buildBase, [], 0, "NONE"];
    if (isNull _buildUnit) then {
        _fail = _fail + 1;
        diag_log "[FAC TestSuite] FAIL (server): build test unit";
    } else {
        _buildUnit setUnitTrait ["Engineer", false];
        private _buildBeforeIds = [];
        {
            if (_x getVariable ["FADE_build_placed", false]) then { _buildBeforeIds pushBack (netId _x) };
        } forEach nearestObjects [_buildBase, ["All"], 2500];
        private _buildOverride = [_buildUnit] call FAC_playerHasLeaderOverrideAccess;
        if (_buildOverride) then {
            missionNamespace setVariable ["FAC_param_buildAccess", 2];
            _ok = [_buildUnit] call FAC_playerCanBuild;
            if (_ok) then {
                _pass = _pass + 1;
                diag_log "[FAC TestSuite] PASS (server): build admin/Zeus override allows No-one mode";
            } else {
                _fail = _fail + 1;
                diag_log "[FAC TestSuite] FAIL (server): build admin/Zeus override";
            };
            diag_log "[FAC TestSuite] SKIP (server): build access matrix (test unit counts as admin/Zeus)";
        } else {
            missionNamespace setVariable ["FAC_param_buildAccess", 1];
            private _anyone = [_buildUnit] call FAC_playerCanBuild;
            missionNamespace setVariable ["FAC_param_buildAccess", 0];
            private _rifleDenied = !([_buildUnit] call FAC_playerCanBuild);
            _buildUnit setUnitTrait ["Engineer", true];
            private _engAllowed = [_buildUnit] call FAC_playerCanBuild;
            missionNamespace setVariable ["FAC_param_buildAccess", 2];
            private _noneDenied = !([_buildUnit] call FAC_playerCanBuild);
            _ok = _anyone && { _rifleDenied } && { _engAllowed } && { _noneDenied };
            if (_ok) then {
                _pass = _pass + 1;
                diag_log "[FAC TestSuite] PASS (server): build access Anyone / Engineers / No-one";
            } else {
                _fail = _fail + 1;
                diag_log format ["[FAC TestSuite] FAIL (server): build access anyone=%1 rifleDenied=%2 eng=%3 noneDenied=%4", _anyone, _rifleDenied, _engAllowed, _noneDenied];
            };
        };

        private _buildLogic = createGroup [sideLogic, true];
        private _buildCur = _buildLogic createUnit ["ModuleCurator_F", _buildBase, [], 0, "NONE"];
        if (!isNull _buildCur) then {
            _buildUnit assignCurator _buildCur;
            missionNamespace setVariable ["FAC_param_buildAccess", 2];
            _ok = [_buildUnit] call FAC_playerCanBuild;
            unassignCurator _buildCur;
            deleteVehicle _buildCur;
            if (_ok) then {
                _pass = _pass + 1;
                diag_log "[FAC TestSuite] PASS (server): build Zeus override";
            } else {
                _fail = _fail + 1;
                diag_log "[FAC TestSuite] FAIL (server): build Zeus override";
            };
        } else {
            _fail = _fail + 1;
            diag_log "[FAC TestSuite] FAIL (server): build Zeus module";
        };
        deleteGroup _buildLogic;

        missionNamespace setVariable ["FAC_param_buildAccess", 1];
        _buildUnit setUnitTrait ["Engineer", false];
        private _buildEntry = ["Land_BagFence_Long_F"] call FADE_build_findEntry;
        if (_buildEntry isEqualTo []) then { _buildEntry = _buildCat select 0 };
        private _buildClass = _buildEntry select 0;
        private _buildCost = _buildEntry select 2;
        private _buildSpot = [];
        for "_i" from 2 to 30 do {
            private _try = [(_buildBase select 0) + (_i * 6), (_buildBase select 1) + 15, 0];
            if (([_buildClass, _try, 0, objNull] call FADE_build_spotBlocked) == "") exitWith { _buildSpot = _try };
        };
        if (_buildSpot isEqualTo []) then {
            _fail = _fail + 1;
            diag_log "[FAC TestSuite] FAIL (server): build no free spot near base";
        } else {
            missionNamespace setVariable ["FAC_param_buildLogistics", 0];
            private _poolBefore = missionNamespace getVariable ["FADE_buildSupply", 0];
            private _placedFree = [_buildUnit, _buildClass, _buildSpot, 0, [0, 0, 1], false] call FADE_build_place;
            private _poolAfter = missionNamespace getVariable ["FADE_buildSupply", 0];
            private _built = objNull;
            {
                if (_x getVariable ["FADE_build_placed", false] && { (_x distance2D _buildSpot) < 4 }) exitWith { _built = _x };
            } forEach nearestObjects [_buildSpot, ["Static", "Thing"], 8];
            private _builtId = if (isNull _built) then { "" } else { netId _built };
            private _builtRec = FADE_build_registry getOrDefault [_builtId, createHashMap];
            private _stillOpen = false;
            if (!isNull _built) then {
                _stillOpen = ([_buildClass, getPosATL _built, getDir _built, objNull] call FADE_build_spotBlocked) == "";
            };
            _ok = _placedFree && { _poolBefore == _poolAfter } && { (_builtRec getOrDefault ["state", ""]) == "complete" } && { _stillOpen };
            if (_ok) then {
                _pass = _pass + 1;
                diag_log "[FAC TestSuite] PASS (server): build free place, registry complete, overlap not enforced";
            } else {
                _fail = _fail + 1;
                diag_log format ["[FAC TestSuite] FAIL (server): build free place placed=%1 pool %2->%3 state=%4 open=%5", _placedFree, _poolBefore, _poolAfter, _builtRec getOrDefault ["state", ""], _stillOpen];
            };
            if (_builtId != "") then { [_buildUnit, _builtId] call FADE_build_remove };
            _ok = FADE_build_registry getOrDefault [_builtId, ""] isEqualTo "";
            if (_ok) then {
                _pass = _pass + 1;
                diag_log "[FAC TestSuite] PASS (server): build remove clears registry";
            } else {
                _fail = _fail + 1;
                diag_log "[FAC TestSuite] FAIL (server): build remove clears registry";
            };

            private _spot2 = [];
            for "_i" from 2 to 30 do {
                private _try2 = [(_buildBase select 0) + 15, (_buildBase select 1) + (_i * 6), 0];
                if (([_buildClass, _try2, 0, objNull] call FADE_build_spotBlocked) == "") exitWith { _spot2 = _try2 };
            };
            missionNamespace setVariable ["FAC_param_buildLogistics", 1];
            missionNamespace setVariable ["FADE_buildSupply", _buildCost];
            if (_spot2 isEqualTo []) then {
                _fail = _fail + 1;
                diag_log "[FAC TestSuite] FAIL (server): build no second spot for supply check";
            } else {
                private _paid = [_buildUnit, _buildClass, _spot2, 0, [0, 0, 1], false] call FADE_build_place;
                private _poolPaid = missionNamespace getVariable ["FADE_buildSupply", -1];
                private _paidObj = objNull;
                {
                    if (_x getVariable ["FADE_build_placed", false] && { (_x distance2D _spot2) < 4 }) exitWith { _paidObj = _x };
                } forEach nearestObjects [_spot2, ["Static", "Thing"], 8];
                private _broke = [_buildUnit, _buildClass, _buildSpot, 0, [0, 0, 1], false] call FADE_build_place;
                private _poolBroke = missionNamespace getVariable ["FADE_buildSupply", -1];
                _ok = _paid && { _poolPaid == 0 } && { !_broke } && { _poolBroke == 0 };
                if (_ok) then {
                    _pass = _pass + 1;
                    diag_log "[FAC TestSuite] PASS (server): build supply debit and empty pool deny";
                } else {
                    _fail = _fail + 1;
                    diag_log format ["[FAC TestSuite] FAIL (server): build supply paid=%1 pool=%2 second=%3 poolAfter=%4", _paid, _poolPaid, _broke, _poolBroke];
                };
                if (!isNull _paidObj) then {
                    private _refundId = netId _paidObj;
                    [_buildUnit, _refundId] call FADE_build_remove;
                    _ok = (missionNamespace getVariable ["FADE_buildSupply", -1]) == _buildCost;
                    if (_ok) then {
                        _pass = _pass + 1;
                        diag_log "[FAC TestSuite] PASS (server): build remove refunds supply";
                    } else {
                        _fail = _fail + 1;
                        diag_log format ["[FAC TestSuite] FAIL (server): build refund pool=%1 expected=%2", missionNamespace getVariable ["FADE_buildSupply", -1], _buildCost];
                    };
                };
            };

            private _far = [(_buildBase select 0) + 2000, _buildBase select 1, 0];
            missionNamespace setVariable ["FAC_param_buildArea", 0];
            private _farWhy = [_buildClass, _far, 0, objNull] call FADE_build_spotBlocked;
            private _farPlaced = [_buildUnit, _buildClass, _far, 0, [0, 0, 1], false] call FADE_build_place;
            _ok = !_farPlaced && { _farWhy == "radius" || { _farWhy == "water" } };
            if (_ok) then {
                _pass = _pass + 1;
                diag_log format ["[FAC TestSuite] PASS (server): build outside radius denied (%1)", _farWhy];
            } else {
                _fail = _fail + 1;
                diag_log format ["[FAC TestSuite] FAIL (server): build outside radius placed=%1 why=%2", _farPlaced, _farWhy];
            };

            missionNamespace setVariable ["FAC_param_buildArea", 1];
            private _farLand = [];
            for "_k" from 0 to 6 do {
                private _tryFar = [(_buildBase select 0) + 1400 + (_k * 80), (_buildBase select 1) + 40, 0];
                if (([_buildClass, _tryFar, 0, objNull] call FADE_build_spotBlocked) == "") exitWith { _farLand = _tryFar };
            };
            if (_farLand isEqualTo []) then {
                diag_log "[FAC TestSuite] SKIP (server): build anywhere (no dry spot outside the radius)";
            } else {
                private _anywherePlaced = [_buildUnit, _buildClass, _farLand, 0, [0, 0, 1], false] call FADE_build_place;
                if (_anywherePlaced) then {
                    _pass = _pass + 1;
                    diag_log "[FAC TestSuite] PASS (server): build anywhere allows outside the radius";
                } else {
                    _fail = _fail + 1;
                    diag_log "[FAC TestSuite] FAIL (server): build anywhere allows outside the radius";
                };
            };
            missionNamespace setVariable ["FAC_param_buildArea", 0];

            private _sea = [0, 0, 0];
            if (surfaceIsWater _sea) then {
                private _seaWhy = [_buildClass, _sea, 0, objNull] call FADE_build_spotBlocked;
                _ok = _seaWhy == "water";
                if (_ok) then {
                    _pass = _pass + 1;
                    diag_log "[FAC TestSuite] PASS (server): build water denied";
                } else {
                    _fail = _fail + 1;
                    diag_log format ["[FAC TestSuite] FAIL (server): build water why=%1", _seaWhy];
                };
            } else {
                diag_log "[FAC TestSuite] SKIP (server): build water (origin is not water)";
            };
        };

        private _signClass = "Land_WallSign_01_F";
        private _signEntry = [_signClass] call FADE_build_findEntry;
        if (_signEntry isEqualTo []) then {
            if (isClass (configFile >> "CfgVehicles" >> _signClass)) then {
                _fail = _fail + 1;
                diag_log "[FAC TestSuite] FAIL (server): build sign class missing from catalog";
            } else {
                diag_log "[FAC TestSuite] SKIP (server): build sign (class not in config)";
            };
        } else {
            missionNamespace setVariable ["FAC_param_buildLogistics", 0];
            missionNamespace setVariable ["FAC_param_buildArea", 0];
            private _signSpot = [];
            for "_i" from 2 to 40 do {
                private _tryS = [(_buildBase select 0) - (_i * 5), (_buildBase select 1) + 20, 0];
                if (([_signClass, _tryS, 0, objNull] call FADE_build_spotBlocked) == "") exitWith { _signSpot = _tryS };
            };
            private _dummy = createVehicle ["Land_BagFence_Long_F", _buildBase, [], 0, "CAN_COLLIDE"];
            private _dummyDenied = true;
            if (!isNull _dummy) then {
                _dummyDenied = [_buildUnit, netId _dummy, "nope"] call FADE_build_signSet;
                deleteVehicle _dummy;
            };
            if (_signSpot isEqualTo []) then {
                _fail = _fail + 1;
                diag_log "[FAC TestSuite] FAIL (server): build sign no spot";
            } else {
                private _signPlaced = [_buildUnit, _signClass, _signSpot, 0, [0, 0, 1], false] call FADE_build_place;
                private _signObj = objNull;
                {
                    if (_x getVariable ["FADE_build_placed", false] && { (_x distance2D _signSpot) < 4 }) exitWith { _signObj = _x };
                } forEach nearestObjects [_signSpot, ["All"], 8];
                private _raw = "Hello\nWorld";
                private _wrote = false;
                private _cleared = false;
                if (!isNull _signObj) then {
                    _wrote = [_buildUnit, netId _signObj, _raw] call FADE_build_signSet;
                    private _stored = _signObj getVariable ["FADE_build_signText", ""];
                    private _slot = [_signObj] call FADE_build_writeSlot;
                    private _textures = getObjectTextures _signObj;
                    private _face = if (_slot >= 0 && { _slot < count _textures }) then { _textures select _slot } else { "" };
                    private _materialKept = true;
                    if (_slot > 0 && { count _textures > 0 }) then {
                        private _mat = _textures select 0;
                        _materialKept = !(_mat isEqualType "") || { _mat find "Hello" < 0 };
                    };
                    _wrote = _wrote && { _stored == _raw } && { _slot >= 0 } && { _materialKept } && { _face == "" || { _face find "Hello" >= 0 } };
                    _cleared = [_buildUnit, netId _signObj, ""] call FADE_build_signSet;
                    _cleared = _cleared && { (_signObj getVariable ["FADE_build_signText", "x"]) == "" };
                };
                _ok = _signPlaced && { _wrote } && { _cleared } && { !_dummyDenied };
                if (_ok) then {
                    _pass = _pass + 1;
                    diag_log "[FAC TestSuite] PASS (server): build sign write and clear";
                } else {
                    _fail = _fail + 1;
                    diag_log format ["[FAC TestSuite] FAIL (server): build sign placed=%1 wrote=%2 cleared=%3 dummyDenied=%4", _signPlaced, _wrote, _cleared, _dummyDenied];
                };
            };
        };

        private _chalkClass = "Land_WallSign_01_chalkboard_F";
        private _chalkEntry = [_chalkClass] call FADE_build_findEntry;
        if (_chalkEntry isEqualTo []) then {
            if (isClass (configFile >> "CfgVehicles" >> _chalkClass)) then {
                _fail = _fail + 1;
                diag_log "[FAC TestSuite] FAIL (server): build chalkboard missing from catalog";
            } else {
                diag_log "[FAC TestSuite] SKIP (server): build chalkboard (class not in config)";
            };
        } else {
            private _chalkSpot = [];
            for "_i" from 2 to 40 do {
                private _tryC = [(_buildBase select 0) - (_i * 5), (_buildBase select 1) + 40, 0];
                if (([_chalkClass, _tryC, 0, objNull] call FADE_build_spotBlocked) == "") exitWith { _chalkSpot = _tryC };
            };
            if (_chalkSpot isEqualTo []) then {
                _fail = _fail + 1;
                diag_log "[FAC TestSuite] FAIL (server): build chalkboard no spot";
            } else {
                private _chalkPlaced = [_buildUnit, _chalkClass, _chalkSpot, 0, [0, 0, 1], false] call FADE_build_place;
                private _chalkObj = objNull;
                {
                    if (_x getVariable ["FADE_build_placed", false] && { (_x distance2D _chalkSpot) < 4 }) exitWith { _chalkObj = _x };
                } forEach nearestObjects [_chalkSpot, ["All"], 8];
                private _chalkWrote = false;
                if (!isNull _chalkObj) then {
                    _chalkWrote = [_buildUnit, netId _chalkObj, "Hello\nWorld"] call FADE_build_signSet;
                    private _slot = [_chalkObj] call FADE_build_writeSlot;
                    private _textures = getObjectTextures _chalkObj;
                    private _face = if (_slot >= 0 && { _slot < count _textures }) then { _textures select _slot } else { "" };
                    private _lowerClean = true;
                    {
                        if (_forEachIndex < _slot && { _x isEqualType "" } && { _x find "Hello" >= 0 }) then { _lowerClean = false };
                    } forEach _textures;
                    _chalkWrote = _chalkWrote && { _slot >= 0 } && { _lowerClean } && { _face == "" || { _face find "Hello" >= 0 } };
                };
                if (_chalkPlaced && { _chalkWrote }) then {
                    _pass = _pass + 1;
                    diag_log "[FAC TestSuite] PASS (server): build chalkboard write";
                } else {
                    _fail = _fail + 1;
                    diag_log format ["[FAC TestSuite] FAIL (server): build chalkboard placed=%1 wrote=%2", _chalkPlaced, _chalkWrote];
                };
            };
        };

        private _plainClass = "";
        {
            private _cls = _x param [0, ""];
            if (_cls != "" && { ([objNull, _cls] call FADE_build_writeSlot) < 0 }) exitWith { _plainClass = _cls };
        } forEach (missionNamespace getVariable ["FADE_buildCatalog", []]);
        if (_plainClass == "") then {
            diag_log "[FAC TestSuite] SKIP (server): build write denied (no catalog class without a texture)";
        } else {
            private _plainSpot = [];
            for "_i" from 2 to 40 do {
                private _tryP = [(_buildBase select 0) + (_i * 5), (_buildBase select 1) + 60, 0];
                if (([_plainClass, _tryP, 0, objNull] call FADE_build_spotBlocked) == "") exitWith { _plainSpot = _tryP };
            };
            if (_plainSpot isEqualTo []) then {
                _fail = _fail + 1;
                diag_log "[FAC TestSuite] FAIL (server): build plain write no spot";
            } else {
                private _plainPlaced = [_buildUnit, _plainClass, _plainSpot, 0, [0, 0, 1], false] call FADE_build_place;
                private _plainObj = objNull;
                {
                    if (_x getVariable ["FADE_build_placed", false] && { (typeOf _x) == _plainClass } && { (_x distance2D _plainSpot) < 4 }) exitWith { _plainObj = _x };
                } forEach nearestObjects [_plainSpot, ["All"], 8];
                private _plainDenied = true;
                if (!isNull _plainObj && { ([_plainObj] call FADE_build_writeSlot) >= 0 }) then {
                    diag_log format ["[FAC TestSuite] SKIP (server): build write denied (%1 has a live texture)", _plainClass];
                } else {
                    if (!isNull _plainObj) then {
                        _plainDenied = [_buildUnit, netId _plainObj, "nope"] call FADE_build_signSet;
                    };
                    if (_plainPlaced && { !_plainDenied }) then {
                        _pass = _pass + 1;
                        diag_log format ["[FAC TestSuite] PASS (server): build write denied on %1", _plainClass];
                    } else {
                        _fail = _fail + 1;
                        diag_log format ["[FAC TestSuite] FAIL (server): build write denied class=%1 placed=%2 denied=%3", _plainClass, _plainPlaced, _plainDenied];
                    };
                };
            };
        };

        private _undoSpot = [];
        for "_i" from 2 to 40 do {
            private _tryU = [(_buildBase select 0) + (_i * 5), (_buildBase select 1) - 40, 0];
            if (([_buildClass, _tryU, 0, objNull] call FADE_build_spotBlocked) == "") exitWith { _undoSpot = _tryU };
        };
        if (_undoSpot isEqualTo []) then {
            _fail = _fail + 1;
            diag_log "[FAC TestSuite] FAIL (server): build undo no spot";
        } else {
            private _undoPlaced = [_buildUnit, _buildClass, _undoSpot, 0, [0, 0, 1], false] call FADE_build_place;
            private _undoObj = objNull;
            {
                if (_x getVariable ["FADE_build_placed", false] && { (_x distance2D _undoSpot) < 4 }) exitWith { _undoObj = _x };
            } forEach nearestObjects [_undoSpot, ["All"], 8];
            private _undoId = if (isNull _undoObj) then { "" } else { netId _undoObj };
            private _undoOk = [_buildUnit] call FADE_build_undo;
            if (canSuspend) then { sleep 0.1 };
            private _undoLeft = objNull;
            {
                if (_x getVariable ["FADE_build_placed", false] && { (_x distance2D _undoSpot) < 4 }) exitWith { _undoLeft = _x };
            } forEach nearestObjects [_undoSpot, ["All"], 8];
            private _undoStack = FADE_build_undoStack getOrDefault [getPlayerUID _buildUnit, []];
            if (_undoPlaced && { _undoOk } && { _undoId != "" } && { isNull _undoLeft } && { !(_undoId in _undoStack) } && { !(_undoId in (keys FADE_build_registry)) }) then {
                _pass = _pass + 1;
                diag_log "[FAC TestSuite] PASS (server): build undo last piece";
            } else {
                _fail = _fail + 1;
                diag_log format ["[FAC TestSuite] FAIL (server): build undo placed=%1 ok=%2 id=%3 leftId=%4 origNull=%5", _undoPlaced, _undoOk, _undoId, if (isNull _undoLeft) then { "" } else { netId _undoLeft }, isNull _undoObj];
            };
        };

        private _clearSpot = [];
        for "_i" from 2 to 40 do {
            private _tryClear = [(_buildBase select 0) - (_i * 5), (_buildBase select 1) - 40, 0];
            if (([_buildClass, _tryClear, 0, objNull] call FADE_build_spotBlocked) == "") exitWith { _clearSpot = _tryClear };
        };
        if (_clearSpot isEqualTo []) then {
            _fail = _fail + 1;
            diag_log "[FAC TestSuite] FAIL (server): build clear-all no spot";
        } else {
            private _clearPlaced = [_buildUnit, _buildClass, _clearSpot, 0, [0, 0, 1], false] call FADE_build_place;
            private _cleared = [] call FADE_build_clearAll;
            private _left = objNull;
            {
                if (_x getVariable ["FADE_build_placed", false] && { (_x distance2D _clearSpot) < 8 }) exitWith { _left = _x };
            } forEach nearestObjects [_clearSpot, ["All"], 12];
            if (_clearPlaced && { _cleared >= 1 } && { isNull _left } && { (count FADE_build_registry) == 0 }) then {
                _pass = _pass + 1;
                diag_log "[FAC TestSuite] PASS (server): build clear-all";
            } else {
                _fail = _fail + 1;
                diag_log format ["[FAC TestSuite] FAIL (server): build clear-all placed=%1 n=%2 left=%3 reg=%4", _clearPlaced, _cleared, !isNull _left, count FADE_build_registry];
            };
        };

        if !(_clearSpot isEqualTo []) then {
            private _undoNone = [_buildUnit] call FADE_build_undo;
            if (!_undoNone && { (count FADE_build_undoStack) == 0 }) then {
                _pass = _pass + 1;
                diag_log "[FAC TestSuite] PASS (server): build undo empty";
            } else {
                _fail = _fail + 1;
                diag_log format ["[FAC TestSuite] FAIL (server): build undo empty returned=%1 stacks=%2", _undoNone, count FADE_build_undoStack];
            };
        };

        private _flagSpot = [];
        for "_i" from 2 to 40 do {
            private _tryF = [(_buildBase select 0) + (_i * 5), (_buildBase select 1) - 20, 0];
            if (([_buildClass, _tryF, 0, objNull] call FADE_build_spotBlocked) == "") exitWith { _flagSpot = _tryF };
        };
        if (_flagSpot isEqualTo []) then {
            _fail = _fail + 1;
            diag_log "[FAC TestSuite] FAIL (server): build flags no spot";
        } else {
            private _simPlaced = [_buildUnit, _buildClass, _flagSpot, 0, [0, 0, 1], false, false, false, false] call FADE_build_place;
            private _simObj = objNull;
            {
                if (_x getVariable ["FADE_build_placed", false] && { (_x distance2D _flagSpot) < 4 }) exitWith { _simObj = _x };
            } forEach nearestObjects [_flagSpot, ["All"], 8];
            private _simOff = (!isNull _simObj) && { !(simulationEnabled _simObj) };
            if (_simPlaced && { _simOff }) then {
                _pass = _pass + 1;
                diag_log "[FAC TestSuite] PASS (server): build simulation off";
            } else {
                _fail = _fail + 1;
                diag_log format ["[FAC TestSuite] FAIL (server): build simulation off placed=%1 obj=%2", _simPlaced, _simOff];
            };
            private _simpleSpot = [(_flagSpot select 0), (_flagSpot select 1) + 8, 0];
            if (([_buildClass, _simpleSpot, 0, objNull] call FADE_build_spotBlocked) != "") then {
                _simpleSpot = [];
            };
            if (_simpleSpot isEqualTo []) then {
                _fail = _fail + 1;
                diag_log "[FAC TestSuite] FAIL (server): build simple no spot";
            } else {
                private _simplePlaced = [_buildUnit, _buildClass, _simpleSpot, 0, [0, 0, 1], false, false, false, true] call FADE_build_place;
                private _simpleObj = objNull;
                {
                    private _cand = _x call BIS_fnc_objectFromNetId;
                    if (!isNull _cand && { isSimpleObject _cand } && { _cand getVariable ["FADE_build_simple", false] }) exitWith { _simpleObj = _cand };
                } forEach (keys FADE_build_registry);
                if (_simplePlaced && { !isNull _simpleObj }) then {
                    _pass = _pass + 1;
                    diag_log "[FAC TestSuite] PASS (server): build simple object";
                } else {
                    _fail = _fail + 1;
                    diag_log format ["[FAC TestSuite] FAIL (server): build simple placed=%1", _simplePlaced];
                };
            };
        };

        missionNamespace setVariable ["FAC_param_buildCatalog", 1];
        private _realRow = ["Land_BagFence_Long_F"] call FADE_build_findEntry;
        private _realOk = !(_realRow isEqualTo []) && { (_realRow select 2) == 15 };
        {
            if (isClass (configFile >> "CfgVehicles" >> _x)) then {
                private _row = [_x] call FADE_build_findEntry;
                if (_row isEqualTo [] || { (_row param [5, ""]) != "Fortifications" }) then { _realOk = false };
            };
        } forEach [
            "Land_BagFence_Long_F", "Land_BagFence_Short_F", "Land_BagFence_Round_F",
            "Land_HBarrier_1_F", "Land_HBarrier_5_F", "Land_Razorwire_F",
            "Land_CncBarrierMedium4_F", "Land_BagBunker_Small_F",
            "Land_CamoNet_BIG_F", "Land_PortableLight_single_F"
        ];
        {
            if (isClass (configFile >> "CfgVehicles" >> _x)) then {
                private _row = [_x] call FADE_build_findEntry;
                if (_row isEqualTo []) then { _realOk = false };
            };
        } forEach [
            "Land_HBarrierTower_lxWS", "CamoNet_OPFOR_open_F",
            "Land_CampingChair_V2_white_F", "Land_CampingTable_white_F",
            "Land_PowerGenerator_F", "WaterPump_01_sand_F",
            "Land_MapBoard_01_Wall_F", "Land_MapBoard_F", "Land_WallSign_01_F",
            "Land_PaperBox_closed_F", "Land_Net_Fence_8m_F", "Land_Net_Fence_4m_F",
            "Land_Net_Fence_Gate_F", "CargoNet_01_box_F", "Box_Cargo_Science_RF",
            "Box_Cargo_Green_RF", "Land_FoodSacks_01_cargo_brown_F",
            "CargoNet_01_barrels_F", "Land_WaterBarrel_F", "Land_TTowerSmall_2_F",
            "Land_BarrelTrash_grey_F", "Land_CampingChair_V1_F", "Metal_Locker_F",
            "Land_Sofa_01_F", "Fridge_01_closed_F", "Land_WaterCooler_01_new_F",
            "Land_FlowerPot_01_Flower_F", "Land_ToiletBox_F", "Land_WaterTank_F",
            "Land_Shoot_House_Wall_Long_F", "Land_Shoot_House_Wall_F",
            "Land_MetalBarrel_F", "Land_MetalBarrel_empty_F",
            "Land_MedicalTent_01_NATO_generic_closed_F", "Land_TentA_F",
            "Land_TentDome_F", "Land_TentSolar_01_folded_olive_F",
            "Land_TentSolar_01_folded_sand_F", "gm_gc_tent_5x5m"
        ];
        missionNamespace setVariable ["FAC_param_buildCatalog", 0];
        if (isClass (configFile >> "CfgVehicles" >> "Land_WallSign_01_F")) then {
            private _signBack = ["Land_WallSign_01_F"] call FADE_build_findEntry;
            if (_signBack isEqualTo []) then { _realOk = false };
        };
        if (_realOk) then {
            _pass = _pass + 1;
            diag_log "[FAC TestSuite] PASS (server): build realistic list";
        } else {
            _fail = _fail + 1;
            diag_log "[FAC TestSuite] FAIL (server): build realistic list";
        };

        private _gearEntry = ["gear"] call FADE_build_findBase;
        private _barEntry = ["barracks"] call FADE_build_findBase;
        private _vehEntry = ["vehicles"] call FADE_build_findBase;
        private _medEntry = ["medical"] call FADE_build_findBase;
        private _baseRowsOk = !(_gearEntry isEqualTo []) && { !(_barEntry isEqualTo []) } && { !(_vehEntry isEqualTo []) };
        if (_baseRowsOk) then {
            _baseRowsOk = (_gearEntry select 0) == (_barEntry select 0)
                && { (_gearEntry select 0) == (_vehEntry select 0) }
                && { (_gearEntry param [7, ""]) == "gear" }
                && { (_barEntry param [7, ""]) == "barracks" }
                && { (_vehEntry param [7, ""]) == "vehicles" };
            if (isClass (configFile >> "CfgVehicles" >> "Land_MedicalTent_01_MTP_closed_F")) then {
                _baseRowsOk = _baseRowsOk && { !(_medEntry isEqualTo []) }
                    && { (_medEntry param [7, ""]) == "medical" }
                    && { (_medEntry select 0) != (_gearEntry select 0) };
            };
        };
        if !(isClass (configFile >> "CfgVehicles" >> "Land_MedicalTent_01_NATO_generic_closed_F")) then {
            diag_log "[FAC TestSuite] SKIP (server): build base rows (tent class missing)";
        } else {
            if (_baseRowsOk) then {
                _pass = _pass + 1;
                diag_log "[FAC TestSuite] PASS (server): build base rows keep separate roles";
            } else {
                _fail = _fail + 1;
                diag_log "[FAC TestSuite] FAIL (server): build base rows keep separate roles";
            };
        };

        if (_baseRowsOk) then {
            missionNamespace setVariable ["FAC_param_buildRequire", 1];
            missionNamespace setVariable ["FAC_param_buildArea", 1];
            private _gearPos = [(_buildBase select 0) + 24, (_buildBase select 1) + 24, 0];
            private _barPos = [(_buildBase select 0) + 32, (_buildBase select 1) + 24, 0];
            private _gearPlaced = [_buildUnit, _gearEntry select 0, _gearPos, 0, [0, 0, 1], false, true, true, false, "gear"] call FADE_build_place;
            private _svc = missionNamespace getVariable ["FADE_build_services", []];
            private _gearOnly = _gearPlaced && { "gear" in _svc } && { !("barracks" in _svc) };
            private _farLand = [];
            for "_k" from 0 to 6 do {
                private _tryFar = [(_buildBase select 0) + 1400 + (_k * 80), (_buildBase select 1) + 80, 0];
                if (([_gearEntry select 0, _tryFar, 0, objNull] call FADE_build_spotBlocked) == "") exitWith { _farLand = _tryFar };
            };
            private _farDenied = true;
            if !(_farLand isEqualTo []) then {
                private _farPlaced = [_buildUnit, _barEntry select 0, _farLand, 0, [0, 0, 1], false, true, true, false, "barracks"] call FADE_build_place;
                _farDenied = !_farPlaced && { !("barracks" in (missionNamespace getVariable ["FADE_build_services", []])) };
            } else {
                diag_log "[FAC TestSuite] SKIP (server): build base outside radius (no dry spot)";
            };
            private _barPlaced = [_buildUnit, _barEntry select 0, _barPos, 0, [0, 0, 1], false, true, true, false, "barracks"] call FADE_build_place;
            private _both = missionNamespace getVariable ["FADE_build_services", []];
            private _bothUp = _barPlaced && { "gear" in _both } && { "barracks" in _both };
            private _gearId = "";
            {
                private _rec = FADE_build_registry getOrDefault [_x, createHashMap];
                if ((_rec getOrDefault ["role", ""]) == "gear") exitWith { _gearId = _x };
            } forEach (keys FADE_build_registry);
            private _gearObj = if (_gearId == "") then { objNull } else { _gearId call BIS_fnc_objectFromNetId };
            private _roleVar = (!isNull _gearObj) && { (_gearObj getVariable ["FADE_build_role", ""]) == "gear" };
            private _removed = if (_gearId == "") then { false } else { [_buildUnit, _gearId] call FADE_build_remove };
            private _after = missionNamespace getVariable ["FADE_build_services", []];
            private _split = _removed && { !("gear" in _after) } && { "barracks" in _after };
            missionNamespace setVariable ["FAC_param_buildArea", 0];
            if (_gearOnly && { _farDenied } && { _bothUp } && { _roleVar } && { _split }) then {
                _pass = _pass + 1;
                diag_log "[FAC TestSuite] PASS (server): build base services follow radius and role";
            } else {
                _fail = _fail + 1;
                diag_log format [
                    "[FAC TestSuite] FAIL (server): build base services gearOnly=%1 far=%2 both=%3 role=%4 split=%5",
                    _gearOnly, _farDenied, _bothUp, _roleVar, _split
                ];
            };
            [] call FADE_build_clearAll;
        };

        missionNamespace setVariable ["FAC_param_buildRequire", 1];
        missionNamespace setVariable ["FADE_build_services", []];
        private _savedRecruitAccess = missionNamespace getVariable ["FAC_param_recruitGuiAccess", 0];
        private _savedVehicleAccess = missionNamespace getVariable ["FAC_param_vehicleGuiAccess", 0];
        missionNamespace setVariable ["FAC_param_recruitGuiAccess", 0];
        missionNamespace setVariable ["FAC_param_vehicleGuiAccess", 0];
        private _deniedRole = "";
        private _reasonCalls = 0;
        private _savedDeny = FAC_build_denyService;
        private _savedReason = FADE_vehiclePlacement_reason;
        FAC_build_denyService = {
            params ["_player", "_role"];
            _deniedRole = _role;
            true
        };
        [_buildUnit, "", "rifle"] call FADE_recruit_spawnUnit;
        private _recruitDenied = _deniedRole == "barracks";
        _deniedRole = "";
        FADE_vehiclePlacement_reason = {
            _reasonCalls = _reasonCalls + 1;
            "blocked"
        };
        ["B_Quadbike_01_F", _buildUnit, [0, 0, 0], 0] call FADE_spawnVehicleAtPos;
        private _vehicleDenied = _deniedRole == "vehicles" && { _reasonCalls == 0 };
        FAC_build_denyService = _savedDeny;
        FADE_vehiclePlacement_reason = _savedReason;
        missionNamespace setVariable ["FAC_param_recruitGuiAccess", _savedRecruitAccess];
        missionNamespace setVariable ["FAC_param_vehicleGuiAccess", _savedVehicleAccess];
        missionNamespace setVariable ["FAC_param_buildRequire", 0];
        if (_recruitDenied && { _vehicleDenied }) then {
            _pass = _pass + 1;
            diag_log "[FAC TestSuite] PASS (server): build service denies recruit and vehicle spawn";
        } else {
            _fail = _fail + 1;
            diag_log format [
                "[FAC TestSuite] FAIL (server): build service denies recruit=%1 vehicle=%2 role=%3",
                _recruitDenied, _vehicleDenied, _deniedRole
            ];
        };

        {
            if (_x getVariable ["FADE_build_placed", false] && { !((netId _x) in _buildBeforeIds) }) then {
                private _id = netId _x;
                FADE_build_registry deleteAt _id;
                deleteVehicle _x;
            };
        } forEach (nearestObjects [_buildBase, ["All"], 2500]) + (nearestObjects [[0, 0, 0], ["All"], 30]);
        {
            private _id = _x;
            if !(_id in _buildBeforeIds) then {
                private _left = _id call BIS_fnc_objectFromNetId;
                if (!isNull _left) then { deleteVehicle _left };
                FADE_build_registry deleteAt _id;
            };
        } forEach (+ (keys FADE_build_registry));
        deleteVehicle _buildUnit;
    };
    deleteGroup _buildGrp;
    missionNamespace setVariable ["FAC_param_buildAccess", _buildSavedAccess];
    missionNamespace setVariable ["FAC_param_buildLogistics", _buildSavedLog];
    missionNamespace setVariable ["FAC_param_buildArea", _buildSavedArea];
    missionNamespace setVariable ["FAC_param_buildCatalog", _buildSavedCatalog];
    missionNamespace setVariable ["FAC_param_buildRequire", _buildSavedRequire];
    missionNamespace setVariable ["FADE_buildSupply", _buildSavedSupply];
    publicVariable "FADE_buildSupply";

    // Map teleport's onMapSingleClick string looks these up in missionNamespace after the click.
    private _mapPickSrc = preprocessFileLineNumbers "rsc\TeleportMapPick.sqf";
    if (isNil "FAC_ensureTeleportGui") then {
        call compile preprocessFileLineNumbers "rsc\FAC_ClientGuiEnsure.sqf";
    };
    call FAC_ensureTeleportGui;
    private _tpAdd = missionNamespace getVariable ["FAC_teleport_fnc_addReturnToBase", nil];
    private _tpBack = missionNamespace getVariable ["FAC_teleport_fnc_returnToBase", nil];
    _ok = (_mapPickSrc find "call FAC_ensureTeleportGui") >= 0
        && { _tpAdd isEqualType {} }
        && { _tpBack isEqualType {} };
    if (_ok) then {
        _pass = _pass + 1;
        diag_log "[FAC TestSuite] PASS (server): map teleport return-to-base is in missionNamespace";
    } else {
        _fail = _fail + 1;
        diag_log "[FAC TestSuite] FAIL (server): map teleport return-to-base is in missionNamespace";
    };

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
        "FAC_ensureCQBGui",
        "FAC_ensureFiresGui",
        "FAC_ensureTeleportGui",
        "FAC_ensureRangeGui",
        "FAC_ensureSniperGui",
        "FAC_ensureCivTalkGui",
        "FAC_ensureMedicalTrainingGui",
        "FAC_ensureRecruitGui",
        "FAC_ensureBuildGui"
    ];

    private _fncNames = [
        "FADE_showMissionHint",
        "FADE_normalizeScenarioFactions",
        "FADE_scenarioFactionsDescribeIssue",
        "FADE_getPlayableFactions",
        "FADE_getOpposedSideNums",
        "FADE_isScenarioFriendlyUnit",
        "FADE_requestScenarioFriendlySideSync",
        "FADE_applyMissionSlotsClientSync",
        "FADE_aiSideChat_exec",
        "FAC_playerCanUseMissionsGui",
        "FAC_playerCanUseScenarioGui",
        "FAC_playerCanUseVehicleGui",
        "FAC_playerCanUseLoadoutGui",
        "FAC_playerCanUseScenarioAdmin",
        "FAC_playerCanUseDebugTools",
        "FAC_playerCanTeleportToPlayers",
        "FAC_lobbyParams_callAccess",
        "FAC_lobbyParams_serverDenyUnless",
        "FAC_ensureLobbyParams",
        "FAC_guiScheduleHeaderRefresh",
        "FAC_clientInstallBoardActions",
        "FAC_aceSelf_install",
        "FAC_aceSelf_nearPlayerBase",
        "FAC_aceSelf_myVehicle",
        "FAC_hqHeal_applyLocal",
        "FAC_addScenarioActionToTerminal",
        "FAC_vehicleGui_fnc",
        "FAC_missionsGui_fnc",
        "FAC_missionLocationPickGui_fnc",
        "FAC_troopInsertPickGui_fnc",
        "FAC_escapeEvasionPickGui_fnc",
        "FAC_geoGuesserPickGui_fnc",
        "FAC_pointDefensePickGui_fnc",
        "FADE_ggClient_beginRound",
        "FADE_ggClient_closeMissionGui",
        "FADE_ggClient_forceStop",
        "FADE_ggClient_showResults",
        "FAC_scenarioGui_fnc",
        "FAC_loadoutGui_fnc",
        "FADE_civCarRadio_clientPlay",
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
        "FAC_teleport_fnc_addReturnToBase",
        "FAC_teleport_fnc_returnToBase",
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
        "FADE_recover_clientRegisterHold",
        "FADE_intel_clientAppendIntelDiary",
        "FADE_showMissionAssignedIntro",
        "FAC_ensureLoadoutGui",
        "FAC_ensureVehicleGui",
        "FAC_ensureMissionsGui",
        "FAC_ensureScenarioGui",
        "FAC_ensureCQBGui",
        "FAC_ensureFiresGui",
        "FAC_ensureTeleportGui",
        "FAC_ensureRangeGui",
        "FAC_ensureSniperGui",
        "FAC_ensureCivTalkGui",
        "FAC_ensureMedicalTrainingGui",
        "FAC_ensureRecruitGui",
        "FAC_ensureBuildGui",
        "FAC_buildGui_fnc",
        "FAC_buildSignGui_fnc",
        "FAC_build_clientAddRemove",
        "FAC_build_clientScan"
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
        "rsc\FAC_CivCarRadio.sqf",
        "rsc\CQBGui.sqf",
        "rsc\FiresGui.sqf",
        "rsc\TeleportGui.sqf",
        "rsc\TeleportMapPick.sqf",
        "rsc\RangeGui.sqf",
        "rsc\SniperGui.sqf",
        "rsc\CivTalkGui.sqf",
        "rsc\MedicalTrainingGui.sqf",
        "rsc\BuildGui.sqf",
        "rsc\BuildSignGui.sqf",
        "rsc\BuildCatalog.sqf",
        "rsc\BuildCommon.sqf",
        "rsc\MissionLocationPickGui.sqf",
        "rsc\MissionMapPick.sqf",
        "rsc\MissionMapPick_exec.sqf",
        "rsc\MissionRaidMapPick.sqf",
        "rsc\MissionRaidMapPick_exec.sqf",
        "rsc\MissionConvoyMapPick.sqf",
        "rsc\MissionConvoyMapPick_exec.sqf",
        "rsc\TroopInsertPickGui.sqf",
        "rsc\PointDefensePickGui.sqf",
        "rsc\EscapeEvasionPickGui.sqf",
        "rsc\GeoGuesserPickGui.sqf",
        "rsc\GeoGuesserClient.sqf",
        "rsc\MissionPickOverlay.sqf",
        "rsc\FAC_ClientBoardActions.sqf",
        "rsc\FADE_RecoverObjectClient.sqf",
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

    // @CTB - Mission Sounds Library (ambient civ car radio OGGs in Sig_CTB_MSL_Music_Loudspeaker.pbo)
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
