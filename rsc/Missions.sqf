// =============================================================================
// Missions.sqf -- Dynamic mission implementations (runs on server; compiled from initServer FADE_startMission)
// =============================================================================
//
// EXECUTION: Invoked via spawn+compile from FADE_startMission (server). Params from FADE_missionParams
//   (set in the same spawn before compile - avoids cross-player races with execVM queue).
// _missionType: "TroopInsert" | "TroopExtract" | "CAS" | "Cargo" | "HVT" | "Hostage" | "ClearArea" | "InterceptConvoy" | ...
// _destPos: position array [x,y,z] -- from FADE_startMission (Asset Retrieval / Mine Clearing anchor: within 500 m of a CIV_T_* zone; hazards spawn on roads near anchor; others: see initServer)
// _player: player who started the mission (for tasks, cargo seat check). Initial "MISSION ASSIGNED"
//   hint: all clients for global mission types; starter only for single types. Other feedback unchanged.
//
// SCENARIO: Unit/vehicle lists come from missionNamespace (Scenario GUI Apply or initServer defaults).
// All enemy spawns MUST use FADE_enemyUnits (or local list built from missionNamespace + FADE_scenarioEnemyFaction
// fallback) so faction choices in the config GUI are respected. Do not use BIS_fnc_spawnCrew for vehicles - spawn
// driver/gunner/commander from the scenario enemy unit list so crew matches the chosen faction.
// All createVehicle/createGroup/BIS_fnc_spawnGroup run on server; markers and tasks are server-global.
// =============================================================================

// Params from FADE_missionParams (set by FADE_startMission / FADE_startEscapeEvasion before compile)
if (isNil "FADE_missionParams" || { count FADE_missionParams < 3 }) exitWith {};
FADE_missionParams params ["_missionType", "_destPos", ["_player", objNull], ["_evadeePlayers", []]];
if (!isServer) exitWith {};

// Validate mission type (Global + Single types)
private _validTypes = ["TroopInsert", "TroopExtract", "CAS", "Cargo", "HVT", "Hostage", "ClearArea", "InterceptConvoy", "AreaOfOperations", "MineClearing", "CASEVAC", "CSAR", "AssetRetrieval", "SearchDestroy", "Operation", "EscapeEvasion"];
if !(_missionType in _validTypes) exitWith {
    if (!isNull _player) then { _player setVariable ["FADE_myMission", "", true] };
    ["<t size='1.2' color='#FF6666'>MISSION ERROR</t><br/><br/><t color='#E0E0E0'>Unknown mission type.</t>"] remoteExec ["FADE_showMissionHint", _player];
};
if (_missionType == "EscapeEvasion" && { count _evadeePlayers == 0 }) exitWith {
    if (!isNull _player) then { [_player] call FADE_clearActiveMission };
    ["<t size='1.2' color='#FF6666'>MISSION ERROR</t><br/><br/><t color='#E0E0E0'>No evadees for Escape &amp; Evasion.</t>"] remoteExec ["FADE_showMissionHint", _player];
};

// Single source: scenario-applied unit lists (initServer FADE_resolveScenario* helpers)
private _friendlyUnits = [] call FADE_resolveScenarioFriendlyUnits;
private _enemyUnits = [] call FADE_resolveScenarioEnemyUnits;
private _sideFriendly = missionNamespace getVariable ["FADE_sideFriendly", west];
private _sideEnemy = missionNamespace getVariable ["FADE_sideEnemy", east];
private _markerFriendly = missionNamespace getVariable ["FADE_markerColorFriendly", "ColorWEST"];
private _markerEnemy = missionNamespace getVariable ["FADE_markerColorEnemy", "ColorEAST"];
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
private _mkrJitter = missionNamespace getVariable ["FADE_jitterMarkerPos", { params [["_p", [0, 0, 0]]]; [_p] call FADE_normPos3 }];
private _enemyFactionClass = missionNamespace getVariable ["FADE_scenarioEnemyFaction", "OPF_F"];
private _enemyFactionName = getText (configFile >> "CfgFactionClasses" >> _enemyFactionClass >> "displayName");
if (_enemyFactionName == "") then { _enemyFactionName = _enemyFactionClass };
private _zeroAlphaObj = missionNamespace getVariable ["CTB_PILOT_1", objNull];
private _zeroAlphaDisplayName = if (isNull _zeroAlphaObj) then { "UNASSIGNED" } else { name _zeroAlphaObj };
if (_zeroAlphaDisplayName == "") then { _zeroAlphaDisplayName = "UNASSIGNED" };
missionNamespace setVariable ["FADE_countFriendlyPlayers", {
    params [["_friendlySide", west]];
    private _count = 0;
    {
        if (isPlayer _x && { side group _x == _friendlySide }) then { _count = _count + 1 };
    } forEach allPlayers;
    _count
}];
missionNamespace setVariable ["FADE_getAcreChannelSummary", {
    private _logic = objNull;
    {
        if (typeOf _x == "acre_api_nameChannels") exitWith { _logic = _x };
    } forEach (allMissionObjects "Logic");
    if (isNull _logic) exitWith { "ACRE channel names unavailable" };
    private _named = [];
    for "_i" from 1 to 10 do {
        private _ch = _logic getVariable [format ["Channel_%1", _i], ""];
        if !(_ch isEqualTo "") then { _named pushBack format ["CH%1 %2", _i, _ch] };
    };
    if (count _named == 0) then { "ACRE channel names unavailable" } else { _named joinString " | " }
}];
missionNamespace setVariable ["FADE_getTopographySummary", {
    params [["_pos", [0, 0, 0]]];
    private _grid = "UNKNOWN";
    private _areaName = "Unknown area";
    if (_pos isEqualType [] && { count _pos >= 2 }) then {
        _grid = mapGridPosition _pos;
        private _nearby = nearestLocations [_pos, ["NameCityCapital", "NameCity", "NameVillage", "NameLocal"], 3000];
        if (count _nearby > 0) then {
            private _name = text (_nearby select 0);
            if !(_name isEqualTo "") then { _areaName = _name };
        };
    };
    [_grid, _areaName]
}];
missionNamespace setVariable ["FADE_formatSituationIntelHtml", {
    params [
        "_missionType",
        "_destPos",
        "_sideEnemy",
        "_sideFriendly",
        "_estimatedOpforCount",
        "_opforCountFactor",
        "_enemyFactionDisplay",
        "_friendlyFactionDisplay",
        "_friendlyPlayerCount",
        "_topographyGrid",
        "_topographyArea",
        ["_bodyColorHex", ""]
    ];
    private _topoBodyCol = if (_bodyColorHex isEqualTo "") then { "#B0B0B0" } else { _bodyColorHex };
    private _bodyCol = if (_bodyColorHex isEqualTo "") then { "#A0A0A0" } else { _bodyColorHex };
    private _estQual = if (_opforCountFactor < 1) then { " (intel estimate leans minus)" } else { " (intel estimate leans plus)" };
    private _n = _estimatedOpforCount max 0;
    private _echelon = switch (true) do {
        case (_n <= 0): { "no confirmed dismounts pre-contact" };
        case (_n <= 3): { "contact / fire team (minus)" };
        case (_n <= 8): { "fire team to squad (minus)" };
        case (_n <= 15): { "squad (minus) to squad" };
        case (_n <= 28): { "squad to platoon (minus)" };
        case (_n <= 50): { "platoon (minus) to platoon" };
        case (_n <= 85): { "platoon to company (minus)" };
        case (_n <= 140): { "company (minus) to company" };
        default { "company (+) toward battalion-level footprint" };
    };
    private _launcherSet = missionNamespace getVariable ["FADE_opforLauncherSetting", "Normal"];
    private _atLine = switch (_launcherSet) do {
        case "None": { "Anti-armour: reporting suggests light handheld threat only; dedicated AT teams unlikely." };
        case "Minimal": { "Anti-armour: limited; occasional RPG-class weapons possible among dismounts." };
        case "Reduced": { "Anti-armour: present but assessed below full table of equipment." };
        default { "Anti-armour: expect RPG / light AT teams in the infantry mix." };
    };
    private _airSet = missionNamespace getVariable ["FADE_opforAirSetting", "Off"];
    private _airLine = if (_airSet isEqualTo "Off") then {
        "Hostile rotary-wing: low likelihood in current reporting; not a standing assumption for planning."
    } else {
        "Hostile rotary-wing: may be taskable against detected friendly activity — maintain awareness and stand-off where practical."
    };
    private _commsLine = if (_missionType in ["HVT", "Hostage", "ClearArea", "SearchDestroy", "CASEVAC", "CSAR", "Operation", "AreaOfOperations", "AssetRetrieval", "InterceptConvoy", "EscapeEvasion"]) then {
        "Comms / QRF: long-range nets assessed; reinforcement after sustained contact is plausible."
    } else {
        "Comms / QRF: assessed as local / tactical; large coordinated QRF less likely."
    };
    private _specBlock = [_atLine, _airLine, _commsLine] joinString "<br/>";
    private _mlcoa = switch (_missionType) do {
        case "TroopInsert": { "MLCOA: local security reacts to noise; minor harassing fire possible en route to LZ." };
        case "TroopExtract": { "MLCOA: pick-up zone may be probed; enemy tries to delay embarkation, not decisive engagement." };
        case "CASEVAC": { "MLCOA: enemy in vicinity of the casualty site maintains pressure while you load." };
        case "CSAR": { "MLCOA: search teams sweep toward the survivor; defend in place until extraction." };
        case "Cargo": { "MLCOA: sporadic contacts on approach; garrison remains defensive around the drop site." };
        case "CAS": { "MLCOA: enemy continues pressure on friendly positions; seeks cover when engaged from the air." };
        case "HVT": { "MLCOA: guards fix and protect the HVT; outer patrols try to canalise you into kill zones." };
        case "Hostage": { "MLCOA: captors barricade structures; attempt to shield hostages while returning fire." };
        case "ClearArea": { "MLCOA: garrison fights for the town or camp; withdraws in fragments once cohesion breaks." };
        case "SearchDestroy": { "MLCOA: objective and adjacent building garrisons stay internal; outer guards and patrols reinforce toward gunfire." };
        case "InterceptConvoy": { "MLCOA: escorts suppress flanks and push through; vehicles button up and run the route." };
        case "MineClearing": { "MLCOA: explosive hazard on routes — minimal manoeuvre; treat area as contaminated until cleared." };
        case "AssetRetrieval": { "MLCOA: house team holds the objective; outer patrols counter-attack toward the building." };
        case "AreaOfOperations": { "MLCOA: objective garrisons defend in place; patrols and QRF may shift between objectives." };
        case "Operation": { "MLCOA: zone garrisons hold built-up areas; vehicles may move between zones; contested areas may draw reinforcement." };
        case "EscapeEvasion": { "MLCOA: dispersed hunting teams pressure evaders; garrisoned town holds interior; road QRF vectors on confirmed contact." };
        default { "MLCOA: on contact, enemy likely to defend key ground, adjust disposition on flanks, or break contact once cohesion is lost." };
    };
    private _mdcoa = "MDCOA: rapid multi-axis reinforcement (ground and air) if the enemy retains capacity — lower probability, but not discounted.";
    private _civOn = missionNamespace getVariable ["FADE_civiliansEnabled", true];
    private _civLine = if (_civOn) then {
        "Civilian: local population presence expected in the TAOR; unknown individuals may observe or report — exercise pattern awareness."
    } else {
        "Civilian: local population presence not expected in the TAOR (sparse to absent per latest reporting)."
    };
    format [
        "<t align='left' color='#FFD166'>TOPOGRAPHY</t><br/><t align='left' color='%13'>Grid %1 | Area %2</t><br/><br/><t align='left' color='#FFD166'>ENEMY</t><br/><t align='left' color='%14'>Faction: %3.</t><br/><t align='left' color='%14'>Strength: ~%4 personnel; echelon brackets %5%6.</t><br/><t align='left' color='%14'>Equipment &amp; nets: %7</t><br/><t align='left' color='%14'>%8</t><br/><t align='left' color='%14'>%9</t><br/><br/><t align='left' color='#FFD166'>FRIENDLY</t><br/><t align='left' color='%14'>Faction: %10 | committed strength %11 players.</t><br/><br/><t align='left' color='#FFD166'>CIVILIAN</t><br/><t align='left' color='%14'>%12</t>",
        _topographyGrid,
        _topographyArea,
        _enemyFactionDisplay,
        _n,
        _echelon,
        _estQual,
        _specBlock,
        _mlcoa,
        _mdcoa,
        _friendlyFactionDisplay,
        _friendlyPlayerCount,
        _civLine,
        _topoBodyCol,
        _bodyCol
    ]
}];
private _friendlyPlayerCount = [_sideFriendly] call (missionNamespace getVariable ["FADE_countFriendlyPlayers", { 0 }]);
private _friendlyFactionClass = missionNamespace getVariable ["FADE_scenarioFriendlyFaction", "BLU_F"];
private _friendlyFactionName = getText (configFile >> "CfgFactionClasses" >> _friendlyFactionClass >> "displayName");
if (_friendlyFactionName == "") then { _friendlyFactionName = _friendlyFactionClass };
private _acreChannelSummary = [] call (missionNamespace getVariable ["FADE_getAcreChannelSummary", { "ACRE channel names unavailable" }]);
private _topographyData = [_destPos] call (missionNamespace getVariable ["FADE_getTopographySummary", { ["UNKNOWN", "Unknown area"] }]);
private _topographyGrid = _topographyData param [0, "UNKNOWN"];
private _topographyArea = _topographyData param [1, "Unknown area"];
private _actualOpforCount = { alive _x && { side group _x == _sideEnemy } } count allUnits;
private _fallbackOpforBaseline = switch (_missionType) do {
    case "TroopInsert": { 10 };
    case "TroopExtract": { 12 };
    case "CASEVAC": { 14 };
    case "CSAR": { 16 };
    case "Cargo": { 8 };
    case "CAS": { 24 };
    case "HVT": { 18 };
    case "Hostage": { 20 };
    case "ClearArea": { 26 };
    case "SearchDestroy": { 20 };
    case "InterceptConvoy": { 14 };
    case "MineClearing": { 6 };
    case "AssetRetrieval": { 14 };
    case "AreaOfOperations": { 30 };
        case "Operation": { 36 };
        case "EscapeEvasion": { 22 };
        default { 10 };
};
private _opforBaseline = if (_actualOpforCount > 0) then { _actualOpforCount } else { _fallbackOpforBaseline };
private _opforCountFactor = if (random 1 < 0.5) then { 0.8 } else { 1.2 };
private _estimatedOpforCount = (round (_opforBaseline * _opforCountFactor)) max 0;
private _intelFormatter = missionNamespace getVariable ["FADE_formatSituationIntelHtml", {}];
private _defaultSituationHtml = if (_intelFormatter isEqualTo {}) then {
    format [
        "<t align='left' color='#B0B0B0'>Topography: Grid %2 | Area: %3</t><br/><t align='left' color='#B0B0B0'>Enemy: %1</t><br/><t align='left' color='#B0B0B0'>Friendly package active from base.</t>",
        _enemyFactionName,
        _topographyGrid,
        _topographyArea
    ]
} else {
    [
        _missionType,
        _destPos,
        _sideEnemy,
        _sideFriendly,
        _estimatedOpforCount,
        _opforCountFactor,
        _enemyFactionName,
        _friendlyFactionName,
        _friendlyPlayerCount,
        _topographyGrid,
        _topographyArea
    ] call _intelFormatter
};
private _defaultSituationHintHtml = if (_intelFormatter isEqualTo {}) then {
    format [
        "<t align='left' color='#FFFFFF'>Topography: Grid %2 | Area: %3</t><br/><t align='left' color='#FFFFFF'>Enemy: %1</t><br/><t align='left' color='#FFFFFF'>Friendly package active from base.</t>",
        _enemyFactionName,
        _topographyGrid,
        _topographyArea
    ]
} else {
    [
        _missionType,
        _destPos,
        _sideEnemy,
        _sideFriendly,
        _estimatedOpforCount,
        _opforCountFactor,
        _enemyFactionName,
        _friendlyFactionName,
        _friendlyPlayerCount,
        _topographyGrid,
        _topographyArea,
        "#FFFFFF"
    ] call _intelFormatter
};
private _defaultExecutionHtml = "<t align='left' color='#C0C0C0'>Method: follow task markers, clear objective sequence, and report phase transitions over net.</t>";
private _defaultAdminHtml = format ["<t align='left' color='#FFFFFF'>Zero Alpha (%1)</t>", _zeroAlphaDisplayName];
private _defaultCommandHtml = format ["<t align='left' color='#FFFFFF'>Command &amp; Signal: %1</t>", _acreChannelSummary];
private _defaultSituationTaskText = _defaultSituationHtml;
private _defaultExecutionTaskText = "Execute task marker sequence and report objective status through each mission phase.";
private _defaultAdminTaskText = format ["Zero Alpha (%1).", _zeroAlphaDisplayName];
private _defaultCommandTaskText = format ["ACRE channels: %1", _acreChannelSummary];
// Hint-only SMEAC: execution is omitted here (still in BI task via FADE_buildMissionTaskSmeacText) to keep on-screen hint shorter.
missionNamespace setVariable ["FADE_formatMissionAssignedSmeac", {
    params [
        "_operationNameUpper",
        "_missionHtml",
        ["_situationHtml", ""],
        ["_executionHtml", ""],
        ["_adminHtml", ""],
        ["_commandHtml", ""]
    ];
    if (_situationHtml isEqualTo "") then { _situationHtml = "<t color='#FFFFFF'>Situation pending.</t>" };
    if (_adminHtml isEqualTo "") then { _adminHtml = "<t color='#FFFFFF'>Admin details pending.</t>" };
    if (_commandHtml isEqualTo "") then { _commandHtml = "<t color='#FFFFFF'>Command details pending.</t>" };
    format [
        "<t align='center' size='1.3' color='#FFD700'>MISSION ASSIGNED</t><br/><br/><t align='center' size='1.1' color='#FFFFFF'>%1</t><br/><br/><t align='left' color='#FFD166'>SITUATION</t><br/>%2<br/><br/><t align='left' color='#FFD166'>MISSION</t><br/><t align='left' color='#FFFFFF'>%3</t><br/><br/><t align='left' color='#FFD166'>ADMIN / LOGISTICS</t><br/>%4<br/><br/><t align='left' color='#FFD166'>COMMAND / SIGNAL</t><br/>%5",
        _operationNameUpper,
        _situationHtml,
        _missionHtml,
        _adminHtml,
        _commandHtml
    ]
}];
missionNamespace setVariable ["FADE_buildMissionTaskSmeacText", {
    params [
        "_missionText",
        "_pos",
        ["_situationText", ""],
        ["_executionText", ""],
        ["_adminText", ""],
        ["_commandText", ""]
    ];
    private _br = "<br/>";
    if (_situationText isEqualTo "") then { _situationText = "Situation pending." };
    if (_executionText isEqualTo "") then { _executionText = "Execution details pending." };
    if (_adminText isEqualTo "") then { _adminText = "Admin / logistics details pending." };
    if (_commandText isEqualTo "") then { _commandText = "Command / signal details pending." };
    private _topoData = [_pos] call (missionNamespace getVariable ["FADE_getTopographySummary", { ["UNKNOWN", "Unknown area"] }]);
    private _grid = _topoData param [0, "UNKNOWN"];
    private _areaName = _topoData param [1, "Unknown area"];
    private _sitHasTopo = (_situationText find "TOPOGRAPHY") >= 0;
    if (_sitHasTopo) exitWith {
        format [
            "<t align='left' color='#FFD166'>SITUATION</t>%1%2%1%1<t align='left' color='#FFD166'>MISSION</t>%1<t align='left'>%3</t>%1%1<t align='left' color='#FFD166'>EXECUTION</t>%1<t align='left'>%4</t>%1%1<t align='left' color='#FFD166'>ADMIN / LOGISTICS</t>%1<t align='left'>%5</t>%1%1<t align='left' color='#FFD166'>COMMAND / SIGNAL</t>%1<t align='left'>%6</t>",
            _br,
            _situationText,
            _missionText,
            _executionText,
            _adminText,
            _commandText
        ]
    };
    format [
        "<t align='left' color='#FFD166'>SITUATION</t>%1<t align='left'>%2</t>%1<t align='left'>Topography: Grid %3 | Area: %8</t>%1%1<t align='left' color='#FFD166'>MISSION</t>%1<t align='left'>%4</t>%1%1<t align='left' color='#FFD166'>EXECUTION</t>%1<t align='left'>%5</t>%1%1<t align='left' color='#FFD166'>ADMIN / LOGISTICS</t>%1<t align='left'>%6</t>%1%1<t align='left' color='#FFD166'>COMMAND / SIGNAL</t>%1<t align='left'>%7</t>",
        _br,
        _situationText,
        _grid,
        _missionText,
        _executionText,
        _adminText,
        _commandText,
        _areaName
    ]
}];
private _showAssignedHint = {
    params ["_missionHtml", ["_situationHtml", ""], ["_executionHtml", ""], ["_adminHtml", ""], ["_commandHtml", ""]];
    private _hintTarget = if (_isGlobalMission) then { 0 } else { _player };
    private _formatter = missionNamespace getVariable ["FADE_formatMissionAssignedSmeac", {}];
    private _payload = if (_formatter isEqualTo {}) then {
        format ["<t size='1.3' color='#FFD700'>MISSION ASSIGNED</t><br/><br/><t size='1.1' color='#FFFFFF'>%1</t><br/><br/>%2", _operationNameUpper, _missionHtml]
    } else {
        [
            _operationNameUpper,
            _missionHtml,
            if (_situationHtml isEqualTo "") then { _defaultSituationHintHtml } else { _situationHtml },
            if (_executionHtml isEqualTo "") then { _defaultExecutionHtml } else { _executionHtml },
            if (_adminHtml isEqualTo "") then { _defaultAdminHtml } else { _adminHtml },
            if (_commandHtml isEqualTo "") then { _defaultCommandHtml } else { _commandHtml }
        ] call _formatter
    };
    [_payload] remoteExec ["FADE_showMissionHint", _hintTarget];
};
private _basePos = FADE_basePos;

// Refine position: LZ missions use small refinement; HVT/ClearArea/InterceptConvoy handle position themselves
private _needsLZ = _missionType in ["TroopInsert", "TroopExtract", "Cargo", "CASEVAC", "CSAR"];
if (_missionType != "HVT" && { _missionType != "Hostage" } && { _missionType != "ClearArea" } && { _missionType != "InterceptConvoy" } && { _missionType != "AreaOfOperations" } && { _missionType != "SearchDestroy" } && { _missionType != "Operation" } && { _missionType != "AssetRetrieval" } && { _missionType != "MineClearing" } && { _missionType != "EscapeEvasion" }) then {
    private _refineMax = if (_needsLZ) then { 10 } else { 50 };
    private _refineObj = if (_needsLZ) then { 15 } else { 5 };
    private _preRefineDest = +_destPos;
    _destPos = [_destPos, 0, _refineMax, _refineObj, 1, 0.5, 0, [], _destPos] call BIS_fnc_findSafePos;
    // BIS_fnc_findSafePos can return scalar 0 on failure; keep server-validated position for LZ missions
    if (!(_destPos isEqualType []) || { count _destPos < 2 }) then { _destPos = _preRefineDest; };
};
if ((!(_destPos isEqualType []) || { count _destPos < 2 }) && { _missionType != "InterceptConvoy" } && { _missionType != "AreaOfOperations" } && { _missionType != "Operation" }) exitWith {
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
    params ["_player", "_taskId", "_desc", "_title", "_pos", "_taskType"];
    private _sf = missionNamespace getVariable ["FADE_sideFriendly", west];
    private _taskBuilder = missionNamespace getVariable ["FADE_buildMissionTaskSmeacText", {}];
    private _taskDesc = if (_taskBuilder isEqualTo {}) then {
        _desc
    } else {
        [
            _desc,
            _pos,
            _defaultSituationTaskText,
            _defaultExecutionTaskText,
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

// Attach an IR strobe to every living unit in _grp if it is night (19:30-04:30) and ACE3 is loaded.
// Strobes are stored in FADE_irStrobes group variable so cleanup can delete them.
// Called immediately after BIS_fnc_spawnGroup for any friendly group.
FADE_attachNightStrobes = {
    params ["_grp"];
    private _timeMin = (date select 3) * 60 + (date select 4);
    if !(_timeMin >= 1170 || { _timeMin <= 270 }) exitWith {};
    if !(isClass (configFile >> "CfgPatches" >> "ace_attach")) exitWith {};
    private _irVehClass = getText (configFile >> "CfgWeapons" >> "ACE_IR_Strobe_Item" >> "ACE_Attachable");
    if (_irVehClass == "") then { _irVehClass = getText (configFile >> "CfgMagazines" >> "ACE_IR_Strobe_Item" >> "ACE_Attachable") };
    if (_irVehClass == "") exitWith {};
    private _strobes = [];
    {
        if (alive _x) then {
            private _s = _irVehClass createVehicle [0,0,0];
            _s attachTo [_x, [0.07, -0.06, 0.085], "leftshoulder"];
            _strobes pushBack _s;
        };
    } forEach units _grp;
    _grp setVariable ["FADE_irStrobes", _strobes];
};

// -----------------------------------------------------------------------------
// AREA OF OPERATIONS -- 2 km zone, 3 capture points, BLUFOR vs OPFOR, JTAC
// -----------------------------------------------------------------------------
if (_missionType == "AreaOfOperations") exitWith {
    [_player, _destPos, _taskId, _basePos, _friendlyUnits, _enemyUnits, _operationNameUpper, _operationName] spawn {
        params ["_player", "_destPos", "_taskId", "_basePos", "_friendlyUnits", "_enemyUnits", "_operationNameUpper", "_operationName"];
        FADE_aoParams = [_player, _destPos, _taskId, _basePos, _friendlyUnits, _enemyUnits, _operationNameUpper, _operationName];
        call compile preprocessFileLineNumbers "rsc\AOMission.sqf";
    };
};

// -----------------------------------------------------------------------------
// 0b. OPERATION -- Multi-zone capture (global); see rsc\OperationMission.sqf
// Spawn + compile (same pattern as AreaOfOperations): isolates locals from this file.
// Inline call compile shared scope with Missions.sqf and broke _allGroups / retreat registration (RPT: foreach Bool).
// -----------------------------------------------------------------------------
if (_missionType == "Operation") exitWith {
    [_player, _taskId, _basePos, _enemyUnits, _operationNameUpper, _operationName] spawn {
        params ["_player", "_taskId", "_basePos", "_enemyUnits", "_operationNameUpper", "_operationName"];
        FADE_operationParams = [_player, _taskId, _basePos, _enemyUnits, _operationNameUpper, _operationName];
        call compile preprocessFileLineNumbers "rsc\OperationMission.sqf";
    };
};

// -----------------------------------------------------------------------------
// 1. TROOP INSERT -- Spawn friendly AI at B_SP_*, create task to insert at M_LOC_*
// -----------------------------------------------------------------------------
if (_missionType == "TroopInsert") exitWith {
    if (count FADE_bSpPoints == 0) exitWith {
        [_player] call FADE_clearActiveMission;
        ["<t size='1.2' color='#FF6666'>MISSION ERROR</t><br/><br/><t color='#E0E0E0'>No spawn points. Configure B_SP_1/2/3 in Eden.</t>"] remoteExec ["FADE_showMissionHint", _player];
    };
    private _spawnTrigger = selectRandom FADE_bSpPoints;
    if (isNull _spawnTrigger) exitWith {
        [_player] call FADE_clearActiveMission;
        ["<t size='1.2' color='#FF6666'>MISSION ERROR</t><br/><br/><t color='#E0E0E0'>No spawn points. Configure B_SP_1/2/3 in Eden.</t>"] remoteExec ["FADE_showMissionHint", _player];
    };
    private _spawnPos = position _spawnTrigger;

    private _group = [_spawnPos, _sideFriendly, _unitClasses] call BIS_fnc_spawnGroup;
    [_group] call (missionNamespace getVariable ["FADE_assignGroupCallsign", {}]);
    [_group] call FADE_attachNightStrobes;
    _group setBehaviour "SAFE";
    _group setCombatMode "GREEN";

    [_player, _taskId, "Insert the squad at the marked LZ.", "Troop Insert", _destPos, "move"] call _fnc_createMissionTask;

    // Create marker for players
    private _markerName = "FADE_insert_" + _taskId;
    _player setVariable ["FADE_myMissionMarker", _markerName, true];
    private _marker = createMarker [_markerName, [_destPos, 100] call _mkrJitter];
    _marker setMarkerType "mil_pickup";
    _marker setMarkerColor _markerFriendly;
    _marker setMarkerText _operationName;

    private _grid = mapGridPosition _destPos;
    private _brief = format ["TROOP INSERT%1%1PICKUP: Base (squad at B_SP)%1TARGET: LZ Grid %2%1%1Pick up squad at base. Fly to marked LZ. Land to disembark.%1%1Complete when squad has disembarked at LZ.", toString [10], _grid];
    _player setVariable ["FADE_myMissionBrief", _brief, true];
    [format ["<t color='#FFFFFF'>LZ Grid: %1</t><br/><br/><t color='#FFFFFF'>RTB. Pick up squad at base. Proceed to LZ. Land to disembark.</t>", _grid]] call _showAssignedHint;
    [_player, "Troop Insert"] call FADE_notifyOthersMissionStarted;

    [_missionType, _group, _player, _spawnPos, _destPos, _taskId, _markerName] spawn {
        params ["_missionType", "_group", "_player", "_spawnPos", "_destPos", "_taskId", "_markerName"];
        FADE_transportParams = [_missionType, _group, _player, _spawnPos, _destPos, _taskId, _markerName];
        call compile preprocessFileLineNumbers "rsc\TroopTransport.sqf";
    };
};

// -----------------------------------------------------------------------------
// 2. TROOP EXTRACT -- Spawn friendly AI at M_LOC_*, create task to extract to base
// 50% chance: 1-5 enemy groups 500-2000m from pickup, moving to engage; else quiet pickup (SAFE)
// -----------------------------------------------------------------------------
if (_missionType == "TroopExtract") exitWith {
    // Pickup group: 2-10 units regardless of player's vehicle
    private _pickupCount = 2 + floor random 9;
    private _pickupClasses = (_friendlyUnits select [0, _pickupCount min count _friendlyUnits]);
    for "_i" from (count _pickupClasses) to (_pickupCount - 1) do { _pickupClasses pushBack (_friendlyUnits select 0) };

    private _wpPos = _destPos getPos [10, random 360];
    _wpPos = [_wpPos, 0, 15, 2, 1, 0.3, 0, [], _wpPos] call BIS_fnc_findSafePos;
    if (count _wpPos < 2) then { _wpPos = _destPos getPos [10, random 360] };
    private _group = [_wpPos, _sideFriendly, _pickupClasses] call BIS_fnc_spawnGroup;
    [_group] call (missionNamespace getVariable ["FADE_assignGroupCallsign", {}]);
    [_group] call FADE_attachNightStrobes;
    _group addWaypoint [_wpPos, 0];

    private _enemyGroups = [];
    if (random 1 < 0.5) then {
        private _numEnemyGroups = [1 + floor random 5, 1] call _scaleOpforCount;
        private _minDistFromBase = 1000;
        for "_g" from 0 to (_numEnemyGroups - 1) do {
            private _grpPos = [];
            for "_try" from 0 to 10 do {
                private _angle = random 360;
                private _dist = 500 + random 1500;
                private _candidate = _destPos getPos [_dist, _angle];
                _candidate = [_candidate, 0, 30, 3, 1, 0.4, 0, [], _candidate] call BIS_fnc_findSafePos;
                if (count _candidate < 2) then { _candidate = _destPos getPos [_dist, _angle] };
                if ((_candidate distance _basePos) >= _minDistFromBase) exitWith { _grpPos = _candidate };
            };
            if (count _grpPos < 2) then {
                private _dirAwayFromBase = _destPos getDir _basePos;
                _grpPos = _destPos getPos [800, _dirAwayFromBase + 180];
            };
            private _grpSize = [3 + floor random 5, 2] call _scaleOpforCount;
            private _shuffled = _enemyUnits call BIS_fnc_arrayShuffle;
            private _grpUnits = (_shuffled select [0, _grpSize min count _shuffled]);
            if (count _grpUnits == 0) then { _grpUnits = [_enemyUnits select 0] };
            private _grp = [_grpPos, _sideEnemy, _grpUnits] call BIS_fnc_spawnGroup;
            [_grp] call FAC_applyEnemyScenarioToGroup;
            _grp setBehaviour "AWARE";
            _grp setCombatMode "RED";
            _grp addWaypoint [_destPos, 0];
            _enemyGroups pushBack _grp;
        };
        [_enemyGroups, _basePos] call FADE_registerEnemyRetreat;
        _group setBehaviour "COMBAT";
        _group setFormation "DIAMOND";
    } else {
        _group setBehaviour "SAFE";
        _group setCombatMode "GREEN";
        _group setFormation "STAG COLUMN";
    };

    [_player, _taskId, "Extract the squad and return them to base.", "Troop Extract", _destPos, "move"] call _fnc_createMissionTask;

    private _markerName = "FADE_extract_" + _taskId;
    _player setVariable ["FADE_myMissionMarker", _markerName, true];
    private _marker = createMarker [_markerName, [_destPos, 100] call _mkrJitter];
    _marker setMarkerType "mil_pickup";
    _marker setMarkerColor _markerFriendly;
    _marker setMarkerText _operationName;

    private _grid = mapGridPosition _destPos;
    private _enemyLikely = (count _enemyGroups) > 0;
    private _threatBrief = if (_enemyLikely) then { "THREAT: enemy party likely in area" } else { "THREAT: low enemy presence expected" };
    private _threatHint = if (_enemyLikely) then { "Enemy activity likely near pickup." } else { "Low enemy activity expected near pickup." };
    private _brief = format ["TROOP EXTRACT%1%1PICKUP: Grid %2 (marked on map)%1TARGET: Base (RTB)%1PAX: %3 personnel for extraction%1%4%1%1Fly to pickup zone. Land to load squad. Return to base and land.%1%1Complete when squad has disembarked at base.", toString [10], _grid, _pickupCount, _threatBrief];
    _player setVariable ["FADE_myMissionBrief", _brief, true];
    [format ["<t color='#FFFFFF'>RZ Grid: %1</t><br/><t color='#FFFFFF'>PAX: %2 personnel</t><br/><t color='#FFFFFF'>%3</t><br/><br/><t color='#FFFFFF'>Proceed to pickup zone. Land to load squad. RTB once loaded.</t>", _grid, _pickupCount, _threatHint]] call _showAssignedHint;
    [_player, "Troop Extract"] call FADE_notifyOthersMissionStarted;

    private _teQrfPos = +_destPos;
    if (count _teQrfPos < 3) then { _teQrfPos = [(_teQrfPos select 0), (_teQrfPos select 1), 0] };
    [_taskId, _teQrfPos, _basePos, _enemyUnits, _enemyGroups, -1] call FADE_counterAttackStart;

    [_missionType, _group, _player, _destPos, _basePos, _taskId, _markerName, _enemyGroups] spawn {
        params ["_missionType", "_group", "_player", "_destPos", "_basePos", "_taskId", "_markerName", "_enemyGroups"];
        FADE_transportParams = [_missionType, _group, _player, _destPos, _basePos, _taskId, _markerName, _enemyGroups];
        call compile preprocessFileLineNumbers "rsc\TroopTransport.sqf";
    };
};

// -----------------------------------------------------------------------------
// 2b. CASEVAC -- Troop extract; squad has KIA and ACE injuries before pickup
// -----------------------------------------------------------------------------
if (_missionType == "CASEVAC") exitWith {
    private _pickupCount = 2 + floor random 9;
    private _pickupClasses = (_friendlyUnits select [0, _pickupCount min count _friendlyUnits]);
    for "_i" from (count _pickupClasses) to (_pickupCount - 1) do { _pickupClasses pushBack (_friendlyUnits select 0) };

    private _wpPos = _destPos getPos [10, random 360];
    _wpPos = [_wpPos, 0, 15, 2, 1, 0.3, 0, [], _wpPos] call BIS_fnc_findSafePos;
    if (count _wpPos < 2) then { _wpPos = _destPos getPos [10, random 360] };
    private _group = [_wpPos, _sideFriendly, _pickupClasses] call BIS_fnc_spawnGroup;
    [_group] call (missionNamespace getVariable ["FADE_assignGroupCallsign", {}]);
    [_group] call FADE_attachNightStrobes;
    _group addWaypoint [_wpPos, 0];

    private _useACE = isClass (configFile >> "CfgPatches" >> "ace_medical");
    private _aceHasAddDamage = !isNil "ace_medical_fnc_addDamageToUnit";
    private _aceHasAddWound = !isNil "ace_medical_fnc_addWound";
    private _nStart = count units _group;
    if (_nStart >= 2) then {
        private _kia = (1 + floor random 2) min (_nStart - 1);
        for "_k" from 1 to _kia do {
            private _u = selectRandom units _group;
            if (!isNull _u) then { deleteVehicle _u };
        };
        {
            if (!alive _x) then {} else {
                if (_useACE && _aceHasAddDamage) then {
                    private _p = selectRandom ["Head", "Body", "LeftArm", "RightArm", "LeftLeg", "RightLeg"];
                    [_x, 0.12 + random 0.22, _p, "bullet", objNull] call ace_medical_fnc_addDamageToUnit;
                    if (_aceHasAddWound) then { [_x, toLower _p, ["Laceration", 1, 0, 0.2]] call ace_medical_fnc_addWound };
                } else {
                    _x setDamage ((damage _x) + 0.15 + random 0.25);
                };
            };
        } forEach units _group;
    };

    private _enemyGroups = [];
    if (random 1 < 0.5) then {
        private _numEnemyGroups = [1 + floor random 5, 1] call _scaleOpforCount;
        private _minDistFromBase = 1000;
        for "_g" from 0 to (_numEnemyGroups - 1) do {
            private _grpPos = [];
            for "_try" from 0 to 10 do {
                private _angle = random 360;
                private _dist = 500 + random 1500;
                private _candidate = _destPos getPos [_dist, _angle];
                _candidate = [_candidate, 0, 30, 3, 1, 0.4, 0, [], _candidate] call BIS_fnc_findSafePos;
                if (count _candidate < 2) then { _candidate = _destPos getPos [_dist, _angle] };
                if ((_candidate distance _basePos) >= _minDistFromBase) exitWith { _grpPos = _candidate };
            };
            if (count _grpPos < 2) then {
                private _dirAwayFromBase = _destPos getDir _basePos;
                _grpPos = _destPos getPos [800, _dirAwayFromBase + 180];
            };
            private _grpSize = [3 + floor random 5, 2] call _scaleOpforCount;
            private _shuffled = _enemyUnits call BIS_fnc_arrayShuffle;
            private _grpUnits = (_shuffled select [0, _grpSize min count _shuffled]);
            if (count _grpUnits == 0) then { _grpUnits = [_enemyUnits select 0] };
            private _grp = [_grpPos, _sideEnemy, _grpUnits] call BIS_fnc_spawnGroup;
            [_grp] call FAC_applyEnemyScenarioToGroup;
            _grp setBehaviour "AWARE";
            _grp setCombatMode "RED";
            _grp addWaypoint [_destPos, 0];
            _enemyGroups pushBack _grp;
        };
        [_enemyGroups, _basePos] call FADE_registerEnemyRetreat;
        _group setBehaviour "COMBAT";
        _group setFormation "DIAMOND";
    } else {
        _group setBehaviour "SAFE";
        _group setCombatMode "GREEN";
        _group setFormation "STAG COLUMN";
    };

    [_player, _taskId, "CASEVAC: extract casualties and return to base.", "CASEVAC", _destPos, "move"] call _fnc_createMissionTask;

    private _markerName = "FADE_casevac_" + _taskId;
    _player setVariable ["FADE_myMissionMarker", _markerName, true];
    private _marker = createMarker [_markerName, [_destPos, 100] call _mkrJitter];
    _marker setMarkerType "mil_pickup";
    _marker setMarkerColor _markerFriendly;
    _marker setMarkerText _operationName;

    private _grid = mapGridPosition _destPos;
    private _living = { alive _x } count units _group;
    private _brief = format ["CASEVAC%1%1PICKUP: Grid %2 (marked on map)%1TARGET: Base (RTB)%1PAX: %3 alive (some KIA on site; remainder need CASEVAC)%1%1Land to load survivors. RTB and land at base.%1%1Complete when squad has disembarked at base.", toString [10], _grid, _living];
    _player setVariable ["FADE_myMissionBrief", _brief, true];
    [format ["<t color='#FFFFFF'>RZ Grid: %1</t><br/><t color='#FFFFFF'>PAX: %2 (wounded)</t><br/><br/><t color='#FFFFFF'>Extract and RTB.</t>", _grid, _living]] call _showAssignedHint;
    [_player, "CASEVAC"] call FADE_notifyOthersMissionStarted;

    private _cvQrfPos = +_destPos;
    if (count _cvQrfPos < 3) then { _cvQrfPos = [(_cvQrfPos select 0), (_cvQrfPos select 1), 0] };
    [_taskId, _cvQrfPos, _basePos, _enemyUnits, _enemyGroups, -1] call FADE_counterAttackStart;

    ["CASEVAC", _group, _player, _destPos, _basePos, _taskId, _markerName, _enemyGroups] spawn {
        params ["_missionType", "_group", "_player", "_destPos", "_basePos", "_taskId", "_markerName", "_enemyGroups"];
        FADE_transportParams = [_missionType, _group, _player, _destPos, _basePos, _taskId, _markerName, _enemyGroups];
        call compile preprocessFileLineNumbers "rsc\TroopTransport.sqf";
    };
};

// -----------------------------------------------------------------------------
// 2c. CSAR -- Downed helo wreck; one survivor; global mission slot; extract like Troop Extract
// -----------------------------------------------------------------------------
if (_missionType == "CSAR") exitWith {
    private _pickupClasses = [_friendlyUnits select 0];
    private _wpPos = _destPos getPos [10, random 360];
    _wpPos = [_wpPos, 0, 15, 2, 1, 0.3, 0, [], _wpPos] call BIS_fnc_findSafePos;
    if (!(_wpPos isEqualType [])) then { _wpPos = _destPos getPos [10, random 360] };
    if ((_wpPos isEqualType []) && { count _wpPos < 2 }) then { _wpPos = _destPos getPos [10, random 360] };
    // BIS_fnc_findSafePos can return [x,y] only; setPosATL / createVehicle expect ATL with Z
    if ((_wpPos isEqualType []) && { count _wpPos >= 2 && { count _wpPos < 3 } }) then { _wpPos = [(_wpPos select 0), (_wpPos select 1), 0] };
    private _friendlyVehicleClasses = missionNamespace getVariable ["FADE_friendlyVehicleClasses", []];
    private _factionHelis = _friendlyVehicleClasses select {
        _x isKindOf "Helicopter" && { getNumber (configFile >> "CfgVehicles" >> _x >> "isUav") < 1 }
    };
    private _csarWreckClasses = [
        "vn_air_f4b_wreck",
        "vn_air_oh6a_01_wreck",
        "Land_UH1H_Wreck_F",
        "BlackhawkWreck",
        "C130J_wreck_EP1"
    ];
    private _csarWreckOk = _csarWreckClasses select { isClass (configFile >> "CfgVehicles" >> _x) };
    if (count _csarWreckOk == 0) then {
        _csarWreckOk = ["Land_Wreck_Heli_Attack_01_F", "Land_Wreck_Heli_Attack_02_F"] select { isClass (configFile >> "CfgVehicles" >> _x) };
    };
    if (count _csarWreckOk == 0) then { _csarWreckOk = ["Land_Wreck_Heli_Attack_01_F"] };
    private _wreck = objNull;
    private _usedFactionHeli = false;
    if (count _factionHelis > 0) then {
        private _heliClass = selectRandom _factionHelis;
        _wreck = createVehicle [_heliClass, _wpPos, [], 0, "NONE"];
        _wreck setPosATL _wpPos;
        _wreck setDir (random 360);
        _wreck setVelocity [0, 0, 0];
        _wreck engineOn false;
        private _sn = surfaceNormal _wpPos;
        if ((vectorMagnitude _sn) > 0.5) then { _wreck setVectorUp _sn };
        _usedFactionHeli = true;
    } else {
        private _wreckClass = selectRandom _csarWreckOk;
        _wreck = createVehicle [_wreckClass, _wpPos, [], 0, "NONE"];
        _wreck setPosATL _wpPos;
        _wreck setDir (random 360);
    };
    missionNamespace setVariable ["FADE_csarWreck_" + _taskId, _wreck];

    private _survPos = _wreck getPos [10, random 360];
    _survPos = [_survPos, 0, 8, 2, 1, 0.3, 0, [], _survPos] call BIS_fnc_findSafePos;
    if (!(_survPos isEqualType [])) then { _survPos = getPosATL _wreck };
    if ((_survPos isEqualType []) && { count _survPos < 2 }) then { _survPos = getPosATL _wreck };
    if ((_survPos isEqualType []) && { count _survPos >= 2 && { count _survPos < 3 } }) then { _survPos = [(_survPos select 0), (_survPos select 1), 0] };
    private _group = [_survPos, _sideFriendly, _pickupClasses] call BIS_fnc_spawnGroup;
    [_group] call (missionNamespace getVariable ["FADE_assignGroupCallsign", {}]);
    [_group] call FADE_attachNightStrobes;
    { _x allowDamage false } forEach units _group;
    if (_usedFactionHeli && { !isNull _wreck }) then {
        _wreck setDamage 1;
    };
    private _crashCenter = getPosATL _wreck;
    if (count _crashCenter < 3) then { _crashCenter = [(_crashCenter select 0), (_crashCenter select 1), 0] };
    // Pilot starts moving toward the nearest civ-town center in stealth.
    while { count waypoints _group > 0 } do { deleteWaypoint [_group, 0] };
    private _nearestTownCenter = +_crashCenter;
    private _bestTownDist = 1e10;
    {
        private _trg = missionNamespace getVariable [_x, objNull];
        if (!isNull _trg) then {
            private _tc = getPosATL _trg;
            if (_tc isEqualType [] && { count _tc >= 2 }) then {
                if (count _tc < 3) then { _tc = [(_tc select 0), (_tc select 1), 0] };
                private _dTown = _tc distance2D _crashCenter;
                if (_dTown < _bestTownDist) then {
                    _bestTownDist = _dTown;
                    _nearestTownCenter = _tc;
                };
            };
        };
    } forEach (missionNamespace getVariable ["FADE_civTriggerNames", []]);
    private _pilotWp = _group addWaypoint [_nearestTownCenter, 0];
    _pilotWp setWaypointType "MOVE";
    _pilotWp setWaypointSpeed "LIMITED";
    _pilotWp setWaypointCompletionRadius 20;
    _group setBehaviour "STEALTH";
    _group setCombatMode "GREEN";
    _group setSpeedMode "LIMITED";

    // Place two additional KIA friendlies near the wreck for CSAR scene dressing.
    private _csarBodies = [];
    private _kiaClass = _friendlyUnits select 0;
    for "_k" from 0 to 1 do {
        private _kiaPos = _crashCenter getPos [2 + random 8, random 360];
        _kiaPos = [_kiaPos, 0, 4, 1, 1, 0.3, 0, [], _kiaPos] call BIS_fnc_findSafePos;
        if (!(_kiaPos isEqualType []) || { count _kiaPos < 2 }) then { _kiaPos = _crashCenter getPos [2 + random 8, random 360] };
        if (count _kiaPos < 3) then { _kiaPos = [(_kiaPos select 0), (_kiaPos select 1), 0] };
        private _kiaGroup = createGroup [_sideFriendly, true];
        private _kiaUnit = _kiaGroup createUnit [_kiaClass, _kiaPos, [], 0, "NONE"];
        _kiaUnit setPosATL _kiaPos;
        _kiaUnit setDir (random 360);
        _kiaUnit setDamage 1;
        _kiaUnit disableAI "ALL";
        _csarBodies pushBack _kiaUnit;
    };
    missionNamespace setVariable ["FADE_csarBodies_" + _taskId, _csarBodies];

    private _useACE = isClass (configFile >> "CfgPatches" >> "ace_medical");
    private _aceHasAddDamage = !isNil "ace_medical_fnc_addDamageToUnit";
    private _aceHasAddWound = !isNil "ace_medical_fnc_addWound";
    {
        if (_useACE && _aceHasAddDamage) then {
            _x allowDamage true;
            private _p = selectRandom ["Body", "LeftLeg", "RightLeg"];
            [_x, 0.18 + random 0.2, _p, "bullet", objNull] call ace_medical_fnc_addDamageToUnit;
            if (_aceHasAddWound) then { [_x, toLower _p, ["VelocityWound", 1, 1, 0.4]] call ace_medical_fnc_addWound };
            _x allowDamage false;
        } else {
            _x allowDamage true;
            _x setDamage (0.25 + random 0.2);
            _x allowDamage false;
        };
    } forEach units _group;

    [_group] spawn {
        params ["_grp"];
        sleep 30;
        if (isNull _grp) exitWith {};
        { if (!isNull _x && { alive _x }) then { _x allowDamage true } } forEach units _grp;
    };

    private _enemyGroups = [];
    if (count _enemyUnits > 0) then {
        private _searchDistances = [750, 1250, 2000];
        {
            private _spawnDist = _x;
            private _grpPos = [];
            for "_try" from 0 to 12 do {
                private _angle = random 360;
                private _candidate = _crashCenter getPos [_spawnDist + (random 80 - 40), _angle];
                _candidate = [_candidate, 0, 35, 4, 1, 0.4, 0, [], _candidate] call BIS_fnc_findSafePos;
                if (count _candidate < 2) then { _candidate = _crashCenter getPos [_spawnDist, _angle] };
                if (count _candidate < 3) then { _candidate = [(_candidate select 0), (_candidate select 1), 0] };
                if (
                    (_candidate distance2D _crashCenter) >= (_spawnDist - 150) &&
                    { !(surfaceIsWater _candidate) }
                ) exitWith { _grpPos = _candidate };
            };
            if (count _grpPos < 2) then {
                for "_fb" from 0 to 18 do {
                    private _fallback = _crashCenter getPos [_spawnDist, random 360];
                    _fallback = [_fallback, 0, 60, 6, 1, 0.45, 0, [], _fallback] call BIS_fnc_findSafePos;
                    if (count _fallback < 2) then { _fallback = _crashCenter getPos [_spawnDist, random 360] };
                    if (count _fallback < 3) then { _fallback = [(_fallback select 0), (_fallback select 1), 0] };
                    if (
                        count _fallback >= 2 &&
                        { !(surfaceIsWater _fallback) } &&
                        { (_fallback distance2D _crashCenter) >= (_spawnDist - 200) }
                    ) exitWith { _grpPos = _fallback };
                };
            };
            if (count _grpPos < 2) then {
                private _fallback = _crashCenter getPos [_spawnDist, random 360];
                if (count _fallback < 3) then { _fallback = [(_fallback select 0), (_fallback select 1), 0] };
                if (surfaceIsWater _fallback) then {
                    private _rMin = (_spawnDist - 250) max 80;
                    private _rMax = _spawnDist + 350;
                    _fallback = [_crashCenter, _rMin, _rMax, 10, 1, 0.5, 0, [], _crashCenter] call BIS_fnc_findSafePos;
                    if (count _fallback < 3) then { _fallback = [(_fallback select 0), (_fallback select 1), 0] };
                };
                _grpPos = _fallback;
            };
            if (count _grpPos >= 2 && { surfaceIsWater _grpPos }) then {
                private _rMin2 = (_spawnDist - 250) max 80;
                _grpPos = [_crashCenter, _rMin2, _spawnDist + 350, 10, 1, 0.5, 0, [], _crashCenter] call BIS_fnc_findSafePos;
                if (count _grpPos < 3) then { _grpPos = [(_grpPos select 0), (_grpPos select 1), 0] };
            };
            private _grpSize = [3 + floor random 5, 2] call _scaleOpforCount;
            private _shuffled = _enemyUnits call BIS_fnc_arrayShuffle;
            private _grpUnits = (_shuffled select [0, _grpSize min count _shuffled]);
            if (count _grpUnits == 0) then { _grpUnits = [_enemyUnits select 0] };
            private _grp = [_grpPos, _sideEnemy, _grpUnits] call BIS_fnc_spawnGroup;
            [_grp] call FAC_applyEnemyScenarioToGroup;
            _grp setBehaviour "SAFE";
            _grp setCombatMode "GREEN";
            _grp setSpeedMode "LIMITED";
            _grp setFormation "LINE";
            while { count waypoints _grp > 0 } do { deleteWaypoint [_grp, 0] };
            // 1) Random point within 100 m of crash; 2) same civ-town objective as the survivor's move waypoint
            private _nearCrashWp = +_crashCenter;
            if (count _nearCrashWp < 3) then { _nearCrashWp = [(_nearCrashWp select 0), (_nearCrashWp select 1), 0] };
            for "_wTry" from 0 to 12 do {
                private _r = random 100;
                private _a = random 360;
                private _p = _crashCenter getPos [_r, _a];
                _p = [_p, 0, 30, 4, 1, 0.45, 0, [], _p] call BIS_fnc_findSafePos;
                if (!(_p isEqualType []) || { count _p < 2 }) then { _p = _crashCenter getPos [_r * 0.85, _a] };
                if (count _p < 3) then { _p = [(_p select 0), (_p select 1), 0] };
                if (!(surfaceIsWater _p) && { (_p distance2D _crashCenter) <= 105 }) exitWith { _nearCrashWp = _p };
            };
            private _townWpPos = +_nearestTownCenter;
            if (count _townWpPos < 3) then { _townWpPos = [(_townWpPos select 0), (_townWpPos select 1), 0] };
            private _wpCrash = _grp addWaypoint [_nearCrashWp, 0];
            _wpCrash setWaypointType "MOVE";
            _wpCrash setWaypointSpeed "LIMITED";
            _wpCrash setWaypointBehaviour "SAFE";
            _wpCrash setWaypointCombatMode "GREEN";
            _wpCrash setWaypointFormation "LINE";
            _wpCrash setWaypointCompletionRadius 35;
            private _wpTown = _grp addWaypoint [_townWpPos, 0];
            _wpTown setWaypointType "MOVE";
            _wpTown setWaypointSpeed "LIMITED";
            _wpTown setWaypointBehaviour "SAFE";
            _wpTown setWaypointCombatMode "GREEN";
            _wpTown setWaypointFormation "LINE";
            _wpTown setWaypointCompletionRadius 25;
            _enemyGroups pushBack _grp;
        } forEach _searchDistances;
        [_enemyGroups, _basePos] call FADE_registerEnemyRetreat;
    };

    [_player, _taskId, "CSAR: recover the survivor at the crash site and RTB.", "CSAR", _destPos, "move"] call _fnc_createMissionTask;

    private _markerName = "FADE_csar_" + _taskId;
    _player setVariable ["FADE_myMissionMarker", _markerName, true];
    private _marker = createMarker [_markerName, [_destPos, 100] call _mkrJitter];
    _marker setMarkerType "mil_pickup";
    _marker setMarkerColor _markerFriendly;
    _marker setMarkerText _operationName;

    private _grid = mapGridPosition _destPos;
    private _brief = format ["CSAR%1%1PICKUP: Grid %2 — downed aircraft%1TARGET: Base (RTB)%1%1Land at the survivor's position. Load and RTB.%1%1Complete when survivor has disembarked at base.", toString [10], _grid];
    _player setVariable ["FADE_myMissionBrief", _brief, true];
    [format ["<t color='#FFFFFF'>CSAR Grid: %1</t><br/><br/><t color='#FFFFFF'>Survivor at crash site.</t>", _grid]] call _showAssignedHint;
    [_player, "CSAR"] call FADE_notifyOthersMissionStarted;

    [_taskId, _crashCenter, _basePos, _enemyUnits, _enemyGroups, 500] call FADE_counterAttackStart;

    // 1 km: survivor sideChat + grid; 500 m: green smoke.
    // After smoke the survivor freezes in place, drops patrol waypoints, and tries to board nearby player vehicles.
    [_group, _taskId] spawn {
        params ["_group", "_taskId"];
        private _sf = missionNamespace getVariable ["FADE_sideFriendly", west];
        private _didRadio1k = false;
        private _didSmoke500 = false;
        private _holdActive = false;
        while {
            !isNull _group && { count units _group > 0 } &&
            { !((_taskId call BIS_fnc_taskState) in ["SUCCEEDED", "FAILED", "CANCELED"]) }
        } do {
            sleep 3;
            private _ldr = leader _group;
            if (isNull _ldr || !alive _ldr) exitWith {};
            private _minD = 1e10;
            {
                if (side _x == _sf && { isPlayer _x } && { alive _x }) then {
                    private _d = _x distance _ldr;
                    if (_d < _minD) then { _minD = _d };
                };
            } forEach allPlayers;
            if (_minD < 1e10) then {
                private _posLdr = getPosATL _ldr;
                if (!_didRadio1k && { _minD <= 1000 }) then {
                    _didRadio1k = true;
                    private _cs = _group getVariable ["FADE_callsign", "Survivor"];
                    private _grid = mapGridPosition _posLdr;
                    [_ldr, format ["This is %1. Mayday — holding near Grid %2. Need immediate pickup. Over.", _cs, _grid]] call FADE_aiSideChat;
                };
                if (!_didSmoke500 && { _minD <= 500 }) then {
                    _didSmoke500 = true;
                    "SmokeShellGreen" createVehicle _posLdr;
                    private _cs2 = _group getVariable ["FADE_callsign", "Survivor"];
                    [_ldr, format ["This is %1. Marking position with green smoke. Over.", _cs2]] call FADE_aiSideChat;

                    // Stop roaming once pickup signal is out.
                    while { count waypoints _group > 0 } do { deleteWaypoint [_group, 0] };
                    _group setBehaviour "AWARE";
                    _group setCombatMode "GREEN";
                    _group setSpeedMode "LIMITED";
                    private _holdWp = _group addWaypoint [_posLdr, 0];
                    _holdWp setWaypointType "HOLD";
                    _holdWp setWaypointCompletionRadius 5;
                    _holdWp setWaypointSpeed "LIMITED";
                    _holdActive = true;
                };

                if (_holdActive) then {
                    private _survivor = _ldr;
                    if (!isNull _survivor && { alive _survivor } && { vehicle _survivor == _survivor }) then {
                        private _nearestVeh = objNull;
                        private _nearestDist = 1e10;
                        {
                            if (side _x == _sf && { isPlayer _x } && { alive _x }) then {
                                private _veh = vehicle _x;
                                if (_veh != _x && { alive _veh } && { canMove _veh }) then {
                                    private _dVeh = _survivor distance _veh;
                                    if (_dVeh < _nearestDist) then {
                                        _nearestVeh = _veh;
                                        _nearestDist = _dVeh;
                                    };
                                };
                            };
                        } forEach allPlayers;

                        if (!isNull _nearestVeh && { _nearestDist <= 80 }) then {
                            private _hasSeat = (_nearestVeh emptyPositions "cargo") > 0 || { (_nearestVeh emptyPositions "turret") > 0 } || { (_nearestVeh emptyPositions "gunner") > 0 };
                            if (_hasSeat) then {
                                _survivor assignAsCargo _nearestVeh;
                                [_survivor] orderGetIn true;
                            };
                        };
                    };
                };
            };
        };
    };

    ["CSAR", _group, _player, _destPos, _basePos, _taskId, _markerName, _enemyGroups] spawn {
        params ["_missionType", "_group", "_player", "_destPos", "_basePos", "_taskId", "_markerName", "_enemyGroups"];
        FADE_transportParams = [_missionType, _group, _player, _destPos, _basePos, _taskId, _markerName, _enemyGroups];
        call compile preprocessFileLineNumbers "rsc\TroopTransport.sqf";
    };
};

// -----------------------------------------------------------------------------
// 2d. ASSET RETRIEVAL -- Intel at small site; secure then RTB to base
// -----------------------------------------------------------------------------
if (_missionType == "AssetRetrieval") exitWith {
    if (count _enemyUnits == 0) exitWith {
        [_player] call FADE_clearActiveMission;
        ["<t size='1.2' color='#FF6666'>MISSION ERROR</t><br/><br/><t color='#E0E0E0'>No enemy units configured.</t>"] remoteExec ["FADE_showMissionHint", _player];
    };

    private _enemyUnitsAsset = +_enemyUnits;
    _enemyUnitsAsset = [_enemyUnitsAsset] call (missionNamespace getVariable ["FADE_filterEnemyUnitsArmed", { _this select 0 }]);
    if (count _enemyUnitsAsset == 0) then { _enemyUnitsAsset = +_enemyUnits };
    private _baseEnemyClass = _enemyUnitsAsset select 0;
    private _assetBranch = if (random 1 < 0.66) then { 1 } else { 2 };

    // Branch 2 (33%): recover enemy vehicle and return it near base.
    if (_assetBranch == 2) exitWith {
        private _vehicleClass = "RHS_UAZ_MSV_01";
        private _vehicleCfg = configFile >> "CfgVehicles" >> _vehicleClass;
        private _vehicleName = if (isClass _vehicleCfg) then { getText (_vehicleCfg >> "displayName") } else { _vehicleClass };
        if (_vehicleName == "") then { _vehicleName = _vehicleClass };

        private _spawnRoadVehicleInZone = {
            params ["_zoneCenter", "_vehClass"];
            private _roads = _zoneCenter nearRoads 500;
            if (_roads isEqualTo []) exitWith { [objNull, []] };
            _roads = _roads call BIS_fnc_arrayShuffle;
            private _result = [objNull, []];

            {
                private _road = _x;
                private _roadPos = getPosATL _road;
                if (_roadPos isEqualType [] && { count _roadPos < 3 }) then { _roadPos = [(_roadPos select 0), (_roadPos select 1), 0] };

                private _candidate = [_roadPos, 0, 8, 5, 0, 0.2, 0, [], _roadPos] call BIS_fnc_findSafePos;
                if !(_candidate isEqualType [] && { count _candidate >= 2 }) then { _candidate = _roadPos };
                if (_candidate isEqualType [] && { count _candidate < 3 }) then { _candidate = [(_candidate select 0), (_candidate select 1), 0] };

                if !(isOnRoad _candidate || { (_candidate distance2D _roadPos) <= 12 }) then { continue };
                private _nearVehicles = nearestObjects [_candidate, ["LandVehicle", "Air", "Ship"], 5];
                if (count _nearVehicles > 0) then { continue };

                private _veh = createVehicle [_vehClass, _candidate, [], 0, "NONE"];
                if (isNull _veh) then { continue };

                private _dir = random 360;
                private _conn = roadsConnectedTo _road;
                if (count _conn > 0) then { _dir = _road getDir (_conn select 0) };

                _veh allowDamage false;
                _veh setPosATL _candidate;
                _veh setDir _dir;
                _veh setVectorUp surfaceNormal _candidate;
                _veh setVelocity [0, 0, 0];
                _veh setFuel 1;
                _veh setDamage 0;
                clearWeaponCargoGlobal _veh;
                clearMagazineCargoGlobal _veh;
                clearItemCargoGlobal _veh;
                clearBackpackCargoGlobal _veh;
                [_veh] spawn { params ["_v"]; sleep 2; if (!isNull _v) then { _v allowDamage true } };

                if (!alive _veh || { !canMove _veh }) then {
                    deleteVehicle _veh;
                    continue;
                };

                _result = [_veh, _candidate];
                if (!isNull _veh) exitWith {};
            } forEach _roads;

            _result
        };

        private _zones = +(missionNamespace getVariable ["FADE_civTriggerNames", []]);
        _zones = _zones call BIS_fnc_arrayShuffle;
        private _zonesEligible = [];
        {
            private _trig = missionNamespace getVariable [_x, objNull];
            if (!isNull _trig) then {
                private _zc = getPosATL _trig;
                if (count _zc >= 2 && { (_zc distance _basePos) >= 1500 }) then {
                    _zonesEligible pushBack _x;
                };
            };
        } forEach _zones;

        private _assetVehicle = objNull;
        private _center = +_destPos;
        if (count _zonesEligible > 0) then {
            private _maxPasses = 10;
            private _pass = 0;
            while { isNull _assetVehicle && { _pass < _maxPasses } } do {
                _pass = _pass + 1;
                _zonesEligible = _zonesEligible call BIS_fnc_arrayShuffle;
                {
                    if (!isNull _assetVehicle) exitWith {};
                    private _trig = missionNamespace getVariable [_x, objNull];
                    if (isNull _trig) then { continue };
                    private _zoneCenter = getPosATL _trig;
                    if (_zoneCenter isEqualType [] && { count _zoneCenter < 3 }) then { _zoneCenter = [(_zoneCenter select 0), (_zoneCenter select 1), 0] };
                    private _spawnRes = [_zoneCenter, _vehicleClass] call _spawnRoadVehicleInZone;
                    private _vehTry = _spawnRes param [0, objNull];
                    private _posTry = _spawnRes param [1, []];
                    if (!isNull _vehTry) then {
                        _assetVehicle = _vehTry;
                        _center = _posTry;
                    };
                } forEach _zonesEligible;
            };
        };

        if (isNull _assetVehicle) exitWith {
            [_player] call FADE_clearActiveMission;
            ["<t size='1.2' color='#FF6666'>MISSION ERROR</t><br/><br/><t color='#E0E0E0'>Could not spawn the recovery vehicle on a safe road near an eligible civ zone.</t>"] remoteExec ["FADE_showMissionHint", _player];
        };

        private _allGroups = [];
        private _guardCountSpawned = 0;
        private _guardCap = 20;

        private _guardCount = [3 + floor random 3, 1] call _scaleOpforCount;
        _guardCount = _guardCount min _guardCap;
        for "_g" from 0 to (_guardCount - 1) do {
            if (_guardCountSpawned >= _guardCap) exitWith {};
            private _guardPos = [_center, 12, 100, 3, 1, 0.3, 0, [], _center] call BIS_fnc_findSafePos;
            if (_guardPos isEqualType [] && { count _guardPos >= 2 }) then {
                if (count _guardPos < 3) then { _guardPos = [(_guardPos select 0), (_guardPos select 1), 0] };
                private _guardGrp = createGroup _sideEnemy;
                private _u = _guardGrp createUnit [selectRandom _enemyUnitsAsset, _guardPos, [], 0, "NONE"];
                if (!isNull _u) then {
                    [_guardGrp] call FAC_applyEnemyScenarioToGroup;
                    _u setPosATL _guardPos;
                    _u setUnitPos "MIDDLE";
                    [_u, "STAND", "FULL", { behaviour _this == "COMBAT" || { !alive _this } }, "COMBAT"] call BIS_fnc_ambientAnimCombat;
                    _allGroups pushBack _guardGrp;
                    _guardCountSpawned = _guardCountSpawned + 1;
                } else {
                    deleteGroup _guardGrp;
                };
            };
        };

        private _areaRadius = 220;
        private _numPatrols = [2 + floor random 2, 1] call _scaleOpforCount;
        for "_g" from 0 to (_numPatrols - 1) do {
            private _angle = random 360;
            private _dist = 40 + random (_areaRadius - 50);
            private _sp = [(_center select 0) + _dist * (cos _angle), (_center select 1) + _dist * (sin _angle), 0];
            _sp = [_sp, 0, 15, 3, 1, 0.4, 0, [], _sp] call BIS_fnc_findSafePos;
            if (_sp isEqualType [] && { count _sp >= 2 }) then {
                _sp = [(_sp select 0), (_sp select 1), (_sp param [2, 0])];
                private _size = [3 + floor random 3, 2] call _scaleOpforCount;
                private _grp = createGroup _sideEnemy;
                for "_k" from 0 to (_size - 1) do {
                    private _cls = if (_k < count _enemyUnitsAsset) then { _enemyUnitsAsset select _k } else { _baseEnemyClass };
                    private _u = _grp createUnit [_cls, _sp, [], 0, "NONE"];
                    if (!isNull _u) then { _u setPosATL _sp };
                };
                if (count units _grp > 0) then {
                    [_grp] call FAC_applyEnemyScenarioToGroup;
                    _grp setBehaviour "SAFE";
                    _grp setCombatMode "YELLOW";
                    for "_w" from 0 to 2 do {
                        private _a = _w * 120 + (random 40);
                        private _d = 50 + random (_areaRadius - 50);
                        private _wpPos = [(_center select 0) + _d * (cos _a), (_center select 1) + _d * (sin _a), 0];
                        private _wp = _grp addWaypoint [_wpPos, 0];
                        _wp setWaypointType "MOVE";
                        _wp setWaypointSpeed "LIMITED";
                        if (_w == 2) then { _wp setWaypointType "CYCLE" };
                    };
                    _allGroups pushBack _grp;
                } else {
                    deleteGroup _grp;
                };
            };
        };

        [_allGroups, _basePos] call FADE_registerEnemyRetreat;

        missionNamespace setVariable ["FADE_assetIntelTaken_" + _taskId, false];
        missionNamespace setVariable ["FADE_assetEntities_" + _taskId, _allGroups];
        missionNamespace setVariable ["FADE_assetObjects_" + _taskId, [_assetVehicle]];
        missionNamespace setVariable ["FADE_assetAborted_" + _taskId, false];

        [_player, _taskId, "Locate and recover the vehicle. Return it within 1000 m of base.", "Asset Retrieval", _center, "car"] call _fnc_createMissionTask;

        private _markerName = "FADE_asset_" + _taskId;
        _player setVariable ["FADE_myMissionMarker", _markerName, true];
        private _marker = createMarker [_markerName, [_center, 100] call _mkrJitter];
        _marker setMarkerType "mil_objective";
        _marker setMarkerColor "ColorYellow";
        _marker setMarkerText _operationName;

        private _grid = mapGridPosition _center;
        private _brief = format ["ASSET RETRIEVAL%1%1TARGET: Grid %2 (vehicle recovery)%1ASSET: %3%1%1Locate and secure the recovery vehicle. Return it to base (within 1000 m) to complete mission.%1", toString [10], _grid, _vehicleName];
        _player setVariable ["FADE_myMissionBrief", _brief, true];
        [format ["<t color='#B0B0B0'>Grid: %1</t><br/><br/><t color='#C0C0C0'>Recover vehicle: %2</t><br/><t color='#C0C0C0'>Return it to base (within 1000 m).</t>", _grid, _vehicleName]] call _showAssignedHint;
        [_player, "Asset Retrieval"] call FADE_notifyOthersMissionStarted;

        private _arQrfPos = +_center;
        if (count _arQrfPos < 3) then { _arQrfPos = [(_arQrfPos select 0), (_arQrfPos select 1), 0] };
        private _arDetect = (_areaRadius + 120) max 280;
        [_taskId, _arQrfPos, _basePos, _enemyUnitsAsset, _allGroups, _arDetect] call FADE_counterAttackStart;

        [_taskId, _basePos, _markerName, _player, _allGroups, _assetVehicle] spawn {
            params ["_taskId", "_basePos", "_markerName", "_player", "_allGroups", "_assetVehicle"];
            private _baseDist = 1000;
            waitUntil {
                sleep 2;
                if (missionNamespace getVariable ["FADE_assetAborted_" + _taskId, false]) exitWith { true };
                if ((_taskId call BIS_fnc_taskState) in ["SUCCEEDED", "CANCELED", "FAILED"]) exitWith { true };
                if (isNull _assetVehicle || { !alive _assetVehicle }) exitWith {
                    [_taskId, "FAILED"] call BIS_fnc_taskSetState;
                    ["<t size='1.2' color='#FF6666'>MISSION FAILED</t><br/><br/><t color='#E0E0E0'>Recovery vehicle destroyed.</t>"] remoteExec ["FADE_showMissionHint", _player];
                    true
                };
                if ((_assetVehicle distance _basePos) <= _baseDist) exitWith {
                    [_taskId, "SUCCEEDED"] call BIS_fnc_taskSetState;
                    ["<t size='1.2' color='#90EE90'>MISSION COMPLETE</t><br/><br/><t color='#E0E0E0'>Recovery vehicle returned to base.</t>"] remoteExec ["FADE_showMissionHint", _player];
                    true
                };
                false
            };
            [_markerName] call FADE_deleteMarkerSafe;
            if (!isNull _player && { (_player getVariable ["FADE_myMissionTaskId", ""]) == _taskId }) then { [_player] call FADE_clearActiveMission };
            missionNamespace setVariable ["FADE_assetIntelTaken_" + _taskId, nil];
            missionNamespace setVariable ["FADE_assetEntities_" + _taskId, nil];
            missionNamespace setVariable ["FADE_assetObjects_" + _taskId, nil];
            missionNamespace setVariable ["FADE_assetAborted_" + _taskId, nil];
            sleep 45;
            { if (!isNull _x) then { { deleteVehicle _x } forEach units _x; deleteGroup _x } } forEach _allGroups;
            if (!isNull _assetVehicle) then { deleteVehicle _assetVehicle };
        };
    };

    private _areaRadius = 220;
    private _house = objNull;
    private _houseBps = [];
    private _center = +_destPos;
    private _zones = +(missionNamespace getVariable ["FADE_civTriggerNames", []]);
    _zones = _zones call BIS_fnc_arrayShuffle;
    private _zonesEligible = [];
    {
        private _trig = missionNamespace getVariable [_x, objNull];
        if (!isNull _trig) then {
            private _zc = getPosATL _trig;
            if (count _zc >= 2 && { (_zc distance _basePos) >= 1500 }) then {
                _zonesEligible pushBack _x;
            };
        };
    } forEach _zones;

    if (count _zonesEligible > 0) then {
        private _maxPasses = 12;
        private _pass = 0;
        while { isNull _house && { _pass < _maxPasses } } do {
            _pass = _pass + 1;
            _zonesEligible = _zonesEligible call BIS_fnc_arrayShuffle;
            {
                if (!isNull _house) exitWith {};
                private _trig = missionNamespace getVariable [_x, objNull];
                if (isNull _trig) then { continue };
                private _zoneCenter = getPosATL _trig;
                if (count _zoneCenter < 3) then { _zoneCenter = [(_zoneCenter select 0), (_zoneCenter select 1), 0] };

                // Requested flow: list buildings in 500m around the selected zone center,
                // keep only those with at least 6 building positions, then pick one.
                private _buildings = nearestObjects [_zoneCenter, ["House", "Building"], 500];
                private _suitable = [];
                {
                    private _bps = _x buildingPos -1;
                    if (count _bps >= 6) then {
                        _suitable pushBack [_x, _bps];
                    };
                } forEach _buildings;

                if (count _suitable > 0) exitWith {
                    private _pick = selectRandom _suitable;
                    _house = _pick param [0, objNull];
                    _houseBps = _pick param [1, []];
                    _center = getPosATL _house;
                };
            } forEach _zonesEligible;
        };
    };

    if (isNull _house || { count _houseBps < 1 }) exitWith {
        [_player] call FADE_clearActiveMission;
        ["<t size='1.2' color='#FF6666'>MISSION ERROR</t><br/><br/><t color='#E0E0E0'>No CIV_T_* zone >=1500m from HQ had a building with at least 6 positions within 500m.</t>"] remoteExec ["FADE_showMissionHint", _player];
    };

    private _assetClass = "Land_PlasticCase_01_small_gray_F";
    private _assetIdx = 0;
    if (count _houseBps >= 3) then {
        // Avoid first/last building positions — often outside.
        _assetIdx = 1 + floor random ((count _houseBps) - 2);
    };
    private _assetBp = _houseBps select _assetIdx;
    if (count _assetBp < 3) then { _assetBp = [(_assetBp select 0), (_assetBp select 1), 0] };
    private _intelObj = createVehicle [_assetClass, _assetBp, [], 0, "NONE"];
    if (isNull _intelObj) exitWith {
        [_player] call FADE_clearActiveMission;
        ["<t size='1.2' color='#FF6666'>MISSION ERROR</t><br/><br/><t color='#E0E0E0'>Failed to spawn asset object.</t>"] remoteExec ["FADE_showMissionHint", _player];
    };
    _intelObj setPosATL _assetBp;
    _intelObj setDir (getDir _house);

    private _assetCfg = configFile >> "CfgVehicles" >> _assetClass;
    private _assetName = if (isClass _assetCfg) then { getText (_assetCfg >> "displayName") } else { _assetClass };
    if (_assetName == "") then { _assetName = _assetClass };

    private _assetBarrel = objNull;
    private _barrelPos = [_center, 8, 22, 2, 1, 0.3, 0, [], _center] call BIS_fnc_findSafePos;
    if (_barrelPos isEqualType [] && { count _barrelPos >= 2 }) then {
        _barrelPos = [(_barrelPos select 0), (_barrelPos select 1), (_barrelPos param [2, 0])];
        _assetBarrel = createVehicle ["MetalBarrel_burning_F", _barrelPos, [], 0, "NONE"];
        if (!isNull _assetBarrel) then { _assetBarrel setPosATL _barrelPos };
    };

    private _allGroups = [];
    private _garrisonCount = 0;
    private _guardCountSpawned = 0;
    private _garrisonCap = 40;
    private _guardCap = 20;
    private _perNearbyBuildingCap = 3;
    for "_i" from 0 to ((count _houseBps) - 1) do {
        if (_garrisonCount >= _garrisonCap) exitWith {};
        if (_i == _assetIdx) then { continue };
        private _pos = _houseBps select _i;
        if (count _pos >= 2 && { random 1 < 0.75 }) then {
            if (count _pos < 3) then { _pos = [(_pos select 0), (_pos select 1), 0] };
            private _grp = createGroup _sideEnemy;
            private _u = _grp createUnit [selectRandom _enemyUnitsAsset, _pos, [], 0, "NONE"];
            if (!isNull _u) then {
                [_grp] call FAC_applyEnemyScenarioToGroup;
                _u setPosATL _pos;
                _u setUnitPos "MIDDLE";
                [_u, "STAND", "FULL", { behaviour _this == "COMBAT" || { !alive _this } }, "COMBAT"] call BIS_fnc_ambientAnimCombat;
                _allGroups pushBack _grp;
                _garrisonCount = _garrisonCount + 1;
            } else {
                deleteGroup _grp;
            };
        };
    };

    if (_garrisonCount == 0 && { _garrisonCap > 0 }) then {
        private _fallbackIdx = 0;
        if (_fallbackIdx == _assetIdx && { count _houseBps > 1 }) then { _fallbackIdx = 1 };
        private _fallbackPos = _houseBps select _fallbackIdx;
        if (count _fallbackPos < 3) then { _fallbackPos = [(_fallbackPos select 0), (_fallbackPos select 1), 0] };
        private _grp = createGroup _sideEnemy;
        private _u = _grp createUnit [_baseEnemyClass, _fallbackPos, [], 0, "NONE"];
        if (!isNull _u) then {
            [_grp] call FAC_applyEnemyScenarioToGroup;
            _u setPosATL _fallbackPos;
            _u setUnitPos "MIDDLE";
            [_u, "STAND", "FULL", { behaviour _this == "COMBAT" || { !alive _this } }, "COMBAT"] call BIS_fnc_ambientAnimCombat;
            _allGroups pushBack _grp;
            _garrisonCount = 1;
        } else {
            deleteGroup _grp;
        };
    };

    // Nearby-building garrison: within 200m, each position has 33% chance for one enemy.
    private _nearBuildings = (nearestObjects [_center, ["House", "Building"], 200]) select {
        !(_x isEqualTo _house) && { count (_x buildingPos -1) >= 1 }
    };
    {
        if (_garrisonCount >= _garrisonCap) exitWith {};
        private _bld = _x;
        private _bldPos = _bld buildingPos -1;
        private _bldGrp = createGroup _sideEnemy;
        private _spawnedInBld = 0;
        {
            if (_spawnedInBld >= _perNearbyBuildingCap || { _garrisonCount >= _garrisonCap }) exitWith {};
            private _pos = _x;
            if (count _pos >= 2 && { random 1 < 0.33 }) then {
                if (count _pos < 3) then { _pos = [(_pos select 0), (_pos select 1), 0] };
                private _u = _bldGrp createUnit [selectRandom _enemyUnitsAsset, _pos, [], 0, "NONE"];
                if (!isNull _u) then {
                    _u setPosATL _pos;
                    _u setUnitPos "MIDDLE";
                    [_u, "STAND", "FULL", { behaviour _this == "COMBAT" || { !alive _this } }, "COMBAT"] call BIS_fnc_ambientAnimCombat;
                    _spawnedInBld = _spawnedInBld + 1;
                };
            };
        } forEach _bldPos;

        if (_spawnedInBld > 0) then {
            [_bldGrp] call FAC_applyEnemyScenarioToGroup;
            _allGroups pushBack _bldGrp;
            _garrisonCount = _garrisonCount + _spawnedInBld;
        } else {
            deleteGroup _bldGrp;
        };
    } forEach _nearBuildings;

    // Outside guards: individual units around the target house (within 100m), ambient-combat idle.
    private _guardCount = [3 + floor random 3, 1] call _scaleOpforCount;
    _guardCount = _guardCount min _guardCap;
    for "_g" from 0 to (_guardCount - 1) do {
        if (_guardCountSpawned >= _guardCap) exitWith {};
        private _guardPos = [_center, 12, 100, 3, 1, 0.3, 0, [], _center] call BIS_fnc_findSafePos;
        if (_guardPos isEqualType [] && { count _guardPos >= 2 }) then {
            if (count _guardPos < 3) then { _guardPos = [(_guardPos select 0), (_guardPos select 1), 0] };
            private _guardGrp = createGroup _sideEnemy;
            private _u = _guardGrp createUnit [selectRandom _enemyUnitsAsset, _guardPos, [], 0, "NONE"];
            if (!isNull _u) then {
                [_guardGrp] call FAC_applyEnemyScenarioToGroup;
                _u setPosATL _guardPos;
                _u setUnitPos "MIDDLE";
                [_u, "STAND", "FULL", { behaviour _this == "COMBAT" || { !alive _this } }, "COMBAT"] call BIS_fnc_ambientAnimCombat;
                _allGroups pushBack _guardGrp;
                _guardCountSpawned = _guardCountSpawned + 1;
            } else {
                deleteGroup _guardGrp;
            };
        };
    };

    private _numPatrols = [2 + floor random 2, 1] call _scaleOpforCount;
    for "_g" from 0 to (_numPatrols - 1) do {
        private _angle = random 360;
        private _dist = 40 + random (_areaRadius - 50);
        private _sp = [(_center select 0) + _dist * (cos _angle), (_center select 1) + _dist * (sin _angle), 0];
        _sp = [_sp, 0, 15, 3, 1, 0.4, 0, [], _sp] call BIS_fnc_findSafePos;
        if (_sp isEqualType [] && { count _sp >= 2 }) then {
            _sp = [(_sp select 0), (_sp select 1), (_sp param [2, 0])];
            private _size = [3 + floor random 3, 2] call _scaleOpforCount;
            private _grp = createGroup _sideEnemy;
            for "_k" from 0 to (_size - 1) do {
                private _cls = if (_k < count _enemyUnitsAsset) then { _enemyUnitsAsset select _k } else { _baseEnemyClass };
                private _u = _grp createUnit [_cls, _sp, [], 0, "NONE"];
                if (!isNull _u) then { _u setPosATL _sp };
            };
            if (count units _grp > 0) then {
                [_grp] call FAC_applyEnemyScenarioToGroup;
                _grp setBehaviour "SAFE";
                _grp setCombatMode "YELLOW";
                for "_w" from 0 to 2 do {
                    private _a = _w * 120 + (random 40);
                    private _d = 50 + random (_areaRadius - 50);
                    private _wpPos = [(_center select 0) + _d * (cos _a), (_center select 1) + _d * (sin _a), 0];
                    private _wp = _grp addWaypoint [_wpPos, 0];
                    _wp setWaypointType "MOVE";
                    _wp setWaypointSpeed "LIMITED";
                    if (_w == 2) then { _wp setWaypointType "CYCLE" };
                };
                _allGroups pushBack _grp;
            } else {
                deleteGroup _grp;
            };
        };
    };

    [_allGroups, _basePos] call FADE_registerEnemyRetreat;

    private _assetObjects = [_intelObj];
    if (!isNull _assetBarrel) then { _assetObjects pushBack _assetBarrel };

    missionNamespace setVariable ["FADE_assetIntelTaken_" + _taskId, false];
    _intelObj addAction [
        "Secure intel package",
        {
            (_this select 3) params ["_taskId"];
            [_taskId, _this select 0] remoteExec ["FADE_assetIntelTakeServer", 2];
        },
        [_taskId],
        1.5,
        true,
        true,
        "",
        "(_this distance _target) < 3 && { alive _this }",
        3
    ];

    missionNamespace setVariable ["FADE_assetEntities_" + _taskId, _allGroups];
    missionNamespace setVariable ["FADE_assetObjects_" + _taskId, _assetObjects];
    missionNamespace setVariable ["FADE_assetAborted_" + _taskId, false];

    [_player, _taskId, "Secure the asset object inside the target house, then return to base.", "Asset Retrieval", _center, "search"] call _fnc_createMissionTask;

    private _markerName = "FADE_asset_" + _taskId;
    _player setVariable ["FADE_myMissionMarker", _markerName, true];
    private _marker = createMarker [_markerName, [_center, 100] call _mkrJitter];
    _marker setMarkerType "mil_objective";
    _marker setMarkerColor "ColorYellow";
    _marker setMarkerText _operationName;

    private _grid = mapGridPosition _center;
    private _brief = format ["ASSET RETRIEVAL%1%1SITE: Grid %2 (house objective)%1ASSET: %3%1%1Asset is inside the objective house. Garrison is inside; patrols operate around the house. Use scroll action on the asset to secure it, then RTB within 150 m of base.%1", toString [10], _grid, _assetName];
    _player setVariable ["FADE_myMissionBrief", _brief, true];
    [format ["<t color='#FFFFFF'>Grid: %1</t><br/><br/><t color='#FFFFFF'>Asset: %2</t><br/><t color='#FFFFFF'>Secure inside the house, then RTB.</t>", _grid, _assetName]] call _showAssignedHint;
    [_player, "Asset Retrieval"] call FADE_notifyOthersMissionStarted;

    private _arQrfPos = +_center;
    if (count _arQrfPos < 3) then { _arQrfPos = [(_arQrfPos select 0), (_arQrfPos select 1), 0] };
    private _arDetect = (_areaRadius + 120) max 280;
    [_taskId, _arQrfPos, _basePos, _enemyUnitsAsset, _allGroups, _arDetect] call FADE_counterAttackStart;

    [_taskId, _center, _basePos, _markerName, _player, _allGroups, _assetObjects] spawn {
        params ["_taskId", "_center", "_basePos", "_markerName", "_player", "_allGroups", "_assetObjects"];
        private _baseDist = 150;
        waitUntil {
            sleep 2;
            if (missionNamespace getVariable ["FADE_assetAborted_" + _taskId, false]) exitWith { true };
            if ((_taskId call BIS_fnc_taskState) in ["SUCCEEDED", "CANCELED", "FAILED"]) exitWith { true };
            if (
                missionNamespace getVariable ["FADE_assetIntelTaken_" + _taskId, false] &&
                { !isNull _player } &&
                { alive _player } &&
                { (_player distance _basePos) <= _baseDist }
            ) exitWith {
                [_taskId, "SUCCEEDED"] call BIS_fnc_taskSetState;
                ["<t size='1.2' color='#90EE90'>MISSION COMPLETE</t><br/><br/><t color='#E0E0E0'>Intel secured and returned to base.</t>"] remoteExec ["FADE_showMissionHint", _player];
                true
            };
            false
        };
        [_markerName] call FADE_deleteMarkerSafe;
        if (!isNull _player && { (_player getVariable ["FADE_myMissionTaskId", ""]) == _taskId }) then { [_player] call FADE_clearActiveMission };
        missionNamespace setVariable ["FADE_assetIntelTaken_" + _taskId, nil];
        missionNamespace setVariable ["FADE_assetEntities_" + _taskId, nil];
        missionNamespace setVariable ["FADE_assetObjects_" + _taskId, nil];
        missionNamespace setVariable ["FADE_assetAborted_" + _taskId, nil];
        sleep 45;
        { if (!isNull _x) then { { deleteVehicle _x } forEach units _x; deleteGroup _x } } forEach _allGroups;
        { if (!isNull _x) then { deleteVehicle _x } } forEach _assetObjects;
    };
};

// -----------------------------------------------------------------------------
// 3. CAS / FIRE SUPPORT -- Spawn 1-3 enemy infantry groups (min 750m from friendlies, advancing on friendlies);
//    Friendly infantry only. Friendlies mark with green smoke + sideChat when player within 1km; QRF arms then (FADE_counterAttackStart skip wait).
// -----------------------------------------------------------------------------
if (_missionType == "CAS") exitWith {
    if (count _enemyUnits == 0) exitWith {
        [_player] call FADE_clearActiveMission;
        ["<t size='1.2' color='#FF6666'>MISSION ERROR</t><br/><br/><t color='#E0E0E0'>No enemy units configured.</t>"] remoteExec ["FADE_showMissionHint", _player];
    };

    // Friendly position first (200-400m from objective center); enemies spawn min 750m from friendlies
    private _friendlyPos = [_destPos, 200, 400, 5, 1, 0, 0, [], _destPos] call BIS_fnc_findSafePos;
    private _minEnemyDistFromFriendlies = 750;
    private _numGroups = [2 + floor random 3, 1] call _scaleOpforCount;  // 2 to 4 groups
    private _enemyGroups = [];
    private _groupOffset = 30;  // meters between group spawn rings

    for "_g" from 0 to (_numGroups - 1) do {
        private _angle = random 360;
        private _dist = _minEnemyDistFromFriendlies + (_groupOffset * _g) + (random 80);  // 750m+ from friendlies
        private _grpPos = _friendlyPos getPos [_dist, _angle];
        _grpPos = [_grpPos, 0, 25, 3, 1, 0.4, 0, [], _grpPos] call BIS_fnc_findSafePos;
        if (count _grpPos < 2) then { _grpPos = _friendlyPos getPos [_dist, _angle] };

        private _grpSize = [4 + floor random 7, 2] call _scaleOpforCount;  // 4 to 10 units
        private _shuffled = _enemyUnits call BIS_fnc_arrayShuffle;
        private _grpUnits = (_shuffled select [0, _grpSize min count _shuffled]);
        if (count _grpUnits == 0) then { _grpUnits = [_enemyUnits select 0] };

        private _grp = [_grpPos, _sideEnemy, _grpUnits] call BIS_fnc_spawnGroup;
        [_grp] call FAC_applyEnemyScenarioToGroup;
        if (!isNull _grp && { count units _grp > 0 }) then {
            _grp setBehaviour "AWARE";
            _grp setCombatMode "RED";
            _enemyGroups pushBack _grp;
        };
    };
    [_enemyGroups, _basePos] call FADE_registerEnemyRetreat;
    { _x addWaypoint [_friendlyPos, 0] } forEach _enemyGroups;
    private _casUnits = (_friendlyUnits select [0, 6 min count _friendlyUnits]);
    private _friendlyGroup = [_friendlyPos, _sideFriendly, _casUnits] call BIS_fnc_spawnGroup;
    [_friendlyGroup] call (missionNamespace getVariable ["FADE_assignGroupCallsign", {}]);
    [_friendlyGroup] call FADE_attachNightStrobes;
    _friendlyGroup setBehaviour "COMBAT";
    _friendlyGroup setCombatMode "RED";
    private _casCallsign = _friendlyGroup getVariable ["FADE_callsign", "Alpha 1-1"];
    private _casFriendlyCount = count units _friendlyGroup;
    private _casMarkingLine = "Friendly marking on your arrival (within 1 km): green smoke by day, IR strobes at night (NVG).";

    [_player, _taskId, "Provide fire support to friendly forces at the objective. Mission fails if friendly forces are eliminated.", "CAS / Fire Support", _destPos, "attack"] call _fnc_createMissionTask;

    private _markerName = "FADE_cas_" + _taskId;
    _player setVariable ["FADE_myMissionMarker", _markerName, true];
    private _marker = createMarker [_markerName, [_destPos, 100] call _mkrJitter];
    _marker setMarkerType "mil_objective";
    _marker setMarkerColor "ColorRed";
    _marker setMarkerText _operationName;

    private _grid = mapGridPosition _destPos;
    private _brief = format ["CAS / FIRE SUPPORT%1%1TARGET: AO Grid %2 (marked on map)%1%1Proceed to objective. Friendlies will radio their position when you are within 1 km -- green smoke by day, IR strobes at night (NVG required). Engage hostiles advancing on friendly forces.%1%1Complete when less than 20% of enemy remain. FAIL if all friendly forces are eliminated. No time limit.", toString [10], _grid];
    _player setVariable ["FADE_myMissionBrief", _brief, true];
    private _casSituationHtml = format [
        "<t align='left' color='#FFFFFF'>Supported friendly element: %1.</t><br/><t align='left' color='#FFFFFF'>Friendly strength at objective: %2 soldiers.</t><br/><t align='left' color='#FFFFFF'>%3</t>",
        _casCallsign,
        _casFriendlyCount,
        _casMarkingLine
    ];
    private _casExecutionHtml = format [
        "<t align='left' color='#C0C0C0'>Proceed to AO Grid %1 and support %2 in contact. Prioritise hostiles pressing friendly positions. Mission fails if %2 is eliminated.</t>",
        _grid,
        _casCallsign
    ];
    [
        format ["<t color='#FFFFFF'>AO Grid: %1</t><br/><br/><t color='#FFFFFF'>Support %2 (%3 soldiers) at objective.</t>", _grid, _casCallsign, _casFriendlyCount],
        _casSituationHtml,
        _casExecutionHtml
    ] call _showAssignedHint;
    [_player, "CAS / Fire Support"] call FADE_notifyOthersMissionStarted;

    // Initial air support request from friendly leader at mission start
    [_friendlyGroup, _taskId, _destPos] spawn {
        params ["_grp", "_taskId", "_objPos"];
        sleep 5;
        if (isNull _grp || { count units _grp == 0 }) exitWith {};
        if ((_taskId call BIS_fnc_taskState) in ["SUCCEEDED","CANCELED","FAILED"]) exitWith {};
        private _callsign = _grp getVariable ["FADE_callsign", "Alpha 1-1"];
        private _capable = (units _grp) select { alive _x && { !(_x getVariable ["ACE_isUnconscious", false]) } };
        if (count _capable == 0) exitWith {};
        private _speaker = _capable select 0;
        private _grid = mapGridPosition _objPos;
        [_speaker, format ["All callsigns, this is %1. Requesting immediate close air support at Grid %2. Standby for 5-line. Over.", _callsign, _grid]] call FADE_aiSideChat;
    };

    // 5-line CCA: sent independently after a delay, once task is still active.
    // Waits 25 seconds (gives player time to fly to AO), then fires with live enemy data.
    [_friendlyGroup, _taskId, _enemyGroups] spawn {
        params ["_grp", "_taskId", "_enemyGrps"];
        sleep 25;
        if ((_taskId call BIS_fnc_taskState) in ["SUCCEEDED","CANCELED","FAILED"]) exitWith {};
        if (isNull _grp || { count units _grp == 0 }) exitWith {};
        private _capable = (units _grp) select { alive _x && { !(_x getVariable ["ACE_isUnconscious", false]) } };
        if (count _capable == 0) exitWith {};
        private _speaker = _capable select 0;
        private _callsign = _grp getVariable ["FADE_callsign", "Alpha 1-1"];

        // Find nearest living enemy for 5-line data
        private _nearestEnemy = objNull;
        private _nearestDist = 9999;
        {
            { if (alive _x && { (_x distance _speaker) < _nearestDist }) then { _nearestEnemy = _x; _nearestDist = round (_x distance _speaker) } } forEach units _x;
        } forEach _enemyGrps;

        private _targetElev = if (!isNull _nearestEnemy) then { round ((getPosATL _nearestEnemy) select 2) } else { 0 };
        private _hdg = if (!isNull _nearestEnemy) then { round (_speaker getDir _nearestEnemy) } else { 0 };
        private _enemyCount = 0;
        { _enemyCount = _enemyCount + ({ alive _x } count units _x) } forEach _enemyGrps;
        private _enemySize = if (_enemyCount > 10) then { "platoon-sized" } else { if (_enemyCount > 5) then { "squad-sized" } else { "fireteam-sized" } };
        private _targetDesc = format ["hostile infantry, %1, %2 visible", _enemySize, _enemyCount];
        private _remarks = "friendlies marked green smoke/IR strobes; CLEARED HOT when visual";

        [_speaker, format [
            "All callsigns, this is %1. 5-Line CCA. IP own pos, hdg %2. %3m to target. elevation %4m MSL. %5. %6. CLEARED HOT. Over.",
            _callsign, _hdg, _nearestDist, _targetElev, _targetDesc, _remarks
        ]] call FADE_aiSideChat;
    };

    // When player within 1km: night -- radio callsign; day -- green smoke. QRF counter-attack starts from this moment (same as "detected in zone").
    [_friendlyGroup, _player, _taskId, _destPos, _basePos, _enemyUnits, _enemyGroups] spawn {
        params ["_grp", "_player", "_taskId", "_destPos", "_basePos", "_enemyUnits", "_enemyGroups"];
        private _done = false;
        while { !_done && { !isNull _grp } && { count units _grp > 0 } && { !isNull _player } } do {
            sleep 10;
            if ((_taskId call BIS_fnc_taskState) in ["SUCCEEDED","CANCELED","FAILED"]) exitWith { _done = true };
            private _veh = vehicle _player;
            private _friendlyPos = getPosATL (leader _grp);
            if (_veh distance _friendlyPos < 1000) then {
                private _callsign = _grp getVariable ["FADE_callsign", "Alpha 1-1"];
                private _capable = (units _grp) select { alive _x && { !(_x getVariable ["ACE_isUnconscious", false]) } };
                private _speaker = if (count _capable > 0) then { _capable select 0 } else { objNull };
                private _timeMin = (date select 3) * 60 + (date select 4);
                private _isNight = (_timeMin >= 1170 || { _timeMin <= 270 });
                if (_isNight && { isClass (configFile >> "CfgPatches" >> "ace_attach") }) then {
                    if (!isNull _speaker) then {
                        [_speaker, format ["RZ, This is %1. We're in contact. IR strobes active on all units. Over!", _callsign]] call FADE_aiSideChat;
                    };
                } else {
                    "SmokeShellGreen" createVehicle _friendlyPos;
                    if (!isNull _speaker) then {
                        [_speaker, format ["RZ, This is %1. Marking our position with green smoke. Over.", _callsign]] call FADE_aiSideChat;
                    };
                };
                [_taskId, _destPos, _basePos, _enemyUnits, _enemyGroups, -1, true] call FADE_counterAttackStart;
                _done = true;
            };
        };
    };

    private _initialEnemyCount = 0;
    { _initialEnemyCount = _initialEnemyCount + count units _x } forEach _enemyGroups;
    [_taskId, _enemyGroups, _friendlyGroup, _markerName, _player, _initialEnemyCount] spawn {
        params ["_taskId", "_enemyGroups", "_friendlyGroup", "_markerName", "_player", "_initialEnemyCount"];
        private _threshold = _initialEnemyCount * 0.2;
        waitUntil {
            sleep 1;
            if ((_taskId call BIS_fnc_taskState) in ["SUCCEEDED","CANCELED","FAILED"]) exitWith { true };
            private _friendlyAlive = if (!isNull _friendlyGroup && { count units _friendlyGroup > 0 }) then {
                { alive _x } count units _friendlyGroup
            } else { 0 };
            if (_friendlyAlive == 0) exitWith {
                [_taskId, "FAILED"] call BIS_fnc_taskSetState;
                ["<t size='1.2' color='#FF6666'>MISSION FAILED</t><br/><br/><t color='#E0E0E0'>Friendly forces have been eliminated.</t>"] remoteExec ["FADE_showMissionHint", _player];
                true
            };
            private _aliveCount = 0;
            { _aliveCount = _aliveCount + ({ alive _x } count units _x) } forEach _enemyGroups;
            if (_aliveCount < _threshold) exitWith {
                private _capable = if (!isNull _friendlyGroup) then {
                    (units _friendlyGroup) select { alive _x && { !(_x getVariable ["ACE_isUnconscious", false]) } }
                } else { [] };
                if (count _capable > 0) then {
                    private _callsign = _friendlyGroup getVariable ["FADE_callsign", "Alpha 1-1"];
                    [(_capable select 0), format ["This is %1. Hostiles suppressed. Nice work. Out.", _callsign]] call FADE_aiSideChat;
                };
                [_taskId, "SUCCEEDED"] call BIS_fnc_taskSetState;
                true
            };
            false
        };
        [_markerName] call FADE_deleteMarkerSafe;
        if (!isNull _player && { (_player getVariable ["FADE_myMissionTaskId", ""]) == _taskId }) then { [_player] call FADE_clearActiveMission };
        [_enemyGroups, _friendlyGroup] spawn {
            params ["_enemyGroups", "_friendlyGroup"];
            sleep 60;
            { if (!isNull _x) then { { deleteVehicle _x } forEach units _x; deleteGroup _x } } forEach _enemyGroups;
            if (!isNull _friendlyGroup) then {
                { if (!isNull _x) then { detach _x; deleteVehicle _x } } forEach (_friendlyGroup getVariable ["FADE_irStrobes", []]);
                { deleteVehicle _x } forEach units _friendlyGroup;
                deleteGroup _friendlyGroup;
            };
        };
    };
};

// -----------------------------------------------------------------------------
// 4. CARGO / RESUPPLY -- Spawn cargo at base; spawn small camp + garrison at LZ;
//    player lands at camp → AI walks to vehicle → animation + sideChat → 5s → complete; 60s cleanup
// -----------------------------------------------------------------------------
if (_missionType == "Cargo") exitWith {
    if (isNil "FADE_cargoClasses" || { count FADE_cargoClasses == 0 }) exitWith {
        [_player] call FADE_clearActiveMission;
        ["<t size='1.2' color='#FF6666'>MISSION ERROR</t><br/><br/><t color='#E0E0E0'>No cargo classes configured.</t>"] remoteExec ["FADE_showMissionHint", _player];
    };
    private _cargoClass = selectRandom FADE_cargoClasses;
    if (isNil "_cargoClass" || { _cargoClass == "" }) exitWith {
        [_player] call FADE_clearActiveMission;
        ["<t size='1.2' color='#FF6666'>MISSION ERROR</t><br/><br/><t color='#E0E0E0'>Invalid cargo class.</t>"] remoteExec ["FADE_showMissionHint", _player];
    };
    // Spawn cargo at CargoPoint_1 marker; findSafePos avoids clipping with vehicles
    private _cargoCenter = getMarkerPos "CargoPoint_1";
    if (_cargoCenter isEqualTo [0,0,0]) then { _cargoCenter = _basePos };
    if (count _cargoCenter < 3) then { _cargoCenter = [(_cargoCenter select 0), (_cargoCenter select 1), 0] };
    private _cargoPos = [_cargoCenter, 0, 8, 4, 1, 0.3, 0, [], _cargoCenter] call BIS_fnc_findSafePos;
    _cargoPos = [(_cargoPos select 0), (_cargoPos select 1), (_cargoPos param [2, 0])];
    private _cargo = createVehicle [_cargoClass, _cargoPos, [], 0, "NONE"];
    _cargo setPosATL _cargoPos;
    _cargo enableRopeAttach true;

    // Small camp composition at destination (BIS-style: createVehicle at relative positions)
    private _campObjects = [];
    // [classname, distance from center, angle, object rotation offset]
    private _campComposition = [
        ["Land_TentA_F", 8, 0, 0],
        ["Land_TentDome_F", 10, 180, 0],
        ["Land_CampingTable_F", 5, 90, 0],
        ["Land_CampingChair_V2_F", 6, 120, 0],
        ["Land_CampingChair_V2_F", 6, 60, 0],
        ["Campfire_burning_F", 4, 270, 0],
        ["Box_NATO_Ammo_F", 12, 45, 0],
        ["Box_NATO_Support_F", 12, 315, 0]
    ];
    {
        _x params ["_class", "_dist", "_angle", "_dirObj"];
        private _pos = [(_destPos select 0) + _dist * (cos _angle), (_destPos select 1) + _dist * (sin _angle), (_destPos param [2, 0])];
        _pos = [_pos, 0, 2, 0, 1, 0.3, 0, [], _pos] call BIS_fnc_findSafePos;
        if (_pos isEqualType [] && { count _pos >= 2 }) then {
            _pos = [(_pos select 0), (_pos select 1), (_pos param [2, 0])];
            private _obj = createVehicle [_class, _pos, [], 0, "NONE"];
            _obj setDir (_angle + _dirObj);
            _obj setPosATL _pos;
            if (surfaceIsWater _pos) then { _obj setPosATL [_pos select 0, _pos select 1, 0] } else { _obj setVectorUp surfaceNormal _pos };
            _campObjects pushBack _obj;
        };
    } forEach _campComposition;

    // Single receiving unit (the one who walks to the helicopter and confirms unload)
    private _receiverClass = _friendlyUnits select 0;
    private _garrisonPos = [_destPos, 0, 8, 2, 1, 0.3, 0, [], _destPos] call BIS_fnc_findSafePos;
    if (count _garrisonPos < 2) then { _garrisonPos = _destPos };
    private _garrisonGroup = [_garrisonPos, _sideFriendly, [_receiverClass]] call BIS_fnc_spawnGroup;
    [_garrisonGroup] call (missionNamespace getVariable ["FADE_assignGroupCallsign", {}]);
    _garrisonGroup setBehaviour "SAFE";
    _garrisonGroup setCombatMode "GREEN";
    {
        private _p = [_garrisonPos, 0, 3, 0, 1, 0.2, 0, [], _garrisonPos] call BIS_fnc_findSafePos;
        if (_p isEqualType [] && { count _p >= 2 }) then { _x setPos [(_p select 0), (_p select 1), (_p param [2, 0])] };
        doStop _x;
    } forEach (units _garrisonGroup);

    // Two patrol groups (2-4 units each) patrolling 200m radius of camp
    private _cargoPatrolGroups = [];
    for "_pg" from 0 to 1 do {
        private _patrolSize = 2 + floor random 3;
        private _patrolClasses = (_friendlyUnits select [0, _patrolSize min count _friendlyUnits]);
        for "_k" from (count _patrolClasses) to (_patrolSize - 1) do { _patrolClasses pushBack (_friendlyUnits select 0) };
        private _patrolAngle = _pg * 180 + (random 60);
        private _patrolDist = 30 + random 80;
        private _psp = [(_destPos select 0) + _patrolDist * (cos _patrolAngle), (_destPos select 1) + _patrolDist * (sin _patrolAngle), 0];
        _psp = [_psp, 0, 15, 3, 1, 0.3, 0, [], _psp] call BIS_fnc_findSafePos;
        if (count _psp < 2) then { _psp = _destPos };
        private _pg_grp = [_psp, _sideFriendly, _patrolClasses] call BIS_fnc_spawnGroup;
        [_pg_grp] call (missionNamespace getVariable ["FADE_assignGroupCallsign", {}]);
        _pg_grp setBehaviour "SAFE";
        _pg_grp setCombatMode "GREEN";
        for "_w" from 0 to 3 do {
            private _wa = _w * 90 + (random 30);
            private _wd = 80 + random 120;
            private _wpPos = [(_destPos select 0) + _wd * (cos _wa), (_destPos select 1) + _wd * (sin _wa), 0];
            _wpPos = [_wpPos, 0, 10, 2, 1, 0.3, 0, [], _wpPos] call BIS_fnc_findSafePos;
            if (_wpPos isEqualType [] && { count _wpPos >= 2 }) then {
                _wpPos = [(_wpPos select 0), (_wpPos select 1), (_wpPos param [2, 0])];
                private _wp = _pg_grp addWaypoint [_wpPos, 0];
                _wp setWaypointType "MOVE";
                _wp setWaypointSpeed "LIMITED";
                if (_w == 3) then { _wp setWaypointType "CYCLE" };
            };
        };
        _cargoPatrolGroups pushBack _pg_grp;
    };

    [_player, _taskId, "Deliver cargo to the camp. Land at the camp for the receiving party to unload.", "Cargo / Resupply", _destPos, "box"] call _fnc_createMissionTask;

    private _markerName = "FADE_cargo_" + _taskId;
    _player setVariable ["FADE_myMissionMarker", _markerName, true];
    private _marker = createMarker [_markerName, [_destPos, 100] call _mkrJitter];
    _marker setMarkerType "loc_bunker";
    _marker setMarkerColor "ColorYellow";
    _marker setMarkerText _operationName;

    // Cargo box pickup marker - only visible while this mission is active
    private _cargoPickupMarkerName = "FADE_cargoPickup_" + _taskId;
    private _cargoPickupMarker = createMarker [_cargoPickupMarkerName, [_cargoPos, 100] call _mkrJitter];
    _cargoPickupMarker setMarkerType "mil_box";
    _cargoPickupMarker setMarkerColor "ColorYellow";
    _cargoPickupMarker setMarkerText _operationName;

    private _grid = mapGridPosition _destPos;
    private _cargoGrid = mapGridPosition _cargoPos;
    private _brief = format ["CARGO / RESUPPLY%1%1TARGET: Camp Grid %2 (marked on map)%1%1A cargo box is available at Grid %3 (marked) if you want to practice sling load; bringing it to camp is optional. To complete the mission, fly to the camp and land -- the receiving party will confirm unload.%1%1Complete by landing at camp.", toString [10], _grid, _cargoGrid];
    _player setVariable ["FADE_myMissionBrief", _brief, true];
    [format ["<t color='#FFFFFF'>Camp Grid: %1</t><br/><t color='#FFFFFF'>Cargo Box: Grid %2 (optional sling load)</t><br/><br/><t color='#FFFFFF'>Fly to camp and land to complete. Delivering the box is optional.</t>", _grid, _cargoGrid]] call _showAssignedHint;
    [_player, "Cargo / Resupply"] call FADE_notifyOthersMissionStarted;

    [_taskId, _cargo, _destPos, _markerName, 900, _player, _campObjects, _garrisonGroup, _cargoPatrolGroups, _cargoPickupMarkerName] spawn {
        params ["_taskId", "_cargo", "_destPos", "_markerName", "_timeout", "_player", "_campObjects", "_garrisonGroup", "_cargoPatrolGroups", "_cargoPickupMarkerName"];
        private _start = time;
        private _unloadStarted = false;
        private _unloadStartTime = 0;
        private _contactMsgSent = false;
        private _receivingUnit = objNull;
        private _callsign = if (!isNull _garrisonGroup) then { _garrisonGroup getVariable ["FADE_callsign", "Alpha 1-1"] } else { "Alpha 1-1" };
        if (!isNull _garrisonGroup && { count units _garrisonGroup > 0 }) then { _receivingUnit = leader _garrisonGroup };

        private _waitDone = false;
        waitUntil {
            sleep 0.5;
            if ((_taskId call BIS_fnc_taskState) in ["SUCCEEDED","CANCELED","FAILED"]) then { _waitDone = true };

            if (!_waitDone && { time - _start > _timeout }) then { _waitDone = true };

            if (!_waitDone && !_unloadStarted && !isNull _player && { alive _player }) then {
                private _veh = vehicle _player;
                private _refPos = if (_veh == _player) then { _player } else { _veh };
                private _nearCamp = _refPos distance _destPos < 50;
                if (_nearCamp && !_contactMsgSent && !isNull _receivingUnit && { alive _receivingUnit }) then {
                    [_receivingUnit, format ["This is %1. We have you in sight. Land when ready. Over.", _callsign]] call FADE_aiSideChat;
                    _contactMsgSent = true;
                };
                private _isHeli = _veh isKindOf "Helicopter" && _veh != _player;
                private _landedHeli = _isHeli && { (isTouchingGround _veh) || ((getPosATL _veh select 2) < 2.5 && speed _veh < 6) };
                private _onFootAtCamp = _veh == _player && { _player distance _destPos < 45 };
                if ((_landedHeli || _onFootAtCamp) && _nearCamp && !isNull _receivingUnit && { alive _receivingUnit }) then {
                    _unloadStarted = true;
                    _unloadStartTime = time;
                    private _targetVeh = if (_veh == _player) then { objNull } else { _veh };
                    if (!isNull _targetVeh) then {
                        [_receivingUnit, format ["This is %1. Moving to receive. Over.", _callsign]] call FADE_aiSideChat;
                        private _approachPos = _targetVeh getPos [8, getDir _targetVeh];
                        _approachPos = [_approachPos, 0, 2, 0, 1, 0.3, 0, [], _approachPos] call BIS_fnc_findSafePos;
                        if (_approachPos isEqualType [] && { count _approachPos >= 2 }) then {
                            _approachPos = [(_approachPos select 0), (_approachPos select 1), (_approachPos param [2, 0])];
                            _receivingUnit doMove _approachPos;
                        } else {
                            _receivingUnit doMove (getPos _targetVeh);
                        };
                    } else {
                        [_receivingUnit, format ["This is %1. Confirm drop-off. Out.", _callsign]] call FADE_aiSideChat;
                        [_taskId, "SUCCEEDED"] call BIS_fnc_taskSetState;
                        [_markerName] call FADE_deleteMarkerSafe;
                        [_cargoPickupMarkerName] call FADE_deleteMarkerSafe;
                        if (!isNull _player && { (_player getVariable ["FADE_myMissionTaskId", ""]) == _taskId }) then { [_player] call FADE_clearActiveMission };
                        [_campObjects, _garrisonGroup, _cargo, _cargoPatrolGroups] spawn {
                            params ["_campObjects", "_garrisonGroup", "_cargo", "_pgGrps"];
                            sleep 60;
                            { if (!isNull _x) then { deleteVehicle _x } } forEach _campObjects;
                            if (!isNull _garrisonGroup) then { { if (!isNull _x) then { deleteVehicle _x } } forEach units _garrisonGroup; deleteGroup _garrisonGroup };
                            if (!isNull _cargo) then { deleteVehicle _cargo };
                            { if (!isNull _x) then { { if (!isNull _x) then { deleteVehicle _x } } forEach units _x; deleteGroup _x } } forEach _pgGrps;
                        };
                        _waitDone = true;
                    };
                };
            };

            if (!_waitDone && _unloadStarted && !isNull _receivingUnit && { alive _receivingUnit }) then {
                private _veh = vehicle _player;
                if (_veh == _player) then { _veh = objNull };
                if (!isNull _veh && { _receivingUnit distance _veh < 10 }) then {
                    doStop _receivingUnit;
                    _receivingUnit switchMove "AinvPknlMstpSnonWnonDnon_medic0";
                    [_receivingUnit, format ["This is %1. Receiving. Offloading cargo, give me a few seconds. Out.", _callsign]] call FADE_aiSideChat;
                    sleep 5;
                    [_taskId, "SUCCEEDED"] call BIS_fnc_taskSetState;
                    [_markerName] call FADE_deleteMarkerSafe;
                    [_cargoPickupMarkerName] call FADE_deleteMarkerSafe;
                    if (!isNull _player && { (_player getVariable ["FADE_myMissionTaskId", ""]) == _taskId }) then { [_player] call FADE_clearActiveMission };
                    [_campObjects, _garrisonGroup, _cargo, _cargoPatrolGroups] spawn {
                        params ["_campObjects", "_garrisonGroup", "_cargo", "_pgGrps"];
                        sleep 60;
                        { if (!isNull _x) then { deleteVehicle _x } } forEach _campObjects;
                        if (!isNull _garrisonGroup) then { { if (!isNull _x) then { deleteVehicle _x } } forEach units _garrisonGroup; deleteGroup _garrisonGroup };
                        if (!isNull _cargo) then { deleteVehicle _cargo };
                        { if (!isNull _x) then { { if (!isNull _x) then { deleteVehicle _x } } forEach units _x; deleteGroup _x } } forEach _pgGrps;
                    };
                    _waitDone = true;
                } else {
                    if (time - _unloadStartTime > 25) then {
                        [_receivingUnit, format ["This is %1. Confirm drop-off. Out.", _callsign]] call FADE_aiSideChat;
                        [_taskId, "SUCCEEDED"] call BIS_fnc_taskSetState;
                        [_markerName] call FADE_deleteMarkerSafe;
                        [_cargoPickupMarkerName] call FADE_deleteMarkerSafe;
                        if (!isNull _player && { (_player getVariable ["FADE_myMissionTaskId", ""]) == _taskId }) then { [_player] call FADE_clearActiveMission };
                        [_campObjects, _garrisonGroup, _cargo, _cargoPatrolGroups] spawn {
                            params ["_campObjects", "_garrisonGroup", "_cargo", "_pgGrps"];
                            sleep 60;
                            { if (!isNull _x) then { deleteVehicle _x } } forEach _campObjects;
                            if (!isNull _garrisonGroup) then { { if (!isNull _x) then { deleteVehicle _x } } forEach units _garrisonGroup; deleteGroup _garrisonGroup };
                            if (!isNull _cargo) then { deleteVehicle _cargo };
                            { if (!isNull _x) then { { if (!isNull _x) then { deleteVehicle _x } } forEach units _x; deleteGroup _x } } forEach _pgGrps;
                        };
                        _waitDone = true;
                    };
                };
            };

            _waitDone
        };

        if (!((_taskId call BIS_fnc_taskState) in ["SUCCEEDED","CANCELED","FAILED"])) then {
            [_taskId, "CANCELED"] call BIS_fnc_taskSetState;
        };
        [_markerName] call FADE_deleteMarkerSafe;
        [_cargoPickupMarkerName] call FADE_deleteMarkerSafe;
        if (!isNull _player && { (_player getVariable ["FADE_myMissionTaskId", ""]) == _taskId }) then { [_player] call FADE_clearActiveMission };
        if ((_taskId call BIS_fnc_taskState) != "SUCCEEDED") then {
            [_campObjects, _garrisonGroup, _cargo, _cargoPatrolGroups] spawn {
                params ["_campObjects", "_garrisonGroup", "_cargo", "_pgGrps"];
                sleep 60;
                { if (!isNull _x) then { deleteVehicle _x } } forEach _campObjects;
                if (!isNull _garrisonGroup) then { { if (!isNull _x) then { deleteVehicle _x } } forEach units _garrisonGroup; deleteGroup _garrisonGroup };
                if (!isNull _cargo) then { deleteVehicle _cargo };
                { if (!isNull _x) then { { if (!isNull _x) then { deleteVehicle _x } } forEach units _x; deleteGroup _x } } forEach _pgGrps;
            };
        };
    };
};

// -----------------------------------------------------------------------------
// 5. HVT -- High Value Target in urban building; guards (ambient combat anim) + patrols; complete on kill or capture at base
// -----------------------------------------------------------------------------
if (_missionType == "HVT") exitWith {
    private _hvtMinSlots = 10;
    private _buildRadius = 250;
    private _patrolRadius = 250;
    private _baseDistForComplete = 80;
    private _minDistHVT = 1000;

    private _targetBuilding = objNull;
    private _attempt = 0;
    while { _attempt < 15 } do {
        _attempt = _attempt + 1;
        if (_attempt > 1) then {
            _destPos = [_minDistHVT] call FADE_findMissionPosUrban;
            if (count _destPos >= 2) then { _destPos = [(_destPos select 0), (_destPos select 1), (_destPos param [2, 0])] };
        };
        if (count _destPos < 2) exitWith {};
        private _buildings = nearestObjects [_destPos, ["House", "Building"], _buildRadius];
        {
            private _bps = _x buildingPos -1;
            if (count _bps >= _hvtMinSlots) exitWith { _targetBuilding = _x };
        } forEach _buildings;
        if (!isNull _targetBuilding) exitWith {};
    };

    if (isNull _targetBuilding) exitWith {
        [_player] call FADE_clearActiveMission;
        ["<t size='1.2' color='#FF6666'>MISSION ERROR</t><br/><br/><t color='#E0E0E0'>No suitable building (10+ positions) in any urban area. Try again.</t>"] remoteExec ["FADE_showMissionHint", _player];
    };

    private _bpos = _targetBuilding buildingPos -1;
    if (count _bpos < _hvtMinSlots) exitWith {
        [_player] call FADE_clearActiveMission;
        ["<t size='1.2' color='#FF6666'>MISSION ERROR</t><br/><br/><t color='#E0E0E0'>Building has insufficient positions.</t>"] remoteExec ["FADE_showMissionHint", _player];
    };

    private _officerClasses = _enemyUnits select { ("officer" in (toLower _x)) };
    private _hvtClass = if (count _officerClasses > 0) then { selectRandom _officerClasses } else { if (count _enemyUnits > 0) then { selectRandom _enemyUnits } else { selectRandom _fallbackEnemyInf } };
    private _guardCount = [6 + floor random 4, 2] call _scaleOpforCount;
    private _guardClasses = (_enemyUnits select [0, _guardCount min count _enemyUnits]);
    for "_i" from (count _guardClasses) to (_guardCount - 1) do { _guardClasses pushBack (_enemyUnits select 0) };
    private _patrolGroupCount = [1 + floor random 3, 1] call _scaleOpforCount;
    private _patrolSize = [6 + floor random 7, 2] call _scaleOpforCount;

    private _hvtCodename = selectRandom ["Viktor", "Dmitri", "Sergei", "Ivan", "Pavel", "Boris", "Volkov", "Kozlov"];
    private _hvtSlot = 2 + floor random ((count _bpos - 4) max 1);
    private _hvtPos = _bpos select _hvtSlot;
    if (count _hvtPos < 3) then { _hvtPos = [(_hvtPos select 0), (_hvtPos select 1), (_hvtPos param [2, 0])] };
    private _guardIndices = [];
    for "_i" from 0 to (count _bpos - 1) do { if (_i != _hvtSlot) then { _guardIndices pushBack _i } };

    private _hvtGroup = createGroup _sideEnemy;
    // Create HVT at a general building-interior position first, then snap to exact slot
    private _hvt = _hvtGroup createUnit [_hvtClass, getPosATL _targetBuilding, [], 0, "NONE"];
    // Disable movement and pathfinding BEFORE setPos to prevent AI from immediately walking away
    _hvt disableAI "PATH";
    _hvt disableAI "MOVE";
    _hvt allowDamage false;
    _hvt setPos _hvtPos;
    removeAllWeapons _hvt;
    removeAllItems _hvt;
    removeHeadgear _hvt;
    _hvt setIdentity ("FADE_hvt_" + _hvtCodename);
    [_hvt, _hvtPos] spawn {
        params ["_u", "_p"];
        sleep 0.2;
        _u setPos _p;
        removeAllWeapons _u;
        removeAllItems _u;
        removeHeadgear _u;
        private _berets = ["H_Beret_02", "H_Beret_Colonel", "H_Beret_Blk", "H_Beret_ocamo", "H_Beret_red", "H_Beret_gen_F"];
        { if (isClass (configFile >> "CfgWeapons" >> _x)) exitWith { _u addHeadgear _x } } forEach _berets;
        sleep 0.3;
        _u setPos _p;
        _u allowDamage true;
    };
    _hvt setUnitPos "MIDDLE";
    [_hvt, "SIT_LOW", "NONE", { !alive _this }, "COMBAT"] call BIS_fnc_ambientAnimCombat;
    private _hvtTypeName = getText (configFile >> "CfgVehicles" >> _hvtClass >> "displayName");
    if (_hvtTypeName == "") then { _hvtTypeName = _hvtClass };

    private _guardGroup = createGroup _sideEnemy;
    for "_i" from 0 to (_guardCount - 1) do {
        if (_i >= count _guardIndices) exitWith {};
        private _idx = _guardIndices select _i;
        private _p = _bpos select _idx;
        if (count _p < 3) then { _p = [(_p select 0), (_p select 1), (_p param [2, 0])] };
        private _cls = _guardClasses select (_i mod (count _guardClasses));
        private _u = _guardGroup createUnit [_cls, _p, [], 0, "NONE"];
        _u setUnitPos "MIDDLE";
        [_u, "STAND", "FULL", { behaviour _this == "COMBAT" || { !alive _this } }, "COMBAT"] call BIS_fnc_ambientAnimCombat;
    };
    [_guardGroup] call FAC_applyEnemyScenarioToGroup;

    private _buildingCenterPatrol = getPosATL _targetBuilding;
    if (count _buildingCenterPatrol < 3) then { _buildingCenterPatrol = [(_buildingCenterPatrol select 0), (_buildingCenterPatrol select 1), 0] };
    private _patrolBaseDist = 150;
    private _patrolDistVariance = 100;

    private _patrolGroups = [];
    for "_pg" from 0 to (_patrolGroupCount - 1) do {
        private _angle = random 360;
        private _dist = _patrolBaseDist + (random (2 * _patrolDistVariance) - _patrolDistVariance);
        if (_dist < 50) then { _dist = 50 };
        private _cx = (_buildingCenterPatrol select 0) + _dist * (cos _angle);
        private _cy = (_buildingCenterPatrol select 1) + _dist * (sin _angle);
        private _sp = [_cx, _cy, 0];
        _sp = [_sp, 0, 15, 3, 1, 0.4, 0, [], _sp] call BIS_fnc_findSafePos;
        if (_sp isEqualType [] && { count _sp >= 2 }) then {
            _sp = [(_sp select 0), (_sp select 1), (_sp param [2, 0])];
            private _patrolClasses = (_enemyUnits select [0, _patrolSize min count _enemyUnits]);
            for "_k" from (count _patrolClasses) to (_patrolSize - 1) do { _patrolClasses pushBack (_enemyUnits select 0) };
            private _grp = [_sp, _sideEnemy, _patrolClasses] call BIS_fnc_spawnGroup;
            [_grp] call FAC_applyEnemyScenarioToGroup;
            _grp setBehaviour "SAFE";
            for "_w" from 0 to 3 do {
                private _wpAngle = _w * 90;
                private _wpDist = _patrolBaseDist + (random (2 * _patrolDistVariance) - _patrolDistVariance);
                if (_wpDist < 50) then { _wpDist = 50 };
                private _wpPos = [(_buildingCenterPatrol select 0) + _wpDist * (cos _wpAngle), (_buildingCenterPatrol select 1) + _wpDist * (sin _wpAngle), 0];
                _wpPos = [_wpPos, 0, 10, 2, 1, 0.4, 0, [], _wpPos] call BIS_fnc_findSafePos;
                if (_wpPos isEqualType [] && { count _wpPos >= 2 }) then {
                    _wpPos = [(_wpPos select 0), (_wpPos select 1), (_wpPos param [2, 0])];
                    private _wp = _grp addWaypoint [_wpPos, 0];
                    _wp setWaypointType "MOVE";
                    _wp setWaypointSpeed "LIMITED";
                    if (_w == 3) then { _wp setWaypointType "CYCLE" };
                };
            };
            _patrolGroups pushBack _grp;
        };
    };

    // Additional guards garrisoned in nearby buildings (200 m radius), same as Hostage pattern
    private _hvtSurroundRadius = 200;
    private _hvtSurroundBuildings = (nearestObjects [getPosATL _targetBuilding, ["House", "Building"], _hvtSurroundRadius] select {
        !(_x isEqualTo _targetBuilding) && { count (_x buildingPos -1) >= 1 }
    }) select { random 1 < 0.4 };
    {
        private _bld = _x;
        private _bldPos = _bld buildingPos -1;
        if (_bldPos isEqualTo []) then {} else {
            private _cnt = ([1 + floor random 3, 1] call _scaleOpforCount) min count _bldPos;
            private _indices = [];
            for "_i" from 0 to (count _bldPos - 1) do { _indices pushBack _i };
            _indices = _indices call BIS_fnc_arrayShuffle;
            private _surroundGrp = createGroup _sideEnemy;
            for "_i" from 0 to (_cnt - 1) do {
                private _p = _bldPos select (_indices select _i);
                if (count _p < 3) then { _p = [(_p select 0), (_p select 1), (_p param [2, 0])] };
                private _cls = selectRandom _enemyUnits;
                private _u = _surroundGrp createUnit [_cls, _p, [], 0, "NONE"];
                _u setUnitPos "MIDDLE";
                [_u, "STAND", "FULL", { behaviour _this == "COMBAT" || { !alive _this } }, "COMBAT"] call BIS_fnc_ambientAnimCombat;
            };
            [_surroundGrp] call FAC_applyEnemyScenarioToGroup;
            _patrolGroups pushBack _surroundGrp;
        };
    } forEach _hvtSurroundBuildings;

    private _hvtBarrel = objNull;
    private _buildingCenter = getPosATL _targetBuilding;
    if (count _buildingCenter < 3) then { _buildingCenter = [(_buildingCenter select 0), (_buildingCenter select 1), 0] };
    private _barrelPos = [_buildingCenter, 8, 22, 2, 1, 0.3, 0, [], _buildingCenter] call BIS_fnc_findSafePos;
    if (_barrelPos isEqualType [] && { count _barrelPos >= 2 }) then {
        _barrelPos = [(_barrelPos select 0), (_barrelPos select 1), (_barrelPos param [2, 0])];
        _hvtBarrel = createVehicle ["MetalBarrel_burning_F", _barrelPos, [], 0, "NONE"];
        _hvtBarrel setPosATL _barrelPos;
    };

    [_player, _taskId, "Eliminate or capture the HVT. Return captive to base to complete.", "HVT", getPosATL _targetBuilding, "target"] call _fnc_createMissionTask;
    private _markerName = "FADE_hvt_" + _taskId;
    _player setVariable ["FADE_myMissionMarker", _markerName, true];
    private _marker = createMarker [_markerName, [getPosATL _targetBuilding, 100] call _mkrJitter];
    _marker setMarkerType "mil_objective";
    _marker setMarkerColor _markerEnemy;
    _marker setMarkerText _operationName;

    private _grid = mapGridPosition (getPosATL _targetBuilding);
    private _brief = format ["HVT%1%1TARGET: Grid %2 (urban building)%1HVT: %3 -- %4%1%1Locate and eliminate the HVT, or capture and return them to base. HVT is unarmed and cannot move. Building is guarded; external patrols in the area.%1%1Complete when HVT is killed or delivered to base as captive.", toString [10], _grid, _hvtCodename, _hvtTypeName];
    _player setVariable ["FADE_myMissionBrief", _brief, true];
    [format ["<t color='#FFFFFF'>Grid: %1</t><br/><t color='#FFFFFF'>HVT: %2 -- %3</t><br/><br/><t color='#FFFFFF'>Eliminate or capture and return to base.</t>", _grid, _hvtCodename, _hvtTypeName]] call _showAssignedHint;
    [_player, "HVT"] call FADE_notifyOthersMissionStarted;

    private _allGroups = [_hvtGroup, _guardGroup] + _patrolGroups;
    [[_guardGroup] + _patrolGroups, _basePos] call FADE_registerEnemyRetreat;

    private _hvtObjectivePos = getPosATL _targetBuilding;
    if (count _hvtObjectivePos < 3) then { _hvtObjectivePos = [(_hvtObjectivePos select 0), (_hvtObjectivePos select 1), 0] };
    [_taskId, _hvtObjectivePos, _basePos, _enemyUnits, _allGroups, -1] call FADE_counterAttackStart;

    [_taskId, _hvt, _basePos, _baseDistForComplete, _markerName, _player, _allGroups, _hvtBarrel] spawn {
        params ["_taskId", "_hvt", "_basePos", "_baseDistForComplete", "_markerName", "_player", "_allGroups", "_hvtBarrel"];
        private _done = false;
        private _hvtFleeing = false;

        waitUntil {
            sleep 0.5;
            if ((_taskId call BIS_fnc_taskState) in ["SUCCEEDED","CANCELED","FAILED"]) then { _done = true };
            if (!_done && !alive _hvt) then {
                [_taskId, "SUCCEEDED"] call BIS_fnc_taskSetState;
                _done = true;
            };
            if (!_done && alive _hvt && { _hvt getVariable ["ACE_captives_isHandcuffed", false] || { captive _hvt } }) then {
                if ((_hvt distance _basePos) < _baseDistForComplete) then {
                    [_taskId, "SUCCEEDED"] call BIS_fnc_taskSetState;
                    _done = true;
                };
            };
            // HVT flee behaviour: triggers once on first COMBAT detection; 70% chance to actually flee
            if (!_done && !_hvtFleeing && alive _hvt) then {
                private _alert = false;
                {
                    if (_alert) exitWith {};
                    { if (alive _x && { behaviour _x == "COMBAT" }) exitWith { _alert = true } } forEach units _x;
                } forEach _allGroups;
                if (_alert) then {
                    _hvtFleeing = true;
                    if (random 1 < 0.7) then {
                        _hvt enableAI "PATH";
                        _hvt switchMove "";
                        (group _hvt) setCombatMode "BLUE";
                        private _fleeDir = random 360;
                        private _fleePos = _hvt getPos [200 + random 150, _fleeDir];
                        _fleePos = [_fleePos, 0, 25, 3, 1, 0.5, 0, [], _fleePos] call BIS_fnc_findSafePos;
                        if (_fleePos isEqualType [] && { count _fleePos >= 2 }) then {
                            _hvt doMove _fleePos;
                        };
                    };
                };
            };
            _done
        };

        [_markerName] call FADE_deleteMarkerSafe;
        if (!isNull _player && { (_player getVariable ["FADE_myMissionTaskId", ""]) == _taskId }) then { [_player] call FADE_clearActiveMission };
        [_allGroups, _markerName, _player, _hvtBarrel, _taskId] spawn {
            params ["_groups", "_markerName", "_player", "_hvtBarrel", "_taskId"];
            sleep 60;
            { if (!isNull _x) then { { if (!isNull _x) then { deleteVehicle _x } } forEach units _x; deleteGroup _x } } forEach _groups;
            if (!isNull _hvtBarrel) then { deleteVehicle _hvtBarrel };
            [_markerName] call FADE_deleteMarkerSafe;
            if (!isNull _player && { (_player getVariable ["FADE_myMissionTaskId", ""]) == _taskId }) then { [_player] call FADE_clearActiveMission };
        };
    };
};

// -----------------------------------------------------------------------------
// 5b. HOSTAGE -- Up to 3 civilian hostages in building(s); guards inside, patrols outside; return all alive to base
// -----------------------------------------------------------------------------
if (_missionType == "Hostage") exitWith {
    private _buildRadius = 450;
    private _minSlotsPerBuilding = 5;
    private _minSuitableBuildings = 2;
    private _baseDistForComplete = 100;
    private _minDistHostage = 1000;
    private _maxAttempts = 50;

    private _suitableBuildings = [];
    private _attempt = 0;
    while { _attempt < _maxAttempts } do {
        _attempt = _attempt + 1;
        _destPos = [_minDistHostage] call FADE_findMissionPosUrbanNearCenter;
        if (count _destPos >= 2) then {
            private _buildings = nearestObjects [_destPos, ["House", "Building"], _buildRadius];
            _suitableBuildings = _buildings select { count (_x buildingPos -1) >= _minSlotsPerBuilding };
            if (count _suitableBuildings >= _minSuitableBuildings) exitWith {};
        };
    };
    if (count _suitableBuildings < _minSuitableBuildings) exitWith {
        [_player] call FADE_clearActiveMission;
        ["<t size='1.2' color='#FF6666'>MISSION ERROR</t><br/><br/><t color='#E0E0E0'>No urban area with at least 2 suitable buildings (5+ positions each) near a civ zone. Check CIV_T_* triggers in towns and try again.</t>"] remoteExec ["FADE_showMissionHint", _player];
    };

    private _hostageCount = 1 + floor random 3;
    private _civClasses = missionNamespace getVariable ["FADE_civUnitClasses", ["C_man_1", "C_man_1_1_F", "C_man_polo_1_F"]];
    if (_civClasses isEqualTo []) then { _civClasses = ["C_man_1", "C_man_1_1_F", "C_man_polo_1_F"] };

    private _hostages = [];
    private _guardGroups = [];
    private _patrolGroups = [];
    private _buildingsUsed = [];
    private _hostageGroup = createGroup CIVILIAN;
    private _nextSlotByBuilding = [];
    for "_i" from 0 to (count _suitableBuildings - 1) do { _nextSlotByBuilding pushBack 0 };

    for "_h" from 0 to (_hostageCount - 1) do {
        private _buildingIdx = -1;
        for "_b" from 0 to (count _suitableBuildings - 1) do {
            if ((_nextSlotByBuilding select _b) + _minSlotsPerBuilding <= count ((_suitableBuildings select _b) buildingPos -1)) exitWith { _buildingIdx = _b };
        };
        if (_buildingIdx < 0) exitWith {};
        private _building = _suitableBuildings select _buildingIdx;
        if (!(_building in _buildingsUsed)) then { _buildingsUsed pushBack _building };
        private _bpos = _building buildingPos -1;
        private _startIdx = _nextSlotByBuilding select _buildingIdx;
        _nextSlotByBuilding set [_buildingIdx, _startIdx + _minSlotsPerBuilding];

        private _guardCount = [3 + floor random 4, 1] call _scaleOpforCount;
        private _midOffset = floor ((_minSlotsPerBuilding - 1) / 2);
        private _hostageIdx = _startIdx + _midOffset;
        private _hostagePos = _bpos select _hostageIdx;
        if (count _hostagePos < 3) then { _hostagePos = [(_hostagePos select 0), (_hostagePos select 1), (_hostagePos param [2, 0])] };

        private _civClass = selectRandom _civClasses;
        private _hostage = _hostageGroup createUnit [_civClass, _hostagePos, [], 0, "NONE"];
        removeAllWeapons _hostage;
        removeAllItems _hostage;
        removeHeadgear _hostage;
        removeGoggles _hostage;
        _hostage addGoggles "G_Blindfold_01_black_F";
        _hostage disableAI "PATH";
        _hostage setUnitPos "MIDDLE";
        _hostage switchMove "Acts_ExecutionVictim_Loop";
        _hostages pushBack _hostage;

        private _guardClasses = (_enemyUnits select [0, _guardCount min count _enemyUnits]);
        for "_g" from (count _guardClasses) to (_guardCount - 1) do { _guardClasses pushBack (_enemyUnits select 0) };
        private _guardGroup = createGroup _sideEnemy;
        private _guardSlotIndices = [];
        for "_i" from 0 to (_minSlotsPerBuilding - 1) do {
            if (_startIdx + _i != _hostageIdx) then { _guardSlotIndices pushBack (_startIdx + _i) };
        };
        for "_i" from 0 to (_guardCount - 1) do {
            if (_i >= count _guardSlotIndices) exitWith {};
            private _idx = _guardSlotIndices select _i;
            private _p = _bpos select _idx;
            if (count _p < 3) then { _p = [(_p select 0), (_p select 1), (_p param [2, 0])] };
            private _cls = _guardClasses select (_i mod (count _guardClasses));
            private _u = _guardGroup createUnit [_cls, _p, [], 0, "NONE"];
            _u setUnitPos "MIDDLE";
            [_u, "STAND", "FULL", { behaviour _this == "COMBAT" || { !alive _this } }, "COMBAT"] call BIS_fnc_ambientAnimCombat;
        };
        [_guardGroup] call FAC_applyEnemyScenarioToGroup;
        _guardGroups pushBack _guardGroup;
    };

    if (count _hostages == 0) exitWith {
        [_player] call FADE_clearActiveMission;
        ["<t size='1.2' color='#FF6666'>MISSION ERROR</t><br/><br/><t color='#E0E0E0'>Could not place hostages.</t>"] remoteExec ["FADE_showMissionHint", _player];
    };

    // Additional guards in surrounding buildings (200 m radius), 40% chance per building, 1–3 units per building
    private _surroundRadius = 200;
    private _surroundBuildings = (nearestObjects [_destPos, ["House", "Building"], _surroundRadius] select { !(_x in _buildingsUsed) && { count (_x buildingPos -1) >= 1 } }) select { random 1 < 0.4 };
    {
        private _bld = _x;
        private _bpos = _bld buildingPos -1;
        if (_bpos isEqualTo []) then {} else {
            private _count = [1 + floor random 3, 1] call _scaleOpforCount;
            _count = _count min count _bpos;
            private _indices = [];
            for "_i" from 0 to (count _bpos - 1) do { _indices pushBack _i };
            _indices = _indices call BIS_fnc_arrayShuffle;
            private _guardClasses = (_enemyUnits select [0, _count min count _enemyUnits]);
            for "_k" from (count _guardClasses) to (_count - 1) do { _guardClasses pushBack (_enemyUnits select 0) };
            private _surroundGrp = createGroup _sideEnemy;
            for "_i" from 0 to (_count - 1) do {
                private _idx = _indices select _i;
                private _p = _bpos select _idx;
                if (count _p < 3) then { _p = [(_p select 0), (_p select 1), (_p param [2, 0])] };
                private _cls = _guardClasses select (_i mod (count _guardClasses));
                private _u = _surroundGrp createUnit [_cls, _p, [], 0, "NONE"];
                _u setUnitPos "MIDDLE";
                [_u, "STAND", "FULL", { behaviour _this == "COMBAT" || { !alive _this } }, "COMBAT"] call BIS_fnc_ambientAnimCombat;
            };
            [_surroundGrp] call FAC_applyEnemyScenarioToGroup;
            _guardGroups pushBack _surroundGrp;
        };
    } forEach _surroundBuildings;

    private _patrolBaseDist = 80;
    private _patrolDistVariance = 40;
    {
        private _building = _x;
        private _buildingCenter = getPosATL _building;
        if (count _buildingCenter < 3) then { _buildingCenter = [(_buildingCenter select 0), (_buildingCenter select 1), 0] };
        for "_pg" from 0 to 1 do {
            private _angle = random 360;
            private _dist = _patrolBaseDist + (random (2 * _patrolDistVariance) - _patrolDistVariance);
            if (_dist < 40) then { _dist = 40 };
            private _cx = (_buildingCenter select 0) + _dist * (cos _angle);
            private _cy = (_buildingCenter select 1) + _dist * (sin _angle);
            private _sp = [_cx, _cy, 0];
            _sp = [_sp, 0, 15, 3, 1, 0.4, 0, [], _sp] call BIS_fnc_findSafePos;
            if (_sp isEqualType [] && { count _sp >= 2 }) then {
                _sp = [(_sp select 0), (_sp select 1), (_sp param [2, 0])];
                private _patrolSize = [2 + floor random 3, 1] call _scaleOpforCount;
                private _patrolClasses = (_enemyUnits select [0, _patrolSize min count _enemyUnits]);
                for "_k" from (count _patrolClasses) to (_patrolSize - 1) do { _patrolClasses pushBack (_enemyUnits select 0) };
                private _grp = [_sp, _sideEnemy, _patrolClasses] call BIS_fnc_spawnGroup;
                [_grp] call FAC_applyEnemyScenarioToGroup;
                _grp setBehaviour "SAFE";
                for "_w" from 0 to 3 do {
                    private _wpAngle = _w * 90;
                    private _wpDist = _patrolBaseDist + (random (2 * _patrolDistVariance) - _patrolDistVariance);
                    if (_wpDist < 40) then { _wpDist = 40 };
                    private _wpPos = [(_buildingCenter select 0) + _wpDist * (cos _wpAngle), (_buildingCenter select 1) + _wpDist * (sin _wpAngle), 0];
                    _wpPos = [_wpPos, 0, 10, 2, 1, 0.4, 0, [], _wpPos] call BIS_fnc_findSafePos;
                    if (_wpPos isEqualType [] && { count _wpPos >= 2 }) then {
                        _wpPos = [(_wpPos select 0), (_wpPos select 1), (_wpPos param [2, 0])];
                        private _wp = _grp addWaypoint [_wpPos, 0];
                        _wp setWaypointType "MOVE";
                        _wp setWaypointSpeed "LIMITED";
                        if (_w == 3) then { _wp setWaypointType "CYCLE" };
                    };
                };
                _patrolGroups pushBack _grp;
            };
        };
    } forEach _buildingsUsed;

    private _missionCenter = getPosATL (_buildingsUsed select 0);
    if (count _missionCenter < 3) then { _missionCenter = [(_missionCenter select 0), (_missionCenter select 1), 0] };

    [_player, _taskId, "Rescue the hostages. Return all alive hostages to base (within 100 m). Mission fails if more than half die.", "Hostage", _missionCenter, "run"] call _fnc_createMissionTask;
    private _markerName = "FADE_hostage_" + _taskId;
    _player setVariable ["FADE_myMissionMarker", _markerName, true];
    private _marker = createMarker [_markerName, [_missionCenter, 100] call _mkrJitter];
    _marker setMarkerType "mil_objective";
    _marker setMarkerColor "ColorCIV";
    _marker setMarkerText _operationName;

    private _grid = mapGridPosition _missionCenter;
    private _brief = format ["HOSTAGE%1%1TARGET: Grid %2 (urban building(s))%1HOSTAGES: %3 civilian(s)%1%1Rescue the hostages from the building(s). Each is guarded; patrols operate outside. Return all alive hostages to base (within 100 m). Mission fails if more than half the hostages die.%1%1Complete when every surviving hostage is at base.", toString [10], _grid, count _hostages];
    _player setVariable ["FADE_myMissionBrief", _brief, true];
    [format ["<t color='#FFFFFF'>Grid: %1</t><br/><t color='#FFFFFF'>%2 hostage(s)</t><br/><br/><t color='#FFFFFF'>Rescue and return all alive to base (within 100 m).</t>", _grid, count _hostages]] call _showAssignedHint;
    [_player, "Hostage"] call FADE_notifyOthersMissionStarted;

    private _initialHostageCount = count _hostages;
    private _allGroups = [_hostageGroup] + _guardGroups + _patrolGroups;
    [_guardGroups + _patrolGroups, _basePos] call FADE_registerEnemyRetreat;

    [_taskId, _missionCenter, _basePos, _enemyUnits, _allGroups, -1] call FADE_counterAttackStart;

    [_taskId, _hostages, _basePos, _baseDistForComplete, _markerName, _player, _allGroups, _initialHostageCount] spawn {
        params ["_taskId", "_hostages", "_basePos", "_baseDistForComplete", "_markerName", "_player", "_allGroups", "_initialHostageCount"];
        private _done = false;

        waitUntil {
            sleep 0.5;
            if ((_taskId call BIS_fnc_taskState) in ["SUCCEEDED","CANCELED","FAILED"]) then { _done = true };
            private _alive = _hostages select { alive _x };
            private _aliveCount = count _alive;
            if (!_done && _aliveCount < (ceil (_initialHostageCount / 2))) then {
                [_taskId, "FAILED"] call BIS_fnc_taskSetState;
                ["<t size='1.2' color='#FF6666'>MISSION FAILED</t><br/><br/><t color='#E0E0E0'>Too many hostages lost.</t>"] remoteExec ["FADE_showMissionHint", _player];
                _done = true;
            };
            if (!_done && _aliveCount > 0) then {
                private _allAtBase = (_alive findIf { (_x distance _basePos) >= _baseDistForComplete }) == -1;
                if (_allAtBase) then {
                    [_taskId, "SUCCEEDED"] call BIS_fnc_taskSetState;
                    _done = true;
                };
            };
            _done
        };

        [_markerName] call FADE_deleteMarkerSafe;
        if (!isNull _player && { (_player getVariable ["FADE_myMissionTaskId", ""]) == _taskId }) then { [_player] call FADE_clearActiveMission };
        [_allGroups, _markerName, _player, _hostages, _taskId] spawn {
            params ["_groups", "_markerName", "_player", "_hostages", "_taskId"];
            sleep 60;
            { if (!isNull _x) then { { if (!isNull _x) then { deleteVehicle _x } } forEach units _x; deleteGroup _x } } forEach _groups;
            { if (!isNull _x) then { deleteVehicle _x } } forEach _hostages;
            [_markerName] call FADE_deleteMarkerSafe;
            if (!isNull _player && { (_player getVariable ["FADE_myMissionTaskId", ""]) == _taskId }) then { [_player] call FADE_clearActiveMission };
        };
    };
};

// -----------------------------------------------------------------------------
// 6. CLEAR AREA -- Occupied town (civ zone) or enemy camp; destroy 80% of enemies
// -----------------------------------------------------------------------------
if (_missionType == "ClearArea") exitWith {
    // Use same resolved list as rest of Missions.sqf (FADE_resolveScenarioEnemyUnits — scenario faction first)
    private _enemyUnitsCA = +_enemyUnits;
    _enemyUnitsCA = [_enemyUnitsCA] call (missionNamespace getVariable ["FADE_filterEnemyUnitsArmed", { _this select 0 }]);
    if (count _enemyUnitsCA == 0) exitWith {
        [_player] call FADE_clearActiveMission;
        ["<t size='1.2' color='#FF6666'>MISSION ERROR</t><br/><br/><t color='#E0E0E0'>No enemy units configured.</t>"] remoteExec ["FADE_showMissionHint", _player];
    };
    // Use only classnames from our list (no createUnit with side default that could spawn CSAT)
    private _baseClassCA = _enemyUnitsCA select 0;
    private _useTown = random 1 > 0.5;
    private _center = _destPos;
    private _campObjects = [];
    // Must exist before camp branch: stationary spawns push into _allGroups (was after town/camp block - undefined variable)
    private _allGroups = [];
    if (_useTown) then {
        private _civZones = missionNamespace getVariable ["FADE_civTriggerNames", []];
        if (count _civZones > 0) then {
            private _zoneName = selectRandom _civZones;
            private _trig = missionNamespace getVariable [_zoneName, objNull];
            if (!isNull _trig) then { _center = getPosATL _trig };
        };
    } else {
        _center = [_destPos, 0, 400, 100, 1, 0.3, 0, [], _destPos] call BIS_fnc_findSafePos;
        if (count _center < 2) then { _center = _destPos };
        if (count _center < 3) then { _center = [(_center select 0), (_center select 1), 0] };
        // Multiple camp compositions to choose from randomly for variety
        private _campVariants = [
            // Variant A: patrol forward base
            [
                ["Land_TentA_F", 12, 0], ["Land_TentDome_F", 15, 180], ["Land_CampingTable_F", 8, 90],
                ["Campfire_burning_F", 6, 270], ["Box_NATO_Ammo_F", 18, 45], ["Box_NATO_Support_F", 18, 315]
            ],
            // Variant B: dug-in position with sandbags
            [
                ["Land_BagFence_Round_F", 5, 0], ["Land_BagFence_Round_F", 5, 90], ["Land_BagFence_Round_F", 5, 180],
                ["Land_TentA_F", 16, 225], ["Campfire_burning_F", 4, 315], ["Box_NATO_Ammo_F", 20, 60]
            ],
            // Variant C: roadside checkpoint
            [
                ["Land_Barrier_01_wide_F", 8, 0], ["Land_Barrier_01_wide_F", 8, 180],
                ["Land_CampingTable_F", 6, 90], ["Campfire_burning_F", 5, 270],
                ["Land_TentDome_F", 14, 45], ["Box_NATO_Ammo_F", 16, 135]
            ],
            // Variant D: logistics camp
            [
                ["Land_TentA_F", 10, 30], ["Land_TentA_F", 10, 150], ["Land_TentDome_F", 14, 270],
                ["Land_CampingTable_F", 7, 60], ["Land_CampingChair_V2_F", 8, 100],
                ["Box_NATO_Ammo_F", 20, 0], ["Box_NATO_Support_F", 20, 180], ["Campfire_burning_F", 5, 230]
            ],
            // Variant E: minimal hide
            [
                ["Land_TentDome_F", 8, 0], ["Campfire_burning_F", 5, 180],
                ["Box_NATO_Ammo_F", 12, 90], ["Land_CampingTable_F", 10, 270]
            ]
        ];
        private _campComp = selectRandom _campVariants;
        {
            _x params ["_cls", "_dist", "_angle"];
            private _p = [(_center select 0) + _dist * (cos _angle), (_center select 1) + _dist * (sin _angle), 0];
            _p = [_p, 0, 2, 0, 1, 0.3, 0, [], _p] call BIS_fnc_findSafePos;
            if (_p isEqualType [] && { count _p >= 2 }) then {
                _p = [(_p select 0), (_p select 1), (_p param [2, 0])];
                private _obj = createVehicle [_cls, _p, [], 0, "NONE"];
                _obj setPosATL _p;
                _campObjects pushBack _obj;
            };
        } forEach _campComp;

        // Stationary enemies at the camp itself (ambient combat anims like HVT/Hostage guards)
        private _stationaryCount = [3 + floor random 5, 1] call _scaleOpforCount;
        private _campCenterArea = [_center, 0, 20, 2, 1, 0.4, 0, [], _center] call BIS_fnc_findSafePos;
        if (count _campCenterArea < 2) then { _campCenterArea = _center };
        for "_si" from 0 to (_stationaryCount - 1) do {
            private _angle = (_si / _stationaryCount) * 360 + (random 30 - 15);
            private _dist = 3 + random 12;
            private _p = [(_center select 0) + _dist * (cos _angle), (_center select 1) + _dist * (sin _angle), 0];
            _p = [_p, 0, 2, 0, 1, 0.3, 0, [], _p] call BIS_fnc_findSafePos;
            if (_p isEqualType [] && { count _p >= 2 }) then {
                _p = [(_p select 0), (_p select 1), (_p param [2, 0])];
                private _cls = selectRandom _enemyUnitsCA;
                private _grp = createGroup _sideEnemy;
                private _u = _grp createUnit [_cls, _p, [], 0, "NONE"];
                if (!isNull _u) then {
                    [_grp] call FAC_applyEnemyScenarioToGroup;
                    _u setPos _p;
                    _u setUnitPos "MIDDLE";
                    [_u, "STAND", "FULL", { behaviour _this == "COMBAT" || { !alive _this } }, "COMBAT"] call BIS_fnc_ambientAnimCombat;
                    _allGroups pushBack _grp;
                } else { deleteGroup _grp };
            };
        };
    };
    if (count _center >= 2 && { count _center < 3 }) then { _center = [(_center select 0), (_center select 1), 0] };
    private _areaRadius = if (_useTown) then { 280 } else { 120 };
    private _buildings = nearestObjects [_center, ["House", "Building"], _areaRadius];
    private _usedPositions = [];
    private _maxUnitsPerBuilding = 2;
    private _maxGarrisonTotal = [35, 8] call _scaleOpforCount;
    {
        private _bps = _x buildingPos -1;
        private _addedThisBuilding = 0;
        for "_i" from 0 to (count _bps - 1) do {
            if (count _usedPositions >= _maxGarrisonTotal) exitWith {};
            if (_addedThisBuilding >= _maxUnitsPerBuilding) exitWith {};
            private _pos = _bps select _i;
            if (count _pos >= 2) then {
                if (count _pos < 3) then { _pos = [(_pos select 0), (_pos select 1), 0] };
                private _cls = selectRandom _enemyUnitsCA;
                private _grp = createGroup _sideEnemy;
                private _u = _grp createUnit [_cls, _pos, [], 0, "NONE"];
                if (!isNull _u) then {
                    [_grp] call FAC_applyEnemyScenarioToGroup;
                    _u setPos _pos;
                    _u setUnitPos "MIDDLE";
                    [_u, "STAND", "FULL", { behaviour _this == "COMBAT" || { !alive _this } }, "COMBAT"] call BIS_fnc_ambientAnimCombat;
                    _allGroups pushBack _grp;
                    _usedPositions pushBack _pos;
                    _addedThisBuilding = _addedThisBuilding + 1;
                };
            };
        };
        if (count _usedPositions >= _maxGarrisonTotal) exitWith {};
    } forEach _buildings;
    private _numPatrols = [2 + floor random 3, 1] call _scaleOpforCount;
    for "_g" from 0 to (_numPatrols - 1) do {
        private _angle = random 360;
        private _dist = 30 + random (_areaRadius - 30);
        private _sp = [(_center select 0) + _dist * (cos _angle), (_center select 1) + _dist * (sin _angle), 0];
        _sp = [_sp, 0, 15, 3, 1, 0.4, 0, [], _sp] call BIS_fnc_findSafePos;
        if (_sp isEqualType [] && { count _sp >= 2 }) then {
            _sp = [(_sp select 0), (_sp select 1), (_sp param [2, 0])];
            private _size = [3 + floor random 5, 1] call _scaleOpforCount;
            private _grp = createGroup _sideEnemy;
            for "_k" from 0 to (_size - 1) do {
                private _cls = if (_k < count _enemyUnitsCA) then { _enemyUnitsCA select _k } else { _baseClassCA };
                private _u = _grp createUnit [_cls, _sp, [], 0, "NONE"];
                if (!isNull _u) then { _u setPos _sp };
            };
            if (count units _grp > 0) then {
                [_grp] call FAC_applyEnemyScenarioToGroup;
                _grp setBehaviour "SAFE";
                for "_w" from 0 to 3 do {
                    private _a = _w * 90 + (random 30);
                    private _d = 40 + random (_areaRadius - 40);
                    private _wpPos = [(_center select 0) + _d * (cos _a), (_center select 1) + _d * (sin _a), 0];
                    private _wp = _grp addWaypoint [_wpPos, 0];
                    _wp setWaypointType "MOVE";
                    _wp setWaypointSpeed "LIMITED";
                    if (_w == 3) then { _wp setWaypointType "CYCLE" };
                };
                _allGroups pushBack _grp;
            } else { deleteGroup _grp };
        };
    };
    private _areaVehicles = [];
    private _enemyVehList = missionNamespace getVariable ["FADE_enemyVehicles", []];
    if (_enemyVehList isEqualTo []) then {
        private _ef = missionNamespace getVariable ["FADE_scenarioEnemyFaction", "OPF_F"];
        _enemyVehList = [_ef] call FADE_getEnemyVehiclesForFaction;
    };
    private _landVehClasses = _enemyVehList select { !(_x isKindOf "Air") && { !(_x isKindOf "Ship") } };
    if (count _landVehClasses > 0) then {
        private _roads = _center nearRoads _areaRadius;
        if (count _roads > 0) then {
            private _numVeh = [1 + floor random 3, 1] call _scaleOpforCount;
            _numVeh = _numVeh min count _roads;
            private _roadShuf = _roads call BIS_fnc_arrayShuffle;
            for "_nv" from 0 to (_numVeh - 1) do {
                private _roadObj = _roadShuf select _nv;
                private _roadPos = getPosATL _roadObj;
                if (count _roadPos < 3) then { _roadPos = [(_roadPos select 0), (_roadPos select 1), 0] };
                private _vClass = selectRandom _landVehClasses;
                private _veh = createVehicle [_vClass, _roadPos, [], 0, "NONE"];
                if (!isNull _veh) then {
                    _veh setPosATL _roadPos;
                    _areaVehicles pushBack _veh;
                    private _vehGrp = createGroup _sideEnemy;
                    private _driver = _vehGrp createUnit [selectRandom _enemyUnitsCA, _roadPos, [], 0, "NONE"];
                    if (!isNull _driver) then { _driver moveInDriver _veh };
                    if (_veh emptyPositions "gunner" > 0) then {
                        private _g = _vehGrp createUnit [selectRandom _enemyUnitsCA, _roadPos, [], 0, "NONE"];
                        if (!isNull _g) then { _g moveInGunner _veh };
                    };
                    if (_veh emptyPositions "commander" > 0) then {
                        private _c = _vehGrp createUnit [selectRandom _enemyUnitsCA, _roadPos, [], 0, "NONE"];
                        if (!isNull _c) then { _c moveInCommander _veh };
                    };
                    [_vehGrp] call FAC_applyEnemyScenarioToGroup;
                    _vehGrp setBehaviour "SAFE";
                    _vehGrp setSpeedMode "LIMITED";
                    private _wpAngle = random 360;
                    private _wpDist = 30 + random 170;
                    private _wpPos = [(_center select 0) + _wpDist * (cos _wpAngle), (_center select 1) + _wpDist * (sin _wpAngle), 0];
                    _wpPos = [_wpPos, 0, 20, 10, 1, 0.3, 0, [], _wpPos] call BIS_fnc_findSafePos;
                    if (_wpPos isEqualType [] && { count _wpPos >= 2 }) then {
                        if (count _wpPos < 3) then { _wpPos = [(_wpPos select 0), (_wpPos select 1), 0] };
                        private _wp = _vehGrp addWaypoint [_wpPos, 0];
                        _wp setWaypointType "MOVE";
                        _wp setWaypointSpeed "LIMITED";
                    };
                    _allGroups pushBack _vehGrp;
                };
            };
        };
    };
    [_allGroups, _basePos] call FADE_registerEnemyRetreat;
    private _initialCount = 0;
    { _initialCount = _initialCount + count units _x } forEach _allGroups;
    if (_initialCount == 0) then {
        { if (!isNull _x) then { deleteVehicle _x } } forEach _areaVehicles;
        { if (!isNull _x) then { deleteVehicle _x } } forEach _campObjects;
        [_player] call FADE_clearActiveMission;
        ["<t size='1.2' color='#FF6666'>MISSION ERROR</t><br/><br/><t color='#E0E0E0'>Could not spawn enemies in area.</t>"] remoteExec ["FADE_showMissionHint", _player];
    } else {
        private _markerName = "FADE_clear_" + _taskId;
        _player setVariable ["FADE_myMissionMarker", _markerName, true];
        private _marker = createMarker [_markerName, [_center, 100] call _mkrJitter];
        _marker setMarkerType "mil_objective";
        _marker setMarkerColor _markerEnemy;
        _marker setMarkerText _operationName;
        private _grid = mapGridPosition _center;
        [_player, _taskId, "Destroy at least 80% of enemy forces in the area.", "Clear Area", _center, "attack"] call _fnc_createMissionTask;
        private _brief = format ["CLEAR AREA%1%1TARGET: Grid %2 (%3)%1%1Neutralize at least 80% of enemy forces.", toString [10], _grid, if (_useTown) then { "occupied town" } else { "enemy camp" }];
        _player setVariable ["FADE_myMissionBrief", _brief, true];
        [format ["<t color='#FFFFFF'>Grid: %1 -- %2</t><br/><br/><t color='#FFFFFF'>Destroy 80%%+ of enemy forces.</t>", _grid, if (_useTown) then { "town" } else { "camp" }]] call _showAssignedHint;
        [_player, "Clear Area"] call FADE_notifyOthersMissionStarted;
        private _caDetect = (_areaRadius + 180) max 320;
        [_taskId, _center, _basePos, _enemyUnitsCA, _allGroups, _caDetect] call FADE_counterAttackStart;
        private _clearTimeout = 900;
        [_taskId, _allGroups, _initialCount, _markerName, _player, _campObjects, _areaVehicles, _clearTimeout] spawn {
            params ["_taskId", "_allGroups", "_initialCount", "_markerName", "_player", "_campObjects", "_areaVehicles", "_timeout"];
            private _start = time;
            waitUntil {
                sleep 0.5;
                if ((_taskId call BIS_fnc_taskState) in ["SUCCEEDED","CANCELED","FAILED"]) exitWith { true };
                if (time - _start > _timeout) exitWith { true };
                private _alive = 0;
                { _alive = _alive + ({ alive _x } count units _x) } forEach _allGroups;
                if (_alive <= _initialCount * 0.2) then {
                    [_taskId, "SUCCEEDED"] call BIS_fnc_taskSetState;
                    true
                } else { false };
            };
            if (!((_taskId call BIS_fnc_taskState) in ["SUCCEEDED","CANCELED","FAILED"])) then {
                private _alive = 0;
                { _alive = _alive + ({ alive _x } count units _x) } forEach _allGroups;
                if (_alive <= _initialCount * 0.2) then { [_taskId, "SUCCEEDED"] call BIS_fnc_taskSetState } else { [_taskId, "CANCELED"] call BIS_fnc_taskSetState };
            };
            [_markerName] call FADE_deleteMarkerSafe;
            if (!isNull _player && { (_player getVariable ["FADE_myMissionTaskId", ""]) == _taskId }) then { [_player] call FADE_clearActiveMission };
            [_allGroups, _campObjects, _areaVehicles, _markerName, _player, _taskId] spawn {
                params ["_groups", "_campObjects", "_areaVehicles", "_markerName", "_player", "_taskId"];
                sleep 60;
                { if (!isNull _x) then { { if (!isNull _x) then { deleteVehicle _x } } forEach units _x; deleteGroup _x } } forEach _groups;
                { if (!isNull _x) then { deleteVehicle _x } } forEach _campObjects;
                { if (!isNull _x) then { deleteVehicle _x } } forEach _areaVehicles;
                [_markerName] call FADE_deleteMarkerSafe;
                if (!isNull _player && { (_player getVariable ["FADE_myMissionTaskId", ""]) == _taskId }) then { [_player] call FADE_clearActiveMission };
            };
        };
    };
};

// -----------------------------------------------------------------------------
// 6b. SEARCH & DESTROY -- Three buildings in civ area; garrison only those + patrols
// -----------------------------------------------------------------------------
if (_missionType == "SearchDestroy") exitWith {
    private _enemyUnitsSd = +_enemyUnits;
    _enemyUnitsSd = [_enemyUnitsSd] call (missionNamespace getVariable ["FADE_filterEnemyUnitsArmed", { _this select 0 }]);
    if (count _enemyUnitsSd == 0) exitWith {
        [_player] call FADE_clearActiveMission;
        ["<t size='1.2' color='#FF6666'>MISSION ERROR</t><br/><br/><t color='#E0E0E0'>No enemy units configured.</t>"] remoteExec ["FADE_showMissionHint", _player];
    };
    private _baseClassSd = _enemyUnitsSd select 0;
    // Same civ-zone + near-center pattern as Hostage: random urban pos can land in empty ground — loop until
    // three enterable buildings (2+ buildingPos slots) exist within radius, trying random zones then every CIV_T_*.
    private _minDistUrban = 1000;
    private _areaRadius = 250;
    private _trySdPickBuildings = {
        params ["_pos", "_radius"];
        if (count _pos < 2) exitWith { [[], []] };
        private _c = +_pos;
        if (count _c < 3) then { _c = [(_c select 0), (_c select 1), 0] };
        private _buildings = nearestObjects [_c, ["House", "Building"], _radius];
        private _cands = _buildings call BIS_fnc_arrayShuffle;
        private _pickedTrial = [];
        {
            if (count _pickedTrial >= 3) exitWith {};
            private _bps = _x buildingPos -1;
            if (count _bps >= 2) then { _pickedTrial pushBack _x };
        } forEach _cands;
        if (count _pickedTrial >= 3) then {
            [_c, _pickedTrial select [0, 3]]
        } else {
            [[], []]
        };
    };
    private _center = [];
    private _picked = [];
    private _maxAttempts = 50;
    private _attempt = 0;
    while { _attempt < _maxAttempts } do {
        _attempt = _attempt + 1;
        private _tryPos = [_minDistUrban] call FADE_findMissionPosUrbanNearCenter;
        private _res = [_tryPos, _areaRadius] call _trySdPickBuildings;
        _res params ["_cPos", "_bList"];
        if (count _bList >= 3) exitWith {
            _center = _cPos;
            _picked = _bList;
        };
    };
    if (count _picked < 3) then {
        private _zones = +(missionNamespace getVariable ["FADE_civTriggerNames", []]);
        _zones = _zones call BIS_fnc_arrayShuffle;
        {
            if (count _picked >= 3) exitWith {};
            private _trig = missionNamespace getVariable [_x, objNull];
            if (!isNull _trig) then {
                private _zc = getPosATL _trig;
                if ((_zc distance _basePos) >= _minDistUrban) then {
                    private _tryPos = [_zc, 50, 400, 5, 1, 0.5, 0, [], _zc] call BIS_fnc_findSafePos;
                    private _res2 = [_tryPos, _areaRadius] call _trySdPickBuildings;
                    _res2 params ["_cPos2", "_bList2"];
                    if (count _bList2 >= 3) then {
                        _center = _cPos2;
                        _picked = _bList2;
                    };
                };
            };
        } forEach _zones;
    };

    if (count _picked < 3) exitWith {
        [_player] call FADE_clearActiveMission;
        ["<t size='1.2' color='#FF6666'>MISSION ERROR</t><br/><br/><t color='#E0E0E0'>No town with three enterable buildings near a civ zone (CIV_T_*). Add triggers in built-up areas or try again.</t>"] remoteExec ["FADE_showMissionHint", _player];
    };

    private _allGroups = [];
    private _garrisonCount = 0;
    {
        private _building = _x;
        private _bps = _building buildingPos -1;
        private _addedThis = 0;
        for "_i" from 0 to (count _bps - 1) do {
            if (_addedThis >= 2) exitWith {};
            private _pos = _bps select _i;
            if (count _pos >= 2) then {
                if (count _pos < 3) then { _pos = [(_pos select 0), (_pos select 1), 0] };
                private _cls = selectRandom _enemyUnitsSd;
                private _grp = createGroup _sideEnemy;
                private _u = _grp createUnit [_cls, _pos, [], 0, "NONE"];
                if (!isNull _u) then {
                    [_grp] call FAC_applyEnemyScenarioToGroup;
                    _u setPos _pos;
                    _u setUnitPos "MIDDLE";
                    [_u, "STAND", "FULL", { behaviour _this == "COMBAT" || { !alive _this } }, "COMBAT"] call BIS_fnc_ambientAnimCombat;
                    _allGroups pushBack _grp;
                    _addedThis = _addedThis + 1;
                    _garrisonCount = _garrisonCount + 1;
                } else { deleteGroup _grp };
            };
        };
    } forEach _picked;

    // Burning barrel outside each target building (same placement band as Asset Retrieval).
    private _sdBarrelObjs = [];
    {
        private _building = _x;
        private _buildingCenter = getPosATL _building;
        if (count _buildingCenter < 3) then { _buildingCenter = [(_buildingCenter select 0), (_buildingCenter select 1), 0] };
        private _barrelPos = [_buildingCenter, 8, 22, 2, 1, 0.3, 0, [], _buildingCenter] call BIS_fnc_findSafePos;
        if (_barrelPos isEqualType [] && { count _barrelPos >= 2 }) then {
            _barrelPos = [(_barrelPos select 0), (_barrelPos select 1), (_barrelPos param [2, 0])];
            private _barrel = createVehicle ["MetalBarrel_burning_F", _barrelPos, [], 0, "NONE"];
            if (!isNull _barrel) then {
                _barrel setPosATL _barrelPos;
                _sdBarrelObjs pushBack _barrel;
            };
        };
    } forEach _picked;

    // Nearby-building garrison + outside guards: same caps / logic as Asset Retrieval (mission center = urban anchor).
    private _garrisonCap = 40;
    private _guardCap = 20;
    private _perNearbyBuildingCap = 3;
    private _guardCountSpawned = 0;
    private _nearBuildings = (nearestObjects [_center, ["House", "Building"], 200]) select {
        !(_x in _picked) && { count (_x buildingPos -1) >= 1 }
    };
    {
        if (_garrisonCount >= _garrisonCap) exitWith {};
        private _bld = _x;
        private _bldPos = _bld buildingPos -1;
        private _bldGrp = createGroup _sideEnemy;
        private _spawnedInBld = 0;
        {
            if (_spawnedInBld >= _perNearbyBuildingCap || { _garrisonCount >= _garrisonCap }) exitWith {};
            private _pos = _x;
            if (count _pos >= 2 && { random 1 < 0.33 }) then {
                if (count _pos < 3) then { _pos = [(_pos select 0), (_pos select 1), 0] };
                private _u = _bldGrp createUnit [selectRandom _enemyUnitsSd, _pos, [], 0, "NONE"];
                if (!isNull _u) then {
                    _u setPosATL _pos;
                    _u setUnitPos "MIDDLE";
                    [_u, "STAND", "FULL", { behaviour _this == "COMBAT" || { !alive _this } }, "COMBAT"] call BIS_fnc_ambientAnimCombat;
                    _spawnedInBld = _spawnedInBld + 1;
                };
            };
        } forEach _bldPos;

        if (_spawnedInBld > 0) then {
            [_bldGrp] call FAC_applyEnemyScenarioToGroup;
            _allGroups pushBack _bldGrp;
            _garrisonCount = _garrisonCount + _spawnedInBld;
        } else {
            deleteGroup _bldGrp;
        };
    } forEach _nearBuildings;

    private _guardCount = [3 + floor random 3, 1] call _scaleOpforCount;
    _guardCount = _guardCount min _guardCap;
    for "_g" from 0 to (_guardCount - 1) do {
        if (_guardCountSpawned >= _guardCap) exitWith {};
        private _guardPos = [_center, 12, 100, 3, 1, 0.3, 0, [], _center] call BIS_fnc_findSafePos;
        if (_guardPos isEqualType [] && { count _guardPos >= 2 }) then {
            if (count _guardPos < 3) then { _guardPos = [(_guardPos select 0), (_guardPos select 1), 0] };
            private _guardGrp = createGroup _sideEnemy;
            private _u = _guardGrp createUnit [selectRandom _enemyUnitsSd, _guardPos, [], 0, "NONE"];
            if (!isNull _u) then {
                [_guardGrp] call FAC_applyEnemyScenarioToGroup;
                _u setPosATL _guardPos;
                _u setUnitPos "MIDDLE";
                [_u, "STAND", "FULL", { behaviour _this == "COMBAT" || { !alive _this } }, "COMBAT"] call BIS_fnc_ambientAnimCombat;
                _allGroups pushBack _guardGrp;
                _guardCountSpawned = _guardCountSpawned + 1;
            } else {
                deleteGroup _guardGrp;
            };
        };
    };

    // GM ammo pile props (one per garrisoned building, one building position each) — Global Mobilization CfgVehicles; skipped if not loaded
    private _sdAmmoClasses = [
        "gm_ammobox_pile_small_03_empty",
        "gm_ammobox_pile_small_02_empty",
        "gm_ammobox_pile_large_02_empty"
    ];
    private _sdAmmoClassesOk = _sdAmmoClasses select { isClass (configFile >> "CfgVehicles" >> _x) };
    private _sdAmmoObjs = [];
    if (count _sdAmmoClassesOk > 0) then {
        {
            private _building = _x;
            private _bps = _building buildingPos -1;
            if (count _bps > 0) then {
                private _ammoBp = if (count _bps > 2) then { _bps select 2 } else { selectRandom _bps };
                if (count _ammoBp >= 2) then {
                    if (count _ammoBp < 3) then { _ammoBp = [(_ammoBp select 0), (_ammoBp select 1), 0] };
                    private _cls = selectRandom _sdAmmoClassesOk;
                    private _obj = createVehicle [_cls, _ammoBp, [], 0, "NONE"];
                    if (!isNull _obj) then {
                        _obj setPosATL _ammoBp;
                        _obj setDir ((getDir _building) + random 360);
                        _sdAmmoObjs pushBack _obj;
                    };
                };
            };
        } forEach _picked;
    };

    private _sdCleanupObjs = _sdAmmoObjs + _sdBarrelObjs;

    private _numPatrols = [2, 1] call _scaleOpforCount;
    for "_g" from 0 to (_numPatrols - 1) do {
        private _angle = random 360;
        private _dist = 40 + random (_areaRadius - 50);
        private _sp = [(_center select 0) + _dist * (cos _angle), (_center select 1) + _dist * (sin _angle), 0];
        _sp = [_sp, 0, 15, 3, 1, 0.4, 0, [], _sp] call BIS_fnc_findSafePos;
        if (_sp isEqualType [] && { count _sp >= 2 }) then {
            _sp = [(_sp select 0), (_sp select 1), (_sp param [2, 0])];
            private _size = [3 + floor random 3, 2] call _scaleOpforCount;
            private _grp = createGroup _sideEnemy;
            for "_k" from 0 to (_size - 1) do {
                private _cls = if (_k < count _enemyUnitsSd) then { _enemyUnitsSd select _k } else { _baseClassSd };
                private _u = _grp createUnit [_cls, _sp, [], 0, "NONE"];
                if (!isNull _u) then { _u setPos _sp };
            };
            if (count units _grp > 0) then {
                [_grp] call FAC_applyEnemyScenarioToGroup;
                _grp setBehaviour "SAFE";
                for "_w" from 0 to 2 do {
                    private _a = _w * 120 + (random 40);
                    private _d = 50 + random(_areaRadius - 50);
                    private _wpPos = [(_center select 0) + _d * (cos _a), (_center select 1) + _d * (sin _a), 0];
                    private _wp = _grp addWaypoint [_wpPos, 0];
                    _wp setWaypointType "MOVE";
                    _wp setWaypointSpeed "LIMITED";
                    if (_w == 2) then { _wp setWaypointType "CYCLE" };
                };
                _allGroups pushBack _grp;
            } else { deleteGroup _grp };
        };
    };

    [_allGroups, _basePos] call FADE_registerEnemyRetreat;
    private _initialCount = 0;
    { _initialCount = _initialCount + count units _x } forEach _allGroups;
    if (_initialCount == 0) exitWith {
        { if (!isNull _x) then { deleteVehicle _x } } forEach _sdCleanupObjs;
        [_player] call FADE_clearActiveMission;
        ["<t size='1.2' color='#FF6666'>MISSION ERROR</t><br/><br/><t color='#E0E0E0'>Could not spawn enemies.</t>"] remoteExec ["FADE_showMissionHint", _player];
    };

    missionNamespace setVariable ["FADE_searchDestroyEntities_" + _taskId, [_allGroups, _sdCleanupObjs]];
    missionNamespace setVariable ["FADE_sdAborted_" + _taskId, false];

    private _markerName = "FADE_sd_" + _taskId;
    missionNamespace setVariable ["FADE_searchDestroyMarker_" + _taskId, _markerName];
    _player setVariable ["FADE_myMissionMarker", _markerName, true];
    private _marker = createMarker [_markerName, [_center, 100] call _mkrJitter];
    _marker setMarkerType "mil_objective";
    _marker setMarkerColor _markerEnemy;
    _marker setMarkerText _operationName;

    private _grid = mapGridPosition _center;
    [_player, _taskId, format ["Clear %1 marked buildings and all hostile forces in the area.", count _picked], "Search & Destroy", _center, "attack"] call _fnc_createMissionTask;
    private _brief = format ["SEARCH & DESTROY%1%1%2 buildings in town grid %3 — strongpoints in those structures; garrison in nearby buildings; burning barrels outside each objective; patrols in the area.%1%1Destroy all hostiles.", toString [10], count _picked, _grid];
    _player setVariable ["FADE_myMissionBrief", _brief, true];
    [format ["<t color='#FFFFFF'>Grid: %1</t><br/><br/><t color='#FFFFFF'>Clear %2 buildings + surrounding hostiles.</t>", _grid, count _picked]] call _showAssignedHint;
    [_player, "Search & Destroy"] call FADE_notifyOthersMissionStarted;

    private _sdDetect = (_areaRadius + 120) max 280;
    [_taskId, _center, _basePos, _enemyUnitsSd, _allGroups, _sdDetect] call FADE_counterAttackStart;

    private _sdTimeout = 900;
    [_taskId, _allGroups, _initialCount, _markerName, _player, _sdTimeout, _sdCleanupObjs] spawn {
        params ["_taskId", "_allGroups", "_initialCount", "_markerName", "_player", "_timeout", "_sdCleanupObjs"];
        private _start = time;
        waitUntil {
            sleep 0.5;
            if (missionNamespace getVariable ["FADE_sdAborted_" + _taskId, false]) exitWith { true };
            if ((_taskId call BIS_fnc_taskState) in ["SUCCEEDED", "CANCELED", "FAILED"]) exitWith { true };
            if (time - _start > _timeout) exitWith { true };
            private _alive = 0;
            { _alive = _alive + ({ alive _x } count units _x) } forEach _allGroups;
            if (_alive == 0) exitWith {
                [_taskId, "SUCCEEDED"] call BIS_fnc_taskSetState;
                true
            };
            false
        };
        if ((time - _start > _timeout) && { (_taskId call BIS_fnc_taskState) == "ASSIGNED" }) then {
            [_taskId, "CANCELED"] call BIS_fnc_taskSetState;
        };
        [_markerName] call FADE_deleteMarkerSafe;
        if (!isNull _player && { (_player getVariable ["FADE_myMissionTaskId", ""]) == _taskId }) then { [_player] call FADE_clearActiveMission };
        missionNamespace setVariable ["FADE_searchDestroyEntities_" + _taskId, nil];
        missionNamespace setVariable ["FADE_searchDestroyMarker_" + _taskId, nil];
        missionNamespace setVariable ["FADE_sdAborted_" + _taskId, nil];
        sleep 60;
        { if (!isNull _x) then { { deleteVehicle _x } forEach units _x; deleteGroup _x } } forEach _allGroups;
        { if (!isNull _x) then { deleteVehicle _x } } forEach _sdCleanupObjs;
    };
};

// -----------------------------------------------------------------------------
// 6c. ESCAPE & EVASION — evadees dispersed (500–700 m annulus); hunt patrols + truck QRF; no map markers / task destination
// -----------------------------------------------------------------------------
if (_missionType == "EscapeEvasion") exitWith {
    private _enemyUnitsEe = +_enemyUnits;
    _enemyUnitsEe = [_enemyUnitsEe] call (missionNamespace getVariable ["FADE_filterEnemyUnitsArmed", { _this select 0 }]);
    if (count _enemyUnitsEe == 0) exitWith {
        [_player] call FADE_clearActiveMission;
        ["<t size='1.2' color='#FF6666'>MISSION ERROR</t><br/><br/><t color='#E0E0E0'>No enemy units configured.</t>"] remoteExec ["FADE_showMissionHint", _player];
    };
    private _zoneCenter = +_destPos;
    if (count _zoneCenter < 3) then { _zoneCenter = [(_zoneCenter select 0), (_zoneCenter select 1), 0] };
    private _applyGrpEe = missionNamespace getVariable ["FAC_applyEnemyScenarioToGroup", {}];
    if (_applyGrpEe isEqualTo {}) exitWith {
        [_player] call FADE_clearActiveMission;
        ["<t size='1.2' color='#FF6666'>MISSION ERROR</t><br/><br/><t color='#E0E0E0'>Scenario apply function missing.</t>"] remoteExec ["FADE_showMissionHint", _player];
    };
    private _allGroupsEe = [];
    private _garCap = 20;
    private _guardCap = 15;
    private _bldsEe = (nearestObjects [_zoneCenter, ["House", "Building"], 700]) select { count (_x buildingPos -1) >= 1 };
    _bldsEe = _bldsEe call BIS_fnc_arrayShuffle;
    private _garCount = 0;
    {
        if (_garCount >= _garCap) exitWith {};
        private _bps = (_x buildingPos -1) call BIS_fnc_arrayShuffle;
        private _bldGrp = createGroup _sideEnemy;
        private _spawnedB = 0;
        {
            if (_garCount >= _garCap) exitWith {};
            private _pos = _x;
            if (count _pos < 2) then { };
            if (count _pos >= 2) then {
                if (count _pos < 3) then { _pos = [(_pos select 0), (_pos select 1), 0] };
                private _u = _bldGrp createUnit [selectRandom _enemyUnitsEe, _pos, [], 0, "NONE"];
                if (!isNull _u) then {
                    _u setPosATL _pos;
                    _u setUnitPos "MIDDLE";
                    [_u, "STAND", "FULL", { behaviour _this == "COMBAT" || { !alive _this } }, "COMBAT"] call BIS_fnc_ambientAnimCombat;
                    _garCount = _garCount + 1;
                    _spawnedB = _spawnedB + 1;
                };
            };
        } forEach _bps;
        if (_spawnedB > 0) then {
            [_bldGrp] call _applyGrpEe;
            _allGroupsEe pushBack _bldGrp;
        } else {
            deleteGroup _bldGrp;
        };
    } forEach _bldsEe;

    private _gd = 0;
    while { _gd < _guardCap } do {
        private _ang = random 360;
        private _rd = 25 + random 675;
        private _gp = _zoneCenter getPos [_rd, _ang];
        _gp = [_gp, 0, 22, 5, 1, 0.35, 0, [], _gp] call BIS_fnc_findSafePos;
        if (_gp isEqualType [] && { count _gp >= 2 }) then {
            _gp = [(_gp select 0), (_gp select 1), (_gp param [2, 0])];
            private _gg = createGroup _sideEnemy;
            private _ug = _gg createUnit [selectRandom _enemyUnitsEe, _gp, [], 0, "NONE"];
            if (!isNull _ug) then {
                [_gg] call _applyGrpEe;
                _ug setPosATL _gp;
                _ug setUnitPos "MIDDLE";
                [_ug, "STAND", "FULL", { behaviour _this == "COMBAT" || { !alive _this } }, "COMBAT"] call BIS_fnc_ambientAnimCombat;
                _allGroupsEe pushBack _gg;
                _gd = _gd + 1;
            } else {
                deleteGroup _gg;
            };
        };
    };

    private _findPatrolSpawnEe = {
        params ["_zc", "_evs", "_minPl", "_minZc"];
        private _out = [];
        for "_try" from 0 to 79 do {
            private _dir = random 360;
            private _dist = _minZc + random 3500;
            private _cand = _zc getPos [_dist, _dir];
            _cand = [_cand, 0, 45, 18, 0, 0.35, 0, [], _cand] call BIS_fnc_findSafePos;
            if (!(_cand isEqualType []) || { count _cand < 2 }) then { } else {
                if (_cand distance2D _zc >= _minZc) then {
                    private _bad = false;
                    { if (alive _x && { _cand distance2D _x < _minPl }) exitWith { _bad = true } } forEach _evs;
                    if (!_bad) exitWith { _out = [(_cand select 0), (_cand select 1), (_cand param [2, 0])]; };
                };
            };
        };
        if (count _out < 2) then {
            _out = _zc getPos [4000, random 360];
            if (count _out < 3) then { _out = [(_out select 0), (_out select 1), 0] };
        };
        _out
    };

    {
        private _targetP = _x;
        if (isNull _targetP) then { };
        private _sp = [_zoneCenter, _evadeePlayers, 500, 1000] call _findPatrolSpawnEe;
        private _psz = 4 + (floor random 5);
        private _hGrp = createGroup _sideEnemy;
        for "_k" from 0 to (_psz - 1) do {
            private _cls = if (_k < count _enemyUnitsEe) then { _enemyUnitsEe select _k } else { _enemyUnitsEe select 0 };
            private _hu = _hGrp createUnit [_cls, _sp, [], 0, "NONE"];
            if (!isNull _hu) then { _hu setPosATL _sp };
        };
        if (count units _hGrp > 0) then {
            [_hGrp] call _applyGrpEe;
            _hGrp setBehaviour "AWARE";
            _hGrp setCombatMode "RED";
            _allGroupsEe pushBack _hGrp;
            [_hGrp, _targetP, _taskId] spawn {
                params ["_grp", "_targetP", "_taskId"];
                scriptName "FADE_ee_huntLoop";
                while { true } do {
                    if (missionNamespace getVariable ["FADE_eeAborted_" + _taskId, false]) exitWith {};
                    if ((_taskId call BIS_fnc_taskState) in ["SUCCEEDED", "CANCELED", "FAILED"]) exitWith {};
                    if (isNull _grp || { count units _grp == 0 }) exitWith {};
                    if (isNull _targetP || { !alive _targetP }) exitWith {};
                    if (!isNil "lambs_danger_fnc_taskAttack") then {
                        [_grp, _targetP] call lambs_danger_fnc_taskAttack;
                    } else {
                        while { count waypoints _grp > 0 } do { deleteWaypoint [_grp, 0] };
                        private _wp = _grp addWaypoint [getPosATL _targetP, 0];
                        _wp setWaypointType "SAD";
                        _wp setWaypointBehaviour "AWARE";
                        _wp setWaypointCombatMode "RED";
                    };
                    sleep 55 + (floor random 50);
                };
            };
        } else {
            deleteGroup _hGrp;
        };
    } forEach _evadeePlayers;

    if (count _allGroupsEe == 0) exitWith {
        [_player] call FADE_clearActiveMission;
        ["<t size='1.2' color='#FF6666'>MISSION ERROR</t><br/><br/><t color='#E0E0E0'>Could not spawn Escape &amp; Evasion OPFOR.</t>"] remoteExec ["FADE_showMissionHint", _player];
    };

    [_allGroupsEe, _basePos] call FADE_registerEnemyRetreat;

    {
        [] remoteExec ["FADE_clientStripEvadeeGPS", _x];
    } forEach _evadeePlayers;

    {
        private _evp = _x;
        if (isNull _evp) then { } else {
            private _tp = [];
            for "_attempt" from 0 to 24 do {
                private _dir = random 360;
                private _dist = 500 + random 201;
                private _raw = _zoneCenter getPos [_dist, _dir];
                _tp = [_raw, 0, 14, 5, 1, 0.4, 0, [], _raw] call BIS_fnc_findSafePos;
                if (_tp isEqualType [] && { count _tp >= 2 }) then {
                    _tp = [(_tp select 0), (_tp select 1), (_tp param [2, 0])];
                    private _d2 = _tp distance2D _zoneCenter;
                    if (_d2 >= 480 && { _d2 <= 750 }) exitWith {};
                };
                _tp = [];
            };
            if (count _tp < 2) then {
                private _dir = random 360;
                private _dist = 500 + random 201;
                _tp = _zoneCenter getPos [_dist, _dir];
                _tp = [(_tp select 0), (_tp select 1), (_tp param [2, 0])];
            };
            [_tp] remoteExec ["FADE_clientTeleportPos", _evp];
        };
    } forEach _evadeePlayers;

    missionNamespace setVariable ["FADE_eeEntities_" + _taskId, [_allGroupsEe]];
    missionNamespace setVariable ["FADE_eeAborted_" + _taskId, false];
    missionNamespace setVariable ["FADE_eeQrfVehs_" + _taskId, []];
    missionNamespace setVariable ["FADE_eeSearchHeli_" + _taskId, []];

    private _sfEe = missionNamespace getVariable ["FADE_sideFriendly", west];
    private _taskBuilderEe = missionNamespace getVariable ["FADE_buildMissionTaskSmeacText", {}];
    private _missionTxtEe = "Evadees: survive and return to base (within 1000 m). GPS removed. No task markers — use comms. Any evadee KIA fails the mission. OPFOR will hunt and send truck QRF after contact (10 min cooldown). After 15–20 min, OPFOR may launch a helicopter to search the area (orbit only — no tasking on your position); long gap between sorties.";
    private _taskDescFull = if (_taskBuilderEe isEqualTo {}) then {
        _missionTxtEe
    } else {
        [
            _missionTxtEe,
            _basePos,
            _defaultSituationTaskText,
            _defaultExecutionTaskText,
            _defaultAdminTaskText,
            _defaultCommandTaskText
        ] call _taskBuilderEe
    };
    [_sfEe, _taskId, [_taskDescFull, "Escape & Evasion", ""], objNull, "CREATED", 1, true, "run", false] call BIS_fnc_taskCreate;

    private _briefEe = format ["ESCAPE & EVASION%1%1Selected players are dispersed near a hostile town (no position given). GPS stripped from evadees. All evadees must return within 1000 m of base alive.%1%1Later, OPFOR may send a search helicopter to sweep the area (not directly tasked on you).%1%1Rescue party: no markers — coordinate by radio.", toString [10]];
    if (!isNull _player) then {
        _player setVariable ["FADE_myMissionBrief", _briefEe, true];
    };
    [format ["<t color='#FFFFFF'>Evadees teleported (dispersed). No grid given. RTB 1000 m / all alive.</t>"]] call _showAssignedHint;
    [_player, "Escape & Evasion"] call FADE_notifyOthersMissionStarted;

    // OPFOR search helicopter: faction heli (or FADE_opforAir fallback list), orbit waypoints on zone geometry only — never player positions.
    private _eePickSearchHeliClass = {
        private _air = [] call FADE_getEnemyAirVehicleClasses;
        _air = _air select { _x isKindOf "Helicopter" };
        if (_air isEqualTo []) then {
            _air = +FADE_opforAir_fallbackHeliClasses;
            _air = _air select { isClass (configFile >> "CfgVehicles" >> _x) && { _x isKindOf "Helicopter" } };
        };
        if (_air isEqualTo []) exitWith { "O_Heli_Light_02_dynamicLoadout_F" };
        selectRandom _air
    };

    private _eeDeleteSearchHeli = {
        params ["_veh", "_pilotGrp", "_cargoGrp"];
        if (!isNull _cargoGrp) then {
            { if (!isNull _x) then { deleteVehicle _x } } forEach units _cargoGrp;
            deleteGroup _cargoGrp;
        };
        if (!isNull _veh) then {
            { if (!isNull _x) then { deleteVehicle _x } } forEach crew _veh;
            private _dg = group driver _veh;
            if (!isNull _dg) then {
                { if (!isNull _x) then { deleteVehicle _x } } forEach units _dg;
                deleteGroup _dg;
            };
            deleteVehicle _veh;
        } else {
            if (!isNull _pilotGrp) then {
                { if (!isNull _x) then { deleteVehicle _x } } forEach units _pilotGrp;
                deleteGroup _pilotGrp;
            };
        };
    };

    private _eeSpawnSearchHeli = {
        params ["_tid", "_zc", "_crewUnits", "_applyLoc", "_sideEn"];
        private _zc2 = [_zc select 0, _zc select 1];
        private _mapMinA = missionNamespace getVariable ["FADE_mapMin", 0];
        private _mapMaxA = missionNamespace getVariable ["FADE_mapMax", worldSize];
        private _edgePad = 200;
        private _class = [] call _eePickSearchHeliClass;
        private _dirFrom = random 360;
        private _dist = 2600 + random 1400;
        private _spawn2 = [
            (_zc2 select 0) + _dist * (sin _dirFrom),
            (_zc2 select 1) + _dist * (cos _dirFrom)
        ];
        _spawn2 set [0, (_spawn2 select 0) max (_mapMinA + _edgePad) min (_mapMaxA - _edgePad)];
        _spawn2 set [1, (_spawn2 select 1) max (_mapMinA + _edgePad) min (_mapMaxA - _edgePad)];
        private _alt = (getTerrainHeightASL [_spawn2 select 0, _spawn2 select 1]) + 260 + random 200;
        private _spawnPos = [_spawn2 select 0, _spawn2 select 1, _alt];
        private _face = ((_zc2 select 1) - (_spawn2 select 1)) atan2 ((_zc2 select 0) - (_spawn2 select 0));
        private _veh = createVehicle [_class, _spawnPos, [], 0, "FLY"];
        if (isNull _veh) exitWith { [objNull, grpNull, grpNull] };
        _veh setDir _face;
        { if (!isNull _x) then { deleteVehicle _x } } forEach crew _veh;
        private _grp = createGroup _sideEn;
        private _driver = _grp createUnit [selectRandom _crewUnits, _spawnPos, [], 0, "NONE"];
        if (!isNull _driver) then { _driver moveInDriver _veh; _grp selectLeader _driver };
        if (_veh emptyPositions "gunner" > 0) then {
            private _gn = _grp createUnit [selectRandom _crewUnits, _spawnPos, [], 0, "NONE"];
            if (!isNull _gn) then { _gn moveInGunner _veh };
        };
        if (isNull driver _veh) exitWith {
            { if (!isNull _x) then { deleteVehicle _x } } forEach units _grp;
            deleteGroup _grp;
            deleteVehicle _veh;
            [objNull, grpNull, grpNull]
        };
        [_grp] call _applyLoc;
        _grp setGroupIdGlobal [format ["OPF-EE-SRCH-%1", floor random 999]];
        _grp setBehaviour "AWARE";
        _grp setCombatMode "RED";
        _veh flyInHeight (70 + floor random 60);
        private _orbitR = 520 + random 280;
        private _nPts = 6;
        private _firstWp = [];
        for "_wi" from 0 to (_nPts - 1) do {
            private _ang = (_wi * (360 / _nPts)) + random 25;
            private _p2 = _zc2 getPos [_orbitR, _ang];
            _p2 = [_p2, 0, 120, 22, 0, 0.35, 0, [], _p2] call BIS_fnc_findSafePos;
            if (!(_p2 isEqualType []) || { count _p2 < 2 }) then { _p2 = _zc2 getPos [_orbitR, _ang] };
            private _atlp = [(_p2 select 0), (_p2 select 1), 0];
            if (_wi == 0) then { _firstWp = _atlp };
            private _wp = _grp addWaypoint [_atlp, _wi];
            _wp setWaypointType "MOVE";
            _wp setWaypointSpeed "LIMITED";
            _wp setWaypointBehaviour "AWARE";
            _wp setWaypointCombatMode "RED";
        };
        if (count _firstWp >= 2) then {
            private _wpc = _grp addWaypoint [_firstWp, _nPts];
            _wpc setWaypointType "CYCLE";
        };
        [ _veh, _grp, grpNull ]
    };

    private _eeDeleteQrf = {
        params ["_tid"];
        private _lst = missionNamespace getVariable ["FADE_eeQrfVehs_" + _tid, []];
        {
            private _v = _x;
            if (!isNull _v) then {
                private _cg = _v getVariable ["FADE_eeQrfCargoGrp", grpNull];
                if (!isNull _cg) then {
                    { if (!isNull _x) then { deleteVehicle _x } } forEach units _cg;
                    deleteGroup _cg;
                };
                { if (!isNull _x) then { deleteVehicle _x } } forEach crew _v;
                private _dg = group driver _v;
                if (!isNull _dg) then {
                    { if (!isNull _x) then { deleteVehicle _x } } forEach units _dg;
                    deleteGroup _dg;
                };
                if (!isNull _v) then { deleteVehicle _v };
            };
        } forEach _lst;
        missionNamespace setVariable ["FADE_eeQrfVehs_" + _tid, []];
    };

    private _eeSpawnQrf = {
        params ["_tid", "_detP", "_zc", "_baseQ", "_enemyUnitsLoc", "_applyLoc", "_sideEn"];
        [_tid] call _eeDeleteQrf;
        private _staging = _zc getPos [2200 + random 1800, random 360];
        private _roads = _staging nearRoads 500;
        private _roadPos = [];
        if (count _roads > 0) then {
            _roadPos = getPosATL (selectRandom _roads);
        } else {
            _roadPos = [_staging, 0, 400, 15, 0, 0.35, 0, [], _staging] call BIS_fnc_findSafePos;
        };
        if (count _roadPos < 2) exitWith {};
        if (count _roadPos < 3) then { _roadPos = [(_roadPos select 0), (_roadPos select 1), 0] };
        private _vehClasses = missionNamespace getVariable ["FADE_enemyVehicles", []];
        if (_vehClasses isEqualTo []) then {
            private _ef = missionNamespace getVariable ["FADE_scenarioEnemyFaction", "OPF_F"];
            _vehClasses = [_ef] call FADE_getEnemyVehiclesForFaction;
        };
        private _soft = [];
        {
            if (!(_x isKindOf "Air") && { !(_x isKindOf "Ship") } && { !(_x isKindOf "StaticWeapon") }) then {
                if (!(_x isKindOf "Tank") && { !(_x isKindOf "Wheeled_APC_F") }) then { _soft pushBack _x };
            };
        } forEach _vehClasses;
        private _minCargo = 4;
        private _vehPick = [_soft, _minCargo] call FADE_counterAttack_filterClassesByMinCargo;
        if (count _vehPick == 0) then {
            private _landAll = _vehClasses select { !(_x isKindOf "Air") && { !(_x isKindOf "Ship") } && { !(_x isKindOf "StaticWeapon") } };
            _vehPick = [_landAll, _minCargo] call FADE_counterAttack_filterClassesByMinCargo;
        };
        if (count _vehPick == 0) exitWith {};
        private _vClass = selectRandom _vehPick;
        private _dir = [_roadPos, getPosATL _detP] call BIS_fnc_dirTo;
        private _vehGrp = createGroup _sideEn;
        private _veh = createVehicle [_vClass, _roadPos, [], 0, "NONE"];
        if (isNull _veh) exitWith { deleteGroup _vehGrp };
        _veh setPosATL _roadPos;
        _veh setDir _dir;
        _veh engineOn true;
        private _driver = _vehGrp createUnit [selectRandom _enemyUnitsLoc, _roadPos, [], 0, "NONE"];
        if (!isNull _driver) then {
            _driver moveInDriver _veh;
            _vehGrp selectLeader _driver;
        };
        if (_veh emptyPositions "gunner" > 0) then {
            private _gn = _vehGrp createUnit [selectRandom _enemyUnitsLoc, _roadPos, [], 0, "NONE"];
            if (!isNull _gn) then { _gn moveInGunner _veh };
        };
        [_vehGrp] call _applyLoc;
        _vehGrp setBehaviour "AWARE";
        _vehGrp setCombatMode "RED";
        private _cargoGrp = grpNull;
        private _seats = (_veh emptyPositions "cargo") max 0;
        if (_seats > 0) then {
            _cargoGrp = createGroup _sideEn;
            for "_c" from 0 to ((_seats min 6) - 1) do {
                private _u = _cargoGrp createUnit [selectRandom _enemyUnitsLoc, _roadPos, [], 0, "NONE"];
                if (!isNull _u) then { _u moveInCargo _veh };
            };
            if (count units _cargoGrp > 0) then { [_cargoGrp] call _applyLoc };
        };
        _veh setVariable ["FADE_eeQrfCargoGrp", _cargoGrp];
        private _tgtPos = getPosATL _detP;
        private _wp1 = _vehGrp addWaypoint [_tgtPos, 80];
        _wp1 setWaypointType "MOVE";
        _wp1 setWaypointSpeed "FULL";
        private _wp2 = _vehGrp addWaypoint [_tgtPos, 25];
        _wp2 setWaypointType "SAD";
        [_veh, _vehGrp, _cargoGrp, _tid, _detP] spawn {
            params ["_veh", "_vehGrp", "_cargoGrp", "_tid", "_detP"];
            scriptName "FADE_ee_qrfWp";
            while {
                alive _veh && {!isNull _veh} &&
                {!(((_tid call BIS_fnc_taskState) in ["SUCCEEDED", "CANCELED", "FAILED"]))} &&
                {!missionNamespace getVariable ["FADE_eeAborted_" + _tid, false]}
            } do {
                sleep 40;
                if (!alive _veh || { isNull _veh }) exitWith {};
                if (isNull _detP || { !alive _detP }) exitWith {};
                while { count waypoints _vehGrp > 0 } do { deleteWaypoint [_vehGrp, 0] };
                private _p = getPosATL _detP;
                private _w1 = _vehGrp addWaypoint [_p, 80];
                _w1 setWaypointType "MOVE";
                _w1 setWaypointSpeed "FULL";
                private _w2 = _vehGrp addWaypoint [_p, 20];
                _w2 setWaypointType "SAD";
            };
            if (!isNull _veh && { alive _veh } && {!isNull _cargoGrp} && { count units _cargoGrp > 0 } && {!isNull _detP} && { alive _detP }) then {
                {
                    unassignVehicle _x;
                    _x action ["GetOut", _veh];
                } forEach units _cargoGrp;
            };
        };
        private _cur = missionNamespace getVariable ["FADE_eeQrfVehs_" + _tid, []];
        _cur pushBack _veh;
        missionNamespace setVariable ["FADE_eeQrfVehs_" + _tid, _cur];
    };

    [_taskId, _evadeePlayers, _zoneCenter, _basePos, _enemyUnitsEe, _applyGrpEe, _sideEnemy, _eeDeleteQrf, _eeSpawnQrf, _eeSpawnSearchHeli, _eeDeleteSearchHeli, _player] spawn {
        params ["_taskId", "_evadeePlayers", "_zoneCenter", "_basePos", "_enemyUnitsEe", "_applyGrpEe", "_sideEnemy", "_eeDeleteQrf", "_eeSpawnQrf", "_eeSpawnSearchHeli", "_eeDeleteSearchHeli", "_player"];
        scriptName "FADE_ee_main";
        private _lastQrf = -1e9;
        private _eeHeliVeh = objNull;
        private _eeHeliGrp = grpNull;
        private _eeHeliCargo = grpNull;
        private _eeHeliSortieUntil = -1;
        private _eeHeliNextAfter = time + 900 + random 300;
        waitUntil {
            sleep 5;
            if (missionNamespace getVariable ["FADE_eeAborted_" + _taskId, false]) exitWith { true };
            private _st = _taskId call BIS_fnc_taskState;
            if (_st in ["SUCCEEDED", "CANCELED", "FAILED"]) exitWith { true };
            if (!isNull _eeHeliVeh) then {
                if (!alive _eeHeliVeh || { isNull _eeHeliVeh } || { time >= _eeHeliSortieUntil }) then {
                    [_eeHeliVeh, _eeHeliGrp, _eeHeliCargo] call _eeDeleteSearchHeli;
                    _eeHeliVeh = objNull;
                    _eeHeliGrp = grpNull;
                    _eeHeliCargo = grpNull;
                    _eeHeliSortieUntil = -1;
                    _eeHeliNextAfter = time + (1200 + random 600);
                    missionNamespace setVariable ["FADE_eeSearchHeli_" + _taskId, []];
                };
            } else {
                if (_st == "ASSIGNED" && { time >= _eeHeliNextAfter }) then {
                    private _hRes = [_taskId, _zoneCenter, _enemyUnitsEe, _applyGrpEe, _sideEnemy] call _eeSpawnSearchHeli;
                    if (!isNull (_hRes param [0, objNull])) then {
                        _eeHeliVeh = _hRes select 0;
                        _eeHeliGrp = _hRes select 1;
                        _eeHeliCargo = _hRes select 2;
                        _eeHeliSortieUntil = time + 720 + random 360;
                        missionNamespace setVariable ["FADE_eeSearchHeli_" + _taskId, _hRes];
                    } else {
                        _eeHeliNextAfter = time + 300;
                    };
                };
            };
            private _liveE = _evadeePlayers select { !isNull _x && { alive _x } && { isPlayer _x } };
            private _anyDead = false;
            {
                if (isNull _x) then { _anyDead = true } else { if (!alive _x) then { _anyDead = true } };
            } forEach _evadeePlayers;
            if (_anyDead) exitWith {
                [_taskId, "FAILED"] call BIS_fnc_taskSetState;
                true
            };
            if (count _liveE == 0) exitWith {
                [_taskId, "FAILED"] call BIS_fnc_taskSetState;
                true
            };
            private _allHome = true;
            {
                if ((_x distance2D _basePos) > 1000) then { _allHome = false };
            } forEach _liveE;
            if (_allHome) exitWith {
                [_taskId, "SUCCEEDED"] call BIS_fnc_taskSetState;
                true
            };
            if ((time - _lastQrf) >= 600) then {
                private _detP = objNull;
                {
                    private _p = _x;
                    if (!isNull _p && { alive _p }) then {
                        {
                            private _u = _x;
                            if (side _u == _sideEnemy && { alive _u } && { _u isKindOf "Man" } && { _u distance2D _p < 550 }) then {
                                if (_u knowsAbout _p > 1.59) then { _detP = _p };
                            };
                        } forEach allUnits;
                    };
                    if (!isNull _detP) exitWith {};
                } forEach _liveE;
                if (!isNull _detP) then {
                    [_taskId, _detP, _zoneCenter, _basePos, _enemyUnitsEe, _applyGrpEe, _sideEnemy] call _eeSpawnQrf;
                    _lastQrf = time;
                };
            };
            false
        };
        if ((_taskId call BIS_fnc_taskState) == "ASSIGNED" && { missionNamespace getVariable ["FADE_eeAborted_" + _taskId, false] }) then {
            [_taskId, "CANCELED"] call BIS_fnc_taskSetState;
        };
        [_taskId] call _eeDeleteQrf;
        if (!isNull _eeHeliVeh || { !isNull _eeHeliGrp }) then {
            [_eeHeliVeh, _eeHeliGrp, _eeHeliCargo] call _eeDeleteSearchHeli;
        };
        private _ent = missionNamespace getVariable ["FADE_eeEntities_" + _taskId, []];
        if (count _ent >= 1) then {
            private _grps = _ent select 0;
            {
                private _g = _x;
                if (!isNull _g) then {
                    { if (!isNull _x) then { deleteVehicle _x } } forEach units _g;
                    deleteGroup _g;
                };
            } forEach _grps;
        };
        missionNamespace setVariable ["FADE_eeEntities_" + _taskId, nil];
        missionNamespace setVariable ["FADE_eeQrfVehs_" + _taskId, nil];
        missionNamespace setVariable ["FADE_eeSearchHeli_" + _taskId, nil];
        missionNamespace setVariable ["FADE_eeAborted_" + _taskId, nil];
        if (!isNull _player && { (_player getVariable ["FADE_myMissionTaskId", ""]) == _taskId }) then { [_player] call FADE_clearActiveMission };
    };
};

// -----------------------------------------------------------------------------
// 7. INTERCEPT CONVOY -- Convoy 3-6 vehicles (random roads: start → end, min separation); destroy 100% before arrival
// -----------------------------------------------------------------------------
if (_missionType == "InterceptConvoy") exitWith {
    private _efConv = missionNamespace getVariable ["FADE_scenarioEnemyFaction", "OPF_F"];
    private _convoyVehicles = [_efConv] call FADE_getEnemyVehiclesForFaction;
    if (_convoyVehicles isEqualTo []) then {
        _convoyVehicles = +(missionNamespace getVariable ["FADE_enemyVehicles", []]);
    };
    private _enemyUnitsConv = +_enemyUnits;
    _enemyUnitsConv = [_enemyUnitsConv] call (missionNamespace getVariable ["FADE_filterEnemyUnitsArmed", { _this select 0 }]);
    if (count _enemyUnitsConv == 0) exitWith {
        [_player] call FADE_clearActiveMission;
        ["<t size='1.2' color='#FF6666'>MISSION ERROR</t><br/><br/><t color='#E0E0E0'>No enemy units configured for convoy crew.</t>"] remoteExec ["FADE_showMissionHint", _player];
    };
    private _soft = [];
    private _armored = [];
    {
        if (_x isKindOf "Air" || { _x isKindOf "Ship" } || { _x isKindOf "StaticWeapon" }) then {} else {
            if (_x isKindOf "Tank" || { _x isKindOf "Wheeled_APC_F" }) then { _armored pushBack _x } else { _soft pushBack _x };
        };
    } forEach _convoyVehicles;
    if (count _soft == 0 && { count _armored == 0 }) exitWith {
        [_player] call FADE_clearActiveMission;
        ["<t size='1.2' color='#FF6666'>MISSION ERROR</t><br/><br/><t color='#E0E0E0'>Enemy faction has no land vehicles. Choose a faction with cars/trucks or light armour.</t>"] remoteExec ["FADE_showMissionHint", _player];
    };
    if (isNil "FADE_interceptConvoyRoadRoute") then {
        FADE_interceptConvoyRoadRoute = compile preprocessFileLineNumbers "rsc\fn_FADE_interceptConvoyRoadRoute.sqf";
    };
    private _route = [_basePos] call FADE_interceptConvoyRoadRoute;
    if (_route isEqualTo []) exitWith {
        private _minRm = round (missionNamespace getVariable ["FADE_convoyMinRouteM", 5000]);
        [_player] call FADE_clearActiveMission;
        [format ["<t size='1.2' color='#FF6666'>MISSION ERROR</t><br/><br/><t color='#E0E0E0'>Could not find a suitable convoy route (roads at least %1 m apart). Try again.</t>", _minRm]] remoteExec ["FADE_showMissionHint", _player];
    };
    private _startPos = _route select 0;
    private _endPos = _route select 1;
    if (count _startPos < 3) then { _startPos = [(_startPos select 0), (_startPos select 1), 0] };
    if (count _endPos < 3) then { _endPos = [(_endPos select 0), (_endPos select 1), 0] };
    private _convoySize = [3 + floor random 4, 2] call _scaleOpforCount;
    private _numArmored = (([floor random 3, 0] call _scaleOpforCount) min 2) min _convoySize;
    private _vehicleClasses = [];
    for "_v" from 0 to (_convoySize - 1) do {
        if (_v < _numArmored && { count _armored > 0 }) then {
            _vehicleClasses pushBack (selectRandom _armored);
        } else {
            if (count _soft > 0) then { _vehicleClasses pushBack (selectRandom _soft) } else { _vehicleClasses pushBack (selectRandom _armored) };
        };
    };
    private _convoyGroup = createGroup _sideEnemy;
    private _convoyVehiclesSpawned = [];
    private _convoySpawnEntries = [];
    private _cargoGroups = [];
    private _convoyWp = [];
    private _dir = [_startPos, _endPos] call BIS_fnc_dirTo;
    private _findConvoySafeSpawn = {
        params ["_desiredPos", ["_minVehGap", 12], ["_buildingGap", 10]];
        if (count _desiredPos < 3) then { _desiredPos = [(_desiredPos select 0), (_desiredPos select 1), 0] };
        private _fallback = _desiredPos;
        private _best = [];
        private _done = false;
        for "_try" from 0 to 9 do {
            if (_done) then { continue };
            private _candidate = [_desiredPos, 0, 16, 6, 1, 0.3, 0, [], _fallback] call BIS_fnc_findSafePos;
            if (count _candidate < 2) then { _candidate = _fallback };
            if (count _candidate < 3) then { _candidate = [(_candidate select 0), (_candidate select 1), 0] };
            private _tooCloseVeh = false;
            {
                if (!isNull _x && { alive _x } && { (_x distance2D _candidate) < _minVehGap }) exitWith { _tooCloseVeh = true };
            } forEach _convoyVehiclesSpawned;
            if (_tooCloseVeh) then { continue };
            private _nearBuildings = nearestTerrainObjects [_candidate, ["HOUSE","BUILDING","WALL","FENCE"], _buildingGap, false, true];
            if (count _nearBuildings > 0) then { continue };
            _best = _candidate;
            _done = true;
        };
        if (count _best < 2) then { _best = _fallback };
        if (count _best < 3) then { _best = [(_best select 0), (_best select 1), 0] };
        _best
    };
    private _spawnConvoyVehicle = {
        params ["_vClass", "_spawnPos"];
        if (count _spawnPos < 3) then { _spawnPos = [(_spawnPos select 0), (_spawnPos select 1), 0] };
        private _veh = createVehicle [_vClass, _spawnPos, [], 0, "NONE"];
        if (isNull _veh) exitWith { [objNull, grpNull] };
        _veh setPosATL _spawnPos;
        _veh setDir _dir;
        // Small forward nudge helps newly spawned convoy vehicles break static friction/get unstuck.
        private _nudge = 2;
        _veh setVelocity [ (sin _dir) * _nudge, (cos _dir) * _nudge, 0 ];
        private _cargoGrp = grpNull;
        if (count _enemyUnitsConv > 0) then {
            private _driver = _convoyGroup createUnit [selectRandom _enemyUnitsConv, _spawnPos, [], 0, "NONE"];
            if (!isNull _driver) then { _driver moveInDriver _veh };
            if (_veh emptyPositions "gunner" > 0) then {
                private _g = _convoyGroup createUnit [selectRandom _enemyUnitsConv, _spawnPos, [], 0, "NONE"];
                if (!isNull _g) then { _g moveInGunner _veh };
            };
            if (_veh emptyPositions "commander" > 0) then {
                private _c = _convoyGroup createUnit [selectRandom _enemyUnitsConv, _spawnPos, [], 0, "NONE"];
                if (!isNull _c) then { _c moveInCommander _veh };
            };
        };
        private _cargoSeats = (_veh emptyPositions "cargo") max 0;
        if (_cargoSeats > 0 && { count _enemyUnitsConv > 0 }) then {
            _cargoGrp = createGroup _sideEnemy;
            for "_c" from 0 to (_cargoSeats - 1) do {
                private _u = _cargoGrp createUnit [selectRandom _enemyUnitsConv, _spawnPos, [], 0, "NONE"];
                if (!isNull _u) then { _u moveInCargo _veh };
            };
        };
        [_veh, _cargoGrp]
    };

    // Spawn lead vehicle first, then stagger followers to reduce spawn-gridlock.
    if (count _vehicleClasses > 0) then {
        private _leadSpawn = [_startPos, 14, 12] call _findConvoySafeSpawn;
        private _leadResult = [(_vehicleClasses select 0), _leadSpawn] call _spawnConvoyVehicle;
        private _leadVeh = _leadResult select 0;
        if (!isNull _leadVeh) then {
            _convoyVehiclesSpawned pushBack _leadVeh;
            private _cg = _leadResult select 1;
            if (!isNull _cg) then { _cargoGroups pushBack _cg };
            _convoySpawnEntries pushBack [_leadVeh, (_vehicleClasses select 0), _leadSpawn, false, _cg];
            // Give move orders immediately so lead starts driving while followers spawn.
            _convoyGroup setFormation "COLUMN";
            _convoyGroup setBehaviour "SAFE";
            _convoyGroup setSpeedMode "NORMAL";
            _convoyWp = _convoyGroup addWaypoint [_endPos, 20];
            _convoyWp setWaypointType "MOVE";
            _convoyWp setWaypointSpeed "NORMAL";
        };

        for "_v" from 1 to (count _vehicleClasses - 1) do {
            sleep 10;
            private _vClass = _vehicleClasses select _v;
            private _anchorVeh = _convoyVehiclesSpawned param [(count _convoyVehiclesSpawned) - 1, objNull];
            private _anchorPos = if (!isNull _anchorVeh) then { getPosATL _anchorVeh } else { _startPos };
            private _desired = [
                (_anchorPos select 0) - (sin _dir) * 10,
                (_anchorPos select 1) - (cos _dir) * 10,
                0
            ];
            private _safeBehind = [_desired, 12, 10] call _findConvoySafeSpawn;
            private _res = [_vClass, _safeBehind] call _spawnConvoyVehicle;
            private _veh = _res select 0;
            if (!isNull _veh) then {
                _convoyVehiclesSpawned pushBack _veh;
                private _cg2 = _res select 1;
                if (!isNull _cg2) then { _cargoGroups pushBack _cg2 };
                _convoySpawnEntries pushBack [_veh, _vClass, _safeBehind, false, _cg2];
            };
        };
    };
    // One-time recovery: respawn exploded or non-moving convoy vehicles once.
    sleep 8;
    for "_i" from 0 to (count _convoySpawnEntries - 1) do {
        private _entry = _convoySpawnEntries select _i;
        _entry params ["_veh", "_vClass", "_spawnPos", "_retried", "_cargoGrp"];
        private _needsRespawn = isNull _veh || { !alive _veh } || { !canMove _veh } || { speed _veh < 1 };
        if (_needsRespawn && { !_retried }) then {
            if (!isNull _cargoGrp) then {
                { if (!isNull _x) then { deleteVehicle _x } } forEach units _cargoGrp;
                deleteGroup _cargoGrp;
                _cargoGroups = _cargoGroups - [_cargoGrp];
            };
            if (!isNull _veh) then { deleteVehicle _veh };
            private _retryPos = [_spawnPos, 12, 10] call _findConvoySafeSpawn;
            private _retryRes = [_vClass, _retryPos] call _spawnConvoyVehicle;
            private _retryVeh = _retryRes select 0;
            private _retryCargo = _retryRes select 1;
            if (!isNull _retryCargo) then { _cargoGroups pushBack _retryCargo };
            if (!isNull _retryVeh) then {
                _entry = [_retryVeh, _vClass, _retryPos, true, _retryCargo];
                _convoySpawnEntries set [_i, _entry];
            };
        };
    };
    _convoyVehiclesSpawned = (_convoySpawnEntries apply { _x select 0 }) select { !isNull _x && { alive _x } };
    // Cleanup: delete any convoy infantry that failed to board (prevents stragglers at spawn).
    {
        if (!isNull _x && { alive _x } && { vehicle _x == _x }) then { deleteVehicle _x };
    } forEach units _convoyGroup;
    {
        {
            if (!isNull _x && { alive _x } && { vehicle _x == _x }) then { deleteVehicle _x };
        } forEach units _x;
    } forEach _cargoGroups;
    [_convoyGroup] call FAC_applyEnemyScenarioToGroup;
    { [_x] call FAC_applyEnemyScenarioToGroup } forEach _cargoGroups;
    if (count _convoyVehiclesSpawned == 0) exitWith {
        deleteGroup _convoyGroup;
        { { if (!isNull _x) then { deleteVehicle _x } } forEach units _x; deleteGroup _x } forEach _cargoGroups;
        [_player] call FADE_clearActiveMission;
        ["<t size='1.2' color='#FF6666'>MISSION ERROR</t><br/><br/><t color='#E0E0E0'>Could not spawn convoy vehicles.</t>"] remoteExec ["FADE_showMissionHint", _player];
    };
    _convoyGroup setVariable ["FADE_convoyTaskId", _taskId, true];
    _convoyGroup setVariable ["FADE_convoyVehiclesList", _convoyVehiclesSpawned, true];
    _convoyGroup setVariable ["FADE_convoyCargoGroups", _cargoGroups, true];
    if (count _convoyWp == 0) then {
        _convoyGroup setFormation "COLUMN";
        _convoyGroup setBehaviour "SAFE";
        _convoyGroup setSpeedMode "NORMAL";
        _convoyWp = _convoyGroup addWaypoint [_endPos, 20];
        _convoyWp setWaypointType "MOVE";
        _convoyWp setWaypointSpeed "NORMAL";
    };
    {
        if (!isNull _x) then { _x setConvoySeparation 20 };
    } forEach _convoyVehiclesSpawned;
    _convoyWp setWaypointStatements ["true", "
        private _g = group this;
        private _task = _g getVariable ['FADE_convoyTaskId', ''];
        if (_task != '' && { (_task call BIS_fnc_taskState) != 'SUCCEEDED' }) then { [_task, 'FAILED'] call BIS_fnc_taskSetState };
        private _vList = _g getVariable ['FADE_convoyVehiclesList', []];
        { if (!isNull _x) then { deleteVehicle _x } } forEach _vList;
        private _cargoGrps = _g getVariable ['FADE_convoyCargoGroups', []];
        { { if (!isNull _x) then { deleteVehicle _x } } forEach units _x; deleteGroup _x } forEach _cargoGrps;
        { if (!isNull _x) then { deleteVehicle _x } } forEach units _g;
        deleteGroup _g;
    "];
    [[_convoyGroup] + _cargoGroups, _basePos] call FADE_registerEnemyRetreat;
    private _markerNameStart = "FADE_convoy_start_" + _taskId;
    private _markerNameEnd = "FADE_convoy_end_" + _taskId;
    _player setVariable ["FADE_myMissionMarker", _markerNameStart, true];
    _player setVariable ["FADE_myMissionMarkerEnd", _markerNameEnd, true];
    private _markerStart = createMarker [_markerNameStart, [_startPos, 100] call _mkrJitter];
    _markerStart setMarkerType "mil_arrow";
    _markerStart setMarkerColor _markerEnemy;
    _markerStart setMarkerText _operationName;
    private _markerEnd = createMarker [_markerNameEnd, [_endPos, 100] call _mkrJitter];
    _markerEnd setMarkerType "mil_end";
    _markerEnd setMarkerColor _markerEnemy;
    _markerEnd setMarkerText _operationName;
    [_player, _taskId, "Stop the convoy: destroy or immobilise at least 60% of vehicles before they reach the end zone.", "Intercept Convoy", _endPos, "destroy"] call _fnc_createMissionTask;
    private _gridStart = mapGridPosition _startPos;
    private _gridEnd = mapGridPosition _endPos;
    private _brief = format ["INTERCEPT CONVOY%1%1START: Grid %2%1END: Grid %3%1%1Stop the convoy: at least 60%% of vehicles destroyed or immobilised before they arrive.", toString [10], _gridStart, _gridEnd];
    _player setVariable ["FADE_myMissionBrief", _brief, true];
    [format ["<t color='#FFFFFF'>Start: %1 -> End: %2</t><br/><br/><t color='#FFFFFF'>Stop the convoy: at least 60%% of vehicles destroyed or immobilised.</t>", _gridStart, _gridEnd]] call _showAssignedHint;
    [_player, "Intercept Convoy"] call FADE_notifyOthersMissionStarted;
    private _friendlyObserverClass = _friendlyUnits select 0;
    [_taskId, _convoyVehiclesSpawned, _convoyGroup, _cargoGroups, _markerNameStart, _markerNameEnd, _player, _endPos, _startPos, _friendlyObserverClass, _sideFriendly] spawn {
        params ["_taskId", "_convoyVehiclesSpawned", "_convoyGroup", "_cargoGroups", "_markerNameStart", "_markerNameEnd", "_player", "_endPos", "_startPos", "_friendlyObserverClass", "_sideFriendly"];
        private _warningSent = false;
        private _routeDist = (_startPos distance _endPos) max 1;
        private _warningDist = (_routeDist * 0.35) max 400;
        waitUntil {
            sleep 0.5;
            if ((_taskId call BIS_fnc_taskState) in ["SUCCEEDED","CANCELED","FAILED"]) exitWith { true };
            // RATEL observer warning when convoy nears objective
            if (!_warningSent) then {
                private _leadVeh = (_convoyVehiclesSpawned select { (!isNull _x) && { alive _x } }) param [0, objNull];
                if (!isNull _leadVeh && { (_leadVeh distance _endPos) <= _warningDist }) then {
                    _warningSent = true;
                    private _observerGrp = createGroup _sideFriendly;
                    private _observer = _observerGrp createUnit [_friendlyObserverClass, [0, 0, 0], [], 0, "NONE"];
                    _observer setIdentity "FADE_ratel_eagleeye";
                    private _dist = round (_leadVeh distance _endPos);
                    private _msgs = [
                        format ["All callsigns, this is Eagle Eye. Convoy is tracking, %1 metres from end zone. Expedite intercept. Out.", _dist],
                        "All callsigns, this is Eagle Eye. Visual on convoy. Multiple vehicles, closing on objective. Intercept immediately. Out.",
                        "All callsigns, this is Eagle Eye. Be advised - the convoy is nearing the edge of the AO. Over.",
                        "All callsigns, this is Eagle Eye. Hostile convoy will be leaving the AO shortly. All assets, engage now. Out."
                    ];
                    [_observer, selectRandom _msgs] call FADE_aiSideChat;
                    [_observer, _observerGrp] spawn {
                        params ["_o", "_g"];
                        sleep 4;
                        if (!isNull _o) then { deleteVehicle _o };
                        if (!isNull _g) then { deleteGroup _g };
                    };
                };
            };
            // Success when 60%+ of convoy vehicles are inoperable (destroyed or immobile)
            private _total = count _convoyVehiclesSpawned;
            private _inoperable = 0;
            {
                if (isNull _x || { !alive _x } || { !canMove _x }) then { _inoperable = _inoperable + 1 };
            } forEach _convoyVehiclesSpawned;
            if (_total > 0 && { _inoperable >= (ceil (_total * 0.6)) }) then {
                [_taskId, "SUCCEEDED"] call BIS_fnc_taskSetState;
                true
            } else { false };
        };
        [_markerNameStart] call FADE_deleteMarkerSafe;
        [_markerNameEnd] call FADE_deleteMarkerSafe;
        if (!isNull _player && { (_player getVariable ["FADE_myMissionTaskId", ""]) == _taskId }) then { [_player] call FADE_clearActiveMission };
        [_convoyGroup, _convoyVehiclesSpawned, _cargoGroups, _markerNameStart, _markerNameEnd, _player, _taskId] spawn {
            params ["_convoyGroup", "_convoyVehiclesSpawned", "_cargoGroups", "_markerNameStart", "_markerNameEnd", "_player", "_taskId"];
            sleep 60;
            if (!isNull _convoyGroup) then { { if (!isNull _x) then { deleteVehicle _x } } forEach units _convoyGroup; deleteGroup _convoyGroup };
            { { if (!isNull _x) then { deleteVehicle _x } } forEach units _x; deleteGroup _x } forEach _cargoGroups;
            { if (!isNull _x) then { deleteVehicle _x } } forEach _convoyVehiclesSpawned;
            [_markerNameStart] call FADE_deleteMarkerSafe;
            [_markerNameEnd] call FADE_deleteMarkerSafe;
            if (!isNull _player && { (_player getVariable ["FADE_myMissionTaskId", ""]) == _taskId }) then { [_player] call FADE_clearActiveMission };
        };
    };
};

// Mine Clearing — anti-personnel mines OR IEDs on roads (one threat type per mission), 20 m+ spacing, marker at cluster centre
if (_missionType == "MineClearing") exitWith {
    private _useMines = random 1 < 0.5;
    private _need = if (_useMines) then { 2 + (floor random 4) } else { 1 + (floor random 3) };
    private _minSep = 20;
    private _anchor = +_destPos;
    if (count _anchor < 3) then { _anchor set [2, 0] };

    private _sepOkFn = {
        params ["_p", "_list", "_minD"];
        private _ok = true;
        { if ((_p distance2D _x) < _minD) exitWith { _ok = false } } forEach _list;
        _ok
    };

    private _greedyFromPool = {
        params ["_pool", "_have", "_target", "_minD", "_sepOkFn"];
        private _out = +_have;
        {
            if (count _out >= _target) exitWith {};
            private _p = getPosATL _x;
            if (count _p < 2) then { } else {
                if (!(surfaceIsWater _p) && { [_p, _out, _minD] call _sepOkFn }) then { _out pushBack _p };
            };
        } forEach _pool;
        _out
    };

    private _bestChain = [];
    private _radii = [200, 350, 500, 650];
    private _ri = 0;
    while { _ri < count _radii } do {
        private _rad = _radii select _ri;
        _ri = _ri + 1;
        private _roads = _anchor nearRoads _rad;
        if (_roads isEqualTo []) then { } else {
            private _roadsShuffled = _roads call BIS_fnc_arrayShuffle;
            private _maxStarts = (count _roadsShuffled) min 20;
            for "_s" from 0 to (_maxStarts - 1) do {
                private _start = _roadsShuffled select _s;
                private _visited = [];
                private _queue = [_start];
                private _chain = [];
                while { count _chain < _need && count _queue > 0 } do {
                    private _rd = _queue deleteAt 0;
                    if (_rd in _visited) then { } else {
                        _visited pushBack _rd;
                        private _p = getPosATL _rd;
                        if (count _p >= 2 && { !(surfaceIsWater _p) } && { [_p, _chain, _minSep] call _sepOkFn }) then {
                            _chain pushBack _p;
                        };
                        {
                            if (!(_x in _visited)) then { _queue pushBack _x };
                        } forEach (roadsConnectedTo _rd);
                    };
                };
                if (count _chain > count _bestChain) then { _bestChain = +_chain };
            };
        };
    };

    private _positions = +_bestChain;
    if (count _positions > _need) then { _positions resize _need };
    if (count _positions < _need) then {
        private _pool = (_anchor nearRoads 700) call BIS_fnc_arrayShuffle;
        _positions = [_pool, _positions, _need, _minSep, _sepOkFn] call _greedyFromPool;
    };

    if (count _positions < _need) then {
        [_player] call FADE_clearActiveMission;
        ["<t size='1.2' color='#FF6666'>MISSION ERROR</t><br/><br/><t color='#E0E0E0'>Could not place hazards along roads in this area. Try again.</t>"] remoteExec ["FADE_showMissionHint", _player];
    } else {
        private _nPlaced = count _positions;
        private _sx = 0;
        private _sy = 0;
        private _sz = 0;
        { _sx = _sx + (_x select 0); _sy = _sy + (_x select 1); _sz = _sz + (_x param [2, 0]) } forEach _positions;
        private _centerPos = [_sx / _nPlaced, _sy / _nPlaced, _sz / _nPlaced];
        if (surfaceIsWater _centerPos) then { _centerPos = [_sx / _nPlaced, _sy / _nPlaced, _anchor param [2, 0]] };

        private _hazards = [];
        if (_useMines) then {
            private _mineClass = "APERSBoundingMine";
            if (!isClass (configFile >> "CfgVehicles" >> _mineClass)) then { _mineClass = "APERSMine" };
            {
                private _p = +_x;
                if (count _p < 3) then { _p set [2, 0] };
                private _m = createMine [_mineClass, _p, [], 0];
                if (!isNull _m) then { _hazards pushBack _m };
            } forEach _positions;
        } else {
            private _iedClass = "IEDLandBig_F";
            if (!isClass (configFile >> "CfgVehicles" >> _iedClass)) then { _iedClass = "Land_IED_v1_F" };
            {
                private _p = +_x;
                if (count _p < 3) then { _p set [2, 0] };
                private _ied = createVehicle [_iedClass, _p, [], 0, "NONE"];
                if (!isNull _ied) then {
                    _ied setPosATL _p;
                    _ied setDir (random 360);
                    _hazards pushBack _ied;
                };
            } forEach _positions;
        };

        if (count _hazards < _need) then {
            { if (!isNull _x) then { deleteVehicle _x } } forEach _hazards;
            [_player] call FADE_clearActiveMission;
            ["<t size='1.2' color='#FF6666'>MISSION ERROR</t><br/><br/><t color='#E0E0E0'>Could not spawn all hazards. Try again.</t>"] remoteExec ["FADE_showMissionHint", _player];
        } else {
            private _hazardWord = if (_useMines) then {
                if (_need == 1) then { "mine" } else { "mines" }
            } else {
                if (_need == 1) then { "IED" } else { "IEDs" }
            };
            private _taskDescShort = if (_useMines) then {
                format ["Clear all %1 along the route (disarm). Hazards are on the road network near the marker.", _hazardWord]
            } else {
                format ["Locate and disarm or destroy all %1 along the route. Hazards are on the road network near the marker.", _hazardWord]
            };

            [_player, _taskId, _taskDescShort, "Mine Clearing", _centerPos, "destroy"] call _fnc_createMissionTask;

            private _markerName = "FADE_mines_" + _taskId;
            _player setVariable ["FADE_myMissionMarker", _markerName, true];
            private _mkr = createMarker [_markerName, [_centerPos, 30] call _mkrJitter];
            _mkr setMarkerType "mil_warning";
            _mkr setMarkerColor (missionNamespace getVariable ["FADE_markerColorEnemy", "ColorEAST"]);
            _mkr setMarkerText _operationName;

            private _grid = mapGridPosition _centerPos;
            private _threatLine = if (_useMines) then {
                format ["Intel: %1 anti-personnel mines reported on a local route — EOD clearance.", _need]
            } else {
                format ["Intel: %1 improvised explosive device(s) on a local route — treat as live until cleared.", _need]
            };
            _player setVariable ["FADE_myMissionBrief", format ["MINE / EOD CLEARANCE%1%1Grid: %2%1%3", toString [10], _grid, _threatLine], true];

            private _missionHtml = format [
                "<t color='#FFFFFF'>Grid: %1</t><br/><t color='#FFFFFF'>Threat: %2 × %3 on road.</t><br/><br/><t color='#FFFFFF'>Marker: approximate centre of the hazard stretch. Clear all devices.</t>",
                _grid,
                if (_useMines) then { "mines" } else { "IEDs" },
                _need
            ];
            private _situationHtml = format [
                "<t align='left' color='#FFFFFF'>%1</t><br/><br/>%2",
                _threatLine,
                _defaultSituationHintHtml
            ];
            [_missionHtml, _situationHtml] call _showAssignedHint;

            [_player, "Mine Clearing"] call FADE_notifyOthersMissionStarted;

            [_taskId, _hazards, _markerName, _player, _useMines] spawn {
                params ["_taskId", "_hazards", "_markerName", "_player", "_useMines"];
                private _left = 1;
                while { _left > 0 } do {
                    sleep 2;
                    _left = 0;
                    {
                        if (!isNull _x) then {
                            if (_useMines) then {
                                _left = _left + 1;
                            } else {
                                if (alive _x) then { _left = _left + 1 };
                            };
                        };
                    } forEach _hazards;
                };
                [_taskId, "SUCCEEDED"] call BIS_fnc_taskSetState;
                private _doneMsg = if (_useMines) then {
                    "<t size='1.2' color='#90EE90'>MINES CLEARED</t><br/><br/><t color='#E0E0E0'>All mines neutralised.</t>"
                } else {
                    "<t size='1.2' color='#90EE90'>IEDs CLEARED</t><br/><br/><t color='#E0E0E0'>All devices neutralised.</t>"
                };
                [_doneMsg] remoteExec ["FADE_showMissionHint", _player];
                sleep 5;
                [_markerName] call FADE_deleteMarkerSafe;
                if (!isNull _player && { (_player getVariable ["FADE_myMissionTaskId", ""]) == _taskId }) then { [_player] call FADE_clearActiveMission };
            };
        };
    };
};
