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
    private _estQual = if (_opforCountFactor < 1) then { " (estimate may be low)" } else { " (estimate may be high)" };
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
    private _airSet = missionNamespace getVariable ["FADE_opforAirSetting", "Off"];
    private _airLine = if (_airSet isEqualTo "Off") then {
        "Hostile air is unlikely."
    } else {
        "Hostile rotary-wing may respond to detected friendly activity."
    };
    private _commsLine = if (_missionType in ["HVT", "Hostage", "ClearArea", "SearchDestroy", "CASEVAC", "CSAR", "Operation", "AreaOfOperations", "AssetRetrieval", "AssetRetrievalVeh", "InterceptConvoy", "EscapeEvasion"]) then {
        "Reinforcement (QRF) is possible after sustained contact."
    } else {
        "Reinforcement is unlikely; expect local contacts only."
    };
    private _specBlock = [_atLine, _airLine, _commsLine] joinString "<br/>";
    private _mlcoa = switch (_missionType) do {
        case "TroopInsert": { "Likely action: local security reacts to noise; minor harassing fire possible en route to LZ." };
        case "TroopExtract": { "Likely action: enemy may probe the pickup zone and try to delay embarkation." };
        case "CASEVAC": { "Likely action: enemy near the casualty site maintains pressure while you load." };
        case "CSAR": { "Likely action: search teams sweep toward the survivor; defend until extraction." };
        case "Cargo": { "Likely action: sporadic contacts on approach; garrison stays defensive at the drop site." };
        case "CAS": { "Likely action: enemy continues pressure on friendly positions and seeks cover when engaged from the air." };
        case "HVT": { "Likely action: guards protect the HVT; outer patrols try to canalise you into kill zones." };
        case "Hostage": { "Likely action: captors barricade structures and use hostages as cover while returning fire." };
        case "ClearArea": { "Likely action: garrison fights for the town; withdraws in fragments once cohesion breaks." };
        case "SearchDestroy": { "Likely action: garrisoned buildings hold ammo caches inside; outer guards and patrols reinforce toward gunfire." };
        case "InterceptConvoy": { "Likely action: escorts suppress flanks and push through; vehicles button up and run the route." };
        case "MineClearing": { "Likely action: minimal manoeuvre; treat the area as contaminated until cleared." };
        case "AssetRetrieval": { "Likely action: house team holds the objective; outer patrols counter-attack toward the building." };
        case "AssetRetrievalVeh": { "Likely action: dismounted security holds the road site; patrols screen approaches." };
        case "AreaOfOperations": { "Likely action: objective garrisons defend in place; patrols and QRF may shift between objectives." };
        case "Operation": { "Likely action: zone garrisons hold built-up areas; vehicles may move between zones." };
        case "EscapeEvasion": { "Likely action: dismounted patrols sweep the area; road QRF vectors on confirmed contact." };
        default { "Likely action: defend key ground on contact, adjust on flanks, or break contact once cohesion is lost." };
    };
    private _mdcoa = "Possible reinforcement: multi-axis ground or air QRF if the enemy still has capacity.";
    private _civOn = missionNamespace getVariable ["FADE_civiliansEnabled", true];
    private _civLine = if (_civOn) then {
        "Civilians may be present; unknown individuals may observe or report activity."
    } else {
        "Civilian presence is not expected in the area."
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
            _tag + "%1 - %2 players committed." + _end,
            _friendlyFactionDisplay,
            _friendlyPlayerCount
        ];
        _enemyPart + _friendlyPart +
            "<br/><br/><t align='left' color='#FFD166'>CIVILIAN</t><br/>" + _tag + _civLine + _end
    };
    private _bodyTag = format ["<t align='left' color='%1'>", _bodyCol];
    private _topoTag = format ["<t align='left' color='%1'>", _topoBodyCol];
    private _bodyEnd = "</t>";
    private _locationPart = format [
        "<t align='left' color='#FFD166'>LOCATION</t><br/>" +
        _topoTag + "Grid %1 - %2" + _bodyEnd,
        _topographyGrid,
        _topographyArea
    ];
    private _enemyPart = format [
        "<br/><br/><t align='left' color='#FFD166'>ENEMY</t><br/>" +
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
        _bodyTag + "%1 - %2 players committed." + _bodyEnd,
        _friendlyFactionDisplay,
        _friendlyPlayerCount
    ];
    _locationPart + _enemyPart + _friendlyPart +
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
    private _friendlyFactionClass = missionNamespace getVariable ["FADE_scenarioFriendlyFaction", "BLU_F"];
    private _friendlyFactionName = [_friendlyFactionClass] call (missionNamespace getVariable ["FADE_getFactionDisplayName", { _this select 0 }]);
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

// Full SMEAC text for BI Task only (FADE_buildMissionTaskSmeacText). Assigned intro: FADE_showMissionAssignedIntro (typeText + Task hint).
missionNamespace setVariable ["FADE_buildMissionTaskSmeacText", {
    params [
        "_missionText",
        "_pos",
        ["_situationText", ""],
        ["_executionText", ""],
        ["_adminText", ""],
        ["_commandText", ""],
        ["_omitAppendedTopography", false]
    ];
    private _br = "<br/>";
    if (_situationText isEqualTo "") then { _situationText = "No intel available." };
    if (_executionText isEqualTo "") then { _executionText = "Follow map markers and task updates." };
    if (_adminText isEqualTo "") then { _adminText = "Mission lead: Zero Alpha." };
    if (_commandText isEqualTo "") then { _commandText = "Use assigned radio channels." };
    private _topoData = [_pos] call (missionNamespace getVariable ["FADE_getTopographySummary", { ["UNKNOWN", "Unknown area"] }]);
    private _grid = _topoData param [0, "UNKNOWN"];
    private _areaName = _topoData param [1, "Unknown area"];
    private _sitHasLocation = ((_situationText find "LOCATION") >= 0) || { (_situationText find "TOPOGRAPHY") >= 0 };
    if (_sitHasLocation) exitWith {
        format [
            "<t align='left' color='#FFD166'>SITUATION</t>%1%2%1%1<t align='left' color='#FFD166'>MISSION</t>%1%3%1%1<t align='left' color='#FFD166'>EXECUTION</t>%1%4%1%1<t align='left' color='#FFD166'>ADMIN</t>%1%5%1%1<t align='left' color='#FFD166'>COMMAND</t>%1%6",
            _br,
            _situationText,
            _missionText,
            _executionText,
            _adminText,
            _commandText
        ]
    };
    if (_omitAppendedTopography) exitWith {
        format [
            "<t align='left' color='#FFD166'>SITUATION</t>%1%2%1%1<t align='left' color='#FFD166'>MISSION</t>%1%3%1%1<t align='left' color='#FFD166'>EXECUTION</t>%1%4%1%1<t align='left' color='#FFD166'>ADMIN</t>%1%5%1%1<t align='left' color='#FFD166'>COMMAND</t>%1%6",
            _br,
            _situationText,
            _missionText,
            _executionText,
            _adminText,
            _commandText
        ]
    };
    format [
        "<t align='left' color='#FFD166'>SITUATION</t>%1%2%1<t align='left' color='#B0B0B0'>Grid %3 - %8</t>%1%1<t align='left' color='#FFD166'>MISSION</t>%1%4%1%1<t align='left' color='#FFD166'>EXECUTION</t>%1%5%1%1<t align='left' color='#FFD166'>ADMIN</t>%1%6%1%1<t align='left' color='#FFD166'>COMMAND</t>%1%7",
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
