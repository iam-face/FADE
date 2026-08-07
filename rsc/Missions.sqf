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
// pickMeta (7th): [rawClick, resolvedAnchor, snappedCenter, resolvedRadius, convoyEndRaw, convoyEndResolved, raidZoneClicks] — per-mission, not missionNamespace globals.
if (isNil "FADE_missionParams" || { count FADE_missionParams < 3 }) exitWith {};
FADE_missionParams params ["_missionType", "_destPos", ["_player", objNull], ["_evadeePlayers", []], ["_fromMapClick", false], ["_pickMeta", []]];
private _rawAnchor = _pickMeta param [0, []];
private _mapAnchor = _pickMeta param [1, []];
private _snappedCenter = _pickMeta param [2, []];
private _resolvedRadius = _pickMeta param [3, -1];
private _convoyEndRaw = _pickMeta param [4, []];
private _convoyEndAnchor = _pickMeta param [5, []];
private _raidZoneClicks = _pickMeta param [6, []];
if (!([_mapAnchor] call FADE_fnc_isValidMapClickPos)) then {
    _mapAnchor = if (_fromMapClick) then { +_destPos } else { [] };
    _fromMapClick = [_mapAnchor] call FADE_fnc_isValidMapClickPos;
};
if (!isServer) exitWith {};

// Validate mission type (Global + Single types)
private _validTypes = ["TroopInsert", "TroopExtract", "CAS", "Cargo", "HVT", "Hostage", "ClearArea", "InterceptConvoy", "AreaOfOperations", "MineClearing", "CASEVAC", "CSAR", "AssetRetrieval", "SearchDestroy", "Operation", "Raid", "Invasion", "EscapeEvasion", "GeoGuesser", "PointDefense"];
if !(_missionType in _validTypes) exitWith {
    if (!isNull _player) then { _player setVariable ["FADE_myMission", "", true] };
    [_player, "MISSION ERROR", "Unknown mission type."] call FADE_missionErrorHint;
};
if (_missionType in (missionNamespace getVariable ["FADE_disabledMissionTypes", []])) exitWith {
    if (!isNull _player) then { [_player] call FADE_clearActiveMission };
    private _lbl = [_missionType] call (missionNamespace getVariable ["FADE_missionTypeDisplayName", { _this select 0 }]);
    [_player, "MISSION UNAVAILABLE", format ["%1 is temporarily disabled.", _lbl]] call FADE_missionErrorHint;
};
if (_missionType == "EscapeEvasion" && { count _evadeePlayers == 0 }) exitWith {
    if (!isNull _player) then { [_player] call FADE_clearActiveMission };
    [_player, "MISSION ERROR", "No evadees for Escape &amp; Evasion."] call FADE_missionErrorHint;
};
if (_missionType == "GeoGuesser" && { count _evadeePlayers == 0 }) exitWith {
    if (!isNull _player) then { [_player] call FADE_clearActiveMission };
    [_player, "MISSION ERROR", "No participants for Geo-Guesser."] call FADE_missionErrorHint;
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
    [_player, "MISSION ERROR", "No friendly units configured."] call FADE_missionErrorHint;
};
private _factionIssueRun = [
    missionNamespace getVariable ["FADE_scenarioFriendlyFaction", "BLU_F"],
    missionNamespace getVariable ["FADE_scenarioEnemyFaction", "OPF_F"]
] call FADE_scenarioFactionsDescribeIssue;
if (_factionIssueRun != "") exitWith {
    if (!isNull _player) then { _player setVariable ["FADE_myMission", "", true] };
    [_player, "SCENARIO ERROR", "Friendly and enemy factions are incompatible. Update Manage Scenario → Factions."] call FADE_missionErrorHint;
};
private _needsEnemyUnits = _missionType in ["TroopExtract", "CAS", "HVT", "Hostage", "ClearArea", "InterceptConvoy", "AreaOfOperations", "CASEVAC", "CSAR", "AssetRetrieval", "SearchDestroy", "Operation", "Raid", "Invasion", "EscapeEvasion", "PointDefense"];
if (_needsEnemyUnits && { count _enemyUnits == 0 }) exitWith {
    if (!isNull _player) then { _player setVariable ["FADE_myMission", "", true] };
    [_player, "MISSION ERROR", "No enemy units configured for the chosen enemy faction."] call FADE_missionErrorHint;
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

// Appended to FADE_myMissionBrief
private _briefGuiTail = toString [10] + toString [10] + "See Tasks and map markers for grids, routes, and win/fail criteria.";
private _mkrJitter = missionNamespace getVariable ["FADE_jitterMarkerPos", { params [["_p", [0, 0, 0]]]; [_p] call FADE_normPos3 }];
private _enemyFactionClass = missionNamespace getVariable ["FADE_scenarioEnemyFaction", "OPF_F"];
private _enemyFactionName = [_enemyFactionClass] call (missionNamespace getVariable ["FADE_getFactionDisplayName", { _this select 0 }]);
private _zeroAlphaDisplayName = [] call (missionNamespace getVariable ["FADE_getZeroAlphaDisplayName", { "UNASSIGNED" }]);

private _showAssignedHint = {
    params [["_missionHtml", ""], ["_situationHtml", ""], ["_executionHtml", ""], ["_adminHtml", ""], ["_commandHtml", ""]];
    private _hintTarget = if (_isGlobalMission) then { 0 } else { _player };
    private _starterName = if (isNull _player) then { "Unknown" } else { name _player };
    if (_loreShort != "") then {
        [_operationNameUpper, _starterName, _loreShort] remoteExec ["FADE_showMissionAssignedIntro", _hintTarget];
    } else {
        [_operationNameUpper, _starterName] remoteExec ["FADE_showMissionAssignedIntro", _hintTarget];
    };
    if (_loreLong != "") then {
        private _whenStr = format ["Mission start +%1 min", floor (time / 60) max 0];
        [_operationName, _whenStr, _loreLong, "Background"] remoteExec ["FADE_client_appendMissionBackground", _hintTarget];
    };
};
private _basePos = FADE_basePos;

// Refine position: LZ missions use small refinement; HVT/ClearArea/InterceptConvoy handle position themselves
private _needsLZ = _missionType in ["TroopInsert", "TroopExtract", "Cargo", "CASEVAC", "CSAR"];
if (_missionType != "HVT" && { _missionType != "Hostage" } && { _missionType != "ClearArea" } && { _missionType != "InterceptConvoy" } && { _missionType != "AreaOfOperations" } && { _missionType != "SearchDestroy" } && { _missionType != "Operation" } && { _missionType != "Raid" } && { _missionType != "Invasion" } && { _missionType != "AssetRetrieval" } && { _missionType != "MineClearing" } && { _missionType != "EscapeEvasion" } && { _missionType != "GeoGuesser" } && { _missionType != "PointDefense" }) then {
    private _refineMax = if (_needsLZ) then { 10 } else { 50 };
    private _refineObj = if (_needsLZ) then { 15 } else { 5 };
    _destPos = [[_destPos, 0, _refineMax, _refineObj, 1, 0.5, 0, [], _destPos], _destPos] call FADE_findSafePosArray;
};
if ((!(_destPos isEqualType []) || { count _destPos < 2 }) && { _missionType != "InterceptConvoy" } && { _missionType != "AreaOfOperations" } && { _missionType != "Operation" } && { _missionType != "Raid" } && { _missionType != "Invasion" } && { _missionType != "GeoGuesser" }) exitWith {
    if (!isNull _player) then { _player setVariable ["FADE_myMission", "", true] };
    [_player, "MISSION ERROR", "No valid area of operations found."] call FADE_missionErrorHint;
};

// Bootstrap SMEAC from anchor _destPos; runners that resolve a different objective refresh at task creation.
private _loreShort = "";
private _loreLong = "";
private _loreSmeacHtml = "";
if (!isNil "FADE_lore_generate") then {
    private _loreResult = [_missionType, _destPos, _operationName] call FADE_lore_generate;
    if (_loreResult isEqualType [] && { count _loreResult >= 3 }) then {
        _loreResult params ["_ls", "_ldiary", "_lsmeac"];
        _loreShort = _ls;
        _loreLong = _ldiary;
        _loreSmeacHtml = _lsmeac;
    };
};

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

if (_loreSmeacHtml != "") then {
    _defaultSituationHintHtml = _defaultSituationHintHtml + format [
        "<br/><br/><t align='left' color='#8BA4BE'>%1</t>",
        _loreLong
    ];
};
_defaultSituationTaskText = _defaultSituationHtml;

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
        ["_executionOverride", ""],
        ["_omitAppendedTopography", false]
    ];
    private _withholdGrid = _omitAppendedTopography;
    private _sf = missionNamespace getVariable ["FADE_sideFriendly", west];
    private _taskBuilder = missionNamespace getVariable ["FADE_buildMissionTaskSmeacText", {}];
    private _sitT = _defaultSituationHtml;
    if (_sitT isEqualTo "") then { _sitT = _defaultSituationTaskText };
    private _execT = _defaultExecutionTaskText;
    // Custom situation overrides (Raid, Asset Retrieval, etc.) already embed correct topography.
    if (_situationOverride isEqualTo "" && { _pos isEqualType [] } && { count _pos >= 2 }) then {
        private _refreshFn = missionNamespace getVariable ["FADE_missionRefreshBriefingAtPos", {}];
        if (!(_refreshFn isEqualTo {})) then {
            private _ref = [
                _missionType, _pos, _sideFriendly, _sideEnemy, _enemyFactionName, _zeroAlphaDisplayName, _operationName
            ] call _refreshFn;
            if (count _ref > 0) then {
                _sitT = _ref getOrDefault ["defaultSituationTaskText", _sitT];
                private _newLoreShort = _ref getOrDefault ["loreShort", ""];
                private _newLoreLong = _ref getOrDefault ["loreLong", ""];
                private _newLoreSmeac = _ref getOrDefault ["loreSmeacHtml", ""];
                if (_newLoreShort != "") then { _loreShort = _newLoreShort };
                if (_newLoreLong != "") then { _loreLong = _newLoreLong };
                if (_newLoreSmeac != "") then {
                    _loreSmeacHtml = _newLoreSmeac;
                    missionNamespace setVariable ["FADE_missionRun_loreSmeacHtml", _newLoreSmeac];
                };
                _topographyGrid = _ref getOrDefault ["topographyGrid", _topographyGrid];
                _topographyArea = _ref getOrDefault ["topographyArea", _topographyArea];
                missionNamespace setVariable ["FADE_missionRun_topographyGrid", _topographyGrid];
                missionNamespace setVariable ["FADE_missionRun_topographyArea", _topographyArea];
                _defaultSituationHtml = _sitT;
                _defaultSituationTaskText = _sitT;
            };
        };
    };
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
            _defaultCommandTaskText,
            _omitAppendedTopography
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
    missionNamespace setVariable ["FADE_missionRun_convoyEndRaw", _convoyEndRaw];
    missionNamespace setVariable ["FADE_missionRun_convoyEndAnchor", _convoyEndAnchor];
    missionNamespace setVariable ["FADE_missionRun_raidZoneClicks", _raidZoneClicks];
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
    missionNamespace setVariable ["FADE_missionRun_loreShort", _loreShort];
    missionNamespace setVariable ["FADE_missionRun_loreLong", _loreLong];
    missionNamespace setVariable ["FADE_missionRun_loreSmeacHtml", _loreSmeacHtml];
    missionNamespace setVariable ["FADE_mission_createTask", _fnc_createMissionTask];
    missionNamespace setVariable ["FADE_mission_showAssignedHint", _showAssignedHint];

    private _runner = missionNamespace getVariable [format ["FADE_runMission_%1", _missionType], {}];
    if (_runner isEqualType {} && { !(_runner isEqualTo {}) }) exitWith { call _runner };

    if (!isNull _player) then { [_player] call FADE_clearActiveMission };
    [_player, "MISSION ERROR", "No mission runner installed for this type."] call FADE_missionErrorHint;
};
