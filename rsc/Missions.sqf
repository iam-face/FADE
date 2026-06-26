// =============================================================================
// Missions.sqf -- Dynamic mission implementations (runs on server; compiled from initServer FADE_startMission)
// =============================================================================
//
// EXECUTION: Invoked via spawn+compile from FADE_startMission (server). Params from FADE_missionParams
//   (set in the same spawn before compile - avoids cross-player races with execVM queue).
// _missionType: "TroopInsert" | "TroopExtract" | "CAS" | "Cargo" | "HVT" | "Hostage" | "ClearArea" | "InterceptConvoy" | ...
// _destPos: position array [x,y,z] -- from FADE_startMission (Asset Retrieval / Mine Clearing anchor: within 500 m of a civ zone centre; hazards spawn on roads near anchor; others: see initServer)
// _player: player who started the mission (for tasks, cargo seat check). Assigned intro: FADE_showMissionAssignedIntro
//   (typeText + Task hint)  -  all clients for global mission types; starter only for single types. Full SMEAC on BI Task only.
//
// SCENARIO: Unit/vehicle lists come from missionNamespace (Scenario GUI Apply or initServer defaults).
// All enemy spawns MUST use FADE_enemyUnits (or local list built from missionNamespace + FADE_scenarioEnemyFaction
// fallback) so faction choices in the config GUI are respected. Do not use BIS_fnc_spawnCrew for vehicles - spawn
// driver/gunner/commander from the scenario enemy unit list so crew matches the chosen faction.
// All createVehicle/createGroup/BIS_fnc_spawnGroup run on server; markers and tasks are server-global.
// =============================================================================
// Dispatcher: compiled once at server boot (FADE_installMissionModules).
FADE_runMission = {
// Params from FADE_missionParams (set by FADE_startMission / FADE_startEscapeEvasion before compile)
// pickMeta (6th): [rawClick, resolvedAnchor, snappedCenter, resolvedRadius] — per-mission, not missionNamespace globals.
if (isNil "FADE_missionParams" || { count FADE_missionParams < 3 }) exitWith {};
FADE_missionParams params ["_missionType", "_destPos", ["_player", objNull], ["_evadeePlayers", []], ["_fromMapClick", false], ["_pickMeta", []]];
private _rawAnchor = _pickMeta param [0, []];
private _mapAnchor = _pickMeta param [1, []];
private _snappedCenter = _pickMeta param [2, []];
private _resolvedRadius = _pickMeta param [3, -1];
if (!([_mapAnchor] call FADE_fnc_isValidMapClickPos)) then {
    _mapAnchor = if (_fromMapClick) then { +_destPos } else { [] };
    _fromMapClick = [_mapAnchor] call FADE_fnc_isValidMapClickPos;
};
if (!isServer) exitWith {};

// Validate mission type (Global + Single types)
private _validTypes = ["TroopInsert", "TroopExtract", "CAS", "Cargo", "HVT", "Hostage", "ClearArea", "InterceptConvoy", "AreaOfOperations", "MineClearing", "CASEVAC", "CSAR", "AssetRetrieval", "SearchDestroy", "Operation", "EscapeEvasion", "GeoGuesser"];
if !(_missionType in _validTypes) exitWith {
    if (!isNull _player) then { _player setVariable ["FADE_myMission", "", true] };
    ["<t size='1.2' color='#FF6666'>MISSION ERROR</t><br/><br/><t color='#E0E0E0'>Unknown mission type.</t>"] remoteExec ["FADE_showMissionHint", _player];
};
if (_missionType == "EscapeEvasion" && { count _evadeePlayers == 0 }) exitWith {
    if (!isNull _player) then { [_player] call FADE_clearActiveMission };
    ["<t size='1.2' color='#FF6666'>MISSION ERROR</t><br/><br/><t color='#E0E0E0'>No evadees for Escape &amp; Evasion.</t>"] remoteExec ["FADE_showMissionHint", _player];
};
if (_missionType == "GeoGuesser" && { count _evadeePlayers == 0 }) exitWith {
    if (!isNull _player) then { [_player] call FADE_clearActiveMission };
    ["<t size='1.2' color='#FF6666'>MISSION ERROR</t><br/><br/><t color='#E0E0E0'>No participants for Geo-Guesser.</t>"] remoteExec ["FADE_showMissionHint", _player];
};

// Single source: scenario-applied unit lists (initServer FADE_resolveScenario* helpers)
private _friendlyUnits = [] call FADE_resolveScenarioFriendlyUnits;
private _enemyUnits = [] call FADE_resolveScenarioEnemyUnits;
private _sideFriendly = missionNamespace getVariable ["FADE_sideFriendly", west];
private _sideEnemy = missionNamespace getVariable ["FADE_sideEnemy", east];
private _markerFriendly = missionNamespace getVariable ["FADE_markerColorFriendly", "ColorWEST"];
private _markerEnemy = missionNamespace getVariable ["FADE_markerColorEnemy", "ColorEAST"];
private _dryPos = missionNamespace getVariable ["FADE_surfaceIsDry", { params ["_p"]; count _p >= 2 && { !surfaceIsWater [_p select 0, _p select 1] } }];
private _fallbackEnemyInf = +(missionNamespace getVariable ["FADE_fallbackEnemyUnits", ["O_Soldier_TL_F", "O_Soldier_F", "O_Soldier_AR_F"]]);
if (count _friendlyUnits == 0) exitWith {
    if (!isNull _player) then { _player setVariable ["FADE_myMission", "", true] };
    ["<t size='1.2' color='#FF6666'>MISSION ERROR</t><br/><br/><t color='#E0E0E0'>No friendly units configured.</t>"] remoteExec ["FADE_showMissionHint", _player];
};

private _isGlobalMission = _missionType in (missionNamespace getVariable ["FADE_globalMissionTypes", []]);

// Mission-assigned hint is sent per mission type below (formatted; broadcast for global, starter only for single)
private _taskId = "FADE_" + _missionType + str (floor (time * 1000));
if (!isNull _player) then {
    _player setVariable ["FADE_myMission", _missionType, true];
    _player setVariable ["FADE_myMissionTaskId", _taskId, true];
};
[_taskId] call FADE_missionEnt_init;
private _operationName = "Operation Iron Resolve";
if (!isNull _player) then {
    private _playerUid = getPlayerUID _player;
    private _globalEntry = missionNamespace getVariable ["FADE_globalMission", []];
    if (
        count _globalEntry >= 5 &&
        { (_globalEntry param [0, ""]) == _missionType } &&
        {
            (_globalEntry param [1, objNull]) == _player ||
            { (_globalEntry param [3, ""]) == _playerUid }
        }
    ) then {
        _operationName = _globalEntry param [4, _operationName];
    } else {
        private _singleList = missionNamespace getVariable ["FADE_singleMissions", []];
        private _singleIdx = _singleList findIf {
            (_x param [0, ""]) == _missionType &&
            {
                (_x param [1, objNull]) == _player ||
                { (_x param [3, ""]) == _playerUid }
            }
        };
        if (_singleIdx >= 0) then {
            _operationName = (_singleList select _singleIdx) param [4, _operationName];
        };
    };
};
private _operationNameUpper = toUpper _operationName;
// Appended to FADE_myMissionBrief (Missions GUI description while mission runs): grid/intent only; task + markers hold execution detail.
private _briefGuiTail = toString [10] + toString [10] + "See your Tasks panel and map markers for objectives, routes, and completion criteria.";
private _mkrJitter = missionNamespace getVariable ["FADE_jitterMarkerPos", { params [["_p", [0, 0, 0]]]; [_p] call FADE_normPos3 }];
private _enemyFactionClass = missionNamespace getVariable ["FADE_scenarioEnemyFaction", "OPF_F"];
private _enemyFactionName = [_enemyFactionClass] call (missionNamespace getVariable ["FADE_getFactionDisplayName", { _this select 0 }]);
private _zeroAlphaDisplayName = [] call (missionNamespace getVariable ["FADE_getZeroAlphaDisplayName", { "UNASSIGNED" }]);

private _briefDefaults = [
    _missionType, _destPos, _sideFriendly, _sideEnemy, _enemyFactionName, _zeroAlphaDisplayName
] call (missionNamespace getVariable ["FADE_missionComputeBriefingDefaults", { createHashMap }]);
private _friendlyPlayerCount = _briefDefaults getOrDefault ["friendlyPlayerCount", 0];
private _friendlyFactionName = _briefDefaults getOrDefault ["friendlyFactionName", ""];
private _estimatedOpforCount = _briefDefaults getOrDefault ["estimatedOpforCount", 0];
private _opforCountFactor = _briefDefaults getOrDefault ["opforCountFactor", 1];
private _topographyGrid = _briefDefaults getOrDefault ["topographyGrid", "UNKNOWN"];
private _topographyArea = _briefDefaults getOrDefault ["topographyArea", "Unknown area"];
private _defaultSituationHtml = _briefDefaults getOrDefault ["defaultSituationHtml", ""];
private _defaultSituationHintHtml = _briefDefaults getOrDefault ["defaultSituationHintHtml", ""];
private _defaultExecutionHtml = _briefDefaults getOrDefault ["defaultExecutionHtml", ""];
private _defaultAdminHtml = _briefDefaults getOrDefault ["defaultAdminHtml", ""];
private _defaultCommandHtml = _briefDefaults getOrDefault ["defaultCommandHtml", ""];
private _defaultSituationTaskText = _briefDefaults getOrDefault ["defaultSituationTaskText", ""];
private _defaultExecutionTaskText = _briefDefaults getOrDefault ["defaultExecutionTaskText", ""];
private _defaultAdminTaskText = _briefDefaults getOrDefault ["defaultAdminTaskText", ""];
private _defaultCommandTaskText = _briefDefaults getOrDefault ["defaultCommandTaskText", ""];

private _showAssignedHint = {
    params [["_missionHtml", ""], ["_situationHtml", ""], ["_executionHtml", ""], ["_adminHtml", ""], ["_commandHtml", ""]];
    private _hintTarget = if (_isGlobalMission) then { 0 } else { _player };
    private _starterName = if (isNull _player) then { "Unknown" } else { name _player };
    [_operationNameUpper, _starterName] remoteExec ["FADE_showMissionAssignedIntro", _hintTarget];
};
private _basePos = FADE_basePos;

// Refine position: LZ missions use small refinement; HVT/ClearArea/InterceptConvoy handle position themselves
private _needsLZ = _missionType in ["TroopInsert", "TroopExtract", "Cargo", "CASEVAC", "CSAR"];
if (_missionType != "HVT" && { _missionType != "Hostage" } && { _missionType != "ClearArea" } && { _missionType != "InterceptConvoy" } && { _missionType != "AreaOfOperations" } && { _missionType != "SearchDestroy" } && { _missionType != "Operation" } && { _missionType != "AssetRetrieval" } && { _missionType != "MineClearing" } && { _missionType != "EscapeEvasion" } && { _missionType != "GeoGuesser" }) then {
    private _refineMax = if (_needsLZ) then { 10 } else { 50 };
    private _refineObj = if (_needsLZ) then { 15 } else { 5 };
    _destPos = [[_destPos, 0, _refineMax, _refineObj, 1, 0.5, 0, [], _destPos], _destPos] call FADE_findSafePosArray;
};
if ((!(_destPos isEqualType []) || { count _destPos < 2 }) && { _missionType != "InterceptConvoy" } && { _missionType != "AreaOfOperations" } && { _missionType != "Operation" } && { _missionType != "GeoGuesser" }) exitWith {
    if (!isNull _player) then { _player setVariable ["FADE_myMission", "", true] };
    ["<t size='1.2' color='#FF6666'>MISSION ERROR</t><br/><br/><t color='#E0E0E0'>No valid area of operations found.</t>"] remoteExec ["FADE_showMissionHint", _player];
};

// Unit count: use player's vehicle cargo seats if in a heli, else default 6
private _unitCount = 6;
if (!isNull _player) then {
    private _veh = vehicle _player;
    if (_veh != _player && { _veh isKindOf "Helicopter" }) then {
        _unitCount = ([_veh] call FADE_getCargoSeats) max 1;
    };
};
private _unitClasses = (_friendlyUnits select [0, _unitCount min count _friendlyUnits]);
private _baseClass = _friendlyUnits select 0;
for "_i" from (count _unitClasses) to (_unitCount - 1) do {
    _unitClasses pushBack _baseClass;
};

// Task: BI task framework - create side-visible task so all players can review and join mission execution.
private _fnc_createMissionTask = {
    params [
        "_player",
        "_taskId",
        "_desc",
        "_title",
        "_pos",
        "_taskType",
        ["_situationOverride", ""],
        ["_executionOverride", ""]
    ];
    private _sf = missionNamespace getVariable ["FADE_sideFriendly", west];
    private _taskBuilder = missionNamespace getVariable ["FADE_buildMissionTaskSmeacText", {}];
    private _sitT = _defaultSituationTaskText;
    private _execT = _defaultExecutionTaskText;
    if !(_situationOverride isEqualTo "") then { _sitT = _situationOverride };
    if !(_executionOverride isEqualTo "") then { _execT = _executionOverride };
    private _taskDesc = if (_taskBuilder isEqualTo {}) then {
        _desc
    } else {
        [
            _desc,
            _pos,
            _sitT,
            _execT,
            _defaultAdminTaskText,
            _defaultCommandTaskText
        ] call _taskBuilder
    };
    [_sf, _taskId, [_taskDesc, _title, ""], _pos, "CREATED", 1, true, _taskType, true] call BIS_fnc_taskCreate;
};

// Scale OPFOR counts using scenario population setting.
private _scaleOpforCount = missionNamespace getVariable ["FADE_scaleOpforCount", {
    params ["_baseCount", ["_minCount", 1], ["_maxCount", -1]];
    private _base = floor (_baseCount max 0);
    if (_base <= 0) exitWith { 0 };
    private _scaled = _base max _minCount;
    if (_maxCount >= 0 && { _scaled > _maxCount }) then { _scaled = _maxCount };
    _scaled
}];

    [] call FADE_profile_missionRunMark;

    missionNamespace setVariable ["FADE_missionRun_missionType", _missionType];
    missionNamespace setVariable ["FADE_missionRun_destPos", _destPos];
    missionNamespace setVariable ["FADE_missionRun_player", _player];
    missionNamespace setVariable ["FADE_missionRun_evadeePlayers", _evadeePlayers];
    missionNamespace setVariable ["FADE_missionRun_fromMapClick", _fromMapClick];
    missionNamespace setVariable ["FADE_missionRun_mapAnchor", _mapAnchor];
    missionNamespace setVariable ["FADE_missionRun_mapPickRawAnchor", _rawAnchor];
    missionNamespace setVariable ["FADE_missionRun_mapPickSnappedCenter", _snappedCenter];
    missionNamespace setVariable ["FADE_missionRun_mapPickResolvedRadius", _resolvedRadius];
    missionNamespace setVariable ["FADE_missionRun_friendlyUnits", _friendlyUnits];
    missionNamespace setVariable ["FADE_missionRun_enemyUnits", _enemyUnits];
    missionNamespace setVariable ["FADE_missionRun_sideFriendly", _sideFriendly];
    missionNamespace setVariable ["FADE_missionRun_sideEnemy", _sideEnemy];
    missionNamespace setVariable ["FADE_missionRun_markerFriendly", _markerFriendly];
    missionNamespace setVariable ["FADE_missionRun_markerEnemy", _markerEnemy];
    missionNamespace setVariable ["FADE_missionRun_taskId", _taskId];
    missionNamespace setVariable ["FADE_missionRun_operationName", _operationName];
    missionNamespace setVariable ["FADE_missionRun_operationNameUpper", _operationNameUpper];
    missionNamespace setVariable ["FADE_missionRun_briefGuiTail", _briefGuiTail];
    missionNamespace setVariable ["FADE_missionRun_enemyFactionName", _enemyFactionName];
    missionNamespace setVariable ["FADE_missionRun_zeroAlphaDisplayName", _zeroAlphaDisplayName];
    missionNamespace setVariable ["FADE_missionRun_isGlobalMission", _isGlobalMission];
    missionNamespace setVariable ["FADE_missionRun_basePos", _basePos];
    missionNamespace setVariable ["FADE_missionRun_unitCount", _unitCount];
    missionNamespace setVariable ["FADE_missionRun_unitClasses", _unitClasses];
    missionNamespace setVariable ["FADE_missionRun_defaultSituationTaskText", _defaultSituationTaskText];
    missionNamespace setVariable ["FADE_missionRun_defaultExecutionTaskText", _defaultExecutionTaskText];
    missionNamespace setVariable ["FADE_missionRun_defaultAdminTaskText", _defaultAdminTaskText];
    missionNamespace setVariable ["FADE_missionRun_defaultCommandTaskText", _defaultCommandTaskText];
    missionNamespace setVariable ["FADE_missionRun_defaultSituationHtml", _defaultSituationHtml];
    missionNamespace setVariable ["FADE_missionRun_defaultSituationHintHtml", _defaultSituationHintHtml];
    missionNamespace setVariable ["FADE_missionRun_friendlyPlayerCount", _friendlyPlayerCount];
    missionNamespace setVariable ["FADE_missionRun_friendlyFactionName", _friendlyFactionName];
    missionNamespace setVariable ["FADE_missionRun_estimatedOpforCount", _estimatedOpforCount];
    missionNamespace setVariable ["FADE_missionRun_opforCountFactor", _opforCountFactor];
    missionNamespace setVariable ["FADE_missionRun_topographyGrid", _topographyGrid];
    missionNamespace setVariable ["FADE_missionRun_topographyArea", _topographyArea];
    missionNamespace setVariable ["FADE_mission_createTask", _fnc_createMissionTask];
    missionNamespace setVariable ["FADE_mission_showAssignedHint", _showAssignedHint];

    private _runner = missionNamespace getVariable [format ["FADE_runMission_%1", _missionType], {}];
    if (_runner isEqualType {} && { !(_runner isEqualTo {}) }) exitWith { call _runner };

    if (!isNull _player) then { [_player] call FADE_clearActiveMission };
    [_player, "MISSION ERROR", "No mission runner installed for this type."] call FADE_missionErrorHint;
};
