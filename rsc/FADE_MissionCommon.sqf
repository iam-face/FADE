// =============================================================================
// FADE_MissionCommon.sqf  -  SMEAC / mission briefing helpers (compile once at boot)
// =============================================================================

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
        private _radius = if (!isNil "FADE_topographyLocationRadius") then { FADE_topographyLocationRadius } else { 8000 };
        if (_radius < 500) then { _radius = 500 };
        private _nearby = nearestLocations [_pos, ["NameCityCapital", "NameCity", "NameVillage", "NameLocal"], _radius];
        // Pure nearest location often picks NameLocal (hill, junction) over the real town slightly farther.
        // Score = distance / (typeWeight^2): cities beat locals at similar "effective" distance; then take best
        // settlement tier within a small band of the minimum score, and closest distance within that tier.
        private _scored = [];
        {
            private _name = text _x;
            if !(_name isEqualTo "") then {
                private _d = _pos distance2D locationPosition _x;
                private _prio = switch (type _x) do {
                    case "NameCityCapital": { 5 };
                    case "NameCity": { 4 };
                    case "NameVillage": { 3 };
                    case "NameLocal": { 1 };
                    default { 1 };
                };
                private _score = _d / (_prio * _prio);
                _scored pushBack [_score, _prio, _d, _name];
            };
        } forEach _nearby;
        if (count _scored > 0) then {
            private _minScore = 1e15;
            { _minScore = _minScore min (_x select 0) } forEach _scored;
            private _thresh = _minScore * 1.15;
            private _maxPrio = -1;
            {
                if ((_x select 0) <= _thresh) then { _maxPrio = _maxPrio max (_x select 1) };
            } forEach _scored;
            private _tier = _scored select { (_x select 0) <= _thresh && { (_x select 1) == _maxPrio } };
            if (count _tier == 0) then { _tier = +_scored };
            _tier = [_tier, [], { _x select 2 }, "ASCEND"] call BIS_fnc_sortBy;
            _areaName = (_tier select 0) select 3;
        };
    };
    [_grid, _areaName]
}];

// Player-facing SMEAC / lore friendly label (not scenario spawn faction classname).
FADE_smeacFriendlyLabel = "CTB";
FADE_getSmeacFriendlyLabel = { missionNamespace getVariable ["FADE_smeacFriendlyLabel", "CTB"] };
missionNamespace setVariable ["FADE_smeacFriendlyLabel", FADE_smeacFriendlyLabel];
missionNamespace setVariable ["FADE_getSmeacFriendlyLabel", FADE_getSmeacFriendlyLabel];

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
    _friendlyFactionDisplay = [] call FADE_getSmeacFriendlyLabel;
    private _topoBodyCol = if (_bodyColorHex isEqualTo "") then { "#B0B0B0" } else { _bodyColorHex };
    private _bodyCol = if (_bodyColorHex isEqualTo "") then { "#A0A0A0" } else { _bodyColorHex };
    private _estQual = "";
    private _n = _estimatedOpforCount max 0;
    private _echelon = switch (true) do {
        case (_n <= 0): { "none confirmed" };
        case (_n <= 3): { "fire team or less" };
        case (_n <= 8): { "fire team to squad" };
        case (_n <= 15): { "squad" };
        case (_n <= 28): { "squad to platoon" };
        case (_n <= 50): { "platoon" };
        case (_n <= 85): { "platoon to company" };
        case (_n <= 140): { "company" };
        default { "company or larger" };
    };
    private _launcherSet = missionNamespace getVariable ["FADE_opforLauncherSetting", "Normal"];
    private _atLine = switch (_launcherSet) do {
        case "None": { "Anti-armour threat is light; dedicated AT teams unlikely." };
        case "Minimal": { "Limited anti-armour; occasional RPG-class weapons possible." };
        case "Reduced": { "Anti-armour present but below full table of equipment." };
        default { "Expect RPG / light AT teams in the infantry mix." };
    };
    private _airSet = [missionNamespace getVariable ["FADE_opforAirSetting", "Off"]] call FADE_normalizeOpforThreatSetting;
    private _airLine = if (_airSet isEqualTo "Off") then {
        "Hostile air is unlikely."
    } else {
        format ["Hostile rotary-wing may be committed if the enemy gains situational awareness (%1).", toLower _airSet]
    };
    private _droneSet = [missionNamespace getVariable ["FADE_opforDroneSetting", "Off"]] call FADE_normalizeOpforThreatSetting;
    private _droneLine = if (_droneSet isEqualTo "Off") then {
        "Enemy UAV patrols are unlikely."
    } else {
        format ["Enemy UAVs may patrol the battlespace and vector ground QRF onto detected foot mobile (%1).", toLower _droneSet]
    };
    private _commsLine = if (_missionType in ["HVT", "Hostage", "ClearArea", "SearchDestroy", "CASEVAC", "CSAR", "Operation", "AreaOfOperations", "AssetRetrieval", "AssetRetrievalVeh", "InterceptConvoy", "EscapeEvasion", "Raid", "Invasion", "PointDefense"]) then {
        "Enemy may request reinforcements after sustained or reported contact."
    } else {
        "Reinforcement is unlikely; expect local contacts only."
    };
    private _specBlock = [_atLine, _airLine, _droneLine, _commsLine] joinString "<br/>";
    private _mlcoa = switch (_missionType) do {
        case "TroopInsert": { "Local security may react to aircraft noise; expect minor harassing fire en route to the LZ." };
        case "TroopExtract": { "Enemy may probe the pickup zone and try to delay embarkation." };
        case "CASEVAC": { "Enemy near the casualty site may maintain pressure during loading." };
        case "CSAR": { "Search teams may sweep toward the survivor; defend the site until extraction." };
        case "Cargo": { "Non-combat resupply; expect friendly receiving party and local camp security only." };
        case "CAS": { "Enemy may continue pressure on friendly positions and seek cover when engaged from the air." };
        case "HVT": { "Bodyguards will protect the HVT; outer patrols may try to canalise approach routes." };
        case "Hostage": { "Captors may barricade structures and use hostages as cover while returning fire." };
        case "ClearArea": { "Garrison may fight for the town and withdraw in fragments once cohesion breaks." };
        case "SearchDestroy": { "Garrisoned buildings may hold caches; outer guards may move toward gunfire." };
        case "InterceptConvoy": { "Escorts may suppress flanks and attempt to push through; expect vehicles to button up." };
        case "MineClearing": { "Minimal enemy manoeuvre expected; treat the area as contaminated until cleared." };
        case "AssetRetrieval": { "House team may hold the objective; patrols may counter-attack toward the building." };
        case "AssetRetrievalVeh": { "Dismounted security may hold the road site; patrols may screen approaches." };
        case "AreaOfOperations": { "Objective garrisons will defend in place; enemy may shift forces between objectives under pressure." };
        case "Operation": { "Zone garrisons will hold built-up areas; enemy may move vehicles between sectors." };
        case "Raid": { "Each objective appears independently defended; assault on one site may draw enemy attention elsewhere." };
        case "Invasion": { "OPFOR pushes zone-by-zone from the beachhead; heliborne waves continue while they hold it. Retake INVASION to win." };
        case "PointDefense": { "Enemy will probe then assault the marked point with infantry and vehicle-borne waves from nearby ground; they will try to seize it while friendlies are absent." };
        case "EscapeEvasion": { "Dismounted patrols sweep the area; enemy may follow up after confirmed contact." };
        default { "Expect defenders to hold key ground on contact, adjust on flanks, or break contact once cohesion is lost." };
    };
    private _mdcoa = "Enemy reserves may commit additional troops or vehicles if local forces become decisively engaged.";
    private _civOn = missionNamespace getVariable ["FADE_civiliansEnabled", true];
    private _civLine = if (_civOn) then {
        "Civilians may be present; unknown individuals may observe or report activity."
    } else {
        "Civilian presence is not expected in the area."
    };
    if (_missionType == "Cargo") exitWith {
        private _bodyTag = format ["<t align='left' color='%1'>", _bodyCol];
        private _bodyEnd = "</t>";
        private _enemyPart = format [
            "<t align='left' color='#FFD166'>ENEMY</t><br/>" +
            _bodyTag + "No hostile forces are task-organized for this resupply run." + _bodyEnd + "<br/>" +
            _bodyTag + "Route is not expected to be contested." + _bodyEnd
        ];
        private _friendlyPart = format [
            "<br/><br/><t align='left' color='#FFD166'>FRIENDLY</t><br/>" +
            _bodyTag + "Forward camp with receiving party and local security patrols." + _bodyEnd + "<br/>" +
            _bodyTag + "%1 — task-organized from base." + _bodyEnd,
            _friendlyFactionDisplay
        ];
        _enemyPart + _friendlyPart +
            "<br/><br/><t align='left' color='#FFD166'>CIVILIAN</t><br/>" + _bodyTag + _civLine + _bodyEnd
    };
    if (_missionType == "EscapeEvasion") exitWith {
        private _tag = format ["<t align='left' color='%1'>", _bodyCol];
        private _end = "</t>";
        private _enemyPart = format [
            "<t align='left' color='#FFD166'>ENEMY</t><br/>" +
            _tag + "%1 - ~%2 troops (%3%4)." + _end + "<br/>" +
            _tag + "%5" + _end + "<br/>" +
            _tag + "%6" + _end + "<br/>" +
            _tag + "%7" + _end,
            _enemyFactionDisplay,
            _n,
            _echelon,
            _estQual,
            _specBlock,
            _mlcoa,
            _mdcoa
        ];
        private _friendlyPart = format [
            "<br/><br/><t align='left' color='#FFD166'>FRIENDLY</t><br/>" +
            _tag + "%1 — task-organized from base." + _end,
            _friendlyFactionDisplay
        ];
        _enemyPart + _friendlyPart +
            "<br/><br/><t align='left' color='#FFD166'>CIVILIAN</t><br/>" + _tag + _civLine + _end
    };
    private _bodyTag = format ["<t align='left' color='%1'>", _bodyCol];
    private _bodyEnd = "</t>";
    private _enemyPart = format [
        "<t align='left' color='#FFD166'>ENEMY</t><br/>" +
        _bodyTag + "%1 - ~%2 troops (%3%4)." + _bodyEnd + "<br/>" +
        _bodyTag + "%5" + _bodyEnd + "<br/>" +
        _bodyTag + "%6" + _bodyEnd + "<br/>" +
        _bodyTag + "%7" + _bodyEnd,
        _enemyFactionDisplay,
        _n,
        _echelon,
        _estQual,
        _specBlock,
        _mlcoa,
        _mdcoa
    ];
    private _friendlyPart = format [
        "<br/><br/><t align='left' color='#FFD166'>FRIENDLY</t><br/>" +
        _bodyTag + "%1 — task-organized from base." + _bodyEnd,
        _friendlyFactionDisplay
    ];
    _enemyPart + _friendlyPart +
        "<br/><br/><t align='left' color='#FFD166'>CIVILIAN</t><br/>" + _bodyTag + _civLine + _bodyEnd
}];

FADE_getZeroAlphaDisplayName = {
    private _zeroAlphaRaw = missionNamespace getVariable ["FAC_PILOT_1", objNull];
    private _displayName = "UNASSIGNED";
    if (_zeroAlphaRaw isEqualType objNull) then {
        if (!isNull _zeroAlphaRaw) then { _displayName = name _zeroAlphaRaw };
    } else {
        if (_zeroAlphaRaw isEqualType "") then { _displayName = _zeroAlphaRaw };
    };
    if (_displayName == "") then { "UNASSIGNED" } else { _displayName }
};
missionNamespace setVariable ["FADE_getZeroAlphaDisplayName", FADE_getZeroAlphaDisplayName];

FADE_missionComputeBriefingDefaults = {
    params [
        "_missionType",
        "_destPos",
        "_sideFriendly",
        "_sideEnemy",
        "_enemyFactionName",
        "_zeroAlphaDisplayName"
    ];
    private _friendlyPlayerCount = [_sideFriendly] call (missionNamespace getVariable ["FADE_countFriendlyPlayers", { 0 }]);
    private _friendlyFactionName = [] call FADE_getSmeacFriendlyLabel;
    private _acreChannelSummary = [] call (missionNamespace getVariable ["FADE_getAcreChannelSummary", { "ACRE channel names unavailable" }]);
    private _topographyData = [_destPos] call (missionNamespace getVariable ["FADE_getTopographySummary", { ["UNKNOWN", "Unknown area"] }]);
    private _topographyGrid = _topographyData param [0, "UNKNOWN"];
    private _topographyArea = _topographyData param [1, "Unknown area"];
    private _actualOpforCount = [_sideEnemy] call FADE_getEnemyMenCount;
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
        case "Raid": { 28 };
        case "Invasion": { 40 };
        case "PointDefense": { 24 };
        case "EscapeEvasion": { 22 };
        default { 10 };
    };
    private _opforBaseline = if (_missionType == "Cargo") then {
        0
    } else {
        if (_actualOpforCount > 0) then { _actualOpforCount } else { _fallbackOpforBaseline }
    };
    private _opforCountFactor = if (random 1 < 0.5) then { 0.8 } else { 1.2 };
    private _estimatedOpforCount = (round (_opforBaseline * _opforCountFactor)) max 0;
    private _intelFormatter = missionNamespace getVariable ["FADE_formatSituationIntelHtml", {}];
    private _defaultSituationHtml = if (_intelFormatter isEqualTo {}) then {
        format [
            "<t align='left' color='#B0B0B0'>Topography: Grid %2 | Area: %3</t><br/><t align='left' color='#B0B0B0'>Enemy: %1</t><br/><t align='left' color='#B0B0B0'>CTB task-organized from base.</t>",
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
            "<t align='left' color='#FFFFFF'>Topography: Grid %2 | Area: %3</t><br/><t align='left' color='#FFFFFF'>Enemy: %1</t><br/><t align='left' color='#FFFFFF'>CTB task-organized from base.</t>",
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
    private _defaultExecutionHtml = "<t align='left' color='#C0C0C0'>Follow map markers and task updates. Report phase changes on radio.</t>";
    private _defaultAdminHtml = format ["<t align='left' color='#FFFFFF'>Mission lead: Zero Alpha (%1)</t>", _zeroAlphaDisplayName];
    private _defaultCommandHtml = format ["<t align='left' color='#FFFFFF'>Radio: %1</t>", _acreChannelSummary];
    createHashMapFromArray [
        ["friendlyPlayerCount", _friendlyPlayerCount],
        ["friendlyFactionName", _friendlyFactionName],
        ["estimatedOpforCount", _estimatedOpforCount],
        ["opforCountFactor", _opforCountFactor],
        ["topographyGrid", _topographyGrid],
        ["topographyArea", _topographyArea],
        ["defaultSituationHtml", _defaultSituationHtml],
        ["defaultSituationHintHtml", _defaultSituationHintHtml],
        ["defaultExecutionHtml", _defaultExecutionHtml],
        ["defaultAdminHtml", _defaultAdminHtml],
        ["defaultCommandHtml", _defaultCommandHtml],
        ["defaultSituationTaskText", _defaultSituationHtml],
        ["defaultExecutionTaskText", "<t align='left' color='#C0C0C0'>Follow map markers and task updates. Report phase changes on radio.</t>"],
        ["defaultAdminTaskText", format ["<t align='left' color='#FFFFFF'>Mission lead: Zero Alpha (%1).</t>", _zeroAlphaDisplayName]],
        ["defaultCommandTaskText", format ["<t align='left' color='#FFFFFF'>Radio: %1.</t>", _acreChannelSummary]]
    ]
};
missionNamespace setVariable ["FADE_missionComputeBriefingDefaults", FADE_missionComputeBriefingDefaults];

// Recompute SMEAC location/lore at the resolved objective (many runners refine _destPos after Missions.sqf bootstrap).
FADE_missionRefreshBriefingAtPos = {
    params [
        "_missionType",
        "_objectivePos",
        "_sideFriendly",
        "_sideEnemy",
        "_enemyFactionName",
        "_zeroAlphaDisplayName",
        ["_operationName", ""]
    ];
    if (!(_objectivePos isEqualType []) || { count _objectivePos < 2 }) exitWith { createHashMap };
    private _briefDefaults = [
        _missionType, _objectivePos, _sideFriendly, _sideEnemy, _enemyFactionName, _zeroAlphaDisplayName
    ] call FADE_missionComputeBriefingDefaults;
    private _loreShort = "";
    private _loreLong = "";
    private _loreSmeacHtml = "";
    if (!isNil "FADE_lore_generate" && { _operationName isEqualType "" } && { _operationName != "" }) then {
        private _loreResult = [_missionType, _objectivePos, _operationName] call FADE_lore_generate;
        if (_loreResult isEqualType [] && { count _loreResult >= 3 }) then {
            _loreResult params ["_ls", "_ldiary", "_lsmeac"];
            _loreShort = _ls;
            _loreLong = _ldiary;
            _loreSmeacHtml = _lsmeac;
        };
    };
    private _situationHtml = _briefDefaults getOrDefault ["defaultSituationHtml", ""];
    private _sitHint = _briefDefaults getOrDefault ["defaultSituationHintHtml", ""];
    if (_loreLong != "") then {
        _sitHint = _sitHint + format ["<br/><br/><t align='left' color='#8BA4BE'>%1</t>", _loreLong];
        _briefDefaults set ["defaultSituationHintHtml", _sitHint];
    };
    _briefDefaults set ["defaultSituationTaskText", _situationHtml];
    _briefDefaults set ["loreShort", _loreShort];
    _briefDefaults set ["loreLong", _loreLong];
    _briefDefaults set ["loreSmeacHtml", _loreSmeacHtml];
    if (isServer) then {
        private _boardFn = missionNamespace getVariable ["FADE_hqMainBoard_setObjectiveBrief", {}];
        if (_boardFn isEqualType {} && { !(_boardFn isEqualTo {}) }) then {
            [_objectivePos] call _boardFn;
        };
    };
    _briefDefaults
};
missionNamespace setVariable ["FADE_missionRefreshBriefingAtPos", FADE_missionRefreshBriefingAtPos];

// Full SMEAC text for BI Task only (FADE_buildMissionTaskSmeacText). Assigned intro: FADE_showMissionAssignedIntro (typeText + Task hint).
FADE_smeac_formatBackgroundFallback = {
    params [["_enemyFactionName", "Hostile forces"]];
    format [
        "<t align='left' color='#FFD166'>BACKGROUND</t><br/>" +
        "<t align='left' color='#8BA4BE'>- %1 operating in the objective area.</t><br/>" +
        "<t align='left' color='#B0B0B0'>- Threat assessment: Local posture uncertain; treat all contacts as hostile until identified.</t><br/>" +
        "<t align='left' color='#B0B0B0'>- Commander's intent: Execute assigned objectives IAW task execution.</t>",
        _enemyFactionName
    ]
};
missionNamespace setVariable ["FADE_smeac_formatBackgroundFallback", FADE_smeac_formatBackgroundFallback];

FADE_smeac_wrapMissionHtml = {
    params ["_text"];
    if (_text isEqualTo "") exitWith { "" };
    if ((_text find "<t") >= 0) exitWith { _text };
    format ["<t align='left' color='#C0C0C0'>%1</t>", _text]
};
missionNamespace setVariable ["FADE_smeac_wrapMissionHtml", FADE_smeac_wrapMissionHtml];

missionNamespace setVariable ["FADE_buildMissionTaskSmeacText", {
    params [
        "_missionText",
        "_pos",
        ["_situationText", ""],
        ["_executionText", ""],
        ["_adminText", ""],
        ["_commandText", ""],
        ["_withholdGrid", false]
    ];
    private _br = "<br/>";
    private _bodyCol = "#B0B0B0";
    private _hdrCol = "#E8E8E8";
    private _sectionCol = "#FFD166";
    private _opName = missionNamespace getVariable ["FADE_missionRun_operationName", "Operation"];
    if (_opName isEqualTo "") then { _opName = "Operation" };
    if (_situationText isEqualTo "") then { _situationText = "<t align='left' color='#B0B0B0'>No situation picture available.</t>" };
    if (_executionText isEqualTo "") then { _executionText = "<t align='left' color='#C0C0C0'>Follow map markers and task updates.</t>" };
    if (_adminText isEqualTo "") then { _adminText = "<t align='left' color='#FFFFFF'>Mission lead: Zero Alpha.</t>" };
    if (_commandText isEqualTo "") then { _commandText = "<t align='left' color='#FFFFFF'>Use assigned radio channels.</t>" };
    private _backgroundHtml = missionNamespace getVariable ["FADE_missionRun_loreSmeacHtml", ""];
    if (_backgroundHtml isEqualTo "") then {
        private _enemyName = missionNamespace getVariable ["FADE_missionRun_enemyFactionName", "Hostile forces"];
        _backgroundHtml = [_enemyName] call FADE_smeac_formatBackgroundFallback;
    };
    private _grid = missionNamespace getVariable ["FADE_missionRun_topographyGrid", "UNKNOWN"];
    private _areaName = missionNamespace getVariable ["FADE_missionRun_topographyArea", "Unknown area"];
    if (_pos isEqualType [] && { count _pos >= 2 }) then {
        private _topoData = [_pos] call (missionNamespace getVariable ["FADE_getTopographySummary", { ["UNKNOWN", "Unknown area"] }]);
        _grid = _topoData param [0, _grid];
        _areaName = _topoData param [1, _areaName];
    };
    private _gridLine = if (_withholdGrid) then {
        format ["<t align='left' color='%1'>Grid withheld — map-reconnaissance drill</t>", _bodyCol]
    } else {
        format ["<t align='left' color='%1'>Grid %2 — %3</t>", _bodyCol, _grid, _areaName]
    };
    private _missionHtml = [_missionText] call FADE_smeac_wrapMissionHtml;
    format [
        "<t align='left' color='%1' size='1.05'>%2</t>%3%4%3%3" +
        "%5%3%3" +
        "<t align='left' color='%6'>SITUATION</t>%3%7%3%3" +
        "<t align='left' color='%6'>MISSION</t>%3%8%3%3" +
        "<t align='left' color='%6'>EXECUTION</t>%3%9%3%3" +
        "<t align='left' color='%6'>ADMIN</t>%3%10%3%3" +
        "<t align='left' color='%6'>COMMAND</t>%3%11",
        _hdrCol,
        _opName,
        _br,
        _gridLine,
        _backgroundHtml,
        _sectionCol,
        _situationText,
        _missionHtml,
        _executionText,
        _adminText,
        _commandText
    ]
}];

// Alive human players (server loops — build once per tick, reuse in sub-calls).
FADE_getAlivePlayers = {
    private _out = [];
    { if (alive _x && { isPlayer _x }) then { _out pushBack _x } } forEach allPlayers;
    _out
};

FADE_getAlivePlayerPositions = {
    private _out = [];
    {
        if (alive _x && { isPlayer _x }) then { _out pushBack (getPosATL _x) };
    } forEach allPlayers;
    _out
};

// Standard mission runner context (set by FADE_runMission in Missions.sqf before dispatch).
FADE_missionRun_contextFieldCount = 49;
missionNamespace setVariable ["FADE_missionRun_contextFieldCount", FADE_missionRun_contextFieldCount];

FADE_missionRun_getContext = {
    [
        missionNamespace getVariable ["FADE_missionRun_missionType", ""],
        missionNamespace getVariable ["FADE_missionRun_destPos", [0, 0, 0]],
        missionNamespace getVariable ["FADE_missionRun_player", objNull],
        missionNamespace getVariable ["FADE_missionRun_evadeePlayers", []],
        missionNamespace getVariable ["FADE_missionRun_fromMapClick", false],
        missionNamespace getVariable ["FADE_missionRun_mapAnchor", []],
        missionNamespace getVariable ["FADE_missionRun_friendlyUnits", []],
        missionNamespace getVariable ["FADE_missionRun_enemyUnits", []],
        missionNamespace getVariable ["FADE_missionRun_sideFriendly", west],
        missionNamespace getVariable ["FADE_missionRun_sideEnemy", east],
        missionNamespace getVariable ["FADE_missionRun_markerFriendly", "ColorWEST"],
        missionNamespace getVariable ["FADE_missionRun_markerEnemy", "ColorEAST"],
        missionNamespace getVariable ["FADE_surfaceIsDry", {}],
        missionNamespace getVariable ["FADE_missionRun_taskId", ""],
        missionNamespace getVariable ["FADE_missionRun_operationName", ""],
        missionNamespace getVariable ["FADE_missionRun_operationNameUpper", ""],
        missionNamespace getVariable ["FADE_missionRun_briefGuiTail", ""],
        missionNamespace getVariable ["FADE_jitterMarkerPos", {}],
        missionNamespace getVariable ["FADE_missionRun_enemyFactionName", ""],
        missionNamespace getVariable ["FADE_missionRun_zeroAlphaDisplayName", ""],
        missionNamespace getVariable ["FADE_missionRun_isGlobalMission", false],
        missionNamespace getVariable ["FADE_missionRun_basePos", [0, 0, 0]],
        missionNamespace getVariable ["FADE_missionRun_unitCount", 6],
        missionNamespace getVariable ["FADE_missionRun_unitClasses", []],
        missionNamespace getVariable ["FADE_scaleOpforCount", {}],
        missionNamespace getVariable ["FADE_mission_createTask", {}],
        missionNamespace getVariable ["FADE_mission_showAssignedHint", {}],
        missionNamespace getVariable ["FADE_missionRun_defaultSituationTaskText", ""],
        missionNamespace getVariable ["FADE_missionRun_defaultExecutionTaskText", ""],
        missionNamespace getVariable ["FADE_missionRun_defaultAdminTaskText", ""],
        missionNamespace getVariable ["FADE_missionRun_defaultCommandTaskText", ""],
        missionNamespace getVariable ["FADE_missionRun_defaultSituationHtml", ""],
        missionNamespace getVariable ["FADE_missionRun_defaultSituationHintHtml", ""],
        missionNamespace getVariable ["FADE_missionRun_friendlyPlayerCount", 0],
        missionNamespace getVariable ["FADE_missionRun_friendlyFactionName", ""],
        missionNamespace getVariable ["FADE_missionRun_estimatedOpforCount", 0],
        missionNamespace getVariable ["FADE_missionRun_opforCountFactor", 1],
        missionNamespace getVariable ["FADE_formatSituationIntelHtml", {}],
        missionNamespace getVariable ["FADE_missionRun_topographyGrid", "UNKNOWN"],
        missionNamespace getVariable ["FADE_missionRun_topographyArea", ""],
        missionNamespace getVariable ["FADE_missionRun_mapPickRawAnchor", []],
        missionNamespace getVariable ["FADE_missionRun_mapPickSnappedCenter", []],
        missionNamespace getVariable ["FADE_missionRun_mapPickResolvedRadius", -1],
        missionNamespace getVariable ["FADE_missionRun_convoyEndRaw", []],
        missionNamespace getVariable ["FADE_missionRun_convoyEndAnchor", []],
        missionNamespace getVariable ["FADE_missionRun_raidZoneClicks", []],
        missionNamespace getVariable ["FADE_missionRun_loreShort", ""],
        missionNamespace getVariable ["FADE_missionRun_loreLong", ""],
        missionNamespace getVariable ["FADE_missionRun_loreSmeacHtml", ""]
    ]
};

// Post-monitor cleanup tail (marker delete + clear active + scheduled entity cleanup).
FADE_mission_completeCleanup = {
    params ["_taskId", "_markerName", "_player", ["_delay", 60], ["_extraMarkers", []]];
    if (_markerName != "") then { [_markerName] call FADE_deleteMarkerSafe };
    if (_markerName != "") then {
        private _gridPrefix = _markerName + "_grid";
        if (getMarkerColor (_markerName + "_zone") != "") then { [_markerName + "_zone"] call FADE_deleteMarkerSafe };
        [_gridPrefix] call FADE_mission_deleteGridZoneMarkers;
    };
    { if (_x != "") then { [_x] call FADE_deleteMarkerSafe } } forEach _extraMarkers;
    if (!isNil "FADE_fieldIntel_endMission") then { [_taskId] call FADE_fieldIntel_endMission };
    if (!isNull _player && { (_player getVariable ["FADE_myMissionTaskId", ""]) == _taskId }) then {
        [_player] call FADE_clearActiveMission;
    };
    [_taskId, _delay, _player] call FADE_missionEnt_scheduledCleanup;
};

// AO sustain: points with no friendly infantry nearby (cheaper than per-point nearEntities when few BLUFOR).
FADE_ao_pointsWithoutFriendlies = {
    params ["_points", "_captureRadius", "_sideFriendly", ["_friendlyUnits", []]];
    if (_friendlyUnits isEqualTo []) then {
        _friendlyUnits = allUnits select { side _x == _sideFriendly && { alive _x } };
    };
    private _out = [];
    {
        private _pt = _x;
        private _empty = true;
        {
            if (alive _x && { _x distance _pt < _captureRadius }) exitWith { _empty = false };
        } forEach _friendlyUnits;
        if (_empty) then { _out pushBack _pt };
    } forEach _points;
    _out
};

missionNamespace setVariable ["FADE_getAlivePlayers", FADE_getAlivePlayers];
missionNamespace setVariable ["FADE_getAlivePlayerPositions", FADE_getAlivePlayerPositions];
missionNamespace setVariable ["FADE_missionRun_getContext", FADE_missionRun_getContext];
missionNamespace setVariable ["FADE_mission_completeCleanup", FADE_mission_completeCleanup];
missionNamespace setVariable ["FADE_ao_pointsWithoutFriendlies", FADE_ao_pointsWithoutFriendlies];
