// =============================================================================

// FADE_MissionSlots.sqf  -  packed mission slot sync (server publish / client apply)

// =============================================================================



FADE_hqMainBoard_fontSize = 0.0525; // 25% smaller than prior 0.07 Caveat on 512² procedural texture

FADE_hqMainBoard_wrapChars = 48;



FADE_hqMainBoard_sanitizeTextureText = FADE_textureText_sanitize;

FADE_hqMainBoard_wrapText = {
    params [["_text", ""], ["_maxChars", FADE_hqMainBoard_wrapChars]];
    [_text, _maxChars] call FADE_textureText_wrap
};



FADE_hqMainBoard_missionTypeDisplayName = {

    params [["_missionType", ""]];

    private _displayName = _missionType;

    private _displayNameFnc = missionNamespace getVariable ["FADE_missionTypeDisplayName", {}];

    if (_displayNameFnc isEqualType {}) then {

        _displayName = [_missionType] call _displayNameFnc;

    };

    if (_displayName == _missionType) then {

        private _fallbackLabels = [

            ["AreaOfOperations", "Area of Operations"],

            ["AssetRetrieval", "Asset Retrieval"],

            ["CAS", "CAS / Fire Support"],

            ["ClearArea", "Clear Area"],

            ["CSAR", "CSAR"],

            ["EscapeEvasion", "Escape & Evasion"],

            ["GeoGuesser", "Geo-Guesser"],

            ["Hostage", "Hostage"],

            ["HVT", "HVT"],

            ["InterceptConvoy", "Intercept Convoy"],

            ["Operation", "Operation"],

            ["Raid", "Raid"],

            ["Invasion", "Invasion"],

            ["SearchDestroy", "Search & Destroy"]

        ];

        { if ((_x select 0) == _missionType) exitWith { _displayName = _x select 1 } } forEach _fallbackLabels;

    };

    _displayName

};



FADE_hqMainBoard_typeParenLabel = {

    params [["_missionType", ""]];

    switch (_missionType) do {

        case "AreaOfOperations": { "AO" };

        case "SearchDestroy": { "S&D" };

        case "EscapeEvasion": { "E&E" };

        case "InterceptConvoy": { "Intercept Convoy" };

        case "AssetRetrieval": { "Asset Retrieval" };

        case "MineClearing": { "Mine Clearing" };

        case "TroopInsert": { "Troop Insert" };

        case "TroopExtract": { "Troop Extract" };

        default { _missionType };

    };

};



FADE_hqMainBoard_missionTaskLine = {

    params [["_missionType", ""]];

    switch (_missionType) do {

        case "HVT": { "Eliminate or capture the HVT. Return captive to base to complete." };

        case "Hostage": { "Rescue civilians held by hostiles. Return all alive to base." };

        case "ClearArea": { "Destroy at least 80% of enemy forces in the area." };

        case "SearchDestroy": { "Search the marked zone and destroy enemy ammo caches per task criteria." };

        case "CAS": { "Provide fire support to friendly forces at the objective. Supported element must not be overrun." };

        case "Cargo": { "Deliver cargo to the camp. Land at the camp for the receiving party to unload." };

        case "CASEVAC": { "CASEVAC: extract casualties and return to base." };

        case "CSAR": { "CSAR: recover the survivor at the crash site and RTB." };

        case "AssetRetrieval": { "Recover priority equipment from enemy-held ground and return it to base." };

        case "InterceptConvoy": { "Stop the convoy: destroy or immobilise at least 60% of vehicles before they reach the end zone." };

        case "MineClearing": { "Clear mines and IEDs from the marked road segment." };

        case "AreaOfOperations": { "Capture objectives in sequence across the AO belt." };

        case "Operation": { "Clear and hold linked zones; prevent enemy movement between sectors." };

        case "Raid": { "Clear all marked objectives linked to the enemy network." };

        case "Invasion": { "Retake the INVASION beachhead to win; stop OPFOR capturing every zone." };

        case "EscapeEvasion": { "Move separated personnel to friendly lines while rescue coordinates recovery." };

        case "GeoGuesser": { "Navigate from a blind drop and mark your estimated position on the map." };

        case "TroopInsert": { "Insert friendly squads at the marked LZ and RTB between waves." };

        case "TroopExtract": { "Extract friendly squads from the field and RTB." };

        default { "Follow map markers and task updates to complete the operation." };

    };

};



FADE_hqMainBoard_resolveBrief = {

    params ["_globalMission", ["_objectivePos", []]];

    if (!(_globalMission isEqualType []) || { count _globalMission < 5 }) exitWith { [] };

    private _missionType = _globalMission param [0, ""];

    private _destPos = if (count _objectivePos >= 2) then { +_objectivePos } else { +(_globalMission param [2, []]) };

    private _operationName = _globalMission param [4, ""];

    if (count _destPos < 2) exitWith { [] };

    private _stored = missionNamespace getVariable ["FADE_hqMainBoard_brief", []];

    if (

        _stored isEqualType [] && { count _stored >= 4 } &&

        { count _objectivePos < 2 }

    ) exitWith { +_stored };

    private _topoFn = missionNamespace getVariable ["FADE_getTopographySummary", { ["UNKNOWN", "Unknown area"] }];

    private _topo = [_destPos] call _topoFn;

    private _grid = _topo param [0, "UNKNOWN"];

    private _area = _topo param [1, "Unknown area"];

    private _intentFn = missionNamespace getVariable ["FADE_lore_commanderIntentLine", {}];

    private _intent = if (_intentFn isEqualType {} && { !(_intentFn isEqualTo {}) }) then {

        [_missionType, _destPos, _operationName] call _intentFn

    } else { "" };

    private _mission = [_missionType] call FADE_hqMainBoard_missionTaskLine;

    [_intent, _mission, _area, _grid]

};



FADE_hqMainBoard_setObjectiveBrief = {

    params [["_objectivePos", []], ["_intentOverride", ""], ["_missionOverride", ""]];

    if (!isServer) exitWith {};

    private _global = missionNamespace getVariable ["FADE_globalMission", []];

    if (count _global < 5 || { count _objectivePos < 2 }) exitWith {};

    private _brief = [_global, _objectivePos] call FADE_hqMainBoard_resolveBrief;

    if (count _brief < 4) exitWith {};

    if (_intentOverride != "") then { _brief set [0, _intentOverride] };

    if (_missionOverride != "") then { _brief set [1, _missionOverride] };

    missionNamespace setVariable ["FADE_hqMainBoard_brief", _brief];

    [] call FADE_hqMainBoard_update;

};



FADE_hqMainBoard_buildTexture = {

    params [["_globalMission", []]];

    private _nl = toString [92, 110];

    private _body = "Stand down" + _nl + "No current operation underway";

    if (_globalMission isEqualType [] && { count _globalMission >= 5 }) then {

        private _missionType = _globalMission param [0, ""];

        private _operationName = [_globalMission param [4, ""]] call FADE_hqMainBoard_sanitizeTextureText;

        private _typeLabel = [_missionType] call FADE_hqMainBoard_typeParenLabel;

        private _brief = [_globalMission] call FADE_hqMainBoard_resolveBrief;

        private _intent = "";

        private _missionLine = "";

        private _area = "";

        private _grid = "";

        if (count _brief >= 4) then {

            _intent = [_brief param [0, ""]] call FADE_hqMainBoard_sanitizeTextureText;

            _missionLine = [_brief param [1, ""]] call FADE_hqMainBoard_sanitizeTextureText;

            _area = [_brief param [2, ""]] call FADE_hqMainBoard_sanitizeTextureText;

            _grid = [_brief param [3, ""]] call FADE_hqMainBoard_sanitizeTextureText;

        };

        private _intentMission = if (_intent != "") then {

            if (_missionLine != "") then { _intent + " " + _missionLine } else { _intent }

        } else {

            _missionLine

        };

        _intentMission = [_intentMission] call FADE_hqMainBoard_wrapText;

        private _locLine = if (_area != "" && { _grid != "" }) then {

            format ["%1 - %2", _area, _grid]

        } else {

            if (_grid != "") then { _grid } else { "" }

        };

        _body = format [

            "Today's Mission%1%2 (%3)%1%4%1%1%5",

            _nl,

            toUpper _operationName,

            [_typeLabel] call FADE_hqMainBoard_sanitizeTextureText,

            _locLine,

            _intentMission

        ];

    };

    format [

        "#(rgb,512,512,1)text(1,1,""Caveat"",%2,""#FFFFFF"",""#000000"",""%1"")",

        _body,

        FADE_hqMainBoard_fontSize

    ]

};



FADE_hqMainBoard_update = {

    if (!isServer) exitWith {};

    private _board = missionNamespace getVariable ["hqMainBoard", objNull];

    if (isNull _board) exitWith {};

    private _global = missionNamespace getVariable ["FADE_globalMission", []];

    if (!(_global isEqualType []) || { count _global < 5 }) then {

        missionNamespace setVariable ["FADE_hqMainBoard_brief", []];

    };

    private _texture = [_global] call FADE_hqMainBoard_buildTexture;

    _board setObjectTextureGlobal [0, _texture];

};



FADE_missionSlots_publish = {

    if (!isServer) exitWith {};

    private _global = +(missionNamespace getVariable ["FADE_globalMission", []]);

    if (_global isEqualType [] && { count _global >= 5 } && { count (_global param [2, []]) >= 2 }) then {

        [_global param [2, []]] call FADE_hqMainBoard_setObjectiveBrief;

    } else {

        missionNamespace setVariable ["FADE_hqMainBoard_brief", []];

    };

    private _pack = [

        "v1",

        +_global,

        + (missionNamespace getVariable ["FADE_singleMissions", []]),

        missionNamespace getVariable ["FADE_currentMissionType", ""],

        missionNamespace getVariable ["FADE_currentMissionPlayer", objNull]

    ];

    missionNamespace setVariable ["FADE_missionSlotsSync", _pack, true];

    publicVariable "FADE_missionSlotsSync";

    [] call FADE_hqMainBoard_update;

};



FADE_missionSlots_set = {

    if (!isServer) exitWith {};

    params [

        ["_global", nil],

        ["_singles", nil],

        ["_currentType", nil],

        ["_currentPlayer", nil]

    ];

    if (!isNil "_global") then {

        missionNamespace setVariable ["FADE_globalMission", _global];

    };

    if (!isNil "_singles") then {

        missionNamespace setVariable ["FADE_singleMissions", _singles];

    };

    if (!isNil "_currentType") then {

        missionNamespace setVariable ["FADE_currentMissionType", _currentType];

    };

    if (!isNil "_currentPlayer") then {

        missionNamespace setVariable ["FADE_currentMissionPlayer", _currentPlayer];

    };

    [] call FADE_missionSlots_publish;

};



FADE_applyMissionSlotsClientSync = {

    params ["_pack"];

    if (!hasInterface) exitWith {};

    if (!(_pack isEqualType []) || { count _pack < 5 }) exitWith {};

    if ((_pack select 0) != "v1") exitWith {};

    _pack params ["_ver", "_global", "_singles", "_curType", "_curPlayer"];

    missionNamespace setVariable ["FADE_globalMission", _global];

    missionNamespace setVariable ["FADE_singleMissions", _singles];

    missionNamespace setVariable ["FADE_currentMissionType", _curType];

    missionNamespace setVariable ["FADE_currentMissionPlayer", _curPlayer];

    private _fn = missionNamespace getVariable ["FAC_scenarioGui_onMissionSlotsSync", {}];
    if (_fn isEqualType {}) then { [] call _fn };

};



// True while a global or single mission slot is in use (blocks scenario faction changes).
FADE_anyScenarioMissionActive = {
    private _global = missionNamespace getVariable ["FADE_globalMission", []];
    if (_global isEqualType [] && { count _global >= 1 }) exitWith { true };
    private _singles = missionNamespace getVariable ["FADE_singleMissions", []];
    (_singles isEqualType []) && { count _singles > 0 }
};



missionNamespace setVariable ["FADE_missionSlots_publish", FADE_missionSlots_publish];

missionNamespace setVariable ["FADE_missionSlots_set", FADE_missionSlots_set];

missionNamespace setVariable ["FADE_applyMissionSlotsClientSync", FADE_applyMissionSlotsClientSync];

missionNamespace setVariable ["FADE_anyScenarioMissionActive", FADE_anyScenarioMissionActive];

missionNamespace setVariable ["FADE_hqMainBoard_update", FADE_hqMainBoard_update];

missionNamespace setVariable ["FADE_hqMainBoard_setObjectiveBrief", FADE_hqMainBoard_setObjectiveBrief];


